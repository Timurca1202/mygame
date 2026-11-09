#!/usr/bin/env python3
import os, struct, zlib, subprocess, json

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
    # Base dark blue-slate bg: RGB ~(36, 42, 49) with webp compression variation
    # Grid lines: minor RGB ~(49, 54, 62), major RGB ~(67, 72, 84), sheet border ~(65, 71, 78)
    if r <= 46 and g <= 54 and b <= 58 and abs(r - g) <= 12 and abs(b - g) <= 12:
        return True
    if r < 88 and g < 98 and b < 108:
        if abs(r - (g - 6)) <= 10 and abs(b - (g + 8)) <= 10:
            return True
        if abs(r - g) <= 8 and abs(b - g) <= 10 and max(r, g, b) <= 65:
            return True
    return False

def is_device_bg(r, g, b, bg_r, bg_g, bg_b, tolerance=15):
    return abs(r - bg_r) <= tolerance and abs(g - bg_g) <= tolerance and abs(b - bg_b) <= tolerance

def extract_pixel_art_cell(raw, sheet_w, sheet_h, row_bytes, cell_box, label_box, margin=2):
    x0, x1, y0, y1 = cell_box
    def get_rgb(x, y):
        i = y * row_bytes + x * 3
        return raw[i+2], raw[i+1], raw[i]

    # Normalize label_boxes to a list of boxes
    lboxes = []
    if label_box:
        if isinstance(label_box, list):
            lboxes = label_box
        else:
            lboxes = [label_box]

    def is_in_label(x, y):
        for lb in lboxes:
            if lb and lb[0] <= x <= lb[1] and lb[2] <= y <= lb[3]:
                return True
        return False

    item_pts = set()
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if is_in_label(x, y):
                continue
            r, g, b = get_rgb(x, y)
            if not is_pixel_art_bg_or_grid(r, g, b):
                item_pts.add((x, y))

    if not item_pts:
        return None

    min_x = min(p[0] for p in item_pts)
    max_x = max(p[0] for p in item_pts)
    min_y = min(p[1] for p in item_pts)
    max_y = max(p[1] for p in item_pts)

    crop_x0 = max(0, min_x - margin)
    crop_x1 = min(sheet_w - 1, max_x + margin)
    crop_y0 = max(0, min_y - margin)
    crop_y1 = min(sheet_h - 1, max_y + margin)
    cw = crop_x1 - crop_x0 + 1
    ch = crop_y1 - crop_y0 + 1

    rgba = bytearray(cw * ch * 4)
    mask = bytearray(cw * ch * 4)
    for cy in range(ch):
        y = crop_y0 + cy
        for cx in range(cw):
            x = crop_x0 + cx
            idx = (cy * cw + cx) * 4
            if (x, y) in item_pts:
                r, g, b = get_rgb(x, y)
                rgba[idx] = r; rgba[idx+1] = g; rgba[idx+2] = b; rgba[idx+3] = 255
                mask[idx] = 255; mask[idx+1] = 255; mask[idx+2] = 255; mask[idx+3] = 255
            else:
                rgba[idx] = 0; rgba[idx+1] = 0; rgba[idx+2] = 0; rgba[idx+3] = 0
                mask[idx] = 0; mask[idx+1] = 0; mask[idx+2] = 0; mask[idx+3] = 255

    return {
        "width": cw,
        "height": ch,
        "crop_box": (crop_x0, crop_y0, crop_x1, crop_y1),
        "item_bbox": (min_x, min_y, max_x - min_x + 1, max_y - min_y + 1),
        "pixel_count": len(item_pts),
        "rgba": bytes(rgba),
        "mask": bytes(mask)
    }

