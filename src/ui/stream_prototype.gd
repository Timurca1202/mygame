extends Control

const Session = preload("res://src/stream/stream_session.gd")
const Feedback = preload("res://scenes/ui/tap_feedback.tscn")
const CONFIG_PATH := "res://data/stream/prototype.json"
const INK := Color("f4efff")
const MUTED := Color("aaa4c5")
const GREEN := Color("b9ff69")
const CYAN := Color("6ee8f3")
const AMBER := Color("ffd36c")
const RED := Color("ff8093")
const PURPLE := Color("a94fec")

var session: RefCounted
var config: Dictionary
var _text: Dictionary
var _status: Label
var _timer: Label
var _speed: Label
var _live_badge: Label
var _live_detail: Label
var _hype_label: Label
var _heat_label: Label
var _hype_bar: ProgressBar
var _heat_bar: ProgressBar
var _hint: Label
var _mode: OptionButton
var _action: Button
var _tap_area: Control
var _effects: Node2D
var _font: Font

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary:
		push_error("Stream prototype configuration is missing or invalid")
		set_process(false)
		return
	config = parsed
	_text = config.text
	session = Session.new(config)
	var font_file := load("res://assets/fonts/tiny5/Tiny5-Variable.ttf") as FontFile
	font_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_font = font_file
	var ui_theme := Theme.new()
	ui_theme.default_font = _font
	ui_theme.default_font_size = 20
	theme = ui_theme
	_build_interface()
	_refresh()

func _process(delta: float) -> void:
	if session != null:
		session.advance(delta)
		_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if session != null:
			session.pause()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
		_tap(Vector2(327, 450))
		get_viewport().set_input_as_handled()

