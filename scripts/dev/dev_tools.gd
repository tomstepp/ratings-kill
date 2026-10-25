extends Node
## Developer helpers, enabled by command-line args after `--`:
##   --capture=DIR   save a screenshot every --every=N physics ticks (60 per second), quit after --shots=N
##   --bot           hold right, hop and shoot: a crude smoke-test player
##   --god           Rex can't lose health
##   --firepower=N   with --level, start with N shots per trigger pull (handled in main.gd)
##   --touch         show the touch buttons (without saving the setting)
##   --pause=PAGE    after 4.5s (past the title card), pause and open a page: menu, ratings, controls or settings
##   --tanya         after 4.5s, drop a sponsor crate ahead of Rex and send Tanya for it
##   --save=PATH     use another save file (e.g. user://none.cfg for a clean title screen)

var capture_dir := ""
var every := 60
var shots := 8
var bot := false
var god := false
var _frame := 0
var _taken := 0
var _press: Array[String] = []
var _images: Array[Image] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_dir = arg.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(capture_dir)
		elif arg.begins_with("--every="):
			every = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shots="):
			shots = int(arg.get_slice("=", 1))
		elif arg == "--bot":
			bot = true
		elif arg == "--god":
			god = true
		elif arg == "--touch":
			GameState.touch_mode = "on"
			GameState.settings_changed.emit.call_deferred()
		elif arg.begins_with("--pause="):
			var page := arg.get_slice("=", 1)
			get_tree().create_timer(4.5).timeout.connect(func(): _open_pause(page))
		elif arg == "--tanya":
			get_tree().create_timer(4.5).timeout.connect(_send_tanya)
		elif arg.begins_with("--save="):
			GameState.save_path = arg.get_slice("=", 1)
		elif arg == "--quit-test":
			get_tree().create_timer(2.0).timeout.connect(GameState.quit_game)


func _physics_process(_delta: float) -> void:
	_frame += 1
	if god and GameState.health < GameState.MAX_HEALTH:
		GameState.health = GameState.MAX_HEALTH
	if bot:
		_drive_bot()
	if capture_dir != "" and _frame % every == 0:
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%03d.png" % [capture_dir, _taken])
		print("capture %d: frame %d, drawn %d, fps %d, speaking %s, rex %s" % [_taken, _frame, Engine.get_frames_drawn(), Engine.get_frames_per_second(), Narrator.is_speaking(),
			GameState.level.rex.global_position if GameState.level else "-"])
		_images.append(img)
		_taken += 1
		if _taken >= shots:
			_save_contact_sheet()
			get_tree().quit()


## All captures in one image, 3 across, for quick review.
func _save_contact_sheet() -> void:
	var w := _images[0].get_width()
	var h := _images[0].get_height()
	var cols := mini(3, _images.size())
	var rows := ceili(_images.size() / float(cols))
	var sheet := Image.create(w * cols + (cols - 1) * 2, h * rows + (rows - 1) * 2, false, _images[0].get_format())
	sheet.fill(Color.WHITE)
	for i in _images.size():
		sheet.blit_rect(_images[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * (w + 2), (i / cols) * (h + 2)))
	sheet.save_png("%s/sheet.png" % capture_dir)


func _drive_bot() -> void:
	for a in _press:
		Input.action_release(a)
	_press.clear()
	_hold("move_right")
	if _frame % 50 < 18:
		_hold("jump")
	if _frame % 14 < 3:
		_hold("shoot")
	if _frame % 40 == 0:
		_hold("interact")
	if _frame % 300 == 150:
		_hold("drone")


func _hold(action: String) -> void:
	Input.action_press(action)
	_press.append(action)


func _open_pause(page: String) -> void:
	var hud: Hud = GameState.level.hud
	hud.set_paused(true)
	match page:
		"ratings":
			hud._open_page(Hud.ratings_page())
		"controls":
			hud._open_page(hud._text_page("CONTROLS", Hud.CONTROLS_TEXT))
		"settings":
			hud._open_page(SettingsMenu.new())


func _send_tanya() -> void:
	var level: Level = GameState.level
	var crate := SponsorCrate.new()
	crate.position = level.ceiling_above(level.rex.global_position + Vector2(level.rex.facing * 90, -24), 6) + Vector2(0, 8)
	level.add_child(crate)
	level.send_tanya(crate)
