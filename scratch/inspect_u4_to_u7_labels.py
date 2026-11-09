import struct, subprocess

for idx in [4, 5, 6, 7]:
    bmp = f'/tmp/u{idx}.bmp'
    with open(bmp, 'rb') as f:
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

    # Check top row (y=20..32) and mid row (y=290..306) labels
    top_labels = []
    mid_labels = []
    for x in range(w):
        for y in range(18, 35):
            rgb = get_rgb(x, y)
            if rgb[0] > 160 and rgb[1] > 160 and rgb[2] > 160:
                top_labels.append(x)
                break
        for y in range(290, 308):
            rgb = get_rgb(x, y)
            if rgb[0] > 160 and rgb[1] > 160 and rgb[2] > 160:
                mid_labels.append(x)
                break

    import collections
    def cluster(xs):
        c = collections.Counter(xs)
        res = []
        cur = []
        for x in sorted(c.keys()):
            if not cur or x - cur[-1] <= 6:
                cur.append(x)
            else:
                if len(cur) >= 4:
                    res.append((min(cur), max(cur)))
                cur = [x]
        if len(cur) >= 4:
            res.append((min(cur), max(cur)))
        return res

    print(f"=== Sheet Unknown-{idx}.webp ===")
    print("  Top labels x:", cluster(top_labels))
    print("  Mid labels x:", cluster(mid_labels))
