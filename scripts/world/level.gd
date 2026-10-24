class_name Level
extends Node2D
## Builds a playable level from an ASCII layout in levels/*.txt and runs it.
## See levels/README.md for the legend.

const T := 16
const SOLID_CHARS := "#="
# Atlas coords in assets/tiles/<floor>.png (every floor's sheet has the same layout)
const BRICK := Vector2i(0, 0)
const FLOOR_TOP := Vector2i(1, 0)
const FILL := Vector2i(2, 0)
const GRATE := Vector2i(3, 0)
const BRIDGE := Vector2i(4, 0)
const FAKE_BRICK := Vector2i(5, 0)
const BG := Vector2i(6, 0)
const BG_BAND := Vector2i(7, 0)
const PILLAR := Vector2i(8, 0)
const POSTER := Vector2i(9, 0)
const RAIL_OFF := Vector2i(10, 0)
const BELT_LEFT := Vector2i(12, 0)
const BELT_RIGHT := Vector2i(13, 0)
const SOLID_TILES := [BRICK, FLOOR_TOP, FILL, BRIDGE, BELT_LEFT, BELT_RIGHT]
const BELT_SPEED := 55.0
const ATLAS_TILES := 14

static var _tilesets := {}

var title := ""
var rex: Rex
var boss: Boss
var boom: Boom
var hud: Hud
var camera: Camera2D
var kill_y := 0.0
var width := 0
var height := 0

var _grid: Array[String] = []
var _meta := {}
var _hints: Array[String] = []
var _intro: Array[String] = []
var _bridges: Array[Vector2i] = []
var _bg: TileMapLayer
var _terrain: TileMapLayer
var _deco: TileMapLayer
var _fg: TileMapLayer
var _shake := 0.0
var _complete := false
var _boss_exit := Vector2.ZERO


func load_layout(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var in_grid := false
	for raw in text.split("\n"):
		var line := raw.rstrip("\r ")
		if not in_grid:
			if line == "---":
				in_grid = true
			elif line.contains(":") and not line.begins_with(";"):
				var key := line.get_slice(":", 0).strip_edges()
				var value := line.substr(line.find(":") + 1).strip_edges()
				match key:
					"hint":
						_hints.append(value)
					"intro":
						_intro.append(value)
					_:
						_meta[key] = value
		elif line != "":
			_grid.append(line)
	height = _grid.size()
	for row in _grid:
		width = maxi(width, row.length())
	for i in height:
		_grid[i] = _grid[i].rpad(width, ".")
	title = _meta.get("name", "UNTITLED")
	kill_y = height * T + 24.0


## Just the header of a level file (name, floor, music...), without building it.
static func read_header(path: String) -> Dictionary:
	var out := {}
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line == "---":
			break
		if line.contains(":") and not line.begins_with(";"):
			out[line.get_slice(":", 0).strip_edges()] = line.substr(line.find(":") + 1).strip_edges()
	return out


## Which tile sheet this level uses, from its `floor:` header.
func tiles_name() -> String:
	var f := clampi(int(_meta.get("floor", "1")) - 1, 0, GameState.FLOORS.size() - 1)
	return GameState.FLOORS[f].tiles


func _ready() -> void:
	GameState.level = self
	_bg = _make_layer(-10, false)
	_terrain = _make_layer(0, true)
	_deco = _make_layer(1, false)
	_fg = _make_layer(5, false)
	_build_tiles()
	_spawn_entities()

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = width * T
	# Room below the map so the dialogue box never hides Rex near the floor.
	camera.limit_bottom = height * T + 40
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	camera.global_position = rex.global_position
	camera.reset_smoothing.call_deferred()

	hud = Hud.new()
	hud.level = self
	add_child(hud)

	Ratings.start_level()
	Ratings.sponsor_drop.connect(_on_sponsor_drop)
	Ratings.boredom.connect(_on_boredom)
	Ratings.canceled.connect(_on_canceled)
	Sfx.music(_meta.get("music", "music_level"))
	Showrunner.clear()
	for line in _intro:
		var parts := line.split("|", true, 1)
		Showrunner.say(parts[1].strip_edges(), parts[0].strip_edges())
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(rex):
			rex.quip("start", true))


