class_name Mascot
extends Boss
## Floor 1 boss: Mister Cheddar, the network's beloved foam rat mascot.
## Pattern: charge across the arena (dizzy after hitting a wall), jump at Rex
## and land with floor shockwaves, and below half health, lob confetti bombs
## and call in rat fans. Shoot him anywhere; stomp his head for big damage.

const GRAVITY := 900.0
const WALK_SPEED := 40.0
const CHARGE_SPEED := 165.0
const STOMP_DAMAGE := 4

enum Mode { INTRO, IDLE, WALK, WINDUP, CHARGE, DIZZY, CROUCH, JUMP, THROW, DYING }

var mode := Mode.INTRO
var facing := -1
var _t := 1.0
var _next_moves: Array = []
var _stomp_cd := 0.0
var _throws_left := 0


func _build() -> void:
	display_name = "MISTER CHEDDAR, THE MASCOT"
	max_hp = 60
	hp = max_hp
	points = 5000
	collision_mask = 1  # too heavy for grates
	top_offset = 44.0
	contact_damage = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 40)
	shape.shape = rect
	shape.position = Vector2(0, -20)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("mascot", Vector2i(48, 48), {
		"idle": [[0, 1], 3.0, true],
		"walk": [[2, 3], 6.0, true],
		"charge": [[2, 3], 14.0, true],
		"crouch": [[4], 1.0, false],
		"jump": [[5], 1.0, false],
		"hurt": [[6], 1.0, false],
		"throw": [[7], 1.0, false],
	})
	sprite.position = Vector2(0, -24)
	sprite.play("idle")
	add_child(sprite)


func _behave(delta: float) -> void:
	_stomp_cd -= delta
	velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
	if stunned > 0.0:
		velocity.x = 0.0
		move_and_slide()
		return
	_t -= delta
	match mode:
		Mode.INTRO:
			velocity.x = 0.0
			sprite.play("idle")
			_face_rex()
			if _intro_over(delta):
				_set_mode(Mode.IDLE, 0.6)
		Mode.IDLE:
			velocity.x = 0.0
			sprite.play("idle")
			_face_rex()
			if _t <= 0.0:
				_pick_move()
		Mode.WALK:
			velocity.x = facing * WALK_SPEED
			sprite.play("walk")
			if _t <= 0.0 or is_on_wall():
				_set_mode(Mode.IDLE, 0.3)
		Mode.WINDUP:
			velocity.x = 0.0
			sprite.play("crouch")
			sprite.position.x = sin(_t * 60.0) * 1.5
			if _t <= 0.0:
				sprite.position.x = 0.0
				Sfx.play("roar")
				_set_mode(Mode.CHARGE, 4.0)
		Mode.CHARGE:
			velocity.x = facing * CHARGE_SPEED * (1.2 if enraged else 1.0)
			sprite.play("charge")
			if is_on_wall() or _t <= 0.0:
				GameState.level.shake(5.0)
				Sfx.play("explode", 0.7)
				velocity.x = 0.0
				_set_mode(Mode.DIZZY, 1.4)
		Mode.DIZZY:
			velocity.x = 0.0
			sprite.play("hurt")
			if _t <= 0.0:
				_set_mode(Mode.IDLE, 0.4)
		Mode.CROUCH:
			velocity.x = 0.0
			sprite.play("crouch")
			if _t <= 0.0:
				_jump_at_rex()
		Mode.JUMP:
			sprite.play("jump")
			if is_on_floor() and velocity.y >= 0.0 and _t <= 0.0:
				_land()
		Mode.THROW:
			velocity.x = 0.0
			sprite.play("throw")
			if _t <= 0.0:
				if _throws_left > 0:
					_throw_bomb()
					_throws_left -= 1
					_t = 0.45
				else:
					_set_mode(Mode.IDLE, 0.6)
		Mode.DYING:
			velocity.x = 0.0
	sprite.flip_h = facing > 0
	move_and_slide()


func _set_mode(m: Mode, time: float) -> void:
	mode = m
	_t = time


