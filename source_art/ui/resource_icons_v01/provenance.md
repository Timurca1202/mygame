# Пиксельные значки верхней полосы — v30

Автор попросил найти навык для готовых иконок вместо подписей ресурсов, затем одобрил их добавление. Через find-skills найден Better Icons (better-auth/better-icons), работающий с Iconify. Навык/CLI не устанавливался: в среде отсутствует npx, а для добавления готовых SVG в Godot установка не требуется.

Первоначально проверена коллекция Pixelarticons: API вернул четыре подходящие иконки, но gem/diamond отсутствуют. Чтобы все пять символов принадлежали одному набору, использована **Streamline Pixel / Pixel free icons** от Streamline через Iconify API. Это готовые SVG, не сгенерированные изображения и не emoji.

Источник автора: https://github.com/webalys-hq/streamline-vectors

Сайт автора: https://www.streamlinehq.com/

Коллекция: `streamline-pixel`, размер 32×32, лицензия CC BY 4.0: https://creativecommons.org/licenses/by/4.0/

| Файл в assets/ui/icons/resources/ | Исходный ID |
|---|---|
| balance.svg | streamline-pixel:business-money-coin-currency |
| followers.svg | streamline-pixel:multiple-user |
| level.svg | streamline-pixel:social-rewards-rating-star-1 |
| energy.svg | streamline-pixel:interface-essential-flash |
| gems.svg | streamline-pixel:money-payments-diamond |

Исходные тела SVG и метаданные сохранены в `iconify_selected.json`. Для Godot заменён только `currentColor` на белый; цвета применяются через `self_modulate` в существующей палитре HUD. Геометрия не менялась. Иконки загружаются локально, без сетевых запросов во время игры, в размере 32×32 с nearest-фильтрацией. Копия атрибуции размещена с ассетами: `assets/ui/icons/resources/ATTRIBUTION.txt`. При последующей подготовке распространяемой сборки этот кредит должен сохраняться в доступных игроку сведениях об авторах.

Подписи ресурсов убраны из строки; числа и XP остаются. Имена ресурсов сохранены в tooltip и accessibility_name. «Скоро» у энергии и алмазов сохранено: эти механики не реализованы. Логика экономики, сохранения и композиция комнаты не менялись.
