extends SceneTree
## 検証: 魔女スプライトの装着と、被弾時のテクスチャ切替を確認する。
##   godot --headless --path godot --script res://tests/verify_sprite.gd

var _frames := 0
var _scene: Node

func _initialize() -> void:
	_scene = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_scene)

func _fail(message: String) -> bool:
	printerr("[FAIL] " + message)
	quit(1)
	return true

func _texture_of(player: Node) -> Texture2D:
	var sprite := player.get_node_or_null("WitchSprite") as Sprite2D
	return sprite.texture if sprite else null

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false

	var player := _scene.get_node("World/Player")
	var idle := _texture_of(player)
	if idle == null:
		return _fail("WitchSprite が無い / テクスチャ未設定")
	if not idle.resource_path.ends_with("witch_sprite.png"):
		return _fail("通常テクスチャが witch_sprite.png でない: " + idle.resource_path)
	print("[OK] idle=%s size=%s" % [idle.resource_path, idle.get_size()])

	player.call("die")
	var hit := _texture_of(player)
	if hit == null or not hit.resource_path.ends_with("witch_hit.png"):
		return _fail("die() で被弾テクスチャに切り替わらない")
	print("[OK] hit=%s" % hit.resource_path)

	player.call("spawn_at", Vector2(270, 710))
	var respawn := _texture_of(player)
	if respawn == null or not respawn.resource_path.ends_with("witch_sprite.png"):
		return _fail("spawn_at() で通常テクスチャに戻らない")
	print("[OK] respawn=%s" % respawn.resource_path)
	return true
