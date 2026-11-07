# Структура и границы систем

Корень этой папки является корнем проекта Godot (`res://`). Структура основана на §14 GDD, с отдельным каталогом сцен.

## Представление и логика

| Система | Сцены | Код | Данные |
|---|---|---|---|
| Запуск и состояние | `scenes/app/` | `src/core/` | — |
| Комната, слоты и декор | `scenes/room/` | `src/room/` | `data/items/decor/` |
| Герой и NPC | `scenes/characters/` | `src/characters/` | `data/dialogues/`, `data/items/clothes/` |
| Стрим, нагрев, чат, донаты | `scenes/stream/` | `src/stream/` | `data/chat/` |
| Дневной цикл | `scenes/locations/` | `src/day/` | `data/events/` |
| Экономика | — | `src/economy/` | `data/economy/`, `data/items/` |
| Прогрессия | — | `src/progression/` | `data/progression/`, `data/achievements/` |
| События | — | `src/events/` | `data/events/` |
| Экраны и компоненты UI | `scenes/ui/` | `src/ui/` | `data/localization/` |
| Платформенные интеграции | — | `src/services/` | — |

Это границы будущей реализации, а не список уже работающих систем. Глобальные autoload-сервисы пока не зарегистрированы.

## Графика

- `assets/art/rooms/`: отдельные каталоги пяти стадий комнаты.
- `assets/art/devices/`: телефоны, ноутбуки, настольные компьютеры.
- `assets/art/equipment/`: камеры, микрофоны, свет.
- `assets/art/characters/`: герой и NPC.
- `assets/art/ui/`: иконки и темы интерфейса.
- `assets/art/atlases/`, `assets/art/fx/`: атласы и эффекты.
- `source_art/`: исходники редакторов; `ref/`: неизменяемые референсы.

## Документация и инструменты

- `docs/decisions/`: принятые технические решения с причиной и последствиями.
- `docs/art/`: визуальные требования и учёт ассетов.
- `docs/balance/`: расчёты; `docs/production/`: этапы и приёмка.
- `tools/balance/`, `tools/import/`, `tools/validation/`: инструменты при появлении соответствующих задач.
- `tests/unit/`, `tests/integration/`, `tests/fixtures/`: тесты при реализации систем; фреймворк пока не выбран.

Не помещать сохранения игрока в каталоги проекта: для них используется `user://`.

## Реализованный прототип стрима

`src/stream/stream_session.gd` — независимая симуляция эфира; `data/stream/prototype.json` — параметры и строки первого русского интерфейса. `scenes/ui/stream_prototype.tscn` и `src/ui/stream_prototype.gd` подключены к главной сцене через CanvasLayer. Новые autoload-сервисы не требуются. Проверки находятся в `tests/stream/`, описание границ прототипа — `docs/production/stream_prototype.md`.
