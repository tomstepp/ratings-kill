class_name EndCard
extends Screen
## After a floor's boss: the floor's wrap-up, then on to the break room.
## After the last boss (`final`): the season wrap-up, then back to the title.

var final := true


func _ready() -> void:
	var f := GameState.floor_index()
	backdrop(0.55, GameState.FLOORS[f].tiles)
	var s := GameState.stats
	if final:
		centered("SEASON ONE COMPLETE", 10, Art.c("gold"), 2)
		centered("THE TOWER BELOW HAS BEEN... CANCELED. BY YOU.", 32, Art.c("cyan"))
	else:
		centered("FLOOR %d COMPLETE" % (f + 1), 10, Art.c("gold"), 2)
		centered(GameState.FLOORS[f].name, 32, Art.c("cyan"))
	var lines := [
		"SCORE SO FAR     $%d" % GameState.score,
		"TAKEDOWNS        %d" % s.kills,
		"STOMPS           %d" % s.stomps,
		"SECRETS FOUND    %d" % s.secrets,
		"SPONSOR DROPS    %d" % Ratings.drops,
		"ACHIEVEMENTS     %d / %d" % [Showrunner.unlocked.size(), Showrunner.ACHIEVEMENTS.size()],
		"TIMES CANCELED   %d" % s.deaths,
	]
	if final:
		lines[0] = "FINAL SCORE      $%d" % GameState.score
	for i in lines.size():
		text(lines[i], Vector2(92, 50 + i * 11), Art.c("white"))
	if final:
		centered("THANKS FOR WATCHING. SEASON TWO: PENDING RENEWAL.", 136, Art.c("magenta"))
		centered("PRESS JUMP TO RETURN TO THE TITLE", 158, Art.c("steel"))
	else:
		centered("NEXT: FLOOR %d - %s" % [f + 2, GameState.FLOORS[f + 1].name], 136, Art.c("magenta"))
		centered("PRESS JUMP FOR THE BREAK ROOM", 158, Art.c("steel"))
	scanlines()
	Sfx.music("music_title")
	Showrunner.clear()
	if final:
		Showrunner.say("You beat the finale. The network is... reviewing its options. Congratulations, I suppose. Roll credits!")
	else:
		Showrunner.say(["Floor %d, conquered! Test audiences rated it 'technically watchable'." % (f + 1),
			"Floor %d is in the can! The next floor down is even less up to code." % (f + 1)][f % 2])


func _process(delta: float) -> void:
	super(delta)
	if _t > 1.5 and confirm_pressed():
		set_process(false)
		if final:
			GameState.main.show_title()
		else:
			GameState.main.show_break_room()
