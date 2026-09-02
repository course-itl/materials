#!/usr/bin/env bash
# check.sh — автопроверка однострочников недели 1. Запускается НА СЕРВЕРЕ курса.
# Использование:
#   bash check.sh [каталог-с-решениями]     # по умолчанию ./solutions
#
# Как работает: генерирует каноническую версию ваших данных (сид = ваш логин),
# прогоняет каждое решение и сравнивает хеш вывода с эталонным. Эталоны
# посчитаны заранее преподавательским скриптом и лежат в ANSWERS_DIR.

set -u

SOLDIR="${1:-./solutions}"
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

echo "Генерирую канонические данные (сид: $USER)..."
bash "$SCRIPT_DIR/make-logs.sh" --seed "$USER" --out "$TMP" >/dev/null

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

  ( cd "$TMP" && timeout 30 bash "$SOL" ) > "$TMP/out.$NN" 2> "$TMP/err.$NN"
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
  if [ "$GOT" = "$WANT" ]; then
    printf 'task%s  ✓\n' "$NN"
    if [ "$KIND" = "core" ]; then CORE_OK=$((CORE_OK+1)); else BONUS_OK=$((BONUS_OK+1)); fi
  else
    printf 'task%s  ✗  вывод отличается от ожидаемого; первые строки вашего вывода:\n' "$NN"
    head -3 "$TMP/out.$NN" | sed 's/^/           | /'
  fi
done

echo
echo "Итог: core $CORE_OK/6, доп. $BONUS_OK/2"
if [ "$CORE_OK" -eq 6 ]; then
  echo "Core сдан. Осталось закоммитить solutions/ в свой репозиторий (урок 5)."
fi
[ "$CORE_OK" -eq 6 ]