func _exit_tree() -> void:
	# A restarted level replaces this one before we leave, so only clean up if we're current.
	if GameState.level == self:
		GameState.level = null
		Ratings.stop()


func _process(delta: float) -> void:
	if is_instance_valid(rex) and rex.state != Rex.State.DEAD:
		camera.global_position = rex.global_position + Vector2(rex.facing * 28.0, -28.0)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 12.0)
		camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
	else:
		camera.offset = Vector2.ZERO


# ------------------------------------------------------------------ building

static func tileset(sheet := "subway") -> TileSet:
	if _tilesets.has(sheet):
		return _tilesets[sheet]
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 16)
	ts.set_physics_layer_collision_mask(1, 0)
	var src := TileSetAtlasSource.new()
	src.texture = Art.tex[sheet]
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	for i in ATLAS_TILES:
		src.create_tile(Vector2i(i, 0))
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for coords in [BRICK, FLOOR_TOP, FILL, BELT_LEFT, BELT_RIGHT]:
		var td := src.get_tile_data(coords, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
	# Conveyor belts (escalator treads) carry whatever stands on them.
	src.get_tile_data(BELT_LEFT, 0).set_constant_linear_velocity(0, Vector2(-BELT_SPEED, 0))
	src.get_tile_data(BELT_RIGHT, 0).set_constant_linear_velocity(0, Vector2(BELT_SPEED, 0))
	var bridge := src.get_tile_data(BRIDGE, 0)
	bridge.add_collision_polygon(0)
	bridge.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -1), Vector2(-8, -1)]))
	var grate := src.get_tile_data(GRATE, 0)
	grate.add_collision_polygon(1)
	grate.set_collision_polygon_points(1, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -4), Vector2(-8, -4)]))
	grate.set_collision_polygon_one_way(1, 0, true)
	_tilesets[sheet] = ts
	return ts


func _make_layer(z: int, collide: bool) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.tile_set = tileset(tiles_name())
	l.z_index = z
	l.collision_enabled = collide
	add_child(l)
	return l


