import struct, zlib

# Load /tmp/p2_raw.bmp
with open('/tmp/p2_raw.bmp', 'rb') as f:
    hdr = f.read(54)
    w, h = struct.unpack('<ii', hdr[18:26])
    h = abs(h)
    f.seek(54)
    raw = f.read()

row_bytes = (w * 3 + 3) & ~3
def get_rgb(x, y):
    i = (h - 1 - y) * row_bytes + x * 3
    return raw[i+2], raw[i+1], raw[i]

# Background is (56, 59, 64)
# Drop shadow on floor is dark: r < 40, g < 40, b < 45 around the base (y > 420)
# Mug is warm ceramic / beige / tan / coffee: r > 100, g > 80, b > 70
# Phone is silver/black / glass mirror

print(f"P2 crop size: {w}x{h}")
# Analyze color clusters:
# Let's count colors
def is_bg(r, g, b):
    return abs(r - 57) <= 12 and abs(g - 59) <= 12 and abs(b - 64) <= 12

def is_floor_shadow(r, g, b, y):
    # Floor shadow is only at the bottom near y > 430
    if y > 430 and r < 45 and g < 48 and b < 54:
        return True
    return False

# Find phone + mug pixels
obj_pixels = []
for y in range(h):
    for x in range(w):
        r, g, b = get_rgb(x, y)
        if not is_bg(r, g, b) and not is_floor_shadow(r, g, b, y):
            obj_pixels.append((x, y, r, g, b))

print(f"Total object pixels (excluding bg & floor shadow): {len(obj_pixels)}")
min_x = min(p[0] for p in obj_pixels)
max_x = max(p[0] for p in obj_pixels)
min_y = min(p[1] for p in obj_pixels)
max_y = max(p[1] for p in obj_pixels)
print(f"Assembly bounds: x={min_x}..{max_x} (w={max_x-min_x+1}), y={min_y}..{max_y} (h={max_y-min_y+1})")
