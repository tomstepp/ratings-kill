extends SceneTree
## Writes the Godot license and third-party notices next to the web build.
## Run: Godot --headless --path . --script tools/dump_licenses.gd


func _init() -> void:
	var f := FileAccess.open("res://build/web/licenses.txt", FileAccess.WRITE)
	f.store_string("SUPER REX LIVE! - A GAME BY TOM STEPP\n\n" + LicenseText.full() + "\n")
	f.close()
	print("wrote build/web/licenses.txt")
	quit()
