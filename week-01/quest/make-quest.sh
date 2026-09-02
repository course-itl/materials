#!/usr/bin/env bash
# make-quest.sh — генератор терминального квеста «Восстановление доступа» (неделя 1).
#
# Использование:
#   bash make-quest.sh                  # создать квест в ~/quest (сид = имя пользователя)
#   bash make-quest.sh --reset          # пересоздать заново (фрагменты не изменятся)
#   bash make-quest.sh --revive        # только перезапустить процесс-вредитель
#   bash make-quest.sh --dir D --seed S # нестандартные каталог/сид (для отладки)
#
# Ученикам внутрь не смотреть — здесь ответы. Совместим с bash 3.2 (macOS).

set -u

QDIR="$HOME/quest"
SEED="${USER:-student}"
MODE="create"

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)   QDIR="$2"; shift 2 ;;
    --seed)  SEED="$2"; shift 2 ;;
    --reset) MODE="reset"; shift ;;
    --revive) MODE="revive"; shift ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 2 ;;
  esac
done

# --- утилиты ----------------------------------------------------------------

sha() { # sha256 от строки, работает и на Linux, и на macOS
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | cut -d' ' -f1
  else
    printf '%s' "$1" | shasum -a 256 | cut -d' ' -f1
  fi
}

# Детерминированный ПСЧ для «мусорных» частей дерева (быстрее, чем sha на каждый чих)
RND_STATE=1
rnd() { # rnd <range> -> 0..range-1
  RND_STATE=$(( (RND_STATE * 6364136223846793005 + 1442695040888963407) & 0x7fffffffffffffff ))
  echo $(( RND_STATE % $1 ))
}

# --- фрагменты и фраза (зависят только от сида) ------------------------------