func _face_rex() -> void:
	var rex: Rex = GameState.level.rex
	if rex:
		facing = 1 if rex.global_position.x > global_position.x else -1


## Moves come from a shuffled bag so the pattern is learnable but not rote.
func _pick_move() -> void:
	if _next_moves.is_empty():
		_next_moves = ["charge", "jump", "jump", "walk"]
		if enraged:
			_next_moves += ["throw", "throw", "charge"]
		_next_moves.shuffle()
	_face_rex()
	match _next_moves.pop_back():
		"charge":
			_set_mode(Mode.WINDUP, 0.7 if not enraged else 0.5)
		"jump":
			_set_mode(Mode.CROUCH, 0.45)
		"walk":
			_set_mode(Mode.WALK, 1.2)
		"throw":
			_throws_left = 3
			_set_mode(Mode.THROW, 0.4)


func _jump_at_rex() -> void:
	var rex: Rex = GameState.level.rex
	var dx := (rex.global_position.x - global_position.x) if rex else 0.0
	velocity = Vector2(clampf(dx * 1.1, -170.0, 170.0), -380.0)
	Sfx.play("jump", 0.5)
	_set_mode(Mode.JUMP, 0.2)


func _land() -> void:
	GameState.level.shake(6.0)
	Sfx.play("explode", 0.6)
	velocity.x = 0.0
	for dir in [-1, 1]:
		var w := Shockwave.new()
		w.direction = dir
		w.global_position = global_position + Vector2(dir * 16, 0)
		GameState.level.add_child(w)
	if enraged and randf() < 0.35:
		_call_fans()
	_set_mode(Mode.IDLE, 0.7 if not enraged else 0.45)


func _throw_bomb() -> void:
	var rex: Rex = GameState.level.rex
	if rex == null:
		return
	var b := ConfettiBomb.new()
	b.global_position = global_position + Vector2(facing * 14, -40)
	# Aim to land near Rex in ~0.9s, with some spread.
	var flight := 0.9
	var target := rex.global_position + Vector2(randf_range(-24, 24), 0)
	b.velocity = Vector2((target.x - b.global_position.x) / flight,
		(target.y - b.global_position.y - 0.5 * ConfettiBomb.GRAVITY * flight * flight) / flight)
	GameState.level.add_child(b)
	Sfx.play("shoot", 0.6)


func _call_fans() -> void:
	Showrunner.say("Cheddar's fan club has arrived! Please don't feed them.", "showrunner", true)
	for dx in [-60.0, 60.0]:
		var p: Vector2 = GameState.level.ceiling_above(global_position + Vector2(dx, -20), 6) + Vector2(0, 8)
		var rat := RatDrone.new()
		rat.position = p
		GameState.level.add_child(rat)


# ------------------------------------------------------------------ damage

func touch_rex(rex: Rex, prev_feet: float, falling: bool) -> void:
	if dead or mode == Mode.DYING or rex.state == Rex.State.DEAD:
		return
	var top := global_position.y - top_offset
	if falling and prev_feet <= top + 8.0:
		rex.stomp_bounce()
		# He shrugs Rex off so you can't just pogo on his head.
		var away := signf(rex.global_position.x - global_position.x)
		rex.knock((away if away != 0.0 else -facing) * 170.0)
		if _stomp_cd <= 0.0:
			_stomp_cd = 1.2
			Sfx.play("stomp", 0.7)
			Ratings.add(8, "HEADLINER")
			shot(STOMP_DAMAGE, rex)
	elif stunned <= 0.0 and mode != Mode.DIZZY:
		rex.hurt(contact_damage, global_position.x)


func _on_enrage() -> void:
	_next_moves.clear()
	Showrunner.say("Uh oh, Cheddar's getting cranky! Legal says that's YOUR problem.", "showrunner", true)


func _die() -> void:
	mode = Mode.DYING
	sprite.play("hurt")
	_finale("NOOO! Not Cheddar! Do you know what his plush toys cost us?!", 40.0)
