extends RefCounted
## GDD §8.5 formulas; independent of UI, persistence and animation.
var config: Dictionary

func _init(parameters: Dictionary) -> void:
	config = parameters.duplicate(true)

func organic(followers: float) -> float:
	return float(config.organic_base) + float(config.organic_factor) * pow(maxf(0.0, followers), float(config.organic_exponent))

func online_ratio(followers: float) -> float:
	for tier in config.online_tiers:
		if followers < float(tier[0]):
			return float(tier[1])
	return float(config.online_tiers[-1][1])

func audience(followers: float, score: float) -> float:
	return minf(target_audience(followers, score), float(config.viewer_cap))

func target_audience(followers: float, score: float) -> float:
	return (organic(followers) + followers * online_ratio(followers)) * (0.5 + clampf(score, 0.0, 100.0) / 100.0)

func follower_gain(followers: float, score: float, game_seconds: float) -> float:
	if game_seconds <= 0.0:
		return 0.0
	var g := float(config.growth_base) + pow(clampf(score, 0.0, 100.0) / 100.0, float(config.growth_exponent)) * float(config.growth_factor)
	var length_factor := sqrt(game_seconds / 60.0 / float(config.length_reference_minutes))
	var cap_factor := pow(minf(1.0, float(config.viewer_cap) / target_audience(followers, score)), float(config.cap_exponent))
	return followers * g * length_factor * cap_factor + organic(followers)

func vibe(inventory: Array) -> int:
	var total := 0
	for item in config.items:
		if inventory.has(str(item.id)):
			total += int(item.vibe)
	return total

func performance(session: RefCounted, inventory: Array) -> float:
	var quizzes: int = session.chat.correct_answers + session.chat.wrong_answers + session.chat.missed_questions
	var accuracy := float(session.chat.correct_answers) / quizzes if quizzes > 0 else 0.0
	var tapping := clampf(session.tap_count / maxf(1.0, session.elapsed_real * float(config.tap_activity_per_second)), 0.0, 1.0)
	var gratitude: float = float(session.income.thanked_count) / session.income.donation_count if session.income.donation_count > 0 else 0.0
	var activity: float = accuracy * float(config.activity_weights.chat) + tapping * float(config.activity_weights.taps) + gratitude * float(config.activity_weights.thanks)
	var components := {
		"activity": activity * 100.0,
		"equipment": clampf(float(config.equipment_quality) / float(config.epoch_quality_reference), 0.0, 1.0) * 100.0,
		"packaging": float(config.starter_packaging_score),
		"decor": clampf(vibe(inventory) / float(config.vibe_for_full_score), 0.0, 1.0) * 100.0,
		"reputation": float(config.starting_reputation_score)}
	var score := 0.0
	for key in components:
		score += float(components[key]) * float(config.score_weights[key])
	return clampf(score, 0.0, 100.0)

func item(item_id: String) -> Dictionary:
	for entry in config.items:
		if str(entry.id) == item_id:
			return entry
	return {}

func buy(wallet: RefCounted, item_id: String) -> Error:
	var entry := item(item_id)
	return ERR_INVALID_PARAMETER if entry.is_empty() else wallet.buy(item_id, int(entry.price_units))

func sell(wallet: RefCounted, item_id: String) -> Error:
	var entry := item(item_id)
	return ERR_INVALID_PARAMETER if entry.is_empty() else wallet.sell(item_id, int(floor(float(entry.price_units) * float(config.sale_ratio))))
