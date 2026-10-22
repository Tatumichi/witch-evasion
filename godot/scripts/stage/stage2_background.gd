extends Node2D
## STAGE 2「丘と森の上空」の背景。
## 青空。眼下に緑の丘と風車小屋、その奥に深い森。終盤は森いちばんの大木のてっぺんをかすめ、
## わた雲が近づいてくる。progress（0〜1）をステージ側が毎フレーム設定する。
##
## STAGE 1 と同じく「動く部分だけ画像化」（docs/decisions.md D-006）。空と太陽はコード描画のまま。
## 画像があれば使い、無ければコード描画に戻る（ResourceLoader.exists で判定）。仕様は docs/stage2-assets.md。
##   assets/background/hills_band.png  … 丘の帯（横長。小さな風車も描き込む）。2 枚重ねで奥行きを出す
##   assets/background/forest_band.png … 森の帯（横長。上端が木々の頭、下端は森の暗い色）
##   assets/background/big_tree.png    … 森いちばんの大木（縦長。根元が画像の下端）
##   assets/props/cloud.png            … 雲（STAGE 1 と共用）

signal landmark_passed

const GAME_W := 540.0
const GAME_H := 960.0
const PLAYER_Y := 710.0

## 丘は手前ほど速く流れて、半分ほどで画面の下へ消える
const HILL_TRAVEL := 1500.0
## 森は奥にあるのでゆっくり流れる。大木は森から突き出た遠景で、7 割ほどでてっぺんがメルルの高さを越え、
## ボス戦までに画面の下へ消える。
const FOREST_PARALLAX := 0.56
const TREE_X := 150.0
const TREE_H := 760.0
const HAZE := 0.25          # 遠景なので空の色を少し混ぜる

const SKY_TOP_A := Color(0.36, 0.62, 0.95)
const SKY_TOP_B := Color(0.30, 0.52, 0.90)
const SKY_BOT_A := Color(0.80, 0.92, 0.99)
const SKY_BOT_B := Color(0.88, 0.94, 1.0)
const HILLS := [Color(0.56, 0.80, 0.44), Color(0.46, 0.72, 0.38), Color(0.38, 0.64, 0.34)]
const FOREST := Color(0.20, 0.42, 0.30)
const FOREST_LIGHT := Color(0.28, 0.52, 0.34)
const TRUNK := Color(0.42, 0.30, 0.24)

const HILLS_TEX := "res://assets/background/hills_band.png"
const FOREST_TEX := "res://assets/background/forest_band.png"
const TREE_TEX := "res://assets/background/big_tree.png"
const CLOUD_TEX := "res://assets/props/cloud.png"

var progress := 0.0
var scroll_speed := 253.0

var _t := 0.0
var _clouds: Array = []
var _mills: Array = []
var _passed := false
var _hills_tex: Texture2D
var _forest_tex: Texture2D
var _tree_tex: Texture2D
var _cloud_tex: Texture2D


func _ready() -> void:
	z_index = -10
	_hills_tex = _tex(HILLS_TEX)
	_forest_tex = _tex(FOREST_TEX)
	_tree_tex = _tex(TREE_TEX)
	_cloud_tex = _tex(CLOUD_TEX)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2202
	for i in 12:
		_clouds.append({
			"pos": Vector2(rng.randf_range(-40.0, GAME_W + 40.0), rng.randf_range(-100.0, GAME_H)),
			"w": rng.randf_range(100.0, 200.0),
			"mul": rng.randf_range(0.10, 0.25),
			"late": i >= 5,     # 終盤だけ見える雲
		})
	for x in [90.0, 300.0, 460.0]:
		_mills.append({"x": x, "ph": rng.randf() * TAU})


func _tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func reset() -> void:
	progress = 0.0
	_passed = false


