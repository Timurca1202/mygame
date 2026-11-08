extends SceneTree
const Session = preload("res://src/stream/stream_session.gd")
var config: Dictionary
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fresh(spawn: float = 5.0) -> RefCounted:
	var settings := config.duplicate(true)
	settings["viral_spawn_real_seconds"] = spawn
	settings["active_cooling_available"] = true
	settings.hype_decay_per_second = 0
	settings.hype_idle_decay_per_second = 0
	var session := Session.new(settings)
	session.start(900)
	return session

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	for test in ["test_catch", "test_deadline", "test_states", "test_boundaries"]:
		check(call(test) == true, test + " finished without runtime errors")
	print("Viral moment: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_catch() -> bool:
	var session := fresh()
	check(not session.catch_viral(0), "No catch before an event")
	session.advance(4.99)
	check(session.viral_seconds_left() == 0, "No early spawn")
	session.advance(0.01)
	check(is_equal_approx(session.viral_seconds_left(), 2.0) and session.viral_serial == 1, "Exactly two real seconds at scheduled spawn")
	check(not session.catch_viral(0), "Stale serial is rejected")
	var time: float = session.elapsed_game
	var earned: int = session.income.earned_total_units()
	var heat: float = session.heat
	check(session.catch_viral(1) and session.hype == 10 and session.peak_hype == 10, "Catch awards configured hype and records peak")
	check(session.viral_caught == 1 and session.viral_outcome == "caught" and session.viral_seconds_left() == 0, "Catch resolves event immediately")
	check(session.elapsed_game == time and session.income.earned_total_units() == earned and session.heat == heat and session.tap_count == 0 and session._taps.is_empty(), "Catch invents neither money, taps, heat nor time")
	check(not session.catch_viral(1) and session.hype == 10, "Duplicate catch cannot reward twice")
	session.advance(90)
	check(session.viral_serial == 1 and session.viral_caught == 1, "At most one event per stream")
	return true

func test_deadline() -> bool:
	var missed := fresh()
	missed.hype = 30
	missed.advance(6.99)
	check(missed.viral_seconds_left() > 0 and missed.catch_viral(1), "Catch just before deadline succeeds")
	var expired := fresh()
	expired.hype = 30
	expired.advance(7)
	check(expired.viral_seconds_left() == 0 and not expired.catch_viral(1), "Catch at exact deadline is rejected")
	check(expired.viral_outcome == "missed" and expired.hype == 30 and expired.viral_caught == 0, "Missing has no penalty")
	expired.advance(1)
	check(expired.hype == 30 and expired.viral_outcome == "missed", "Expiry cannot apply repeated penalties")
	var fast := fresh()
	fast.speed = 4
	for index in range(6):
		fast.tap()
	fast.advance(5)
	check(is_equal_approx(fast.viral_seconds_left(), 2.0), "Time acceleration does not shorten catch window")
	var large := fresh()
	large.advance(20)
	check(large.viral_outcome == "missed" and not large.catch_viral(1), "Large simulation step cannot leave an expired event catchable")
	return true

func test_states() -> bool:
	var session := fresh()
	session.advance(5.5)
	var remaining: float = session.viral_seconds_left()
	session.pause()
	session.advance(50)
	check(session.viral_seconds_left() == remaining and not session.catch_viral(1), "Pause freezes timer and rejects catch")
	session.resume()
	session.heat = 90
	check(session.is_lagging() and session.catch_viral(1), "Simulated phone lag does not block HUD catch")
	session.finish_early()
	session.start(900)
	session.advance(5)
	check(session.viral_serial == 2 and not session.catch_viral(1), "Restart rejects previous event serial")
	check(session.cool_device() and session.catch_viral(2), "Cooling tap lock does not block a catch")
	session.finish_early()
	session.start(900)
	session.advance(5)
	session.finish_early()
	check(session.viral_seconds_left() == 0 and not session.catch_viral(3), "Early finish removes target and prevents rewards")
	session.start(900)
	check(session.viral_caught == 0 and session.viral_outcome.is_empty(), "New stream clears transient result")
	return true

func test_boundaries() -> bool:
	var disabled := fresh(-1)
	disabled.advance(100)
	check(disabled.viral_serial == 0 and disabled.hype == 0, "Streams without scheduled event are unchanged")
	var capped := fresh()
	capped.advance(5)
	capped.hype = 98
	check(capped.catch_viral(1) and capped.hype == 100 and capped.viral_hype_gain == 2, "Hype caps at 100 and feedback uses actual gain")
	var completed := fresh(5)
	completed.finish_early()
	completed.start(10)
	completed.advance(5)
	check(completed.state == Session.State.FINISHED and completed.viral_serial == 0, "Completion wins simultaneous spawn")
	var overheated := fresh()
	overheated.advance(5)
	overheated.heat = 99.999
	overheated.advance(0.1)
	check(overheated.end_reason == Session.EndReason.OVERHEATED and overheated.viral_seconds_left() == 0, "Overheat removes active target")
	return true
