extends Node
## ステージの BGM。親（stage_base.gd を継承したステージ）の state を毎フレーム見て、曲を切り替える。
## ステージ側には手を入れずに済むよう、状態の変化だけを手がかりにしている。
##
##   TITLE / INTRO / ROAD     … 道中曲（STAGE 1 は「村の空」。タイトルから鳴らし、開始しても頭に戻さない）
##   BOSS_INTRO / BOSS        … ボス曲（STAGE 1 は「迷子の風見鶏」。イントロが登場演出に重なる）
##   CLEAR                    … ボス曲をフェードアウト
##   FAINT                    … 音量を下げて待つ。やり直しで、道中なら道中曲、ボス戦ならボス曲を頭から
##
## 音源と作曲データ: godot/assets/audio/bgm/*.ogg ← tools/music/*_bgm.py（MIDI 原本は art/music/）
## OGG は「イントロ＋ループ本体」で終わるように書き出してあり、TRACKS の loop_offset 秒の位置へ戻ってループする。
##
## どの曲を鳴らすかはステージに聞く: ステージが bgm_track(role) を持っていれば、その名前（TRACKS のキー）を使う。
## 持っていなければ STAGE 1 の曲。role は "road"（タイトル〜道中）と "boss"。

const StageScript := preload("res://scripts/stage/stage_base.gd")

const TRACKS := {
	"stage1_road": {"path": "res://assets/audio/bgm/stage1_mura_no_sora.ogg", "loop_offset": 12.0},
	"stage1_boss": {"path": "res://assets/audio/bgm/boss1_maigo_no_kazamidori.ogg", "loop_offset": 4.186047},
	"stage2_road": {"path": "res://assets/audio/bgm/stage2_oka_to_mori.ogg", "loop_offset": 10.909091},
	"stage2_boss": {"path": "res://assets/audio/bgm/boss2_hagure_fusha.ogg", "loop_offset": 4.0},
}

@export var volume_db := -6.0
@export var faint_duck_db := -14.0

var _player: AudioStreamPlayer
var _current := ""        # 役割（"road" / "boss"）
var _current_key := ""    # TRACKS のキー
## ヘッドレス（検証・CI）では音を出さない。Godot は再生中のまま終了すると「resources still in use」を出すため。
## どの曲を鳴らすかの判断と音量の変化はそのまま動くので、テストは current_track() と音量で確かめる。
var _silent := DisplayServer.get_name() == "headless"
var _last_state := -1
var _tween: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.volume_db = volume_db
	add_child(_player)


## 終了時に再生中のままだと、ストリームの再生状態が解放されずに残る（--quit で警告が出る）。
func _exit_tree() -> void:
	_kill_tween()
	_player.stop()
	_player.stream = null


func _process(_delta: float) -> void:
	var stage := get_parent()
	if stage == null or not ("state" in stage):
		return
	var s: int = stage.state
	if s == _last_state:
		return
	var prev := _last_state
	_last_state = s
	match s:
		StageScript.State.TITLE, StageScript.State.INTRO, StageScript.State.ROAD:
			# 気絶からのやり直しは頭から。タイトル→開始はそのまま流し続ける
			_play("road", prev == StageScript.State.FAINT)
		StageScript.State.BOSS_INTRO, StageScript.State.BOSS:
			_play("boss", prev == StageScript.State.FAINT)
		StageScript.State.CLEAR:
			_fade_to(-60.0, 2.5, true)
		StageScript.State.FAINT:
			_fade_to(volume_db + faint_duck_db, 0.6, false)


## その曲のファイルがあるか（ステージが専用曲の有無で切り替えるのに使う）。
static func has_file(key: String) -> bool:
	return TRACKS.has(key) and ResourceLoader.exists(String(TRACKS[key].path))


func _key_for(role: String) -> String:
	var stage := get_parent()
	if stage and stage.has_method("bgm_track"):
		return String(stage.call("bgm_track", role))
	return "stage1_" + role


func _play(role: String, restart: bool) -> void:
	var key := _key_for(role)
	if role == _current and key == _current_key and not restart:
		_fade_to(volume_db, 0.4, false)
		return
	var stream := _load(key)
	if stream == null:
		return
	_current = role
	_current_key = key
	_kill_tween()
	_player.stream = stream
	_player.volume_db = volume_db
	if not _silent:
		_player.play()


func _load(key: String) -> AudioStream:
	if not TRACKS.has(key):
		push_warning("BGM の名前が TRACKS にありません: %s" % key)
		return null
	var info: Dictionary = TRACKS[key]
	if not ResourceLoader.exists(info.path):
		push_warning("BGM が見つかりません: %s" % info.path)
		return null
	var stream = load(info.path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
		stream.loop_offset = info.loop_offset
	return stream


## 今鳴らしている曲の役割（"road" / "boss"、止まっていれば ""）。
func current_track() -> String:
	return _current


## 今鳴らしている曲の TRACKS のキー（"stage1_road" など、止まっていれば ""）。
func current_key() -> String:
	return _current_key


func current_stream() -> AudioStream:
	return _player.stream if _current != "" else null


func current_volume_db() -> float:
	return _player.volume_db


func _fade_to(db: float, sec: float, stop_after: bool) -> void:
	if _current == "":
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", db, sec)
	if stop_after:
		_tween.tween_callback(func():
			_player.stop()
			_current = ""
			_current_key = "")


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
