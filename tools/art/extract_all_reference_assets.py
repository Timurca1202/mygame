#!/usr/bin/env python3
import os, sys, subprocess, struct, json
from asset_preparation_engine import (
    load_bmp, save_png, extract_pixel_art_cell, extract_device_item,
    is_pixel_art_bg_or_grid
)

# Convert all reference sheets to /tmp bitmaps if not already present
SHEETS = {
    "u2": "ref/items/Unknown-2.webp",
    "u3": "ref/items/Unknown-3.webp",
    "u4": "ref/items/Unknown-4.webp",
    "u5": "ref/items/Unknown-5.webp",
    "u6": "ref/items/Unknown-6.webp",
    "u7": "ref/items/Unknown-7.webp",
    "main_dev": "ref/device/Main/Gemini_Generated_Image_tjhcjitjhcjitjhc.jpg",
    "wind_dev": "ref/device/wind/Gemini_Generated_Image_z1lscpz1lscpz1ls-2.jpg",
    "mic_dev": "ref/device/microphone/Gemini_Generated_Image_84hlag84hlag84hl.jpg",
    "light_dev": "ref/device/light/Gemini_Generated_Image_phzj9aphzj9aphzj.jpg"
}

print("Converting source sheets to BMP via sips...")
for key, src_path in SHEETS.items():
    bmp_path = f"/tmp/{key}.bmp"
    if not os.path.exists(bmp_path):
        subprocess.run(["sips", "-s", "format", "bmp", src_path, "--out", bmp_path], capture_output=True, check=True)
print("Conversion complete.")

# -------------------------------------------------------------
# Definitions of all items to extract
# -------------------------------------------------------------

ITEMS_U2 = [
    ("W1", "wall_art_picture_vintage", "decor", (25, 200, 35, 270), (25, 45, 18, 35), "Картина в деревянной раме, винтажный стиль", "Ретро-декор эпохи E1, стена"),
    ("W2", "poster_retro_city", "decor", (215, 400, 35, 270), (212, 235, 18, 35), "Ретро-постер с городским пейзажем", "Постер эпохи E1, стена"),
    ("W3", "calendar_wall_hanging", "decor", (415, 600, 35, 270), (417, 437, 18, 35), "Настенный отрывной календарь", "Календарь эпохи E1, стена"),
    ("W4", "wall_shelf_books", "decor", (615, 810, 35, 270), (622, 645, 18, 35), "Настенная деревянная полка с книгами", "Полка эпохи E1, стена"),
    ("W5", "wall_clock_round", "decor", (820, 990, 35, 270), (828, 850, 18, 35), "Круглые настенные часы со стрелками", "Часы эпохи E1, стена"),
    ("W6", "party_flags_garland", "decor", (25, 205, 310, 550), (25, 45, 290, 308), "Праздничная гирлянда из разноцветных флажков", "Гирлянда E1, стена"),
    ("W7", "string_lights_garland", "decor", (215, 405, 310, 550), (212, 235, 290, 308), "Светящаяся гирлянда-нить на проводе", "Гирлянда E1, стена"),
    ("W8", "pennant_banner_flag", "decor", (440, 558, 330, 485), (417, 437, 290, 308), "Треугольный вымпел на стену", "Вымпел E1, стена"),
    ("F1", "thrift_rug_ref", "decor", (560, 865, 330, 520), (622, 640, 290, 308), "Потёртый тканый напольный ковёр с барахолки", "Напольный ковёр F1 эпохи E1"),
    ("F2", "old_cactus_ref", "decor", (870, 985, 310, 550), (826, 845, 290, 308), "Старый кактус в глиняном горшке с блюдцем", "Растение F2 эпохи E1")
]

