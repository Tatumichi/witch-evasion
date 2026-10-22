extends Area2D
## 取るとスコアが増える光の星。

var scroll := 260.0
var _t := 0.0


func setup(scroll_speed: float) -> void:
	scroll = scroll_speed
	collision_layer = 4
	collision_mask = 0
	add_to_group("pickups")
	_t = randf() * TAU

	var s := CircleShape2D.new()
	s.radius = 16.0
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)


func _physics_process(delta: float) -> void:
	position.y += scroll * 0.9 * delta
	position.x += sin(_t * 2.0) * 22.0 * delta
	if position.y > 1060.0:
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.82 + sin(_t * 4.0) * 0.18
	var r := 9.0 * pulse

	draw_circle(Vector2.ZERO, r * 2.6, Color(1.0, 0.9, 0.6, 0.04))
	draw_circle(Vector2.ZERO, r * 1.6, Color(1.0, 0.9, 0.65, 0.08))

	var star := Color(1.0, 0.93, 0.62, 0.96)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r * 1.9), Vector2(r * 0.5, 0.0),
		Vector2(0.0, r * 1.9), Vector2(-r * 0.5, 0.0),
	]), star)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 1.9, 0.0), Vector2(0.0, r * 0.5),
		Vector2(r * 1.9, 0.0), Vector2(0.0, -r * 0.5),
	]), star)
	draw_circle(Vector2.ZERO, r * 0.42, Color(1.0, 1.0, 0.97))
