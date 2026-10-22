extends Node2D
## 小麦粉の白い粉（STAGE 2 ボス）。当たり判定はなく、ふわっと広がって視界をふさぎ、数秒で消える。
## 画像は使わない（半透明の円を重ねて描く。画面を覆う大きさで、画像にすると縁が目立つため）。
## メルルや障害物より手前に描く。下へ流れていく。

const DURATION := 4.0

var fall := 120.0
var _t := 0.0
var _puffs: Array = []


func setup(pos: Vector2) -> void:
	position = pos
	z_index = 20
	for i in 12:
		var a := randf() * TAU
		_puffs.append({"o": Vector2(cos(a), sin(a)) * randf_range(0.0, 70.0), "r": randf_range(40.0, 72.0)})


func _process(delta: float) -> void:
	_t += delta
	position.y += fall * delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var grow := minf(_t / 0.35, 1.0)
	var a := 0.82 * clampf((DURATION - _t) / 1.2, 0.0, 1.0)
	for p in _puffs:
		draw_circle(p["o"] * grow, float(p["r"]) * (0.5 + 0.5 * grow), Color(0.99, 0.98, 0.95, a * 0.55))
	draw_circle(Vector2.ZERO, 60.0 * grow, Color(1.0, 1.0, 0.98, a * 0.6))
