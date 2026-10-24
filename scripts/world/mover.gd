class_name Mover
extends AnimatableBody2D
## A moving platform two tiles wide. Rex can jump up through it and ride it.
## The level sets `from` and `to` (positions of the platform's top-center);
## it shuttles between them, pausing at each end. With `orbit` set it's a
## camera-crane platform instead, circling `from` at that radius.

const SPEED := 42.0
const PAUSE := 0.7

var orbit := 0.0
var from := Vector2.ZERO
var to := Vector2.ZERO
var _target := Vector2.ZERO
var _wait := 0.0
var _angle := 0.0


func _ready() -> void:
	collision_layer = 16  # the one-way platform layer (Rex can drop through)
	collision_mask = 0
	sync_to_physics = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(32, 6)
	shape.shape = rect
	shape.position = Vector2(0, 3)
	shape.one_way_collision = true
	add_child(shape)
	var s := Sprite2D.new()
	s.texture = Art.tex["lift"]
	s.position = Vector2(0, 4)
	add_child(s)
	position = from + (Vector2(orbit, 0) if orbit > 0.0 else Vector2.ZERO)
	_target = to
	_wait = PAUSE


func _physics_process(delta: float) -> void:
	if orbit > 0.0:
		_angle += SPEED / orbit * delta
		position = from + Vector2(cos(_angle), sin(_angle)) * orbit
		return
	if from == to:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	position = position.move_toward(_target, SPEED * delta)
	if position == _target:
		_target = from if _target == to else to
		_wait = PAUSE
