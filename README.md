# .github — спільний каркас репозиторіїв Kite

Тут лежить те, що не має копіюватися з репозиторію в репозиторій: пайплайни,
кроки збірки образів і шаблони. Правка в одному місці змінює збірку всім
27 репозиторіям (5.6, 12.6).

```
.github/workflows/      reusable-workflow: по одному на тип репозиторію
actions/                спільні кроки: збірка образу, bump версії в kite-infra
scripts/                бутстрап організації і створення нових репозиторіїв
workflow-templates/     стартові пайплайни для «New workflow» в UI
.github/ISSUE_TEMPLATE/ шаблони issue організації
profile/README.md       сторінка організації
```

## Скрипти

```bash
# один раз: залити каркас і чотири шаблони, поставити тег v1
ORG=kite-post bash scripts/push-scaffold.sh

# щоразу, коли потрібен новий сервіс
bash scripts/new-repo.sh shipment-service java
bash scripts/new-repo.sh scan-service     go
bash scripts/new-repo.sh ai-service       python
bash scripts/new-repo.sh kite-web         vue
```

`new-repo.sh` створює репозиторій з потрібного шаблону, проганяє в ньому
`rename.sh` (артефакт, пакет, ім'я образу), виставляє опис і вимикає зайве.
Після нього CI уже біжить, і правити руками нічого не треба.

Репозиторії створюються публічними. Причина прозаїчна: на плані Free приватні
репозиторії мають 2000 хвилин Actions на місяць і 500 МБ сховища пакетів, а в
нас 27 репозиторіїв, і кожен коміт у `main` публікує новий образ — один тільки
Java-образ займає понад 300 МБ. Для публічних і хвилини, і сховище безлімітні.
Закрити все: `VISIBILITY=private bash scripts/new-repo.sh …`.

## Як підключити пайплайн

У репозиторії сервіса — один файл `.github/workflows/ci.yml`:

```yaml
name: ci
on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
  workflow_dispatch:
jobs:
  ci:
    uses: kite-post/.github/.github/workflows/java-service.yml@main
    permissions:
      contents: read
      packages: write
    secrets: inherit
```

Більше нічого в репозиторії сервіса про CI не знає. Для Go, Python і Vue —
те саме з `go-service.yml`, `python-service.yml`, `vue-app.yml`.

> `@main` ставимо на час бутстрапу. Коли каркас усталиться, краще закріпитися
> за тегом: `git tag -f v1 && git push -f origin v1`, і далі `…@v1`.

## Що робить пайплайн

| Крок                 | Java                     | Go                             | Python              | Vue                        |
| -------------------- | ------------------------ | ------------------------------ | ------------------- | -------------------------- |
| Лінт                 | `spotless:check`         | `gofmt`, `golangci-lint`, `vet` | `ruff`              | `eslint`                   |
| Типи                 | —                        | —                              | `mypy`              | `vue-tsc`                  |
| Схеми kite-contracts | `make contracts-check`   | те саме                        | те саме             | —                          |
| Тести                | Maven + Testcontainers   | `go test -race`                | `pytest`            | `vitest`                   |
| Образ                | `ghcr.io/kite-post/<ім'я сервіса>` | те саме             | те саме             | статика в nginx            |
| Версія               | PR у `kite-infra` → `versions.env` | те саме            | те саме             | те саме                    |

Крок зі схемами спрацьовує лише тоді, коли в `Makefile` репозиторію є ціль
`contracts-check`; інакше його тихо пропускають. Так кожен сервіс сам вирішує,
коли підключити `kite-contracts`, і CI не падає в репозиторії, який ще не
встиг цього зробити.

Maven-пакет `ua.kite:kite-contracts` лежить у GitHub Packages, а він віддає
Maven лише з токеном. Окремого секрета для цього не треба: `java-service.yml`
сам розставляє `settings.xml` із вбудованим `GITHUB_TOKEN` — і для тестів, і
для збірки образу, куди токен їде секретом BuildKit, а не аргументом збірки.

## Видимість образів

Образи в GHCR створюються приватними — навіть у публічного репозиторію. Це
окрема від репозиторію настройка, і REST API її не змінює. Тому після першої
публікації образу кожного сервіса треба один раз відкрити

```
https://github.com/orgs/kite-post/packages/container/<сервіс>/settings
```

і поставити Public. Інакше образи йдуть у 500 МБ приватного сховища плану Free,
а цього вистачає приблизно на два Java-образи.

## Теги образів

Кожна збірка з `main` → `sha-<короткий хеш>`; реліз за тегом `v1.2.3` → `v1.2.3`.
Рухомого `latest` немає принципово: compose у `kite-infra` використовує лише
закріплені теги, інакше стенд щоразу піднімається різним (12.6).

На pull request образ **збирається, але не публікується** — Dockerfile ламається
так само часто, як код, і дізнатися про це краще до мерджу.

## Входи reusable-workflow

Усі входи необов'язкові; типові значення підібрані так, щоб шаблонний
репозиторій проходив CI без правок.

| Вхід                | Типово             | Для чого                                              |
| ------------------- | ------------------ | ----------------------------------------------------- |
| `service-name`      | ім'я репозиторію   | Якщо ім'я образу не дорівнює імені репозиторію        |
| `java-version` / `go-version` / `python-version` / `node-version` | `21` / з `go.mod` / `3.12` / `22` | Версія тулчейна |
| `dockerfile`        | `Dockerfile`       | Нетиповий шлях                                        |
| `context`           | `.`                | Нетиповий контекст збірки                             |
| `publish`           | `true`             | Вимкнути публікацію образу (бібліотеки, прототипи)    |
| `integration-tests` | `true`             | Вимкнути важкі тести з Testcontainers                 |
| `bump-infra`        | `true`             | Не чіпати `versions.env` у `kite-infra`               |
| `main-branch`       | `main`             | Гілка, збірка з якої вважається деплоєм на стенд      |
| `runs-on`           | `ubuntu-latest`    | Свій раннер                                           |

## Секрети організації

| Секрет                 | Потрібен для                                             | Без нього                        |
| ---------------------- | -------------------------------------------------------- | -------------------------------- |
| `INFRA_BUMP_TOKEN`     | PR з новою версією в `kite-infra`                        | Крок тихо пропускається          |
| `NPM_READ_TOKEN`       | Читання `@kite/ui` з GitHub Packages поза організацією   | Беруть вбудований `GITHUB_TOKEN` |
| `TEMPLATE_SMOKE_TOKEN` | Дим-тест шаблонів (створює і видаляє тимчасове репо)     | Дим-тест недоступний             |

Образи й пакети публікуються вбудованим `GITHUB_TOKEN` — окремий секрет для
GHCR не потрібен.

## Шаблони репозиторіїв

| Шаблон                     | Для чого                          |
| -------------------------- | --------------------------------- |
| `template-java-service`    | 12 Java-сервісів                  |
| `template-go-service`      | 5 Go-сервісів і емуляторів        |
| `template-python-service`  | `ai-service`, `simulator`         |
| `template-vue-app`         | 4 Vue-застосунки                  |

GitHub не вміє тримати шаблон репозиторію всередині іншого репозиторію, тому
шаблони — окремі репозиторії з прапорцем «Template». Новий сервіс:

```bash
gh repo create kite-post/shipment-service --public --template kite-post/template-java-service
cd shipment-service && make rename NAME=shipment-service
```

`make rename` перейменовує артефакт, пакет і ім'я образу. Без нього репозиторій
теж збирається і проходить CI — просто під іменем шаблону.

## Перевірити, що шаблон не зіпсований

```bash
gh workflow run dispatch-template-smoke.yml -R kite-post/.github -f template=template-java-service
```

Створює тимчасовий приватний репозиторій із шаблону, чекає на його CI, показує
висновок і видаляє репозиторій. Це і є критерій «новий репозиторій з шаблону
проходить CI без правок руками».
