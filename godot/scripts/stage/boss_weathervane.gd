extends Area2D
## STAGE 1 ボス「ぐるぐる大風見鶏」（仮グラフィック）。
## とさかに猫がぶら下がったせいで回転が止まらず、風をまき散らしている。
## 倒す相手ではない。満足ゲージが満タンになれば落ち着いて村へ帰っていく。
##
## 攻撃サイクル（設定書 STAGE 1 の 1〜3 をくり返す）:
##   ARROWS : 左右に揺れながら、矢印型の風向き板を 3 方向に飛ばす
##   GUST   : ぐるっと回転して突風。メルルが画面端へ押し流される（当たり判定なし）
##   STORM  : 突風に乗って洗濯物が大量に飛んでくる

signal satisfied
signal drop_cat(pos: Vector2)
signal gust_changed(force: Vector2)
signal left_screen

const LaundryScript := preload("res://scripts/stage/laundry.gd")
const ArrowScript := preload("res://scripts/stage/wind_arrow.gd")
const FONT := preload("res://assets/fonts/MPLUSRounded1c-Bold.ttf")
const Sfx := preload("res://scripts/stage/sfx.gd")

## 何もしなくても 50 秒で満タン。キャンディ 1 発で 0.014 増える（設定書: 最短 25 秒程度）。
const NATURAL_RATE := 1.0 / 50.0
const FEED_AMOUNT := 0.014
const HOME := Vector2(270.0, 205.0)   # 満足ゲージの下に来る高さ
const CAT_DROP_AT := 9.0
const GUST_FORCE := 230.0

enum Mode { ENTER, WAIT, FIGHT, LEAVE, GONE }
enum Attack { ARROWS, GUST, STORM }

const IRON := Color(0.22, 0.18, 0.28)
const IRON_LIGHT := Color(0.38, 0.32, 0.46)
const GOLD := Color(0.96, 0.78, 0.40)
const COMB := Color(0.90, 0.30, 0.32)
const TABBY := Color(1.0, 0.66, 0.32)
const LINE := Color(0.25, 0.16, 0.22, 0.95)

var mode: int = Mode.ENTER
var satisfaction := 0.0
var has_cat := true

var _world: Node2D
var _rng: RandomNumberGenerator
var _scroll := 230.0
var _t := 0.0
var _fight_t := 0.0
var _attack: int = Attack.ARROWS
var _attack_t := 0.0
var _volley_cd := 0.8
var _laundry_cd := 0.0
var _gust_dir := 1.0
var _spin := 0.0
var _spin_speed := 2.4
var _feed_flash := 0.0
var _leave_t := 0.0
var _debug_symbol := ""
var _force := Vector2.ZERO
var _storm_sound := false


func setup(world: Node2D, rng: RandomNumberGenerator, scroll: float) -> void:
	_world = world
	_rng = rng
	_scroll = scroll
	position = Vector2(HOME.x, -160.0)
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")
	add_to_group("boss")
	var s := CircleShape2D.new()
	s.radius = 60.0
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)
	z_index = 2


## 登場して所定の位置に着いたら true（ステージ側はこれを見てボス戦を始める）。
func is_ready() -> bool:
	return mode == Mode.WAIT


## 登場演出が終わったらステージ側が呼ぶ。
func begin_fight() -> void:
	mode = Mode.FIGHT
	_fight_t = 0.0
	_start_attack(Attack.ARROWS)
	Sfx.fire(self, "boss_crow")


func feed() -> void:
	if mode != Mode.FIGHT:
		return
	satisfaction = minf(satisfaction + FEED_AMOUNT, 1.0)
	_feed_flash = 0.18


## テスト用：満足ゲージを直接進める。
func debug_fill(amount: float) -> void:
	satisfaction = minf(satisfaction + amount, 1.0)


func _set_force(f: Vector2) -> void:
	if f != _force:
		# 突風が吹き始めた瞬間。風上（押される向きの反対側）から聞こえるようにする
		if _attack == Attack.GUST and f.x != 0.0 and _force == Vector2.ZERO:
			Sfx.fire(self, "gust", {"x": 270.0 - signf(f.x) * 230.0})
		_force = f
		gust_changed.emit(f)


