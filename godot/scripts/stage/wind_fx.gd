extends Node2D
## 横風の見た目（STAGE 2）。障害物より奥、背景より手前に置く。画像は使わずコードで描く。
##   予告中: 風上の画面端で草と葉がなびき、「≫」が点滅する
##   吹いている間: 画面全体に風の筋と葉が流れる

const GAME_W := 540.0
const GAME_H := 960.0
const LEAF := Color(0.46, 0.74, 0.36)
const GRASS := Color(0.40, 0.66, 0.32)

var dir := 1.0
var warn := 0.0      # 0〜1
var blow := 0.0      # 0〜1

var _t := 0.0
var _leaves: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 18:
		_leaves.append({"y": rng.randf_range(80.0, 900.0), "x": rng.randf_range(0.0, GAME_W), "ph": rng.randf() * TAU, "sp": rng.randf_range(0.8, 1.3)})


func _process(delta: float) -> void:
	_t += delta
	var speed := 900.0 * blow + 120.0 * warn
	for l in _leaves:
		l["x"] = float(l["x"]) + dir * speed * float(l["sp"]) * delta
		if dir > 0.0 and float(l["x"]) > GAME_W + 20.0:
			l["x"] = -20.0
		elif dir < 0.0 and float(l["x"]) < -20.0:
			l["x"] = GAME_W + 20.0
	queue_redraw()


func _draw() -> void:
	if warn <= 0.0 and blow <= 0.0:
		return
	var edge := 0.0 if dir > 0.0 else GAME_W
	# 風上の端の草（なびく）
	var bend := (0.4 * warn + 0.9 * blow) * dir
	for i in 16:
		var y := 120.0 + float(i) * 52.0
		var base := Vector2(edge, y)
		var sway := sin(_t * 9.0 + float(i)) * 0.15
		for k in 3:
			var h := 26.0 + float(k) * 8.0
			var tip := base + Vector2(dir * (h * (bend + sway)), -h * (1.0 - absf(bend) * 0.5))
			draw_line(base + Vector2(0.0, float(k) * 6.0), tip + Vector2(0.0, float(k) * 6.0), GRASS, 3.0, true)
	# 予告の「≫」
	if warn > 0.0:
		var a := (0.45 + 0.45 * sin(_t * 14.0)) * warn
		for i in 3:
			var x := edge + dir * (34.0 + float(i) * 18.0)
			for y in [300.0, 520.0, 740.0]:
				draw_polyline(PackedVector2Array([
					Vector2(x - dir * 8.0, y - 12.0), Vector2(x + dir * 4.0, y), Vector2(x - dir * 8.0, y + 12.0),
				]), Color(1.0, 1.0, 1.0, a), 4.0, true)
	# 風の筋と葉
	var strength := maxf(blow, warn * 0.3)
	for i in 16:
		var y := fmod(float(i) * 61.0 + 23.0, 880.0) + 50.0
		var x := fmod(_t * 1100.0 * dir + float(i) * 157.0, GAME_W + 200.0)
		if x < 0.0:
			x += GAME_W + 200.0
		x -= 100.0
		var streak := 70.0 + float(i % 3) * 40.0
		draw_line(Vector2(x, y), Vector2(x - streak * dir, y), Color(1.0, 1.0, 1.0, 0.28 * strength), 3.0, true)
	for l in _leaves:
		var p := Vector2(float(l["x"]), float(l["y"]) + sin(_t * 4.0 + float(l["ph"])) * 10.0)
		var rot := _t * 6.0 + float(l["ph"])
		draw_set_transform(p, rot, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([Vector2(-7.0, 0.0), Vector2(0.0, -4.0), Vector2(7.0, 0.0), Vector2(0.0, 4.0)]), Color(LEAF.r, LEAF.g, LEAF.b, strength))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