ITEMS_U3 = [
    ("F3", "folding_chair_metal", "decor", (25, 200, 35, 270), (25, 45, 18, 35), "Складной металлический стул со спинкой", "Мебель F3 эпохи E1"),
    ("F4", "box_pet_bed_cozy", "decor", (215, 400, 35, 270), (212, 235, 18, 35), "Коробка-лежанка для питомца с пледом", "Лежанка F4 эпохи E1"),
    ("F5", "crt_tv_retro", "decor", (415, 600, 35, 270), (417, 437, 18, 35), "Старый выпуклый ЭЛТ-телевизор с антенной", "Техника F5 эпохи E1"),
    ("F6", "dumbbells_floor_set", "decor", (615, 810, 35, 270), (620, 645, 18, 35), "Пара литых спортивных гантелей на полу", "Спорт F6 эпохи E1"),
    ("D4", "desk_lamp_vintage", "decor", (820, 990, 35, 270), (828, 850, 18, 35), "Настольная винтажная лампа с круглым абажуром", "Освещение стола D4"),
    ("D5", "toy_soldier_figurine", "decor", (50, 180, 320, 500), (25, 45, 290, 308), "Зелёный игрушечный солдатик на подставке", "Сувенир стола D5"),
    ("D6", "desk_mug_ceramic", "decor", (215, 350, 320, 500), (180, 210, 290, 308), "Керамическая кофейная кружка для стола", "Посуда стола D6"),
    ("D7", "headphones_retro_wired", "decor", (360, 525, 320, 500), (360, 385, 290, 308), "Проводные ретро-наушники с оголовьем", "Аудио стола D7"),
    ("D8", "power_strip_extension", "decor", (530, 665, 320, 500), (515, 540, 290, 308), "Удлинитель-сетевой фильтр с кнопкой", "Электрика стола D8"),
    ("S1", "diploma_framed_wall", "decor", (665, 820, 320, 500), (670, 695, 290, 308), "Диплом в деревянной рамке под стеклом", "Награда стола S1"),
    ("S2_S3", "magazines_with_console", "decor", (825, 995, 320, 500), (825, 850, 290, 308), "Стопка журналов с ретро-консолью сверху", "Медиа стола S2/S3 (составной объект)")
]

ITEMS_U4 = [
    ("U4_1", "window_curtains_pair", "decor", (30, 200, 35, 270), (24, 53, 18, 35), "Окно со шторами и занавесками", "Окно и текстиль"),
    ("U4_2", "window_glass_brick", "decor", (215, 380, 35, 270), (212, 244, 18, 35), "Большое светлое окно с рамой", "Оконный проём"),
    ("U4_3", "bare_lightbulb_wire", "decor", (430, 525, 35, 270), (417, 433, 18, 35), "Подвесная лампочка на черном проводе", "Потолочный свет"),
    ("U4_4", "ribbon_decor_streamer", "decor", (540, 620, 35, 270), (536, 555, 18, 35), "Ленточный декор / серпантин", "Декор стены"),
    ("U4_5", "cat_sleeping_floor", "decor", (640, 850, 35, 270), (655, 671, 18, 35), "Спящий кот на коврике", "Питомец"),
    ("U4_6", "fishbowl_goldfish", "decor", (870, 985, 35, 270), (860, 878, 18, 35), "Круглая стеклянная банка с золотой рыбкой", "Питомец на столе"),
    ("U4_7", "chromakey_backdrop_stand", "decor", (25, 215, 301, 540), [(20, 55, 290, 306), (211, 230, 290, 306)], "Зеленый хромакей на мобильной стойке", "Студийное оборудование"),
    ("U4_8", "acoustic_guitar_stand", "decor", (235, 360, 300, 540), (212, 233, 290, 308), "Акустическая гитара на напольной стойке", "Музыкальный инструмент"),
    ("U4_9", "books_stack_table", "decor", (365, 515, 310, 550), (365, 384, 290, 308), "Стопка книг в твердом переплете", "Декор стола"),
    ("U4_10", "mousepad_gaming_mouse", "decor", (520, 680, 310, 550), (520, 539, 290, 308), "Игровая мышь на коврике для стола", "Аксессуар стола"),
    ("U4_11", "cardboard_boxes_pile", "decor", (685, 855, 310, 550), (700, 715, 290, 308), "Стопка картонных коробок для переезда", "Хранение"),
    ("U4_12", "handheld_console_retro", "decor", (860, 995, 310, 550), (861, 880, 290, 308), "Портативная игровая консоль ретро", "Гаджет")
]

