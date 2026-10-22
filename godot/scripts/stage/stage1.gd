extends Node2D
## STAGE 1「村の空」の進行。仕様は docs/stage_design.md の「全ステージ共通仕様」「STAGE 1」。
##
## 状態: TITLE → INTRO（ステージ名）→ ROAD（道中 120 秒）→ BOSS_INTRO → BOSS → CLEAR
##       帽子が 0 になると FAINT。道中なら最初から、ボス戦ならボス戦の頭からやり直す。
##
## ワールドはスクロールしない。障害物などがスクロール速度で下へ流れることで上昇を表す。
##
## 起動オプション（撮影・確認用。`godot --path godot -- --start` のように渡す）:
##   --start : タイトルを飛ばして開始     --boss : ボス戦から開始     --god : 被弾しない

const LaundryScript := preload("res://scripts/stage/laundry.gd")
const PigeonScript := preload("res://scripts/stage/pigeon.gd")
const VaneScript := preload("res://scripts/stage/weathervane.gd")
const SmokeScript := preload("res://scripts/stage/smoke.gd")
const CourageScript := preload("res://scripts/stage/courage.gd")
const CatScript := preload("res://scripts/stage/falling_cat.gd")
const CandyScript := preload("res://scripts/stage/candy.gd")
const BossScript := preload("res://scripts/stage/boss_weathervane.gd")
const FxScript := preload("res://scripts/stage/fx.gd")
const RingScript := preload("res://scripts/ring.gd")

const GAME_W := 540.0
const GAME_H := 960.0
const START_POS := Vector2(270.0, 710.0)

## 道中の長さ（秒）とスクロール速度（STAGE 1 = 1.0 倍）
const ROAD_TIME := 120.0
const SCROLL := 230.0

const MAX_HATS := 3
const INVINCIBLE_TIME := 1.5
const COURAGE_PER_HAT := 50
const CAT_EFFECT_TIME := 15.0
const CANDY_INTERVAL := 0.2
const CATS_TOTAL := 4

const SAVE_PATH := "user://witch_stage.cfg"

enum State { TITLE, INTRO, ROAD, BOSS_INTRO, BOSS, CLEAR, FAINT }

## 道中の「埋め草」の出現設定。区間ごとに間隔と種類の重みを変える。
## 鳩の列はほかの障害物とまとめて降らせると避けられないので、出たあとは少し間を空ける。
const SECTIONS := [
	{"from": 2.0, "to": 18.0, "gap": [1.7, 2.5], "w": {"sheet": 0.5, "sock": 0.5}},
	{"from": 18.0, "to": 48.0, "gap": [1.3, 2.0], "w": {"sheet": 0.38, "sock": 0.42, "pigeons": 0.20}},
	{"from": 48.0, "to": 85.0, "gap": [1.1, 1.7], "w": {"sheet": 0.25, "sock": 0.25, "pigeons": 0.15, "vane": 0.35}},
	{"from": 85.0, "to": 116.0, "gap": [1.0, 1.5], "w": {"sheet": 0.25, "sock": 0.22, "pigeons": 0.18, "vane": 0.35}},
]

@onready var background = $Background
@onready var world: Node2D = $World
@onready var player = $World/Player
@onready var hud = $HUD

var state: int = State.TITLE
var road_t := 0.0
var hats := MAX_HATS
var courage := 0
var cats_saved := 0
var cats_missed := 0
var hits_taken := 0
var score := 0
var best := 0
var god_mode := false

## 猫の効果。-1 = なし、0 = 茶トラ（キャンディ）、1 = 白猫（バリア）
var cat_effect := -1
var cat_effect_t := 0.0

## 何が何回出たか（テスト用の記録）
var spawn_counts := {}

var _rng := RandomNumberGenerator.new()
var _score_f := 0.0
var _state_t := 0.0
var _events: Array = []
var _event_i := 0
var _filler_cd := 0.0
var _courage_cd := 0.0
var _last_row_t := -99.0
var _hold_until := 0.0
var _candy_cd := 0.0
var _candy_n := 0
var _shake := 0.0
var _boss: Area2D
var _faint_in_boss := false
var _faint_god_said := false
var _road_cats_saved := 0
var _road_cats_missed := 0
var _said := {}
var _cooldowns := {}
var _clear_step := 0


