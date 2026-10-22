extends SceneTree
## 検証: STAGE 1「村の空」を最初から最後まで通して動かす。
##   godot --headless --path godot --fixed-fps 60 --script res://tests/verify_stage1.gd
## --fixed-fps 60 を付けると実時間を待たずに進む（全体で 3 分強のゲーム時間）。
## 失敗すると exit 1。

const Stage := preload("res://scripts/stage/stage1.gd")

var _scene: Node
var _failed := false


func _initialize() -> void:
	_scene = (load("res://scenes/stage1.tscn") as PackedScene).instantiate()
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
	var frames := int(seconds * 60.0)
	for i in frames:
		await physics_frame


func _wait_state(s: int, max_seconds: float) -> bool:
	var frames := int(max_seconds * 60.0)
	for i in frames:
		if _scene.state == s:
			return true
		await physics_frame
	return _scene.state == s


func _run() -> void:
	await _wait(0.2)
	var hud = _scene.get_node("HUD")
	var player = _scene.get_node("World/Player")

	# --- タイトル
	if not _check(_scene.state == Stage.State.TITLE and hud.is_title_visible(), "タイトル表示"): return

	# --- 開始
	_scene.start_stage()
	if not _check(_scene.state == Stage.State.INTRO and _scene.hats == 3, "開始で INTRO・帽子 3"): return
	await _wait(0.3)

	# --- 被弾と無敵時間
	_scene._on_damaged()
	_scene._on_damaged()
	if not _check(_scene.hats == 2 and player.invincible > 0.0, "被弾で帽子 2、無敵中は 2 回目が当たらない"): return

	# --- 白猫を真上から落とし、受け止めてバリアになるか
	await _wait(1.6)
	var saved_before: int = _scene.cats_saved
	_scene._spawn_cat(1, Vector2(player.global_position.x, 0.0), "テスト", true)
	await _wait(3.2)
	if not _check(_scene.cats_saved == saved_before + 1, "落ちてきた猫を受け止める"): return
	if not _check(_scene.cat_effect == 1 and player.barrier, "白猫でバリアが付く"): return

	# --- 茶トラのキャンディが小さな障害物を壊すか
	_scene._start_cat_effect(0)
	var PigeonScript := preload("res://scripts/stage/pigeon.gd")
	var target = PigeonScript.new()
	target.setup(Vector2(player.global_position.x - 34.0, 140.0), 0.0, RandomNumberGenerator.new())
	_scene.world.add_child(target)
	await _wait(2.0)   # 最初の 1 発は 0.6 秒後、届くまで約 0.8 秒
	if not _check(int(_scene.spawn_counts.get("candy", 0)) > 0, "茶トラでキャンディを発射"): return
	if not _check(not is_instance_valid(target) or not target.is_in_group("obstacles"), "キャンディで鳩が逃げる"): return

	# --- 帽子 0 で目を回し、最初からやり直し
	_scene._end_cat_effect()
	player.invincible = 0.0
	_scene.hats = 1
	_scene._on_damaged()
	if not _check(_scene.state == Stage.State.FAINT, "帽子 0 で目を回す"): return
	if not _check(await _wait_state(Stage.State.INTRO, 4.0), "目を回したあと最初からやり直し"): return
	if not _check(_scene.hats == 3 and _scene.road_t == 0.0, "やり直しで帽子 3・道中 0 秒"): return

	# --- 道中を通しで（被弾なし）
	_scene.god_mode = true
	player.god_mode = true
	if not _check(await _wait_state(Stage.State.BOSS_INTRO, 130.0), "道中 120 秒を走りきってボス登場"): return
	var c: Dictionary = _scene.spawn_counts
	print("     spawn_counts = %s" % str(c))
	for kind in ["sheet", "sock", "pigeons", "vane", "smoke"]:
		if not _check(int(c.get(kind, 0)) > 0, "道中に %s が出た" % kind): return
	if not _check(int(c.get("cat", 0)) == 3, "道中の猫は 3 匹"): return
	if not _check(_scene._said.has("tower"), "教会の塔を越えたセリフが出た"): return

	# --- ボス戦
	if not _check(await _wait_state(Stage.State.BOSS, 6.0), "ボス戦開始"): return
	await _wait(10.0)
	if not _check(int(_scene.spawn_counts.get("cat", 0)) == 4, "ボス戦でとさかの猫が落ちる"): return
	if not _check(await _wait_state(Stage.State.CLEAR, 60.0), "満足ゲージが満タンになってクリア"): return
	await _wait(6.0)
	if not _check(hud.is_result_visible(), "クリア結果を表示"): return
	print("     score=%d cats=%d courage=%d hits=%d" % [_scene.score, _scene.cats_saved, _scene.courage, _scene.hits_taken])

	if not _failed:
		print("[OK] STAGE 1 通し検証 完了")
		quit(0)
