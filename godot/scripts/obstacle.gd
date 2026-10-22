extends Area2D
## 降ってくる障害物。岩 / 枯れ枝 / 鳥の群れ の 3 種をコードで生成する。

enum Kind { ROCK, BRANCH, BIRD }

const DARK := Color(0.12, 0.07, 0.19)
const EDGE := Color(0.58, 0.48, 0.84, 0.32)
const FACET := Color(0.26, 0.18, 0.38)

var kind: int = Kind.ROCK
var half_w := 40.0

var scroll := 260.0
var extra := 0.0
var drift := 0.0
var phase := 0.0

var _rng: RandomNumberGenerator
var _pts := PackedVector2Array()
var _facet := PackedVector2Array()
var _twigs: Array = []
var _birds: Array = []
var _spin := 0.0
var _radius := 30.0
var _length := 100.0
var _thick := 9.0


func setup(k: int, rng: RandomNumberGenerator, scroll_speed: float) -> void:
	kind = k
	_rng = rng
	scroll = scroll_speed
	collision_layer = 2
	collision_mask = 0
	add_to_group("obstacles")

	match kind:
		Kind.ROCK:
			_gen_rock()
		Kind.BRANCH:
			_gen_branch()
		Kind.BIRD:
			_gen_birds()

	_add_shape()


func _gen_rock() -> void:
	var r := _rng.randf_range(26.0, 50.0)
	half_w = r * 1.15
	_radius = r * 0.72
	var n := _rng.randi_range(7, 9)
	_pts = PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n) + _rng.randf_range(-0.16, 0.16)
		var rr := r * _rng.randf_range(0.78, 1.12)
		_pts.append(Vector2(cos(a), sin(a)) * rr)
	_facet = PackedVector2Array([_pts[0], _pts[1], _pts[2] * 0.72])

	_spin = _rng.randf_range(-0.55, 0.55)
	extra = _rng.randf_range(-10.0, 40.0)
	drift = _rng.randf_range(-30.0, 30.0)


func _gen_branch() -> void:
	_length = _rng.randf_range(80.0, 130.0)
	_thick = _rng.randf_range(7.0, 11.0)
	half_w = _length * 0.58

	_pts = PackedVector2Array([
		Vector2(-_length, -_thick),
		Vector2(_length * 0.9, -_thick * 0.7),
		Vector2(_length, _thick * 0.4),
		Vector2(-_length * 0.95, _thick),
	])

	_twigs.clear()
	for i in 3:
		var x := _rng.randf_range(-_length * 0.7, _length * 0.55)
		var base := Vector2(x, -_thick * 0.4)
		var tip := base + Vector2(_rng.randf_range(-16.0, 16.0), -_rng.randf_range(16.0, 32.0))
		_twigs.append([base, tip])

	extra = _rng.randf_range(0.0, 20.0)
	drift = _rng.randf_range(-10.0, 10.0)


func _gen_birds() -> void:
	_birds.clear()
	for i in _rng.randi_range(2, 3):
		_birds.append({
			"off": Vector2(_rng.randf_range(-26.0, 26.0), _rng.randf_range(-18.0, 18.0)),
			"ph": _rng.randf() * TAU,
		})
	half_w = 60.0
	extra = 90.0
	drift = _rng.randf_range(-24.0, 24.0)


func _add_shape() -> void:
	var cs := CollisionShape2D.new()
	match kind:
		Kind.ROCK:
			var s := CircleShape2D.new()
			s.radius = _radius
			cs.shape = s
		Kind.BRANCH:
			var s2 := CapsuleShape2D.new()
			s2.radius = _thick + 4.0
			s2.height = _length * 1.9
			cs.shape = s2
			cs.rotation = PI * 0.5
		Kind.BIRD:
			var s3 := CircleShape2D.new()
			s3.radius = 34.0
			cs.shape = s3
	add_child(cs)


func _process(delta: float) -> void:
	phase += delta
	if kind == Kind.ROCK:
		rotation += _spin * delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	position.y += (scroll + extra) * delta
	position.x += drift * delta
	if position.y > 1080.0 or position.x < -220.0 or position.x > 760.0:
		queue_free()


func _draw() -> void:
	match kind:
		Kind.ROCK:
			draw_colored_polygon(_pts, DARK)
			draw_colored_polygon(_facet, FACET)
			var closed := _pts.duplicate()
			closed.append(_pts[0])
			draw_polyline(closed, EDGE, 2.0, true)

		Kind.BRANCH:
			draw_colored_polygon(_pts, DARK)
			for tw in _twigs:
				draw_line(tw[0], tw[1], DARK, 3.0, true)
			var edge := PackedVector2Array([
				Vector2(-_length, -_thick), Vector2(_length * 0.9, -_thick * 0.7),
			])
			draw_polyline(edge, EDGE, 2.0, true)

		Kind.BIRD:
			for b in _birds:
				var off: Vector2 = b["off"]
				var flap := sin(phase * 9.0 + float(b["ph"]))
				var lift := flap * 5.0
				var line := PackedVector2Array([
					off + Vector2(-9.0, lift),
					off + Vector2(0.0, 2.0 - lift * 0.4),
					off + Vector2(9.0, lift),
				])
				draw_polyline(line, EDGE, 5.5, true)
				draw_polyline(line, DARK, 2.6, true)
