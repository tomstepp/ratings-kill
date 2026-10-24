class_name ElectricRail
extends Area2D
## A run of electrified rail. Cycles on and off; hurts while live.
## The level draws the rail tiles; this node only flips them and deals damage.

const ON_TIME := 1.6
const OFF_TIME := 1.8
const WARN_TIME := 0.4

var cells: Array[Vector2i] = []
var layer: TileMapLayer
var live := false
var _t := 0.0


func setup(run: Array[Vector2i], deco: TileMapLayer) -> void:
	cells = run
	layer = deco
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(run.size() * 16 - 4, 6)
	shape.shape = rect
	var first := run[0]
	position = Vector2(first.x * 16 + run.size() * 8, first.y * 16 + 12)
	add_child(shape)


func _physics_process(delta: float) -> void:
	_t += delta
	var cycle := fmod(_t, ON_TIME + OFF_TIME)
	var now_live := cycle < ON_TIME
	var warn := not now_live and cycle > ON_TIME + OFF_TIME - WARN_TIME
	var show_live := now_live or (warn and fmod(cycle, 0.1) < 0.05)
	for c in cells:
		layer.set_cell(c, 0, Vector2i(11 if show_live else 10, 0))
	live = now_live
	if live:
		for b in get_overlapping_bodies():
			if b is Rex:
				b.hurt(1, b.global_position.x - b.facing)
