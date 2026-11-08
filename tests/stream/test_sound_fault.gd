extends SceneTree
const Session = preload("res://src/stream/stream_session.gd")
const Progression = preload("res://src/economy/channel_progression.gd")
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
	settings["sound_fault_spawn_real_seconds"] = spawn
	settings["active_cooling_available"] = true
	var session := Session.new(settings, JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json")))
	session.start(900)
	return session

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	for test in ["test_loss", "test_recovery", "test_boundaries"]:
		check(call(test) == true, test + " completed without runtime errors")
	print("Sound fault: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_loss() -> bool:
	var fault := fresh()
	var control := fresh(-1)
	fault.advance(4.99)
	check(not fault.sound_fault_active and fault.sound_fault_game_seconds == 0, "No early failure or penalty")
	fault.advance(0.01)
	check(fault.sound_fault_active and fault.sound_fault_serial == 1 and is_zero_approx(fault.sound_fault_game_seconds), "Fault starts exactly at schedule without retroactive loss")
	fault.advance(5)
	control.advance(10)
	check(is_equal_approx(fault.elapsed_game, 20) and is_equal_approx(fault.sound_fault_game_seconds, 10), "Only actual game time with faulty sound is counted")
	check(fault.income.earned_total_units() == 316 and control.income.earned_total_units() == 333, "Half of the twenty-second segment loses ten percent income")
	check(is_equal_approx(fault.quality_multiplier(), 0.95), "Quality averages cold and faulty segments")
	var model := Progression.new(JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json")))
	check(model.performance_components(fault, []).equipment < model.performance_components(control, []).equipment, "Actual score uses time-weighted quality loss")
	check(model.performance_tip(fault, model.performance_components(fault, [])) == model.config.result_report.tips.sound_fault, "Unrepaired sound receives actionable result tip")
	var hot := fresh()
	hot.heat = 85
	hot.advance(10)
	check(is_equal_approx(hot.quality_multiplier(), 0.855) and hot.income.earned_total_units() == 285, "Simultaneous heat and sound loss multiply only during overlap")
	var crossing := fresh(0.01)
	crossing.advance(0.02)
	check(is_equal_approx(crossing.sound_fault_game_seconds, 0.02) and is_equal_approx(crossing.quality_multiplier(), 0.95), "Spawn within integration slice penalizes only trailing fraction")
	return true

func test_recovery() -> bool:
	var session := fresh()
	check(not session.repair_sound(0), "Cannot repair before failure")
	session.advance(7)
	check(not session.repair_sound(0), "Wrong serial cannot repair current fault")
	var time: float = session.elapsed_game
	var heat: float = session.heat
	var earned: int = session.income.earned_total_units()
	var hype: float = session.hype
	session.pause()
	var faulty_time: float = session.sound_fault_game_seconds
	session.advance(40)
	check(session.elapsed_game == time and session.sound_fault_game_seconds == faulty_time and not session.repair_sound(1), "Pause freezes failure time and blocks repair")
	session.resume()
	check(session.repair_sound(1) and not session.sound_fault_active and session.sound_fault_repairs == 1, "Repair resolves current fault once")
	check(session.elapsed_game == time and session.heat == heat and session.income.earned_total_units() == earned and session.hype == hype and session.tap_count == 0, "Repair itself grants no money, hype, taps or time")
	check(not session.repair_sound(1), "Repeated repair is rejected")
	session.advance(3)
	check(is_equal_approx(session.sound_fault_game_seconds, 4) and session.income.earned_total_units() == 326, "Recovery stops future penalty without refunding lost income")
	session.advance(20)
	check(not session.sound_fault_active and session.sound_fault_serial == 1, "Fault cannot reappear in same stream")
	session.finish_early()
	session.start(900)
	session.advance(5)
	check(session.sound_fault_serial == 2 and session.sound_fault_repairs == 0 and not session.repair_sound(1), "Restart resets statistics and rejects stale serial")
	session.heat = 90
	check(session.is_lagging() and session.cool_device() and session.repair_sound(2), "Lag and cooling tap lock do not block repair")
	return true

func test_boundaries() -> bool:
	var session := fresh()
	session.advance(100)
	check(session.sound_fault_active and session.sound_fault_game_seconds > 0, "Ignored fault remains until repair or stream end")
	session.finish_early()
	check(not session.sound_fault_active and not session.repair_sound(1), "Early finish closes repair action")
	session.start(10)
	session.advance(5)
	check(session.end_reason == Session.EndReason.COMPLETED and not session.sound_fault_active, "Completion wins simultaneous spawn")
	session.start(900)
	session.advance(5)
	session.heat = 99.999
	session.advance(1)
	check(session.end_reason == Session.EndReason.OVERHEATED and not session.sound_fault_active and not session.repair_sound(session.sound_fault_serial), "Overheat closes active fault")
	return true
