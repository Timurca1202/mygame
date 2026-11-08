extends Control
const Drawing = preload("res://src/stream/preview_drawing.gd")
const Canvas = preload("res://src/ui/preview_canvas.gd")
var studio: Control
var document: RefCounted
var canvas: Control
var _scroll: ScrollContainer
var _colors: Array[Button] = []
var _tools: Array[Button] = []
var _undo: Button
var _apply: Button
var _status: Label
var _source: Label
var _zoom: OptionButton
var _color_index := 1
var _tool_index := 0
var _rng := RandomNumberGenerator.new()
var _text: Dictionary
var _opened := false
signal applied
signal closed

func _ready() -> void:
	size = Vector2(540, 960)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_text = studio.preview_catalog.editor.text
	_rng.randomize()
	var background := ColorRect.new()
	background.color = Color("0b0820")
	background.size = size
	add_child(background)
	var panel: Panel = studio.host._panel(Rect2(20, 20, 500, 924))
	studio.host.remove_child(panel)
	add_child(panel)
	studio.host._label(panel, _text.heading, Rect2(24, 18, 300, 32), 28, studio.host.CYAN)
	var cancel: Button = studio._button(panel, _text.cancel, Rect2(340, 12, 136, 48))
	cancel.pressed.connect(cancel_editing)
	studio.host._label(panel, _text.hint, Rect2(24, 74, 452, 24), 20, studio.host.MUTED)
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(24, 108)
	_scroll.size = Vector2(452, 256)
	_scroll.add_theme_stylebox_override("panel", studio.host._style(Color("17102f"), studio.host.PURPLE, 4))
	# A stroke belongs to the canvas; enlarged art is panned by the visible scrollbars.
	_scroll.scroll_deadzone = 10000
	panel.add_child(_scroll)
	_scroll.get_h_scroll_bar().custom_minimum_size.y = 44
	_scroll.get_v_scroll_bar().custom_minimum_size.x = 44
	for bar in [_scroll.get_h_scroll_bar(), _scroll.get_v_scroll_bar()]:
		bar.add_theme_stylebox_override("scroll", studio.host._style(Color("17102f"), Color("49345e"), 4))
		for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
			bar.add_theme_stylebox_override(state, studio.host._style(Color("49345e"), studio.host.CYAN if state == "grabber_pressed" else studio.host.PURPLE, 6))
	document = Drawing.new(studio.preview_catalog)
	canvas = Canvas.new()
	canvas.document = document
	canvas.custom_minimum_size = Vector2(448, 252)
	_scroll.add_child(canvas)
	canvas.changed.connect(refresh_controls)
	var captions: Array = [_text.pencil, _text.brush3, _text.brush5, _text.eraser]
	for index in range(captions.size()):
		var tool: Button = studio._button(panel, captions[index], Rect2(24 + index * 116, 402, 104, 48))
		tool.pressed.connect(select_tool.bind(index))
		_tools.append(tool)
	for index in range(studio.preview_catalog.editor.palette.size()):
		var swatch := Button.new()
		swatch.position = Vector2(24 + (index % 8) * 56, 470 + (index / 8) * 56)
		swatch.size = Vector2(48, 48)
		swatch.accessibility_name = _text.color % (index + 1)
		swatch.tooltip_text = swatch.accessibility_name
		swatch.pressed.connect(select_color.bind(index))
		panel.add_child(swatch)
		_colors.append(swatch)
	_undo = studio._button(panel, _text.undo, Rect2(24, 590, 140, 48))
	_undo.pressed.connect(func():
		canvas.finish_stroke()
		document.undo()
		canvas.refresh_image()
		refresh_controls())
	var clear: Button = studio._button(panel, _text.clear, Rect2(176, 590, 140, 48))
	clear.pressed.connect(func():
		canvas.finish_stroke()
		document.clear()
		canvas.refresh_image()
		refresh_controls())
	_zoom = OptionButton.new()
	_zoom.position = Vector2(328, 590)
	_zoom.size = Vector2(148, 48)
	_zoom.accessibility_name = _text.zoom
	for factor in [1, 2, 4]:
		_zoom.add_item("%s %d×" % [_text.zoom, factor])
	_zoom.add_theme_font_size_override("font_size", 20)
	_zoom.item_selected.connect(_set_zoom)
	panel.add_child(_zoom)
	var random: Button = studio._button(panel, _text.random, Rect2(24, 660, 452, 52))
	random.name = "Random"
	random.pressed.connect(randomize_preview)
	_source = studio.host._label(panel, "", Rect2(24, 724, 452, 26), 20, studio.host.CYAN)
	_status = studio.host._label(panel, _text.random_help, Rect2(24, 768, 452, 56), 20, studio.host.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply = studio._button(panel, _text.apply, Rect2(24, 848, 452, 56))
	_apply.pressed.connect(apply_preview)
	var buttons := find_children("*", "BaseButton", true, false)
	for index in range(buttons.size()):
		buttons[index].focus_next = buttons[index].get_path_to(buttons[(index + 1) % buttons.size()])
		buttons[index].focus_previous = buttons[index].get_path_to(buttons[(index - 1 + buttons.size()) % buttons.size()])
	hide()

func open_editor() -> void:
	document.restore(studio.preview_document.snapshot())
	document.load_error = studio.preview_document.load_error
	document.undo_stack.clear()
	_zoom.select(0)
	_set_zoom(0)
	_status.text = _text.random_help if document.load_error == OK else _text.load_error
	_opened = true
	show()
	canvas.refresh_image()
	select_color(_color_index)
	select_tool(_tool_index)
	refresh_controls()
	_tools[_tool_index].grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_editing()
		get_viewport().set_input_as_handled()

func _set_zoom(index: int) -> void:
	canvas.finish_stroke()
	var factor: int = [1, 2, 4][index]
	canvas.custom_minimum_size = Vector2(448, 252) * factor
	canvas.size = canvas.custom_minimum_size
	_scroll.scroll_horizontal = 0
	_scroll.scroll_vertical = 0
	canvas.queue_redraw()

func select_color(index: int) -> void:
	canvas.finish_stroke()
	_color_index = index
	canvas.ink = Color(studio.preview_catalog.editor.palette[index])
	if canvas.erasing:
		select_tool(0)
	refresh_controls()

func select_tool(index: int) -> void:
	canvas.finish_stroke()
	_tool_index = index
	canvas.erasing = index == 3
	canvas.brush_size = int(studio.preview_catalog.editor.brushes[index]) if index < 3 else 5
	refresh_controls()

func randomize_preview() -> void:
	canvas.finish_stroke()
	if document.randomize_from_library(_rng):
		canvas.refresh_image()
		_status.text = _text.random_help
	refresh_controls()

func apply_preview() -> void:
	canvas.finish_stroke()
	if not document.has_content():
		_status.text = _text.empty
		return
	if document.save(studio.preview_path()) != OK:
		_status.text = _text.save_error
		return
	studio.preview_document.restore(document.snapshot())
	studio.preview_document.load_error = OK
	_opened = false
	hide()
	applied.emit()

func cancel_editing() -> void:
	canvas.finish_stroke()
	_opened = false
	hide()
	closed.emit()

func refresh_controls() -> void:
	if not _opened:
		return
	_undo.disabled = document.undo_stack.is_empty()
	_apply.disabled = not document.has_content() or document.load_error != OK
	var entry: Dictionary = document.library_entry()
	_source.text = _text.chosen % (entry.name if not entry.is_empty() else _text.custom_name)
	for index in range(_colors.size()):
		var color := Color(studio.preview_catalog.editor.palette[index])
		var selected := index == _color_index
		_colors[index].text = "X" if selected else ""
		_colors[index].accessibility_name = str(studio.preview_catalog.editor.palette_names[index]) + (" / " + studio.preview_catalog.text.selected if selected else "")
		for state in ["normal", "hover", "pressed", "focus"]:
			var style: StyleBoxFlat = studio.host._style(color, studio.host.INK if selected else Color("49345e"), 4)
			style.set_border_width_all(4 if selected else 1)
			_colors[index].add_theme_stylebox_override(state, style)
		_colors[index].add_theme_color_override("font_color", Color.BLACK if color.get_luminance() > 0.5 else Color.WHITE)
	for index in range(_tools.size()):
		_tools[index].toggle_mode = true
		_tools[index].set_pressed_no_signal(index == _tool_index)
		_tools[index].add_theme_stylebox_override("normal", studio.host._style(Color("233c36") if index == _tool_index else Color("22153d"), studio.host.GREEN if index == _tool_index else studio.host.PURPLE, 6))
