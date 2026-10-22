extends CanvasLayer
## ステージ用 HUD（仮グラフィック）。
##   左上 : 帽子（ライフ）/ 勇気のかけら（次の帽子までのメーター）/ 救った猫
##   右上 : スコア
##   右端 : 高度レール（村 → ボス）
##   上中央: ボスの満足ゲージ、神々の実況
##   下   : メルルたちのセリフ
##   全面 : タイトル / ステージ名カード / 目を回した / クリア結果

const FONT_PATH := "res://assets/fonts/MPLUSRounded1c-Bold.ttf"
const LOGO_PATH := "res://assets/ui/logo.png"
const CARD_PATH := "res://assets/ui/title_witch.png"
const Sfx := preload("res://scripts/stage/sfx.gd")

const TEXT := Color(1.0, 0.98, 0.96)
const OUTLINE := Color(0.14, 0.07, 0.18, 0.92)
const GOD_GOLD := Color(1.0, 0.88, 0.52)
const PANEL := Color(0.10, 0.06, 0.16, 0.78)

var _root: Control
var _hats: HatsView
var _courage_label: Label
var _courage_bar: MeterBar
var _cats_label: Label
var _score_label: Label
var _rail: ProgressRail

var _effect_box: Control
var _effect_label: Label
var _effect_bar: MeterBar

var _boss_box: Control
var _boss_bar: MeterBar

var _say_box: PanelContainer
var _say_name: Label
var _say_text: Label
var _say_left := 0.0

var _god_box: PanelContainer
var _god_text: Label
var _god_left := 0.0

var _card: Control
var _card_title: Label
var _card_sub: Label

var _title_panel: Control
var _title_card: TextureRect
var _title_prompt: Label
var _title_best: Label

var _faint_panel: Control
var _result_panel: Control
var _result_lines: Label
var _result_hint: Label

var _play_widgets: Array[Control] = []
var _t := 0.0


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		theme.default_font = load(FONT_PATH)
	theme.default_font_size = 20
	_root.theme = theme
	add_child(_root)

	_build_status()
	_build_dialogue()
	_build_overlays()


# ------------------------------------------------------------------ 組み立て

func _label(size: int, color := TEXT, outline := 5) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel_style(c: Color, radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	return sb


func _build_status() -> void:
	_hats = HatsView.new()
	_hats.name = "Hats"
	_hats.position = Vector2(14.0, 10.0)
	_hats.size = Vector2(130.0, 44.0)
	_root.add_child(_hats)

	var shard := ShardIcon.new()
	shard.position = Vector2(20.0, 62.0)
	shard.size = Vector2(16.0, 22.0)
	_root.add_child(shard)
	_courage_label = _label(20)
	_courage_label.name = "Courage"
	_courage_label.position = Vector2(42.0, 56.0)
	_root.add_child(_courage_label)
	_courage_bar = MeterBar.new()
	_courage_bar.position = Vector2(20.0, 88.0)
	_courage_bar.size = Vector2(110.0, 6.0)
	_courage_bar.fill = Color(0.62, 1.0, 0.86)
	_root.add_child(_courage_bar)

	_cats_label = _label(20)
	_cats_label.name = "Cats"
	_cats_label.position = Vector2(18.0, 98.0)
	_root.add_child(_cats_label)

	_score_label = _label(34)
	_score_label.name = "Score"
	_score_label.position = Vector2(260.0, 6.0)
	_score_label.size = Vector2(266.0, 44.0)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_score_label)

	_rail = ProgressRail.new()
	_rail.name = "Rail"
	_rail.position = Vector2(516.0, 150.0)
	_rail.size = Vector2(16.0, 640.0)
	_root.add_child(_rail)

	_effect_box = Control.new()
	_effect_box.position = Vector2(18.0, 134.0)
	_effect_box.size = Vector2(200.0, 40.0)
	_effect_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_effect_box)
	_effect_label = _label(16)
	_effect_box.add_child(_effect_label)
	_effect_bar = MeterBar.new()
	_effect_bar.position = Vector2(0.0, 26.0)
	_effect_bar.size = Vector2(150.0, 6.0)
	_effect_box.add_child(_effect_bar)
	_effect_box.visible = false

	_boss_box = Control.new()
	_boss_box.name = "BossGauge"
	_boss_box.position = Vector2(120.0, 58.0)
	_boss_box.size = Vector2(300.0, 50.0)
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_boss_box)
	var bl := _label(16, Color(1.0, 0.86, 0.92))
	bl.text = "大風見鶏の満足ゲージ"
	bl.size = Vector2(300.0, 22.0)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(bl)
	_boss_bar = MeterBar.new()
	_boss_bar.position = Vector2(0.0, 26.0)
	_boss_bar.size = Vector2(300.0, 12.0)
	_boss_bar.fill = Color(1.0, 0.56, 0.70)
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false

	_play_widgets = [_hats, shard, _courage_label, _courage_bar, _cats_label, _score_label, _rail]