func cell(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= width or y >= height:
		return "#"
	return _grid[y][x]


func _build_tiles() -> void:
	for y in range(height, height + 3):
		for x in width:
			_bg.set_cell(Vector2i(x, y), 0, FILL)
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			_bg.set_cell(c, 0, _bg_tile(x, y))
			match cell(x, y):
				"#":
					_terrain.set_cell(c, 0, BRICK)
				"=":
					_terrain.set_cell(c, 0, FILL if SOLID_CHARS.contains(cell(x, y - 1)) else FLOOR_TOP)
				"-":
					_terrain.set_cell(c, 0, GRATE)
				"<":
					_terrain.set_cell(c, 0, BELT_LEFT)
				">":
					_terrain.set_cell(c, 0, BELT_RIGHT)
				"F":
					_fg.set_cell(c, 0, FAKE_BRICK)
				"m":
					_bridges.append(c)
	# Electrified rails: group horizontal runs.
	for y in height:
		var run: Array[Vector2i] = []
		for x in width + 1:
			if x < width and cell(x, y) == "z":
				run.append(Vector2i(x, y))
				_deco.set_cell(Vector2i(x, y), 0, RAIL_OFF)
			elif not run.is_empty():
				var rail := ElectricRail.new()
				rail.setup(run.duplicate(), _deco)
				add_child(rail)
				run.clear()
	# Laser gates: group vertical runs of '|'.
	for x in width:
		var beam: Array[Vector2i] = []
		for y in height + 1:
			if y < height and cell(x, y) == "|":
				beam.append(Vector2i(x, y))
			elif not beam.is_empty():
				var gate := LaserGate.new()
				gate.setup(beam.duplicate())
				add_child(gate)
				beam.clear()


func _bg_tile(x: int, y: int) -> Vector2i:
	if x % 13 == 6:
		return PILLAR
	if (x * 7 + y * 3) % 41 == 0:
		return POSTER
	if y % 9 == 5:
		return BG_BAND
	return BG


func _spawn_entities() -> void:
	var hint_i := 0
	for y in height:
		for x in width:
			var ch := cell(x, y)
			var center := Vector2(x * T + 8, y * T + 8)
			var feet := Vector2(x * T + 8, y * T + 16)
			match ch:
				"P":
					rex = Rex.new()
					rex.position = feet
					rex.died.connect(_on_rex_died)
				"R", "r":
					var rat := RatDrone.new()
					rat.fast = ch == "r"
					_add(rat, feet)
				"L", "H":
					_add_mover(x, y, ch == "L")
				"S":
					_add(SparkBot.new(), feet)
				"G":
					_add(SecurityBot.new(), feet)
				"Q":
					_add(Mannequin.new(), feet)
				"D":
					_add(MicDrone.new(), center)
				"N":
					_add(ExecDrone.new(), center)
				"K":
					var crane := Mover.new()
					crane.orbit = 40.0
					crane.from = Vector2(x * T + T, y * T)
					add_child(crane)
				"V":
					var spot := TriggerZone.new()
					spot.kind = "spotlight"
					_add(spot, center)
				"a", "b", "c":
					spawn_pickup({"a": "key_red", "b": "key_blue", "c": "key_yellow"}[ch], center)
				"h":
					spawn_pickup("soda", center)
				"f":
					spawn_pickup("food", center)
				"u":
					spawn_pickup("firepower", center)
				"o":
					spawn_pickup("token", center)
				"A", "B", "C":
					var d := KeyDoor.new()
					d.color = {"A": "red", "B": "blue", "C": "yellow"}[ch]
					_add(d, feet)
				"x":
					_add(Crate.new(), center)
				"?", "*":
					var tv := TVBlock.new()
					tv.contents = "token" if ch == "?" else "firepower"
					_add(tv, center)
				"E":
					_add(ExitDoor.new(), feet)
				"e":
					_boss_exit = feet
				"M":
					match _meta.get("boss", "mascot"):
						"manager":
							boss = FloorManager.new()
						"director":
							boss = Director.new()
						"finale":
							boss = Finale.new()
						_:
							boss = Mascot.new()
					boss.defeated.connect(_on_boss_defeated)
					_add(boss, feet)
				"w":
					_add(Lever.new(), center)
				"$":
					var s := TriggerZone.new()
					s.kind = "secret"
					_add(s, center)
				"T":
					var h := TriggerZone.new()
					h.kind = "hint"
					h.text = _hints[hint_i] if hint_i < _hints.size() else ""
					hint_i += 1
					_add(h, Vector2(center.x, center.y - 8))
	assert(rex != null, "Level has no P (player start)")
	add_child(rex)
	boom = Boom.new()
	boom.rex = rex
	add_child(boom)
	rex.boom = boom


## Lifts ('L') ride up from where they're placed until just below the ceiling,
## or stop level with the highest ledge beside them so Rex can step straight off;
## sliders ('H') ride right until they meet a wall. Both are two tiles wide.
func _add_mover(x: int, y: int, vertical: bool) -> void:
	var m := Mover.new()
	m.from = Vector2(x * T + T, y * T)
	m.to = m.from
	if vertical:
		var r := y - 1
		while r > 0 and _open(x, r) and _open(x + 1, r):
			r -= 1
		var top := mini(y, r + 3)
		for row in range(top, y):
			if _ledge_beside(x, row):
				top = row
				break
		m.to.y = minf(m.from.y, top * T)
	else:
		var c := x + 2
		while c < width and _open(c, y) and _open(c, y - 1) and _open(c, y - 2):
			c += 1
		m.to.x = maxf(m.from.x, (c - 2) * T + T)
	add_child(m)


## A walkable surface whose top is row `row`, within two tiles of a lift at columns x..x+1.
func _ledge_beside(x: int, row: int) -> bool:
	for cx in [x - 2, x - 1, x + 2, x + 3]:
		if "#=-<>".contains(cell(cx, row)) and _open(cx, row - 1) and _open(cx, row - 2):
			return true
	return false


func _open(x: int, y: int) -> bool:
	return not "#=?*xABCF-mL".contains(cell(x, y))


func _add(node: Node2D, pos: Vector2) -> Node2D:
	node.position = pos
	add_child(node)
	return node


# ------------------------------------------------------------------ queries

func _cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / T), floori(pos.y / T))


