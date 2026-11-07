extends RefCounted
## Pure session simulation. No nodes, UI, wall clock, or persistent rewards.

const Chat = preload("res://src/stream/stream_chat.gd")
const Income = preload("res://src/economy/stream_income.gd")

enum State { READY, LIVE, PAUSED, FINISHED }
enum EndReason { NONE, COMPLETED, OVERHEATED }

var state := State.READY
var end_reason := EndReason.NONE
var elapsed_game := 0.0
var elapsed_real := 0.0
var duration := 0.0
var speed := 2.0
var hype := 0.0
var peak_hype := 0.0
var heat := 0.0
var tap_count := 0
var viewers := 3.0
var chat: RefCounted
var income: RefCounted
var _config: Dictionary
var _taps: Array[float] = []
var _last_tap := -INF
var _last_activity := -INF

func _init(config: Dictionary, chat_content: Dictionary = {}, donors: Array = []) -> void:
	_config = config.duplicate(true)
	viewers = float(config.economy.viewers)
	speed = float(_config.base_speed)
	if not chat_content.is_empty():
		chat = Chat.new(config.chat, chat_content)
	income = Income.new(config.economy, donors)

func start(planned_seconds: float) -> bool:
	if state == State.LIVE or state == State.PAUSED:
		return false
	if not is_finite(planned_seconds) or planned_seconds <= 0.0 or planned_seconds > float(_config.device_capacity_seconds):
		return false
	duration = planned_seconds
	elapsed_game = 0.0
	elapsed_real = 0.0
	speed = float(_config.base_speed)
	hype = 0.0
	peak_hype = 0.0
	heat = 0.0
	tap_count = 0
	_taps.clear()
	_last_tap = -INF
	_last_activity = -INF
	if chat != null:
		chat.reset()
	income.start(planned_seconds)
	end_reason = EndReason.NONE
	state = State.LIVE
	return true

func tap() -> void:
	if state != State.LIVE:
		return
	tap_count += 1
	_last_tap = elapsed_real
	_last_activity = elapsed_real
	_taps.append(elapsed_real)
	_change_hype(float(_config.hype_per_tap))

func answer_chat(serial: int, choice: int) -> bool:
	if state != State.LIVE or chat == null or not chat.answer(serial, choice):
		return false
	_last_activity = elapsed_real
	var before := hype
	_change_hype(float(chat.last_result.hype_delta))
	chat.last_result.hype_delta = hype - before
	if chat.last_result.outcome == "correct":
		income.reward_correct_answer(chat.combo)
	return true

func thank_donation(serial: int) -> bool:
	if state != State.LIVE or not income.thank(serial):
		return false
	_last_activity = elapsed_real
	return true

func is_hype_cooling() -> bool:
	return state == State.LIVE and hype > 0.0 and elapsed_real - _last_activity >= float(_config.hype_idle_delay_seconds)

func _change_hype(amount: float) -> void:
	hype = clampf(hype + amount, 0.0, 100.0)
	peak_hype = maxf(peak_hype, hype)

func pause() -> void:
	if state == State.LIVE:
		state = State.PAUSED

func resume() -> void:
	if state == State.PAUSED:
		state = State.LIVE

func advance(delta: float) -> void:
	if state != State.LIVE or not is_finite(delta) or delta <= 0.0:
		return
	# Bound integration error and stop exactly at the first terminal event.
	var remaining := delta
	while remaining > 0.000001 and state == State.LIVE:
		var step_seconds := minf(remaining, 0.02)
		_step(step_seconds)
		remaining -= step_seconds

func _step(delta: float) -> void:
	while not _taps.is_empty() and elapsed_real - _taps[0] > float(_config.tap_window_seconds):
		_taps.pop_front()
	var base := float(_config.base_speed)
	var target := base + (float(_config.max_speed) - base) * clampf(
		float(_taps.size()) / float(_config.tap_saturation), 0.0, 1.0)
	if target > speed:
		speed = move_toward(speed, target, float(_config.speed_acceleration) * delta)
	elif elapsed_real - _last_tap >= float(_config.tap_grace_seconds):
		speed = move_toward(speed, target, float(_config.speed_deceleration) * delta)
	var heat_per_game_second := 100.0 / float(_config.device_capacity_seconds) * pow(
		speed / base, float(_config.heat_exponent))
	var game_step := speed * delta
	var to_overheat := maxf(0.0, (100.0 - heat) / heat_per_game_second)
	var to_completion := maxf(0.0, duration - elapsed_game)
	game_step = minf(game_step, minf(to_overheat, to_completion))
	elapsed_game += game_step
	elapsed_real += game_step / speed
	heat = minf(100.0, heat + heat_per_game_second * game_step)
	var decay := float(_config.hype_idle_decay_per_second) if is_hype_cooling() else float(_config.hype_decay_per_second)
	_change_hype(-decay * game_step / speed)
	income.advance(game_step, game_step / speed)
	if heat >= 100.0 - 0.000001:
		heat = 100.0
		end_reason = EndReason.OVERHEATED
		state = State.FINISHED
	elif elapsed_game >= duration - 0.000001:
		elapsed_game = duration
		end_reason = EndReason.COMPLETED
		state = State.FINISHED
	if chat != null:
		var before := hype
		var change: float = chat.advance(game_step, game_step / speed, state == State.LIVE)
		_change_hype(change)
		if change != 0.0:
			chat.last_result.hype_delta = hype - before
		if state == State.FINISHED:
			chat.finish()
	if state == State.FINISHED:
		income.finish()
