extends Node2D
## STAGE 2 ボス「はぐれ大風車」。
## 丘の上の大風車が、強い上昇気流で小屋ごと浮かび上がってしまったもの。回るたびに羽根で風を起こす。
## 倒す相手ではない。満足ゲージが満タンになれば、風がやんで帆をたたみ、丘へ帰っていく。
##
## 攻撃サイクル（設定書 STAGE 2 の 1〜3 をくり返す）:
##   TURN  : 4 枚の羽根がゆっくり回り、上下しながら羽根を下へ張り出す。弱い風で羽根のほうへ吸い寄せられる
##   GUST  : 回転が速まり、風車の向きに合わせて強い横風が吹く（最初の 1 秒は予告）
##   FLOUR : 粉ひき小屋から小麦粉の袋が放り出され、破れて白い粉が視界をふさぐ
##
## 当たり判定は 2 つ: 小屋（House）と、別に回る羽根（Blades）。どちらもキャンディを受けると満足する。
## 状態は STAGE 1 のボスと同じく記号で見せる: 満足=ハート / 怒り（突風）=湯気 / 退場=渦巻き。
##
## 画像（無ければコード描画。docs/stage2-assets.md）:
##   assets/characters/boss/windmill_house.png  … 小屋。幅 HOUSE_W px。HOUSE_HUB の位置が羽根の軸
##   assets/characters/boss/windmill_blades.png … 4 枚羽根。正方形・ハブが中心。一辺 = BLADE_LEN × 2 で回す
##   軸の上の猫は assets/props/cat_tabby.png を流用
## 音: 登場 boss_appear（ステージ側）/ 戦闘開始 boss2_start / 戦闘中は羽根の軋み boss2_blades_loop /
##     突風 gust_warning → gust / 袋を投げる flour_throw / 袋が破れる smoke_in（flour_bag.gd）/ 帆をたたむ boss_leave
##     boss2_* と flour_throw は専用音が無いあいだ sfx.gd の FALLBACK で既存音に振り替わる（boss2_start は無音）

signal satisfied
signal drop_cat(pos: Vector2)
signal gust_changed(force: Vector2)
signal left_screen

const WindmillScript := preload("res://scripts/stage/windmill.gd")
const FlourBagScript := preload("res://scripts/stage/flour_bag.gd")
const Sfx := preload("res://scripts/stage/sfx.gd")

const HOUSE_TEX := "res://assets/characters/boss/windmill_house.png"
const BLADES_TEX := "res://assets/characters/boss/windmill_blades.png"
const CAT_TEX := "res://assets/props/cat_tabby.png"
const HOUSE_W := 150.0
## 小屋の画像の中で羽根の軸が来る位置（割合）
const HOUSE_HUB := Vector2(0.5, 0.16)

## 何もしなくても 60 秒で満タン（設定書: 30〜60 秒）。キャンディ 1 発で 0.012。
const NATURAL_RATE := 1.0 / 60.0
const FEED_AMOUNT := 0.012
const HOME := Vector2(270.0, 200.0)
const BLADE_LEN := 215.0
const CAT_DROP_AT := 9.0
const GUST_FORCE := 260.0
const PULL_FORCE := 70.0

enum Mode { ENTER, WAIT, FIGHT, LEAVE, GONE }
enum Attack { TURN, GUST, FLOUR }

const WALL := Color(0.94, 0.88, 0.78)
const WALL_DARK := Color(0.78, 0.70, 0.60)
const ROOF := Color(0.55, 0.34, 0.30)
const FRAME := Color(0.48, 0.34, 0.26)
const TABBY := Color(1.0, 0.66, 0.32)
const LINE := Color(0.25, 0.16, 0.22, 0.95)

var mode: int = Mode.ENTER
var satisfaction := 0.0
var has_cat := true

var _world: Node2D
var _rng: RandomNumberGenerator
var _scroll := 253.0
var _t := 0.0
var _fight_t := 0.0
var _attack: int = Attack.TURN
var _attack_t := 0.0
var _bag_cd := 0.0
var _gust_dir := 1.0
var _spin_speed := 0.6
var _fold := 1.0
var _feed_flash := 0.0
var _leave_t := 0.0
var _force := Vector2.ZERO
var _player: Node2D
var _creaking := false
var _debug_symbol := ""

var _house: Area2D
var _blades: Area2D
var _house_tex: Texture2D
var _blades_tex: Texture2D
var _cat_tex: Texture2D


