extends Node
## ステージをまたぐ情報（autoload: GameState）。
## どこまで解放したか、ステージごとのベストスコア、ステージ間の移動。
## 保存先は user://witch_stage.cfg（STAGE 1 だけの頃の形式のまま読める）。

const SAVE_PATH := "user://witch_stage.cfg"

## ステージ番号 → シーンとステージ名。ステージを増やしたらここに足す。
const STAGES := {
	1: {"scene": "res://scenes/stage1.tscn", "name": "村の空"},
	2: {"scene": "res://scenes/stage2.tscn", "name": "丘と森の上空"},
}

## 次のシーンでタイトルを飛ばしてすぐ始めるか（ステージ間の移動で使う）。
var autostart := false
## タイトル画面で選ばれているステージ。
var selected := 1
## false にすると保存ファイルを読み書きしない（テスト用。開発者のベストスコアを汚さない）。
var persist := true

var _unlocked := 1
var _best := {}


func _ready() -> void:
	# テストでは debug_fresh() が _ready より先に呼ばれることがあるので、その場合は読み込まない
	if persist:
		_load()


func last_stage() -> int:
	var m := 1
	for k in STAGES.keys():
		m = maxi(m, int(k))
	return m


func stage_name(n: int) -> String:
	return String(STAGES[n]["name"]) if STAGES.has(n) else ""


func has_stage(n: int) -> bool:
	return STAGES.has(n)


func unlocked() -> int:
	return mini(_unlocked, last_stage())


func is_unlocked(n: int) -> bool:
	return n <= unlocked()


func best(n: int) -> int:
	return int(_best.get(n, 0))


## クリア時に呼ぶ。次のステージを解放し、ベストを更新していれば記録する。
func record_clear(n: int, score: int) -> void:
	if score > best(n):
		_best[n] = score
	_unlocked = maxi(_unlocked, n + 1)
	_save()


## 別のステージのシーンへ移る。
func goto_stage(n: int, start_now: bool) -> void:
	if not STAGES.has(n):
		return
	autostart = start_now
	selected = n
	get_tree().change_scene_to_file.call_deferred(String(STAGES[n]["scene"]))


## テスト用：保存せずに解放状態だけ変える。
func debug_unlock(n: int) -> void:
	_unlocked = maxi(_unlocked, n)


## テスト用：保存ファイルを使わず、何も解放していない状態から始める。
func debug_fresh() -> void:
	persist = false
	_unlocked = 1
	_best.clear()
	selected = 1


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	for n in STAGES.keys():
		var b := int(cfg.get_value("stage%d" % n, "best", 0))
		if b > 0:
			_best[n] = b
			# ベストがある = そのステージはクリア済み
			_unlocked = maxi(_unlocked, int(n) + 1)
	_unlocked = maxi(_unlocked, int(cfg.get_value("progress", "unlocked", 1)))


func _save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	for n in _best.keys():
		cfg.set_value("stage%d" % n, "best", _best[n])
	cfg.set_value("progress", "unlocked", _unlocked)
	cfg.save(SAVE_PATH)
