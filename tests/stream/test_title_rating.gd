extends SceneTree
const Rating = preload("res://src/stream/title_rating.gd")
const Wallet = preload("res://src/economy/player_wallet.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/title_rules.json"))
	var model := Rating.new(config)
	check(not model.valid("  ") and not model.valid("я".repeat(41)), "Empty and overlong titles are invalid")
	check(model.valid("я".repeat(40)), "Cyrillic length limit counts characters")
	check(model.evaluate("", 0, [], []).is_empty() and model.evaluate("title", -1, [], []).is_empty(), "Invalid evaluation inputs fail safely")
	var good := model.evaluate("Хоррор кооп кот челлендж", 0, [0, 1], [])
	check(good.score == 100 and is_equal_approx(good.multiplier, 1.3), "Matching genre, trends and themes can reach 100 and x1.3")
	check(model.evaluate("Хоррор кооп кот челлендж", 0, [0, 0, 1], []).score == 100, "Duplicate themes cannot inflate score")
	var unknown := model.evaluate("xyz", 0, [], [])
	check(unknown.parts.genre == 0 and unknown.parts.trends == 0, "Unknown words remain neutral")
	check(model.evaluate("ХОРРОР КООП!!!", 0, [], []).parts.clickbait == 0, "Excessive uppercase loses clickbait points")
	check(model.evaluate("Хоррор!!!!", 0, [], []).parts.clickbait == 0, "Excessive punctuation loses clickbait points")
	check(model.evaluate("  ХОРРОР  кооп кот ЧЕЛЛЕНДЖ ", 0, [], ["хоррор кооп кот челлендж"]).parts.freshness == 0, "Repeat detection ignores case and extra spaces")
	check(model.evaluate("Ёж на стриме", 0, [], ["еж на стриме"]).parts.freshness == 0, "Yo and ye are equivalent in title history")
	check(model.evaluate("a", 0, [], ["a", "b", "c", "d", "e", "f"]).parts.freshness == 10, "Only the most recent five titles count")
	for title in ["a", "!".repeat(40), "Хоррор кооп кот челлендж", "Разговор с друзьями"]:
		for genre in range(3):
			var result := model.evaluate(title, genre, [0, 1], [])
			check(result.score >= 0 and result.score <= 100 and result.multiplier >= 0.7 and result.multiplier <= 1.3, "Score and multiplier stay bounded")
	var path := "user://title_wallet_%d.json" % OS.get_process_id()
	# Migrate an actual v2 payload without losing money, purchases or reward IDs.
	var payload := JSON.stringify({"version": 2, "balance_units": 123456, "credited_sessions": ["old"], "followers": 5.5, "completed_streams": 1, "last_score": 60, "inventory": ["desk_fan"]})
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload": payload, "checksum": payload.sha256_text()}))
	file.close()
	var wallet := Wallet.new(path)
	check(wallet.load_error == OK and wallet.recent_titles.is_empty(), "V2 profile loads with empty title history")
	for index in range(7):
		check(wallet.remember_title("Эфир %d" % index) == OK, "Title history saves atomically")
	var restored := Wallet.new(path)
	check(restored.recent_titles == ["Эфир 2", "Эфир 3", "Эфир 4", "Эфир 5", "Эфир 6"], "Five most recent titles survive reload")
	check(restored.balance_units == 123456 and restored.inventory == ["desk_fan"] and restored.followers == 5.5, "Title migration preserves progress")
	check(restored.credit("old", 100) == OK and restored.balance_units == 123456, "Migration preserves reward deduplication")
	check(restored.remember_title(" ") == ERR_INVALID_PARAMETER and restored.recent_titles.size() == 5, "Invalid history writes cannot mutate progress")
	var blocked := Wallet.new("user://absent_title_directory_%d/profile.json" % OS.get_process_id())
	check(blocked.remember_title("Эфир") != OK and blocked.recent_titles.is_empty(), "Failed persistence cannot mutate in-memory history")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Title rating and history: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
