#!/usr/bin/env python3
import json

with open('data/art/reference_asset_catalog.json', 'r', encoding='utf-8') as f:
    cat = json.load(f)

lines = [
    "# Hypster — Пакет подготовленных ассетов для Codex (Handoff)",
    "",
    f"> **Статус:** подготовлено {len(cat['assets'])} PNG; READY: {sum(a['status'] == 'READY' for a in cat['assets'])}, PROBLEMATIC: {sum(a['status'] == 'PROBLEMATIC' for a in cat['assets'])}, UNREVIEWED: {sum(a['status'] == 'UNREVIEWED' for a in cat['assets'])}. Техническая проверка не заменяет визуальную приёмку.",
    "> **Формат:** 32-bit RGBA PNG с прозрачностью. Проверка границ и цветов не обнаруживает все подписи, линии сетки, повреждённые детали и посторонние предметы.",
    "> **Ключевое правило проекта:** `iFone 2G` сохранён строго в исходной ориентации референса (**без горизонтального отражения**).",
    "",
    "## 1. Сводка и обзорные листы",
    "",
    "- **Машиночитаемый мастер-каталог (JSON):** `data/art/reference_asset_catalog.json`",
    "- **Обзорный лист декора (70 предметов):** `assets/art/overview_decor_sheet_v01.png`",
    "- **Обзорный лист техники и устройств (19 предметов):** `assets/art/overview_devices_sheet_v01.png`",
    "- **Полный контактный лист (89 предметов):** `assets/art/overview_master_sheet_v01.png`",
    "- **Исходные маски и происхождение:** `source_art/<категория>/<ассет>/mask.png` и `provenance.json`",
    "",
    "---",
    "",
    "## 2. Особые случаи и ограничения (Правило 4: Не додумывать скрытые части)",
    "",
    "1. **Стопка журналов с ретро-консолью (`magazines_with_console`, код `S2_S3`):**",
    "   - *Референс:* `ref/items/Unknown-3.webp`, ячейки S2 и S3.",
    "   - *Ограничение:* В оригинальном пиксель-арте консоль S3 физически стоит поверх стопки журналов S2 как единая монолитная связка.",
    "   - *Решение:* Согласно правилу 4, скрытые части не дорисовывались. Сохранён аутентичный составной игровой проп `assets/art/decor/magazines_with_console.png`.",
    "",
    "2. **iFone 2G и опорная кружка (`ifone_2g_ref` и `ifone_2g_with_mug_support_ref`):**",
    "   - *Референс:* `ref/device/Main/Gemini_Generated_Image_tjhcjitjhcjitjhc.jpg` (ряд 1, предмет 2).",
    "   - *Ограничение:* В оригинальном концепте телефон опирается на керамическую кружку.",
    "   - *Решение:* `ifone_2g_ref.png` ошибочно назван изолированным: он содержит кружку, зеркало и линию листа. Статус PROBLEMATIC. Составной `ifone_2g_with_mug_support_ref.png` также требует приёмки. Утверждённый игровой спрайт `assets/art/equipment/ifone_2g_v01.png` не заменён.",
    "",
    "---",
    "",
    "## 3. Полный реестр ассетов «Референс → Ассет»",
    "",
    "| Код | Название файла | Путь к PNG | Исходный референс | Разрешение | Статус | Примечания и ограничения |",
    "|---|---|---|---|---|---|---|"
]

for a in cat['assets']:
    rel_path = f"assets/art/{a['category']}/{a['id']}.png"
    code = a['code']
    fname = f"{a['id']}.png"
    src = a['source_reference']
    res = a['resolution']
    status = a['status']
    notes = a['notes']
    lines.append(f"| `{code}` | `{fname}` | `{rel_path}` | `{src}` | {res} | **{status}** | {notes} |")

with open('docs/art/reference_asset_handoff_codex.md', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines) + '\n')

print("docs/art/reference_asset_handoff_codex.md successfully generated.")
