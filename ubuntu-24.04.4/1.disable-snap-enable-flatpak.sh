#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
PURGE_USER_DATA=false
ASSUME_YES=false
REBOOT_AFTER=false

usage() {
  cat <<EOF
Використання:
  sudo ./$SCRIPT_NAME [options]

Опції:
  -y, --yes              Не питати підтвердження
  --purge-user-data      Зробити бекап ~/snap і видалити оригінальний каталог
  --reboot               Перезавантажити систему після завершення
  -h, --help             Показати цю довідку
EOF
}

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32mГотово:\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mПопередження:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mПомилка:\033[0m %s\n' "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  printf '\n\033[1;31mСкрипт зупинився на рядку %s з кодом виходу %s.\033[0m\n' \
    "${BASH_LINENO[0]:-unknown}" "$exit_code" >&2
  exit "$exit_code"
}
trap on_error ERR

while (($#)); do
  case "$1" in
    -y|--yes) ASSUME_YES=true ;;
    --purge-user-data) PURGE_USER_DATA=true ;;
    --reboot) REBOOT_AFTER=true ;;
    -h|--help) usage; exit 0 ;;
    *) die "Невідома опція: $1" ;;
  esac
  shift
done

if ((EUID != 0)); then
  sudo_args=()
  $ASSUME_YES && sudo_args+=(--yes)
  $PURGE_USER_DATA && sudo_args+=(--purge-user-data)
  $REBOOT_AFTER && sudo_args+=(--reboot)
  exec sudo -- "$0" "${sudo_args[@]}"
fi

[[ -r /etc/os-release ]] || die "Не вдалося визначити дистрибутив Linux."
# shellcheck disable=SC1091
source /etc/os-release

[[ "${ID:-}" == "ubuntu" ]] || die "Цей скрипт призначений лише для Ubuntu."
command -v apt-get >/dev/null || die "APT не знайдено. Ubuntu Core не підтримується."

TARGET_USER="${SUDO_USER:-${USER:-root}}"
if [[ "$TARGET_USER" == "root" ]]; then
  TARGET_HOME="/root"
else
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
fi
[[ -n "$TARGET_HOME" ]] || die "Не вдалося визначити домашній каталог користувача."

if ! $ASSUME_YES; then
  cat <<EOF

Буде виконано такі дії:
  • встановити Flatpak, Flathub і GNOME Software;
  • встановити Flatpak-версії Firefox і Thunderbird, якщо виявлено їхні Snap-версії;
  • видалити всі пакети Snap і snapd;
  • заблокувати повторне встановлення snapd через APT;
  • видалити системні дані Snap.

Домашній каталог користувача: $TARGET_HOME
EOF

  if $PURGE_USER_DATA; then
    warn "$TARGET_HOME/snap буде заархівовано, а потім видалено."
  else
    warn "$TARGET_HOME/snap буде збережено."
  fi

  read -r -p "Продовжити? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 0
fi

export DEBIAN_FRONTEND=noninteractive

log "Встановлення Flatpak і графічного менеджера ПЗ"
apt-get update

if ! apt-get install -y flatpak gnome-software gnome-software-plugin-flatpak; then
  warn "Потрібні пакети не знайдено. Увімкнення репозиторію Universe."
  apt-get install -y software-properties-common
  add-apt-repository -y universe
  apt-get update
  apt-get install -y flatpak gnome-software gnome-software-plugin-flatpak
fi

log "Додавання Flathub"
flatpak remote-add --system --if-not-exists \
  flathub https://dl.flathub.org/repo/flathub.flatpakrepo

snap_installed() {
  command -v snap >/dev/null 2>&1 && snap list "$1" >/dev/null 2>&1
}

install_flatpak_replacement() {
  local snap_name="$1"
  local flatpak_id="$2"

  if snap_installed "$snap_name"; then
    log "Встановлення Flatpak-заміни для Snap-пакета $snap_name"
    if flatpak install --system -y flathub "$flatpak_id"; then
      ok "$flatpak_id встановлено"
    else
      warn "Не вдалося встановити $flatpak_id. Snap-пакет усе одно буде видалено."
    fi
  fi
}

install_flatpak_replacement firefox org.mozilla.firefox
install_flatpak_replacement thunderbird org.mozilla.Thunderbird

remove_snapshots() {
  command -v snap >/dev/null 2>&1 || return 0

  local snapshot_ids
  snapshot_ids="$(snap saved 2>/dev/null | awk 'NR > 1 && $1 ~ /^[0-9]+$/ {print $1}' | sort -u || true)"

  if [[ -n "$snapshot_ids" ]]; then
    log "Видалення раніше створених знімків Snap"
    while IFS= read -r snapshot_id; do
      snap forget "$snapshot_id" || warn "Не вдалося видалити знімок $snapshot_id"
    done <<< "$snapshot_ids"
  fi
}

remove_all_snaps() {
  command -v snap >/dev/null 2>&1 || return 0

  local -a packages=()
  local progress package

  while true; do
    mapfile -t packages < <(snap list 2>/dev/null | awk 'NR > 1 {print $1}')

    ((${#packages[@]} == 0)) && break
    progress=false

    for package in "${packages[@]}"; do
      printf 'Видалення Snap-пакета: %s\n' "$package"
      if snap remove --purge "$package"; then
        progress=true
      fi
    done

    $progress || break
  done

  mapfile -t packages < <(snap list 2>/dev/null | awk 'NR > 1 {print $1}')
  if ((${#packages[@]} > 0)); then
    printf 'Не вдалося видалити Snap-пакети: %s\n' "${packages[*]}" >&2
    return 1
  fi
}

if command -v snap >/dev/null 2>&1; then
  log "Видалення Snap-пакетів"
  remove_snapshots
  remove_all_snaps
else
  warn "Snap уже відсутній."
fi

log "Вимкнення та видалення snapd"
systemctl disable --now \
  snapd.socket snapd.service snapd.seeded.service \
  snapd.autoimport.service 2>/dev/null || true

apt-get purge -y snapd || true

log "Блокування повторного встановлення snapd"
cat >/etc/apt/preferences.d/nosnap.pref <<'EOF'
Package: snapd
Pin: version *
Pin-Priority: -1
EOF

log "Видалення системних каталогів Snap"
rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd

if $PURGE_USER_DATA && [[ -d "$TARGET_HOME/snap" ]]; then
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup="$TARGET_HOME/snap-backup-$timestamp.tar.gz"

  log "Створення резервної копії користувацьких даних Snap"
  tar -C "$TARGET_HOME" -czf "$backup" snap
  chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$backup"
  rm -rf "$TARGET_HOME/snap"
  ok "Резервну копію створено: $backup"
elif [[ -d "$TARGET_HOME/snap" ]]; then
  warn "Користувацькі дані Snap збережено в $TARGET_HOME/snap"
fi

log "Перевірка результату"
command -v flatpak >/dev/null || die "Flatpak не встановлено."
flatpak remotes --system | grep -q '^flathub' || die "Flathub не налаштовано."

ok "Flatpak і Flathub налаштовано."
ok "Snap видалено і заблоковано."

printf '\nПриклади команд:\n'
printf '  flatpak search telegram\n'
printf '  flatpak install flathub org.telegram.desktop\n'
printf '  flatpak update\n'

if $REBOOT_AFTER; then
  log "Перезавантаження системи"
  systemctl reboot
else
  printf '\nПерезавантаж систему, щоб завершити налаштування:\n'
  printf '  sudo reboot\n'
fi

sudo systemctl reboot -i
