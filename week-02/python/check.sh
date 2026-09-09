#!/usr/bin/env bash
# check.sh — автопроверка разминок на Python (неделя 2).
#
#   bash check.sh [каталог-со-скриптами]      # по умолчанию ./python
#
# Ожидаемые файлы: stats.py, topwords.py, tree.py, sha.py (core), checker.py (bonus).
# Работает и на ноутбуке, и на сервере курса (там — команда check-warmups):
# вывод Python одинаков на всех платформах, поэтому эталоны — просто
# sha256-хеши выводов на данных с фиксированным сидом (каталог expected/).

set -u

DIR="${1:-./python}"
HERE=$(cd "$(dirname "$0")" && pwd)
EXP="$HERE/expected"

if [ ! -d "$DIR" ]; then
  echo "Каталог со скриптами не найден: $DIR" >&2
  echo "Ожидается: $DIR/stats.py, topwords.py, tree.py, sha.py" >&2
  exit 2
fi
DIR=$(cd "$DIR" && pwd)

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_INFO=$'\033[33m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_ERR=""; C_INFO=""; C_OFF=""
fi

CORE_OK=0; CORE_ALL=4
BONUS="—"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
python3 "$HERE/make-inputs.py" --out "$TMP/in" >/dev/null || { echo "make-inputs.py не отработал" >&2; exit 2; }
cd "$TMP/in" || exit 2

hash_of() { sha256sum < "$1" 2>/dev/null | cut -d' ' -f1 || shasum -a 256 < "$1" | cut -d' ' -f1; }

# verdict NAME RESULT HINT — RESULT: ok | fail
verdict() {
  if [ "$2" = ok ]; then
    printf '%s✓%s %s\n' "$C_OK" "$C_OFF" "$1"; CORE_OK=$((CORE_OK+1))
  else
    printf '%s✗%s %s\n    → %s\n' "$C_ERR" "$C_OFF" "$1" "$3"
  fi
}

# run_and_compare NAME EXPECTED-FILE CMD... — вывод CMD (stdout) сравнить с эталонным хешем
run_and_compare() {
  local name=$1 exp=$2; shift 2
  "$@" > "$TMP/out" 2> "$TMP/err"; local rc=$?
  if [ "$rc" -ne 0 ]; then
    verdict "$name" fail "скрипт завершился с кодом $rc: $(tail -1 "$TMP/err")"
  elif [ "$(hash_of "$TMP/out")" = "$(cat "$exp")" ]; then
    verdict "$name" ok
  else
    verdict "$name" fail "вывод отличается от ожидаемого; первые строки вашего вывода:"
    head -4 "$TMP/out" | sed 's/^/      | /'
  fi
}

missing() { printf '%s—%s %s: файл %s не найден\n' "$C_INFO" "$C_OFF" "$1" "$2"; }

echo "=== Проверка разминок: $DIR ==="
echo

# --- w1 stats ---------------------------------------------------------------------
if [ -f "$DIR/stats.py" ]; then
  run_and_compare "w1 stats.py" "$EXP/stats.sha256" python3 "$DIR/stats.py" < numbers.txt
else missing "w1 stats.py" "$DIR/stats.py"; fi

# --- w2 topwords ------------------------------------------------------------------
if [ -f "$DIR/topwords.py" ]; then
  python3 "$DIR/topwords.py" < text.txt > "$TMP/out10" 2>"$TMP/err"; rc1=$?
  python3 "$DIR/topwords.py" 3 < text.txt > "$TMP/out3" 2>>"$TMP/err"; rc2=$?
  if [ "$rc1" -ne 0 ] || [ "$rc2" -ne 0 ]; then
    verdict "w2 topwords.py" fail "скрипт завершился с ошибкой: $(tail -1 "$TMP/err")"
  elif [ "$(hash_of "$TMP/out10")" != "$(cat "$EXP/topwords-10.sha256")" ]; then
    verdict "w2 topwords.py" fail "без аргумента (K=10) вывод отличается; первые строки:"
    head -4 "$TMP/out10" | sed 's/^/      | /'
  elif [ "$(hash_of "$TMP/out3")" != "$(cat "$EXP/topwords-3.sha256")" ]; then
    verdict "w2 topwords.py" fail "с аргументом 3 вывод отличается (ровно K строк?)"
  else
    verdict "w2 topwords.py" ok
  fi
