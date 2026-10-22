extends SceneTree
## 検証: STAGE 1 を通して動かし、各イベントで効果音が鳴るか（SFX ノードの記録で確かめる）。
##   godot --headless --path godot --fixed-fps 60 --script res://tests/verify_sfx.gd
## ヘッドレスでは実際の音は出さないが、鳴らす判断は SFX.counts に記録される。失敗すると exit 1。

const Stage := preload("res://scripts/stage/stage1.gd")
const SE_DIR := "res://assets/audio/se"

var _scene: Node
var _sfx: Node
var _failed := false


func _initialize() -> void:
	_scene = (load("res://scenes/stage1.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	_run()


func _check(cond: bool, message: String) -> void:
	if cond:
		print("[OK] " + message)
	else:
		printerr("[FAIL] " + message)
		_failed = true


func _wait(seconds: float) -> void:
	for i in int(seconds * 60.0):
		await physics_frame


func _wait_state(s: int, max_seconds: float) -> bool:
	for i in int(max_seconds * 60.0):
		if _scene.state == s:
			return true
		await physics_frame
	return false


func _n(name: String) -> int:
	return int(_sfx.counts.get(name, 0))


func _heard(names: Array, message: String) -> void:
	var missing := names.filter(func(n): return _n(n) == 0)
	_check(missing.is_empty(), message + ("" if missing.is_empty() else "（鳴っていない: %s）" % ", ".join(missing)))


func _run() -> void:
	await _wait(0.2)
	_sfx = _scene.get_node("SFX")
	var player = _scene.get_node("World/Player")
	var hud = _scene.get_node("HUD")

	# --- タイトルで決定（Space）
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	_scene._unhandled_input(key)
	await _wait(0.4)
	_heard(["ui_start", "stage_card"], "タイトルで決定 → 決定音とステージ名の音")

	# --- 被弾。帽子が残り 1 になったら警告
	await _wait(3.0)
	_heard(["talk_meruru"], "メルルのセリフで会話音")
	_scene._on_damaged()
	player.invincible = 0.0
	_scene._on_damaged()
	await _wait(0.4)
	_heard(["hit", "hat_warning"], "被弾音と、帽子が残り 1 の警告")
	player.invincible = 0.0
	_scene.hats = 3
	_scene._refresh_hud()

	# --- 白猫: 落ちてくる → 受け止める → バリア
	_scene._spawn_cat(1, Vector2(player.global_position.x, 0.0), "テスト", true)
	await _wait(3.4)
	_heard(["cat_fall", "cat_catch", "barrier_on", "pop_score"], "猫が落ちる・受け止める・バリア・スコアのポップ")

	# --- 茶トラ: キャンディで鳩が逃げる。効果の終わり際の「かちっ」と終了音
	_scene._end_cat_effect()
	_scene._start_cat_effect(0)
	# 道中のシーツ（キャンディでは壊れない）が射線を横切ると命中しないので、確認のあいだは片付けて出現も止める
	for n in _scene.world.get_children():
		if n != player and n.is_in_group("obstacles"):
			n.queue_free()
	_scene._hold_until = _scene.road_t + 3.0
	var target = preload("res://scripts/stage/pigeon.gd").new()
	target.setup(Vector2(player.global_position.x - 34.0, 140.0), 0.0, RandomNumberGenerator.new())
	_scene.world.add_child(target)
	await _wait(2.0)
	_heard(["candy_fire", "candy_hit", "pigeon_scatter"], "キャンディ発射・命中・鳩が逃げる")
	_check(_n("candy_fire") > 3, "キャンディは連射のたびに鳴る（%d 回）" % _n("candy_fire"))
	# 道中の猫が落ちてきて受け止めると効果が上書きされるので、待つあいだは猫を片付けておく
	for c in get_nodes_in_group("cats"):
		c.queue_free()
	_scene.cat_effect_t = 2.2
	await _wait(2.6)
	_check(_n("cat_effect_warn") >= 3, "残り 2 秒から「かちっ」が鳴る（%d 回）" % _n("cat_effect_warn"))
	_heard(["cat_effect_end"], "猫の効果が切れる音")

	# --- 煙・勇気のかけら・取り逃がし
	_scene._on_smoke(true)
	_scene._on_smoke(false)
	_heard(["smoke_in", "smoke_out"], "煙に入る・出る")
	_scene.hats = 2
	for i in Stage.COURAGE_PER_HAT:
		_scene._on_courage(Area2D.new())
	_heard(["courage", "hat_restore"], "勇気のかけら・帽子がもどった")
	for i in Stage.COURAGE_PER_HAT:
		_scene._on_courage(Area2D.new())
	_heard(["bonus"], "帽子が満タンならボーナス音")
	_scene._on_cat_missed(null)
	_heard(["cat_miss"], "猫を取り逃がす音")

	# --- 気絶とやり直し
	player.invincible = 0.0
	_scene.hats = 1
	_scene._on_damaged()
	_heard(["faint"], "目を回す音")
	await _wait(1.0)
	_scene._restart_after_faint()
	_heard(["restart"], "やり直しの音")

	# --- 道中を通しで（被弾なし）
	_scene.god_mode = true
	player.god_mode = true
	var vane_heard := false
	for i in int(130.0 * 60.0):
		if _scene.state == Stage.State.BOSS_INTRO:
			break
		if _sfx.is_looping("vane_spin"):
			vane_heard = true
		await physics_frame
	_check(_scene.state == Stage.State.BOSS_INTRO, "道中を走りきってボス登場")
	_heard(["pigeon_incoming", "chimney_puff", "church_bell"], "鳩の予告・煙突・教会の鐘")
	_check(vane_heard, "風見鶏（小）がいるあいだ回転音がループする")
	_check(not _sfx.is_looping("vane_spin") or not _scene.world.get_children().any(func(c): return c.get_script() == preload("res://scripts/stage/weathervane.gd")), "風見鶏がいなくなったら回転音が止まる")
	_heard(["boss_appear"], "ボス登場の軋み")

	# --- ボス戦: 矢印 → 突風（予告つき） → 洗濯物の嵐
	if not await _wait_state(Stage.State.BOSS, 6.0):
		_check(false, "ボス戦開始")
	await _wait(0.5)
	_heard(["boss_crow", "gauge_show"], "戦闘開始のコケーッとゲージ表示")
	var storm_heard := false
	for i in int(13.0 * 60.0):
		if _sfx.is_looping("storm_loop"):
			storm_heard = true
		await physics_frame
	_heard(["arrow_volley", "gust_warning", "gust"], "矢印・突風の予告・突風")
	_check(storm_heard, "洗濯物の嵐のあいだ風音がループする")

	# --- キャンディで満足させてクリア
	var LaundryScript := preload("res://scripts/stage/laundry.gd")
	var L = LaundryScript.new()
	L.setup(LaundryScript.Kind.SOCK, Vector2(270.0, 300.0), Vector2.ZERO, RandomNumberGenerator.new())
	_scene.world.add_child(L)
	L.break_apart()
	_heard(["laundry_pop"], "洗濯物がはじける音")
	_scene._start_cat_effect(0)
	# キャンディは真上にしか飛ばない。突風で画面端へ流されたままだとボスに当たらないことがあるので、
	# 当たるまでのあいだボスの真下に置く（発射口はメルルの 34px 左）
	for i in int(6.0 * 60.0):
		if _n("candy_eat") > 0 or _scene._boss == null:
			break
		player.global_position.x = clampf(_scene._boss.global_position.x + 34.0, 40.0, 500.0)
		await physics_frame
	_scene.best = 0
	if not await _wait_state(Stage.State.CLEAR, 60.0):
		_check(false, "クリア")
	await _wait(0.2)
	_heard(["candy_eat"], "ボスがキャンディを食べる音")
	_check(not _sfx.is_looping("storm_loop"), "クリアで嵐の風音が止まる")
	await _wait(6.0)
	_heard(["boss_satisfied", "boss_koke", "boss_leave", "talk_god", "god_voice"], "満足・コケッ・去る・神々のつぶやき")
	_check(hud.is_result_visible(), "リザルト表示")
	_heard(["result_line", "new_best"], "リザルトの行と NEW BEST")

	# --- 42 音すべてに鳴る場面がある
	var all: Array[String] = []
	for f in DirAccess.get_files_at(SE_DIR):
		if f.ends_with(".wav"):
			all.append(f.get_basename())
	_heard(all, "用意した %d 音がすべてどこかで鳴る" % all.size())
	print("     counts = %s" % str(_sfx.counts))

	quit(1 if _failed else 0)