func _start_attack(a: int) -> void:
	_attack = a
	_attack_t = 0.0
	_set_storm_sound(a == Attack.STORM)
	match a:
		Attack.ARROWS:
			_volley_cd = 0.6
			_set_force(Vector2.ZERO)
		Attack.GUST:
			_gust_dir = 1.0 if _rng.randf() < 0.5 else -1.0
			Sfx.fire(self, "gust_warning")
		Attack.STORM:
			_laundry_cd = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_spin += _spin_speed * delta
	_feed_flash = maxf(_feed_flash - delta, 0.0)

	match mode:
		Mode.ENTER:
			position.y = move_toward(position.y, HOME.y, 170.0 * delta)
			if is_equal_approx(position.y, HOME.y):
				mode = Mode.WAIT
		Mode.WAIT:
			position.x = HOME.x + sin(_t * 0.8) * 20.0
		Mode.FIGHT:
			_fight(delta)
		Mode.LEAVE:
			_leave(delta)


func _fight(delta: float) -> void:
	_fight_t += delta
	_attack_t += delta
	satisfaction = minf(satisfaction + NATURAL_RATE * delta, 1.0)
	position.x = HOME.x + sin(_fight_t * 0.55) * 140.0
	position.y = HOME.y + sin(_fight_t * 1.3) * 8.0

	if has_cat and _fight_t >= CAT_DROP_AT:
		has_cat = false
		drop_cat.emit(global_position + Vector2(18.0, -60.0))

	var heat := satisfaction   # ゲージが進むほど少し激しくなる
	match _attack:
		Attack.ARROWS:
			_spin_speed = lerpf(_spin_speed, 2.4, 1.0 - exp(-3.0 * delta))
			_volley_cd -= delta
			if _volley_cd <= 0.0:
				_volley_cd = lerpf(1.6, 1.1, heat)
				_fire_volley(lerpf(220.0, 300.0, heat))
			if _attack_t >= 6.0:
				_start_attack(Attack.GUST)
		Attack.GUST:
			# 最初の 1 秒は予告（回転が速くなる）、その後 3 秒押し流す
			_spin_speed = lerpf(_spin_speed, 11.0, 1.0 - exp(-4.0 * delta))
			if _attack_t >= 1.0:
				_set_force(Vector2(_gust_dir * GUST_FORCE, 0.0))
			if _attack_t >= 4.0:
				_start_attack(Attack.STORM)
		Attack.STORM:
			_spin_speed = lerpf(_spin_speed, 6.0, 1.0 - exp(-3.0 * delta))
			_set_force(Vector2(_gust_dir * GUST_FORCE * 0.45, 0.0))
			_laundry_cd -= delta
			if _laundry_cd <= 0.0:
				_laundry_cd = lerpf(0.55, 0.38, heat)
				_spawn_storm_laundry()
			if _attack_t >= 4.5:
				_start_attack(Attack.ARROWS)

	if satisfaction >= 1.0:
		if has_cat:
			# 猫を落とす前に満足した場合も、猫はちゃんと落として受け止められるようにする
			has_cat = false
			drop_cat.emit(global_position + Vector2(18.0, -60.0))
		mode = Mode.LEAVE
		_leave_t = 0.0
		_set_force(Vector2.ZERO)
		_set_storm_sound(false)
		Sfx.fire(self, "boss_leave", {"delay": 1.4})
		remove_from_group("obstacles")
		set_deferred("monitorable", false)
		satisfied.emit()


func _leave(delta: float) -> void:
	_leave_t += delta
	_spin_speed = move_toward(_spin_speed, 0.0, 4.0 * delta)
	if _leave_t > 1.6:
		# 来たべき方角を向き直して、村（下）へ帰っていく
		position.y += 320.0 * delta
		if position.y > 1150.0:
			mode = Mode.GONE
			left_screen.emit()
			queue_free()


func _set_storm_sound(on: bool) -> void:
	if on == _storm_sound:
		return
	_storm_sound = on
	if on:
		Sfx.loop_on(self, "storm_loop")
	else:
		Sfx.loop_off(self, "storm_loop")


func _exit_tree() -> void:
	_set_storm_sound(false)


func _fire_volley(speed: float) -> void:
	var origin := global_position + Vector2(0.0, 40.0)
	Sfx.fire(self, "arrow_volley", {"x": origin.x, "pitch_jitter": 0.04})
	for deg in [-25.0, 0.0, 25.0]:
		var dir := Vector2.DOWN.rotated(deg_to_rad(deg))
		var a = ArrowScript.new()
		a.setup(origin, dir * speed)
		_world.add_child(a)


