#!/usr/bin/env bash

set -Eeuo pipefail

BASE_URL="https://extensions.gnome.org"

###############################################################################
# https://extensions.gnome.org/extension/28/gtile/
# https://extensions.gnome.org/extension/779/clipboard-indicator/
# https://extensions.gnome.org/extension/1460/vitals/
# https://extensions.gnome.org/extension/4158/gnome-40-ui-improvements/
# https://extensions.gnome.org/extension/6816/wtmb-window-thumbnails/
###############################################################################

DEFAULT_EXTENSIONS=(
  28
  779
  1460
  4158
  6816
)

log() {
  printf '\033[1;34m[INFO]\033[0m %s\n' "$*"
}

success() {
  printf '\033[1;32m[OK]\033[0m %s\n' "$*"
}

error() {
  printf '\033[1;31m[ERROR]\033[0m %s\n' "$*" >&2
}

install_dependencies() {
  local packages=()

  command -v curl >/dev/null || packages+=("curl")
  command -v python3 >/dev/null || packages+=("python3")
  command -v gnome-extensions >/dev/null || packages+=("gnome-shell-extensions")

  [[ ${#packages[@]} -eq 0 ]] && return

  if command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y "${packages[@]}"
  elif command -v dnf >/dev/null; then
    sudo dnf install -y "${packages[@]}"
  elif command -v pacman >/dev/null; then
    sudo pacman -Sy --needed "${packages[@]}"
  elif command -v zypper >/dev/null; then
    sudo zypper install -y "${packages[@]}"
  else
    error "Не вдалося визначити менеджер пакетів."
    exit 1
  fi
}

get_shell_version() {
  gnome-shell --version | grep -oE '[0-9]+(\.[0-9]+)?' | head -n1
}

install_extension() {
  local extension_id="$1"
  local shell_version="$2"
  local metadata
  local uuid
  local download_url
  local archive

  log "Обробка ID: ${extension_id}"

  metadata="$(
    curl -fsSL \
      "${BASE_URL}/extension-info/?pk=${extension_id}&shell_version=${shell_version}"
  )" || {
    error "Не вдалося отримати інформацію для ID ${extension_id}"
    return 1
  }

  uuid="$(
    python3 -c '
import json, sys
data = json.load(sys.stdin)
print(data.get("uuid", ""))
' <<< "$metadata"
  )"

  download_url="$(
    python3 -c '
import json, sys
data = json.load(sys.stdin)
print(data.get("download_url", ""))
' <<< "$metadata"
  )"

  if [[ -z "$uuid" || -z "$download_url" ]]; then
    error "Розширення ${extension_id} не знайдено або несумісне з GNOME ${shell_version}"
    return 1
  fi

  if [[ "$download_url" != http* ]]; then
    download_url="${BASE_URL}${download_url}"
  fi

  archive="$(mktemp --suffix=.zip)"

  curl -fsSL "$download_url" -o "$archive" || {
    rm -f "$archive"
    error "Помилка завантаження ${uuid}"
    return 1
  }

  if gnome-extensions list | grep -Fxq "$uuid"; then
    log "${uuid} уже встановлено; оновлення..."
    gnome-extensions install --force "$archive"
  else
    gnome-extensions install "$archive"
  fi

  rm -f "$archive"

  gnome-extensions enable "$uuid" 2>/dev/null || true

  success "${uuid} встановлено і увімкнено"
}

main() {
  local extension_ids=("$@")

  if [[ ${#extension_ids[@]} -eq 0 ]]; then
    extension_ids=("${DEFAULT_EXTENSIONS[@]}")
  fi

  install_dependencies

  local shell_version
  shell_version="$(get_shell_version)"

  if [[ -z "$shell_version" ]]; then
    error "Не вдалося визначити версію GNOME Shell"
    exit 1
  fi

  log "GNOME Shell: ${shell_version}"

  for extension_id in "${extension_ids[@]}"; do
    if [[ "$extension_id" =~ ^[0-9]+$ ]]; then
      install_extension "$extension_id" "$shell_version" || true
    else
      error "Некоректний ID: ${extension_id}"
    fi
  done

  echo
  log "Вийди з сеансу і увійди знову, якщо розширення не з’явилися."
}

main "$@"

echo "===== Налаштування GNOME UI ====="
# Згортати вікно подвійним кліком по іконці в dock
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize-or-previews'
# Дробове масштабування для високого DPI
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

echo "GNOME-розширення успішно налаштовано."

###############################################################################
# Зміна системних налаштувань
###############################################################################

# Показувати відсоток батареї
gsettings set org.gnome.desktop.interface show-battery-percentage true

# Вимкнути автоматичне вимкнення екрана — Never
gsettings set org.gnome.desktop.session idle-delay 0

# Режим продуктивності
powerprofilesctl set performance

# Hot Corner
gsettings set org.gnome.desktop.interface enable-hot-corners true

# Активні краї екрана
gsettings set org.gnome.mutter edge-tiling true

# Робочі простори на всіх моніторах
gsettings set org.gnome.mutter workspaces-only-on-primary false

# Розмір іконок Dock — 36 px
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 36

# Показувати Dock на всіх моніторах
gsettings set org.gnome.shell.extensions.dash-to-dock multi-monitor true

# Приховати домашню теку на робочому столі
gsettings set org.gnome.shell.extensions.ding show-home false

# Розмір іконок на робочому столі — small
gsettings set org.gnome.shell.extensions.ding icon-size 'small'

###############################################################################
# Розкладки клавіатури
###############################################################################

gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ua'), ('xkb', 'ru')]"

gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space']"

gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift><Super>space']"
