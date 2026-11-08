extends SceneTree
var viewport: SubViewport
var ui: Control
var checks := 0
var failures := 0
var path := "/tmp/hypster_viral_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream/viral_moment_v23"

func _initialize() -> void:
	call_deferred("run_all")

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

func capture(label: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUTPUT + "/" + label + ".png") == OK, "Capture " + label)

func run_all() -> void:
	check(await run() == true, "UI scenario finished without runtime errors")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Viral moment UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func run() -> bool:
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
	var flow: Control = ui._viral
	check(not flow.visible, "No event over setup")
	ui._mode.select(1)
	click(ui._action)
	check(not flow.visible and ui._studio.report_visible, "No target over launch report")
	click(ui._action)
	ui.session._config["viral_spawn_real_seconds"] = 5.0
	ui._process(5.2)
	check(flow.visible and flow._button.visible, "Live stream shows scheduled target")
	check(flow._button.size.y >= 64 and flow._button.size.x >= 64, "Moving target has generous touch area")
	check(flow._button.get_global_rect().position.x >= 28 and flow._button.get_global_rect().end.x <= 512, "Target stays fully within portrait viewport")
	check(not flow._button.get_global_rect().intersects(ui._donation_panel.get_global_rect()) and not flow._button.get_global_rect().intersects(ui._chat_view.get_global_rect()), "Flight avoids donation and chat actions")
	check(not flow._button.get_global_rect().intersects(ui._cooling._fan.get_global_rect()) and not flow._button.get_global_rect().intersects(ui._cooling._button.get_global_rect()), "Flight avoids both cooling controls")
	check(flow._button.accessibility_name.contains("мегафон"), "Button has meaningful accessibility label")
	await capture("flying")
	var x: float = flow._button.position.x
	ui._process(0.5)
	check(flow._button.position.x > x, "Target moves across room")
	click(ui._action)
	var remaining: float = ui.session.viral_seconds_left()
	ui._process(5)
	check(not flow.visible and ui.session.viral_seconds_left() == remaining, "Pause hides target and freezes deadline")
	flow.catch_moment()
	check(ui.session.viral_caught == 0, "Hidden action cannot reward on pause")
	ui._exit_flow._open_confirmation()
	check(not flow.visible, "Exit confirmation hides viral target")
	ui._exit_flow.cancel_exit()
	click(ui._action)
	check(flow._button.visible and ui.session.viral_seconds_left() == remaining, "Resume restores remaining catch window")
	var taps: int = ui.session.tap_count
	var income: int = ui.session.income.earned_total_units()
	var hype: float = ui.session.hype
	click(flow._button)
	check(ui.session.viral_caught == 1 and is_equal_approx(ui.session.hype, hype + 10), "Actual mouse input catches megaphone and grants hype")
	check(ui.session.tap_count == taps and ui.session.income.earned_total_units() == income, "Catch consumes input without room tap or money")
	check(not flow._button.visible and flow._feedback.visible and flow._feedback.text.contains("10.0"), "Catch immediately shows actual gain")
	flow.catch_moment()
	check(ui.session.viral_caught == 1, "Repeat UI call cannot reward twice")
	await capture("caught")
	ui._process(2.1)
	check(not flow._button.visible and not flow._feedback.visible, "Feedback disappears after configured time")
	ui.session.finish_early()
	ui._process(0)
	check(not flow.visible and FileAccess.file_exists(path), "Results hide target and settle only isolated profile")
	click(ui._action)
	click(ui._action)
	click(ui._action)
	ui.session._config["viral_spawn_real_seconds"] = 5.0
	ui._process(6.9)
	check(flow._button.get_global_rect().end.x <= 512 and flow._button.visible, "Late flight stays on-screen and catchable")
	await capture("last_chance")
	ui._process(0.1)
	check(not flow._button.visible and flow._feedback.visible and ui.session.viral_caught == 0, "Timeout removes target without catch reward")
	await capture("missed")
	ui.session.finish_early()
	ui._process(0)
	click(ui._action)
	click(ui._action)
	click(ui._action)
	ui.session._config["viral_spawn_real_seconds"] = 5.0
	ui._process(5.1)
	flow._button.grab_focus()
	await process_frame
	check(flow._button.has_focus(), "Viral target receives keyboard focus")
	var before_key: int = ui.session.tap_count
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = pressed
		viewport.push_input(key)
	check(ui.session.viral_caught == 1 and ui.session.tap_count == before_key, "Focused keyboard catch (caught=%d, taps=%d, before=%d)" % [ui.session.viral_caught, ui.session.tap_count, before_key])
	return true
