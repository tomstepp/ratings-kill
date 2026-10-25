class_name Screen
extends Node2D
## Shared bits for full-screen menus: a tiled backdrop, scanlines, labels.

var _t := 0.0


func backdrop(dim := 0.45, tiles := "subway") -> void:
	var bg := TileMapLayer.new()
	bg.tile_set = Level.tileset(tiles)
	for y in 12:
		for x in 20:
			bg.set_cell(Vector2i(x, y), 0, Level.BG_BAND if y % 9 == 5 else Level.PILLAR if x % 13 == 6 else Level.BG)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(Art.c("black"), dim)
	shade.size = Vector2(320, 180)
	add_child(shade)


func scanlines() -> void:
	for y in range(0, 180, 3):
		var line := ColorRect.new()
		line.color = Color(0, 0, 0, 0.12)
		line.position = Vector2(0, y)
		line.size = Vector2(320, 1)
		line.z_index = 50
		add_child(line)


func text(t: String, pos: Vector2, color := Color("f4f1e8"), scale := 1, width := 0.0) -> Label:
	var l := Art.label(t, color, scale)
	l.position = pos
	if width > 0.0:
		l.size = Vector2(width, 8 * scale)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(l)
	return l


## A line centered on screen. Placed by hand (every glyph is 6px wide at scale 1):
## Label's own centering misjudges long lines of the pixel font. Text changed
## later is re-centered.
func centered(t: String, y: float, color := Color("f4f1e8"), scale := 1) -> Label:
	var l := text(t, Vector2(0, y), color, scale)
	var place := func(): l.position.x = floorf((320 - l.text.length() * 6 * scale) / 2.0)
	place.call()
	l.item_rect_changed.connect(place)
	return l


func confirm_pressed() -> bool:
	return _t > 0.5 and (Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("shoot")
		or Input.is_key_pressed(KEY_ENTER))


func _process(delta: float) -> void:
	_t += delta
