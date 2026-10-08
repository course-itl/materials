#!/usr/bin/env bash
# check.sh — автопроверка тренажёра недели 3: задачи 1–7 из tasks.md и бонусы B1–B2.
#
#   bash check.sh [каталог-тренажёра]      # по умолчанию ~/git-practice
#
# Смотрит на репозитории staging/, conflict/, messy/, undo/ (и bisect/ для бонуса)
# и сверяет их с тем, что должно получиться по каждой задаче: содержимое файлов —
# через хеши объектов (тренажёр детерминирован, см. setup.sh), историю — через log,
# следы действий (merge, stash, переключения веток) — через reflog и объекты в .git.
# Ничего не меняет: test.sh из репозиториев запускаются на копиях во временном
# каталоге. Работает и на ноутбуке, и на сервере курса
# (bash /opt/course/materials/03-git/check.sh). Нужны: git 2.32+, python3.
#
# Зачёт снимается с сервера курса: преподаватель запускает этот же скрипт под учёткой ученика.
# Код выхода 0 = все core-задачи сделаны.

set -u

ROOT="${1:-$HOME/git-practice}"
case "$ROOT" in -h|--help) sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

if [ ! -d "$ROOT" ]; then
  echo "Каталог тренажёра не найден: $ROOT" >&2
  echo "Соберите его: bash setup.sh (или укажите путь: bash check.sh ПУТЬ)" >&2
  exit 2
fi
ROOT=$(cd "$ROOT" && pwd)
command -v git >/dev/null 2>&1 || { echo "Нужен git" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "Нужен python3: его запускают test.sh из тренажёра" >&2; exit 2; }
export GIT_OPTIONAL_LOCKS=0

# Объекты, которые создаёт setup.sh. Хеши у всех одинаковые (фиксированные автор и даты),
# поэтому по ним можно сверять и исходную историю, и содержимое файлов.
STAGING_ROOT=bb4a271d44c219ddf328784783d19bcc6df21c6f     # topwords: first version
CONFLICT_MAIN=bfb8514fed14223c9d47a26bd5e940e0cc8c1275    # readme: empty input is fine (вершина main)
CONFLICT_FEATURE=d04b783f5edf2bf4315aa4a8226bd9b276a87f39 # stats: add median (до rebase)
MESSY_MAIN=df63a65a9f2bb346077161cbf531e852bf574081       # init: readme and tests
MESSY_TREE=446db62c3543e1da371708fdc87d15e8a9a69a69       # дерево вершины feature до уборки
UNDO_ROOT=42dba19a77cfcb64091a57b59c193cdc0a185e55        # stats: count, sum, min, max
UNDO_CULPRIT=d0c66ea771277388daf650ae06296ccb06e6f8c8     # stats: speed up mean with integer math
UNDO_GEN_BLOB=5a5efc8fe1a5dfbc5cd4e5b90a7ef65521ed7732    # содержимое удалённого gen.py
UNDO_WIP=ea7f1248861ca80f0a6a06cd585ae4de91863a3d         # stats: histogram experiment (ветка wip)
BISECT_CULPRIT=d1169f13ff4e38171d14562a9e680322efcb67f4   # day 23

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_ERR=$'\033[31m'; C_INFO=$'\033[33m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_ERR=""; C_INFO=""; C_OFF=""
fi

CORE_OK=0; CORE_ALL=0; B1="не делали"; B2="не делали"
T_OK=1
REPO=""

g()    { git --no-pager -C "$REPO" "$@"; }
task() { printf '\n-- %s\n' "$1"; T_OK=1; }
ok()   { printf '%sOK%s   %s\n' "$C_OK" "$C_OFF" "$1"; }
bad()  { printf '%sFAIL%s %s\n     -> %s\n' "$C_ERR" "$C_OFF" "$1" "$2"; T_OK=0; }
note() { printf '%sINFO%s %s\n' "$C_INFO" "$C_OFF" "$1"; }
core_done() { CORE_ALL=$((CORE_ALL+1)); [ "$T_OK" = 1 ] && CORE_OK=$((CORE_OK+1)); return 0; }