func _style(fill: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(border, 0.15)
	style.shadow_size = 7
	style.anti_aliasing = true
	return style

func _panel(rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.add_theme_stylebox_override("panel", _style(Color("0e0928"), PURPLE))
	add_child(panel)
	return panel

func _label(parent: Node, value: String, rect: Rect2, font_size: int = 20, tint: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label

func _gradient(colors: PackedColorArray) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.width = 460
	texture.height = 16
	texture.gradient = Gradient.new()
	texture.gradient.colors = colors
	var offsets := PackedFloat32Array()
	for i in range(colors.size()):
		offsets.append(float(i) / float(colors.size() - 1))
	texture.gradient.offsets = offsets
	return texture

func _bar(parent: Node, rect: Rect2, colors: PackedColorArray) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := _style(Color("24133e"), Color("704298"), 4)
	background.shadow_size = 0
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxTexture.new()
	fill.texture = _gradient(colors)
	fill.set_expand_margin_all(-3)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func _build_interface() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := _panel(Rect2(20, 18, 500, 184))
	_label(top, _text.studio, Rect2(18, 10, 350, 20), 20, MUTED)
	_live_badge = _label(top, "", Rect2(380, 10, 100, 20), 20, MUTED)
	_live_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status = _label(top, "", Rect2(18, 32, 464, 40), 40)
	_hype_label = _label(top, "", Rect2(18, 78, 95, 24), 20, CYAN)
	_hype_bar = _bar(top, Rect2(114, 85, 284, 16), PackedColorArray([Color("f035c8"), Color("a767ff"), CYAN, GREEN]))
	_speed = _label(top, "", Rect2(403, 76, 78, 28), 30, GREEN)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_heat_label = _label(top, "", Rect2(18, 110, 95, 24), 20, RED)
	_heat_bar = _bar(top, Rect2(114, 117, 284, 16), PackedColorArray([AMBER, Color("ff955b"), Color("f14d80")]))
	var heat_value := _label(top, "", Rect2(403, 110, 78, 24), 20, AMBER)
	heat_value.name = "HeatValue"
	heat_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(top, config.device_name, Rect2(18, 148, 190, 24), 20, MUTED)
	_timer = _label(top, "", Rect2(222, 144, 260, 28), 20, CYAN)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_tap_area = Control.new()
	_tap_area.position = Vector2(0, 206)
	_tap_area.size = Vector2(540, 500)
	_tap_area.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tap_area.gui_input.connect(_room_input)
	add_child(_tap_area)

	var bottom := _panel(Rect2(20, 720, 500, 224))
	_label(bottom, _text.title, Rect2(20, 12, 420, 30), 30)
	var line := TextureRect.new()
	line.texture = _gradient(PackedColorArray([Color("e84adc"), CYAN, Color("6ee8f300")]))
	line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	line.position = Vector2(20, 44)
	line.size = Vector2(460, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(line)
	_hint = _label(bottom, "", Rect2(20, 54, 460, 54), 20)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode = OptionButton.new()
	_mode.position = Vector2(20, 108)
	_mode.size = Vector2(460, 44)
	_mode.add_theme_font_size_override("font_size", 20)
	_mode.add_theme_color_override("font_color", INK)
	_mode.focus_mode = Control.FOCUS_NONE
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var style := _style(Color("17102f"), Color("7351a3"), 6)
		style.content_margin_left = 12
		style.content_margin_right = 26
		style.shadow_size = 0
		_mode.add_theme_stylebox_override(state_name, style)
	for preset in config.durations:
		_mode.add_item(preset.label)
	_mode.get_popup().theme = theme
	_mode.get_popup().add_theme_stylebox_override("panel", _style(Color("17102f"), PURPLE, 6))
	_mode.get_popup().add_theme_color_override("font_color", INK)
	bottom.add_child(_mode)
	_live_detail = _label(bottom, "", Rect2(20, 116, 460, 28), 20, CYAN)
	_action = Button.new()
	_action.position = Vector2(20, 160)
	_action.size = Vector2(460, 52)
	_action.focus_mode = Control.FOCUS_NONE
	_action.add_theme_font_size_override("font_size", 40)
	for state_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_action.add_theme_color_override(state_name, Color("102029"))
	for state_name in ["normal", "hover", "pressed"]:
		var style := StyleBoxTexture.new()
		style.texture = load("res://assets/art/ui/stream_button.svg")
		if state_name == "pressed":
			style.modulate_color = Color(0.8, 0.92, 1.0)
		elif state_name == "hover":
			style.modulate_color = Color(1.05, 1.05, 1.05)
		_action.add_theme_stylebox_override(state_name, style)
	_action.pressed.connect(_action_pressed)
	bottom.add_child(_action)
	var bolt := TextureRect.new()
	bolt.texture = load("res://assets/art/ui/bolt.svg")
	bolt.position = Vector2(432, -22)
	bolt.size = Vector2(52, 56)
	bolt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bolt)

	_effects = Node2D.new()
	_effects.name = "TapEffects"
	add_child(_effects)

func _room_input(event: InputEvent) -> void:
	# Primary touch uses Godot's mouse emulation, so it cannot count twice.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_tap(_tap_area.position + event.position)
		accept_event()

func _tap(point: Vector2) -> void:
	if session.state != Session.State.LIVE:
		return
	var before: float = session.hype
	session.tap()
	var gain: float = session.hype - before
	var caption: String = _text.tap_gain % gain if gain > 0.0 else _text.tap_max
	while _effects.get_child_count() >= 16:
		var oldest := _effects.get_child(0)
		_effects.remove_child(oldest)
		oldest.queue_free()
	var effect := Feedback.instantiate()
	_effects.add_child(effect)
	effect.setup(point, caption, _font, CYAN if gain > 0.0 else GREEN)

func _action_pressed() -> void:
	match session.state:
		Session.State.READY:
			session.start(float(config.durations[_mode.selected].seconds))
		Session.State.LIVE:
			session.pause()
		Session.State.PAUSED:
			session.resume()
		Session.State.FINISHED:
			# Return to setup so the next duration can be chosen deliberately.
			session = Session.new(config)
	_refresh()

func _refresh() -> void:
	var ready: bool = session.state == Session.State.READY
	_mode.visible = ready
	var planned: float = float(config.durations[_mode.selected].seconds) if ready else session.duration
	_timer.text = _text.timer % [_clock(session.elapsed_game), _clock(planned)]
	_hype_label.text = _text.hype % roundi(session.hype)
	_heat_label.text = _text.heat
	_heat_bar.get_parent().get_node("HeatValue").text = "%d%%" % roundi(session.heat)
	_hype_bar.value = session.hype
	_heat_bar.value = session.heat
	match session.state:
		Session.State.READY:
			_status.text = _text.ready
			_hint.text = _text.ready_hint
			_action.text = _text.start
		Session.State.LIVE:
			_status.text = _text.live
			_hint.text = _text.live_hint
			if session.heat >= float(config.heat_thresholds[2]):
				_hint.text = _text.critical_hint
			elif session.heat >= float(config.heat_thresholds[1]):
				_hint.text = _text.hot_hint
			elif session.heat >= float(config.heat_thresholds[0]):
				_hint.text = _text.warm_hint
			_action.text = _text.pause
		Session.State.PAUSED:
			_status.text = _text.paused
			_hint.text = _text.paused_hint
			_action.text = _text.resume
		Session.State.FINISHED:
			_status.text = _text.overheated if session.end_reason == Session.EndReason.OVERHEATED else _text.completed
			_hint.text = _text.results % [_clock(session.elapsed_game), _clock(session.elapsed_real), roundi(session.peak_hype), session.tap_count, roundi(session.heat)]
			_action.text = _text.again
	_live_badge.text = _text.badge_live if session.state == Session.State.LIVE else _text.badge_idle
	_live_badge.add_theme_color_override("font_color", RED if session.state == Session.State.LIVE else MUTED)
	_speed.text = "×%.1f" % session.speed
	_live_detail.visible = not ready
	_live_detail.text = _text.live_detail % [session.tap_count, session.speed]
	_status.add_theme_color_override("font_color", RED if session.end_reason == Session.EndReason.OVERHEATED else INK)

func _clock(seconds: float) -> String:
	var whole := int(floor(seconds + 0.00001))
	return "%02d:%02d" % [whole / 60, whole % 60]
