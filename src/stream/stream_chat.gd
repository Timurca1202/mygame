extends RefCounted
## Offline chat scheduling in game time; content and tuning come from data.
var active: Dictionary = {}
var feed: Array[Dictionary] = []
var elapsed := 0.0
var real_elapsed := 0.0
var _next_allowed_real := 0.0
var event_serial := 0
var resolution_serial := 0
var feed_serial := 0
var last_result: Dictionary = {}
var combo := 0
var best_combo := 0
var correct_answers := 0
var wrong_answers := 0
var missed_questions := 0
var reactions := 0
var _config: Dictionary
var _content: Dictionary
var _next_event := 0.0
var _next_ambient := 0.0
var _deadline := 0.0
var _sequence_index := 0
var _ambient_index := 0
var _pool_indices: Dictionary = {}
var _stopped := false

func _init(config: Dictionary, content: Dictionary) -> void:
	_config = config.duplicate(true)
	_content = content.duplicate(true)
	reset()

func reset() -> void:
	active = {}
	feed.clear()
	elapsed = 0.0
	real_elapsed = 0.0
	_next_allowed_real = 0.0
	event_serial = 0
	resolution_serial = 0
	feed_serial = 0
	last_result = {}
	combo = 0
	best_combo = 0
	correct_answers = 0
	wrong_answers = 0
	missed_questions = 0
	reactions = 0
	_next_event = float(_config.first_event_seconds)
	_next_ambient = float(_config.first_ambient_seconds)
	_deadline = 0.0
	_sequence_index = 0
	_ambient_index = 0
	_pool_indices = {}
	_stopped = false
	_push_feed(_content.welcome)

func is_calm() -> bool:
	var cycle := float(_config.activity_cycle_seconds)
	return fmod(elapsed, cycle) >= cycle - float(_config.calm_seconds) - 0.000001

func seconds_left() -> float:
	return maxf(0.0, _deadline - real_elapsed) if not active.is_empty() else 0.0

func next_event_in() -> float:
	return maxf(0.0, _next_event - elapsed)

func advance(game_delta: float, real_delta: float, allow_spawn: bool = true) -> float:
	if _stopped or game_delta <= 0.0:
		return 0.0
	elapsed += game_delta
	real_elapsed += real_delta
	var hype_delta := 0.0
	if not active.is_empty() and real_elapsed >= _deadline - 0.000001:
		var was_quiz: bool = active.kind == "quiz"
		if was_quiz:
			combo = 0
			missed_questions += 1
		hype_delta = -float(_config.quiz_hype_penalty) if was_quiz else 0.0
		_resolve("timeout" if was_quiz else "ignored", hype_delta)
	if not allow_spawn:
		return hype_delta
	if elapsed >= _next_ambient:
		var messages: Array = _content.ambient
		_push_feed(messages[_ambient_index % messages.size()])
		_ambient_index += 1
		_next_ambient = elapsed + float(_config.ambient_interval_seconds) * (2.0 if is_calm() else 1.0)
	if active.is_empty() and elapsed >= _next_event and real_elapsed >= _next_allowed_real and not is_calm():
		_spawn_event()
	return hype_delta

func answer(serial: int, choice: int) -> bool:
	if _stopped or active.is_empty() or serial != event_serial or seconds_left() <= 0.0:
		return false
	var answers: Array = active.answers
	if choice < 0 or choice >= answers.size():
		return false
	if active.kind == "quiz":
		if choice == int(active.correct):
			correct_answers += 1
			combo += 1
			best_combo = maxi(best_combo, combo)
			_resolve("correct", float(_config.quiz_hype_reward))
		else:
			wrong_answers += 1
			combo = 0
			_resolve("wrong", -float(_config.quiz_hype_penalty))
	else:
		reactions += 1
		var reward := float(_config.poll_hype_reward) if active.kind == "poll" else float(_config.decor_hype_reward)
		_resolve("reaction", reward)
	return true

func finish() -> void:
	_stopped = true
	active = {}

func _spawn_event() -> void:
	var sequence: Array = _content.sequence
	var kind: String = sequence[_sequence_index % sequence.size()]
	_sequence_index += 1
	var pool: Array = _content[kind]
	var index := int(_pool_indices.get(kind, 0))
	_pool_indices[kind] = index + 1
	active = pool[index % pool.size()].duplicate(true)
	event_serial += 1
	active["serial"] = event_serial
	_deadline = real_elapsed + float(_config.answer_seconds)
	_next_event = elapsed + float(_config.event_interval_seconds)
	_push_feed({"author": active.author, "text": active.text})

func _resolve(outcome: String, hype_delta: float) -> void:
	_next_allowed_real = real_elapsed + float(_config.reply_cooldown_real_seconds)
	resolution_serial += 1
	last_result = {"outcome": outcome, "hype_delta": hype_delta, "correct_text": "", "combo": combo, "resolved_at": elapsed}
	if active.kind == "quiz":
		last_result.correct_text = active.answers[int(active.correct)]
	_push_feed({"author": active.author, "text": _content.replies[outcome]})
	active = {}

func _push_feed(message: Dictionary) -> void:
	feed.append(message.duplicate(true))
	if feed.size() > 3:
		feed.pop_front()
	feed_serial += 1
