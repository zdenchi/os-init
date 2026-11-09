# Термінал Ubuntu у стилі Kali Linux

Інструкція для Ubuntu з GNOME Terminal: встановлення Zsh, дворядкового запрошення Kali, підсвічування синтаксису та автопідказок.

## 1. Встановити Zsh і плагіни

```bash
sudo apt update
sudo apt install -y zsh zsh-autosuggestions zsh-syntax-highlighting curl
```

## 2. Встановити конфігурацію Kali

Зберегти наявну конфігурацію (якщо є):

```bash
[ ! -f ~/.zshrc ] || cp ~/.zshrc ~/.zshrc.backup
```

Завантажити оригінальний `.zshrc` із репозиторію Kali Linux:

```bash
curl -fL \
  https://gitlab.com/kalilinux/packages/kali-defaults/-/raw/kali/master/etc/skel/.zshrc \
  -o ~/.zshrc
```

> Перед використанням завантажених конфігурацій корисно переглянути вміст: `less ~/.zshrc`.

## 3. Зробити Zsh оболонкою за замовчуванням

```bash
chsh -s "$(command -v zsh)"
```

Вийти з облікового запису Ubuntu і увійти знову. Щоб спробувати Zsh без перезапуску сеансу, виконати `zsh`.

## 4. Налаштувати зовнішній вигляд GNOME Terminal

Відкрити **Preferences → Profile** і встановити:

- Фон: `#171421` або чорний.
- Шрифт: моноширинний, наприклад **Fira Code**, розмір 11–12 pt.
- Текст: світло-сірий.
- Курсор: вертикальна риска.

Якщо потрібен Fira Code:

```bash
sudo apt install -y fonts-firacode
```

## 5. Перевірити результат

Відкрити новий термінал і виконати:

```bash
echo "$SHELL"
echo "$ZSH_VERSION"
```

Очікується шлях до `zsh` і номер її версії. Зовнішній вигляд має нагадувати дворядковий prompt Kali:

```text
┌──(user㉿ubuntu)-[~]
└─$ 
```

## Відновлення попередніх налаштувань

```bash
[ ! -f ~/.zshrc.backup ] || cp ~/.zshrc.backup ~/.zshrc
chsh -s /bin/bash
```

Після зміни оболонки знову увійти в систему.

> Примітка: сумісність окремих налаштувань залежить від версії конфігурації Kali. Якщо підсвічування або підказки не запрацювали, перевірте шляхи до встановлених плагінів у `/usr/share/` і відповідні рядки в `~/.zshrc`.
