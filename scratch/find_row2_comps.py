import sys; sys.path.append('scratch')
from pixel_art_extractor import load_bmp, is_pixel_art_bg_or_grid

sheet_w, sheet_h, raw, row_bytes = load_bmp('/tmp/u2.bmp')
def get_rgb(x, y):
    i = y * row_bytes + x * 3
    return raw[i+2], raw[i+1], raw[i]

# Scan row 2: y in 310..555
# Find connected components in this whole band!
visited = set()
comps = []
for y in range(310, 555):
    for x in range(20, 1000):
        if (x, y) in visited: continue
        if is_pixel_art_bg_or_grid(*get_rgb(x, y)): continue
        
        # BFS component
        c_pts = []
        q = [(x, y)]
        visited.add((x, y))
        while q:
            cx, cy = q.pop()
            c_pts.append((cx, cy))
            for nx, ny in ((cx-1, cy), (cx+1, cy), (cx, cy-1), (cx, cy+1)):
                if 20 <= nx < 1000 and 310 <= ny < 555:
                    if (nx, ny) not in visited and not is_pixel_art_bg_or_grid(*get_rgb(nx, ny)):
                        visited.add((nx, ny))
                        q.append((nx, ny))
        if len(c_pts) > 100:
            min_x = min(p[0] for p in c_pts)
            max_x = max(p[0] for p in c_pts)
            min_y = min(p[1] for p in c_pts)
            max_y = max(p[1] for p in c_pts)
            comps.append((min_x, max_x, min_y, max_y, len(c_pts)))

comps.sort(key=lambda c: c[0])
print(f"Row 2 connected components (>100 px): {len(comps)}")
for i, c in enumerate(comps):
    print(f"  [{i+1}] bbox: x={c[0]}..{c[1]} (w={c[1]-c[0]+1}), y={c[2]}..{c[3]} (h={c[3]-c[2]+1}), pixels={c[4]}")
