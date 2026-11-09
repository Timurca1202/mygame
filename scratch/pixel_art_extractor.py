import os, struct, zlib, subprocess

def save_png(path, width, height, rgba_bytes):
    line_bytes = width * 4
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw.extend(rgba_bytes[y * line_bytes : (y + 1) * line_bytes])
    compressed = zlib.compress(bytes(raw), 9)
    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    ihdr_crc = zlib.crc32(b'IHDR' + ihdr) & 0xffffffff
    idat_crc = zlib.crc32(b'IDAT' + compressed) & 0xffffffff
    iend_crc = zlib.crc32(b'IEND') & 0xffffffff
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(struct.pack('>I', len(ihdr)) + b'IHDR' + ihdr + struct.pack('>I', ihdr_crc))
        f.write(struct.pack('>I', len(compressed)) + b'IDAT' + compressed + struct.pack('>I', idat_crc))
        f.write(struct.pack('>I', 0) + b'IEND' + struct.pack('>I', iend_crc))

def load_bmp(bmp_path):
    with open(bmp_path, 'rb') as f:
        hdr = f.read(54)
        offset = struct.unpack('<I', hdr[10:14])[0]
        w, h = struct.unpack('<ii', hdr[18:26])
        h = abs(h)
        f.seek(offset)
        raw = f.read()
    row_bytes = (w * 3 + 3) & ~3
    return w, h, raw, row_bytes

def is_pixel_art_bg_or_grid(r, g, b):
    # Base dark blue-slate bg: RGB ~(36, 42, 49)
    # Grid lines: minor RGB ~(49, 54, 62), major RGB ~(67, 72, 84), sheet border ~(65, 71, 78)
    if r < 85 and g < 95 and b < 105:
        if abs(r - (g - 6)) <= 8 and abs(b - (g + 8)) <= 8:
            return True
    return False

def extract_pixel_art_item(raw, sheet_w, sheet_h, row_bytes, search_box, label_box, margin=2):
    # search_box = (x0, x1, y0, y1)
    # label_box = (lx0, lx1, ly0, ly1) to exclude text label if within search_box
    x0, x1, y0, y1 = search_box
    
    def get_rgb(x, y):
        i = y * row_bytes + x * 3
        return raw[i+2], raw[i+1], raw[i]

    # Find item pixels inside search_box excluding label_box
    item_pts = []
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if label_box:
                lx0, lx1, ly0, ly1 = label_box
                if lx0 <= x <= lx1 and ly0 <= y <= ly1:
                    continue
            r, g, b = get_rgb(x, y)
            if not is_pixel_art_bg_or_grid(r, g, b):
                item_pts.append((x, y))

    if not item_pts:
        return None

    # Compute bounding box
    min_x = min(p[0] for p in item_pts)
    max_x = max(p[0] for p in item_pts)
    min_y = min(p[1] for p in item_pts)
    max_y = max(p[1] for p in item_pts)

    # Add margin
    crop_x0 = max(0, min_x - margin)
    crop_x1 = min(sheet_w - 1, max_x + margin)
    crop_y0 = max(0, min_y - margin)
    crop_y1 = min(sheet_h - 1, max_y + margin)
    cw = crop_x1 - crop_x0 + 1
    ch = crop_y1 - crop_y0 + 1

    # Extract RGBA
    rgba = bytearray(cw * ch * 4)
    mask = bytearray(cw * ch * 4)
    for cy in range(ch):
        y = crop_y0 + cy
        for cx in range(cw):
            x = crop_x0 + cx
            r, g, b = get_rgb(x, y)
            idx = (cy * cw + cx) * 4
            
            # Check if this pixel is inside the label box
            is_label = False
            if label_box:
                lx0, lx1, ly0, ly1 = label_box
                if lx0 <= x <= lx1 and ly0 <= y <= ly1:
                    is_label = True

            if is_pixel_art_bg_or_grid(r, g, b) or is_label:
                rgba[idx] = 0; rgba[idx+1] = 0; rgba[idx+2] = 0; rgba[idx+3] = 0
                mask[idx] = 0; mask[idx+1] = 0; mask[idx+2] = 0; mask[idx+3] = 255
            else:
                rgba[idx] = r; rgba[idx+1] = g; rgba[idx+2] = b; rgba[idx+3] = 255
                mask[idx] = 255; mask[idx+1] = 255; mask[idx+2] = 255; mask[idx+3] = 255

    return {
        "width": cw,
        "height": ch,
        "crop_box": (crop_x0, crop_y0, crop_x1, crop_y1),
        "item_bbox": (min_x, min_y, max_x - min_x + 1, max_y - min_y + 1),
        "pixel_count": len(item_pts),
        "rgba": bytes(rgba),
        "mask": bytes(mask)
    }

print("Extractor module compiled.")
