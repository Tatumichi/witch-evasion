extends Node2D
## その場で広がって消えるリング。被弾や回収のフィードバック用。

var color := Color(1.0, 0.9, 0.6)
var radius_from := 8.0
var radius_to := 50.0
var duration := 0.35
var width := 3.0

var _life := 0.0


func setup(pos: Vector2, c: Color, to_radius: float, dur := 0.35) -> void:
	position = pos
	color = c
	radius_to = to_radius
	duration = dur
	z_index = 5


func _process(delta: float) -> void:
	_life += delta
	if _life >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_life / duration, 0.0, 1.0)
	var r := lerpf(radius_from, radius_to, ease(k, 0.4))
	var a := (1.0 - k) * 0.9
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color.r, color.g, color.b, a), width, true)
