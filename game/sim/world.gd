class_name World
extends RefCounted
## Wires the sim modules together (K8 "world"). Owns the one game state, builds the modules,
## runs the 1-second tick, routes Visits events to Wallet, Collection and the view signals, and
## saves through SaveStore. Player actions return the module Result unchanged and change nothing
## when it fails. Time is always passed in (unix seconds). The view connects to the signals.
##
## Save policy (F4): tick() marks the state dirty and saves at most every SAVE_EVERY_S seconds.
## buy, claim, place, remove, fill, the tutorial reward, catch-up, pause, start and reset save at once.
## A failed save keeps the state and stays dirty, so the next tick tries again.
##
## Routing: every Visits event (tick, catch-up, forced leave) goes through _route(). A 'left' event
## creates the gift (Wallet) and counts the visit (Collection). A 'settled' event goes to Collection.
## Catch-up calls _route() once per replay round, at the round's own time (CatchUp on_round), so
## first_seen_at and the scene checks see the state at that time. Nothing is routed a second time.
## Wallet changes (coins, pending gifts per slot) are compared before and after and emitted as signals.

signal visit_changed(slot: String)
signal spirit_settled(slot: String, spirit_id: String, is_new: bool)
signal spirit_left(slot: String, spirit_id: String)
signal gift_changed(slot: String)
signal coins_changed(n: int)
signal bowl_changed(slot: String)
signal unlocked(kind: String, id: String)
signal catch_up_done(summary: Dictionary)

const SAVE_EVERY_S: int = 10
const FULL_CATCH_UP_S: int = 1800

var _defs: Defs
var _store: SaveStore
var _placement: Placement
var _bowls: FoodBowls
var _visits: Visits
var _catch_up: CatchUp
var _wallet: Wallet
var _shop: Shop
var _collection: Collection

var _state: Dictionary = {}
var _env: EnvClock = null
var _utc_offset_s: int = 0
var _started: bool = false
var _dirty: bool = false
var _last_save_t: int = 0
var _last_t: int = 0


func _init(defs: Defs, save_store: SaveStore) -> void:
	_defs = defs
	_store = save_store
	_placement = Placement.new(defs)
	_bowls = FoodBowls.new(defs)
	_visits = Visits.new(defs)
	_catch_up = CatchUp.new(defs)
	_wallet = Wallet.new(defs)
	_shop = Shop.new(defs)
	_collection = Collection.new(defs)


## Loads (or creates) the game, builds the EnvClock from tuning, runs CatchUp (which routes its events
## round by round), saves.
## Returns {load_kind: SaveStore.LoadKind, load_reason: String, catch_up: {elapsed_s, capped, clock_back, event_count}, saved: bool}.
func start(now: int, utc_offset_s: int, fresh_seed: int) -> Dictionary:
	var loaded: SaveStore.LoadResult = _store.load_game(fresh_seed, now)
	_state = loaded.state
	_utc_offset_s = utc_offset_s
	_env = _build_env()
	_started = true
	_last_t = now
	var report: Dictionary = _catch_up.run(_state, now, _env, utc_offset_s, _route)
	var summary: Dictionary = _catch_up_summary(report)
	var saved: bool = _save(now)
	catch_up_done.emit(summary)
	return {"load_kind": loaded.kind, "load_reason": loaded.reason, "catch_up": summary, "saved": saved}


## Called every second while the app is open. Advances the bowls, runs Visits, routes the events.
func tick(now: int, visible_room: String, app_open: bool) -> void:
	if not _started:
		return
	_last_t = now
	_advance_bowls(now, app_open)
	var env: Dictionary = _env.at(now, _utc_offset_s)
	var events: Array[Dictionary] = _visits.tick(_state, now, env, visible_room, app_open)
	_route(events, now, env)
	_dirty = true
	if _dirty and absi(now - _last_save_t) >= SAVE_EVERY_S:
		_save(now)


