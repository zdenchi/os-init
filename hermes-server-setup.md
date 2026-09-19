# Configuring the Server for Hermes Agent

## Configurate server

### 1. Update the system

```bash
sudo apt update && sudo apt upgrade -y
```

### 2. Install the necessary packages

```bash
sudo apt install -y \
  curl \
  git \
  ufw \
  fail2ban \
  ca-certificates \
  unzip \
  xz-utils \
  htop \
  rsync
```

### 3. Create a separate user

Replace `my_username` with the desired username.

```bash
sudo adduser my_username
sudo usermod -aG sudo my_username
```

### 4. Copy SSH keys

Execute as `root`:

```bash
sudo rsync -a --chown=my_username:my_username /root/.ssh/ /home/my_username/.ssh/
sudo chmod 700 /home/my_username/.ssh
sudo chmod 600 /home/my_username/.ssh/*
```

### 5. Create an alias for quick login via SSH

```~/.ssh/config
Host hermes_vps
    HostName SERVER_IP
    User my_username
    Port 22
    IdentityFile ~/.ssh/id_ed25519
```

### 6. Prevent SSH login under root and password

Create a config:

```bash
sudo nano /etc/ssh/sshd_config.d/99-hardening.conf
```

Add:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes

X11Forwarding no
PermitEmptyPasswords no

MaxAuthTries 3
LoginGraceTime 30
```

Reload SSH:

```bash
sudo systemctl reload ssh
```

### 7. Configure UFW

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow OpenSSH
sudo ufw enable
```

## Install and configure Hermes Agent

### 1. Install Hermes Agent

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc
```

### 2. Install Hermes gateway

```bash
hermes gateway install
hermes gateway start
```

### 3. Configure Hermes model

```bash
hermes model
```

Select `OpenAI` >> `ChatGPT or Codex Subscription` and follow the instructions.