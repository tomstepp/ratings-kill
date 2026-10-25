extends Node
## The ratings meter. Stylish play fills it, and it multiplies every dollar
## earned on air (x1 to x4). A full meter triggers a sponsor drop; a meter that
## sits low too long makes the Showrunner spice things up, and on Floors 3 and 4
## an empty meter gets the episode canceled.

signal changed(value: float)
signal bumped(amount: int, reason: String)
signal sponsor_drop
signal boredom
signal canceled
signal tier_changed(mult: int)

const MAX := 100.0
const START := 35.0
const AFTER_DROP := 60.0  # stays at x3 after a drop
const DECAY := 1.6  # per second
const BORED_BELOW := 15.0
const BORED_AFTER := 9.0  # seconds spent low before the penalty
const BORED_COOLDOWN := 18.0
const CLEAN_EVERY := 25.0  # seconds without damage for a CLEAN RUN bonus
const QUIP_WINDOW := 2.5  # take an enemy down this soon after a quip for a bonus
const TIER := 25.0  # every 25 points of meter adds x1 to the cash multiplier
const CANCEL_FROM_FLOOR := 2  # floor index (0-based) where an empty meter cancels you
const CANCEL_AFTER := 6.0  # seconds at zero before the plug is pulled
const CANCEL_BELOW := 1.0
# Average meter over the level -> grade; the bonus scales with the floor.
const GRADES := [[80.0, "S", 1500], [62.0, "A", 1000], [46.0, "B", 600], [30.0, "C", 300], [0.0, "D", 0]]
const GRADE_LINES := {
	"S": "Ratings GOLD! The network is weeping with joy.",
	"A": "Strong numbers! The sponsors are almost smiling.",
	"B": "Solid ratings. Respectable. Forgettable, but respectable.",
	"C": "Mediocre numbers. We'll fix it in post.",
	"D": "Those ratings were a disaster. Back to the break room.",
}

var value := START
var active := false
var drops := 0
var _low_t := 0.0
var _bored_cd := 0.0
var _clean_t := 0.0
var _last_quip := -100.0
var _time := 0.0
var cancel_t := 0.0  # seconds spent at zero (on floors where that matters)
var _sum := 0.0  # meter-seconds this level, for the average
var _level_t := 0.0
var _peak := 0.0
var _tier := 1
var _tier_note_t := -100.0


func _process(delta: float) -> void:
	if not active or get_tree().paused:
		return
	_time += delta
	_level_t += delta
	_sum += value * delta
	# Later floors' audiences are harder to please.
	var decay: float = DECAY * (1.0 + 0.2 * GameState.difficulty()) * (1.0 - 0.3 * GameState.upgrades.hype)
	_set_value(value - decay * delta)
	# Only while there's something on screen worth watching: with every enemy down,
	# the boredom penalty sends in rats instead of the network pulling the plug.
	var has_enemies := not get_tree().get_nodes_in_group("enemies").is_empty()
	if GameState.difficulty() >= CANCEL_FROM_FLOOR and value < CANCEL_BELOW and not _boss_fight() and has_enemies:
		cancel_t += delta
		if cancel_t >= CANCEL_AFTER:
			cancel_t = 0.0
			canceled.emit()
	else:
		cancel_t = 0.0
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
	cancel_t = 0.0
	_sum = 0.0
	_level_t = 0.0
	_peak = value
	_tier = multiplier()
	changed.emit(value)


func stop() -> void:
	active = false
	cancel_t = 0.0


## Cash multiplier from the meter: x1 below 25, up to x4 at 75 and above.
func multiplier() -> int:
	if not active:
		return 1
	return clampi(1 + int(value / TIER), 1, 4)


## How the level went, for the end-of-level ratings report.
func report() -> Dictionary:
	var avg := _sum / _level_t if _level_t > 0.0 else value
	for g in GRADES:
		if avg >= g[0]:
			return {"average": avg, "peak": _peak, "grade": g[1], "drops": drops,
				"bonus": int(g[2] * (1.0 + 0.5 * GameState.difficulty()))}
	return {}


func _boss_fight() -> bool:
	var level = GameState.level
	return level != null and is_instance_valid(level.boss)


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
		add(10, "QUIP COMBO")


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
	_peak = maxf(_peak, value)
	changed.emit(value)
	var m := multiplier()
	if m != _tier:
		var up := m > _tier
		_tier = m
		tier_changed.emit(m)
		if up and active and _time - _tier_note_t > 4.0:
			_tier_note_t = _time
			Showrunner.notice("CASH x%d!" % m)
