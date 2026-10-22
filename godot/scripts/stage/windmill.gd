extends Area2D
## 画面端の風車小屋（STAGE 2）。回転する 4 枚の羽根が画面の内側へ張り出す。
## 当たり判定は羽根だけ。キャンディでは壊れない。回転のタイミングを見て通る。
##
## Area2D ごと回転させると当たり判定（羽根）も一緒に回る。小屋は回転を打ち消して描く。
##
## 画像（無ければコード描画）:
##   assets/props/windmill_blades.png … 4 枚羽根。**正方形・ハブが画像の中心・羽根の先が画像の端**。
##                                       ゲームでは一辺 = 羽根の長さ × 2 に拡大縮小して回す
##   assets/props/windmill_house.png  … 小屋。屋根の頂点付近がハブ（原点）。幅 HOUSE_W px で描く
## 音: 画面にいるあいだ windmill_loop をループ。何基いても 1 本（専用音が無いあいだは FALLBACK で vane_spin）。

const Sfx := preload("res://scripts/stage/sfx.gd")
const BLADES_TEX := "res://assets/props/windmill_blades.png"
const HOUSE_TEX := "res://assets/props/windmill_house.png"
const HOUSE_W := 110.0
## 小屋の画像の中で、ハブ（羽根の軸）が来る位置（左上 0,0 〜 右下 1,1 の割合）
const HOUSE_HUB := Vector2(0.5, 0.12)

const SAIL := Color(0.97, 0.94, 0.88)
const FRAME := Color(0.48, 0.34, 0.26)
const WALL := Color(0.94, 0.90, 0.82)
const ROOF := Color(0.55, 0.34, 0.30)
const LINE := Color(0.25, 0.18, 0.20, 0.8)

## 羽根の長さ（中心から先端まで）と回転の速さ
var blade_len := 190.0
var spin := 0.8
var fall := 253.0
var side := -1.0             # -1 = 画面の左端、1 = 右端

var _t := 0.0
var _scale_y := 1.0          # 退場時に羽根をたたむ（ボスでも使う）
var _blades_tex: Texture2D
var _house_tex: Texture2D


func setup(on_side: float, y: float, fall_speed: float, rng: RandomNumberGenerator, length := 190.0) -> void:
	side = on_side
	fall = fall_speed
	blade_len = length
	position = Vector2(-6.0 if side < 0.0 else 546.0, y)
	rotation = rng.randf() * TAU
	spin = rng.randf_range(0.7, 0.95) * (1.0 if side < 0.0 else -1.0)
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	for i in 4:
		var a := TAU * float(i) / 4.0
		var cs := CollisionShape2D.new()
		var s := CapsuleShape2D.new()
		s.radius = 13.0
		s.height = blade_len - 30.0
		cs.shape = s
		cs.position = Vector2(cos(a), sin(a)) * (blade_len * 0.5 + 15.0)
		cs.rotation = a + PI * 0.5
		add_child(cs)


func _ready() -> void:
	if ResourceLoader.exists(BLADES_TEX):
		_blades_tex = load(BLADES_TEX) as Texture2D
	if ResourceLoader.exists(HOUSE_TEX):
		_house_tex = load(HOUSE_TEX) as Texture2D


func _enter_tree() -> void:
	Sfx.loop_on(self, "windmill_loop")


func _exit_tree() -> void:
	Sfx.loop_off(self, "windmill_loop")


func _physics_process(delta: float) -> void:
	_t += delta
	rotation += spin * delta
	position.y += fall * delta
	if position.y - blade_len > 1000.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# 小屋（回転を打ち消して描く。画面の外側へ半分はみ出す）
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	if _house_tex:
		draw_house_tex(self, _house_tex, HOUSE_W, HOUSE_HUB)
	else:
		draw_wall(Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# 羽根（回転したまま描く）
	if _blades_tex:
		draw_blades_tex(self, _blades_tex, blade_len, _scale_y)
	else:
		draw_blades(self, blade_len, _scale_y)
		draw_circle(Vector2.ZERO, 12.0, FRAME)
		draw_circle(Vector2.ZERO, 5.0, LINE)


func draw_wall(o: Vector2) -> void:
	var w := 64.0
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(-w * 0.5, 14.0), o + Vector2(w * 0.5, 14.0), o + Vector2(w * 0.7, 260.0), o + Vector2(-w * 0.7, 260.0),
	]), WALL)
	draw_colored_polygon(PackedVector2Array([
		o + Vector2(-w * 0.62, 18.0), o + Vector2(w * 0.62, 18.0), o + Vector2(0.0, -34.0),
	]), ROOF)
	draw_rect(Rect2(o + Vector2(-10.0, 70.0), Vector2(20.0, 26.0)), Color(0.42, 0.62, 0.86))
	draw_rect(Rect2(o + Vector2(-12.0, 210.0), Vector2(24.0, 50.0)), FRAME)


## 小屋の画像を、ハブの位置（hub = 画像内の割合）が原点に来るように描く（ボスの大風車でも使う）。
static func draw_house_tex(ci: CanvasItem, tex: Texture2D, width: float, hub: Vector2, tint := Color.WHITE) -> void:
	var h := width * float(tex.get_height()) / float(tex.get_width())
	ci.draw_texture_rect(tex, Rect2(-Vector2(width * hub.x, h * hub.y), Vector2(width, h)), false, tint)


## 羽根の画像を描く。fold < 1 で帆をたたんだように細くする（退場時）。
static func draw_blades_tex(ci: CanvasItem, tex: Texture2D, length: float, fold: float) -> void:
	var size := length * 2.0
	ci.draw_texture_rect(tex, Rect2(-Vector2(size, size) * 0.5, Vector2(size, size)), false,
		Color(1.0, 1.0, 1.0, lerpf(0.55, 1.0, fold)))


## 羽根をコードで描く（ボスの大風車でも使う）。fold < 1 で帆をたたんで細くする。
static func draw_blades(ci: CanvasItem, length: float, fold: float) -> void:
	for i in 4:
		var a := TAU * float(i) / 4.0
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		var w := 30.0 * fold
		var p0 := d * 28.0
		var p1 := d * length
		ci.draw_line(Vector2.ZERO, p1, FRAME, 5.0, true)
		if w > 1.0:
			var sail := PackedVector2Array([p0, p1, p1 + n * w, p0 + n * w * 0.8])
			ci.draw_colored_polygon(sail, SAIL)
			for k in 5:
				var t := float(k + 1) / 6.0
				ci.draw_line(p0.lerp(p1, t), p0.lerp(p1, t) + n * w * lerpf(0.8, 1.0, t), FRAME, 1.4, true)
			ci.draw_line(p0 + n * w * 0.8, p1 + n * w, FRAME, 2.0, true)
