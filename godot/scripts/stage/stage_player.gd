extends "res://scripts/player.gd"
## ステージ用のメルル。帽子ライフの被弾判定、無敵時間、猫の同乗、白猫バリア、煙での減速を持つ。
## 帽子の数そのものはステージ側（stage_base.gd）が管理し、ここは「当たった」ことを知らせるだけ。

signal damaged
signal cat_caught(cat: Area2D)
signal courage_got(shard: Area2D)
signal smoke_changed(inside: bool)
## 当たっても帽子は落ちないが、はじかれるもの（group "bumpers"。STAGE 2 の風船など）に触れた
signal bumped(area: Area2D)

## 同乗している猫の位置（ほうきの後ろ）。仮グラフィック用の目安。
const RIDER_POS := Vector2(-76.0, -48.0)
const CURLED_POS := Vector2(-97.0, -24.0)

const TABBY := Color(1.0, 0.66, 0.32)
const TABBY_STRIPE := Color(0.78, 0.42, 0.16)
const WHITE_CAT := Color(0.98, 0.97, 0.95)
const CAT_LINE := Color(0.25, 0.16, 0.22, 0.9)

## 残りの無敵時間（秒）。被弾直後に点滅する。
var invincible := 0.0
## true の間は被弾しない（白猫のバリア）。
var barrier := false
## テスト・撮影用。true なら何に当たっても被弾しない。
var god_mode := false

## 同乗している猫の毛色。最後の 1 匹が効果を出している猫、残りは穂先で丸くなっている。
var riders: Array[int] = []
var rider_active := false

var _smoke_count := 0
var _hit_flash := 0.0
var _spin_faint := false
var _front: Node2D
var _knock := Vector2.ZERO


func _ready() -> void:
	super()
	_build_front()
	area_exited.connect(_on_area_exited)
	# 取得判定は被弾判定より広い別 Area2D（CatchArea）。見た目に触れたら拾えるようにする。
	var catch_area := get_node_or_null("CatchArea") as Area2D
	if catch_area:
		catch_area.area_entered.connect(_on_area_entered)
		catch_area.area_exited.connect(_on_area_exited)


func spawn_at(pos: Vector2) -> void:
	super(pos)
	push = Vector2.ZERO
	speed_mul = 1.0
	invincible = 0.0
	barrier = false
	riders.clear()
	rider_active = false
	_smoke_count = 0
	_hit_flash = 0.0
	_spin_faint = false
	_knock = Vector2.ZERO
	rotation = _tilt


## 被弾したあとに呼ぶ。点滅しながら一定時間当たらなくなる。
func start_invincible(seconds: float) -> void:
	invincible = seconds
	_hit_flash = 0.3
	if _sprite and _tex_hit:
		_sprite.texture = _tex_hit
	var punch := create_tween()
	punch.tween_property(self, "scale", Vector2(1.1, 0.9), 0.05)
	punch.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 帽子が全部なくなったとき。目を回してくるくる回る。
func faint() -> void:
	die()
	push = Vector2.ZERO
	_spin_faint = true
	riders.clear()
	rider_active = false
	barrier = false


## はじき飛ばす（風船にぶつかったときなど）。すぐに減衰する。
func knock(v: Vector2) -> void:
	_knock = v


func add_rider(fur: int) -> void:
	riders.append(fur)
	if riders.size() > 4:
		riders.remove_at(0)
	rider_active = true


func _process(delta: float) -> void:
	super(delta)
	if invincible > 0.0:
		invincible = maxf(invincible - delta, 0.0)
		modulate.a = 0.35 if int(invincible * 14.0) % 2 == 0 else 1.0
		if invincible <= 0.0:
			modulate.a = 1.0
	if _hit_flash > 0.0:
		_hit_flash -= delta
		if _hit_flash <= 0.0 and alive and _sprite and _tex_idle:
			_sprite.texture = _tex_idle
	if _spin_faint:
		rotation += delta * 9.0
	_front.queue_redraw()


func _physics_process(delta: float) -> void:
	super(delta)
	if _knock != Vector2.ZERO:
		if alive:
			position += _knock * delta
			position.x = clampf(position.x, 40.0, GAME_W - 40.0)
			position.y = clampf(position.y, GAME_H * 0.24, GAME_H - 60.0)
		_knock = _knock.move_toward(Vector2.ZERO, 1400.0 * delta)
	if alive and active:
		_check_obstacles()


