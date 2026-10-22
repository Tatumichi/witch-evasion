extends Area2D
## 落っこち猫（仮グラフィック）。
## 1 秒間「にゃー！」の吹き出しで予告してから落ちてくる。受け止めると 15 秒間の効果。
## 取り逃して画面下へ抜けると missed を出す。

signal missed(cat: Area2D)

enum Fur { TABBY, WHITE }

const FONT := preload("res://assets/fonts/MPLUSRounded1c-Bold.ttf")
const WARN_TIME := 1.0
const GRAVITY := 620.0
const MAX_FALL := 400.0

const TABBY := Color(1.0, 0.66, 0.32)
const TABBY_STRIPE := Color(0.78, 0.42, 0.16)
const WHITE_CAT := Color(0.98, 0.97, 0.95)
const LINE := Color(0.25, 0.16, 0.22, 0.95)
const BUBBLE := Color(1.0, 1.0, 1.0, 0.94)
const TABBY_TEX := "res://assets/props/cat_tabby.png"
const WHITE_TEX := "res://assets/props/cat_white.png"

var fur: int = Fur.TABBY
var source := ""

var _falling := false
var _t := 0.0
var _tex_tabby: Texture2D
var _tex_white: Texture2D
var _vy := 60.0
var _from_top := true
var _warn_pos := Vector2.ZERO


## from_top=true なら画面上端で予告して上から落ちる。false なら pos（ボスのとさかなど）から落ちる。
func setup(f: int, pos: Vector2, source_text: String, from_top: bool) -> void:
	fur = f
	source = source_text
	_from_top = from_top
	_warn_pos = Vector2(pos.x, 64.0) if from_top else pos
	position = _warn_pos
	collision_layer = 4
	collision_mask = 0
	monitorable = false          # 予告中は取れない
	var s := CircleShape2D.new()
	s.radius = 28.0              # 受け止めやすいように大きめ
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)


func is_falling() -> bool:
	return _falling


func _physics_process(delta: float) -> void:
	_t += delta
	if not _falling:
		if _t >= WARN_TIME:
			_falling = true
			add_to_group("cats")
			set_deferred("monitorable", true)
			if _from_top:
				position.y = -30.0
		return
	_vy = minf(_vy + GRAVITY * delta, MAX_FALL)
	position.y += _vy * delta
	position.x += sin(_t * 5.0) * 20.0 * delta
	if position.y > 1010.0:
		missed.emit(self)
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _ready() -> void:
	if ResourceLoader.exists(TABBY_TEX):
		_tex_tabby = load(TABBY_TEX) as Texture2D
	if ResourceLoader.exists(WHITE_TEX):
		_tex_white = load(WHITE_TEX) as Texture2D


func _draw() -> void:
	if not _falling:
		_draw_bubble()
		if not _from_top:
			_draw_cat(Vector2(0.0, 30.0), true)   # とさかにぶら下がっている
		return
	_draw_cat(Vector2.ZERO, false)


func _draw_bubble() -> void:
	var pop := minf(_t / 0.15, 1.0)
	var w := 170.0 * pop
	var h := (52.0 if source != "" else 34.0) * pop
	var top := -h - 12.0
	var rect := Rect2(-w * 0.5, top, w, h)
	draw_rect(rect, BUBBLE)
	draw_rect(rect, LINE, false, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, top + h), Vector2(8.0, top + h), Vector2(0.0, top + h + 10.0),
	]), BUBBLE)
	if pop < 1.0:
		return
	draw_string(FONT, Vector2(-w * 0.5, top + 26.0), "にゃー！", HORIZONTAL_ALIGNMENT_CENTER, w, 22, LINE)
	if source != "":
		draw_string(FONT, Vector2(-w * 0.5, top + 46.0), source, HORIZONTAL_ALIGNMENT_CENTER, w, 14, Color(LINE.r, LINE.g, LINE.b, 0.7))


func _draw_cat(o: Vector2, hanging: bool) -> void:
	var tex: Texture2D = _tex_tabby if fur == Fur.TABBY else _tex_white
	if tex:
		var w := 46.0
		var h := w * float(tex.get_height()) / float(tex.get_width())
		draw_set_transform(o + Vector2(0.0, 12.0), sin(_t * 9.0) * 0.10, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-Vector2(w, h) * 0.5, Vector2(w, h)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var c := TABBY if fur == Fur.TABBY else WHITE_CAT
	var flail := sin(_t * 18.0) * 6.0
	# 手足（落ちている間はじたばた）
	var legs := [Vector2(-12.0, 12.0), Vector2(12.0, 12.0), Vector2(-10.0, -10.0), Vector2(10.0, -10.0)]
	for i in legs.size():
		var base: Vector2 = o + legs[i]
		var tip: Vector2 = base + Vector2(signf(legs[i].x) * 8.0, (10.0 if legs[i].y > 0.0 else -10.0) + (flail if i % 2 == 0 else -flail))
		if hanging and legs[i].y < 0.0:
			tip = o + Vector2(legs[i].x * 0.4, -30.0)   # 前足でとさかをつかむ
		draw_line(base, tip, c, 5.0, true)
	# しっぽ
	draw_arc(o + Vector2(14.0, 12.0), 10.0, -PI * 0.2, PI * 0.9 + sin(_t * 6.0) * 0.3, 10, c, 4.0, true)
	# 胴と頭
	draw_circle(o + Vector2(0.0, 6.0), 14.0, c)
	draw_circle(o + Vector2(0.0, -12.0), 12.0, c)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-11.0, -16.0), o + Vector2(-9.0, -30.0), o + Vector2(-2.0, -22.0)]), c)
	draw_colored_polygon(PackedVector2Array([o + Vector2(11.0, -16.0), o + Vector2(9.0, -30.0), o + Vector2(2.0, -22.0)]), c)
	if fur == Fur.TABBY:
		for i in 3:
			draw_line(o + Vector2(-6.0 + i * 6.0, -4.0), o + Vector2(-5.0 + i * 6.0, 14.0), TABBY_STRIPE, 2.5, true)
		draw_line(o + Vector2(-3.0, -23.0), o + Vector2(-2.0, -17.0), TABBY_STRIPE, 2.0, true)
		draw_line(o + Vector2(3.0, -23.0), o + Vector2(2.0, -17.0), TABBY_STRIPE, 2.0, true)
	else:
		draw_colored_polygon(PackedVector2Array([o + Vector2(-9.0, -18.0), o + Vector2(-8.5, -26.0), o + Vector2(-4.0, -21.0)]), Color(1.0, 0.72, 0.78))
		draw_colored_polygon(PackedVector2Array([o + Vector2(9.0, -18.0), o + Vector2(8.5, -26.0), o + Vector2(4.0, -21.0)]), Color(1.0, 0.72, 0.78))
	draw_arc(o + Vector2(0.0, 6.0), 14.0, 0.0, TAU, 20, LINE, 1.4, true)
	draw_arc(o + Vector2(0.0, -12.0), 12.0, 0.0, TAU, 20, LINE, 1.4, true)
	# 驚いた顔
	draw_circle(o + Vector2(-4.5, -13.0), 2.4, LINE)
	draw_circle(o + Vector2(4.5, -13.0), 2.4, LINE)
	draw_arc(o + Vector2(0.0, -6.0), 2.6, 0.0, TAU, 10, LINE, 1.4, true)
