import subprocess, struct

bmp = '/tmp/main_dev.bmp'
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

# Background of Main sheet is ~(58, 59, 64)
# P2 is in upper row: x in 720..1100, y in 150..720
# Let's inspect the colors across P2:
print(f"P2 region inspection:")
for y in range(180, 700, 40):
    row_pixels = [get_rgb(x, y) for x in range(730, 1100, 25)]
    print(f"y={y:3}: {row_pixels[0]} .. {row_pixels[len(row_pixels)//2]} .. {row_pixels[-1]}")
