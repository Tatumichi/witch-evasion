extends Area2D
## 風船（STAGE 2）。下から昇ってくる。画面下に入る前は、下端に「▲」の予告を出す。
## 当たっても帽子は落ちない（group "bumpers"）。割れてメルルが驚き、少しはじかれる。キャンディでも割れる。
## 猫がぶら下がっている風船は、一定の高さで割れて猫が落ちる（released_cat）。
##
## 画像: assets/props/balloon.png があれば使う。**白〜薄い灰色で描いた 1 枚**を、ゲーム側で 4 色に着色する
##       （幅 DRAW_W px、風船の玉の中心が原点。ひもは画像に含めず、コードで描いて揺らす）。
##       ぶら下がる猫は assets/props/cat_tabby.png を流用する。無ければコード描画。
## 音:   割れる → candy_fire を低めに鳴らして「ぽんっ」（専用 SE が無いあいだの代用）。

signal released_cat(pos: Vector2)

const Sfx := preload("res://scripts/stage/sfx.gd")
const TEX_PATH := "res://assets/props/balloon.png"
const CAT_TEX_PATH := "res://assets/props/cat_tabby.png"
const DRAW_W := 48.0

const COLORS := [Color(1.0, 0.45, 0.50), Color(1.0, 0.80, 0.30), Color(0.45, 0.70, 1.0), Color(0.62, 0.88, 0.52)]
const LINE := Color(0.30, 0.22, 0.32, 0.8)
const WARN := Color(1.0, 0.55, 0.45)
const TABBY := Color(1.0, 0.66, 0.32)

var vel := Vector2(0.0, -80.0)
var wind := 0.0
var has_cat := false
## 猫つきの風船は、この高さまで昇ったら割れる。
var release_y := 360.0

var _t := 0.0
var _ph := 0.0
var _col := COLORS[0]
var _popped := false
var _pop_t := 0.0
var _tex: Texture2D
var _cat_tex: Texture2D


func setup(start: Vector2, rise_speed: float, rng: RandomNumberGenerator, with_cat := false) -> void:
	position = start
	vel = Vector2(0.0, -rise_speed)
	has_cat = with_cat
	_ph = rng.randf() * TAU
	_col = COLORS[rng.randi() % COLORS.size()]
	collision_layer = 2          # キャンディと本体の当たり判定が見る層。被弾はしない（obstacles に入れない）
	collision_mask = 0
	add_to_group("bumpers")
	add_to_group("breakable")
	add_to_group("windable")
	var s := CircleShape2D.new()
	s.radius = 22.0
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)


func _ready() -> void:
	if ResourceLoader.exists(TEX_PATH):
		_tex = load(TEX_PATH) as Texture2D
	if ResourceLoader.exists(CAT_TEX_PATH):
		_cat_tex = load(CAT_TEX_PATH) as Texture2D


## メルルがぶつかったとき。
func bump() -> void:
	_pop()


## キャンディが当たったとき。
func break_apart() -> void:
	_pop()


func _pop() -> void:
	if _popped:
		return
	_popped = true
	remove_from_group("bumpers")
	remove_from_group("breakable")
	set_deferred("monitorable", false)
	Sfx.fire(self, "candy_fire", {"x": global_position.x, "pitch": 0.62, "pitch_jitter": 0.05, "volume_db": 3.0})
	if has_cat:
		has_cat = false
		# 当たり判定の処理中（ぶつかった・キャンディ）に割れることがあるので、猫の生成は後回しにする
		released_cat.emit.call_deferred(global_position + Vector2(0.0, 46.0))


func _physics_process(delta: float) -> void:
	_t += delta
	if _popped:
		_pop_t += delta
		if _pop_t > 0.25:
			queue_free()
		return
	position += (vel + Vector2(wind * 0.8 + sin(_t * 1.5 + _ph) * 14.0, 0.0)) * delta
	if has_cat and position.y < release_y:
		_pop()
	if position.y < -140.0 or position.x < -120.0 or position.x > 660.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _popped:
		var k := _pop_t / 0.25
		for i in 8:
			var a := TAU * float(i) / 8.0
			var d := Vector2(cos(a), sin(a))
			draw_line(d * (10.0 + 20.0 * k), d * (18.0 + 26.0 * k), Color(_col.r, _col.g, _col.b, 1.0 - k), 3.0, true)
		return

	# 画面の下にいる間は下端に予告
	if position.y > 950.0:
		var y := 960.0 - position.y - 22.0
		var a := 0.5 + 0.5 * sin(_t * 16.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-12.0, y + 10.0), Vector2(12.0, y + 10.0), Vector2(0.0, y - 10.0),
		]), Color(WARN.r, WARN.g, WARN.b, a))

	# ひも
	var pts := PackedVector2Array()
	for i in 9:
		var yy := 28.0 + float(i) * 5.0
		pts.append(Vector2(sin(_t * 3.0 + float(i) * 0.7) * 3.0, yy))
	draw_polyline(pts, LINE, 1.4, true)

	# 風船
	if _tex:
		var h := DRAW_W * float(_tex.get_height()) / float(_tex.get_width())
		draw_texture_rect(_tex, Rect2(-Vector2(DRAW_W, h) * 0.5, Vector2(DRAW_W, h)), false, _col)
	else:
		var body := PackedVector2Array()
		for i in 24:
			var a2 := TAU * float(i) / 24.0
			body.append(Vector2(cos(a2) * 22.0, sin(a2) * 26.0))
		draw_colored_polygon(body, _col)
		draw_colored_polygon(PackedVector2Array([Vector2(-4.0, 25.0), Vector2(4.0, 25.0), Vector2(0.0, 31.0)]), _col.darkened(0.2))
		draw_circle(Vector2(-8.0, -10.0), 5.0, Color(1.0, 1.0, 1.0, 0.55))
		var closed := body.duplicate()
		closed.append(body[0])
		draw_polyline(closed, LINE, 1.6, true)

	if has_cat:
		_draw_hanging_cat(Vector2(pts[pts.size() - 1].x, 76.0))


## ひもの先にしがみつく茶トラ
func _draw_hanging_cat(o: Vector2) -> void:
	if _cat_tex:
		var w := 40.0
		var h := w * float(_cat_tex.get_height()) / float(_cat_tex.get_width())
		draw_set_transform(o + Vector2(0.0, 8.0), sin(_t * 4.0) * 0.12, Vector2.ONE)
		draw_texture_rect(_cat_tex, Rect2(-Vector2(w, h) * 0.5, Vector2(w, h)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_line(o + Vector2(-4.0, -12.0), Vector2(o.x - 1.0, 70.0), TABBY, 4.0, true)
	draw_line(o + Vector2(4.0, -12.0), Vector2(o.x + 1.0, 70.0), TABBY, 4.0, true)
	draw_circle(o, 11.0, TABBY)
	draw_circle(o + Vector2(0.0, -6.0), 9.0, TABBY)
	draw_circle(o + Vector2(-3.0, -7.0), 1.6, LINE)
	draw_circle(o + Vector2(3.0, -7.0), 1.6, LINE)
	draw_line(o + Vector2(-5.0, 9.0), o + Vector2(-6.0, 18.0 + sin(_t * 10.0) * 3.0), TABBY, 4.0, true)
	draw_line(o + Vector2(5.0, 9.0), o + Vector2(6.0, 18.0 - sin(_t * 10.0) * 3.0), TABBY, 4.0, true)
