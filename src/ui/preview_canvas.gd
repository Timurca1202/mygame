extends Control
## Pointer positions map to document pixels; only this surface consumes strokes.
var document: RefCounted
var ink := Color.WHITE
var brush_size := 1
var erasing := false
var _texture: ImageTexture
var _drawing := false
var _touch_index := -1
signal changed

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	accessibility_name = "Холст превью"
	refresh_image()

func refresh_image() -> void:
	if _texture == null:
		_texture = ImageTexture.create_from_image(document.image)
	else:
		_texture.update(document.image)
	queue_redraw()

func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
		# Pixel boundaries become useful only when there is room to see each cell.
		var scale_x: float = size.x / document.image.get_width()
		if scale_x >= 7.0:
			for x in range(document.image.get_width() + 1):
				draw_line(Vector2(x * scale_x, 0), Vector2(x * scale_x, size.y), Color(1, 1, 1, 0.08))
			for y in range(document.image.get_height() + 1):
				draw_line(Vector2(0, y * scale_x), Vector2(size.x, y * scale_x), Color(1, 1, 1, 0.08))

func _pixel(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / size.x * document.image.get_width()), floori(point.y / size.y * document.image.get_height()))

func finish_stroke() -> void:
	if _drawing:
		document.end_stroke()
		_drawing = false
		_touch_index = -1
		changed.emit()

func _press(point: Vector2) -> void:
	_drawing = true
	document.begin_stroke(_pixel(point), document.background() if erasing else ink, brush_size)
	refresh_image()

func _drag(point: Vector2) -> void:
	if _drawing:
		document.draw_to(_pixel(point), document.background() if erasing else ink, brush_size)
		refresh_image()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_press(event.position)
		elif not event.pressed and event.index == _touch_index:
			finish_stroke()
		accept_event()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_drag(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Godot marks emulated touch mouse events as device -1; touch is handled above.
		if event.device != -1:
			if event.pressed:
				_press(event.position)
			else:
				finish_stroke()
		accept_event()
	elif event is InputEventMouseMotion and _drawing and _touch_index == -1:
		_drag(event.position)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		finish_stroke()
