extends Node2D
## Local, short-lived feedback. It never changes session state.
const LIFE := 0.58
var age := 0.0
var _label: Label
var _origin := Vector2.ZERO
var _tint := Color("78f4ec")

func setup(point: Vector2, caption: String, font: Font, tint: Color) -> void:
	position = point
	_tint = tint
	_label = Label.new()
	_label.text = caption
	_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", tint)
	_label.add_theme_color_override("font_outline_color", Color("130b29"))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_origin = Vector2(clampf(point.x - width / 2.0, 8.0, 532.0 - width) - point.x, -44.0)
	_label.position = _origin

func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	_label.position = (_origin + Vector2(0, -24.0 * age / LIFE)).round()
	_label.modulate.a = 1.0 - smoothstep(0.22, LIFE, age)
	queue_redraw()

func _draw() -> void:
	var progress := clampf(age / LIFE, 0.0, 1.0)
	var tint := _tint
	tint.a = (1.0 - progress) * 0.85
	var radius := floorf(6.0 + progress * 23.0)
	# Four segmented pixel arcs and outward sparks; no full-screen flash.
	for quadrant in range(4):
		for segment in range(3):
			var angle := float(quadrant) * PI / 2.0 + float(segment) * 0.21
			var point := (Vector2(cos(angle), sin(angle)) * radius).round()
			draw_rect(Rect2(point - Vector2.ONE, Vector2(3, 3)), tint)
		var diagonal := PI / 4.0 + float(quadrant) * PI / 2.0
		var spark := (Vector2(cos(diagonal), sin(diagonal)) * (radius + 7.0)).round()
		draw_rect(Rect2(spark, Vector2(3, 3)), tint)
	if progress < 0.35:
		draw_line(Vector2(-4, 0), Vector2(4, 0), tint, 2)
		draw_line(Vector2(0, -4), Vector2(0, 4), tint, 2)
