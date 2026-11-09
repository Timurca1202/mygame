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

def render_ascii_box(x0, x1, y0, y1):
    for y in range(y0, y1 + 1):
        line = []
        for x in range(x0, x1 + 1):
            r, g, b = get_rgb(x, y)
            line.append("#" if (r > 160 and g > 160 and b > 160) else " ")
        s = "".join(line)
        if "#" in s:
            print(f"  y={y:3}: {s}")

print("--- Top row labels (y=18..35) ---")
for x in [25, 215, 415, 620, 830]:
    print(f"Label around x={x}:")
    render_ascii_box(x, x + 35, 18, 35)

print("\n--- Mid row labels (y=290..308) ---")
for x in [25, 180, 360, 515, 670, 825]:
    print(f"Label around x={x}:")
    render_ascii_box(x, x + 30, 290, 308)
