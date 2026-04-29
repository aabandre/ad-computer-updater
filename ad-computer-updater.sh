#!/bin/bash

# ==============================================================================
# Установщик AD Computer Updater (финальная версия - доверяем системным механизмам)
# Версия 15.0 ("Победа")
# ==============================================================================

set -e

SERVICE_NAME="ad-computer-updater"
LOG_FILE="/var/log/${SERVICE_NAME}.log"

echo "[$(date)] INFO: Начало чистой установки службы $SERVICE_NAME (Версия 15)"

# --- ШАГ 0: Принудительное удаление старых компонентов ---
echo "[$(date)] INFO: Принудительное удаление старых версий для чистого обновления..."
systemctl stop ${SERVICE_NAME}.timer >/dev/null 2>&1 || true
systemctl disable ${SERVICE_NAME}.timer >/dev/null 2>&1 || true
rm -f /etc/systemd/system/${SERVICE_NAME}.service
rm -f /etc/systemd/system/${SERVICE_NAME}.timer
rm -f /usr/local/sbin/ad-updater-dispatcher.sh
rm -f /usr/local/sbin/ad-updater-run.sh
rm -f /usr/local/sbin/ad-updater-logic.sh

# --- ШАГ 1: Создание скрипта-ДИСПЕТЧЕРА ---
mkdir -p /usr/local/sbin
cat > "/usr/local/sbin/ad-updater-dispatcher.sh" <<'DISPATCHER_SCRIPT'
#!/bin/bash
LOG_FILE="/var/log/ad-computer-updater.log"
exec >> "$LOG_FILE" 2>&1
echo "--- [$(date)] --- Диспетчер запущен (Версия 15). ---"
find_active_user() {
    for SESSION_ID in $(loginctl list-sessions --no-legend | awk '{print $1}'); do
        local PROPERTIES=$(loginctl show-session "$SESSION_ID")
        if echo "$PROPERTIES" | grep -q "Active=yes" && echo "$PROPERTIES" | grep -qE "Type=x11|Type=wayland"; then
            echo "$PROPERTIES" | grep "^Name=" | cut -d'=' -f2
            return 0
        fi
    done
    return 1
}
if ACTIVE_USER=$(find_active_user); then
    echo "[$(date)] INFO: Найден активный пользователь: $ACTIVE_USER. Запускаю обновление..."
    /usr/local/sbin/ad-updater-run.sh "$ACTIVE_USER"
else
    echo "[$(date)] INFO: Подходящая активная графическая сессия не найдена. Пропуск."
fi
echo "[$(date)] --- Диспетчер завершил работу. ---"
exit 0
DISPATCHER_SCRIPT
chmod 755 /usr/local/sbin/ad-updater-dispatcher.sh

# --- ШАГ 2: Создание скрипта-ИСПОЛНИТЕЛЯ (финальное исправление) ---
cat > "/usr/local/sbin/ad-updater-run.sh" <<'RUNNER_SCRIPT'
#!/bin/bash
USERNAME=$1
LOG_FILE="/var/log/ad-computer-updater.log"

if [ -z "$USERNAME" ]; then
    echo "[$(date)] ERROR: Имя пользователя не передано." >> "$LOG_FILE"
    exit 1
fi

# *** ФИНАЛЬНОЕ ИСПРАВЛЕНИЕ: Мы больше не проверяем файл! ***
# Мы просто доверяем, что 'runuser -l' создаст правильную сессию,
# в которой klist и ldapsearch сами найдут билет (в файле или ядре).
echo "[$(date)] INFO: Запускаю логику обновления для $USERNAME..." >> "$LOG_FILE"
runuser -l "$USERNAME" -c "/usr/local/sbin/ad-updater-logic.sh" &>> "$LOG_FILE"

RUNNER_SCRIPT
chmod 755 /usr/local/sbin/ad-updater-run.sh

# --- ШАГ 3: Создание скрипта с ЛОГИКОЙ (с новой проверкой) ---
cat > "/usr/local/sbin/ad-updater-logic.sh" <<'LOGIC_SCRIPT'
#!/bin/bash
# Эта версия сначала проверяет klist, а потом работает
print_message() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$USER] $1"; }

# *** НОВАЯ ПРОВЕРКА: Убеждаемся, что в этой сессии klist видит билет ***
if ! klist -s >/dev/null 2>&1; then
    print_message "ERROR: В сессии, созданной runuser, Kerberos-билет недоступен. Проверьте настройки SSSD/PAM."
    exit 1
