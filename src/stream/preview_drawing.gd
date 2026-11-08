extends RefCounted
## A pixel document with stroke undo, offline rating and an atomic accepted-preview save.
var config: Dictionary
var image: Image
var source_id := ""
var load_error: Error = OK
var recovered_from_backup := false
var undo_stack: Array[Dictionary] = []
var _before: Dictionary = {}
var _last := Vector2i(-1, -1)
var _changed := false

func _init(catalog: Dictionary) -> void:
	config = catalog.duplicate(true)
	config.editor.brushes = config.editor.brushes.map(func(value): return int(value))
	image = Image.create(int(config.canvas_size[0]), int(config.canvas_size[1]), false, Image.FORMAT_RGBA8)
	image.fill(background())

func background() -> Color:
	return Color(config.editor.palette[0])

func snapshot() -> Dictionary:
	return {"image": image.duplicate(), "source_id": source_id}

func restore(state: Dictionary) -> void:
	image = state.image.duplicate()
	source_id = str(state.source_id)
	_before = {}
	_last = Vector2i(-1, -1)

func _remember(state: Dictionary) -> void:
	undo_stack.append(state)
	if undo_stack.size() > int(config.editor.undo_limit):
		undo_stack.pop_front()

func begin_stroke(point: Vector2i, color: Color, size: int) -> void:
	end_stroke()
	if not Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
		return
	_before = snapshot()
	_changed = false
	draw_to(point, color, size)

func draw_to(point: Vector2i, color: Color, size: int) -> void:
	if _before.is_empty() or not config.editor.brushes.has(size):
		return
	if not Rect2i(Vector2i.ZERO, image.get_size()).has_point(point):
		_last = Vector2i(-1, -1)
		return
	var start := point if _last.x < 0 else _last
	# Interpolate quick drags so a stroke never leaves gaps between input events.
	var steps := maxi(absi(point.x - start.x), absi(point.y - start.y))
	for step in range(steps + 1):
		var pixel := Vector2i(Vector2(start).lerp(Vector2(point), float(step) / maxf(1.0, steps)).round())
		var radius := size / 2
		for y in range(maxi(0, pixel.y - radius), mini(image.get_height(), pixel.y + radius + 1)):
			for x in range(maxi(0, pixel.x - radius), mini(image.get_width(), pixel.x + radius + 1)):
				if image.get_pixel(x, y) != color:
					image.set_pixel(x, y, color)
					_changed = true
					source_id = ""
	_last = point

func end_stroke() -> void:
	if not _before.is_empty() and _changed:
		_remember(_before)
	_before = {}
	_changed = false
	_last = Vector2i(-1, -1)

func undo() -> void:
	end_stroke()
	if not undo_stack.is_empty():
		restore(undo_stack.pop_back())

func clear() -> void:
	end_stroke()
	if has_content():
		_remember(snapshot())
	image.fill(background())
	source_id = ""

func library_entry() -> Dictionary:
	for entry in config.items:
		if str(entry.id) == source_id:
			return entry
	return {}

func use_library(index: int) -> bool:
	end_stroke()
	if index < 0 or index >= config.items.size():
		return false
	var texture := load(str(config.items[index].texture)) as Texture2D
	if texture == null:
		return false
	var next := texture.get_image()
	if next.is_compressed():
		next.decompress()
	next.convert(Image.FORMAT_RGBA8)
	next.resize(image.get_width(), image.get_height(), Image.INTERPOLATE_NEAREST)
	_remember(snapshot())
	image = next
	source_id = str(config.items[index].id)
	return true

func randomize_from_library(rng: RandomNumberGenerator) -> bool:
	var choices: Array[int] = []
	for index in range(config.items.size()):
		if str(config.items[index].id) != source_id:
			choices.append(index)
	if choices.is_empty():
		return false
	return use_library(choices[rng.randi_range(0, choices.size() - 1)])

func has_content() -> bool:
	var blank := background()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y) != blank:
				return true
	return false

