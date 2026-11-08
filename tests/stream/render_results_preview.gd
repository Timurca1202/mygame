extends SceneTree
const Wallet = preload("res://src/economy/player_wallet.gd")
var viewport: SubViewport
var ui: Control
var checks := 0
var failures := 0
var path := "user://results_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream/results_v20"

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

func capture(name: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK, "Capture " + name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main: Node = load("res://scenes/app/main.tscn").instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = path
	viewport.add_child(main)
	ui.set_process(false)
	var flow: Control = ui._results
	check(not flow._open.visible, "Setup has no empty result report")
	flow.open_report()
	check(not flow._modal.visible, "Report cannot open before a stream")
	ui._mode.select(0)
	click(ui._action)
	click(ui._action)
	check(not flow._open.visible, "Live stream layout is preserved")
	# An actual write failure keeps results inspectable without inventing saved rewards.
	DirAccess.make_dir_absolute(path + ".tmp")
	for second in range(60):
		ui.session.advance(1)
		if ui.session.state == ui.Session.State.FINISHED:
			break
		if not ui.session.chat.active.is_empty():
			ui.session.answer_chat(ui.session.chat.event_serial, int(ui.session.chat.active.get("correct", 0)))
		if not ui.session.income.donation.is_empty():
			ui.session.thank_donation(ui.session.income.donation_serial)
		ui.session.tap()
	ui._process(0)
	check(ui._save_pending and flow._open.visible, "Failed save leaves retry and score details available")
	check(flow._open.size.x >= 44 and flow._open.size.y >= 44 and flow._open.get_global_rect().end.x + 12 <= ui._action.get_global_rect().position.x, "Result actions have separate large touch targets")
	check(ui._bottom_panel.get_global_rect().encloses(ui._action.get_global_rect()), "Save retry fits inside bottom panel")
	await capture("save_retry")
	click(flow._open)
	check(flow._modal.visible, "Real pointer opens report")
	check(flow._grade.text.contains(ui.progression.performance_grade(ui._result_score)), "Report shows actual result grade")
	check(flow._close.has_focus(), "Focus moves into report")
	for key in flow._values:
		check(flow._panel.get_global_rect().encloses(flow._values[key].get_global_rect()), "Score row fits report: " + key)
		check(flow._bars[key].get_parent().size.y == 6 and flow._bars[key].get_global_rect().end.y < flow._values[key].get_global_rect().end.y + 20, "Score bar stays thin: " + key)
	check(flow._tip.get_line_count() * flow._tip.get_line_height() <= flow._tip.size.y, "Full recommendation fits without clipping")
	await capture("report")
	ui._action_pressed()
	check(ui.session.state == ui.Session.State.FINISHED, "Report blocks underlying new-stream action")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	viewport.push_input(escape)
	check(not flow._modal.visible and flow._open.has_focus(), "Escape returns focus to result details")
	DirAccess.remove_absolute(path + ".tmp")
	ui._settle_income(true)
	ui._refresh()
	check(not ui._save_pending, "Existing save retry can persist the same inspected result")
	await capture("summary")
	click(ui._action)
	check(ui.session.state == ui.Session.State.READY and not ui._save_pending, "Save retry persists result then returns to setup")
	check(not flow._open.visible and ui._action.position.x == 20 and ui._action.size.x == 460, "Setup restores full-width launch action")
	var saved := Wallet.new(path)
	check(saved.completed_streams == 1 and saved.balance_units == ui.wallet.balance_units, "Inspecting report cannot duplicate settlement")
	ui._mode.select(1)
	click(ui._action)
	click(ui._action)
	ui.session.advance(5)
	ui.session.finish_early()
	ui._process(0)
	click(flow._open)
	check(flow._modal.visible and flow._tip.text == ui.progression.config.result_report.tips.early, "Early finish shows actual penalty advice")
	await capture("early_report")
	click(flow._close)
	check(not flow._modal.visible and flow._open.has_focus(), "Close button returns to same results")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Results UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
