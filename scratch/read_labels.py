import struct, subprocess

bmp = '/tmp/u2.bmp'
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

# Let's inspect each of the 10 cells in detail
# Cell bounds approximately:
# Row 1 (y: 16..275):
#   Col 1: x=16..208
#   Col 2: x=208..408
#   Col 3: x=408..608
#   Col 4: x=608..814
#   Col 5: x=814..1008
# Row 2 (y: 275..555):
#   Col 1: x=16..208
#   Col 2: x=208..408
#   Col 3: x=408..608
#   Col 4: x=608..814
#   Col 5: x=814..1008

cols = [(16, 208), (208, 408), (408, 608), (608, 814), (814, 1008)]
rows = [(16, 275), (275, 555)]

for r_i, (y0, y1) in enumerate(rows):
    for c_i, (x0, x1) in enumerate(cols):
        # Look for text label in top 35 pixels of the cell
        label_pixels = []
        for y in range(y0 + 2, y0 + 35):
            for x in range(x0 + 2, x1 - 2):
                rgb = get_rgb(x, y)
                if rgb[0] > 180 and rgb[1] > 180 and rgb[2] > 180:
                    label_pixels.append((x, y))
        print(f"Row {r_i+1}, Col {c_i+1} [x={x0}..{x1}, y={y0}..{y1}]:")
        if label_pixels:
            lx0 = min(p[0] for p in label_pixels)
            lx1 = max(p[0] for p in label_pixels)
            ly0 = min(p[1] for p in label_pixels)
            ly1 = max(p[1] for p in label_pixels)
            print(f"  Label bbox: x={lx0}..{lx1}, y={ly0}..{ly1} ({len(label_pixels)} px)")
            # Let's print ASCII rendering of the label!
            for ly in range(ly0, ly1 + 1):
                row_str = "".join("#" if (lx, ly) in label_pixels else " " for lx in range(lx0, lx1 + 1))
                print(f"    {row_str}")
        else:
            print("  No bright text label found")
