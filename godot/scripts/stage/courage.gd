extends Area2D
## 勇気のかけら（仮グラフィック）。全ステージ共通の小さな光の粒。

const CORE := Color(1.0, 0.96, 0.72)
const GLOW := Color(0.62, 1.0, 0.86)

var fall := 230.0
var _t := 0.0


func setup(start: Vector2, fall_speed: float) -> void:
	position = start
	fall = fall_speed
	collision_layer = 4
	collision_mask = 0
	add_to_group("courage")
	var s := CircleShape2D.new()
	s.radius = 14.0
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)
	_t = randf() * TAU


func _physics_process(delta: float) -> void:
	position.y += fall * delta
	if position.y > 1000.0:
		queue_free()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var k := 0.85 + 0.15 * sin(_t * 5.0)
	draw_circle(Vector2.ZERO, 13.0 * k, Color(GLOW.r, GLOW.g, GLOW.b, 0.18))
	var r := 7.0 * k
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, -r * 1.5), Vector2(r, 0.0), Vector2(0.0, r * 1.5), Vector2(-r, 0.0),
	]), CORE)
	draw_circle(Vector2.ZERO, r * 0.35, Color.WHITE)
