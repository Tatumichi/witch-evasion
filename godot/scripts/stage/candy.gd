extends Area2D
## 茶トラが飛ばすキャンディ（仮グラフィック）。
## 小さな障害物（group "breakable"）を壊し、ボス（group "boss"）に当たると満足ゲージを増やす。
## 大きな障害物には吸い込まれて消えるだけ。

signal broke(target: Area2D)
signal fed(target: Area2D)

const COLORS := [Color(1.0, 0.55, 0.72), Color(0.55, 0.85, 1.0), Color(1.0, 0.85, 0.4)]

var vel := Vector2(0.0, -720.0)
var _t := 0.0
var _col := COLORS[0]
var _done := false


func setup(start: Vector2, velocity_px: Vector2, index: int) -> void:
	position = start
	vel = velocity_px
	_col = COLORS[index % COLORS.size()]
	collision_layer = 16
	collision_mask = 2
	var s := CircleShape2D.new()
	s.radius = 9.0
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if _done:
		return
	if area.is_in_group("boss"):
		if area.has_method("feed"):
			area.call("feed")
		fed.emit(area)
		_pop()
	elif area.is_in_group("breakable"):
		area.call("break_apart")
		broke.emit(area)
		_pop()
	elif area.is_in_group("obstacles"):
		_pop()


func _pop() -> void:
	_done = true
	set_deferred("monitoring", false)
	queue_free()


func _physics_process(delta: float) -> void:
	_t += delta
	position += vel * delta
	if position.y < -40.0 or position.x < -40.0 or position.x > 580.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _t * 8.0, Vector2.ONE)
	draw_colored_polygon(PackedVector2Array([Vector2(-6.0, 0.0), Vector2(-14.0, -6.0), Vector2(-14.0, 6.0)]), _col)
	draw_colored_polygon(PackedVector2Array([Vector2(6.0, 0.0), Vector2(14.0, -6.0), Vector2(14.0, 6.0)]), _col)
	draw_circle(Vector2.ZERO, 7.0, _col)
	draw_arc(Vector2.ZERO, 4.0, 0.0, PI * 1.4, 10, Color.WHITE, 2.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
