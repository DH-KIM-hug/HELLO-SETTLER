class_name MainScene
extends Node2D
## App entry: builds Defs, SaveStore and World, owns the views, runs the 1 s tick and the app lifecycle
## (F8), and turns the input requests into World calls. The views only draw and ask. The state lives in World.
## Test hooks (used by tools/shot_room.gd): save_sub, fresh_seed_override, manual_clock, clock_override.

const DATA_DIR: String = "res://data"
const FONT_PATH: String = "res://assets/fonts/NanumSquareRoundR.ttf"
const DEBUG_HOUR_S: int = 3600
const BACK_EXIT_WINDOW_MS: int = 2000

## Save folder under user:// (UserPaths.of(save_sub)).
var save_sub: String = "save"
## Fixed seed for a new game. -1 = random.
var fresh_seed_override: int = -1
## true: no 1 s timer. The caller drives World.tick itself.
var manual_clock: bool = false
## Unix seconds used as "now" when >= 0 (the caller's clock).
var clock_override: int = -1

var world: World
var _defs: Defs
var _store: SaveStore
var _font: Font
var _snap: Dictionary = {}
var _time_offset: int = 0
var _timer: Timer
var _room: RoomView
var _hud: Hud
var _sheet: ItemsSheet
var _shop: ShopScreen
var _popup: ConfirmPopup
var _toasts: Toasts
var _router: InputRouter
var _room_ids: Array[String] = []
var _room_index: int = 0
var _popup_callback: Callable = Callable()
var _back_ms: int = -100000
var _built: bool = false


func _ready() -> void:
	_font = load(FONT_PATH) as Font
	_defs = Defs.new().load_dir(DATA_DIR)
	_store = SaveStore.new(UserPaths.of(save_sub), _defs)
	world = World.new(_defs, _store)
	var fresh_seed: int = fresh_seed_override if fresh_seed_override >= 0 else randi()
	var offset: int = int(Time.get_time_zone_from_system()["bias"]) * 60
	_build_views()
	_connect_world()
	_router.stack.push("Busy")
	world.start(_now(), offset, fresh_seed)
	_router.stack.remove("Busy")
	_router.stack.push("Room")
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	if not manual_clock:
		_timer.start()
	_built = true
	refresh_all()


## Redraws every view from a fresh copy of the World state.
func refresh_all() -> void:
	if world == null or _router == null:
		return
	_snap = world.state_copy()
	var env: Dictionary = world.env_at(_now())
	_room_ids = _owned_room_ids(_snap)
	_room_index = clampi(_room_index, 0, maxi(_room_ids.size() - 1, 0))
	_room.set_state(_snap, env, _current_room(), _room_index, _room_ids.size())
	_hud.set_state(int(_snap.get("coins", 0)), env)
	_sheet.refresh(_snap)
	_shop.refresh(_snap)


## Opens the items sheet for a toy slot (the same thing a slot tap does).
func open_sheet_for(slot_id: String) -> void:
	_open_sheet(slot_id, ItemsSheet.TAB_TOYS)


func _notification(what: int) -> void:
	if world == null or not _built:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			world.on_app_paused(_now())
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_push_busy()
			world.on_app_resumed(_now())
			_pop_busy()
			refresh_all()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back_requested()


func _now() -> int:
	var base: int = clock_override if clock_override >= 0 else int(Time.get_unix_time_from_system())
	return base + _time_offset


func _build_views() -> void:
	_room = RoomView.new()
	add_child(_room)
	_room.setup(_defs, _font)

	var hud_layer: CanvasLayer = CanvasLayer.new()
	hud_layer.layer = 1
	add_child(hud_layer)
	_hud = Hud.new()
	hud_layer.add_child(_hud)
	_hud.setup(OS.is_debug_build())

	var over_layer: CanvasLayer = CanvasLayer.new()
	over_layer.layer = 2
	add_child(over_layer)
	_sheet = ItemsSheet.new()
	over_layer.add_child(_sheet)
	_sheet.setup(world, _defs)
	_sheet.now_source = Callable(self, "_now")
	_shop = ShopScreen.new()
	over_layer.add_child(_shop)
	_shop.setup(world, _defs)
	_popup = ConfirmPopup.new()
	over_layer.add_child(_popup)
	_popup.setup()

	var top_layer: CanvasLayer = CanvasLayer.new()
	top_layer.layer = 3
	add_child(top_layer)
	_toasts = Toasts.new()
	top_layer.add_child(_toasts)
	_toasts.setup()

	_router = InputRouter.new()
	add_child(_router)
	_router.hit_source = Callable(self, "_hits_for")
	_router.tapped.connect(_on_tapped)
	_router.swiped.connect(_on_swiped)

	_sheet.closed.connect(_on_sheet_closed)
	_sheet.notice.connect(_toast)
	_shop.closed.connect(_on_shop_closed)
	_shop.product_tapped.connect(_on_product_tapped)
	_popup.answered.connect(_on_popup_answered)


