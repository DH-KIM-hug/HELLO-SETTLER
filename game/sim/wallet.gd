class_name Wallet
extends RefCounted
## The only code that changes coins (state.coins) and the gift list (state.pending_gifts).
## create_gift() queues the gift of one visit (G6 ev_leave). claim() pays the gifts of one slot and
## claim_all() pays all of them; each payment is one step (F6 PerVisit).
## Caps (decision G-5): over pending_per_slot in a slot, or over pending_total, the oldest gift is claimed
## at once. The newest gift of each slot is never auto-claimed. Coins over coin_cap are dropped; nectar
## over nectar_cap is paid as coins at nectar_overflow_coin each (G6 table).
## Time is passed in by the caller. Nothing here reads a clock or writes the save file (SaveStore does).

enum Code { Ok, AlreadyClaimed, Overflowed }

const NECTAR_ID: String = "food_nectar"
## Visits do not leave in visit_seq order, so dedupe uses the last GIFTED_WINDOW seqs (state.gifted_seqs),
## plus any seq still in pending_gifts. last_processed_visit_seq is kept for information only (max).
const GIFTED_WINDOW: int = 64


class Result extends RefCounted:
	var code: Wallet.Code = Wallet.Code.Ok
	var coins_added: int = 0       # coins that reached the wallet
	var coins_dropped: int = 0     # coins over coin_cap, thrown away
	var nectar_added: int = 0      # nectar that reached the inventory
	var nectar_converted: int = 0  # nectar over nectar_cap, paid as coins

	func _init(p_code: Wallet.Code) -> void:
		code = p_code


var _defs: Defs
var _inventory: Inventory


func _init(p_defs: Defs) -> void:
	_defs = p_defs
	_inventory = Inventory.new(p_defs)


## Rolls the gift of one visit and queues it. Returns the notes of the automatic claims (see _auto_claim).
## Ignored, with no change: visit_seq already in gifted_seqs or in pending_gifts, an unknown slot,
## spirit or gift table, or a rarity that does not match the spirit.
## Coins: the GiftTable of the spirit, uniform integer in [coins_min, coins_max], from DetRng(save_seed, "gift", visit_seq).
## Nectar: independent chance nectar_chance, from DetRng(save_seed, "gift_item", visit_seq).
func create_gift(state: Dictionary, slot: String, spirit_id: String, visit_seq: int, rarity: String) -> Array:
	var notes: Array = []
	if _already_gifted(state, visit_seq):
		return notes
	if _defs.slot(slot).is_empty():
		return notes
	var spirit: Dictionary = _defs.spirit(spirit_id)
	if spirit.is_empty() or str(spirit["rarity"]) != rarity:
		return notes
	var table: Dictionary = _defs.gift(str(spirit["gift_table"]))
	if table.is_empty():
		return notes
	var save_seed: int = int(state.get("save_seed", 0))
	var coins_min: int = int(table["coins_min"])
	var coins_max: int = int(table["coins_max"])
	var coins: int = coins_min + floori(DetRng.unit(save_seed, "gift", visit_seq) * float(coins_max - coins_min + 1))
	var items: Array = []
	if DetRng.unit(save_seed, "gift_item", visit_seq) < float(table["nectar_chance"]):
		items.append(str(table["nectar_item"]))
	_pending(state).append({"visit_seq": visit_seq, "slot": slot, "spirit_id": spirit_id, "coins": coins, "items": items})
	_remember_gifted(state, visit_seq)
	state["last_processed_visit_seq"] = maxi(int(state.get("last_processed_visit_seq", 0)), visit_seq)
	return _enforce_caps(state)


## Pays every pending gift of one slot at once. AlreadyClaimed when none is pending (nothing changes).
func claim(state: Dictionary, slot: String) -> Result:
	var gifts: Array = _pending(state)
	var taken: Array = []
	var kept: Array = []
	for gift: Variant in gifts:
		var g: Dictionary = gift
		if str(g["slot"]) == slot:
			taken.append(g)
		else:
			kept.append(g)
	if taken.is_empty():
		return Result.new(Code.AlreadyClaimed)
	gifts.clear()
	gifts.append_array(kept)
	return _pay(state, taken)


## Pays all pending gifts. AlreadyClaimed when none is pending (nothing changes).
func claim_all(state: Dictionary) -> Result:
	var gifts: Array = _pending(state)
	if gifts.is_empty():
		return Result.new(Code.AlreadyClaimed)
	var taken: Array = gifts.duplicate()
	gifts.clear()
	return _pay(state, taken)


## Number of pending gifts in one slot. Read only.
func pending_count(state: Dictionary, slot: String) -> int:
	var n: int = 0
	var gifts: Array = state.get("pending_gifts", [])
	for gift: Variant in gifts:
		var g: Dictionary = gift
		if str(g["slot"]) == slot:
			n += 1
	return n


## True when the wallet holds at least n coins and n is not negative. Changes nothing.
func can_spend(state: Dictionary, n: int) -> bool:
	return n >= 0 and _coins(state) >= n


## Takes n coins. Returns false and changes nothing when it cannot (no negative balance).
func spend(state: Dictionary, n: int) -> bool:
	if not can_spend(state, n):
		return false
	state["coins"] = _coins(state) - n
	return true


## Adds n coins, clamped at coin_cap. Returns the amount that was actually added (0 for n <= 0).
func add(state: Dictionary, n: int) -> int:
	if n <= 0:
		return 0
	var have: int = _coins(state)
	var added: int = clampi(_tuning_int("coin_cap") - have, 0, n)
	state["coins"] = have + added
	return added