func setup(world: Node2D, rng: RandomNumberGenerator, scroll: float) -> void:
	_world = world
	_rng = rng
	_scroll = scroll
	_player = world.get_node_or_null("Player")
	position = Vector2(HOME.x, -260.0)
	z_index = 2

	_house = _Part.new()
	_house.owner_boss = self
	_house.name = "House"
	var hs := RectangleShape2D.new()
	hs.size = Vector2(96.0, 150.0)
	var hc := CollisionShape2D.new()
	hc.shape = hs
	hc.position = Vector2(0.0, 92.0)
	_house.add_child(hc)
	add_child(_house)

	_blades = _Part.new()
	_blades.owner_boss = self
	_blades.name = "Blades"
	for i in 4:
		var a := TAU * float(i) / 4.0
		var cs := CollisionShape2D.new()
		var s := CapsuleShape2D.new()
		s.radius = 15.0
		s.height = BLADE_LEN - 30.0
		cs.shape = s
		cs.position = Vector2(cos(a), sin(a)) * (BLADE_LEN * 0.5 + 15.0)
		cs.rotation = a + PI * 0.5
		_blades.add_child(cs)
	add_child(_blades)


func _ready() -> void:
	if ResourceLoader.exists(HOUSE_TEX):
		_house_tex = load(HOUSE_TEX) as Texture2D
	if ResourceLoader.exists(BLADES_TEX):
		_blades_tex = load(BLADES_TEX) as Texture2D
	if ResourceLoader.exists(CAT_TEX):
		_cat_tex = load(CAT_TEX) as Texture2D


func _exit_tree() -> void:
	_set_creak(false)


## 登場して所定の位置に着いたら true（ステージ側はこれを見てボス戦を始める）。
func is_ready() -> bool:
	return mode == Mode.WAIT


## 登場演出が終わったらステージ側が呼ぶ。
func begin_fight() -> void:
	mode = Mode.FIGHT
	_fight_t = 0.0
	_start_attack(Attack.TURN)
	_set_creak(true)
	Sfx.fire(self, "boss2_start")


func feed() -> void:
	if mode != Mode.FIGHT:
		return
	satisfaction = minf(satisfaction + FEED_AMOUNT, 1.0)
	_feed_flash = 0.18


func debug_fill(amount: float) -> void:
	satisfaction = minf(satisfaction + amount, 1.0)


## 動作確認用: 記号の描画だけを強制する（--symbol から呼ぶ）。
func debug_symbol(m: String) -> void:
	_debug_symbol = m


func _set_creak(on: bool) -> void:
	if on == _creaking:
		return
	_creaking = on
	if on:
		Sfx.loop_on(self, "boss2_blades_loop")
	else:
		Sfx.loop_off(self, "boss2_blades_loop")


func _set_force(f: Vector2) -> void:
	if not f.is_equal_approx(_force):
		# 突風が吹き始めた瞬間。風上（押される向きの反対側）から聞こえるようにする
		if _attack == Attack.GUST and absf(f.x) > PULL_FORCE and absf(_force.x) <= PULL_FORCE:
			Sfx.fire(self, "gust", {"x": 270.0 - signf(f.x) * 230.0})
		_force = f
		gust_changed.emit(f)


func _start_attack(a: int) -> void:
	_attack = a
	_attack_t = 0.0
	match a:
		Attack.GUST:
			_gust_dir = 1.0 if _rng.randf() < 0.5 else -1.0
			Sfx.fire(self, "gust_warning", {"x": 270.0 - _gust_dir * 230.0})
		Attack.FLOUR:
			_bag_cd = 0.3


