class_name Tanya
extends CharacterBody2D
## Tanya Voss, the fan-favorite rival contestant. She drops in to race Rex to
## sponsor crates, and steals one if she gets there first. On some levels she's
## waiting at the exit, one step ahead as always. Boom's flash stuns her;
## nothing else touches her (she's a contestant, not an enemy).

const SPEED := 92.0
const GRAVITY := 900.0
const JUMP := -300.0
const GIVE_UP := 9.0

const START_LINES := ["That crate's got my name on it, Halloway!", "Sponsor drop? Don't mind if I do!",
	"Last one there's a rerun!"]
const WIN_LINES := ["Thanks for keeping it warm, Halloway!", "Too slow! Try running next time.",
	"The fans love a comeback. Mine."]
const LOSE_LINES := ["Fine. Keep it. Enjoy your participation trophy.", "Lucky grab. See you on the next floor.",
	"Ugh. The producers are going to edit that out."]

enum Mode { DROP, RACE, DONE, CAMEO }

var mode := Mode.DROP
var target: SponsorCrate
var cameo_line := ""
var facing := 1
var stunned := 0.0
var sprite: AnimatedSprite2D
var _t := 0.0
var _leaving := false
var _bubble: Label


func _ready() -> void:
	add_to_group("rivals")
	collision_layer = 0
	collision_mask = 1 | 16
	z_index = 3
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 27)
	shape.shape = rect
	shape.position = Vector2(0, -13.5)
	add_child(shape)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.frames("tanya", Vector2i(16, 32), {
		"idle": [[0], 1.0, false],
		"run": [[1, 2, 3, 2], 10.0, true],
		"cheer": [[4, 0], 4.0, true],
	})
	sprite.position = Vector2(0, -16)
	sprite.play("idle")
	add_child(sprite)
	_bubble = Art.label("", Art.c("lime"))
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.position = Vector2(-80, -44)
	_bubble.visible = false
	_bubble.z_index = 20
	add_child(_bubble)
	if mode == Mode.CAMEO:
		sprite.modulate.a = 0.0
		create_tween().tween_property(sprite, "modulate:a", 1.0, 0.3)
		sprite.play("cheer")
		Showrunner.say(cameo_line, "tanya", true)


## Race Rex to `crate`. She appears above `pos` and drops in.
func race(crate: SponsorCrate) -> void:
	target = crate
	mode = Mode.DROP


func stun(time: float) -> void:
	stunned = time


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 300.0)
	_t += delta
	if stunned > 0.0:
		stunned -= delta
		velocity.x = 0.0
		sprite.speed_scale = 0.0
		sprite.modulate = Color(0.6, 0.8, 1.6) if stunned > 0.0 else Color.WHITE
		move_and_slide()
		return
	sprite.speed_scale = 1.0
	match mode:
		Mode.DROP:
			velocity.x = 0.0
			if is_on_floor():
				mode = Mode.RACE
				say(START_LINES.pick_random())
		Mode.RACE:
			_race()
		Mode.DONE:
			velocity.x = 0.0
		Mode.CAMEO:
			velocity.x = 0.0
			if _t > 2.4:
				_leave()
	sprite.flip_h = facing < 0
	move_and_slide()
	var level = GameState.level
	if level and global_position.y > level.kill_y:
		queue_free()


func _race() -> void:
	if not is_instance_valid(target) or target.is_opened():
		# Rex got there first.
		_finish(false)
		return
	if _t > GIVE_UP:
		_finish(false, true)
		return
	var d := target.global_position - global_position
	facing = 1 if d.x > 0.0 else -1
	velocity.x = facing * SPEED
	sprite.play("run")
	if is_on_wall() and is_on_floor():
		velocity.y = JUMP
	if absf(d.x) < 10.0 and absf(d.y) < 24.0 and target.is_landed():
		target.steal()
		_finish(true)


## She won (stole the crate) or lost (Rex opened it, or she gave up).
func _finish(won: bool, gave_up := false) -> void:
	mode = Mode.DONE
	velocity.x = 0.0
	sprite.play("cheer" if won else "idle")
	if won:
		Ratings.add(-6, "SCOOPED!")
		say(WIN_LINES.pick_random())
	elif not gave_up:
		Ratings.add(10, "RIVALRY!")
		Showrunner.unlock("rival")
		say(LOSE_LINES.pick_random())
	get_tree().create_timer(1.6).timeout.connect(_leave)


## Mid-race trash talk goes in a bubble over her head (the dialogue box is
## often busy), read aloud if nobody else is talking.
func say(text: String) -> void:
	_bubble.text = text
	_bubble.size = Vector2(text.length() * 6 + 2, 9)
	_bubble.visible = true
	Narrator.bark(text, "tanya")
	var screen_x := get_global_transform_with_canvas().origin.x
	_bubble.position.x = clampf(-_bubble.size.x / 2.0, 2.0 - screen_x, 318.0 - screen_x - _bubble.size.x)
	get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(_bubble):
			_bubble.visible = false)


## Off she goes (to the next floor, presumably).
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var t := create_tween()
	t.tween_property(sprite, "modulate:a", 0.0, 0.4)
	t.tween_callback(queue_free)
