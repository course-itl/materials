#!/usr/bin/env bash
# setup.sh — тренажёр недели 3: собирает учебные репозитории в ~/git-practice.
#
#   bash setup.sh              # создать ~/git-practice/{staging,conflict,messy,undo,bisect}
#   bash setup.sh ДРУГОЙ/ПУТЬ  # то же, но в другом каталоге
#   bash setup.sh --reset      # снести и собрать заново (начать задачу с чистого листа)
#
# Каждый каталог — отдельный git-репозиторий с заготовленной историей под одну-две
# задачи из tasks.md. Ломайте их смело: --reset возвращает всё в исходное состояние.
# Скрипт не трогает ваш глобальный git config и ничего не пишет вне целевого каталога.
# Нужны: git 2.32+, python3.

set -eu

ROOT="$HOME/git-practice"
RESET=0
for a in "$@"; do
  case "$a" in
    --reset) RESET=1 ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) ROOT="$a" ;;
  esac
done

if [ -e "$ROOT" ]; then
  if [ "$RESET" = 1 ]; then
    rm -rf "$ROOT"
  else
    echo "Каталог $ROOT уже есть. Чтобы собрать тренажёр заново: bash setup.sh --reset" >&2
    exit 1
  fi
fi

# Одна и та же «личность» автора и одни и те же даты у всех: истории совпадают
# у всех учеников, и в подсказках можно ссылаться на коммиты по сообщению.
# Глобальные настройки (подписи коммитов, хуки, autocrlf, алиасы) отключены,
# чтобы они не вмешивались в сборку.
export GIT_AUTHOR_NAME="Course Bot" GIT_AUTHOR_EMAIL="bot@course.local"
export GIT_COMMITTER_NAME="Course Bot" GIT_COMMITTER_EMAIL="bot@course.local"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

BASE=1788246000   # 2026-09-01 10:00 +0300
N=0
commit() { # commit "сообщение" — закоммитить индекс с монотонно растущей датой
  N=$((N + 1))
  local d="$((BASE + N * 600)) +0300"
  GIT_AUTHOR_DATE="$d" GIT_COMMITTER_DATE="$d" git commit -q -m "$1"
}
snap() { # snap "сообщение" — добавить всё и закоммитить
  git add -A && commit "$1"
}

mkdir -p "$ROOT"
echo "Собираю тренажёр в $ROOT"

###############################################################################
# staging — задача 1: один файл, три разные правки, нужно два чистых коммита
###############################################################################
mkdir -p "$ROOT/staging" && cd "$ROOT/staging" && git init -q -b main

cat > topwords.py <<'EOF'
#!/usr/bin/env python3
"""topwords: самые частые слова текста из stdin."""
import sys
from collections import Counter


def words(text):
    return text.split()


def main():
    text = sys.stdin.read()
    counts = Counter(words(text))
    top = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    for word, n in top[:10]:
        print(word, n)


if __name__ == "__main__":
    main()
EOF

cat > test.sh <<'EOF'
#!/usr/bin/env bash
# test.sh — две проверки для topwords.py: исправление бага и новая опция.
cd "$(dirname "$0")"
status=0
check() { # НАЗВАНИЕ ОЖИДАЕМОЕ ПОЛУЧЕННОЕ
  if [ "$2" = "$3" ]; then
    echo "✓ $1"
  else
    echo "✗ $1"
    echo "    ожидалось: $(printf '%s' "$2" | tr '\n' '|')"
    echo "    получено:  $(printf '%s' "$3" | tr '\n' '|')"
    status=1
  fi
}
sample='Кот, кот и КОТ. Пёс! пёс?'
check "баг: регистр и знаки препинания" $'кот 3\nпёс 2\nи 1' "$(printf '%s\n' "$sample" | python3 topwords.py 2>/dev/null)"
check "опция: число слов аргументом"    $'кот 3'            "$(printf '%s\n' "$sample" | python3 topwords.py 1 2>/dev/null)"
exit $status
EOF

cat > README.md <<'EOF'
# topwords

Самые частые слова текста. Запуск: `python3 topwords.py < текст.txt`.
Проверка: `bash test.sh`.
EOF
snap "topwords: first version"

# Рабочее дерево: исправление бага, новая опция и отладочные print — всё вперемешку,
# ничего не закоммичено. Разделить это на два коммита и есть задача.
cat > topwords.py <<'EOF'
#!/usr/bin/env python3
"""topwords: самые частые слова текста из stdin."""
import re
import sys
from collections import Counter


def words(text):
    print("DEBUG raw length:", len(text))
    return re.findall(r"[^\W\d_]+", text.lower())


def main():
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    text = sys.stdin.read()
    counts = Counter(words(text))
    print("DEBUG counts:", counts)
    top = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    for word, n in top[:limit]:
        print(word, n)


if __name__ == "__main__":
    main()
EOF
echo "  staging/   готов"

###############################################################################
# conflict — задача 2: main и feature правят одно место; нужны обе правки
###############################################################################
mkdir -p "$ROOT/conflict" && cd "$ROOT/conflict" && git init -q -b main