else missing "w2 topwords.py" "$DIR/topwords.py"; fi

# --- w3 tree ----------------------------------------------------------------------
if [ -f "$DIR/tree.py" ]; then
  run_and_compare "w3 tree.py" "$EXP/tree.sha256" python3 "$DIR/tree.py" tree
else missing "w3 tree.py" "$DIR/tree.py"; fi

# --- w4 sha -----------------------------------------------------------------------
if [ -f "$DIR/sha.py" ]; then
  ( cd files && python3 "$DIR/sha.py" one.txt two.bin three.txt ) > "$TMP/out" 2>"$TMP/err"; rc1=$?
  ( cd files && python3 "$DIR/sha.py" one.txt no-such-file.txt three.txt ) > "$TMP/out2" 2>"$TMP/err2"; rc2=$?
  if [ "$rc1" -ne 0 ]; then
    verdict "w4 sha.py" fail "на существующих файлах код выхода должен быть 0, получен $rc1"
  elif [ "$(hash_of "$TMP/out")" != "$(cat "$EXP/sha.sha256")" ]; then
    verdict "w4 sha.py" fail "формат: «<hex>  <имя>» — два пробела, как у sha256sum; ваш вывод:"
    head -3 "$TMP/out" | sed 's/^/      | /'
  elif [ "$rc2" -ne 1 ]; then
    verdict "w4 sha.py" fail "если файл не открылся — код выхода 1 (получен $rc2), остальные файлы всё равно обработать"
  elif [ ! -s "$TMP/err2" ]; then
    verdict "w4 sha.py" fail "сообщение о ненайденном файле должно уходить в stderr"
  elif [ "$(hash_of "$TMP/out2")" != "$(cat "$EXP/sha-missing.sha256")" ]; then
    verdict "w4 sha.py" fail "при пропавшем файле в stdout должны остаться хеши остальных двух — и только они"
  else
    verdict "w4 sha.py" ok
  fi
else missing "w4 sha.py" "$DIR/sha.py"; fi

# --- w5 checker (bonus) ------------------------------------------------------------
if [ -f "$DIR/checker.py" ]; then
  BAD=0; TOTAL=0
  for c in checker-cases/case*/; do
    TOTAL=$((TOTAL+1))
    want=$(cat "$c/verdict")
    if python3 "$DIR/checker.py" "$c/input.txt" "$c/output.txt" "$c/answer.txt" >/dev/null 2>&1; then got=OK; else got=WA; fi
    if [ "$got" != "$want" ]; then
      BAD=$((BAD+1))
      printf '    %s: ожидалось %s, чекер сказал %s (вход: %s; вывод: %s)\n' "$(basename "$c")" "$want" "$got" \
        "$(tr '\n' ' ' < "$c/input.txt")" "$(tr '\n' ' ' < "$c/output.txt")"
    fi
  done
  if [ "$BAD" -eq 0 ]; then
    printf '%s✓%s w5 checker.py (bonus): %d/%d случаев\n' "$C_OK" "$C_OFF" "$TOTAL" "$TOTAL"; BONUS="да"
  else
    printf '%s✗%s w5 checker.py (bonus): ошибок %d из %d\n' "$C_ERR" "$C_OFF" "$BAD" "$TOTAL"; BONUS="нет"
  fi
else
  printf '%s—%s w5 checker.py (bonus): нет\n' "$C_INFO" "$C_OFF"
fi

echo
echo "Итог: core $CORE_OK/$CORE_ALL, bonus (checker): $BONUS"
if [ "$CORE_OK" -eq "$CORE_ALL" ]; then
  echo "Разминки сданы. Не забудьте закоммитить week-02/python/."
fi
[ "$CORE_OK" -eq "$CORE_ALL" ]
