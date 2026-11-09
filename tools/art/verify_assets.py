#!/usr/bin/env python3
import os, sys, struct, zlib, json

def read_png(path):
    with open(path, 'rb') as f:
        sig = f.read(8)
        assert sig == b'\x89PNG\r\n\x1a\n', f"Invalid PNG signature: {path}"
        raw_idat = bytearray()
        w, h, bit_depth, color_type = 0, 0, 0, 0
        while True:
            chunk_len_b = f.read(4)
            if not chunk_len_b: break
            chunk_len = struct.unpack('>I', chunk_len_b)[0]
            chunk_type = f.read(4)
            chunk_data = f.read(chunk_len)
            crc = f.read(4)
            if chunk_type == b'IHDR':
                w, h, bit_depth, color_type = struct.unpack('>IIBB', chunk_data[:10])
            elif chunk_type == b'IDAT':
                raw_idat.extend(chunk_data)
            elif chunk_type == b'IEND':
                break
    decomp = zlib.decompress(bytes(raw_idat))
    line_len = 1 + w * 4
    # Reconstruct rgba buffer (filter type 0 expected)
    rgba = bytearray(w * h * 4)
    for y in range(h):
        line_filter = decomp[y * line_len]
        assert line_filter == 0, f"Unsupported PNG filter {line_filter} in {path}"
        line_slice = decomp[y * line_len + 1 : (y + 1) * line_len]
        rgba[y * w * 4 : (y + 1) * w * 4] = line_slice
    return w, h, rgba, bit_depth, color_type

def verify_all_assets():
    with open('data/art/reference_asset_catalog.json') as f:
        catalog = json.load(f)
    
    total = len(catalog['assets'])
    print(f"Starting verification of {total} extracted assets...")
    
    passed = 0
    failures = []

    for item in catalog['assets']:
        cat = item['category']
        name = item['id']
        png_path = f"assets/art/{cat}/{name}.png"
        mask_path = f"source_art/{cat}/{name}/mask.png"
        prov_path = f"source_art/{cat}/{name}/provenance.json"

        # Check file existence
        if not os.path.exists(png_path):
            failures.append((name, f"Missing PNG: {png_path}"))
            continue
        if not os.path.exists(mask_path):
            failures.append((name, f"Missing Mask: {mask_path}"))
            continue
        if not os.path.exists(prov_path):
            failures.append((name, f"Missing Provenance: {prov_path}"))
            continue

        w, h, rgba, bit_depth, color_type = read_png(png_path)
        
        # 1. 32-bit RGBA check
        if bit_depth != 8 or color_type != 6:
            failures.append((name, f"Not 32-bit RGBA (bit_depth={bit_depth}, color_type={color_type})"))
            continue

        # 2. Border clearance (all 4 edges must have 100% alpha = 0)
        top_a = [rgba[(0 * w + x) * 4 + 3] for x in range(w)]
        bot_a = [rgba[((h - 1) * w + x) * 4 + 3] for x in range(w)]
        left_a = [rgba[(y * w + 0) * 4 + 3] for y in range(h)]
        right_a = [rgba[(y * w + (w - 1)) * 4 + 3] for y in range(h)]
        border_sum = sum(top_a) + sum(bot_a) + sum(left_a) + sum(right_a)
        if border_sum > 0:
            failures.append((name, f"Border leakage: {border_sum} non-zero alpha on boundary"))
            continue

        # 3. True transparency check
        alpha_values = set(rgba[i+3] for i in range(0, len(rgba), 4))
        if 0 not in alpha_values:
            failures.append((name, "No transparent pixels found (missing alpha channel content)"))
            continue
        if 255 not in alpha_values:
            failures.append((name, "No opaque pixels found"))
            continue

        # 4. Pixel art purity check (no blurry anti-aliasing edges for decor)
        if cat == 'decor':
            semi_transparent = sum(1 for i in range(0, len(rgba), 4) if 0 < rgba[i+3] < 255)
            if semi_transparent > 0:
                failures.append((name, f"Pixel art has {semi_transparent} semi-transparent pixels (loss of crisp pixel styling)"))
                continue

        # 5. Contrast tests against white (#FFFFFF) and black (#000000)
        # Verify edge transition pixels don't leave lingering background slate color
        # Base slate bg was ~(36, 42, 49) or ~(58, 59, 64)
        halo_count = 0
        for y in range(1, h - 1):
            for x in range(1, w - 1):
                idx = (y * w + x) * 4
                if rgba[idx+3] == 255:
                    # check if it touches transparent
                    has_empty_neighbor = any(
                        rgba[((y + dy) * w + (x + dx)) * 4 + 3] == 0
                        for dx, dy in ((-1,0), (1,0), (0,-1), (0,1))
                    )
                    if has_empty_neighbor:
                        r, g, b = rgba[idx], rgba[idx+1], rgba[idx+2]
                        # check if edge pixel is an unremoved pixel art background slate pixel
                        if cat == 'decor' and (34 <= r <= 42 and 40 <= g <= 48 and 46 <= b <= 54):
                            halo_count += 1
        
        if halo_count > 0:
            failures.append((name, f"Halo detected: {halo_count} unremoved background pixels at edge"))
            continue

        passed += 1

    print(f"\nVerification Results: {passed}/{total} PASSED")
    if failures:
        print(f"FAILED ({len(failures)}):")
        for name, reason in failures:
            print(f"  - {name}: {reason}")
        return False
    else:
        print("Technical checks passed. Visual acceptance is separate; inspect catalog statuses before integration.")
        return True

if __name__ == '__main__':
    if not verify_all_assets():
        sys.exit(1)
