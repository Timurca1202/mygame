extends SceneTree
const Session = preload("res://src/stream/stream_session.gd")
const Income = preload("res://src/economy/stream_income.gd")
var config: Dictionary
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fresh(initial: float = 10, cap: float = 100) -> RefCounted:
	var settings := config.duplicate(true)
	settings.economy.viewers = initial
	settings["viewer_cap"] = cap
	settings.device_capacity_seconds = 1000000
	settings.hype_decay_per_second = 0
	settings.hype_idle_decay_per_second = 0
	settings.audience.grace_game_seconds = 0
	var session := Session.new(settings)
	session.start(900)
	return session

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	for test in ["test_growth_and_income", "test_faults", "test_limits_and_states", "test_integrator"]:
		check(call(test) == true, test + " completed without runtime errors")
	print("Live audience: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_growth_and_income() -> bool:
	var session := fresh()
	session.hype = 100
	session.advance(30)
	var decay := exp(-60.0 / 90.0)
	var expected := 17.5 - 7.5 * decay
	var integral := 17.5 * 60.0 - 7.5 * 90.0 * (1.0 - decay)
	check(is_equal_approx(session.viewers, expected), "Hype produces gradual exponential arrival, not an instant jump")
	check(is_equal_approx(session.viewer_game_seconds, integral) and is_equal_approx(session.average_viewers(), integral / 60), "Average counts entire viewer-time integral")
	check(session.income.earned_total_units() == int(floor(integral / 3600 * 20000 + 0.000001)), "Income uses actual viewer-time, never final audience retroactively")
	check(session.peak_viewers == session.viewers and session.audience_notice == "growing", "Peak and arrival notice reflect actual growth")
	var peak: float = session.peak_viewers
	session.hype = 0
	session.advance(60)
	check(session.viewers < expected and session.viewers > 10 and session.peak_viewers == peak, "Cooling hype causes gradual return toward baseline and retains peak")
	check(session.audience_notice == "quiet", "Departure from cooling hype is explained")
	var grace := fresh(3, 10)
	grace._config.audience.grace_game_seconds = 60
	grace.hype = 100
	grace.advance(30)
	check(is_equal_approx(grace.viewers, 3) and grace.income.earned_total_units() == 1000, "First game minute preserves starting three viewers and prior income")
	grace.advance(1)
	check(grace.viewers > 3, "Growth begins after grace period")
	return true

func test_faults() -> bool:
	var fault := fresh()
	fault._config["sound_fault_spawn_real_seconds"] = 0.0
	fault.advance(60)
	check(fault.viewers < 10 and fault.viewers > 6.5 and fault.audience_notice == "sound", "Missing sound gradually loses audience and explains cause")
	var before: float = fault.viewers
	var earned: int = fault.income.earned_total_units()
	check(fault.repair_sound(fault.sound_fault_serial) and fault.viewers == before and fault.income.earned_total_units() == earned, "Repair invents neither instant viewers nor refunds")
	fault.advance(60)
	check(fault.viewers > before and fault.viewers < 10 and fault.audience_notice == "returning", "Healthy stream gradually wins viewers back")
	var hot := fresh()
	hot.heat = 90
	hot.advance(60)
	check(hot.viewers < 10 and hot.viewers > 7.5 and hot.audience_notice == "heat", "Sustained heat drives audience toward lower target")
	var both := fresh()
	both.heat = 90
	both._config["sound_fault_spawn_real_seconds"] = 0.0
	both.advance(30)
	var target := 10.0 * 0.75 * 0.65
	var integral := target * 60 + (10 - target) * 90 * (1 - exp(-60.0 / 90))
	check(is_equal_approx(both.viewer_game_seconds, integral), "Simultaneous faults affect audience multiplicatively")
	check(both.income.earned_total_units() == int(floor(integral / 3600 * 20000 * 0.81 + 0.000001)), "Actual smaller audience and technical quality both affect faulty interval only")
	return true

func test_limits_and_states() -> bool:
	var capped := fresh(9, 10)
	capped.hype = 100
	capped.advance(100)
	check(capped.viewers <= 10 and capped.peak_viewers <= 10 and capped.average_viewers() <= 10, "Device cap constrains current, peak and average audience")
	var initial := fresh(100, 10)
	check(initial.viewers == 10 and initial.starting_viewers == 10, "Starting audience is capped before simulation")
	var zero := fresh(0)
	zero.hype = 100
	zero.advance(60)
	check(zero.viewers == 0 and zero.income.earned_total_units() == 0, "Hype cannot mint viewers or income from zero baseline")
	var audience: float = capped.viewers
	var integral: float = capped.viewer_game_seconds
	capped.pause()
	capped.advance(200)
	check(capped.viewers == audience and capped.viewer_game_seconds == integral, "Pause freezes audience and viewer-hours")
	capped.resume()
	capped.finish_early()
	var paid: int = capped.income.total_units()
	capped.advance(200)
	check(capped.income.total_units() == paid and capped.viewer_game_seconds == integral, "Finished stream cannot add audience-time or income")
	capped.start(900)
	check(capped.viewers == 9 and capped.peak_viewers == 9 and capped.viewer_game_seconds == 0 and capped.audience_notice.is_empty(), "New stream resets audience statistics and notices")
	return true

func test_integrator() -> bool:
	var whole := fresh()
	var split := fresh()
	whole.hype = 70
	split.hype = 70
	whole.advance(60)
	for frame in range(240):
		split.advance(0.25)
	check(is_equal_approx(whole.viewers, split.viewers) and is_equal_approx(whole.viewer_game_seconds, split.viewer_game_seconds) and whole.income.earned_total_units() == split.income.earned_total_units(), "Different frame sizes preserve audience and posted income")
	var fast := fresh()
	fast.hype = 70
	fast._config.base_speed = 4.0
	fast._config.max_speed = 4.0
	fast.speed = 4
	fast.advance(30)
	check(is_equal_approx(fast.elapsed_game, whole.elapsed_game) and is_equal_approx(fast.viewers, whole.viewers) and fast.income.earned_total_units() == whole.income.earned_total_units(), "Equal game time and hype at x2 and x4 earn equal audience income")
	var ledger := Income.new(config.economy)
	ledger.start(900)
	ledger.advance(60, 30, 1, 0)
	check(ledger.earned_total_units() == 0, "Explicit zero audience earns nothing")
	ledger.advance(60, 30, 1, NAN)
	ledger.advance(60, 30, 1, -2)
	check(ledger.game_elapsed == 60 and ledger.earned_total_units() == 0, "Invalid audience inputs cannot corrupt money or time")
	ledger.advance(60, 30, 1, 4.5)
	check(ledger.earned_total_units() == 1500, "Fractional dynamic audience feeds precise integer-money ledger")
	return true