ITEMS_U5 = [
    ("U5_1", "neon_poster_cyber", "decor", (40, 180, 50, 270), None, "Неоновый кибер-постер на стену", "Постер эпохи E2"),
    ("U5_2", "neon_sign_live", "decor", (200, 350, 50, 270), (212, 230, 18, 35), "Светящаяся неоновая вывеска LIVE", "Световой декор E2"),
    ("U5_3", "led_strip_wall_accent", "decor", (360, 510, 50, 270), (366, 384, 18, 35), "Светодиодная LED-лента настенный контур", "Освещение E2"),
    ("U5_4", "streamer_banner_vert", "decor", (520, 670, 50, 270), None, "Вертикальный стримерский баннер", "Декор стены E2"),
    ("U5_5", "geometric_carpet_bright", "decor", (675, 870, 50, 270), (700, 706, 18, 35), "Яркий геометрический напольный ковер", "Ковер E2"),
    ("U5_6", "ficus_potted_plant", "decor", (872, 990, 50, 270), (871, 878, 18, 35), "Фикус в современном белом кашпо", "Растение E2"),
    ("U5_7", "beanbag_chair_gaming", "decor", (25, 195, 330, 520), (25, 35, 290, 308), "Мягкое кресло-мешок для стримера", "Мебель E2"),
    ("U5_8", "pet_plush_bed", "decor", (210, 360, 330, 520), (214, 231, 290, 308), "Уютная круглая плюшевая лежанка", "Питомец E2"),
    ("U5_9", "skateboard_deck_wall", "decor", (370, 540, 330, 520), (367, 377, 290, 308), "Скейтборд с ярким принтом у стены", "Спорт E2"),
    ("U5_10", "stream_award_plaque", "decor", (550, 675, 330, 520), (520, 545, 290, 308), "Наградная плакетка за подписчиков", "Награда E2"),
    ("U5_11", "anime_figurine_stand", "decor", (720, 825, 330, 520), None, "Коллекционная фигурка на подставке", "Сувенир стола E2"),
    ("U5_12", "energy_drink_cans_pile", "decor", (865, 990, 330, 520), (865, 890, 290, 308), "Банки энергетических напитков на столе", "Напитки E2")
]

ITEMS_U6 = [
    ("U6_1", "graffiti_wall_mural", "decor", (30, 190, 50, 260), None, "Яркое граффити-мурал на стену", "Арт стены E3"),
    ("U6_2", "hanging_monstera_pot", "decor", (205, 340, 35, 260), (212, 225, 18, 35), "Подвесная монстера в макраме-кашпо", "Растение E3"),
    ("U6_3", "studio_sofa_modern", "decor", (350, 520, 50, 260), (365, 375, 18, 35), "Современный двухместный диван для гостей", "Мебель E3"),
    ("U6_4", "arcade_cabinet_mini", "decor", (530, 665, 50, 265), (519, 530, 18, 35), "Ретро-аркадный автомат с джойстиком", "Гейминг E3"),
    ("U6_5", "electric_guitar_stand", "decor", (710, 805, 50, 260), None, "Электрогитара на напольной стойке", "Музыка E3"),
    ("U6_6", "aquarium_tank_led", "decor", (830, 1000, 50, 260), (843, 855, 18, 35), "Стеклянный аквариум с LED-подсветкой", "Аквариум E3"),
    ("U6_7", "light_neon_rug", "decor", (25, 195, 330, 515), None, "Световой неоновый напольный коврик", "Ковер E3"),
    ("U6_8", "display_cabinet_glass", "decor", (220, 345, 315, 525), (214, 225, 290, 308), "Стеклянная витрина с мерчем", "Мебель E3"),
    ("U6_9", "lava_lamp_desk", "decor", (365, 505, 330, 515), (366, 375, 290, 308), "Классическая лава-лампа с воском", "Освещение стола E3"),
    ("U6_10", "custom_streamer_mug", "decor", (540, 650, 350, 510), (520, 530, 290, 308), "Большая стримерская кружка с логотипом", "Посуда E3"),
    ("U6_11", "vinyl_turntable_audio", "decor", (660, 835, 330, 515), (690, 710, 290, 308), "Виниловый проигрыватель с пластинкой", "Аудио E3"),
    ("U6_12", "silver_play_button_frame", "decor", (860, 985, 330, 515), (860, 880, 290, 308), "Серебряная наградная кнопка в рамке", "Награда E3")
]

