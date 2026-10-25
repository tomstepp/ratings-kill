extends Node
## Root of the game. Swaps between the title, levels, the break room and the end card.

var _current: Node


func _ready() -> void:
	GameState.main = self
	if not OS.get_cmdline_user_args().is_empty():
		add_child(preload("res://scripts/dev/dev_tools.gd").new())
	# Dev shortcuts: godot --path . -- --level=1   (or --screen=break / --screen=end)
	for arg in OS.get_cmdline_user_args():
		if arg == "--test":
			add_child(preload("res://scripts/dev/playtest.gd").new())
			return
		if arg.begins_with("--room="):
			GameState.new_game()
			show_level("res://levels/%s.txt" % arg.get_slice("=", 1))
			return
		if arg.begins_with("--level="):
			GameState.new_game()
			# --firepower=N starts the run with N shots per trigger pull (1-4).
			for other in OS.get_cmdline_user_args():
				if other.begins_with("--firepower="):
					GameState.firepower = clampi(int(other.get_slice("=", 1)), 1, GameState.MAX_FIREPOWER)
			GameState.start_level(int(arg.get_slice("=", 1)))
			return
		if arg == "--screen=break":
			GameState.points = 2500
			_swap(BreakRoom.new())
			return
		if arg == "--screen=credits":
			show_credits()
			return
		if arg == "--screen=end":
			show_end()
			return
		if arg.begins_with("--card="):
			GameState.new_game()
			show_card(int(arg.get_slice("=", 1)))
			return
	show_title()


func _exit_tree() -> void:
	# Release the shared tileset so Godot doesn't report it as leaked at quit.
	Level._tilesets.clear()


func _swap(node: Node) -> void:
	get_tree().paused = false
	if _current:
		_current.queue_free()
	_current = node
	add_child.call_deferred(node)


func show_title() -> void:
	Ratings.stop()
	Showrunner.clear()
	_swap(TitleScreen.new())


func show_level(path: String) -> void:
	var level := Level.new()
	level.load_layout(path)
	_swap(level)


func show_card(i: int) -> void:
	Ratings.stop()
	Showrunner.clear()
	var card := LevelCard.new()
	card.index = i
	_swap(card)


func show_settings() -> void:
	_swap(SettingsScreen.new())


func show_credits() -> void:
	_swap(Credits.new())


func show_break_room() -> void:
	_swap(BreakRoom.new())


## The end of a floor, or with `final` the end of the season.
func show_end(final := true) -> void:
	var card := EndCard.new()
	card.final = final
	_swap(card)
