class_name Visits
extends RefCounted
## Visit judgment and the spirit visit state machine (K4 transitions, K5 timings, K7 weights,
## G7 meeting rules, X3 seeds, L6 R1 and R2). Pure logic: the caller passes the time in (whole
## seconds) and gets events back. No Node, no signals. Matches docs/gdd/sim/visit_sim.py.
##
## State keys used (missing keys are created on first write):
##   visits_now {slot: {spirit_id, state, arrived_at, leave_at, visit_seq}}
##   check_seq, next_check_at, cooldown_until, pity, last_r1_at, visit_seq (int)
## Read only here: save_seed, rooms_owned, inventory, placement, food_bowls, collection,
## slot_checkable_at (FoodBowls), slot_placed_at (Placement).
##
## Events: {type: "arrived", slot, spirit_id, visit_seq}
##         {type: "settled", slot, spirit_id, is_new}
##         {type: "left", slot, spirit_id, visit_seq, rarity}

const STATE_ARRIVING: String = "arriving"
const STATE_PLAYING: String = "playing"
## K5 TEMP: appear_s + walk_s + settle_s (0.4 + 0.8 + 0.3). Not in tuning.json.
const ARRIVE_S: float = 1.5
## K7 step 3: attract is multiplied by this when the food is in likes_food.
const LIKED_FOOD_FACTOR: float = 1.2
## K7 step 4: a weight never goes above this many times its base weight.
const WEIGHT_CAP_FACTOR: float = 10.0

var _defs: Defs
var _bowls: FoodBowls


func _init(p_defs: Defs) -> void:
	_defs = p_defs
	_bowls = FoodBowls.new(p_defs)


