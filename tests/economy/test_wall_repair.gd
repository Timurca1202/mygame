extends SceneTree
const Wallet = preload("res://src/economy/player_wallet.gd")
const Progression = preload("res://src/economy/channel_progression.gd")
var checks := 0
var failures := 0
var path := "/tmp/hypster_repair_logic_%d.json" % OS.get_process_id()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var model := Progression.new(JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json")))
	var wallet := Wallet.new(path)
	check(model.buy(wallet, "fresh_wallpaper") == ERR_UNAVAILABLE and wallet.inventory.is_empty(), "Insufficient budget cannot repair walls")
	check(wallet.credit("repair_budget", 300000) == OK, "Prepare isolated budget")
	DirAccess.make_dir_absolute(path + ".tmp")
	check(model.buy(wallet, "fresh_wallpaper") != OK and wallet.balance_units == 300000 and wallet.inventory.is_empty(), "Failed write leaves walls and money unchanged")
	DirAccess.remove_absolute(path + ".tmp")
	check(model.buy(wallet, "fresh_wallpaper") == OK and wallet.balance_units == 50000, "Repair charges exactly twenty-five dollars")
	check(model.buy(wallet, "fresh_wallpaper") == ERR_ALREADY_EXISTS and wallet.balance_units == 50000, "Duplicate repair cannot charge twice")
	var restored := Wallet.new(path)
	check(restored.inventory == ["fresh_wallpaper"] and restored.balance_units == 50000, "Repair ownership persists with existing profile format")
	check(model.vibe(restored.inventory) == 2 and model.vibe(["fresh_wallpaper", "fresh_wallpaper"]) == 2, "Repair contributes two Vibe without stacking")
	check(model.sell(restored, "fresh_wallpaper") == ERR_UNAVAILABLE and restored.balance_units == 50000 and restored.inventory == ["fresh_wallpaper"], "Completed renovation cannot be sold for a refund")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Wall repair economy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
