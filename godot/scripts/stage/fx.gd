extends Node2D
## 使い捨ての小さな演出（仮グラフィック）。
##   HAT : 被弾で飛んでいく帽子。くるくる回りながら落ちていく。
##   POP : 文字がふわっと浮いて消える（「ごめんね」「+100」など）。

enum Kind { HAT, POP }

const FONT := preload("res://assets/fonts/MPLUSRounded1c-Bold.ttf")
const HAT := Color(0.42, 0.30, 0.62)
const HAT_DARK := Color(0.28, 0.18, 0.44)

var kind: int = Kind.HAT
var text := ""
var color := Color.WHITE
var vel := Vector2.ZERO
var life := 1.0

var _t := 0.0


func setup_hat(pos: Vector2) -> void:
	kind = Kind.HAT
	position = pos
	vel = Vector2(randf_range(-90.0, 90.0), -220.0)
	life = 1.6
	z_index = 6


func setup_pop(pos: Vector2, label: String, c: Color) -> void:
	kind = Kind.POP
	position = pos
	text = label
	color = c
	vel = Vector2(0.0, -60.0)
	life = 0.9
	z_index = 7


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	if kind == Kind.HAT:
		vel.y += 520.0 * delta
		rotation += 6.0 * delta
	position += vel * delta
	modulate.a = clampf((life - _t) / 0.35, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	if kind == Kind.HAT:
		draw_colored_polygon(PackedVector2Array([Vector2(-22.0, 8.0), Vector2(22.0, 8.0), Vector2(16.0, 13.0), Vector2(-16.0, 13.0)]), HAT_DARK)
		draw_colored_polygon(PackedVector2Array([Vector2(-12.0, 8.0), Vector2(10.0, 8.0), Vector2(-4.0, -26.0)]), HAT)
		draw_rect(Rect2(-11.0, 2.0, 21.0, 5.0), Color(0.55, 0.92, 0.80))
	else:
		draw_string_outline(FONT, Vector2(-80.0, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 18, 5, Color(0.12, 0.06, 0.16, 0.85))
		draw_string(FONT, Vector2(-80.0, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, 160.0, 18, color)
