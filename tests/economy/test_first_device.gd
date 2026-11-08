extends SceneTree
const Model = preload("res://src/economy/channel_progression.gd")
const Wallet = preload("res://src/economy/player_wallet.gd")
const Session = preload("res://src/stream/stream_session.gd")
var checks := 0
var failures := 0
var path := "user://device_test_%d.json" % OS.get_process_id()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var parameters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json"))
	var model := Model.new(parameters)
	var payload := JSON.stringify({"version": 3, "balance_units": 10000000, "credited_sessions": ["old_reward"], "followers": 200.5, "completed_streams": 2, "last_score": 72.5, "inventory": ["thrift_rug", "desk_fan"], "recent_titles": ["Мой эфир"]})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
	file.close()
	var original := FileAccess.get_file_as_string(path)
	var wallet := Wallet.new(path)
	check(wallet.load_error == OK and wallet.equipped_device.is_empty(), "V3 migration selects starter without changing progress")
	check(wallet.balance_units == 10000000 and wallet.recent_titles == ["Мой эфир"] and wallet.followers == 200.5, "Migration retains money, audience and title history")
	check(FileAccess.get_file_as_string(path) == original, "Reading an older profile cannot rewrite it")
	check(model.selected_device(wallet).capacity_seconds == 1200 and model.owned_devices(wallet).size() == 1, "Starter is available without purchase")
	check(model.equip(wallet, "ifone_2g") == ERR_DOES_NOT_EXIST, "An unowned phone cannot be equipped")
	check(model.equip(wallet, "thrift_rug") == ERR_INVALID_PARAMETER, "Decor cannot occupy device slot")
	check(model.buy(wallet, "ifone_2g") == OK, "P2 purchase succeeds")
	check(wallet.balance_units == 9400000 and wallet.equipped_device == "ifone_2g", "Purchase atomically charges $60 and equips P2")
	check(model.buy(wallet, "ifone_2g") == ERR_ALREADY_EXISTS and wallet.balance_units == 9400000, "Repeated purchase cannot charge twice")
	var restored := Wallet.new(path)
	check(restored.equipped_device == "ifone_2g" and restored.inventory.size() == 3, "Equipped phone survives reload alongside decor")
	check(restored.credit("old_reward", 999) == OK and restored.balance_units == 9400000, "Migration preserves income deduplication")
	var device := model.selected_device(restored)
	check(device.viewer_cap == 25 and device.capacity_seconds == 1800 and is_equal_approx(device.quality, 0.30), "P2 matches GDD cap, duration and quality")
	check(model.owned_devices(restored).size() == 2, "Both starter and purchased phone remain available")
	check(model.equip(restored, "") == OK and restored.inventory.has("ifone_2g"), "Selecting starter keeps P2 as spare")
	check(Wallet.new(path).equipped_device.is_empty(), "Switching back to starter persists")
	check(model.equip(restored, "ifone_2g") == OK, "Spare phone can be selected again")
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	var chat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json"))
	var p1 := Session.new(config, chat)
	check(p1.start(1200) and not Session.new(config).start(1800), "Starter accepts twenty minutes and rejects thirty")
	var p2_config := config.duplicate(true)
	p2_config.device_capacity_seconds = device.capacity_seconds
	p2_config["viewer_cap"] = device.viewer_cap
	p2_config["device_quality"] = device.quality
	var p2 := Session.new(p2_config, chat)
	check(p2.start(1800) and not Session.new(p2_config).start(1801), "P2 accepts thirty minutes and rejects excess duration")
	p1.advance(30)
	p2.advance(30)
	check(is_equal_approx(p2.heat / p1.heat, 2.0 / 3.0), "Larger device capacity slows actual heating at equal speed")
	check(is_equal_approx(model.performance(p2, []) - model.performance(p1, []), 2.5), "P2 quality adds 2.5 PS points using existing equipment weight")
	p1.advance(2000)
	p2.advance(2000)
	check(p1.end_reason == Session.EndReason.COMPLETED and p1.elapsed_game == 1200, "Twenty-minute base-speed stream finishes at exact heat boundary")
	check(p2.end_reason == Session.EndReason.COMPLETED and p2.elapsed_game == 1800, "Thirty-minute base-speed stream finishes normally")
	check(model.follower_gain(200, 70, 1800, 25) > model.follower_gain(200, 70, 1800, 10), "P2 cap relieves growth suppression without changing formula")
	var blocked := Wallet.new("user://missing_device_dir_%d/profile.json" % OS.get_process_id())
	blocked.balance_units = 1000000
	check(model.buy(blocked, "ifone_2g") != OK and blocked.balance_units == 1000000 and blocked.equipped_device.is_empty() and blocked.inventory.is_empty(), "Failed purchase write cannot debit, grant or equip")
	blocked.inventory.append("ifone_2g")
	check(model.equip(blocked, "ifone_2g") != OK and blocked.equipped_device.is_empty(), "Failed equipment write leaves selection unchanged")
	blocked.equipped_device = "ifone_2g"
	check(model.sell(blocked, "ifone_2g") != OK and blocked.inventory.has("ifone_2g") and blocked.equipped_device == "ifone_2g", "Failed sale cannot remove device or change selection")
	check(model.sell(restored, "ifone_2g") == OK and restored.balance_units == 9700000, "Sale refunds exactly $30")
	check(restored.equipped_device.is_empty() and restored.inventory == ["thrift_rug", "desk_fan"], "Selling selected phone restores starter and retains unrelated items")
	check(Wallet.new(path).equipped_device.is_empty() and model.selected_device(restored).viewer_cap == 10, "Sale fallback persists and restores starter cap")
	check(model.sell(restored, "ifone_2g") == ERR_INVALID_PARAMETER and restored.balance_units == 9700000, "Duplicate sale cannot grant extra money")
	var poor := Wallet.new("user://unwritten_device_%d.json" % OS.get_process_id())
	check(model.buy(poor, "ifone_2g") == ERR_UNAVAILABLE and poor.inventory.is_empty(), "Insufficient funds cannot grant a device")
	# New source patch must preserve every pixel outside the removed phone region.
	var before := Image.new()
	before.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/rooms/e1/desk_with_props_v01.png"))
	var after := Image.new()
	after.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/art/rooms/e1/desk_without_phone_v01.png"))
	for rect in [Rect2i(0, 0, 1280, 388), Rect2i(0, 504, 1280, 776), Rect2i(0, 388, 397, 116), Rect2i(462, 388, 818, 116)]:
		check(before.get_region(rect).get_data() == after.get_region(rect).get_data(), "Furniture and props outside phone patch remain pixel-identical")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("First device progression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
