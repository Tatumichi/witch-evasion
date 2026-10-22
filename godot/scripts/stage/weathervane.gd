extends Area2D
## 屋根から外れて落ちてくる小さな風見鶏（仮グラフィック）。くるくる回りながら速めに落ちる。
## 画面上に入る前は、上端に「！」の予告を出す。キャンディで壊せる。

const IRON := Color(0.24, 0.20, 0.30)
const GOLD := Color(0.95, 0.76, 0.36)
const WARN := Color(1.0, 0.5, 0.42)

var vel := Vector2.ZERO
var _spin := 3.0
var _t := 0.0
var _broken := false


func setup(start: Vector2, velocity_px: Vector2, rng: RandomNumberGenerator) -> void:
	position = start
	vel = velocity_px
	_spin = rng.randf_range(3.0, 5.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	add_to_group("breakable")
	var s := CircleShape2D.new()
	s.radius = 20.0
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)


func break_apart() -> void:
	if _broken:
		return
	_broken = true
	remove_from_group("obstacles")
	remove_from_group("breakable")
	set_deferred("monitorable", false)
	vel = Vector2(vel.x, -160.0)
	_spin *= 3.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	position += vel * delta
	if position.y > 1060.0 or position.x < -120.0 or position.x > 660.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# 画面外にいる間は上端に予告を出す（回転させない）
	if position.y < 6.0 and not _broken:
		var y := -position.y + 18.0
		var a := 0.5 + 0.5 * sin(_t * 18.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12.0, y - 10.0), Vector2(12.0, y - 10.0), Vector2(0.0, y + 10.0),
		]), Color(WARN.r, WARN.g, WARN.b, a))
		return

	draw_set_transform(Vector2.ZERO, _t * _spin, Vector2.ONE)
	# 矢印
	draw_line(Vector2(-26.0, 10.0), Vector2(26.0, 10.0), IRON, 4.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(26.0, 3.0), Vector2(38.0, 10.0), Vector2(26.0, 17.0)]), IRON)
	draw_colored_polygon(PackedVector2Array([Vector2(-26.0, 10.0), Vector2(-36.0, 2.0), Vector2(-30.0, 10.0), Vector2(-36.0, 18.0)]), IRON)
	# 小さな鶏
	draw_circle(Vector2(0.0, -4.0), 10.0, IRON)
	draw_circle(Vector2(9.0, -14.0), 6.0, IRON)
	draw_colored_polygon(PackedVector2Array([Vector2(-8.0, -6.0), Vector2(-20.0, -20.0), Vector2(-16.0, 0.0)]), IRON)
	draw_circle(Vector2(9.0, -21.0), 3.0, Color(0.9, 0.3, 0.3))
	draw_arc(Vector2(0.0, -4.0), 10.0, PI, TAU, 12, GOLD, 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
