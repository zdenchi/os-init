# Термінал Ubuntu у стилі Manjaro GNOME

У Manjaro GNOME використовується **Zsh** із конфігурацією `manjaro-zsh-config`, темою **Powerlevel10k** і плагінами автопідказок. Нижче — безпечний спосіб отримати аналогічний вигляд в Ubuntu без встановлення пакетів Arch Linux.

## 1. Встановити залежності

```bash
sudo apt update
sudo apt install -y zsh git curl zsh-autosuggestions zsh-syntax-highlighting fonts-powerline
```

## 2. Зробити резервну копію конфігурації

```bash
[ ! -f ~/.zshrc ] || cp -a ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d-%H%M%S)
```

> Якщо раніше був налаштований термінал у стилі Kali, нові налаштування замінять його в `~/.zshrc`. Копія збережеться.

## 3. Встановити Powerlevel10k

```bash
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.local/share/powerlevel10k
```

Якщо директорія вже існує, замість клонування оновити її:

```bash
git -C ~/.local/share/powerlevel10k pull --ff-only
```

## 4. Створити конфігурацію Zsh

```bash
cat > ~/.zshrc <<'EOF_ZSH'
# Історія та автодоповнення
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY HIST_IGNORE_ALL_DUPS AUTO_CD CORRECT
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Тема у стилі Manjaro GNOME
source "$HOME/.local/share/powerlevel10k/powerlevel10k.zsh-theme"
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Автопідказки та підсвічування синтаксису
[[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
EOF_ZSH
```

## 5. Призначити Zsh оболонкою за замовчуванням

```bash
chsh -s "$(command -v zsh)"
```

Потім вийти з сеансу Ubuntu і увійти знову. Для негайної перевірки можна виконати `zsh`.

## 6. Налаштувати тему

Запустити майстер налаштування:

```bash
p10k configure
```

Якщо команда недоступна, виконати її всередині Zsh: `zsh -ic 'p10k configure'`.

Рекомендовані варіанти для зовнішнього вигляду Manjaro:

- **Unicode** і **Nerd Font** (за наявності відповідного шрифту).
- **Rainbow** або **Classic**, обрати за бажаним виглядом.
- **Two lines** — якщо потрібен дворядковий prompt.
- **Icons** — увімкнути.
- **Transient prompt** — за бажанням, щоб раніше виконані команди виглядали компактніше.

### Шрифт для іконок

Встановити **MesloLGS NF** (Nerd Font) з офіційного репозиторію Powerlevel10k: https://github.com/romkatv/powerlevel10k#fonts. Потім відкрити налаштування профілю GNOME Terminal (або Ptyxis, якщо використовується він), вимкнути системний шрифт і обрати **MesloLGS NF**. Без Nerd Font частина значків може відображатися квадратиками.

## 7. Перевірити

```bash
printf 'Оболонка: %s\n' "$SHELL"
zsh --version
git --version
```

Відкрийте новий термінал. Мають працювати кольорове запрошення Powerlevel10k, підказки з історії та підсвічування введених команд.

## Відновлення попереднього вигляду

Подивитися збережені копії:

```bash
ls -lt ~/.zshrc.backup.*
```

Скопіювати потрібну резервну копію замість поточної конфігурації:

```bash
cp ~/.zshrc.backup.РРРРММДД-ГГХХСС ~/.zshrc
exec zsh
```

Повернути Bash як оболонку за замовчуванням:

```bash
chsh -s /bin/bash
```

Після зміни оболонки слід вийти з сеансу і увійти знову.

## Джерела

- [Офіційний пакет manjaro-zsh-config](https://gitlab.manjaro.org/packages/extra/manjaro-zsh-config)
- [Powerlevel10k — встановлення та налаштування](https://github.com/romkatv/powerlevel10k)
- [Обговорення стандартного термінала Manjaro GNOME](https://forum.manjaro.org/t/terminal-look-as-in-live-boot-usb/174715)

> Результат візуально близький до Manjaro GNOME, але це не побайтова копія оригінальної теми `manjaro-zsh-config`: зовнішній вигляд залежить від обраних параметрів майстра та встановленого шрифту.