# repo_ok — репозиторий $REPO на месте
repo_ok() {
  if [ -d "$REPO" ] && g rev-parse --git-dir >/dev/null 2>&1; then return 0; fi
  bad "репозиторий $(basename "$REPO")/ на месте" "нет $REPO или это не git-репозиторий; соберите тренажёр: bash setup.sh"
  return 1
}
# have_commit HASH — объект из setup.sh на месте (значит, тренажёр собран именно им)
have_commit() { g cat-file -e "$1^{commit}" 2>/dev/null; }
not_ours() { bad "тренажёр собран setup.sh" "не нахожу исходные коммиты из setup.sh (другая сборка? core.autocrlf?); пересоберите: bash setup.sh --reset"; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
K=0
# extract REV — распаковать дерево коммита во временный каталог, напечатать его путь
extract() {
  K=$((K+1)); local d="$TMP/t$K"; mkdir -p "$d"
  g archive --format=tar "$1" 2>/dev/null | tar -xf - -C "$d" || return 1
  printf '%s' "$d"
}
# tests_at REV — запустить test.sh из коммита REV на копии; вывод в stdout, код как у test.sh
tests_at() {
  local d; d=$(extract "$1") || return 99
  ( cd "$d" && bash test.sh 2>/dev/null )
}
# failed_lines ВЫВОД — первые две строки FAIL из вывода test.sh
failed_lines() { printf '%s' "$1" | grep '^FAIL' | head -2 | tr '\n' ';' | sed 's/;$//'; }
# marks ВЫВОД — метки OK/FAIL из вывода test.sh одной строкой, например «OK FAIL»
marks() { printf '%s\n' "$1" | awk '$1 == "OK" || $1 == "FAIL" {printf "%s ", $1}' | sed 's/ $//'; }
touched() { g diff-tree --no-commit-id --name-only -r "$1" | tr '\n' ' ' | sed 's/ $//'; }
in_progress() { # merge/rebase/cherry-pick/revert не завершён
  local gd; gd=$(g rev-parse --git-dir)
  [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ] || [ -f "$gd/MERGE_HEAD" ] || \
  [ -f "$gd/CHERRY_PICK_HEAD" ] || [ -f "$gd/REVERT_HEAD" ]
}
# status_check [ВЕТКА] — ничего не висит в процессе, (стоим на ВЕТКЕ,) git status чист
status_check() {
  local want=${1:-} br text
  br=$(g symbolic-ref -q --short HEAD 2>/dev/null || echo "detached HEAD")
  if [ -n "$want" ]; then text="вы на ветке $want, git status чист"; else text="git status чист"; fi
  if in_progress; then
    bad "$text" "merge/rebase не завершён: git status скажет, что делать (--continue или --abort)"
  elif [ -n "$want" ] && [ "$br" != "$want" ]; then
    bad "$text" "сейчас: $br; git switch $want"
  elif [ -n "$(g status --porcelain 2>/dev/null)" ]; then
    bad "$text" "незакоммиченное или неотслеживаемое: $(g status --short | head -3 | tr '\n' ';' | sed 's/;$//')"
  else
    ok "$text"
  fi
}
# in_origin REV — коммит отправлен в origin (голый репозиторий undo-origin.git рядом)
in_origin() {
  if [ -d "$ROOT/undo-origin.git" ]; then
    git --no-pager -C "$ROOT/undo-origin.git" merge-base --is-ancestor "$1" main 2>/dev/null
  else
    g merge-base --is-ancestor "$1" origin/main 2>/dev/null
  fi
}
# my_reflog — записи reflog HEAD, сделанные не setup.sh (у него личность Course Bot)
my_reflog() { g log -g --format='%gn%x09%gs' HEAD 2>/dev/null | awk -F'\t' '$1 != "Course Bot" {print $2}'; }

echo "=== Проверка тренажёра недели 3: $ROOT ($(date +%F)) ==="

###############################################################################
check_task1() {
  task "1. Хирургический коммит (staging/)"
  REPO=$ROOT/staging; repo_ok || return
  have_commit "$STAGING_ROOT" || { not_ours; return; }
  local n root f1 f2 out1 out2 rc2 m1 m2
  root=$(g rev-list --max-parents=0 HEAD)
  n=$(g rev-list --count HEAD)
  if [ "$root" != "$STAGING_ROOT" ]; then
    bad "история растёт из коммита «topwords: first version»" "первый коммит не из setup.sh: пересоберите тренажёр (bash setup.sh --reset)"; return
  fi
  if [ "$n" = 3 ]; then
    ok "три коммита: исходный и два новых"
  else
    bad "три коммита: исходный и два новых" "сейчас в истории $n (git log --oneline); нужны ровно два коммита поверх исходного"; return
  fi
  if [ "$(touched HEAD~1)" = "topwords.py" ] && [ "$(touched HEAD)" = "topwords.py" ]; then
    ok "оба новых коммита меняют только topwords.py"
  else
    bad "оба новых коммита меняют только topwords.py" "HEAD~1 трогает: $(touched HEAD~1); HEAD трогает: $(touched HEAD)"
  fi
  f1=$(g show HEAD~1:topwords.py 2>/dev/null); f2=$(g show HEAD:topwords.py 2>/dev/null)
  if printf '%s' "$f1" | grep -q DEBUG; then
    bad "первый новый коммит — только исправление бага" "в HEAD~1 остались строки DEBUG: их не должно быть ни в одном коммите"
  elif printf '%s' "$f1" | grep -q 'sys.argv'; then
    bad "первый новый коммит — только исправление бага" "в HEAD~1 попала опция (sys.argv / limit); первый коммит — только регистр и знаки препинания (git reset --soft HEAD~2 и заново git add -p)"
  elif ! printf '%s' "$f1" | grep -q 'lower()'; then
    bad "первый новый коммит — только исправление бага" "в HEAD~1 нет исправления бага (ожидаю .lower() и re.findall в words())"
  else
    ok "первый новый коммит — только исправление бага (без опции и без DEBUG)"
  fi
  if printf '%s' "$f2" | grep -q DEBUG; then
    bad "второй новый коммит — опция числа слов" "в HEAD остались строки DEBUG"
  elif ! printf '%s' "$f2" | grep -q 'sys.argv'; then
    bad "второй новый коммит — опция числа слов" "в HEAD нет чтения аргумента (sys.argv)"
  else
    ok "второй новый коммит — опция числа слов (без DEBUG)"
  fi
  out1=$(tests_at HEAD~1); out2=$(tests_at HEAD); rc2=$?
  m1=$(marks "$out1"); m2=$(marks "$out2")
  if [ "$rc2" = 0 ] && [ "$m1" = "OK FAIL" ]; then
    ok "bash test.sh: на HEAD~1 OK FAIL, на HEAD OK OK"
  else
    bad "bash test.sh: на HEAD~1 OK FAIL, на HEAD OK OK" "на HEAD~1: ${m1:-нет вывода}; на HEAD: ${m2:-нет вывода}"
  fi
  status_check main
}

###############################################################################
check_task2() {
  task "2. Конфликт, дважды (conflict/)"
  REPO=$ROOT/conflict; repo_ok || return
  have_commit "$CONFLICT_FEATURE" && have_commit "$CONFLICT_MAIN" || { not_ours; return; }
  local want m p found="" good="" parent subj out
  want=$(printf '%s\n%s\n' "$CONFLICT_MAIN" "$CONFLICT_FEATURE" | sort | tr '\n' ' ')
  for m in $(g rev-list --merges --all --reflog 2>/dev/null); do
    p=$(g rev-parse "$m^1" "$m^2" | sort | tr '\n' ' ')
    [ "$p" = "$want" ] || continue
    found=$m
    if tests_at "$m" >/dev/null; then good=$m; break; fi
  done
  if [ -n "$good" ]; then
    ok "merge: merge-коммит feature -> main найден (${good:0:7}), тесты на нём проходят"
  elif [ -n "$found" ]; then
    bad "merge: merge-коммит feature -> main найден, тесты на нём проходят" "merge-коммит ${found:0:7} есть, но bash test.sh на нём не проходит: конфликт разрешён не до конца (median на пустом вводе?); повторите merge и перед откатом поставьте git tag merged"
  else
    bad "merge: merge-коммит feature -> main найден, тесты на нём проходят" "не вижу коммита с родителями «readme: empty input is fine» и «stats: add median»: на main выполните git merge feature, разрешите конфликт, закоммитьте и поставьте git tag merged, прежде чем откатывать"
  fi
  parent=$(g rev-parse -q --verify main~1 2>/dev/null); subj=$(g log -1 --format=%s main 2>/dev/null)
  if [ "$parent" = "$CONFLICT_MAIN" ] && [ "$subj" = "stats: add median" ]; then
    ok "rebase: main — прямая линия, «stats: add median» (новый хеш) поверх «readme: empty input is fine»"
  else
    bad "rebase: main — прямая линия, «stats: add median» поверх «readme: empty input is fine»" "сейчас вершина main: $(g log --oneline -1 main); ожидается переложенный коммит сразу над «readme: empty input is fine» (reset --hard ORIG_HEAD -> git switch feature -> git rebase main -> git switch main -> git merge feature)"
  fi
  if [ "$(g rev-parse main)" = "$(g rev-parse -q --verify feature)" ]; then
    ok "feature и main указывают на один коммит (fast-forward выполнен)"
  else
    bad "feature и main указывают на один коммит (fast-forward выполнен)" "после rebase: git switch main && git merge feature"
  fi
  out=$(tests_at main)
  if [ $? = 0 ]; then ok "bash test.sh на main: все пять проверок проходят"
  else bad "bash test.sh на main: все пять проверок проходят" "$(failed_lines "$out")"; fi
  status_check main
}

###############################################################################
check_task3() {
  task "3. Уборка в ветке (messy/)"
  REPO=$ROOT/messy; repo_ok || return
  have_commit "$MESSY_MAIN" || { not_ours; return; }
  if [ "$(g rev-parse -q --verify main)" != "$MESSY_MAIN" ]; then
    bad "main не трогали" "main должен остаться на «init: readme and tests»: git branch -f main $MESSY_MAIN"; return
  fi
  g rev-parse -q --verify feature >/dev/null 2>&1 || { bad "ветка feature существует" "ветки feature нет; если удалили — git reflog поможет её вернуть, иначе bash setup.sh --reset"; return; }
  if in_progress; then bad "rebase завершён" "rebase ещё идёт: git status подскажет (--continue или --abort)"; return; fi
  local n base h files bad_msgs=""
  n=$(g rev-list --count main..feature); base=$(g merge-base main feature)
  if [ "$base" = "$MESSY_MAIN" ] && [ "$n" = 3 ]; then
    ok "feature растёт из main и состоит из трёх коммитов"
  else
    bad "feature растёт из main и состоит из трёх коммитов" "сейчас коммитов в main..feature: $n (git log --oneline main..feature); нужно три: key=value, комментарии и пустые строки, README"
  fi
  if g log --format=%s main..feature | grep -qiE '^(wip|oops)'; then
    bad "сообщения осмысленные, без wip и oops" "в ветке ещё есть: $(g log --format=%s main..feature | grep -iE '^(wip|oops)' | tr '\n' ';' | sed 's/;$//')"
  else
    ok "сообщения осмысленные, без wip и oops"
  fi
  for h in $(g rev-list main..feature); do
    files=$(touched "$h")
    case "$files" in *" "*) bad_msgs="$bad_msgs ${h:0:7}: $files;" ;; esac
  done
  if [ -z "$bad_msgs" ]; then ok "каждый коммит меняет один файл"
  else bad "каждый коммит меняет один файл" "смешаны правки разных файлов:$bad_msgs README отдельно от парсера"; fi
  if [ "$(g rev-parse 'feature^{tree}')" = "$MESSY_TREE" ]; then
    ok "содержимое вершины feature не изменилось ни на байт"
  else
    bad "содержимое вершины feature не изменилось ни на байт" "файлы на вершине отличаются от исходных: git diff before-cleanup feature покажет, что разошлось (тег удалили? bash test.sh и глазами README/ini.py)"
  fi
  status_check
}

