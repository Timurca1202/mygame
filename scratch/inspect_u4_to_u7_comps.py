import sys; sys.path.append('scratch')
from pixel_art_extractor import load_bmp, is_pixel_art_bg_or_grid

def get_sheet_items(sheet_idx):
    bmp = f'/tmp/u{sheet_idx}.bmp'
    sheet_w, sheet_h, raw, row_bytes = load_bmp(bmp)
    def get_rgb(x, y):
        i = y * row_bytes + x * 3
        return raw[i+2], raw[i+1], raw[i]

    visited = set()
    comps = []
    # Row 1 (y=40..270) and Row 2 (y=310..555)
    for y in range(40, 555):
        if 270 <= y <= 315: continue # divider band
        for x in range(20, 1000):
            if (x, y) in visited: continue
            if is_pixel_art_bg_or_grid(*get_rgb(x, y)): continue

            c_pts = []
            q = [(x, y)]
            visited.add((x, y))
            while q:
                cx, cy = q.pop()
                c_pts.append((cx, cy))
                for nx, ny in ((cx-1, cy), (cx+1, cy), (cx, cy-1), (cx, cy+1)):
                    if 20 <= nx < 1000 and 40 <= ny < 555 and not (270 <= ny <= 315):
                        if (nx, ny) not in visited and not is_pixel_art_bg_or_grid(*get_rgb(nx, ny)):
                            visited.add((nx, ny))
                            q.append((nx, ny))
            if len(c_pts) > 100:
                min_x = min(p[0] for p in c_pts)
                max_x = max(p[0] for p in c_pts)
                min_y = min(p[1] for p in c_pts)
                max_y = max(p[1] for p in c_pts)
                row_num = 1 if min_y < 270 else 2
                comps.append((row_num, min_x, max_x, min_y, max_y, len(c_pts)))

    comps.sort(key=lambda c: (c[0], c[1]))
    print(f"\n=======================================================")
    print(f"Sheet Unknown-{sheet_idx}.webp: {len(comps)} major items (>100 px)")
    for i, c in enumerate(comps):
        w = c[2] - c[1] + 1
        h = c[4] - c[3] + 1
        print(f"  Item {i+1:2} (Row {c[0]}): x={c[1]:3}..{c[2]:3} (w={w:3}), y={c[3]:3}..{c[4]:3} (h={h:3}), pixels={c[5]:5}")

for idx in [4, 5, 6, 7]:
    get_sheet_items(idx)