def extract_device_item(raw, sheet_w, sheet_h, row_bytes, box, bg_rgb, tolerance=14, margin=4, drop_floor_shadow=True, shadow_y_thresh=None):
    x0, x1, y0, y1 = box
    bg_r, bg_g, bg_b = bg_rgb
    def get_rgb(x, y):
        i = y * row_bytes + x * 3
        return raw[i+2], raw[i+1], raw[i]

    def is_bg(x, y):
        r, g, b = get_rgb(x, y)
        if abs(r - bg_r) <= tolerance and abs(g - bg_g) <= tolerance and abs(b - bg_b) <= tolerance:
            return True
        if drop_floor_shadow and shadow_y_thresh and y >= shadow_y_thresh:
            if r < bg_r - 6 and g < bg_g - 6 and b < bg_b - 6 and abs(r - g) < 8 and abs(b - g) < 8:
                return True
        return False

    cx0 = max(0, x0 - margin)
    cx1 = min(sheet_w - 1, x1 + margin)
    cy0 = max(0, y0 - margin)
    cy1 = min(sheet_h - 1, y1 + margin)
    cw = cx1 - cx0 + 1
    ch = cy1 - cy0 + 1

    # Outer perimeter flood-fill
    is_outer = [False] * (cw * ch)
    q = []
    for cx in range(cw):
        is_outer[0 * cw + cx] = True; q.append((cx, 0))
        is_outer[(ch - 1) * cw + cx] = True; q.append((cx, ch - 1))
    for cy in range(ch):
        if not is_outer[cy * cw + 0]:
            is_outer[cy * cw + 0] = True; q.append((0, cy))
        if not is_outer[cy * cw + (cw - 1)]:
            is_outer[cy * cw + (cw - 1)] = True; q.append((cw - 1, cy))

    head = 0
    while head < len(q):
        cx, cy = q[head]
        head += 1
        for nx, ny in ((cx-1, cy), (cx+1, cy), (cx, cy-1), (cx, cy+1)):
            if 0 <= nx < cw and 0 <= ny < ch:
                nidx = ny * cw + nx
                if not is_outer[nidx] and is_bg(cx0 + nx, cy0 + ny):
                    is_outer[nidx] = True
                    q.append((nx, ny))

    # Candidate item pixels
    candidate_pts = []
    for cy in range(ch):
        for cx in range(cw):
            if not is_outer[cy * cw + cx]:
                candidate_pts.append((cx, cy))

    if not candidate_pts:
        return None

    # Filter out tiny disconnected islands (< 50 connected pixels)
    c_set = set(candidate_pts)
    visited = set()
    kept_pts = set()
    for p in candidate_pts:
        if p in visited: continue
        comp = []
        comp_q = [p]
        visited.add(p)
        while comp_q:
            cur = comp_q.pop()
            comp.append(cur)
            cx, cy = cur
            for nx, ny in ((cx-1, cy), (cx+1, cy), (cx, cy-1), (cx, cy+1)):
                if (nx, ny) in c_set and (nx, ny) not in visited:
                    visited.add((nx, ny))
                    comp_q.append((nx, ny))
        if len(comp) >= 50:
            for pt in comp:
                kept_pts.add(pt)

    if not kept_pts:
        kept_pts = c_set

    # Build RGBA and Mask
    rgba = bytearray(cw * ch * 4)
    mask = bytearray(cw * ch * 4)
    opaque_count = 0
    item_xs = []
    item_ys = []

    for cy in range(ch):
        y = cy0 + cy
        for cx in range(cw):
            x = cx0 + cx
            idx = (cy * cw + cx) * 4
            if (cx, cy) in kept_pts:
                r, g, b = get_rgb(x, y)
                rgba[idx] = r; rgba[idx+1] = g; rgba[idx+2] = b; rgba[idx+3] = 255
                mask[idx] = 255; mask[idx+1] = 255; mask[idx+2] = 255; mask[idx+3] = 255
                opaque_count += 1
                item_xs.append(x)
                item_ys.append(y)
            else:
                rgba[idx] = 0; rgba[idx+1] = 0; rgba[idx+2] = 0; rgba[idx+3] = 0
                mask[idx] = 0; mask[idx+1] = 0; mask[idx+2] = 0; mask[idx+3] = 255

    min_x = min(item_xs) if item_xs else x0
    max_x = max(item_xs) if item_xs else x1
    min_y = min(item_ys) if item_ys else y0
    max_y = max(item_ys) if item_ys else y1

    return {
        "width": cw,
        "height": ch,
        "crop_box": (cx0, cy0, cx1, cy1),
        "item_bbox": (min_x, min_y, max_x - min_x + 1, max_y - min_y + 1),
        "pixel_count": opaque_count,
        "rgba": bytes(rgba),
        "mask": bytes(mask)
    }

print("Asset preparation engine initialized.")
