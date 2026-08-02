#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== Installing Software ====="

sudo mkdir -p /etc/apt/keyrings

###############################################################################
# Google Chrome
###############################################################################

echo "==> Google Chrome"

curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
| sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
| sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null

###############################################################################
# VS Code
###############################################################################

echo "==> VS Code"

wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
| sudo gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" \
| sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

###############################################################################
# Cursor
###############################################################################

echo "==> Cursor"

curl -fsSL https://downloads.cursor.com/keys/anysphere.asc \
| sudo gpg --dearmor -o /etc/apt/keyrings/cursor.gpg

echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/cursor.gpg] https://downloads.cursor.com/aptrepo stable main" \
| sudo tee /etc/apt/sources.list.d/cursor.list >/dev/null

###############################################################################
# Sublime Text
###############################################################################

echo "==> Sublime Text"

wget -qO- https://download.sublimetext.com/sublimehq-pub.gpg \
| sudo gpg --dearmor -o /etc/apt/keyrings/sublimehq.gpg

echo "deb [signed-by=/etc/apt/keyrings/sublimehq.gpg] https://download.sublimetext.com/ apt/stable/" \
| sudo tee /etc/apt/sources.list.d/sublime-text.list >/dev/null

###############################################################################
# Enpass
###############################################################################

echo "==> Enpass"

wget -qO- https://apt.enpass.io/keys/enpass-linux.key \
| sudo gpg --dearmor -o /etc/apt/keyrings/enpass.gpg

echo "deb [signed-by=/etc/apt/keyrings/enpass.gpg] https://apt.enpass.io/ stable main" \
| sudo tee /etc/apt/sources.list.d/enpass.list >/dev/null

###############################################################################
# Mullvad VPN
###############################################################################

echo "==> Mullvad VPN"

curl -fsSL https://repository.mullvad.net/deb/mullvad-keyring.asc \
| sudo gpg --dearmor -o /etc/apt/keyrings/mullvad.gpg

echo "deb [signed-by=/etc/apt/keyrings/mullvad.gpg] https://repository.mullvad.net/deb/stable bookworm main" \
| sudo tee /etc/apt/sources.list.d/mullvad.list >/dev/null

###############################################################################
# RustDesk
###############################################################################

echo "==> RustDesk"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' RETURN

cd "$TMPDIR"

URL=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest \
    | jq -r '.assets[] | select(.name | test("x86_64\\.deb$")) | .browser_download_url')

if [[ -z "$URL" || "$URL" == "null" ]]; then
    echo "Не удалось найти пакет RustDesk."
    exit 1
fi

wget "$URL" -O rustdesk.deb

sudo apt install -y ./rustdesk.deb

###############################################################################
# Antigravity IDE
###############################################################################

echo "==> Antigravity IDE"

curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg \
| sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg

echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" \
| sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null

###############################################################################
# Обновление
###############################################################################

echo "==> apt update"
sudo apt update

###############################################################################
# Установка
###############################################################################

echo "==> Установка программ"

sudo apt install -y \
    google-chrome-stable \
    code \
    cursor \
    sublime-text \
    enpass \
    vlc \
    mullvad-vpn

flatpak install -y flathub org.chromium.Chromium


###############################################################################
# Telegram
###############################################################################

echo "==> Telegram"

if apt-cache show telegram-desktop >/dev/null 2>&1; then
    sudo apt install -y telegram-desktop
else
    echo "Пакет отсутствует в репозиториях."
    echo "Установка через Flatpak."

    sudo apt install -y flatpak

    flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo

    flatpak install -y flathub org.telegram.desktop
fi

###############################################################################
# Insomnia
###############################################################################

echo "==> Insomnia"

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cd "$TMPDIR"

