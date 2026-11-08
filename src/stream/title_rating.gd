extends RefCounted
## Offline title heuristics, GDD §5.4. Rules and dictionaries live in data.
var config: Dictionary

func _init(parameters: Dictionary) -> void:
	config = parameters.duplicate(true)

func normalize(value: String) -> String:
	return " ".join(value.strip_edges().to_lower().replace("ё", "е").split(" ", false))

func valid(value: String) -> bool:
	return not value.strip_edges().is_empty() and value.length() <= int(config.max_length)

func _matches(value: String, words: Array) -> int:
	var count := 0
	for word in words:
		if value.contains(normalize(str(word))):
			count += 1
	return count

func evaluate(value: String, genre: int, themes: Array, history: Array) -> Dictionary:
	if not valid(value) or genre < 0 or genre >= config.genres.size():
		return {}
	var title := normalize(value)
	var upper := 0
	var letters := 0
	for character in value:
		if character.to_lower() != character.to_upper():
			letters += 1
			if character == character.to_upper():
				upper += 1
	var repeated := false
	for previous in history.slice(-int(config.history_limit)):
		if normalize(str(previous)) == title:
			repeated = true
	var theme_matches := 0
	for index in range(config.themes.size()):
		if themes.has(index) and _matches(title, config.themes[index].keywords) > 0:
			theme_matches += 1
	var weights: Dictionary = config.weights
	var parts := {
		"genre": mini(int(weights.genre), _matches(title, config.genres[genre].keywords) * int(config.genre_points_per_match)),
		"trends": mini(int(weights.trends), _matches(title, config.trends) * int(config.trend_points_per_match)),
		"readability": int(weights.readability) if value.length() >= int(config.ideal_length[0]) and value.length() <= int(config.ideal_length[1]) else 0,
		"clickbait": 0 if value.count("!") > int(config.max_exclamations) or (letters > 0 and float(upper) / letters > float(config.max_uppercase_ratio)) else int(weights.clickbait),
		"freshness": 0 if repeated else int(weights.freshness),
		"themes": mini(int(weights.themes), theme_matches * int(config.theme_points_per_match))}
	var score := 0
	for points in parts.values():
		score += int(points)
	return {"score": score, "parts": parts, "multiplier": lerpf(float(config.audience_range[0]), float(config.audience_range[1]), score / 100.0)}
