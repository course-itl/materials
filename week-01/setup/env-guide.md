# Подготовка окружения (сделать ДО первого занятия)

На курсе мы работаем в Unix-окружении. Ваша задача до понедельника — получить на своём ноутбуке работающий Linux-терминал и базовый набор инструментов, а затем убедиться, что проверочный скрипт `check-env.sh` показывает всё зелёным. На занятии будет время на добивку, но чем больше сделаете дома, тем быстрее перейдёте к интересному.

Выберите свой раздел: **Windows → WSL2**, **Linux**, **macOS**.

---

## Windows: WSL2 + Ubuntu

WSL2 — это полноценный Linux внутри Windows. Не «эмуляция команд», а настоящее ядро в лёгкой виртуалке. Именно так на Windows работает большинство разработчиков.

1. Откройте **PowerShell от администратора** и выполните:
   ```powershell
   wsl --install -d Ubuntu-24.04
   ```
2. Перезагрузитесь. При первом запуске Ubuntu придумайте имя пользователя и пароль (пароль при вводе не отображается — это нормально).
3. Обновите пакеты и поставьте нужное:
   ```bash
   sudo apt update && sudo apt upgrade -y
   sudo apt install -y build-essential gdb git python3 python3-pip tmux curl wget tree man-db manpages-dev unzip
   ```
4. Терминал: используйте **Windows Terminal** (есть в Microsoft Store), профиль Ubuntu.

Грабли:

- `wsl --install` требует Windows 10 2004+ или Windows 11. Если команда не найдена — обновите Windows.
- Если после перезагрузки ошибка про виртуализацию — включите в BIOS/UEFI пункт VT-x / SVM.
- **Работайте в Linux-файловой системе** (`/home/вы/...`), а не в `/mnt/c/...` — там всё в разы медленнее и ломаются права файлов.
- Файлы из Windows видны в `/mnt/c/`, Linux-файлы из Windows — по адресу `\\wsl$\Ubuntu-24.04\` в проводнике. Но лучше просто жить в терминале.

## Linux (нативный)

Вы уже дома. Убедитесь, что стоит базовый набор:

```bash
# Ubuntu/Debian:
sudo apt update
sudo apt install -y build-essential gdb git python3 python3-pip tmux curl wget tree man-db unzip

# Fedora:
sudo dnf install -y gcc gcc-c++ make gdb git python3 tmux curl wget tree man-db unzip

# Arch:
sudo pacman -S --needed base-devel gdb git python tmux curl wget tree man-db unzip
```

## macOS

macOS — это Unix (BSD-ветка), почти всё работает из коробки. Но утилиты местами отличаются от GNU-версий, которые стоят на сервере курса — об этом будем говорить по ходу.

1. Инструменты командной строки:
   ```bash
   xcode-select --install
   ```
2. Пакетный менеджер [Homebrew](https://brew.sh) (если ещё нет):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
3. Доустановите:
   ```bash
   brew install git python3 tmux tree wget coreutils gnu-tar
   ```

Грабли:

- Системный `bash` на macOS — древней версии 3.2 (лицензионные причины). Для интерактивной работы это не мешает; на неделе 2, когда начнём писать скрипты, поставим свежий (`brew install bash`).
- `sed`, `ls`, `stat` и другие — BSD-варианты с другими флагами. Если пример с занятия не работает — это первое, что стоит заподозрить.

---

## Проверка (все ОС)

Скачайте и запустите проверочный скрипт курса:

```bash
curl -fsSL https://raw.githubusercontent.com/course-itl/materials/main/week-01/setup/check-env.sh -o check-env.sh
bash check-env.sh
```

Цель — ноль ошибок (`✗`). Предупреждения (`!`) допустимы, разберём на занятии. Если что-то не получилось починить самостоятельно — не страшно, приходите как есть, уроки 2–3 первой недели включают доводку окружения. Но принесите текст ошибки.

## Что НЕ нужно

- Ставить IDE «для курса» — первые недели живём в терминале и простом редакторе.
- Виртуалки VirtualBox/VMware на Windows — только WSL2.
- Платить за что-либо. Всё в курсе — бесплатное.
