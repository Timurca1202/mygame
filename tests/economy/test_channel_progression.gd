extends SceneTree
const Progression = preload("res://src/economy/channel_progression.gd")
const Wallet = preload("res://src/economy/player_wallet.gd")
const Session = preload("res://src/stream/stream_session.gd")
var checks := 0
var failures := 0
var path := "user://progression_test_%d.json" % OS.get_process_id()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func write_payload(payload: Dictionary) -> void:
	var encoded := JSON.stringify(payload)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": encoded, "checksum": encoded.sha256_text()}))
	file.close()

func _initialize() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json"))
	var model := Progression.new(config)
	check(model.organic(0.0) == 3.0, "Organic discovery must start at three")
	check(is_equal_approx(model.organic(100.0), 3.0 + 0.8 * pow(100.0, 0.55)), "Organic formula must match GDD")
	for pair in [[0, 0.2], [99, 0.2], [100, 0.12], [999, 0.12], [1000, 0.08], [10000, 0.06], [100000, 0.045], [1000000, 0.035]]:
		check(is_equal_approx(model.online_ratio(pair[0]), pair[1]), "Online share boundary: %s" % pair[0])
	check(model.audience(0.0, 50.0) == 3.0, "First audience must preserve the approved three viewers")
	check(model.audience(1000.0, 100.0) == 10.0, "Brick 3300 must cap at ten viewers")
	check(model.audience(5.0, 50.0) > 3.0, "New followers must raise the next audience")
	check(model.follower_gain(0.0, 50.0, 900.0) == 3.0, "First stream organic gain must match GDD")
	check(model.follower_gain(100.0, 50.0, 0.0) == 0.0, "Unplayed streams cannot award followers")
	var target := model.target_audience(100.0, 70.0)
	var expected := 100.0 * (0.002 + pow(0.7, 1.5) * 0.088) * 0.5 * pow(minf(1.0, 10.0 / target), 1.5) + model.organic(100.0)
	check(is_equal_approx(model.follower_gain(100.0, 70.0, 900.0), expected), "Growth must include score, duration and cap factor exactly")
	check(is_equal_approx(model.follower_gain(100.0, 70.0, 3600.0) - model.organic(100.0), 2.0 * (expected - model.organic(100.0))), "Duration factor must use square root, not linear scaling")
	check(model.follower_gain(10.0, 90.0, 900.0) > model.follower_gain(10.0, 10.0, 900.0), "Better performance must improve uncapped growth")
	var stream_config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	var chat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json"))
	var donors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/donations.json"))
	var session := Session.new(stream_config, chat, donors.donors)
	session.start(900.0)
	session.advance(5.0)
	var quiet := model.performance(session, [])
	check(is_equal_approx(model.packaging(100.0, 60.0), 80.0), "Title and preview contribute equally to packaging")
	check(is_equal_approx(model.packaging(-20.0, 120.0), 50.0), "Individual packaging scores must stay bounded")
	check(is_equal_approx(model.performance(session, [], 80.0) - quiet, 16.0), "Packaging contributes its GDD weight of 20 percent to PS")
	check(is_equal_approx(model.performance(session, [], 500.0) - quiet, 20.0), "Packaging cannot contribute more than twenty PS points")
	session.answer_chat(session.chat.event_serial, int(session.chat.active.correct))
	session.tap()
	check(model.performance(session, []) > quiet, "Correct answers and taps must contribute to activity score")
	check(is_equal_approx(model.performance(session, ["thrift_rug"]) - model.performance(session, []), 1.0), "One Vibe point must add one PS point with the current decor scale")
	check(model.vibe(["thrift_rug", "thrift_rug"]) == 1, "Inventory duplicates must not stack item bonuses")
	stream_config.economy.viewers = 10.0
	var larger := Session.new(stream_config, chat, donors.donors)
	larger.start(60.0)
	larger.advance(30.0)
	check(larger.income.base_units == 3333, "Fractional viewer-hours must feed actual income")

	# Genuine v1 fixture, preserving money, duplicate protection and original bytes on read.
	write_payload({"version": 1, "balance_units": 20000, "credited_sessions": ["legacy_stream"]})
	var legacy_bytes := FileAccess.get_file_as_string(path)
	var wallet := Wallet.new(path)
	check(wallet.load_error == OK and wallet.balance_units == 20000, "Migration must retain the existing wallet")
	check(wallet.followers == 0 and wallet.inventory.is_empty(), "Legacy profiles must receive neutral new fields")
	check(FileAccess.get_file_as_string(path) == legacy_bytes, "Reading v1 must not rewrite the author profile")
	check(wallet.credit("legacy_stream", 1000) == OK and wallet.balance_units == 20000, "Migration must preserve duplicate protection")
	check(model.buy(wallet, "unknown") == ERR_INVALID_PARAMETER, "Unknown catalog entries must be rejected")
	check(model.buy(wallet, "thrift_rug") == OK, "First room item must be purchasable with earned money")
	check(wallet.balance_units == 7500 and wallet.inventory == ["thrift_rug"], "Price and ownership must change together")
	check(model.buy(wallet, "thrift_rug") == ERR_ALREADY_EXISTS and wallet.balance_units == 7500, "Double purchase cannot charge twice")
	var restored := Wallet.new(path)
	check(restored.balance_units == 7500 and restored.inventory == ["thrift_rug"], "Purchased room item must survive reload")
	check(restored.settle_stream("growth_stream", 5000, 3.75, 40.5) == OK, "Money and follower growth must settle atomically")
	var after := Wallet.new(path)
	check(after.balance_units == 12500 and after.followers == 3.75 and after.completed_streams == 1 and after.last_score == 40.5, "Complete stream result must survive reload without losing fractional followers")
	check(after.settle_stream("growth_stream", 5000, 3.75, 40.5) == OK and after.followers == 3.75 and after.balance_units == 12500, "Repeated settlement cannot duplicate money or followers")
	check(model.sell(after, "thrift_rug") == OK and after.balance_units == 18750 and after.inventory.is_empty(), "Sale must return exactly half the price and remove the rug")
	check(model.sell(after, "thrift_rug") == ERR_INVALID_PARAMETER and after.balance_units == 18750, "Unowned items cannot generate refunds")
	check(after.buy("free_item", 0) == ERR_INVALID_PARAMETER, "Invalid purchase prices cannot create ownership")
	var poor_path := path + ".poor"
	var poor := Wallet.new(poor_path)
	check(model.buy(poor, "thrift_rug") == ERR_UNAVAILABLE and poor.inventory.is_empty() and poor.balance_units == 0, "Insufficient funds cannot create items or negative balance")
	check(not FileAccess.file_exists(poor_path), "Rejected purchase must not write a profile")
	# Block the temporary file to simulate an actual disk failure, not a mocked service.
	var before_bytes := FileAccess.get_file_as_string(path)
	DirAccess.make_dir_absolute(path + ".tmp")
	check(model.buy(after, "thrift_rug") != OK and after.inventory.is_empty() and after.balance_units == 18750, "Failed purchase write must retain money and ownership")
	check(after.settle_stream("retry_stream", 1000, 4.25, 50.0) != OK and after.followers == 3.75 and after.balance_units == 18750, "Failed settlement must not award either resource in memory")
	check(FileAccess.get_file_as_string(path) == before_bytes, "Failed transactions must preserve original profile bytes")
	DirAccess.remove_absolute(path + ".tmp")
	check(after.settle_stream("retry_stream", 1000, 4.25, 50.0) == OK and after.followers == 8.0 and after.balance_units == 19750, "Retry must award a failed stream exactly once")
	check(after.settle_stream("bad_score", 1000, 3.0, 101.0) == ERR_INVALID_PARAMETER, "Out-of-range scores cannot enter saves")
	check(after.settle_stream("bad_gain", 1000, -3.0, 50.0) == ERR_INVALID_PARAMETER, "Negative growth must fail validation")
	check(after.settle_stream("nan_gain", 1000, NAN, 50.0) == ERR_INVALID_PARAMETER, "Non-finite growth must fail validation")
	# Current-schema validation and recovery include owned items and followers.
	check(model.buy(after, "thrift_rug") == OK, "Successful purchase after a failed write must remain possible")
	DirAccess.make_dir_absolute(path + ".tmp")
	var before_sale: int = after.balance_units
	check(model.sell(after, "thrift_rug") != OK and after.balance_units == before_sale and after.inventory == ["thrift_rug"], "Failed sale write must retain both the item and original balance")
	DirAccess.remove_absolute(path + ".tmp")
	check(after.settle_stream("backup_owned", 1000, 1.25, 51.0) == OK, "Create backup containing purchased item")
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("broken")
	broken.close()
	var recovered := Wallet.new(path)
	check(recovered.recovered_from_backup and recovered.inventory == ["thrift_rug"] and recovered.followers == 8.0, "Backup recovery must preserve ownership and fractional audience state")
	for suffix in ["", ".bak", ".tmp", ".poor"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Channel progression and purchases: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
