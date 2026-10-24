class_name Mannequin
extends Enemy
## Floor 2: a display mannequin that only moves while Rex isn't looking at it.
## Turn your back and it rushes you; face it and it freezes mid-step.

const GRAVITY := 900.0
const WAKE_RANGE := 210.0

var speed := 72.0


func _build() -> void:
	hp = 5
	points = 350
	top_offset = 30.0
	contact_damage = 2
	speed *= 1.0 + 0.1 * GameState.difficulty()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 28)
	shape.shape = rect
	shape.position = Vector2(0, -14)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("mannequin", Vector2i(16, 32), {
		"pose": [[0], 1.0, false],
		"walk": [[1, 2], 9.0, true],
	})
	sprite.position = Vector2(0, -16)
	sprite.play("pose")
	add_child(sprite)


## Rex is looking at us if he faces our way.
func _watched(rex: Rex) -> bool:
	return signf(global_position.x - rex.global_position.x) == float(rex.facing)


func _behave(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 300.0)
	velocity.x = 0.0
	var rex: Rex = GameState.level.rex if GameState.level else null
	if rex and rex.state != Rex.State.DEAD and stunned <= 0.0:
		var d := rex.global_position - global_position
		if absf(d.x) < WAKE_RANGE and absf(d.y) < 64.0 and not _watched(rex):
			velocity.x = signf(d.x) * speed
			sprite.flip_h = d.x > 0
	if velocity.x != 0.0:
		sprite.play("walk")
	elif sprite.animation == "walk":
		sprite.play("pose")
		Sfx.play_varied("bonk", 0.1, -12.0)
	move_and_slide()