## Puts a toy on a toy slot. A visiting spirit leaves at once (a gift is made), then the state is saved.
func place(slot_id: String, toy_id: String, now: int) -> Placement.Result:
	if not _started:
		return Placement.Result.new(Placement.Code.InvalidSlot)
	var result: Placement.Result = _placement.place(_state, slot_id, toy_id, now)
	if result.code != Placement.Code.Ok:
		return result
	_last_t = now
	if result.force_leave_slot:
		_route(_visits.force_leave(_state, slot_id, now), now, _env.at(now, _utc_offset_s))
	visit_changed.emit(slot_id)
	_save(now)
	return result


## Takes the toy off a toy slot. A visiting spirit leaves at once (a gift is made), then the state is saved.
func remove(slot_id: String, now: int) -> Placement.Result:
	if not _started:
		return Placement.Result.new(Placement.Code.InvalidSlot)
	var result: Placement.Result = _placement.remove(_state, slot_id, now)
	if result.code != Placement.Code.Ok:
		return result
	_last_t = now
	if result.force_leave_slot:
		_route(_visits.force_leave(_state, slot_id, now), now, _env.at(now, _utc_offset_s))
	visit_changed.emit(slot_id)
	_save(now)
	return result


## Fills a bowl (basic food or one nectar). Saves at once.
func fill_bowl(slot_id: String, food_id: String, now: int) -> FoodBowls.Result:
	if not _started:
		return FoodBowls.Result.new(FoodBowls.Code.WrongSlotType)
	var result: FoodBowls.Result = _bowls.fill(_state, slot_id, food_id, now)
	if result.code != FoodBowls.Code.Ok:
		return result
	_last_t = now
	bowl_changed.emit(slot_id)
	_save(now)
	return result


## Pays the pending gifts of one slot. AlreadyClaimed (no change, no save) when there are none.
func claim_gift(slot_id: String) -> Wallet.Result:
	if not _started:
		return Wallet.Result.new(Wallet.Code.AlreadyClaimed)
	var before: Dictionary = _wallet_snapshot()
	var result: Wallet.Result = _wallet.claim(_state, slot_id)
	if result.code == Wallet.Code.AlreadyClaimed:
		return result
	_emit_wallet_changes(before)
	_save_last()
	return result


## Pays all pending gifts. AlreadyClaimed (no change, no save) when there are none.
func claim_all() -> Wallet.Result:
	if not _started:
		return Wallet.Result.new(Wallet.Code.AlreadyClaimed)
	var before: Dictionary = _wallet_snapshot()
	var result: Wallet.Result = _wallet.claim_all(_state)
	if result.code == Wallet.Code.AlreadyClaimed:
		return result
	_emit_wallet_changes(before)
	_save_last()
	return result


## Buys one product (Shop checks everything and changes nothing on failure). Saves at once when it succeeds.
func buy(product_id: String, now: int) -> Shop.Result:
	if not _started:
		return Shop.Result.new(Shop.Code.InvalidProduct)
	var before: Dictionary = _wallet_snapshot()
	var result: Shop.Result = _shop.buy(_state, product_id, now)
	if result.code != Shop.Code.Success:
		return result
	_last_t = now
	_emit_wallet_changes(before)
	_save(now)
	return result


## One of "available", "not_enough", "inventory_full", "locked", "owned", "limit". Read only.
func shop_state(product_id: String) -> String:
	if not _started:
		return "locked"
	return _shop.state_of(_state, product_id)


## Clears the book badge of a card (kind "card"). Marks the state dirty only.
func mark_seen(kind: String, id: String) -> bool:
	var changed: bool = _collection.mark_seen(_state, kind, id)
	if changed:
		_dirty = true
	return changed


## Marks one unlock reveal as shown. Marks the state dirty only.
func mark_revealed(key: String) -> bool:
	var changed: bool = _collection.mark_revealed(_state, key)
	if changed:
		_dirty = true
	return changed


