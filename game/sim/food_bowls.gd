class_name FoodBowls
extends RefCounted
## Food bowls: one bowl slot per owned room.
## state.food_bowls = {slot_id: {food_id, amount (0..1), last_t}}.
## fill() sets the amount to 1.0. advance() lowers it with time.
## Basic food (infinite) costs nothing, and it cannot go on top of nectar that is still in the bowl.
##
## Also keeps state.slot_checkable_at (R1 bookkeeping, toy slots only). A toy slot is checkable when it
## holds a toy and its room's bowl is not empty. The key is present exactly when the slot is checkable,
## and its value is the time the slot became checkable. Swapping a toy on a checkable slot keeps the time.

enum Code { Ok, NoChange, WrongSlotType, NotEnough, FoodRemaining }

const EMPTY_LIMIT: float = 0.001
const FULL_LIMIT: float = 0.999
const SECONDS_PER_HOUR: float = 3600.0


class Result extends RefCounted:
	var code: FoodBowls.Code = FoodBowls.Code.Ok

	func _init(p_code: FoodBowls.Code) -> void:
		code = p_code


var _defs: Defs
var _inventory: Inventory


func _init(p_defs: Defs) -> void:
	_defs = p_defs
	_inventory = Inventory.new(p_defs)


## The bowl slot of a room, or "" when the room is unknown or has no bowl.
func bowl_slot_of_room(room_id: String) -> String:
	for slot_value: Variant in _slots_of_room(room_id):
		var slot: Dictionary = slot_value
		if slot.get("accepts") == "bowl":
			return str(slot.get("slot_id", ""))
	return ""


## The amount left in the bowl at slot_id (0.0 when there is no bowl).
func amount(state: Dictionary, slot_id: String) -> float:
	var bowls: Dictionary = state.get("food_bowls", {})
	if not bowls.has(slot_id):
		return 0.0
	var bowl: Dictionary = bowls[slot_id]
	return float(bowl.get("amount", 0.0))


func is_empty(state: Dictionary, slot_id: String) -> bool:
	return amount(state, slot_id) <= EMPTY_LIMIT


## True when a toy slot holds a toy and its room's bowl is not empty (R1 'checkable').
func is_checkable(state: Dictionary, slot_id: String) -> bool:
	var placement: Dictionary = state.get("placement", {})
	if not placement.has(slot_id):
		return false
	var slot: Dictionary = _defs.slot(slot_id)
	if slot.is_empty():
		return false
	var bowl_id: String = bowl_slot_of_room(str(slot["room_id"]))
	return bowl_id != "" and not is_empty(state, bowl_id)


## Fills the bowl at slot_id with food_id (F1 fill_bowl). Nothing changes unless the result is Ok.
## Nectar is taken from the inventory only after the bowl has been updated.
func fill(state: Dictionary, slot_id: String, food_id: String, now: int) -> Result:
	var slot: Dictionary = _defs.slot(slot_id)
	if slot.is_empty() or not _owned(state, str(slot["room_id"])) or slot.get("accepts") != "bowl":
		return Result.new(Code.WrongSlotType)
	var food: Dictionary = _defs.food(food_id)
	if food.is_empty():
		return Result.new(Code.NotEnough)
	var infinite: bool = food.get("infinite") == true
	if not infinite and _inventory.count(state, food_id) < 1:
		return Result.new(Code.NotEnough)
	var bowls: Dictionary = state["food_bowls"]
	var old_food: String = str((bowls.get(slot_id, {}) as Dictionary).get("food_id", ""))
	var old_amount: float = amount(state, slot_id)
	if old_food == food_id and old_amount >= FULL_LIMIT:
		return Result.new(Code.NoChange)
	if infinite and old_food != food_id and old_amount > EMPTY_LIMIT:
		return Result.new(Code.FoodRemaining)
	bowls[slot_id] = {"food_id": food_id, "amount": 1.0, "last_t": now}
	if not infinite:
		_inventory.remove(state, food_id, 1)
	sync_checkable_in_room(state, str(slot["room_id"]), now)
	return Result.new(Code.Ok)


## Lowers the bowl at slot_id for the time from from_t to to_t (K3).
## The shy spirit eats only while the app is closed: time / duration_s.
## Each spirit present eats eat_rate_per_hour per hour, whether or not the app is open.
## The amount is clamped at 0 and food_id stays as it was.
func advance(state: Dictionary, slot_id: String, from_t: int, to_t: int, app_open: bool, spirits_present: int) -> void:
	var bowls: Dictionary = state.get("food_bowls", {})
	if not bowls.has(slot_id) or to_t <= from_t:
		return
	var bowl: Dictionary = bowls[slot_id]
	var elapsed: float = float(to_t - from_t)
	var eat_rate: float = float(_defs.tuning().get("eat_rate_per_hour", 0.0))
	var drop: float = float(maxi(spirits_present, 0)) * eat_rate * elapsed / SECONDS_PER_HOUR
	if not app_open:
		var food: Dictionary = _defs.food(str(bowl.get("food_id", "")))
		if not food.is_empty():
			drop += elapsed / float(food["duration_s"])
	bowl["amount"] = maxf(0.0, float(bowl.get("amount", 0.0)) - drop)
	bowl["last_t"] = to_t
	var slot: Dictionary = _defs.slot(slot_id)
	if not slot.is_empty():
		sync_checkable_in_room(state, str(slot["room_id"]), to_t)


## Brings state.slot_checkable_at up to date for the toy slots of one room:
## a checkable slot without a key gets now, a slot that is no longer checkable loses its key.
func sync_checkable_in_room(state: Dictionary, room_id: String, now: int) -> void:
	if not state.has("slot_checkable_at"):
		state["slot_checkable_at"] = {}
	var checkable_at: Dictionary = state["slot_checkable_at"]
	for slot_value: Variant in _slots_of_room(room_id):
		var slot: Dictionary = slot_value
		if slot.get("accepts") != "toy":
			continue
		var slot_id: String = str(slot.get("slot_id", ""))
		if is_checkable(state, slot_id):
			if not checkable_at.has(slot_id):
				checkable_at[slot_id] = now
		else:
			checkable_at.erase(slot_id)


func _slots_of_room(room_id: String) -> Array:
	var out: Array = []
	var slots: Variant = _defs.room(room_id).get("slots")
	if typeof(slots) != TYPE_ARRAY:
		return out
	for slot_value: Variant in slots:
		if typeof(slot_value) == TYPE_DICTIONARY:
			out.append(slot_value)
	return out


func _owned(state: Dictionary, room_id: String) -> bool:
	var owned: Array = state.get("rooms_owned", [])
	return owned.has(room_id)
