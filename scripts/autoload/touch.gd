extends CanvasLayer
## On-screen buttons for phones and tablets: a d-pad on the left; jump, shoot
## and Boom's flash on the right; pause in the corner. They press the same
## input actions as the keyboard, so menus and the game work unchanged.
## Shown on touchscreens (or always/never, from Settings > Touch buttons).

const ALPHA := 0.45
# [frame in touch.png, top-left position, actions it holds down]
const BUTTONS := [
	[0, Vector2(4, 136), ["move_left"]],
	[1, Vector2(44, 136), ["move_right"]],
	[2, Vector2(24, 114), ["move_up", "interact"]],
	[3, Vector2(24, 156), ["move_down"]],
	[4, Vector2(290, 140), ["jump"]],
	[5, Vector2(262, 154), ["shoot"]],
	[6, Vector2(262, 124), ["drone"]],
	[7, Vector2(294, 24), ["pause"]],
]

var buttons: Array[TouchScreenButton] = []


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	for spec in BUTTONS:
		var b := TouchScreenButton.new()
		var tex := Art.frame("touch", Vector2i(24, 24), spec[0])
		b.texture_normal = tex
		b.texture_pressed = tex
		b.position = spec[1]
		var shape := CircleShape2D.new()
		shape.radius = 14.0  # a little bigger than the art, for thumbs
		b.shape = shape
		b.shape_centered = true
		b.passby_press = spec[0] <= 3  # slide between d-pad directions
		b.action = spec[2][0]
		b.modulate.a = ALPHA
		# Up also works doors and switches.
		for extra in spec[2].slice(1):
			b.pressed.connect(Input.action_press.bind(extra))
			b.released.connect(Input.action_release.bind(extra))
		b.pressed.connect(func(): b.modulate.a = 0.85)
		b.released.connect(func(): b.modulate.a = ALPHA)
		add_child(b)
		buttons.append(b)
	GameState.settings_changed.connect(_update_visibility)
	_update_visibility()


func active() -> bool:
	match GameState.touch_mode:
		"on":
			return true
		"off":
			return false
	return DisplayServer.is_touchscreen_available()


func _update_visibility() -> void:
	visible = active()
	for b in buttons:
		b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