## Reveal keys still waiting to be shown, oldest unlock first. Read only.
func pending_reveals() -> Array:
	return _collection.pending_reveals(_state)


## Pays the one-time tutorial reward (L6, 100 coins). Returns true when it paid; saves at once then.
func tutorial_reward() -> bool:
	if not _started:
		return false
	var before: Dictionary = _wallet_snapshot()
	var paid: bool = _wallet.tutorial_reward(_state)
	if paid:
		_emit_wallet_changes(before)
		_save_last()
	return paid


## The app went to the background: last_seen = now, then save at once (F8 Backgrounded).
func on_app_paused(now: int) -> bool:
	if not _started:
		return false
	_last_t = now
	_state["last_seen"] = now
	return _save(now)


## The app came back. Runs CatchUp in both cases (it handles short gaps too; it routes the events round
## by round), saves. Returns {full: bool}, where full is true when the app was away for FULL_CATCH_UP_S or more.
func on_app_resumed(now: int) -> Dictionary:
	if not _started:
		return {"full": false}
	var away: int = now - int(_state.get("last_seen", 0))
	_last_t = now
	var report: Dictionary = _catch_up.run(_state, now, _env, _utc_offset_s, _route)
	_save(now)
	catch_up_done.emit(_catch_up_summary(report))
	return {"full": away >= FULL_CATCH_UP_S}


## Starts a new game (fresh seed, starter items, last_seen = now) and saves it.
## The view redraws everything after a reset: no per-slot signals are sent for the old state.
func reset_game(now: int, fresh_seed: int) -> bool:
	var before: Dictionary = _wallet_snapshot()
	_state = _store.new_game_state(fresh_seed)
	_state["last_seen"] = now
	_env = _build_env()
	_started = true
	_last_t = now
	_emit_wallet_changes(before)
	return _save(now)


## Environment at now ({is_night, weather, source}), for the view and the tests. Read only.
func env_at(now: int) -> Dictionary:
	if not _started:
		return {}
	return _env.at(now, _utc_offset_s)


## A deep copy of the state, for reading. Changing the copy changes nothing.
func state_copy() -> Dictionary:
	return _state.duplicate(true)


# ---------------------------------------------------------------- routing

## Sends Visits events to the other modules and emits the signals. Also emits the wallet changes it caused.
func _route(events: Array, now: int, env: Dictionary) -> void:
	var before: Dictionary = _wallet_snapshot()
	for ev_value: Variant in events:
		var ev: Dictionary = ev_value
		var slot: String = str(ev.get("slot", ""))
		match str(ev.get("type", "")):
			"arrived":
				visit_changed.emit(slot)
			"settled":
				_on_settled(slot, str(ev["spirit_id"]), bool(ev["is_new"]), now, env)
			"left":
				_on_left(slot, str(ev["spirit_id"]), int(ev["visit_seq"]), str(ev["rarity"]))
	_emit_wallet_changes(before)


func _on_settled(slot: String, spirit_id: String, is_new: bool, now: int, env: Dictionary) -> void:
	var placement: Dictionary = _state.get("placement", {})
	var toy_id: String = str(placement.get(slot, ""))
	var unlocks: Array = _collection.on_settled(_state, slot, spirit_id, toy_id, now, env)
	visit_changed.emit(slot)
	spirit_settled.emit(slot, spirit_id, is_new)
	for unlock_value: Variant in unlocks:
		var unlock: Dictionary = unlock_value
		unlocked.emit(str(unlock["kind"]), str(unlock["id"]))


func _on_left(slot: String, spirit_id: String, visit_seq: int, rarity: String) -> void:
	_wallet.create_gift(_state, slot, spirit_id, visit_seq, rarity)
	_collection.on_left(_state, spirit_id)
	visit_changed.emit(slot)
	spirit_left.emit(slot, spirit_id)


# ---------------------------------------------------------------- bowls

