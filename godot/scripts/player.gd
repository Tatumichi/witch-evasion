extends Area2D
## 魔女の少女。横を向いたまま上空へ飛ぶ。ほうきの先から光の軌跡を引く。

signal hit
signal picked(amount: int)

const GAME_W := 540.0
const GAME_H := 960.0
const BASE_Y := 710.0
const DRAW_SCALE := 0.95

## 生成した魔女スプライト。無ければ下のコード描画にフォールバックする。
const SPRITE_PATH := "res://assets/characters/witch/witch_sprite.png"
const HIT_SPRITE_PATH := "res://assets/characters/witch/witch_hit.png"
const SPRITE_ORIGIN := Vector2(135.0, 125.0)   # 画像内でゲーム座標(0,0)にあたる画素
## スプライトの見た目の中心（tools/prepare_sprite.py の --center と一致）。
## 当たり判定はこの点を基準に置く。ノード原点 (0,0) は絵の中心ではない。
const VISUAL_CENTER := Vector2(-16.0, -32.0)
const TRAIL_ANCHOR := Vector2(-70.0, -28.0)    # ほうきの穂先（後方）

const SKIN := Color(1.0, 0.88, 0.79)
const BLUSH := Color(1.0, 0.55, 0.65)
const HAIR := Color(0.96, 0.56, 0.79)
const DRESS := Color(0.96, 0.93, 0.99)
const HAT := Color(0.24, 0.11, 0.33)
const HAT_DARK := Color(0.16, 0.06, 0.23)
const HAT_LIGHT := Color(0.34, 0.17, 0.45)
const WOOD := Color(0.55, 0.37, 0.27)
const BRISTLE := Color(0.80, 0.64, 0.44)
const OUTLINE := Color(0.10, 0.03, 0.14, 0.85)

@export var max_speed := 440.0
@export var accel := 9.0

var velocity := Vector2.ZERO
var active := false
var alive := true
## 外から加わる押し流し（ボスの突風など）。ステージ側が設定する。既定は 0。
var push := Vector2.ZERO
## 移動速度の倍率（煙の中で遅くなるなど）。既定は 1。
var speed_mul := 1.0

var _t := 0.0
var _tilt := -0.24
var _trail: Line2D
var _sprite: Sprite2D
var _tex_idle: Texture2D
var _tex_hit: Texture2D
var _history: Array[Vector2] = []


func _ready() -> void:
	collision_layer = 1
	# collision_mask はシーン側で決める（旧 main.tscn は障害物＋ピックアップ、stage1 は障害物のみ）
	area_entered.connect(_on_area_entered)
	_build_sprite()
	_build_trail()


## スプライトがあれば親の原点に合わせて配置する。画像はゲーム解像度で焼き込み済みなので拡縮不要。
func _build_sprite() -> void:
	if not ResourceLoader.exists(SPRITE_PATH):
		return
	var texture := load(SPRITE_PATH) as Texture2D
	if texture == null:
		return
	_tex_idle = texture
	if ResourceLoader.exists(HIT_SPRITE_PATH):
		_tex_hit = load(HIT_SPRITE_PATH) as Texture2D
	_sprite = Sprite2D.new()
	_sprite.name = "WitchSprite"
	_sprite.texture = texture
	_sprite.centered = false
	_sprite.position = -SPRITE_ORIGIN
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)


func _build_trail() -> void:
	_trail = Line2D.new()
	_trail.top_level = true          # ワールドの揺れに影響されない
	_trail.width = 12.0
	_trail.default_color = Color(1.0, 0.62, 0.9, 0.5)
	_trail.antialiased = true
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.z_index = -1

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.05))
	curve.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = curve

	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.55, 0.85, 0.0))
	grad.set_color(1, Color(1.0, 0.84, 0.96, 0.5))
	_trail.gradient = grad

	add_child(_trail)


