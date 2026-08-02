#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
PURGE_USER_DATA=false
ASSUME_YES=false
REBOOT_AFTER=false

usage() {
  cat <<EOF
Usage:
  sudo ./$SCRIPT_NAME [options]

Options:
  -y, --yes              Do not ask for confirmation
  --purge-user-data      Back up ~/snap and remove the original directory
  --reboot               Reboot the system after completion
  -h, --help             Show this help message
EOF
}

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32mDone:\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWarning:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  printf '\n\033[1;31mThe script stopped at line %s with exit code %s.\033[0m\n' \
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
    *) die "Unknown option: $1" ;;
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

[[ -r /etc/os-release ]] || die "Unable to detect the Linux distribution."
# shellcheck disable=SC1091
source /etc/os-release

[[ "${ID:-}" == "ubuntu" ]] || die "This script is intended for Ubuntu only."
command -v apt-get >/dev/null || die "APT was not found. Ubuntu Core is not supported."

TARGET_USER="${SUDO_USER:-${USER:-root}}"
if [[ "$TARGET_USER" == "root" ]]; then
  TARGET_HOME="/root"
else
  TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
fi
[[ -n "$TARGET_HOME" ]] || die "Unable to determine the user's home directory."

if ! $ASSUME_YES; then
  cat <<EOF

The following actions will be performed:
  • install Flatpak, Flathub, and GNOME Software;
  • install Flatpak versions of Firefox and Thunderbird if their Snap versions are detected;
  • remove all Snap packages and snapd;
  • block snapd from being installed again through APT;
  • remove system Snap data.

User home directory: $TARGET_HOME
EOF

  if $PURGE_USER_DATA; then
    warn "$TARGET_HOME/snap will be archived and then removed."
  else
    warn "$TARGET_HOME/snap will be preserved."
  fi

  read -r -p "Continue? [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 0
fi

export DEBIAN_FRONTEND=noninteractive

log "Installing Flatpak and the graphical software manager"
apt-get update

if ! apt-get install -y flatpak gnome-software gnome-software-plugin-flatpak; then
  warn "Required packages were not found. Enabling the Universe repository."
  apt-get install -y software-properties-common
  add-apt-repository -y universe
  apt-get update
  apt-get install -y flatpak gnome-software gnome-software-plugin-flatpak
fi

log "Adding Flathub"
flatpak remote-add --system --if-not-exists \
  flathub https://dl.flathub.org/repo/flathub.flatpakrepo

snap_installed() {
  command -v snap >/dev/null 2>&1 && snap list "$1" >/dev/null 2>&1
}

install_flatpak_replacement() {
  local snap_name="$1"
  local flatpak_id="$2"

  if snap_installed "$snap_name"; then
    log "Installing a Flatpak replacement for the $snap_name Snap package"
    if flatpak install --system -y flathub "$flatpak_id"; then
      ok "$flatpak_id was installed"
    else
      warn "Unable to install $flatpak_id. The Snap package will still be removed."
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
    log "Removing previously created Snap snapshots"
    while IFS= read -r snapshot_id; do
      snap forget "$snapshot_id" || warn "Unable to remove snapshot $snapshot_id"
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
      printf 'Removing Snap package: %s\n' "$package"
      if snap remove --purge "$package"; then
        progress=true
      fi
    done

    $progress || break
  done

  mapfile -t packages < <(snap list 2>/dev/null | awk 'NR > 1 {print $1}')
  if ((${#packages[@]} > 0)); then
    printf 'Unable to remove Snap packages: %s\n' "${packages[*]}" >&2
    return 1
  fi
}

if command -v snap >/dev/null 2>&1; then
  log "Removing Snap packages"
  remove_snapshots
  remove_all_snaps
else
  warn "Snap is already absent."
fi

log "Disabling and removing snapd"
systemctl disable --now \
  snapd.socket snapd.service snapd.seeded.service \
  snapd.autoimport.service 2>/dev/null || true

apt-get purge -y snapd || true

log "Blocking snapd from being installed again"
cat >/etc/apt/preferences.d/nosnap.pref <<'EOF'
Package: snapd
Pin: version *
Pin-Priority: -1
EOF

log "Removing system Snap directories"
rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd

if $PURGE_USER_DATA && [[ -d "$TARGET_HOME/snap" ]]; then
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup="$TARGET_HOME/snap-backup-$timestamp.tar.gz"

  log "Creating a backup of the user's Snap data"
  tar -C "$TARGET_HOME" -czf "$backup" snap
  chown "$TARGET_USER":"$(id -gn "$TARGET_USER")" "$backup"
  rm -rf "$TARGET_HOME/snap"
  ok "Backup created: $backup"
elif [[ -d "$TARGET_HOME/snap" ]]; then
  warn "User Snap data was preserved in $TARGET_HOME/snap"
fi

log "Verifying the result"
command -v flatpak >/dev/null || die "Flatpak is not installed."
flatpak remotes --system | grep -q '^flathub' || die "Flathub is not configured."

ok "Flatpak and Flathub are configured."
ok "Snap has been removed and blocked."

printf '\nExample commands:\n'
printf '  flatpak search telegram\n'
printf '  flatpak install flathub org.telegram.desktop\n'
printf '  flatpak update\n'

if $REBOOT_AFTER; then
  log "Rebooting the system"
  systemctl reboot
else
  printf '\nReboot the system to complete the setup:\n'
  printf '  sudo reboot\n'
fi

sudo systemctl reboot -i
