extends CanvasLayer
## スコア表示とタイトル / ゲームオーバーのオーバーレイ。
## タイトルはロゴ画像＋立ち絵カード。画像が無ければテキスト表示にフォールバックする。

const LOGO_PATH := "res://assets/ui/logo.png"
const CARD_PATH := "res://assets/ui/title_witch.png"

const CARD_POS := Vector2(60.0, 330.0)
const CARD_SIZE := Vector2(420.0, 500.0)

var _score: Label
var _best: Label
var _overlay: Control

var _title_panel: Control
var _logo: TextureRect
var _card: TextureRect
var _best_chip: Label
var _prompt: Label
var _keys: Label

var _over_panel: Control
var _over_title: Label
var _over_line1: Label
var _over_line2: Label
var _over_hint: Label

var _best_value := 0
var _t := 0.0


func _ready() -> void:
	_score = _make_label(48, Color(1.0, 0.97, 0.99))
	_score.name = "Score"
	_score.position = Vector2(26.0, 6.0)
	add_child(_score)

	_best = _make_label(18, Color(1.0, 0.78, 0.92, 0.8))
	_best.name = "Best"
	_best.position = Vector2(30.0, 70.0)
	add_child(_best)

	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	_build_title()
	_build_game_over()
	_overlay.visible = false


# ------------------------------------------------------------------ タイトル

func _build_title() -> void:
	_title_panel = Control.new()
	_title_panel.name = "TitlePanel"
	_title_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_title_panel)

	# 夜空を少し落としてロゴと立ち絵を目立たせる。
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.02, 0.08, 0.45)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_panel.add_child(veil)

	_logo = TextureRect.new()
	_logo.name = "Logo"
	_logo.texture = _load_texture(LOGO_PATH)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.position = Vector2(40.0, 60.0)
	_logo.size = Vector2(460.0, 236.0)
	_title_panel.add_child(_logo)

	if _logo.texture == null:
		# ロゴ画像が無いときは文字で代替する。
		var fallback := _make_label(46, Color(1.0, 0.91, 0.99))
		fallback.text = "WITCH EVASION"
		fallback.position = Vector2(0.0, 150.0)
		fallback.size = Vector2(540.0, 60.0)
		fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_panel.add_child(fallback)

	_card = TextureRect.new()
	_card.name = "Card"
	_card.texture = _load_texture(CARD_PATH)
	_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = CARD_POS
	_card.size = CARD_SIZE
	_title_panel.add_child(_card)

	_best_chip = _make_label(18, Color(1.0, 0.82, 0.95, 0.85))
	_best_chip.name = "BestChip"
	_best_chip.position = Vector2(0.0, 304.0)
	_best_chip.size = Vector2(540.0, 24.0)
	_best_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_panel.add_child(_best_chip)

	_prompt = _make_label(28, Color(1.0, 0.95, 1.0))
	_prompt.name = "Prompt"
	_prompt.position = Vector2(0.0, 846.0)
	_prompt.size = Vector2(540.0, 36.0)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.text = "SPACE / TAP TO START"
	_title_panel.add_child(_prompt)

	_keys = _make_label(16, Color(0.93, 0.88, 1.0, 0.72))
	_keys.name = "Keys"
	_keys.position = Vector2(0.0, 886.0)
	_keys.size = Vector2(540.0, 24.0)
	_keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_keys.text = "WASD / ARROWS  to fly"
	_title_panel.add_child(_keys)


# --------------------------------------------------------------- ゲームオーバー

func _build_game_over() -> void:
	_over_panel = Control.new()
	_over_panel.name = "OverPanel"
	_over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_over_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_over_panel)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_over_panel.add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	_over_title = _make_label(56, Color(1.0, 0.91, 0.97))
	_over_line1 = _make_label(24, Color(1.0, 0.74, 0.91, 0.95))
	_over_line2 = _make_label(24, Color(1.0, 0.74, 0.91, 0.95))
	_over_hint = _make_label(20, Color(0.95, 0.9, 1.0, 0.72))

	for l in [_over_title, _over_line1, _over_line2, _over_hint]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(l)


# ------------------------------------------------------------------- 表示制御

func _make_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.07, 0.02, 0.10, 0.9))
	l.add_theme_constant_override("outline_size", maxi(4, int(size / 6.0)))
	return l


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func setup(best: int) -> void:
	_best_value = best
	set_score(0)


func set_score(v: int) -> void:
	_score.text = str(v)


func _show_title(visible_now: bool) -> void:
	_title_panel.visible = visible_now
	_over_panel.visible = not visible_now
	# どちらのオーバーレイでも左上のスコアは隠す（重複表示を避ける）。
	_score.visible = false
	_best.visible = false


func show_ready(best: int) -> void:
	_best_value = best
	_show_title(true)
	_overlay.visible = true
	_best_chip.text = "BEST  %d" % best


func show_game_over(score: int, best: int, is_best: bool) -> void:
	_best_value = best
	_show_title(false)
	_overlay.visible = true
	_over_title.text = "GAME OVER"
	_over_line1.text = "SCORE  %d" % score
	_over_line2.text = ("NEW BEST  %d" if is_best else "BEST  %d") % best
	_over_hint.text = "SPACE to retry"


func hide_overlay() -> void:
	_overlay.visible = false
	_score.visible = true
	_best.visible = true
	_best.text = "BEST  %d" % _best_value


func _process(delta: float) -> void:
	if not _title_panel.visible:
		return
	_t += delta
	_card.position.y = CARD_POS.y + sin(_t * 1.1) * 5.0
	_prompt.modulate.a = 0.55 + 0.45 * sin(_t * 2.6)
