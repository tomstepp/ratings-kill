class_name ExitDoor
extends Area2D
## The level's exit. Stand in front and press UP. Origin is bottom-center.

var _prompt: Label
var _used := false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14, 30)
	shape.shape = rect
	shape.position = Vector2(0, -15)
	add_child(shape)
	var s := Sprite2D.new()
	s.texture = Art.frame("doors", Vector2i(16, 32), 3)
	s.position = Vector2(0, -16)
	s.z_index = -1
	add_child(s)
	_prompt = Art.label("UP: EXIT", Art.c("lime"))
	_prompt.size = Vector2(60, 9)
	_prompt.position = Vector2(-30, -46)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	add_child(_prompt)


func _process(_delta: float) -> void:
	var near := false
	for b in get_overlapping_bodies():
		if b is Rex:
			near = true
	_prompt.visible = near and not _used and fmod(Time.get_ticks_msec() / 1000.0, 0.8) < 0.55


func interact(_rex: Rex) -> void:
	if _used:
		return
	_used = true
	GameState.level.complete()