func _ready() -> void:
	_rng.randomize()
	best = _load_best()
	player.damaged.connect(_on_damaged)
	player.cat_caught.connect(_on_cat_caught)
	player.courage_got.connect(_on_courage)
	player.smoke_changed.connect(_on_smoke)
	background.tower_passed.connect(_on_tower_passed)
	_enter_title()

	var args := OS.get_cmdline_user_args()
	god_mode = "--god" in args
	if "--boss" in args:
		await get_tree().process_frame
		start_stage()
		_enter_boss_intro()
	elif "--start" in args:
		await get_tree().process_frame
		start_stage()


# ================================================================ 状態遷移

func _enter_title() -> void:
	state = State.TITLE
	_clear_world()
	player.spawn_at(START_POS)
	background.reset()
	hud.show_title(best)


## タイトルから、または最初からやり直すときに呼ぶ。
func start_stage() -> void:
	_clear_world()
	background.reset()
	player.spawn_at(START_POS)
	player.active = true
	player.god_mode = god_mode

	road_t = 0.0
	hats = MAX_HATS
	courage = 0
	cats_saved = 0
	cats_missed = 0
	hits_taken = 0
	_score_f = 0.0
	score = 0
	cat_effect = -1
	spawn_counts.clear()
	_said.clear()
	_cooldowns.clear()
	_events = _build_timeline()
	_event_i = 0
	_filler_cd = 2.0
	_courage_cd = 2.5
	_last_row_t = -99.0
	_hold_until = 0.0
	_boss = null

	hud.show_play()
	hud.clear_talk()
	hud.show_boss_gauge(false)
	_refresh_hud()
	hud.show_stage_card("STAGE 1", "村の空")
	_set_state(State.INTRO)


func _set_state(s: int) -> void:
	state = s
	_state_t = 0.0


func _enter_road() -> void:
	_set_state(State.ROAD)
	_say_once("start", "メルル", "ひゃっ……洗濯物が、飛んでくる〜！！", 3.0)


func _enter_boss_intro() -> void:
	_set_state(State.BOSS_INTRO)
	road_t = ROAD_TIME
	background.progress = 1.0
	_boss = BossScript.new()
	_boss.setup(world, _rng, SCROLL)
	world.add_child(_boss)
	_boss.drop_cat.connect(_on_boss_drop_cat)
	_boss.gust_changed.connect(func(f: Vector2): player.push = f)
	_boss.satisfied.connect(_on_boss_satisfied)
	_boss.left_screen.connect(func(): _boss = null)
	_road_cats_saved = cats_saved
	_road_cats_missed = cats_missed
	hud.say("メルル", "風見鶏さん、うしろに猫ちゃんが！　ちょっとだけじっとしてて〜！", 3.4)


func _begin_boss() -> void:
	_set_state(State.BOSS)
	_boss.begin_fight()
	hud.show_boss_gauge(true)
	hud.set_boss_gauge(0.0)


func _on_boss_satisfied() -> void:
	if state != State.BOSS:
		return
	_set_state(State.CLEAR)
	_clear_step = 0
	player.push = Vector2.ZERO
	hud.show_boss_gauge(false)
	hud.say("大風見鶏", "……コケッ。", 2.0)
	# 残っている矢印や洗濯物はそっと消す
	for c in world.get_children():
		if c != player and c != _boss and c.has_method("break_apart"):
			c.call("break_apart")


func _faint() -> void:
	_faint_in_boss = state == State.BOSS or state == State.BOSS_INTRO
	_set_state(State.FAINT)
	_faint_god_said = false
	player.faint()
	_end_cat_effect()
	_shake = 18.0
	hud.say("メルル", "ふにゃ〜……め、目がまわる〜……", 2.6)
	hud.show_faint(true)


func _restart_after_faint() -> void:
	hud.show_faint(false)
	if not _faint_in_boss:
		start_stage()
		return
	# ボス戦の頭から。道中で救った猫の数は残す
	_clear_world()
	player.spawn_at(START_POS)
	player.active = true
	player.god_mode = god_mode
	hats = MAX_HATS
	cats_saved = _road_cats_saved
	cats_missed = _road_cats_missed
	cat_effect = -1
	hud.show_play()
	hud.clear_talk()
	_refresh_hud()
	_enter_boss_intro()


