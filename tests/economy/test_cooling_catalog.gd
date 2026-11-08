extends SceneTree
const Model = preload("res://src/economy/channel_progression.gd")
const Session = preload("res://src/stream/stream_session.gd")
const Wallet = preload("res://src/economy/player_wallet.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var parameters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json"))
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	var model := Model.new(parameters)
	check(model.item("old_cactus").price_units == 50000, "Cactus must use catalog price")
	check(model.item("desk_fan").price_units == 800000, "Fan price must match GDD $80")
	check(model.cooling([]) == 0.0, "Empty room must not gain cooling")
	check(model.cooling(["old_cactus", "thrift_rug"]) == 0.0, "Decor cannot cool the phone")
	check(is_equal_approx(model.cooling(["desk_fan"]), 0.15), "Fan must reduce heat by fifteen percent")
	check(is_equal_approx(model.cooling(["desk_fan", "desk_fan"]), 0.15), "Duplicate inventory cannot stack cooling")
	check(model.vibe(["old_cactus", "thrift_rug", "desk_fan"]) == 2, "Fan must not invent decor points")
	var plain := Session.new(config)
	var cooled_config := config.duplicate(true)
	cooled_config.cooling_ratio = model.cooling(["desk_fan"])
	var cooled := Session.new(cooled_config)
	plain.start(900.0)
	cooled.start(900.0)
	plain.advance(30.0)
	cooled.advance(30.0)
	check(is_equal_approx(cooled.heat, plain.heat * 0.85), "Actual simulation heat must fall by exactly fifteen percent")
	check(cooled.elapsed_game == plain.elapsed_game and cooled.elapsed_real == plain.elapsed_real and cooled.speed == plain.speed, "Cooling cannot alter time or stream speed")
	check(cooled.income.total_units() == plain.income.total_units(), "Cooling cannot multiply income at equal viewer-hours")
	var held_heat: float = cooled.heat
	cooled.pause()
	cooled.advance(120.0)
	check(cooled.heat == held_heat, "Cooling must not run timers during pause")
	cooled.resume()
	cooled.advance(1.0)
	check(cooled.heat > held_heat, "Fan slows heating; it does not actively erase existing heat")
	var limited := config.duplicate(true)
	limited.cooling_ratio = 5.0
	check(is_equal_approx(Session.new(limited).cooling_ratio, 0.6), "Cooling must respect the configured GDD maximum")
	limited.cooling_ratio = -1.0
	check(Session.new(limited).cooling_ratio == 0.0, "Negative cooling must be rejected by clamping")
	# Passive cooling extends the same forced stream; it no longer guarantees a safe finish.
	var normal := Session.new(config)
	var ventilated := Session.new(cooled_config)
	normal.start(900.0)
	ventilated.start(900.0)
	for step in range(600):
		if normal.state == Session.State.LIVE:
			normal.tap()
			normal.advance(1.0)
		if ventilated.state == Session.State.LIVE:
			ventilated.tap()
			ventilated.advance(1.0)
	check(normal.end_reason == Session.EndReason.OVERHEATED, "Uncooled sustained tapping must retain the existing overheat behavior")
	check(ventilated.elapsed_game > normal.elapsed_game, "Passive fan must still extend the same forced stream")
	check(ventilated.end_reason == Session.EndReason.OVERHEATED and ventilated.heat == 100.0, "Stronger heat requires active cooling rather than passive immunity during continuous tapping")
	# A real multi-item profile, with sales preserving all unrelated purchases.
	var path := "user://catalog_test_%d.json" % OS.get_process_id()
	var wallet := Wallet.new(path)
	check(wallet.credit("test_budget", 10000000) == OK, "Create isolated catalog test budget")
	check(model.buy(wallet, "old_cactus") == OK and model.buy(wallet, "desk_fan") == OK, "Both new items must be purchasable")
	check(wallet.balance_units == 9150000, "Both prices must be debited exactly once")
	var restored := Wallet.new(path)
	check(restored.inventory.has("old_cactus") and restored.inventory.has("desk_fan"), "All item ownership must survive reload")
	check(is_equal_approx(model.cooling(restored.inventory), 0.15) and model.vibe(restored.inventory) == 1, "Restored inventory must restore actual effects")
	check(model.buy(restored, "desk_fan") == ERR_ALREADY_EXISTS and restored.balance_units == 9150000, "Fan cannot be charged twice")
	check(model.sell(restored, "desk_fan") == OK and restored.balance_units == 9550000, "Fan sale must return $40")
	check(restored.inventory == ["old_cactus"] and model.cooling(restored.inventory) == 0.0, "Selling fan must remove cooling while preserving plant")
	check(model.sell(restored, "desk_fan") == ERR_INVALID_PARAMETER, "Sold fan cannot produce a second refund")
	check(model.sell(restored, "old_cactus") == OK and restored.balance_units == 9575000, "Cactus sale must return $2.50")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Cooling and catalog: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
