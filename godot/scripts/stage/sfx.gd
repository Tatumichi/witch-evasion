extends Node
## 効果音の再生係。stage1.tscn の SFX ノード（グループ "sfx"）。一覧と鳴らす場面は docs/sound_effects.md。
##
## 鳴らす側は `Sfx.fire(self, "hit")` のように呼ぶ（Sfx = preload("res://scripts/stage/sfx.gd")）。
## ループ音は `Sfx.loop_on(self, "vane_spin")` / `Sfx.loop_off(self, "vane_spin")`。参照カウントなので、
## 画面に風見鶏が何羽いても 1 本だけ鳴り、最後の 1 羽が消えたら止まる。
##
## 連発でうるさくならないように:
##   - 同じ音の同時発音数を MAX_VOICES で制限（超えたら一番古いものを止めて鳴らし直す）
##   - 全体の同時発音数は POOL_SIZE。あふれたら PRIORITY 以外の一番古い音を止める
##   - pitch_jitter で音程を少し揺らす
##
## 専用音がまだ無い名前は FALLBACK で既存の音に振り替える（STAGE 2 以降）。専用の .wav を置けば自動でそちらが鳴る。

const DIR := "res://assets/audio/se/%s.wav"
const POOL_SIZE := 14
const CENTER := Vector2(270.0, 480.0)

## 同じ音の同時発音数（書いていないものは 2）
const MAX_VOICES := {
	"candy_fire": 2, "candy_hit": 2, "pigeon_scatter": 1, "laundry_pop": 1, "pop_score": 1,
	"talk_meruru": 1, "talk_god": 1, "courage": 3, "cat_effect_warn": 1, "arrow_volley": 1,
	"hit": 1, "faint": 1, "gust": 1, "gust_warning": 1, "church_bell": 1,
}
## 専用音がまだ無い名前 → [代わりに鳴らす既存音, 上乗せする opts]。代わりが "" なら鳴らさない（記録だけ）。
## assets/audio/se/<名前>.wav を置くと、FALLBACK より実ファイルが優先される。一覧は docs/sound_effects.md。
const FALLBACK := {
	# STAGE 2「丘と森の上空」
	"fluff_storm_loop": ["storm_loop", {}],
	"fluff_pop": ["laundry_pop", {"pitch": 1.35}],
	"balloon_pop": ["candy_fire", {"pitch": 0.62, "volume_db": 3.0}],
	"balloon_rise": ["", {}],
	"geese_incoming": ["pigeon_incoming", {"pitch": 0.85}],
	"geese_scatter": ["pigeon_scatter", {"pitch": 0.82}],
	"windmill_loop": ["vane_spin", {}],
	"tree_rustle": ["", {}],
	"boss2_start": ["", {}],
	"boss2_blades_loop": ["vane_spin", {}],
	"flour_throw": ["arrow_volley", {"pitch": 0.8, "volume_db": -3.0}],
}

## 発音数があふれても止めない音（危険の予告と、遊びの手応えに直結するもの）
const PRIORITY := ["gust_warning", "gust", "pigeon_incoming", "hit", "faint", "cat_fall", "cat_catch",
	"boss_appear", "boss_satisfied", "hat_restore", "ui_start"]

@export var volume_db := -3.0

## テスト用: 鳴らした音の名前（新しい順に最大 400 件）と、音ごとの累計回数。
## FALLBACK で振り替えたときは、頼まれた名前と実際に鳴らした名前の両方を記録する。
var played: Array[String] = []
var counts := {}

var _cache := {}
var _pool: Array[AudioStreamPlayer2D] = []
var _names := {}      # player -> name
var _started := {}    # player -> 開始時刻（msec）
var _loops := {}      # name -> {"player": AudioStreamPlayer2D, "count": int}
## ヘッドレス（検証・CI）では音を出さない。Godot は再生中のまま終了すると「resources still in use」を出すため。
## 鳴らす判断はそのまま動き、played に記録される。
var _silent := DisplayServer.get_name() == "headless"


## どのノードからでも呼べる入口。
static func fire(from: Node, name: String, opts := {}) -> void:
	var s = _find(from)
	if s:
		s.play(name, opts)


static func loop_on(from: Node, name: String) -> void:
	var s = _find(from)
	if s:
		s.loop_acquire(name)


static func loop_off(from: Node, name: String) -> void:
	var s = _find(from)
	if s:
		s.loop_release(name)


static func _find(from: Node) -> Node:
	if from == null or not from.is_inside_tree():
		return null
	return from.get_tree().get_first_node_in_group("sfx")


func _ready() -> void:
	add_to_group("sfx")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer2D.new()
		p.attenuation = 0.0          # 距離では小さくしない。位置は左右の定位だけに使う
		p.max_distance = 4000.0
		p.position = CENTER
		add_child(p)
		_pool.append(p)


