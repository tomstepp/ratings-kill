class_name Hud
extends CanvasLayer
## Health pips, money, firepower, keycards, Boom's charge, the ratings meter
## with its cash multiplier, boss health, and the end-of-level ratings report.

const METER_W := 70

var level: Level
var _hearts: Array[TextureRect] = []
var _points: Label
var _fire: Label
var _keys: Array[TextureRect] = []
var _boom_bar: ColorRect
var _meter_fill: ColorRect
var _viewers: Label
var _live: TextureRect
var _flash: ColorRect
var _pause: Control
var _pops: Array[Label] = []
var _boss_ui: Control
var _boss_fill: ColorRect
var _boss_name: Label
var _mult: Label
var _cancel: Label
var _report: Control
var _t := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bar := ColorRect.new()
	bar.color = Color(Art.c("black"), 0.75)
	bar.size = Vector2(320, 21)
	add_child(bar)

	for i in GameState.MAX_HEALTH:
		var h := TextureRect.new()
		h.position = Vector2(3 + i * 8, 2)
		add_child(h)
		_hearts.append(h)
	_points = Art.label("", Art.c("gold"))
	_points.position = Vector2(3, 11)
	add_child(_points)

	_fire = Art.label("", Art.c("lime"))
	_fire.position = Vector2(72, 2)
	add_child(_fire)
	for i in 3:
		var k := TextureRect.new()
		k.texture = Art.region("keycards", Rect2(i * 14 + 2, 3, 10, 6))
		k.position = Vector2(110 + i * 12, 3)
		k.visible = false
		add_child(k)
		_keys.append(k)

	var boom_label := Art.label("FLASH", Art.c("cyan"))
	boom_label.position = Vector2(72, 11)
	add_child(boom_label)
	var boom_bg := ColorRect.new()
	boom_bg.color = Art.c("navy")
	boom_bg.position = Vector2(104, 13)
	boom_bg.size = Vector2(32, 4)
	add_child(boom_bg)
	_boom_bar = ColorRect.new()
	_boom_bar.color = Art.c("cyan")
	_boom_bar.position = boom_bg.position
	_boom_bar.size = Vector2(32, 4)
	add_child(_boom_bar)

	_live = TextureRect.new()
	_live.texture = Art.frame("ui", Vector2i(8, 8), 2)
	_live.position = Vector2(170, 1)
	add_child(_live)
	var live_label := Art.label("RATINGS", Art.c("white"))
	live_label.position = Vector2(178, 2)
	add_child(live_label)
	var meter_bg := ColorRect.new()
	meter_bg.color = Art.c("black")
	meter_bg.position = Vector2(170, 12)
	meter_bg.size = Vector2(METER_W + 2, 7)
	add_child(meter_bg)
	var meter_in := ColorRect.new()
	meter_in.color = Art.c("navy")
	meter_in.position = Vector2(171, 13)
	meter_in.size = Vector2(METER_W, 5)
	add_child(meter_in)
	_meter_fill = ColorRect.new()
	_meter_fill.position = Vector2(171, 13)
	_meter_fill.size = Vector2(0, 5)
	add_child(_meter_fill)
	# Ticks where the cash multiplier steps up.
	for i in [1, 2, 3]:
		var tick := ColorRect.new()
		tick.color = Art.c("black")
		tick.position = Vector2(171 + METER_W * i * Ratings.TIER / Ratings.MAX, 13)
		tick.size = Vector2(1, 5)
		add_child(tick)
	_mult = Art.label("", Art.c("gold"))
	_mult.position = Vector2(246, 2)
	add_child(_mult)
	_viewers = Art.label("", Art.c("steel"))
	_viewers.position = Vector2(246, 11)
	add_child(_viewers)

	_boss_ui = Control.new()
	_boss_ui.visible = false
	add_child(_boss_ui)
	_boss_name = Art.label("", Art.c("magenta"))
	_boss_name.position = Vector2(6, 33)
	_boss_ui.add_child(_boss_name)
	var boss_bg := ColorRect.new()
	boss_bg.color = Art.c("black")
	boss_bg.position = Vector2(6, 43)
	boss_bg.size = Vector2(152, 6)
	_boss_ui.add_child(boss_bg)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Art.c("magenta")
	_boss_fill.position = Vector2(7, 44)
	_boss_fill.size = Vector2(150, 4)
	_boss_ui.add_child(_boss_fill)

	_cancel = Art.label("", Art.c("red"))
	_cancel.size = Vector2(320, 9)
	_cancel.position = Vector2(0, 52)
	_cancel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_cancel)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = Vector2(320, 180)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	_pause = Control.new()
	_pause.visible = false
	add_child(_pause)
	var dim := ColorRect.new()
	dim.color = Color(Art.c("black"), 0.7)
	dim.size = Vector2(320, 180)
	_pause.add_child(dim)
	var pl := Art.label("PAUSED", Art.c("gold"), 2)
	pl.size = Vector2(320, 16)
	pl.position = Vector2(0, 62)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause.add_child(pl)
	var help := Art.label("WE'LL BE RIGHT BACK AFTER THESE MESSAGES.\n\nARROWS/WASD MOVE   SPACE/Z JUMP   X/J SHOOT\nUP/E DOORS+SWITCHES   C/L DRONE FLASH\nDOWN: DROP THROUGH GRATES   F FULLSCREEN\nM MUSIC ON/OFF   N NARRATION ON/OFF\n\nESC: RESUME     Q: QUIT TO TITLE", Art.c("steel"))
	help.size = Vector2(320, 80)
	help.position = Vector2(0, 82)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause.add_child(help)

	Ratings.bumped.connect(_on_bump)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	if Input.is_action_just_pressed("pause"):
		get_tree().paused = not get_tree().paused
		_pause.visible = get_tree().paused
	if get_tree().paused:
		if Input.is_key_pressed(KEY_Q):
			get_tree().paused = false
			GameState.main.show_title()
		return
	_refresh()