func _physics_process(delta: float) -> void:
	_t += delta
	_blades.rotation += _spin_speed * delta
	_feed_flash = maxf(_feed_flash - delta, 0.0)

	match mode:
		Mode.ENTER:
			position.y = move_toward(position.y, HOME.y, 180.0 * delta)
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
	var heat := satisfaction
	position.x = HOME.x + sin(_fight_t * 0.45) * 110.0

	if has_cat and _fight_t >= CAT_DROP_AT:
		has_cat = false
		drop_cat.emit(global_position + Vector2(0.0, -46.0))

	match _attack:
		Attack.TURN:
			# 上下しながら羽根を下へ張り出す。弱い風で羽根のほうへ吸い寄せられる
			_spin_speed = lerpf(_spin_speed, lerpf(0.8, 1.2, heat), 1.0 - exp(-2.0 * delta))
			position.y = HOME.y + (1.0 - cos(_attack_t * TAU / 6.0)) * 0.5 * lerpf(170.0, 220.0, heat)
			var pull := 0.0
			if _player:
				pull = signf(global_position.x - _player.global_position.x) * PULL_FORCE
			_set_force(Vector2(pull, 0.0))
			if _attack_t >= 6.0:
				position.y = HOME.y
				_start_attack(Attack.GUST)
		Attack.GUST:
			# 最初の 1 秒は予告（回転が速くなる）、その後 3.5 秒強い横風
			_spin_speed = lerpf(_spin_speed, 5.5, 1.0 - exp(-3.0 * delta))
			_set_force(Vector2(_gust_dir * GUST_FORCE, 0.0) if _attack_t >= 1.0 else Vector2.ZERO)
			if _attack_t >= 4.5:
				_start_attack(Attack.FLOUR)
		Attack.FLOUR:
			_spin_speed = lerpf(_spin_speed, 1.5, 1.0 - exp(-2.0 * delta))
			_set_force(Vector2.ZERO)
			_bag_cd -= delta
			if _bag_cd <= 0.0:
				_bag_cd = lerpf(0.9, 0.6, heat)
				_throw_bag()
			if _attack_t >= 5.0:
				_start_attack(Attack.TURN)

	if satisfaction >= 1.0:
		if has_cat:
			has_cat = false
			drop_cat.emit(global_position + Vector2(0.0, -46.0))
		mode = Mode.LEAVE
		_leave_t = 0.0
		_set_force(Vector2.ZERO)
		_set_creak(false)
		Sfx.fire(self, "boss_leave", {"delay": 0.5})
		for part in [_house, _blades]:
			part.remove_from_group("obstacles")
			part.set_deferred("monitorable", false)
		satisfied.emit()


func _leave(delta: float) -> void:
	_leave_t += delta
	_spin_speed = move_toward(_spin_speed, 0.0, 2.0 * delta)
	_fold = move_toward(_fold, 0.0, 0.8 * delta)     # 帆をたたむ
	if _leave_t > 1.8:
		# ふんわりと丘（下）へ帰っていく
		position.y += 220.0 * delta
		position.x += sin(_leave_t * 2.0) * 30.0 * delta
		if position.y > 1250.0:
			mode = Mode.GONE
			left_screen.emit()
			queue_free()


func _throw_bag() -> void:
	var door := global_position + Vector2(0.0, 150.0)
	var b = FlourBagScript.new()
	var target_x := _rng.randf_range(60.0, 480.0)
	if _player and _rng.randf() < 0.7:
		target_x = clampf(_player.global_position.x + _rng.randf_range(-60.0, 60.0), 60.0, 480.0)
	var t := _rng.randf_range(1.2, 1.6)
	var vx := (target_x - door.x) / t
	b.setup(door, Vector2(vx, _rng.randf_range(-260.0, -160.0)), t)
	_world.add_child(b)
	Sfx.fire(self, "flour_throw", {"x": door.x, "pitch_jitter": 0.05})


func _process(_delta: float) -> void:
	queue_redraw()


# ---------------------------------------------------------------- 描画

func _draw() -> void:
	_draw_wind()
	var flash := Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.80, 0.80), _feed_flash * 3.0)

	# 小屋（羽根の奥）
	if _house_tex:
		WindmillScript.draw_house_tex(self, _house_tex, HOUSE_W, HOUSE_HUB, flash)
	else:
		var wall := WALL.lerp(Color(1.0, 0.80, 0.80), _feed_flash * 3.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-44.0, 14.0), Vector2(44.0, 14.0), Vector2(56.0, 170.0), Vector2(-56.0, 170.0),
		]), wall)
		draw_colored_polygon(PackedVector2Array([Vector2(30.0, 14.0), Vector2(44.0, 14.0), Vector2(56.0, 170.0), Vector2(40.0, 170.0)]), WALL_DARK)
		draw_colored_polygon(PackedVector2Array([Vector2(-56.0, 18.0), Vector2(56.0, 18.0), Vector2(0.0, -46.0)]), ROOF)
		draw_rect(Rect2(-12.0, 60.0, 24.0, 28.0), Color(0.42, 0.62, 0.86))
		draw_rect(Rect2(-16.0, 122.0, 32.0, 48.0), FRAME)
		# 小麦粉の袋が積んである入口
		draw_rect(Rect2(-36.0, 150.0, 16.0, 18.0), Color(0.90, 0.84, 0.70))
		draw_rect(Rect2(22.0, 152.0, 16.0, 16.0), Color(0.90, 0.84, 0.70))

	# 羽根（回転）
	draw_set_transform(Vector2.ZERO, _blades.rotation, Vector2.ONE)
	if _blades_tex:
		WindmillScript.draw_blades_tex(self, _blades_tex, BLADE_LEN, _fold)
	else:
		WindmillScript.draw_blades(self, BLADE_LEN, _fold)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not _blades_tex:
		draw_circle(Vector2.ZERO, 16.0, FRAME)
		draw_circle(Vector2.ZERO, 6.0, LINE)

	_draw_state_symbols()
	if has_cat:
		_draw_axle_cat(Vector2(0.0, -30.0))
	if _feed_flash > 0.0:
		for i in 3:
			var hp := Vector2(-30.0 + i * 30.0, -70.0 - (0.18 - _feed_flash) * 120.0)
			_draw_heart(hp, 7.0, Color(1.0, 0.5, 0.65, _feed_flash * 5.0))


