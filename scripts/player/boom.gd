class_name Boom
extends Node2D
## B0-0M, the network camera drone. Follows Rex; ability: flash-stun nearby enemies.

const BASE_COOLDOWN := 6.0
const STUN_RADIUS := 96.0
const STUN_TIME := 2.6

var rex: Rex
var cooldown := 0.0
var _sprite: AnimatedSprite2D
var _t := 0.0


func _ready() -> void:
	z_index = 4
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = Art.frames("boom", Vector2i(14, 14), {"fly": [[0, 1], 14.0, true]})
	_sprite.play("fly")
	add_child(_sprite)
	if rex:
		global_position = rex.global_position + Vector2(-14, -34)


func max_cooldown() -> float:
	return BASE_COOLDOWN * (1.0 - 0.25 * GameState.upgrades.battery)


## 0..1, how charged the flash is (for the HUD).
func charge() -> float:
	return 1.0 - clampf(cooldown / max_cooldown(), 0.0, 1.0)


func _process(delta: float) -> void:
	if not is_instance_valid(rex):
		return
	_t += delta
	cooldown = maxf(0.0, cooldown - delta)
	var target := rex.global_position + Vector2(-rex.facing * 15, -36 + sin(_t * 3.0) * 2.0)
	global_position = global_position.lerp(target, 1.0 - exp(-delta * 6.0))
	_sprite.flip_h = rex.facing < 0
	# A ready drone blinks its lens now and then.
	_sprite.modulate = Color(1.4, 1.4, 1.4) if cooldown <= 0.0 and fmod(_t, 1.5) < 0.08 else Color.WHITE


func flash() -> void:
	if cooldown > 0.0:
		Sfx.play("deny", 1.4, -8.0)
		return
	cooldown = max_cooldown()
	Sfx.play("stun")
	var hit := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(global_position) <= STUN_RADIUS:
			e.stun(STUN_TIME)
			hit += 1
	# Tanya too: fair's fair on live TV.
	for t in get_tree().get_nodes_in_group("rivals"):
		if t.global_position.distance_to(global_position) <= STUN_RADIUS:
			t.stun(STUN_TIME)
	if GameState.level:
		GameState.level.flash_screen()
	if hit >= 3:
		Ratings.add(8, "CROWD CONTROL")
	if hit > 0 and randf() < 0.35:
		Showrunner.say(["Say cheese! Ha. Get it? Because I am a camera.", "Flash photography! Strictly prohibited. By me. For them.",
			"Was that my good angle? Everything is my good angle."].pick_random(), "boom")
