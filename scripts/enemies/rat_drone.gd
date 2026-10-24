class_name RatDrone
extends Enemy
## Floor 1 grunt: patrols, turns at walls and ledges, and lunges when Rex is
## close and level with it. Stomp or shoot it.

const GRAVITY := 900.0
const LUNGE_RANGE := 80.0
const LUNGE_BOOST := 2.2

var speed := 38.0
var fast := false  # the 'r' variant: quicker, tougher, angrier
var dir := -1
var _ledge: RayCast2D


func _build() -> void:
	hp = 3 if fast else 2
	points = 150 if fast else 100
	if fast:
		speed = 64.0
	speed *= 1.0 + 0.12 * GameState.difficulty()
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
	if fast:
		tint = Color(1.35, 0.8, 0.8)
		anim_speed = 1.6
		sprite.modulate = tint
		sprite.speed_scale = anim_speed
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
		var lunge := 1.0
		var rex: Rex = GameState.level.rex if GameState.level else null
		if rex and rex.state != Rex.State.DEAD:
			var d := rex.global_position - global_position
			if absf(d.x) < LUNGE_RANGE and absf(d.y) < 20.0 and is_on_floor():
				dir = int(signf(d.x)) if d.x != 0.0 else dir
				lunge = LUNGE_BOOST
		velocity.x = dir * speed * lunge
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
