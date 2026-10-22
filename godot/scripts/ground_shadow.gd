extends Sprite2D
## キャラクターの奥に敷く、ソフトな「接地影 / 光暈」。
##
## 生成画像に影や光を焼き込むと「光るリング」「影の向きの不一致」が起きるので、
## 影はエンジン側で描く（docs/ai-quality/03-breakage-benchmark.md 参照）。
##
## モード
##   SHADOW : 地面のあるシーン用。足元を暗く落として接地させる。
##   GLOW   : 夜空など暗い背景用。黒い影は沈んで見えないため、
##            加算合成の淡い光暈でキャラクターを背景から分離する。
##
## top_level にしてあるので、親の回転・拡縮・被弾のつぶれの影響を受けない。

enum Mode { SHADOW, GLOW }

@export var mode: Mode = Mode.GLOW
@export var target_path: NodePath
@export var follow_offset := Vector2.ZERO
@export var radius := 52.0
@export var squash := 0.75
@export var opacity := 0.22
@export var tint := Color(0.92, 0.80, 1.0)

var _target: Node2D


func _ready() -> void:
	top_level = true
	z_index = -1
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture = _radial_gradient()

	if mode == Mode.SHADOW:
		modulate = Color(0.06, 0.02, 0.10, maxf(opacity, 0.35))
		scale = Vector2(radius / 64.0, radius * minf(squash, 0.35) / 64.0)
		if follow_offset == Vector2.ZERO:
			follow_offset = Vector2(0.0, 30.0)
	else:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = mat
		modulate = Color(tint.r, tint.g, tint.b, opacity)
		scale = Vector2(radius / 64.0, radius * squash / 64.0)

	if not target_path.is_empty():
		_target = get_node_or_null(target_path) as Node2D
	if _target:
		global_position = _target.global_position + follow_offset


func _process(_delta: float) -> void:
	if _target:
		global_position = _target.global_position + follow_offset


## 中心が濃く、外周が透明な円形グラデーション。
func _radial_gradient() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.00),
		Color(1.0, 1.0, 1.0, 0.62),
		Color(1.0, 1.0, 1.0, 0.20),
		Color(1.0, 1.0, 1.0, 0.00),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex
