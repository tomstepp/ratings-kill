class_name TitleScreen
extends Screen

var _rex: AnimatedSprite2D
var _options: Array[Label] = []
var _ids: Array[String] = []
var _diff: Array[Label] = []  # the difficulty picker, while it's open
var _diff_desc: Label
var _diff_choice := 0
var _choice := 0


func _ready() -> void:
	backdrop(0.35)
	var tv := Sprite2D.new()
	tv.texture = Art.frame("portraits", Vector2i(24, 24), 0)
	tv.scale = Vector2(3, 3)
	tv.position = Vector2(278, 70)
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
	boom.position = Vector2(22, 150)
	add_child(boom)

	centered("THE GALACTIC CONTENT SYNDICATE PRESENTS", 10, Art.c("metal"))
	centered("SUPER REX", 28, Art.c("red"), 3).position += Vector2(2, 2)
	centered("SUPER REX", 28, Art.c("gold"), 3)
	centered("LIVE!", 58, Art.c("rust"), 4).position += Vector2(2, 2)
	centered("LIVE!", 58, Art.c("white"), 4)
	centered("ON AIR: THE TOWER BELOW", 100, Art.c("cyan"))
	var saved := GameState.saved_level()
	if saved > 0:
		var name: String = Level.read_header(GameState.LEVELS[saved]).get("name", "")
		_add_option("continue", "CONTINUE: %s %s" % [GameState.level_label(saved).replace("FLOOR ", "F").replace(" - LEVEL ", "-L").replace(" - BOSS", " BOSS"), name.to_upper()])
	_add_option("new", "NEW GAME" if saved > 0 else "GO ON AIR (NEW GAME)")
	_add_option("settings", "SETTINGS")
	_add_option("credits", "CREDITS")
	_refresh()
	centered("ARROWS MOVE  SPACE JUMP  X SHOOT", 156, Art.c("steel"))
	centered("C DRONE FLASH  UP DOORS  ESC PAUSE", 167, Art.c("metal"))
	scanlines()
	Sfx.music("music_title")


func _add_option(id: String, text: String) -> void:
	_options.append(centered(text, 112 + _options.size() * 10, Art.c("steel")))
	_ids.append(id)


const DIFFICULTIES := [
	["NORMAL", "THE SHOW AS INTENDED."],
	["EASY", "EVERY HIT COSTS 1 PIP. WEAKER BOSSES. NO CANCELING."],
]


func _process(delta: float) -> void:
	super(delta)
	if not _diff.is_empty():
		_difficulty_input()
		return
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		_choice = posmod(_choice + (1 if Input.is_action_just_pressed("move_down") else -1), _options.size())
		Sfx.play("blip", 1.2)
		_refresh()
	_options[_choice].visible = fmod(_t, 1.0) < 0.75
	if confirm_pressed():
		_options[_choice].visible = true
		match _ids[_choice]:
			"credits":
				set_process(false)
				Sfx.play("blip", 0.8)
				GameState.main.show_credits()
			"settings":
				set_process(false)
				Sfx.play("blip", 0.8)
				GameState.main.show_settings()
			"continue":
				set_process(false)
				Sfx.play("powerup")
				if not GameState.continue_game():
					GameState.new_game()
			_:
				_open_difficulty()


## New Game asks for a difficulty first (it can be changed later in Settings).
func _open_difficulty() -> void:
	Sfx.play("blip", 1.0)
	for o in _options:
		o.visible = false
	_diff_choice = 1 if GameState.easy else 0
	var title := centered("CHOOSE YOUR DIFFICULTY", 110, Art.c("cyan"))
	_diff.append(title)
	for i in DIFFICULTIES.size():
		_diff.append(centered("", 121 + i * 10))
	_diff_desc = centered("", 143, Art.c("metal"))
	_diff.append(_diff_desc)
	_t = 0.0  # so the press that opened this doesn't also confirm it
	_refresh_difficulty()


func _difficulty_input() -> void:
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		_diff_choice = 1 - _diff_choice
		Sfx.play("blip", 1.2)
		_refresh_difficulty()
	elif Input.is_action_just_pressed("pause"):
		# Back to the main menu.
		for l in _diff:
			l.queue_free()
		_diff.clear()
		_refresh()
	elif confirm_pressed():
		set_process(false)
		GameState.easy = _diff_choice == 1
		GameState.apply_settings()
		Sfx.play("powerup")
		GameState.new_game()


func _refresh_difficulty() -> void:
	for i in DIFFICULTIES.size():
		var row: Label = _diff[i + 1]
		var on := i == _diff_choice
		row.text = ("> %s <" if on else "%s") % DIFFICULTIES[i][0]
		row.add_theme_color_override("font_color", Art.c("gold") if on else Art.c("steel"))
	_diff_desc.text = DIFFICULTIES[_diff_choice][1]


func _refresh() -> void:
	for i in _options.size():
		var label := _options[i]
		label.text = ("> " if i == _choice else "") + label.text.trim_prefix("> ").strip_edges()
		label.visible = true
		label.add_theme_color_override("font_color", Art.c("gold") if i == _choice else Art.c("steel"))
