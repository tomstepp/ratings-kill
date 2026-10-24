class_name MicDrone
extends Enemy
## Floor 3 backlot: a boom-mic drone that hovers at its post, then swoops
## down at Rex in an arc and climbs back. Stomp or shoot it (2 hits).

const SWOOP_EVERY := 2.6
const SWOOP_TIME := 1.1
const RANGE := 150.0

var _home := Vector2.ZERO
var _t := 1.5
var _swoop := -1.0
var _target := Vector2.ZERO
var _from := Vector2.ZERO
var _bob := 0.0


func _build() -> void:
	hp = 2
	points = 250
	top_offset = 12.0
	collision_mask = 0  # flies
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 12)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("micdrone", Vector2i(16, 16), {"fly": [[0, 1], 12.0, true]})
	sprite.position = Vector2(0, -8)
	sprite.play("fly")
	add_child(sprite)


func _ready() -> void:
	super()
	position.y += 6.0  # center of the tile -> roughly feet
	_home = position
	_bob = randf() * TAU


func _behave(delta: float) -> void:
	if stunned > 0.0:
		return
	var rex: Rex = GameState.level.rex if GameState.level else null
	if _swoop >= 0.0:
		_swoop += delta / SWOOP_TIME
		var k := minf(_swoop, 1.0)
		# Out and back along a dip: down to the target at the midpoint, home at the end.
		var along := _from.lerp(Vector2(_target.x, _from.y), k)
		var dip := sin(k * PI) * (_target.y - _from.y)
		position = Vector2(along.x, _from.y + dip)
		if k >= 1.0:
			_swoop = -1.0
			_home = position
		return
	_bob += delta * 3.0
	position = position.move_toward(_home + Vector2(0, sin(_bob) * 3.0), 40.0 * delta)
	_t -= delta * (1.0 + 0.15 * GameState.difficulty())
	if rex and rex.state != Rex.State.DEAD and _t <= 0.0:
		var d := rex.global_position - position
		if absf(d.x) < RANGE and d.y > -20.0 and d.y < 120.0:
			_t = SWOOP_EVERY
			_swoop = 0.0
			_from = position
			# Overshoot past Rex so the far half of the arc carries on.
			_target = Vector2(rex.global_position.x + signf(d.x) * 50.0, rex.global_position.y - 6.0)
			sprite.flip_h = d.x > 0
			Sfx.play("blip", 0.5, -6.0)
