class_name Placement
extends RefCounted
## Toys on toy slots: state.placement = {slot_id: toy_id}.
## The slot must be in an owned room and accept a toy. The toy must be owned and must not be on
## another slot (one per kind, one slot). A spirit visiting the slot is not handled here: the result
## carries force_leave_slot and the caller (Visits) makes the spirit leave. visits_now is never touched.
## Keeps state.slot_checkable_at up to date (see FoodBowls.sync_checkable_in_room).
## Every successful place (a swap too) records state.slot_placed_at[slot] = now (R1 in Visits).

enum Code { Ok, NoChange, InvalidSlot, WrongSlotType, NotAvailable }


class Result extends RefCounted:
	var code: Placement.Code = Placement.Code.Ok
	var force_leave_slot: bool = false

	func _init(p_code: Placement.Code, p_force_leave: bool = false) -> void:
		code = p_code
		force_leave_slot = p_force_leave


var _defs: Defs
var _inventory: Inventory
var _bowls: FoodBowls


func _init(p_defs: Defs) -> void:
	_defs = p_defs
	_inventory = Inventory.new(p_defs)
	_bowls = FoodBowls.new(p_defs)


## Puts toy_id on slot_id. A toy already on the slot is replaced, and the old toy becomes available again.
func place(state: Dictionary, slot_id: String, toy_id: String, now: int) -> Result:
	var slot: Dictionary = _defs.slot(slot_id)
	if slot.is_empty() or not _owned(state, str(slot["room_id"])):
		return Result.new(Code.InvalidSlot)
	if slot.get("accepts") != "toy":
		return Result.new(Code.WrongSlotType)
	var placement: Dictionary = state["placement"]
	if placement.get(slot_id) == toy_id:
		return Result.new(Code.NoChange)
	if not _available(state, slot_id, toy_id):
		return Result.new(Code.NotAvailable)
	placement[slot_id] = toy_id
	_bowls.sync_checkable_in_room(state, str(slot["room_id"]), now)
	_record_placed(state, slot_id, now)
	return Result.new(Code.Ok, _visited(state, slot_id))


## Takes the toy off slot_id. An empty slot gives NoChange.
func remove(state: Dictionary, slot_id: String, now: int) -> Result:
	var slot: Dictionary = _defs.slot(slot_id)
	if slot.is_empty() or not _owned(state, str(slot["room_id"])):
		return Result.new(Code.InvalidSlot)
	if slot.get("accepts") != "toy":
		return Result.new(Code.WrongSlotType)
	var placement: Dictionary = state["placement"]
	if not placement.has(slot_id):
		return Result.new(Code.NoChange)
	var force: bool = _visited(state, slot_id)
	placement.erase(slot_id)
	_bowls.sync_checkable_in_room(state, str(slot["room_id"]), now)
	return Result.new(Code.Ok, force)


## True when the toy slot holds a toy and its room's bowl is not empty (R1 'checkable').
## The R1 timing itself belongs to the Visits chunk.
func is_checkable(state: Dictionary, slot_id: String) -> bool:
	return _bowls.is_checkable(state, slot_id)


## Owned, and not on another slot. A toy on this same slot counts as available.
func _available(state: Dictionary, slot_id: String, toy_id: String) -> bool:
	if _defs.toy(toy_id).is_empty() or _inventory.count(state, toy_id) < 1:
		return false
	var placement: Dictionary = state["placement"]
	for other_slot: Variant in placement:
		if placement[other_slot] == toy_id and str(other_slot) != slot_id:
			return false
	return true


## R1 input: the time of the last successful place on this slot.
func _record_placed(state: Dictionary, slot_id: String, now: int) -> void:
	if not state.has("slot_placed_at"):
		state["slot_placed_at"] = {}
	var placed_at: Dictionary = state["slot_placed_at"]
	placed_at[slot_id] = now


func _visited(state: Dictionary, slot_id: String) -> bool:
	var visits: Dictionary = state.get("visits_now", {})
	return visits.has(slot_id)


func _owned(state: Dictionary, room_id: String) -> bool:
	var owned: Array = state.get("rooms_owned", [])
	return owned.has(room_id)
