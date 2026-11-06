## 거인의 손 — 아래 띠 [손] 칸 (UI 01 · A9) + 손에 든 물건 떨어뜨리기 (SHOP 3 · WORLD_EVENTS 3 · 4 · A7).
## 칸 (아래 띠 위에 펼쳐짐): 뚜껑 열기/닫기 (닫힐 때까지 남은 초) · 불기 (뚜껑이 열린 동안) · 등불 옮기기 /
##   손에 든 것 (Market.hand — 5칸). 물건을 누르면 → 뚜껑이 열리고 (한 번 열고 여러 개 — 병의 법칙) 떨어뜨릴 자리 고르기:
##   땅 위 그림자 + 그 위에 거인의 손이 물건을 들고 기다림. 손가락으로 끌면 그림자가 따라옴, [떨어뜨리기]로 놓음.
##   물건 칸에서 바로 땅으로 끌어 놓으면 곧바로 떨어진다 (경고가 있으면 멈추고 묻는다).
##   집·사람 위면 붉게 ("여기 떨어뜨리면 집이 부서져요") — 그래도 놓을 수 있다. 건물은 빈 땅만 + 자리 말 (농사 잘 되는 땅 …).
## 장면(view/test_village.gd · world_village.gd)이 가진다: 손가락 끌기·톡을 aiming() 동안 aim_at으로 돌려준다.
class_name GiantHandCtl
extends Node

const AIM_LIFT := 46.0                 # 손가락 위로 띄워 그림자가 손가락에 가리지 않게 (화면 px)
const HOLD_H := 5.5                    # 거인의 손이 물건을 들고 기다리는 높이 (칸)
const DRAG_START := 14.0
const SLOT_PX := 54.0

var sc: Node                           # 장면 (TestVillage 계열)
var tray: PanelContainer
var lid_btn: Button
var blow_btn: Button
var lamp_btn: Button
var hand_title: Label
var hint: Label
var slot_row: HBoxContainer
var slots: Array[Button] = []
var banner: PanelContainer
var b_icon: TextureRect
var b_name: Label
var b_text: Label
var drop_btn: Button
var cancel_btn: Button
var _hand_sig := ""
var _aim: Dictionary = {}              # {id, item, p, pv, v, root, shadow, held}
var _press: Dictionary = {}            # 물건 칸을 누름 {id, pos, drag}
var _t := 0.0


func _init(scene: Node) -> void:
	sc = scene
	name = "GiantHandCtl"


# ───────────────────────── 칸 ─────────────────────────
func build(root: Control) -> void:
	tray = PanelContainer.new()
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := UiTheme._box(Color(0.984, 0.965, 0.902, 0.97), UiTheme.INK, 1, 0, 8)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.border_width_bottom = 0
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 5
	tray.add_theme_stylebox_override("panel", sb)
	tray.visible = false
	root.add_child(tray)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	tray.add_child(col)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP)
	col.add_child(row)
	lid_btn = _btn(row, "뚜껑 열기", "뚜껑", Callable(sc, "toggle_lid"))
	blow_btn = _btn(row, "불기", "불기", Callable(sc, "blow"))
	lamp_btn = _btn(row, "등불 옮기기", "등불", Callable(sc, "move_lamp"))
	col.add_child(HSeparator.new())
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	col.add_child(head)
	head.add_child(GameIcons.rect("손", 22))
	hand_title = Label.new()
	hand_title.add_theme_font_override("font", UiTheme.font(true))
	hand_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(hand_title)
	hint = Label.new()
	hint.theme_type_variation = "Small"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.clip_text = true
	head.add_child(hint)
	slot_row = HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", UiTheme.GAP)
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(slot_row)
	for i in Shop.HAND_MAX:
		var s := Button.new()
		s.focus_mode = Control.FOCUS_NONE
		s.custom_minimum_size = Vector2(SLOT_PX, SLOT_PX)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.expand_icon = true
		s.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_constant_override("icon_max_width", 40)
		s.button_down.connect(_on_slot_down.bind(i))
		slot_row.add_child(s)
		slots.append(s)
	# 자리 고르기 띠
	banner = PanelContainer.new()
	banner.mouse_filter = Control.MOUSE_FILTER_STOP
	banner.add_theme_stylebox_override("panel", sb.duplicate())
	banner.visible = false
	root.add_child(banner)
	var bc := VBoxContainer.new()
	bc.add_theme_constant_override("separation", 6)
	banner.add_child(bc)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 8)
	bc.add_child(br)
	b_icon = GameIcons.rect("", 40)
	br.add_child(b_icon)
	var bt := VBoxContainer.new()
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.add_theme_constant_override("separation", 2)
	br.add_child(bt)
	b_name = Label.new()
	b_name.add_theme_font_override("font", UiTheme.font(true))
	bt.add_child(b_name)
	b_text = Label.new()
	b_text.theme_type_variation = "Small"
	b_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bt.add_child(b_text)
	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", UiTheme.GAP)
	bc.add_child(bb)
	cancel_btn = _btn(bb, "그만두기", "", cancel_drop)
	drop_btn = _btn(bb, "떨어뜨리기", "", confirm_drop)
	drop_btn.theme_type_variation = "Primary"


