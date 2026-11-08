extends Control
## A transient HUD target; it never changes the room or its tap region.
var host: Control
var _button: Button
var _feedback: Label
var _displayed_serial := -1

class Megaphone extends Control:
	func _draw() -> void:
		var gold := Color("ffd36c")
		draw_rect(Rect2(0, 12, 12, 16), gold)
		draw_colored_polygon(PackedVector2Array([Vector2(12, 12), Vector2(28, 4), Vector2(32, 4), Vector2(32, 36), Vector2(28, 36), Vector2(12, 28)]), gold)
		draw_rect(Rect2(8, 28, 8, 12), Color("c08535"))
		draw_rect(Rect2(28, 8, 4, 24), Color("fff2bb"))
		draw_rect(Rect2(36, 16, 8, 4), gold)
		draw_rect(Rect2(36, 4, 4, 4), gold)
		draw_rect(Rect2(36, 32, 4, 4), gold)

func _ready() -> void:
	size = Vector2(540, 960)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button = host._studio._button(self, "", Rect2(28, 568, 236, 64))
	for state in ["normal", "hover", "pressed"]:
		_button.add_theme_stylebox_override(state, host._style(Color("443052") if state == "pressed" else Color("22153d"), host.AMBER, 6))
	_button.add_theme_color_override("font_color", host.AMBER)
	_button.add_theme_font_size_override("font_size", 20)
	_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.pressed.connect(catch_moment)
	var icon := Megaphone.new()
	icon.position = Vector2(12, 12)
	icon.size = Vector2(44, 40)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button.add_child(icon)
	_feedback = host._label(self, "", Rect2(28, 568, 484, 48), 22, host.AMBER)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback.add_theme_stylebox_override("normal", host._style(Color("22153d"), host.AMBER, 6))
	hide()

func catch_moment() -> void:
	if not is_visible_in_tree() or not _button.visible or host._exit_flow._modal.visible or host._studio.report_visible:
		return
	if host.session.catch_viral(_displayed_serial):
		# Hiding a focused target must not pass its activation key to room tapping.
		get_viewport().set_input_as_handled()
		host._refresh()

func refresh() -> void:
	var session: RefCounted = host.session
	visible = session.state == host.Session.State.LIVE and not host._studio.report_visible and not host._exit_flow._modal.visible
	if not visible:
		return
	var rules: Dictionary = host.config.viral_moment
	var remaining: float = session.viral_seconds_left()
	_button.visible = remaining > 0.000001
	_feedback.visible = not _button.visible and session.elapsed_real - session.viral_resolved_at < float(rules.feedback_seconds)
	if _button.visible:
		_displayed_serial = session.viral_serial
		_button.position.x = lerpf(28.0, 276.0, clampf(1.0 - remaining / float(rules.catch_seconds), 0.0, 1.0))
		_button.text = rules.text.catch % [remaining, roundi(rules.hype_reward)]
		_button.accessibility_name = rules.text.accessibility % roundi(rules.hype_reward)
	elif _feedback.visible:
		_feedback.text = rules.text.caught % session.viral_hype_gain if session.viral_outcome == "caught" else rules.text.missed
