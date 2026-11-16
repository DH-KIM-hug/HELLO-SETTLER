class_name Collection
extends RefCounted
## Spirit collection (G10 collection, G7 scenes, F6 one-time rewards) and the unlock-reveal list (U8 U-5).
## Pure logic: time and the environment ({is_night, weather}, as EnvClock.at() gives it) are passed in.
## Never changes coins or items (Wallet, Inventory).
## Reveal list: state.reveal_shown {"card:<id>" | "scene:<id>": shown yet?} and state.unlock_order (oldest first).
##
## Events: {type: "unlocked", kind: "card" | "scene", id}

var _defs: Defs


func _init(p_defs: Defs) -> void:
	_defs = p_defs


## Called when a spirit settles (Playing) at a toy slot. The spirit must be in visits_now with state "playing".
## The first meeting unlocks its card. The pose spirit@toy is recorded (no event, no reward).
## Then the scenes are checked for the room of this slot. Returns the unlock events.
## Unknown spirit, toy or slot: nothing changes and [] comes back.
func on_settled(state: Dictionary, slot: String, spirit_id: String, toy_id: String, now: int, env: Dictionary) -> Array:
	var events: Array = []
	var room_slot: Dictionary = _defs.slot(slot)
	if room_slot.is_empty() or _defs.spirit(spirit_id).is_empty() or _defs.toy(toy_id).is_empty():
		return events
	var book: Dictionary = _sub(state, "collection")
	if not book.has(spirit_id):
		book[spirit_id] = {"first_seen_at": now, "visit_count": 0, "poses_seen": [], "seen_in_book": false}
		_reveal(state, "card:" + spirit_id)
		events.append({"type": "unlocked", "kind": "card", "id": spirit_id})
	var entry: Dictionary = book[spirit_id]
	var poses: Array = entry["poses_seen"]
	var pose: String = spirit_id + "@" + toy_id
	if not poses.has(pose):
		poses.append(pose)
	events.append_array(_check_scenes(state, str(room_slot["room_id"]), env))
	return events


## A visit ended for this spirit: visit_count += 1. Returns false (no change) for a spirit not yet met.
func on_left(state: Dictionary, spirit_id: String) -> bool:
	var book: Dictionary = _read(state, "collection")
	if not book.has(spirit_id):
		return false
	var entry: Dictionary = book[spirit_id]
	entry["visit_count"] = int(entry.get("visit_count", 0)) + 1
	return true


## Keys still waiting to be shown, oldest unlock first (the U8 queue). Read only.
func pending_reveals(state: Dictionary) -> Array:
	var out: Array = []
	var shown: Dictionary = _read(state, "reveal_shown")
	var order: Array = state.get("unlock_order", [])
	for key: Variant in order:
		if shown.has(key) and shown[key] == false:
			out.append(str(key))
	return out


## Marks one reveal as shown. Returns false for an unknown key.
func mark_revealed(state: Dictionary, key: String) -> bool:
	var shown: Dictionary = _read(state, "reveal_shown")
	if not shown.has(key):
		return false
	shown[key] = true
	return true


## Clears the book badge of a card. Only kind "card" has one (G10 seen_in_book). Returns false otherwise.
func mark_seen(state: Dictionary, kind: String, id: String) -> bool:
	if kind != "card":
		return false
	var book: Dictionary = _read(state, "collection")
	if not book.has(id):
		return false
	var entry: Dictionary = book[id]
	entry["seen_in_book"] = true
	return true


## A scene unlocks once, when its spirits are all Playing in one room (the room of the settled slot),
## the weather is in its set, and the time of day fits. Scenes already unlocked are skipped.
func _check_scenes(state: Dictionary, room_id: String, env: Dictionary) -> Array:
	var events: Array = []
	var unlocked: Array = _sub_array(state, "scenes_unlocked")
	var playing: Array = _playing_in_room(state, room_id)
	var weather: String = str(env.get("weather", ""))
	var is_night: bool = bool(env.get("is_night", false))
	for scene_id: String in _defs.ids("scenes"):
		if unlocked.has(scene_id):
			continue
		var scene: Dictionary = _defs.scene(scene_id)
		if not _env_fits(scene, weather, is_night) or not _all_playing(scene, playing):
			continue
		unlocked.append(scene_id)
		_reveal(state, "scene:" + scene_id)
		events.append({"type": "unlocked", "kind": "scene", "id": scene_id})
	return events


func _playing_in_room(state: Dictionary, room_id: String) -> Array:
	var out: Array = []
	var visits: Dictionary = _read(state, "visits_now")
	for slot_id: Variant in visits:
		var visit: Dictionary = visits[slot_id]
		if str(visit.get("state", "")) != Visits.STATE_PLAYING:
			continue
		if str(_defs.slot(str(slot_id)).get("room_id", "")) != room_id:
			continue
		out.append(str(visit.get("spirit_id", "")))
	return out


static func _all_playing(scene: Dictionary, playing: Array) -> bool:
	var spirits: Array = scene["spirits"]
	for spirit_id: Variant in spirits:
		if not playing.has(str(spirit_id)):
			return false
	return true


static func _env_fits(scene: Dictionary, weather: String, is_night: bool) -> bool:
	var weathers: Array = scene["weather"]
	if not weathers.has(weather):
		return false
	var time_gate: String = str(scene["time"])
	if time_gate == "day":
		return not is_night
	if time_gate == "night":
		return is_night
	return true


## Adds a reveal key as not yet shown, at the end of the unlock order.
func _reveal(state: Dictionary, key: String) -> void:
	var shown: Dictionary = _sub(state, "reveal_shown")
	shown[key] = false
	_sub_array(state, "unlock_order").append(key)


static func _sub(state: Dictionary, key: String) -> Dictionary:
	if typeof(state.get(key)) != TYPE_DICTIONARY:
		state[key] = {}
	var out: Dictionary = state[key]
	return out


static func _sub_array(state: Dictionary, key: String) -> Array:
	if typeof(state.get(key)) != TYPE_ARRAY:
		state[key] = []
	var out: Array = state[key]
	return out


static func _read(state: Dictionary, key: String) -> Dictionary:
	var value: Variant = state.get(key)
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}
