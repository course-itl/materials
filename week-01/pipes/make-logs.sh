#!/usr/bin/env bash
# make-logs.sh — генератор данных для задач про пайпы (неделя 1).
# Создаёт access.log (~100 000 строк, формат веб-сервера) и каталог code/.
# Данные детерминированы сидом (по умолчанию — имя пользователя), поэтому
# у каждого ученика свои ответы, а автопроверка на сервере знает их заранее.
#
# Использование:
#   bash make-logs.sh                          # access.log и code/ в текущем каталоге
#   bash make-logs.sh --out DIR --seed S --lines N
#
# ВАЖНО: эталонные ответы считаются на сервере курса тем же awk. Локально
# сгенерированный лог годится для тренировки, но числа могут отличаться —
# автопроверка сверяет только серверную версию.

set -u

OUT="."
SEED="${USER:-student}"
# Имя N_LINES, а не LINES: LINES — служебная переменная шелла (высота окна терминала).
# Интерактивный bash/zsh обновляет её сам, и в некоторых окружениях она перебивала
# наше значение — лог получался длиной в высоту окна (30, 50 строк вместо 100000).
N_LINES=100000

while [ $# -gt 0 ]; do
  case "$1" in
    --out)   OUT="$2"; shift 2 ;;
    --seed)  SEED="$2"; shift 2 ;;
    --lines) N_LINES="$2"; shift 2 ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$OUT"

if command -v sha256sum >/dev/null 2>&1; then
  H=$(printf '%s' "$SEED:cs2026-logs-v1" | sha256sum | cut -d' ' -f1)
else
  H=$(printf '%s' "$SEED:cs2026-logs-v1" | shasum -a 256 | cut -d' ' -f1)
fi
NSEED=$((16#${H:0:8}))
OFFSET=$(( (16#${H:8:2}) % 13 ))

# --- access.log --------------------------------------------------------------

awk -v n="$N_LINES" -v seed="$NSEED" 'BEGIN {
  srand(seed)
  split("203.0.113.7 198.51.100.23 192.0.2.42 203.0.113.99 198.51.100.5", heavy, " ")
  nref = split("- https://google.com/ https://t.me/dev_channel https://news.ycombinator.com/", refs, " ")
  ua[1] = "Mozilla/5.0 (X11; Linux x86_64) Firefox/128.0"
  ua[2] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_5) Safari/605.1.15"
  ua[3] = "Mozilla/5.0 (Windows NT 10.0; Win64) Chrome/126.0"
  ua[4] = "curl/8.5.0"
  ua[5] = "python-requests/2.32"

  for (i = 1; i <= n; i++) {
    # IP: пять «тяжёлых» с сильно разными вероятностями + фоновый шум
    r = rand()
    if      (r < 0.090) ip = heavy[1]
    else if (r < 0.160) ip = heavy[2]
    else if (r < 0.210) ip = heavy[3]
    else if (r < 0.245) ip = heavy[4]
    else if (r < 0.265) ip = heavy[5]
    else ip = sprintf("10.%d.%d.%d", int(rand()*8), int(rand()*16), 1+int(rand()*254))

    # время: один день, секунды идут вперёд
    t = int(i * 0.9) % 86400
    hh = int(t / 3600); mm = int(t % 3600 / 60); ss = t % 60

    r = rand()
    if      (r < 0.90)  method = "GET"
    else if (r < 0.98)  method = "POST"
    else if (r < 0.995) method = "PUT"
    else                method = "DELETE"

    r = rand()
    if      (r < 0.25) path = "/index.html"
    else if (r < 0.38) path = "/static/app.js"
    else if (r < 0.50) path = "/api/users"
    else if (r < 0.60) path = "/api/orders"
    else if (r < 0.68) path = "/static/style.css"
    else if (r < 0.75) path = "/img/logo.png"
    else if (r < 0.81) path = "/login"
    else if (r < 0.86) path = "/about"
    else if (r < 0.91) path = "/health"
    else if (r < 0.95) path = "/search"
    else               path = "/favicon.ico"

    if (path == "/favicon.ico") status = 404
    else {
      r = rand()
      if      (r < 0.86)  status = 200
      else if (r < 0.90)  status = 302
      else if (r < 0.93)  status = 301
      else if (r < 0.965) status = 404
      else if (r < 0.985) status = 403
      else                status = 500
    }

    if      (status == 200) bytes = 500 + int(rand()*19500)
    else if (status == 404) bytes = 150 + int(rand()*350)
    else if (status == 500) bytes = 512
    else                    bytes = 20 + int(rand()*70)

    ref = refs[1 + int(rand()*nref)]
    agent = ua[1 + int(rand()*5)]

    printf "%s - - [01/Sep/2026:%02d:%02d:%02d +0300] \"%s %s HTTP/1.1\" %d %d \"%s\" \"%s\"\n", \
           ip, hh, mm, ss, method, path, status, bytes, ref, agent
  }
}' > "$OUT/access.log"

# --- code/ — дерево исходников для задач про строки кода ---------------------

gen_file() { # gen_file <path> <lines> <prefix>
  awk -v n="$2" -v p="$3" 'BEGIN { for (i = 1; i <= n; i++) print p " строка " i }' > "$1"
}

mkdir -p "$OUT/code/src" "$OUT/code/lib" "$OUT/code/tests"
gen_file "$OUT/code/src/main.py"          $((120 + OFFSET)) "#"
gen_file "$OUT/code/src/utils.py"         $((84  + OFFSET)) "#"
gen_file "$OUT/code/src/parser.py"        $((210 + OFFSET)) "#"
gen_file "$OUT/code/src/engine.cpp"       $((340 + OFFSET)) "//"
gen_file "$OUT/code/src/engine.h"         $((55  + OFFSET)) "//"
gen_file "$OUT/code/lib/helpers.py"       $((57  + OFFSET)) "#"
gen_file "$OUT/code/tests/test_parser.py" $((96  + OFFSET)) "#"
gen_file "$OUT/code/tests/test_utils.py"  $((42  + OFFSET)) "#"
gen_file "$OUT/code/README.md"            $((30  + OFFSET)) ">"
gen_file "$OUT/code/notes.txt"            $((18  + OFFSET)) "-"

echo "Готово: $OUT/access.log ($(wc -l < "$OUT/access.log" | tr -d ' ') строк) и $OUT/code/"
