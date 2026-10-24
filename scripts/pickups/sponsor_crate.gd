class_name SponsorCrate
extends CharacterBody2D
## Falls from the ceiling on a parachute when the ratings meter fills.

const FALL_SPEED := 48.0

const ITEMS := [
	{"id": "blaster", "name": "MEGAVOLT BLASTER MOD", "line": "This firepower upgrade brought to you by MegaVolt: 'Why aim when you can spray?'"},
	{"id": "cola", "name": "FIZZO COLA 6-PACK", "line": "Fizzo Cola! Now with 40 percent fewer lawsuits. Full health!"},
	{"id": "snax", "name": "CRUNCHCO SNAX", "line": "CrunchCo Snax: technically food! Plus three health."},
	{"id": "smile", "name": "SMILEBRITE STRIPS", "line": "SmileBrite whitening strips. They do nothing for you, but the sponsor pays $500."},
	{"id": "chicken", "name": "RUBBER CHICKEN", "line": "A rubber chicken, courtesy of LaffTrak Props. It's worth $250 to someone."},
	{"id": "battery", "name": "VOLTZ DRONE CELL", "line": "Voltz batteries! Your drone is fully charged. Your contract is not."},
]

var _landed := false
var _opened := false
var _chute: Sprite2D
var _area: Area2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 16
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 16)
	shape.shape = rect
	shape.position = Vector2(0, -8)
	add_child(shape)
	var s := Sprite2D.new()
	s.texture = Art.tex["sponsor_crate"]
	s.position = Vector2(0, -8)
	add_child(s)
	_chute = Sprite2D.new()
	_chute.texture = Art.tex["chute"]
	_chute.position = Vector2(0, -22)
	add_child(_chute)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var ashape := CollisionShape2D.new()
	ashape.shape = rect
	ashape.position = Vector2(0, -8)
	_area.add_child(ashape)
	add_child(_area)


func _physics_process(delta: float) -> void:
	if not _landed:
		velocity = Vector2(sin(Time.get_ticks_msec() * 0.003) * 10.0, FALL_SPEED)
		move_and_slide()
		if is_on_floor():
			_landed = true
			Sfx.play("door", 1.6, -6.0)
			var t := create_tween()
			t.tween_property(_chute, "modulate:a", 0.0, 0.3)
	else:
		velocity = Vector2(0, 200)
		move_and_slide()
	if GameState.level and global_position.y > GameState.level.kill_y:
		queue_free()
	if not _opened:
		for b in _area.get_overlapping_bodies():
			if b is Rex and b.state != Rex.State.DEAD:
				_open(b)


func _open(rex: Rex) -> void:
	_opened = true
	var item: Dictionary = _choose()
	match item.id:
		"blaster":
			GameState.add_firepower()
			Sfx.play("powerup")
		"cola":
			GameState.heal(GameState.MAX_HEALTH)
			Sfx.play("pickup")
		"snax":
			GameState.heal(3)
			Sfx.play("pickup", 0.85)
		"smile":
			GameState.add_points(500)
			Sfx.play("buy")
		"chicken":
			GameState.add_points(250)
			Sfx.play("bonk", 1.8)
		"battery":
			if rex.boom:
				rex.boom.cooldown = 0.0
			Sfx.play("powerup", 1.3)
	Showrunner.say(item.line, "showrunner", true)
	var level = GameState.level
	level.float_text(global_position + Vector2(0, -24), item.name, Art.c("magenta"))
	level.burst(global_position + Vector2(0, -8), Art.c("magenta"), 16, 90.0)
	level.burst(global_position + Vector2(0, -8), Art.c("gold"), 10, 70.0)
	rex.quip("pickup", true)
	queue_free()


## Sponsors read the room: they push health when Rex is hurting.
func _choose() -> Dictionary:
	var pool: Array = []
	for item in ITEMS:
		var weight := 2
		match item.id:
			"blaster":
				weight = 0 if GameState.firepower >= GameState.MAX_FIREPOWER else 3
			"cola", "snax":
				weight = 5 if GameState.health <= 4 else 1
			"battery":
				weight = 1
		for i in weight:
			pool.append(item)
	return pool.pick_random()
