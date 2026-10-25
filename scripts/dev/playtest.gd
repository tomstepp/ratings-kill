extends Node
## Automated mechanics checks. Run:
##   godot --headless --path . -- --test
## Prints PASS/FAIL per check and exits non-zero on failure.

var _fails := 0
var level: Level
var rex: Rex


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.save_path = "user://playtest_save.cfg"
	GameState.skip_cards = true
	get_tree().create_timer(480.0).timeout.connect(func():
		print("PLAYTEST TIMED OUT")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	await _jump_checks()
	await _combat_checks()
	await _world_checks()
	await _show_checks()
	await _phase4_checks()
	await _season_checks()
	print("PLAYTEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func check(name: String, ok: bool, detail := "") -> void:
	if not ok:
		_fails += 1
	print("%s  %s %s" % ["PASS" if ok else "FAIL", name, detail])


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Fresh copy of level 1 with nothing but floor around Rex.
func fresh_level() -> void:
	GameState.new_game()
	await frames(3)
	level = GameState.level
	rex = level.rex
	Showrunner.clear()
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await frames(2)


func place_rex(cell: Vector2i) -> void:
	rex.global_position = Vector2(cell.x * 16 + 8, cell.y * 16 + 16)
	rex.velocity = Vector2.ZERO
	await frames(4)


func release_all() -> void:
	for a in ["move_left", "move_right", "jump", "shoot", "interact", "drone", "move_down"]:
		Input.action_release(a)


# ------------------------------------------------------------------ jumping

func _jump_checks() -> void:
	await fresh_level()
	await place_rex(Vector2i(4, 19))
	check("rex starts on floor", rex.is_on_floor())

	var y0 := rex.global_position.y
	Input.action_press("jump")
	var apex := y0
	for i in 60:
		await frames(1)
		apex = minf(apex, rex.global_position.y)
	Input.action_release("jump")
	var full := y0 - apex
	check("full jump clears 3 tiles", full >= 48.0 and full < 64.0, "(%.1f px)" % full)
	await frames(30)

	y0 = rex.global_position.y
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	apex = y0
	for i in 40:
		await frames(1)
		apex = minf(apex, rex.global_position.y)
	var short := y0 - apex
	check("tap jump is lower (variable height)", short < full * 0.6, "(%.1f px)" % short)
	await frames(30)

	# Run-up: top speed takes a moment.
	Input.action_press("move_right")
	await frames(4)
	var early := rex.velocity.x
	await frames(20)
	var later := rex.velocity.x
	Input.action_release("move_right")
	check("run has momentum", early < later * 0.6 and later >= Rex.RUN_SPEED * 0.95, "(%.0f -> %.0f)" % [early, later])
	await frames(30)

	# Coyote time: walk off the step edge at x=33 (floor row 18) and jump late.
	await place_rex(Vector2i(32, 17))
	Input.action_press("move_left")
	await frames(2)
	Input.action_release("move_left")
	await place_rex(Vector2i(33, 17))
	Input.action_press("move_right")
	var left_floor := false
	for i in 40:
		await frames(1)
		if not rex.is_on_floor():
			left_floor = true
			break
	await frames(3)
	Input.action_press("jump")
	await frames(2)
	var vy := rex.velocity.y
	release_all()
	check("coyote jump after leaving ledge", left_floor and vy < -200.0, "(vy %.0f)" % vy)
	await frames(60)

	# Jump buffer: press jump just before landing.
	await place_rex(Vector2i(8, 15))
	rex.global_position.y -= 0.0
	var buffered := false
	for i in 90:
		await frames(1)
		var floor_y := 320.0
		if not rex.is_on_floor() and rex.velocity.y > 0.0 and floor_y - rex.global_position.y < 8.0:
			Input.action_press("jump")
			await frames(6)
			buffered = rex.velocity.y < -150.0
			break
	release_all()
	check("buffered jump fires on landing", buffered)
	await frames(60)


# ------------------------------------------------------------------ combat

func _combat_checks() -> void:
	await fresh_level()
	await place_rex(Vector2i(17, 19))
	var rat := RatDrone.new()
	rat.position = Vector2(17 * 16 + 8 + 56, 20 * 16)
	level.add_child(rat)
	await frames(3)
	rex.facing = 1
	Input.action_press("shoot")
	await frames(40)
	Input.action_release("shoot")
	await frames(30)
	check("held fire kills a rat drone (2 hits)", not is_instance_valid(rat) or rat.dead)

	# Holding fire into empty air: one short burst, then nothing until re-pressed.
	await frames(30)
	var shots0: int = GameState.stats.shots
	Input.action_press("shoot")
	await frames(90)
	Input.action_release("shoot")
	var burst: int = GameState.stats.shots - shots0
	check("held fire stops after a burst", burst == Rex.BURST, "(%d shots)" % burst)
	await frames(2)
	Input.action_press("shoot")
	await frames(2)
	Input.action_release("shoot")
	check("re-pressing fire shoots again", GameState.stats.shots > shots0 + burst)

	# Hits refill the burst: holding fire on a tough target keeps shooting.
	await frames(20)
	var tank := RatDrone.new()
	tank.position = Vector2(rex.global_position.x + 40 * rex.facing, rex.global_position.y)
	level.add_child(tank)
	await frames(2)
	tank.hp = 50
	tank.stunned = 99.0
	shots0 = GameState.stats.shots
	Input.action_press("shoot")
	await frames(90)
	Input.action_release("shoot")
	check("hitting enemies keeps the burst going", GameState.stats.shots - shots0 > Rex.BURST + 2,
		"(%d shots)" % (GameState.stats.shots - shots0))
	tank.queue_free()

	# Stomp: drop Rex onto a rat.
	rat = RatDrone.new()
	rat.position = Vector2(21 * 16 + 8, 20 * 16)
	level.add_child(rat)
	await frames(2)
	rex.global_position = rat.global_position + Vector2(0, -40)
	rex.velocity = Vector2(0, 50)
	var bounced := false
	for i in 40:
		await frames(1)
		if rex.velocity.y < -100.0:
			bounced = true
			break
	check("stomp kills rat and bounces", bounced and (not is_instance_valid(rat) or rat.dead))
	await frames(100)

	# Touching a rat from the side hurts.
	GameState.health = 8
	rat = RatDrone.new()
	rat.position = rex.global_position + Vector2(8, 0)
	level.add_child(rat)
	await frames(10)
	check("side contact hurts", GameState.health < 8, "(hp %d)" % GameState.health)
	if is_instance_valid(rat):
		rat.queue_free()
	await frames(90)

	# Stunned enemies are harmless and stompable.
	GameState.health = 8
	var spark := SparkBot.new()
	spark.position = rex.global_position + Vector2(30, 0)
	level.add_child(spark)
	await frames(2)
	rex.boom.cooldown = 0.0
	rex.boom.global_position = rex.global_position + Vector2(0, -30)
	rex.boom.flash()
	await frames(2)
	check("drone flash stuns enemies", spark.stunned > 0.0)
	rex.global_position = spark.global_position + Vector2(0, -40)
	rex.velocity = Vector2(0, 60)
	await frames(30)
	check("stunned spark bot can be stomped", not is_instance_valid(spark) or spark.dead)
	await frames(30)

	# Crate breaks when shot.
	await place_rex(Vector2i(7, 19))
	rex.facing = 1
	var crates_before: int = GameState.stats.crates
	Input.action_press("shoot")
	await frames(2)
	Input.action_release("shoot")
	await frames(30)
	check("shooting a crate breaks it", GameState.stats.crates > crates_before)

	# Spark bot fires at Rex when in range.
	GameState.health = 8
	spark = SparkBot.new()
	spark.position = rex.global_position + Vector2(90, 0)
	level.add_child(spark)
	var saw_bolt := false
	for i in 200:
		await frames(1)
		for n in level.get_children():
			if n is EnemyBolt:
				saw_bolt = true
		if saw_bolt:
			break
	check("spark bot shoots", saw_bolt)
	spark.queue_free()
	await frames(5)


# ------------------------------------------------------------------ world

func _world_checks() -> void:
	await fresh_level()
	# TV block at (15,16): stand under it and jump.
	await place_rex(Vector2i(15, 19))
	var tv: TVBlock
	for n in level.get_children():
		if n is TVBlock and not n.used:
			tv = n
			break
	rex.global_position.x = tv.global_position.x
	Input.action_press("jump")
	await frames(30)
	Input.action_release("jump")
	check("bonking a TV block uses it", tv.used)
	# Its prize slides off the top and comes down to Rex's level (or into his hands).
	rex.global_position.x -= 48.0
	await frames(240)
	var stranded := false
	for n in level.get_children():
		if n is Pickup and absf(n.global_position.x - tv.global_position.x) < 20.0 and n.global_position.y < tv.global_position.y:
			stranded = true
	check("TV block prizes drop off the block", not stranded)
	await frames(40)

	# Lever extends the bridge.
	var lever: Lever
	for n in level.get_children():
		if n is Lever:
			lever = n
	rex.global_position = lever.global_position + Vector2(0, 8)
	await frames(4)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(90)
	check("lever extends solid bridge", lever.on and level.is_solid(Vector2i(40, 18)))

	# Red door blocks without key, opens with it.
	var door: KeyDoor
	for n in level.get_children():
		if n is KeyDoor:
			door = n
	rex.global_position = door.global_position + Vector2(-40, 0)
	await frames(4)
	Input.action_press("move_right")
	await frames(50)
	Input.action_release("move_right")
	check("locked door blocks Rex", rex.global_position.x < door.global_position.x - 8)
	GameState.add_key("red")
	Input.action_press("move_right")
	await frames(70)
	Input.action_release("move_right")
	check("keycard opens door", rex.global_position.x > door.global_position.x + 8)

	# Keycard pickup.
	level.spawn_pickup("key_blue", rex.global_position + Vector2(0, -12))
	await frames(25)
	check("keycard pickup", GameState.keys.has("blue"))

	# Falling into a pit costs health and respawns.
	GameState.health = 8
	await place_rex(Vector2i(30, 19))
	rex.global_position = Vector2(30 * 16, level.kill_y + 10)
	await frames(3)
	check("falling out respawns and hurts", GameState.health == 6 and rex.global_position.y < level.kill_y)
	await frames(90)

	# Electric rail hurts when live.
	GameState.health = 8
	rex.global_position = Vector2(39 * 16 + 8, 21 * 16 - 1)
	await frames(240)
	check("live rail hurts", GameState.health < 8)
	await frames(90)


# ------------------------------------------------------------------ show layer

func _show_checks() -> void:
	await fresh_level()
	await place_rex(Vector2i(19, 19))
	Ratings.add(100, "TEST")
	await frames(5)
	var crate: SponsorCrate
	for n in level.get_children():
		if n is SponsorCrate:
			crate = n
	check("full meter triggers sponsor drop", crate != null and Ratings.value < 60.0)
	var hp_before := GameState.health
	var pts_before := GameState.points
	var fp_before := GameState.firepower
	for i in 360:
		await frames(1)
		if not is_instance_valid(crate):
			break
		rex.global_position.x = crate.global_position.x
	if is_instance_valid(crate):
		print("  crate at %s, rex at %s" % [crate.global_position, rex.global_position])
	check("Rex opens sponsor crate", not is_instance_valid(crate),
		"(hp %d->%d, $%d->%d, gun %d->%d)" % [hp_before, GameState.health, pts_before, GameState.points, fp_before, GameState.firepower])
	check("achievement unlocked for sponsor", Showrunner.unlocked.has("sponsor"))

	var enemies_before := get_tree().get_nodes_in_group("enemies").size()
	var lights_before := 0
	Ratings.boredom.emit()
	await frames(10)
	var lights := 0
	for n in level.get_children():
		if n is StageLight:
			lights += 1
	var spawned := get_tree().get_nodes_in_group("enemies").size() > enemies_before or lights > lights_before
	check("boredom penalty spawns trouble", spawned)
	await frames(120)

	Ratings.value = 50.0
	var drops := Ratings.drops
	for i in 5:
		Ratings.on_kill("stomp", false)
	check("kills raise ratings", Ratings.value > 50.0 or Ratings.drops > drops)

	# Exit completes the level and goes to the break room.
	var exit: ExitDoor
	for n in level.get_children():
		if n is ExitDoor:
			exit = n
	rex.global_position = exit.global_position
	await frames(4)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	for i in 330:
		await frames(1)
	var in_break := false
	for n in GameState.main.get_children():
		if n is BreakRoom:
			in_break = true
	check("exit leads to break room", in_break)


# ------------------------------------------------------------------ phase 4

func open_level(i: int) -> void:
	release_all()
	GameState.new_game()
	await frames(2)
	GameState.start_level(i)
	await frames(3)
	level = GameState.level
	rex = level.rex
	Showrunner.clear()


func find(kind) -> Node:
	for n in level.get_children():
		if is_instance_of(n, kind):
			return n
	return null


func screen_is(kind) -> bool:
	for n in GameState.main.get_children():
		if is_instance_of(n, kind):
			return true
	return false


func use_exit() -> void:
	var exit: ExitDoor = find(ExitDoor)
	rex.global_position = exit.global_position
	await frames(4)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")


## Clear the boss intro, check it fights and takes damage, then finish it off.
func boss_fight(i: int, title: String) -> Boss:
	await open_level(i)
	var boss: Boss = level.boss
	check("%s spawns" % title, boss != null and boss.display_name != "")
	await frames(30)
	check("%s waits during intro" % title, boss.in_intro())
	Showrunner.clear()
	await frames(150)
	check("%s starts fighting" % title, not boss.in_intro())
	return boss


func _phase4_checks() -> void:
	# Lift in Maintenance Shaft (index 1) carries Rex up.
	await open_level(1)
	var lift: Mover
	for n in level.get_children():
		if n is Mover and n.from.x == n.to.x and n.orbit == 0.0:
			lift = n
	rex.global_position = lift.global_position + Vector2(0, -1)
	rex.velocity = Vector2.ZERO
	var y0 := rex.global_position.y
	await frames(240)
	check("lift carries Rex up", rex.global_position.y < y0 - 64.0, "(%.0f -> %.0f)" % [y0, rex.global_position.y])

	# Slider in Fountain Plaza (index 4) carries Rex over the live wiring.
	await open_level(4)
	var slider: Mover
	for n in level.get_children():
		if n is Mover and n.from.y == n.to.y and n.orbit == 0.0:
			slider = n
			break
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	GameState.health = 8
	rex.global_position = slider.global_position + Vector2(0, -1)
	rex.velocity = Vector2.ZERO
	var x0 := rex.global_position.x
	await frames(240)
	check("slider carries Rex across", rex.global_position.x > x0 + 64.0 and GameState.health == 8,
		"(%.0f -> %.0f, hp %d)" % [x0, rex.global_position.x, GameState.health])

	# Fast rats take two hits.
	var rat := RatDrone.new()
	rat.fast = true
	rat.position = Vector2(-1000, -1000)
	level.add_child(rat)
	await frames(2)
	var plain := RatDrone.new()
	plain.position = Vector2(-1100, -1000)
	level.add_child(plain)
	await frames(2)
	check("fast rats are tougher, and Floor 2 grunts tougher than Floor 1's", rat.hp > plain.hp and plain.hp > 2,
		"(fast %d, plain %d)" % [rat.hp, plain.hp])
	rat.shot(rat.hp - 1, null)
	var survived := not rat.dead
	rat.shot(1, null)
	check("fast rat dies on its last hit point", survived and rat.dead)

	# Mister Cheddar ends Floor 1: the floor card, then the break room; the run is saved.
	var boss: Boss = await boss_fight(3, "the Mascot")
	var hp0 := boss.hp
	boss.shot(1, null)
	check("boss takes damage", boss.hp == hp0 - 1)
	boss.shot(boss.hp, null)
	await frames(200)
	check("defeating the boss opens the exit", find(ExitDoor) != null and Showrunner.unlocked.has("mascot"))
	await use_exit()
	await frames(400)
	check("boss exit shows the floor card", screen_is(EndCard))
	check("finishing a floor saves the next one", GameState.saved_level() == 4)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(5)
	check("floor card leads to the break room", screen_is(BreakRoom))

	# Save and continue: finish level 1, then continue into the break room before level 2.
	await open_level(0)
	level.complete()
	await frames(300)
	check("completing a level saves", GameState.saved_level() == 1)
	var pts := GameState.points
	GameState.points = 0
	check("continue restores the run", GameState.continue_game() and GameState.points == pts)
	await frames(5)
	check("continue opens the break room", screen_is(BreakRoom) and GameState.level_index == 0)
	GameState.clear_save()


# ------------------------------------------------------------------ the season

func _season_checks() -> void:
	check("season has 16 episodes", GameState.LEVELS.size() == 16)
	for i in GameState.LEVELS.size():
		if not FileAccess.file_exists(GameState.LEVELS[i]):
			check("level file exists: %s" % GameState.LEVELS[i], false)

	# Title card before a level, then the level itself.
	GameState.new_game()
	await frames(2)
	GameState.skip_cards = false
	GameState.start_level(5)
	await frames(3)
	check("title card shows before a level", screen_is(LevelCard))
	await frames(int(LevelCard.HOLD * 60) + 20)
	check("title card hands off to the level", GameState.level != null and GameState.level.title == "Department Store")
	GameState.skip_cards = true

	# Ratings multiply cash; the end-of-level report pays a bonus.
	await open_level(0)
	Ratings.value = 80.0
	var before := GameState.points
	var paid := GameState.add_points(100, true)
	check("ratings multiply cash (x4 at 80)", Ratings.multiplier() == 4 and paid == 400 and GameState.points == before + 400)
	Ratings.value = 10.0
	check("low ratings pay x1", Ratings.multiplier() == 1)
	var r := Ratings.report()
	check("ratings report grades the level", r.has("grade") and r.has("bonus"))

	# Rats lunge at Rex when he's close and level with them.
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await place_rex(Vector2i(19, 19))
	var lunger := RatDrone.new()
	lunger.dir = 1  # walking away from Rex
	lunger.position = rex.global_position + Vector2(60, 0)
	level.add_child(lunger)
	await frames(20)
	check("rats lunge at a nearby Rex", lunger.dir == -1 and absf(lunger.velocity.x) > lunger.speed * 1.5,
		"(dir %d, vx %.0f)" % [lunger.dir, lunger.velocity.x])
	lunger.queue_free()
	GameState.health = GameState.MAX_HEALTH

	# Corner correction: clipping a ledge corner mid-jump nudges Rex past it.
	var corner := Vector2i(-1, -1)
	for y in range(2, level.height - 4):
		for x in range(2, level.width - 2):
			if corner.x < 0 and level.is_solid(Vector2i(x, y)) and level.is_empty(Vector2i(x + 1, y)) \
					and level.is_empty(Vector2i(x, y + 1)) and level.is_empty(Vector2i(x, y + 2)) and level.is_empty(Vector2i(x, y + 3)) \
					and level.is_empty(Vector2i(x + 1, y + 1)) and level.is_empty(Vector2i(x + 1, y + 2)):
				corner = Vector2i(x, y)
	var edge := (corner.x + 1) * 16.0
	rex.global_position = Vector2(edge + 2.0, (corner.y + 1) * 16.0 + 27.0 + 3.0)
	rex.velocity = Vector2(0, -280)
	await frames(6)
	check("head clipping a corner slides past it", rex.global_position.x >= edge + 5.0 and rex.global_position.y < (corner.y + 1) * 16.0 + 20.0,
		"(corner %s, rex %s)" % [corner, rex.global_position])

	# New enemies all die to blaster fire.
	for kind in [SecurityBot, Mannequin, MicDrone, ExecDrone]:
		var e: Enemy = kind.new()
		e.position = Vector2(-2000, -2000)
		level.add_child(e)
		await frames(2)
		for i in 6:
			e.shot(1, null)
		check("%s can be shot down" % e.get_script().get_global_name(), e.dead)

	# Mannequins freeze while watched and rush you otherwise.
	await open_level(5)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await frames(2)
	var spot := rex.global_position
	var m := Mannequin.new()
	m.position = spot + Vector2(50, 0)  # clear of the crate further along
	level.add_child(m)
	rex.facing = 1
	await frames(40)
	var still := absf(m.position.x - (spot.x + 50)) < 1.0
	rex.facing = -1
	await frames(40)
	check("mannequin freezes while watched, moves when not", still and m.position.x < spot.x + 40.0,
		"(still %s, now %.0f, rex facing %d)" % [still, m.position.x - spot.x, rex.facing])

	# Belts carry Rex.
	var belt := Vector2i(-1, -1)
	for y in level.height:
		for x in level.width:
			if belt.x < 0 and level.cell(x, y) == ">" and level.cell(x, y - 1) == "." and level.cell(x + 1, y) == ">":
				belt = Vector2i(x, y)
	m.queue_free()
	rex.global_position = Vector2(belt.x * 16 + 8, belt.y * 16)
	rex.velocity = Vector2.ZERO
	var bx := rex.global_position.x
	await frames(30)
	check("conveyor belts carry Rex", rex.global_position.x > bx + 10.0, "(%.0f -> %.0f)" % [bx, rex.global_position.x])

	# A crane platform carries Rex around (Soundstage 9, index 8).
	await open_level(8)
	var crane: Mover
	for n in level.get_children():
		if n is Mover and n.orbit > 0.0:
			crane = n
	await frames(2)
	GameState.health = 8
	rex.global_position = crane.global_position + Vector2(0, -1)
	rex.velocity = Vector2.ZERO
	var c0 := rex.global_position
	await frames(50)
	check("crane carries Rex", rex.global_position.distance_to(c0) > 20.0 and rex.is_on_floor(), "(%s -> %s)" % [c0, rex.global_position])

	# Spotlight cues drop a stage light.
	var cue: TriggerZone
	for n in level.get_children():
		if n is TriggerZone and n.kind == "spotlight":
			cue = n
			break
	rex.global_position = cue.global_position + Vector2(0, 8)
	await frames(10)
	check("spotlight cue drops a light", find(StageLight) != null)

	# Empty ratings on Floor 3+ cancel the episode.
	await open_level(8)
	var canceled := [false]
	Ratings.canceled.connect(func(): canceled[0] = true, CONNECT_ONE_SHOT)
	Ratings.value = 0.0
	await frames(60 * 7)
	check("an empty meter cancels the episode on floor 3", canceled[0])
	await frames(200)

	# With every enemy down, an empty meter doesn't cancel (boredom takes over instead).
	await open_level(8)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.remove_from_group("enemies")
		e.queue_free()
	await frames(2)
	Ratings.value = 0.0
	await frames(60 * 2)
	check("no cancel countdown on a cleared stage", Ratings.cancel_t == 0.0)

	# Killed grunts come back offscreen.
	var far := Vector2(level.width * 16 - 40, 40)
	level._try_respawn(RatDrone, true, far)
	await frames(2)
	var back := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is RatDrone and e.fast and e.position.distance_to(far) < 32.0:
			back = true
	check("killed grunts respawn offscreen", back)

	# Laser gates hurt while live (Lobby and Security, index 12).
	await open_level(12)
	var gate: LaserGate = find(LaserGate)
	GameState.health = 8
	rex.global_position = Vector2(gate.global_position.x, rex.global_position.y)
	await frames(240)
	check("laser gates hurt", GameState.health < 8)

	# Down alone drops Rex through a grate (the Finale arena, index 15).
	await open_level(15)
	var grate := Vector2i(-1, -1)
	for y in level.height:
		for x in level.width:
			if grate.x < 0 and level.cell(x, y) == "-" and level.cell(x - 1, y) == "-" and level.cell(x + 1, y) == "-":
				grate = Vector2i(x, y)
	rex.global_position = Vector2(grate.x * 16 + 8, grate.y * 16)
	rex.velocity = Vector2.ZERO
	await frames(10)
	var gy := rex.global_position.y
	Input.action_press("move_down")
	await frames(2)
	Input.action_release("move_down")
	await frames(30)
	check("down drops through a grate", rex.global_position.y > gy + 16.0, "(%.0f -> %.0f)" % [gy, rex.global_position.y])

	# The three new bosses.
	for pair in [[7, "the Floor Manager", "manager"], [11, "the Director", "director"]]:
		var b: Boss = await boss_fight(pair[0], pair[1])
		var h0 := b.hp
		b.shot(1, null)
		check("%s takes damage" % pair[1], b.hp == h0 - 1)
		b.shot(b.hp / 2, null)
		await frames(5)
		check("%s enrages below half" % pair[1], b.enraged)
		b.shot(b.hp, null)
		await frames(200)
		check("beating %s opens the exit" % pair[1], find(ExitDoor) != null and Showrunner.unlocked.has(pair[2]))

	# Only the Director himself hurts; his crane seat doesn't.
	var dir_boss: Director = await boss_fight(11, "the Director (contact)")
	dir_boss.mode = Director.Mode.DYING  # hold still for the test
	await frames(2)
	GameState.health = 8
	rex.global_position = dir_boss.global_position + Vector2(18, 0)  # beside the seat, below his body
	rex.velocity = Vector2.ZERO
	rex._invuln = 0.0
	dir_boss.touch_rex(rex, rex.global_position.y, false)
	var seat_safe := GameState.health == 8
	rex.global_position = dir_boss.global_position + Vector2(0, -8)  # right into him
	dir_boss.touch_rex(rex, rex.global_position.y, false)
	check("the Director's crane seat is safe, he isn't", seat_safe and GameState.health < 8, "(hp %d)" % GameState.health)

	var fin: Finale = await boss_fight(15, "the Season Finale")
	var f0 := fin.hp
	fin.mode = Finale.Mode.IDLE
	fin.shot(1, null)
	check("the Finale shrugs off shots while closed", fin.hp == f0)
	fin.mode = Finale.Mode.OPEN
	fin._t = 5.0
	fin.shot(1, null)
	check("the Finale takes damage while open", fin.hp == f0 - 1)
	fin.shot(fin.hp, null)
	await frames(200)
	check("beating the Finale opens the exit", find(ExitDoor) != null and Showrunner.unlocked.has("finale"))
	await use_exit()
	await frames(300)
	check("the last boss ends the season", screen_is(EndCard) and not GameState.has_save())