func _show_result() -> void:
	var bonus := 1000 + hats * 200
	_score_f += bonus
	score = int(_score_f)
	var is_best := score > best
	if is_best:
		best = score
		_save_best()
	hud.set_score(score)
	hud.show_result([
		"スコア　%d%s" % [score, "　NEW BEST!" if is_best else ""],
		"救った猫　%d / %d" % [cats_saved, CATS_TOTAL],
		"勇気のかけら　%d" % courage,
		"被弾　%d" % hits_taken,
		"クリアボーナス　+%d" % bonus,
	])


func _clear_world() -> void:
	for c in world.get_children():
		if c != player:
			c.queue_free()


# ================================================================ 毎フレーム

func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 60.0, 0.0)
		world.position = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * _shake
	else:
		world.position = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_state_t += delta
	for k in _cooldowns.keys():
		_cooldowns[k] = float(_cooldowns[k]) - delta

	match state:
		State.INTRO:
			if _state_t >= 2.0:
				_enter_road()
		State.ROAD:
			_update_road(delta)
		State.BOSS_INTRO:
			if _state_t >= 3.0 and _boss and _boss.mode == BossScript.Mode.WAIT:
				_begin_boss()
		State.BOSS:
			_update_boss(delta)
		State.CLEAR:
			_update_clear()
		State.FAINT:
			if _state_t >= 3.2:
				_restart_after_faint()
			elif _state_t >= 1.0 and not _faint_god_said:
				_faint_god_said = true
				hud.god_say("……もう一度、見せよ。", 2.0)

	if state in [State.INTRO, State.ROAD, State.BOSS_INTRO, State.BOSS, State.CLEAR]:
		_update_cat_effect(delta)
		if state != State.CLEAR:
			_score_f += SCROLL * delta * 0.1
		score = int(_score_f)
		hud.set_score(score)

	var boss_phase := state in [State.BOSS_INTRO, State.BOSS, State.CLEAR]
	hud.set_progress(1.0 if boss_phase else road_t / ROAD_TIME, boss_phase)


func _update_road(delta: float) -> void:
	road_t += delta
	background.progress = clampf(road_t / ROAD_TIME, 0.0, 1.0)

	while _event_i < _events.size() and float(_events[_event_i][0]) <= road_t:
		var cb: Callable = _events[_event_i][1]
		cb.call()
		_event_i += 1

	_update_fillers(delta)

	_courage_cd -= delta
	if _courage_cd <= 0.0 and road_t < ROAD_TIME - 4.0:
		_spawn_courage_pattern()
		_courage_cd = _rng.randf_range(2.6, 3.8)

	if road_t >= ROAD_TIME:
		_enter_boss_intro()


func _update_boss(delta: float) -> void:
	if _boss == null:
		return
	hud.set_boss_gauge(_boss.satisfaction)
	_courage_cd -= delta
	if _courage_cd <= 0.0:
		_courage_cd = _rng.randf_range(4.0, 5.5)
		_spawn_courage_line(Vector2(_rng.randf_range(80.0, 460.0), -20.0), Vector2(0.0, -40.0), 4)


func _update_clear() -> void:
	if _clear_step == 0 and _state_t >= 2.6:
		_clear_step = 1
		hud.god_say("……ん？　今、下で何か光らなかったか？", 3.0)
	elif _clear_step == 1 and _state_t >= 5.2:
		_clear_step = 2
		player.active = false
		_show_result()


# ================================================================ 道中の出現表