func _build_dialogue() -> void:
	_say_box = PanelContainer.new()
	_say_box.name = "Say"
	_say_box.add_theme_stylebox_override("panel", _panel_style(PANEL))
	_say_box.position = Vector2(16.0, 846.0)
	_say_box.size = Vector2(508.0, 96.0)
	_say_box.custom_minimum_size = Vector2(508.0, 0.0)
	_say_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_say_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_say_box.add_child(v)
	_say_name = _label(15, Color(1.0, 0.78, 0.90), 0)
	v.add_child(_say_name)
	_say_text = _label(22, TEXT, 0)
	_say_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_say_text.custom_minimum_size = Vector2(478.0, 0.0)
	v.add_child(_say_text)
	_say_box.visible = false

	_god_box = PanelContainer.new()
	_god_box.name = "Gods"
	_god_box.add_theme_stylebox_override("panel", _panel_style(Color(0.30, 0.22, 0.08, 0.72), 22))
	_god_box.position = Vector2(60.0, 196.0)
	_god_box.custom_minimum_size = Vector2(420.0, 0.0)
	_god_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_god_box)
	_god_text = _label(20, GOD_GOLD, 0)
	_god_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_god_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_god_text.custom_minimum_size = Vector2(392.0, 0.0)
	_god_box.add_child(_god_text)
	_god_box.visible = false


func _build_overlays() -> void:
	# ステージ名カード
	_card = Control.new()
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_card)
	_card_title = _label(64, TEXT, 10)
	_card_title.position = Vector2(0.0, 330.0)
	_card_title.size = Vector2(540.0, 80.0)
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_title)
	_card_sub = _label(34, Color(1.0, 0.86, 0.72), 8)
	_card_sub.position = Vector2(0.0, 410.0)
	_card_sub.size = Vector2(540.0, 50.0)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_sub)
	_card.visible = false

	# タイトル
	_title_panel = _full_panel(Color(0.05, 0.03, 0.10, 0.40))
	_title_panel.name = "TitlePanel"
	var logo := TextureRect.new()
	logo.texture = _tex(LOGO_PATH)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(40.0, 40.0)
	logo.size = Vector2(460.0, 236.0)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_panel.add_child(logo)
	if logo.texture == null:
		var fb := _label(46)
		fb.text = "WITCH EVASION"
		fb.position = Vector2(0.0, 130.0)
		fb.size = Vector2(540.0, 60.0)
		fb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_panel.add_child(fb)
	var sub := _label(26, Color(1.0, 0.90, 0.80), 7)
	sub.text = "見習い魔女メルル　STAGE 1「村の空」"
	sub.position = Vector2(0.0, 282.0)
	sub.size = Vector2(540.0, 36.0)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_panel.add_child(sub)
	_title_card = TextureRect.new()
	_title_card.texture = _tex(CARD_PATH)
	_title_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_card.position = Vector2(90.0, 340.0)
	_title_card.size = Vector2(360.0, 430.0)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_panel.add_child(_title_card)
	_title_best = _label(18, Color(1.0, 0.86, 0.94))
	_title_best.position = Vector2(0.0, 774.0)
	_title_best.size = Vector2(540.0, 26.0)
	_title_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_panel.add_child(_title_best)
	_title_prompt = _label(28)
	_title_prompt.text = "SPACE / クリックでスタート"
	_title_prompt.position = Vector2(0.0, 816.0)
	_title_prompt.size = Vector2(540.0, 40.0)
	_title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_panel.add_child(_title_prompt)
	var keys := _label(17, Color(0.96, 0.92, 1.0, 0.85))
	keys.text = "WASD / 矢印キーで移動　　猫は受け止めてあげてね"
	keys.position = Vector2(0.0, 864.0)
	keys.size = Vector2(540.0, 26.0)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_panel.add_child(keys)

	# 目を回した
	_faint_panel = _full_panel(Color(0.08, 0.04, 0.14, 0.35))
	var ft := _label(44, TEXT, 9)
	ft.text = "目をまわした……"
	ft.position = Vector2(0.0, 380.0)
	ft.size = Vector2(540.0, 60.0)
	ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faint_panel.add_child(ft)
	var fh := _label(18, Color(1.0, 0.9, 0.96, 0.85))
	fh.text = "SPACE でもう一度"
	fh.position = Vector2(0.0, 450.0)
	fh.size = Vector2(540.0, 30.0)
	fh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_faint_panel.add_child(fh)

	# クリア結果
	_result_panel = _full_panel(Color(0.06, 0.04, 0.12, 0.62))
	_result_panel.name = "ResultPanel"
	var rt := _label(52, Color(1.0, 0.92, 0.70), 10)
	rt.text = "STAGE 1 CLEAR!"
	rt.position = Vector2(0.0, 250.0)
	rt.size = Vector2(540.0, 70.0)
	rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_panel.add_child(rt)
	_result_lines = _label(26, TEXT, 6)
	_result_lines.position = Vector2(0.0, 350.0)
	_result_lines.size = Vector2(540.0, 260.0)
	_result_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_panel.add_child(_result_lines)
	_result_hint = _label(20, Color(1.0, 0.9, 0.96, 0.85))
	_result_hint.text = "SPACE でタイトルへ"
	_result_hint.position = Vector2(0.0, 650.0)
	_result_hint.size = Vector2(540.0, 30.0)
	_result_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_panel.add_child(_result_hint)

	_title_panel.visible = false
	_faint_panel.visible = false
	_result_panel.visible = false


