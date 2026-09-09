#!/usr/bin/env bash
# check.sh — автопроверка однострочников недели 1. Запускается НА СЕРВЕРЕ курса.
# Использование:
#   bash check.sh [каталог-с-решениями]     # по умолчанию ./solutions
#   bash check.sh --keep [КАТАЛОГ]          # + оставить данные, на которых шла проверка
#
# Как работает: генерирует каноническую версию ваших данных (сид = ваш логин),
# прогоняет каждое решение и сравнивает хеш вывода с эталонным. Эталоны
# посчитаны заранее преподавательским скриптом и лежат в ANSWERS_DIR.

set -u

SOLDIR=""
KEEP=""
while [ $# -gt 0 ]; do
  case "$1" in
    --keep)
      KEEP="./check-data"
      case "${2:-}" in -*|"") ;; *) KEEP="$2"; shift ;; esac
      shift ;;
    --keep=*) KEEP="${1#--keep=}"; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    -*) echo "Неизвестный аргумент: $1" >&2; exit 2 ;;
    *) [ -n "$SOLDIR" ] || SOLDIR="$1"; shift ;;
  esac
done
SOLDIR="${SOLDIR:-./solutions}"
ANSDIR="${ANSWERS_DIR:-/opt/course/week-01/answers/$USER}"
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

if [ ! -d "$SOLDIR" ]; then
  echo "Каталог с решениями не найден: $SOLDIR" >&2
  echo "Ожидается structure: solutions/task01.sh ... solutions/task08.sh" >&2
  exit 2
fi
SOLDIR=$(cd "$SOLDIR" && pwd)

if [ ! -d "$ANSDIR" ]; then
  echo "Эталонные ответы для пользователя $USER не найдены ($ANSDIR)." >&2
  echo "Скажите преподавателю — он запустит gen-answers.sh для вас." >&2
  exit 2
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Генератор берём рядом с собой, а если рядом его нет — из установленных материалов курса.
# Это важно: запущенная копия check.sh без make-logs.sh рядом раньше молча сравнивала
# ваши решения с пустыми данными и показывала ✗ по всем задачам.
INSTALLED=/opt/course/materials/week-01/pipes
MAKELOGS="$SCRIPT_DIR/make-logs.sh"
[ -f "$MAKELOGS" ] || MAKELOGS="$INSTALLED/make-logs.sh"
if [ ! -f "$MAKELOGS" ]; then
  echo "Не найден make-logs.sh (ни рядом с check.sh, ни в $INSTALLED)." >&2
  echo "На сервере курса запускайте установленную команду: check-pipes" >&2
  exit 2
fi
if [ "$SCRIPT_DIR" != "$INSTALLED" ] && [ -d "$INSTALLED" ]; then
  echo "· Вы запустили свою копию check.sh. На сервере есть команда check-pipes — она всегда свежая."
fi

echo "Генерирую канонические данные (сид: $USER)..."
bash "$MAKELOGS" --seed "$USER" --out "$TMP" >/dev/null
CANON_LINES=$(wc -l < "$TMP/access.log" 2>/dev/null | tr -d ' ')
CANON_SHA=$(sha256sum < "$TMP/access.log" 2>/dev/null | cut -d' ' -f1)

# Эталоны посчитаны на полном логе (100 000 строк). Если данные получились другие —
# сравнивать бессмысленно: все задачи покажут «вывод отличается», и виновата будет
# не работа ученика. Лучше остановиться и сказать об этом прямо.
EXPECT_LINES=100000
if [ ! -s "$TMP/access.log" ] || [ ! -d "$TMP/code" ]; then
  echo "Не удалось сгенерировать данные (нет access.log или code/). Скажите преподавателю." >&2
  exit 2
fi
if [ "$CANON_LINES" != "$EXPECT_LINES" ]; then
  echo "Данные сгенерированы не полностью: $CANON_LINES строк вместо $EXPECT_LINES." >&2
  echo "Эталонные ответы посчитаны на полном логе, поэтому проверять смысла нет." >&2
  echo "Так бывает, если запускать не установленную команду check-pipes, а свою копию check.sh" >&2
  echo "рядом с изменённым make-logs.sh (например, с --lines). Скажите преподавателю." >&2
  exit 2
fi
echo "Данные: $CANON_LINES строк, отпечаток ${CANON_SHA:0:12}"

# Проверка идёт на данных во временном каталоге, а смотреть глазами нужно на тех же
# самых. По умолчанию временный каталог удаляется; --keep оставляет копию.
if [ -n "$KEEP" ]; then
  mkdir -p "$KEEP" && cp -r "$TMP/access.log" "$TMP/code" "$KEEP"/ 2>/dev/null
  KEEP_ABS=$(cd "$KEEP" && pwd)
  echo "  копия данных: $KEEP_ABS (access.log и code/ — ровно те, на которых шла проверка)"
fi

