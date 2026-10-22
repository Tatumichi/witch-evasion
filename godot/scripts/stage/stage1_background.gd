extends Node2D
## STAGE 1「村の空」の背景（仮グラフィック）。
## 朝焼けの空。赤い屋根と煙突の村から始まり、教会の塔を越え、終盤は空だけになる。
## progress（0〜1 = 道中の進み）をステージ側が毎フレーム設定する。

signal tower_passed

const GAME_W := 540.0
const GAME_H := 960.0
## 道中の終わりまでに村が下へ流れる量（px）。屋根は 4 割ほどで画面外へ消える。
const TOWN_TRAVEL := 1540.0
const TOWER_X := 392.0
const TOWER_W := 54.0
const TOWER_H := 610.0         # 地面から鐘楼の屋根まで
## 塔は遠くにあるので、村よりゆっくり流れる。尖塔の先がメルルの高さを越えるのは 6 割ほど進んだころ。
const TOWER_PARALLAX := 0.45
const HAZE := 0.28             # 遠景なので空の色を少し混ぜる
const PLAYER_Y := 710.0

## 画像素材（無ければ下のコード描画にフォールバックする）
const VILLAGE_TEX := "res://assets/background/village_band.png"
const TOWER_TEX := "res://assets/background/tower.png"

const SKY_TOP_A := Color(0.30, 0.27, 0.55)
const SKY_TOP_B := Color(0.47, 0.67, 0.93)
const SKY_MID_A := Color(0.98, 0.62, 0.52)
const SKY_MID_B := Color(0.74, 0.86, 0.98)
const SKY_BOT_A := Color(1.0, 0.76, 0.46)
const SKY_BOT_B := Color(0.94, 0.95, 0.98)

const ROOFS := [Color(0.84, 0.32, 0.28), Color(0.74, 0.36, 0.30), Color(0.90, 0.46, 0.34), Color(0.58, 0.34, 0.42)]
const WALLS := [Color(0.99, 0.90, 0.78), Color(0.96, 0.84, 0.72), Color(0.92, 0.88, 0.82)]
const WINDOW := Color(1.0, 0.86, 0.48)
const STONE := Color(0.80, 0.74, 0.70)
const STONE_DARK := Color(0.62, 0.56, 0.56)

var progress := 0.0
var scroll_speed := 230.0

var _t := 0.0
var _back: Array = []
var _front: Array = []
var _clouds: Array = []
var _tower_done := false
var _village_tex: Texture2D
var _tower_tex: Texture2D


func _ready() -> void:
	z_index = -10
	var rng := RandomNumberGenerator.new()
	rng.seed = 1201   # 村の並びは毎回同じにする
	if ResourceLoader.exists(VILLAGE_TEX):
		_village_tex = load(VILLAGE_TEX) as Texture2D
	if ResourceLoader.exists(TOWER_TEX):
		_tower_tex = load(TOWER_TEX) as Texture2D
	_back = _make_row(rng, 0.62, 90.0)
	_front = _make_row(rng, 1.0, 0.0)
	for i in 7:
		_clouds.append({
			"pos": Vector2(rng.randf_range(-40.0, GAME_W + 40.0), rng.randf_range(-100.0, GAME_H)),
			"w": rng.randf_range(90.0, 170.0),
			"mul": rng.randf_range(0.10, 0.22),
		})


func _make_row(rng: RandomNumberGenerator, shade: float, lift: float) -> Array:
	var row := []
	var x := -30.0
	while x < GAME_W + 40.0:
		var w := rng.randf_range(58.0, 96.0)
		row.append({
			"x": x, "w": w,
			"h": rng.randf_range(70.0, 150.0),
			"roof_h": rng.randf_range(30.0, 56.0),
			"roof": ROOFS[rng.randi() % ROOFS.size()],
			"wall": WALLS[rng.randi() % WALLS.size()],
			"chimney": rng.randf() < 0.55,
			"shade": shade,
			"lift": lift,
		})
		x += w + rng.randf_range(2.0, 14.0)
	return row


