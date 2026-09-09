#!/usr/bin/env bash
# check.sh — автопроверка stress.sh по спецификации (spec.md).
#
#   bash check.sh [путь/к/stress.sh] [путь/к/counter.txt]
#
# По умолчанию проверяется ./stress.sh, а контртест к задаче A ищется в
# task-a/counter.txt рядом с ним. Работает и на ноутбуке, и на сервере курса
# (там — команда check-stress). Нужны: python3, timeout или gtimeout, g++.
#
# Как работает: запускает ваш stress.sh на заглушках из fixtures/ (решения с
# заранее известным поведением) и сверяет коды выхода, файлы и вывод с тем,
# что требует спецификация. Проверяется поведение, а не текст скрипта.

set -u

STRESS=${1:-./stress.sh}
COUNTER=${2:-}
HERE=$(cd "$(dirname "$0")" && pwd)
FIX="$HERE/fixtures"
TASKA="$HERE/task-a"

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_INFO=$'\033[33m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_ERR=""; C_INFO=""; C_OFF=""
fi

V1_OK=0; V1_ALL=0; V2_OK=0; V2_ALL=0
pass() { # KIND TEXT
  case "$1" in v1) V1_OK=$((V1_OK+1)); V1_ALL=$((V1_ALL+1)) ;; v2) V2_OK=$((V2_OK+1)); V2_ALL=$((V2_ALL+1)) ;; esac
  printf '%s✓%s [%s] %s\n' "$C_OK" "$C_OFF" "$1" "$2"
}
fail() { # KIND TEXT HINT
  case "$1" in v1) V1_ALL=$((V1_ALL+1)) ;; v2) V2_ALL=$((V2_ALL+1)) ;; esac
  printf '%s✗%s [%s] %s\n    → %s\n' "$C_ERR" "$C_OFF" "$1" "$2" "$3"
}
info() { printf '%s·%s %s\n' "$C_INFO" "$C_OFF" "$1"; }

if [ ! -f "$STRESS" ]; then
  echo "Не найден stress.sh: $STRESS" >&2
  echo "Использование: bash check.sh [путь/к/stress.sh]" >&2
  exit 2
fi
STRESS=$(cd "$(dirname "$STRESS")" && pwd)/$(basename "$STRESS")
[ -n "$COUNTER" ] || COUNTER=$(dirname "$STRESS")/task-a/counter.txt

TIMEOUT=$(command -v timeout || command -v gtimeout || true)
[ -n "$TIMEOUT" ] || info "нет timeout/gtimeout: зависший stress.sh придётся прерывать руками (Ctrl+C)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
WORK="$TMP/work"
mkdir -p "$WORK"
cd "$WORK" || exit 2

echo "=== Проверка stress.sh: $STRESS ==="
echo

# --- 0. формат файла и как запускать ---------------------------------------------------

