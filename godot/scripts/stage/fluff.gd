extends Area2D
## たんぽぽの綿毛（STAGE 2）。1 粒ずつは当たり判定が小さい。
## ステージ側が「嵐」としてまとめて降らせ、すき間をぬって進ませる。キャンディで吹き飛ばせる。横風（wind）に流される。
##
## 画像: assets/props/fluff.png があれば使う（幅 DRAW_W px、綿毛の玉の中心が原点）。無ければ下のコード描画。
## 音:   嵐の綿毛（in_storm）が画面にあるあいだ storm_loop をループ（何粒いても 1 本）。吹き飛ぶと laundry_pop を高めに。

const Sfx := preload("res://scripts/stage/sfx.gd")
const TEX_PATH := "res://assets/props/fluff.png"
const DRAW_W := 30.0

const PUFF := Color(1.0, 1.0, 1.0, 0.92)
const STEM := Color(0.62, 0.56, 0.42)
const SEED := Color(0.52, 0.42, 0.30)

var vel := Vector2.ZERO
## 横風の速さ（px/秒）。ステージ側が毎フレーム入れる。
var wind := 0.0
## 嵐の一部なら true（画面にいるあいだ風音を鳴らす）
var in_storm := false

var _t := 0.0
var _ph := 0.0
var _broken := false
var _tex: Texture2D
var _looping := false


func setup(start: Vector2, velocity_px: Vector2, rng: RandomNumberGenerator, storm := false) -> void:
	position = start
	vel = velocity_px
	in_storm = storm
	_ph = rng.randf() * TAU
	rotation = rng.randf_range(-0.4, 0.4)
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	add_to_group("breakable")
	add_to_group("windable")
	var s := CircleShape2D.new()
	s.radius = 7.0
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)


func _ready() -> void:
	if ResourceLoader.exists(TEX_PATH):
		_tex = load(TEX_PATH) as Texture2D


func _exit_tree() -> void:
	_set_loop(false)


func _set_loop(on: bool) -> void:
	if on == _looping:
		return
	_looping = on
	if on:
		Sfx.loop_on(self, "storm_loop")
	else:
		Sfx.loop_off(self, "storm_loop")


func break_apart() -> void:
	if _broken:
		return
	_broken = true
	remove_from_group("obstacles")
	remove_from_group("breakable")
	set_deferred("monitorable", false)
	Sfx.fire(self, "laundry_pop", {"x": global_position.x, "pitch": 1.35, "pitch_jitter": 0.08})
	_set_loop(false)
	vel = Vector2(randf_range(-160.0, 160.0), -320.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	var sway := Vector2(sin(_t * 2.0 + _ph) * 22.0, cos(_t * 1.6 + _ph) * 10.0)
	position += (vel + sway + Vector2(wind * 0.95, 0.0)) * delta
	rotation += sin(_t * 1.3 + _ph) * 0.4 * delta
	if in_storm and not _broken:
		_set_loop(position.y > -10.0 and position.y < 970.0)
	if position.y > 1000.0 or position.x < -80.0 or position.x > 620.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _tex:
		var h := DRAW_W * float(_tex.get_height()) / float(_tex.get_width())
		draw_texture_rect(_tex, Rect2(-Vector2(DRAW_W, h) * 0.5, Vector2(DRAW_W, h)), false)
		return
	draw_line(Vector2(0.0, 2.0), Vector2(0.0, 14.0), STEM, 1.4, true)
	draw_circle(Vector2(0.0, 15.0), 2.2, SEED)
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 1.0, 1.0, 0.22))
	for i in 10:
		var a := TAU * float(i) / 10.0
		var tip := Vector2(cos(a), sin(a)) * 10.0
		draw_line(Vector2.ZERO, tip, PUFF, 1.1, true)
		draw_circle(tip, 1.3, PUFF)
	draw_circle(Vector2.ZERO, 2.0, Color(0.95, 0.92, 0.80))
