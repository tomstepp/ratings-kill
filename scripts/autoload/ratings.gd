extends Node
## The ratings meter. Stylish play fills it; a full meter triggers a sponsor
## drop; a meter that sits low too long makes the Showrunner spice things up.

signal changed(value: float)
signal bumped(amount: int, reason: String)
signal sponsor_drop
signal boredom

const MAX := 100.0
const START := 35.0
const AFTER_DROP := 45.0
const DECAY := 1.6  # per second
const BORED_BELOW := 15.0
const BORED_AFTER := 9.0  # seconds spent low before the penalty
const BORED_COOLDOWN := 18.0
const CLEAN_EVERY := 25.0  # seconds without damage for a CLEAN RUN bonus
const QUIP_WINDOW := 2.5  # kill this soon after a quip for a bonus

var value := START
var active := false
var drops := 0
var _low_t := 0.0
var _bored_cd := 0.0
var _clean_t := 0.0
var _last_quip := -100.0
var _time := 0.0


func _process(delta: float) -> void:
	if not active or get_tree().paused:
		return
	_time += delta
	var decay: float = DECAY * (1.0 - 0.3 * GameState.upgrades.hype)
	_set_value(value - decay * delta)
	_clean_t += delta
	if _clean_t >= CLEAN_EVERY:
		_clean_t = 0.0
		add(10, "CLEAN RUN")
	_bored_cd -= delta
	if value < BORED_BELOW:
		_low_t += delta
		if _low_t >= BORED_AFTER and _bored_cd <= 0.0:
			_low_t = 0.0
			_bored_cd = BORED_COOLDOWN
			boredom.emit()
	else:
		_low_t = 0.0


func start_level() -> void:
	active = true
	value = START
	_low_t = 0.0
	_bored_cd = BORED_COOLDOWN * 0.5
	_clean_t = 0.0
	changed.emit(value)


func stop() -> void:
	active = false


func add(amount: int, reason: String) -> void:
	if not active:
		return
	bumped.emit(amount, reason)
	_set_value(value + amount)
	if value >= MAX:
		drops += 1
		value = AFTER_DROP
		changed.emit(value)
		sponsor_drop.emit()


# ------------------------------------------------------------------ events

func on_kill(how: String, was_stunned: bool) -> void:
	var quip_bonus := _time - _last_quip <= QUIP_WINDOW
	if how == "stomp":
		add(7, "STOMP")
	elif was_stunned:
		add(9, "SHOWBOAT")
	else:
		add(6, "TAKEDOWN")
	if quip_bonus:
		_last_quip = -100.0
		add(10, "QUIP KILL")


func on_stomp_chain(chain: int) -> void:
	if chain >= 2:
		add(6 * chain, "STOMP CHAIN x%d" % chain)


func on_damage() -> void:
	_clean_t = 0.0
	add(-8, "OUCH")


func on_quip() -> void:
	_last_quip = _time


## How many people are watching right now (purely for show).
func viewers() -> String:
	var v := 4000.0 * pow(1.07, value)
	if v >= 1_000_000.0:
		return "%.1fM" % (v / 1_000_000.0)
	return "%dK" % int(v / 1000.0)


func _set_value(v: float) -> void:
	value = clampf(v, 0.0, MAX)
	changed.emit(value)
