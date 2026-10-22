extends "res://scripts/stage/stage_base.gd"
## STAGE 2「丘と森の上空」。仕様は docs/stage_design.md の「STAGE 2」。素材は docs/stage2-assets.md。
## 「横風」を学ぶステージ。風が吹くと障害物（group "windable"）もメルルも同じ方向へ流される。
## 綿毛の嵐・風船・渡り鳥の V 字・画面端の風車。ボスは「はぐれ大風車」。スクロールは 1.1 倍。
## 共通の進行（帽子・猫・キャンディ・やり直し・ボス戦の流れ・結果）は stage_base.gd。
##
## 効果音は STAGE 1 の 42 音を流用している。専用にしたい音は専用の名前で鳴らし、ファイルが無いあいだは
## sfx.gd の FALLBACK が既存音に振り替える（割り当ては docs/sound_effects.md の「STAGE 2」）。
## BGM は専用曲ができるまで STAGE 1 の曲を流す（bgm_track）。

const FluffScript := preload("res://scripts/stage/fluff.gd")
const BalloonScript := preload("res://scripts/stage/balloon.gd")
const GooseScript := preload("res://scripts/stage/goose.gd")
const WindmillScript := preload("res://scripts/stage/windmill.gd")
const BgmScript := preload("res://scripts/stage/bgm.gd")
const BossScript := preload("res://scripts/stage/boss_windmill.gd")

## 専用 BGM（docs/stage2-assets.md）。ファイルが置かれたら自動でこちらに切り替わる
const BGM_ROAD := "stage2_road"
const BGM_BOSS := "stage2_boss"

## 横風：予告の長さ、吹く長さ、メルルを押す力、障害物を流す速さ
const WIND_WARN := 1.2
const WIND_BLOW := 3.0
const WIND_PUSH := 210.0
const WIND_DRIFT := 170.0

const SECTIONS := [
	{"from": 2.0, "to": 20.0, "gap": [1.8, 2.6], "w": {"balloon": 0.45, "puff": 0.55}},
	{"from": 20.0, "to": 50.0, "gap": [1.2, 1.8], "w": {"balloon": 0.26, "puff": 0.36, "geese": 0.20, "windmill": 0.18}},
	{"from": 50.0, "to": 85.0, "gap": [1.0, 1.55], "w": {"balloon": 0.22, "puff": 0.34, "geese": 0.22, "windmill": 0.22}},
	{"from": 85.0, "to": 116.0, "gap": [0.95, 1.45], "w": {"balloon": 0.22, "puff": 0.32, "geese": 0.24, "windmill": 0.22}},
]

@onready var wind_fx = $WindFx

## 0 = なし、1 = 予告中、2 = 吹いている
var wind_phase := 0
var wind_dir := 1.0
var _wind_t := 0.0
var _wind_x := 0.0
var _last_v_t := -99.0
var _last_mill_t := -99.0


func stage_number() -> int:
	return 2

func stage_name() -> String:
	return "丘と森の上空"

## STAGE 1 の 1.1 倍
func scroll_speed() -> float:
	return 253.0

func sections() -> Array:
	return SECTIONS

func make_boss() -> Node2D:
	return BossScript.new()

func boss_gauge_label() -> String:
	return "はぐれ大風車の満足ゲージ"

func boss_cat() -> Array:
	return [Fur.TABBY, "はぐれ大風車の軸の上から"]

func line_start() -> Array:
	return ["メルル", "村が、もうあんなに小さい……グランマ、ぜったい怒ってるよね……"]

func line_boss_intro() -> Array:
	return ["メルル", "風車さんが……飛んでる！？　どういうこと〜！？"]

func line_boss_satisfied() -> Array:
	return ["はぐれ大風車", "（ギィ……ゴトン。）"]

func lines_clear_gods() -> Array:
	return ["風車をよけきったぞ。", "……もう少し、派手にしてみるか。"]

func stage_reset() -> void:
	wind_phase = 0
	_wind_t = 0.0
	_wind_x = 0.0
	_last_v_t = -99.0
	_last_mill_t = -99.0
	_env_force = Vector2.ZERO
	if wind_fx:
		wind_fx.warn = 0.0
		wind_fx.blow = 0.0

func stage_ready() -> void:
	background.landmark_passed.connect(_on_tree_passed)

## BGM ノード（bgm.gd）が聞きに来る。専用曲のファイルがあればそれ、無ければ STAGE 1 の曲
func bgm_track(role: String) -> String:
	var want := BGM_ROAD if role == "road" else BGM_BOSS
	return want if BgmScript.has_file(want) else ("stage1_road" if role == "road" else "stage1_boss")

