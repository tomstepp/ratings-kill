extends Node
## Loads the generated art and builds animations and the pixel font.
## Every texture comes from tools/gen_art.py; re-run it after changing art.

const PALETTE := {
	"black": Color("0b0b14"), "navy": Color("141b33"), "midnight": Color("263258"),
	"metal": Color("5a6488"), "steel": Color("b3bbd9"), "white": Color("f6f1e7"),
	"gold": Color("f2c14e"), "terracotta": Color("d98a4a"), "red": Color("e0473f"),
	"rust": Color("8a4b2f"), "pine": Color("3f7d6a"), "lime": Color("8fd14f"),
	"teal": Color("2c6e85"), "cyan": Color("66d6e8"), "magenta": Color("c75bb0"),
	"peach": Color("f0b08c"),
}

var tex := {}
var font: FontFile


func _ready() -> void:
	for name in ["rex", "boom", "rat", "spark", "bolt", "enemy_bolt", "pickups", "keycards", "crate",
			"tvblock", "doors", "switch", "sponsor_crate", "chute", "stage_light", "portraits", "ui", "lift", "mascot", "shockwave", "bomb"]:
		tex[name] = load("res://assets/sprites/%s.png" % name)
	tex["subway"] = load("res://assets/tiles/subway.png")
	font = _build_font()


func c(name: String) -> Color:
	return PALETTE[name]


## Cut a region out of a sheet.
func region(sheet: String, rect: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex[sheet]
	a.region = rect
	return a


## Frame `i` of a horizontal strip of `size`-sized frames.
func frame(sheet: String, size: Vector2i, i: int) -> AtlasTexture:
	return region(sheet, Rect2(i * size.x, 0, size.x, size.y))


## anims: {name: [frame indices, fps, loop]}
func frames(sheet: String, size: Vector2i, anims: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in anims:
		var spec: Array = anims[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, spec[1])
		sf.set_animation_loop(anim, spec[2])
		for i in spec[0]:
			sf.add_frame(anim, frame(sheet, size, i))
	return sf


func _build_font() -> FontFile:
	var img: Image = (load("res://assets/fonts/pixel5x7.png") as Texture2D).get_image()
	var f := FontFile.new()
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.fixed_size = 8
	f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var sz := Vector2i(8, 0)
	f.set_texture_image(0, sz, 0, img)
	f.set_cache_ascent(0, 8, 7)
	f.set_cache_descent(0, 8, 1)
	for code in range(32, 96):
		var i := code - 32
		var uv := Rect2((i % 16) * 6, (i / 16) * 8, 5, 7)
		_add_glyph(f, sz, code, uv)
		# Lowercase renders with the uppercase glyphs.
		if code >= 65 and code <= 90:
			_add_glyph(f, sz, code + 32, uv)
	return f


func _add_glyph(f: FontFile, sz: Vector2i, code: int, uv: Rect2) -> void:
	f.set_glyph_advance(0, 8, code, Vector2(6, 0))
	f.set_glyph_offset(0, sz, code, Vector2(0, -7))
	f.set_glyph_size(0, sz, code, Vector2(5, 7))
	f.set_glyph_uv_rect(0, sz, code, uv)
	f.set_glyph_texture_idx(0, sz, code, 0)


## A Label using the pixel font. Scale 2 doubles the font size.
func label(text: String, color := Color("f4f1e8"), scale := 1) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 8 * scale)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color("0b0b14"))
	l.add_theme_constant_override("shadow_offset_x", 1 * scale)
	l.add_theme_constant_override("shadow_offset_y", 1 * scale)
	l.add_theme_constant_override("line_spacing", 1)
	return l
