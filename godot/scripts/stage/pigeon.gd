extends Area2D
## 鳩（仮グラフィック）。ステージ側が 8 マスに 7 羽並べ、1 マス分のすき間を空けて降らせる。
## キャンディが当たると驚いて飛び去る（壊れるのではなく逃げる）。

const BODY := Color(0.72, 0.72, 0.82)
const WING := Color(0.56, 0.56, 0.68)
const NECK := Color(0.52, 0.74, 0.70)
const LINE := Color(0.22, 0.18, 0.30, 0.85)
const RADIUS := 22.0

var fall := 230.0
var _t := 0.0
var _phase := 0.0
var _facing := 1.0
var _fleeing := false
var _flee_vel := Vector2.ZERO


func setup(start: Vector2, fall_speed: float, rng: RandomNumberGenerator) -> void:
	position = start
	fall = fall_speed
	_phase = rng.randf() * TAU
	_facing = 1.0 if rng.randf() < 0.5 else -1.0
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	add_to_group("breakable")
	var s := CircleShape2D.new()
	s.radius = RADIUS
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)


func break_apart() -> void:
	if _fleeing:
		return
	_fleeing = true
	remove_from_group("obstacles")
	remove_from_group("breakable")
	set_deferred("monitorable", false)
	_flee_vel = Vector2(randf_range(160.0, 260.0) * _facing, -280.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	if _fleeing:
		position += _flee_vel * delta
		return
	position.y += fall * delta
	position.x += sin(_t * 1.4 + _phase) * 8.0 * delta
	if position.y > 1060.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var f := _facing
	var flap := sin(_t * (16.0 if _fleeing else 10.0) + _phase)
	# 胴と頭
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1.0))
	draw_circle(Vector2(-2.0, 4.0), 15.0, BODY)
	draw_circle(Vector2(12.0, -8.0), 9.0, BODY)
	draw_circle(Vector2(8.0, -1.0), 6.0, NECK)
	draw_colored_polygon(PackedVector2Array([Vector2(20.0, -9.0), Vector2(27.0, -6.0), Vector2(20.0, -5.0)]), Color(0.95, 0.7, 0.45))
	draw_circle(Vector2(14.0, -10.0), 1.8, LINE)
	# しっぽ
	draw_colored_polygon(PackedVector2Array([Vector2(-14.0, 2.0), Vector2(-28.0, -2.0), Vector2(-26.0, 10.0)]), WING)
	# 羽ばたく翼
	var tip := Vector2(-10.0, -6.0 - flap * 18.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-8.0, 0.0), Vector2(6.0, -2.0), tip]), WING)
	draw_arc(Vector2(-2.0, 4.0), 15.0, 0.0, TAU, 20, LINE, 1.4, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
