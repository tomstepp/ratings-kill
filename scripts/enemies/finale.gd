class_name Finale
extends Boss
## Floor 4 boss: the Season Finale. The Showrunner itself, a giant broadcast
## screen bolted to the end wall. Between attacks its screen opens and the
## core is exposed; that's the only time shots do damage. Attacks: walls of
## bolts with a gap, a sweeping laser at Rex's height, a bolt rain, and
## reruns of enemies from earlier floors. Below half health it climbs the wall.

const OPEN_TIME := 3.0
const LASER_WARN := 0.9
const LASER_LIVE := 0.55

enum Mode { INTRO, IDLE, VOLLEY, LASER, RAIN, SUMMON, OPEN, DYING }

var mode := Mode.INTRO
var _t := 0.0
var _count := 0
var _bag: Array = []
var _home_y := 0.0
var _laser: ColorRect
var _laser_y := 0.0
var _climb := 0.0
var _rain_t := 0.0


func _build() -> void:
	display_name = "THE SEASON FINALE"
	max_hp = 90
	hp = max_hp
	points = 15000
	collision_mask = 0
	top_offset = 56.0
	contact_damage = 2
	can_be_stomped = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 54)
	shape.shape = rect
	shape.position = Vector2(0, -28)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("finale", Vector2i(48, 56), {
		"idle": [[0, 1], 3.0, true],
		"angry": [[2], 1.0, false],
		"open": [[3, 4], 8.0, true],
		"hurt": [[5], 1.0, false],
	})
	sprite.position = Vector2(0, -28)
	sprite.play("idle")
	add_child(sprite)


func _ready() -> void:
	super()
	_home_y = position.y
	_laser = ColorRect.new()
	_laser.visible = false
	_laser.z_index = 8
	GameState.level.add_child.call_deferred(_laser)


func in_intro() -> bool:
	return mode == Mode.INTRO


func shot(damage: int, from: Node) -> void:
	if mode != Mode.OPEN:
		if not dead and not _intro and from is Bolt:
			Sfx.play("deny", 1.4, -10.0)
		return
	super(damage, from)


func _behave(delta: float) -> void:
	velocity = Vector2.ZERO
	# Phase two: it slides up and down the wall.
	if enraged and mode != Mode.DYING:
		_climb += delta * 0.9
		position.y = _home_y - (0.5 - 0.5 * cos(_climb)) * 64.0
	if stunned > 0.0:
		return
	_t -= delta
	match mode:
		Mode.INTRO:
			if _intro_over(delta):
				_go(Mode.IDLE, 1.0)
		Mode.IDLE:
			sprite.play("idle")
			if _t <= 0.0:
				_pick()
		Mode.VOLLEY:
			sprite.play("angry")
			if _t <= 0.0:
				if _count > 0:
					_count -= 1
					_volley()
					_t = 0.85 if not enraged else 0.65
				else:
					_open()
		Mode.LASER:
			sprite.play("angry")
			_update_laser()
			if _t <= -LASER_LIVE:
				_laser.visible = false
				if _count > 1:
					_count -= 1
					_aim_laser()
				else:
					_open()
		Mode.RAIN:
			sprite.play("angry")
			_rain_t -= delta
			if _rain_t <= 0.0:
				_rain_t = 0.16 if not enraged else 0.11
				_drip()
			if _t <= 0.0:
				_open()
		Mode.SUMMON:
			sprite.play("angry")
			if _t <= 0.0:
				_rerun()
				_go(Mode.IDLE, 1.2)
		Mode.OPEN:
			sprite.play("open")
			if _t <= 0.0:
				Sfx.play("door", 0.7)
				_go(Mode.IDLE, 0.6 if not enraged else 0.35)
		Mode.DYING:
			pass


func _go(m: Mode, time: float) -> void:
	mode = m
	_t = time


