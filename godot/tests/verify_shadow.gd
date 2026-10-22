extends SceneTree
## ステージ1のShadowノードが正しく構成されているかを確認する。

func _init() -> void:
	var packed := load("res://scenes/stage1.tscn") as PackedScene
	if packed == null:
		print("[shadow] scene not found")
		quit(1)
		return
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame

	var shadow := scene.get_node_or_null("Shadow") as Sprite2D
	if shadow == null:
		print("[shadow] node missing")
		quit(1)
		return
	var player := scene.get_node_or_null("World/Player") as Node2D
	print("[shadow] texture=", shadow.texture)
	print("[shadow] tex_size=", shadow.texture.get_size() if shadow.texture else Vector2.ZERO)
	print("[shadow] visible=", shadow.visible, " modulate=", shadow.modulate, " self_modulate=", shadow.self_modulate)
	print("[shadow] scale=", shadow.scale, " z=", shadow.z_index, " top_level=", shadow.top_level)
	print("[shadow] pos=", shadow.global_position, " player=", player.global_position if player else Vector2.ZERO)
	print("[shadow] script=", shadow.get_script().resource_path if shadow.get_script() else "none")
	quit(0)
