class_name Rex
extends CharacterBody2D
## Rex Halloway, contestant. Origin is at his feet.
## Movement: momentum run-up, variable jump, coyote time and jump buffering.

signal died

# Tuning (pixels, seconds). The test room is the place to tweak these.
const RUN_SPEED := 112.0
const ACCEL := 640.0
const AIR_ACCEL := 500.0
const TURN_BOOST := 1.8
const DECEL := 950.0
const AIR_DECEL := 280.0
const JUMP_VELOCITY := -318.0
const STOMP_BOUNCE := -220.0
const GRAVITY_UP := 920.0
const GRAVITY_DOWN := 1350.0
const JUMP_CUT := 0.45
const MAX_FALL := 330.0
const COYOTE := 0.1
const JUMP_BUFFER := 0.12
const SHOT_COOLDOWN := 0.2
const INVULN := 1.3
const PLATFORM_LAYER := 16  # one-way grates (physics layer 5)

const QUIPS := {
	"kill": ["Cut to commercial!", "That's a wrap.", "Cancelled.", "You've been renewed... NOT.", "Ratings, baby!",
		"And scene.", "Should've read the script."],
	"stomp": ["Sole proprietor!", "Step on it!", "Floor seats!", "Mind the boots."],
	"pickup": ["Product placement!", "Don't mind if I do.", "Hydration is self-care.", "Expensed."],
	"near_death": ["I've had worse reviews.", "Just a flesh wound. Mostly.", "Is my good side bleeding?",
		"Somebody call my agent."],
	"key": ["Access granted. Obviously.", "Keycard? I AM the key."],
	"secret": ["Hidden talent!", "Nobody reads the fine print."],
	"start": ["Hold my headshot.", "Let's make some television.", "Mattress money never felt this good."],
}

enum State { IDLE, RUN, JUMP, FALL, HURT, DEAD }

var state := State.IDLE
var facing := 1
var controls_locked := false
var stomp_chain := 0

var _coyote := 0.0
var _buffer := 0.0
var _shot_cd := 0.0
var _invuln := 0.0
var _hurt := 0.0
var _knock := 0.0
var _drop_t := 0.0
var _was_pushing_wall := false
var _quip_cd := 0.0
var _last_safe := Vector2.ZERO

