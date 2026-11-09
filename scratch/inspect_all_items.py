import subprocess, struct

def inspect_all():
    for idx in range(2, 8):
        webp = f'ref/items/Unknown-{idx}.webp'
        bmp = f'/tmp/u{idx}.bmp'
        subprocess.run(['sips', '-s', 'format', 'bmp', webp, '--out', bmp], capture_output=True, check=True)
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

        def is_bg_or_grid(rgb):
            r, g, b = rgb
            if r < 85 and g < 95 and b < 105:
                # dark blue-slate tones
                if abs(r - (g - 6)) <= 8 and abs(b - (g + 8)) <= 8:
                    return True
            return False

        # Look at the horizontal and vertical projection of non-bg pixels
        row_counts = []
        for y in range(h):
            row_counts.append(sum(1 for x in range(w) if not is_bg_or_grid(get_rgb(x, y))))

        # Find row segments (dividers between rows)
        in_r = False
        r_segments = []
        r_start = 0
        for y, c in enumerate(row_counts):
            if c > 40 and not in_r:
                in_r = True
                r_start = y
            elif c <= 40 and in_r:
                in_r = False
                r_segments.append((r_start, y))
        if in_r:
            r_segments.append((r_start, h))

        print(f"\n=======================================================")
        print(f"Sheet Unknown-{idx}.webp ({w}x{h}): {len(r_segments)} row bands:")
        for r_i, (ry0, ry1) in enumerate(r_segments):
            # Find columns within this row
            in_c = False
            c_segments = []
            c_start = 0
            sub_col_counts = [sum(1 for y in range(ry0, ry1) if not is_bg_or_grid(get_rgb(x, y))) for x in range(w)]
            for x, cc in enumerate(sub_col_counts):
                if cc > 15 and not in_c:
                    in_c = True
                    c_start = x
                elif cc <= 15 and in_c:
                    in_c = False
                    c_segments.append((c_start, x))
            if in_c:
                c_segments.append((c_start, w))
            print(f"  Row {r_i+1} [y={ry0}..{ry1}]: {len(c_segments)} items:")
            for ci, (cx0, cx1) in enumerate(c_segments):
                # Pixel count
                cnt = sum(1 for y in range(ry0, ry1) for x in range(cx0, cx1) if not is_bg_or_grid(get_rgb(x, y)))
                print(f"    Item {ci+1}: x={cx0}..{cx1} (w={cx1-cx0+1}), pixels={cnt}")

if __name__ == '__main__':
    inspect_all()
