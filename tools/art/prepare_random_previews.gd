extends SceneTree
## Keep generated originals in source_art; export compact, editable 128x72 game assets.
func _initialize() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/preview_catalog.json"))
	for item in catalog.items:
		var source := "res://source_art/stream_previews/library_v02/%s_original.png" % item.id
		var image := Image.load_from_file(source)
		if image == null:
			quit(1)
			return
		image.convert(Image.FORMAT_RGBA8)
		image.resize(int(catalog.canvas_size[0]), int(catalog.canvas_size[1]), Image.INTERPOLATE_NEAREST)
		if image.save_png(item.texture) != OK:
			quit(1)
			return
	print("Random preview library: four 128x72 assets prepared")
	quit()
