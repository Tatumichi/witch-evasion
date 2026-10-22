extends Node2D
## 全ステージ共通の進行。仕様は docs/stage_design.md の「全ステージ共通仕様」。
## 各ステージ（stage1.gd …）はこれを継承し、下の「ステージごとに上書きする」関数だけを書く。
##
## 状態: TITLE → INTRO（ステージ名）→ ROAD（道中）→ BOSS_INTRO → BOSS → CLEAR
##       帽子が 0 になると FAINT。道中なら最初から、ボス戦ならボス戦の頭からやり直す。
##
## ワールドはスクロールしない。障害物などがスクロール速度で下へ流れることで上昇を表す。
##
## 起動オプション（撮影・確認用。`godot --path godot -- --start` のように渡す）:
##   --start : タイトルを飛ばして開始     --boss : ボス戦から開始     --god : 被弾しない
##   --symbol=happy|angry|dizzy : ボスの状態記号を強制（ボスが debug_symbol を持つとき）
##   --stage=N : STAGE N から始める（--boss / --god と組み合わせ可）
##
## ステージの解放・ベストスコア・ステージ間の移動は autoload の GameState（scripts/game_state.gd）。
##
## 効果音は Sfx.fire で鳴らす（一覧は docs/sound_effects.md）。BGM は BGM ノード（bgm.gd）が state を見て切り替える。

const CourageScript := preload("res://scripts/stage/courage.gd")
const CatScript := preload("res://scripts/stage/falling_cat.gd")
const CandyScript := preload("res://scripts/stage/candy.gd")
const FxScript := preload("res://scripts/stage/fx.gd")
const RingScript := preload("res://scripts/ring.gd")
const Sfx := preload("res://scripts/stage/sfx.gd")

const GAME_W := 540.0
const GAME_H := 960.0
const START_POS := Vector2(270.0, 710.0)

const MAX_HATS := 3
const INVINCIBLE_TIME := 1.5
const COURAGE_PER_HAT := 50
const CAT_EFFECT_TIME := 15.0
const CANDY_INTERVAL := 0.2

enum State { TITLE, INTRO, ROAD, BOSS_INTRO, BOSS, CLEAR, FAINT }
enum Fur { TABBY, WHITE }

@onready var background = $Background
@onready var world: Node2D = $World
@onready var player = $World/Player
@onready var hud = $HUD
## autoload の GameState。--script のテストでもコンパイルできるよう、グローバル名ではなくノードで引く。
@onready var _gs: Node = _find_game_state()

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

## スクロール速度（px/秒）。scroll_speed() の値が入る。
var scroll := 230.0

var _rng := RandomNumberGenerator.new()
var _score_f := 0.0
var _state_t := 0.0
var _events: Array = []
var _event_i := 0
var _filler_cd := 0.0
var _courage_cd := 0.0
var _hold_until := 0.0
var _candy_cd := 0.0
var _candy_n := 0
var _shake := 0.0
var _boss: Node2D
## メルルを押し流す力。ボスの突風（_boss_force）とステージの環境（横風など。_env_force）の合計を毎フレーム渡す。
var _boss_force := Vector2.ZERO
var _env_force := Vector2.ZERO
var _faint_in_boss := false
var _faint_god_said := false
var _road_cats_saved := 0
var _road_cats_missed := 0
var _said := {}
var _cooldowns := {}
var _clear_step := 0
var _clear_lines: Array = []
var _courage_chain := 0
var _courage_last_ms := -10000


# ================================================================ ステージごとに上書きする

func stage_number() -> int:
	return 1

func stage_name() -> String:
	return ""

## 道中の長さ（秒）
func road_time() -> float:
	return 120.0

## STAGE 1 の 230 px/秒を 1.0 倍とする（設定書の難易度曲線）。
func scroll_speed() -> float:
	return 230.0

## このステージで落ちてくる猫の数（道中＋ボス戦）
func cats_total() -> int:
	return 4