var sprite: AnimatedSprite2D
var boom: Boom
var _bubble: Label
var _interact: Area2D
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | PLATFORM_LAYER
	floor_snap_length = 4.0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 27)
	_shape.shape = rect
	_shape.position = Vector2(0, -13.5)
	add_child(_shape)

	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("rex", Vector2i(16, 32), {
		"idle": [[0, 1], 2.0, true],
		"run": [[2, 3, 4, 5], 10.0, true],
		"jump": [[6], 1.0, false],
		"fall": [[7], 1.0, false],
		"hurt": [[8], 1.0, false],
	})
	sprite.position = Vector2(0, -16)
	sprite.play("idle")
	add_child(sprite)

	_interact = Area2D.new()
	_interact.collision_layer = 0
	_interact.collision_mask = 8
	var ishape := CollisionShape2D.new()
	var irect := RectangleShape2D.new()
	irect.size = Vector2(10, 24)
	ishape.shape = irect
	ishape.position = Vector2(0, -12)
	_interact.add_child(ishape)
	add_child(_interact)

	_bubble = Art.label("", Art.c("gold"))
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.size = Vector2(160, 9)
	_bubble.position = Vector2(-80, -46)
	_bubble.visible = false
	_bubble.z_index = 20
	add_child(_bubble)

	_last_safe = global_position


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		velocity.y = minf(velocity.y + GRAVITY_DOWN * 0.6 * delta, MAX_FALL)
		position += velocity * delta
		return

	_tick_timers(delta)
	var dir := 0.0
	if not controls_locked:
		dir = Input.get_axis("move_left", "move_right")

	# Horizontal movement with momentum.
	var on_floor := is_on_floor()
	var target := dir * RUN_SPEED
	var accel: float
	if _hurt > 0.0 or _knock > 0.0:
		accel = AIR_DECEL
		target = velocity.x
	elif dir != 0.0:
		accel = ACCEL if on_floor else AIR_ACCEL
		if velocity.x != 0.0 and signf(dir) != signf(velocity.x):
			accel *= TURN_BOOST
		facing = int(signf(dir))
	else:
		accel = DECEL if on_floor else AIR_DECEL
	velocity.x = move_toward(velocity.x, target, accel * delta)

	# Jumping: coyote time + buffer + variable height.
	if on_floor:
		_coyote = COYOTE
		if stomp_chain > 0:
			stomp_chain = 0
	if not controls_locked and Input.is_action_just_pressed("jump"):
		if Input.is_action_pressed("move_down") and on_floor and _on_platform():
			_drop_t = 0.25
			collision_mask = 1
		else:
			_buffer = JUMP_BUFFER
	if _buffer > 0.0 and _coyote > 0.0:
		_jump()
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	var gravity := GRAVITY_UP if velocity.y < 0.0 else GRAVITY_DOWN
	velocity.y = minf(velocity.y + gravity * delta, MAX_FALL)

	var rising := velocity.y < 0.0
	var falling := velocity.y > 0.0
	var prev_feet := global_position.y
	move_and_slide()
	_check_bonks(rising)
	_check_enemy_contacts(prev_feet, falling)

	# Walking into walls is a skill too (for the achievement, anyway).
	var pushing := is_on_wall() and is_on_floor() and dir != 0.0
	if pushing and not _was_pushing_wall:
		GameState.stat("wall_bumps")
	_was_pushing_wall = pushing

	if not controls_locked:
		if Input.is_action_pressed("shoot") and _shot_cd <= 0.0:
			_shoot()
		if Input.is_action_just_pressed("interact"):
			for a in _interact.get_overlapping_areas():
				if a.has_method("interact"):
					a.interact(self)
					break
		if Input.is_action_just_pressed("drone") and boom:
			boom.flash()

	if is_on_floor() and _hurt <= 0.0 and _on_solid_ground():
		_last_safe = global_position
	if GameState.level and global_position.y > GameState.level.kill_y:
		_fell_out()

	_update_animation()
	if _bubble.visible:
		_place_bubble()


func _tick_timers(delta: float) -> void:
	_coyote -= delta
	_buffer -= delta
	_shot_cd -= delta
	_hurt -= delta
	_knock -= delta
	_quip_cd -= delta
	if _drop_t > 0.0:
		_drop_t -= delta
		if _drop_t <= 0.0:
			collision_mask = 1 | PLATFORM_LAYER
	if _invuln > 0.0:
		_invuln -= delta
		sprite.visible = fmod(_invuln, 0.12) > 0.05 or _invuln <= 0.0


func _jump() -> void:
	velocity.y = JUMP_VELOCITY
	_buffer = 0.0
	_coyote = 0.0
	Sfx.play_varied("jump", 0.05, -4.0)
	GameState.stat("jumps")


func _check_bonks(was_rising: bool) -> void:
	if not was_rising:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_normal().y > 0.5:
			var other := col.get_collider()
			if other and other.has_method("bonk"):
				other.bonk(self)
				return


func _check_enemy_contacts(prev_feet: float, falling: bool) -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape.shape
	query.transform = _shape.global_transform
	query.collision_mask = 4
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 8):
		if hit.collider is Enemy:
			hit.collider.touch_rex(self, prev_feet, falling)
			if state == State.DEAD:
				return


func _shoot() -> void:
	_shot_cd = SHOT_COOLDOWN
	var offsets: Array = [[0], [-3, 3], [-5, 0, 5], [-6, -2, 2, 6]][GameState.firepower - 1]
	for off in offsets:
		var b := Bolt.new()
		b.direction = facing
		b.global_position = global_position + Vector2(facing * 11, -14 + off)
		GameState.level.add_child(b)
	Sfx.play_varied("shoot", 0.06, -5.0)
	GameState.stat("shots")


