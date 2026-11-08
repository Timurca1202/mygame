extends SceneTree
const Wallet = preload("res://src/economy/player_wallet.gd")
var viewport: SubViewport
var ui: Control
var checks := 0
var failures := 0
var path := "user://exit_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream/exit_v19"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func pointer(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	viewport.push_input(motion)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	viewport.push_input(event)

func click(button: Control) -> void:
	pointer(button.get_global_rect().get_center(), true)
	pointer(button.get_global_rect().get_center(), false)

func hold_to_warning() -> void:
	var button: Button = ui._exit_flow._end_button
	pointer(button.get_global_rect().get_center(), true)
	ui._process(3.05)
	pointer(button.get_global_rect().get_center(), false)

func capture(name: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK, "Capture " + name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var budget := Wallet.new(path)
	budget.followers = 200
	check(budget.credit("isolated_exit_budget", 100000) == OK, "Prepare isolated wallet")
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main: Node2D = load("res://scenes/app/main.tscn").instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = path
	viewport.add_child(main)
	ui.set_process(false)
	ui._mode.select(1)
	click(ui._action)
	click(ui._action)
	ui.session.advance(60)
	ui._refresh()
	check(not ui._exit_flow._end_button.visible, "Live stream keeps existing chat layout")
	click(ui._action)
	var flow: Control = ui._exit_flow
	check(ui.session.state == ui.Session.State.PAUSED and flow._end_button.visible, "Pause exposes protected finish action")
	check(flow._end_button.get_global_rect().end.y + 8 <= ui._action.get_global_rect().position.y, "Finish action leaves gap before resume button")
	await capture("pause")
	var held_time: float = ui.session.elapsed_game
	click(flow._end_button)
	ui._process(4)
	check(not flow._modal.visible and ui.session.state == ui.Session.State.PAUSED, "A normal click cannot trigger exit")
	pointer(flow._end_button.get_global_rect().get_center(), true)
	ui._process(2.9)
	check(not flow._modal.visible and flow._progress.value > 0.9, "Hold must reach full configured duration")
	pointer(flow._end_button.get_global_rect().get_center(), false)
	ui._process(1)
	check(not flow._modal.visible, "Release before three seconds cancels hold")
	pointer(flow._end_button.get_global_rect().get_center(), true)
	ui._process(1)
	var outside := InputEventMouseMotion.new()
	outside.position = Vector2(8, 8)
	outside.button_mask = MOUSE_BUTTON_MASK_LEFT
	viewport.push_input(outside)
	ui._process(3)
	pointer(Vector2(8, 8), false)
	check(not flow._modal.visible, "Dragging outside cancels hold")
	pointer(flow._end_button.get_global_rect().get_center(), true)
	flow._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	ui._process(4)
	pointer(flow._end_button.get_global_rect().get_center(), false)
	check(not flow._modal.visible, "Losing app focus cancels hold")
	hold_to_warning()
	check(flow._modal.visible and ui.session.state == ui.Session.State.PAUSED, "Full hold opens confirmation without ending stream")
	check(ui.session.elapsed_game == held_time and ui.wallet.followers == 200 and ui.wallet.balance_units == 100000, "Hold and confirmation consume no game time or saved resources")
	await capture("warning")
	click(flow._cancel)
	check(not flow._modal.visible and ui.session.state == ui.Session.State.PAUSED, "Cancel returns to pause with no consequences")
	click(ui._action)
	check(ui.session.state == ui.Session.State.LIVE, "Resume remains available after cancel")
	click(ui._action)
	hold_to_warning()
	var earned: int = ui.session.income.earned_total_units()
	var loss: float = 200 * ui.session.exit_penalty_ratio()
	click(flow._confirm)
	check(ui.session.end_reason == ui.Session.EndReason.EARLY and ui.session.state == ui.Session.State.FINISHED, "Explicit confirmation ends actual session")
	check(ui.wallet.balance_units == 100000 + earned and is_equal_approx(ui.wallet.followers, 200 - loss), "Actual results post earned money and exact follower loss together")
	check(ui._follower_gain == 0 and ui.session.hype == 0, "Penalized short streams cannot farm organic followers")
	var after: float = ui.wallet.followers
	ui._settle_income(true)
	ui._refresh()
	check(ui.wallet.followers == after and ui.wallet.balance_units == 100000 + earned, "Result refresh cannot duplicate loss or income")
	check(ui._channel_detail.text.contains("-") and not ui._channel_detail.text.contains("+-"), "Negative follower result has a clear sign")
	await capture("early_results")
	click(ui._action)
	ui._mode.select(0)
	click(ui._action)
	click(ui._action)
	ui.session.advance(27)
	ui._refresh()
	click(ui._action)
	hold_to_warning()
	check(flow._modal.visible and ui.session.exit_penalty_ratio() == 0 and flow._hype.text.is_empty(), "At ninety percent warning accurately shows no penalty")
	await capture("safe_warning")
	var before_safe: float = ui.wallet.followers
	click(flow._confirm)
	check(ui.wallet.followers > before_safe and ui._follower_loss == 0, "Safe early finish grants normal earned progression without follower loss")
	var saved := Wallet.new(path)
	check(is_equal_approx(saved.followers, ui.wallet.followers) and saved.balance_units == ui.wallet.balance_units, "Both outcomes survive save reload")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Protected stream exit UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
