import struct

with open('/tmp/u3.bmp', 'rb') as f:
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

# Look at bright pixels around labels across the sheet
print("Searching for bright labels in Unknown-3.bmp:")
bright_pts = [(x, y) for y in range(h) for x in range(w) if get_rgb(x, y)[0] > 180 and get_rgb(x, y)[1] > 180 and get_rgb(x, y)[2] > 180]
import collections
# Group by y regions:
y_groups = collections.defaultdict(list)
for x, y in bright_pts:
    y_groups[y // 20].append((x, y))

for yg, pts in sorted(y_groups.items()):
    min_y = min(p[1] for p in pts)
    max_y = max(p[1] for p in pts)
    print(f"Region y={min_y}..{max_y}: {len(pts)} bright pixels")
    # cluster in x
    xs = sorted(set(p[0] for p in pts))
    cl = []
    for x in xs:
        if not cl or x - cl[-1][-1] <= 8:
            if not cl: cl.append([x])
            else: cl[-1].append(x)
        else:
            cl.append([x])
    for c in cl:
        if len(c) > 3:
            print(f"  x={min(c)}..{max(c)}")