###############################################################################
check_task4() {
  task "4. Откат опубликованного коммита (undo/)"
  REPO=$ROOT/undo; repo_ok || return
  have_commit "$UNDO_CULPRIT" || { not_ours; return; }
  [ -d "$ROOT/undo-origin.git" ] || note "undo-origin.git рядом не найден: «отправлено в origin» проверяю по origin/main"
  local out
  if g merge-base --is-ancestor "$UNDO_CULPRIT" main 2>/dev/null; then
    ok "виновник d0c66ea остался в истории main (история не переписана)"
  else
    bad "виновник d0c66ea остался в истории main (история не переписана)" "main больше не содержит d0c66ea — был reset? верните: git reset --hard origin/main, затем git revert d0c66ea"
  fi
  REVERT=$(g log main --format=%H --grep="This reverts commit $UNDO_CULPRIT" 2>/dev/null | tail -1)
  [ -n "$REVERT" ] || REVERT=$(g log main --format=%H --grep='^Revert "stats: speed up mean' 2>/dev/null | tail -1)
  if [ -n "$REVERT" ]; then ok "в main есть коммит-revert виновника (${REVERT:0:7})"
  else bad "в main есть коммит-revert виновника" "git revert d0c66ea (сообщение оставить как есть)"; fi
  out=$(tests_at main)
  if [ $? = 0 ]; then ok "bash test.sh на main: все пять проверок проходят"
  else bad "bash test.sh на main: все пять проверок проходят" "$(failed_lines "$out")"; fi
  if [ -n "$REVERT" ] && in_origin "$REVERT"; then ok "revert отправлен в origin"
  else bad "revert отправлен в origin" "git push; проверка: git status -sb без [ahead]"; fi
}