## +tutorial_coins once (G6 ev_tutorial_done). Guarded by tutorial.done_reward. Returns true when it paid.
func tutorial_reward(state: Dictionary) -> bool:
	if typeof(state.get("tutorial")) != TYPE_DICTIONARY:
		state["tutorial"] = {}
	var tutorial: Dictionary = state["tutorial"]
	if tutorial.get("done_reward", false) == true:
		return false
	add(state, _tuning_int("tutorial_coins"))
	tutorial["done_reward"] = true
	return true


## Pays gifts that are already removed from pending: coins first, then nectar, with the caps.
## Nothing here can fail: the caps are applied as clamps, so the result is always Ok or Overflowed.
func _pay(state: Dictionary, gifts: Array) -> Result:
	var coins_due: int = 0
	var nectar_due: int = 0
	for gift: Variant in gifts:
		var g: Dictionary = gift
		coins_due += int(g["coins"])
		nectar_due += _nectar_in(g)
	var nectar_room: int = maxi(0, mini(_tuning_int("nectar_cap") - _inventory.count(state, NECTAR_ID), _inventory.room(state, NECTAR_ID)))
	var nectar_added: int = mini(nectar_due, nectar_room)
	var nectar_converted: int = nectar_due - nectar_added
	var offered: int = coins_due + nectar_converted * _tuning_int("nectar_overflow_coin")
	var have_coins: int = _coins(state)
	var coins_added: int = clampi(_tuning_int("coin_cap") - have_coins, 0, offered)
	state["coins"] = have_coins + coins_added
	if nectar_added > 0:
		_inventory.add(state, NECTAR_ID, nectar_added)
	var out: Result = Result.new(Code.Ok)
	out.coins_added = coins_added
	out.coins_dropped = offered - coins_added
	out.nectar_added = nectar_added
	out.nectar_converted = nectar_converted
	if nectar_converted > 0 or out.coins_dropped > 0:
		out.code = Code.Overflowed
	return out


## Index of the next gift to auto-claim, or -1 when no cap is exceeded.
## A slot over pending_per_slot gives its oldest gift. Over pending_total, the oldest gift overall.
## The newest gift of each slot is never chosen.
func _victim(state: Dictionary, per_slot: int, total: int) -> int:
	var gifts: Array = _pending(state)
	var newest: Dictionary = {}
	var counts: Dictionary = {}
	for i: int in range(gifts.size()):
		var g: Dictionary = gifts[i]
		var slot: String = str(g["slot"])
		newest[slot] = i
		counts[slot] = int(counts.get(slot, 0)) + 1
	for i: int in range(gifts.size()):
		var g: Dictionary = gifts[i]
		var slot: String = str(g["slot"])
		if int(counts[slot]) > per_slot and i != int(newest[slot]):
			return i
	if gifts.size() > total:
		for i: int in range(gifts.size()):
			var g: Dictionary = gifts[i]
			var slot: String = str(g["slot"])
			if i != int(newest[slot]):
				return i
	return -1


## Claims the capped gifts one at a time. Returns the notes: an auto-claim that carries nectar
## reports {type: "auto_claim_nectar", slot, visit_seq, coins, nectar}.
func _enforce_caps(state: Dictionary) -> Array:
	var notes: Array = []
	var per_slot: int = _tuning_int("pending_per_slot")
	var total: int = _tuning_int("pending_total")
	var victim: int = _victim(state, per_slot, total)
	while victim >= 0:
		notes.append_array(_auto_claim(state, victim))
		victim = _victim(state, per_slot, total)
	return notes


func _auto_claim(state: Dictionary, index: int) -> Array:
	var gifts: Array = _pending(state)
	var gift: Dictionary = gifts[index]
	gifts.remove_at(index)
	_pay(state, [gift])
	var notes: Array = []
	var nectar: int = _nectar_in(gift)
	if nectar > 0:
		notes.append({"type": "auto_claim_nectar", "slot": str(gift["slot"]), "visit_seq": int(gift["visit_seq"]), "coins": int(gift["coins"]), "nectar": nectar})
	return notes


static func _nectar_in(gift: Dictionary) -> int:
	var n: int = 0
	var items: Array = gift.get("items", [])
	for item: Variant in items:
		if str(item) == NECTAR_ID:
			n += 1
	return n


## True when this visit already produced a gift: its seq is in the recent window or still pending. Read only.
func _already_gifted(state: Dictionary, visit_seq: int) -> bool:
	var gifted: Array = state.get("gifted_seqs", [])
	if gifted.has(visit_seq):
		return true
	var gifts: Array = state.get("pending_gifts", [])
	for gift: Variant in gifts:
		var g: Dictionary = gift
		if int(g["visit_seq"]) == visit_seq:
			return true
	return false


## Appends visit_seq to state.gifted_seqs and keeps only the last GIFTED_WINDOW entries.
func _remember_gifted(state: Dictionary, visit_seq: int) -> void:
	if typeof(state.get("gifted_seqs")) != TYPE_ARRAY:
		state["gifted_seqs"] = []
	var gifted: Array = state["gifted_seqs"]
	gifted.append(visit_seq)
	while gifted.size() > GIFTED_WINDOW:
		gifted.remove_at(0)


## state.pending_gifts, created when missing (for writes).
func _pending(state: Dictionary) -> Array:
	if typeof(state.get("pending_gifts")) != TYPE_ARRAY:
		state["pending_gifts"] = []
	return state["pending_gifts"]


func _coins(state: Dictionary) -> int:
	return int(state.get("coins", 0))


func _tuning_int(key: String) -> int:
	return int(_defs.tuning().get(key, 0))