func rating() -> float:
	var entry := library_entry()
	if not entry.is_empty():
		return float(entry.score)
	var covered := 0
	var colors := {}
	var bins := {}
	var low := 1.0
	var high := 0.0
	var blank := background()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			var luminance := pixel.get_luminance()
			low = minf(low, luminance)
			high = maxf(high, luminance)
			if pixel == blank:
				continue
			covered += 1
			colors[pixel.to_rgba32()] = true
			var bin := Vector2i(x * 4 / image.get_width(), y * 4 / image.get_height())
			bins[bin] = int(bins.get(bin, 0)) + 1
	if covered == 0:
		return 0.0
	var parameters: Dictionary = config.editor.rating
	var coverage := float(covered) / (image.get_width() * image.get_height())
	var coverage_score := minf(1.0, coverage / float(parameters.coverage_ideal[0]))
	if coverage > float(parameters.coverage_ideal[1]):
		coverage_score *= (1.0 - coverage) / (1.0 - float(parameters.coverage_ideal[1]))
	var color_score := minf(1.0, float(colors.size()) / float(parameters.color_ideal[0]))
	if colors.size() > int(parameters.color_ideal[1]):
		color_score *= float(parameters.color_ideal[1]) / colors.size()
	var focus := 0.0
	for count in bins.values():
		focus = maxf(focus, float(count) / covered)
	var weights: Dictionary = parameters.weights
	var score := coverage_score * float(weights.coverage) + color_score * float(weights.colors)
	score += minf(1.0, (high - low) / float(parameters.contrast_reference)) * float(weights.contrast)
	score += minf(1.0, focus / float(parameters.focus_reference)) * float(weights.focus)
	return clampf(score, float(parameters.minimum), 100.0)

func selection() -> Dictionary:
	var entry := library_entry()
	return {"id": source_id if not entry.is_empty() else "drawn", "name": str(entry.name) if not entry.is_empty() else str(config.editor.text.custom_name), "score": rating(), "texture": ImageTexture.create_from_image(image)}

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > int(config.editor.max_save_bytes):
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not envelope.get("payload") is String:
		return {}
	if str(envelope.get("checksum", "")) != str(envelope.payload).sha256_text():
		return {}
	if parser.parse(envelope.payload) != OK:
		return {}
	var payload: Variant = parser.data
	if not payload is Dictionary or not (payload.get("version") is float or payload.get("version") is int):
		return {}
	if float(payload.version) > 1.0:
		return {"future": true}
	if float(payload.version) != 1.0 or not payload.get("png") is String or not payload.get("source_id") is String:
		return {}
	var bytes := Marshalls.base64_to_raw(payload.png)
	# Validate PNG dimensions before decompression, so corrupt saves cannot allocate huge images.
	if bytes.size() < 24 or bytes.slice(0, 8) != PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		return {}
	var dimensions := Vector2i.ZERO
	for index in range(4):
		dimensions.x = (dimensions.x << 8) | bytes[16 + index]
		dimensions.y = (dimensions.y << 8) | bytes[20 + index]
	if dimensions != image.get_size():
		return {}
	var decoded := Image.new()
	if decoded.load_png_from_buffer(bytes) != OK or decoded.get_size() != image.get_size():
		return {}
	decoded.convert(Image.FORMAT_RGBA8)
	return {"image": decoded, "source_id": payload.source_id}

func load_saved(path: String) -> Error:
	var state := _read(path)
	if state.get("future", false):
		load_error = ERR_UNAVAILABLE
		return load_error
	if state.is_empty():
		state = _read(path + ".bak")
		if state.get("future", false):
			load_error = ERR_UNAVAILABLE
			return load_error
		recovered_from_backup = not state.is_empty()
	if state.is_empty():
		load_error = ERR_FILE_CORRUPT if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") else OK
	else:
		restore(state)
		load_error = OK
	return load_error

func save(path: String) -> Error:
	end_stroke()
	if load_error != OK:
		return load_error
	if not has_content():
		return ERR_INVALID_DATA
	var payload := JSON.stringify({"version": 1, "source_id": source_id, "png": Marshalls.raw_to_base64(image.save_png_to_buffer())})
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if _read(path + ".tmp").is_empty():
		return ERR_FILE_CORRUPT
	var previous := _read(path)
	if not previous.is_empty() and not previous.get("future", false):
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error == OK:
		recovered_from_backup = false
	return error
