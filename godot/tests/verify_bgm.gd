extends SceneTree
## 検証: STAGE 1 の BGM が状態に合わせて切り替わる。
##   godot --headless --path godot --fixed-fps 60 --script res://tests/verify_bgm.gd
## 失敗すると exit 1。

const Stage := preload("res://scripts/stage/stage1.gd")
const ROAD := "res://assets/audio/bgm/stage1_mura_no_sora.ogg"
const BOSS := "res://assets/audio/bgm/boss1_maigo_no_kazamidori.ogg"

var _scene: Node
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


func _player() -> AudioStreamPlayer:
	return _scene.get_node("BGM").get_child(0) as AudioStreamPlayer


func _now_playing() -> String:
	var p := _player()
	return p.stream.resource_path if p.playing and p.stream else ""


func _run() -> void:
	await _wait(0.2)
	_check(_now_playing() == ROAD, "タイトルで道中曲が鳴る")
	var road_stream := _player().stream as AudioStreamOggVorbis
	_check(road_stream.loop and is_equal_approx(road_stream.loop_offset, 12.0), "道中曲は 12.0 秒の位置へループする")

	var before := _player().stream
	_scene.start_stage()
	await _wait(0.2)
	_check(_now_playing() == ROAD and _player().stream == before, "開始しても道中曲を頭から鳴らし直さない")

	_scene._enter_boss_intro()
	await _wait(0.2)
	_check(_now_playing() == BOSS, "ボス登場でボス曲に切り替わる")
	var boss_stream := _player().stream as AudioStreamOggVorbis
	_check(boss_stream.loop and is_equal_approx(boss_stream.loop_offset, 4.186047), "ボス曲は 4.186 秒の位置へループする")

	_scene._faint()
	await _wait(1.0)
	_check(_player().volume_db < -15.0, "気絶中は音量が下がる")
	_scene._restart_after_faint()
	await _wait(0.2)
	_check(_now_playing() == BOSS and _player().volume_db > -7.0, "ボス戦のやり直しでボス曲が元の音量で鳴る")

	_scene._set_state(Stage.State.CLEAR)
	await _wait(3.0)
	_check(_now_playing() == "", "クリアでボス曲がフェードアウトして止まる")

	quit(1 if _failed else 0)
