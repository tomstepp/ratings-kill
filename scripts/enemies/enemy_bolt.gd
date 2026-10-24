class_name EnemyBolt
extends Area2D
## A slow enemy projectile. Hurts Rex, fizzles on walls. Rex can shoot it down.

const SPEED := 105.0

var direction := Vector2.RIGHT
var _life := 3.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 32
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	var s := Sprite2D.new()
	s.texture = Art.tex["enemy_bolt"]
	add_child(s)
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)


func _physics_process(delta: float) -> void:
	position += direction * SPEED * delta
	rotation += delta * 8.0
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body(body: Node) -> void:
	if body is Rex:
		body.hurt(1, global_position.x)
	_pop()


func _on_area(area: Area2D) -> void:
	if area is Bolt:
		Ratings.add(3, "INTERCEPT")
		area.queue_free()
		_pop()


func _pop() -> void:
	if GameState.level:
		GameState.level.burst(global_position, Art.c("magenta"), 6, 50.0)
	queue_free()
