#!/usr/bin/env bash
# check-env.sh — проверочный скрипт окружения курса, неделя 1.
# Запуск:  bash check-env.sh
# Совместим с bash 3.2 (macOS) и выше. Ничего не устанавливает, только проверяет.

PASS=0
FAIL=0
WARN=0

# Цвета — только если stdout это терминал
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_WARN=$'\033[33m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_ERR=""; C_WARN=""; C_OFF=""
fi

ok()   { printf '%s✓%s %s\n' "$C_OK" "$C_OFF" "$1"; PASS=$((PASS+1)); }
err()  { printf '%s✗%s %s\n    → %s\n' "$C_ERR" "$C_OFF" "$1" "$2"; FAIL=$((FAIL+1)); }
warn() { printf '%s!%s %s\n    → %s\n' "$C_WARN" "$C_OFF" "$1" "$2"; WARN=$((WARN+1)); }

have() { command -v "$1" >/dev/null 2>&1; }

echo "=== Проверка окружения курса ==="
echo

# --- Операционная система ---------------------------------------------------
OS=$(uname -s)
case "$OS" in
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then
      ok "ОС: Linux (WSL2) — $(uname -r)"
      case "$PWD" in
        /mnt/*) warn "Вы находитесь в /mnt/... (файловая система Windows)" \
                     "Работайте в домашнем каталоге Linux: cd ~" ;;
      esac
    else
      ok "ОС: Linux — $(uname -r)"
    fi
    ;;
  Darwin)
    ok "ОС: macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
    ;;
  *)
    err "ОС: $OS — не распознана" "Нужен Linux, WSL2 или macOS (см. env-guide.md)"
    ;;
esac

# --- Shell ------------------------------------------------------------------
if [ -n "$BASH_VERSION" ]; then
  ok "bash: $BASH_VERSION"
else
  warn "Скрипт запущен не в bash" "Запускайте: bash check-env.sh"
fi

# --- Обязательные утилиты ---------------------------------------------------
REQUIRED="git python3 make tar grep sed awk curl ssh man"
for cmd in $REQUIRED; do
  if have "$cmd"; then
    ok "$cmd: $(command -v "$cmd")"
  else
    err "$cmd не найден" "Установите (см. env-guide.md для вашей ОС)"
  fi
done

# --- Компилятор C++ ---------------------------------------------------------
if have g++; then
  ok "g++: $(g++ --version | head -1)"
elif have clang++; then
  ok "clang++: $(clang++ --version | head -1)"
else
  err "Компилятор C++ не найден" "Linux/WSL: sudo apt install build-essential; macOS: xcode-select --install"
fi

# Компилятор реально работает?
if have g++ || have cc; then
  TMPD=$(mktemp -d 2>/dev/null || echo /tmp/checkenv.$$)
  mkdir -p "$TMPD"
  cat > "$TMPD/t.cpp" <<'EOF'
#include <iostream>
int main() { std::cout << "ok\n"; }
EOF
  CXX=g++; have g++ || CXX=clang++
  if "$CXX" "$TMPD/t.cpp" -o "$TMPD/t" 2>"$TMPD/cerr" && [ "$("$TMPD/t")" = "ok" ]; then
    ok "Компиляция и запуск hello-программы"
  else
    err "Компилятор есть, но собрать программу не удалось" "Покажите преподавателю: $(head -1 "$TMPD/cerr" 2>/dev/null)"
  fi
  rm -rf "$TMPD"
fi

# --- Python версия ----------------------------------------------------------
if have python3; then
  PYV=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)
  PYMAJ=${PYV%%.*}; PYMIN=${PYV##*.}
  if [ "${PYMAJ:-0}" -ge 3 ] && [ "${PYMIN:-0}" -ge 10 ]; then
    ok "python3 версии $PYV (нужно ≥ 3.10)"
  else
    warn "python3 версии $PYV" "Желательно ≥ 3.10; обновим при необходимости на неделе 2"
  fi
fi

# --- Желательные утилиты ----------------------------------------------------
for cmd in tmux tree wget gdb; do
  if have "$cmd"; then
    ok "$cmd (опционально)"
  else
    warn "$cmd не найден (опционально)" "Пригодится позже: установите при случае"
  fi
done

# --- Локаль и UTF-8 ---------------------------------------------------------
if locale 2>/dev/null | grep -qi 'utf-8\|utf8'; then
  ok "Локаль UTF-8"
else
  warn "Локаль не UTF-8" "Возможны кракозябры; покажите преподавателю вывод команды locale"
fi

# --- Домашний каталог -------------------------------------------------------
if [ -w "$HOME" ]; then
  ok "Домашний каталог доступен на запись: $HOME"
else
  err "Домашний каталог недоступен на запись: $HOME" "Что-то сильно не так — к преподавателю"
fi

# --- Сеть -------------------------------------------------------------------
if curl -fsS --max-time 5 -o /dev/null https://github.com 2>/dev/null; then
  ok "Сеть: github.com доступен"
else
  warn "Не удалось достучаться до github.com за 5 секунд" "Проверьте интернет; если вы за прокси — скажите преподавателю"
fi

# --- Итог -------------------------------------------------------------------
echo
echo "=== Итог: $PASS ок, $WARN предупреждений, $FAIL ошибок ==="
if [ "$FAIL" -eq 0 ]; then
  echo "Окружение готово. Предупреждения (если есть) разберём на занятии."
else
  echo "Есть ошибки — попробуйте починить по env-guide.md или принесите этот вывод на занятие."
fi
exit "$FAIL"