func _pick() -> void:
	if _bag.is_empty():
		_bag = ["volley", "laser", "rain", "volley", "laser", "summon"]
		_bag.shuffle()
	match _bag.pop_back():
		"volley":
			_count = 3
			_go(Mode.VOLLEY, 0.5)
		"laser":
			_count = 2 if not enraged else 3
			_go(Mode.LASER, 0.0)
			_aim_laser()
		"rain":
			Showrunner.say(["It's raining... CONTENT!", "Precipitation brought to you by our sponsors!"].pick_random(), "showrunner", true)
			_rain_t = 0.0
			_go(Mode.RAIN, 2.4)
		"summon":
			Showrunner.say(["Let's revisit some fan favorites!", "Previously, on Super Rex Live!..."].pick_random(), "showrunner", true)
			_go(Mode.SUMMON, 0.6)


func _open() -> void:
	Showrunner.notice("SIGNAL OPEN: SHOOT THE CORE!")
	Sfx.play("door", 1.3)
	_go(Mode.OPEN, OPEN_TIME if not enraged else OPEN_TIME * 0.8)


## A wall of bolts sweeping left at chest height for the floor and both tiers
## of grates, with one tier left open. Get to the gap (or shoot your way through).
func _volley() -> void:
	var level = GameState.level
	var floor_y: float = level.floor_below(global_position + Vector2(-40, -8))
	var heights := [-14.0, -62.0, -110.0]
	var gap := randi() % heights.size()
	for i in heights.size():
		if i == gap:
			continue
		var b := EnemyBolt.new()
		b.direction = Vector2.LEFT
		b.global_position = Vector2(global_position.x - 30, floor_y + heights[i])
		level.add_child(b)
	Sfx.play_varied("shoot", 0.05, -4.0)


## Mark Rex's height with a thin warning line, then fire a beam across the room.
func _aim_laser() -> void:
	var r := rex()
	_laser_y = (r.global_position.y - 12.0) if r else global_position.y - 20.0
	_laser.position = Vector2(16, _laser_y - 1)
	_laser.size = Vector2(global_position.x - 40.0, 2)
	_laser.color = Color(Art.c("red"), 0.6)
	_laser.visible = true
	_t = LASER_WARN
	Sfx.play("blip", 0.4, -4.0)


func _update_laser() -> void:
	if _t > 0.0:
		_laser.visible = fmod(_t, 0.12) < 0.08
		return
	if _laser.size.y < 8.0:
		_laser.position.y = _laser_y - 5
		_laser.size.y = 10
		_laser.color = Art.c("white")
		GameState.level.shake(3.0)
		Sfx.play("explode", 1.6, -2.0)
	_laser.visible = true
	_laser.color = Art.c("white") if fmod(_t, 0.08) < 0.04 else Art.c("red")
	var r := rex()
	if r and absf(r.global_position.y - 13.0 - _laser_y) < 16.0 and r.global_position.x < global_position.x:
		r.hurt(2, r.global_position.x + 1.0)


func _drip() -> void:
	var level = GameState.level
	var r := rex()
	var x := randf_range(24.0, global_position.x - 40.0)
	if r and randf() < 0.35:
		x = r.global_position.x + randf_range(-20, 20)
	var b := EnemyBolt.new()
	b.direction = Vector2.DOWN
	b.global_position = Vector2(x, 24.0)
	level.add_child(b)


## Reruns: two enemies from earlier floors drop in.
func _rerun() -> void:
	var level = GameState.level
	var kinds := [RatDrone, SecurityBot, Mannequin, MicDrone]
	for dx in [-120.0, -220.0]:
		var e: Enemy = kinds.pick_random().new()
		var p: Vector2 = level.ceiling_above(global_position + Vector2(dx, -20), 6) + Vector2(0, 8)
		e.position = p
		level.add_child(e)
		level.burst(p, Art.c("magenta"), 10, 60.0)


func _on_enrage() -> void:
	_bag.clear()
	Showrunner.say("You think you can cancel ME? I AM the network! ...Well, its system AI. Same thing!", "showrunner", true)


func _die() -> void:
	mode = Mode.DYING
	_laser.visible = false
	sprite.play("hurt")
	_finale("Signal... lost... Please stand by... for... season... two...", 52.0)


func _exit_tree() -> void:
	if is_instance_valid(_laser):
		_laser.queue_free()
