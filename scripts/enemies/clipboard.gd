class_name Clipboard
extends Area2D
## The Floor Manager's thrown clipboard: flies out, slows, and comes back.
## Hurts Rex on the way out and back; Rex can shoot it down.

const SPEED := 190.0
const RETURN_ACCEL := 330.0

var velocity := Vector2.ZERO
var thrower: Node2D
var _life := 4.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 2 | 32
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 8)
	shape.shape = rect
	add_child(shape)
	var s := Sprite2D.new()
	s.texture = Art.tex["clipboard"]
	add_child(s)
	body_entered.connect(func(b):
		if b is Rex:
			b.hurt(1, global_position.x))
	area_entered.connect(func(a):
		if a is Bolt:
			a.queue_free()
			Ratings.add(3, "INTERCEPT")
			_pop())


func _physics_process(delta: float) -> void:
	_life -= delta
	rotation += delta * 14.0
	if is_instance_valid(thrower):
		var back := (thrower.global_position + Vector2(0, -24) - global_position)
		velocity += back.normalized() * RETURN_ACCEL * delta
		if _life < 3.2 and back.length() < 14.0:
			queue_free()
	position += velocity * delta
	if _life <= 0.0 or not is_instance_valid(thrower):
		_pop()


func _pop() -> void:
	if GameState.level:
		GameState.level.burst(global_position, Art.c("white"), 6, 50.0)
	queue_free.call_deferred()
