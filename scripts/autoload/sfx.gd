extends Node
## Plays the generated sound effects and music loops (tools/gen_audio.py).

const SOUNDS := ["jump", "shoot", "hit", "explode", "stomp", "pickup", "powerup", "key", "hurt", "door",
	"bonk", "blip", "crate", "stun", "switch", "achieve", "drop", "boredom", "death", "buy", "deny", "cheer", "roar"]
const POOL_SIZE := 12
const MUSIC_DB := -8.0

var streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in SOUNDS:
		streams[s] = load("res://assets/audio/%s.wav" % s)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	# Separate buses so the settings menu can set music and sound levels.
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_music.bus = "Music"
	_music.volume_db = MUSIC_DB
	for p in _pool:
		p.bus = "SFX"
	apply_volumes.call_deferred()


func stop_all() -> void:
	for p in _pool + [_music]:
		p.stop()
		p.stream = null
	_music_name = ""


## Settings -> bus levels (volume 0 mutes; M mutes music on its own).
func apply_volumes() -> void:
	_set_bus("Music", GameState.music_vol if GameState.music_on else 0)
	_set_bus("SFX", GameState.sfx_vol)


func _set_bus(bus: String, level: int) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_mute(i, level <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(level / 10.0) if level > 0 else -80.0)


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = streams[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Plays with a little random pitch so repeats don't sound robotic.
func play_varied(sound: String, spread := 0.08, volume_db := 0.0) -> void:
	play(sound, randf_range(1.0 - spread, 1.0 + spread), volume_db)


func music(track: String) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	if track == "":
		_music.stop()
		return
	var s: AudioStreamWAV = load("res://assets/audio/%s.wav" % track)
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2
	_music.stream = s
	_music.play()