## タイトル画面へ戻すときに呼ぶ。
func spawn_at(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	alive = true
	active = false
	modulate = Color.WHITE
	scale = Vector2.ONE
	_tilt = -0.24
	rotation = _tilt
	_history.clear()
	if _sprite and _tex_idle:
		_sprite.texture = _tex_idle
	if _trail:
		_trail.points = PackedVector2Array()
		_trail.visible = true
	set_deferred("monitoring", true)
	show()


func die() -> void:
	alive = false
	active = false
	set_deferred("monitoring", false)
	if _trail:
		_trail.visible = false
	if _sprite and _tex_hit:
		_sprite.texture = _tex_hit

	# 被弾の「めり込み」を一瞬だけ見せる。
	var punch := create_tween()
	punch.tween_property(self, "scale", Vector2(1.08, 0.92), 0.05)
	punch.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.0, 0.45, 0.55, 1.0), 0.06)
	tw.tween_property(self, "modulate", Color(1.0, 0.9, 0.95, 0.45), 0.35)


func _process(delta: float) -> void:
	_t += delta

	if alive:
		var target := -0.24 + clampf(velocity.x / max_speed, -1.0, 1.0) * 0.38
		if not active:
			target = -0.24 + sin(_t * 1.6) * 0.05
		_tilt = lerpf(_tilt, target, 1.0 - exp(-8.0 * delta))
		rotation = _tilt

		if not active:
			position.y = BASE_Y + sin(_t * 1.6) * 6.0

	if _sprite:
		_sprite.position = -SPRITE_ORIGIN + Vector2(0.0, sin(_t * 3.1) * 2.0)

	_update_trail()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not alive:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		position += velocity * delta
		return

	var dir := Vector2.ZERO
	if active:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	velocity = velocity.lerp(dir * max_speed * speed_mul, 1.0 - exp(-accel * delta))
	position += (velocity + push) * delta
	position.x = clampf(position.x, 40.0, GAME_W - 40.0)
	position.y = clampf(position.y, GAME_H * 0.24, GAME_H - 60.0)


func _update_trail() -> void:
	if not alive or not active:
		if _trail and not _history.is_empty():
			_history.clear()
			_trail.points = PackedVector2Array()
		return

	var anchor := TRAIL_ANCHOR if _sprite else Vector2(-46.0, 16.0)
	var head := global_position + anchor.rotated(rotation)
	_history.push_front(head)
	while _history.size() > 18:
		_history.pop_back()
	_trail.points = PackedVector2Array(_history)


func _on_area_entered(area: Area2D) -> void:
	if not alive or not active:
		return
	if area.is_in_group("pickups"):
		picked.emit(25)
		area.queue_free()
	elif area.is_in_group("obstacles"):
		hit.emit()


# ---------------------------------------------------------------- 描画

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(DRAW_SCALE, DRAW_SCALE))
	_draw_glow()
	if _sprite == null:
		_draw_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glow() -> void:
	for i in 8:
		var k := float(i) / 7.0
		draw_circle(Vector2(-4.0, -22.0), lerpf(16.0, 54.0, k), Color(1.0, 0.62, 0.85, 0.007))


