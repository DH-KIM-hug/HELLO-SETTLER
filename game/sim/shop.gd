class_name Shop
extends RefCounted
## Buying (G9 steps 1-7) and the six product states (U6). One transaction: the coins go through Wallet,
## the item through Inventory (toys, food) or rooms_owned (rooms). A failed buy changes nothing (decision G-10:
## no partial purchase).
## Check order, shared by buy() and state_of(): exists, requires (Locked), already owned (AlreadyOwned),
## purchase limit (LimitReached), inventory room for the full qty (InventoryFull), coins (NotEnoughCurrency).
## The shop has no time rules, so buy() takes now only to keep the common API shape.

enum Code { Success, NotEnoughCurrency, Locked, AlreadyOwned, LimitReached, InventoryFull, InvalidProduct }


class Result extends RefCounted:
	var code: Shop.Code = Shop.Code.Success

	func _init(p_code: Shop.Code) -> void:
		code = p_code


var _defs: Defs
var _inventory: Inventory
var _wallet: Wallet


func _init(p_defs: Defs) -> void:
	_defs = p_defs
	_inventory = Inventory.new(p_defs)
	_wallet = Wallet.new(p_defs)


## Buys one product. Returns Success, or the first reason it fails (nothing changes then).
func buy(state: Dictionary, product_id: String, _now: int) -> Result:
	var product: Dictionary = _defs.product(product_id)
	if product.is_empty():
		return Result.new(Code.InvalidProduct)
	var check: Code = _check(state, product)
	if check != Code.Success:
		return Result.new(check)
	var snapshot: Dictionary = state.duplicate(true)
	if not _wallet.spend(state, int(product["price"])):
		return Result.new(Code.NotEnoughCurrency)
	if not _grant(state, str(product["target"]), int(product["qty"])):
		state.clear()
		state.merge(snapshot)
		return Result.new(Code.InventoryFull)
	var counts: Dictionary = _sub(state, "purchase_count")
	counts[product_id] = int(counts.get(product_id, 0)) + 1
	return Result.new(Code.Success)


## One of "available", "not_enough", "inventory_full", "locked", "owned", "limit" (U6).
## An unknown product gives "locked" (it cannot be bought). Read only.
func state_of(state: Dictionary, product_id: String) -> String:
	var product: Dictionary = _defs.product(product_id)
	if product.is_empty():
		return "locked"
	match _check(state, product):
		Code.Success:
			return "available"
		Code.NotEnoughCurrency:
			return "not_enough"
		Code.InventoryFull:
			return "inventory_full"
		Code.AlreadyOwned:
			return "owned"
		Code.LimitReached:
			return "limit"
	return "locked"


## The first reason the purchase fails, or Success. Changes nothing.
func _check(state: Dictionary, product: Dictionary) -> Code:
	var target: String = str(product["target"])
	if not _requires_met(state, product["requires"]):
		return Code.Locked
	if _owned(state, target):
		return Code.AlreadyOwned
	var limit: Variant = product["limit"]
	if limit != null and _purchases(state, str(product["product_id"])) >= int(limit):
		return Code.LimitReached
	if not _fits(state, target, int(product["qty"])):
		return Code.InventoryFull
	if not _wallet.can_spend(state, int(product["price"])):
		return Code.NotEnoughCurrency
	return Code.Success


## requires: null (no condition) or {owned_toys_min: n}, counted as owned toy kinds.
func _requires_met(state: Dictionary, requires: Variant) -> bool:
	if typeof(requires) != TYPE_DICTIONARY:
		return true
	var need: int = int((requires as Dictionary).get("owned_toys_min", 0))
	return _owned_toy_kinds(state) >= need


func _owned_toy_kinds(state: Dictionary) -> int:
	var stock: Dictionary = state.get("inventory", {})
	var kinds: int = 0
	for item_id: Variant in stock:
		if not _defs.toy(str(item_id)).is_empty() and _inventory.count(state, str(item_id)) > 0:
			kinds += 1
	return kinds


## A toy is owned when one is in the inventory. A room is owned when it is in rooms_owned. Food is never owned.
func _owned(state: Dictionary, target: String) -> bool:
	if not _defs.toy(target).is_empty():
		return _inventory.count(state, target) >= 1
	if not _defs.room(target).is_empty():
		var owned: Array = state.get("rooms_owned", [])
		return owned.has(target)
	return false


## Rooms are not stacked items (an owned room is caught by _owned), so they always fit.
func _fits(state: Dictionary, target: String, qty: int) -> bool:
	if not _defs.room(target).is_empty():
		return true
	return _inventory.can_add(state, target, qty)


func _grant(state: Dictionary, target: String, qty: int) -> bool:
	if not _defs.room(target).is_empty():
		if typeof(state.get("rooms_owned")) != TYPE_ARRAY:
			state["rooms_owned"] = []
		var owned: Array = state["rooms_owned"]
		owned.append(target)
		return true
	return _inventory.add(state, target, qty)


func _purchases(state: Dictionary, product_id: String) -> int:
	var counts: Dictionary = state.get("purchase_count", {})
	return int(counts.get(product_id, 0))


static func _sub(state: Dictionary, key: String) -> Dictionary:
	if typeof(state.get(key)) != TYPE_DICTIONARY:
		state[key] = {}
	var out: Dictionary = state[key]
	return out