## opts: pitch（1.0）, pitch_jitter（0.0, ±の幅）, x（定位。0〜540、既定は中央）, volume_db（0.0）, delay（秒）
func play(name: String, opts := {}) -> void:
	var delay: float = opts.get("delay", 0.0)
	if delay > 0.0:
		get_tree().create_timer(delay, false).timeout.connect(func(): play(name, _without_delay(opts)))
		return
	if not _has_file(name) and FALLBACK.has(name):
		_log(name)
		var alt: String = FALLBACK[name][0]
		if alt == "":
			return
		opts = _merge(opts, FALLBACK[name][1])
		name = alt
	var stream := _stream(name)
	if stream == null:
		return
	var p := _take_player(name)
	if p == null:
		return
	var pitch: float = opts.get("pitch", 1.0)
	var jitter: float = opts.get("pitch_jitter", 0.0)
	if jitter > 0.0:
		pitch *= 1.0 + randf_range(-jitter, jitter)
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db + float(opts.get("volume_db", 0.0))
	p.position = Vector2(float(opts.get("x", CENTER.x)), CENTER.y)
	if not _silent:
		p.play()
	_names[p] = name
	_started[p] = Time.get_ticks_msec()
	_log(name)
	if played.size() > 400:
		played.resize(400)


## 終了時に再生中のままだと、ストリームの再生状態が解放されずに残る（--quit で警告が出る）。
func _exit_tree() -> void:
	for p in _pool:
		p.stop()
		p.stream = null
	for name in _loops:
		var p: AudioStreamPlayer2D = _loops[name].player
		if p:
			p.stop()
			p.stream = null
	_loops.clear()


func loop_acquire(name: String) -> void:
	if _loops.has(name):
		_loops[name].count += 1
		return
	# ループは頼まれた名前で数える（振り替え先が同じでも別のループとして止められるように）
	var source := name
	if not _has_file(name) and FALLBACK.has(name):
		_log(name)
		source = FALLBACK[name][0]
		if source == "":
			_loops[name] = {"player": null, "count": 1}
			return
	var stream := _stream(source)
	if stream == null:
		return
	var p := AudioStreamPlayer2D.new()
	p.attenuation = 0.0
	p.max_distance = 4000.0
	p.position = CENTER
	p.stream = stream
	p.volume_db = volume_db - 30.0
	add_child(p)
	if not _silent:
		p.play()
	create_tween().tween_property(p, "volume_db", volume_db, 0.25)
	_loops[name] = {"player": p, "count": 1}
	_log(source)


func loop_release(name: String) -> void:
	if not _loops.has(name):
		return
	_loops[name].count -= 1
	if _loops[name].count > 0:
		return
	var p: AudioStreamPlayer2D = _loops[name].player
	_loops.erase(name)
	if p == null:
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", volume_db - 40.0, 0.3)
	tw.tween_callback(p.queue_free)


func is_looping(name: String) -> bool:
	return _loops.has(name)


func _log(name: String) -> void:
	played.push_front(name)
	counts[name] = int(counts.get(name, 0)) + 1


func _has_file(name: String) -> bool:
	return ResourceLoader.exists(DIR % name)


## opts に振り替え用の opts を重ねる（pitch は掛け算、volume_db は足し算、それ以外は上書きしない）。
func _merge(opts: Dictionary, extra: Dictionary) -> Dictionary:
	var o := opts.duplicate()
	for k in extra:
		if k == "pitch":
			o["pitch"] = float(o.get("pitch", 1.0)) * float(extra[k])
		elif k == "volume_db":
			o["volume_db"] = float(o.get("volume_db", 0.0)) + float(extra[k])
		elif not o.has(k):
			o[k] = extra[k]
	return o


func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := DIR % name
	if not ResourceLoader.exists(path):
		push_warning("SE が見つかりません: %s" % path)
		_cache[name] = null
		return null
	_cache[name] = load(path)
	return _cache[name]


func _take_player(name: String) -> AudioStreamPlayer2D:
	# 同じ音が上限まで鳴っていたら、その一番古いものを使い回す
	var same: Array[AudioStreamPlayer2D] = []
	for p in _pool:
		if p.playing and _names.get(p, "") == name:
			same.append(p)
	if same.size() >= int(MAX_VOICES.get(name, 2)):
		return _oldest(same)
	for p in _pool:
		if not p.playing:
			return p
	# 全部埋まっている: 優先でない一番古い音を止める。新しい音が優先でもなければ鳴らさない
	var victims: Array[AudioStreamPlayer2D] = []
	for p in _pool:
		if not (_names.get(p, "") in PRIORITY):
			victims.append(p)
	if victims.is_empty():
		return _oldest(_pool) if name in PRIORITY else null
	return _oldest(victims)


func _oldest(list: Array[AudioStreamPlayer2D]) -> AudioStreamPlayer2D:
	var best: AudioStreamPlayer2D = list[0]
	for p in list:
		if int(_started.get(p, 0)) < int(_started.get(best, 0)):
			best = p
	return best


func _without_delay(opts: Dictionary) -> Dictionary:
	var o := opts.duplicate()
	o.erase("delay")
	return o
