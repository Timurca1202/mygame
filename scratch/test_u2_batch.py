import subprocess, os
from pixel_art_extractor import load_bmp, extract_pixel_art_item, save_png

# Ensure bmp exists
subprocess.run(['sips', '-s', 'format', 'bmp', 'ref/items/Unknown-2.webp', '--out', '/tmp/u2.bmp'], check=True)
sheet_w, sheet_h, raw, row_bytes = load_bmp('/tmp/u2.bmp')

items_def = [
    # code, name, search_box(x0, x1, y0, y1), label_box(lx0, lx1, ly0, ly1), description
    ("W1", "wall_art_picture_vintage", (25, 200, 35, 270), (25, 45, 18, 35), "Картина в винтажной деревянной рамке"),
    ("W2", "poster_retro_city", (215, 400, 35, 270), (212, 235, 18, 35), "Ретро-постер с городским пейзажем"),
    ("W3", "calendar_wall_hanging", (415, 600, 35, 270), (417, 437, 18, 35), "Настенный отрывной календарь"),
    ("W4", "wall_shelf_books", (615, 810, 35, 270), (622, 645, 18, 35), "Настенная деревянная полка с книгами"),
    ("W5", "wall_clock_round", (820, 990, 35, 270), (828, 850, 18, 35), "Круглые настенные часы со стрелками"),
    ("W6", "party_flags_garland", (25, 205, 310, 550), (25, 45, 290, 308), "Праздничная гирлянда из разноцветных флажков"),
    ("W7", "string_lights_garland", (215, 405, 310, 550), (212, 235, 290, 308), "Светящаяся гирлянда-нить"),
    ("W8", "pennant_banner_flag", (430, 530, 320, 415), (417, 437, 290, 308), "Треугольный вымпел на стену"),
    ("F1", "thrift_rug_ref_v01", (550, 860, 415, 550), (622, 640, 290, 308), "Потёртый тканый напольный ковёр (референс F1)"),
    ("F2", "old_cactus_ref_v01", (870, 985, 310, 550), (826, 845, 290, 308), "Старый кактус в терракотовом горшке (референс F2)")
]

out_dir = "/tmp/u2_extracted"
os.makedirs(out_dir, exist_ok=True)

for code, name, sbox, lbox, desc in items_def:
    res = extract_pixel_art_item(raw, sheet_w, sheet_h, row_bytes, sbox, lbox, margin=2)
    if res:
        png_path = f"{out_dir}/{name}.png"
        mask_path = f"{out_dir}/{name}_mask.png"
        save_png(png_path, res["width"], res["height"], res["rgba"])
        save_png(mask_path, res["width"], res["height"], res["mask"])
        
        # Check borders
        w, h = res["width"], res["height"]
        rgba = res["rgba"]
        top_a = [rgba[(0 * w + x) * 4 + 3] for x in range(w)]
        bot_a = [rgba[((h-1) * w + x) * 4 + 3] for x in range(w)]
        left_a = [rgba[(y * w + 0) * 4 + 3] for y in range(h)]
        right_a = [rgba[(y * w + (w-1)) * 4 + 3] for y in range(h)]
        border_sum = sum(top_a) + sum(bot_a) + sum(left_a) + sum(right_a)
        
        status = "CLEAN" if border_sum == 0 else f"BORDER WARNING ({border_sum})"
        print(f"[{code:2}] {name:25} -> {w:3}x{h:3} px, pixels={res['pixel_count']:5}, border={status}")
    else:
        print(f"[{code:2}] {name:25} -> FAILED")
