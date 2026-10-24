class_name EndCard
extends Screen
## Shown after the Floor 1 boss: the season's first "episode" wraps.


func _ready() -> void:
	backdrop(0.55)
	centered("FLOOR 1 COMPLETE", 14, Art.c("gold"), 2)
	centered("THE NETWORK HAS RENEWED YOU FOR... ONE MORE FLOOR.", 36, Art.c("cyan"))
	var s := GameState.stats
	var lines := [
		"FINAL SCORE      $%d" % GameState.score,
		"TAKEDOWNS        %d" % s.kills,
		"STOMPS           %d" % s.stomps,
		"SECRETS FOUND    %d" % s.secrets,
		"SPONSOR DROPS    %d" % Ratings.drops,
		"ACHIEVEMENTS     %d / %d" % [Showrunner.unlocked.size(), Showrunner.ACHIEVEMENTS.size()],
		"TIMES CANCELED   %d" % s.deaths,
	]
	for i in lines.size():
		text(lines[i], Vector2(92, 56 + i * 11), Art.c("white"))
	centered("NEXT SEASON: THE SHOPPING MALL AFTER HOURS", 140, Art.c("magenta"))
	centered("PRESS JUMP TO RETURN TO THE TITLE", 158, Art.c("steel"))
	scanlines()
	Sfx.music("music_title")
	Showrunner.clear()
	Showrunner.say("Floor one, conquered! Test audiences rated it 'technically watchable'. The mall awaits... eventually.")


func _process(delta: float) -> void:
	super(delta)
	if _t > 1.5 and confirm_pressed():
		set_process(false)
		GameState.main.show_title()
