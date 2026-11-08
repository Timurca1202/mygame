extends SceneTree
const Drawing = preload("res://src/stream/preview_drawing.gd")
var viewport: SubViewport
var main: Node2D
var ui: Control
var checks := 0
var failures := 0
var path := "user://editor_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream/editor_v12"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event)

func press_named(parent: Node, caption: String) -> void:
	for button in parent.find_children("*", "Button", true, false):
		if button.text == caption:
			click(button.get_global_rect().get_center())
			return
	check(false, "Missing button: " + caption)

func mouse_stroke(canvas: Control, points: Array) -> void:
	var event := InputEventMouseButton.new()
	event.position = canvas.get_global_rect().position + Vector2(points[0]) * canvas.size / Vector2(128, 72)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	viewport.push_input(event)
	for point in points:
		var motion := InputEventMouseMotion.new()
		motion.position = canvas.get_global_rect().position + Vector2(point) * canvas.size / Vector2(128, 72)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		viewport.push_input(motion)
	event.position = canvas.get_global_rect().position + Vector2(points[-1]) * canvas.size / Vector2(128, 72)
	event.pressed = false
	viewport.push_input(event)

func capture(name: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK, "Capture " + name)

func mount() -> void:
	main = load("res://scenes/app/main.tscn").instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = path
	viewport.add_child(main)
	ui.set_process(false)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	mount()
	await process_frame
	var studio: Control = ui._studio
	click(studio._edit_button.get_global_rect().get_center())
	click(studio._preview_button.get_global_rect().get_center())
	var editor: Control = studio._editor
	check(editor.visible and not studio._form.visible and not ui._navigation.visible, "Editor opens as a separate full screen")
	check(editor.get_global_rect() == Rect2(0, 0, 540, 960), "Editor covers the viewport without scene offsets")
	check(editor._apply.get_global_rect().end.x <= 520 and editor._apply.get_global_rect().end.y <= 944, "Primary action stays inside screen margins")
	check(editor._colors.size() == 16 and editor._tools.size() == 4, "Editor exposes sixteen colors and four drawing tools")
	check(editor.canvas.get_global_rect().size == Vector2(448, 252), "Canvas is enlarged without stretching its 16:9 aspect ratio")
	for swatch in editor._colors:
		check(swatch.size.x >= 44 and swatch.size.y >= 44, "Palette cells remain touch sized")
	var first: String = editor.document.source_id
	press_named(editor, editor._text.random)
	check(editor.document.source_id != first and not editor.document.library_entry().is_empty(), "Random inserts a different real library image")
	for entry in studio.preview_catalog.items:
		check(str(entry.texture).ends_with("_v02.png") and load(entry.texture).get_size() == Vector2(128, 72), "Active library uses new compact illustrations, never room crops")
	await capture("random_library")
	press_named(editor, editor._text.clear)
	check(not editor.document.has_content() and editor._apply.disabled, "Empty canvas blocks acceptance")
	await capture("blank_canvas")
	click(editor._colors[6].get_global_rect().get_center())
	click(editor._tools[1].get_global_rect().get_center())
	var undo_before: int = editor.document.undo_stack.size()
	var heart := [Vector2(28.5, 26.5), Vector2(28.5, 18.5), Vector2(36.5, 10.5), Vector2(46.5, 10.5), Vector2(64.5, 26.5), Vector2(82.5, 10.5), Vector2(92.5, 10.5), Vector2(100.5, 18.5), Vector2(100.5, 32.5), Vector2(64.5, 62.5), Vector2(28.5, 32.5), Vector2(28.5, 26.5)]
	mouse_stroke(editor.canvas, heart)
	check(editor.document.has_content() and editor.document.undo_stack.size() == undo_before + 1, "Real dragging creates one continuous undoable stroke")
	check(editor.document.image.get_pixel(28, 26) == Color(studio.preview_catalog.editor.palette[6]), "Chosen color reaches the correct logical pixel")
	click(editor._undo.get_global_rect().get_center())
	check(not editor.document.has_content(), "Undo button removes the whole heart")
	mouse_stroke(editor.canvas, heart)
	await capture("drawing")
	var accepted_pixels: PackedByteArray = editor.document.image.get_data()
	var drawing_score: float = editor.document.rating()
	click(editor._apply.get_global_rect().get_center())
	check(not editor.visible and studio._form.visible and FileAccess.file_exists(studio.preview_path()), "Accept saves image and returns to preparation")
	check(studio.preview_document.image.get_data() == accepted_pixels and ui.wallet.balance_units == 0, "Accepted art changes no wallet balance")
	var preview_path: String = studio.preview_path()
	main.queue_free()
	await process_frame
	mount()
	await process_frame
	studio = ui._studio
	check(studio.preview_document.image.get_data() == accepted_pixels, "A reconstructed game scene restores the drawing")
	studio.open_previews()
	editor = studio._editor
	click(editor._tools[0].get_global_rect().get_center())
	click(editor._colors[1].get_global_rect().get_center())
	undo_before = editor.document.undo_stack.size()
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = editor.canvas.get_global_rect().position + Vector2(10.5, 10.5) * 3.5
	touch.pressed = true
	viewport.push_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = editor.canvas.get_global_rect().position + Vector2(20.5, 10.5) * 3.5
	viewport.push_input(drag)
	touch.position = drag.position
	touch.pressed = false
	viewport.push_input(touch)
	check(editor.document.undo_stack.size() == undo_before + 1 and editor.document.image.get_pixel(15, 10) == Color(studio.preview_catalog.editor.palette[1]), "Touch paints a continuous stroke exactly once")
	editor._zoom.select(1)
	editor._zoom.item_selected.emit(1)
	for frame in range(3):
		await process_frame
	check(editor.canvas.size == Vector2(896, 504) and editor._scroll.get_v_scroll_bar().visible, "Zoom enlarges pixels and exposes scrollbars")
	editor._scroll.scroll_horizontal = 200
	for frame in range(2):
		await process_frame
	mouse_stroke(editor.canvas, [Vector2(70.5, 15.5)])
	check(editor.document.image.get_pixel(70, 15) == Color(studio.preview_catalog.editor.palette[1]), "Zoomed and scrolled canvas still paints the intended pixel")
	await capture("zoomed_canvas")
	press_named(editor, editor._text.cancel)
	check(studio.preview_document.image.get_data() == accepted_pixels, "Cancel preserves previously accepted art")
	studio.close_form()
	click(ui._action.get_global_rect().get_center())
	check(studio.report_visible and studio.report.preview.id == "drawn" and is_equal_approx(studio.report.preview.score, drawing_score), "Report uses the actual saved custom drawing and its rating")
	check(studio.report.preview.texture.get_image().get_data() == accepted_pixels, "Report thumbnail has the exact accepted pixels")
	ui._process(10.0)
	check(ui.session.elapsed_game == 0, "Reading report still freezes time")
	studio.open_previews()
	check(not editor.visible, "Editor cannot open after launch")
	await capture("custom_report")
	click(ui._action.get_global_rect().get_center())
	ui.session.advance(60.0)
	ui._settle_income()
	check(is_equal_approx(ui.wallet.last_score, ui.progression.performance(ui.session, [], studio.report.packaging_score)), "Custom art contributes to saved stream performance")
	for base in [path, preview_path]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(base + suffix):
				DirAccess.remove_absolute(base + suffix)
	print("Preview editor UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