## 決まった時刻の出来事。[[秒, Callable], …]（順不同。基底が時刻順に並べる）
func build_timeline() -> Array:
	return []

## 区間ごとのランダム出現。[{from, to, gap: [最短, 最長], w: {種類: 重み}}]
func sections() -> Array:
	return []

## sections() の「種類」を 1 つ出す。
func spawn_filler(_kind: String) -> void:
	pass

## ボスを作って返す（world への追加とシグナルの接続は基底がやる）。
## ボスは Node2D で、setup(world, rng, scroll) / begin_fight() / is_ready() / satisfaction /
## debug_fill(amount) と、シグナル satisfied / drop_cat(pos) / gust_changed(force) / left_screen を持つ。
func make_boss() -> Node2D:
	return null

## ボスのとさかなどから落ちてくる猫: [毛色, 吹き出しの出どころ]
func boss_cat() -> Array:
	return [Fur.TABBY, ""]

## ボスの満足ゲージの見出し
func boss_gauge_label() -> String:
	return "満足ゲージ"

## ボス登場時の効果音
func se_boss_appear() -> String:
	return "boss_appear"

## セリフ: [話者, 本文]
func line_start() -> Array:
	return ["メルル", ""]

func line_boss_intro() -> Array:
	return ["メルル", ""]

func line_boss_satisfied() -> Array:
	return ["", ""]

## クリア後の神々の実況（2.6 秒ごとに順に出し、最後の 1 つのあとで結果画面）
func lines_clear_gods() -> Array:
	return []

## ボスが満足した瞬間（基底が boss_satisfied を鳴らしたあと）に呼ばれる。セリフに合わせた効果音など。
func stage_on_satisfied() -> void:
	pass

## 道中・ボス戦のあいだ毎フレーム呼ばれる（横風など）。
func stage_process(_delta: float) -> void:
	pass

## start_stage() とボス戦のやり直しで呼ばれる。ステージ固有の状態を戻す。
func stage_reset() -> void:
	pass

## _ready() の途中（タイトル表示の前）に呼ばれる。背景のシグナルをつなぐなど。
func stage_ready() -> void:
	pass


# ================================================================ 起動

func _find_game_state() -> Node:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		# autoload が無い起動のされ方（単体のシーン実行など）でも動くようにする
		gs = load("res://scripts/game_state.gd").new()
		gs.name = "GameState"
		get_tree().root.add_child.call_deferred(gs)
	return gs


func _ready() -> void:
	_rng.randomize()
	scroll = scroll_speed()
	best = _gs.best(stage_number())
	player.damaged.connect(_on_damaged)
	player.cat_caught.connect(_on_cat_caught)
	player.courage_got.connect(_on_courage)
	player.smoke_changed.connect(_on_smoke)
	player.bumped.connect(_on_bumped)
	stage_ready()
	_enter_title()

	var args := OS.get_cmdline_user_args()
	god_mode = "--god" in args
	var want := 0
	for a in args:
		if a.begins_with("--stage="):
			want = int(a.substr(8))
	if want > 0 and want != stage_number() and _gs.has_stage(want):
		_gs.goto_stage(want, "--boss" not in args)
		return
	if "--boss" in args:
		await get_tree().process_frame
		start_stage()
		_enter_boss_intro()
		for a in args:
			if a.begins_with("--symbol="):
				await get_tree().create_timer(0.3).timeout
				if _boss and _boss.has_method("debug_symbol"):
					_boss.debug_symbol(a.split("=")[1])
	elif "--start" in args or want == stage_number() or _gs.autostart:
		_gs.autostart = false
		await get_tree().process_frame
		start_stage()


# ================================================================ 状態遷移

func _enter_title() -> void:
	state = State.TITLE
	_clear_world()
	player.spawn_at(START_POS)
	background.reset()
	if not _gs.is_unlocked(_gs.selected):
		_gs.selected = 1
	hud.show_title(best)
	_refresh_title()


