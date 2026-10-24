class_name Lever
extends Area2D
## A switch. Press UP to pull it; it extends every bridge in the level.

var on := false
var _sprite: Sprite2D
var _prompt: Label


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = Art.frame("switch", Vector2i(16, 16), 0)
	add_child(_sprite)
	_prompt = Art.label("UP", Art.c("gold"))
	_prompt.position = Vector2(-6, -20)
	_prompt.visible = false
	add_child(_prompt)


func _process(_delta: float) -> void:
	var near := false
	for b in get_overlapping_bodies():
		if b is Rex:
			near = true
	_prompt.visible = near and not on


func interact(_rex: Rex) -> void:
	if on:
		return
	on = true
	_sprite.texture = Art.frame("switch", Vector2i(16, 16), 1)
	Sfx.play("switch")
	GameState.level.extend_bridges()
