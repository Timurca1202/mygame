extends SceneTree
var viewport: SubViewport
var ui: Control
var checks := 0
var failures := 0
var path := "/tmp/hypster_audience_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream/live_audience_v27"

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
	print("Live audience UI: %d checks, %d failures" % [checks, failures])
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
	check(not ui._audience_status.visible, "Preparation hides live notices")
	ui._mode.select(1)
	click(ui._action)
	check(not ui._audience_status.visible and ui._studio.report_visible, "Launch report hides live notices")
	click(ui._action)
	ui.session._config.audience.grace_game_seconds = 0
	ui.session._config.device_capacity_seconds = 1000000
	ui.session._config.hype_decay_per_second = 0
	ui.session._config.hype_idle_decay_per_second = 0
	ui.session._config["viral_spawn_real_seconds"] = -1.0
	ui.session._config["sound_fault_spawn_real_seconds"] = -1.0
	ui.session.hype = 100
	var baseline: float = ui.session.starting_viewers
	for index in range(300):
		ui._process(0.1)
		if ui._audience_status.visible:
			break
	ui.session._last_activity = ui.session.elapsed_real
	ui._refresh()
	check(ui.session.viewers > baseline and ui._channel_detail.text.contains("%.1f/10" % ui.session.viewers), "Live room displays changing fractional audience and device cap")
	check(ui._audience_status.visible and ui._audience_status.text == ui.config.audience.text.growing, "Whole-viewer arrival has readable cause")
	check(not ui._audience_status.get_global_rect().intersects(ui._chat_feedback.get_global_rect()) and not ui._audience_status.get_global_rect().intersects(ui._sound_fault._panel.get_global_rect()), "Audience notice stays separate from chat feedback and fault actions")
	await capture("arrivals")
	click(ui._action)
	var audience: float = ui.session.viewers
	var earned: int = ui.session.income.earned_total_units()
	ui._process(20)
	check(ui.session.viewers == audience and ui.session.income.earned_total_units() == earned and not ui._audience_status.visible, "Pause freezes audience and income and hides notices")
	click(ui._action)
	ui._process(40)
	ui.session.hype = 0
	ui.session._config["sound_fault_spawn_real_seconds"] = ui.session.elapsed_real
	for index in range(400):
		ui._process(0.1)
		if ui.session.audience_notice == "sound" and ui._audience_status.visible:
			break
	check(ui.session.sound_fault_active and ui._sound_fault._panel.visible and ui._audience_status.visible and ui._audience_status.text == ui.config.audience.text.sound, "Fault causes actual departure with explanation while repair remains available")
	check(ui._sound_fault._button.size.y >= 44 and not ui._audience_status.get_global_rect().intersects(ui._sound_fault._button.get_global_rect()), "Audience feedback cannot cover recovery button")
	await capture("departures")
	ui._process(70)
	var before: float = ui.session.viewers
	click(ui._sound_fault._button)
	ui._process(20)
	check(not ui.session.sound_fault_active and ui.session.viewers > before, "Restoring sound allows audience to return gradually")
	var average: float = ui.session.average_viewers()
	var peak: float = ui.session.peak_viewers
	var actual_income: int = ui.session.income.earned_total_units()
	ui.session.finish_early()
	ui._process(0)
	check(not ui._audience_status.visible and ui.wallet.balance_units == actual_income, "Results hide notices and settle exactly actual dynamic-audience income")
	click(ui._results._open)
	check(ui._results._audience_stats.text == ui.progression.config.result_report.text.audience_stats % [average, peak], "Report uses actual average and peak audience")
	check(ui._results._audience_stats.get_global_rect().end.y <= ui._results._values.activity.get_global_rect().position.y and ui._results._panel.get_global_rect().encloses(ui._results._close.get_global_rect()), "Extra statistics leave score rows and report action within panel")
	await capture("report")
	click(ui._results._close)
	var saved: int = ui.wallet.balance_units
	ui._settle_income(true)
	check(ui.wallet.balance_units == saved, "Reopening result cannot duplicate dynamic income")
	click(ui._action)
	check(ui.session.viewer_game_seconds == 0 and is_equal_approx(ui.session.viewers, ui.session.starting_viewers), "New stream resets viewer-time and uses newly calculated starting audience")
	return true

