class_name ConfettiBomb
extends Area2D
## The enraged Mascot's party favor: arcs toward Rex and bursts on landing.
## Rex can shoot it down mid-air.

const GRAVITY := 500.0
const BLAST_RADIUS := 22.0

var velocity := Vector2.ZERO
var _done := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 32
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)
	var s := Sprite2D.new()
	s.texture = Art.tex["bomb"]
	add_child(s)
	body_entered.connect(func(_b): _burst())
	area_entered.connect(func(a):
		if a is Bolt:
			a.queue_free()
			Ratings.add(3, "INTERCEPT")
			_burst())


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	position += velocity * delta
	rotation += delta * 6.0
	if GameState.level and position.y > GameState.level.kill_y:
		queue_free()


func _burst() -> void:
	if _done:
		return
	_done = true
	var level = GameState.level
	level.burst(global_position, Art.c("magenta"), 12, 90.0)
	level.burst(global_position, Art.c("gold"), 10, 70.0)
	Sfx.play_varied("crate", 0.1)
	var rex: Rex = level.rex
	if rex and rex.global_position.distance_to(global_position + Vector2(0, 12)) < BLAST_RADIUS + 12.0:
		rex.hurt(1, global_position.x)
	queue_free.call_deferred()