func _refresh_title() -> void:
	var n: int = _gs.selected
	hud.set_title_stage(n, _gs.stage_name(n), _gs.is_unlocked(n), _gs.best(n), _gs.has_stage(n - 1), _gs.has_stage(n + 1))


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
	_boss_force = Vector2.ZERO
	_env_force = Vector2.ZERO
	spawn_counts.clear()
	_said.clear()
	_cooldowns.clear()
	_events = build_timeline()
	_events.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	_event_i = 0
	_filler_cd = 2.0
	_courage_cd = 2.5
	_hold_until = 0.0
	_boss = null
	stage_reset()

	hud.show_play()
	hud.clear_talk()
	hud.show_boss_gauge(false)
	_refresh_hud()
	hud.show_stage_card("STAGE %d" % stage_number(), stage_name())
	_set_state(State.INTRO)


func _set_state(s: int) -> void:
	state = s
	_state_t = 0.0


func _enter_road() -> void:
	_set_state(State.ROAD)
	var l := line_start()
	_say_once("start", l[0], l[1], 3.0)


func _enter_boss_intro() -> void:
	_set_state(State.BOSS_INTRO)
	road_t = road_time()
	background.progress = 1.0
	_boss = make_boss()
	_boss.setup(world, _rng, scroll)
	world.add_child(_boss)
	_boss.drop_cat.connect(_on_boss_drop_cat)
	_boss.gust_changed.connect(func(f: Vector2): _boss_force = f)
	_boss.satisfied.connect(_on_boss_satisfied)
	_boss.left_screen.connect(func(): _boss = null)
	Sfx.fire(self, se_boss_appear())
	_road_cats_saved = cats_saved
	_road_cats_missed = cats_missed
	var l := line_boss_intro()
	hud.say(l[0], l[1], 3.4)


func _begin_boss() -> void:
	_set_state(State.BOSS)
	_boss.begin_fight()
	hud.show_boss_gauge(true, boss_gauge_label())
	Sfx.fire(self, "gauge_show", {"delay": 0.15})
	hud.set_boss_gauge(0.0)


func _on_boss_satisfied() -> void:
	if state != State.BOSS:
		return
	_set_state(State.CLEAR)
	_clear_step = 0
	_clear_lines = lines_clear_gods()
	_boss_force = Vector2.ZERO
	_env_force = Vector2.ZERO
	hud.show_boss_gauge(false)
	var l := line_boss_satisfied()
	if l[1] != "":
		hud.say(l[0], l[1], 2.0)
	Sfx.fire(self, "boss_satisfied")
	stage_on_satisfied()
	# 残っている障害物はそっと消す
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
	Sfx.fire(self, "faint")
	hud.say("メルル", "ふにゃ〜……め、目がまわる〜……", 2.6)
	hud.show_faint(true)


func _restart_after_faint() -> void:
	hud.show_faint(false)
	Sfx.fire(self, "restart")
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
	_boss_force = Vector2.ZERO
	_env_force = Vector2.ZERO
	stage_reset()
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
	_gs.record_clear(stage_number(), score)
	hud.set_score(score)
	for i in 5:
		Sfx.fire(self, "result_line", {"delay": 0.12 * i, "pitch": pow(2.0, [0, 2, 4, 5, 7][i] / 12.0)})
	if is_best:
		Sfx.fire(self, "new_best", {"delay": 0.75})
	var next := stage_number() + 1
	var hint := "SPACE で STAGE %d へ" % next if _gs.has_stage(next) else "SPACE でタイトルへ"
	hud.show_result([
		"スコア　%d%s" % [score, "　NEW BEST!" if is_best else ""],
		"救った猫　%d / %d" % [cats_saved, cats_total()],
		"勇気のかけら　%d" % courage,
		"被弾　%d" % hits_taken,
		"クリアボーナス　+%d" % bonus,
	], "STAGE %d CLEAR!" % stage_number(), hint)


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
			if _state_t >= 3.0 and _boss and _boss.is_ready():
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

	if state in [State.ROAD, State.BOSS_INTRO, State.BOSS]:
		stage_process(delta)
	# 押し流す力は毎フレーム合計して渡す（ステージ → プレイヤーの順に処理されるので、同じフレームで効く）
	player.push = (_boss_force + _env_force) if player.alive else Vector2.ZERO

	if state in [State.INTRO, State.ROAD, State.BOSS_INTRO, State.BOSS, State.CLEAR]:
		_update_cat_effect(delta)
		if state != State.CLEAR:
			_score_f += scroll * delta * 0.1
		score = int(_score_f)
		hud.set_score(score)

	var boss_phase := state in [State.BOSS_INTRO, State.BOSS, State.CLEAR]
	hud.set_progress(1.0 if boss_phase else road_t / road_time(), boss_phase)


