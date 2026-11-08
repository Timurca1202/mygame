extends RefCounted
## Pure session simulation. No nodes, UI, wall clock, or persistent rewards.

const Chat = preload("res://src/stream/stream_chat.gd")
const Income = preload("res://src/economy/stream_income.gd")

enum State { READY, LIVE, PAUSED, FINISHED }
enum EndReason { NONE, COMPLETED, OVERHEATED, EARLY }

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
var viewer_cap := INF
var device_quality := -1.0
var device_id := ""
var cooling_ratio := 0.0
var active_cooling_available := false
var cooling_lock_remaining := 0.0
var cooling_cooldown_remaining := 0.0
var cooling_uses := 0
var hot_game_seconds := 0.0
var viral_serial := 0
var viral_started_at := -1.0
var viral_resolved_at := -INF
var viral_outcome := ""
var viral_caught := 0
var viral_hype_gain := 0.0
var _viral_spawned := false
var _lag_elapsed := 0.0
var chat: RefCounted
var income: RefCounted
var _config: Dictionary
var _taps: Array[float] = []
var _last_tap := -INF
var _last_activity := -INF

func _init(config: Dictionary, chat_content: Dictionary = {}, donors: Array = []) -> void:
	_config = config.duplicate(true)
	viewers = float(config.economy.viewers)
	viewer_cap = float(config.get("viewer_cap", INF))
	device_quality = float(config.get("device_quality", -1.0))
	device_id = str(config.get("device_id", ""))
	cooling_ratio = clampf(float(config.get("cooling_ratio", 0.0)), 0.0, float(config.get("max_cooling_ratio", 0.6)))
	active_cooling_available = bool(config.get("active_cooling_available", false))
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
	cooling_lock_remaining = 0.0
	cooling_cooldown_remaining = 0.0
	cooling_uses = 0
	hot_game_seconds = 0.0
	viral_started_at = -1.0
	viral_resolved_at = -INF
	viral_outcome = ""
	viral_caught = 0
	viral_hype_gain = 0.0
	_viral_spawned = false
	_lag_elapsed = 0.0
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
	if state != State.LIVE or cooling_lock_remaining > 0.000001 or is_lagging():
		return
	tap_count += 1
	_last_tap = elapsed_real
	_last_activity = elapsed_real
	_taps.append(elapsed_real)
	_change_hype(float(_config.hype_per_tap))

func cool_device() -> bool:
	if state != State.LIVE or not active_cooling_available or cooling_cooldown_remaining > 0.000001 or heat <= 0.0:
		return false
	heat = maxf(0.0, heat - float(_config.active_cooling.heat_drop))
	if heat < float(_config.heat_thresholds[1]):
		_lag_elapsed = 0.0
	cooling_lock_remaining = float(_config.active_cooling.tap_lock_seconds)
	cooling_cooldown_remaining = float(_config.active_cooling.cooldown_seconds)
	cooling_uses += 1
	# Buffered taps must not continue accelerating while the player cools the phone.
	_taps.clear()
	_last_tap = -INF
	return true

func is_lagging() -> bool:
	return state == State.LIVE and heat >= float(_config.heat_thresholds[1]) and fmod(_lag_elapsed, float(_config.lag.cycle_seconds)) < float(_config.lag.freeze_seconds)

func quality_multiplier() -> float:
	return 1.0 - float(_config.lag.quality_loss) * hot_game_seconds / maxf(elapsed_game, 0.000001)

func block_spam(serial: int) -> bool:
	if state != State.LIVE or chat == null or not chat.block_spam(serial):
		return false
	_last_activity = elapsed_real
	return true

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

func viral_seconds_left() -> float:
	return maxf(0.0, viral_started_at + float(_config.viral_moment.catch_seconds) - elapsed_real) if viral_started_at >= 0.0 else 0.0

