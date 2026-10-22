extends Node2D

## 環境確認用のエントリースクリプト。
## `godot --headless --quit --path .` でこの print が出れば構築成功。


func _ready() -> void:
	print("[OK] Godot boot: scene loaded, version=%s" % Engine.get_version_info().get("string", "unknown"))
