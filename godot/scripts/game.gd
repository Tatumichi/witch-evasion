extends Node2D
## ゲーム全体の進行。READY → PLAYING → OVER の 3 状態。

const ObstacleScript := preload("res://scripts/obstacle.gd")
const PickupScript := preload("res://scripts/pickup.gd")
const RingScript := preload("res://scripts/ring.gd")

const GAME_W := 540.0
const GAME_H := 960.0
const START_POS := Vector2(270.0, 710.0)

const BASE_SPEED := 260.0
const MAX_SPEED := 660.0
const RAMP_SECONDS := 70.0

const SAVE_PATH := "user://witch_flight.cfg"

enum State { READY, PLAYING, OVER }

@onready var background = $Background
@onready var world = $World
@onready var player = $World/Player
@onready var hud = $HUD

var state: int = State.READY
var speed := 0.0
var elapsed := 0.0
var score := 0
var best := 0

var _score_f := 0.0
var _spawn_cd := 0.0
var _pickup_cd := 0.0
var _shake := 0.0
var _over_cd := 0.0
var _shown_score := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	best = _load_best()
	hud.setup(best)
	player.hit.connect(_on_hit)
	player.picked.connect(_on_picked)
	_enter_ready()

	# 検証・撮影用: `godot --path godot -- --start` でタイトルを飛ばす
	if "--start" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.2).timeout
		_start()


# ---------------------------------------------------------------- 状態遷移

func _enter_ready() -> void:
	state = State.READY
	speed = 190.0
	elapsed = 0.0
	_score_f = 0.0
	score = 0
	_shake = 0.0
	_over_cd = 0.0
	_clear_world()
	player.spawn_at(START_POS)
	hud.set_score(0)
	hud.show_ready(best)


func _start() -> void:
	_clear_world()
	player.spawn_at(START_POS)
	player.active = true

	state = State.PLAYING
	speed = BASE_SPEED
	elapsed = 0.0
	_score_f = 0.0
	score = 0
	_shown_score = -1
	_spawn_cd = 1.0
	_pickup_cd = 3.5
	_shake = 0.0
	hud.set_score(0)
	hud.hide_overlay()


func _on_hit() -> void:
	if state != State.PLAYING:
		return

	state = State.OVER
	_over_cd = 0.55
	_shake = 26.0
	player.die()
	_spawn_ring(player.global_position, Color(1.0, 0.35, 0.55), 70.0, 0.5)

	var is_best := score > best
	if is_best:
		best = score
		_save_best()
	hud.show_game_over(score, best, is_best)


func _on_picked(amount: int) -> void:
	if state != State.PLAYING:
		return
	_score_f += amount
	_spawn_ring(player.global_position, Color(1.0, 0.9, 0.55), 44.0, 0.3)


func _clear_world() -> void:
	for c in world.get_children():
		if c != player:
			c.queue_free()


# ---------------------------------------------------------------- 毎フレーム

func _process(delta: float) -> void:
	background.scroll_speed = speed

	if _shake > 0.0:
		_shake = maxf(_shake - delta * 70.0, 0.0)
		world.position = Vector2(
			_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)
		) * _shake
	else:
		world.position = Vector2.ZERO

	if score != _shown_score:
		_shown_score = score
		hud.set_score(score)

	if state == State.OVER:
		_over_cd = maxf(_over_cd - delta, 0.0)


func _physics_process(delta: float) -> void:
	match state:
		State.READY:
			speed = lerpf(speed, 190.0, 1.0 - exp(-2.0 * delta))

		State.PLAYING:
			elapsed += delta
			var d := clampf(elapsed / RAMP_SECONDS, 0.0, 1.0)
			speed = lerpf(BASE_SPEED, MAX_SPEED, ease(d, 1.6))
			_score_f += speed * delta * 0.10
			score = int(_score_f)

			_spawn_cd -= delta
			if _spawn_cd <= 0.0:
				_spawn_obstacle()
				_spawn_cd = lerpf(1.25, 0.40, d) * _rng.randf_range(0.82, 1.18)

			_pickup_cd -= delta
			if _pickup_cd <= 0.0:
				_spawn_pickup()
				_pickup_cd = _rng.randf_range(2.6, 4.6)

		State.OVER:
			speed = move_toward(speed, 0.0, 1100.0 * delta)


# ---------------------------------------------------------------- 生成

func _spawn_obstacle() -> void:
	var d := clampf(elapsed / RAMP_SECONDS, 0.0, 1.0)
	var roll := _rng.randf()
	var kind: int = ObstacleScript.Kind.ROCK
	if d > 0.15 and roll > 0.52:
		kind = ObstacleScript.Kind.BRANCH
	if d > 0.35 and roll > 0.80:
		kind = ObstacleScript.Kind.BIRD

	var o = ObstacleScript.new()
	o.setup(kind, _rng, speed)
	var margin: float = o.half_w + 16.0
	o.position = Vector2(_rng.randf_range(margin, GAME_W - margin), -140.0)
	world.add_child(o)


func _spawn_pickup() -> void:
	var p = PickupScript.new()
	p.setup(speed)
	p.position = Vector2(_rng.randf_range(60.0, GAME_W - 60.0), -60.0)
	world.add_child(p)


func _spawn_ring(pos: Vector2, c: Color, to_radius: float, dur: float) -> void:
	var r = RingScript.new()
	r.setup(pos, c, to_radius, dur)
	world.add_child(r)


# ---------------------------------------------------------------- 入力

func _unhandled_input(event: InputEvent) -> void:
	var advance := false
	if event is InputEventKey and event.pressed and not event.echo:
		advance = event.keycode == KEY_SPACE or event.keycode == KEY_ENTER
	elif event is InputEventMouseButton and event.pressed:
		advance = event.button_index == MOUSE_BUTTON_LEFT

	if not advance:
		return

	if state == State.READY:
		_start()
	elif state == State.OVER and _over_cd <= 0.0:
		_start()


# ---------------------------------------------------------------- 保存

func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return int(cfg.get_value("score", "best", 0))
	return 0


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.save(SAVE_PATH)