ITEMS_U7 = [
    ("U7_1", "abstract_canvas_large", "decor", (50, 155, 60, 255), None, "Большая абстрактная картина на холсте", "Арт стены E4"),
    ("U7_2", "designer_chandelier_pendant", "decor", (195, 355, 65, 245), None, "Дизайнерская подвесная люстра", "Освещение потолка E4"),
    ("U7_3", "glass_florarium_geometric", "decor", (355, 515, 70, 260), None, "Геометрический стеклянный флорариум с суккулентами", "Растение стола E4"),
    ("U7_4", "collector_display_case", "decor", (545, 655, 65, 260), None, "Премиальная витрина для наград", "Мебель E4"),
    ("U7_5", "gold_creator_award_wall", "decor", (695, 810, 85, 255), None, "Золотая наградная кнопка стримера", "Награда E4"),
    ("U7_6", "lounge_armchair_ottoman", "decor", (815, 995, 80, 275), None, "Дизайнерское лаунж-кресло с пуфом", "Мебель E4"),
    ("U7_7", "synthesizer_pro_keyboard", "decor", (25, 190, 325, 520), (36, 45, 290, 308), "Профессиональный аналоговый синтезатор", "Музыка E4"),
    ("U7_8", "exotic_terrarium_vertical", "decor", (200, 345, 335, 525), None, "Вертикальный террариум с подсветкой", "Питомец E4"),
    ("U7_9", "robot_vacuum_dock", "decor", (375, 500, 340, 515), None, "Робот-пылесос с базой самоочистки", "Умный дом E4"),
    ("U7_10", "telescope_brass_tripod", "decor", (525, 665, 335, 525), None, "Оптический телескоп на латунном штативе", "Декор E4"),
    ("U7_11", "electric_fireplace_modern", "decor", (695, 825, 340, 510), None, "Современный настенный электрокамин с пламенем", "Уют E4"),
    ("U7_12", "espresso_coffee_station", "decor", (855, 990, 345, 510), (867, 875, 290, 308), "Рожковая кофемашина с чашками", "Кухня E4")
]

ALL_PIXEL_SHEETS = [
    ("u2", ITEMS_U2, "ref/items/Unknown-2.webp"),
    ("u3", ITEMS_U3, "ref/items/Unknown-3.webp"),
    ("u4", ITEMS_U4, "ref/items/Unknown-4.webp"),
    ("u5", ITEMS_U5, "ref/items/Unknown-5.webp"),
    ("u6", ITEMS_U6, "ref/items/Unknown-6.webp"),
    ("u7", ITEMS_U7, "ref/items/Unknown-7.webp"),
]

# -------------------------------------------------------------
# Devices & Equipment extraction definitions
# -------------------------------------------------------------

DEVICES_PHONES = [
    ("P1", "phone_p01_brick_ref", "devices/phones", (87, 592, 40, 700), 620, "Кнопочный сотовый телефон ('Кирпич 3300')", "Стартовый стримерский телефон P1", False),
    # IMPORTANT: iFone 2G MUST be kept in authoritative reference orientation (NO horizontal flip!)
    ("P2", "ifone_2g_ref", "devices/phones", (712, 1102, 170, 670), 620, "iFone 2G с зеркальцем (авторский ракурс, без зеркалирования)", "Первый апгрейд телефона P2. Настоящий референсный спрайт без отражения.", False),
    ("P2_MUG", "ifone_2g_with_mug_support_ref", "devices/phones", (712, 1102, 170, 670), None, "iFone 2G с опорной керамической кружкой", "Телефон P2 вместе с кружкой-подставкой из референса", False),
    ("P3", "phone_p03_slider_ref", "devices/phones", (1238, 1579, 115, 700), 620, "Телефон-слайдер с выдвижной панелью", "Ступень телефона P3", False),
    ("P4", "phone_p04_qwerty_ref", "devices/phones", (1776, 2080, 223, 670), 620, "Телефон с физической QWERTY-клавиатурой", "Ступень телефона P4", False),
    ("P5", "phone_p05_touch_early_ref", "devices/phones", (2259, 2579, 120, 680), 620, "Ранний сенсорный смартфон со стилусом", "Ступень телефона P5", False),
    ("P6", "phone_p06_modern_touch_ref", "devices/phones", (69, 629, 770, 1450), 1340, "Современный безрамочный смартфон", "Ступень телефона P6", False)
]

