extends Node2D
## 夜空のパララックス背景。ワールドはスクロールしないので画面座標で直接描く。

const GAME_W := 540.0
const GAME_H := 960.0

const SKY_TOP := Color(0.04, 0.03, 0.12)
const SKY_BOT := Color(0.27, 0.10, 0.29)
const MOON := Vector2(398.0, 148.0)

var scroll_speed := 180.0

var _t := 0.0
var _stars: Array = []
var _nebulae: Array = []


func _ready() -> void:
	z_index = -10
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# 星：奥ほどゆっくり流れる
	for i in 90:
		_stars.append({
			"pos": Vector2(rng.randf_range(0.0, GAME_W), rng.randf_range(0.0, GAME_H)),
			"r": rng.randf_range(0.6, 1.9),
			"ph": rng.randf() * TAU,
			"mul": rng.randf_range(0.02, 0.10),
		})

	# 星雲：大きなぼかしで奥行きを出す
	var palette := [
		Color(0.52, 0.26, 0.72), Color(0.72, 0.30, 0.52), Color(0.30, 0.38, 0.78),
	]
	for i in 5:
		_nebulae.append({
			"pos": Vector2(rng.randf_range(-60.0, GAME_W + 60.0), rng.randf_range(-100.0, GAME_H + 100.0)),
			"r": rng.randf_range(150.0, 280.0),
			"col": palette[i % palette.size()],
			"mul": rng.randf_range(0.02, 0.06),
		})


func _process(delta: float) -> void:
	_t += delta

	for s in _stars:
		var p: Vector2 = s["pos"]
		p.y += scroll_speed * float(s["mul"]) * delta
		if p.y > GAME_H + 4.0:
			p.y = -4.0
			p.x = fmod(p.x + 97.0, GAME_W)
		s["pos"] = p

	for n in _nebulae:
		var q: Vector2 = n["pos"]
		q.y += scroll_speed * float(n["mul"]) * delta
		if q.y > GAME_H + 320.0:
			q.y = -320.0
		n["pos"] = q

	queue_redraw()


func _draw() -> void:
	# 空のグラデーション（4 頂点カラーで 1 枚）
	var quad := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(GAME_W, 0.0),
		Vector2(GAME_W, GAME_H), Vector2(0.0, GAME_H),
	])
	draw_polygon(quad, PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOT, SKY_BOT]))

	# 星雲（重ねて縁を消す）
	for n in _nebulae:
		var c: Color = n["col"]
		for i in 14:
			var k := float(i) / 13.0
			draw_circle(n["pos"], float(n["r"]) * k, Color(c.r, c.g, c.b, 0.0045))

	# 星
	for s in _stars:
		var tw := 0.35 + 0.5 * (0.5 + 0.5 * sin(_t * 2.0 + float(s["ph"])))
		draw_circle(s["pos"], float(s["r"]), Color(1.0, 0.96, 0.92, tw))

	# 月（輪は細かく重ねてバンディングを消す）
	for i in 40:
		var k := float(i) / 39.0
		draw_circle(MOON, lerpf(40.0, 150.0, k), Color(1.0, 0.85, 0.68, 0.006))
	draw_circle(MOON, 40.0, Color(1.0, 0.94, 0.84, 0.95))
	draw_circle(MOON + Vector2(-12.0, -9.0), 7.5, Color(0.93, 0.86, 0.79, 0.5))
	draw_circle(MOON + Vector2(14.0, 11.0), 5.0, Color(0.93, 0.86, 0.79, 0.4))
	draw_circle(MOON + Vector2(3.0, -24.0), 3.5, Color(0.93, 0.86, 0.79, 0.35))

	# 地平線のほのかな光（上下グラデーションで境目を消す）
	var glow := PackedVector2Array([
		Vector2(0.0, GAME_H - 300.0), Vector2(GAME_W, GAME_H - 300.0),
		Vector2(GAME_W, GAME_H), Vector2(0.0, GAME_H),
	])
	draw_polygon(glow, PackedColorArray([
		Color(1.0, 0.45, 0.35, 0.0), Color(1.0, 0.45, 0.35, 0.0),
		Color(1.0, 0.54, 0.38, 0.10), Color(1.0, 0.54, 0.38, 0.10),
	]))
