extends SceneTree
## 検証: タイトル画面のロゴ / 立ち絵カードが読み込まれ、
## ゲーム開始でタイトルが隠れてスコア表示に切り替わることを確認する。
##   godot --headless --path godot --script res://tests/verify_ui.gd

var _frames := 0
var _scene: Node

func _initialize() -> void:
	_scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_scene)

func _fail(message: String) -> bool:
	printerr("[FAIL] " + message)
	quit(1)
	return true

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false

	var hud := _scene.get_node("HUD")
	var title := hud.get_node_or_null("Overlay/TitlePanel")
	var logo := hud.get_node_or_null("Overlay/TitlePanel/Logo") as TextureRect
	var card := hud.get_node_or_null("Overlay/TitlePanel/Card") as TextureRect
	var score := hud.get_node_or_null("Score") as Label

	if title == null or logo == null or card == null:
		return _fail("タイトル画面のノード構成が想定と違う")
	if logo.texture == null:
		return _fail("ロゴ画像が読み込まれていない（assets/ui/logo.png）")
	if card.texture == null:
		return _fail("立ち絵カードが読み込まれていない（assets/ui/title_witch.png）")
	if not title.is_visible_in_tree():
		return _fail("READY 状態でタイトルが表示されていない")
	print("[OK] title logo=%s card=%s" % [logo.texture.resource_path, card.texture.resource_path])

	_scene.call("_start")
	if title.is_visible_in_tree():
		return _fail("ゲーム開始後もタイトルが表示されたまま")
	if score == null or not score.is_visible_in_tree():
		return _fail("ゲーム開始後にスコアが表示されない")
	print("[OK] title hidden, score visible after start")
	return true