DEVICES_WIND = [
    ("WIND_1", "cooling_pad_ref", "equipment", (104, 504, 200, 640), 620, "Охлаждающая подставка для устройств с вентилятором", "Ступень охлаждения 1", False),
    ("WIND_2", "desk_fan_ref", "equipment", (751, 1169, 90, 625), 620, "Маленький настольный вентилятор с металлической решёткой", "Ступень охлаждения 2 (авторский референс)", False),
    ("WIND_3", "blower_exhaust_ref", "equipment", (1508, 1885, 140, 640), 620, "Турбинная вытяжка для стрим-сетапа", "Ступень охлаждения 3", False),
    ("WIND_4", "portable_ac_ref", "equipment", (2121, 2656, 90, 665), 620, "Мобильный напольный кондиционер с гофрой", "Ступень охлаждения 4", False)
]

DEVICES_MICS = [
    ("MIC_1", "mic_clip_lapel_ref", "equipment/microphones", (231, 551, 80, 470), 420, "Петличный микрофон-клипса с проводом", "Микрофон ступени 1", False),
    ("MIC_2", "mic_budget_gooseneck_ref", "equipment/microphones", (160, 650, 470, 850), 840, "Бюджетный настольный микрофон на гибкой стойке", "Микрофон ступени 2", False),
    ("MIC_3", "mic_usb_podcast_ref", "equipment/microphones", (840, 1330, 470, 890), 880, "USB-конденсаторный микрофон на настольной треноге", "Микрофон ступени 3", False),
    ("MIC_4", "mic_condenser_popfilter_ref", "equipment/microphones", (840, 1319, 940, 1475), 1420, "Студийный микрофон в пауке с поп-фильтром", "Микрофон ступени 4", False),
    ("MIC_5", "mic_boom_arm_setup_ref", "equipment/microphones", (1440, 1945, 910, 1465), 1420, "Профессиональный микрофон на регулируемом пантографе", "Микрофон ступени 5", False)
]

DEVICES_LIGHT = [
    ("LIGHT_1", "light_desk_lamp_ref", "equipment/lighting", (247, 520, 110, 415), 410, "Настольная шарнирная лампа на струбцине", "Освещение ступени 1", False),
    ("LIGHT_2", "light_led_strip_spool_ref", "equipment/lighting", (883, 1240, 70, 360), 350, "Катушка светодиодной RGB LED-ленты с контроллером", "Освещение ступени 2", False),
    ("LIGHT_3", "light_ring_tripod_ref", "equipment/lighting", (2040, 2630, 80, 505), 500, "Кольцевая лампа с держателем смартфона на штативе", "Освещение ступени 3", False),
    ("LIGHT_4", "light_softbox_stand_ref", "equipment/lighting", (150, 680, 520, 960), 950, "Студийный прямоугольный софтбокс на высокой стойке", "Освещение ступени 4", False)
]

# -------------------------------------------------------------
# Execution & Verification
# -------------------------------------------------------------

catalog_records = []
overview_cards = []

