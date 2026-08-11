#!/usr/bin/env bash
set -Eeuo pipefail

echo "===== zsh install ====="
sudo apt install zsh -y
chsh -s $(which zsh)

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Auto-completion
git clone https://github.com/zsh-users/zsh-autosuggestions \
~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

git clone https://github.com/zsh-users/zsh-syntax-highlighting \
~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc && source ~/.zshrc

sudo apt install fonts-powerline -y
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
~/.oh-my-zsh/custom/themes/powerlevel10k
sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc && source ~/.zshrc

sudo systemctl reboot -i
