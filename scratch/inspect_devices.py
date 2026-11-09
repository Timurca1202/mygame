import subprocess, struct

def inspect_sheet(path):
    bmp = '/tmp/dev_temp.bmp'
    subprocess.run(['sips', '-s', 'format', 'bmp', path, '--out', bmp], capture_output=True, check=True)
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

    # Sample corners
    c0 = get_rgb(10, 10)
    c1 = get_rgb(w-10, 10)
    c2 = get_rgb(10, h-10)
    c3 = get_rgb(w-10, h-10)
    bg_r = (c0[0] + c1[0] + c2[0] + c3[0]) // 4
    bg_g = (c0[1] + c1[1] + c2[1] + c3[1]) // 4
    bg_b = (c0[2] + c1[2] + c2[2] + c3[2]) // 4
    
    print(f"\nSheet: {path} ({w}x{h}), BG: RGB({bg_r}, {bg_g}, {bg_b})")

    # Find row and col bands
    def is_bg(r, g, b):
        return abs(r - bg_r) <= 16 and abs(g - bg_g) <= 16 and abs(b - bg_b) <= 16

    step = 4
    row_counts = [sum(1 for x in range(0, w, step) if not is_bg(*get_rgb(x, y))) for y in range(0, h, step)]
    col_counts = [sum(1 for y in range(0, h, step) if not is_bg(*get_rgb(x, y))) for x in range(0, w, step)]

    # Print row segments
    in_row = False
    row_ranges = []
    r_start = 0
    for idx, c in enumerate(row_counts):
        y = idx * step
        if c > 40 and not in_row:
            in_row = True
            r_start = y
        elif c <= 40 and in_row:
            in_row = False
            row_ranges.append((r_start, y))
    if in_row:
        row_ranges.append((r_start, h))

    print(f"Row bands ({len(row_ranges)}):")
    for r_i, (y0, y1) in enumerate(row_ranges):
        # find col bands in this row range
        in_col = False
        c_ranges = []
        c_start = 0
        r_cols = [sum(1 for y in range(y0, y1, step) if not is_bg(*get_rgb(x, y))) for x in range(0, w, step)]
        for c_idx, cc in enumerate(r_cols):
            x = c_idx * step
            if cc > 20 and not in_col:
                in_col = True
                c_start = x
            elif cc <= 20 and in_col:
                in_col = False
                c_ranges.append((c_start, x))
        if in_col:
            c_ranges.append((c_start, w))
        print(f"  Row {r_i+1}: y={y0}..{y1} (h={y1-y0}), {len(c_ranges)} items:")
        for ci, (x0, x1) in enumerate(c_ranges):
            print(f"    Item {ci+1}: x={x0}..{x1} (w={x1-x0})")

if __name__ == '__main__':
    inspect_sheet('ref/device/Main/Gemini_Generated_Image_tjhcjitjhcjitjhc.jpg')
    inspect_sheet('ref/device/wind/Gemini_Generated_Image_z1lscpz1lscpz1ls-2.jpg')
    inspect_sheet('ref/device/microphone/Gemini_Generated_Image_84hlag84hlag84hl.jpg')
    inspect_sheet('ref/device/light/Gemini_Generated_Image_phzj9aphzj9aphzj.jpg')