## Advances every owned bowl from its last_t to now, with the spirits present in its room.
func _advance_bowls(now: int, app_open: bool) -> void:
	var bowls: Dictionary = _state.get("food_bowls", {})
	for room_id: String in _owned_room_ids():
		var bowl_slot: String = _bowls.bowl_slot_of_room(room_id)
		if bowl_slot == "" or not bowls.has(bowl_slot):
			continue
		var bowl: Dictionary = bowls[bowl_slot]
		var before: float = _bowls.amount(_state, bowl_slot)
		_bowls.advance(_state, bowl_slot, int(bowl.get("last_t", now)), now, app_open, _spirits_in_room(room_id))
		if _bowls.amount(_state, bowl_slot) != before:
			bowl_changed.emit(bowl_slot)


## Visits in the toy slots of one room (the spirits that eat from its bowl).
func _spirits_in_room(room_id: String) -> int:
	var visits: Dictionary = _state.get("visits_now", {})
	var count: int = 0
	for slot_id: String in _toy_slots_of(room_id):
		if visits.has(slot_id):
			count += 1
	return count


func _owned_room_ids() -> Array[String]:
	var out: Array[String] = []
	var owned: Array = _state.get("rooms_owned", [])
	for room_id: String in _defs.ids("rooms"):
		if owned.has(room_id):
			out.append(room_id)
	return out


func _toy_slots_of(room_id: String) -> Array[String]:
	var out: Array[String] = []
	var slots: Array = _defs.room(room_id).get("slots", [])
	for slot_value: Variant in slots:
		var slot: Dictionary = slot_value
		if slot.get("accepts") == "toy":
			out.append(str(slot.get("slot_id", "")))
	return out


# ---------------------------------------------------------------- wallet signals

func _wallet_snapshot() -> Dictionary:
	return {"coins": int(_state.get("coins", 0)), "gifts": _gift_counts()}


## Pending gift count per slot.
func _gift_counts() -> Dictionary:
	var counts: Dictionary = {}
	var gifts: Array = _state.get("pending_gifts", [])
	for gift_value: Variant in gifts:
		var slot: String = str((gift_value as Dictionary).get("slot", ""))
		counts[slot] = int(counts.get(slot, 0)) + 1
	return counts


func _emit_wallet_changes(before: Dictionary) -> void:
	var coins_now: int = int(_state.get("coins", 0))
	if coins_now != int(before["coins"]):
		coins_changed.emit(coins_now)
	var before_counts: Dictionary = before["gifts"]
	var after_counts: Dictionary = _gift_counts()
	var slots: Dictionary = {}
	for slot_key: Variant in before_counts:
		slots[slot_key] = true
	for slot_key: Variant in after_counts:
		slots[slot_key] = true
	for slot_key: Variant in slots:
		var slot: String = str(slot_key)
		if int(before_counts.get(slot, 0)) != int(after_counts.get(slot, 0)):
			gift_changed.emit(slot)


# ---------------------------------------------------------------- save and helpers

func _save(now: int) -> bool:
	_last_save_t = now
	var kind: SaveStore.SaveKind = _store.save(_state)
	_dirty = kind != SaveStore.SaveKind.OK
	return kind == SaveStore.SaveKind.OK


func _save_last() -> bool:
	return _save(_last_t)


func _build_env() -> EnvClock:
	var tuning: Dictionary = _defs.tuning()
	var seed_value: int = int(_state.get("save_seed", 0))
	return EnvClock.new(seed_value, int(tuning["day_start_hour"]), int(tuning["night_start_hour"]), float(tuning["seed_weather_clear_p"]), float(tuning["seed_weather_cloudy_p"]))


func _catch_up_summary(report: Dictionary) -> Dictionary:
	var events: Array = report["events"]
	return {
		"elapsed_s": int(report["elapsed_s"]),
		"capped": bool(report["capped"]),
		"clock_back": bool(report["clock_back"]),
		"event_count": events.size(),
	}