func _full_panel(veil: Color) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(c)
	var r := ColorRect.new()
	r.color = veil
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(r)
	return c


func _tex(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


# ------------------------------------------------------------------ 公開 API

func show_title(best: int) -> void:
	_set_play_visible(false)
	_title_panel.visible = true
	_faint_panel.visible = false
	_result_panel.visible = false
	_boss_box.visible = false
	_effect_box.visible = false
	_say_box.visible = false
	_god_box.visible = false
	_title_best.text = "BEST  %d" % best if best > 0 else ""


func show_play() -> void:
	_title_panel.visible = false
	_faint_panel.visible = false
	_result_panel.visible = false
	_set_play_visible(true)


func _set_play_visible(v: bool) -> void:
	for w in _play_widgets:
		w.visible = v


func show_stage_card(title: String, sub: String, seconds := 2.2) -> void:
	_card_title.text = title
	_card_sub.text = sub
	_card.visible = true
	_card.modulate.a = 0.0
	Sfx.fire(self, "stage_card")
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, 0.3)
	tw.tween_interval(maxf(seconds - 0.6, 0.1))
	tw.tween_property(_card, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): _card.visible = false)


func set_hats(n: int, max_n: int) -> void:
	_hats.count = n
	_hats.max_count = max_n
	_hats.queue_redraw()


func set_courage(total: int, per_hat: int) -> void:
	_courage_label.text = "× %d" % total
	_courage_bar.value = float(total % per_hat) / float(per_hat)


func set_cats(saved: int, total: int) -> void:
	_cats_label.text = "猫  %d / %d" % [saved, total]


func set_score(v: int) -> void:
	_score_label.text = str(v)


func set_progress(p: float, boss_phase: bool) -> void:
	_rail.value = clampf(p, 0.0, 1.0)
	_rail.boss = boss_phase


## 猫の効果表示。fur < 0 で隠す。
func set_cat_effect(fur: int, ratio: float) -> void:
	if fur < 0:
		_effect_box.visible = false
		return
	_effect_box.visible = true
	_effect_label.text = "茶トラ：キャンディ" if fur == 0 else "白猫：ふわふわバリア"
	_effect_bar.fill = Color(1.0, 0.70, 0.42) if fur == 0 else Color(0.92, 0.94, 1.0)
	_effect_bar.value = ratio