###############################################################################
check_task5() {
  task "5. Вернуть удалённый файл (undo/)"
  REPO=$ROOT/undo; repo_ok || return
  have_commit "$UNDO_ROOT" || { not_ours; return; }
  local restore blob d
  restore=$(g log main --diff-filter=A --format=%H -- gen.py 2>/dev/null | head -1)
  blob=$(g rev-parse -q --verify main:gen.py 2>/dev/null)
  if [ -n "$restore" ] && [ "$restore" != "$UNDO_ROOT" ]; then
    ok "gen.py возвращён отдельным коммитом (${restore:0:7})"
  else
    restore=""
    bad "gen.py возвращён отдельным коммитом" "git log --oneline -- gen.py -> коммит удаления; git restore --source=<хеш>^ -- gen.py; git add, git commit"
  fi
  if [ "$blob" = "$UNDO_GEN_BLOB" ]; then
    ok "содержимое gen.py совпадает с тем, что было удалено"
  else
    bad "содержимое gen.py совпадает с тем, что было удалено" "файл отличается от версии из истории: доставайте его из родителя коммита удаления (<хеш>^), а не пишите заново"
  fi
  if [ -n "$blob" ]; then
    d=$(extract main)
    if [ "$( (cd "$d" && python3 gen.py 5 1 2>/dev/null) | wc -w | tr -d ' ')" = 5 ]; then
      ok "python3 gen.py 5 1 печатает пять чисел"
    else
      bad "python3 gen.py 5 1 печатает пять чисел" "запустите сами: python3 gen.py 5 1"
    fi
  fi
  if [ -n "$restore" ] && in_origin "$restore"; then ok "коммит с gen.py отправлен в origin"
  else bad "коммит с gen.py отправлен в origin" "git push"; fi
  if [ -f "$REPO/README.md" ] && [ -f "$REPO/test.sh" ] && [ -z "$(g status --porcelain -- README.md test.sh)" ]; then
    ok "README.md и test.sh на месте"
  else
    bad "README.md и test.sh на месте" "git status показывает их удалёнными и подсказывает команду восстановления (restore / restore --staged)"
  fi
}