func _btn(parent: Node, text: String, icon: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UiTheme.TOUCH, UiTheme.TOUCH)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	if icon != "":
		GameIcons.button_icon(b, icon, 24)
	b.pressed.connect(GameAudio.ui_click)
	b.pressed.connect(on_press)
	parent.add_child(b)
	return b


func is_open() -> bool:
	return tray != null and tray.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if aiming():
		cancel_drop()
	tray.visible = true
	_hand_sig = ""
	refresh()


func close() -> void:
	if tray != null:
		tray.visible = false


## 칸 높이 (장면이 알림 줄을 그 위로 올린다)
func height() -> float:
	if tray != null and tray.visible:
		return tray.size.y
	if banner != null and banner.visible:
		return banner.size.y
	return 0.0


func layout(bottom_h: float) -> void:
	for p: PanelContainer in [tray, banner]:
		p.anchor_left = 0.0
		p.anchor_right = 1.0
		p.anchor_top = 1.0
		p.anchor_bottom = 1.0
		p.offset_left = 6
		p.offset_right = -6
		p.offset_bottom = -bottom_h + 1.0
		p.grow_vertical = Control.GROW_DIRECTION_BEGIN
		p.offset_top = p.offset_bottom - p.get_combined_minimum_size().y


## 매 화면: 뚜껑 글자·불기·손에 든 것
func refresh() -> void:
	var v: Village = sc.focus_village()
	var open_lid: bool = v.air.lid_open
	if open_lid:
		lid_btn.text = "뚜껑 닫기 %d" % ceili(Balance.LID_AUTO_CLOSE_REAL - sc.clock.lid_real)
		lid_btn.modulate = Color(1, 0.9, 0.6)
	else:
		lid_btn.text = "뚜껑 열기"
		lid_btn.modulate = Color.WHITE
	blow_btn.visible = open_lid
	var sig := str(Market.hand)
	if sig == _hand_sig:
		return
	_hand_sig = sig
	hand_title.text = "손에 든 것 %d / %d" % [Market.hand.size(), Shop.HAND_MAX]
	hint.text = "누르거나 끌어서 떨어뜨려요" if not Market.hand.is_empty() else "상점에서 산 것이 여기 들려요"
	for i in slots.size():
		var s := slots[i]
		for c in s.get_children():
			c.queue_free()
		if i < Market.hand.size():
			var item := String(Market.hand[i]["item"])
			s.disabled = false
			s.tooltip_text = item
			if Shop.is_building(item):
				s.icon = null
				var cc := CenterContainer.new()
				cc.set_anchors_preset(Control.PRESET_FULL_RECT)
				cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
				s.add_child(cc)
				cc.add_child(BuildingThumb.rect(item, 40))
			else:
				s.icon = GameIcons.tex(item)
			s.modulate = Color.WHITE
		else:
			s.icon = null
			s.disabled = true
			s.tooltip_text = ""
			s.modulate = Color(1, 1, 1, 0.45)


func _on_slot_down(i: int) -> void:
	if i >= Market.hand.size():
		return
	_press = {"id": int(Market.hand[i]["id"]), "pos": sc.get_viewport().get_mouse_position(), "drag": false}


# ───────────────────────── 자리 고르기 ─────────────────────────
func aiming() -> bool:
	return not _aim.is_empty()


