class_name StageLight
extends Area2D
## Boredom penalty hazard: a warning marker blinks, then a stage light drops.

const WARN := 1.0
const FALL_SPEED := 340.0

var floor_y := 0.0
var _t := 0.0
var _sprite: Sprite2D
var _marker: Label
var _falling := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 10)
	shape.shape = rect
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = Art.tex["stage_light"]
	add_child(_sprite)
	_sprite.visible = false
	_marker = Art.label("!", Art.c("red"))
	_marker.position = Vector2(-2, floor_y - global_position.y - 10)
	add_child(_marker)


func _physics_process(delta: float) -> void:
	_t += delta
	if not _falling:
		_marker.visible = fmod(_t, 0.2) < 0.12
		if _t >= WARN:
			_falling = true
			_sprite.visible = true
		return
	position.y += FALL_SPEED * delta
	_marker.position.y = floor_y - global_position.y - 10
	for b in get_overlapping_bodies():
		if b is Rex:
			b.hurt(2, global_position.x)
	if global_position.y >= floor_y - 6:
		Sfx.play("explode", 1.3, -4.0)
		GameState.level.burst(global_position, Art.c("gold"), 16, 110.0)
		GameState.level.burst(global_position, Art.c("white"), 8, 80.0)
		GameState.level.shake(2.0)
		queue_free()
