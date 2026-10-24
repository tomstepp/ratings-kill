class_name TriggerZone
extends Area2D
## One-shot zone: a secret area or a Showrunner hint. Origin is the tile center.

var kind := "hint"  # "hint" or "secret"
var text := ""
var _fired := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 32) if kind == "hint" else Vector2(16, 16)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if _fired or not body is Rex:
		return
	_fired = true
	if kind == "secret":
		GameState.stat("secrets")
		GameState.add_points(250)
		Ratings.add(25, "SECRET!")
		Sfx.play("cheer")
		GameState.level.float_text(global_position + Vector2(0, -16), "SECRET! $250", Art.c("lime"))
		(body as Rex).quip("secret", true)
		Showrunner.say(["A secret area! The audience adores a snoop.", "Ooh, off-script! Legal is typing furiously.",
			"You found the crew's hiding spot. They'll be thrilled."].pick_random())
	elif text != "":
		var parts := text.split("|", true, 1)
		if parts.size() == 2:
			Showrunner.say(parts[1].strip_edges(), parts[0].strip_edges())
		else:
			Showrunner.say(text)
