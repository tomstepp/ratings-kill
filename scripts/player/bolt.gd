class_name Bolt
extends Area2D
## Rex's blaster shot. Flies horizontally (or along a slight fan angle with
## firepower upgrades); breaks crates, hurts enemies.

const SPEED := 290.0
const LIFETIME := 0.85

var direction := 1
var rise := 0.0  # vertical px per horizontal px (the fan angle)
var _life := LIFETIME
var _done := false


func _ready() -> void:
	collision_layer = 32  # player shots (EnemyBolt listens for these)
	collision_mask = 1 | 4  # world, enemies
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(7, 3)
	shape.shape = rect
	add_child(shape)
	var s := Sprite2D.new()
	s.texture = Art.tex["bolt"]
	s.flip_h = direction < 0
	add_child(s)
	body_entered.connect(_on_body)


func _physics_process(delta: float) -> void:
	position += Vector2(direction, rise) * SPEED * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body(body: Node) -> void:
	if _done:
		return
	if body.has_method("shot"):
		if body.has_method("is_alive") and not body.is_alive():
			return
		body.shot(1, self)
		if body is Enemy and GameState.level and is_instance_valid(GameState.level.rex):
			GameState.level.rex.shot_landed()
	_done = true
	if GameState.level:
		GameState.level.burst(global_position, Art.c("cyan"), 4, 40.0)
	queue_free()