## 状態は記号で示す（STAGE 1 の大風見鶏と同じ決まり）。満足=ハート / 怒り=湯気 / 目が回る=渦巻き
func _draw_state_symbols() -> void:
	var head := Vector2(0.0, -40.0)
	var want_happy := satisfaction >= 0.8 and mode != Mode.LEAVE
	var want_angry := mode == Mode.FIGHT and _attack == Attack.GUST
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
			var p := head + Vector2(sin(t * TAU + float(i)) * 18.0, -40.0 - t * 62.0)
			_draw_heart(p, 8.0 * (1.0 - t * 0.45), Color(1.0, 0.55, 0.70, 1.0 - t))
	if want_angry:
		for i in 3:
			var t := fmod(_t * 1.7 + float(i) / 3.0, 1.0)
			var p := head + Vector2(-34.0 + float(i) * 14.0 + t * 7.0, -36.0 - t * 46.0)
			draw_circle(p, 6.5 + t * 6.0, Color(1.0, 1.0, 1.0, 0.6 * (1.0 - t)))
	if want_dizzy:
		var c := head + Vector2(0.0, -46.0)
		var pts := PackedVector2Array()
		for i in 44:
			var a := float(i) / 43.0 * TAU * 2.1
			var r := 1.5 + a * 2.6
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_polyline(pts, Color(0.34, 0.18, 0.44, 0.9), 2.5, true)


func _draw_axle_cat(p: Vector2) -> void:
	# 軸の上で丸くなってしがみつく茶トラ。回転にあわせてぷるぷる震える
	var shiver := sin(_t * 30.0) * 1.2
	var o := p + Vector2(shiver, 0.0)
	if _cat_tex:
		var w := 44.0
		var h := w * float(_cat_tex.get_height()) / float(_cat_tex.get_width())
		draw_texture_rect(_cat_tex, Rect2(o - Vector2(w, h) * 0.5, Vector2(w, h)), false)
		return
	draw_circle(o, 13.0, TABBY)
	draw_circle(o + Vector2(8.0, -10.0), 10.0, TABBY)
	draw_colored_polygon(PackedVector2Array([o + Vector2(1.0, -15.0), o + Vector2(3.0, -25.0), o + Vector2(8.0, -18.0)]), TABBY)
	draw_colored_polygon(PackedVector2Array([o + Vector2(10.0, -19.0), o + Vector2(15.0, -26.0), o + Vector2(17.0, -14.0)]), TABBY)
	draw_arc(o, 13.0, 0.0, TAU, 16, LINE, 1.2, true)
	draw_circle(o + Vector2(5.0, -11.0), 1.8, LINE)
	draw_circle(o + Vector2(12.0, -11.0), 1.8, LINE)


func _draw_heart(p: Vector2, r: float, c: Color) -> void:
	draw_circle(p + Vector2(-r * 0.5, 0.0), r * 0.6, c)
	draw_circle(p + Vector2(r * 0.5, 0.0), r * 0.6, c)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.05, r * 0.2), p + Vector2(r * 1.05, r * 0.2), p + Vector2(0.0, r * 1.3)]), c)


## 強い横風の筋。画面全体に描くので、グローバル座標に戻して描く。
func _draw_wind() -> void:
	var strength := 0.0
	if mode == Mode.FIGHT and _attack == Attack.GUST:
		strength = 0.35 if _attack_t < 1.0 else 1.0
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
		draw_line(Vector2(x, y), Vector2(x - streak * _gust_dir, y), Color(1.0, 1.0, 1.0, 0.25 * strength), 3.0, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## 小屋と羽根の当たり判定。キャンディ（feed）は本体へ回す。
class _Part extends Area2D:
	var owner_boss: Node

	func _ready() -> void:
		collision_layer = 2
		collision_mask = 0
		add_to_group("obstacles")
		add_to_group("boss")

	func feed() -> void:
		owner_boss.call("feed")