func _update_road(delta: float) -> void:
	road_t += delta
	background.progress = clampf(road_t / road_time(), 0.0, 1.0)

	while _event_i < _events.size() and float(_events[_event_i][0]) <= road_t:
		var cb: Callable = _events[_event_i][1]
		cb.call()
		_event_i += 1

	_update_fillers(delta)

	_courage_cd -= delta
	if _courage_cd <= 0.0 and road_t < road_time() - 4.0:
		_spawn_courage_pattern()
		_courage_cd = _rng.randf_range(2.6, 3.8)

	if road_t >= road_time():
		_enter_boss_intro()


func _update_boss(delta: float) -> void:
	if _boss == null:
		return
	hud.set_boss_gauge(_boss.satisfaction)
	_courage_cd -= delta
	if _courage_cd <= 0.0:
		_courage_cd = _rng.randf_range(4.0, 5.5)
		_spawn_courage_line(Vector2(_rng.randf_range(80.0, 460.0), -20.0), Vector2(0.0, -40.0), 4)


## 神々の実況を 2.6 秒ごとに出して、最後の 1 つの 2.6 秒後に結果画面。
func _update_clear() -> void:
	var n := _clear_lines.size()
	if _clear_step < n and _state_t >= 2.6 * float(_clear_step + 1):
		hud.god_say(String(_clear_lines[_clear_step]), 3.0)
		Sfx.fire(self, "god_voice")
		_clear_step += 1
	elif _clear_step == n and _state_t >= 2.6 * float(n + 1):
		_clear_step = n + 1
		player.active = false
		_show_result()


## 道中のランダム出現。_hold_until まではお休み（大きな出現の直後に間を空ける）。
func _update_fillers(delta: float) -> void:
	if road_t < _hold_until:
		return
	var sec: Dictionary = {}
	for s in sections():
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
	spawn_filler(_weighted(sec["w"]))


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


# ================================================================ 共通の生成

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
	c.setup(pos, scroll)
	world.add_child(c)


## from_top=true なら画面上端で予告してから上から落ちる。false なら pos（ボスのとさかなど）から落ちる。
func _spawn_cat(fur: int, pos: Vector2, source: String, from_top: bool) -> Node:
	var c = CatScript.new()
	c.setup(fur, pos, source, from_top)
	c.missed.connect(_on_cat_missed)
	world.add_child(c)
	_count("cat")
	Sfx.fire(self, "cat_fall", {"x": pos.x, "pitch_jitter": 0.04})
	return c


func _spawn_ring(pos: Vector2, c: Color, to_radius: float, dur: float) -> void:
	var r = RingScript.new()
	r.setup(pos, c, to_radius, dur)
	world.add_child(r)


func _pop_text(pos: Vector2, text: String, c: Color) -> void:
	var f = FxScript.new()
	f.setup_pop(pos, text, c)
	world.add_child(f)
	if text.begins_with("+"):
		Sfx.fire(self, "pop_score", {"x": pos.x})


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
	Sfx.fire(self, "hit", {"x": player.global_position.x})
	if hats == 1:
		Sfx.fire(self, "hat_warning", {"delay": 0.18})
	player.start_invincible(INVINCIBLE_TIME)
	hud.say("メルル", "ひゃっ！" if _rng.randf() < 0.5 else "ご、ごめんなさい〜！", 1.4)


