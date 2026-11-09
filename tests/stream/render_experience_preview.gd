extends SceneTree
var viewport: SubViewport
var ui: Control
var checks := 0
var failures := 0
var path := "/tmp/hypster_xp_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream/review_v31"

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
	print("Experience HUD UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func run() -> bool:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var seed_wallet: RefCounted = load("res://src/economy/player_wallet.gd").new(path)
	check(seed_wallet.settle_stream("isolated_seed", 1000000, 123, 50, true, 0, 95) == OK, "Prepare isolated near-level profile")
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var main: Node = load("res://scenes/app/main.tscn").instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = path
	viewport.add_child(main)
	ui.set_process(false)
	var screen := Rect2(Vector2.ZERO, Vector2(viewport.size))
	for control in [ui._resource_panel, ui._top_panel, ui._bottom_panel, ui._navigation, ui._action]:
		check(screen.encloses(control.get_global_rect()), "Main scene keeps complete panels and actions inside the screen: %s" % control.name)
	check(ui._level_label.text == "1" and ui._xp_label.text.contains("95/102"), "HUD displays saved level and XP")
	check(ui._wallet_label.text == "$100.00" and ui._channel_label.text.contains("123"), "Top resources use actual saved money and followers")
	check(ui._energy_label.text.contains("СКОРО") and ui._gems_label.text.contains("СКОРО"), "Future energy and premium currency have no fake balances")
	for control in [ui._wallet_label, ui._channel_label, ui._level_label, ui._energy_label, ui._gems_label, ui._xp_label, ui._xp_bar]:
		check(ui._resource_panel.get_global_rect().encloses(control.get_global_rect()), "Resource element fits separate horizontal strip: %s %s" % [control.name, control.get_global_rect()])
	for control in [ui._heat_bar, ui._hype_bar, ui._timer, ui._status]:
		check(ui._top_panel.get_global_rect().encloses(control.get_global_rect()), "Stream controls fit independent stream panel")
	check(ui._resource_panel.get_global_rect().end.y + 8 <= ui._top_panel.get_global_rect().position.y and ui._top_panel.get_global_rect().end.y <= 202, "Resources sit above stream panel without moving room boundary")
	var values := [ui._wallet_label, ui._channel_label, ui._level_label, ui._energy_label, ui._gems_label]
	check(ui._resource_icons.size() == 5, "All five resource captions are replaced by icons")
	for index in range(ui._resource_icons.size()):
		var icon: TextureRect = ui._resource_icons[index]
		check(icon.texture != null and icon.texture.get_size() == Vector2(32, 32), "Ready-made icon imports at native pixel size")
		check(not icon.tooltip_text.is_empty() and icon.accessibility_name == icon.tooltip_text, "Icon retains resource name through tooltip and accessibility")
		check(ui._resource_panel.get_global_rect().encloses(icon.get_global_rect()) and not icon.get_global_rect().intersects(values[index].get_global_rect()), "Icon fits its cell without covering the value")
	for index in range(values.size() - 1):
		check(values[index].get_global_rect().end.x + 8 <= values[index + 1].get_global_rect().position.x, "All five values occupy consecutive horizontal cells")
	for control in ui._resource_panel.get_children():
		if control is Label:
			var font: Font = control.get_theme_font("font")
			check(font.get_string_size(control.text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x <= control.size.x, "Resource text fits its own cell: " + control.text)
	check(ui._short_resource(10000000) == "10.0M" and ui._short_resource(10000) == "10.0K", "Large resource values use compact notation")
	check(not ui._wallet_label.get_global_rect().intersects(ui._channel_label.get_global_rect()) and not ui._channel_label.get_global_rect().intersects(ui._gems_label.get_global_rect()), "Resource counters do not overlap")
	check(not ui._xp_label.get_global_rect().intersects(ui._energy_label.get_global_rect()) and not ui._timer.get_global_rect().intersects(ui._status.get_global_rect()), "XP, energy, timer and status have separate space")
	await capture("ready")
	ui._mode.select(1)
	click(ui._action)
	click(ui._action)
	ui.session._config["viral_spawn_real_seconds"] = -1.0
	ui.session._config["sound_fault_spawn_real_seconds"] = -1.0
	ui._process(10)
	check(ui._wallet_label.text == "$100.00" and ui._studio_caption.text.contains("ЗР."), "Live HUD keeps saved balance separate from pending income and audience")
	await capture("live")
	DirAccess.make_dir_absolute(path + ".tmp")
	ui.session.advance(1000)
	ui._process(0)
	check(ui.session.end_reason == ui.Session.EndReason.COMPLETED and ui._experience_gain > 7, "Completed real stream earns enough XP to cross level boundary")
	check(ui._save_pending and ui.wallet.experience == 95 and ui.wallet.balance_units == 1000000 and ui._xp_label.text.contains("95/102"), "Failed write cannot advance XP or money shown in HUD")
	click(ui._results._open)
	check(ui._results._xp_stats.text.contains("ОЖИДАЕТ СОХРАНЕНИЯ"), "Unsaved result does not claim a completed level-up")
	click(ui._results._close)
	DirAccess.remove_absolute(path + ".tmp")
	ui._settle_income(true)
	ui._refresh()
	check(not ui._save_pending and ui.wallet.experience == 95 + ui._experience_gain and ui._level_label.text == "2", "Successful retry updates saved XP and top-level indicator together")
	click(ui._results._open)
	check(ui._results._xp_stats.text.contains("НОВЫЙ УРОВЕНЬ 2"), "Report explicitly celebrates level-up")
	check(ui._results._xp_stats.get_global_rect().end.y <= ui._results._values.activity.get_global_rect().position.y and ui._results._panel.get_global_rect().encloses(ui._results._close.get_global_rect()), "XP report row leaves score and closing action unobstructed")
	await capture("level_up")
	click(ui._results._close)
	var saved_xp: int = ui.wallet.experience
	var saved_balance: int = ui.wallet.balance_units
	ui._settle_income(true)
	check(ui.wallet.experience == saved_xp and ui.wallet.balance_units == saved_balance, "Repeated settlement cannot duplicate XP or money")
	click(ui._action)
	check(ui._level_label.text == "2" and ui.wallet.experience == saved_xp, "Next preparation retains progression")
	await capture("next_stream")
	var restored: RefCounted = load("res://src/economy/player_wallet.gd").new(path)
	check(restored.experience == saved_xp and restored.balance_units == saved_balance and restored.inventory == ui.wallet.inventory, "Profile reload preserves XP and existing rewards")
	return true

