class_name Enemy
extends CharacterBody2D
## Shared enemy behavior: health, stun, stomp checks and contact damage.
## Origin is at the enemy's feet.

var hp := 1
var points := 100
var stompable := true
var top_offset := 9.0  # feet-to-top distance, for stomp checks
var contact_damage := 1
var tint := Color.WHITE  # resting sprite color (variants can recolor)
var anim_speed := 1.0

var sprite: AnimatedSprite2D
var stunned := 0.0
var dead := false
var _flash := 0.0
var _stars: Label


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 16
	_build()
	# Grunts get tougher floor by floor (bosses are tuned by hand).
	if not self is Boss:
		hp = ceili(hp * (1.0 + 0.35 * GameState.difficulty()))
	# Network HQ hits harder.
	if GameState.difficulty() >= 3:
		contact_damage += 1
	_stars = Art.label("*", Art.c("gold"))
	_stars.position = Vector2(-3, -top_offset - 12)
	_stars.visible = false
	add_child(_stars)


## Subclasses add their sprite and collision shape here.
func _build() -> void:
	pass


func is_alive() -> bool:
	return not dead


func _physics_process(delta: float) -> void:
	if dead:
		return
	if _flash > 0.0:
		_flash -= delta
		sprite.modulate = Color(3, 3, 3) if _flash > 0.0 else tint
	if stunned > 0.0:
		stunned -= delta
		_stars.visible = true
		_stars.position.x = -3 + sin(stunned * 12.0) * 4.0
		sprite.speed_scale = 0.0
		if stunned <= 0.0:
			_stars.visible = false
			sprite.speed_scale = anim_speed
			sprite.modulate = tint
		else:
			sprite.modulate = Color(0.6, 0.8, 1.6)
	_behave(delta)


## Subclasses move/attack here. Not called once dead.
func _behave(_delta: float) -> void:
	pass


## Rex touched us (Rex checks this right after he moves). `prev_feet` is where
## his feet were before this frame's move, so fast falls still count as stomps.
func touch_rex(rex: Rex, prev_feet: float, falling: bool) -> void:
	if dead or rex.state == Rex.State.DEAD:
		return
	var top := global_position.y - top_offset
	var can_stomp := stompable or stunned > 0.0
	if can_stomp and falling and prev_feet <= top + 6.0:
		rex.stomp_bounce()
		stomped(rex)
	elif stunned <= 0.0:
		rex.hurt(contact_damage, global_position.x)


func stun(time: float) -> void:
	if dead:
		return
	stunned = time


func shot(damage: int, _from: Node) -> void:
	if dead:
		return
	hp -= damage
	_flash = 0.08
	Sfx.play_varied("hit", 0.1, -4.0)
	if hp <= 0:
		kill("shot")


func stomped(_rex: Rex) -> void:
	Sfx.play_varied("stomp")
	GameState.stat("stomps")
	kill("stomp")


func kill(how: String) -> void:
	if dead:
		return
	var was_stunned := stunned > 0.0
	dead = true
	remove_from_group("enemies")
	set_deferred("collision_layer", 0)
	var paid := GameState.add_points(points, true)
	GameState.stat("kills")
	Ratings.on_kill(how, was_stunned)
	var level = GameState.level
	if level:
		level.float_text(global_position + Vector2(0, -top_offset - 6), _cash_text(paid), Art.c("gold"))
		var rex: Rex = level.rex
		if rex and randf() < 0.45:
			rex.quip("stomp" if how == "stomp" else "kill")
	_die_visual(how)


static func _cash_text(paid: int) -> String:
	var m := Ratings.multiplier()
	return "$%d" % paid if m <= 1 else "$%d X%d" % [paid, m]


## Default death: pop into sparks.
func _die_visual(_how: String) -> void:
	Sfx.play_varied("explode", 0.1, -6.0)
	if GameState.level:
		GameState.level.burst(global_position + Vector2(0, -top_offset * 0.5), Art.c("terracotta"), 14, 90.0)
		GameState.level.burst(global_position + Vector2(0, -top_offset * 0.5), Art.c("steel"), 8, 60.0)
	queue_free()
