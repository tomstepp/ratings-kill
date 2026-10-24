class_name Boss
extends Enemy
## Shared boss plumbing: the name on the health bar, waiting out the
## Showrunner's introduction, the enraged half, and the big finish.

signal defeated

var display_name := ""
var max_hp := 60
var enraged := false
var _intro := true
var _intro_t := 1.0


var stomp_damage := 3
var can_be_stomped := true
var stomp_cooldown := 0.0


func _physics_process(delta: float) -> void:
	stomp_cooldown -= delta
	super(delta)


## Default contact: stomp the head for big damage (then get shoved off so you
## can't pogo), otherwise it hurts.
func touch_rex(r: Rex, prev_feet: float, falling: bool) -> void:
	if dead or r.state == Rex.State.DEAD:
		return
	var top := global_position.y - top_offset
	if can_be_stomped and falling and prev_feet <= top + 8.0:
		r.stomp_bounce()
		var away := signf(r.global_position.x - global_position.x)
		r.knock((away if away != 0.0 else 1.0) * 170.0)
		if stomp_cooldown <= 0.0 and not _intro:
			stomp_cooldown = 1.2
			Sfx.play("stomp", 0.7)
			Ratings.add(8, "HEADLINER")
			shot(stomp_damage, r)
	elif stunned <= 0.0:
		r.hurt(contact_damage, global_position.x)


func health_ratio() -> float:
	return clampf(float(hp) / max_hp, 0.0, 1.0)


func in_intro() -> bool:
	return _intro


## Call every frame during the intro; true once the Showrunner has finished
## talking (capped so a stuck dialogue box can't stall the fight).
func _intro_over(delta: float) -> bool:
	_intro_t -= delta
	if (_intro_t <= 0.0 and not Showrunner.is_talking()) or _intro_t < -12.0:
		_intro = false
		Sfx.play("roar")
		return true
	return false


func rex() -> Rex:
	var level = GameState.level
	return level.rex if level and is_instance_valid(level.rex) else null


## Shots chip away; below half health the boss enrages once.
func shot(damage: int, _from: Node) -> void:
	if dead or _intro:
		return
	hp -= damage
	_flash = 0.06
	Sfx.play_varied("hit", 0.1, -4.0)
	if not enraged and hp <= max_hp / 2:
		enraged = true
		tint = Color(1.25, 0.85, 0.85)
		Sfx.play("roar", 0.8)
		_on_enrage()
	if hp <= 0:
		_die()


func _on_enrage() -> void:
	pass


func stun(time: float) -> void:
	# Bosses shrug off most of Boom's flash.
	super(time * 0.35)


## Overridden to stop attacking; then call `_finale(line, height)`.
func _die() -> void:
	pass


func _finale(line: String, height: float) -> void:
	dead = true
	remove_from_group("enemies")
	set_deferred("collision_layer", 0)
	var paid := GameState.add_points(points, true)
	GameState.stat("kills")
	Ratings.add(40, "SEASON HIGHLIGHT")
	Sfx.music("")
	Showrunner.clear()
	Showrunner.say(line, "showrunner", true)
	var level = GameState.level
	var t := create_tween()
	for i in 8:
		t.tween_callback(func():
			var p: Vector2 = global_position + Vector2(randf_range(-18, 18), randf_range(-height, -4))
			level.burst(p, [Art.c("magenta"), Art.c("gold"), Art.c("white")].pick_random(), 14, 110.0)
			level.shake(3.0)
			Sfx.play_varied("explode", 0.2, -2.0))
		t.tween_interval(0.22)
	t.tween_property(sprite, "modulate:a", 0.0, 0.5)
	t.tween_callback(func():
		level.float_text(global_position + Vector2(0, -height - 6), _cash_text(paid), Art.c("gold"))
		defeated.emit()
		queue_free())