# 1. Process Pixel Art Sheets (Unknown-2 to Unknown-7)
for sheet_key, items_list, src_rel in ALL_PIXEL_SHEETS:
    bmp_path = f"/tmp/{sheet_key}.bmp"
    sheet_w, sheet_h, raw, row_bytes = load_bmp(bmp_path)
    print(f"\nProcessing Pixel Art Sheet: {src_rel} ({len(items_list)} items)...")

    for code, name, category, sbox, lbox, desc, role in items_list:
        res = extract_pixel_art_cell(raw, sheet_w, sheet_h, row_bytes, sbox, lbox, margin=2)
        if not res:
            print(f"  [ERROR] Failed to extract {code}: {name}")
            continue

        cw, ch = res["width"], res["height"]
        rgba = res["rgba"]
        mask = res["mask"]

        # Quality checks
        top_a = [rgba[(0 * cw + x) * 4 + 3] for x in range(cw)]
        bot_a = [rgba[((ch - 1) * cw + x) * 4 + 3] for x in range(cw)]
        left_a = [rgba[(y * cw + 0) * 4 + 3] for y in range(ch)]
        right_a = [rgba[(y * cw + (cw - 1)) * 4 + 3] for y in range(ch)]
        border_leak = sum(top_a) + sum(bot_a) + sum(left_a) + sum(right_a)

        # Opaque count
        opaque_cnt = sum(1 for i in range(0, len(rgba), 4) if rgba[i+3] == 255)
        
        # Edge fringe check
        edge_leak = 0
        for y in range(ch):
            for x in range(cw):
                idx = (y * cw + x) * 4
                if rgba[idx+3] == 255:
                    has_trans_neighbor = False
                    for dx, dy in ((-1,0), (1,0), (0,-1), (0,1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < cw and 0 <= ny < ch:
                            if rgba[(ny * cw + nx) * 4 + 3] == 0:
                                has_trans_neighbor = True; break
                    if has_trans_neighbor:
                        r, g, b = rgba[idx], rgba[idx+1], rgba[idx+2]
                        if is_pixel_art_bg_or_grid(r, g, b):
                            edge_leak += 1

        is_clean = (border_leak == 0 and edge_leak == 0)
        status = "UNREVIEWED" if is_clean else "PROBLEMATIC"
        notes = "Технические проверки пройдены; требуется визуальная приёмка" if is_clean else f"Требует внимания: утечка границ ({border_leak}), каймы ({edge_leak})"

        if code == "S2_S3":
            notes = "Составной объект (консоль S3 стоит поверх стопки журналов S2; сохранены вместе без повреждения пикселей)"

        # Save to assets/art/<category>/<name>.png
        target_png = f"assets/art/{category}/{name}.png"
        save_png(target_png, cw, ch, rgba)

        # Save to source_art/<category>/<name>/
        source_art_dir = f"source_art/{category}/{name}"
        mask_png = f"{source_art_dir}/mask.png"
        save_png(mask_png, cw, ch, mask)

        meta = {
            "id": name,
            "code": code,
            "source_reference": src_rel,
            "category": category,
            "description": desc,
            "role": role,
            "resolution": f"{cw}x{ch}",
            "item_bbox": res["item_bbox"],
            "sheet_crop_box": res["crop_box"],
            "pixel_count": opaque_cnt,
            "border_clearance": border_leak == 0,
            "edge_fringe_pixels": edge_leak,
            "status": status,
            "notes": notes
        }
        with open(f"{source_art_dir}/provenance.json", "w") as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)

        catalog_records.append(meta)
        overview_cards.append((name, cw, ch, rgba))
        print(f"  [{status:11}] {code:5} {name:28} -> {cw:3}x{ch:3} px ({opaque_cnt:5} px)")

# 2. Process Device Sheets
ALL_DEVICE_GROUPS = [
    ("main_dev", DEVICES_PHONES, "ref/device/Main/Gemini_Generated_Image_tjhcjitjhcjitjhc.jpg", (58, 59, 64)),
    ("wind_dev", DEVICES_WIND, "ref/device/wind/Gemini_Generated_Image_z1lscpz1lscpz1ls-2.jpg", (50, 52, 55)),
    ("mic_dev", DEVICES_MICS, "ref/device/microphone/Gemini_Generated_Image_84hlag84hlag84hl.jpg", (49, 55, 57)),
    ("light_dev", DEVICES_LIGHT, "ref/device/light/Gemini_Generated_Image_phzj9aphzj9aphzj.jpg", (51, 53, 55))
]

for sheet_key, dev_list, src_rel, bg_color in ALL_DEVICE_GROUPS:
    bmp_path = f"/tmp/{sheet_key}.bmp"
    sheet_w, sheet_h, raw, row_bytes = load_bmp(bmp_path)
    print(f"\nProcessing Device Sheet: {src_rel} ({len(dev_list)} devices)...")

    for code, name, category, sbox, shadow_thresh, desc, role, flip in dev_list:
        drop_shadow = (shadow_thresh is not None)
        res = extract_device_item(
            raw, sheet_w, sheet_h, row_bytes, sbox, bg_color,
            tolerance=14, margin=4, drop_floor_shadow=drop_shadow, shadow_y_thresh=shadow_thresh
        )
        if not res:
            print(f"  [ERROR] Failed to extract device {code}: {name}")
            continue

        cw, ch = res["width"], res["height"]
        rgba = res["rgba"]
        mask = res["mask"]

        # Quality checks
        top_a = [rgba[(0 * cw + x) * 4 + 3] for x in range(cw)]
        bot_a = [rgba[((ch - 1) * cw + x) * 4 + 3] for x in range(cw)]
        left_a = [rgba[(y * cw + 0) * 4 + 3] for y in range(ch)]
        right_a = [rgba[(y * cw + (cw - 1)) * 4 + 3] for y in range(ch)]
        border_leak = sum(top_a) + sum(bot_a) + sum(left_a) + sum(right_a)
        opaque_cnt = sum(1 for i in range(0, len(rgba), 4) if rgba[i+3] == 255)

        is_clean = (border_leak == 0)
        status = "UNREVIEWED" if is_clean else "PROBLEMATIC"
        notes = "Технические проверки пройдены; требуется визуальная приёмка" if is_clean else f"Касание границы ({border_leak})"

        if code == "P2":
            notes = "Ориентация сохранена строго по референсу (без горизонтального отражения). Учтено прямое правило проекта. Падающая тень отделена."
        elif code == "P2_MUG":
            notes = "Составной референс iFone 2G с опорной керамической кружкой (ракурс референса, без отражения)."

        target_png = f"assets/art/{category}/{name}.png"
        save_png(target_png, cw, ch, rgba)

        source_art_dir = f"source_art/{category}/{name}"
        mask_png = f"{source_art_dir}/mask.png"
        save_png(mask_png, cw, ch, mask)

        meta = {
            "id": name,
            "code": code,
            "source_reference": src_rel,
            "category": category,
            "description": desc,
            "role": role,
            "resolution": f"{cw}x{ch}",
            "item_bbox": res["item_bbox"],
            "sheet_crop_box": res["crop_box"],
            "pixel_count": opaque_cnt,
            "border_clearance": border_leak == 0,
            "status": status,
            "notes": notes
        }
        with open(f"{source_art_dir}/provenance.json", "w") as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)

        catalog_records.append(meta)
        overview_cards.append((name, cw, ch, rgba))
        print(f"  [{status:11}] {code:5} {name:28} -> {cw:3}x{ch:3} px ({opaque_cnt:5} px)")

