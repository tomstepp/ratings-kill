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
	get_tree().create_timer(300.0).timeout.connect(func():
		print("PLAYTEST TIMED OUT")
		get_tree().quit(2))
	_run.call_deferred()


func _run() -> void:
	await _jump_checks()
	await _combat_checks()
	await _world_checks()
	await _show_checks()
	await _phase4_checks()
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
	await frames(3)
	Input.action_release("shoot")
	await frames(30)
	check("shot kills a rat drone", not is_instance_valid(rat) or rat.dead)

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
	await frames(60)
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
	for i in 240:
		await frames(1)
	var in_break := false
	for n in GameState.main.get_children():
		if n is BreakRoom:
			in_break = true
	check("exit leads to break room", in_break)


# ------------------------------------------------------------------ phase 4

func open_level(i: int) -> void:
	GameState.new_game()
	await frames(2)
	GameState.start_level(i)
	await frames(3)
	level = GameState.level
	rex = level.rex
	Showrunner.clear()


func _phase4_checks() -> void:
	# Lift in level 3 (index 2) carries Rex up.
	await open_level(2)
	var lift: Mover
	for n in level.get_children():
		if n is Mover and n.from.x == n.to.x:
			lift = n
	rex.global_position = lift.global_position + Vector2(0, -1)
	rex.velocity = Vector2.ZERO
	var y0 := rex.global_position.y
	await frames(240)
	check("lift carries Rex up", rex.global_position.y < y0 - 64.0, "(%.0f -> %.0f)" % [y0, rex.global_position.y])

	# Slider in level 4 (index 3) carries Rex sideways over the rails.
	await open_level(3)
	var slider: Mover
	for n in level.get_children():
		if n is Mover and n.from.y == n.to.y:
			slider = n
			break
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
	rat.shot(1, null)
	var survived := not rat.dead
	rat.shot(1, null)
	check("fast rat takes two hits", survived and rat.dead)

	# Boss: intro holds, damage works, defeat opens the exit, exit ends the floor.
	await open_level(GameState.LEVELS.size() - 1)
	var boss: Mascot = level.boss
	check("boss level spawns the Mascot", boss != null)
	await frames(30)
	check("boss waits during intro", boss.mode == Mascot.Mode.INTRO)
	Showrunner.clear()
	await frames(120)
	check("boss starts fighting after intro", boss.mode != Mascot.Mode.INTRO)
	var hp0 := boss.hp
	boss.shot(1, null)
	check("boss takes damage", boss.hp == hp0 - 1)
	boss.shot(boss.hp, null)
	await frames(200)
	var exit: ExitDoor
	for n in level.get_children():
		if n is ExitDoor:
			exit = n
	check("defeating the boss opens the exit", exit != null and Showrunner.unlocked.has("mascot"))
	rex.global_position = exit.global_position
	await frames(4)
	Input.action_press("interact")
	await frames(2)
	Input.action_release("interact")
	await frames(240)
	var at_end := false
	for n in GameState.main.get_children():
		if n is EndCard:
			at_end = true
	check("boss exit ends the floor", at_end)
	check("finishing the floor clears the save", not GameState.has_save())

	# Save and continue: finish level 1, then continue into the break room before level 2.
	await open_level(0)
	level.complete()
	await frames(200)
	check("completing a level saves", GameState.saved_level() == 1)
	var pts := GameState.points
	GameState.points = 0
	check("continue restores the run", GameState.continue_game() and GameState.points == pts)
	await frames(5)
	var in_break := false
	for n in GameState.main.get_children():
		if n is BreakRoom:
			in_break = true
	check("continue opens the break room", in_break and GameState.level_index == 0)
	GameState.clear_save()
