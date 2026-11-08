extends SceneTree
const Session = preload("res://src/stream/stream_session.gd")
var viewport: SubViewport
var ui: Control
var failures := 0
var checks := 0
const OUTPUT := "res://source_art/prototypes/stream/studio_v12"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func click(point: Vector2) -> void:
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
	var main: Node2D = load("res://scenes/app/main.tscn").instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = "user://studio_ui_%d.json" % OS.get_process_id()
	viewport.add_child(main)
	ui.set_process(false)
	await capture("ready")
	var studio: Control = ui._studio
	click(studio._edit_button.get_global_rect().get_center())
	check(studio._form.visible and not studio._report_panel.visible, "Preparation shows no score")
	studio.title_input.text = "   "
	studio.title_input.text_changed.emit(studio.title_input.text)
	check(ui._action.disabled, "Whitespace-only title blocks launch")
	ui._action_pressed()
	check(ui.session.state == Session.State.READY and ui.wallet.recent_titles.is_empty(), "Invalid launch cannot start or save history")
	studio.title_input.text = "Хоррор кооп кот челлендж"
	studio.title_input.text_changed.emit(studio.title_input.text)
	for button in studio.themes:
		button.button_pressed = true
	await capture("preparation")
	studio.close_form()
	click(ui._action.get_global_rect().get_center())
	check(ui.session.state == Session.State.LIVE and studio.report_visible, "Launch reveals report")
	check(studio.report.score == 100 and is_equal_approx(ui.session.viewers, 3.9), "Actual launch applies title multiplier")
	ui._process(10.0)
	ui._tap(Vector2(270, 500))
	check(ui.session.elapsed_game == 0 and ui.session.tap_count == 0, "Reading report freezes simulation and blocks taps")
	check(ui.wallet.recent_titles.size() == 1 and ui.wallet.balance_units == 0, "Launch records title once without awarding money")
	await capture("report")
	click(ui._action.get_global_rect().get_center())
	check(not studio.report_visible and ui.session.tap_count == 0, "Continue closes report without leaking a tap")
	ui._process(1.0)
	check(ui.session.elapsed_game > 0, "Simulation starts after report dismissal")
	await capture("live")
	ui.session.advance(60.0)
	ui._settle_income()
	ui._action_pressed()
	ui._action_pressed()
	check(studio.report.parts.freshness == 0, "Next launch penalizes repeated title")
	var restored := preload("res://src/economy/player_wallet.gd").new(ui.wallet_path)
	check(restored.recent_titles.size() == 2 and restored.balance_units == ui.wallet.balance_units, "History and income coexist after reload")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(ui.wallet_path + suffix):
			DirAccess.remove_absolute(ui.wallet_path + suffix)
	print("Studio UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
