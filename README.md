# os-init

Особисті інструкції й скрипти для підняття машин з чистого стану: робочий Ubuntu 24.04.4, Kali Live USB з LUKS persistence, Orange Pi 5 під Hermes Agent.

Кожен каталог — окремий сценарій. Скрипти не оркеструються одним entrypoint: запускай їх по одному, у вказаному порядку, після перечитування.

## Структура

```text
ubuntu-24.04.4/     скрипти первинного налаштування десктопа
zsh/                два взаємовиключні вигляди термінала
kali/               Live USB + encrypted persistence
hermes-orange-pi/   Orange Pi 5, Keenetic, Hermes, Open WebUI
```

## Ubuntu 24.04.4

Цільова система: Ubuntu 24.04 з GNOME. Скрипти з номером ідуть по черзі. Решта — за потреби.

| Крок | Файл | Що робить |
| --- | --- | --- |
| 0 | [`0.system-update.sh`](ubuntu-24.04.4/0.system-update.sh) | `apt full-upgrade`, базові пакети, `fstrim.timer`, `fwupdmgr`, reboot |
| 1 | [`1.disable-snap-enable-flatpak.sh`](ubuntu-24.04.4/1.disable-snap-enable-flatpak.sh) | Flatpak + Flathub, заміна Firefox/Thunderbird, purge snapd, pin `snapd` на `-1` |
| 2 | [`2.soft-install.sh`](ubuntu-24.04.4/2.soft-install.sh) | Chrome, VS Code, Cursor, Sublime, Enpass, Mullvad, RustDesk, Antigravity, Telegram, Insomnia, Terminator, tmux, fnm/Node 24, pnpm, Bun, Gear Lever |
| 3 | [`3.resize-swap.sh`](ubuntu-24.04.4/3.resize-swap.sh) | zram (`zstd`) + `/swapfile` за обсягом RAM, `vm.swappiness=100` |

```bash
cd ubuntu-24.04.4
chmod +x ./*.sh
./0.system-update.sh
sudo ./1.disable-snap-enable-flatpak.sh
./2.soft-install.sh
sudo ./3.resize-swap.sh
```

`1.disable-snap-enable-flatpak.sh` сам піднімає себе через `sudo`. Прапорці: `-y`, `--purge-user-data` (архівує `~/snap` і видаляє оригінал), `--reboot`.

### Окремо, не в нумерації

| Файл | Що робить |
| --- | --- |
| [`gnome.sh`](ubuntu-24.04.4/gnome.sh) | Розширення GNOME (gTile, Clipboard Indicator, Vitals, Gnome 40 UI Improvements, WTMB), dock, розкладки `us`/`ua`/`ru`, Super+Space |
| [`create-new-user.sh`](ubuntu-24.04.4/create-new-user.sh) | Інтерактивний `adduser` |
| [`configurate-ssh-key.sh`](ubuntu-24.04.4/configurate-ssh-key.sh) | `ed25519`, `ssh-add`, `git config --global` user.name/email |
| [`setup-usbguard-approval.sh`](ubuntu-24.04.4/setup-usbguard-approval.sh) | USBGuard: нові USB блокуються, дозвіл через zenity + sudo-пароль |
| [`crd.md`](ubuntu-24.04.4/crd.md) | `WaylandEnable=false` у GDM, reboot, Chrome Remote Desktop у вже існуючу X-сесію |

USBGuard:

```bash
sudo ./setup-usbguard-approval.sh USERNAME
```

Політика будується з **уже підключених** пристроїв. Новий USB після цього — `block`, доки не підтвердиш у діалозі. Потрібен графічний сеанс (zenity, autostart).

## Термінал

Обидва гайди в [`zsh/`](zsh/) пишуть у `~/.zshrc`. Обери один.

| Файл | Результат |
| --- | --- |
| [`zsh/ubuntu-manjaro-gnome-terminal.md`](zsh/ubuntu-manjaro-gnome-terminal.md) | Powerlevel10k + плагіни з apt, без пакетів Arch. Перед записом робить `~/.zshrc.backup.*` |
| [`zsh/ubuntu-kali-terminal.md`](zsh/ubuntu-kali-terminal.md) | Офіційний `~/.zshrc` з `kali-defaults`, дворядковий prompt Kali |

## Kali Live USB

| Крок | Файл | Що робить |
| --- | --- | --- |
| 0 | [`kali/0.encrypted_persistence.md`](kali/0.encrypted_persistence.md) | Запис Live ISO, розділ 3, LUKS2, `persistence.conf` = `/ union` |
| 1 | [`kali/1.initial_setup.md`](kali/1.initial_setup.md) | Оновлення всередині persistence, пароль, timezone `Europe/Kyiv`, каталоги `~/Security`, Burp |

`dd`, `luksFormat` і `mkfs.ext4` знищують дані цільового пристрою. У прикладах `/dev/sda` — плейсхолдер: звіряй `lsblk` за моделлю і розміром перед кожною командою. Пароль LUKS не відновлюється. Копію заголовка (`luksHeaderBackup`) тримай на іншому носії, не на флешці.

Завантажувати треба пункт **Live USB Encrypted Persistence**. Звичайний Live зашифрований розділ не чіпає.

## Hermes на Orange Pi 5

Два документи розходяться щодо Docker і Tailscale. Бери гілку свідомо.

| Крок | Файл | Що робить |
| --- | --- | --- |
| 0 | [`hermes-orange-pi/0.os-init.md`](hermes-orange-pi/0.os-init.md) | SSH лише по ключу, ufw, fail2ban, Tailscale, Docker, каталоги `/srv/hermes/{personal,work,backups}` |
| 1 | [`hermes-orange-pi/1.keenetic-setup.md`](hermes-orange-pi/1.keenetic-setup.md) | Сегмент `Hermes-Isolated` `192.168.50.0/24`, порт лише під Orange Pi, SSH з дому на `192.168.50.10:22` |
| 2 | [`hermes-orange-pi/2.hermes-install.md`](hermes-orange-pi/2.hermes-install.md) | Один Hermes від `adminpi` прямо в ОС. Docker і Tailscale тут не використовуються |
| 3 | [`hermes-orange-pi/3.open-webui.md`](hermes-orange-pi/3.open-webui.md) | Hermes API на `127.0.0.1:8642`, Open WebUI на `127.0.0.1:3000`, зовні лише Tailscale Serve |

`0` готує два контейнерні інстанси і Tailscale. `2` ставить одного агента без Docker. `3` знову потребує Docker і Tailscale, але для Open WebUI поруч із уже встановленим Hermes, не для самого агента.

Мережева межа — Keenetic: Pi ходить в інтернет і не ініціює з’єднання в домашній сегмент. Це не захищає файли й ключі на самому Pi, якщо агент скомпрометований. Не давай Hermes `/var/run/docker.sock` і `--privileged`. Funnel, DMZ і проброс 3000/8642 не вмикати: доступ лише через tailnet.

## Що скрипти міняють без окремого питання

- `0.system-update.sh` в кінці робить reboot.
- `1.disable-snap-enable-flatpak.sh` теж ребутить (`systemctl reboot -i`) навіть без `--reboot`.
- `3.resize-swap.sh` видаляє наявний `/swapfile` і переписує його запис у `fstab`.
- `2.soft-install.sh` ставить сторонні APT-репозиторії (Google, Microsoft, Cursor, Sublime, Enpass, Mullvad, Antigravity) і качає `.deb` з GitHub Releases.
- `gnome.sh` ставить розкладки US, UA, RU і хоткеї Super+Space / Shift+Super+Space.
