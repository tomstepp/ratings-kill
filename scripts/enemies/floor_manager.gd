class_name FloorManager
extends Boss
## Floor 2 boss: the mall's Floor Manager on a motorized cart. He dashes the
## length of the atrium (and stalls when he hits a wall), bellows through a
## megaphone to send waves along the floor, and throws clipboards that come
## back. Below half health he calls in security and a mannequin.

const GRAVITY := 900.0
const DRIVE_SPEED := 175.0

enum Mode { INTRO, IDLE, REV, DRIVE, STALL, SHOUT, THROW, CALL, DYING }

var mode := Mode.INTRO
var facing := -1
var _t := 0.0
var _bag: Array = []
var _count := 0


func _build() -> void:
	display_name = "THE FLOOR MANAGER"
	max_hp = 70
	hp = max_hp
	points = 7000
	collision_mask = 1
	top_offset = 38.0
	contact_damage = 2
	stomp_damage = 3
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 36)
	shape.shape = rect
	shape.position = Vector2(0, -18)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("manager", Vector2i(40, 40), {
		"idle": [[0, 1], 3.0, true],
		"drive": [[2, 3], 14.0, true],
		"shout": [[4], 1.0, false],
		"throw": [[5], 1.0, false],
		"hurt": [[6], 1.0, false],
	})
	sprite.position = Vector2(0, -20)
	sprite.play("idle")
	add_child(sprite)


func _behave(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 400.0)
	if stunned > 0.0:
		velocity.x = 0.0
		move_and_slide()
		return
	_t -= delta
	match mode:
		Mode.INTRO:
			velocity.x = 0.0
			_face_rex()
			if _intro_over(delta):
				_go(Mode.IDLE, 0.8)
		Mode.IDLE:
			velocity.x = 0.0
			sprite.play("idle")
			_face_rex()
			if _t <= 0.0:
				_pick()
		Mode.REV:
			velocity.x = 0.0
			sprite.play("drive")
			sprite.position.x = sin(_t * 70.0) * 1.5
			if _t <= 0.0:
				sprite.position.x = 0.0
				Sfx.play("roar", 1.4)
				_go(Mode.DRIVE, 4.0)
		Mode.DRIVE:
			velocity.x = facing * DRIVE_SPEED * (1.2 if enraged else 1.0)
			sprite.play("drive")
			if is_on_wall() or _t <= 0.0:
				GameState.level.shake(5.0)
				Sfx.play("explode", 0.8)
				velocity.x = 0.0
				_go(Mode.STALL, 1.3)
		Mode.STALL:
			velocity.x = 0.0
			sprite.play("hurt")
			if _t <= 0.0:
				facing = -facing
				_go(Mode.IDLE, 0.3)
		Mode.SHOUT:
			velocity.x = 0.0
			sprite.play("shout")
			if _t <= 0.0:
				if _count > 0:
					_count -= 1
					_wave()
					_t = 0.55 if not enraged else 0.42
				else:
					_go(Mode.IDLE, 0.6)
		Mode.THROW:
			velocity.x = 0.0
			sprite.play("throw")
			if _t <= 0.0:
				if _count > 0:
					_count -= 1
					_throw()
					_t = 0.7
				else:
					_go(Mode.IDLE, 0.9)
		Mode.CALL:
			velocity.x = 0.0
			sprite.play("shout")
			if _t <= 0.0:
				_call_staff()
				_go(Mode.IDLE, 1.0)
		Mode.DYING:
			velocity.x = 0.0
	sprite.flip_h = facing < 0  # drawn facing right
	move_and_slide()


func in_intro() -> bool:
	return mode == Mode.INTRO


func _go(m: Mode, time: float) -> void:
	mode = m
	_t = time


func _face_rex() -> void:
	var r := rex()
	if r:
		facing = 1 if r.global_position.x > global_position.x else -1


func _pick() -> void:
	if _bag.is_empty():
		_bag = ["drive", "shout", "throw", "drive"]
		if enraged:
			_bag += ["call", "shout", "drive"]
		_bag.shuffle()
	_face_rex()
	match _bag.pop_back():
		"drive":
			_go(Mode.REV, 0.7 if not enraged else 0.5)
		"shout":
			_count = 3 if not enraged else 4
			Showrunner.say(["ATTENTION SHOPPERS!", "NO RUNNING IN THE MALL!", "THIS IS A CUSTOMER-FIRST ENVIRONMENT!"].pick_random(), "showrunner", true)
			_go(Mode.SHOUT, 0.4)
		"throw":
			_count = 2 if not enraged else 3
			_go(Mode.THROW, 0.4)
		"call":
			_go(Mode.CALL, 0.6)


## A megaphone blast travels along the floor both ways: jump it.
func _wave() -> void:
	Sfx.play("roar", 1.8, -4.0)
	GameState.level.shake(2.0)
	var w := Shockwave.new()
	w.direction = facing
	w.global_position = global_position + Vector2(facing * 20, 0)
	w.modulate = Color(1.6, 1.3, 0.6)
	GameState.level.add_child(w)


func _throw() -> void:
	var r := rex()
	if r == null:
		return
	var c := Clipboard.new()
	c.thrower = self
	c.global_position = global_position + Vector2(facing * 16, -28)
	var aim := (r.global_position + Vector2(0, -14) - c.global_position).normalized()
	c.velocity = aim * Clipboard.SPEED
	GameState.level.add_child(c)
	Sfx.play("shoot", 0.5)


func _call_staff() -> void:
	Showrunner.say("Security to the atrium! And somebody bring the display models!", "showrunner", true)
	var level = GameState.level
	for i in 2:
		var dx := -90.0 if i == 0 else 90.0
		var p: Vector2 = level.ceiling_above(global_position + Vector2(dx, -20), 6) + Vector2(0, 8)
		var e: Enemy = SecurityBot.new() if i == 0 else Mannequin.new()
		e.position = p
		level.add_child(e)
		level.burst(p, Art.c("gold"), 10, 60.0)


func _on_enrage() -> void:
	_bag.clear()
	Showrunner.say("The Floor Manager is escalating this to HIMSELF. Brace for policy.", "showrunner", true)


func _die() -> void:
	mode = Mode.DYING
	sprite.play("hurt")
	_finale("The Floor Manager has clocked out early. Who approves my timesheets now?!", 36.0)