## 손에 든 물건 하나를 고름 → 뚜껑을 열고 (닫혀 있으면) 그림자 + 거인의 손
func start_drop(id: int, sp: Variant = null) -> void:
	var h := Shop.hand_item(id)
	if h.is_empty():
		return
	if aiming():
		_clear_aim()
	close()
	var v: Village = sc.focus_village()
	if not v.air.lid_open:
		sc.toggle_lid()                                # 병의 법칙: 뚜껑을 열고 넣는다 (날벌레·온기·물 — Village.open_lid)
	sc.clock.lid_real = 0.0
	var item := String(h["item"])
	var root := Node3D.new()
	sc.jar.add_child(root)
	var shadow := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.height = 0.04
	cy.radial_segments = 32
	shadow.mesh = cy
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = false
	m.albedo_color = Color(0.1, 0.08, 0.06, 0.38)
	shadow.material_override = m
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)
	var ring := MeshInstance3D.new()                  # 그림자 테두리 (어디에 떨어질지 또렷하게)
	ring.mesh = TorusMesh.new()
	var rm := m.duplicate() as StandardMaterial3D
	ring.material_override = rm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var line := MeshInstance3D.new()                  # 물건에서 그림자까지 가는 선
	var lm := CylinderMesh.new()
	lm.top_radius = 0.05
	lm.bottom_radius = 0.05
	lm.height = HOLD_H
	lm.radial_segments = 6
	line.mesh = lm
	var lmat := m.duplicate() as StandardMaterial3D
	lmat.albedo_color = Color(1, 1, 1, 0.55)
	line.material_override = lmat
	line.position.y = HOLD_H * 0.5
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(line)
	var held := Node3D.new()
	root.add_child(held)
	var thing: Node3D
	if Shop.is_building(item):
		var names: Array = VillageView.BUILDING_MODELS.get(item, ["hut"])
		thing = Node3D.new()
		Art.instance(thing, String(names[0]))
		thing.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG)
	else:
		thing = SkyDropView.make_item(item)
	held.add_child(thing)
	var size := float(Balance.B[item]["size"]) if Shop.is_building(item) else float(Shop.ITEMS[item].get("size", 1.5))
	var hand := SkyDropView.giant_hand(maxf(1.2, size * 0.9))
	hand.position = Vector3(0, (2.4 if Shop.is_building(item) else 1.6) * maxf(1.0, size * 0.6), 0)
	held.add_child(hand)
	_aim = {"id": id, "item": item, "root": root, "shadow": shadow, "ring": ring, "held": held, "size": size, "pv": {}, "p": Vector2.ZERO}
	b_icon.texture = GameIcons.tex(item) if not Shop.is_building(item) else GameIcons.tex("마을로 가기")
	b_name.text = item
	banner.visible = true
	if sp == null:
		var vs: Vector2 = sc.get_viewport().get_visible_rect().size
		sp = Vector2(vs.x * 0.5, vs.y * 0.42)
		aim_at(sp, false)
	else:
		aim_at(sp, true)
	GameAudio.fx("paper", "Room", -10.0)


## 화면 위 점 → 그림자 자리 (touch = 손가락 위로 띄움)
func aim_at(sp: Vector2, touch: bool) -> void:
	if not aiming():
		return
	var q: Vector2 = sp - Vector2(0, AIM_LIFT if touch else 0.0)
	var p: Vector2 = sc.screen_to_ground(q)
	var v: Village = sc.village_at(p)
	_aim["p"] = p
	_aim["v"] = v
	var pv := SkyDrops.preview(v, String(_aim["item"]), p)
	_aim["pv"] = pv
	var root: Node3D = _aim["root"]
	var gy: float = sc.terrain.ground_y(p.x, p.y)
	root.position = Vector3(p.x, gy, p.y)
	var size := float(_aim["size"]) * (1.0 if not Shop.is_building(String(_aim["item"])) else 1.15)
	var cy := (_aim["shadow"] as MeshInstance3D).mesh as CylinderMesh
	cy.top_radius = size
	cy.bottom_radius = size
	(_aim["shadow"] as MeshInstance3D).position.y = 0.06
	var m := (_aim["shadow"] as MeshInstance3D).material_override as StandardMaterial3D
	var ring := _aim["ring"] as MeshInstance3D
	var tm := ring.mesh as TorusMesh
	tm.inner_radius = size - 0.09
	tm.outer_radius = size + 0.09
	ring.position.y = 0.1
	var warn := String(pv.get("warn", ""))
	var rmat := ring.material_override as StandardMaterial3D
	if not bool(pv["ok"]):
		m.albedo_color = Color(0.25, 0.22, 0.2, 0.32)
		rmat.albedo_color = Color(0.3, 0.28, 0.26, 0.6)
		b_text.text = String(pv["why"])
		b_text.add_theme_color_override("font_color", UiTheme.INK_SOFT)
		drop_btn.disabled = true
		drop_btn.text = "떨어뜨리기"
	elif warn != "":
		m.albedo_color = Color(0.86, 0.16, 0.1, 0.5)
		rmat.albedo_color = Color(0.95, 0.2, 0.12, 0.95)
		b_text.text = warn
		b_text.add_theme_color_override("font_color", Color("b3261e"))
		drop_btn.disabled = false
		drop_btn.text = "그래도 떨어뜨리기"
	else:
		m.albedo_color = Color(0.1, 0.08, 0.06, 0.38)
		rmat.albedo_color = Color(1.0, 0.97, 0.85, 0.9)
		var good := String(pv.get("good", ""))
		b_text.text = good if good != "" else "여기에 떨어뜨려요 — 손가락으로 끌어 자리를 옮겨요"
		b_text.add_theme_color_override("font_color", UiTheme.INK)
		drop_btn.disabled = false
		drop_btn.text = "여기에 놓기" if Shop.is_building(String(_aim["item"])) else ("내려놓기" if String(_aim["item"]) == Immigrants.ITEM else "떨어뜨리기")


