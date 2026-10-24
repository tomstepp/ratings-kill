class_name LaserGate
extends Area2D
## Network HQ security beam ('|' columns in a level): cycles on and off,
## flickering as a warning before it fires up. Touching a live beam hurts.

const ON_TIME := 1.6
const OFF_TIME := 1.6
const WARN := 0.45

var _cells: Array[Vector2i] = []
var _t := 0.0
var _beam: ColorRect
var _core: ColorRect
var _live := false


func setup(cells: Array[Vector2i]) -> void:
	_cells = cells


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var top := _cells[0]
	var h := _cells.size() * 16
	position = Vector2(top.x * 16 + 8, top.y * 16)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(4, h)
	shape.shape = rect
	shape.position = Vector2(0, h / 2.0)
	add_child(shape)
	_beam = ColorRect.new()
	_beam.color = Art.c("red")
	_beam.position = Vector2(-2, 0)
	_beam.size = Vector2(5, h)
	add_child(_beam)
	_core = ColorRect.new()
	_core.color = Art.c("white")
	_core.position = Vector2(-1, 0)
	_core.size = Vector2(2, h)
	add_child(_core)
	for y in [0.0, h - 4.0]:
		var cap := ColorRect.new()
		cap.color = Art.c("metal")
		cap.position = Vector2(-5, y)
		cap.size = Vector2(10, 4)
		add_child(cap)
	# Neighbouring gates fall out of step so there's a rhythm to read.
	_t = fmod(top.x * 0.53, ON_TIME + OFF_TIME)


func _physics_process(delta: float) -> void:
	_t = fmod(_t + delta, ON_TIME + OFF_TIME)
	var was := _live
	_live = _t < ON_TIME
	var warning := not _live and _t > ON_TIME + OFF_TIME - WARN
	_beam.visible = _live or (warning and fmod(_t, 0.1) < 0.05)
	_core.visible = _live
	_beam.color.a = 1.0 if _live else 0.5
	if _live and not was:
		Sfx.play("switch", 2.0, -14.0)
	if _live:
		for b in get_overlapping_bodies():
			if b is Rex:
				b.hurt(2, b.global_position.x - 1.0)
