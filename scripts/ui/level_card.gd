class_name LevelCard
extends Screen
## A short title card before each level: where you are in the season.

const HOLD := 3.2

var index := 0
var _path := ""


func _ready() -> void:
	_path = GameState.LEVELS[index]
	var info := Level.read_header(_path)
	var f: Dictionary = GameState.FLOORS[GameState.floor_index(index)]
	backdrop(0.6, f.tiles)
	var boss := GameState.is_boss(index)
	centered("EPISODE %d OF %d" % [index + 1, GameState.LEVELS.size()], 34, Art.c("metal"))
	centered("FLOOR %d: %s" % [GameState.floor_index(index) + 1, f.name], 48, Art.c("cyan"))
	var where := "BOSS FIGHT" if boss else "LEVEL %d OF %d" % [index % GameState.LEVELS_PER_FLOOR + 1, GameState.LEVELS_PER_FLOOR - 1]
	centered(where, 66, Art.c("red") if boss else Art.c("gold"), 2)
	centered(str(info.get("name", "")).to_upper(), 92, Art.c("white"), 2)
	# Progress dots: one per episode, the current one blinking.
	var x0 := 160 - GameState.LEVELS.size() * 6
	for i in GameState.LEVELS.size():
		var dot := ColorRect.new()
		dot.size = Vector2(8 if GameState.is_boss(i) else 6, 6)
		dot.position = Vector2(x0 + i * 12 + (0 if GameState.is_boss(i) else 1), 124)
		dot.color = Art.c("lime") if i < index else Art.c("gold") if i == index else Art.c("midnight")
		if GameState.is_boss(i) and i > index:
			dot.color = Art.c("rust")
		dot.name = "dot%d" % i
		add_child(dot)
	scanlines()
	Sfx.music("")
	Sfx.play("roar" if boss else "powerup", 1.0 if boss else 0.8)


func _process(delta: float) -> void:
	super(delta)
	var dot := get_node_or_null("dot%d" % index)
	if dot:
		dot.visible = fmod(_t, 0.6) < 0.4
	if _t > HOLD or confirm_pressed():
		set_process(false)
		GameState.main.show_level(_path)
