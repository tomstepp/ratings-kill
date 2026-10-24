class_name SparkBot
extends Enemy
## Stationary turret with an electrified top (don't stomp it unless stunned).
## Charges up, then fires a slow bolt along the floor toward Rex.

const RANGE_X := 150.0
const RANGE_Y := 40.0
const FIRE_EVERY := 2.4
const CHARGE_TIME := 0.5

var _t := 1.2


func _build() -> void:
	hp = 3
	points = 250
	stompable = false
	top_offset = 11.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 14)
	shape.shape = rect
	shape.position = Vector2(0, -7)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("spark", Vector2i(16, 16), {
		"idle": [[0, 1], 6.0, true],
		"charge": [[2, 0], 16.0, true],
	})
	sprite.position = Vector2(0, -8)
	sprite.play("idle")
	add_child(sprite)


func _behave(delta: float) -> void:
	if stunned > 0.0:
		return
	var rex: Rex = GameState.level.rex if GameState.level else null
	if rex == null or rex.state == Rex.State.DEAD:
		return
	var d := rex.global_position - global_position
	if absf(d.x) > RANGE_X or absf(d.y) > RANGE_Y:
		sprite.play("idle")
		_t = maxf(_t, CHARGE_TIME + 0.3)
		return
	_t -= delta
	if _t <= CHARGE_TIME:
		sprite.play("charge")
	if _t <= 0.0:
		_t = FIRE_EVERY
		sprite.play("idle")
		var b := EnemyBolt.new()
		b.direction = Vector2(signf(d.x), 0.0)
		b.global_position = global_position + Vector2(signf(d.x) * 9.0, -8.0)
		GameState.level.add_child(b)
		Sfx.play_varied("shoot", 0.05, -8.0)
