extends SceneTree
const Wallet = preload("res://src/economy/player_wallet.gd")
var viewport: SubViewport
var ui: Control
var main: Node2D
var failures := 0
var checks := 0
var path := "user://progression_ui_%d.json" % OS.get_process_id()
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
	check(viewport.get_texture().get_image().save_png(OUTPUT + "/" + name + "_v07.png") == OK, "Screenshot: " + name)

func mount() -> void:
	main = load("res://scenes/app/main.tscn").instantiate()
	ui = main.get_node("Interface/StreamPrototype")
	ui.wallet_path = path
	viewport.add_child(main)
	ui.set_process(false)

func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(540, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	mount()
	await process_frame
	check(ui.wallet.balance_units == 0 and ui.wallet.followers == 0, "Fresh profile starts without money or followers")
	check(main.get_node("StartRoom")._decor.is_empty(), "An unpurchased item must not appear in the room")
	click(ui._shop_button.get_global_rect().get_center())
	check(ui._shop.visible and ui._shop._action.disabled, "Shop opens but cannot spend unavailable money")
	await capture("progression_shop_locked")
	ui._shop.hide()
	ui._mode.select(1)
	click(ui._action.get_global_rect().get_center())
	check(not ui._shop_button.visible and ui.session.viewers == 3.0, "First live stream starts with three viewers and no shopping")
	ui._shop.open_shop()
	check(not ui._shop.visible, "Shop cannot open during a live stream")
	# Play a regular first stream with answers and thanks, using real domain actions.
	for second in range(500):
		ui.session.advance(1.0)
		if ui.session.state == ui.Session.State.FINISHED:
			break
		if not ui.session.chat.active.is_empty():
			var active: Dictionary = ui.session.chat.active
			ui.session.answer_chat(ui.session.chat.event_serial, int(active.get("correct", 0)))
		if not ui.session.income.donation.is_empty():
			ui.session.thank_donation(ui.session.income.donation_serial)
	ui._settle_income()
	ui._refresh()
	check(ui.wallet.followers == 3.0 and ui.wallet.completed_streams == 1, "First result must save the three organic followers")
	check(ui.wallet.balance_units >= 12500, "One regular stream must fund the first improvement")
	await capture("progression_first_result")
	var earned: int = ui.wallet.balance_units
	ui._settle_income(true)
	check(ui.wallet.balance_units == earned and ui.wallet.followers == 3.0, "Reopening results cannot duplicate income or growth")
	click(ui._shop_button.get_global_rect().get_center())
	check(ui._shop.visible and not ui._shop._action.disabled, "Shop must unlock purchase after a funded stream")
	await capture("progression_shop_available")
	click(ui._shop._action.get_global_rect().get_center())
	check(ui.wallet.inventory == ["thrift_rug"] and ui.wallet.balance_units == earned - 12500, "Buy button must charge once and equip the item")
	check(ui._shop._action.disabled, "Purchase button must block an accidental double click")
	click(ui._shop._action.get_global_rect().get_center())
	check(ui.wallet.inventory == ["thrift_rug"] and ui.wallet.balance_units == earned - 12500, "Double clicking must not sell the new rug")
	check(main.get_node("StartRoom")._decor.has("thrift_rug"), "Purchased rug must appear in the actual room")
	await capture("progression_purchase_receipt")
	ui._shop.hide()
	await capture("progression_room_upgraded")
	var restored := Wallet.new(path)
	check(restored.inventory == ["thrift_rug"] and restored.balance_units == earned - 12500 and restored.followers == 3.0, "Reload must retain money, followers and equipped room item together")
	main.queue_free()
	await process_frame
	mount()
	await process_frame
	check(main.get_node("StartRoom")._decor.has("thrift_rug"), "A recreated main scene must restore the purchased room")
	check(ui.session.viewers > 3.0 and ui.session.viewers <= 10.0, "Next stream must use the grown audience within the device cap")
	await capture("progression_reloaded")
	click(ui._shop_button.get_global_rect().get_center())
	click(ui._shop._action.get_global_rect().get_center())
	await process_frame
	check(ui.wallet.inventory.is_empty() and ui.wallet.balance_units == earned - 6250, "Sale through UI must refund exactly half")
	check(not main.get_node("StartRoom")._decor.has("thrift_rug"), "Sold rug must disappear from the room")
	ui._shop.hide()
	# Finish a second short stream and check growth plus duplicate protection across runs.
	click(ui._action.get_global_rect().get_center())
	ui.session.advance(60.0)
	ui._settle_income()
	ui._refresh()
	check(ui.wallet.completed_streams == 2 and ui.wallet.followers > 6.0, "A second stream must grow from the saved subscriber count")
	var final_followers: float = ui.wallet.followers
	ui._settle_income(true)
	check(ui.wallet.followers == final_followers, "Repeated second result must not duplicate followers")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Progression UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
