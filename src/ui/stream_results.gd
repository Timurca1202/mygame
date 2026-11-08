extends Control
## Optional score details reuse the exact components used for follower growth.
var host: Control
var _open: Button
var _modal: Control
var _panel: Panel
var _close: Button
var _grade: Label
var _stats: Label
var _technical_stats: Label
var _tip: Label
var _values := {}
var _bars := {}

func _ready() -> void:
	size = Vector2(540, 960)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text: Dictionary = host.progression.config.result_report.text
	_open = host._studio._button(host._bottom_panel, text.open, Rect2(20, 134, 148, 44))
	_open.pressed.connect(open_report)
	_modal = Control.new()
	_modal.size = size
	_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_modal)
	var shade := ColorRect.new()
	shade.size = size
	shade.color = Color(0.02, 0.01, 0.09, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal.add_child(shade)
	_panel = host._panel(Rect2(20, 194, 500, 548))
	host.remove_child(_panel)
	_modal.add_child(_panel)
	host._label(_panel, text.heading, Rect2(20, 12, 460, 36), 28, host.CYAN)
	_grade = host._label(_panel, "", Rect2(20, 56, 460, 32), 28, host.GREEN)
	_stats = host._label(_panel, "", Rect2(20, 100, 460, 28), 18, host.MUTED)
	_technical_stats = host._label(_panel, "", Rect2(20, 128, 460, 24), 18, host.AMBER)
	var index := 0
	for key in host.progression.config.score_weights:
		var y := 156 + index * 48
		host._label(_panel, text[key], Rect2(20, y, 310, 26), 20)
		_values[key] = host._label(_panel, "", Rect2(340, y, 140, 26), 20, host.CYAN)
		var track := ColorRect.new()
		track.position = Vector2(20, y + 30)
		track.size = Vector2(460, 6)
		track.color = Color("38244f")
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(track)
		var bar := ColorRect.new()
		bar.size = Vector2(460, 6)
		bar.color = host.CYAN
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(bar)
		_bars[key] = bar
		index += 1
	host._label(_panel, text.next, Rect2(20, 394, 460, 26), 20, host.AMBER)
	_tip = host._label(_panel, "", Rect2(20, 428, 460, 54), 20)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_close = host._studio._button(_panel, text.close, Rect2(20, 492, 460, 44))
	_close.pressed.connect(close_report)
	_close.focus_next = NodePath(".")
	_close.focus_previous = NodePath(".")
	_modal.hide()
	_open.hide()

func open_report() -> void:
	if host.session.state != host.Session.State.FINISHED or host._result_score < 0.0 or host._shop.visible:
		return
	var model: RefCounted = host.progression
	var session: RefCounted = host.session
	var components: Dictionary = model.performance_components(session, host._starting_inventory, float(host._launch_rating.get("packaging_score", -1.0)))
	var text: Dictionary = model.config.result_report.text
	_grade.text = text.grade % [model.performance_grade(host._result_score), host._result_score]
	var quizzes: int = session.chat.correct_answers + session.chat.wrong_answers + session.chat.missed_questions
	_stats.text = text.stats % [session.chat.correct_answers, quizzes, session.income.thanked_count, session.income.donation_count, session.tap_count]
	_technical_stats.text = text.technical_stats % [session.chat.blocked_spam, session.chat.blocked_spam + session.chat.missed_spam, host._clock(session.hot_game_seconds)]
	for key in components:
		var maximum: float = float(model.config.score_weights[key]) * 100.0
		_values[key].text = text.points % [float(components[key]) * maximum / 100.0, maximum]
		_bars[key].size.x = 460.0 * float(components[key]) / 100.0
	_tip.text = model.performance_tip(session, components)
	_modal.show()
	_open.hide()
	_close.grab_focus()

func close_report() -> void:
	_modal.hide()
	host._refresh()
	_open.grab_focus()

func refresh() -> void:
	var finished: bool = host.session.state == host.Session.State.FINISHED
	_open.visible = finished and not _modal.visible
	if finished:
		if host._save_pending:
			host._action.text = host.progression.config.result_report.text.retry
		host._action.position.x = 180
		host._action.add_theme_font_size_override("font_size", 26)
		host._action.size.x = 300
	else:
		host._action.position.x = 20
		host._action.size.x = 460
		_modal.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if _modal.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		close_report()
		get_viewport().set_input_as_handled()
