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

func follower_gain(followers: float, score: float, game_seconds: float, device_cap: float = -1.0) -> float:
	if game_seconds <= 0.0:
		return 0.0
	var g := float(config.growth_base) + pow(clampf(score, 0.0, 100.0) / 100.0, float(config.growth_exponent)) * float(config.growth_factor)
	var length_factor := sqrt(game_seconds / 60.0 / float(config.length_reference_minutes))
	var cap := device_cap if device_cap >= 0.0 else float(config.viewer_cap)
	var cap_factor := pow(minf(1.0, cap / target_audience(followers, score)), float(config.cap_exponent))
	return followers * g * length_factor * cap_factor + organic(followers)

func vibe(inventory: Array) -> int:
	var total := 0
	for item in config.items:
		if inventory.has(str(item.id)):
			total += int(item.vibe)
	return total

func level_progress(total_experience: int) -> Dictionary:
	var rules: Dictionary = config.experience
	var remaining := maxi(0, total_experience)
	var level := 1
	while level < int(rules.max_level):
		var required := int(rules.level_base) + int(rules.level_step) * level
		if remaining < required:
			return {"level": level, "current": remaining, "required": required}
		remaining -= required
		level += 1
	return {"level": level, "current": 0, "required": 0}

func maximum_experience() -> int:
	var rules: Dictionary = config.experience
	var transitions := int(rules.max_level) - 1
	return int(rules.level_base) * transitions + int(rules.level_step) * transitions * (transitions + 1) / 2

func stream_experience(session: RefCounted, score: float, current_experience: int) -> int:
	if not is_finite(score) or session.elapsed_game <= 0.0:
		return 0
	var rules: Dictionary = config.experience
	var rate := float(rules.hourly_base) + float(rules.hourly_quality_bonus) * clampf(score, 0.0, 100.0) / 100.0
	var reward: float = rate * float(session.elapsed_game) / 3600.0
	if session.has_exit_penalty():
		reward *= float(rules.early_multiplier)
	return mini(maxi(0, maximum_experience() - current_experience), int(floor(reward + 0.000001)))

func cooling(inventory: Array) -> float:
	# Cooling equipment uses the strongest owned tier; duplicates never stack.
	var ratio := 0.0
	for entry in config.items:
		if inventory.has(str(entry.id)):
			ratio = maxf(ratio, float(entry.get("cooling_ratio", 0.0)))
	return clampf(ratio, 0.0, float(config.get("cooling_cap", 0.6)))

func has_active_cooling(inventory: Array) -> bool:
	for entry in config.items:
		if inventory.has(str(entry.id)) and bool(entry.get("active_cooling", false)):
			return true
	return false

func packaging(title_score: float, preview_score: float) -> float:
	return clampf(title_score, 0.0, 100.0) * float(config.packaging_mix.title) + clampf(preview_score, 0.0, 100.0) * float(config.packaging_mix.preview)

func performance_components(session: RefCounted, inventory: Array, packaging_score: float = -1.0) -> Dictionary:
	var quizzes: int = session.chat.correct_answers + session.chat.wrong_answers + session.chat.missed_questions
	var accuracy := float(session.chat.correct_answers) / quizzes if quizzes > 0 else 0.0
	var moderated: int = session.chat.blocked_spam + session.chat.missed_spam
	if moderated > 0:
		accuracy = float(session.chat.correct_answers + session.chat.blocked_spam) / (quizzes + moderated)
	var tapping := clampf(session.tap_count / maxf(1.0, session.elapsed_real * float(config.tap_activity_per_second)), 0.0, 1.0)
	var gratitude: float = float(session.income.thanked_count) / session.income.donation_count if session.income.donation_count > 0 else 0.0
	var activity: float = accuracy * float(config.activity_weights.chat) + tapping * float(config.activity_weights.taps) + gratitude * float(config.activity_weights.thanks)
	var quality: float = session.device_quality if session.device_quality >= 0.0 else float(config.equipment_quality)
	quality *= session.quality_multiplier()
	return {
		"activity": activity * 100.0,
		"equipment": clampf(quality / float(config.epoch_quality_reference), 0.0, 1.0) * 100.0,
		"packaging": clampf(packaging_score, 0.0, 100.0) if packaging_score >= 0.0 else float(config.starter_packaging_score),
		"decor": clampf(vibe(inventory) / float(config.vibe_for_full_score), 0.0, 1.0) * 100.0,
		"reputation": float(config.starting_reputation_score)}

func performance(session: RefCounted, inventory: Array, packaging_score: float = -1.0) -> float:
	var components := performance_components(session, inventory, packaging_score)
	var score := 0.0
	for key in components:
		score += float(components[key]) * float(config.score_weights[key])
	return clampf(score, 0.0, 100.0)

func performance_grade(score: float) -> String:
	for tier in config.result_report.grades:
		if score >= float(tier.minimum):
			return str(tier.name)
	return str(config.result_report.grades[-1].name)

func performance_tip(session: RefCounted, components: Dictionary) -> String:
	if session.has_exit_penalty():
		return config.result_report.tips.early
	if session.chat.missed_spam > session.chat.blocked_spam:
		return config.result_report.tips.moderation
	if session.heat >= float(config.result_report.heat_tip_threshold):
		return config.result_report.tips.heat
	if session.sound_fault_game_seconds > 0.0 and session.sound_fault_repairs == 0:
		return config.result_report.tips.sound_fault
	var weakest := "activity"
	var missing := -1.0
	# Reputation is a fixed baseline until its own system exists.
	for key in ["activity", "equipment", "packaging", "decor"]:
		var gap := (100.0 - float(components[key])) * float(config.score_weights[key])
		if gap > missing:
			missing = gap
			weakest = key
	return config.result_report.tips[weakest]

func item(item_id: String) -> Dictionary:
	for entry in config.items:
		if str(entry.id) == item_id:
			return entry
	return {}

func buy(wallet: RefCounted, item_id: String) -> Error:
	var entry := item(item_id)
	return ERR_INVALID_PARAMETER if entry.is_empty() else wallet.buy(item_id, int(entry.price_units), entry.has("device"))

func sell(wallet: RefCounted, item_id: String) -> Error:
	var entry := item(item_id)
	if bool(entry.get("renovation", false)):
		return ERR_UNAVAILABLE
	return ERR_INVALID_PARAMETER if entry.is_empty() else wallet.sell(item_id, int(floor(float(entry.price_units) * float(config.sale_ratio))))

func selected_device(wallet: RefCounted) -> Dictionary:
	var entry := item(wallet.equipped_device)
	if entry.is_empty() or not entry.has("device") or not wallet.inventory.has(wallet.equipped_device):
		return config.starter_device.duplicate(true)
	return _device_description(entry)

func _device_description(entry: Dictionary) -> Dictionary:
	var description: Dictionary = entry.device.duplicate(true)
	description["id"] = entry.id
	description["name"] = entry.name
	return description

func owned_devices(wallet: RefCounted) -> Array[Dictionary]:
	var result: Array[Dictionary] = [config.starter_device.duplicate(true)]
	for entry in config.items:
		if entry.has("device") and wallet.inventory.has(str(entry.id)):
			result.append(_device_description(entry))
	return result

func equip(wallet: RefCounted, item_id: String) -> Error:
	if not item_id.is_empty() and not item(item_id).has("device"):
		return ERR_INVALID_PARAMETER
	return wallet.select_device(item_id)