###############################################################################
check_task6() {
  task "6. Отложить незаконченное (undo/)"
  REPO=$ROOT/undo; repo_ok || return
  have_commit "$UNDO_WIP" || { not_ours; return; }
  local log h s found=0
  if [ -z "$(g stash list 2>/dev/null)" ]; then ok "git stash list пуст"
  else bad "git stash list пуст" "в stash что-то осталось: git stash pop (или git stash drop)"; fi
  log=$(my_reflog)
  if printf '%s\n' "$log" | grep -q 'moving from main to wip' && printf '%s\n' "$log" | grep -q 'moving from wip to main'; then
    ok "переход main -> wip -> main есть в reflog"
  else
    bad "переход main -> wip -> main есть в reflog" "в git reflog нет ваших переключений на wip и обратно (записи setup.sh не считаются)"
  fi
  for h in $(g fsck --unreachable --no-progress 2>/dev/null | awk '$1 == "unreachable" && $2 == "commit" {print $3}'); do
    s=$(g log -1 --format=%s "$h" 2>/dev/null)
    case "$s" in "WIP on "*|"On "*) found=1; break ;; esac
  done
  if [ "$found" = 1 ]; then ok "git stash использовался (отложенный снимок найден среди объектов .git)"
  else bad "git stash использовался (отложенный снимок найден среди объектов .git)" "следов git stash нет: отложите правку (git stash), сходите на wip, вернитесь на main, git stash pop"; fi
}

