extends SceneTree
const Wallet = preload("res://src/economy/player_wallet.gd")
var viewport: SubViewport
var main: Node2D
var ui: Control
var checks := 0
var failures := 0
var path := "user://device_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream/device_v14"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
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

func capture(name: String) -> void:
	ui._refresh()
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUTPUT + "/" + name + ".png") == OK, "Capture " + name)

func mount() -> void:
	main = load("res://scenes/app/main.tscn").instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = path
	viewport.add_child(main)
	ui.set_process(false)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var budget := Wallet.new(path)
	budget.followers = 200
	check(budget.credit("isolated_device_budget", 10000000) == OK, "Use isolated profile with audience large enough to expose device caps")
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	mount()
	await process_frame
	check(ui.session.viewers == 10 and ui._mode.is_item_disabled(3), "Starter is capped at ten viewers and locks thirty minutes")
	click(ui._shop_button.get_global_rect().get_center())
	await capture("shop_items")
	check(not ui._shop.rows["ifone_2g"].panel.visible and ui._shop.rows["desk_fan"].panel.visible, "Default items tab excludes stream devices")
	ui._shop._transact("ifone_2g")
	check(ui.wallet.balance_units == 10000000 and not ui.wallet.inventory.has("ifone_2g"), "Hidden phone cannot be bought through an inactive row")
	click(ui._shop._devices_tab.get_global_rect().get_center())
	await capture("shop_available")
	check(ui._shop.rows["ifone_2g"].panel.visible and not ui._shop.rows["thrift_rug"].panel.visible, "Devices tab shows phone separately from room items")
	check(ui._shop._devices_tab.button_pressed and not ui._shop._items_tab.button_pressed, "Active category has exclusive selected state")
	var row: Dictionary = ui._shop.rows["ifone_2g"]
	check(row.price.text == "$60.00" and row.effect.text.contains("25"), "Shop explains actual cost and device comparison")
	check(row.button.get_global_rect().end.y < ui._shop._scroll.get_global_rect().end.y, "Phone purchase is visible without scrolling")
	click(row.button.get_global_rect().get_center())
	check(ui.wallet.balance_units == 9400000 and ui.wallet.equipped_device == "ifone_2g", "Real buy button charges once and selects device")
	click(ui._shop._items_tab.get_global_rect().get_center())
	click(ui._shop._devices_tab.get_global_rect().get_center())
	for frame in range(2):
		await process_frame
	click(row.button.get_global_rect().get_center())
	check(ui.wallet.balance_units == 9400000 and ui.wallet.inventory.has("ifone_2g"), "Double click cannot immediately sell new device")
	await capture("shop_owned")
	check(ui.session.viewers == 25 and not ui._mode.is_item_disabled(3), "Selected phone updates actual audience cap and duration choices")
	click(ui._stream_tab.get_global_rect().get_center())
	await capture("room_upgraded")
	var room: Node2D = main.get_node("StartRoom")
	check(room._decor.has("ifone_2g") and room.desk.texture.resource_path.ends_with("desk_without_phone_v01.png"), "Room replaces embedded starter phone with selected separate P2 sprite")
	check(not room._decor["ifone_2g"].flip_h, "Room phone uses corrected horizontal orientation")
	check(room._decor["ifone_2g"].get_parent() == room.get_node("Furniture"), "New phone is layered above desk and behind hero")
	click(ui._studio._edit_button.get_global_rect().get_center())
	await capture("device_selection")
	var selector: OptionButton = ui._studio._device_selector
	check(selector.item_count == 2 and selector.selected == 1, "Preparation offers both owned devices and restores current selection")
	ui._mode.select(3)
	selector.select(0)
	selector.item_selected.emit(0)
	check(ui.wallet.equipped_device.is_empty() and ui.wallet.inventory.has("ifone_2g"), "Selecting starter retains purchased device as spare")
	check(ui._mode.selected == 2 and ui._mode.is_item_disabled(3), "Switch to weaker device clamps unavailable duration to twenty minutes")
	check(ui.session.viewers == 10 and not room._decor.has("ifone_2g") and room.desk.texture.resource_path.ends_with("desk_with_props_v01.png"), "Starter selection restores both graphics and cap")
	selector.select(1)
	selector.item_selected.emit(1)
	ui._mode.select(3)
	ui._studio.close_form()
	click(ui._action.get_global_rect().get_center())
	check(ui.session.duration == 1800 and ui.session.viewer_cap == 25 and is_equal_approx(ui.session.device_quality, 0.30), "Launch snapshots chosen device into actual simulation")
	check(ui._studio.report_visible and ui.session.viewers == 25, "Title multiplier still respects selected device cap")
	click(ui._action.get_global_rect().get_center())
	ui._shop.open_shop()
	check(not ui._shop.visible, "Phone shop cannot open while live")
	selector.item_selected.emit(0)
	check(ui.wallet.equipped_device == "ifone_2g", "Hidden selection signal cannot change device during live stream")
	ui.session.advance(10)
	ui._refresh()
	check(is_equal_approx(ui.session.heat, 100.0 / 1800.0 * 20.0), "Actual UI session uses new phone heating capacity")
	await capture("live")
	ui.session.advance(1000)
	ui._settle_income()
	check(ui.session.end_reason == ui.Session.EndReason.COMPLETED and ui.session.elapsed_game == 1800, "Thirty-minute stream finishes normally without an early overheat")
	var expected_gain: float = ui.progression.follower_gain(200, ui.wallet.last_score, 1800, 25)
	check(is_equal_approx(ui.wallet.followers, 200 + expected_gain), "Settlement uses selected cap for real follower gain")
	var saved := Wallet.new(path)
	check(saved.equipped_device == "ifone_2g" and saved.last_score == ui.wallet.last_score, "Chosen device and earned progress survive reload")
	main.queue_free()
	await process_frame
	mount()
	await process_frame
	check(ui.wallet.equipped_device == "ifone_2g" and ui.session.viewers == 25 and main.get_node("StartRoom")._decor.has("ifone_2g"), "Fresh scene restores device stats and room art together")
	click(ui._shop_button.get_global_rect().get_center())
	click(ui._shop._devices_tab.get_global_rect().get_center())
	for frame in range(2):
		await process_frame
	var balance_before_sale: int = ui.wallet.balance_units
	click(ui._shop.rows["ifone_2g"].button.get_global_rect().get_center())
	check(ui.wallet.balance_units == balance_before_sale + 300000 and ui.wallet.equipped_device.is_empty(), "Sale refunds thirty dollars and selects starter atomically")
	check(not ui.wallet.inventory.has("ifone_2g") and ui.session.viewer_cap == 10 and ui._mode.is_item_disabled(3), "Sale removes device stats and locks long streams")
	click(ui._stream_tab.get_global_rect().get_center())
	await capture("after_sale")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Device UI integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