## 当たり判定は毎フレームの重なりで見る。無敵が切れた瞬間に重なっていても被弾できるようにするため。
## ここで見るのは本体の Area2D（collision_mask = 障害物のみ）。取得物は CatchArea が拾う。
func _check_obstacles() -> void:
	if god_mode or barrier or invincible > 0.0 or not monitoring:
		return
	for area in get_overlapping_areas():
		if area.is_in_group("obstacles"):
			damaged.emit()
			return


func _on_area_entered(area: Area2D) -> void:
	if not alive or not active:
		return
	if area.is_in_group("courage"):
		courage_got.emit(area)
	elif area.is_in_group("cats"):
		cat_caught.emit(area)
	elif area.is_in_group("bumpers"):
		bumped.emit(area)
	elif area.is_in_group("smoke"):
		_smoke_count += 1
		if _smoke_count == 1:
			smoke_changed.emit(true)


func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("smoke") and _smoke_count > 0:
		_smoke_count -= 1
		if _smoke_count == 0:
			smoke_changed.emit(false)


# ---------------------------------------------------------------- 描画（仮）
# 猫とバリアは魔女スプライトより手前に描きたいので、スプライトの後に足した子ノード（_front）に描く。

func _build_front() -> void:
	_front = Node2D.new()
	_front.name = "FrontLayer"
	add_child(_front)          # スプライトより後に足すので手前に描かれる
	_front.draw.connect(_draw_front)


func _draw_front() -> void:
	var ci := _front
	# 穂先で丸くなっている猫（効果を終えた猫）
	var curled := riders.size() - (1 if rider_active else 0)
	for i in curled:
		var p := CURLED_POS + Vector2(-float(i) * 13.0, float(i) * 6.0)
		_draw_curled_cat(ci, p, riders[i])
	# 効果を出している猫（ほうきの穂にしがみつく）
	if rider_active and not riders.is_empty():
		_draw_rider(ci, RIDER_POS, riders[riders.size() - 1])
	if barrier:
		_draw_barrier(ci)


func _fur_color(fur: int) -> Color:
	return TABBY if fur == 0 else WHITE_CAT


func _draw_rider(ci: CanvasItem, p: Vector2, fur: int) -> void:
	var c := _fur_color(fur)
	p.y += sin(_t * 6.0) * 1.5
	ci.draw_arc(p + Vector2(-12.0, 6.0), 10.0, PI * 0.6, PI * 1.6, 10, c, 5.0, true)   # しっぽ
	ci.draw_circle(p + Vector2(0.0, 6.0), 13.0, c)                                       # 胴
	ci.draw_circle(p + Vector2(8.0, -9.0), 11.0, c)                                      # 頭
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0.0, -15.0), p + Vector2(2.0, -26.0), p + Vector2(8.0, -18.0)]), c)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(9.0, -19.0), p + Vector2(15.0, -27.0), p + Vector2(17.0, -14.0)]), c)
	if fur == 0:
		for i in 3:
			ci.draw_line(p + Vector2(-6.0 + i * 6.0, -3.0), p + Vector2(-5.0 + i * 6.0, 15.0), TABBY_STRIPE, 2.5, true)
	ci.draw_arc(p + Vector2(0.0, 6.0), 13.0, 0.0, TAU, 20, CAT_LINE, 1.4, true)
	ci.draw_arc(p + Vector2(8.0, -9.0), 11.0, 0.0, TAU, 20, CAT_LINE, 1.4, true)
	ci.draw_circle(p + Vector2(5.0, -10.0), 1.8, CAT_LINE)
	ci.draw_circle(p + Vector2(12.0, -10.0), 1.8, CAT_LINE)


func _draw_curled_cat(ci: CanvasItem, p: Vector2, fur: int) -> void:
	var c := _fur_color(fur)
	ci.draw_circle(p, 9.0, c)
	ci.draw_arc(p, 9.0, 0.0, TAU, 16, CAT_LINE, 1.2, true)
	ci.draw_arc(p, 5.5, PI * 0.2, PI * 1.2, 8, CAT_LINE, 1.2, true)


func _draw_barrier(ci: CanvasItem) -> void:
	var center := Vector2(-22.0, -22.0)
	var r := 64.0 + sin(_t * 5.0) * 2.5
	ci.draw_circle(center, r, Color(1.0, 1.0, 1.0, 0.16))
	for i in 14:
		var a := TAU * float(i) / 14.0 + _t * 0.8
		ci.draw_circle(center + Vector2(cos(a), sin(a)) * r, 11.0, Color(1.0, 1.0, 1.0, 0.42))
