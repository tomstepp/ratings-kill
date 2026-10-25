class_name Director
extends Boss
## Floor 3 boss: the Director, riding a camera crane across the top of the
## soundstage. Up high he calls down stage lights and fires clapper bolts;
## then he swoops in for a CLOSE-UP at Rex's level, where he's easy to hit.
## Platforms let Rex shoot him (or stomp him) while he cruises.

enum Mode { INTRO, CRUISE, CLAP, DIVE, CLOSEUP, RISE, DYING }

var mode := Mode.INTRO
var _t := 0.0
var _cruise_y := 0.0
var _phase := 0.0
var _light_t := 1.0
var _target := Vector2.ZERO
var _pivot := Vector2.ZERO
var _arm: Line2D
var _left := 0.0
var _right := 0.0


func _build() -> void:
	display_name = "THE DIRECTOR"
	max_hp = 80
	hp = max_hp
	points = 9000
	collision_mask = 0
	top_offset = 26.0
	contact_damage = 2
	stomp_damage = 3
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30, 26)
	shape.shape = rect
	shape.position = Vector2(0, -13)
	add_child(shape)
	_arm = Line2D.new()
	_arm.width = 4.0
	_arm.default_color = Art.c("metal")
	_arm.z_index = -1
	add_child(_arm)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("director", Vector2i(40, 32), {
		"idle": [[0, 1], 4.0, true],
		"shout": [[2], 1.0, false],
		"hurt": [[3], 1.0, false],
	})
	sprite.position = Vector2(0, -16)
	sprite.play("idle")
	add_child(sprite)


func _ready() -> void:
	super()
	var level = GameState.level
	_left = 48.0
	_right = level.width * 16 - 48.0
	# Level with Rex's head when he stands on the top grates (row 6), so he can shoot back.
	_cruise_y = 6 * 16.0
	_pivot = Vector2(level.width * 8.0, 8.0)
	position.y = _cruise_y


## Only the Director himself hurts. His crane seat and rig are scenery, so
## brushing past them is safe (his whole sprite still takes bolts and stomps).
const PERSON := Rect2(-9, -31, 18, 23)  # head and torso, relative to his feet


func touch_rex(r: Rex, prev_feet: float, falling: bool) -> void:
	var person := Rect2(global_position + PERSON.position, PERSON.size)
	var rex_box := Rect2(r.global_position + Vector2(-5, -27), Vector2(10, 27))
	var stomp := falling and prev_feet <= global_position.y - top_offset + 8.0
	if stomp or person.intersects(rex_box):
		super(r, prev_feet, falling)


func in_intro() -> bool:
	return mode == Mode.INTRO


func _behave(delta: float) -> void:
	_arm.points = PackedVector2Array([to_local(_pivot), Vector2(0, -20)])
	if stunned > 0.0:
		return
	_t -= delta
	var r := rex()
	match mode:
		Mode.INTRO:
			if _intro_over(delta):
				_go(Mode.CRUISE, 4.0)
		Mode.CRUISE:
			sprite.play("idle")
			_phase += delta * (0.55 if not enraged else 0.75)
			var x := lerpf(_left, _right, 0.5 + 0.5 * sin(_phase))
			position = position.move_toward(Vector2(x, _cruise_y + sin(_phase * 2.3) * 10.0), 110.0 * delta)
			_light_t -= delta
			if r and _light_t <= 0.0:
				# His lights are a nuisance, not the main threat: sparse, and 1 damage.
				_light_t = 2.6 if not enraged else 1.8
				GameState.level.drop_light(r.global_position + Vector2(r.velocity.x * 0.5, -20), 0.0, 1)
			if _t <= 0.0:
				if randf() < 0.45:
					_go(Mode.CLAP, 0.5)
				else:
					_dive()
		Mode.CLAP:
			sprite.play("shout")
			if _t <= 0.0:
				_clap()
				_go(Mode.CRUISE, 2.5 if not enraged else 1.8)
		Mode.DIVE:
			sprite.play("shout")
			position = position.move_toward(_target, 170.0 * delta)
			if position.distance_to(_target) < 2.0:
				Sfx.play("roar", 1.2)
				_go(Mode.CLOSEUP, 2.4 if not enraged else 1.8)
		Mode.CLOSEUP:
			sprite.play("idle")
			if r:
				var goal := Vector2(r.global_position.x, _target.y)
				position = position.move_toward(goal, (34.0 if not enraged else 52.0) * delta)
			if _t <= 0.0:
				_go(Mode.RISE, 0.0)
		Mode.RISE:
			position = position.move_toward(Vector2(position.x, _cruise_y), 120.0 * delta)
			if absf(position.y - _cruise_y) < 1.0:
				_go(Mode.CRUISE, 3.5 if not enraged else 2.6)
		Mode.DYING:
			pass
	if r:
		sprite.flip_h = r.global_position.x < global_position.x  # drawn facing right


func _go(m: Mode, time: float) -> void:
	mode = m
	_t = time


## Swoop down to Rex's floor for a close-up: this is when to unload on him.
func _dive() -> void:
	var r := rex()
	if r == null:
		return
	Showrunner.say(["CLOSE-UP! Give me intensity!", "Ready for your close-up, Halloway?", "From the top! With FEELING!"].pick_random(), "showrunner", true)
	_target = Vector2(clampf(r.global_position.x, _left, _right), r.global_position.y - 2.0)
	_go(Mode.DIVE, 0.0)


## "ACTION!": a fan of bolts aimed down at Rex.
func _clap() -> void:
	var r := rex()
	if r == null:
		return
	Sfx.play("bonk", 0.6)
	var aim := (r.global_position + Vector2(0, -12) - global_position).angle()
	var n := 5 if not enraged else 7
	for i in n:
		var b := EnemyBolt.new()
		var a := aim + (i - (n - 1) / 2.0) * 0.22
		b.direction = Vector2.from_angle(a)
		b.global_position = global_position + Vector2(0, -8) + b.direction * 12.0
		GameState.level.add_child(b)


func _on_enrage() -> void:
	Showrunner.say("The Director wants more ACTION! Somebody get the mic drones!", "showrunner", true)
	for dx in [-70.0, 70.0]:
		var d := MicDrone.new()
		d.position = Vector2(clampf(global_position.x + dx, _left, _right), _cruise_y + 30.0)
		GameState.level.add_child.call_deferred(d)  # enraged by a bolt mid-physics-step


func _die() -> void:
	mode = Mode.DYING
	sprite.play("hurt")
	_finale("CUT! CUT! The Director has... left the production. Somebody call his agent.", 24.0)
