class_name CatchUp
extends RefCounted
## Replays the time the app was closed (X11, F9 flow 1, F1 catch_up). The same rules as the open app
## run again in time order, with the app closed (app_open = false, visible_room = "").
## Pure logic: the caller passes now, the environment clock and the UTC offset in. No Node, no signals.
##
## run() steps. All state writes happen after the inputs are checked, so a bad call changes nothing:
##   1. elapsed = now - last_seen.
##      last_seen == 0 (new game): set last_seen = now, no events.
##      elapsed < 0 (clock set back): set last_seen = now, clock_back = true, nothing else.
##      otherwise the window is min(elapsed, tuning.offline_cap_s) long and ends at now.
##   2. last_seen = now, before the replay (duplicate guard: a second call sees elapsed 0).
##   3. Replay from the window start to now. Before each tick at t, every owned bowl is advanced
##      from cur to t (spirits present at cur, app closed), then Visits.tick runs at t.
##      Event times: the smallest next_check_at or leave_at after cur, and now.
##
## Due times (at or before the window start) are handled by one tick at the window start. Later due
## times are not event times: a due check that Visits does not act on (the slot is visited, or it is
## not checkable) does nothing, and counting it as due now would force zero-length steps and move
## the checks of other slots late. Every event time is after cur, and now is always a candidate, so
## each round moves time forward and the last round lands on now.
##
## State keys read and written: last_seen, plus everything Visits and FoodBowls use.

var _defs: Defs
var _visits: Visits
var _bowls: FoodBowls


func _init(p_defs: Defs) -> void:
	_defs = p_defs
	_visits = Visits.new(p_defs)
	_bowls = FoodBowls.new(p_defs)


## Brings the state up to now. Returns {events: Array[Dictionary], elapsed_s: int, capped: bool, clock_back: bool}.
## elapsed_s is the replayed length (after the cap), 0 for a new game or a clock set back.
## A null env_clock replays nothing and writes nothing.
func run(state: Dictionary, now: int, env_clock: EnvClock, utc_offset_s: int) -> Dictionary:
	var events: Array[Dictionary] = []
	if env_clock == null:
		return _report(events, 0, false, false)
	var last_seen: int = int(state.get("last_seen", 0))
	if last_seen == 0:
		state["last_seen"] = now
		return _report(events, 0, false, false)
	var elapsed: int = now - last_seen
	if elapsed < 0:
		state["last_seen"] = now
		return _report(events, 0, false, true)
	var cap: int = _tuning_int("offline_cap_s")
	var span: int = mini(elapsed, cap)
	state["last_seen"] = now

	var rooms: Array[Dictionary] = _owned_rooms(state)
	var cur: int = now - span
	_round(state, rooms, cur, cur, env_clock, utc_offset_s, events)
	while cur < now:
		var t: int = _next_event_time(state, cur, now)
		if t <= cur:
			# Guard: no time moves forward. Not reachable while now is a candidate, kept as a backstop.
			t = mini(cur + maxi(_tuning_int("check_s"), 1), now)
		_round(state, rooms, cur, t, env_clock, utc_offset_s, events)
		cur = t
	return _report(events, span, elapsed > cap, false)


func _report(events: Array[Dictionary], elapsed_s: int, capped: bool, clock_back: bool) -> Dictionary:
	return {"events": events, "elapsed_s": elapsed_s, "capped": capped, "clock_back": clock_back}


## One round: every owned bowl advances from cur to t (app closed), then Visits ticks at t.
func _round(state: Dictionary, rooms: Array[Dictionary], cur: int, t: int, env_clock: EnvClock, utc_offset_s: int, events: Array[Dictionary]) -> void:
	for room: Dictionary in rooms:
		_bowls.advance(state, str(room["bowl_slot"]), cur, t, false, _spirits_in(state, room["toy_slots"]))
	events.append_array(_visits.tick(state, t, env_clock.at(t, utc_offset_s), "", false))


## The smallest next_check_at or leave_at after cur, or now when none comes earlier.
func _next_event_time(state: Dictionary, cur: int, now: int) -> int:
	var best: int = now
	for value: Variant in _dict_of(state, "next_check_at").values():
		if int(value) > cur and int(value) < best:
			best = int(value)
	for visit_value: Variant in _dict_of(state, "visits_now").values():
		if typeof(visit_value) != TYPE_DICTIONARY:
			continue
		var leave_at: int = int((visit_value as Dictionary).get("leave_at", 0))
		if leave_at > cur and leave_at < best:
			best = leave_at
	return best


## Visits in the toy slots of one room at the current time: the spirits that eat from that room's bowl.
func _spirits_in(state: Dictionary, toy_slots: Array) -> int:
	var visits: Dictionary = _dict_of(state, "visits_now")
	var count: int = 0
	for slot_value: Variant in toy_slots:
		if visits.has(str(slot_value)):
			count += 1
	return count


## Owned rooms in file order, each with its bowl slot and its toy slots.
func _owned_rooms(state: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var owned: Variant = state.get("rooms_owned")
	if typeof(owned) != TYPE_ARRAY:
		return out
	for room_id: String in _defs.ids("rooms"):
		if (owned as Array).has(room_id):
			out.append({"bowl_slot": _bowls.bowl_slot_of_room(room_id), "toy_slots": _toy_slots_of(room_id)})
	return out


func _toy_slots_of(room_id: String) -> Array[String]:
	var out: Array[String] = []
	var slots: Variant = _defs.room(room_id).get("slots")
	if typeof(slots) != TYPE_ARRAY:
		return out
	for slot_value: Variant in slots:
		if typeof(slot_value) == TYPE_DICTIONARY and (slot_value as Dictionary).get("accepts") == "toy":
			out.append(str((slot_value as Dictionary).get("slot_id", "")))
	return out


func _dict_of(state: Dictionary, key: String) -> Dictionary:
	var value: Variant = state.get(key)
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}


func _tuning_int(key: String) -> int:
	return int(_defs.tuning().get(key, 0))
