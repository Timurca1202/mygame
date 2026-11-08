extends RefCounted
## First-stream economy: viewer-hours budget, donation presentation and capped bonuses.
## All posted money uses integer 1/10000-dollar units, never floats in a wallet.
var donation: Dictionary = {}
var donation_serial := 0
var donation_count := 0
var thanked_count := 0
var base_units := 0
var thanks_units := 0
var chat_units := 0
var game_elapsed := 0.0
var real_elapsed := 0.0
var _config: Dictionary
var _donors: Array
var _accrued_units := 0.0
var _requested_chat_units := 0
var _planned_base_units := 0
var _next_donation := 0.0
var _thanks_deadline := 0.0
var _finished := false

func _init(config: Dictionary, donors: Array = []) -> void:
	_config = config.duplicate(true)
	_donors = donors.duplicate(true)

func start(planned_game_seconds: float) -> void:
	donation = {}
	donation_serial = 0
	donation_count = 0
	thanked_count = 0
	base_units = 0
	thanks_units = 0
	chat_units = 0
	game_elapsed = 0.0
	real_elapsed = 0.0
	_accrued_units = 0.0
	_requested_chat_units = 0
	_planned_base_units = int(floor(_base_for_seconds(planned_game_seconds) + 0.000001))
	_next_donation = float(_config.first_donation_game_seconds)
	_thanks_deadline = 0.0
	_finished = false

func _base_for_seconds(seconds: float) -> float:
	return float(_config.viewers) * seconds / 3600.0 * float(_config.money_per_viewer_hour) * float(_config.units_per_dollar)

func advance(game_delta: float, real_delta: float, quality_multiplier: float = 1.0) -> void:
	if _finished:
		return
	game_elapsed += game_delta
	real_elapsed += real_delta
	_accrued_units += _base_for_seconds(game_delta) * clampf(quality_multiplier, 0.0, 1.0)
	if not donation.is_empty() and seconds_left() <= 0.000001:
		donation = {}
	if not _donors.is_empty() and donation.is_empty() and game_elapsed >= _next_donation - 0.000001:
		var amount := maxi(0, int(floor(_accrued_units + 0.000001)) - base_units)
		if amount > 0:
			base_units += amount
			donation_serial += 1
			donation_count += 1
			var donor: Dictionary = _donors[(donation_serial - 1) % _donors.size()]
			donation = {"id": donation_serial, "author": donor.author, "text": donor.text, "amount_units": amount}
			_thanks_deadline = real_elapsed + float(_config.thanks_real_seconds)
		_next_donation = game_elapsed + float(_config.donation_interval_game_seconds)
	_update_chat_bonus()

func seconds_left() -> float:
	return maxf(0.0, _thanks_deadline - real_elapsed) if not donation.is_empty() else 0.0

func thank(serial: int) -> bool:
	if _finished or donation.is_empty() or serial != donation_serial or seconds_left() <= 0.000001:
		return false
	var amount := int(donation.amount_units)
	thanks_units += int(floor(float(amount) * float(_config.thanks_bonus_ratio) + 0.000001))
	thanked_count += 1
	donation = {}
	return true

func reward_correct_answer(combo: int) -> void:
	if _finished:
		return
	var multiplier := minf(float(_config.combo_multiplier_cap), 1.0 + maxf(0.0, float(combo - 1)) * float(_config.combo_bonus_step))
	_requested_chat_units += int(floor(float(_planned_base_units) * float(_config.quiz_bonus_ratio) * multiplier + 0.000001))
	_update_chat_bonus()

func _update_chat_bonus() -> void:
	var earned_base := int(floor(_accrued_units + 0.000001))
	chat_units = mini(_requested_chat_units, int(floor(float(earned_base) * float(_config.chat_bonus_cap_ratio) + 0.000001)))

func finish() -> void:
	if _finished:
		return
	# Settle the last partial donation interval, without inventing extra audience income.
	base_units = int(floor(_accrued_units + 0.000001))
	_update_chat_bonus()
	donation = {}
	_finished = true

func total_units() -> int:
	return base_units + thanks_units + chat_units

func earned_total_units() -> int:
	return int(floor(_accrued_units + 0.000001)) + thanks_units + chat_units
