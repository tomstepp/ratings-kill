class_name BreakRoom
extends Screen
## Between levels: spend money on upgrades, hear from the Showrunner and Boom.

const ITEMS := [
	{"id": "fire", "name": "EXTRA SHOT", "cost": 1200, "desc": "+1 BLASTER SHOT PER TRIGGER PULL. MAX 4."},
	{"id": "heal", "name": "FULL REFILL", "cost": 300, "desc": "RESTORE ALL 8 HEALTH PIPS."},
	{"id": "battery", "name": "DRONE BATTERY", "cost": 800, "desc": "BOOM'S FLASH RECHARGES 25% FASTER. MAX 2."},
	{"id": "hype", "name": "HYPE MAN", "cost": 900, "desc": "RATINGS DRAIN 30% SLOWER. MAX 2."},
	{"id": "go", "name": "BACK ON AIR >", "cost": 0, "desc": ""},
]

var _cursor := 0
var _rows: Array[Label] = []
var _desc: Label
var _money: Label
var _bought := 0
var _next_title := ""


func _ready() -> void:
	backdrop(0.25)
	var floor_rect := ColorRect.new()
	floor_rect.color = Art.c("rust")
	floor_rect.position = Vector2(0, 150)
	floor_rect.size = Vector2(320, 30)
	add_child(floor_rect)
	var stripe := ColorRect.new()
	stripe.color = Art.c("gold")
	stripe.position = Vector2(0, 150)
	stripe.size = Vector2(320, 2)
	add_child(stripe)
	# A sad couch and a vending machine. Glamour.
	var couch := ColorRect.new()
	couch.color = Art.c("pine")
	couch.position = Vector2(12, 134)
	couch.size = Vector2(44, 16)
	add_child(couch)
	var vend := ColorRect.new()
	vend.color = Art.c("teal")
	vend.position = Vector2(120, 100)
	vend.size = Vector2(22, 50)
	add_child(vend)
	var glass := ColorRect.new()
	glass.color = Art.c("cyan")
	glass.position = Vector2(123, 104)
	glass.size = Vector2(12, 28)
	add_child(glass)
	var tv := Sprite2D.new()
	tv.texture = Art.frame("portraits", Vector2i(24, 24), 0)
	tv.scale = Vector2(2, 2)
	tv.position = Vector2(80, 62)
	add_child(tv)
	var rex := AnimatedSprite2D.new()
	rex.sprite_frames = Art.frames("rex", Vector2i(16, 32), {"idle": [[0, 1], 2.0, true]})
	rex.play("idle")
	rex.position = Vector2(76, 134)
	add_child(rex)
	var boom := AnimatedSprite2D.new()
	boom.sprite_frames = Art.frames("boom", Vector2i(14, 14), {"fly": [[0, 1], 14.0, true]})
	boom.play("fly")
	boom.position = Vector2(98, 108)
	add_child(boom)

	centered("BREAK ROOM", 6, Art.c("gold"), 2)
	var panel := ColorRect.new()
	panel.color = Color(Art.c("black"), 0.85)
	panel.position = Vector2(156, 26)
	panel.size = Vector2(158, 112)
	add_child(panel)
	text("CRAFT SERVICES", Vector2(162, 30), Art.c("magenta"))
	_money = text("", Vector2(162, 40), Art.c("gold"))
	for i in ITEMS.size():
		_rows.append(text("", Vector2(162, 54 + i * 11)))
	_desc = text("", Vector2(162, 112), Art.c("steel"))
	_desc.size = Vector2(150, 24)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD

	var next_path: String = GameState.LEVELS[GameState.level_index + 1]
	var probe := Level.new()
	probe.load_layout(next_path)
	_next_title = probe.title
	probe.free()

	_refresh()
	scanlines()
	Sfx.music("music_break")
	Showrunner.clear()
	Showrunner.say("Welcome to the break room! You have $%d. Spend it before accounting notices." % GameState.points)
	Showrunner.say(["Psst. The vending machine has been out of order since season one. Like you. Kidding! Mostly.",
		"Do you think the audience noticed my lens flare? Be honest. No, don't.",
		"I uploaded your last fall in slow motion. Forty million views. You're welcome."].pick_random(), "boom")


func _process(delta: float) -> void:
	super(delta)
	if Input.is_action_just_pressed("move_up"):
		_cursor = posmod(_cursor - 1, ITEMS.size())
		Sfx.play("blip", 1.2)
		_refresh()
	elif Input.is_action_just_pressed("move_down"):
		_cursor = posmod(_cursor + 1, ITEMS.size())
		Sfx.play("blip", 1.2)
		_refresh()
	elif confirm_pressed():
		_choose(ITEMS[_cursor])


func _level_of(id: String) -> int:
	match id:
		"fire":
			return GameState.firepower - 1
		"battery":
			return GameState.upgrades.battery
		"hype":
			return GameState.upgrades.hype
	return 0


func _maxed(id: String) -> bool:
	match id:
		"fire":
			return GameState.firepower >= GameState.MAX_FIREPOWER
		"heal":
			return GameState.health >= GameState.MAX_HEALTH
		"battery", "hype":
			return GameState.upgrades[id] >= 2
	return false


func _choose(item: Dictionary) -> void:
	if item.id == "go":
		set_process(false)
		if _bought == 0:
			Showrunner.unlock("window_shopper")
		Sfx.play("door")
		GameState.next_level()
		return
	if _maxed(item.id):
		Sfx.play("deny")
		Showrunner.say("You've maxed that out. Even our generosity has limits. Mostly legal ones.", "showrunner", true)
		return
	if not GameState.spend(item.cost):
		Sfx.play("deny")
		Showrunner.say("Insufficient funds! Have you considered being more entertaining?", "showrunner", true)
		return
	_bought += 1
	Sfx.play("buy")
	match item.id:
		"fire":
			GameState.add_firepower()
		"heal":
			GameState.heal(GameState.MAX_HEALTH)
		"battery", "hype":
			GameState.upgrades[item.id] += 1
	Showrunner.say(["Sold! The network thanks you for your contribution.", "Excellent purchase. Non-refundable, naturally.",
		"Ka-ching! That's the sound of synergy."].pick_random(), "showrunner", true)
	_refresh()


func _refresh() -> void:
	_money.text = "$%d   HP %d/%d" % [GameState.points, GameState.health, GameState.MAX_HEALTH]
	for i in ITEMS.size():
		var item: Dictionary = ITEMS[i]
		var label: String = ("> " if i == _cursor else "  ") + item.name
		if item.id != "go":
			label += " SOLD OUT" if _maxed(item.id) else " $%d" % item.cost
		_rows[i].text = label
		var color := Art.c("white")
		if i == _cursor:
			color = Art.c("gold")
		elif item.id != "go" and (_maxed(item.id) or GameState.points < item.cost):
			color = Art.c("metal")
		_rows[i].add_theme_color_override("font_color", color)
	var sel: Dictionary = ITEMS[_cursor]
	_desc.text = "NEXT: " + _next_title.to_upper() if sel.id == "go" else sel.desc
