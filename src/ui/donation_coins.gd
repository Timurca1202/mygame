extends Node2D
## Small pixel coins fall beside the donation banner; no gameplay state lives here.
var _age := 0.0
const LIFE := 1.1

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for i in range(8):
		var t := clampf((_age - float(i) * 0.035) / LIFE, 0.0, 1.0)
		var x := (float(i) - 3.5) * 15.0 + sin(float(i) * 2.3) * t * 16.0
		var y := -sin(float(i) + 1.0) * 10.0 - 55.0 * t + 140.0 * t * t
		var point := Vector2(x, y).round()
		var alpha := 1.0 - smoothstep(0.45, 1.0, t)
		draw_rect(Rect2(point + Vector2(0, 2), Vector2(8, 8)), Color(0.5, 0.27, 0.08, alpha))
		draw_rect(Rect2(point + Vector2(1, 0), Vector2(6, 10)), Color(1.0, 0.74, 0.22, alpha))
		draw_rect(Rect2(point + Vector2(2, 1), Vector2(2, 6)), Color(1.0, 0.96, 0.61, alpha))
