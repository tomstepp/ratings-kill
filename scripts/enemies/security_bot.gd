class_name SecurityBot
extends Enemy
## Floor 2 mall cop: patrols, and when Rex steps into its flashlight it stops,
## takes aim and fires a two-shot burst. Stomp it or shoot it (3 hits).

const GRAVITY := 900.0
const SIGHT_X := 135.0
const SIGHT_Y := 26.0
const AIM_TIME := 0.45
const COOLDOWN := 1.6

var speed := 30.0
var dir := -1
var _aim := 0.0
var _cd := 0.8
var _ledge: RayCast2D
var _beam: Polygon2D


func _build() -> void:
	hp = 4
	points = 300
	top_offset = 22.0
	speed *= 1.0 + 0.1 * GameState.difficulty()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 22)
	shape.shape = rect
	shape.position = Vector2(0, -11)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("guard", Vector2i(16, 24), {
		"walk": [[0, 1], 5.0, true],
		"aim": [[2], 1.0, false],
	})
	sprite.position = Vector2(0, -12)
	sprite.play("walk")
	add_child(sprite)
	# The flashlight cone shows where it can see.
	_beam = Polygon2D.new()
	_beam.color = Color(Art.c("gold"), 0.13)
	_beam.polygon = PackedVector2Array([Vector2(6, -16), Vector2(SIGHT_X, -26), Vector2(SIGHT_X, -2)])
	_beam.z_index = -1
	add_child(_beam)
	_ledge = RayCast2D.new()
	_ledge.collision_mask = 1 | 16
	_ledge.target_position = Vector2(0, 10)
	add_child(_ledge)


func _behave(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 300.0)
	_cd -= delta
	var rex: Rex = GameState.level.rex if GameState.level else null
	var sees := false
	if rex and rex.state != Rex.State.DEAD and stunned <= 0.0:
		var d := rex.global_position - global_position
		sees = signf(d.x) == dir and absf(d.x) < SIGHT_X and absf(d.y) < SIGHT_Y
	if stunned > 0.0:
		velocity.x = 0.0
		_aim = 0.0
	elif _aim > 0.0:
		velocity.x = 0.0
		_aim -= delta
		if _aim <= 0.0:
			_fire()
	elif sees and _cd <= 0.0:
		_aim = AIM_TIME
		sprite.play("aim")
		Sfx.play("blip", 0.6, -6.0)
	else:
		velocity.x = dir * speed
		sprite.play("walk")
	_ledge.position = Vector2(dir * 8, -2)
	move_and_slide()
	if stunned <= 0.0 and _aim <= 0.0 and is_on_floor():
		if is_on_wall() or not _ledge.is_colliding():
			dir = -dir
	sprite.flip_h = dir > 0
	_beam.scale.x = dir
	_beam.color.a = 0.28 if _aim > 0.0 else 0.13


func _fire() -> void:
	_cd = COOLDOWN * (1.0 - 0.12 * GameState.difficulty())
	for i in 2:
		get_tree().create_timer(i * 0.18).timeout.connect(func():
			if dead or not GameState.level:
				return
			var b := EnemyBolt.new()
			b.direction = Vector2(dir, 0)
			b.global_position = global_position + Vector2(dir * 9.0, -15.0)
			GameState.level.add_child(b)
			Sfx.play_varied("shoot", 0.05, -8.0))