func _process(delta: float) -> void:
	_t += delta
	for c in _clouds:
		var p: Vector2 = c["pos"]
		p.y += scroll_speed * float(c["mul"]) * delta
		if p.y > GAME_H + 80.0:
			p.y = -80.0
			p.x = fmod(p.x + 233.0, GAME_W + 80.0) - 40.0
		c["pos"] = p
	var tip := _tree_top() - 60.0
	if not _passed and tip > PLAYER_Y:
		_passed = true
		landmark_passed.emit()
	queue_redraw()


func _hill_off() -> float:
	return progress * HILL_TRAVEL


func _forest_off() -> float:
	return progress * HILL_TRAVEL * FOREST_PARALLAX


func _tree_top() -> float:
	return GAME_H - TREE_H + _forest_off()


func _draw() -> void:
	var k := smoothstep(0.0, 1.0, progress)
	var top := SKY_TOP_A.lerp(SKY_TOP_B, k)
	var bot := SKY_BOT_A.lerp(SKY_BOT_B, k)
	draw_polygon(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(GAME_W, 0.0), Vector2(GAME_W, GAME_H), Vector2(0.0, GAME_H),
	]), PackedColorArray([top, top, bot, bot]))
	# 太陽
	var sun := Vector2(440.0, 150.0)
	for i in 16:
		draw_circle(sun, lerpf(40.0, 140.0, float(i) / 15.0), Color(1.0, 1.0, 0.9, 0.012))
	draw_circle(sun, 38.0, Color(1.0, 0.99, 0.92, 0.95))

	_draw_forest(_forest_off())
	_draw_tree(_forest_off())
	_draw_hills(_hill_off())

	# わた雲（終盤ほど増える）
	var late_a := smoothstep(0.55, 0.95, progress)
	for c in _clouds:
		var a := 0.75 if not c["late"] else 0.85 * late_a
		if a > 0.01:
			_draw_cloud(c["pos"], float(c["w"]), a)


func _draw_forest(off: float) -> void:
	# 奥の深い森。こんもりした木の頭を並べる
	var base := GAME_H - 140.0 + off
	if base - 80.0 > GAME_H:
		return
	var sky := SKY_BOT_A.lerp(SKY_BOT_B, progress)
	var dark := FOREST.lerp(sky, HAZE)
	var light := FOREST_LIGHT.lerp(sky, HAZE)
	if _forest_tex:
		# 帯の下端を base + 60 に合わせ、その下は森の暗い色で延ばす
		var h := GAME_W * float(_forest_tex.get_height()) / float(_forest_tex.get_width())
		draw_rect(Rect2(0.0, base + 50.0, GAME_W, 700.0), dark)
		draw_texture_rect(_forest_tex, Rect2(0.0, base + 60.0 - h, GAME_W, h), false)
		return
	draw_rect(Rect2(0.0, base, GAME_W, 600.0), dark)
	for i in 14:
		var x := float(i) * 42.0 - 10.0
		var r := 30.0 + float((i * 7) % 5) * 4.0
		draw_circle(Vector2(x, base + 6.0), r, dark if i % 2 == 0 else light)


func _draw_tree(off: float) -> void:
	# 森いちばんの大木（遠景）
	var top := GAME_H - TREE_H + off
	if top - 90.0 > GAME_H:
		return
	if _tree_tex:
		# 梢の上端（top - 90）から地面（画面下 + off）まで
		var h := TREE_H + 90.0
		var w := h * float(_tree_tex.get_width()) / float(_tree_tex.get_height())
		draw_texture_rect(_tree_tex, Rect2(TREE_X - w * 0.5, top - 90.0, w, h), false)
		return
	var sky := SKY_BOT_A.lerp(SKY_BOT_B, progress)
	var trunk := TRUNK.lerp(sky, HAZE)
	var leaf := FOREST_LIGHT.lerp(sky, HAZE)
	draw_rect(Rect2(TREE_X - 15.0, top + 40.0, 30.0, TREE_H + 200.0), trunk)
	draw_line(Vector2(TREE_X, top + 140.0), Vector2(TREE_X + 54.0, top + 100.0), trunk, 8.0, true)
	draw_line(Vector2(TREE_X, top + 210.0), Vector2(TREE_X - 60.0, top + 176.0), trunk, 8.0, true)
	for c in [[Vector2(0.0, 0.0), 58.0], [Vector2(-46.0, 32.0), 42.0], [Vector2(48.0, 30.0), 44.0],
			[Vector2(62.0, 96.0), 30.0], [Vector2(-66.0, 172.0), 30.0], [Vector2(0.0, -34.0), 38.0]]:
		draw_circle(Vector2(TREE_X, top) + c[0], c[1], leaf)
	draw_circle(Vector2(TREE_X - 14.0, top - 16.0), 18.0, Color(0.40, 0.62, 0.40).lerp(sky, HAZE))


