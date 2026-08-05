#!/usr/bin/env bash

set -Eeuo pipefail
# Один раз запрашиваем пароль администратора
sudo -v

# Поддерживаем sudo-сессию до завершения скрипта
while true; do
  sudo -n true
  sleep 30
  kill -0 "$$" || exit
done 2>/dev/null &

SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT


log() {
  printf '\n\033[1;34m==> %s\033[0m\n' "$1"
}

warn() {
  printf '\033[1;33mWARNING: %s\033[0m\n' "$1"
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Этот скрипт предназначен только для macOS."
  exit 1
fi

if [[ "$(uname -m)" != "x86_64" ]]; then
  warn "Скрипт рассчитан на Intel Mac. Обнаружено: $(uname -m)"
fi

log "Проверка прав администратора"
sudo -v

while true; do
  sudo -n true
  sleep 50
  kill -0 "$$" || exit
done 2>/dev/null &
SUDO_PID=$!
trap 'kill "$SUDO_PID" 2>/dev/null || true' EXIT

log "Проверка MDM"
profiles status -type enrollment || true

log "Установка Xcode Command Line Tools"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install
  echo "Заверши установку Command Line Tools в открывшемся окне."
  read -rp "После завершения нажми Enter..."

  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Command Line Tools не установлены."
    exit 1
  fi
fi

log "Установка Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"

  if ! grep -q '/usr/local/bin/brew shellenv' "$HOME/.zprofile" 2>/dev/null; then
    echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
  fi
fi

log "Обновление Homebrew"
brew update

log "Установка консольных программ"
FORMULAS=(
  git
  git-lfs
  fnm
  bun
  pnpm
  tmux
  htop
  wget
  curl
  jq
  tree
  rsync
  ripgrep
  fd
  bat
  btop
  ffmpeg
  openssl@3
)

for package in "${FORMULAS[@]}"; do
  if brew list --formula "$package" >/dev/null 2>&1; then
    echo "$package уже установлен"
  else
    brew install "$package"
  fi
done

log "Настройка Node.js через fnm"
if ! grep -q 'fnm env' "$HOME/.zshrc" 2>/dev/null; then
  cat >> "$HOME/.zshrc" <<'EOF'

# Node.js version manager
eval "$(fnm env --use-on-cd --shell zsh)"
EOF
fi

eval "$(fnm env --shell bash)"
fnm install --lts
fnm default lts-latest
fnm use lts-latest

corepack enable || true
npm install --global npm@latest

log "Установка Playwright и Chromium"
if ! command -v playwright >/dev/null 2>&1; then
  npm install --global playwright
fi

playwright install chromium

log "Установка приложений"
CASKS=(
  google-chrome
  visual-studio-code
  docker
  rustdesk
  enpass
  telegram
  insomnia
  cursor
  sublime-text
  mullvad-vpn
  vlc
)

for app in "${CASKS[@]}"; do
  if brew list --cask "$app" >/dev/null 2>&1; then
    echo "$app уже установлен"
  else
    brew install --cask "$app" || warn "Не удалось установить $app"
  fi
done

log "Настройка Git"
read -rp "Git user.name: " GIT_NAME
read -rp "Git user.email: " GIT_EMAIL

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.autocrlf input
git config --global fetch.prune true
git config --global credential.helper osxkeychain

log "Создание SSH-ключа"
SSH_KEY="$HOME/.ssh/id_ed25519"

mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ ! -f "$SSH_KEY" ]]; then
  read -rp "Email для SSH-ключа GitHub или Enter, чтобы пропустить: " SSH_EMAIL

  if [[ -n "$SSH_EMAIL" ]]; then
    ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_KEY" -N ""
    eval "$(ssh-agent -s)"
    ssh-add --apple-use-keychain "$SSH_KEY" 2>/dev/null || ssh-add "$SSH_KEY"

    if [[ ! -f "$HOME/.ssh/config" ]] || ! grep -q '^Host github.com$' "$HOME/.ssh/config"; then
      cat >> "$HOME/.ssh/config" <<'EOF'

Host github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
EOF
    fi

    chmod 600 "$HOME/.ssh/config"
  fi
fi

log "Создание каталогов"
mkdir -p \
  "$HOME/Projects" \
  "$HOME/Servers" \
  "$HOME/Backups" \
  "$HOME/Logs"

log "Настройка Finder"
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
killall Finder 2>/dev/null || true

log "Настройка tmux"
cat >> ~/.tmux.conf <<'EOF'

# Управление мышью
set -g mouse on

# Большая история прокрутки
set -g history-limit 100000
EOF

tmux source-file ~/.tmux.conf

log "Проверка диска"
diskutil info disk0 | grep -E \
  "Device / Media Name|Disk Size|Solid State|SMART Status" || true

log "Версии"
echo "macOS:      $(sw_vers -productVersion)"
echo "Homebrew:   $(brew --version | head -n1)"
echo "Git:        $(git --version)"
echo "Node.js:    $(node --version)"
echo "npm:        $(npm --version)"
echo "Bun:        $(bun --version)"
echo "pnpm:       $(pnpm --version)"
echo "Playwright: $(playwright --version)"

brew cleanup

echo
echo "Настройка завершена."
echo "Перезапусти Terminal или выполни:"
echo "source ~/.zprofile && source ~/.zshrc"

if [[ -f "$SSH_KEY.pub" ]]; then
  echo
  echo "Публичный SSH-ключ:"
  cat "$SSH_KEY.pub"
fi

echo
echo "Docker, RustDesk и Mullvad VPN нужно один раз открыть вручную"
echo "и подтвердить системные разрешения macOS."
