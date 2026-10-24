class_name LicenseText
extends RefCounted
## The Godot Engine license and its third-party notices, as plain text. Shown
## in the credits and written to licenses.txt for the website
## (tools/dump_licenses.gd).


static func full() -> String:
	var out := PackedStringArray()
	out.append("THIS GAME USES THE GODOT ENGINE, AVAILABLE UNDER THE FOLLOWING LICENSE:")
	out.append("")
	out.append(Engine.get_license_text())
	out.append("")
	out.append("GODOT ENGINE THIRD-PARTY COMPONENTS:")
	out.append("")
	for comp in Engine.get_copyright_info():
		if comp.name == "Godot Engine":
			continue
		for part in comp.parts:
			out.append("%s - %s" % [comp.name, part.license])
			for c in part.copyright:
				out.append("  (C) " + c)
	out.append("")
	out.append("LICENSE TEXTS:")
	var info := Engine.get_license_info()
	for name in info:
		out.append("")
		out.append("--- " + name + " ---")
		out.append(info[name])
	return "\n".join(out)