## 当たっても帽子は落ちないが、はじかれるもの（風船など。group "bumpers"）に触れた。
## 相手の bump() を呼び（風船なら割れて音が鳴る）、メルルを相手と反対へはじく。
func _on_bumped(area: Area2D) -> void:
	if not state in [State.ROAD, State.BOSS, State.BOSS_INTRO]:
		return
	var away: Vector2 = player.global_position - area.global_position
	if away.length() < 1.0:
		away = Vector2.DOWN
	player.knock(away.normalized() * 420.0)
	if area.has_method("bump"):
		area.call("bump")
	stage_on_bumped(area)


## はじかれたときのセリフなど（ステージごと）。
func stage_on_bumped(_area: Area2D) -> void:
	pass


func _on_courage(shard: Area2D) -> void:
	shard.queue_free()
	courage += 1
	_score_f += 10
	var now := Time.get_ticks_msec()
	_courage_chain = mini(_courage_chain + 1, 7) if now - _courage_last_ms < 600 else 0
	_courage_last_ms = now
	Sfx.fire(self, "courage", {"pitch": pow(2.0, _courage_chain / 12.0), "x": player.global_position.x})
	if courage % COURAGE_PER_HAT == 0:
		if hats < MAX_HATS:
			Sfx.fire(self, "hat_restore")
			hats += 1
			_pop_text(player.global_position + Vector2(0.0, -80.0), "帽子がもどった！", Color(0.70, 1.0, 0.86))
		else:
			Sfx.fire(self, "bonus")
			_score_f += 500
			_pop_text(player.global_position + Vector2(0.0, -80.0), "+500", Color(1.0, 0.92, 0.6))
	elif courage % 10 == 0 and _cooldown_ok("courage_line", 12.0):
		hud.say("メルル", "……がんばれ、わたし。", 1.6)
	_refresh_hud()


func _on_smoke(inside: bool) -> void:
	player.speed_mul = 0.55 if inside else 1.0
	Sfx.fire(self, "smoke_in" if inside else "smoke_out", {"x": player.global_position.x})
	if inside and _cooldown_ok("cough", 6.0):
		hud.say("メルル", "けほっ、けほっ……前が見えない〜", 1.6)


func _on_cat_caught(cat: Area2D) -> void:
	if not cat.is_in_group("cats"):
		return
	cat.remove_from_group("cats")
	var fur: int = cat.fur
	cat.queue_free()
	cats_saved += 1
	_score_f += 100
	Sfx.fire(self, "cat_catch", {"x": player.global_position.x})
	_spawn_ring(player.global_position, Color(1.0, 0.85, 0.55), 70.0, 0.4)
	_pop_text(player.global_position + Vector2(0.0, -86.0), "+100", Color(1.0, 0.92, 0.6))
	_start_cat_effect(fur)
	# 「猫ちゃん！？」は最初に猫と出会う STAGE 1 だけ
	if not _said.has("first_cat") and stage_number() == 1:
		_say_once("first_cat", "メルル", "ね、猫ちゃん！？　だ、だいじょうぶ……つかまって！", 2.6)
	else:
		hud.say("メルル", "よかった……もうだいじょうぶだよ。", 1.8)
	_refresh_hud()


func _on_cat_missed(_cat: Area2D) -> void:
	if not state in [State.ROAD, State.BOSS, State.BOSS_INTRO, State.CLEAR]:
		return
	cats_missed += 1
	Sfx.fire(self, "cat_miss")
	hud.say("メルル", "あっ……ああっ！", 1.6)
	_refresh_hud()


func _on_boss_drop_cat(pos: Vector2) -> void:
	var bc := boss_cat()
	_spawn_cat(bc[0], pos, bc[1], false)


func _start_cat_effect(fur: int) -> void:
	cat_effect = fur
	cat_effect_t = CAT_EFFECT_TIME
	_candy_cd = 0.6
	player.add_rider(fur)
	player.barrier = fur == Fur.WHITE
	if fur == Fur.WHITE:
		Sfx.fire(self, "barrier_on", {"delay": 0.25})


