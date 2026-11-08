extends SceneTree
const Wallet = preload("res://src/economy/player_wallet.gd")
var viewport: SubViewport
var ui: Control
var main: Node
var checks := 0
var failures := 0
var path := "user://moderation_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream/moderation_v22"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event)

func next_spam() -> void:
	for step in range(300):
		if not ui.session.chat.active.is_empty():
			if ui.session.chat.active.kind == "spam":
				ui._refresh()
				return
			ui.session.answer_chat(ui.session.chat.event_serial, int(ui.session.chat.active.get("correct", 0)))
		ui.session.advance(0.5)
	check(false, "Scheduled spam must appear without replacing active questions")

func capture(name: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK, "Capture " + name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var budget := Wallet.new(path)
	check(budget.credit("isolated_moderation_budget", 10000000) == OK, "Prepare isolated wallet")
	check(budget.buy("ifone_2g", 600000, true) == OK and budget.buy("desk_fan", 800000) == OK, "Prepare real owned device and fan")
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/app/main.tscn").instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = path
	viewport.add_child(main)
	ui.set_process(false)
	ui._mode.select(1)
	click(ui._action)
	click(ui._action)
	ui.session.advance(4.1)
	ui._refresh()
	check(not ui._block_button.visible, "Normal viewer question has no accidental ban action")
	next_spam()
	check(ui._block_button.is_visible_in_tree(), "Spam exposes a real labeled block button")
	check(ui._block_button.size.y >= 44 and ui._block_button.get_global_rect().end.y + 8 <= ui._action.get_global_rect().position.y, "Moderation has a separate touch target above pause")
	var hidden_answers := true
	for button in ui._chat_buttons:
		hidden_answers = hidden_answers and not button.visible
	check(hidden_answers and ui._chat_feedback.text == ui._text.spam_warning, "Spam replaces answer controls with clear consequence warning")
	await capture("spam")
	var taps: int = ui.session.tap_count
	click(ui._block_button)
	check(ui.session.chat.blocked_spam == 1 and ui.session.chat.active.is_empty(), "Real click removes current spam")
	check(ui.session.tap_count == taps and ui._chat_feedback.text == ui._text.spam_blocked, "Blocking never leaks into acceleration and shows success")
	ui._block_button.pressed.emit()
	check(ui.session.chat.blocked_spam == 1, "Stale hidden button signal cannot count twice")
	await capture("blocked")
	next_spam()
	click(ui._action)
	var remaining: float = ui.session.chat.seconds_left()
	ui._process(20)
	check(ui.session.chat.seconds_left() == remaining and not ui._block_button.is_visible_in_tree(), "Pause freezes moderation and hides its action")
	click(ui._action)
	ui.session.hype = 50
	ui._process(10.1)
	check(ui.session.chat.missed_spam == 1 and ui.session.hype < 44, "Ignored spam applies actual hype loss alongside ordinary idle decay")
	check(ui._chat_feedback.text.begins_with("СПАМ НЕ УДАЛЁН"), "Miss warning takes priority over idle hint")
	await capture("missed")
	var room: Node = main.get_node("StartRoom")
	room.set_process(false)
	ui.session.heat = 90
	ui._refresh()
	check(ui._status.text == ui._text.lag_status and ui.session.is_lagging(), "HUD explicitly identifies actual dropped-input lag")
	var frozen_time: float = room._screen_material.get_shader_parameter("screen_time")
	room._process(0.3)
	check(room._screen_material.get_shader_parameter("screen_time") == frozen_time, "Phone screen freezes during real lag pulse while game controls stay responsive")
	click(ui._action)
	room._process(1)
	check(room._screen_material.get_shader_parameter("screen_time") == frozen_time, "Pausing during lag preserves the displayed screen frame")
	click(ui._action)
	ui._tap(Vector2(410, 600))
	check(ui.session.tap_count == taps and ui._effects.get_child_count() == 1, "Lag tap shows explicit failure instead of fake hype gain")
	await capture("lag")
	ui._process(0.7)
	room._process(0.7)
	check(not ui.session.is_lagging() and room._screen_material.get_shader_parameter("screen_time") != frozen_time, "Phone screen resumes between periodic freezes")
	click(ui._cooling._button)
	check(ui.session.heat < 85 and not ui.session.is_lagging(), "Cooling below threshold immediately restores stream quality")
	ui._process(2.1)
	# The simulation clock is stepped manually; age its short visual effects too.
	for effect in ui._effects.get_children():
		effect._process(1.0)
	await process_frame
	ui._tap(Vector2(410, 600))
	check(ui.session.tap_count == taps + 1, "Real taps recover after cooling's explicit two-second cost")
	await capture("recovered")
	ui.session.finish_early()
	ui._process(0)
	click(ui._results._open)
	check(ui._results._technical_stats.text.contains("1/2") and ui._results._technical_stats.text.contains("ЛАГИ"), "Result report retains both moderation accuracy and actual hot game time")
	await capture("report")
	var restored := Wallet.new(path)
	check(restored.completed_streams == 1 and restored.balance_units == ui.wallet.balance_units and is_equal_approx(restored.last_score, ui._result_score), "Actual hot-stream income and score persist once")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Moderation and lag UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
