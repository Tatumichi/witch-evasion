extends Area2D
## はぐれ大風車が放り出す小麦粉の袋（STAGE 2 ボス）。放物線で飛び、しばらくすると破れて
## 白い粉（flour_cloud.gd）を広げる。粉には当たり判定がなく、視界をふさぐだけ。
## 袋そのものは障害物。キャンディで早めに破ける（その場で粉が出る）。
##
## 画像: assets/props/flour_bag.png があれば使う（幅 DRAW_W px、袋の中心が原点）。無ければコード描画。
## 音:   破れる → smoke_in（ぼふっ）。投げる音はボス側（boss_windmill.gd）。

const CloudScript := preload("res://scripts/stage/flour_cloud.gd")
const Sfx := preload("res://scripts/stage/sfx.gd")
const TEX_PATH := "res://assets/props/flour_bag.png"
const DRAW_W := 40.0

const SACK := Color(0.90, 0.84, 0.70)
const TIE := Color(0.62, 0.44, 0.30)
const LINE := Color(0.32, 0.24, 0.20, 0.85)
const GRAVITY := 380.0

var vel := Vector2.ZERO
var burst_after := 1.4

var _t := 0.0
var _done := false
var _tex: Texture2D


func setup(start: Vector2, velocity_px: Vector2, burst_time: float) -> void:
	position = start
	vel = velocity_px
	burst_after = burst_time
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	add_to_group("breakable")
	var s := CircleShape2D.new()
	s.radius = 16.0
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)


func _ready() -> void:
	if ResourceLoader.exists(TEX_PATH):
		_tex = load(TEX_PATH) as Texture2D


func break_apart() -> void:
	_burst()


func _burst() -> void:
	if _done:
		return
	_done = true
	remove_from_group("obstacles")
	remove_from_group("breakable")
	set_deferred("monitorable", false)
	Sfx.fire(self, "smoke_in", {"x": global_position.x, "pitch_jitter": 0.06})
	var c = CloudScript.new()
	c.setup(global_position)
	get_parent().add_child.call_deferred(c)
	queue_free()


func _physics_process(delta: float) -> void:
	_t += delta
	vel.y += GRAVITY * delta
	position += vel * delta
	rotation += 3.0 * delta
	if _t >= burst_after:
		_burst()
	elif position.y > 1060.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _tex:
		var h := DRAW_W * float(_tex.get_height()) / float(_tex.get_width())
		draw_texture_rect(_tex, Rect2(-Vector2(DRAW_W, h) * 0.5, Vector2(DRAW_W, h)), false)
		return
	var body := PackedVector2Array([Vector2(-14.0, -10.0), Vector2(14.0, -10.0), Vector2(17.0, 16.0), Vector2(-17.0, 16.0)])
	draw_colored_polygon(body, SACK)
	draw_colored_polygon(PackedVector2Array([Vector2(-8.0, -10.0), Vector2(8.0, -10.0), Vector2(4.0, -20.0), Vector2(-4.0, -20.0)]), SACK)
	draw_line(Vector2(-9.0, -11.0), Vector2(9.0, -11.0), TIE, 3.0)
	var closed := body.duplicate()
	closed.append(body[0])
	draw_polyline(closed, LINE, 1.5, true)
	draw_circle(Vector2(0.0, 4.0), 5.0, Color(1.0, 1.0, 1.0, 0.8))
