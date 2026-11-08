extends SceneTree
const Drawing = preload("res://src/stream/preview_drawing.gd")
var checks := 0
var failures := 0
var catalog: Dictionary
var path := "user://drawing_test_%d.json" % OS.get_process_id()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func write_payload(payload: Dictionary, target: String) -> void:
	var encoded := JSON.stringify(payload)
	var file := FileAccess.open(target, FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": encoded, "checksum": encoded.sha256_text()}))
	file.close()

func _initialize() -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/preview_catalog.json"))
	var document := Drawing.new(catalog)
	check(document.image.get_size() == Vector2i(128, 72) and not document.has_content(), "Document starts as blank 128x72 canvas")
	check(document.rating() == 0 and document.save(path) == ERR_INVALID_DATA, "Blank previews cannot be accepted")
	check(document.load_saved(path) == OK and not FileAccess.file_exists(path), "Reading a fresh document cannot create a save")
	var color := Color(catalog.editor.palette[6])
	document.begin_stroke(Vector2i(0, 0), color, 1)
	document.draw_to(Vector2i(127, 71), color, 1)
	document.end_stroke()
	check(document.undo_stack.size() == 1, "Long drag produces one undo step")
	check(document.image.get_pixel(0, 0) == color and document.image.get_pixel(127, 71) == color, "Stroke reaches both canvas corners")
	for x in range(128):
		var found := false
		for y in range(72):
			found = found or document.image.get_pixel(x, y) == color
		check(found, "Fast diagonal stroke has no skipped columns")
	check(document.rating() >= 30 and document.rating() <= 100, "A nonempty drawing has a bounded offline rating")
	document.undo()
	check(not document.has_content(), "Undo removes the entire stroke")
	document.begin_stroke(Vector2i(0, 0), color, 5)
	document.end_stroke()
	check(document.image.get_pixel(2, 2) == color and document.image.get_pixel(3, 3) == document.background(), "Brush clips cleanly at canvas boundaries")
	document.begin_stroke(Vector2i(0, 0), document.background(), 5)
	document.end_stroke()
	check(not document.has_content(), "Eraser restores the canvas background")
	document.undo()
	check(document.has_content(), "Erasing is undoable")
	document.begin_stroke(Vector2i(-1, 5), color, 1)
	document.draw_to(Vector2i(2, 2), color, 1)
	document.end_stroke()
	check(document.undo_stack.size() == 1, "Stroke starting outside the canvas cannot paint or add undo")
	document.clear()
	check(not document.has_content(), "Clear resets the image")
	document.undo()
	check(document.has_content(), "Clear is undoable")
	for index in range(9):
		document.begin_stroke(Vector2i(10 + index, 10), color, 1)
		document.end_stroke()
	check(document.undo_stack.size() == 5, "Undo history is bounded to five strokes")
	check(document.save(path) == OK, "Drawing saves atomically")
	var restored := Drawing.new(catalog)
	check(restored.load_saved(path) == OK and restored.image.get_data() == document.image.get_data(), "Every pixel survives a reload")
	document.begin_stroke(Vector2i(30, 20), color, 3)
	document.end_stroke()
	check(document.save(path) == OK and FileAccess.file_exists(path + ".bak"), "Second save retains previous valid backup")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("corrupt")
	file.close()
	var recovered := Drawing.new(catalog)
	check(recovered.load_saved(path) == OK and recovered.recovered_from_backup and recovered.image.get_data() == restored.image.get_data(), "Corrupt drawing recovers the previous valid image")
	check(recovered.save(path) == OK, "Recovered drawing remains writable")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken primary")
	file.close()
	file = FileAccess.open(path + ".bak", FileAccess.WRITE)
	file.store_string("broken backup")
	file.close()
	var broken := Drawing.new(catalog)
	check(broken.load_saved(path) == ERR_FILE_CORRUPT, "Two corrupt copies report an error")
	broken.begin_stroke(Vector2i(1, 1), color, 1)
	broken.end_stroke()
	check(broken.save(path) == ERR_FILE_CORRUPT and FileAccess.get_file_as_string(path) == "broken primary", "Corrupt originals cannot be silently overwritten")
	write_payload({"version": 99}, path)
	var future := Drawing.new(catalog)
	check(future.load_saved(path) == ERR_UNAVAILABLE and future.save(path) == ERR_UNAVAILABLE, "Future drawing formats cannot be overwritten")
	var wrong_size := Image.create(256, 144, false, Image.FORMAT_RGBA8)
	write_payload({"version": 1, "source_id": "", "png": Marshalls.raw_to_base64(wrong_size.save_png_to_buffer())}, path)
	var malformed := Drawing.new(catalog)
	check(malformed.load_saved(path) == ERR_FILE_CORRUPT, "Mismatched PNG dimensions fail before loading")
	check(document.save("user://missing_drawing_directory_%d/image.json" % OS.get_process_id()) != OK, "Failed disk writes report an error")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for index in range(12):
		var previous := document.source_id
		check(document.randomize_from_library(rng) and document.source_id != previous, "Random button chooses a different library entry")
		check(document.image.get_size() == Vector2i(128, 72) and document.rating() >= 55 and document.rating() <= 75, "Library image fits canvas and safe rating range")
	var library_state := document.snapshot()
	document.begin_stroke(Vector2i(50, 35), Color.WHITE, 3)
	document.end_stroke()
	check(document.source_id.is_empty(), "Drawing over library art uses actual custom-image rating")
	document.undo()
	check(document.source_id == library_state.source_id and document.image.get_data() == library_state.image.get_data(), "Undo restores both library artwork and source rating")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Pixel drawing, rating and saves: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
