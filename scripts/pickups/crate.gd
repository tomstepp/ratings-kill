class_name Crate
extends StaticBody2D
## Breakable crate. Shoot it to find what's inside. Origin is the tile center.

var contents := ""  # empty = random


func _ready() -> void:
	collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	add_child(shape)
	var s := Sprite2D.new()
	s.texture = Art.tex["crate"]
	add_child(s)


func is_alive() -> bool:
	return not is_queued_for_deletion()


func shot(_damage: int, _from: Node) -> void:
	if is_queued_for_deletion():
		return
	Sfx.play_varied("crate")
	GameState.stat("crates")
	Ratings.add(2, "SMASH")
	var level = GameState.level
	level.burst(global_position, Art.c("orange"), 12, 80.0)
	level.burst(global_position, Art.c("maroon"), 6, 60.0)
	var item := contents
	if item == "":
		var r := randf()
		item = "token" if r < 0.5 else "soda" if r < 0.72 else "food" if r < 0.82 else ""
	if item != "":
		level.spawn_pickup(item, global_position, true)
	queue_free()
