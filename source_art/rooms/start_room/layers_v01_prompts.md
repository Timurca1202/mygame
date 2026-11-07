# Room layer preparation

Tool: built-in imagegen. Source: `assets/art/rooms/e1/poor_corner_expanded_v01.png`.
The approved composite is preserved. The layers are aligned in the Godot scene.

## shell

Precise-object-edit: remove ONLY the wooden desk, all objects on the desk, the stool, and their shadows from this approved game room. Reconstruct wallpaper, baseboard and patterned linoleum previously hidden by them seamlessly. Keep the entire rest of the image EXACTLY unchanged: same camera, spacious floor diamond, wall heights, window, lamp, wallpaper cracks, scattered floor scraps, room silhouette, margins, lighting, colors, pixel-art texture. Same square framing and canvas dimensions as input, do not zoom or recenter, do not add anything. Output clean empty room shell. Preserve opaque background. Production background layer for the same Godot scene.

## desk

Background-extraction: extract ONLY the wooden desk and ALL its tabletop objects from this approved game room into a genuinely TRANSPARENT PNG. Include stack of books, foil aerial, button phone, mug, papers, eraser, desk drawer and ALL desk legs. REMOVE stool, room, walls, floor, lamp, window and all background completely. Reconstruct the desk surfaces and legs obscured by the stool consistently. Keep the exact same pixel-art style, proportions, camera, textures, colors, desk size and original position on the FULL SQUARE canvas as in input. Do NOT center or enlarge desk. Full canvas must remain the same as input, with the desk located in its original left-middle position, transparent everywhere else. No baked wallpaper or floor pixels, no ground plane, no extra objects, no text. Crisp alpha edges.

## stool

Background-extraction: extract ONLY the small wooden stool in front of the desk from the supplied approved game room. Output genuinely TRANSPARENT PNG, all background, desk and other objects removed. Keep EXACT stool shape, seat, legs, braces, perspective, worn wood texture and pixel-art style. Preserve stool size and its exact original position in FULL SQUARE canvas as input. Do NOT enlarge or center stool; leave transparent space around it matching original full image framing. Clean alpha edges, no floor fragment, no background, no text. Production foreground furniture layer.

