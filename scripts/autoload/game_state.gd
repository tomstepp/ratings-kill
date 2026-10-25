extends Node
## Contestant progress, input bindings and screen flow.

signal health_changed
signal points_changed
signal keys_changed
signal firepower_changed

const MAX_HEALTH := 8
const MAX_FIREPOWER := 4
const LEVELS_PER_FLOOR := 4  # three levels, then the floor's boss
## The season: four floors, each three levels and a boss. Files live in levels/.
const FLOORS := [
	{"name": "THE ABANDONED SUBWAY", "tiles": "subway", "levels": ["f1_l1", "f1_l2", "f1_l3", "f1_boss"]},
	{"name": "THE MALL AFTER HOURS", "tiles": "mall", "levels": ["f2_l1", "f2_l2", "f2_l3", "f2_boss"]},
	{"name": "THE STUDIO BACKLOT", "tiles": "backlot", "levels": ["f3_l1", "f3_l2", "f3_l3", "f3_boss"]},
	{"name": "NETWORK HQ", "tiles": "hq", "levels": ["f4_l1", "f4_l2", "f4_l3", "f4_boss"]},
]

var LEVELS: Array[String] = []  # every level path in play order, built from FLOORS

var main: Node  # scenes/main.gd registers itself here
var level: Node  # the running Level, if any

var health := MAX_HEALTH
var points := 0  # spendable in the break room
var score := 0  # lifetime total, never goes down
var firepower := 1
var keys := {}  # "red"/"blue"/"yellow" -> true
var level_index := 0
var upgrades := {"battery": 0, "hype": 0}
var stats := {"wall_bumps": 0, "jumps": 0, "shots": 0, "crates": 0, "sodas": 0, "deaths": 0, "kills": 0, "stomps": 0, "secrets": 0}
var damage_this_level := 0
var music_on := true
var narration_on := true

var skip_cards := false  # the automated playtest goes straight into levels

var _snapshot := {}


func _init() -> void:
	for f in FLOORS:
		for name in f.levels:
			LEVELS.append("res://levels/%s.txt" % name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_migrate_old_data()
	_load_settings()
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()


## Quit cleanly: silence audio and give the audio server a moment to let go of
## its playbacks, otherwise Godot reports them as leaked on exit.
func quit_game() -> void:
	Narrator.stop()
	Sfx.stop_all()
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_music"):
		music_on = not music_on
		Sfx.apply_music_setting()
		Showrunner.notice("MUSIC ON" if music_on else "MUSIC OFF")
		_save_settings()
	elif event.is_action_pressed("toggle_narration"):
		narration_on = not narration_on
		if not narration_on:
			Narrator.stop()
		Showrunner.notice("NARRATION ON" if narration_on else "NARRATION OFF")
		_save_settings()
	if event.is_action_pressed("fullscreen"):
		var mode := DisplayServer.window_get_mode()
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)


# ------------------------------------------------------------------ flow

func new_game() -> void:
	health = MAX_HEALTH
	points = 0
	score = 0
	firepower = 1
	keys = {}
	level_index = 0
	upgrades = {"battery": 0, "hype": 0}
	for k in stats:
		stats[k] = 0
	Showrunner.reset_achievements()
	Ratings.drops = 0
	start_level(0)


## Starts level `i`, after its title card unless this is a restart.
func start_level(i: int, card := true) -> void:
	level_index = i
	keys = {}
	damage_this_level = 0
	_snapshot = {"points": points, "score": score, "firepower": firepower}
	if card and not skip_cards:
		main.show_card(i)
	else:
		main.show_level(LEVELS[i])


func restart_level() -> void:
	health = MAX_HEALTH
	points = _snapshot.points
	score = _snapshot.score
	firepower = _snapshot.firepower
	start_level(level_index, false)


func level_complete() -> void:
	if level_index + 1 >= LEVELS.size():
		clear_save()
		main.show_end(true)
	elif is_boss(level_index):
		save_progress()
		main.show_end(false)
	else:
		save_progress()
		main.show_break_room()


# ------------------------------------------------------------------ where we are

func floor_index(i := level_index) -> int:
	return i / LEVELS_PER_FLOOR


## 0 on Floor 1 up to 3 on Floor 4. Enemies, prices and the meter scale with it.
func difficulty() -> int:
	return floor_index()


func is_boss(i := level_index) -> bool:
	return i % LEVELS_PER_FLOOR == LEVELS_PER_FLOOR - 1


## "FLOOR 2 · LEVEL 3" style label for level `i`.
func level_label(i := level_index) -> String:
	var where := "BOSS" if is_boss(i) else "LEVEL %d" % (i % LEVELS_PER_FLOOR + 1)
	return "FLOOR %d - %s" % [floor_index(i) + 1, where]


func next_level() -> void:
	start_level(level_index + 1)


# ------------------------------------------------------------------ state changes

func heal(amount: int) -> void:
	health = mini(MAX_HEALTH, health + amount)
	health_changed.emit()


