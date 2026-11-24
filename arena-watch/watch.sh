#!/usr/bin/env bash
# Прослушка origin/main для Monitor: каждая строка stdout = событие для агента.
# Молчит, пока main не изменился. Использование: watch.sh <путь-к-репо> [интервал-сек]
repo="${1:-.}"; interval="${2:-60}"
cd "$repo" 2>/dev/null || { echo "WATCH-ERROR: нет каталога $repo"; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "WATCH-ERROR: $repo не git-репозиторий"; exit 1; }

# База — локальная ветка main (не HEAD: агент может сидеть в bot/<тема>).
last=$(git rev-parse main 2>/dev/null) || { echo "WATCH-ERROR: нет локальной ветки main"; exit 1; }
fails=0
echo "WATCH-START main=${last:0:7} interval=${interval}s"

while true; do
  if git fetch -q origin main 2>/dev/null; then
    fails=0
    cur=$(git rev-parse origin/main)
    if [ "$cur" != "$last" ]; then
      echo "NEW origin/main ${last:0:7}..${cur:0:7}"
      git log --oneline "$last..$cur" 2>/dev/null | sed 's/^/  commit /'
      git diff --name-status "$last" "$cur" 2>/dev/null | sed 's/^/  file /'
      last=$cur
    fi
  else
    fails=$((fails+1))
    # Одно предупреждение на серию сбоев, без спама.
    [ "$fails" -eq 5 ] && echo "WATCH-WARN: git fetch падает 5 раз подряд (сеть/доступ)"
  fi
  sleep "$interval"
done