func catch_viral(serial: int) -> bool:
	if state != State.LIVE or serial != viral_serial or viral_seconds_left() <= 0.000001:
		return false
	viral_caught += 1
	viral_started_at = -1.0
	viral_outcome = "caught"
	viral_resolved_at = elapsed_real
	_last_activity = elapsed_real
	var before := hype
	_change_hype(float(_config.viral_moment.hype_reward))
	viral_hype_gain = hype - before
	return true

func _advance_viral() -> void:
	if state != State.LIVE:
		viral_started_at = -1.0
		return
	var spawn_at := float(_config.get("viral_spawn_real_seconds", -1.0))
	if not _viral_spawned and spawn_at >= 0.0 and elapsed_real >= spawn_at - 0.000001:
		_viral_spawned = true
		viral_serial += 1
		viral_started_at = spawn_at
	if viral_started_at >= 0.0 and viral_seconds_left() <= 0.000001:
		viral_started_at = -1.0
		viral_outcome = "missed"
		viral_resolved_at = elapsed_real

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

func exit_penalty_ratio() -> float:
	if duration <= 0.0 or elapsed_game + 0.000001 >= duration * float(_config.exit.safe_completion_ratio):
		return 0.0
	var remaining := clampf(1.0 - elapsed_game / duration, 0.0, 1.0)
	return float(_config.exit.follower_base_loss_ratio) + float(_config.exit.follower_remaining_loss_ratio) * remaining

func has_exit_penalty() -> bool:
	return (end_reason == EndReason.EARLY or end_reason == EndReason.OVERHEATED) and exit_penalty_ratio() > 0.0

func finish_early() -> bool:
	if state != State.LIVE and state != State.PAUSED:
		return false
	end_reason = EndReason.EARLY
	state = State.FINISHED
	_finalize()
	return true

func _finalize() -> void:
	viral_started_at = -1.0
	if chat != null:
		chat.finish()
	income.finish()
	if has_exit_penalty():
		hype = 0.0

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
	heat_per_game_second *= (1.0 - cooling_ratio) * float(_config.heat_gain_multiplier)
	var game_step := speed * delta
	var to_overheat := maxf(0.0, (100.0 - heat) / heat_per_game_second)
	var to_completion := maxf(0.0, duration - elapsed_game)
	game_step = minf(game_step, minf(to_overheat, to_completion))
	elapsed_game += game_step
	var real_step := game_step / speed
	elapsed_real += real_step
	cooling_lock_remaining = maxf(0.0, cooling_lock_remaining - real_step)
	cooling_cooldown_remaining = maxf(0.0, cooling_cooldown_remaining - real_step)
	heat = minf(100.0, heat + heat_per_game_second * game_step)
	var hot_step := minf(game_step, maxf(0.0, (heat - float(_config.heat_thresholds[1])) / heat_per_game_second))
	hot_game_seconds += hot_step
	_lag_elapsed = _lag_elapsed + hot_step / speed if heat >= float(_config.heat_thresholds[1]) else 0.0
	var decay := float(_config.hype_idle_decay_per_second) if is_hype_cooling() else float(_config.hype_decay_per_second)
	_change_hype(-decay * game_step / speed)
	var quality := 1.0 - float(_config.lag.quality_loss) * hot_step / maxf(game_step, 0.000001)
	income.advance(game_step, game_step / speed, quality)
	# At the exact scheduled finish, completion wins a simultaneous heat boundary.
	if elapsed_game >= duration - 0.000001:
		elapsed_game = duration
		end_reason = EndReason.COMPLETED
		state = State.FINISHED
	elif heat >= 100.0 - 0.000001:
		heat = 100.0
		end_reason = EndReason.OVERHEATED
		state = State.FINISHED
	_advance_viral()
	if chat != null:
		var before := hype
		var change: float = chat.advance(game_step, game_step / speed, state == State.LIVE)
		_change_hype(change)
		if change != 0.0:
			chat.last_result.hype_delta = hype - before
	if state == State.FINISHED:
		_finalize()