func _refresh() -> void:
	for i in _hearts.size():
		_hearts[i].texture = Art.frame("ui", Vector2i(8, 8), 0 if i < GameState.health else 1)
		# Low health: the last hearts throb.
		_hearts[i].modulate = Color(1.6, 1.6, 1.6) if GameState.health <= 2 and i < GameState.health and fmod(_t, 0.5) < 0.25 else Color.WHITE
	_points.text = "$%d" % GameState.points
	_fire.text = "ZAP x%d" % GameState.firepower
	for i in 3:
		_keys[i].visible = GameState.keys.has(["red", "blue", "yellow"][i])
	if level and is_instance_valid(level.boom):
		var c: float = level.boom.charge()
		_boom_bar.size.x = 32.0 * c
		_boom_bar.color = Art.c("cyan") if c >= 1.0 else Art.c("teal")
	var v := Ratings.value
	_meter_fill.size.x = METER_W * v / Ratings.MAX
	_meter_fill.color = Art.c("red") if v < Ratings.BORED_BELOW else Art.c("gold") if v < 70.0 else Art.c("lime")
	if v >= 85.0 and fmod(_t, 0.2) < 0.1:
		_meter_fill.color = Art.c("white")
	_viewers.text = Ratings.viewers() + " VIEWERS"
	var m := Ratings.multiplier()
	_mult.text = "CASH X%d" % m
	_mult.add_theme_color_override("font_color", [Art.c("metal"), Art.c("steel"), Art.c("gold"), Art.c("lime")][m - 1])
	if Ratings.cancel_t > 0.0:
		var left := ceili(Ratings.CANCEL_AFTER - Ratings.cancel_t)
		_cancel.text = "NO ONE IS WATCHING! CANCELED IN %d..." % left
		_cancel.visible = fmod(_t, 0.4) < 0.28
	else:
		_cancel.visible = false
	var boss: Boss = level.boss if level and is_instance_valid(level.boss) else null
	_boss_ui.visible = boss != null and not boss.in_intro()
	if boss:
		_boss_name.text = boss.display_name
		_boss_fill.size.x = 150.0 * boss.health_ratio()
		_boss_fill.color = Art.c("red") if boss.health_ratio() <= 0.5 else Art.c("magenta")
	_live.visible = fmod(_t, 1.0) < 0.6


## The end-of-level card: average rating, grade and the bonus it paid.
func show_report(r: Dictionary) -> void:
	_report = Control.new()
	add_child(_report)
	var panel := ColorRect.new()
	panel.color = Color(Art.c("black"), 0.88)
	panel.position = Vector2(80, 40)
	panel.size = Vector2(160, 76)
	_report.add_child(panel)
	var lines := [
		["RATINGS REPORT", Art.c("magenta")],
		["AVERAGE RATING   %d" % roundi(r.average), Art.c("white")],
		["PEAK RATING      %d" % roundi(r.peak), Art.c("white")],
		["GRADE            %s" % r.grade, Art.c("gold")],
		["NETWORK BONUS    $%d" % r.bonus, Art.c("lime")],
	]
	for i in lines.size():
		var l := Art.label(lines[i][0], lines[i][1])
		l.position = Vector2(88, 46 + i * 13)
		_report.add_child(l)
	var big := Art.label(r.grade, Art.c("gold"), 3)
	big.position = Vector2(214, 82)
	_report.add_child(big)
	_report.modulate.a = 0.0
	create_tween().tween_property(_report, "modulate:a", 1.0, 0.3)
	Sfx.play("achieve")


func flash() -> void:
	_flash.color = Color(1, 1, 1, 0.85)
	var t := create_tween()
	t.tween_property(_flash, "color:a", 0.0, 0.35)


## Floating "+8 STOMP" style labels under the meter.
func _on_bump(amount: int, reason: String) -> void:
	var l := Art.label("%s%d %s" % ["+" if amount >= 0 else "", amount, reason],
		Art.c("lime") if amount >= 0 else Art.c("red"))
	l.size = Vector2(150, 9)
	l.position = Vector2(166, 22 + _pops.size() * 9)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(l)
	_pops.append(l)
	var t := l.create_tween()
	t.tween_interval(0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(func():
		_pops.erase(l)
		l.queue_free())