cat > stats.py <<'EOF'
#!/usr/bin/env python3
"""stats: статистика по числам из stdin."""
import sys


def main():
    nums = [int(x) for x in sys.stdin.read().split()]
    print("count:", len(nums))
    print("sum:", sum(nums))
    print("min:", min(nums))
    print("max:", max(nums))
    print(f"mean: {sum(nums) / len(nums):.2f}")


if __name__ == "__main__":
    main()
EOF

cat > test.sh <<'EOF'
#!/usr/bin/env bash
# test.sh — проверки stats.py. Каждая смотрит, есть ли в выводе нужная строка.
cd "$(dirname "$0")"
status=0
has() { # НАЗВАНИЕ ВВОД ОЖИДАЕМАЯ-СТРОКА
  local out
  out=$(printf '%b' "$2" | python3 stats.py 2>&1) || true
  if printf '%s\n' "$out" | grep -qx -- "$3"; then
    echo "✓ $1"
  else
    echo "✗ $1 (в выводе нет строки «$3»)"
    status=1
  fi
}
has "обычный ввод: mean"   '3 1 2\n'    'mean: 2.00'
has "обычный ввод: median" '1 2 3 10\n' 'median: 2.50'
has "пустой ввод: count"   ''           'count: 0'
has "пустой ввод: mean"    ''           'mean: 0.00'
has "пустой ввод: median"  ''           'median: 0.00'
exit $status
EOF

cat > README.md <<'EOF'
# stats

Читает числа из stdin, печатает count, sum, min, max, mean.
Проверка: `bash test.sh`.
EOF
snap "stats: count, sum, min, max, mean"

git switch -q -c feature
cat > stats.py <<'EOF'
#!/usr/bin/env python3
"""stats: статистика по числам из stdin."""
import sys


def median(nums):
    s = sorted(nums)
    mid = len(s) // 2
    return s[mid] if len(s) % 2 else (s[mid - 1] + s[mid]) / 2


def main():
    nums = [int(x) for x in sys.stdin.read().split()]
    print("count:", len(nums))
    print("sum:", sum(nums))
    print("min:", min(nums))
    print("max:", max(nums))
    print(f"mean: {sum(nums) / len(nums):.2f}")
    print(f"median: {median(nums):.2f}")


if __name__ == "__main__":
    main()
EOF
snap "stats: add median"

git switch -q main
cat > stats.py <<'EOF'
#!/usr/bin/env python3
"""stats: статистика по числам из stdin."""
import sys


def main():
    nums = [int(x) for x in sys.stdin.read().split()]
    print("count:", len(nums))
    print("sum:", sum(nums))
    print("min:", min(nums, default=0))
    print("max:", max(nums, default=0))
    mean = sum(nums) / len(nums) if nums else 0
    print(f"mean: {mean:.2f}")


if __name__ == "__main__":
    main()
EOF
snap "stats: survive empty input"
cat >> README.md <<'EOF'

Пустой ввод — не ошибка: печатаются нули.
EOF
snap "readme: empty input is fine"
echo "  conflict/  готов"

###############################################################################
# messy — задача 3: шесть неряшливых коммитов в ветке, нужно три осмысленных
###############################################################################
mkdir -p "$ROOT/messy" && cd "$ROOT/messy" && git init -q -b main

cat > README.md <<'EOF'
# ini

Парсер конфигов в формате key=valeu: читает строки из stdin, печатает `key -> value`.
Проверка: `bash test.sh`.
EOF
cat > test.sh <<'EOF'
#!/usr/bin/env bash
# test.sh — проверка ini.py на конфиге с комментарием, пустой строкой и пробелами.
cd "$(dirname "$0")"
expected=$'host -> example.com\nport -> 8080\nname -> demo'
actual=$(printf '# config\nhost = example.com\n\nport=8080\n  name =  demo \n' | python3 ini.py 2>&1) || true
if [ "$expected" = "$actual" ]; then
  echo "✓ parser"
else
  echo "✗ parser"
  printf '%s\n' "$actual" | sed 's/^/    /'
  exit 1
fi
EOF
snap "init: readme and tests"

git switch -q -c feature
cat > ini.py <<'EOF'
#!/usr/bin/env python3
"""ini: читает key=value из stdin, печатает key -> value."""
import sys


def parse(lines):
    result = {}
    for line in lines:
        key, value = line.split("=", 1)
        result[key] = value
    return result


def main():
    for key, value in parse(sys.stdin.read().splitlines()).items():
        print(f"{key} -> {value}")


if __name__ == "__main__":
    main()
EOF
snap "parser: read key=value lines"

python3 - <<'PY'
import pathlib
p = pathlib.Path("ini.py"); s = p.read_text()
s = s.replace('    for line in lines:\n        key, value',
              '    for line in lines:\n        if line.startswith("#"):\n            continue\n        key, value')
p.write_text(s)
PY
snap "wip"

sed -i.bak 's/valeu/value/' README.md && rm README.md.bak
snap "fix typo in README"