func _draw_hills(off: float) -> void:
	if off > GAME_H + 300.0:
		return
	if _hills_tex:
		# 奥（少し暗く・上に・ゆっくり）と手前の 2 枚重ね
		var h := GAME_W * float(_hills_tex.get_height()) / float(_hills_tex.get_width())
		for layer in [[0.85, 70.0, Color(0.86, 0.90, 0.92)], [1.0, 0.0, Color.WHITE]]:
			var y: float = GAME_H + off * float(layer[0]) - h - float(layer[1])
			if y < GAME_H:
				draw_texture_rect(_hills_tex, Rect2(0.0, y, GAME_W, h), false, layer[2])
				draw_rect(Rect2(0.0, y + h - 2.0, GAME_W, 700.0), (HILLS[2] as Color) * (layer[2] as Color))
		return
	# 3 段の丘。手前ほど速く流れる
	for layer in 3:
		var speed: float = [0.75, 0.88, 1.0][layer]
		var base := GAME_H - 150.0 + 70.0 * float(layer) + off * float(speed)
		if base - 120.0 > GAME_H:
			continue
		var pts := PackedVector2Array()
		pts.append(Vector2(0.0, GAME_H + 600.0))
		for i in 13:
			var x := GAME_W * float(i) / 12.0
			pts.append(Vector2(x, base - 50.0 - sin(float(i) * 0.9 + float(layer) * 1.7) * 40.0))
		pts.append(Vector2(GAME_W, GAME_H + 600.0))
		draw_colored_polygon(pts, HILLS[layer])
		if layer == 1:
			for m in _mills:
				_draw_small_mill(Vector2(float(m["x"]), base - 70.0), float(m["ph"]))


func _draw_small_mill(p: Vector2, ph: float) -> void:
	draw_rect(Rect2(p.x - 9.0, p.y - 40.0, 18.0, 40.0), Color(0.96, 0.92, 0.86))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-12.0, -40.0), p + Vector2(12.0, -40.0), p + Vector2(0.0, -54.0)]), Color(0.60, 0.38, 0.32))
	var hub := p + Vector2(0.0, -42.0)
	for i in 4:
		var a := _t * 1.4 + ph + TAU * float(i) / 4.0
		draw_line(hub, hub + Vector2(cos(a), sin(a)) * 30.0, Color(0.50, 0.38, 0.30), 3.0, true)


func _draw_cloud(pos: Vector2, w: float, a: float) -> void:
	if _cloud_tex:
		var h := w * float(_cloud_tex.get_height()) / float(_cloud_tex.get_width())
		draw_texture_rect(_cloud_tex, Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h)), false, Color(1.0, 1.0, 1.0, a))
		return
	var col := Color(1.0, 1.0, 1.0, a)
	draw_circle(pos, w * 0.22, col)
	draw_circle(pos + Vector2(-w * 0.24, w * 0.06), w * 0.17, col)
	draw_circle(pos + Vector2(w * 0.25, w * 0.07), w * 0.16, col)
	draw_rect(Rect2(pos.x - w * 0.4, pos.y + w * 0.02, w * 0.8, w * 0.16), col)
