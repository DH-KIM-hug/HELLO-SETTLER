class_name Inventory
extends RefCounted
## Owned items: state.inventory = {item_id: qty}.
## A stack never goes above the item's max_stack (toys.json, foods.json; toys are 1 per kind).
## An entry that drops to 0 is removed. Unknown ids cannot be added.

var _defs: Defs


func _init(p_defs: Defs) -> void:
	_defs = p_defs


func count(state: Dictionary, item_id: String) -> int:
	var stock: Dictionary = state["inventory"]
	return int(stock.get(item_id, 0))


## How many more of item_id fit in its stack (0 for an unknown id).
func room(state: Dictionary, item_id: String) -> int:
	return maxi(0, _max_stack(item_id) - count(state, item_id))


## True when qty more of item_id fit. Changes nothing.
func can_add(state: Dictionary, item_id: String, qty: int) -> bool:
	return qty >= 1 and room(state, item_id) >= qty


## Returns false and changes nothing when qty < 1, the id is unknown, or the stack would pass max_stack.
func add(state: Dictionary, item_id: String, qty: int) -> bool:
	var limit: int = _max_stack(item_id)
	if qty < 1 or limit < 1:
		return false
	var have: int = count(state, item_id)
	if have + qty > limit:
		return false
	var stock: Dictionary = state["inventory"]
	stock[item_id] = have + qty
	return true


## Returns false and changes nothing when qty < 1 or fewer than qty are owned.
func remove(state: Dictionary, item_id: String, qty: int) -> bool:
	var have: int = count(state, item_id)
	if qty < 1 or have < qty:
		return false
	var stock: Dictionary = state["inventory"]
	if have == qty:
		stock.erase(item_id)
	else:
		stock[item_id] = have - qty
	return true


func _max_stack(item_id: String) -> int:
	var toy: Dictionary = _defs.toy(item_id)
	if not toy.is_empty():
		return int(toy.get("max_stack", 0))
	var food: Dictionary = _defs.food(item_id)
	if not food.is_empty():
		return int(food.get("max_stack", 0))
	return 0
