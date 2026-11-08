extends SceneTree
const Session = preload("res://src/stream/stream_session.gd")
const Wallet = preload("res://src/economy/player_wallet.gd")
var config: Dictionary
var chat: Dictionary
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fresh() -> RefCounted:
	var result := Session.new(config, chat)
	result.start(60)
	return result

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	chat = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json"))
	var ready := Session.new(config, chat)
	check(not ready.finish_early(), "Ready session cannot be ended or rewarded")
	var zero := fresh()
	check(is_equal_approx(zero.exit_penalty_ratio(), 0.015), "Immediate exit has maximum GDD follower loss of 1.5 percent")
	check(zero.finish_early() and zero.income.total_units() == 0, "Immediate exit cannot award any money")
	check(not zero.finish_early(), "Finished session rejects duplicate stop")
	var early := fresh()
	early.advance(5)
	early.tap()
	var before_time: float = early.elapsed_game
	var expected_income: int = early.income.earned_total_units()
	check(early.income.total_units() < expected_income, "Finish preview includes last earned interval before donation is posted")
	early.pause()
	check(early.finish_early() and early.state == Session.State.FINISHED and early.end_reason == Session.EndReason.EARLY, "Paused stream can end with a distinct reason")
	check(early.elapsed_game == before_time and early.income.total_units() == expected_income, "Early stop posts only actually earned money")
	check(early.hype == 0 and early.peak_hype > 0, "Penalty resets current hype while keeping real peak statistics")
	check(early.chat.active.is_empty() and early.income.donation.is_empty(), "Stopping closes pending chat and donation actions")
	var paid: int = early.income.total_units()
	early.advance(999)
	early.tap()
	early.answer_chat(1, 0)
	check(early.income.total_units() == paid and early.elapsed_game == before_time, "Stopped stream rejects further progress and rewards")
	var almost := fresh()
	almost.advance(26.999)
	check(almost.exit_penalty_ratio() > 0, "Just below ninety percent still has a penalty")
	var safe := fresh()
	safe.advance(27)
	safe.tap()
	var held_hype: float = safe.hype
	check(safe.exit_penalty_ratio() == 0, "Exactly ninety percent is safe despite integration rounding")
	safe.finish_early()
	check(not safe.has_exit_penalty() and safe.hype == held_hype, "Safe early finish cannot reset hype or deduct followers")
	var complete := fresh()
	complete.advance(100)
	check(not complete.has_exit_penalty() and not complete.finish_early(), "Normal completion never becomes a penalized exit")
	var hot := Session.new(config, chat)
	hot.start(900)
	for index in range(3000):
		hot.tap()
		hot.advance(1.0 / 6.0)
		if hot.state == Session.State.FINISHED:
			break
	check(hot.end_reason == Session.EndReason.OVERHEATED and hot.has_exit_penalty() and hot.hype == 0, "Early overheat uses the same real penalty and hype reset")
	var path := "user://exit_wallet_%d.json" % OS.get_process_id()
	var wallet := Wallet.new(path)
	wallet.followers = 200
	check(wallet.credit("budget", 1000) == OK, "Create isolated follower profile")
	var loss: float = 200 * early.exit_penalty_ratio()
	check(wallet.settle_stream("early", paid, 0, 40, true, loss) == OK, "Income and follower penalty settle atomically")
	check(is_equal_approx(wallet.followers, 200 - loss) and wallet.balance_units == 1000 + paid, "Settlement credits real income and deducts exact fractional follower loss")
	var restored := Wallet.new(path)
	check(restored.settle_stream("early", paid, 0, 40, true, loss) == OK and restored.followers == wallet.followers and restored.balance_units == wallet.balance_units, "Reload and duplicate settlement cannot repeat either reward or penalty")
	check(wallet.settle_stream("negative", 1, 0, 40, true, -1) == ERR_INVALID_PARAMETER and wallet.settle_stream("nan", 1, 0, 40, true, NAN) == ERR_INVALID_PARAMETER, "Malformed penalties fail validation without mutations")
	check(wallet.settle_stream("floor", 0, 0, 40, true, 10000) == OK and wallet.followers == 0, "A penalty cannot make followers negative")
	var blocked := Wallet.new("user://missing_exit_directory_%d/profile.json" % OS.get_process_id())
	blocked.followers = 100
	check(blocked.settle_stream("retry", 100, 0, 40, true, 2) != OK and blocked.followers == 100 and blocked.balance_units == 0, "Failed write cannot debit followers or post income in memory")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	print("Stream exit and settlement: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
