extends Node2D
## Presentation adapter: observes a session, never changes the simulation.
const Session = preload("res://src/stream/stream_session.gd")
var clock := 0.0
var live := false
var frozen := false
var heat := 0.0
var hype := 0.0
var _session: RefCounted
var _taps := 0
var _answers := 0
var _thanks := 0
var _activity: Node2D
class PhoneActivity extends Node2D:
	func _draw() -> void:
		get_parent().draw_activity(self)

@onready var hero: Node2D = $Furniture/SeatedHero
@onready var breathing: AnimationPlayer = $Furniture/SeatedHero/IdleAnimation
@onready var dust: AnimationPlayer = $WindowDust/DriftAnimation

func _ready() -> void:
	_activity = PhoneActivity.new()
	_activity.name = "PhoneActivity"
	add_child(_activity)

func sync_session(session: RefCounted) -> void:
	if _session != session or session.tap_count < _taps:
		_session = session
		_taps = 0
		_answers = 0
		_thanks = 0
		hero.reaction_time = 100.0
		hero.heat = 0.0
	live = session.state == Session.State.LIVE
	frozen = session.state == Session.State.PAUSED
	heat = session.heat
	hype = session.hype
	hero.frozen = frozen
	hero.heat = heat
	breathing.speed_scale = 0.0 if frozen else 1.0
	dust.speed_scale = 0.0 if frozen else 1.0
	if live:
		if session.tap_count > _taps:
			hero.react("tap")
		if session.chat.resolution_serial > _answers:
			var outcome: String = session.chat.last_result.outcome
			if outcome == "correct" or outcome == "reaction":
				hero.react("correct")
			elif outcome == "wrong" or outcome == "timeout":
				hero.react("wrong")
		if session.income.thanked_count > _thanks:
			hero.react("thanks")
	_taps = session.tap_count
	_answers = session.chat.resolution_serial
	_thanks = session.income.thanked_count
	_activity.queue_redraw()

func _process(delta: float) -> void:
	if not frozen:
		clock += delta
		_activity.queue_redraw()

func draw_activity(canvas: Node2D) -> void:
	if not live and not frozen:
		return
	# Reflected screen light on the existing phone, with a tiny audio meter.
	var hot := smoothstep(60.0, 95.0, heat)
	var tint := Color("6ee8f3").lerp(Color("ff805c"), hot)
	for i in range(3):
		var alpha := (0.025 + hype * 0.0004) * (1.0 - float(i) / 3.0)
		canvas.draw_circle(Vector2(340, 424), 7.0 + i * 4.0, Color(tint, alpha))
	for i in range(3):
		var height: float = 1.0 + floorf((sin(clock * (5.0 + i) + i * 2.0) * 0.5 + 0.5) * (2.0 + hype * 0.035))
		canvas.draw_rect(Rect2(337 + i * 2, 428 - height, 1, height), Color(tint, 0.65))