func damage(amount: int) -> void:
	health = maxi(0, health - amount)
	damage_this_level += amount
	health_changed.emit()


## Money earned on air is multiplied by the ratings (x1 to x4). Returns what was paid.
func add_points(amount: int, on_air := false) -> int:
	if on_air:
		amount *= Ratings.multiplier()
	points += amount
	score += amount
	points_changed.emit()
	return amount


func spend(amount: int) -> bool:
	if points < amount:
		return false
	points -= amount
	points_changed.emit()
	return true


func add_key(color: String) -> void:
	keys[color] = true
	keys_changed.emit()


func add_firepower() -> bool:
	if firepower >= MAX_FIREPOWER:
		return false
	firepower += 1
	firepower_changed.emit()
	return true


## Count something the achievements care about.
func stat(name: String, amount := 1) -> void:
	stats[name] += amount
	Showrunner.check_stat(name, stats[name])


# ------------------------------------------------------------------ saving

const SAVE_PATH := "user://save.cfg"

var save_path := SAVE_PATH  # the automated playtest points this elsewhere


## Saved after each level, so Continue drops you in the break room before the next one.
func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("run", "next_level", level_index + 1)
	for key in ["health", "points", "score", "firepower", "upgrades", "stats"]:
		cfg.set_value("run", key, get(key))
	cfg.set_value("run", "achievements", Showrunner.unlocked.keys())
	cfg.set_value("run", "drops", Ratings.drops)
	cfg.save(save_path)


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## The level a saved run would continue into (or -1).
func saved_level() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return -1
	return cfg.get_value("run", "next_level", -1)


func continue_game() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return false
	var next: int = cfg.get_value("run", "next_level", 0)
	if next <= 0 or next >= LEVELS.size():
		return false
	health = cfg.get_value("run", "health", MAX_HEALTH)
	points = cfg.get_value("run", "points", 0)
	score = cfg.get_value("run", "score", 0)
	firepower = cfg.get_value("run", "firepower", 1)
	upgrades = cfg.get_value("run", "upgrades", {"battery": 0, "hype": 0})
	var saved_stats: Dictionary = cfg.get_value("run", "stats", {})
	for k in stats:
		stats[k] = saved_stats.get(k, 0)
	Showrunner.reset_achievements()
	for id in cfg.get_value("run", "achievements", []):
		Showrunner.unlocked[id] = true
	Ratings.drops = cfg.get_value("run", "drops", 0)
	keys = {}
	level_index = next - 1
	main.show_break_room()
	return true


func clear_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# ------------------------------------------------------------------ settings

const SETTINGS_PATH := "user://settings.cfg"


## The game used to be called Ratings Kill, which kept its data in another
## folder; carry that save and settings over the first time.
func _migrate_old_data() -> void:
	var old := OS.get_user_data_dir().get_base_dir().path_join("Ratings Kill")
	for f in ["save.cfg", "settings.cfg"]:
		var src := old.path_join(f)
		var dst := OS.get_user_data_dir().path_join(f)
		if FileAccess.file_exists(src) and not FileAccess.file_exists(dst):
			DirAccess.copy_absolute(src, dst)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_on = cfg.get_value("audio", "music", true)
		narration_on = cfg.get_value("audio", "narration", true)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "narration", narration_on)
	cfg.save(SETTINGS_PATH)


# ------------------------------------------------------------------ input

func _setup_input() -> void:
	var bindings := {
		"move_left": [KEY_LEFT, KEY_A, JOY_BUTTON_DPAD_LEFT],
		"move_right": [KEY_RIGHT, KEY_D, JOY_BUTTON_DPAD_RIGHT],
		"move_up": [KEY_UP, KEY_W, JOY_BUTTON_DPAD_UP],
		"move_down": [KEY_DOWN, KEY_S, JOY_BUTTON_DPAD_DOWN],
		"jump": [KEY_SPACE, KEY_Z, KEY_K, JOY_BUTTON_A],
		"shoot": [KEY_X, KEY_J, JOY_BUTTON_X],
		"drone": [KEY_C, KEY_L, JOY_BUTTON_Y],
		"interact": [KEY_UP, KEY_W, KEY_E, JOY_BUTTON_DPAD_UP, JOY_BUTTON_B],
		"pause": [KEY_ESCAPE, KEY_P, JOY_BUTTON_START],
		"fullscreen": [KEY_F],
		"toggle_music": [KEY_M],
		"toggle_narration": [KEY_N],
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.3)
		for code in bindings[action]:
			var ev: InputEvent
			if _is_joy(code):
				ev = InputEventJoypadButton.new()
				ev.button_index = code
			else:
				ev = InputEventKey.new()
				ev.physical_keycode = code
			InputMap.action_add_event(action, ev)
	for pair in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0],
			["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0]]:
		var m := InputEventJoypadMotion.new()
		m.axis = pair[1]
		m.axis_value = pair[2]
		InputMap.action_add_event(pair[0], m)


func _is_joy(code: int) -> bool:
	# Key codes are all >= 32; joypad buttons are small integers.
	return code < 32