fi

get_system_info() { echo "$(hostname -s | tr '[:lower:]' '[:upper:]') $(date '+%d.%m.%Y %H:%M:%S')"; }
computer_info=$(get_system_info)
kerberos_realm=$(klist | grep "Default principal:" | head -1 | sed 's/.*@//' | tr '[:upper:]' '[:lower:]')
if [ -z "$kerberos_realm" ]; then print_message "ERROR: Не удалось определить домен из билета."; exit 1; fi
domain_fqdn="$kerberos_realm"
base_dn="DC=$(echo $domain_fqdn | sed 's/\./,DC=/g')"
ldap_server=$(dig +short -t SRV _ldap._tcp.$domain_fqdn 2>/dev/null | sort -k2n | awk '{print $4}' | head -1 | sed 's/\.$//' || echo "$domain_fqdn")
ldap_uri="ldap://$ldap_server"
search_cmd="ldapsearch -Y GSSAPI -Q -H '$ldap_uri' -b '$base_dn' '(sAMAccountName=$USER)' dn streetAddress"
search_result=$(eval "$search_cmd" 2>&1)
unfolded_result=$(echo "$search_result" | perl -p00e 's/\n //g')
user_dn_line=$(echo "$unfolded_result" | grep -E "^dn::? ")
user_dn=""
if [[ $user_dn_line == dn::* ]]; then
    encoded_dn=$(echo "$user_dn_line" | sed 's/^dn:: //')
    if ! user_dn=$(echo "$encoded_dn" | base64 --decode 2>/dev/null); then print_message "ERROR: Ошибка декодирования DN."; exit 1; fi
elif [[ $user_dn_line == dn:* ]]; then user_dn=$(echo "$user_dn_line" | sed 's/^dn: //'); fi
if [ -z "$user_dn" ]; then print_message "ERROR: Пользователь '$USER' не найден."; exit 1; fi
ldif_file="/tmp/ad-update-$USER-$$.ldif"
cat > "$ldif_file" <<EOF
dn: $user_dn
changetype: modify
replace: streetAddress
streetAddress: $computer_info
EOF
if ! ldapmodify -Y GSSAPI -Q -H "$ldap_uri" -f "$ldif_file"; then
    print_message "ERROR: ldapmodify завершилась неудачно."
    rm -f "$ldif_file"; exit 1
fi
rm -f "$ldif_file"
sleep 1
verify_value=$(ldapsearch -Y GSSAPI -Q -H "$ldap_uri" -b "$base_dn" "(sAMAccountName=$USER)" streetAddress 2>/dev/null | grep "^streetAddress:" | sed 's/^streetAddress: //')
if [ "$verify_value" = "$computer_info" ]; then
    print_message "SUCCESS: Поле streetAddress обновлено: $verify_value"
else
    print_message "ERROR: 'Тихий отказ'. Ожидалось: [$computer_info], в AD сейчас: [$verify_value]"
fi
LOGIC_SCRIPT
chmod 755 /usr/local/sbin/ad-updater-logic.sh

# --- Создание системных файлов ---
cat > "/etc/systemd/system/${SERVICE_NAME}.service" <<'SERVICE_FILE'
[Unit]
Description=Dispatcher to find active user and update AD
After=network-online.target systemd-user-sessions.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/ad-updater-dispatcher.sh
SERVICE_FILE

cat > "/etc/systemd/system/${SERVICE_NAME}.timer" <<'TIMER_FILE'
[Unit]
Description=Run AD Computer Updater every 4 hours
[Timer]
OnBootSec=5min
OnUnitActiveSec=4h
Unit=ad-computer-updater.service
[Install]
WantedBy=timers.target
TIMER_FILE

cat > /etc/logrotate.d/ad-computer-updater <<'LOGROTATE_CONTENT'
/var/log/ad-computer-updater.log { weekly; rotate 4; compress; delaycompress; missingok; notifempty; create 0640 root adm; }
LOGROTATE_CONTENT
chmod 644 /etc/logrotate.d/ad-computer-updater

# --- Финальная активация ---
echo "[$(date)] INFO: Перезагрузка демона systemd и активация таймера..."
systemctl daemon-reload
systemctl enable --now ${SERVICE_NAME}.timer

echo "[$(date)] SUCCESS: Установка завершена."
echo "[$(date)] INFO: Для немедленного теста запустите: systemctl start ${SERVICE_NAME}.service"
echo "[$(date)] INFO: Для просмотра логов: cat ${LOG_FILE}"