func cancel_drop() -> void:
	_clear_aim()


func _clear_aim() -> void:
	if not _aim.is_empty():
		(_aim["root"] as Node).queue_free()
	_aim = {}
	_press = {}
	banner.visible = false


## [떨어뜨리기] — 손에서 빼고 (저장은 한 번에: begin/end_giant) 병 안에 떨어진다. 손에 남은 것이 있으면 칸을 다시 연다
func confirm_drop() -> void:
	if not aiming():
		return
	var pv: Dictionary = _aim["pv"]
	if pv.is_empty() or not bool(pv["ok"]):
		return
	var v: Village = _aim["v"]
	if not v.air.lid_open:
		sc.toggle_lid()
	var id := int(_aim["id"])
	var item := String(_aim["item"])
	var p: Vector2 = _aim["p"]
	var h := Shop.hand_item(id)
	var idx := Market.hand.find(h)
	v.begin_giant()
	Shop.hand_remove(id)
	var r := SkyDrops.drop(v, item, p, h)
	if not bool(r["ok"]):
		Market.hand.insert(maxi(0, idx), h)
	v.end_giant()
	if not bool(r["ok"]):
		b_text.text = String(r.get("why", ""))
		return
	sc.clock.lid_real = 0.0
	var root: Node3D = _aim["root"]
	var held: Node3D = _aim["held"]
	_aim = {}
	banner.visible = false
	# 손은 물건을 놓고 올라간다 (물건은 SkyDropView가 떨어뜨림)
	var thing := held.get_child(0) as Node3D
	if thing != null:
		thing.visible = false
	(root.get_child(0) as Node3D).visible = false
	var tw := sc.create_tween()
	tw.tween_property(held, "position:y", held.position.y + 30.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	if r.has("building"):
		sc.drop_building_fx(v, r["building"])
		GameAudio.say("miracle")
	else:
		sc.after_drop(v)
		GameAudio.say("miracle")
	if not Market.hand.is_empty():
		open()


# ───────────────────────── 매 화면 ─────────────────────────
func process(dt: float) -> void:
	_t += dt
	if tray.visible:
		refresh()
	if aiming():
		sc.clock.lid_real = 0.0                         # 고르는 동안은 뚜껑이 저절로 닫히지 않음
		var held: Node3D = _aim["held"]
		held.position.y = HOLD_H + 0.35 * sin(_t * 2.2)
	if not _press.is_empty():
		var mp: Vector2 = sc.get_viewport().get_mouse_position()
		var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if not bool(_press["drag"]) and mp.distance_to(_press["pos"]) > DRAG_START and down:
			_press["drag"] = true
			start_drop(int(_press["id"]), mp)
		if bool(_press.get("drag", false)) and aiming():
			aim_at(mp, true)
		if not down:
			var was_drag := bool(_press["drag"])
			var id := int(_press["id"])
			_press = {}
			if not was_drag:
				start_drop(id)
			elif aiming():
				var pv: Dictionary = _aim["pv"]
				var vs: Vector2 = sc.get_viewport().get_visible_rect().size
				if mp.y < vs.y - sc.bottom_h - 10.0 and bool(pv.get("ok", false)) and String(pv.get("warn", "")) == "":
					confirm_drop()
