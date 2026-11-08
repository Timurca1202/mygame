extends Control
## A continuous hold opens a consequence preview; only explicit confirmation ends a stream.
var host: Control
var _end_button: Button
var _progress: ProgressBar
var _modal: Control
var _confirm: Button
var _cancel: Button
var _played: Label
var _followers: Label
var _hype: Label
var _income: Label
var _note: Label
var _holding := false
var _held := 0.0

func _ready() -> void:
	size = Vector2(540, 960)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_button = host._studio._button(host._bottom_panel, host._text.exit_hold, Rect2(20, 108, 460, 44))
	_end_button.add_theme_font_size_override("font_size", 20)
	_end_button.keep_pressed_outside = false
	_end_button.button_down.connect(_begin_hold)
	_end_button.button_up.connect(_reset_hold)
	_end_button.mouse_exited.connect(_reset_hold)
	_progress = ProgressBar.new()
	_progress.position = Vector2(12, 38)
	_progress.size = Vector2(436, 4)
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_button.add_child(_progress)
	_modal = Control.new()
	_modal.size = size
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.02, 0.01, 0.09, 0.75)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(shade)
	var panel: Panel = host._panel(Rect2(20, 274, 500, 430))
	host.remove_child(panel)
	_modal.add_child(panel)
	host._label(panel, host._text.exit_heading, Rect2(20, 14, 460, 36), 28, host.AMBER)
	_played = host._label(panel, "", Rect2(20, 64, 460, 28), 22, host.CYAN)
	_followers = host._label(panel, "", Rect2(20, 120, 460, 28), 22)
	_hype = host._label(panel, "", Rect2(20, 162, 460, 28), 22)
	_income = host._label(panel, "", Rect2(20, 210, 460, 48), 20, host.GREEN)
	_income.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note = host._label(panel, "", Rect2(20, 270, 460, 52), 20, host.MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cancel = host._studio._button(panel, host._text.exit_cancel, Rect2(20, 354, 220, 52))
	_cancel.pressed.connect(cancel_exit)
	_confirm = host._studio._button(panel, host._text.exit_confirm, Rect2(260, 354, 220, 52))
	_confirm.pressed.connect(confirm_exit)
	_cancel.focus_next = _cancel.get_path_to(_confirm)
	_confirm.focus_next = _confirm.get_path_to(_cancel)
	_cancel.focus_previous = _cancel.focus_next
	_confirm.focus_previous = _confirm.focus_next
	_modal.hide()
	_end_button.hide()

func _begin_hold() -> void:
	if host.session.state != host.Session.State.PAUSED or _modal.visible:
		return
	_holding = true
	_held = 0.0

func _reset_hold() -> void:
	_holding = false
	_held = 0.0
	if _progress != null:
		_progress.value = 0.0

func advance_hold(delta: float) -> void:
	if not _holding:
		return
	if host.session.state != host.Session.State.PAUSED or not _end_button.is_pressed():
		_reset_hold()
		return
	if not is_finite(delta) or delta <= 0.0:
		return
	_held += delta
	_progress.value = _held / float(host.config.exit.hold_seconds)
	if _held >= float(host.config.exit.hold_seconds):
		_holding = false
		_open_confirmation()

func _open_confirmation() -> void:
	var session: RefCounted = host.session
	var ratio: float = session.exit_penalty_ratio()
	_played.text = host._text.exit_progress % [floori((session.elapsed_game + 0.000001) / session.duration * 100.0), host._clock(session.elapsed_game), host._clock(session.duration)]
	var loss: float = host.wallet.followers * ratio
	var visible_loss := floori(host.wallet.followers) - floori(maxf(0.0, host.wallet.followers - loss))
	_followers.text = host._text.exit_followers % [visible_loss, ratio * 100.0] if ratio > 0.0 else host._text.exit_safe
	_followers.add_theme_color_override("font_color", host.RED if ratio > 0.0 else host.GREEN)
	_hype.text = host._text.exit_hype if ratio > 0.0 else ""
	_income.text = host._text.exit_income % host._money(session.income.earned_total_units())
	_note.text = host._text.exit_note if ratio > 0.0 else ""
	_modal.show()
	_cancel.grab_focus()
	host._refresh()

func cancel_exit() -> void:
	_modal.hide()
	_reset_hold()
	host._refresh()

func confirm_exit() -> void:
	if not _modal.visible or host.session.state != host.Session.State.PAUSED:
		return
	if host.session.finish_early():
		_modal.hide()
		_reset_hold()
		host._settle_income()
		host._refresh()

func refresh() -> void:
	var paused: bool = host.session.state == host.Session.State.PAUSED
	_end_button.visible = paused and not _modal.visible and not host._studio.report_visible
	if paused:
		host._live_detail.hide()
	if not paused:
		_modal.hide()
		_reset_hold()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_reset_hold()

func _unhandled_key_input(event: InputEvent) -> void:
	if _modal.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		cancel_exit()
		get_viewport().set_input_as_handled()
