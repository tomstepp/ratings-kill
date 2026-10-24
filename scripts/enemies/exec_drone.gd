class_name ExecDrone
extends Enemy
## Floor 4 Network HQ security: a flying drone that keeps its distance from
## Rex and fires aimed bolts. Shoot it (3 hits) or stomp it.

const KEEP_X := 88.0
const LIFT := 34.0
const FIRE_EVERY := 2.2
const CHARGE := 0.5
const WAKE := 190.0

var _t := 1.4
var _side := 1.0


func _build() -> void:
	hp = 4
	points = 400
	top_offset = 12.0
	collision_mask = 1  # flies, but not through walls
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 12)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("execdrone", Vector2i(16, 16), {
		"fly": [[0, 1], 10.0, true],
		"charge": [[2, 0], 16.0, true],
	})
	sprite.position = Vector2(0, -8)
	sprite.play("fly")
	add_child(sprite)


func _ready() -> void:
	super()
	position.y += 6.0


func _behave(delta: float) -> void:
	velocity = Vector2.ZERO
	if stunned > 0.0:
		return
	var rex: Rex = GameState.level.rex if GameState.level else null
	if rex == null or rex.state == Rex.State.DEAD:
		return
	var d := rex.global_position - global_position
	if d.length() > WAKE:
		return
	_side = -signf(d.x) if d.x != 0.0 else _side
	var goal := rex.global_position + Vector2(_side * KEEP_X, -LIFT)
	velocity = (goal - global_position).limit_length(60.0 + 10.0 * GameState.difficulty())
	move_and_slide()
	sprite.flip_h = d.x > 0
	_t -= delta
	if _t <= CHARGE:
		sprite.play("charge")
	if _t <= 0.0:
		_t = FIRE_EVERY
		sprite.play("fly")
		var b := EnemyBolt.new()
		var aim := (rex.global_position + Vector2(0, -14) - global_position).normalized()
		b.direction = aim
		b.global_position = global_position + Vector2(0, -6) + aim * 8.0
		GameState.level.add_child(b)
		Sfx.play_varied("shoot", 0.05, -8.0)