# Частая путаница: рядом лежит свой access.log (сгенерированный с --lines или принесённый
# с ноутбука), на нём руками получаются одни числа, а проверка показывает другие.
# Проверка свой файл никогда не использует — предупреждаем, если он отличается.
for f in ./access.log "$SOLDIR/../access.log"; do
  [ -f "$f" ] || continue
  if [ "$(sha256sum < "$f" | cut -d' ' -f1)" != "$CANON_SHA" ]; then
    echo "· Внимание: $f ($(wc -l < "$f" | tr -d ' ') строк) отличается от канонических данных ($CANON_LINES строк)."
    echo "  Проверка его не использует, а ручные прогоны на нём дадут другие числа. Чтобы совпадало —"
    echo "  пересоздайте его без --lines: cd $(dirname "$f") && make-logs"
  fi
  break
done

CORE_OK=0
BONUS_OK=0
echo
for NN in 01 02 03 04 05 06 07 08; do
  SOL="$SOLDIR/task$NN.sh"
  ANS="$ANSDIR/task$NN.sha256"
  KIND="core"; [ "$NN" = "07" ] || [ "$NN" = "08" ] && KIND="доп."

  if [ ! -f "$SOL" ]; then
    printf 'task%s  —  файл не найден (%s)\n' "$NN" "$KIND"
    continue
  fi
  if [ ! -f "$ANS" ]; then
    printf 'task%s  ?  нет эталона — скажите преподавателю\n' "$NN"
    continue
  fi

  # Файл из Windows-редактора: BOM в начале и/или переносы строк CRLF. Bash видит их
  # как невидимые символы («﻿wc: command not found», «access.log\r: No such file»).
  # Такой файл проверяем в очищенной копии, но зачёт не ставим — файл надо починить.
  FMT=""
  [ "$(head -c 3 "$SOL" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ] && FMT="BOM"
  grep -q $'\r' "$SOL" && FMT="${FMT:+$FMT+}CRLF"
  RUN="$SOL"
  if [ -n "$FMT" ]; then
    { if [ "${FMT#BOM}" != "$FMT" ]; then tail -c +4 "$SOL"; else cat "$SOL"; fi; } | tr -d '\r' > "$TMP/sol.$NN.sh"
    RUN="$TMP/sol.$NN.sh"
  fi

  ( cd "$TMP" && timeout 30 bash "$RUN" ) > "$TMP/out.$NN" 2> "$TMP/err.$NN"
  RC=$?
  if [ $RC -eq 124 ]; then
    printf 'task%s  ✗  превышено время (30 с) — вечный цикл или чтение stdin?\n' "$NN"
    continue
  fi
  if [ $RC -ne 0 ] && [ ! -s "$TMP/out.$NN" ]; then
    printf 'task%s  ✗  команда завершилась с ошибкой (код %d): %s\n' "$NN" "$RC" "$(head -1 "$TMP/err.$NN" 2>/dev/null)"
    continue
  fi

  GOT=$(sha256sum < "$TMP/out.$NN" | cut -d' ' -f1)
  WANT=$(cat "$ANS")
  if [ -n "$FMT" ]; then
    if [ "$GOT" = "$WANT" ]; then VERDICT="конвейер верный, но файл в формате Windows ($FMT)"; else VERDICT="файл в формате Windows ($FMT), и конвейер тоже даёт не тот результат"; fi
    printf 'task%s  ✗  %s: bash видит в нём невидимые символы (BOM перед первой командой, \\r в конце строк).\n' "$NN" "$VERDICT"
    printf '           Почините и проверьте снова:  sed -i '"'"'1s/^\\xEF\\xBB\\xBF//; s/\\r$//'"'"' %s\n' "solutions/task$NN.sh"
    printf '           (в редакторе: сохранить как UTF-8 без BOM, переносы строк LF; посмотреть формат: file solutions/task%s.sh)\n' "$NN"
  elif [ "$GOT" = "$WANT" ]; then
    printf 'task%s  ✓\n' "$NN"
    if [ "$KIND" = "core" ]; then CORE_OK=$((CORE_OK+1)); else BONUS_OK=$((BONUS_OK+1)); fi
  else
    printf 'task%s  ✗  вывод отличается от ожидаемого; первые строки вашего вывода:\n' "$NN"
    head -3 "$TMP/out.$NN" | sed 's/^/           | /'
    [ -s "$TMP/err.$NN" ] && head -1 "$TMP/err.$NN" | sed 's/^/           stderr: /'
  fi
done

echo
echo "Итог: core $CORE_OK/6, доп. $BONUS_OK/2"
if [ "$CORE_OK" -eq 6 ]; then
  echo "Core сдан. Осталось закоммитить solutions/ в свой репозиторий (урок 5)."
elif [ -z "$KEEP" ]; then
  echo "Чтобы посмотреть глазами на те же данные: check-pipes --keep (оставит их в ./check-data)"
  echo "или make-logs в текущем каталоге — на сервере он даёт ровно эти данные."
fi
[ "$CORE_OK" -eq 6 ]
