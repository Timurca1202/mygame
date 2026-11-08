extends SceneTree
## Small deterministic balance audit, not a campaign-scale calibration.
const Session = preload("res://src/stream/stream_session.gd")
const Progression = preload("res://src/economy/channel_progression.gd")
const OUTPUT := "res://source_art/prototypes/stream/first_steps_balance_v07.json"

func _initialize() -> void:
	var parameters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json"))
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	var chat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json"))
	var donors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/donations.json"))
	var model := Progression.new(parameters)
	var report := {"scope": "first five 15-minute streams, P1, one rug; prototype score, no campaign expenses", "scenarios": []}
	var failures := 0
	for style in ["quiet", "engaged", "forced"]:
		var followers := 0.0
		var balance := 0
		var previous_score := float(parameters.first_stream_score)
		var inventory: Array = []
		var real_total := 0.0
		var first_purchase_minutes := -1.0
		var results: Array = []
		for stream in range(5):
			var run_config := config.duplicate(true)
			run_config.economy.viewers = model.audience(followers, previous_score)
			var session := Session.new(run_config, chat, donors.donors)
			session.start(900.0)
			var steps := 0
			while session.state == Session.State.LIVE:
				if style == "forced" or (style == "engaged" and session.heat < 55.0 and steps % 6 == 0):
					session.tap()
				session.advance(1.0 / 6.0)
				if style == "engaged":
					if not session.chat.active.is_empty():
						session.answer_chat(session.chat.event_serial, int(session.chat.active.get("correct", 0)))
					if not session.income.donation.is_empty():
						session.thank_donation(session.income.donation_serial)
				steps += 1
			var score := model.performance(session, inventory)
			var gain := model.follower_gain(followers, score, session.elapsed_game)
			followers += gain
			balance += session.income.total_units()
			real_total += session.elapsed_real
			if inventory.is_empty() and balance >= int(model.item("thrift_rug").price_units):
				inventory.append("thrift_rug")
				balance -= int(model.item("thrift_rug").price_units)
				first_purchase_minutes = real_total / 60.0
			previous_score = score
			results.append({"stream": stream + 1, "viewers": session.viewers, "score": score, "game_minutes": session.elapsed_game / 60.0, "real_minutes": session.elapsed_real / 60.0, "followers": followers, "gain": gain, "income_dollars": session.income.total_units() / 10000.0, "balance_dollars": balance / 10000.0, "overheated": session.end_reason == Session.EndReason.OVERHEATED})
			if balance < 0 or session.viewers > float(parameters.viewer_cap):
				failures += 1
		report.scenarios.append({"style": style, "first_purchase_real_minutes": first_purchase_minutes, "streams": results})
		print(style, ": first purchase after ", snappedf(first_purchase_minutes, 0.01), " real minutes; followers after five streams=", snappedf(followers, 0.01))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("Balance invariants: ", failures, " failures; report: ", OUTPUT)
	quit(1 if failures else 0)
