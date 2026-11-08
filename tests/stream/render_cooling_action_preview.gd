extends SceneTree
const Wallet = preload("res://src/economy/player_wallet.gd")
var viewport: SubViewport
var ui: Control
var main: Node
var checks := 0
var failures := 0
var path := "user://cooling_action_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream/active_cooling_v21"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func point_click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event)

func click(control: Control) -> void:
	point_click(control.get_global_rect().get_center())

func reveal_fan() -> void:
	for frame in range(2):
		await process_frame
	ui._shop._scroll.ensure_control_visible(ui._shop.rows.desk_fan.panel)
	for frame in range(2):
		await process_frame

func capture(name: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK, "Capture " + name)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var budget := Wallet.new(path)
	check(budget.credit("isolated_cooling_budget", 1000000) == OK, "Prepare isolated shop budget")
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/app/main.tscn").instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = path
	viewport.add_child(main)
	ui.set_process(false)
	var flow: Control = ui._cooling
	check(not flow.visible and not ui.session.active_cooling_available, "Unowned fan adds no controls")
	click(ui._shop_button)
	await reveal_fan()
	var fan_row: Dictionary = ui._shop.rows.desk_fan
	check(fan_row.effect.get_global_rect().end.y + 8 <= fan_row.button.get_global_rect().position.y, "Fan benefits leave space above purchase action")
	check(fan_row.effect.get_line_count() * fan_row.effect.get_line_height() <= fan_row.effect.size.y, "Fan description fits without clipping")
	await capture("fan_shop")
	click(ui._shop.rows.desk_fan.button)
	check(ui.wallet.inventory.has("desk_fan") and ui.wallet.balance_units == 200000, "Actual shop purchase enables owned fan")
	click(ui._stream_tab)
	check(not flow.visible, "Setup keeps cooling controls hidden")
	ui._mode.select(1)
	click(ui._action)
	check(not flow.visible and ui._studio.report_visible, "Launch report has no obstructing fan controls")
	click(ui._action)
	check(flow.visible and ui.session.active_cooling_available and is_equal_approx(ui.session.cooling_ratio, 0.15), "Live owned fan exposes action and retains passive reduction")
	check(flow._fan.size.x >= 44 and flow._fan.size.y >= 44 and flow._button.size.y >= 44, "Both cooling targets are large enough")
	check(not flow._button.get_global_rect().intersects(ui._donation_panel.get_global_rect()), "Cooling control does not overlap donation actions")
	ui.session.advance(10)
	ui.session.heat = 92
	ui._refresh()
	await capture("ready")
	var taps: int = ui.session.tap_count
	click(flow._fan)
	check(ui.session.heat == 82 and ui.session.cooling_uses == 1 and ui.session.tap_count == taps, "Clicking room fan cools instead of accelerating stream")
	check(flow._button.disabled and flow._status.text.contains("2"), "UI explains temporary tap lock and cooldown")
	check(main.get_node("StartRoom").cooling_active, "Room shows stronger airflow during active cooling")
	point_click(Vector2(420, 620))
	check(ui.session.tap_count == taps and ui._effects.get_child_count() == 0, "Blocked room taps create neither activity nor fake feedback")
	var space := InputEventKey.new()
	space.pressed = true
	space.physical_keycode = KEY_SPACE
	viewport.push_input(space)
	check(ui.session.tap_count == taps, "Keyboard cannot bypass temporary lock")
	click(flow._button)
	click(flow._fan)
	check(ui.session.heat == 82 and ui.session.cooling_uses == 1 and ui.session.tap_count == taps, "Disabled fan targets absorb input without repeated cooling or taps")
	click(ui._chat_buttons[int(ui.session.chat.active.correct)])
	check(ui.session.chat.correct_answers == 1, "Chat answer remains interactive during cooling")
	click(ui._thanks_button)
	check(ui.session.income.thanked_count == 1, "Thanks remains interactive during cooling")
	await capture("cooling")
	click(ui._action)
	var lock_time: float = ui.session.cooling_lock_remaining
	ui._process(30)
	check(ui.session.state == ui.Session.State.PAUSED and ui.session.cooling_lock_remaining == lock_time and flow._button.disabled, "Pause freezes lock and disables cooling")
	ui._exit_flow._open_confirmation()
	check(not flow.visible, "Exit confirmation covers and hides cooling controls")
	ui._exit_flow.cancel_exit()
	click(ui._action)
	ui._process(2.01)
	point_click(Vector2(420, 620))
	check(ui.session.tap_count == taps + 1 and flow._status.text.is_empty(), "Room taps resume after two real seconds")
	check(not main.get_node("StartRoom").cooling_active, "Extra airflow returns to normal when lock ends")
	ui._process(18)
	check(not flow._button.disabled, "Visible reuse countdown unlocks after twenty real seconds")
	var before: float = ui.session.heat
	click(flow._button)
	check(is_equal_approx(ui.session.heat, before - 10) and ui.session.cooling_uses == 2, "Labeled control invokes same actual cooling action")
	ui.session.finish_early()
	ui._process(0)
	check(not flow.visible, "Finished results hide fan controls")
	click(ui._action)
	click(ui._shop_button)
	await reveal_fan()
	click(ui._shop.rows.desk_fan.button)
	check(not ui.wallet.inventory.has("desk_fan"), "Fan can be sold after stream")
	click(ui._stream_tab)
	click(ui._action)
	click(ui._action)
	check(not flow.visible and not ui.session.active_cooling_available and ui.session.cooling_ratio == 0, "Selling fan removes both passive and active cooling next stream")
	var restored := Wallet.new(path)
	check(not restored.inventory.has("desk_fan") and restored.balance_units == ui.wallet.balance_units, "Purchase, results and sale persist without ephemeral cooling state")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Cooling action UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