func _connect_world() -> void:
	world.visit_changed.connect(_on_world_changed)
	world.spirit_settled.connect(_on_world_changed)
	world.spirit_left.connect(_on_world_changed)
	world.gift_changed.connect(_on_world_changed)
	world.coins_changed.connect(_on_world_changed)
	world.bowl_changed.connect(_on_world_changed)
	world.unlocked.connect(_on_world_changed)
	world.catch_up_done.connect(_on_world_changed)


func _on_world_changed(_a: Variant = null, _b: Variant = null, _c: Variant = null) -> void:
	refresh_all()


func _on_tick() -> void:
	world.tick(_now(), _current_room(), true)
	refresh_all()


func _owned_room_ids(snap: Dictionary) -> Array[String]:
	var owned: Array = snap.get("rooms_owned", [])
	var out: Array[String] = []
	for room_id: String in _defs.ids("rooms"):
		if owned.has(room_id):
			out.append(room_id)
	return out


func _current_room() -> String:
	if _room_ids.is_empty():
		return ""
	return _room_ids[clampi(_room_index, 0, _room_ids.size() - 1)]


# ---------------------------------------------------------------- input

## Hit targets of the top context, for the InputRouter.
func _hits_for(context: String) -> Array:
	match context:
		"Room":
			return _room.hit_targets() + _hud.hit_targets()
		"Sheet":
			return _sheet.hit_targets()
		"Screen":
			return _shop.hit_targets()
		"Modal":
			return _popup.hit_targets()
	return []


func _on_tapped(context: String, kind: String, id: String) -> void:
	match context:
		"Room":
			_on_room_tap(kind, id)
		"Sheet":
			_sheet.on_tap(kind, id)
		"Screen":
			_shop.on_tap(kind, id)
		"Modal":
			_popup.on_tap(kind, id)


func _on_swiped(_context: String, direction: int) -> void:
	if _room_ids.size() < 2:
		return
	# direction -1 (swiped left) shows the next room.
	var next_index: int = clampi(_room_index - direction, 0, _room_ids.size() - 1)
	if next_index == _room_index:
		return
	_room_index = next_index
	refresh_all()


func _on_room_tap(kind: String, id: String) -> void:
	match kind:
		"spirit":
			_room.bounce(id)
		"gift":
			_claim(id)
		"bowl":
			_tap_bowl(id)
		"slot":
			_open_sheet(id, ItemsSheet.TAB_TOYS)
		"menu":
			_on_menu(id)
		"debug":
			_plus_hour()


func _on_menu(id: String) -> void:
	match id:
		"shop":
			_open_shop()
		"items":
			_open_sheet("", ItemsSheet.TAB_TOYS)
		_:
			_toast(tr("toast.coming_soon"))


func _claim(slot_id: String) -> void:
	var result: Wallet.Result = world.claim_gift(slot_id)
	if result.code != Wallet.Code.AlreadyClaimed:
		var text: String = tr("toast.gift") % result.coins_added
		if result.nectar_added > 0:
			text += "  " + tr("toast.nectar") % result.nectar_added
		_toast(text)
	refresh_all()


## An empty bowl is filled with basic food at once. A bowl with food opens the sheet on the food tab.
func _tap_bowl(bowl_slot: String) -> void:
	var bowls: Dictionary = _snap.get("food_bowls", {})
	var bowl: Dictionary = bowls.get(bowl_slot, {})
	var amount: float = float(bowl.get("amount", 0.0))
	if amount <= FoodBowls.EMPTY_LIMIT:
		var fed: FoodBowls.Result = world.fill_bowl(bowl_slot, "food_basic", _now())
		if fed.code != FoodBowls.Code.Ok and fed.code != FoodBowls.Code.NoChange:
			_toast(UiKit.result_text(tr("msg.retry"), FoodBowls.Code.keys()[fed.code]))
		refresh_all()
	else:
		_open_sheet(bowl_slot, ItemsSheet.TAB_FOOD)


