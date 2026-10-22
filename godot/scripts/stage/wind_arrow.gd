extends Area2D
## 大風見鶏が飛ばす矢印型の風向き板（仮グラフィック）。キャンディで壊せる。

const IRON := Color(0.26, 0.21, 0.32)
const GOLD := Color(0.96, 0.78, 0.40)

var vel := Vector2.ZERO
var _broken := false


func setup(start: Vector2, velocity_px: Vector2) -> void:
	position = start
	vel = velocity_px
	rotation = vel.angle()
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	add_to_group("breakable")
	var s := CapsuleShape2D.new()
	s.radius = 9.0
	s.height = 40.0
	var cs := CollisionShape2D.new()
	cs.shape = s
	cs.rotation = PI * 0.5
	add_child(cs)


func break_apart() -> void:
	if _broken:
		return
	_broken = true
	remove_from_group("obstacles")
	remove_from_group("breakable")
	set_deferred("monitorable", false)
	vel *= -0.3
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	position += vel * delta
	if _broken:
		rotation += 10.0 * delta
	if position.y > 1060.0 or position.x < -80.0 or position.x > 620.0:
		queue_free()


func _draw() -> void:
	draw_line(Vector2(-20.0, 0.0), Vector2(14.0, 0.0), IRON, 5.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(12.0, -9.0), Vector2(26.0, 0.0), Vector2(12.0, 9.0)]), IRON)
	draw_colored_polygon(PackedVector2Array([Vector2(-20.0, 0.0), Vector2(-28.0, -9.0), Vector2(-22.0, 0.0), Vector2(-28.0, 9.0)]), IRON)
	draw_line(Vector2(-18.0, -2.0), Vector2(12.0, -2.0), GOLD, 1.5, true)
