extends Area2D
## 煙突の煙（仮グラフィック）。当たり判定はなく、中にいるあいだメルルが咳き込んで遅くなる。
## 縦長の帯ごとワールドと一緒に下へ流れ、帯の中では煙の粒が上へ昇っていく。

const W := 84.0
const H := 320.0
const PUFF := Color(0.55, 0.55, 0.60)

var fall := 230.0
var _t := 0.0
var _puffs: Array = []


func setup(x: float, fall_speed: float, rng: RandomNumberGenerator) -> void:
	position = Vector2(x, -H * 0.5 - 10.0)
	fall = fall_speed
	collision_layer = 4
	collision_mask = 0
	add_to_group("smoke")
	var s := RectangleShape2D.new()
	s.size = Vector2(W * 0.8, H)
	var cs := CollisionShape2D.new()
	cs.shape = s
	add_child(cs)
	for i in 16:
		_puffs.append({
			"y": rng.randf_range(-H * 0.5, H * 0.5),
			"x": rng.randf_range(-W * 0.3, W * 0.3),
			"r": rng.randf_range(16.0, 30.0),
			"ph": rng.randf() * TAU,
		})


func _physics_process(delta: float) -> void:
	_t += delta
	position.y += fall * delta
	for p in _puffs:
		p["y"] = float(p["y"]) - 46.0 * delta
		if float(p["y"]) < -H * 0.5:
			p["y"] = H * 0.5
	if position.y - H * 0.5 > 980.0:
		queue_free()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for p in _puffs:
		var y := float(p["y"])
		# 帯の上下の端は薄くして境目を消す
		var edge := 1.0 - absf(y) / (H * 0.5)
		var a := 0.30 * clampf(edge * 2.5, 0.0, 1.0)
		var x := float(p["x"]) + sin(_t * 1.3 + float(p["ph"])) * 8.0
		draw_circle(Vector2(x, y), float(p["r"]), Color(PUFF.r, PUFF.g, PUFF.b, a))
