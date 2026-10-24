class_name TriggerZone
extends Area2D
## A zone Rex walks into: a secret area or a Showrunner hint (both one-shot), or
## a spotlight cue on the backlot that drops a stage light as he passes (re-arms).
## Origin is the tile center.

const SPOT_REARM := 3.5

var kind := "hint"  # "hint", "secret" or "spotlight"
var text := ""
var _fired := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = {"hint": Vector2(16, 32), "spotlight": Vector2(16, 64)}.get(kind, Vector2(16, 16))
	if kind == "spotlight":
		shape.position.y = -24.0
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if _fired or not body is Rex:
		return
	_fired = true
	if kind == "spotlight":
		var rex := body as Rex
		GameState.level.drop_light(rex.global_position + Vector2(rex.velocity.x * 0.45, -20))
		get_tree().create_timer(SPOT_REARM).timeout.connect(func(): _fired = false)
		return
	if kind == "secret":
		GameState.stat("secrets")
		Ratings.add(25, "SECRET!")
		var paid := GameState.add_points(250, true)
		Sfx.play("cheer")
		GameState.level.float_text(global_position + Vector2(0, -16), "SECRET! $%d" % paid, Art.c("lime"))
		(body as Rex).quip("secret", true)
		Showrunner.say(["A secret area! The audience adores a snoop.", "Ooh, off-script! Legal is typing furiously.",
			"You found the crew's hiding spot. They'll be thrilled."].pick_random())
	elif text != "":
		var parts := text.split("|", true, 1)
		if parts.size() == 2:
			Showrunner.say(parts[1].strip_edges(), parts[0].strip_edges())
		else:
			Showrunner.say(text)
