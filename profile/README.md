<p align="center">
  <img src="https://raw.githubusercontent.com/kite-post/kite-docs/main/logo.svg" width="96" alt="Kite">
</p>

<h1 align="center">Kite</h1>

<p align="center">Поштова система: накладні, мережа відділень і Kite Box, сортування, доставка, відстеження.</p>

---

Код живе в окремих репозиторіях — по одному на сервіс, застосунок і бібліотеку.
Збирає все докупи не код, а готові образи: оркестратор `kite-infra` тягне їх
із GitHub Container Registry за закріпленими тегами.

| Почати з                                                     | Що там                                            |
| ------------------------------------------------------------ | ------------------------------------------------- |
| [kite-docs](https://github.com/kite-post/kite-docs)           | Документація системи і ADR                        |
| [kite-infra](https://github.com/kite-post/kite-infra)         | Стенд: compose з профілями, сид, `make up`        |
| [kite-contracts](https://github.com/kite-post/kite-contracts) | OpenAPI і JSON Schema подій, генератори клієнтів  |
| [.github](https://github.com/kite-post/.github)               | Спільні reusable-workflow і шаблони репозиторіїв  |

Стек: Java 21 / Spring Boot 3, Go, Python / FastAPI, Vue 3, Flutter.
Транспорт: REST за шлюзом, Kafka для доменних подій, MQTT для пристроїв.
