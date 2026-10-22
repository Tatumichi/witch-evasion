extends Area2D
## 飛んできた洗濯物（仮グラフィック）。
## SHEET: 大きくてゆっくり。キャンディでは壊れない。
## SOCK : 小さくてくるくる回る。キャンディで壊せる。

enum Kind { SHEET, SOCK }

const SHEET_COL := Color(0.97, 0.97, 1.0)
const SHEET_STRIPE := Color(0.62, 0.78, 0.96)
const LINE := Color(0.32, 0.24, 0.36, 0.75)
const SOCK_COLS := [Color(1.0, 0.62, 0.72), Color(0.55, 0.86, 0.74), Color(1.0, 0.86, 0.42)]

var kind: int = Kind.SHEET
var vel := Vector2.ZERO

var _t := 0.0
var _phase := 0.0
var _spin := 0.0
var _col := SHEET_COL
var _broken := false


func setup(k: int, start: Vector2, velocity_px: Vector2, rng: RandomNumberGenerator) -> void:
	kind = k
	position = start
	vel = velocity_px
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	_phase = rng.randf() * TAU

	var cs := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	if kind == Kind.SHEET:
		s.size = Vector2(80.0, 50.0)
	else:
		add_to_group("breakable")
		s.size = Vector2(22.0, 30.0)
		_spin = rng.randf_range(2.0, 4.0) * (1.0 if rng.randf() < 0.5 else -1.0)
		_col = SOCK_COLS[rng.randi() % SOCK_COLS.size()]
	cs.shape = s
	add_child(cs)


func break_apart() -> void:
	if _broken:
		return
	_broken = true
	remove_from_group("obstacles")
	remove_from_group("breakable")
	set_deferred("monitorable", false)
	vel = Vector2(vel.x * 0.3, -120.0)
	_spin *= 4.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	position += vel * delta
	position.y += sin(_t * 2.2 + _phase) * 22.0 * delta   # ひらひら
	if kind == Kind.SHEET:
		rotation = sin(_t * 1.7 + _phase) * 0.18
	else:
		rotation += _spin * delta
	if position.y > 1080.0 or position.x < -200.0 or position.x > 740.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if kind == Kind.SHEET:
		_draw_sheet()
	else:
		_draw_sock()


func _draw_sheet() -> void:
	# 波打つ布。下の辺だけ揺らす。
	var pts := PackedVector2Array()
	var w := 100.0
	var h := 64.0
	for i in 9:
		var x := -w * 0.5 + w * float(i) / 8.0
		pts.append(Vector2(x, -h * 0.5 + sin(_t * 3.0 + float(i)) * 2.0))
	for i in range(8, -1, -1):
		var x := -w * 0.5 + w * float(i) / 8.0
		pts.append(Vector2(x, h * 0.5 + sin(_t * 4.0 + float(i) * 0.9 + _phase) * 6.0))
	draw_colored_polygon(pts, SHEET_COL)
	draw_rect(Rect2(-w * 0.5, -6.0, w, 8.0), SHEET_STRIPE)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, LINE, 2.0, true)
	# 洗濯ばさみ
	draw_rect(Rect2(-34.0, -40.0, 8.0, 12.0), Color(0.95, 0.55, 0.45))
	draw_rect(Rect2(26.0, -40.0, 8.0, 12.0), Color(0.95, 0.55, 0.45))


func _draw_sock() -> void:
	var pts := PackedVector2Array([
		Vector2(-8.0, -18.0), Vector2(8.0, -18.0), Vector2(8.0, 6.0),
		Vector2(16.0, 10.0), Vector2(14.0, 18.0), Vector2(-8.0, 16.0),
	])
	draw_colored_polygon(pts, _col)
	draw_rect(Rect2(-8.0, -18.0, 16.0, 6.0), Color(1.0, 1.0, 1.0, 0.85))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, LINE, 1.6, true)
