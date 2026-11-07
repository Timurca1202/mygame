extends SceneTree
const Wallet = preload("res://src/economy/player_wallet.gd")
var checks := 0
var failures := 0
var path: String

func _initialize() -> void:
	path = "user://wallet_test_%d.json" % OS.get_process_id()
	_run()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Wallet persistence: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func write_raw(target: String, contents: String) -> void:
	var file := FileAccess.open(target, FileAccess.WRITE)
	file.store_string(contents)
	file.close()

func _run() -> void:
	var wallet := Wallet.new(path)
	check(wallet.load_error == OK and wallet.balance_units == 0, "New wallet must start empty without a file error")
	check(not FileAccess.file_exists(path), "Loading a fresh wallet must not write a save in advance")
	check(wallet.credit("stream_a", 1000) == OK, "First completed stream must save atomically")
	check(wallet.balance_units == 1000, "Successful save must update in-memory balance")
	check(not FileAccess.file_exists(path + ".tmp"), "Atomic rename must leave no temporary save behind")
	check(wallet.credit("stream_a", 1000) == OK and wallet.balance_units == 1000, "Duplicate settlement must not pay twice")
	check(wallet.credit("", 10) == ERR_INVALID_PARAMETER and wallet.credit("negative", -1) == ERR_INVALID_PARAMETER, "Invalid transactions must not alter the wallet")
	check(wallet.credit("overflow", 9223372036854775807) == ERR_INVALID_PARAMETER, "Overflowing credits must be rejected before addition")
	var restored := Wallet.new(path)
	check(restored.load_error == OK and restored.balance_units == 1000, "Wallet must survive a new process instance")
	check(restored.credit("stream_a", 1000) == OK and restored.balance_units == 1000, "Duplicate protection must survive reload")
	check(restored.credit("stream_b", 333) == OK and restored.balance_units == 1333, "Second stream must accumulate money")
	check(FileAccess.file_exists(path + ".bak"), "Second save must keep the previous valid state as backup")

	write_raw(path, "{broken json")
	var recovered := Wallet.new(path)
	check(recovered.recovered_from_backup and recovered.balance_units == 1000, "Corrupt primary save must recover the previous valid state")
	check(recovered.credit("stream_recovery", 42) == OK, "Recovered wallet must be writable")
	var recovered_again := Wallet.new(path)
	check(recovered_again.balance_units == 1042 and recovered_again.load_error == OK, "Recovery transaction must survive reload")

	var file := FileAccess.open(path, FileAccess.READ)
	var decoded: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var tampered: Dictionary = JSON.parse_string(decoded.payload)
	tampered.balance_units = 999999
	decoded.payload = JSON.stringify(tampered)
	write_raw(path, JSON.stringify(decoded))
	var checksum_recovered := Wallet.new(path)
	check(checksum_recovered.recovered_from_backup, "Checksum mismatch must not silently accept altered money")

	write_raw(path, "corrupt primary")
	write_raw(path + ".bak", "corrupt backup")
	var corrupt := Wallet.new(path)
	check(corrupt.load_error == ERR_FILE_CORRUPT, "Two invalid saves must report a genuine read error")
	check(corrupt.credit("do_not_overwrite", 10) == ERR_FILE_CORRUPT, "Unreadable progress must not be replaced with a fresh zero balance")
	check(FileAccess.get_file_as_string(path) == "corrupt primary", "Failed load must preserve the original corrupt file for recovery")

	var future_payload := JSON.stringify({"version": 99})
	var future := {"payload": future_payload, "checksum": future_payload.sha256_text()}
	write_raw(path, JSON.stringify(future))
	var newer := Wallet.new(path)
	check(newer.load_error == ERR_UNAVAILABLE and newer.credit("old_client", 10) == ERR_UNAVAILABLE, "Newer save versions must not be overwritten by an older client")
	var malformed_payload := JSON.stringify({"version": [1], "balance_units": 10, "credited_sessions": []})
	write_raw(path, JSON.stringify({"payload": malformed_payload, "checksum": malformed_payload.sha256_text()}))
	var malformed := Wallet.new(path)
	check(malformed.load_error == ERR_FILE_CORRUPT, "Malformed schema types must fail cleanly without a script exception")
	var inaccessible := Wallet.new("user://missing_wallet_dir_%d/profile.json" % OS.get_process_id())
	check(inaccessible.credit("failed_write", 100) != OK and inaccessible.balance_units == 0, "Failed disk write must not update in-memory money")
