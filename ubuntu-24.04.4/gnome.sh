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
    error "Unable to identify the package manager."
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

  log "Processing ID: ${extension_id}"

  metadata="$(
    curl -fsSL \
      "${BASE_URL}/extension-info/?pk=${extension_id}&shell_version=${shell_version}"
  )" || {
    error "Unable to retrieve information for ID ${extension_id}"
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
    error "Extension ${extension_id} not found or incompatible with GNOME ${shell_version}"
    return 1
  fi

  if [[ "$download_url" != http* ]]; then
    download_url="${BASE_URL}${download_url}"
  fi

  archive="$(mktemp --suffix=.zip)"

  curl -fsSL "$download_url" -o "$archive" || {
    rm -f "$archive"
    error "Ошибка скачивания ${uuid}"
    return 1
  }

  if gnome-extensions list | grep -Fxq "$uuid"; then
    log "${uuid} already installed; updating..."
    gnome-extensions install --force "$archive"
  else
    gnome-extensions install "$archive"
  fi

  rm -f "$archive"

  gnome-extensions enable "$uuid" 2>/dev/null || true

  success "${uuid} installed and turned on"
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
    error "Не удалось определить версию GNOME Shell"
    exit 1
  fi

  log "GNOME Shell: ${shell_version}"

  for extension_id in "${extension_ids[@]}"; do
    if [[ "$extension_id" =~ ^[0-9]+$ ]]; then
      install_extension "$extension_id" "$shell_version" || true
    else
      error "Incorrect ID: ${extension_id}"
    fi
  done

  echo
  log "Log out and log back in if the extensions haven't appeared."
}

main "$@"

echo "===== Configurate GNOME UI ====="
# Minimize the window by double-clicking the icon in the dock
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'minimize-or-previews'
# Fractional scaling for high DPI
gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

echo log "GNOME ext successfully configurated."

###############################################################################
# Change system settings
###############################################################################

# Show battery percentage
gsettings set org.gnome.desktop.interface show-battery-percentage true

# Disable automatic screen off — Never
gsettings set org.gnome.desktop.session idle-delay 0

# Performance mode
powerprofilesctl set performance

# Hot Corner
gsettings set org.gnome.desktop.interface enable-hot-corners true

# Active Screen Edges
gsettings set org.gnome.mutter edge-tiling true

# Workspaces on all monitors
gsettings set org.gnome.mutter workspaces-only-on-primary false

# Dock icon size — 36 px
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 36

# Show Dock 
gsettings set org.gnome.shell.extensions.dash-to-dock multi-monitor true

# Hide home folder on desktop
gsettings set org.gnome.shell.extensions.ding show-home false

# Desktop icon size — small
gsettings set org.gnome.shell.extensions.ding icon-size 'small'

###############################################################################
# Keyboard layouts
###############################################################################

gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ua'), ('xkb', 'ru')]"

gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space']"

gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift><Super>space']"
