import subprocess, struct

bmp = '/tmp/wind_dev.bmp'
subprocess.run(['sips', '-s', 'format', 'bmp', 'ref/device/wind/Gemini_Generated_Image_z1lscpz1lscpz1ls-2.jpg', '--out', bmp], check=True)

with open(bmp, 'rb') as f:
    hdr = f.read(54)
    offset = struct.unpack('<I', hdr[10:14])[0]
    w, h = struct.unpack('<ii', hdr[18:26])
    h = abs(h)
    f.seek(offset)
    raw = f.read()

row_bytes = (w * 3 + 3) & ~3
def get_rgb(x, y):
    i = y * row_bytes + x * 3
    return raw[i+2], raw[i+1], raw[i]

def is_bg(r, g, b):
    # BG is ~(50, 52, 55)
    return abs(r - 50) <= 15 and abs(g - 52) <= 15 and abs(b - 55) <= 15

# Upper row is y in 150..700
# 4 items in top row:
# Item 1: cooling pad (x ~ 150..500)
# Item 2: desk fan (x ~ 700..1200)
# Item 3: blower exhaust (x ~ 1400..1950)
# Item 4: mobile AC (x ~ 2100..2650)

print("Upper row of wind reference:")
for (name, x0, x1) in [
    ("cooling_pad_stand", 120, 550),
    ("desk_fan_small", 700, 1200),
    ("blower_exhaust_fan", 1450, 1950),
    ("portable_ac_unit", 2100, 2700)
]:
    pts = [(x, y) for y in range(160, 680) for x in range(x0, x1) if not is_bg(*get_rgb(x, y))]
    if pts:
        bx0 = min(p[0] for p in pts)
        bx1 = max(p[0] for p in pts)
        by0 = min(p[1] for p in pts)
        by1 = max(p[1] for p in pts)
        print(f"  {name:20}: x={bx0}..{bx1} (w={bx1-bx0+1}), y={by0}..{by1} (h={by1-by0+1}), pixels={len(pts)}")
    else:
        print(f"  {name:20}: EMPTY")
