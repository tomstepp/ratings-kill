class_name SettingsMenu
extends Control
## Volumes, narration, fullscreen, touch buttons and difficulty (Easy/Normal
## can change mid-run; it takes effect from the next enemy or level). Used from the title screen
## and the pause menu. Up/Down pick a row, Left/Right change it, Jump toggles,
## Esc (or BACK) closes. Every change applies and saves right away.

signal closed

const ROWS := [
	{"id": "music", "name": "MUSIC VOLUME"},
	{"id": "sound", "name": "SOUND VOLUME"},
	{"id": "narration", "name": "NARRATION"},
	{"id": "voice", "name": "VOICE VOLUME"},
	{"id": "fullscreen", "name": "FULLSCREEN"},
	{"id": "touch", "name": "TOUCH BUTTONS"},
	{"id": "difficulty", "name": "DIFFICULTY"},
	{"id": "back", "name": "BACK"},
]
const TOUCH_MODES := ["auto", "on", "off"]

var _cursor := 0
var _labels: Array[Label] = []
var _values: Array[Label] = []
var _opened_at := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	size = Vector2(320, 180)
	var panel := ColorRect.new()
	panel.color = Color(Art.c("black"), 0.92)
	panel.position = Vector2(40, 26)
	panel.size = Vector2(240, 118)
	add_child(panel)
	var title := Art.label("SETTINGS", Art.c("gold"))
	title.position = Vector2(48, 31)
	add_child(title)
	for i in ROWS.size():
		var l := Art.label(ROWS[i].name)
		l.position = Vector2(56, 44 + i * 11)
		add_child(l)
		_labels.append(l)
		var v := Art.label("")
		v.position = Vector2(176, 44 + i * 11)
		add_child(v)
		_values.append(v)
	var hint := Art.label("LEFT/RIGHT CHANGE   ESC BACK", Art.c("metal"))
	hint.position = Vector2(56, 133)
	add_child(hint)
	_opened_at = Engine.get_process_frames()
	_refresh()


func _process(_delta: float) -> void:
	# Ignore the press that opened us.
	if Engine.get_process_frames() - _opened_at < 2:
		return
	if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
		_cursor = posmod(_cursor + (1 if Input.is_action_just_pressed("move_down") else -1), ROWS.size())
		Sfx.play("blip", 1.2)
		_refresh()
	elif Input.is_action_just_pressed("move_left"):
		_change(-1)
	elif Input.is_action_just_pressed("move_right"):
		_change(1)
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("shoot") or Input.is_key_pressed(KEY_ENTER):
		if ROWS[_cursor].id == "back":
			close()
		else:
			_change(1)
	elif Input.is_action_just_pressed("pause"):
		close()


func close() -> void:
	set_process(false)
	Sfx.play("blip", 0.8)
	closed.emit()
	queue_free()


func _change(step: int) -> void:
	match ROWS[_cursor].id:
		"music":
			GameState.music_vol = clampi(GameState.music_vol + step, 0, 10)
			GameState.music_on = true
		"sound":
			GameState.sfx_vol = clampi(GameState.sfx_vol + step, 0, 10)
		"voice":
			GameState.voice_vol = clampi(GameState.voice_vol + step, 0, 10)
			if GameState.voice_vol > 0:
				GameState.narration_on = true
		"narration":
			GameState.narration_on = not GameState.narration_on
		"fullscreen":
			GameState.toggle_fullscreen()
		"touch":
			var i := TOUCH_MODES.find(GameState.touch_mode)
			GameState.touch_mode = TOUCH_MODES[posmod(i + step, TOUCH_MODES.size())]
		"difficulty":
			GameState.easy = not GameState.easy
		_:
			return
	GameState.apply_settings()
	Sfx.play("blip", 1.5)
	_refresh()


func _bar(level: int) -> String:
	return "#".repeat(level) + "-".repeat(10 - level)


func _refresh() -> void:
	for i in ROWS.size():
		var id: String = ROWS[i].id
		var value := ""
		match id:
			"music":
				value = _bar(GameState.music_vol) if GameState.music_on else "MUTED (M)"
			"sound":
				value = _bar(GameState.sfx_vol)
			"voice":
				value = _bar(GameState.voice_vol)
			"narration":
				value = "ON" if GameState.narration_on else "OFF"
			"fullscreen":
				value = "ON" if GameState.is_fullscreen() else "OFF"
			"touch":
				value = GameState.touch_mode.to_upper()
			"difficulty":
				value = "EASY" if GameState.easy else "NORMAL"
		_values[i].text = value
		var selected := i == _cursor
		_labels[i].text = ("> " if selected else "  ") + ROWS[i].name
		_labels[i].add_theme_color_override("font_color", Art.c("gold") if selected else Art.c("steel"))
		_values[i].add_theme_color_override("font_color", Art.c("white") if selected else Art.c("metal"))