## やり直し時に呼ぶ。
func reset() -> void:
	progress = 0.0
	_tower_done = false


func town_offset() -> float:
	return progress * TOWN_TRAVEL


func _process(delta: float) -> void:
	_t += delta
	for c in _clouds:
		var p: Vector2 = c["pos"]
		p.y += scroll_speed * float(c["mul"]) * delta
		if p.y > GAME_H + 60.0:
			p.y = -60.0
			p.x = fmod(p.x + 211.0, GAME_W + 80.0) - 40.0
		c["pos"] = p

	var tip_y := GAME_H - TOWER_H - 70.0 + town_offset() * TOWER_PARALLAX
	if not _tower_done and tip_y > PLAYER_Y:
		_tower_done = true
		tower_passed.emit()
	queue_redraw()


func _draw() -> void:
	var k := smoothstep(0.0, 0.9, progress)
	_draw_sky(k)
	_draw_sun(k)
	for c in _clouds:
		_draw_cloud(c["pos"], float(c["w"]), 0.35 + 0.35 * k)

	var off := town_offset()
	if _tower_tex:
		_draw_tower_tex(off * TOWER_PARALLAX)
	else:
		_draw_tower(off * TOWER_PARALLAX, k)
	if off < GAME_H + 200.0:
		if _village_tex:
			# 遠景（薄く・少し上）と近景の2枚重ねで奥行きを出す
			_draw_band(off * 0.85, 0.55, 54.0)
			_draw_band(off, 1.0, 0.0)
		else:
			_draw_row(_back, off * 0.85)
			_draw_row(_front, off)


func _draw_sky(k: float) -> void:
	var top := SKY_TOP_A.lerp(SKY_TOP_B, k)
	var mid := SKY_MID_A.lerp(SKY_MID_B, k)
	var bot := SKY_BOT_A.lerp(SKY_BOT_B, k)
	var y_mid := GAME_H * 0.62
	draw_polygon(PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(GAME_W, 0.0), Vector2(GAME_W, y_mid), Vector2(0.0, y_mid),
	]), PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([
		Vector2(0.0, y_mid), Vector2(GAME_W, y_mid), Vector2(GAME_W, GAME_H), Vector2(0.0, GAME_H),
	]), PackedColorArray([mid, mid, bot, bot]))


func _draw_sun(k: float) -> void:
	# 朝日。昇るにつれて上へ移り、白っぽくなる
	var pos := Vector2(118.0, lerpf(820.0, 300.0, k))
	var c := Color(1.0, 0.80, 0.50).lerp(Color(1.0, 0.98, 0.90), k)
	for i in 24:
		var t := float(i) / 23.0
		draw_circle(pos, lerpf(46.0, 170.0, t), Color(c.r, c.g, c.b, 0.012))
	draw_circle(pos, 46.0, Color(c.r, c.g, c.b, 0.95))


func _draw_cloud(pos: Vector2, w: float, a: float) -> void:
	var col := Color(1.0, 0.98, 0.96, a)
	draw_circle(pos, w * 0.22, col)
	draw_circle(pos + Vector2(-w * 0.24, w * 0.06), w * 0.17, col)
	draw_circle(pos + Vector2(w * 0.25, w * 0.07), w * 0.16, col)
	draw_rect(Rect2(pos.x - w * 0.4, pos.y + w * 0.02, w * 0.8, w * 0.16), col)


