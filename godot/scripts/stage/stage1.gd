extends "res://scripts/stage/stage_base.gd"
## STAGE 1「村の空」。仕様は docs/stage_design.md の「STAGE 1」。素材は docs/stage1-assets.md。
## 操作を覚えるチュートリアル。洗濯物・鳩の列・落ちてくる風見鶏・煙突の煙。ボスは「ぐるぐる大風見鶏」。
## 共通の進行（帽子・猫・キャンディ・やり直し・ボス戦の流れ・結果）は stage_base.gd。

const LaundryScript := preload("res://scripts/stage/laundry.gd")
const PigeonScript := preload("res://scripts/stage/pigeon.gd")
const VaneScript := preload("res://scripts/stage/weathervane.gd")
const SmokeScript := preload("res://scripts/stage/smoke.gd")
const BossScript := preload("res://scripts/stage/boss_weathervane.gd")

## 道中の長さ（秒）とスクロール速度（STAGE 1 = 1.0 倍）
const ROAD_TIME := 120.0
const SCROLL := 230.0
const CATS_TOTAL := 4

## 道中の「埋め草」の出現設定。区間ごとに間隔と種類の重みを変える。
## 鳩の列はほかの障害物とまとめて降らせると避けられないので、出たあとは少し間を空ける。
const SECTIONS := [
	{"from": 2.0, "to": 18.0, "gap": [1.7, 2.5], "w": {"sheet": 0.5, "sock": 0.5}},
	{"from": 18.0, "to": 48.0, "gap": [1.3, 2.0], "w": {"sheet": 0.38, "sock": 0.42, "pigeons": 0.20}},
	{"from": 48.0, "to": 85.0, "gap": [1.1, 1.7], "w": {"sheet": 0.25, "sock": 0.25, "pigeons": 0.15, "vane": 0.35}},
	{"from": 85.0, "to": 116.0, "gap": [1.0, 1.5], "w": {"sheet": 0.25, "sock": 0.22, "pigeons": 0.18, "vane": 0.35}},
]

var _last_row_t := -99.0


func stage_number() -> int:
	return 1

func stage_name() -> String:
	return "村の空"

func road_time() -> float:
	return ROAD_TIME

func scroll_speed() -> float:
	return SCROLL

func cats_total() -> int:
	return CATS_TOTAL

func sections() -> Array:
	return SECTIONS

func make_boss() -> Node2D:
	return BossScript.new()

func boss_cat() -> Array:
	return [Fur.TABBY, "大風見鶏のとさかから"]

func line_start() -> Array:
	return ["メルル", "ひゃっ……洗濯物が、飛んでくる〜！！"]

func line_boss_intro() -> Array:
	return ["メルル", "風見鶏さん、うしろに猫ちゃんが！　ちょっとだけじっとしてて〜！"]

func line_boss_satisfied() -> Array:
	return ["大風見鶏", "……コケッ。"]

func lines_clear_gods() -> Array:
	return ["……ん？　今、下で何か光らなかったか？"]

func stage_on_satisfied() -> void:
	Sfx.fire(self, "boss_koke", {"delay": 0.7})

func stage_reset() -> void:
	_last_row_t = -99.0

func stage_ready() -> void:
	background.tower_passed.connect(_on_tower_passed)


# ================================================================ 道中の出現表

func build_timeline() -> Array:
	var t: Array = []
	# 最初は洗濯物だけ。ゆっくりで「動けばよけられる」を覚える
	t.append([1.0, func(): _spawn_sheet(-1.0, 160.0)])
	t.append([3.2, func(): _spawn_sock(1.0, 240.0)])
	# 1 匹目の猫は必ず真上に落とす（動かなくても受け止められる）
	t.append([6.0, func(): _spawn_cat(Fur.TABBY, Vector2(player.global_position.x, 0.0), "パン屋の煙突から", true)])
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
	t.append([79.0, func(): _spawn_cat(Fur.TABBY, Vector2(392.0, 0.0), "教会の鐘から", true)])
	t.append([96.0, func(): _spawn_pigeon_row()])
	t.append([108.0, func(): _spawn_pigeon_row()])
	return t


func _event_clothesline_cat() -> void:
	var x := _rng.randf_range(120.0, 420.0)
	_spawn_cat(Fur.TABBY, Vector2(x, 0.0), "物干し竿から", true)
	_spawn_sock(-1.0, 120.0)
	_spawn_sock(1.0, 200.0)


func spawn_filler(kind: String) -> void:
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


func _on_tower_passed() -> void:
	if state == State.ROAD:
		Sfx.fire(self, "church_bell")
		_say_once("tower", "メルル", "塔より、高い……いやいやいや、下見ない。下見ない。", 3.2)


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
	Sfx.fire(self, "pigeon_incoming")
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
	Sfx.fire(self, "chimney_puff", {"x": x, "pitch_jitter": 0.06})
