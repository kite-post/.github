#!/usr/bin/env bash
# Створює репозиторій сервіса з шаблону і перейменовує в ньому шаблонні імена.
#
#   bash scripts/new-repo.sh shipment-service java
#   bash scripts/new-repo.sh scan-service     go
#   bash scripts/new-repo.sh ai-service       python
#   bash scripts/new-repo.sh kite-web         vue
#
# Після цього репозиторій одразу проходить CI: нічого правити руками не треба.
set -euo pipefail

name="${1:-}"
kind="${2:-}"
ORG="${ORG:-kite-post}"
VISIBILITY="${VISIBILITY:-private}"

if [ -z "$name" ] || [ -z "$kind" ]; then
  echo "Використання: $0 <ім'я-репозиторію> <java|go|python|vue>" >&2
  exit 1
fi

case "$kind" in
  java)   template="template-java-service" ;;
  go)     template="template-go-service" ;;
  python) template="template-python-service" ;;
  vue)    template="template-vue-app" ;;
  *) echo "Тип має бути java, go, python або vue." >&2; exit 1 ;;
esac

command -v gh >/dev/null 2>&1 || { echo "Потрібен gh CLI." >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Спершу: gh auth login" >&2; exit 1; }

echo "Створюю $ORG/$name з $ORG/$template"
gh repo create "$ORG/$name" "--$VISIBILITY" --template "$ORG/$template" --clone
cd "$name"

if [ -f scripts/rename.sh ]; then
  echo "Перейменовую шаблонні імена на $name"
  ORG="$ORG" bash scripts/rename.sh "$name"
  git add -A
  git commit -q -m "Перейменувати шаблон у $name"
  git push -q
fi

# Образ публікується сюди, тож нехай це буде видно одразу в описі репозиторію.
gh repo edit "$ORG/$name" \
  --description "Kite · $name · образ ghcr.io/$ORG/$name" \
  --enable-issues --enable-projects=false --enable-wiki=false \
  --delete-branch-on-merge >/dev/null

gh api -X PUT "repos/$ORG/$name/branches/main/protection" \
  --input - >/dev/null 2>&1 <<'JSON' || echo "⚠ захист гілки не ввімкнувся (потрібен платний план для приватних репо)"
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON

echo
echo "Готово: https://github.com/$ORG/$name"
echo "CI уже запустився — подивитися: gh run watch -R $ORG/$name"
