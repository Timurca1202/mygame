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
var _decor: Dictionary = {}
var _air_origins: Array[Vector2] = []
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

func apply_inventory(inventory: Array, items: Array) -> void:
	_air_origins.clear()
	for item in items:
		var id := str(item.id)
		if inventory.has(id) and not _decor.has(id):
			var sprite := Sprite2D.new()
			sprite.name = id.to_pascal_case()
			sprite.texture = load(item.texture)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = Vector2(float(item.position[0]), float(item.position[1]))
			if item.has("display_height"):
				sprite.region_enabled = true
				sprite.region_rect = sprite.texture.get_image().get_used_rect()
				sprite.scale = Vector2.ONE * float(item.display_height) / sprite.region_rect.size.y
			else:
				sprite.scale = Vector2.ONE * float(item.scale)
			sprite.flip_h = bool(item.get("flip_h", false))
			add_child(sprite)
			move_child(sprite, $Furniture.get_index())
			_decor[id] = sprite
		elif not inventory.has(id) and _decor.has(id):
			_decor[id].queue_free()
			_decor.erase(id)
		if inventory.has(id) and item.has("air_origin"):
			_air_origins.append(Vector2(float(item.air_origin[0]), float(item.air_origin[1])))

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
	for origin in _air_origins:
		for i in range(3):
			var phase := fmod(clock * 0.8 + i / 3.0, 1.0)
			var point := origin + Vector2(24, -19) * phase + Vector2(0, (i - 1) * 3)
			canvas.draw_line(point.round(), (point + Vector2(5, -3)).round(), Color(0.72, 0.85, 0.87, sin(PI * phase) * 0.35), 1.0)
	# Reflected screen light on the existing phone, with a tiny audio meter.
	var hot := smoothstep(60.0, 95.0, heat)
	var tint := Color("6ee8f3").lerp(Color("ff805c"), hot)
	for i in range(3):
		var alpha := (0.025 + hype * 0.0004) * (1.0 - float(i) / 3.0)
		canvas.draw_circle(Vector2(340, 424), 7.0 + i * 4.0, Color(tint, alpha))
	for i in range(3):
		var height: float = 1.0 + floorf((sin(clock * (5.0 + i) + i * 2.0) * 0.5 + 0.5) * (2.0 + hype * 0.035))
		canvas.draw_rect(Rect2(337 + i * 2, 428 - height, 1, height), Color(tint, 0.65))
