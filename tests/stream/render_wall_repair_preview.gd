extends SceneTree
var viewport: SubViewport
var ui: Control
var checks := 0
var failures := 0
var path := "/tmp/hypster_wall_repair_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/room_repair/wallpaper_tabs_v26"

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
	print("Wall repair UI: %d checks, %d failures" % [checks, failures])
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
	var room: Node = main.get_node("StartRoom")
	var shell: Sprite2D = room.get_node("RoomShell")
	check(not bool(shell.material.get_shader_parameter("walls_repaired")), "Initial room keeps original damaged walls")
	await capture("before")
	click(ui._shop_button)
	for frame in range(2):
		await process_frame
	var row: Dictionary = ui._shop.rows.fresh_wallpaper
	check(not row.panel.visible and ui._shop.rows.thrift_rug.panel.visible, "Default Items category excludes renovation")
	ui._shop._transact("fresh_wallpaper")
	check(not ui.wallet.inventory.has("fresh_wallpaper"), "Hidden repair cannot be purchased from another category")
	click(ui._shop._devices_tab)
	check(ui._shop.rows.ifone_2g.panel.visible and not row.panel.visible, "Devices category excludes renovation")
	click(ui._shop._repair_tab)
	check(row.panel.visible and not ui._shop.rows.thrift_rug.panel.visible and not ui._shop.rows.ifone_2g.panel.visible, "Repair category contains renovation alone")
	check(ui._shop._repair_tab.button_pressed and not ui._shop._items_tab.button_pressed and not ui._shop._devices_tab.button_pressed, "Three categories have exclusive selection")
	check(ui._shop._items_tab.get_global_rect().end.x + 8 <= ui._shop._devices_tab.get_global_rect().position.x and ui._shop._devices_tab.get_global_rect().end.x + 8 <= ui._shop._repair_tab.get_global_rect().position.x and ui._shop._panel.get_global_rect().encloses(ui._shop._repair_tab.get_global_rect()), "Three category targets fit with separate touch areas")
	ui._shop._scroll.ensure_control_visible(row.panel)
	for frame in range(2):
		await process_frame
	check(row.panel.is_visible_in_tree() and row.button.disabled, "Repair requires sufficient money in its own category")
	check(ui.wallet.credit("repair_test_budget", 500000) == OK, "Fund isolated profile")
	ui._shop.refresh_catalog()
	await capture("shop")
	var desk_texture: Texture2D = room.desk.texture
	var hero_position: Vector2 = room.hero.position
	click(row.button)
	check(ui.wallet.inventory.has("fresh_wallpaper") and ui.wallet.balance_units == 250000, "Real purchase debits twenty-five dollars")
	check(bool(shell.material.get_shader_parameter("walls_repaired")) and not room._decor.has("fresh_wallpaper"), "Purchase replaces wall surface without adding a floating room sprite")
	check(row.button.disabled and row.button.text == "ОТРЕМОНТИРОВАНО", "Completed renovation has clear permanent state")
	click(ui._shop._items_tab)
	click(ui._shop._repair_tab)
	check(row.panel.visible and row.button.disabled and row.button.text == "ОТРЕМОНТИРОВАНО", "Switching categories preserves completed repair state")
	check(row.effect.text.contains("БЕЗ ПРОДАЖИ") and row.effect.get_global_rect().end.y < row.button.get_global_rect().position.y, "Permanent purchase is explained before buying without overlapping action")
	check(room.desk.texture == desk_texture and room.hero.position == hero_position, "Room purchase preserves desk and hero placement")
	ui._shop._transact("fresh_wallpaper")
	check(ui.wallet.balance_units == 250000, "Repeated UI calls cannot sell or charge again")
	click(ui._stream_tab)
	await capture("after")
	# Render the shell alone so animated actors and changing HUD text cannot mask regressions.
	var art_view := SubViewport.new()
	art_view.size = Vector2i(540, 540)
	art_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(art_view)
	var art := Sprite2D.new()
	art.texture = shell.texture
	art.position = Vector2(270, 270)
	art.scale = Vector2.ONE * 540.0 / float(shell.texture.get_width())
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.material = shell.material.duplicate()
	art_view.add_child(art)
	art.material.set_shader_parameter("walls_repaired", false)
	await process_frame
	await RenderingServer.frame_post_draw
	var before: Image = art_view.get_texture().get_image()
	art.material.set_shader_parameter("walls_repaired", true)
	await process_frame
	await RenderingServer.frame_post_draw
	var after: Image = art_view.get_texture().get_image()
	var floor_changes := 0
	var window_changes := 0
	var wall_changes := 0
	for y in range(540):
		for x in range(540):
			if before.get_pixel(x, y) != after.get_pixel(x, y):
				if y >= 350:
					floor_changes += 1
				if Rect2i(355, 150, 70, 50).has_point(Vector2i(x, y)):
					window_changes += 1
				if Rect2i(70, 180, 120, 70).has_point(Vector2i(x, y)):
					wall_changes += 1
	check(floor_changes == 0 and window_changes == 0, "Floor and window remain pixel-exact")
	check(wall_changes > 7000, "Cosmetic repair visibly changes wallpaper")
	art_view.queue_free()
	var restored: RefCounted = load("res://src/economy/player_wallet.gd").new(path)
	check(restored.inventory.has("fresh_wallpaper"), "Purchase survives profile reload")
	room.apply_inventory(restored.inventory, ui.progression.config.items, restored.equipped_device)
	check(bool(shell.material.get_shader_parameter("walls_repaired")), "Restored inventory restores wall repair")
	var other: Node = load("res://scenes/room/start_room.tscn").instantiate()
	viewport.add_child(other)
	check(other.get_node("RoomShell").material != shell.material and not bool(other.get_node("RoomShell").material.get_shader_parameter("walls_repaired")), "Different room instance does not inherit another profile's repair")
	other.queue_free()
	room.apply_inventory([], ui.progression.config.items)
	check(not bool(shell.material.get_shader_parameter("walls_repaired")), "Fresh profile retains original room")
	room.apply_inventory(restored.inventory, ui.progression.config.items, restored.equipped_device)
	return true

