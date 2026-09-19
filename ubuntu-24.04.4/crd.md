# Chrome Remote Desktop

## Download and install CRD 

```bash
wget -O ~/Downloads/app.deb "https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb"
sudo apt install ~/Downloads/app.deb
```

## Setup headless

Go to [headless setup](https://remotedesktop.google.com/headless) and follow the instructions.

## Stop CRD and backup the config

```bash
/opt/google/chrome-remote-desktop/chrome-remote-desktop --stop

sudo cp \
  /opt/google/chrome-remote-desktop/chrome-remote-desktop \
  /opt/google/chrome-remote-desktop/chrome-remote-desktop.backup
```

## Edit config file

Get the display number 

```bash
echo "DISPLAY=$DISPLAY"
```

Edit config file

```bash
sudo nano /opt/google/chrome-remote-desktop/chrome-remote-desktop
```

Replace `FIRST_X_DISPLAY_NUMBER` to the display number

```python
FIRST_X_DISPLAY_NUMBER = 1
```

Change `get_unused_display_number` 

```python
@staticmethod
def get_unused_display_number():
    display = FIRST_X_DISPLAY_NUMBER
    return display
```

Change `launch_session`

```python
def launch_session(self, *args, **kwargs):
    logging.info("Using existing X session.")
    self._init_child_env()

    display = self.get_unused_display_number()
    self.child_env["DISPLAY"] = ":%d" % display
```

## Start CRD

```bash
/opt/google/chrome-remote-desktop/chrome-remote-desktop --start
```

## Enable auto start

Create user-service

```bash
mkdir -p ~/.config/systemd/user
nano ~/.config/systemd/user/crd-session.service
```

```ini
[Unit]
Description=Chrome Remote Desktop
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/opt/google/chrome-remote-desktop/chrome-remote-desktop --start
ExecStop=/opt/google/chrome-remote-desktop/chrome-remote-desktop --stop
Environment=DISPLAY=:1

[Install]
WantedBy=graphical-session.target
```

Enable and start the service

```bash
systemctl --user daemon-reload
systemctl --user enable crd-session.service
systemctl --user start crd-session.service
```