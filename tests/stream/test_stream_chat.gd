extends SceneTree
const Session = preload("res://src/stream/stream_session.gd")
const Chat = preload("res://src/stream/stream_chat.gd")
var config: Dictionary
var content: Dictionary
var checks := 0
var failures := 0

func _initialize() -> void:
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	content = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json"))
	_run()
	print("Chat and hype integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func fresh(seconds: float = 900.0) -> RefCounted:
	var result := Session.new(config, content)
	result.start(seconds)
	return result

func next_question(session: RefCounted) -> void:
	for i in range(2000):
		if not session.chat.active.is_empty():
			return
		session.advance(0.02)
	check(false, "An interactive event must eventually appear")

func _run() -> void:
	check(content.quiz.size() == 20, "The first question bank must contain twenty questions")
	var ids: Dictionary = {}
	for question in content.quiz:
		check(question.answers.size() == 3 and int(question.correct) >= 0 and int(question.correct) < 3, "Every quiz must have three valid choices")
		check(not ids.has(question.id), "Question IDs must be unique")
		ids[question.id] = true

	var session := fresh()
	session.advance(3.9)
	check(session.chat.active.is_empty(), "Questions must not appear before their scheduled game time")
	session.advance(0.2)
	check(session.chat.active.kind == "quiz", "First event must be a quiz")
	check(session.chat.seconds_left() <= 12.0 and session.chat.seconds_left() > 11.7, "Question must expose the twelve-real-second deadline")
	var serial: int = session.chat.event_serial
	var correct: int = session.chat.active.correct
	var before: float = session.hype
	check(not session.answer_chat(serial + 1, correct), "Stale or future event IDs must not award hype")
	check(not session.answer_chat(serial, -1) and not session.answer_chat(serial, 3), "Invalid choices must be rejected")
	check(session.answer_chat(serial, correct), "Correct answer must be accepted")
	check(is_equal_approx(session.hype - before, 4.0), "Correct quiz answer must award exactly four hype")
	check(session.chat.combo == 1 and session.chat.best_combo == 1, "Correct answer must advance the streak")
	check(not session.is_hype_cooling(), "Answering chat must count as activity without changing speed")
	check(session.tap_count == 0 and session.speed == 2.0, "Chat answers must not count as room taps or acceleration")
	check(not session.answer_chat(serial, correct), "An answered event must never pay twice")

	next_question(session)
	check(session.chat.active.kind == "poll", "Second event must be a poll")
	check(session.answer_chat(session.chat.event_serial, 2), "Any poll choice must be valid")
	check(session.chat.reactions == 1 and session.chat.combo == 1, "Poll must register engagement without breaking the quiz streak")
	next_question(session)
	check(session.chat.active.kind == "quiz", "Third event must return to the quiz bank")
	var wrong := (int(session.chat.active.correct) + 1) % 3
	session.hype = 10.0
	check(session.answer_chat(session.chat.event_serial, wrong), "Wrong answer is still a consumed interaction")
	check(is_equal_approx(session.hype, 8.0) and session.chat.combo == 0, "Wrong answer must subtract two hype and reset the streak")
	check(session.chat.wrong_answers == 1 and not session.chat.last_result.correct_text.is_empty(), "Mistake must retain the correct answer for feedback")
	next_question(session)
	check(session.chat.active.kind == "decor" and session.chat.active.answers.size() == 1, "Room reaction must offer one response")
	check(session.answer_chat(session.chat.event_serial, 0), "Room reaction must be answerable")

	next_question(session)
	var frozen_game: float = session.elapsed_game
	var frozen_deadline: float = session.chat.seconds_left()
	var frozen_hype: float = session.hype
	session.pause()
	session.advance(100.0)
	check(not session.answer_chat(session.chat.event_serial, 0), "Paused session must reject chat answers")
	check(session.elapsed_game == frozen_game and session.chat.seconds_left() == frozen_deadline and session.hype == frozen_hype, "Pause must freeze chat deadlines, pacing, and hype decay")
	session.resume()
	session.chat.combo = 3
	session.advance(12.1)
	check(session.chat.missed_questions == 1 and session.chat.combo == 0, "Quiz expiry must count one miss and reset the streak")
	check(session.chat.active.is_empty(), "Expired question must disappear")
	check(session.chat.last_result.outcome == "timeout", "Expiry must be visible to the UI")

	var accelerated := fresh()
	for i in range(6):
		accelerated.tap()
	accelerated.speed = 4.0
	accelerated.advance(2.01)
	check(not accelerated.chat.active.is_empty(), "At x4 the same first message must arrive in about two real seconds")
	check(accelerated.chat.event_serial == 1, "Acceleration must not spawn overlapping questions")
	var accelerated_remaining: float = accelerated.chat.seconds_left()
	accelerated.advance(3.0)
	check(absf(accelerated.chat.seconds_left() - (accelerated_remaining - 3.0)) < 0.001, "Acceleration must not shorten the real answer timer")
	check(accelerated.chat.seconds_left() > 8.9, "Fast stream must still allow time to read after three real seconds")
	accelerated.advance(9.1)
	check(accelerated.chat.active.is_empty(), "Timed-out event must leave a real-time breathing gap")
	var cooldown_serial: int = accelerated.chat.event_serial
	accelerated.advance(2.0)
	check(accelerated.chat.event_serial == cooldown_serial, "No next event may arrive during the reply cooldown")
	accelerated.advance(1.1)
	check(accelerated.chat.event_serial > cooldown_serial, "Event scheduling must resume after the cooldown")

	var idle_chat := Chat.new(config.chat, content)
	for i in range(7200):
		idle_chat.advance(0.02, 0.01)
	check(idle_chat.is_calm(), "Activity waves must enter the configured calm window")
	var calm_serial: int = idle_chat.event_serial
	for i in range(1700):
		idle_chat.advance(0.02, 0.01)
	check(idle_chat.event_serial == calm_serial, "Calm window must not spawn interactive events")
	check(idle_chat.feed.size() <= 3, "Ambient message history must remain bounded")
	for i in range(200):
		idle_chat.advance(0.02, 0.01)
	check(idle_chat.event_serial > calm_serial, "Interactive events must resume after the calm window")

	var finished := fresh(60.0)
	finished.advance(999.0)
	var end_hype: float = finished.hype
	check(finished.state == Session.State.FINISHED and finished.chat.active.is_empty(), "Finish must cancel pending interactions")
	check(not finished.answer_chat(finished.chat.event_serial, 0), "Finished stream must reject late answers")
	finished.advance(100.0)
	check(finished.hype == end_hype, "Finished results must stay frozen")
	finished.start(60.0)
	check(finished.chat.correct_answers == 0 and finished.chat.combo == 0 and finished.chat.event_serial == 0, "New stream must reset chat statistics")
