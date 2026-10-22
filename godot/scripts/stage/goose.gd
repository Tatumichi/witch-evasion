extends Area2D
## 渡り鳥（STAGE 2）。ステージ側が V 字の隊列に並べ、斜めに横切らせる。
## 隊列の内側（V のくぼみ）は安全地帯。キャンディが当たると驚いて逃げる。横風に少し流される。
##
## 画像: assets/props/goose.png があれば使う。**右向き**で描く（左へ飛ぶときはゲーム側で反転）。
##       幅 DRAW_W px、胴の中心が原点。羽ばたきは画像を上下に揺らして表す。無ければコード描画。
## 音:   逃げる → geese_scatter（専用音が無いあいだは FALLBACK で pigeon_scatter を低めに）。隊列の出現は stage2.gd が geese_incoming。

const Sfx := preload("res://scripts/stage/sfx.gd")
const TEX_PATH := "res://assets/props/goose.png"
const DRAW_W := 62.0

const BODY := Color(0.50, 0.42, 0.36)
const WING := Color(0.40, 0.33, 0.28)
const NECK := Color(0.20, 0.18, 0.20)
const CHEEK := Color(0.95, 0.94, 0.90)
const LINE := Color(0.18, 0.14, 0.16, 0.85)

var vel := Vector2.ZERO
var wind := 0.0

var _t := 0.0
var _ph := 0.0
var _fleeing := false
var _tex: Texture2D


func setup(start: Vector2, velocity_px: Vector2, phase: float) -> void:
	position = start
	vel = velocity_px
	_ph = phase
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	add_to_group("breakable")
	add_to_group("windable")
	var s := CircleShape2D.new()
	s.radius = 18.0
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)


func _ready() -> void:
	if ResourceLoader.exists(TEX_PATH):
		_tex = load(TEX_PATH) as Texture2D


func break_apart() -> void:
	if _fleeing:
		return
	_fleeing = true
	Sfx.fire(self, "geese_scatter", {"x": global_position.x, "pitch_jitter": 0.06})
	remove_from_group("obstacles")
	remove_from_group("breakable")
	set_deferred("monitorable", false)
	vel = Vector2(vel.x * 1.5, -300.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	position += (vel + Vector2(wind * 0.3, 0.0)) * delta
	if position.y > 1080.0 or position.x < -260.0 or position.x > 800.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var f := 1.0 if vel.x >= 0.0 else -1.0
	var flap := sin(_t * (16.0 if _fleeing else 7.0) + _ph)
	if _tex:
		var h := DRAW_W * float(_tex.get_height()) / float(_tex.get_width())
		draw_set_transform(Vector2(0.0, flap * 2.5), flap * 0.06, Vector2(f, 1.0))
		draw_texture_rect(_tex, Rect2(-Vector2(DRAW_W, h) * 0.5, Vector2(DRAW_W, h)), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(f, 1.0))
	# 翼（奥）
	draw_colored_polygon(PackedVector2Array([Vector2(-6.0, 0.0), Vector2(6.0, 0.0), Vector2(-2.0, -8.0 - flap * 18.0)]), WING.darkened(0.15))
	# 胴・首・頭
	draw_colored_polygon(PackedVector2Array([Vector2(-18.0, 2.0), Vector2(-8.0, -6.0), Vector2(10.0, -4.0), Vector2(14.0, 3.0), Vector2(-4.0, 8.0)]), BODY)
	draw_line(Vector2(10.0, -2.0), Vector2(22.0, -10.0), NECK, 4.5, true)
	draw_circle(Vector2(24.0, -11.0), 4.5, NECK)
	draw_circle(Vector2(23.0, -9.0), 1.8, CHEEK)
	draw_colored_polygon(PackedVector2Array([Vector2(28.0, -12.0), Vector2(33.0, -10.0), Vector2(28.0, -9.0)]), Color(0.25, 0.22, 0.20))
	# 翼（手前）
	draw_colored_polygon(PackedVector2Array([Vector2(-8.0, -1.0), Vector2(8.0, -1.0), Vector2(-6.0, -6.0 + flap * 20.0)]), WING)
	draw_polyline(PackedVector2Array([Vector2(-18.0, 2.0), Vector2(-8.0, -6.0), Vector2(10.0, -4.0), Vector2(14.0, 3.0), Vector2(-4.0, 8.0), Vector2(-18.0, 2.0)]), LINE, 1.3, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
