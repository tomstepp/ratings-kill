class_name Shockwave
extends Area2D
## A ground wave from the Mascot's landing. Runs along the floor; jump over it.

const SPEED := 150.0

var direction := 1
var _life := 3.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 9)
	shape.shape = rect
	shape.position = Vector2(0, -4.5)
	add_child(shape)
	var s := AnimatedSprite2D.new()
	s.sprite_frames = Art.frames("shockwave", Vector2i(16, 12), {"go": [[0, 1], 12.0, true]})
	s.position = Vector2(0, -6)
	s.flip_h = direction < 0
	s.play("go")
	add_child(s)


func _physics_process(delta: float) -> void:
	position.x += direction * SPEED * delta
	_life -= delta
	var level = GameState.level
	var ahead := Vector2i(floori((position.x + direction * 8) / 16.0), floori((position.y - 4) / 16.0))
	if _life <= 0.0 or (level and level.is_solid(ahead)):
		queue_free()
		return
	for b in get_overlapping_bodies():
		if b is Rex:
			b.hurt(1, position.x - direction)