# -------------------------------------------------------------
# Generate Visual Contact Sheets (Overview Sheets)
# -------------------------------------------------------------

print(f"\nBuilding Visual Overview Contact Sheets for {len(overview_cards)} assets...")

def generate_contact_sheet(cards_subset, out_path, sheet_title, cols=8, cell_size=120):
    rows = (len(cards_subset) + cols - 1) // cols
    sheet_w = cols * cell_size
    sheet_h = rows * cell_size + 40 # 40px header

    # Background: dark checkerboard for verifying transparency
    sheet_rgba = bytearray(sheet_w * sheet_h * 4)
    for y in range(sheet_h):
        for x in range(sheet_w):
            idx = (y * sheet_w + x) * 4
            # checker pattern (10px squares): #222228 and #2a2a32
            if y < 40:
                # header bar #16181f
                sheet_rgba[idx] = 22; sheet_rgba[idx+1] = 24; sheet_rgba[idx+2] = 31; sheet_rgba[idx+3] = 255
            else:
                chk = ((x // 10) + (y // 10)) % 2
                c = 36 if chk == 0 else 44
                sheet_rgba[idx] = c; sheet_rgba[idx+1] = c + 4; sheet_rgba[idx+2] = c + 10; sheet_rgba[idx+3] = 255

    for idx, (name, cw, ch, rgba) in enumerate(cards_subset):
        col = idx % cols
        row = idx // cols
        cx0 = col * cell_size
        cy0 = row * cell_size + 40

        # Scale down to fit inside (cell_size - 16) if larger
        max_dim = max(cw, ch)
        scale = min(1.0, (cell_size - 24) / max_dim)
        dw = max(1, int(cw * scale))
        dh = max(1, int(ch * scale))
        dx0 = cx0 + (cell_size - dw) // 2
        dy0 = cy0 + (cell_size - dh) // 2

        # Nearest neighbor blit
        for dy in range(dh):
            sy = int(dy / scale)
            if sy >= ch: sy = ch - 1
            for dx in range(dw):
                sx = int(dx / scale)
                if sx >= cw: sx = cw - 1
                s_idx = (sy * cw + sx) * 4
                sa = rgba[s_idx + 3]
                if sa > 0:
                    d_idx = ((dy0 + dy) * sheet_w + (dx0 + dx)) * 4
                    alpha_f = sa / 255.0
                    inv_a = 1.0 - alpha_f
                    sheet_rgba[d_idx] = int(rgba[s_idx] * alpha_f + sheet_rgba[d_idx] * inv_a)
                    sheet_rgba[d_idx+1] = int(rgba[s_idx+1] * alpha_f + sheet_rgba[d_idx+1] * inv_a)
                    sheet_rgba[d_idx+2] = int(rgba[s_idx+2] * alpha_f + sheet_rgba[d_idx+2] * inv_a)
                    sheet_rgba[d_idx+3] = 255

    save_png(out_path, sheet_w, sheet_h, sheet_rgba)
    print(f"Generated Overview Sheet: {out_path} ({sheet_w}x{sheet_h})")

# Separate into Decor and Devices overview sheets
decor_cards = [c for c in overview_cards if not c[0].startswith(("phone_", "ifone_", "cooling_", "desk_fan_", "blower_", "portable_ac_", "mic_", "light_"))]
device_cards = [c for c in overview_cards if c[0].startswith(("phone_", "ifone_", "cooling_", "desk_fan_", "blower_", "portable_ac_", "mic_", "light_"))]

generate_contact_sheet(decor_cards, "assets/art/overview_decor_sheet_v01.png", "Hypster Decor Reference Assets (Authentic Extracted)", cols=10, cell_size=100)
generate_contact_sheet(device_cards, "assets/art/overview_devices_sheet_v01.png", "Hypster Streaming Devices & Equipment (Authentic Extracted)", cols=6, cell_size=140)
generate_contact_sheet(overview_cards, "assets/art/overview_master_sheet_v01.png", "Hypster All Reference Assets (Authentic Extracted)", cols=10, cell_size=110)

# Save master catalog JSON
master_catalog_path = "data/art/reference_asset_catalog.json"
os.makedirs(os.path.dirname(master_catalog_path), exist_ok=True)
with open(master_catalog_path, "w") as f:
    json.dump({
        "total_assets": len(catalog_records),
        "ready_count": sum(1 for c in catalog_records if c["status"] == "READY"),
        "unreviewed_count": sum(1 for c in catalog_records if c["status"] == "UNREVIEWED"),
        "problematic_count": sum(1 for c in catalog_records if c["status"] == "PROBLEMATIC"),
        "assets": catalog_records
    }, f, ensure_ascii=False, indent=2)

print(f"\nMaster catalog written to: {master_catalog_path}")
print(f"Total processed: {len(catalog_records)} assets | READY: {sum(1 for c in catalog_records if c['status'] == 'READY')} | PROBLEMS: {sum(1 for c in catalog_records if c['status'] == 'PROBLEMATIC')}")