H=$(sha "$SEED:cs2026-quest-v1")
FRAG1=${H:0:8}
FRAG2=${H:8:8}
FRAG3=${H:16:8}
FRAG4=${H:24:8}
RND_STATE=$((16#${H:48:12}))

WORDS="аврора базальт вектор гранит дельта изумруд кварц лагуна маяк нефрит опал пирамида рубин сапфир титан фрегат циклон шафран эверест янтарь"
set -- $WORDS
NW=$#
W_IDX1=$(( (16#${H:32:4}) % NW + 1 ))
W_IDX2=$(( (16#${H:36:4}) % NW + 1 ))
PHRASE=$(eval echo "\${$W_IDX1}-\${$W_IDX2}")
PHRASE_HASH=$(sha "$PHRASE")

# --- вредитель ---------------------------------------------------------------

kill_pest() {
  if [ -f "$QDIR/.internals/pest.pid" ]; then
    OLDPID=$(cat "$QDIR/.internals/pest.pid" 2>/dev/null)
    if [ -n "${OLDPID:-}" ] && kill -0 "$OLDPID" 2>/dev/null; then
      kill -TERM "$OLDPID" 2>/dev/null
      sleep 1
    fi
  fi
}

start_pest() {
  nohup bash "$QDIR/.internals/pest.sh" >/dev/null 2>&1 &
  echo $! > "$QDIR/.internals/pest.pid"
  disown 2>/dev/null || true
}

if [ "$MODE" = "revive" ]; then
  if [ ! -f "$QDIR/.internals/pest.sh" ]; then
    echo "Квест не найден в $QDIR — сначала создайте его: bash make-quest.sh" >&2
    exit 1
  fi
  kill_pest
  start_pest
  echo "Вредитель снова на свободе. Удачной охоты."
  exit 0
fi

if [ -d "$QDIR" ]; then
  if [ "$MODE" = "reset" ]; then
    kill_pest
    rm -rf "$QDIR"
  else
    echo "Каталог $QDIR уже существует." >&2
    echo "Пересоздать заново: bash make-quest.sh --reset" >&2
    exit 1
  fi
fi

mkdir -p "$QDIR"

# --- шаг 0: легенда ----------------------------------------------------------

cat > "$QDIR/README.txt" <<'EOF'
=== ИНЦИДЕНТ #1337: ВОССТАНОВЛЕНИЕ ДОСТУПА ===

Прошлый администратор ушёл, не передав дела. Ключ доступа он разбил на
ЧЕТЫРЕ ФРАГМЕНТА и спрятал в файловой системе. А ещё, по слухам, оставил
после себя запущенный процесс-вредитель.

Финальный флаг собирается так:
    FLAG{фрагмент1-фрагмент2-фрагмент3-фрагмент4}
Запиши его в файл FLAG.txt здесь, в корне квеста.

По одной ключевой команде на каждый пройденный шаг записывай в journal.txt.

Начни с его рабочих архивов: каталог archive/. Он был человеком
обстоятельным — бэкапы раскладывал по годам и кварталам. Настоящая
записка одна, остальные — тупики.
EOF

cat > "$QDIR/journal.txt" <<'EOF'
# Журнал прохождения. По одной ключевой команде на шаг (можно с комментарием).
# Пример:  шаг 3: find storage -size 1337c
шаг 1 (навигация):
шаг 2 (скрытое):
шаг 3 (find):
шаг 4 (grep):
шаг 5 (права):
шаг 6 (запуск скрипта):
шаг 7 (архивы):
шаг 8 (man):
шаг 9 (процессы):
EOF

# --- шаг 1: навигация по archive/ -------------------------------------------

YR=$(( 2017 + $(rnd 5) ))
QT=$(( 1 + $(rnd 4) ))
for y in 2017 2018 2019 2020 2021; do
  for q in 1 2 3 4; do
    for sub in full old tmp; do
      D="$QDIR/archive/y$y/quarter$q/backups/$sub"
      mkdir -p "$D"
      echo "Тупик. Здесь только пыль. Ищи дальше." > "$D/note1.txt"
    done
  done
done
REAL1="$QDIR/archive/y$YR/quarter$QT/backups/full"
cat > "$REAL1/note1.txt" <<'EOF'
Ага, нашёл. Значит, с навигацией у тебя порядок.

Продолжение — ЗДЕСЬ ЖЕ, в этом каталоге. Но я его спрятал так, что
обычный ls его не покажет. Подумай, какие файлы ls скрывает по умолчанию.
EOF

# --- шаг 2: скрытый каталог --------------------------------------------------

mkdir -p "$REAL1/.cache"
cat > "$REAL1/.cache/note2.txt" <<'EOF'
Скрытое от глаз — не скрыто от ls -a. Идём дальше.

Следующая записка — в каталоге storage/ в корне квеста. Там сотня
одинаковых с виду файлов-чанков. Помню только одно: нужный файл
весит РОВНО 1337 байт. Перебирать руками — жизни не хватит;
у find есть флаг для поиска по размеру.
EOF

# --- шаг 3: find по размеру --------------------------------------------------

mkdir -p "$QDIR/storage"
TARGET_CHUNK=$(( $(rnd 150) + 1 ))
i=1
while [ $i -le 150 ]; do
  SZ=$(( 300 + $(rnd 3900) ))
  [ $SZ -eq 1337 ] && SZ=1338
  NUM=$(printf '%03d' $i)
  if [ $i -ne $TARGET_CHUNK ]; then
    head -c $SZ /dev/zero > "$QDIR/storage/chunk_$NUM.dat"
  fi
  i=$((i+1))
done
NUM=$(printf '%03d' $TARGET_CHUNK)
MSG="=== ФРАГМЕНТ 1/4: $FRAG1 ===

Дальше — каталог library/ в корне квеста: мои старые заметки.
В одной из них записана КОДОВАЯ ФРАЗА (ищи по слову «кодовая»).
Читать все подряд не советую — есть команда, которая ищет строку
сразу во всех файлах каталога.

"
MSGLEN=$(printf '%s' "$MSG" | wc -c | tr -d ' ')
PAD=$(( 1337 - MSGLEN ))
{ printf '%s' "$MSG"; printf '%*s' "$PAD" '' | tr ' ' '#'; } > "$QDIR/storage/chunk_$NUM.dat"

# --- шаг 4: grep -r по library/ ---------------------------------------------

mkdir -p "$QDIR/library"
PHRASE_FILE=$(( (16#${H:40:4}) % 80 + 1 ))
i=1
while [ $i -le 80 ]; do
  NUM=$(printf '%02d' $i)
  F="$QDIR/library/note_$NUM.txt"
  : > "$F"
  line=1
  while [ $line -le 6 ]; do
    L=""
    w=1
    while [ $w -le 4 ]; do
      IDX=$(( $(rnd $NW) + 1 ))
      L="$L $(eval echo "\${$IDX}")"
      w=$((w+1))
    done
    echo "заметка:$L" >> "$F"
    line=$((line+1))
  done
  i=$((i+1))
done
NUM=$(printf '%02d' $PHRASE_FILE)
cat >> "$QDIR/library/note_$NUM.txt" <<EOF
кодовая фраза: $PHRASE
запомни её — она понадобится позже. а пока загляни в каталог locked/:
там лежит записка, но у файла сняты ВСЕ права. хозяин файла может их вернуть.
EOF

# --- шаг 5: права ------------------------------------------------------------

mkdir -p "$QDIR/locked"
cat > "$QDIR/locked/note4.txt" <<EOF
=== ФРАГМЕНТ 2/4: $FRAG2 ===

Права — вещь поправимая, когда файл твой.

Теперь про кодовую фразу: скрипт tools/reveal.sh покажет дорогу,
если запустить его с фразой в качестве аргумента. Одна беда:
запускаться он почему-то отказывается. Посмотри на его права.
EOF
chmod 000 "$QDIR/locked/note4.txt"

# --- шаг 6: исполняемость ----------------------------------------------------

mkdir -p "$QDIR/tools"
cat > "$QDIR/tools/reveal.sh" <<EOF
#!/usr/bin/env bash
# reveal.sh — принимает кодовую фразу аргументом.
if [ \$# -ne 1 ]; then
  echo "Использование: ./reveal.sh <кодовая-фраза>"
  exit 1
fi
if command -v sha256sum >/dev/null 2>&1; then
  GOT=\$(printf '%s' "\$1" | sha256sum | cut -d' ' -f1)
else
  GOT=\$(printf '%s' "\$1" | shasum -a 256 | cut -d' ' -f1)
fi
if [ "\$GOT" = "$PHRASE_HASH" ]; then
  echo "Фраза верна."
  echo "Третий фрагмент я запер в архиве: vault/matryoshka.tar."
  echo "Предупреждаю: это матрёшка."
else
  echo "Неверная фраза. Ищи внимательнее в library/."
  exit 1
fi
EOF
chmod 644 "$QDIR/tools/reveal.sh"

# --- шаг 7: архив-матрёшка ---------------------------------------------------

mkdir -p "$QDIR/vault"
BUILD=$(mktemp -d)
cat > "$BUILD/note5.txt" <<'EOF'
Почти у цели. Третий фрагмент охраняет стражник: gatekeeper/ask.sh.
Он задаст вопрос про tar. Ответ есть в man tar — ты ведь уже умеешь
его открывать?
EOF
( cd "$BUILD" && tar -czf inner.tar.gz note5.txt && rm note5.txt && tar -cf matryoshka.tar inner.tar.gz )
mv "$BUILD/matryoshka.tar" "$QDIR/vault/"
rm -rf "$BUILD"

# --- шаг 8: стражник (man) ---------------------------------------------------

mkdir -p "$QDIR/gatekeeper" "$QDIR/vault2"
cat > "$QDIR/gatekeeper/ask.sh" <<EOF
#!/usr/bin/env bash
echo "СТРАЖНИК: Назови флаг tar, который показывает СПИСОК файлов архива,"
echo "не распаковывая его. Подойдёт короткая или длинная форма."
printf "Твой ответ: "
read -r ANS
ANS=\$(printf '%s' "\$ANS" | tr 'A-Z' 'a-z' | tr -d ' ')
case "\$ANS" in
  -t|t|--list|list)
    echo
    echo "=== ФРАГМЕНТ 3/4: $FRAG3 ==="
    echo
    echo "Последний фрагмент должен лежать в vault2/fragment4.txt,"
    echo "но мой процесс-вредитель затирает его каждые пару секунд."
    echo "Найди вредителя в списке процессов (его зовут pest) и останови"
    echo "ВЕЖЛИВО — обычным сигналом завершения. Перед смертью он честно"
    echo "вернёт фрагмент на место. Убьёшь через -9 — фрагмент погибнет"
    echo "вместе с ним (тогда: bash make-quest.sh --revive и попробуй снова)."
    ;;
  *)
    echo "Неверно. man tar, раздел с описанием основных режимов."
    exit 1
    ;;
esac
EOF
chmod 755 "$QDIR/gatekeeper/ask.sh"

# --- шаг 9: процесс-вредитель ------------------------------------------------

mkdir -p "$QDIR/.internals"
cat > "$QDIR/.internals/pest.sh" <<EOF
#!/usr/bin/env bash
# pest — процесс-вредитель квеста. Ученикам внутрь не смотреть.
Q="$QDIR"
trap 'printf "=== ФРАГМЕНТ 4/4: %s ===\nМолодец: SIGTERM дал мне шанс прибраться за собой.\n" "$FRAG4" > "\$Q/vault2/fragment4.txt"; exit 0' TERM
while true; do
  printf "ФАЙЛ ПОВРЕЖДЁН процессом-вредителем pest (PID %s).\nОстанови его — и данные восстановятся.\n" "\$\$" > "\$Q/vault2/fragment4.txt"
  # sleep в фоне + wait: TERM обрабатывается сразу, а не после конца sleep
  sleep 2 & wait \$!
done
EOF
chmod 700 "$QDIR/.internals/pest.sh"
start_pest

# --- финал -------------------------------------------------------------------

echo "Квест создан в: $QDIR"
echo "Начинайте:  cd $QDIR && cat README.txt"
