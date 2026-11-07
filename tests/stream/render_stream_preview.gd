extends SceneTree
## UI integration check and screenshots of the actual main scene.
const Session = preload("res://src/stream/stream_session.gd")
var viewport: SubViewport
var ui: Control
var failures := 0
const OUTPUT := "res://source_art/prototypes/stream"

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event)

func capture(file_name: String) -> void:
	ui._settle_income()
	ui._refresh()
	# Let deferred minimum-size changes settle before reading the render target.
	for frame in range(2):
		await process_frame
		await RenderingServer.frame_post_draw
	var error := viewport.get_texture().get_image().save_png(OUTPUT + "/" + file_name)
	check(error == OK, "Screenshot failed: " + file_name)
	check(ui._action.get_global_rect().end.y <= 960.0, "Action button extends beyond the screen")
	check(ui._timer.get_global_rect().position.y >= ui._status.get_global_rect().end.y, "Timer must not overlap the status line")
	if ui._chat_view.visible and not ui.session.chat.active.is_empty():
		check(ui._chat_time_bar.get_global_rect().end.y <= ui._chat_buttons[0].get_global_rect().position.y, "Countdown must not overlap answer buttons")
		for button in ui._chat_buttons:
			if button.visible:
				check(button.size.y >= 56 and button.get_global_rect().end.y <= ui._action.get_global_rect().position.y, "Answers must remain large enough and above the pause button")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main := (load("res://scenes/app/main.tscn") as PackedScene).instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = "user://ui_wallet_test_%d.json" % OS.get_process_id()
	viewport.add_child(main)
	ui.set_process(false)
	await process_frame
	await capture("stream_ready_v06.png")
	click(ui._action.get_global_rect().get_center())
	check(ui.session.state == Session.State.LIVE, "Start button must launch the stream")
	check(ui.session.tap_count == 0, "Start click must not leak into room tapping")
	check(ui._effects.get_child_count() == 0, "Start button must not create tap feedback")
	for i in range(18):
		click(Vector2(270, 560))
		ui.session.advance(1.0 / 6.0)
	check(ui.session.tap_count == 18, "Room must count each click exactly once")
	check(ui._effects.get_child_count() <= 16, "Tap feedback must have a bounded node count")
	for effect in ui._effects.get_children():
		effect.queue_free()
	await process_frame
	await capture("stream_live_v06.png")
	click(Vector2(340, 470))
	check(ui.session.tap_count == 19 and ui._effects.get_child_count() == 1, "Each live click must create exactly one feedback effect")
	ui._effects.get_child(0)._process(0.12)
	await capture("stream_tap_v06.png")
	ui._effects.get_child(0)._process(1.0)
	await process_frame
	check(ui._effects.get_child_count() == 0, "Tap feedback must clean itself up")
	check(not ui.session.chat.active.is_empty() and ui._chat_view.visible, "Live room must expose its interactive chat")
	await capture("stream_question_v06.png")
	var tap_count_before_answer: int = ui.session.tap_count
	var answer_index: int = ui.session.chat.active.correct
	click(ui._chat_buttons[answer_index].get_global_rect().get_center())
	check(ui.session.chat.correct_answers == 1, "Clicking a correct answer must resolve the current quiz")
	check(ui.session.tap_count == tap_count_before_answer, "Answer button must never leak into room tapping")
	check(ui.session.chat.combo == 1, "Quiz streak must reach the UI")
	await capture("stream_chat_correct_v06.png")
	click(ui._action.get_global_rect().get_center())
	check(ui.session.state == Session.State.PAUSED, "Pause button must pause the stream")
	await capture("stream_paused_v06.png")
	click(ui._action.get_global_rect().get_center())
	check(ui.session.state == Session.State.LIVE, "Resume button must resume the stream")
	ui.session.advance(60.0)
	await capture("stream_completed_v06.png")
	check(ui.session.end_reason == Session.EndReason.COMPLETED, "Quick UI session must finish normally")
	var earned: int = ui.session.income.total_units()
	check(ui.wallet.balance_units == earned and earned > 0, "Completed UI stream must credit earned money to the wallet")
	ui._settle_income(true)
	check(ui.wallet.balance_units == earned, "Repeated result rendering must not settle twice")
	var reloaded := preload("res://src/economy/player_wallet.gd").new(ui.wallet_path)
	check(reloaded.load_error == OK and reloaded.balance_units == earned, "Actual UI income must be readable from its isolated save")
	click(ui._action.get_global_rect().get_center())
	check(ui.session.state == Session.State.READY and ui._mode.visible, "New stream must return to duration selection")
	ui._mode.select(1)
	await process_frame
	click(ui._action.get_global_rect().get_center())
	check(ui.session.duration == 900.0, "Duration selector must affect the next session")
	check(ui.session.chat.correct_answers == 0, "New UI session must clear chat results")
	ui.session.advance(4.01)
	ui._refresh()
	click(ui._chat_buttons[int(ui.session.chat.active.correct)].get_global_rect().get_center())
	ui.session.advance(6.1)
	ui._refresh()
	check(ui._donation_panel.visible, "Donation must have a visible banner")
	await capture("stream_donation_v06.png")
	var taps_before_thanks: int = ui.session.tap_count
	click(ui._thanks_button.get_global_rect().get_center())
	check(ui.session.income.thanked_count == 1 and ui.session.income.thanks_units > 0, "Thanks button must grant one bonus")
	check(ui.session.tap_count == taps_before_thanks and ui._effects.get_child_count() == 0, "Thanks must not leak into tapping or tap feedback")
	await capture("stream_thanked_v06.png")
	ui.session.advance(5.9)
	ui._refresh()
	check(ui.session.chat.active.kind == "poll", "Poll must appear in the regular stream")
	await capture("stream_poll_v06.png")
	click(ui._chat_buttons[0].get_global_rect().get_center())
	check(ui.session.chat.reactions == 1, "Poll button must register engagement")
	for i in range(3000):
		ui.session.tap()
		ui.session.advance(1.0 / 6.0)
		if ui.session.heat >= 95.0:
			break
	await capture("stream_critical_v06.png")
	for i in range(300):
		ui.session.tap()
		ui.session.advance(1.0 / 6.0)
		if ui.session.state == Session.State.FINISHED:
			break
	await capture("stream_overheated_v06.png")
	check(ui.session.end_reason == Session.EndReason.OVERHEATED, "UI session must display overheating results")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(ui.wallet_path + suffix):
			DirAccess.remove_absolute(ui.wallet_path + suffix)
	print("Stream UI integration: ", failures, " failures; screenshots: ", OUTPUT)
	quit(1 if failures else 0)
