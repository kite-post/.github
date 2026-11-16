#!/usr/bin/env bash
# Заливає каркас організації на GitHub: репозиторій .github і чотири шаблони.
# Запускається один раз, з каталогу, де лежать усі п'ять клонів:
#
#   dev/kite/
#     .github/                  ← цей репозиторій
#     template-java-service/
#     template-go-service/
#     template-python-service/
#     template-vue-app/
#
#   ORG=kite-post bash .github/scripts/push-scaffold.sh
#
# Репозиторії публічні: на плані Free приватні дають лише 2000 хвилин Actions
# на місяць і 500 МБ сховища пакетів, а 27 репозиторіїв з образами на кожен
# коміт у це не влазять. Закрити все: VISIBILITY=private.
#
# Повторний запуск безпечний: наявні репозиторії не перестворюються, пушиться
# лише те, що змінилося.
set -euo pipefail

ORG="${ORG:-kite-post}"
VISIBILITY="${VISIBILITY:-public}"

command -v gh >/dev/null 2>&1 || { echo "Потрібен gh CLI." >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Спершу: gh auth login" >&2; exit 1; }

if ! gh api "orgs/$ORG" >/dev/null 2>&1; then
  cat >&2 <<MSG
Організації '$ORG' не видно. Створи її вручну — GitHub не дає створювати
організації через API:

  https://github.com/organizations/plan   (план Free)

Потім запусти цей скрипт знову.
MSG
  exit 1
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo "Каталог: $root"
echo "Організація: $ORG ($VISIBILITY)"
echo

push_repo() {
  local dir="$1" repo="$2" desc="$3" is_template="$4"
  local path="$root/$dir"

  [ -d "$path" ] || { echo "⚠ немає каталогу $path — пропускаю"; return 0; }
  echo "── $repo ──"
  cd "$path"

  if [ ! -d .git ]; then
    git init -q -b main
  fi
  git add -A
  if ! git diff --cached --quiet; then
    git commit -q -m "Каркас: $repo"
  fi

  if gh repo view "$ORG/$repo" >/dev/null 2>&1; then
    echo "репозиторій уже є"
  else
    gh repo create "$ORG/$repo" "--$VISIBILITY" --description "$desc"
  fi

  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "https://github.com/$ORG/$repo.git"
  fi
  git branch -M main
  git push -u origin main

  if [ "$is_template" = "template" ]; then
    gh api -X PATCH "repos/$ORG/$repo" -F is_template=true >/dev/null
    echo "позначено як Template"
  fi
  echo
}

push_repo ".github" ".github" \
  "Спільні reusable-workflow і шаблони репозиторіїв Kite" "plain"
push_repo "template-java-service" "template-java-service" \
  "Шаблон Java-сервіса Kite: Spring Boot 3, Java 21" "template"
push_repo "template-go-service" "template-go-service" \
  "Шаблон Go-сервіса Kite" "template"
push_repo "template-python-service" "template-python-service" \
  "Шаблон Python-сервіса Kite: FastAPI" "template"
push_repo "template-vue-app" "template-vue-app" \
  "Шаблон веб-застосунку Kite: Vue 3, Vite, TypeScript, pnpm" "template"

cd "$root/.github"

echo "── доступ до спільних workflow ──"
# Приватний репозиторій за замовчуванням не дає іншим репо викликати свої
# workflow і actions. Без цього CI кожного сервіса падає ще на кроці
# «не можу знайти kite-post/.github/...».
if gh api -X PUT "repos/$ORG/.github/actions/permissions/access" \
     -f access_level=organization >/dev/null 2>&1; then
  echo "workflow з .github доступні всім репозиторіям організації"
else
  echo "⚠ не вдалося відкрити доступ автоматично. Зроби вручну:"
  echo "   github.com/$ORG/.github → Settings → Actions → General →"
  echo "   Access → Accessible from repositories in the '$ORG' organization"
fi
echo

echo "── тег v1 для спільних workflow ──"
git tag -f v1
git push -f origin v1
echo "Тепер у ci.yml можна писати '@v1' замість '@main'."
echo

cat <<MSG
Готово. Далі:

1. Секрети організації (Settings → Secrets → Actions):
     INFRA_BUMP_TOKEN      щоб CI відкривав PR з версією в kite-infra
     TEMPLATE_SMOKE_TOKEN  щоб працював дим-тест шаблонів
   Обидва — fine-grained PAT; без них CI працює, просто без цих кроків.

2. Перший сервіс:
     bash .github/scripts/new-repo.sh shipment-service java

3. Перевірити, що шаблон проходить CI без правок:
     gh workflow run dispatch-template-smoke.yml -R $ORG/.github \\
       -f template=template-java-service
MSG
