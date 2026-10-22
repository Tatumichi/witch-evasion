extends CanvasLayer
## スコア表示とタイトル / ゲームオーバーのオーバーレイ。

var _score: Label
var _best: Label
var _overlay: Control
var _title: Label
var _line1: Label
var _line2: Label
var _hint: Label

var _best_value := 0


func _ready() -> void:
	_score = _make_label(48, Color(1.0, 0.97, 0.99))
	_score.position = Vector2(26.0, 6.0)
	add_child(_score)

	_best = _make_label(18, Color(1.0, 0.78, 0.92, 0.8))
	_best.position = Vector2(30.0, 70.0)
	add_child(_best)

	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	_title = _make_label(56, Color(1.0, 0.91, 0.97))
	_line1 = _make_label(24, Color(1.0, 0.74, 0.91, 0.95))
	_line2 = _make_label(24, Color(1.0, 0.74, 0.91, 0.95))
	_hint = _make_label(20, Color(0.95, 0.9, 1.0, 0.72))

	for l in [_title, _line1, _line2, _hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)


func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.07, 0.02, 0.10, 0.9))
	l.add_theme_constant_override("outline_size", maxi(4, int(size / 6.0)))
	return l


func setup(best: int) -> void:
	_best_value = best
	set_score(0)


func set_score(v: int) -> void:
	_score.text = str(v)


func show_ready(best: int) -> void:
	_best_value = best
	_overlay.visible = true
	_best.visible = false
	_title.text = "WITCH FLIGHT"
	_line1.text = "Fly through the night sky"
	_line2.text = "BEST  %d" % best
	_hint.text = "WASD / ARROWS      SPACE to start"


func show_game_over(score: int, best: int, is_best: bool) -> void:
	_best_value = best
	_overlay.visible = true
	_best.visible = false
	_title.text = "GAME OVER"
	_line1.text = "SCORE  %d" % score
	_line2.text = ("NEW BEST  %d" if is_best else "BEST  %d") % best
	_hint.text = "SPACE to retry"


func hide_overlay() -> void:
	_overlay.visible = false
	_best.visible = true
	_best.text = "BEST  %d" % _best_value
