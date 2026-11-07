extends Node2D
## Local articulation only: hands, pelvis and feet retain their authored anchors.
var reaction := "idle"
var reaction_time := 0.0
var clock := 0.0
var heat := 0.0
var frozen := false
var _duration := 0.0
var _priority := 0
@onready var body_material: ShaderMaterial = $Body.material

func react(kind: String) -> void:
	var priority := 1 if kind == "tap" else 2
	if kind == "thanks":
		priority = 3
	if reaction_time < _duration and (priority < _priority or (priority == 1 and _priority == 1)):
		return
	reaction = kind
	reaction_time = 0.0
	_priority = priority
	_duration = {"tap": 0.36, "correct": 0.85, "wrong": 1.0, "thanks": 1.45}.get(kind, 0.6)

func _process(delta: float) -> void:
	advance_pose(delta)

func advance_pose(delta: float) -> void:
	if frozen:
		return
	clock += delta
	reaction_time += delta
	var nod := 0.0
	var shift := 0.0
	var shoulder := 0.0
	if reaction_time < _duration:
		var phase := reaction_time / _duration
		var envelope := sin(PI * phase)
		match reaction:
			"tap":
				nod = 0.065 * envelope
				shoulder = 5.0 * envelope
			"correct":
				nod = 0.15 * sin(TAU * phase) * envelope
				shoulder = 8.0 * envelope
			"wrong":
				shift = 16.0 * sin(TAU * 2.0 * phase) * envelope
				nod = -0.04 * envelope
			"thanks":
				nod = 0.20 * pow(sin(TAU * phase), 2.0) * envelope
				shoulder = -6.0 * envelope
	else:
		reaction = "idle"
		_priority = 0
	var fatigue := smoothstep(65.0, 95.0, heat)
	nod += fatigue * (0.10 + 0.025 * sin(clock * 2.1))
	body_material.set_shader_parameter("head_angle", nod)
	body_material.set_shader_parameter("head_shift", shift)
	body_material.set_shader_parameter("shoulder_lift", shoulder - fatigue * 4.0)
	queue_redraw()

func _draw() -> void:
	# Two small beads at the temple, only when the phone is hot.
	if heat < 70.0:
		return
	for i in range(2):
		var phase := fmod(clock * 0.6 + i * 0.5, 1.0)
		var tint := Color(0.65, 0.87, 0.92, sin(PI * phase) * 0.85)
		draw_rect(Rect2(Vector2(4 + i * 3, -30 + floor(phase * 7)), Vector2(1, 2)), tint)