func _draw_body() -> void:
	var flutter := sin(_t * 7.0) * 3.0

	# --- ほうき（体の奥） ---
	draw_line(Vector2(-48.0, 16.0), Vector2(36.0, 2.0), WOOD, 5.5, true)
	for tip in [
		Vector2(-74.0, 4.0), Vector2(-79.0, -4.0), Vector2(-76.0, 12.0),
		Vector2(-70.0, 21.0), Vector2(-62.0, 27.0), Vector2(-54.0, 26.0),
	]:
		draw_line(Vector2(-48.0, 16.0), tip, BRISTLE, 3.0, true)
	draw_line(Vector2(-50.0, 11.0), Vector2(-46.0, 21.0), HAT_DARK, 4.0, true)

	# --- マント（2 枚重ねで布らしく） ---
	_poly([
		Vector2(-8.0, -34.0), Vector2(-2.0, -16.0),
		Vector2(-26.0 + flutter, 0.0), Vector2(-30.0, -22.0),
	], HAT, OUTLINE)
	_poly([
		Vector2(-9.0, -32.0), Vector2(-4.0, -18.0),
		Vector2(-18.0 + flutter * 0.6, -6.0), Vector2(-20.0, -24.0),
	], HAT_LIGHT, null)

	# --- 髪のボリューム（頭の後ろ） ---
	draw_circle(Vector2(0.0, -46.0), 11.5, HAIR)
	_poly([Vector2(-6.0, -50.0), Vector2(-24.0 + flutter, -46.0), Vector2(-10.0, -36.0)], HAIR, OUTLINE)

	# --- ブーツ ---
	_poly([Vector2(-8.0, 12.0), Vector2(0.0, 12.0), Vector2(2.0, 24.0), Vector2(-6.0, 24.0)], HAT_DARK, OUTLINE)
	_poly([Vector2(0.0, 12.0), Vector2(8.0, 12.0), Vector2(10.0, 24.0), Vector2(2.0, 24.0)], HAT_DARK, OUTLINE)

	# --- スカート / ベルト / 胴 ---
	_poly([Vector2(-10.0, -17.0), Vector2(10.0, -17.0), Vector2(19.0, 12.0), Vector2(-19.0, 12.0)], DRESS, OUTLINE)
	_poly([Vector2(-10.0, -20.0), Vector2(10.0, -20.0), Vector2(10.0, -16.0), Vector2(-10.0, -16.0)], HAT, null)
	_poly([Vector2(-8.0, -34.0), Vector2(8.0, -34.0), Vector2(10.0, -19.0), Vector2(-10.0, -19.0)], DRESS, OUTLINE)

	# --- 腕（ほうきを握る） ---
	draw_line(Vector2(2.0, -27.0), Vector2(16.0, -4.0), DRESS, 4.5, true)

	# --- 頭 ---
	draw_circle(Vector2(2.0, -44.0), 10.0, SKIN)
	draw_arc(Vector2(2.0, -44.0), 10.0, 0.0, TAU, 24, OUTLINE, 1.5, true)

	# --- 前髪（目の上で止める） ---
	_poly([Vector2(-7.0, -53.0), Vector2(2.0, -54.0), Vector2(1.0, -45.0), Vector2(-7.0, -47.0)], HAIR, null)
	_poly([Vector2(2.0, -54.0), Vector2(10.0, -52.0), Vector2(6.0, -45.0), Vector2(1.0, -45.0)], HAIR, null)

	# --- 目と頬 ---
	draw_circle(Vector2(8.5, -41.0), 1.7, OUTLINE)
	draw_circle(Vector2(10.5, -37.0), 2.6, Color(BLUSH.r, BLUSH.g, BLUSH.b, 0.35))

	# --- 帽子：つば / 山 / リボン ---
	_ellipse(Vector2(0.0, -54.0), 27.0, 5.5, HAT, OUTLINE)
	_poly([Vector2(-13.0, -54.0), Vector2(9.0, -55.0), Vector2(-18.0, -92.0)], HAT_DARK, OUTLINE)
	_poly([Vector2(-17.0, -56.0), Vector2(-27.0, -64.0), Vector2(-22.0, -50.0)], HAIR, OUTLINE)

	# --- 先端のランプ ---
	draw_circle(Vector2(36.0, 2.0), 10.0, Color(1.0, 0.9, 0.55, 0.10))
	draw_circle(Vector2(36.0, 2.0), 4.0, Color(1.0, 0.96, 0.76, 0.95))


func _poly(points: Array, fill: Color, outline) -> void:
	var p := PackedVector2Array(points)
	draw_colored_polygon(p, fill)
	if outline != null:
		var closed := p.duplicate()
		closed.append(p[0])
		draw_polyline(closed, outline, 1.6, true)


func _ellipse(center: Vector2, rx: float, ry: float, fill: Color, outline) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, fill)
	if outline != null:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, outline, 1.6, true)