sed -i.bak 's/result\[key\] = value/result[key.strip()] = value.strip()/' ini.py && rm ini.py.bak
snap "oops"

sed -i.bak 's/if line.startswith("#"):/if not line.strip() or line.startswith("#"):/' ini.py && rm ini.py.bak
snap "parser: skip blank lines too"

sed -i.bak 's/"""ini: читает key=value из stdin, печатает key -> value."""/"""ini: читает key=value из stdin, печатает key -> value.\n\nКомментарии (#) и пустые строки пропускаются, пробелы вокруг = не важны."""/' ini.py && rm ini.py.bak
snap "wip"

git switch -q main
echo "  messy/     готов"

###############################################################################
# undo — задачи 4–7: откат, восстановление файла, stash, .gitignore.
# У репозитория есть «удалённый» origin (голый репозиторий рядом), так что
# push и pull работают по-настоящему, без GitHub.
###############################################################################
git init -q --bare -b main "$ROOT/undo-origin.git"
git clone -q "$ROOT/undo-origin.git" "$ROOT/undo" 2>/dev/null
cd "$ROOT/undo"

cat > stats.py <<'EOF'
#!/usr/bin/env python3
"""stats: статистика по числам из stdin."""
import sys


def main():
    nums = [int(x) for x in sys.stdin.read().split()]
    print("count:", len(nums))
    print("sum:", sum(nums))
    print("min:", min(nums))
    print("max:", max(nums))


if __name__ == "__main__":
    main()
EOF
cat > gen.py <<'EOF'
#!/usr/bin/env python3
"""gen: печатает N случайных чисел; аргументы — N и seed."""
import random
import sys

n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
random.seed(int(sys.argv[2]) if len(sys.argv) > 2 else 1)
print(*[random.randint(-100, 100) for _ in range(n)])
EOF
cat > test.sh <<'EOF'
#!/usr/bin/env bash
# test.sh — проверка stats.py на фиксированном примере. Вывод кладётся в out/.
cd "$(dirname "$0")"
mkdir -p out
printf '3 1 2 1\n' | python3 stats.py > out/actual.txt 2>&1 || true
status=0
for line in 'count: 4' 'sum: 7' 'min: 1' 'max: 3' 'mean: 1.75'; do
  if grep -qx -- "$line" out/actual.txt; then echo "✓ $line"; else echo "✗ $line"; status=1; fi
done
exit $status
EOF
cat > README.md <<'EOF'
# stats

Статистика по числам из stdin. Проверка: `bash test.sh`.
EOF
snap "stats: count, sum, min, max"

git rm -q gen.py
commit "remove gen.py: tests use a fixed sample"

python3 - <<'PY'
import pathlib
p = pathlib.Path("stats.py"); s = p.read_text()
s = s.replace('    print("max:", max(nums))\n',
              '    print("max:", max(nums))\n    print(f"mean: {sum(nums) / len(nums):.2f}")\n')
p.write_text(s)
PY
snap "stats: add mean"

git switch -q -c wip
cat >> stats.py <<'EOF'


def histogram(nums):
    for v in sorted(set(nums)):
        print(f"{v:4d} {'#' * nums.count(v)}")
EOF
snap "stats: histogram experiment (not wired in yet)"
git switch -q main

sed -i.bak 's|sum(nums) / len(nums)|sum(nums) // len(nums)|' stats.py && rm stats.py.bak
snap "stats: speed up mean with integer math"

cat >> README.md <<'EOF'

Пример: `printf '3 1 2 1\n' | python3 stats.py`.
EOF
snap "readme: usage example"

git push -q -u origin main 2>/dev/null
git push -q origin wip 2>/dev/null
echo "  undo/      готов (origin: undo-origin.git)"

###############################################################################
# bisect — бонус: сорок коммитов, один из них сломал calc.py
###############################################################################
mkdir -p "$ROOT/bisect" && cd "$ROOT/bisect" && git init -q -b main

cat > calc.py <<'EOF'
#!/usr/bin/env python3
"""calc: наибольший общий делитель двух чисел."""
import sys


def gcd(a, b):
    while b:
        a, b = b, a % b
    return a


print(gcd(int(sys.argv[1]), int(sys.argv[2])))
EOF
cat > test.sh <<'EOF'
#!/usr/bin/env bash
# test.sh — проверка calc.py; код возврата 0 = всё хорошо, 1 = сломано.
cd "$(dirname "$0")"
[ "$(python3 calc.py 12 18 2>/dev/null)" = 6 ] && [ "$(python3 calc.py 3 5 2>/dev/null)" = 1 ]
EOF
echo "# Журнал" > CHANGELOG.md
snap "calc: gcd and tests"

for i in $(seq 1 40); do
  echo "day $i: notes" >> CHANGELOG.md
  if [ "$i" = 23 ]; then
    sed -i.bak 's/while b:/while b > 1:/' calc.py && rm calc.py.bak
  fi
  snap "day $i"
done
echo "  bisect/    готов"

cd "$ROOT"
echo
echo "Готово. Задачи — в tasks.md рядом с этим скриптом; начинайте с cd $ROOT/staging"