URL=$(curl -fsSL https://api.github.com/repos/Kong/insomnia/releases/latest \
    | jq -r '.assets[]
        | select(.name | test("^Insomnia\\.Core-.*\\.deb$"))
        | .browser_download_url' \
    | head -n1)

if [[ -z "$URL" || "$URL" == "null" ]]; then
    echo "Не удалось найти актуальный .deb пакет Insomnia."
    exit 1
fi

wget "$URL" -O insomnia.deb

sudo apt install -y ./insomnia.deb

###############################################################################
# Terminator
###############################################################################

echo "==> Installing Terminator..."

sudo apt update
sudo apt install -y terminator fonts-firacode

echo "==> Installing JetBrainsMono Nerd Font..."
mkdir -p ~/.local/share/fonts
TMP_DIR=$(mktemp -d)

curl -L \
  https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip \
  -o "$TMP_DIR/JetBrainsMono.zip"

unzip -oq "$TMP_DIR/JetBrainsMono.zip" -d "$TMP_DIR/fonts"
find "$TMP_DIR/fonts" -name "*.ttf" -exec cp {} ~/.local/share/fonts/ \;

fc-cache -fv >/dev/null
rm -rf "$TMP_DIR"

echo "==> Configuring Terminator..."
mkdir -p ~/.config/terminator

curl https://raw.githubusercontent.com/dracula/terminator/master/terminator/dracula.py \
-o ~/.config/terminator/dracula.py

cat > ~/.config/terminator/config <<'EOF'
[global_config]
  borderless = False
  focus = click
  enabled_plugins = LaunchpadBugURLHandler, LaunchpadCodeURLHandler, APTURLHandler

[keybindings]

[profiles]
  [[default]]
    background_color = "#282a36"
    foreground_color = "#f8f8f2"
    cursor_color = "#f8f8f2"
    palette = "#21222c:#ff5555:#50fa7b:#f1fa8c:#bd93f9:#ff79c6:#8be9fd:#f8f8f2:#6272a4:#ff6e6e:#69ff94:#ffffa5:#d6acff:#ff92df:#a4ffff:#ffffff"
    use_system_font = False
    font = JetBrainsMono Nerd Font Mono 11
    cursor_shape = ibeam
    copy_on_selection = True
    login_shell = True
    show_titlebar = False
    scrollback_infinite = True
    scrollbar_position = right

[layouts]
  [[default]]
    [[[window0]]]
      type = Window
      parent = ""
    [[[child1]]]
      type = Terminal
      parent = window0

[plugins]
EOF

###############################################################################
# Android Studio
###############################################################################

# echo "==> Android Studio"

# sudo apt install -y \
#     openjdk-21-jdk \
#     adb \
#     fastboot \
#     qemu-system-x86 \
#     qemu-utils \
#     libvirt-daemon-system \
#     libvirt-clients \
#     virt-manager \
#     bridge-utils \
#     dnsmasq-base

# cd ~
# cd /tmp

# URL=$(curl -fsSL https://developer.android.com/studio \
#     | grep -oP 'https://redirector\.gvt1\.com/edgedl/android/studio/ide-zips/[^"]+linux\.tar\.gz' \
#     | head -n1)

# wget -O android-studio.tar.gz "$URL"

# sudo rm -rf /opt/android-studio
# sudo tar -xzf android-studio.tar.gz -C /opt

# sudo ln -sf /opt/android-studio/bin/studio /usr/local/bin/android-studio

# cat <<EOF | sudo tee /usr/share/applications/android-studio.desktop >/dev/null
# [Desktop Entry]
# Version=1.0
# Type=Application
# Name=Android Studio
# Exec=/opt/android-studio/bin/studio %f
# Icon=/opt/android-studio/bin/studio.png
# Terminal=false
# Categories=Development;IDE;
# StartupNotify=true
# EOF

###############################################################################
# tmux
###############################################################################

echo "==> tmux"

sudo apt install -y tmux

cat > ~/.tmux.conf <<'EOF'
# Использовать мышь
set -g mouse on

# История терминала
set -g history-limit 100000

# Индексация окон и панелей с 1
set -g base-index 1
setw -g pane-base-index 1

# Автоматическая перенумерация окон
set -g renumber-windows on

# Быстрое разделение окон
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Перезагрузка конфига
bind r source-file ~/.tmux.conf \; display-message "tmux.conf reloaded"
EOF

# Если tmux уже запущен — перечитать конфигурацию
if command -v tmux >/dev/null && tmux info >/dev/null 2>&1; then
    tmux source-file ~/.tmux.conf
fi

###############################################################################
echo
echo "======================================="
echo "Установка завершена."
echo "======================================="
echo
###############################################################################



