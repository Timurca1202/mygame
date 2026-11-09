import os, struct, subprocess

def analyze_sheet(webp_path):
    bmp_path = '/tmp/current_sheet.bmp'
    subprocess.run(['sips', '-s', 'format', 'bmp', webp_path, '--out', bmp_path], capture_output=True, check=True)
    
    with open(bmp_path, 'rb') as f:
        hdr = f.read(54)
        offset = struct.unpack('<I', hdr[10:14])[0]
        w, h = struct.unpack('<ii', hdr[18:26])
        bpp = struct.unpack('<H', hdr[28:30])[0]
        f.seek(offset)
        raw = f.read()
    
    h = abs(h)
    row_bytes = (w * (bpp // 8) + 3) & ~3
    
    def get_rgb(x, y):
        idx = y * row_bytes + x * 3
        return raw[idx+2], raw[idx+1], raw[idx] # R, G, B
        
    c0 = get_rgb(0, 0)
    c1 = get_rgb(w-1, 0)
    c2 = get_rgb(0, h-1)
    c3 = get_rgb(w-1, h-1)
    bg_r = (c0[0] + c1[0] + c2[0] + c3[0]) // 4
    bg_g = (c0[1] + c1[1] + c2[1] + c3[1]) // 4
    bg_b = (c0[2] + c1[2] + c2[2] + c3[2]) // 4
    
    print(f"\n=======================================================")
    print(f"Sheet: {webp_path} ({w}x{h}), BG: RGB({bg_r}, {bg_g}, {bg_b})")
    
    # Outer flood fill
    is_outer_bg = [False] * (w * h)
    queue = []
    
    def is_bg_color(r, g, b):
        return abs(r - bg_r) <= 15 and abs(g - bg_g) <= 15 and abs(b - bg_b) <= 15
        
    for x in range(w):
        r, g, b = get_rgb(x, 0)
        if is_bg_color(r, g, b):
            is_outer_bg[x] = True
            queue.append(x)
        r, g, b = get_rgb(x, h - 1)
        b_idx = (h - 1) * w + x
        if is_bg_color(r, g, b):
            is_outer_bg[b_idx] = True
            queue.append(b_idx)
            
    for y in range(h):
        r, g, b = get_rgb(0, y)
        l_idx = y * w
        if not is_outer_bg[l_idx] and is_bg_color(r, g, b):
            is_outer_bg[l_idx] = True
            queue.append(l_idx)
        r, g, b = get_rgb(w - 1, y)
        r_idx = y * w + (w - 1)
        if not is_outer_bg[r_idx] and is_bg_color(r, g, b):
            is_outer_bg[r_idx] = True
            queue.append(r_idx)
            
    head = 0
    while head < len(queue):
        cur = queue[head]
        head += 1
        cx = cur % w
        cy = cur // w
        for nx, ny in ((cx-1, cy), (cx+1, cy), (cx, cy-1), (cx, cy+1)):
            if 0 <= nx < w and 0 <= ny < h:
                nidx = ny * w + nx
                if not is_outer_bg[nidx]:
                    r, g, b = get_rgb(nx, ny)
                    if is_bg_color(r, g, b):
                        is_outer_bg[nidx] = True
                        queue.append(nidx)
                        
    # Connected components
    visited = [False] * (w * h)
    components = []
    
    for y in range(h):
        for x in range(w):
            idx = y * w + x
            if is_outer_bg[idx] or visited[idx]:
                continue
            
            c_min_x, c_max_x = x, x
            c_min_y, c_max_y = y, y
            c_pixels = 0
            c_queue = [idx]
            visited[idx] = True
            c_head = 0
            
            while c_head < len(c_queue):
                p = c_queue[c_head]
                c_head += 1
                px = p % w
                py = p // w
                c_pixels += 1
                if px < c_min_x: c_min_x = px
                if px > c_max_x: c_max_x = px
                if py < c_min_y: c_min_y = py
                if py > c_max_y: c_max_y = py
                
                for nx, ny in ((px-1, py), (px+1, py), (px, py-1), (px, py+1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        nidx = ny * w + nx
                        if not is_outer_bg[nidx] and not visited[nidx]:
                            visited[nidx] = True
                            c_queue.append(nidx)
                            
            if c_pixels > 120: # ignore tiny specks / tiny letters
                cw = c_max_x - c_min_x + 1
                ch = c_max_y - c_min_y + 1
                components.append((c_min_x, c_min_y, cw, ch, c_pixels))
                
    components.sort(key=lambda c: (c[1] // 150, c[0]))
    print(f"Detected {len(components)} objects (>120 px):")
    for i, c in enumerate(components):
        print(f"  Item {i+1:2}: x={c[0]:3}, y={c[1]:3}, w={c[2]:3}, h={c[3]:3}, pixels={c[4]}")

if __name__ == '__main__':
    for idx in range(2, 8):
        analyze_sheet(f'ref/items/Unknown-{idx}.webp')
