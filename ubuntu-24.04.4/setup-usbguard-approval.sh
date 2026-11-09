#!/usr/bin/env bash

# chmod +x setup-usbguard-approval.sh

set -euo pipefail

TARGET_USER="${1:-${SUDO_USER:-}}"

if [[ $EUID -ne 0 ]]; then
  echo "Запусти від root: sudo $0 USERNAME"
  exit 1
fi

if [[ -z "$TARGET_USER" || "$TARGET_USER" == "root" ]]; then
  echo "Вкажи користувача: sudo $0 USERNAME"
  exit 1
fi

if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "Користувача не знайдено: $TARGET_USER"
  exit 1
fi

echo "[1/9] Встановлення пакетів"
apt update
apt install -y usbguard zenity libnotify-bin ssh-askpass-gnome

echo "[2/9] Група usb-approvers"
groupadd --system usb-approvers 2>/dev/null || true
usermod -aG usb-approvers "$TARGET_USER"

echo "[3/9] Зупинка USBGuard"
systemctl stop usbguard 2>/dev/null || true

echo "[4/9] Генерація політики для поточних підключених USB"
install -d -m 700 /etc/usbguard
usbguard generate-policy > /etc/usbguard/rules.conf
chmod 600 /etc/usbguard/rules.conf
chown root:root /etc/usbguard/rules.conf

echo "[5/9] Конфіг USBGuard"
install -d -m 700 /etc/usbguard/IPCAccessControl.d

cat > /etc/usbguard/usbguard-daemon.conf <<'EOF'
RuleFile=/etc/usbguard/rules.conf

ImplicitPolicyTarget=block
PresentDevicePolicy=apply-policy
PresentControllerPolicy=keep
InsertedDevicePolicy=block
AuthorizedDefault=none
RestoreControllerDeviceState=false

IPCAllowedUsers=root
IPCAccessControlFiles=/etc/usbguard/IPCAccessControl.d/
EOF

chmod 600 /etc/usbguard/usbguard-daemon.conf
chown root:root /etc/usbguard/usbguard-daemon.conf

echo "[6/9] Команда підтвердження USB"
cat > /usr/local/sbin/usb-approve <<'EOF'
#!/bin/sh
set -eu

USB=/usr/bin/usbguard
cmd="${1:-}"

case "$cmd" in
  list)
    exec "$USB" list-devices
    ;;
  blocked)
    exec "$USB" list-devices -b
    ;;
  allow)
    id="${2:-}"
    case "$id" in ''|*[!0-9]*) echo "Використання: usb-approve allow <id>" >&2; exit 2;; esac
    exec "$USB" allow-device "$id"
    ;;
  block)
    id="${2:-}"
    case "$id" in ''|*[!0-9]*) echo "Використання: usb-approve block <id>" >&2; exit 2;; esac
    exec "$USB" block-device "$id"
    ;;
  *)
    echo "Використання: usb-approve {list|blocked|allow <id>|block <id>}" >&2
    exit 2
    ;;
esac
EOF

chmod 750 /usr/local/sbin/usb-approve
chown root:root /usr/local/sbin/usb-approve

echo "[7/9] Sudoers з обов’язковим паролем"
cat > /etc/sudoers.d/usb-approve <<'EOF'
Cmnd_Alias USB_APPROVE = /usr/local/sbin/usb-approve *
Defaults!USB_APPROVE timestamp_timeout=0
%usb-approvers ALL=(root) PASSWD: USB_APPROVE
EOF

chmod 0440 /etc/sudoers.d/usb-approve
chown root:root /etc/sudoers.d/usb-approve
visudo -c >/dev/null

echo "[8/9] UI і вікно пароля USBGuard"
install -d -m 755 /usr/local/libexec

cat > /usr/local/libexec/usbguard-askpass <<'EOF'
#!/bin/sh
zenity --password \
  --title="USBGuard" \
  --text="${SUDO_ASKPASS_PROMPT:-Введіть пароль для дозволу USB}"
EOF

chmod 755 /usr/local/libexec/usbguard-askpass
chown root:root /usr/local/libexec/usbguard-askpass

cat > /usr/local/bin/usb-approval-ui <<'EOF'
#!/usr/bin/env bash
set -u

[ -n "${XDG_RUNTIME_DIR:-}" ] || exit 0

export SUDO_ASKPASS="/usr/local/libexec/usbguard-askpass"

STATE_DIR="$XDG_RUNTIME_DIR/usb-approval-ui"
mkdir -p "$STATE_DIR"

exec 9>"$STATE_DIR/lock"
flock -n 9 || exit 0

while true; do
  devices="$(usbguard list-devices -b 2>/dev/null || true)"

  while IFS= read -r line; do
    [ -n "$line" ] || continue

    id="${line%%:*}"
    case "$id" in
      ''|*[!0-9]*) continue ;;
    esac

    marker="$STATE_DIR/device-$id"
    [ -e "$marker" ] && continue
    touch "$marker"

    safe_line="$(printf '%s' "$line" \
      | sed 's/serial "[^"]*"/serial "***"/g; s/hash "[^"]*"/hash "***"/g')"

    notify-send "USBGuard" "Заблоковано USB-пристрій #$id"

    if zenity --question \
      --width=720 \
      --title="USBGuard" \
      --ok-label="Дозволити" \
      --cancel-label="Залишити заблокованим" \
      --text="Заблоковано USB-пристрій:\n\n$safe_line\n\nДозволити пристрій?"; then

      if sudo -A -p "Введіть пароль для дозволу USB: " /usr/local/sbin/usb-approve allow "$id"; then
        notify-send "USBGuard" "USB-пристрій #$id дозволено"
      else
        rm -f "$marker"
        notify-send "USBGuard" "Не вдалося дозволити USB-пристрій #$id"
      fi
    fi
  done <<< "$devices"

  sleep 2
done
EOF

chmod 755 /usr/local/bin/usb-approval-ui
chown root:root /usr/local/bin/usb-approval-ui

cat > /etc/xdg/autostart/usb-approval-ui.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=USB Approval UI
Exec=/usr/local/bin/usb-approval-ui
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF

chmod 644 /etc/xdg/autostart/usb-approval-ui.desktop
chown root:root /etc/xdg/autostart/usb-approval-ui.desktop

echo "[9/9] Запуск USBGuard"
systemctl enable --now usbguard
systemctl restart usbguard

usbguard remove-user usb-approvers -g 2>/dev/null || true
usbguard add-user usb-approvers -g -d list,listen

systemctl restart usbguard

echo
echo "Готово."
echo "Користувача додано: $TARGET_USER"
echo "Тепер перезавантаж систему:"
echo "sudo reboot"