###############################################################################
check_task7() {
  task "7. Чистый status: .gitignore (undo/)"
  REPO=$ROOT/undo; repo_ok || return
  have_commit "$UNDO_ROOT" || { not_ours; return; }
  local src
  if g cat-file -e main:.gitignore 2>/dev/null; then ok ".gitignore закоммичен в main"
  else bad ".gitignore закоммичен в main" "создайте .gitignore со строкой out/ в корне репозитория, git add, git commit"; fi
  src=$(g check-ignore -v out/actual.txt 2>/dev/null | cut -d: -f1)
  if [ "$src" = ".gitignore" ]; then ok "out/actual.txt игнорируется правилом из .gitignore репозитория"
  else bad "out/actual.txt игнорируется правилом из .gitignore репозитория" "git check-ignore -v out/actual.txt молчит${src:+ (или ссылается на $src)}: нужна строка out/ в .gitignore в корне репозитория"; fi
  if [ -d "$ROOT/undo-origin.git" ] && git --no-pager -C "$ROOT/undo-origin.git" cat-file -e main:.gitignore 2>/dev/null; then
    ok ".gitignore отправлен в origin"
  elif [ ! -d "$ROOT/undo-origin.git" ] && g cat-file -e origin/main:.gitignore 2>/dev/null; then
    ok ".gitignore отправлен в origin"
  else
    bad ".gitignore отправлен в origin" "git push"
  fi
  status_check main
}

