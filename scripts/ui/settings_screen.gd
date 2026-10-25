class_name SettingsScreen
extends Screen
## The settings menu, opened from the title screen.


func _ready() -> void:
	backdrop(0.6)
	var menu := SettingsMenu.new()
	menu.closed.connect(func(): GameState.main.show_title())
	add_child(menu)
	scanlines()