# Файл из Windows-редактора (BOM и/или CRLF) ломает shebang и все пути невидимыми
# символами. Говорим об этом прямо и дальше проверяем очищенную копию.
FMT=""
[ "$(head -c 3 "$STRESS" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ] && FMT="BOM"
grep -q $'\r' "$STRESS" && FMT="${FMT:+$FMT+}CRLF"
if [ -n "$FMT" ]; then
  fail v1 "файл в формате Unix: UTF-8 без BOM, переносы строк LF" "у файла $FMT (Windows-редактор): shebang «bash\\r» не найдётся, пути получат невидимый \\r. Почините: sed -i '1s/^\\xEF\\xBB\\xBF//; s/\\r\$//' stress.sh (дальше проверяю очищенную копию)"
  CLEAN="$TMP/stress.clean.sh"
  { if [ "${FMT#BOM}" != "$FMT" ]; then tail -c +4 "$STRESS"; else cat "$STRESS"; fi; } | tr -d '\r' > "$CLEAN"
  chmod +x "$CLEAN"
  STRESS="$CLEAN"
fi

RUNNER=""
if [ -x "$STRESS" ] && [ "$(head -c 2 "$STRESS")" = "#!" ]; then
  pass v1 "исполняемый файл с shebang"
else
  fail v1 "исполняемый файл с shebang" "chmod +x stress.sh и первая строка #!/usr/bin/env bash (дальше запускаю через bash)"
  RUNNER=bash
fi

# run ARGS... — запустить stress.sh в чистом рабочем каталоге; результат в RC, $TMP/out, $TMP/err
WALL=90
run() {
  rm -f "$WORK"/*
  if [ -n "$TIMEOUT" ]; then
    "$TIMEOUT" "$WALL" $RUNNER "$STRESS" "$@" > "$TMP/out" 2> "$TMP/err"
  else
    $RUNNER "$STRESS" "$@" > "$TMP/out" 2> "$TMP/err"
  fi
  RC=$?
}
mentions() { grep -q "$1" "$TMP/out" "$TMP/err" 2>/dev/null; }

# --- сиды заглушек (см. fixtures/README.md) -----------------------------------------

S_OK=""; S_WA=""; S_TL=""; S_RE=""
s=1
while [ "$s" -le 100 ]; do
  n=$("$FIX/gen.py" "$s" | head -1)
  case "$n" in
    3) [ -n "$S_TL" ] || S_TL=$s ;;
    4) [ -n "$S_RE" ] || S_RE=$s ;;
    1|2|5|6) [ -n "$S_OK" ] || S_OK=$s ;;
    *) [ -n "$S_WA" ] || S_WA=$s ;;
  esac
  if [ -n "$S_OK" ] && [ -n "$S_WA" ] && [ -n "$S_TL" ] && [ -n "$S_RE" ]; then break; fi
  s=$((s + 1))
done
if [ -z "$S_OK$S_WA$S_TL$S_RE" ] || [ -z "$S_WA" ]; then
  echo "Не удалось подобрать сиды заглушек — python3 на месте? (python3 $FIX/gen.py 1)" >&2
  exit 2
fi

# --- v1 -----------------------------------------------------------------------------

run
if [ "$RC" -eq 2 ] && [ -s "$TMP/err" ]; then
  pass v1 "без аргументов: код 2 и подсказка в stderr"
else
  fail v1 "без аргументов: код 2 и подсказка в stderr" "получен код $RC; ожидается usage в stderr и exit 2"
fi

run "$FIX/gen.py" "$FIX/ok.py" "$WORK/no-such-file"
if [ "$RC" -eq 2 ]; then
  pass v1 "несуществующее решение: код 2"
else
  fail v1 "несуществующее решение: код 2" "получен код $RC; проверяйте аргументы до запуска цикла ([ -x ])"
fi

run "$FIX/gen.py" "$FIX/ok.py" "$FIX/ok2.py"
if [ "$RC" -eq 0 ]; then
  pass v1 "два верных решения: код 0 (100 тестов по умолчанию)"
else
  fail v1 "два верных решения: код 0 (100 тестов по умолчанию)" "получен код $RC: $(head -1 "$TMP/err" "$TMP/out" 2>/dev/null | grep -v '^==>' | head -1)"
fi

run "$FIX/gen.py" "$FIX/ok.py" "$FIX/wa.py"
if [ "$RC" -ne 1 ]; then
  fail v1 "WA пойман: код 1, counter.txt воспроизводит расхождение, в выводе «WA»" "получен код $RC (wa.py врёт при n ≥ 7, первый такой сид — $S_WA)"
elif [ ! -f counter.txt ]; then
  fail v1 "WA пойман: код 1, counter.txt воспроизводит расхождение, в выводе «WA»" "код 1 есть, но файла counter.txt в текущем каталоге нет"
elif [ "$("$FIX/ok.py" < counter.txt)" = "$("$FIX/wa.py" < counter.txt)" ]; then
  fail v1 "WA пойман: код 1, counter.txt воспроизводит расхождение, в выводе «WA»" "в counter.txt лежит тест, на котором ok.py и wa.py совпадают — сохраняете не тот файл?"
elif ! mentions WA; then
  fail v1 "WA пойман: код 1, counter.txt воспроизводит расхождение, в выводе «WA»" "контртест верный, но в сообщении нет вердикта WA"
else
  pass v1 "WA пойман: код 1, counter.txt воспроизводит расхождение, в выводе «WA»"
fi

# --- v2 -----------------------------------------------------------------------------

T="-n/-s: тесты ровно с сидами S..S+N-1"
run -n 1 -s "$S_OK" "$FIX/gen.py" "$FIX/ok.py" "$FIX/wa.py"; rc1=$RC
run -n 1 -s "$S_WA" "$FIX/gen.py" "$FIX/ok.py" "$FIX/wa.py"; rc2=$RC
rc3=0
if [ "$S_WA" -gt 1 ]; then
  run -n $((S_WA - 1)) -s 1 "$FIX/gen.py" "$FIX/ok.py" "$FIX/wa.py"; rc3=$RC
fi
if [ "$rc1" -eq 0 ] && [ "$rc2" -eq 1 ] && [ "$rc3" -eq 0 ]; then
  pass v2 "$T"
else
  fail v2 "$T" "-n 1 -s $S_OK → $rc1 (ждём 0); -n 1 -s $S_WA → $rc2 (ждём 1); -n $((S_WA - 1)) -s 1 → $rc3 (ждём 0)"
fi

T="-t: TL пойман, не дожидаясь конца зависшего решения; в выводе «TL»"
START=$SECONDS
WALL=8; run -n 1 -s "$S_TL" -t 1 "$FIX/gen.py" "$FIX/ok.py" "$FIX/tl.py"; WALL=90
ELAPSED=$((SECONDS - START))
if [ "$RC" -eq 1 ] && [ "$ELAPSED" -lt 8 ] && mentions TL; then
  pass v2 "$T"
elif [ "$RC" -eq 1 ] && [ "$ELAPSED" -lt 8 ]; then
  fail v2 "$T" "код 1 есть, но в сообщении нет вердикта TL"
else
  fail v2 "$T" "код $RC за $ELAPSED с (tl.py спит 10 с при n == 3, сид $S_TL); timeout возвращает код 124"
fi

T="RE пойман: код 1, в выводе «RE»"
run -n 1 -s "$S_RE" "$FIX/gen.py" "$FIX/ok.py" "$FIX/re.py"
if [ "$RC" -eq 1 ] && mentions RE; then
  pass v2 "$T"
else
  fail v2 "$T" "код $RC (re.py падает с кодом 3 при n == 4, сид $S_RE); ненулевой код решения — это RE, и его тоже надо ловить"
fi

T="-c: с чекером два верных решения проходят, без него — нет"
run -n 40 "$FIX/gen-argmax.py" "$FIX/first.py" "$FIX/last.py"; rc1=$RC
run -n 40 -c "$FIX/chk.py" "$FIX/gen-argmax.py" "$FIX/first.py" "$FIX/last.py"; rc2=$RC
if [ "$rc1" -eq 1 ] && [ "$rc2" -eq 0 ]; then
  pass v2 "$T"
else
  fail v2 "$T" "без чекера → $rc1 (ждём 1), с чекером → $rc2 (ждём 0); чекер зовётся как «CHECKER input outB outA»"
fi

T="-o FILE: контртест сохраняется в указанный файл"
run -n 1 -s "$S_WA" -o my-test.txt "$FIX/gen.py" "$FIX/ok.py" "$FIX/wa.py"
if [ "$RC" -eq 1 ] && [ -f my-test.txt ] && [ ! -f counter.txt ]; then
  pass v2 "$T"
else
  fail v2 "$T" "код $RC; my-test.txt: $([ -f my-test.txt ] && echo есть || echo нет); counter.txt: $([ -f counter.txt ] && echo 'есть (лишний)' || echo нет)"
fi

T="цвет только в терминале: в перенаправленном выводе нет ESC-последовательностей"
run -n 2 -s "$S_OK" "$FIX/gen.py" "$FIX/ok.py" "$FIX/ok2.py"
if grep -q $'\033' "$TMP/out" "$TMP/err" 2>/dev/null; then
  fail v2 "$T" "найдены коды цвета; включайте их только при [ -t 1 ] (см. гл. 3)"
else
  pass v2 "$T"
fi

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S error "$STRESS" > "$TMP/sc" 2>&1; then
    pass v2 "shellcheck: нет ошибок уровня error"
  else
    fail v2 "shellcheck: нет ошибок уровня error" "$(grep -c '^In ' "$TMP/sc") замечаний; смотрите: shellcheck $STRESS"
  fi
  NWARN=$(shellcheck "$STRESS" 2>/dev/null | grep -c '^In ' || true)
  [ "$NWARN" -eq 0 ] && info "shellcheck чист полностью" || info "shellcheck: $NWARN замечаний уровня warning/info — стоит посмотреть: shellcheck $STRESS"
else
  info "shellcheck не установлен — эта проверка выполнится на сервере курса"
fi

# --- задача A: контртест -------------------------------------------------------------

echo
if [ ! -f "$COUNTER" ]; then
  info "контртест к задаче A не найден ($COUNTER) — эта часть ещё не сдана"
  TASK_A="нет"
elif ! command -v g++ >/dev/null 2>&1; then
  info "нет g++ — контртест к задаче A проверится на сервере"
  TASK_A="?"
elif ! g++ -O2 -std=c++17 -o "$TMP/slow" "$TASKA/slow.cpp" 2>"$TMP/cc" || ! g++ -O2 -std=c++17 -o "$TMP/fast" "$TASKA/fast.cpp" 2>>"$TMP/cc"; then
  info "не удалось собрать task-a/*.cpp: $(head -1 "$TMP/cc")"
  TASK_A="?"
else
  RUN_SLOW="$TMP/slow"; RUN_FAST="$TMP/fast"
  if [ -n "$TIMEOUT" ]; then RUN_SLOW="$TIMEOUT 20 $TMP/slow"; RUN_FAST="$TIMEOUT 20 $TMP/fast"; fi
  A_OUT=$($RUN_SLOW < "$COUNTER" 2>/dev/null); rcA=$?
  B_OUT=$($RUN_FAST < "$COUNTER" 2>/dev/null); rcB=$?
  if [ "$rcA" -ne 0 ]; then
    info "задача A: slow.cpp не отработал на вашем тесте (код $rcA) — тест слишком большой или битый"
    TASK_A="нет"
  elif [ "$rcB" -ne 0 ] || [ "$A_OUT" != "$B_OUT" ]; then
    printf '%s✓%s задача A: контртест подтверждён (slow → %s, fast → %s)\n' "$C_OK" "$C_OFF" "${A_OUT:-?}" "${B_OUT:-код $rcB}"
    TASK_A="да"
  else
    printf '%s✗%s задача A: на этом тесте slow и fast совпадают (%s) — это не контртест\n' "$C_ERR" "$C_OFF" "$A_OUT"
    TASK_A="нет"
  fi
fi

# --- итог ---------------------------------------------------------------------------

echo
echo "Итог: v1 $V1_OK/$V1_ALL, v2 $V2_OK/$V2_ALL, контртест к задаче A: $TASK_A"
if [ "$V1_OK" -eq "$V1_ALL" ] && [ "$V2_OK" -eq "$V2_ALL" ] && [ "$TASK_A" = "да" ]; then
  echo "stress.sh и задача A сданы. Осталось: разминки на Python (check-warmups) и коммит."
  exit 0
elif [ "$V1_OK" -eq "$V1_ALL" ]; then
  echo "v1 готов. Дальше — v2 (spec.md) и контртест к задаче A (task-a/task.md)."
  exit 1
else
  echo "Сначала добейте v1 — без него остальное не имеет смысла."
  exit 1
fi