func show_boss_gauge(v: bool) -> void:
	_boss_box.visible = v


func set_boss_gauge(v: float) -> void:
	_boss_bar.value = v


func say(speaker: String, text: String, seconds := 2.6) -> void:
	_say_name.text = speaker
	_say_text.text = text
	_say_box.visible = true
	_say_left = seconds
	if speaker == "メルル":
		Sfx.fire(self, "talk_meruru", {"pitch_jitter": 0.04})


func god_say(text: String, seconds := 3.0) -> void:
	_god_text.text = "神々「%s」" % text
	_god_box.visible = true
	_god_left = seconds
	Sfx.fire(self, "talk_god")


func clear_talk() -> void:
	_say_box.visible = false
	_god_box.visible = false
	_say_left = 0.0
	_god_left = 0.0


func show_faint(v: bool) -> void:
	_faint_panel.visible = v


func show_result(lines: Array) -> void:
	_result_lines.text = "\n".join(PackedStringArray(lines))
	_result_panel.visible = true
	_boss_box.visible = false
	_effect_box.visible = false


func is_title_visible() -> bool:
	return _title_panel.visible


func is_result_visible() -> bool:
	return _result_panel.visible


func current_say() -> String:
	return _say_text.text if _say_box.visible else ""


func _process(delta: float) -> void:
	_t += delta
	if _say_left > 0.0:
		_say_left -= delta
		if _say_left <= 0.0:
			_say_box.visible = false
	if _god_left > 0.0:
		_god_left -= delta
		if _god_left <= 0.0:
			_god_box.visible = false
	if _title_panel.visible:
		_title_prompt.modulate.a = 0.55 + 0.45 * sin(_t * 2.6)
		_title_card.position.y = 340.0 + sin(_t * 1.1) * 5.0


# ------------------------------------------------------------------ 描画部品（仮）

class HatsView extends Control:
	var count := 3
	var max_count := 3

	func _draw() -> void:
		for i in max_count:
			var o := Vector2(18.0 + i * 40.0, 30.0)
			var have := i < count
			var a := 1.0 if have else 0.25
			var brim := Color(0.28, 0.18, 0.44, a)
			var cone := Color(0.46, 0.32, 0.68, a)
			draw_colored_polygon(PackedVector2Array([o + Vector2(-17.0, 4.0), o + Vector2(17.0, 4.0), o + Vector2(12.0, 9.0), o + Vector2(-12.0, 9.0)]), brim)
			draw_colored_polygon(PackedVector2Array([o + Vector2(-10.0, 4.0), o + Vector2(9.0, 4.0), o + Vector2(-3.0, -24.0)]), cone)
			if have:
				draw_rect(Rect2(o + Vector2(-9.0, -1.0), Vector2(17.0, 4.0)), Color(0.55, 0.92, 0.80))


class ShardIcon extends Control:
	func _draw() -> void:
		var c := Vector2(8.0, 11.0)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -11.0), c + Vector2(7.0, 0.0), c + Vector2(0.0, 11.0), c + Vector2(-7.0, 0.0)]), Color(1.0, 0.96, 0.72))


class MeterBar extends Control:
	var value := 0.0:
		set(v):
			value = clampf(v, 0.0, 1.0)
			queue_redraw()
	var fill := Color(1.0, 0.8, 0.5)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.06, 0.16, 0.7))
		draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * value, size.y)), fill)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.5), false, 1.0)


class ProgressRail extends Control:
	var value := 0.0:
		set(v):
			value = v
			queue_redraw()
	var boss := false

	func _draw() -> void:
		var x := size.x * 0.5
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(1.0, 1.0, 1.0, 0.35), 3.0)
		# 下は村、上はボス
		draw_rect(Rect2(x - 6.0, size.y - 6.0, 12.0, 8.0), Color(0.86, 0.36, 0.30, 0.9))
		draw_circle(Vector2(x, 0.0), 7.0, Color(1.0, 0.56, 0.70) if boss else Color(1.0, 1.0, 1.0, 0.5))
		var y := size.y * (1.0 - value)
		draw_circle(Vector2(x, y), 7.0, Color(0.70, 0.56, 0.96))
		draw_circle(Vector2(x, y), 3.0, Color.WHITE)
