extends Node
## Reads dialogue aloud with the system's built-in text-to-speech voices
## (macOS voices on Mac, the browser's voices on the web). Free, no files.
## Each speaker gets its own voice, pitch and speed.

const STYLE := {
	"showrunner": {"prefer": ["Samantha", "Karen", "Moira", "Google US English", "Aria", "Zira"], "pitch": 1.15, "rate": 1.15},
	# Boom is a small drone: a bright, higher voice, a little louder than the rest.
	"boom": {"prefer": ["Junior", "Kathy", "Google US English", "Zira", "Fred"], "pitch": 1.7, "rate": 1.2, "volume": 100},
	"rex": {"prefer": ["Rocko", "Reed", "Daniel", "Alex", "Tom", "Aaron", "Google UK English Male", "Guy", "David"], "pitch": 0.8, "rate": 1.05},
	"tanya": {"prefer": ["Tessa", "Victoria", "Moira", "Serena", "Google UK English Female", "Sonia", "Libby", "Jenny"], "pitch": 1.05, "rate": 1.2},
}
const VOLUME := 85

var available := false
var _voices := {}
var _dollars := RegEx.create_from_string("\\$(\\d+)")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	available = DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) \
		and ProjectSettings.get_setting("audio/general/text_to_speech", false)
	if available:
		_pick_voices()


## Speak a line. Returns false if narration is off or unavailable.
func speak(text: String, speaker: String, interrupt := false) -> bool:
	if not available or not GameState.narration_on or GameState.voice_vol <= 0:
		return false
	if _voices.is_empty():
		# Browsers load their voice list late, so try again on first use.
		_pick_voices()
		if _voices.is_empty():
			return false
	var style: Dictionary = STYLE[speaker]
	var volume := int(style.get("volume", VOLUME) * GameState.voice_vol / 10.0)
	DisplayServer.tts_speak(_spoken(text), _voices[speaker], volume, style.pitch, style.rate, 0, interrupt)
	return true


## Speak only if nobody else is talking (for Rex's quick quips).
func bark(text: String, speaker: String) -> void:
	if not is_speaking():
		speak(text, speaker)


func is_speaking() -> bool:
	return available and DisplayServer.tts_is_speaking()


func stop() -> void:
	if available:
		DisplayServer.tts_stop()


func _spoken(text: String) -> String:
	var t := text.replace("\n", " ").replace("B0-0M", "Boom")
	return _dollars.sub(t, "$1 dollars", true)


func _pick_voices() -> void:
	var all := DisplayServer.tts_get_voices()
	var english := all.filter(func(v): return String(v.language).begins_with("en"))
	if english.is_empty():
		english = all
	if english.is_empty():
		return
	var used: Array[String] = []
	for speaker in STYLE:
		var chosen := ""
		for pref in STYLE[speaker].prefer:
			for v in english:
				if String(v.name).to_lower().contains(pref.to_lower()) and not used.has(v.id):
					chosen = v.id
					break
			if chosen != "":
				break
		if chosen == "":
			for v in english:
				if not used.has(v.id):
					chosen = v.id
					break
		if chosen == "":
			chosen = english[0].id
		used.append(chosen)
		_voices[speaker] = chosen
