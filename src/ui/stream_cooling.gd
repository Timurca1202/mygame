extends Control
## Both the room fan and a labeled control invoke the same session action.
var host: Control
var _button: Button
var _fan: Button
var _status: Label

func _ready() -> void:
	size = Vector2(540, 960)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = host._studio._button(self, "", Rect2(332, 264, 188, 52))
	_button.add_theme_font_size_override("font_size", 18)
	_button.add_theme_stylebox_override("disabled", host._style(Color("17102f"), host.MUTED, 6))
	_button.add_theme_color_override("font_disabled_color", host.MUTED)
	_button.pressed.connect(cool_device)
	_fan = Button.new()
	_fan.size = Vector2(64, 64)
	for item in host.progression.config.items:
		if bool(item.get("active_cooling", false)):
			_fan.position = Vector2(float(item.position[0]), float(item.position[1])) - _fan.size / 2.0
			break
	for state in ["normal", "hover", "pressed", "disabled"]:
		_fan.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus: StyleBoxFlat = host._style(Color.TRANSPARENT, host.CYAN, 6)
	focus.shadow_size = 0
	_fan.add_theme_stylebox_override("focus", focus)
	_fan.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_fan.pressed.connect(cool_device)
	add_child(_fan)
	_status = host._label(self, "", Rect2(332, 322, 188, 28), 18, host.AMBER)
	var caption: String = host.config.active_cooling.text.accessibility
	_button.accessibility_name = caption
	_fan.accessibility_name = caption
	_fan.tooltip_text = caption
	hide()

func cool_device() -> void:
	if not is_visible_in_tree() or host._studio.report_visible or host._exit_flow._modal.visible:
		return
	if host.session.cool_device():
		host._refresh()

func refresh() -> void:
	var session: RefCounted = host.session
	visible = session.active_cooling_available and (session.state == host.Session.State.LIVE or session.state == host.Session.State.PAUSED) and not host._studio.report_visible and not host._exit_flow._modal.visible
	if not visible:
		return
	var rules: Dictionary = host.config.active_cooling
	var paused: bool = session.state == host.Session.State.PAUSED
	var waiting: bool = session.cooling_cooldown_remaining > 0.000001
	_button.disabled = paused or waiting or session.heat <= 0.0
	_fan.disabled = _button.disabled
	_button.text = rules.text.ready % [roundi(rules.heat_drop), roundi(rules.tap_lock_seconds)]
	if paused:
		_button.text = rules.text.paused
	elif waiting:
		_button.text = rules.text.wait % ceili(session.cooling_cooldown_remaining)
	_status.text = rules.text.locked % ceili(session.cooling_lock_remaining) if session.cooling_lock_remaining > 0.000001 else ""
