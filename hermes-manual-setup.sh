apt update && apt upgrade -y

apt install -y \
  curl \
  git \
  ufw \
  fail2ban \
  ca-certificates \
  unzip \
  xz-utils \
  htop

# Create a separate user for Hermes
adduser hermes
usermod -aG sudo hermes

# Copy SSH keys to the new user's home directory
rsync --archive --chown=hermes:hermes ~/.ssh /home/hermes

# Logout and login as hermes
# Then create separete config
sudo nano /etc/ssh/sshd_config.d/99-hardening.conf

# PermitRootLogin no
# PasswordAuthentication no
# KbdInteractiveAuthentication no
# PubkeyAuthentication yes

# X11Forwarding no
# PermitEmptyPasswords no

# MaxAuthTries 3
# LoginGraceTime 30

sudo systemctl reload ssh

# Configure firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw enable

# Install Hermes
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc