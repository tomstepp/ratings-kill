class_name TitleScreen
extends Screen

var _press: Label
var _rex: AnimatedSprite2D
var _options: Array[Label] = []
var _choice := 0


func _ready() -> void:
	backdrop(0.35)
	var tv := Sprite2D.new()
	tv.texture = Art.frame("portraits", Vector2i(24, 24), 0)
	tv.scale = Vector2(3, 3)
	tv.position = Vector2(262, 70)
	add_child(tv)
	_rex = AnimatedSprite2D.new()
	_rex.sprite_frames = Art.frames("rex", Vector2i(16, 32), {"idle": [[0, 1], 2.0, true]})
	_rex.play("idle")
	_rex.scale = Vector2(3, 3)
	_rex.position = Vector2(52, 92)
	add_child(_rex)
	var boom := AnimatedSprite2D.new()
	boom.sprite_frames = Art.frames("boom", Vector2i(14, 14), {"fly": [[0, 1], 14.0, true]})
	boom.play("fly")
	boom.scale = Vector2(2, 2)
	boom.position = Vector2(100, 118)
	add_child(boom)

	centered("THE GALACTIC CONTENT SYNDICATE PRESENTS", 10, Art.c("metal"))
	centered("RATINGS", 30, Art.c("red"), 4).position += Vector2(2, 2)
	centered("RATINGS", 30, Art.c("gold"), 4)
	centered("KILL", 64, Art.c("rust"), 4).position += Vector2(2, 2)
	centered("KILL", 64, Art.c("white"), 4)
	centered("LIVE FROM THE TOWER BELOW", 102, Art.c("cyan"))
	var saved := GameState.saved_level()
	if saved > 0:
		var name: String = Level.read_header(GameState.LEVELS[saved]).get("name", "")
		_options.append(centered("CONTINUE: %s %s" % [GameState.level_label(saved).replace("FLOOR ", "F").replace(" - LEVEL ", "-L").replace(" - BOSS", " BOSS"), name.to_upper()], 116, Art.c("gold")))
		_options.append(centered("NEW GAME", 127, Art.c("steel")))
		_refresh()
	else:
		_press = centered("PRESS JUMP TO GO ON AIR", 124, Art.c("gold"))
	centered("ARROWS MOVE  SPACE JUMP  X SHOOT", 146, Art.c("steel"))
	centered("C DRONE FLASH  UP DOORS  ESC PAUSE", 157, Art.c("steel"))
	centered("F FULLSCREEN  M MUSIC  N NARRATION", 168, Art.c("metal"))
	scanlines()
	Sfx.music("music_title")


func _process(delta: float) -> void:
	super(delta)
	if _press:
		_press.visible = fmod(_t, 1.0) < 0.65
	elif Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		_choice = 1 - _choice
		Sfx.play("blip", 1.2)
		_refresh()
	if confirm_pressed():
		set_process(false)
		Sfx.play("powerup")
		if _options.is_empty() or _choice == 1 or not GameState.continue_game():
			GameState.new_game()


func _refresh() -> void:
	for i in _options.size():
		var label := _options[i]
		label.text = ("> " if i == _choice else "  ") + label.text.trim_prefix("> ").strip_edges()
		label.add_theme_color_override("font_color", Art.c("gold") if i == _choice else Art.c("steel"))