func _build_timeline() -> Array:
	var t: Array = []
	# 最初は洗濯物だけ。ゆっくりで「動けばよけられる」を覚える
	t.append([1.0, func(): _spawn_sheet(-1.0, 160.0)])
	t.append([3.2, func(): _spawn_sock(1.0, 240.0)])
	# 1 匹目の猫は必ず真上に落とす（動かなくても受け止められる）
	t.append([6.0, func(): _spawn_cat(0, Vector2(player.global_position.x, 0.0), "パン屋の煙突から", true)])
	# 煙突の煙（屋根が見えているあいだだけ）
	for e in [[9.0, 130.0], [15.0, 410.0], [24.0, 250.0], [33.0, 90.0], [42.0, 440.0]]:
		var x: float = e[1]
		t.append([e[0], func(): _spawn_smoke(x)])
	# 鳩の列を初めて見せる
	t.append([18.0, func(): _spawn_pigeon_row()])
	t.append([34.0, func(): _spawn_pigeon_row()])
	# 2 匹目：物干し竿から、洗濯物と一緒に
	t.append([40.0, _event_clothesline_cat])
	# 風見鶏が落ちてくるようになる
	t.append([50.0, func(): _spawn_vane(270.0)])
	t.append([62.0, func(): _spawn_pigeon_row()])
	# 3 匹目：教会の塔の鐘から（塔を越えるころ）
	t.append([79.0, func(): _spawn_cat(0, Vector2(392.0, 0.0), "教会の鐘から", true)])
	t.append([96.0, func(): _spawn_pigeon_row()])
	t.append([108.0, func(): _spawn_pigeon_row()])
	t.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	return t


func _event_clothesline_cat() -> void:
	var x := _rng.randf_range(120.0, 420.0)
	_spawn_cat(0, Vector2(x, 0.0), "物干し竿から", true)
	_spawn_sock(-1.0, 120.0)
	_spawn_sock(1.0, 200.0)


func _update_fillers(delta: float) -> void:
	if road_t < _hold_until:
		return
	var sec: Dictionary = {}
	for s in SECTIONS:
		if road_t >= float(s["from"]) and road_t < float(s["to"]):
			sec = s
			break
	if sec.is_empty():
		return
	_filler_cd -= delta
	if _filler_cd > 0.0:
		return
	var gap: Array = sec["gap"]
	_filler_cd = _rng.randf_range(float(gap[0]), float(gap[1]))

	var kind := _weighted(sec["w"])
	if kind == "pigeons" and road_t - _last_row_t < 6.0:
		kind = "sock"
	match kind:
		"sheet":
			_spawn_sheet(-1.0 if _rng.randf() < 0.5 else 1.0, _rng.randf_range(60.0, 420.0))
		"sock":
			_spawn_sock(-1.0 if _rng.randf() < 0.5 else 1.0, _rng.randf_range(60.0, 480.0))
		"pigeons":
			_spawn_pigeon_row()
		"vane":
			_spawn_vane(_rng.randf_range(60.0, 480.0))


func _weighted(weights: Dictionary) -> String:
	var total := 0.0
	for v in weights.values():
		total += float(v)
	var r := _rng.randf() * total
	for k in weights.keys():
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys()[0]


func _count(kind: String) -> void:
	spawn_counts[kind] = int(spawn_counts.get(kind, 0)) + 1


# ================================================================ 生成

## side = -1 なら左から右へ、1 なら右から左へ流れる。
func _spawn_sheet(side: float, y: float) -> void:
	var l = LaundryScript.new()
	var x := -70.0 if side < 0.0 else GAME_W + 70.0
	var vx := -side * _rng.randf_range(80.0, 130.0)
	l.setup(LaundryScript.Kind.SHEET, Vector2(x, y), Vector2(vx, SCROLL * 0.45), _rng)
	world.add_child(l)
	_count("sheet")


func _spawn_sock(side: float, y: float) -> void:
	var l = LaundryScript.new()
	var x := -40.0 if side < 0.0 else GAME_W + 40.0
	var vx := -side * _rng.randf_range(120.0, 180.0)
	l.setup(LaundryScript.Kind.SOCK, Vector2(x, y), Vector2(vx, SCROLL * 0.6), _rng)
	world.add_child(l)
	_count("sock")


## 8 マスに 7 羽。1 マス分のすき間に勇気のかけらを置く。
func _spawn_pigeon_row() -> void:
	var slots := 8
	var step := GAME_W / float(slots)
	var gap := _rng.randi_range(1, slots - 2)
	for i in slots:
		var x := step * (float(i) + 0.5)
		if i == gap:
			_spawn_courage_line(Vector2(x, -40.0), Vector2(0.0, -46.0), 3)
			continue
		var p = PigeonScript.new()
		p.setup(Vector2(x, -40.0), SCROLL, _rng)
		world.add_child(p)
	_last_row_t = road_t
	_hold_until = road_t + 1.4
	_count("pigeons")


