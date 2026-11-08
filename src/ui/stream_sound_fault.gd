extends Control
## A recoverable transmission fault, independent of the phone's thermal lag.
var host: Control
var _panel: Panel
var _button: Button
var _feedback: Label
var _displayed_serial := -1

func _ready() -> void:
	size = Vector2(540, 960)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rules: Dictionary = host.config.sound_fault
	_panel = host._panel(Rect2(28, 568, 484, 108))
	host.remove_child(_panel)
	add_child(_panel)
	_panel.add_theme_stylebox_override("panel", host._style(Color("22153d"), host.RED, 6))
	host._label(_panel, rules.text.warning % roundi(float(rules.quality_loss) * 100), Rect2(12, 6, 460, 48), 20, host.RED)
	_button = host._studio._button(_panel, rules.text.repair, Rect2(12, 56, 460, 44))
	_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_button.accessibility_name = rules.text.accessibility
	_button.pressed.connect(repair_sound)
	_feedback = host._label(self, rules.text.restored, Rect2(28, 568, 484, 48), 22, host.GREEN)
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback.add_theme_stylebox_override("normal", host._style(Color("22153d"), host.GREEN, 6))
	hide()

func repair_sound() -> void:
	if not is_visible_in_tree() or not _panel.visible or host._exit_flow._modal.visible or host._studio.report_visible:
		return
	if host.session.repair_sound(_displayed_serial):
		get_viewport().set_input_as_handled()
		host._refresh()

func refresh() -> void:
	var session: RefCounted = host.session
	visible = session.state == host.Session.State.LIVE and not host._studio.report_visible and not host._exit_flow._modal.visible
	if not visible:
		return
	_panel.visible = session.sound_fault_active
	_feedback.visible = not _panel.visible and session.elapsed_real - session.sound_fault_repaired_at < float(host.config.sound_fault.feedback_seconds)
	if _panel.visible:
		_displayed_serial = session.sound_fault_serial