func _spawn_storm_laundry() -> void:
	var l = LaundryScript.new()
	var kind: int = LaundryScript.Kind.SOCK if _rng.randf() < 0.55 else LaundryScript.Kind.SHEET
	var from_x := -70.0 if _gust_dir > 0.0 else 610.0
	var y := _rng.randf_range(260.0, 760.0)
	var vx := _gust_dir * _rng.randf_range(170.0, 240.0)
	l.setup(kind, Vector2(from_x, y), Vector2(vx, _scroll * 0.25), _rng)
	_world.add_child(l)


func _process(_delta: float) -> void:
	queue_redraw()


# ---------------------------------------------------------------- 描画（仮）

func _draw() -> void:
	_draw_wind()

	# 支柱と方角の十字（回らない）
	draw_line(Vector2(0.0, 30.0), Vector2(0.0, 120.0), IRON, 7.0, true)
	draw_line(Vector2(-46.0, 92.0), Vector2(46.0, 92.0), IRON, 4.0, true)
	draw_line(Vector2(0.0, 70.0), Vector2(0.0, 114.0), IRON, 4.0, true)
	for item in [["W", Vector2(-62.0, 98.0)], ["E", Vector2(50.0, 98.0)], ["N", Vector2(-6.0, 70.0)]]:
		draw_string(FONT, item[1], item[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD)

	# 回転して見えるように、鶏と矢印を横方向につぶす
	var sx := cos(_spin)
	if absf(sx) < 0.08:
		sx = 0.08 * signf(sx if sx != 0.0 else 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(sx, 1.0))

	var body := IRON.lerp(Color(0.62, 0.40, 0.36), _feed_flash * 3.0)
	# 矢印
	draw_line(Vector2(-90.0, 44.0), Vector2(84.0, 44.0), IRON, 6.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(80.0, 30.0), Vector2(108.0, 44.0), Vector2(80.0, 58.0)]), IRON)
	draw_colored_polygon(PackedVector2Array([Vector2(-90.0, 44.0), Vector2(-112.0, 26.0), Vector2(-100.0, 44.0), Vector2(-112.0, 62.0)]), IRON)
	# しっぽの羽
	draw_colored_polygon(PackedVector2Array([Vector2(-30.0, 0.0), Vector2(-86.0, -58.0), Vector2(-70.0, -10.0)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(-30.0, 10.0), Vector2(-92.0, -20.0), Vector2(-64.0, 20.0)]), body)
	# 胴・首・頭
	draw_circle(Vector2(0.0, 6.0), 40.0, body)
	draw_colored_polygon(PackedVector2Array([Vector2(14.0, -20.0), Vector2(30.0, -54.0), Vector2(44.0, -40.0), Vector2(36.0, -6.0)]), body)
	draw_circle(Vector2(38.0, -54.0), 18.0, body)
	# とさか・くちばし・肉垂れ
	draw_circle(Vector2(30.0, -74.0), 7.0, COMB)
	draw_circle(Vector2(40.0, -76.0), 8.0, COMB)
	draw_circle(Vector2(50.0, -71.0), 6.0, COMB)
	draw_colored_polygon(PackedVector2Array([Vector2(54.0, -58.0), Vector2(72.0, -52.0), Vector2(54.0, -48.0)]), GOLD)
	draw_circle(Vector2(52.0, -42.0), 5.0, COMB)
	# 足
	draw_line(Vector2(-8.0, 42.0), Vector2(-8.0, 44.0), IRON, 5.0)
	draw_line(Vector2(10.0, 42.0), Vector2(10.0, 44.0), IRON, 5.0)
	# ふち取りと目
	draw_arc(Vector2(0.0, 6.0), 40.0, PI * 1.05, PI * 1.9, 16, GOLD, 2.0, true)
	draw_circle(Vector2(44.0, -58.0), 3.5, Color(1.0, 0.95, 0.8))
	draw_circle(Vector2(45.0, -58.0), 1.8, LINE)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_state_symbols()

	if has_cat:
		_draw_hanging_cat(Vector2(18.0, -60.0))
	if _feed_flash > 0.0:
		for i in 3:
			var hp := Vector2(-30.0 + i * 30.0, -100.0 - (0.18 - _feed_flash) * 120.0)
			_draw_heart(hp, 7.0, Color(1.0, 0.5, 0.65, _feed_flash * 5.0))


