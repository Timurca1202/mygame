import struct, subprocess, zlib

def save_png(path, width, height, rgba_bytes):
    line_bytes = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw.extend(rgba_bytes[y * line_bytes : (y + 1) * line_bytes])
    compressed = zlib.compress(bytes(raw), 9)
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    ihdr_crc = zlib.crc32(b'IHDR' + ihdr_data) & 0xffffffff
    idat_crc = zlib.crc32(b'IDAT' + compressed) & 0xffffffff
    iend_crc = zlib.crc32(b'IEND') & 0xffffffff
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(struct.pack('>I', len(ihdr_data)) + b'IHDR' + ihdr_data + struct.pack('>I', ihdr_crc))
        f.write(struct.pack('>I', len(compressed)) + b'IDAT' + compressed + struct.pack('>I', idat_crc))
        f.write(struct.pack('>I', 0) + b'IEND' + struct.pack('>I', iend_crc))

# Load Unknown-2.bmp
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

# F2 Cactus cell: x in 814..1008, y in 275..555
# Label F2 was at x=826..843, y=293..304
# The cactus itself starts below the label and inside the cell
# Let's inspect the bounding box of the cactus
# Background is base (37, 43, 50), minor grid (49, 54, 62), major grid (67, 72, 84)
# Let's check what pixels belong to cactus in x=840..1000, y=310..550

def is_bg_or_grid(rgb):
    r, g, b = rgb
    # Base bg
    if abs(r - 37) <= 6 and abs(g - 43) <= 6 and abs(b - 50) <= 6:
        return True
    # Minor grid
    if abs(r - 49) <= 6 and abs(g - 54) <= 6 and abs(b - 62) <= 6:
        return True
    # Major grid
    if abs(r - 67) <= 6 and abs(g - 72) <= 6 and abs(b - 84) <= 6:
        return True
    # In-between compression artifacts of grid lines on dark background
    # Note that background hue is blue-slate: r <= g and b >= g and g <= 85 and abs(r - g + 6) <= 8 and abs(b - g - 9) <= 9:
    if r < 80 and g < 90 and b < 100:
        if abs(r - (g - 6)) <= 6 and abs(b - (g + 8)) <= 8:
            return True
    return False

# Find bounds of cactus in x=830..990, y=310..545
c_pts = []
for y in range(310, 545):
    for x in range(830, 990):
        if not is_bg_or_grid(get_rgb(x, y)):
            c_pts.append((x, y))

min_x = min(p[0] for p in c_pts)
max_x = max(p[0] for p in c_pts)
min_y = min(p[1] for p in c_pts)
max_y = max(p[1] for p in c_pts)
print(f"Cactus bbox: x={min_x}..{max_x} (w={max_x-min_x+1}), y={min_y}..{max_y} (h={max_y-min_y+1})")

# Add 2px margin around object
margin = 2
out_x0 = max(815, min_x - margin)
out_x1 = min(1007, max_x + margin)
out_y0 = max(276, min_y - margin)
out_y1 = min(554, max_y + margin)
out_w = out_x1 - out_x0 + 1
out_h = out_y1 - out_y0 + 1

# Generate RGBA buffer
rgba = bytearray(out_w * out_h * 4)
for oy in range(out_h):
    y = out_y0 + oy
    for ox in range(out_w):
        x = out_x0 + ox
        rgb = get_rgb(x, y)
        idx = (oy * out_w + ox) * 4
        if is_bg_or_grid(rgb):
            rgba[idx] = 0
            rgba[idx+1] = 0
            rgba[idx+2] = 0
            rgba[idx+3] = 0
        else:
            rgba[idx] = rgb[0]
            rgba[idx+1] = rgb[1]
            rgba[idx+2] = rgb[2]
            rgba[idx+3] = 255

save_png('/tmp/test_cactus_extracted.png', out_w, out_h, rgba)
print(f"Saved /tmp/test_cactus_extracted.png: {out_w}x{out_h}")
