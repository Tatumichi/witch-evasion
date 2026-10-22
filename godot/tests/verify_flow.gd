extends SceneTree
## 検証: ステージ間の流れ。
##   - 何も解放していなければ、タイトルで STAGE 2 は選べない
##   - STAGE 1 をクリアすると STAGE 2 が解放され、結果画面から SPACE で STAGE 2 が始まる
##   godot --headless --path godot --fixed-fps 60 --script res://tests/verify_flow.gd
## 保存ファイルは読み書きしない。失敗すると exit 1。

const Base := preload("res://scripts/stage/stage_base.gd")

var _gs: Node
var _failed := false


func _initialize() -> void:
	_gs = root.get_node("GameState")
	_gs.call("debug_fresh")
	var scene: Node = (load("res://scenes/stage1.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	_run(scene)


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


func _press(keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = true
	root.push_input(ev)
	await physics_frame
	var up := InputEventKey.new()
	up.keycode = keycode
	up.pressed = false
	root.push_input(up)
	await physics_frame


func _run(s1: Node) -> void:
	await _wait(0.3)
	var title: Label = s1.hud.get_node("Root").find_child("TitleStage", true, false)

	# --- 未解放の STAGE 2 は選べるが始められない
	if not _check(s1.state == Base.State.TITLE and title.text.contains("STAGE 1"), "タイトルは STAGE 1"): return
	await _press(KEY_RIGHT)
	if not _check(title.text.contains("STAGE 2") and int(_gs.selected) == 2, "→ で STAGE 2 を選べる"): return
	await _press(KEY_SPACE)
	await _wait(0.3)
	if not _check(s1.state == Base.State.TITLE and current_scene == s1, "未解放の STAGE 2 は始まらない"): return
	await _press(KEY_LEFT)

	# --- STAGE 1 をボス戦から始めてクリア
	s1.god_mode = true
	s1.start_stage()
	s1._enter_boss_intro()
	await _wait(3.5)
	s1._boss.debug_fill(1.0)
	await _wait(7.0)
	if not _check(s1.hud.is_result_visible(), "STAGE 1 クリア結果"): return
	if not _check(s1.hud._result_hint.text.contains("STAGE 2"), "結果画面に「STAGE 2 へ」"): return
	if not _check(_gs.is_unlocked(2), "STAGE 2 が解放される"): return

	# --- SPACE で STAGE 2 へ
	await _press(KEY_SPACE)
	await _wait(1.0)
	var s2 := current_scene
	if not _check(s2 != null and s2 != s1 and s2.stage_number() == 2, "STAGE 2 のシーンに移る"): return
	if not _check(s2.state == Base.State.INTRO or s2.state == Base.State.ROAD, "STAGE 2 がタイトルを飛ばして始まる"): return

	if not _failed:
		print("[OK] ステージ間の流れ 検証完了")
		quit(0)
