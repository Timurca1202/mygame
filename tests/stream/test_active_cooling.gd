extends SceneTree
const Session = preload("res://src/stream/stream_session.gd")
const Progression = preload("res://src/economy/channel_progression.gd")
var config: Dictionary
var chat: Dictionary
var donors: Array
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fresh(available: bool = true) -> RefCounted:
	var settings := config.duplicate(true)
	settings["active_cooling_available"] = available
	settings.cooling_ratio = 0.15
	var session := Session.new(settings, chat, donors)
	session.start(900)
	return session

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	chat = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json"))
	donors = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/donations.json")).donors
	var model := Progression.new(JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json")))
	check(not model.has_active_cooling([]) and not model.has_active_cooling(["old_cactus"]), "No cooling action without the actual equipment")
	check(model.has_active_cooling(["desk_fan"]) and model.has_active_cooling(["desk_fan", "desk_fan"]), "Owned fan enables one action without stacking")
	var absent := fresh(false)
	absent.heat = 50
	check(not absent.cool_device() and absent.heat == 50, "Calling domain action cannot bypass ownership")
	var session := fresh()
	check(not session.cool_device() and session.cooling_uses == 0, "Cold phone cannot consume cooling or lock taps")
	session.advance(10)
	for tap in range(6):
		session.tap()
	session.heat = 92
	var time: float = session.elapsed_game
	var earned: int = session.income.earned_total_units()
	var hype: float = session.hype
	var taps: int = session.tap_count
	check(session.cool_device() and session.heat == 82, "Cooling removes exactly ten heat percentage points")
	check(session.elapsed_game == time and session.income.earned_total_units() == earned and session.hype == hype, "Cooling action itself invents neither time, money nor hype")
	check(session.cooling_lock_remaining == 2 and session.cooling_cooldown_remaining == 20, "Cost is two real seconds without taps and twenty-second reuse timer")
	check(session._taps.is_empty(), "Old tap buffer cannot keep accelerating through cooling")
	check(not session.cool_device() and session.heat == 82 and session.cooling_uses == 1, "Duplicate action cannot stack heat reduction")
	session.tap()
	check(session.tap_count == taps and session.hype == hype, "Domain tap path rejects activity while locked")
	check(session.answer_chat(session.chat.event_serial, int(session.chat.active.correct)), "Chat answers remain available during cooling")
	check(session.thank_donation(session.income.donation_serial), "Donation thanks remain available during cooling")
	session.pause()
	session.advance(50)
	check(session.cooling_lock_remaining == 2 and session.cooling_cooldown_remaining == 20 and not session.cool_device(), "Pause freezes both timers and rejects action")
	session.resume()
	session.advance(1.99)
	session.tap()
	check(session.tap_count == taps and session.cooling_lock_remaining > 0, "Taps stay locked until full two seconds elapsed")
	session.advance(0.01)
	session.tap()
	check(session.tap_count == taps + 1 and session.cooling_lock_remaining < 0.000001, "Taps resume at exact timer boundary")
	check(not session.cool_device(), "Unlocking taps does not bypass reuse cooldown")
	session.advance(18)
	check(session.cool_device() and session.cooling_uses == 2, "Cooling can be used again after twenty real seconds")
	session.finish_early()
	var lock_time: float = session.cooling_lock_remaining
	session.advance(50)
	check(not session.cool_device() and session.cooling_lock_remaining == lock_time, "Finished streams cannot cool or advance timers")
	session.start(900)
	check(session.cooling_lock_remaining == 0 and session.cooling_cooldown_remaining == 0 and session.cooling_uses == 0, "New stream clears ephemeral timers")
	session.heat = 3
	check(session.cool_device() and session.heat == 0, "Cooling clamps safely at zero heat")
	var control := fresh()
	var waiting := fresh()
	control.advance(40)
	waiting.advance(20)
	waiting.cool_device()
	waiting.advance(20)
	check(is_equal_approx(control.elapsed_game, waiting.elapsed_game) and control.income.total_units() == waiting.income.total_units(), "At equal speed cooling preserves game-time income")
	var rushed := fresh(false)
	var managed := fresh()
	for step in range(3000):
		rushed.tap()
		rushed.advance(0.125)
		managed.tap()
		managed.advance(0.125)
		if managed.heat >= 20:
			managed.cool_device()
		if managed.state == Session.State.FINISHED:
			break
	check(rushed.end_reason == Session.EndReason.OVERHEATED, "Unmanaged forced stream still risks real overheat")
	check(managed.elapsed_game > rushed.elapsed_game and managed.cooling_uses > 0, "Accepting tap lock buys meaningful additional stream time")
	check(managed.end_reason == Session.EndReason.COMPLETED, "Managed fan allows this forced fifteen-minute stream to finish")
	print("Active cooling: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
