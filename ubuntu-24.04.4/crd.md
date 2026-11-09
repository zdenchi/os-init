# Chrome Remote Desktop

CRD чіпляється до вже відкритої X-сесії. Спочатку GDM має віддавати X11.

## Увімкнути X11

```bash
sudo sed -i 's/^#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
sudo systemctl reboot -i
```

Після входу в графічний сеанс:

```bash
echo "$XDG_SESSION_TYPE"
```

Має бути `x11`. Далі всі кроки — уже в цьому сеансі.

## Завантаження та встановлення CRD

```bash
wget -O ~/Downloads/chrome-remote-desktop_current_amd64.deb "https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb"
sudo apt install ~/Downloads/chrome-remote-desktop_current_amd64.deb
```

## Налаштування headless

Перейди на [headless setup](https://remotedesktop.google.com/headless) і виконай інструкції.

## Зупинити CRD і зробити резервну копію конфігу

```bash
/opt/google/chrome-remote-desktop/chrome-remote-desktop --stop

sudo cp \
  /opt/google/chrome-remote-desktop/chrome-remote-desktop \
  /opt/google/chrome-remote-desktop/chrome-remote-desktop.backup
```

## Редагувати конфіг

Отримати номер дисплея

```bash
echo "DISPLAY=$DISPLAY"
```

Відредагувати конфіг

```bash
sudo nano /opt/google/chrome-remote-desktop/chrome-remote-desktop
```

Замінити `FIRST_X_DISPLAY_NUMBER` на номер дисплея

```python
FIRST_X_DISPLAY_NUMBER = 1
```

Змінити `get_unused_display_number`

```python
@staticmethod
def get_unused_display_number():
    display = FIRST_X_DISPLAY_NUMBER
    return display
```

Змінити `launch_session`

```python
def launch_session(self, *args, **kwargs):
    logging.info("Using existing X session.")
    self._init_child_env()

    display = self.get_unused_display_number()
    self.child_env["DISPLAY"] = ":%d" % display
```

## Запустити CRD

```bash
/opt/google/chrome-remote-desktop/chrome-remote-desktop --start
```
