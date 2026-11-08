extends SceneTree
var viewport: SubViewport
var ui: Control
var checks := 0
var failures := 0
var path := "/tmp/hypster_sound_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream/sound_fault_v24"

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
	print("Sound fault UI: %d checks, %d failures" % [checks, failures])
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
	var flow: Control = ui._sound_fault
	check(not flow.visible, "Fault controls hidden during preparation")
	seed(2401)
	var seen := {}
	var schedules_valid := true
	for index in range(200):
		ui._new_session()
		var settings: Dictionary = ui.session._config
		var viral: bool = settings.has("viral_spawn_real_seconds")
		var sound: bool = settings.has("sound_fault_spawn_real_seconds")
		seen["viral" if viral else ("sound" if sound else "none")] = true
		schedules_valid = schedules_valid and not (viral and sound)
		for key in ["viral_spawn_real_seconds", "sound_fault_spawn_real_seconds"]:
			if settings.has(key):
				schedules_valid = schedules_valid and settings[key] >= ui.config.live_events.first_real_seconds and settings[key] <= ui.config.live_events.last_real_seconds
	check(schedules_valid and seen.size() == 3, "Scheduler supports both event types and no-event streams, never schedules both, and respects time bounds")
	ui._mode.select(1)
	click(ui._action)
	check(not flow.visible and ui._studio.report_visible, "Launch report has no repair controls")
	click(ui._action)
	ui.session._config["sound_fault_spawn_real_seconds"] = 5.0
	ui.session._config["viral_spawn_real_seconds"] = -1.0
	ui._process(10.1)
	check(flow.visible and flow._panel.visible and ui.session.sound_fault_active, "Live fault exposes recovery control")
	check(flow._button.size.y >= 44 and not flow._button.accessibility_name.is_empty(), "Repair has large touch target and accessible name")
	check(not flow._panel.get_global_rect().intersects(ui._donation_panel.get_global_rect()) and not flow._panel.get_global_rect().intersects(ui._chat_view.get_global_rect()), "Fault panel avoids chat and donation actions")
	check(not flow._panel.get_global_rect().intersects(ui._cooling._fan.get_global_rect()) and not flow._panel.get_global_rect().intersects(ui._cooling._button.get_global_rect()), "Fault panel avoids cooling controls")
	await capture("fault")
	check(ui.session.chat.active.kind == "quiz", "Chat question remains active alongside fault")
	click(ui._chat_buttons[int(ui.session.chat.active.correct)])
	check(ui.session.chat.correct_answers == 1 and ui.session.sound_fault_active, "Chat answer remains available and cannot inadvertently repair sound")
	click(ui._thanks_button)
	check(ui.session.income.thanked_count == 1 and ui.session.sound_fault_active, "Donation thanks remains available during fault")
	click(ui._action)
	var time: float = ui.session.sound_fault_game_seconds
	ui._process(20)
	flow.repair_sound()
	check(not flow.visible and ui.session.sound_fault_game_seconds == time and ui.session.sound_fault_repairs == 0, "Paused fault freezes time and rejects hidden repair")
	ui._exit_flow._open_confirmation()
	check(not flow.visible, "Exit confirmation hides repair controls")
	ui._exit_flow.cancel_exit()
	click(ui._action)
	var taps: int = ui.session.tap_count
	var earned: int = ui.session.income.earned_total_units()
	click(flow._button)
	check(not ui.session.sound_fault_active and ui.session.sound_fault_repairs == 1 and flow._feedback.visible, "Real mouse input restores sound with immediate feedback")
	check(ui.session.tap_count == taps and ui.session.income.earned_total_units() == earned, "Repair consumes pointer without taps or money")
	flow.repair_sound()
	check(ui.session.sound_fault_repairs == 1, "Repeated UI repair cannot count twice")
	await capture("restored")
	ui._process(2.1)
	check(not flow._feedback.visible and not flow._panel.visible, "Recovery feedback expires without another fault")
	ui.session.finish_early()
	ui._process(0)
	check(not flow.visible, "Results hide repair controls")
	click(ui._results._open)
	check(ui._results._fault_stats.text.contains("ВОССТАНОВЛЕНО 1") and ui._results._fault_stats.text.contains(ui._clock(time)), "Report shows actual faulty duration and repair count")
	check(ui._results._fault_stats.get_global_rect().end.y <= ui._results._values.activity.get_global_rect().position.y and ui._results._close.get_global_rect().end.y <= ui._results._panel.get_global_rect().end.y, "New statistics leave score and close button unobstructed")
	await capture("report")
	click(ui._results._close)
	click(ui._action)
	click(ui._action)
	click(ui._action)
	ui.session._config["sound_fault_spawn_real_seconds"] = 5.0
	ui.session._config["viral_spawn_real_seconds"] = -1.0
	ui._process(5.1)
	flow._button.grab_focus()
	await process_frame
	check(flow._button.has_focus(), "Repair control receives focus")
	var before_key: int = ui.session.tap_count
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_SPACE
		key.physical_keycode = KEY_SPACE
		key.pressed = pressed
		viewport.push_input(key)
	check(ui.session.sound_fault_repairs == 1 and ui.session.tap_count == before_key, "Keyboard repair does not leak into room acceleration")
	return true