func _draw_row(row: Array, off: float) -> void:
	for h in row:
		var shade: float = h["shade"]
		var x: float = h["x"]
		var w: float = h["w"]
		var hh: float = h["h"]
		var base := GAME_H + off - float(h["lift"])
		var top := base - hh
		if top > GAME_H + 10.0:
			continue
		var wall: Color = (h["wall"] as Color).darkened(1.0 - shade)
		var roof: Color = (h["roof"] as Color).darkened((1.0 - shade) * 0.8)
		var rh: float = h["roof_h"]
		if h["chimney"]:
			draw_rect(Rect2(x + w * 0.68, top - rh * 0.9, 12.0, rh * 0.9), roof.darkened(0.25))
		draw_rect(Rect2(x, top, w, hh + 400.0), wall)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - 6.0, top), Vector2(x + w + 6.0, top), Vector2(x + w * 0.5, top - rh),
		]), roof)
		# 窓（朝なので少しだけ灯りが残っている）
		var win := WINDOW if shade >= 1.0 else WINDOW.darkened(0.3)
		draw_rect(Rect2(x + w * 0.2, top + 18.0, 12.0, 14.0), win)
		draw_rect(Rect2(x + w * 0.6, top + 18.0, 12.0, 14.0), win)


## 村の帯を画面幅に合わせて敷く。off だけ下へ流れる。
func _draw_band(off: float, alpha: float, lift: float) -> void:
	var w := GAME_W
	var h := w * float(_village_tex.get_height()) / float(_village_tex.get_width())
	var y := GAME_H + off - h - lift
	draw_texture_rect(_village_tex, Rect2(0.0, y, w, h), false, Color(1.0, 1.0, 1.0, alpha))


## 教会の塔を画像で描く。パララックスは従来と同じ。
func _draw_tower_tex(off: float) -> void:
	var h := TOWER_H
	var w := h * float(_tower_tex.get_width()) / float(_tower_tex.get_height())
	var base := GAME_H + off
	var top := base - h
	if top - 100.0 > GAME_H:
		return
	draw_texture_rect(_tower_tex, Rect2(TOWER_X - w * 0.5, top, w, h), false)


func _draw_tower(off: float, k: float) -> void:
	var base := GAME_H + off
	var top := base - TOWER_H
	if top - 100.0 > GAME_H:
		return
	var sky := SKY_MID_A.lerp(SKY_MID_B, k)
	var stone := STONE.lerp(sky, HAZE)
	var stone_dark := STONE_DARK.lerp(sky, HAZE)
	var gold := Color(0.92, 0.74, 0.36).lerp(sky, HAZE)
	var x := TOWER_X - TOWER_W * 0.5
	draw_rect(Rect2(x, top, TOWER_W, TOWER_H + 400.0), stone)
	draw_rect(Rect2(x + TOWER_W - 10.0, top, 10.0, TOWER_H + 400.0), stone_dark)
	# 鐘楼の窓と鐘
	draw_rect(Rect2(x + 12.0, top + 18.0, TOWER_W - 24.0, 38.0), Color(0.30, 0.24, 0.30).lerp(sky, HAZE))
	draw_circle(Vector2(TOWER_X, top + 42.0), 10.0, gold)
	draw_rect(Rect2(x - 5.0, top - 4.0, TOWER_W + 10.0, 7.0), stone_dark)
	# 尖塔
	draw_colored_polygon(PackedVector2Array([
		Vector2(x - 4.0, top - 4.0), Vector2(x + TOWER_W + 4.0, top - 4.0), Vector2(TOWER_X, top - 70.0),
	]), Color(0.36, 0.42, 0.62).lerp(sky, HAZE))
	draw_line(Vector2(TOWER_X, top - 70.0), Vector2(TOWER_X, top - 90.0), gold, 3.0)
	draw_line(Vector2(TOWER_X - 6.0, top - 83.0), Vector2(TOWER_X + 6.0, top - 83.0), gold, 3.0)
	# 時計
	var clock := Vector2(TOWER_X, top + 92.0)
	draw_circle(clock, 14.0, Color(0.98, 0.96, 0.90).lerp(sky, HAZE))
	draw_arc(clock, 14.0, 0.0, TAU, 20, stone_dark, 2.0, true)
	draw_line(clock, clock + Vector2(0.0, -9.0), Color(0.2, 0.2, 0.25), 2.0)
	draw_line(clock, clock + Vector2(7.0, 0.0), Color(0.2, 0.2, 0.25), 2.0)
