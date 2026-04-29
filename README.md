# ad-computer-updater
Automatic Linux Active Directory workstation agent that updates user's LDAP streetAddress attribute via Kerberos GSSAPI.
# AD Computer Updater — Full GitHub Repository Package (RU + EN)
# AD Computer Updater
![License](https://img.shields.io/badge/license-MIT-green)
![Shell](https://img.shields.io/badge/language-bash-blue)
![Systemd](https://img.shields.io/badge/service-systemd-orange)
![Kerberos](https://img.shields.io/badge/auth-GSSAPI-red)
---

# 🇬🇧 English

Automatic Linux Active Directory workstation agent that periodically updates the current domain user's `streetAddress` LDAP attribute with:

- workstation hostname
- last activity date/time

This allows administrators to instantly determine from which Linux workstation a domain user was last active.

## Features

- Fully automatic systemd timer based execution
- Detects active graphical domain session
- Kerberos SSO authentication (no passwords stored)
- LDAP update through GSSAPI
- Verifies successful write-back
- Detailed logging
- Log rotation included
- Zero maintenance after installation

## Example value written to AD

```text
ALTWS001 29.04.2026 14:30:55
````

## Installation

```bash
chmod +x install-ad-computer-updater.sh
sudo ./install-ad-computer-updater.sh
```

## Manual Test

```bash
systemctl start ad-computer-updater.service
cat /var/log/ad-computer-updater.log
```

## Security Model

No passwords.
No service accounts.
No keytabs.

Authentication is performed using the logged-in user's Kerberos ticket.

## Requirements

* Linux workstation joined to Active Directory
* SSSD / Kerberos configured
* Domain users log in via graphical session
* Packages: ldap-utils/openldap-clients, krb5, bind-utils, perl

---

# 🇷🇺 Русский

Автоматический агент Linux для Active Directory, который периодически обновляет LDAP-атрибут `streetAddress` у текущего доменного пользователя, записывая:

* имя рабочей станции
* дату и время последней активности

Это позволяет администраторам мгновенно определить, с какого Linux-компьютера пользователь домена работал последний раз.

## Возможности

* Полностью автоматический запуск через systemd timer
* Определение активной графической пользовательской сессии
* Kerberos SSO аутентификация без хранения паролей
* Обновление LDAP через GSSAPI
* Контроль успешности записи
* Подробное логирование
* Ротация логов
* Не требует обслуживания после установки

## Пример значения в AD

```text
ALTWS001 29.04.2026 14:30:55
```

## Установка

```bash
chmod +x install-ad-computer-updater.sh
sudo ./install-ad-computer-updater.sh
```

## Ручной тест

```bash
systemctl start ad-computer-updater.service
cat /var/log/ad-computer-updater.log
```

## Модель безопасности

Без паролей.
Без service account.
Без keytab.

Аутентификация выполняется Kerberos-билетом вошедшего пользователя.

## Требования

* Linux рабочая станция введена в Active Directory
* Настроен SSSD / Kerberos
* Доменные пользователи входят через графическую сессию
* Пакеты: ldap-utils/openldap-clients, krb5, bind-utils, perl

---


```markdown
# Changelog / История изменений

## Version 15.0 — Victory / Победа
- Complete clean installer / Полный чистый установщик
- Reliable graphical session detection / Надёжное определение графической сессии
- Full GSSAPI LDAP modify logic / Полная логика LDAP-модификации через GSSAPI
- Verification readback / Контрольная проверка записи
- Logrotate support / Поддержка ротации логов
- Systemd timer automation / Автоматизация через systemd timer
```

---



```markdown
# Contributing / Участие в разработке

Pull requests are welcome.

Приветствуются pull request и улучшения в областях:

- multi-domain support / поддержка нескольких доменов
- additional LDAP attributes / дополнительные LDAP-атрибуты
- workstation hardware inventory / аппаратная инвентаризация ПК
- network information collection / сбор сетевой информации
- OS distribution detection / определение дистрибутива Linux
```

---

