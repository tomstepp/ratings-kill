class_name Pickup
extends Area2D
## Health (soda, food), firepower, points tokens and keycards.
## Origin is the item's center.

const KINDS := {
	"soda": {"sheet": "pickups", "size": Vector2i(12, 14), "frame": 0},
	"food": {"sheet": "pickups", "size": Vector2i(14, 14), "frame": 0, "x": 12},
	"firepower": {"sheet": "pickups", "size": Vector2i(14, 14), "frame": 0, "x": 26},
	"token": {"sheet": "pickups", "size": Vector2i(12, 12), "frame": 0, "x": 40},
	"key_red": {"sheet": "keycards", "size": Vector2i(14, 14), "frame": 0},
	"key_blue": {"sheet": "keycards", "size": Vector2i(14, 14), "frame": 1},
	"key_yellow": {"sheet": "keycards", "size": Vector2i(14, 14), "frame": 2},
}

var kind := "token"
var _sprite: Sprite2D
var _t := randf() * TAU
var _base_y := 0.0
var _taken := false
var _ready_t := 0.0
var _slide := 0  # set by slide_off: the direction it slides once it's done sitting
var _hold := 0.0
var _vy := 0.0
var _start_x := 0.0

const SLIDE_SPEED := 48.0
const FALL_GRAVITY := 600.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	shape.shape = rect
	add_child(shape)
	_sprite = Sprite2D.new()
	var spec: Dictionary = KINDS[kind]
	var x: int = spec.get("x", spec.frame * spec.size.x)
	_sprite.texture = Art.region(spec.sheet, Rect2(x, 0, spec.size.x, spec.size.y))
	add_child(_sprite)
	_base_y = position.y
	body_entered.connect(_on_body)


## Pop out of a crate or TV block with a little hop.
func pop_out() -> void:
	_ready_t = 0.35
	var t := create_tween()
	t.tween_property(self, "position:y", position.y - 14.0, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	t.tween_property(self, "position:y", position.y - 4.0, 0.16).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func(): _base_y = position.y)


## Sit for `hold` seconds, then slide `dir` until it drops off the edge and
## lands; it stops once it's down.
func slide_off(dir: int, hold := 1.2) -> void:
	_slide = dir if dir != 0 else 1
	_hold = hold + 0.35  # after the pop-out hop
	_start_x = position.x


func _physics_process(delta: float) -> void:
	if _slide == 0 or _taken:
		return
	_hold -= delta
	if _hold > 0.0:
		return
	var space := get_world_2d().direct_space_state
	var ahead := PhysicsPointQueryParameters2D.new()
	ahead.position = global_position + Vector2(_slide * 7, 0)
	ahead.collision_mask = 1
	if not space.intersect_point(ahead, 1).is_empty():
		_slide = -_slide
	var below := PhysicsPointQueryParameters2D.new()
	below.position = global_position + Vector2(0, 7)
	below.collision_mask = 1 | 16
	var grounded := not space.intersect_point(below, 1).is_empty()
	if grounded and _vy > 0.0 and absf(position.x - _start_x) > 10.0:
		_slide = 0  # landed below the block: stay put so Rex can grab it
		_vy = 0.0
		return
	if grounded:
		_vy = 0.0
		position.x += _slide * SLIDE_SPEED * delta
	else:
		_vy = minf(_vy + FALL_GRAVITY * delta, 300.0)
		position.y += _vy * delta
	if GameState.level and position.y > GameState.level.kill_y:
		queue_free()


func _process(delta: float) -> void:
	_t += delta * 3.0
	_ready_t -= delta
	_sprite.position.y = sin(_t) * 1.5
	if _ready_t <= 0.0 and not _taken:
		for b in get_overlapping_bodies():
			_on_body(b)


func _on_body(body: Node) -> void:
	if _taken or _ready_t > 0.0 or not body is Rex:
		return
	var rex: Rex = body
	if rex.state == Rex.State.DEAD:
		return
	_taken = true
	var text := ""
	var color := Art.c("white")
	match kind:
		"soda":
			GameState.heal(1)
			GameState.stat("sodas")
			Sfx.play("pickup")
			text = "+1 HP"
			color = Art.c("red")
			if randf() < 0.3:
				rex.quip("pickup")
		"food":
			GameState.heal(2)
			Sfx.play("pickup", 0.85)
			text = "+2 HP"
			color = Art.c("red")
		"firepower":
			if GameState.add_firepower():
				text = "FIREPOWER UP!"
				Showrunner.say("Firepower upgrade! Now with %d times the liability." % GameState.firepower)
			else:
				GameState.add_points(500)
				text = "MAXED! $500"
			Sfx.play("powerup")
			color = Art.c("lime")
			Ratings.add(5, "UPGRADE")
		"token":
			text = Enemy._cash_text(GameState.add_points(50, true))
			Sfx.play_varied("pickup", 0.05, -4.0)
			color = Art.c("gold")
		_:
			var col: String = kind.substr(4)
			GameState.add_key(col)
			Sfx.play("key")
			text = col.to_upper() + " KEYCARD"
			color = {"red": Art.c("red"), "blue": Art.c("cyan"), "yellow": Art.c("gold")}[col]
			Ratings.add(4, "KEYCARD")
			rex.quip("key")
	if GameState.level:
		GameState.level.float_text(global_position + Vector2(0, -8), text, color)
		GameState.level.burst(global_position, color, 8, 50.0)
	queue_free()
