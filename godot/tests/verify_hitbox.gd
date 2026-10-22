extends SceneTree
## 検証: メルルの当たり判定が見た目の中心にあり、アイテムと猫を拾えること。
##   godot --headless --path godot --fixed-fps 60 --script res://tests/verify_hitbox.gd
## 失敗すると exit 1。

const Stage := preload("res://scripts/stage/stage1.gd")
const CourageScript := preload("res://scripts/stage/courage.gd")
const PigeonScript := preload("res://scripts/stage/pigeon.gd")

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
	for i in int(seconds * 60.0):
		await physics_frame


func _run() -> void:
	await _wait(0.2)
	var player = _scene.get_node("World/Player")
	var visual: Vector2 = player.VISUAL_CENTER
	var body := player.get_node("CollisionShape2D") as CollisionShape2D
	var catch_area := player.get_node_or_null("CatchArea") as Area2D

	# --- 判定の位置と広さ
	if not _check(body.position.is_equal_approx(visual), "被弾判定が見た目の中心 %s にある" % visual): return
	if not _check(catch_area != null, "取得判定の CatchArea がある"): return
	var catch_shape := catch_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not _check(catch_shape != null and catch_shape.position.is_equal_approx(visual), "取得判定も見た目の中心にある"): return
	if not _check((catch_shape.shape as CircleShape2D).radius >= 36.0, "取得判定は見た目に触れる大きさ (半径 36 以上)"): return
	if not _check(player.collision_mask == 2 and catch_area.collision_mask == 4, "被弾=障害物のみ／取得=アイテム・猫のみ"): return

	# --- 道中まで進める（タイトル → INTRO 2 秒 → ROAD）
	_scene.start_stage()
	_scene.god_mode = true
	player.god_mode = true
	await _wait(2.4)
	if not _check(_scene.state == Stage.State.ROAD, "道中に入った"): return
	await _wait(0.2)

	# --- 見た目の中心の勇気のかけらを取れる
	var courage_before: int = _scene.courage
	_spawn_courage(player.global_position + visual)
	await _wait(0.4)
	if not _check(_scene.courage == courage_before + 1, "見た目の中心のかけらを取れる"): return

	# --- 見た目の中心から少し外れたかけらも取れる（取得判定の広さ）
	var courage_before2: int = _scene.courage
	_spawn_courage(player.global_position + visual + Vector2(30.0, 0.0))
	await _wait(0.4)
	if not _check(_scene.courage == courage_before2 + 1, "中心から 30px ずれたかけらも取れる"): return

	# --- 見た目の中心に落ちてくる猫を受け止められる
	var saved_before: int = _scene.cats_saved
	_scene._spawn_cat(0, Vector2(player.global_position.x + visual.x, 0.0), "テスト", true)
	await _wait(4.0)
	if not _check(_scene.cats_saved == saved_before + 1, "見た目の中心に落ちる猫を受け止める"): return

	# --- 中央の障害物にはちゃんと当たる（取得判定と被弾判定が混ざっていない）
	_scene.god_mode = false
	player.god_mode = false
	player.invincible = 0.0
	player.barrier = false
	var hats_before: int = _scene.hats
	var pigeon = PigeonScript.new()
	pigeon.setup(player.global_position + visual, 0.0, RandomNumberGenerator.new())
	_scene.world.add_child(pigeon)
	await _wait(0.4)
	if not _check(_scene.hats < hats_before, "見た目の中心の障害物には当たる"): return

	if not _failed:
		print("[OK] 当たり判定の検証 完了")
		quit(0)


func _spawn_courage(pos: Vector2) -> void:
	var shard = CourageScript.new()
	shard.setup(pos, 0.0)
	_scene.world.add_child(shard)