## Advances all owned toy slots to time now. Per slot, in this order:
## (a) leave when due, (b) arriving -> playing, (c) R1 bookkeeping, (d) judgment.
## Calling it twice with the same now gives no second 'left' event.
func tick(state: Dictionary, now: int, env: Dictionary, visible_room: String, app_open: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for room_id: String in _owned_rooms(state):
		_bowls.sync_checkable_in_room(state, room_id, now)
	for slot_id: String in _toy_slots(state):
		events.append_array(_leave_if_due(state, slot_id, now))
		events.append_array(_settle_if_ready(state, slot_id, now, visible_room, app_open))
		_r1_bookkeeping(state, slot_id, now)
		events.append_array(_judge(state, slot_id, now, env, visible_room, app_open))
	return events


## Forced leave (K4 T5/T6), called when Placement returns force_leave_slot.
## Valid from arriving or playing. Away gives no event and changes nothing (no gift).
func force_leave(state: Dictionary, slot_id: String, now: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if _visit_at(state, slot_id).is_empty():
		return events
	events.append(_leave(state, slot_id, now))
	return events


## Weight of one spirit for one toy, the bowl food and the real weather (K7 steps 2-4). Pure.
## Returns 0.0 for an unknown spirit.
func weight_of(spirit_id: String, toy_id: String, food_id: String, weather: String) -> float:
	var sp: Dictionary = _defs.spirit(spirit_id)
	if sp.is_empty():
		return 0.0
	var base: float = float(sp["weight"])
	var bonus: Dictionary = sp["toy_bonus"]
	var mult: float = float(bonus.get(toy_id, 1.0))
	var food: Dictionary = _defs.food(food_id)
	var attract: float = float(food.get("attract", 1.0))
	var likes_food: Array = sp["likes_food"]
	if likes_food.has(food_id):
		attract *= LIKED_FOOD_FACTOR
	mult *= attract
	var boost: Array = sp["weather_boost"]
	if boost.has(weather):
		mult *= float(sp["weather_bonus"])
	return minf(base * mult, base * WEIGHT_CAP_FACTOR)


# ---------------------------------------------------------------- (a) leave

func _leave_if_due(state: Dictionary, slot_id: String, now: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var visit: Dictionary = _visit_at(state, slot_id)
	if visit.is_empty() or int(visit["leave_at"]) > now:
		return events
	events.append(_leave(state, slot_id, now))
	return events


## Ends the visit at slot_id: spirit cooldown, visit removed (Away at once), next judgment at now + check_s.
func _leave(state: Dictionary, slot_id: String, now: int) -> Dictionary:
	var visits: Dictionary = _sub(state, "visits_now")
	var visit: Dictionary = visits[slot_id]
	var spirit_id: String = str(visit["spirit_id"])
	var visit_seq: int = int(visit.get("visit_seq", 0))
	var cooldowns: Dictionary = _sub(state, "cooldown_until")
	cooldowns[spirit_id] = now + _tuning_int("revisit_cooldown_s")
	visits.erase(slot_id)
	var next_map: Dictionary = _sub(state, "next_check_at")
	next_map[slot_id] = now + _tuning_int("check_s")
	return {"type": "left", "slot": slot_id, "spirit_id": spirit_id, "visit_seq": visit_seq, "rarity": _rarity(spirit_id)}


# ---------------------------------------------------------------- (b) settle

func _settle_if_ready(state: Dictionary, slot_id: String, now: int, visible_room: String, app_open: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var visit: Dictionary = _visit_at(state, slot_id)
	if visit.is_empty() or str(visit["state"]) != STATE_ARRIVING:
		return events
	var hidden: bool = _room_of(slot_id) != visible_room or not app_open
	var elapsed: float = float(now - int(visit["arrived_at"]))
	if not hidden and elapsed < ARRIVE_S:
		return events
	visit["state"] = STATE_PLAYING
	events.append(_settled(state, slot_id, str(visit["spirit_id"])))
	return events


func _settled(state: Dictionary, slot_id: String, spirit_id: String) -> Dictionary:
	return {"type": "settled", "slot": slot_id, "spirit_id": spirit_id, "is_new": not _met(state, spirit_id)}


# ---------------------------------------------------------------- (c) R1

## R1 (L6): a checkable toy slot with no visit gets its next judgment pulled to r1_from + fresh_place_check_s.
## r1_from = the later of 'became checkable' and 'last placed'. A new R1 event is allowed only when
## r1_from is at least fresh_place_cooldown_s after the last R1 applied to this slot. The cooldown is
## measured at the event time (r1_from), so a blocked swap never fires later.
func _r1_bookkeeping(state: Dictionary, slot_id: String, now: int) -> void:
	if not _visit_at(state, slot_id).is_empty() or not _bowls.is_checkable(state, slot_id):
		return
	var checkable_at: Dictionary = _read(state, "slot_checkable_at")
	var placed_at: Dictionary = _read(state, "slot_placed_at")
	var r1_from: int = maxi(int(checkable_at.get(slot_id, now)), int(placed_at.get(slot_id, 0)))
	var last_map: Dictionary = _read(state, "last_r1_at")
	if last_map.has(slot_id):
		var last: int = int(last_map[slot_id])
		if r1_from <= last or r1_from - last < _tuning_int("fresh_place_cooldown_s"):
			return
	var target: int = r1_from + _tuning_int("fresh_place_check_s")
	var next_map: Dictionary = _sub(state, "next_check_at")
	# A check scheduled before r1_from is stale (the slot was not checkable then), so the R1 time wins.
	if next_map.has(slot_id) and int(next_map[slot_id]) >= r1_from:
		next_map[slot_id] = mini(int(next_map[slot_id]), target)
	else:
		next_map[slot_id] = target
	var last_writes: Dictionary = _sub(state, "last_r1_at")
	last_writes[slot_id] = r1_from


# ---------------------------------------------------------------- (d) judgment

func _judge(state: Dictionary, slot_id: String, now: int, env: Dictionary, visible_room: String, app_open: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _visit_at(state, slot_id).is_empty():
		return events
	if now < int(_read(state, "next_check_at").get(slot_id, 0)):
		return events
	if not _bowls.is_checkable(state, slot_id):
		return events
	var check_map: Dictionary = _sub(state, "check_seq")
	var seq: int = int(check_map.get(slot_id, 0)) + 1
	check_map[slot_id] = seq
	var next_map: Dictionary = _sub(state, "next_check_at")
	next_map[slot_id] = now + _tuning_int("check_s")

	var toy_id: String = str(_read(state, "placement").get(slot_id, ""))
	var food_id: String = _bowl_food(state, slot_id)
	var weather: String = str(env.get("weather", ""))
	var is_night: bool = bool(env.get("is_night", false))
	var candidates: Array[Dictionary] = []
	for spirit_id: String in _defs.ids("spirits"):
		if _can_visit(state, spirit_id, toy_id, food_id, weather, is_night, now):
			candidates.append({
				"spirit_id": spirit_id,
				"weight": weight_of(spirit_id, toy_id, food_id, weather),
				"rare": _rarity(spirit_id) == "rare",
			})
	if candidates.is_empty():
		return events

	var chosen: String = _choose(state, candidates, slot_id, seq)
	if chosen == "":
		return events
	# Unmet rare candidates that were passed over (someone came) get one pity point each.
	var pity: Dictionary = _sub(state, "pity")
	for candidate: Dictionary in candidates:
		var sp: String = str(candidate["spirit_id"])
		if bool(candidate["rare"]) and sp != chosen and not _met(state, sp):
			pity[sp] = int(pity.get(sp, 0)) + 1
	events.append_array(_start_visit(state, slot_id, chosen, now, visible_room, app_open))
	return events


## The spirit that comes, or "" when nobody comes. First-meet guarantee, then the weighted draw.
func _choose(state: Dictionary, candidates: Array[Dictionary], slot_id: String, seq: int) -> String:
	var pity: Dictionary = _read(state, "pity")
	var pity_n: int = _tuning_int("pity_n")
	for candidate: Dictionary in candidates:
		var sp: String = str(candidate["spirit_id"])
		if bool(candidate["rare"]) and not _met(state, sp) and int(pity.get(sp, 0)) >= pity_n:
			return sp
	var total: float = 0.0
	for candidate: Dictionary in candidates:
		total += float(candidate["weight"])
	var p_any: float = _tuning_float("p_any")
	var empty_w: float = 0.0
	# R2: with an empty collection nobody is 'nobody', so the empty weight is 0.
	if _any_met(state):
		if p_any <= 0.0:
			return ""
		empty_w = total * (1.0 - p_any) / p_any
	var x: float = DetRng.unit(_save_seed(state), "visit:" + slot_id, seq) * (total + empty_w)
	for candidate: Dictionary in candidates:
		var w: float = float(candidate["weight"])
		if x < w:
			return str(candidate["spirit_id"])
		x -= w
	return ""


func _start_visit(state: Dictionary, slot_id: String, spirit_id: String, now: int, visible_room: String, app_open: bool) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var visit_seq: int = int(state.get("visit_seq", 1))
	state["visit_seq"] = visit_seq + 1
	var sp: Dictionary = _defs.spirit(spirit_id)
	var lo: int = int(sp["stay_min_s"])
	var hi: int = int(sp["stay_max_s"])
	var stay: int = lo + floori(DetRng.unit(_save_seed(state), "stay", visit_seq) * float(hi - lo + 1))
	var visible: bool = _room_of(slot_id) == visible_room and app_open
	var visit_state: String = STATE_ARRIVING if visible else STATE_PLAYING
	var visits: Dictionary = _sub(state, "visits_now")
	visits[slot_id] = {
		"spirit_id": spirit_id,
		"state": visit_state,
		"arrived_at": now,
		"leave_at": now + stay,
		"visit_seq": visit_seq,
	}
	events.append({"type": "arrived", "slot": slot_id, "spirit_id": spirit_id, "visit_seq": visit_seq})
	if not visible:
		events.append(_settled(state, slot_id, spirit_id))
	return events


func _can_visit(state: Dictionary, spirit_id: String, toy_id: String, food_id: String, weather: String, is_night: bool, now: int) -> bool:
	var sp: Dictionary = _defs.spirit(spirit_id)
	if sp.is_empty():
		return false
	var likes: Array = sp["likes_toys"]
	if not likes.has(toy_id):
		return false
	if _visiting(state, spirit_id):
		return false
	var cooldowns: Dictionary = _read(state, "cooldown_until")
	if int(cooldowns.get(spirit_id, 0)) > now:
		return false
	var time_gate: String = str(sp["time"])
	if time_gate == "day" and is_night:
		return false
	if time_gate == "night" and not is_night:
		return false
	var weather_gate: Array = sp["weather"]
	if not weather_gate.is_empty() and not weather_gate.has(weather):
		return false
	if sp["requires_food"] != null and str(sp["requires_food"]) != food_id:
		return false
	return true


# ---------------------------------------------------------------- helpers

func _visiting(state: Dictionary, spirit_id: String) -> bool:
	for visit_value: Variant in _read(state, "visits_now").values():
		var visit: Dictionary = visit_value
		if str(visit["spirit_id"]) == spirit_id:
			return true
	return false


func _visit_at(state: Dictionary, slot_id: String) -> Dictionary:
	var visits: Dictionary = _read(state, "visits_now")
	var found: Variant = visits.get(slot_id, {})
	if typeof(found) == TYPE_DICTIONARY:
		return found
	return {}


func _bowl_food(state: Dictionary, slot_id: String) -> String:
	var bowl_slot: String = _bowls.bowl_slot_of_room(_room_of(slot_id))
	var bowl: Dictionary = _read(state, "food_bowls").get(bowl_slot, {})
	return str(bowl.get("food_id", ""))


func _met(state: Dictionary, spirit_id: String) -> bool:
	var entry: Variant = _read(state, "collection").get(spirit_id, {})
	return typeof(entry) == TYPE_DICTIONARY and (entry as Dictionary).has("first_seen_at")


func _any_met(state: Dictionary) -> bool:
	for spirit_id: Variant in _read(state, "collection").keys():
		if _met(state, str(spirit_id)):
			return true
	return false


func _owned_rooms(state: Dictionary) -> Array[String]:
	var owned: Array = state.get("rooms_owned", [])
	var out: Array[String] = []
	for room_id: String in _defs.ids("rooms"):
		if owned.has(room_id):
			out.append(room_id)
	return out


func _toy_slots(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for room_id: String in _owned_rooms(state):
		var slots: Array = _defs.room(room_id).get("slots", [])
		for slot_value: Variant in slots:
			var slot: Dictionary = slot_value
			if slot.get("accepts") == "toy":
				out.append(str(slot.get("slot_id", "")))
	return out


func _room_of(slot_id: String) -> String:
	return str(_defs.slot(slot_id).get("room_id", ""))


func _rarity(spirit_id: String) -> String:
	return str(_defs.spirit(spirit_id).get("rarity", ""))


func _save_seed(state: Dictionary) -> int:
	return int(state.get("save_seed", 0))


func _tuning_int(key: String) -> int:
	return int(_defs.tuning().get(key, 0))


func _tuning_float(key: String) -> float:
	return float(_defs.tuning().get(key, 0.0))


## state[key] as a Dictionary, created when missing (for writes).
static func _sub(state: Dictionary, key: String) -> Dictionary:
	if typeof(state.get(key)) != TYPE_DICTIONARY:
		state[key] = {}
	var out: Dictionary = state[key]
	return out


## state[key] as a Dictionary, or {} when missing (for reads; never creates the key).
static func _read(state: Dictionary, key: String) -> Dictionary:
	var value: Variant = state.get(key)
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}
