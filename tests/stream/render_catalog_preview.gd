extends SceneTree
const Wallet = preload("res://src/economy/player_wallet.gd")
var viewport: SubViewport
var main: Node2D
var ui: Control
var failures := 0
var checks := 0
var path := "user://catalog_ui_%d.json" % OS.get_process_id()
const OUTPUT := "res://source_art/prototypes/stream"

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
	for frame in range(2):
		await process_frame
		await RenderingServer.frame_post_draw
	check(viewport.get_texture().get_image().save_png(OUTPUT + "/catalog_" + name + "_v07.png") == OK, "Screenshot: " + name)
	if ui._shop.visible:
		check(ui._shop._description.get_global_rect().end.y <= ui._shop._effect.get_global_rect().position.y, "Description must not overlap effect")
		check(ui._shop._panel.get_global_rect().end.y <= 690.0, "Catalog must fit above the bottom UI")
		check(ui._shop._previous.size.x >= 44 and ui._shop._next.size.x >= 44, "Navigation must remain large enough for touch")

func mount() -> void:
	main = load("res://scenes/app/main.tscn").instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = path
	viewport.add_child(main)
	ui.set_process(false)

func run() -> void:
	var budget := Wallet.new(path)
	check(budget.credit("isolated_catalog_budget", 10000000) == OK, "Create isolated budget without touching author profile")
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	mount()
	await process_frame
	await capture("before")
	click(ui._shop_button.get_global_rect().get_center())
	check(ui._shop._item.id == "thrift_rug", "Catalog must preserve the existing first item")
	click(ui._shop._action.get_global_rect().get_center())
	check(ui.wallet.inventory == ["thrift_rug"], "Existing rug must still be purchasable")
	click(ui._shop._next.get_global_rect().get_center())
	check(ui._shop._item.id == "old_cactus" and not ui._shop._action.disabled, "Navigation must select cactus and reset transaction lock")
	await capture("cactus_card")
	click(ui._shop._action.get_global_rect().get_center())
	check(ui.wallet.inventory.has("old_cactus") and ui.wallet.balance_units == 9937500, "Cactus click must charge $5 once")
	click(ui._shop._action.get_global_rect().get_center())
	check(ui.wallet.inventory.has("old_cactus") and ui.wallet.balance_units == 9937500, "Double click cannot sell the purchased cactus")
	click(ui._shop._next.get_global_rect().get_center())
	check(ui._shop._item.id == "desk_fan" and ui._shop._effect.text.contains("15%"), "Fan card must describe the real cooling effect")
	await capture("fan_card")
	click(ui._shop._action.get_global_rect().get_center())
	check(ui.wallet.balance_units == 9137500 and ui.wallet.inventory.size() == 3, "All three item prices must be charged correctly")
	click(ui._shop._next.get_global_rect().get_center())
	check(ui._shop._item.id == "thrift_rug", "Next must wrap from last item to first")
	click(ui._shop._previous.get_global_rect().get_center())
	check(ui._shop._item.id == "desk_fan", "Previous must wrap from first item to last")
	ui._shop.hide()
	check(main.get_node("StartRoom")._decor.size() == 3, "All purchased items must coexist in the real room")
	for id in ["old_cactus", "desk_fan"]:
		var sprite: Sprite2D = main.get_node("StartRoom")._decor[id]
		check(sprite.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "New item must have actual transparency")
		check(sprite.region_rect.size.y * sprite.scale.y <= 54.1, "New item must use its data-defined room scale")
	await capture("room")
	var restored := Wallet.new(path)
	check(restored.inventory.size() == 3 and restored.balance_units == 9137500, "Multi-item purchase must survive profile reload")
	main.queue_free()
	await process_frame
	mount()
	await process_frame
	check(main.get_node("StartRoom")._decor.size() == 3, "Recreated main scene must restore every purchased sprite")
	check(ui._channel_label.text.contains("15%"), "Equipped fan must be visible in the room status")
	await capture("loaded")
	click(ui._action.get_global_rect().get_center())
	check(is_equal_approx(ui.session.cooling_ratio, 0.15), "Start button must apply cooling from real owned equipment")
	ui.session.advance(10.0)
	check(is_equal_approx(ui.session.heat, 100.0 / 1200.0 * 20.0 * 0.85), "UI session must actually heat more slowly")
	await capture("live_cooled")
	# Inspect airflow over time independently of breathing, dust and UI effects.
	var room: Node2D = main.get_node("StartRoom")
	room.set_process(false)
	room.clock = 0.0
	DirAccess.make_dir_recursive_absolute("/tmp/hypster_fan_frames")
	var first_air: PackedByteArray
	for frame in range(12):
		room.clock = frame / 6.0
		room._activity.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		var air := shot.get_region(Rect2i(267, 465, 31, 28)).get_data()
		if frame == 0:
			first_air = air
		if frame == 3:
			check(first_air != air, "Owned fan airflow must visibly animate")
		var detail := shot.get_region(Rect2i(224, 454, 82, 79))
		detail.resize(328, 316, Image.INTERPOLATE_NEAREST)
		detail.save_png("/tmp/hypster_fan_frames/frame_%02d.png" % frame)
	click(ui._action.get_global_rect().get_center())
	check(ui.session.state == ui.Session.State.PAUSED and main.get_node("StartRoom").frozen, "Pause must freeze fan airflow together with the room")
	var held_clock: float = room.clock
	room._process(1.0)
	check(room.clock == held_clock, "Paused airflow clock cannot advance")
	room.set_process(true)
	click(ui._action.get_global_rect().get_center())
	ui.session.advance(60.0)
	ui._settle_income()
	ui._refresh()
	var before_sale: int = ui.wallet.balance_units
	click(ui._shop_button.get_global_rect().get_center())
	ui._shop.select_item(2)
	click(ui._shop._action.get_global_rect().get_center())
	await process_frame
	check(ui.wallet.balance_units == before_sale + 400000, "Selling fan via UI must refund $40")
	check(ui.wallet.inventory.has("old_cactus") and ui.wallet.inventory.has("thrift_rug") and not ui.wallet.inventory.has("desk_fan"), "Selling one item must preserve other room purchases")
	check(not main.get_node("StartRoom")._decor.has("desk_fan") and main.get_node("StartRoom")._decor.size() == 2, "Sold fan sprite must disappear without removing decor")
	ui._shop.hide()
	await capture("fan_sold")
	click(ui._action.get_global_rect().get_center())
	click(ui._action.get_global_rect().get_center())
	check(ui.session.cooling_ratio == 0.0, "Next stream after sale must lose the cooling bonus")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Catalog UI integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