func is_solid(c: Vector2i) -> bool:
	return _terrain.get_cell_source_id(c) != -1 and _terrain.get_cell_atlas_coords(c) in SOLID_TILES


func is_empty(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return false
	return _terrain.get_cell_source_id(c) == -1


func is_platform_below(feet: Vector2) -> bool:
	var c := _cell_at(feet + Vector2(0, 2))
	return _terrain.get_cell_source_id(c) != -1 and _terrain.get_cell_atlas_coords(c) == GRATE


## Ground Rex can safely respawn on after a fall: solid under both feet, no rail.
func is_safe_ground(feet: Vector2) -> bool:
	if cell(_cell_at(feet + Vector2(0, -2)).x, _cell_at(feet + Vector2(0, -2)).y) == "z":
		return false
	return is_solid(_cell_at(feet + Vector2(-5, 2))) and is_solid(_cell_at(feet + Vector2(5, 2)))


## Highest open cell above `pos`, up to `max_up` tiles (for things dropping in).
func ceiling_above(pos: Vector2, max_up: int) -> Vector2:
	var c := _cell_at(pos)
	var top := c
	for i in max_up:
		var up := Vector2i(c.x, c.y - i - 1)
		if not is_empty(up):
			break
		top = up
	return Vector2(top.x * T + 8, top.y * T + 8)


func floor_below(pos: Vector2) -> float:
	var c := _cell_at(pos)
	for i in 20:
		if is_solid(Vector2i(c.x, c.y + i)):
			return float((c.y + i) * T)
	return kill_y


# ------------------------------------------------------------------ effects

func spawn_pickup(kind: String, pos: Vector2, pop := false) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.position = pos
	add_child.call_deferred(p)
	if pop:
		p.ready.connect(p.pop_out, CONNECT_ONE_SHOT)


func burst(pos: Vector2, color: Color, amount := 10, speed := 70.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 10
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.55
	p.spread = 180.0
	p.direction = Vector2.UP
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.emitting = true
	add_child.call_deferred(p)
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func float_text(pos: Vector2, text: String, color: Color) -> void:
	var l := Art.label(text, color)
	l.z_index = 25
	l.size = Vector2(120, 9)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos - Vector2(60, 4)
	add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", l.position.y - 16.0, 0.8).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	t.tween_callback(l.queue_free)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func flash_screen() -> void:
	hud.flash()


func extend_bridges() -> void:
	Showrunner.say("Bridge extended! Union rules require me to say: mind your step.")
	var t := create_tween()
	for c in _bridges:
		t.tween_callback(func():
			_terrain.set_cell(c, 0, BRIDGE)
			Sfx.play("switch", 1.5, -10.0)
			burst(Vector2(c.x * T + 8, c.y * T + 4), Art.c("gold"), 4, 40.0))
		t.tween_interval(0.08)


# ------------------------------------------------------------------ show events

func _on_sponsor_drop() -> void:
	if _complete or not is_instance_valid(rex) or rex.state == Rex.State.DEAD:
		return
	Showrunner.unlock("sponsor")
	Sfx.play("drop")
	Showrunner.say(["Ratings through the roof! A word from our sponsors...", "The people have spoken, and they want PRODUCT!",
		"Sponsor drop incoming! Smile for the brand partners!"].pick_random(), "showrunner", true)
	var spot := rex.global_position + Vector2(-8, -24)
	for dx in [rex.facing * 40.0, 0.0, -rex.facing * 40.0]:
		var p := rex.global_position + Vector2(dx, -24)
		if is_empty(_cell_at(p)):
			spot = p
			break
	var crate := SponsorCrate.new()
	crate.position = ceiling_above(spot, 6) + Vector2(0, 8)
	add_child(crate)


func _on_boredom() -> void:
	if _complete or not is_instance_valid(rex) or rex.state == Rex.State.DEAD or is_instance_valid(boss):
		return
	Showrunner.unlock("bored")
	Sfx.play("boredom")
	if randf() < 0.5:
		Showrunner.say(["Ratings are flatlining. Let's spice things up! Release the rats!", "Boring! Somebody send in the vermin.",
			"Our test audience fell asleep. Rat delivery!"].pick_random(), "showrunner", true)
		for dx in [-48.0, 48.0]:
			var p := rex.global_position + Vector2(dx, -24)
			if is_empty(_cell_at(p)):
				var r := RatDrone.new()
				r.position = ceiling_above(p, 6) + Vector2(0, 8)
				r.dir = -int(signf(dx))
				add_child(r)
				burst(r.position, Art.c("magenta"), 8, 50.0)
	else:
		Showrunner.say(["Dead air! Lighting department, drop the... I mean, adjust the lights!", "Snooze-fest. Cue the falling lights!",
			"Let's add some drama. Heads up! Or rather, heads DOWN."].pick_random(), "showrunner", true)
		var i := 0
		for dx in [-28.0, 0.0, 28.0]:
			if drop_light(rex.global_position + Vector2(dx + rex.velocity.x * 0.4, -20), i * 0.35):
				i += 1


## Drop a stage light (after a blinking warning) above `p`. False if `p` is inside a wall.
func drop_light(p: Vector2, delay := 0.0) -> bool:
	if not is_empty(_cell_at(p)):
		return false
	var light := StageLight.new()
	light.position = ceiling_above(p, 7)
	light.floor_y = floor_below(p)
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(add_child.bind(light))
	else:
		add_child.call_deferred(light)
	return true


func _on_boss_defeated() -> void:
	Showrunner.unlock(_meta.get("boss", "mascot"))
	Sfx.play("cheer")
	var door := ExitDoor.new()
	door.position = _boss_exit
	door.modulate.a = 0.0
	add_child(door)
	create_tween().tween_property(door, "modulate:a", 1.0, 0.8)
	burst(_boss_exit + Vector2(0, -16), Art.c("lime"), 20, 90.0)
	Showrunner.say(boss_defeat_line(), "showrunner")


func boss_defeat_line() -> String:
	match _meta.get("boss", "mascot"):
		"manager":
			return "Management has been... restructured. The exit's open. Floor two is yours."
		"director":
			return "That's a wrap on the Director. Literally. Floor three is yours, Halloway."
		"finale":
			return "No... no, this isn't how the season ends! ...Roll credits. Fine. FINE."
	return "...Fine. FINE. The exit is open. Floor one is yours, Halloway."


## The meter sat empty too long on a later floor: the network pulls the plug.
func _on_canceled() -> void:
	if _complete or not is_instance_valid(rex) or rex.state == Rex.State.DEAD:
		return
	Showrunner.clear()
	Showrunner.say("We've lost the audience. This episode is CANCELED. Reshoot!", "showrunner", true)
	rex.die(false)


func _on_rex_died() -> void:
	GameState.restart_level()


func complete() -> void:
	if _complete:
		return
	_complete = true
	rex.controls_locked = true
	rex.velocity.x = 0.0
	Ratings.stop()
	Sfx.music("")
	Sfx.play("cheer")
	Sfx.play("powerup")
	if GameState.damage_this_level == 0:
		Showrunner.unlock("untouchable")
	var report := Ratings.report()
	GameState.add_points(report.bonus)
	if report.grade == "S":
		Showrunner.unlock("grade_s")
	hud.show_report(report)
	Showrunner.clear()
	Showrunner.say("That's a wrap on %s! %s" % [title, Ratings.GRADE_LINES[report.grade]])
	var t := create_tween()
	t.tween_property(rex.sprite, "modulate:a", 0.0, 0.6)
	t.tween_interval(3.6)
	t.tween_callback(GameState.level_complete)