###############################################################################
check_bonus1() {
  task "B1. Бинарный поиск по истории (bisect/) — bonus"
  REPO=$ROOT/bisect
  if ! { [ -d "$REPO" ] && g rev-parse --git-dir >/dev/null 2>&1; }; then note "каталога bisect/ нет"; return; fi
  local log="$REPO/bisect.log" steps
  if [ ! -f "$log" ]; then note "bisect.log не найден: перед git bisect reset сохраните журнал — git bisect log > bisect.log"; return; fi
  B1="нет"
  if grep -q "first bad commit: \[$BISECT_CULPRIT\]" "$log"; then
    steps=$(( $(grep -cE '^# (good|bad): ' "$log") - 2 ))   # первые две пометки — границы, остальные — шаги
    ok "bisect.log: виновник d1169f1 (day 23), шагов: $steps"
  else
    bad "bisect.log: виновник d1169f1 (day 23)" "в журнале нет строки «first bad commit: [d1169f1...]»; доведите bisect до конца и сохраните журнал заново"
    return
  fi
  if [ -f "$(g rev-parse --git-path BISECT_LOG)" ]; then
    bad "бисекция завершена" "репозиторий всё ещё в режиме bisect: git bisect reset"
  else
    ok "бисекция завершена (git bisect reset)"
  fi
  [ "$T_OK" = 1 ] && B1="да"
}

###############################################################################
check_bonus2() {
  task "B2. Машина времени (undo/) — bonus"
  REPO=$ROOT/undo
  if ! { [ -d "$REPO" ] && g rev-parse --git-dir >/dev/null 2>&1; }; then note "каталога undo/ нет"; return; fi
  local log wip_n
  log=$(my_reflog)
  wip_n=$(g reflog show wip 2>/dev/null | wc -l | tr -d ' ')
  if ! printf '%s\n' "$log" | grep -q 'reset: moving to HEAD~3' && [ "$wip_n" != 1 ]; then
    note "не делали (в reflog нет reset --hard HEAD~3, ветка wip не пересоздавалась)"; return
  fi
  B2="нет"
  if printf '%s\n' "$log" | grep -q 'reset: moving to HEAD~3' && printf '%s\n' "$log" | grep -A999 'reset: moving to HEAD~3' | grep -q .; then
    if printf '%s\n' "$log" | grep -B999 'reset: moving to HEAD~3' | grep -qE 'reset: moving to (HEAD@\{[0-9]+\}|[0-9a-f]{7,})'; then
      ok "reset --hard HEAD~3 и возврат через reflog есть в истории HEAD"
    else
      bad "reset --hard HEAD~3 и возврат через reflog есть в истории HEAD" "после reset не видно возврата (git reset --hard HEAD@{1} или по хешу из git reflog)"
    fi
  else
    bad "reset --hard HEAD~3 и возврат через reflog есть в истории HEAD" "в git reflog нет записи «reset: moving to HEAD~3»"
  fi
  if [ "$(g rev-parse -q --verify wip 2>/dev/null)" = "$UNDO_WIP" ] && [ "$wip_n" = 1 ] && g reflog show wip | grep -q 'branch: Created from'; then
    ok "ветка wip удалена и воскрешена из reflog на тот же коммит"
  elif [ "$(g rev-parse -q --verify wip 2>/dev/null)" != "$UNDO_WIP" ]; then
    bad "ветка wip удалена и воскрешена из reflog на тот же коммит" "wip нет или она не на «stats: histogram experiment»: хеш найдётся в git reflog, затем git branch wip <хеш>"
  else
    bad "ветка wip удалена и воскрешена из reflog на тот же коммит" "wip на месте, но её не удаляли (git branch -D wip, затем воскресить по reflog)"
  fi
  [ "$T_OK" = 1 ] && B2="да"
}

check_task1; core_done
check_task2; core_done
check_task3; core_done
check_task4; core_done
check_task5; core_done
check_task6; core_done
check_task7; core_done
check_bonus1
check_bonus2

echo
echo "Итог: core $CORE_OK/$CORE_ALL задач; bonus: B1 $B1, B2 $B2"
if [ "$CORE_OK" -eq "$CORE_ALL" ]; then
  echo "Тренажёр пройден. Зачёт по задачам 1–7 снимается с ~/git-practice на сервере курса."
else
  echo "Под каждым FAIL написано, что не так. После правок запустите проверку снова."
fi
[ "$CORE_OK" -eq "$CORE_ALL" ]
