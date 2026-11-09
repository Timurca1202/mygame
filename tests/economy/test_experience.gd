extends SceneTree
const Wallet = preload("res://src/economy/player_wallet.gd")
const Progression = preload("res://src/economy/channel_progression.gd")
const Session = preload("res://src/stream/stream_session.gd")
var model: RefCounted
var checks := 0
var failures := 0
var path := "/tmp/hypster_xp_logic_%d.json" % OS.get_process_id()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func write_payload(payload: Dictionary, target: String) -> void:
	var encoded := JSON.stringify(payload)
	var file := FileAccess.open(target, FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": encoded, "checksum": encoded.sha256_text()}))
	file.close()

func _initialize() -> void:
	model = Progression.new(JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json")))
	for test in ["test_levels", "test_rewards", "test_transactions", "test_migration"]:
		check(call(test) == true, test + " finished without runtime errors")
	for suffix in ["", ".bak", ".tmp", ".legacy", ".bad", ".future"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Experience: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_levels() -> bool:
	check(model.level_progress(0) == {"level": 1, "current": 0, "required": 102}, "Fresh profile starts at level one with 102 XP threshold")
	var total := 0
	for level in range(1, 40):
		var required := 80 + 22 * level
		check(model.level_progress(total + required - 1).level == level, "Level boundary does not trigger early: %d" % level)
		total += required
		check(model.level_progress(total).level == level + 1, "Exact boundary crosses level: %d" % level)
	check(total == 20280 and model.maximum_experience() == total, "Forty levels use exact GDD threshold sum")
	check(model.level_progress(total).required == 0 and model.level_progress(9007199254740991).level == 40, "Maximum level remains bounded")
	return true

func test_rewards() -> bool:
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	settings.device_capacity_seconds = 14400
	var session := Session.new(settings)
	session.start(3600)
	session.elapsed_game = 3600
	session.state = Session.State.FINISHED
	session.end_reason = Session.EndReason.COMPLETED
	check(model.stream_experience(session, 0, 0) == 100 and model.stream_experience(session, 100, 0) == 140, "One played game hour earns 100–140 XP by PS")
	check(model.stream_experience(session, 50, 0) == 120, "Quality interpolates reward")
	session.elapsed_game = 900
	check(model.stream_experience(session, 100, 0) == 35, "Fifteen played minutes receive proportional reward")
	session.end_reason = Session.EndReason.EARLY
	check(model.stream_experience(session, 100, 0) == 17, "Early penalty halves reward, then rounds down")
	session.elapsed_game = 0
	check(model.stream_experience(session, 100, 0) == 0, "Immediate exit cannot farm XP")
	session.elapsed_game = 180
	check(model.stream_experience(session, 100, 0) * 20 < 140, "Repeated short early exits cannot outperform equal completed play time")
	session.elapsed_game = 3600
	session.end_reason = Session.EndReason.COMPLETED
	check(model.stream_experience(session, 100, 20270) == 10 and model.stream_experience(session, 100, 20280) == 0, "Reward caps at maximum level")
	check(model.stream_experience(session, NAN, 0) == 0, "Invalid score cannot award XP")
	return true

func test_transactions() -> bool:
	var wallet := Wallet.new(path)
	DirAccess.make_dir_absolute(path + ".tmp")
	check(wallet.settle_stream("xp_stream", 1000, 3, 70, true, 0, 120) != OK and wallet.experience == 0 and wallet.balance_units == 0 and wallet.followers == 0, "Failed write changes none of money, followers or XP")
	DirAccess.remove_absolute(path + ".tmp")
	check(wallet.settle_stream("xp_stream", 1000, 3, 70, true, 0, 120) == OK and wallet.experience == 120, "Retry settles XP and other rewards atomically")
	var restored := Wallet.new(path)
	check(restored.experience == 120 and restored.balance_units == 1000 and restored.followers == 3, "Experience and other rewards survive reload")
	check(restored.settle_stream("xp_stream", 1000, 3, 70, true, 0, 120) == OK and restored.experience == 120 and restored.balance_units == 1000, "Repeated settlement never duplicates XP")
	check(restored.settle_stream("negative_xp", 0, 0, 0, true, 0, -1) == ERR_INVALID_PARAMETER, "Negative experience is rejected")
	check(restored.settle_stream("overflow_xp", 0, 0, 0, true, 0, 9223372036854775807) == ERR_INVALID_PARAMETER, "Overflowing experience is rejected")
	check(restored.settle_stream("fake_credit", 0, 0, 0, false, 0, 10) == ERR_INVALID_PARAMETER, "Non-stream credits cannot issue experience")
	check(restored.credit("money_only", 10) == OK and restored.experience == 120, "Existing money credits preserve experience")
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("broken primary")
	corrupt.close()
	var recovered := Wallet.new(path)
	check(recovered.recovered_from_backup and recovered.experience == 120 and recovered.settle_stream("xp_stream", 1000, 3, 70, true, 0, 120) == OK and recovered.experience == 120, "Backup recovery preserves XP and duplicate protection")
	return true

func test_migration() -> bool:
	var payload := Wallet.new(path)._payload()
	payload.version = 4
	payload.erase("experience")
	payload.inventory = ["ifone_2g", "fresh_wallpaper"]
	payload.equipped_device = "ifone_2g"
	payload.recent_titles = ["старый эфир"]
	write_payload(payload, path + ".legacy")
	var bytes := FileAccess.get_file_as_string(path + ".legacy")
	var legacy := Wallet.new(path + ".legacy")
	check(legacy.experience == 0 and legacy.load_error == OK and FileAccess.get_file_as_string(path + ".legacy") == bytes, "Loading old profile assigns zero XP without rewriting file")
	check(legacy.settle_stream("new_xp", 100, 1, 80, true, 0, 130) == OK, "Old profile migrates on successful transaction")
	var upgraded := Wallet.new(path + ".legacy")
	check(upgraded.experience == 130 and upgraded.inventory == ["ifone_2g", "fresh_wallpaper"] and upgraded.equipped_device == "ifone_2g" and upgraded.recent_titles == ["старый эфир"], "Migration preserves devices, repair and title history")
	for invalid in [-1, 1.5, "100", null]:
		var bad: Dictionary = upgraded._payload()
		bad.experience = invalid
		write_payload(bad, path + ".bad")
		check(Wallet.new(path + ".bad").load_error == ERR_FILE_CORRUPT, "Malformed experience fails validation")
	var future: Dictionary = upgraded._payload()
	future.version = 99
	write_payload(future, path + ".future")
	check(Wallet.new(path + ".future").credit("no_rewrite", 1) == ERR_UNAVAILABLE, "Future versions remain protected")
	for suffix in [".legacy.bak", ".legacy.tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	return true
