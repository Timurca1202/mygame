import struct

with open('/tmp/u2.bmp', 'rb') as f:
    hdr = f.read(54)
    offset = struct.unpack('<I', hdr[10:14])[0]
    w, h = struct.unpack('<ii', hdr[18:26])
    h = abs(h)
    f.seek(offset)
    bmp_data = f.read()

row_bytes = (w * 3 + 3) & ~3
def get_rgb(x, y):
    i = y * row_bytes + x * 3
    return bmp_data[i+2], bmp_data[i+1], bmp_data[i]

def is_bg_or_grid(rgb):
    r, g, b = rgb
    if r < 85 and g < 95 and b < 105:
        if abs(r - (g - 6)) <= 8 and abs(b - (g + 8)) <= 8:
            return True
    return False

# 10 cells definitions on Unknown-2.webp:
# Columns:
# Col 1: x in 20..200
# Col 2: x in 210..400
# Col 3: x in 410..600
# Col 4: x in 610..810
# Col 5: x in 820..990
# Rows:
# Row 1: y in 35..270 (excluding top label at y=20..32)
# Row 2: y in 310..550 (excluding mid label at y=293..306)

cells = [
    # Row 1
    ("W1", "wall_picture_vintage", 25, 200, 35, 270),
    ("W2", "poster_retro_city", 215, 400, 35, 270),
    ("W3", "calendar_wall_hanging", 415, 600, 35, 270),
    ("W4", "wall_shelf_books", 615, 810, 35, 270),
    ("W5", "wall_clock_round", 820, 990, 35, 270),
    # Row 2
    ("W6", "party_flags_hanging", 25, 205, 310, 550),
    ("W7", "string_lights_garland", 215, 405, 310, 550),
    ("W8", "pennant_banner_flag", 415, 605, 310, 550),
    ("F1", "thrift_rug_worn", 610, 850, 310, 550),
    ("F2", "old_cactus_pot", 870, 985, 310, 550)
]

for label, name, x0, x1, y0, y1 in cells:
    pts = [(x, y) for y in range(y0, y1) for x in range(x0, x1) if not is_bg_or_grid(get_rgb(x, y))]
    if pts:
        bx0 = min(p[0] for p in pts)
        bx1 = max(p[0] for p in pts)
        by0 = min(p[1] for p in pts)
        by1 = max(p[1] for p in pts)
        bw = bx1 - bx0 + 1
        bh = by1 - by0 + 1
        print(f"[{label:2}] {name:25}: bbox x={bx0:3}..{bx1:3} (w={bw:3}), y={by0:3}..{by1:3} (h={bh:3}), pixels={len(pts):5}")
    else:
        print(f"[{label:2}] {name:25}: EMPTY")
