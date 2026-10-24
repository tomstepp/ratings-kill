extends CanvasLayer
## The show's system AI: dialogue pop-ups (with voice blips) and achievements.

const SPEAKERS := {
	"showrunner": {"name": "THE SHOWRUNNER", "portrait": 0, "color": "magenta", "pitch": 1.25},
	"boom": {"name": "B0-0M", "portrait": 1, "color": "cyan", "pitch": 1.7},
	"rex": {"name": "REX HALLOWAY", "portrait": 2, "color": "gold", "pitch": 0.8},
}
const CHARS_PER_SEC := 45.0
const LINE_CHARS := 45

const ACHIEVEMENTS := {
	"first_death": {"title": "CANCELED TOO SOON", "reward": 100},
	"wall_bumps": {"title": "METHOD ACTOR", "reward": 50, "stat": 10},
	"jumps": {"title": "BUNNY HOP HOPEFUL", "reward": 100, "stat": 50},
	"shots": {"title": "TRIGGER HAPPY", "reward": 150, "stat": 100},
	"crates": {"title": "UNBOXING VIDEO", "reward": 150, "stat": 10},
	"sodas": {"title": "HYDRATION PARTNER", "reward": 100, "stat": 3},
	"secrets": {"title": "SECRET SHOPPER", "reward": 200, "stat": 1},
	"stomps": {"title": "FOOTWORK", "reward": 150, "stat": 5},
	"kills": {"title": "BODY COUNT", "reward": 250, "stat": 25},
	"chain3": {"title": "TRIPLE THREAT", "reward": 300},
	"sponsor": {"title": "BRAND SYNERGY", "reward": 200},
	"bored": {"title": "DEAD AIR", "reward": 50},
	"untouchable": {"title": "UNTOUCHABLE", "reward": 500},
	"window_shopper": {"title": "WINDOW SHOPPER", "reward": 25},
}

var unlocked := {}
var _queue: Array = []
var _current := {}
var _shown := 0.0
var _hold := 0.0
var _blip_t := 0.0
var _toasts: Array = []

var _panel: Control
var _portrait: TextureRect
var _name: Label
var _text: Label
var _toast: Control
var _toast_label: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func _build() -> void:
	_panel = Control.new()
	_panel.position = Vector2(4, 144)
	_panel.size = Vector2(312, 33)
	_panel.visible = false
	add_child(_panel)
	var border := ColorRect.new()
	border.color = Art.c("black")
	border.size = _panel.size
	_panel.add_child(border)
	var fill := ColorRect.new()
	fill.color = Art.c("navy")
	fill.position = Vector2(1, 1)
	fill.size = _panel.size - Vector2(2, 2)
	_panel.add_child(fill)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(4, 4)
	_panel.add_child(_portrait)
	_name = Art.label("")
	_name.position = Vector2(32, 2)
	_panel.add_child(_name)
	_text = Art.label("")
	_text.position = Vector2(32, 12)
	_text.size = Vector2(274, 20)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD
	_panel.add_child(_text)

	_toast = Control.new()
	_toast.visible = false
	add_child(_toast)
	var tb := ColorRect.new()
	tb.color = Art.c("black")
	tb.size = Vector2(180, 13)
	_toast.add_child(tb)
	var tf := ColorRect.new()
	tf.color = Art.c("maroon")
	tf.position = Vector2(1, 1)
	tf.size = Vector2(178, 11)
	_toast.add_child(tf)
	_toast_label = Art.label("", Art.c("gold"))
	_toast_label.position = Vector2(0, 2)
	_toast_label.size = Vector2(180, 9)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	_toast.position = Vector2(70, -16)


## Queue a line of dialogue. `speaker` is showrunner, boom or rex.
func say(text: String, speaker := "showrunner", urgent := false) -> void:
	if not urgent and _queue.size() >= 4:
		return
	var pages := _paginate(text)
	if urgent:
		pages.reverse()
	for page in pages:
		var entry := {"text": page, "speaker": speaker}
		if urgent:
			_queue.push_front(entry)
		else:
			_queue.append(entry)


## Split text into pages that fit two lines of the dialogue box.
func _paginate(text: String) -> Array[String]:
	var pages: Array[String] = []
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" ", false):
		if line.length() + word.length() + 1 > LINE_CHARS and line != "":
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(line)
	for i in range(0, lines.size(), 2):
		pages.append("\n".join(lines.slice(i, i + 2)))
	return pages


func clear() -> void:
	_queue.clear()
	_current = {}
	_panel.visible = false


func is_talking() -> bool:
	return not _current.is_empty() or not _queue.is_empty()


func _process(delta: float) -> void:
	_process_dialogue(delta)


func _process_dialogue(delta: float) -> void:
	if _current.is_empty():
		if _queue.is_empty():
			_panel.visible = false
			return
		_current = _queue.pop_front()
		var sp: Dictionary = SPEAKERS[_current.speaker]
		_portrait.texture = Art.frame("portraits", Vector2i(24, 24), sp.portrait)
		_name.text = sp.name
		_name.add_theme_color_override("font_color", Art.c(sp.color))
		_text.text = _current.text
		_text.visible_characters = 0
		_shown = 0.0
		_hold = 1.2 + _current.text.length() * 0.025
		_panel.visible = true
	var total: int = _current.text.length()
	if _shown < total:
		var before := int(_shown)
		_shown = minf(_shown + delta * CHARS_PER_SEC, total)
		var n := int(_shown)
		_text.visible_characters = n
		_blip_t -= delta
		if n > before and _blip_t <= 0.0 and _current.text[n - 1] != " ":
			_blip_t = 0.06
			Sfx.play("blip", SPEAKERS[_current.speaker].pitch * randf_range(0.9, 1.15), -6.0)
		if _shown >= total:
			_text.visible_characters = -1
	else:
		_hold -= delta
		if _hold <= 0.0:
			_current = {}


# ------------------------------------------------------------------ achievements

func reset_achievements() -> void:
	unlocked.clear()


func check_stat(stat: String, value: int) -> void:
	if ACHIEVEMENTS.has(stat) and ACHIEVEMENTS[stat].has("stat") and value >= ACHIEVEMENTS[stat].stat:
		unlock(stat)


func unlock(id: String) -> void:
	if unlocked.has(id):
		return
	unlocked[id] = true
	var a: Dictionary = ACHIEVEMENTS[id]
	GameState.add_points(a.reward)
	_toasts.append("%s  +$%d" % [a.title, a.reward])
	if _toasts.size() == 1:
		_show_next_toast()


func _show_next_toast() -> void:
	if _toasts.is_empty():
		return
	_toast_label.text = "* " + _toasts[0] + " *"
	_toast.visible = true
	Sfx.play("achieve")
	var t := create_tween()
	t.tween_property(_toast, "position:y", 18.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_interval(2.2)
	t.tween_property(_toast, "position:y", -16.0, 0.2)
	t.tween_callback(func():
		_toasts.pop_front()
		_toast.visible = false
		_show_next_toast())