## 表情は小さくて読みづらいので、状態は記号で示す。
## 満足=ハート / 怒り=湯気 / 目が回る=渦巻き
func _draw_state_symbols() -> void:
	var head := Vector2(38.0, -58.0)
	var want_happy := satisfaction >= 0.8 and mode != Mode.LEAVE
	var want_angry := mode == Mode.FIGHT and (_attack == Attack.GUST or _attack == Attack.STORM)
	var want_dizzy := mode == Mode.LEAVE
	if _debug_symbol == "happy":
		want_happy = true
	elif _debug_symbol == "angry":
		want_angry = true
	elif _debug_symbol == "dizzy":
		want_dizzy = true

	if want_happy:
		for i in 3:
			var t := fmod(_t * 0.55 + float(i) / 3.0, 1.0)
			var p := head + Vector2(sin(t * TAU + float(i)) * 15.0, -32.0 - t * 62.0)
			_draw_heart(p, 7.5 * (1.0 - t * 0.45), Color(1.0, 0.55, 0.70, 1.0 - t))

	if want_angry:
		for i in 3:
			var t := fmod(_t * 1.7 + float(i) / 3.0, 1.0)
			var p := head + Vector2(-28.0 + float(i) * 10.0 + t * 7.0, -26.0 - t * 46.0)
			draw_circle(p, 5.5 + t * 5.0, Color(1.0, 1.0, 1.0, 0.55 * (1.0 - t)))

	if want_dizzy:
		var c := head + Vector2(0.0, -32.0)
		var pts := PackedVector2Array()
		for i in 44:
			var a := float(i) / 43.0 * TAU * 2.1
			var r := 1.5 + a * 2.3
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, Color(0.34, 0.18, 0.44, 0.9), 2.5, true)


## 動作確認用: 記号の描画だけを強制する（--symbol から呼ぶ）。
func debug_symbol(m: String) -> void:
	_debug_symbol = m


func _draw_hanging_cat(p: Vector2) -> void:
	# とさかにしがみつく猫。回転に振り回されて左右に揺れる
	var swing := sin(_spin) * 14.0
	var o := p + Vector2(swing, 26.0)
	draw_line(p + Vector2(-4.0, -4.0), o + Vector2(-6.0, -14.0), TABBY, 5.0, true)
	draw_line(p + Vector2(4.0, -4.0), o + Vector2(6.0, -14.0), TABBY, 5.0, true)
	draw_circle(o, 12.0, TABBY)
	draw_circle(o + Vector2(0.0, -12.0), 10.0, TABBY)
	draw_line(o + Vector2(-6.0, 10.0), o + Vector2(-8.0 - swing * 0.3, 22.0), TABBY, 4.0, true)
	draw_line(o + Vector2(6.0, 10.0), o + Vector2(8.0 - swing * 0.3, 22.0), TABBY, 4.0, true)
	draw_arc(o, 12.0, 0.0, TAU, 16, LINE, 1.2, true)
	draw_circle(o + Vector2(-3.5, -13.0), 2.0, LINE)
	draw_circle(o + Vector2(3.5, -13.0), 2.0, LINE)


func _draw_heart(p: Vector2, r: float, c: Color) -> void:
	draw_circle(p + Vector2(-r * 0.5, 0.0), r * 0.6, c)
	draw_circle(p + Vector2(r * 0.5, 0.0), r * 0.6, c)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.05, r * 0.2), p + Vector2(r * 1.05, r * 0.2), p + Vector2(0.0, r * 1.3)]), c)


## 突風の筋。画面全体に描くので、グローバル座標に戻して描く。
func _draw_wind() -> void:
	var strength := 0.0
	if mode == Mode.FIGHT and _attack == Attack.GUST:
		strength = 0.35 if _attack_t < 1.0 else 1.0
	elif mode == Mode.FIGHT and _attack == Attack.STORM:
		strength = 0.5
	if strength <= 0.0:
		return
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	for i in 14:
		var y := fmod(float(i) * 71.0 + 37.0, 900.0) + 40.0
		var x := fmod(_t * 900.0 * _gust_dir + float(i) * 173.0, 700.0)
		if x < 0.0:
			x += 700.0
		x -= 80.0
		var streak := 60.0 + float(i % 3) * 30.0
		var a := 0.25 * strength
		draw_line(Vector2(x, y), Vector2(x - streak * _gust_dir, y), Color(1.0, 1.0, 1.0, a), 3.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)