func _spawn_vane(x: float) -> void:
	var v = VaneScript.new()
	v.setup(Vector2(x, -70.0), Vector2(_rng.randf_range(-40.0, 40.0), SCROLL + 150.0), _rng)
	world.add_child(v)
	_count("vane")


func _spawn_smoke(x: float) -> void:
	var s = SmokeScript.new()
	s.setup(x, SCROLL, _rng)
	world.add_child(s)
	_count("smoke")


func _spawn_courage_pattern() -> void:
	var x := _rng.randf_range(70.0, GAME_W - 70.0)
	match _rng.randi() % 3:
		0:
			_spawn_courage_line(Vector2(x, -20.0), Vector2(0.0, -42.0), 5)
		1:
			var dir := 1.0 if x < GAME_W * 0.5 else -1.0
			_spawn_courage_line(Vector2(x, -20.0), Vector2(dir * 34.0, -34.0), 5)
		_:
			for i in 5:
				var a := PI * float(i) / 4.0
				_spawn_courage(Vector2(x + cos(a) * 60.0, -20.0 - sin(a) * 50.0))


func _spawn_courage_line(start: Vector2, step: Vector2, n: int) -> void:
	for i in n:
		_spawn_courage(start + step * float(i))


func _spawn_courage(pos: Vector2) -> void:
	var c = CourageScript.new()
	c.setup(pos, SCROLL)
	world.add_child(c)


func _spawn_cat(fur: int, pos: Vector2, source: String, from_top: bool) -> void:
	var c = CatScript.new()
	c.setup(fur, pos, source, from_top)
	c.missed.connect(_on_cat_missed)
	world.add_child(c)
	_count("cat")


func _spawn_ring(pos: Vector2, c: Color, to_radius: float, dur: float) -> void:
	var r = RingScript.new()
	r.setup(pos, c, to_radius, dur)
	world.add_child(r)


func _pop_text(pos: Vector2, text: String, c: Color) -> void:
	var f = FxScript.new()
	f.setup_pop(pos, text, c)
	world.add_child(f)


# ================================================================ メルルまわり

func _on_damaged() -> void:
	if not state in [State.ROAD, State.BOSS, State.BOSS_INTRO, State.INTRO]:
		return
	if god_mode or player.invincible > 0.0 or player.barrier:
		return
	hats -= 1
	hits_taken += 1
	_shake = 10.0
	var hat = FxScript.new()
	hat.setup_hat(player.global_position + Vector2(0.0, -50.0))
	world.add_child(hat)
	_spawn_ring(player.global_position, Color(1.0, 0.45, 0.6), 60.0, 0.4)
	_refresh_hud()
	if hats <= 0:
		_faint()
		return
	player.start_invincible(INVINCIBLE_TIME)
	hud.say("メルル", "ひゃっ！" if _rng.randf() < 0.5 else "ご、ごめんなさい〜！", 1.4)


func _on_courage(shard: Area2D) -> void:
	shard.queue_free()
	courage += 1
	_score_f += 10
	if courage % COURAGE_PER_HAT == 0:
		if hats < MAX_HATS:
			hats += 1
			_pop_text(player.global_position + Vector2(0.0, -80.0), "帽子がもどった！", Color(0.70, 1.0, 0.86))
		else:
			_score_f += 500
			_pop_text(player.global_position + Vector2(0.0, -80.0), "+500", Color(1.0, 0.92, 0.6))
	elif courage % 10 == 0 and _cooldown_ok("courage_line", 12.0):
		hud.say("メルル", "……がんばれ、わたし。", 1.6)
	_refresh_hud()


func _on_smoke(inside: bool) -> void:
	player.speed_mul = 0.55 if inside else 1.0
	if inside and _cooldown_ok("cough", 6.0):
		hud.say("メルル", "けほっ、けほっ……前が見えない〜", 1.6)


func _on_tower_passed() -> void:
	if state == State.ROAD:
		_say_once("tower", "メルル", "塔より、高い……いやいやいや、下見ない。下見ない。", 3.2)


