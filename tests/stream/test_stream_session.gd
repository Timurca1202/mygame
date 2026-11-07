extends SceneTree

const Session = preload("res://src/stream/stream_session.gd")
var failures := 0
var checks := 0
var config: Dictionary

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	_run()
	print("Stream simulation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func fresh(seconds: float = 900.0) -> RefCounted:
	var result := Session.new(config)
	check(result.start(seconds), "Valid duration must start")
	return result

func _run() -> void:
	var baseline := fresh()
	baseline.advance(10.0)
	check(is_equal_approx(baseline.elapsed_game, 20.0), "Base clock must run at x2")
	check(is_equal_approx(baseline.heat, 100.0 * 20.0 / 1200.0), "Base heat must use game seconds")
	check(baseline.speed == 2.0 and baseline.hype == 0.0, "No input must not generate hype or acceleration")

	var active := fresh()
	for i in range(36):
		active.tap()
		active.advance(1.0 / 6.0)
	check(is_equal_approx(active.speed, 4.0), "Six taps per second must reach x4")
	check(active.elapsed_game > 12.0 and active.elapsed_game < 24.0, "Acceleration must ramp instead of jumping")
	check(active.heat > 100.0 * active.elapsed_game / 1200.0, "Acceleration must increase heat per game second")
	active.advance(1.0)
	check(is_equal_approx(active.speed, 4.0), "Speed must hold during the two-second grace period")
	active.advance(5.0)
	check(active.speed < 4.0 and active.speed >= 2.0, "Speed must decay gradually after grace")
	active.advance(10.0)
	check(is_equal_approx(active.speed, 2.0), "Speed must return to base without input")

	var hot := fresh()
	for i in range(6):
		hot.tap()
	hot.speed = 4.0
	hot.advance(0.5)
	check(absf(hot.heat / hot.elapsed_game / (100.0 / 1200.0) - pow(2.0, 1.3)) < 0.00001, "Heat multiplier at x4 must match GDD exponent")
	for i in range(ceili(100.0 / float(config.hype_per_tap))):
		hot.tap()
	check(hot.hype == 100.0 and hot.peak_hype == 100.0, "Hype must cap at 100")
	hot.advance(1.0)
	check(hot.hype < 100.0 and hot.peak_hype == 100.0, "Peak hype must survive decay")

	var slower := fresh()
	for i in range(10):
		slower.tap()
	check(is_equal_approx(slower.hype, 3.5), "Ten taps must add only 3.5 hype instead of 25")
	var before_idle: float = slower.hype
	slower.advance(1.0)
	check(absf(slower.hype - (before_idle - 0.15)) < 0.001, "Activity grace must use gentle decay")
	slower.advance(3.0)
	check(slower.hype < 0.1, "Inactivity must noticeably drain hype")
	check(slower.peak_hype == before_idle, "Inactivity must preserve peak statistics")
	for i in range(100):
		slower.tap()
	slower.advance(2.0)
	check(slower.is_hype_cooling(), "Idle state must be visible to the UI")
	slower.tap()
	check(not slower.is_hype_cooling(), "A new tap must leave idle decay immediately")

	var measured := fresh()
	for i in range(180):
		measured.tap()
		measured.advance(1.0 / 6.0)
	check(measured.hype > 55.0 and measured.hype < 65.0, "Thirty seconds of six taps per second must not instantly fill hype")
	var calm_player := fresh()
	for i in range(90):
		calm_player.tap()
		calm_player.advance(1.0 / 3.0)
	check(calm_player.hype > 20.0 and calm_player.hype < 35.0, "Moderate tapping must build hype gradually")

	var paused := fresh()
	paused.tap()
	paused.advance(1.0)
	paused.pause()
	var snapshot: Array = [paused.elapsed_real, paused.elapsed_game, paused.heat, paused.hype, paused.tap_count]
	paused.advance(999.0)
	paused.tap()
	check(snapshot == [paused.elapsed_real, paused.elapsed_game, paused.heat, paused.hype, paused.tap_count], "Pause must freeze all simulation and reject taps")
	paused.resume()
	paused.advance(1.0)
	check(paused.elapsed_real > float(snapshot[0]), "Resume must advance the session")

	var completed := fresh(60.0)
	completed.advance(999.0)
	check(completed.state == Session.State.FINISHED and completed.end_reason == Session.EndReason.COMPLETED, "Short stream must complete normally")
	check(is_equal_approx(completed.elapsed_game, 60.0) and is_equal_approx(completed.elapsed_real, 30.0), "Completion must not overrun even with a large delta")
	var end_heat: float = completed.heat
	completed.advance(10.0)
	completed.tap()
	check(completed.heat == end_heat and completed.tap_count == 0, "Finished session must reject time and input")
	check(completed.start(900.0) and completed.heat == 0.0 and completed.end_reason == Session.EndReason.NONE, "New prototype session must reset results")
	check(not completed.start(60.0), "Live session must reject a second start")

	var overheated := fresh()
	for i in range(3000):
		overheated.tap()
		overheated.advance(1.0 / 6.0)
		if overheated.state == Session.State.FINISHED:
			break
	check(overheated.end_reason == Session.EndReason.OVERHEATED, "Sustained tapping must overheat the phone before a 15-minute stream ends")
	check(overheated.heat == 100.0 and overheated.elapsed_game < 900.0, "Overheat must stop exactly at 100 percent")
	var invalid := Session.new(config)
	check(not invalid.start(0.0) and not invalid.start(1201.0), "Invalid device durations must be rejected")
	check(not invalid.start(NAN) and not invalid.start(INF), "Non-finite durations must be rejected")
	var frozen_time: float = baseline.elapsed_game
	baseline.advance(-1.0)
	baseline.advance(NAN)
	check(baseline.elapsed_game == frozen_time, "Invalid deltas must be ignored")
