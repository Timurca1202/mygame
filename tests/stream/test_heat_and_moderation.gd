extends SceneTree
const Session = preload("res://src/stream/stream_session.gd")
const Progression = preload("res://src/economy/channel_progression.gd")
var config: Dictionary
var content: Dictionary
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fresh(spam_only: bool = false) -> RefCounted:
	var settings := config.duplicate(true)
	settings["active_cooling_available"] = true
	settings.hype_decay_per_second = 0
	settings.hype_idle_decay_per_second = 0
	var messages := content.duplicate(true)
	if spam_only:
		messages.sequence = ["spam"]
	var session := Session.new(settings, messages)
	session.start(900)
	return session

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json"))
	var model := Progression.new(JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json")))
	var hot := fresh()
	var cold := fresh()
	hot.heat = 85
	check(hot.is_lagging() and not cold.is_lagging(), "Lag starts at eighty-five percent, never on cold device")
	hot.tap()
	check(hot.tap_count == 0 and hot.hype == 0 and hot._taps.is_empty(), "Lag pulse drops taps without fake activity or buffered acceleration")
	hot.advance(0.61)
	check(not hot.is_lagging(), "Periodic freeze ends while device remains hot")
	hot.tap()
	check(hot.tap_count == 1, "Responsive part of lag cycle still accepts input")
	var measured := fresh()
	measured.heat = 85
	measured.advance(10)
	cold.advance(10)
	check(is_equal_approx(measured.elapsed_game, cold.elapsed_game), "Lag does not change game duration or timer fairness")
	check(measured.income.earned_total_units() == 300 and cold.income.earned_total_units() == 333, "Twenty game seconds at three viewers earn 300 units hot versus 333 cold")
	check(is_equal_approx(measured.hot_game_seconds, 20) and is_equal_approx(measured.quality_multiplier(), 0.9), "Lag statistics and effective equipment quality reflect hot time")
	check(model.performance_components(measured, []).equipment < model.performance_components(cold, []).equipment, "Hot-time quality loss affects actual performance and therefore follower growth")
	var crossing := fresh()
	crossing.heat = 84
	crossing.advance(10)
	check(crossing.hot_game_seconds > 0 and crossing.hot_game_seconds < crossing.elapsed_game and crossing.quality_multiplier() > 0.9, "Crossing threshold only penalizes the hot fraction, not earlier cold time")
	var held: float = measured._lag_elapsed
	measured.pause()
	measured.advance(100)
	check(measured._lag_elapsed == held and not measured.cool_device(), "Pause freezes lag cycle and rejects cooling")
	measured.resume()
	check(measured.cool_device() and measured.heat < 85 and not measured.is_lagging(), "Cooling below threshold immediately clears lag")
	var old_hot_time: float = measured.hot_game_seconds
	measured.advance(2.1)
	measured.tap()
	check(measured.tap_count == 1 and measured.hot_game_seconds == old_hot_time, "Taps recover after cooling lock and no extra hot-time penalty accrues")
	check(measured.start(900) == false, "Cooling cannot restart or clear current stream results")
	var spam := fresh(true)
	spam.advance(4)
	check(spam.chat.active.kind == "spam" and is_equal_approx(spam.chat.seconds_left(), 10), "Spam has its own ten-real-second moderation deadline")
	spam.hype = 20
	var serial: int = spam.chat.event_serial
	check(not spam.answer_chat(serial, 0), "Quiz answer route cannot silently moderate spam")
	check(not spam.block_spam(serial + 1), "Stale or future message identifiers cannot block current spam")
	var money: int = spam.income.earned_total_units()
	check(spam.block_spam(serial) and spam.chat.blocked_spam == 1 and spam.hype == 20, "Explicit block removes spam without awarding farmable hype")
	check(spam.income.earned_total_units() == money and spam.tap_count == 0, "Moderation creates neither money nor taps")
	check(not spam.block_spam(serial) and spam.chat.blocked_spam == 1, "Repeated block cannot count twice")
	var removed := true
	for message in spam.chat.feed:
		if int(message.get("serial", -1)) == serial:
			removed = false
	check(removed and spam.chat.last_result.outcome == "blocked", "Blocked promotional text disappears from visible feed")
	var missed := fresh(true)
	missed.advance(4)
	missed.hype = 20
	missed.chat.combo = 3
	missed.advance(10.01)
	check(missed.hype == 14 and missed.chat.missed_spam == 1, "Ignored spam costs exactly six hype once")
	check(missed.chat.combo == 3 and missed.chat.missed_questions == 0, "Spam accounting stays separate from quiz accuracy and combo")
	check(model.performance_components(spam, []).activity > model.performance_components(missed, []).activity, "Moderation accuracy contributes to real activity score")
	check(not missed.block_spam(serial), "Expired spam cannot be retroactively rewarded")
	var paused := fresh(true)
	paused.advance(4)
	paused.pause()
	paused.advance(100)
	check(paused.chat.seconds_left() > 9.99 and not paused.block_spam(paused.chat.event_serial), "Pause freezes moderation deadline and rejects block")
	paused.resume()
	paused.cool_device()
	check(paused.block_spam(paused.chat.event_serial), "Moderation remains available during the fan's tap lock")
	var quiz := fresh()
	quiz.advance(4)
	check(not quiz.block_spam(quiz.chat.event_serial) and not quiz.chat.active.is_empty(), "Ordinary viewer question cannot accidentally be blocked")
	quiz.finish_early()
	check(not quiz.block_spam(quiz.chat.event_serial) and not quiz.is_lagging(), "Finished streams reject moderation and show no active lag")
	print("Heat, lag and moderation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
