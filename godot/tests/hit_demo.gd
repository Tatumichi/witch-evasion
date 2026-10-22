extends Node
## 被弾フレームの見た目を確認するためのデモ。
##   godot --path godot res://tests/hit_demo.tscn --write-movie out/frame.png --quit-after 90
## タイトルを飛ばしてゲームを開始し、1 回被弾させたうえで停止する。

func _ready() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().create_timer(0.8).timeout
	main.call("_start")
	await get_tree().create_timer(0.6).timeout
	main.call("_on_hit")
