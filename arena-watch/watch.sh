#!/usr/bin/env bash
# Прослушка ВСЕХ веток origin для Monitor: каждая строка stdout = событие для агента.
# Молчит, пока ни одна ветка не изменилась. Использование: watch.sh <путь-к-репо> [интервал-сек]
# Архитектор может положить задачу и в main, и в bot/<тема> — поэтому слушаем все ветки.
repo="${1:-.}"; interval="${2:-60}"
cd "$repo" 2>/dev/null || { echo "WATCH-ERROR: нет каталога $repo"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "WATCH-ERROR: $repo не git-репозиторий"; exit 1; }

# Снимок: "origin/<ветка> <sha>" по всем удалённым веткам, без origin/HEAD.
snap() { git for-each-ref --format='%(refname:short) %(objectname)' refs/remotes/origin | grep -v '^origin/HEAD \|^origin ' | sort; }

git fetch -q --prune origin 2>/dev/null
prev=$(snap)
fails=0
echo "WATCH-START branches=$(printf '%s\n' "$prev" | grep -c .) interval=${interval}s"

while true; do
  sleep "$interval"
  if git fetch -q --prune origin 2>/dev/null; then
    fails=0
    cur=$(snap)
    if [ "$cur" != "$prev" ]; then
      # Строки, которых не было в прошлом снимке = новые или сдвинутые ветки.
      comm -13 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur") | while read -r ref sha; do
        old=$(printf '%s\n' "$prev" | awk -v r="$ref" '$1==r{print $2}')
        if [ -n "$old" ]; then
          echo "NEW $ref ${old:0:7}..${sha:0:7}"
          git log --oneline "$old..$sha" 2>/dev/null | sed 's/^/  commit /'
          git diff --name-status "$old" "$sha" 2>/dev/null | sed 's/^/  file /'
        else
          echo "NEW-BRANCH $ref ${sha:0:7}"
          git log --oneline -5 "origin/main..$sha" 2>/dev/null | sed 's/^/  commit /'
        fi
      done
      comm -23 <(printf '%s\n' "$prev" | awk '{print $1}') <(printf '%s\n' "$cur" | awk '{print $1}') | sed 's/^/GONE /'
      prev=$cur
    fi
  else
    fails=$((fails+1))
    [ "$fails" -eq 5 ] && echo "WATCH-WARN: git fetch падает 5 раз подряд (сеть/доступ)"
  fi
done