func _on_cat_caught(cat: Area2D) -> void:
	if not cat.is_in_group("cats"):
		return
	cat.remove_from_group("cats")
	var fur: int = cat.fur
	cat.queue_free()
	cats_saved += 1
	_score_f += 100
	_spawn_ring(player.global_position, Color(1.0, 0.85, 0.55), 70.0, 0.4)
	_pop_text(player.global_position + Vector2(0.0, -86.0), "+100", Color(1.0, 0.92, 0.6))
	_start_cat_effect(fur)
	if not _said.has("first_cat"):
		_say_once("first_cat", "メルル", "ね、猫ちゃん！？　だ、だいじょうぶ……つかまって！", 2.6)
	else:
		hud.say("メルル", "よかった……もうだいじょうぶだよ。", 1.8)
	_refresh_hud()


func _on_cat_missed(_cat: Area2D) -> void:
	if not state in [State.ROAD, State.BOSS, State.BOSS_INTRO, State.CLEAR]:
		return
	cats_missed += 1
	hud.say("メルル", "あっ……ああっ！", 1.6)
	_refresh_hud()


func _on_boss_drop_cat(pos: Vector2) -> void:
	_spawn_cat(0, pos, "大風見鶏のとさかから", false)


func _start_cat_effect(fur: int) -> void:
	cat_effect = fur
	cat_effect_t = CAT_EFFECT_TIME
	_candy_cd = 0.6
	player.add_rider(fur)
	player.barrier = fur == 1


func _end_cat_effect() -> void:
	cat_effect = -1
	player.rider_active = false
	player.barrier = false
	hud.set_cat_effect(-1, 0.0)


func _update_cat_effect(delta: float) -> void:
	if cat_effect < 0:
		return
	cat_effect_t -= delta
	hud.set_cat_effect(cat_effect, cat_effect_t / CAT_EFFECT_TIME)
	if cat_effect_t <= 0.0:
		_end_cat_effect()
		return
	if cat_effect == 0 and player.alive:
		_candy_cd -= delta
		if _candy_cd <= 0.0:
			_candy_cd = CANDY_INTERVAL
			_fire_candy()
			if not _said.has("first_candy"):
				_say_once("first_candy", "メルル", "えっ、それグランマのおやつ……どこから出したの！？", 2.8)


func _fire_candy() -> void:
	var c = CandyScript.new()
	var origin: Vector2 = player.global_position + Vector2(-34.0, -64.0)
	# まっすぐ → 少し右 → まっすぐ → 少し左。正面の小物に確実に当たるようにする
	var spread: float = [0.0, 0.04, 0.0, -0.04][_candy_n % 4]
	c.setup(origin, Vector2(0.0, -720.0).rotated(spread), _candy_n)
	c.broke.connect(_on_candy_broke)
	c.fed.connect(func(_b): _score_f += 5)
	world.add_child(c)
	_candy_n += 1
	_count("candy")


func _on_candy_broke(target: Area2D) -> void:
	_score_f += 20
	if _cooldown_ok("sorry", 3.0):
		_pop_text(target.global_position + Vector2(0.0, -30.0), "ごめんね", Color(1.0, 0.86, 0.94))


func _refresh_hud() -> void:
	hud.set_hats(hats, MAX_HATS)
	hud.set_courage(courage, COURAGE_PER_HAT)
	hud.set_cats(cats_saved, CATS_TOTAL)
	hud.set_score(int(_score_f))


func _say_once(key: String, speaker: String, text: String, seconds: float) -> void:
	if _said.has(key):
		return
	_said[key] = true
	hud.say(speaker, text, seconds)


func _cooldown_ok(key: String, seconds: float) -> bool:
	if float(_cooldowns.get(key, 0.0)) > 0.0:
		return false
	_cooldowns[key] = seconds
	return true


# ================================================================ 入力・保存

func _unhandled_input(event: InputEvent) -> void:
	var advance := false
	if event is InputEventKey and event.pressed and not event.echo:
		advance = event.keycode == KEY_SPACE or event.keycode == KEY_ENTER
	elif event is InputEventMouseButton and event.pressed:
		advance = event.button_index == MOUSE_BUTTON_LEFT
	if not advance:
		return
	match state:
		State.TITLE:
			start_stage()
		State.FAINT:
			if _state_t >= 0.8:
				_restart_after_faint()
		State.CLEAR:
			if hud.is_result_visible():
				_enter_title()


func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return int(cfg.get_value("stage1", "best", 0))
	return 0


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("stage1", "best", best)
	cfg.save(SAVE_PATH)
