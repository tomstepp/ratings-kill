class_name KeyDoor
extends StaticBody2D
## A locked door two tiles tall. Opens on touch if Rex has the matching keycard.
## Origin is the bottom-center of the door.

const COLORS := ["red", "blue", "yellow"]

var color := "red"
var _open := false
var _sprite: Sprite2D
var _shape: CollisionShape2D
var _area: Area2D
var _hint_cd := 0.0


func _ready() -> void:
	collision_layer = 1
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 32)
	_shape.shape = rect
	_shape.position = Vector2(0, -16)
	add_child(_shape)
	_sprite = Sprite2D.new()
	_sprite.texture = Art.frame("doors", Vector2i(16, 32), COLORS.find(color))
	_sprite.position = Vector2(0, -16)
	add_child(_sprite)
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var ashape := CollisionShape2D.new()
	var arect := RectangleShape2D.new()
	arect.size = Vector2(22, 30)
	ashape.shape = arect
	ashape.position = Vector2(0, -16)
	_area.add_child(ashape)
	add_child(_area)


func _physics_process(delta: float) -> void:
	_hint_cd -= delta
	if _open:
		return
	for b in _area.get_overlapping_bodies():
		if b is Rex:
			if GameState.keys.has(color):
				open()
			elif _hint_cd <= 0.0:
				_hint_cd = 8.0
				Showrunner.say("Locked! This door requires a %s keycard. Rules are rules." % color.to_upper())


func open() -> void:
	_open = true
	Sfx.play("door")
	_shape.set_deferred("disabled", true)
	var t := create_tween()
	t.tween_property(_sprite, "position:y", -44.0, 0.5).set_trans(Tween.TRANS_QUAD)
	t.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.5)
	Ratings.add(3, "ACCESS")