func _open_sheet(slot_id: String, tab: String) -> void:
	_sheet.open(slot_id, tab, world.state_copy())
	_router.stack.push("Sheet")
	refresh_all()


func _on_sheet_closed() -> void:
	_router.stack.remove("Sheet")
	refresh_all()


func _open_shop() -> void:
	_shop.open(world.state_copy())
	_router.stack.push("Screen")


func _on_shop_closed() -> void:
	_router.stack.remove("Screen")
	refresh_all()


func _on_product_tapped(product_id: String) -> void:
	var state: String = world.shop_state(product_id)
	match state:
		"available", "not_enough":
			var price: int = int(_defs.product(product_id).get("price", 0))
			var message: String = "%s\n%s\n%s" % [product_id, tr("shop.price") % price, tr("confirm.buy")]
			_ask(message, tr("btn.buy"), tr("btn.cancel"), _on_buy_answer.bind(product_id))
		"locked":
			_toast(UiKit.result_text(tr("msg.buy_locked"), "Locked"))
		"limit":
			_toast(UiKit.result_text(tr("msg.buy_limit"), "LimitReached"))
		"inventory_full":
			_toast(UiKit.result_text(tr("msg.buy_full"), "InventoryFull"))


func _on_buy_answer(product_id: String) -> void:
	var result: Shop.Result = world.buy(product_id, _now())
	var target: String = str(_defs.product(product_id).get("target", ""))
	if result.code == Shop.Code.Success and _defs.has_id("rooms", target):
		_shop.close()
		_room_ids = _owned_room_ids(world.state_copy())
		_room_index = maxi(0, _room_ids.find(target))
		_toast(UiKit.result_text(tr("msg.buy_room"), "Success"))
	else:
		var message: String = _shop_message(result.code)
		_toast(UiKit.result_text(message, Shop.Code.keys()[result.code]))
	refresh_all()


func _shop_message(code: int) -> String:
	match code:
		Shop.Code.Success:
			return tr("msg.buy_ok")
		Shop.Code.NotEnoughCurrency:
			return tr("msg.buy_short")
		Shop.Code.Locked:
			return tr("msg.buy_locked")
		Shop.Code.AlreadyOwned:
			return ""
		Shop.Code.LimitReached:
			return tr("msg.buy_limit")
		Shop.Code.InventoryFull:
			return tr("msg.buy_full")
	return tr("msg.retry")


func _ask(message: String, ok_text: String, cancel_text: String, callback: Callable) -> void:
	_popup.open(message, ok_text, cancel_text)
	_popup_callback = callback
	_router.stack.push("Modal")


func _on_popup_answered(ok: bool) -> void:
	_router.stack.remove("Modal")
	var callback: Callable = _popup_callback
	_popup_callback = Callable()
	if ok and callback.is_valid():
		callback.call()
	refresh_all()


## Debug only: the app is "closed" for an hour (pause, shift the clock, resume), so the catch-up runs.
func _plus_hour() -> void:
	_push_busy()
	world.on_app_paused(_now())
	_time_offset += DEBUG_HOUR_S
	world.on_app_resumed(_now())
	_pop_busy()
	_toast("+1h")
	refresh_all()


func _on_back_requested() -> void:
	match _router.stack.top():
		"Modal":
			_popup.on_tap("button", "cancel")
		"Screen":
			_shop.close()
		"Sheet":
			_sheet.close()
		"Room":
			var now_ms: int = Time.get_ticks_msec()
			if now_ms - _back_ms < BACK_EXIT_WINDOW_MS:
				get_tree().quit()
			else:
				_back_ms = now_ms
				_toast(tr("msg.back_again"))


func _push_busy() -> void:
	if _router != null:
		_router.stack.push("Busy")


func _pop_busy() -> void:
	if _router != null:
		_router.stack.remove("Busy")


func _toast(text: String) -> void:
	if _toasts != null:
		_toasts.show_text(text)
