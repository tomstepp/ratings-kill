class_name RatDrone
extends Enemy
## Floor 1 grunt: patrols, turns at walls and ledges. Stomp or shoot it.

const SPEED := 38.0
const GRAVITY := 900.0

var dir := -1
var _ledge: RayCast2D


func _build() -> void:
	hp = 1
	points = 100
	top_offset = 9.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Taller than the sprite so hip-height blaster shots connect.
	rect.size = Vector2(12, 14)
	shape.shape = rect
	shape.position = Vector2(0, -7)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("rat", Vector2i(16, 14), {
		"walk": [[0, 1], 8.0, true],
		"flat": [[2], 1.0, false],
	})
	sprite.position = Vector2(0, -5)
	sprite.play("walk")
	add_child(sprite)
	_ledge = RayCast2D.new()
	_ledge.collision_mask = 1 | 16
	_ledge.target_position = Vector2(0, 10)
	add_child(_ledge)


func _behave(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 300.0)
	if stunned > 0.0:
		velocity.x = 0.0
	else:
		velocity.x = dir * SPEED
	_ledge.position = Vector2(dir * 8, -2)
	move_and_slide()
	if stunned <= 0.0 and is_on_floor():
		if is_on_wall() or not _ledge.is_colliding():
			dir = -dir
	sprite.flip_h = dir > 0


func _die_visual(how: String) -> void:
	if how == "stomp":
		sprite.play("flat")
		sprite.modulate = Color.WHITE
		_stars.visible = false
		var t := create_tween()
		t.tween_interval(0.35)
		t.tween_property(sprite, "modulate:a", 0.0, 0.2)
		t.tween_callback(queue_free)
	else:
		super(how)
