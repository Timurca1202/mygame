import os, subprocess, struct

def inspect_all_devices():
    device_dir = 'ref/device'
    for root, dirs, files in os.walk(device_dir):
        for f in sorted(files):
            if f.startswith('.'): continue
            p = os.path.join(root, f)
            bmp = '/tmp/dev_temp.bmp'
            subprocess.run(['sips', '-s', 'format', 'bmp', p, '--out', bmp], capture_output=True, check=True)
            with open(bmp, 'rb') as fh:
                hdr = fh.read(54)
                offset = struct.unpack('<I', hdr[10:14])[0]
                w, h = struct.unpack('<ii', hdr[18:26])
                h = abs(h)
                fh.seek(offset)
                raw = fh.read()
            row_bytes = (w * 3 + 3) & ~3
            def get_rgb(x, y):
                i = y * row_bytes + x * 3
                return raw[i+2], raw[i+1], raw[i]

            c0 = get_rgb(10, 10)
            c1 = get_rgb(w-10, 10)
            c2 = get_rgb(10, h-10)
            c3 = get_rgb(w-10, h-10)
            bg_r = (c0[0] + c1[0] + c2[0] + c3[0]) // 4
            bg_g = (c0[1] + c1[1] + c2[1] + c3[1]) // 4
            bg_b = (c0[2] + c1[2] + c2[2] + c3[2]) // 4

            def is_bg(r, g, b):
                return abs(r - bg_r) <= 18 and abs(g - bg_g) <= 18 and abs(b - bg_b) <= 18

            # Quick row profiling
            step = 8
            row_counts = [sum(1 for x in range(0, w, step) if not is_bg(*get_rgb(x, y))) for y in range(0, h, step)]
            in_r = False
            r_bands = []
            r_start = 0
            for idx, c in enumerate(row_counts):
                y = idx * step
                if c > 30 and not in_r:
                    in_r = True
                    r_start = y
                elif c <= 30 and in_r:
                    in_r = False
                    r_bands.append((r_start, y))
            if in_r: r_bands.append((r_start, h))

            rel = os.path.relpath(p, 'ref/device')
            print(f"\nDevice: {rel} ({w}x{h}), BG: RGB({bg_r},{bg_g},{bg_b}), {len(r_bands)} rows:")
            for r_i, (y0, y1) in enumerate(r_bands):
                if y1 - y0 < 50: continue # ignore thin noise lines
                # find cols
                sub_cols = [sum(1 for y in range(y0, y1, step) if not is_bg(*get_rgb(x, y))) for x in range(0, w, step)]
                in_c = False
                c_bands = []
                c_start = 0
                for c_idx, cc in enumerate(sub_cols):
                    x = c_idx * step
                    if cc > 15 and not in_c:
                        in_c = True
                        c_start = x
                    elif cc <= 15 and in_c:
                        in_c = False
                        c_bands.append((c_start, x))
                if in_c: c_bands.append((c_start, w))
                c_filtered = [c for c in c_bands if c[1] - c[0] > 40]
                print(f"  Row {r_i+1} [y={y0}..{y1}]: {len(c_filtered)} items")

if __name__ == '__main__':
    inspect_all_devices()
