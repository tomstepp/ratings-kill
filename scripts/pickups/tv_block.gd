class_name TVBlock
extends StaticBody2D
## Bonk it from below to release a prize. Origin is the tile center.

var contents := "token"
var used := false
var _sprite: Sprite2D


func _ready() -> void:
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = Art.frame("tvblock", Vector2i(16, 16), 0)
	add_child(_sprite)


func bonk(rex: Node) -> void:
	var t := create_tween()
	t.tween_property(_sprite, "position:y", -4.0, 0.06)
	t.tween_property(_sprite, "position:y", 0.0, 0.08)
	if used:
		Sfx.play("bonk", 0.8, -6.0)
		return
	used = true
	Sfx.play("bonk")
	_sprite.texture = Art.frame("tvblock", Vector2i(16, 16), 1)
	Ratings.add(2, "BONK")
	# The prize sits on top for a moment, then slides off the side Rex is facing
	# and drops down to him, so it's never stranded out of reach.
	var prize: Pickup = GameState.level.spawn_pickup(contents, global_position + Vector2(0, -12), true)
	prize.slide_off(rex.facing if rex is Rex else 1)
