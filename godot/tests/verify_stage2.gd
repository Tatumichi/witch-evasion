extends SceneTree
## 検証: STAGE 2「丘と森の上空」を最初から最後まで通して動かす（横風・風船・効果音・BGM も）。
##   godot --headless --path godot --fixed-fps 60 --script res://tests/verify_stage2.gd
## 保存ファイルは読み書きしない。失敗すると exit 1。

const Base := preload("res://scripts/stage/stage_base.gd")
const BalloonScript := preload("res://scripts/stage/balloon.gd")
const FluffScript := preload("res://scripts/stage/fluff.gd")
const GooseScript := preload("res://scripts/stage/goose.gd")
const BagScript := preload("res://scripts/stage/flour_bag.gd")

var _scene: Node
var _sfx: Node
var _bgm: Node
var _failed := false


func _initialize() -> void:
	root.get_node("GameState").call("debug_fresh")   # 開発者の保存データを使わない・汚さない
	_scene = (load("res://scenes/stage2.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	_run()


func _check(cond: bool, message: String) -> bool:
	if cond:
		print("[OK] " + message)
		return true
	printerr("[FAIL] " + message)
	_failed = true
	quit(1)
	return false


func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame


func _wait_until(cond: Callable, max_seconds: float) -> bool:
	for i in int(max_seconds * 60.0):
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _n(name: String) -> int:
	return int(_sfx.counts.get(name, 0))


func _heard(names: Array, message: String) -> bool:
	var missing := names.filter(func(n): return _n(n) == 0)
	return _check(missing.is_empty(), message + ("" if missing.is_empty() else "（鳴っていない: %s）" % ", ".join(missing)))


func _run() -> void:
	await _wait(0.2)
	var player = _scene.get_node("World/Player")
	_sfx = _scene.get_node("SFX")
	_bgm = _scene.get_node("BGM")

	if not _check(_scene.state == Base.State.TITLE, "タイトル表示"): return
	if not _check(_bgm.current_key() == "stage2_road", "STAGE 2 の専用道中曲「丘と森の上空」を流す"): return
	_scene.start_stage()
	if not _check(_scene.stage_number() == 2 and is_equal_approx(_scene.scroll, 253.0), "STAGE 2・スクロール 1.1 倍"): return
	await _wait(2.5)

	# --- 横風：予告（音）のあとメルルが押し流される（音）
	player.global_position = Vector2(270.0, 700.0)
	_scene.start_wind(1.0)
	if not _check(_scene.wind_phase == 1 and _scene._env_force == Vector2.ZERO, "横風は予告から始まる（まだ押されない）"): return
	if not _heard(["gust_warning"], "横風の予告音"): return
	await _wait(1.8)
	if not _check(_scene.wind_phase == 2 and _scene._env_force.x > 100.0, "予告のあと右へ押される"): return
	if not _heard(["gust"], "横風の音"): return
	var x0: float = player.global_position.x
	await _wait(0.5)
	if not _check(player.global_position.x > x0 + 40.0, "メルルが風で流される（%.0f → %.0f）" % [x0, player.global_position.x]): return
	await _wait(2.0)
	if not _check(_scene.wind_phase == 0 and _scene._env_force == Vector2.ZERO, "風がやむ"): return

	# --- 風船：当たっても帽子は減らず、割れて（音）はじかれる
	var hats_before: int = _scene.hats
	player.invincible = 0.0
	player.global_position = Vector2(270.0, 700.0)
	var pops_before := _n("balloon_pop")
	var alt_before := _n("candy_fire")
	var b = BalloonScript.new()
	b.setup(Vector2(254.0, 760.0), 80.0, RandomNumberGenerator.new())
	_scene.world.add_child(b)
	await _wait(0.8)
	if not _check(_scene.hats == hats_before, "風船に当たっても帽子は減らない"): return
	if not _check(not is_instance_valid(b) or not b.is_in_group("bumpers"), "風船が割れる"): return
	if not _check(_n("balloon_pop") > pops_before, "風船が割れる音（balloon_pop）"): return
	if not _check(_n("candy_fire") > alt_before, "専用音が無いあいだは candy_fire に振り替えて鳴らす"): return

	# --- 猫つき風船：割れると猫が落ちてくる
	var cats_before := int(_scene.spawn_counts.get("cat", 0))
	_scene._spawn_balloon(270.0, true)
	await _wait(10.0)
	if not _check(int(_scene.spawn_counts.get("cat", 0)) > cats_before, "猫つき風船が割れて猫が落ちる"): return

	# --- キャンディで綿毛・渡り鳥が飛ぶ音
	var f = FluffScript.new()
	f.setup(Vector2(100.0, 300.0), Vector2.ZERO, RandomNumberGenerator.new())
	_scene.world.add_child(f)
	f.break_apart()
	var g = GooseScript.new()
	g.setup(Vector2(100.0, 300.0), Vector2.ZERO, 0.0)
	_scene.world.add_child(g)
	g.break_apart()
	if not _heard(["fluff_pop", "geese_scatter"], "綿毛が吹き飛ぶ・渡り鳥が逃げる音"): return
	if not _heard(["laundry_pop", "pigeon_scatter"], "（専用音が無いあいだは洗濯物・鳩の音に振り替え）"): return

	# --- 道中を通しで（被弾なし）
	_scene.start_stage()
	_scene.god_mode = true
	player.god_mode = true
	var storm_heard := false
	var mill_heard := false
	for i in int(130.0 * 60.0):
		if _scene.state == Base.State.BOSS_INTRO:
			break
		storm_heard = storm_heard or _sfx.is_looping("fluff_storm_loop")
		mill_heard = mill_heard or _sfx.is_looping("windmill_loop")
		await physics_frame
	if not _check(_scene.state == Base.State.BOSS_INTRO, "道中 120 秒を走りきってボス登場"): return
	var c: Dictionary = _scene.spawn_counts
	print("     spawn_counts = %s" % str(c))
	for kind in ["balloon", "puff", "storm", "geese", "windmill", "wind"]:
		if not _check(int(c.get(kind, 0)) > 0, "道中に %s が出た" % kind): return
	if not _check(int(c.get("cat", 0)) == 3, "道中の猫は 3 匹（猫つき風船を含む）"): return
	if not _check(_scene._said.has("tree"), "大木を越えたセリフが出た"): return
	if not _check(storm_heard, "綿毛の嵐のあいだ風音（fluff_storm_loop）がループする"): return
	if not _check(mill_heard, "風車がいるあいだ軋み（windmill_loop）がループする"): return
	if not _heard(["storm_loop", "vane_spin"], "（専用音が無いあいだは storm_loop・vane_spin に振り替え）"): return
	if not _heard(["geese_incoming", "balloon_rise", "tree_rustle", "boss_appear"], "渡り鳥の予告・風船の予告・大木・ボス登場"): return
	await _wait(0.3)
	if not _check(_bgm.current_key() == "stage2_boss", "ボス戦は専用曲「はぐれ大風車」を流す"): return

	# --- ボス戦
	if not _check(await _wait_until(func(): return _scene.state == Base.State.BOSS, 6.0), "ボス戦開始"): return
	var bags := 0
	for i in 60 * 17:
		await physics_frame
		for n in _scene.world.get_children():
			if n.get_script() == BagScript:
				bags += 1
	if not _check(int(_scene.spawn_counts.get("cat", 0)) == 4, "ボス戦で軸の上の猫が落ちる"): return
	if not _check(bags > 0, "小麦粉の袋が飛んでくる"): return
	if not _heard(["boss2_start", "gust_warning", "gust", "flour_throw", "smoke_in"], "ボス戦開始・突風の予告・突風・袋を投げる・袋が破れる"): return
	if not _check(_sfx.is_looping("boss2_blades_loop"), "ボス戦のあいだ羽根の軋みがループする"): return
	if not _check(await _wait_until(func(): return _scene.state == Base.State.CLEAR, 60.0), "満足ゲージが満タンになってクリア"): return
	await _wait(0.3)
	if not _check(not _sfx.is_looping("boss2_blades_loop"), "満足したら羽根の軋みが止まる"): return
	if not _check(await _wait_until(func(): return _scene.hud.is_result_visible(), 10.0), "クリア結果を表示"): return
	if not _heard(["boss_satisfied", "boss_leave", "god_voice", "result_line"], "満足・帆をたたむ・神々・結果"): return
	if not _check(_scene.hud._result_title.text == "STAGE 2 CLEAR!", "結果の見出しが STAGE 2"): return
	print("     score=%d cats=%d courage=%d" % [_scene.score, _scene.cats_saved, _scene.courage])

	if not _failed:
		print("[OK] STAGE 2 通し検証 完了")
		quit(0)