func stage_on_bumped(_area: Area2D) -> void:
	if _cooldown_ok("balloon_line", 8.0):
		hud.say("メルル", "ひゃっ！　ご、ごめんなさい……誰かの風船だったのに……", 2.2)


# ================================================================ 横風

func start_wind(dir: float) -> void:
	if wind_phase != 0:
		return
	wind_dir = dir
	wind_phase = 1
	_wind_t = 0.0
	_count("wind")
	# 予告。風上（風が吹いてくる側）から聞こえるようにする
	Sfx.fire(self, "gust_warning", {"x": 270.0 - dir * 230.0})
	if not _said.has("wind"):
		_say_once("wind", "メルル", "か、風さん、押さないで〜！", 2.4)


func stage_process(delta: float) -> void:
	var push_k := 0.0
	match wind_phase:
		1:
			_wind_t += delta
			wind_fx.warn = minf(_wind_t / 0.3, 1.0)
			wind_fx.blow = 0.0
			if _wind_t >= WIND_WARN:
				wind_phase = 2
				_wind_t = 0.0
				Sfx.fire(self, "gust", {"x": 270.0 - wind_dir * 230.0, "volume_db": -2.0})
		2:
			_wind_t += delta
			# 立ち上がりと終わりをなめらかに
			push_k = minf(_wind_t / 0.35, 1.0) * clampf((WIND_BLOW - _wind_t) / 0.35, 0.0, 1.0)
			wind_fx.warn = 0.0
			wind_fx.blow = push_k
			if _wind_t >= WIND_BLOW:
				wind_phase = 0
				wind_fx.blow = 0.0
	wind_fx.dir = wind_dir
	_env_force = Vector2(wind_dir * WIND_PUSH * push_k, 0.0)
	_wind_x = wind_dir * WIND_DRIFT * push_k
	for n in get_tree().get_nodes_in_group("windable"):
		n.set("wind", _wind_x)


func _on_boss_satisfied() -> void:
	super()
	wind_phase = 0
	wind_fx.warn = 0.0
	wind_fx.blow = 0.0


# ================================================================ 出現表

func build_timeline() -> Array:
	var t: Array = []
	t.append([1.0, func(): _spawn_balloon(380.0)])
	t.append([3.0, func(): _spawn_puff(Vector2(150.0, -30.0))])
	t.append([5.0, func(): _spawn_windmill(-1.0)])
	# 1 匹目：白猫。綿毛の嵐の直前に置き、「バリアがあれば突っ切れる」を体験させる
	t.append([7.0, func(): _spawn_cat(Fur.WHITE, Vector2(clampf(player.global_position.x, 140.0, 400.0), 0.0), "風車の羽根から", true)])
	t.append([11.0, func(): start_wind(1.0)])
	t.append([15.0, func(): _spawn_fluff_storm()])
	t.append([23.0, func(): _spawn_geese_v(1.0)])
	t.append([28.0, func(): _spawn_balloon(140.0)])
	t.append([28.6, func(): _spawn_balloon(400.0)])
	t.append([31.0, func(): _spawn_windmill(1.0)])
	t.append([34.0, func(): start_wind(-1.0)])
	# 神々が初めて気づく
	t.append([36.0, func(): hud.god_say("おや、何か昇ってくるぞ。", 2.6)])
	t.append([38.8, func(): hud.god_say("猫を拾いながらじゃ。", 2.6)])
	# 2 匹目：茶トラ。迷子の風船につかまって下から昇ってきて、途中で風船が割れる
	t.append([44.0, func(): _spawn_balloon(270.0, true)])
	t.append([52.0, func(): _spawn_fluff_storm()])
	t.append([54.5, func(): start_wind(1.0)])
	t.append([61.0, func(): _spawn_geese_v(-1.0)])
	t.append([67.0, func(): _spawn_windmill(-1.0)])
	t.append([70.0, func(): _spawn_windmill(1.0)])
	t.append([77.5, func(): start_wind(-1.0)])
	t.append([77.0, func(): _spawn_fluff_storm()])
	# 3 匹目：白猫。森いちばんの大木のてっぺんから（大木を越えるころ）
	t.append([84.0, func(): _spawn_cat(Fur.WHITE, Vector2(150.0, 0.0), "大木のてっぺんから", true)])
	t.append([93.0, func(): start_wind(1.0)])
	t.append([97.0, func(): _spawn_geese_v(1.0)])
	t.append([104.0, func(): _spawn_fluff_storm()])
	t.append([106.0, func(): start_wind(-1.0)])
	t.append([111.0, func(): _spawn_geese_v(-1.0)])
	return t


