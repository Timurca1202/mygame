extends SceneTree
const Progression = preload("res://src/economy/channel_progression.gd")
const Session = preload("res://src/stream/stream_session.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/progression/first_steps.json"))
	var model := Progression.new(config)
	for pair in [[0, "D"], [39.999, "D"], [40, "C"], [59.999, "C"], [60, "B"], [74.999, "B"], [75, "A"], [89.999, "A"], [90, "S"], [100, "S"]]:
		check(model.performance_grade(pair[0]) == pair[1], "Grade boundary %s" % pair[0])
	var stream: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/stream/prototype.json"))
	var chat: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chat/first_stream.json"))
	var session := Session.new(stream, chat)
	session.start(900)
	session.advance(5)
	var components := model.performance_components(session, ["thrift_rug"], 80)
	check(components.activity == 0 and components.equipment == 20 and components.packaging == 80 and components.decor == 10 and components.reputation == 50, "Report uses real quiet-stream inputs and explicit reputation baseline")
	var total := 0.0
	for key in components:
		var weighted := float(components[key]) * float(config.score_weights[key])
		check(weighted >= 0 and weighted <= float(config.score_weights[key]) * 100, "Bounded contribution: " + key)
		total += weighted
	check(is_equal_approx(total, model.performance(session, ["thrift_rug"], 80)) and is_equal_approx(total, 27), "Visible weighted components equal unchanged PS formula exactly")
	var complete := {"activity": 100, "equipment": 100, "packaging": 100, "decor": 100, "reputation": 0}
	for key in ["activity", "equipment", "packaging", "decor"]:
		var weak := complete.duplicate()
		weak[key] = 0
		check(model.performance_tip(session, weak) == config.result_report.tips[key], "Actionable tip for weakest weighted area: " + key)
	check(model.performance_tip(session, complete) != "", "Fixed reputation baseline never suggests nonexistent reputation controls")
	session.heat = 90
	check(model.performance_tip(session, complete) == config.result_report.tips.heat, "High heat takes priority over score optimization")
	session.finish_early()
	check(model.performance_tip(session, complete) == config.result_report.tips.early, "Early loss takes priority over generic advice")
	print("Performance report: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