func _end_cat_effect() -> void:
	cat_effect = -1
	player.rider_active = false
	player.barrier = false
	hud.set_cat_effect(-1, 0.0)


func _update_cat_effect(delta: float) -> void:
	if cat_effect < 0:
		return
	var before := cat_effect_t
	cat_effect_t -= delta
	hud.set_cat_effect(cat_effect, cat_effect_t / CAT_EFFECT_TIME)
	if cat_effect_t <= 0.0:
		_end_cat_effect()
		Sfx.fire(self, "cat_effect_end")
		return
	# 残り 2 秒から 0.5 秒ごとに「かちっ」
	if cat_effect_t < 2.0 and floori(before / 0.5) != floori(cat_effect_t / 0.5):
		Sfx.fire(self, "cat_effect_warn")
	if cat_effect == Fur.TABBY and player.alive:
		_candy_cd -= delta
		if _candy_cd <= 0.0:
			_candy_cd = CANDY_INTERVAL
			_fire_candy()
			# 「グランマのおやつ」は最初にキャンディが出る STAGE 1 だけ
			if not _said.has("first_candy") and stage_number() == 1:
				_say_once("first_candy", "メルル", "えっ、それグランマのおやつ……どこから出したの！？", 2.8)


func _fire_candy() -> void:
	var c = CandyScript.new()
	var origin: Vector2 = player.global_position + Vector2(-34.0, -64.0)
	# まっすぐ → 少し右 → まっすぐ → 少し左。正面の小物に確実に当たるようにする
	var spread: float = [0.0, 0.04, 0.0, -0.04][_candy_n % 4]
	c.setup(origin, Vector2(0.0, -720.0).rotated(spread), _candy_n)
	c.broke.connect(_on_candy_broke)
	c.fed.connect(func(_b):
		_score_f += 5
		Sfx.fire(self, "candy_eat", {"pitch_jitter": 0.04}))
	world.add_child(c)
	Sfx.fire(self, "candy_fire", {"pitch_jitter": 0.05, "x": origin.x})
	_candy_n += 1
	_count("candy")


func _on_candy_broke(target: Area2D) -> void:
	_score_f += 20
	Sfx.fire(self, "candy_hit", {"x": target.global_position.x, "pitch_jitter": 0.05})
	if _cooldown_ok("sorry", 3.0):
		_pop_text(target.global_position + Vector2(0.0, -30.0), "ごめんね", Color(1.0, 0.86, 0.94))


func _refresh_hud() -> void:
	hud.set_hats(hats, MAX_HATS)
	hud.set_courage(courage, COURAGE_PER_HAT)
	hud.set_cats(cats_saved, cats_total())
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
	# タイトルでは ←→ でステージを選ぶ（まだ遊べないステージも見えるが、始められない）
	if state == State.TITLE and (event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
		var n: int = _gs.selected + (-1 if event.is_action_pressed("move_left") else 1)
		if _gs.has_stage(n):
			_gs.selected = n
			_refresh_title()
			Sfx.fire(self, "ui_select")
		return

	var advance := false
	if event is InputEventKey and event.pressed and not event.echo:
		advance = event.keycode == KEY_SPACE or event.keycode == KEY_ENTER
	elif event is InputEventMouseButton and event.pressed:
		advance = event.button_index == MOUSE_BUTTON_LEFT
	if not advance:
		return
	match state:
		State.TITLE:
			var n: int = _gs.selected
			if not _gs.is_unlocked(n):
				Sfx.fire(self, "ui_locked")
				return
			Sfx.fire(self, "ui_start")
			if n == stage_number():
				start_stage()
			else:
				_gs.goto_stage(n, true)
		State.FAINT:
			if _state_t >= 0.8:
				_restart_after_faint()
		State.CLEAR:
			if hud.is_result_visible():
				var next := stage_number() + 1
				if _gs.has_stage(next):
					_gs.goto_stage(next, true)
				else:
					_enter_title()