func spawn_filler(kind: String) -> void:
	if kind == "geese" and road_t - _last_v_t < 7.0:
		kind = "puff"
	if kind == "windmill" and road_t - _last_mill_t < 6.0:
		kind = "balloon"
	match kind:
		"balloon":
			_spawn_balloon(_rng.randf_range(70.0, 470.0))
		"puff":
			_spawn_puff(Vector2(_rng.randf_range(60.0, 480.0), -30.0))
		"geese":
			_spawn_geese_v(-1.0 if _rng.randf() < 0.5 else 1.0)
		"windmill":
			_spawn_windmill(-1.0 if _rng.randf() < 0.5 else 1.0)


func _on_tree_passed() -> void:
	if state == State.ROAD:
		Sfx.fire(self, "tree_rustle", {"x": 150.0})
		_say_once("tree", "メルル", "森の木より、高いところ……もう、どこまで行っちゃうの〜……", 3.0)



# ================================================================ 生成

## 大きな出現のあと、ランダム出現を seconds 秒止める。
func _hold(seconds: float) -> void:
	_hold_until = maxf(_hold_until, road_t + seconds)


func _spawn_balloon(x: float, with_cat := false) -> void:
	var b = BalloonScript.new()
	var rise := 70.0 if with_cat else _rng.randf_range(60.0, 110.0)
	b.setup(Vector2(x, 1010.0), rise, _rng, with_cat)
	Sfx.fire(self, "balloon_rise", {"x": x})
	if with_cat:
		b.released_cat.connect(func(pos: Vector2): _spawn_cat(Fur.TABBY, pos, "迷子の風船から", false))
	world.add_child(b)
	_count("balloon")


## 綿毛がまばらに数粒（埋め草）
func _spawn_puff(center: Vector2) -> void:
	var n := _rng.randi_range(4, 7)
	for i in n:
		var p := center + Vector2(_rng.randf_range(-70.0, 70.0), _rng.randf_range(-80.0, 0.0))
		_spawn_fluff(p)
	_count("puff")


## 綿毛の嵐。画面いっぱいに 40 粒前後を、すき間ができるように散らす（中心どうし 54px 以上）。
func _spawn_fluff_storm() -> void:
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < 42 and tries < 800:
		tries += 1
		var p := Vector2(_rng.randf_range(20.0, GAME_W - 20.0), _rng.randf_range(-420.0, -30.0))
		var ok := true
		for q in placed:
			if p.distance_to(q) < 54.0:
				ok = false
				break
		if ok:
			placed.append(p)
	for p in placed:
		_spawn_fluff(p, true)
	_hold(3.2)
	_count("storm")
	_say_once("storm", "メルル", "ふわふわでかわいいけど、いまはこわい〜！", 2.6)


func _spawn_fluff(p: Vector2, storm := false) -> void:
	var f = FluffScript.new()
	f.setup(p, Vector2(_rng.randf_range(-20.0, 20.0), scroll * 0.72), _rng, storm)
	world.add_child(f)


## 渡り鳥の V 字。先頭が前、両翼が後ろへ伸びる。dir = 1 なら左上から右下へ横切る。
func _spawn_geese_v(dir: float) -> void:
	# 後半ほど速く横切る
	var vel := Vector2(dir * lerpf(115.0, 170.0, road_t / road_time()), scroll * 0.55)
	var fwd := vel.normalized()
	var lead := Vector2(-40.0 if dir > 0.0 else GAME_W + 40.0, _rng.randf_range(60.0, 260.0))
	var phase := _rng.randf() * TAU
	var g = GooseScript.new()
	g.setup(lead, vel, phase)
	world.add_child(g)
	for side in [-1.0, 1.0]:
		var arm := (-fwd).rotated(deg_to_rad(36.0) * side)
		for k in range(1, 6):
			var b = GooseScript.new()
			b.setup(lead + arm * 46.0 * float(k), vel, phase + float(k) * 0.6)
			world.add_child(b)
	_last_v_t = road_t
	_hold(1.6)
	Sfx.fire(self, "geese_incoming", {"x": lead.x})
	_count("geese")


func _spawn_windmill(side: float) -> void:
	var m = WindmillScript.new()
	m.setup(side, -220.0, scroll, _rng)
	m.spin *= lerpf(1.0, 1.7, road_t / road_time())   # 後半ほど速く回る
	world.add_child(m)
	_last_mill_t = road_t
	_hold(1.0)
	_count("windmill")
