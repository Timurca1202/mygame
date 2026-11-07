extends SceneTree
const Income = preload("res://src/economy/stream_income.gd")
const Session = preload("res://src/stream/stream_session.gd")
var config: Dictionary
var donors: Array
var checks := 0
var failures := 0

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/donations.json"))
	donors = content.donors
	_run()
	print("Stream income: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func model(seconds: float = 900.0) -> RefCounted:
	var result := Income.new(config.economy, donors)
	result.start(seconds)
	return result

func _run() -> void:
	var ledger := model(60.0)
	ledger.advance(19.0, 9.5)
	check(ledger.donation.is_empty() and ledger.base_units == 0, "Donation must wait for its scheduled game time")
	ledger.advance(1.0, 0.5)
	check(ledger.donation_serial == 1 and ledger.donation_count == 1, "First donation must appear on the twentieth game second")
	var base: int = ledger.donation.amount_units
	check(base == 333 and ledger.base_units == base, "Donation amount must come from viewer-hours, not random free money")
	check(absf(ledger.seconds_left() - 5.0) < 0.0001, "Thanks deadline must start at five real seconds")
	check(not ledger.thank(999), "Stale donation IDs must not award a bonus")
	check(ledger.thank(1), "Current donation must accept thanks")
	check(ledger.thanks_units == 33 and ledger.thanked_count == 1, "Thanks must grant ten percent rounded down to a money unit")
	check(not ledger.thank(1) and ledger.thanks_units == 33, "A donation must never pay the thanks bonus twice")
	ledger.advance(40.0, 20.0)
	ledger.finish()
	check(ledger.base_units == 1000, "One game minute with three viewers at $2 per viewer-hour must earn $0.10")
	check(ledger.total_units() == 1033, "Final income must include the earned base and only the accepted thanks bonus")
	ledger.finish()
	ledger.advance(900.0, 450.0)
	check(ledger.total_units() == 1033 and ledger.donation.is_empty(), "Repeated finish and time after finish must not duplicate income")

	var expired := model()
	expired.advance(20.0, 10.0)
	var expired_id: int = expired.donation_serial
	expired.advance(10.0, 5.0)
	check(not expired.thank(expired_id) and expired.thanks_units == 0, "Missed thanks window must not pay a late bonus")
	check(expired.base_units > 0, "Ignoring a donor must not revoke the base donation")

	var base_speed := model()
	var fast_speed := model()
	for i in range(45000):
		base_speed.advance(0.02, 0.01)
		fast_speed.advance(0.02, 0.005)
	base_speed.finish()
	fast_speed.finish()
	check(base_speed.base_units == 15000 and fast_speed.base_units == 15000, "Equal game duration must earn equal base income at x2 and x4")
	check(base_speed.donation_count == fast_speed.donation_count, "Thanks speed must not create extra base donation events")

	var capped := model(60.0)
	for i in range(1000):
		capped.reward_correct_answer(999)
	check(capped.chat_units == 0, "Chat rewards must not grant money before any base income has been earned")
	capped.advance(60.0, 30.0)
	capped.finish()
	check(capped.chat_units == 250, "Chat bonus must cap at twenty-five percent of earned base income")
	check(capped.total_units() == 1250, "Final total must respect the chat reward cap")

	var combo := model(60.0)
	combo.advance(60.0, 30.0)
	combo.reward_correct_answer(1)
	check(combo.chat_units == 15, "First correct answer must request 1.5 percent of planned base income")
	combo.reward_correct_answer(999)
	check(combo.chat_units == 37, "Combo multiplier must cap at x1.5")

	var partial := model()
	for i in range(1000):
		partial.reward_correct_answer(999)
	partial.advance(60.0, 30.0)
	partial.finish()
	check(partial.base_units == 1000 and partial.chat_units == 250, "Early finish must cap bonuses against actual earned income, not the full planned stream")

	var session := Session.new(config, {}, donors)
	session.start(900.0)
	session.advance(10.01)
	check(not session.income.donation.is_empty(), "Session must expose a donation to the UI")
	var before_time: float = session.income.seconds_left()
	session.pause()
	session.advance(99.0)
	check(session.income.seconds_left() == before_time, "Pause must freeze the thanks deadline")
	check(not session.thank_donation(session.income.donation_serial), "Paused session must reject thanks input")
	session.resume()
	check(session.thank_donation(session.income.donation_serial), "Resumed session must accept thanks")
	check(session.tap_count == 0 and session.speed == 2.0, "Thanking must not count as tapping or acceleration")