## Called by an enemy when Rex lands on it.
func stomp_bounce() -> void:
	velocity.y = JUMP_VELOCITY if Input.is_action_pressed("jump") else STOMP_BOUNCE
	_coyote = 0.0
	stomp_chain += 1
	Ratings.on_stomp_chain(stomp_chain)
	if stomp_chain >= 3:
		Showrunner.unlock("chain3")


## Shove Rex sideways; he can't steer against it for a moment.
func knock(vx: float, time := 0.35) -> void:
	velocity.x = vx
	_knock = time


func is_invulnerable() -> bool:
	return _invuln > 0.0 or state == State.DEAD


func hurt(amount: int, from_x: float) -> void:
	if is_invulnerable():
		return
	GameState.damage(amount)
	Ratings.on_damage()
	if GameState.health <= 0:
		die()
		return
	Sfx.play("hurt")
	_invuln = INVULN
	_hurt = 0.3
	var away := signf(global_position.x - from_x)
	if away == 0.0:
		away = -facing
	velocity = Vector2(away * 130.0, -170.0)
	if GameState.level:
		GameState.level.shake(3.0)
	if GameState.health <= 2:
		quip("near_death", true)


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	sprite.visible = true
	sprite.play("hurt")
	_shape.set_deferred("disabled", true)
	velocity = Vector2(0, -260)
	z_index = 30
	GameState.stats.deaths += 1
	Showrunner.unlock("first_death")
	Sfx.music("")
	Sfx.play("death")
	Ratings.stop()
	var lines := ["And that's our show! ...Kidding. Reset the set!",
		"Contestant down! Sponsors, please hold.",
		"Ooh, the focus groups LOVED that."]
	Showrunner.say(lines.pick_random(), "showrunner", true)
	get_tree().create_timer(2.4).timeout.connect(func(): died.emit())


func _fell_out() -> void:
	if is_invulnerable():
		global_position = _last_safe
		velocity = Vector2.ZERO
		return
	GameState.damage(2)
	Ratings.on_damage()
	if GameState.health <= 0:
		die()
		return
	Sfx.play("hurt")
	global_position = _last_safe
	velocity = Vector2.ZERO
	_invuln = INVULN
	Showrunner.say("Mind the gap! That one's coming out of your appearance fee.")


## Say something cocky. Kills soon after a quip score a QUIP KILL bonus.
func quip(kind: String, force := false) -> void:
	if state == State.DEAD or (_quip_cd > 0.0 and not force):
		return
	_quip_cd = 4.0
	_bubble.text = QUIPS[kind].pick_random()
	Narrator.bark(_bubble.text, "rex")
	_bubble.size.x = _bubble.text.length() * 6 + 2
	_bubble.visible = true
	_place_bubble()
	Ratings.on_quip()
	var t := create_tween()
	t.tween_interval(1.8)
	t.tween_callback(func(): _bubble.visible = false)


## Center the quip over Rex but keep it on screen.
func _place_bubble() -> void:
	var screen_x := get_global_transform_with_canvas().origin.x
	var w := _bubble.size.x
	_bubble.position.x = clampf(-w / 2.0, 2.0 - screen_x, 318.0 - screen_x - w)


func _on_platform() -> bool:
	var level = GameState.level
	return level != null and level.is_platform_below(global_position)


func _on_solid_ground() -> bool:
	var level = GameState.level
	return level == null or level.is_safe_ground(global_position)


func _update_animation() -> void:
	sprite.flip_h = facing < 0
	if _hurt > 0.0:
		sprite.play("hurt")
	elif not is_on_floor():
		sprite.play("jump" if velocity.y < 0.0 else "fall")
	elif absf(velocity.x) > 8.0:
		sprite.play("run")
		sprite.speed_scale = clampf(absf(velocity.x) / RUN_SPEED, 0.5, 1.2)
	else:
		sprite.play("idle")
		sprite.speed_scale = 1.0
