## 넓은 세상 장면 = 본 게임의 병 안 (StartFlow.GAME_SCENE) — 기획서 v3.8 3.1·5.1·5.5 · UI 01·02·03·09·10·00 · SAVE.md.
## 마을 장면(view/test_village.gd)의 화면·조작(위아래 띠·제단·뚜껑·불기·속도·설정·주민 상세·따라가기·알림·유리 톡·
## 소리·개발 모드·뒤로 가기·저장·따라잡기·편지)을 그대로 물려받고, 땅만 넓은 세상으로 바꾼다:
##   - 새 세상(무작위 시드 — world_seed가 0이 아니면 그 시드). 짧은 창조에서 들어온 새 병(StartFlow "new")이면 먼저 키트 자리 고르기
##     (OPENING 단계 8 — 안개 없는 세상 전체 + 빛나는 추천 자리 3~5곳, 누르면 그 자리에 키트 → 안개 → 그 빈터로 날아 내려감).
##     그 밖(캡처·시험·pick_spot = false)은 첫 추천 자리에 바로 키트.
##   - 무리가 여럿이면 무리마다 VillageView. 제단·유리 톡·불기·소리·위 띠 = 카메라가 보고 있는 무리 (focus_village)
##   - 뚜껑은 병 하나에 하나 → 모든 무리가 함께. 병 돌리기(빛)는 세상 전체 (JarWorld.rotate_jar)
##   - 분가 편지 [새 땅 고르기] → 세상을 멀리 보여 주고 거인이 땅을 누른다 (아니면 [알아서 고르기] = 가까운 좋은 자리)
##   - 오른쪽 위 둥근 지도 (UI 09 — view/ui/world_minimap.gd): 본 땅·무리·지금 보는 곳. 누르면 그곳으로 날아감 (무리 점이면 그 마을 광장)
##   - [마을로 가기] (지도 아래): 무리가 하나면 그 마을로, 여럿이면 작은 목록 → 구글 어스식 날아가기 (JarCamera.fly_to — GIANT_ROOM 4)
##   - 구글 어스식 확대 (B1 — GIANT_ROOM 4): 마을 → 넓은 땅 → 세상 전체(유리벽) → 유리병 → 거인의 방까지 한 번에 오므림 (view/room/room_zoom.gd).
##     같은 3D 장면에 거인의 방이 세상에 맞는 크기로 서 있고 카메라만 움직인다. [병 밖으로] = 방까지 지름길. 방에서 [마을로 가기]·병 두 번 톡 = 날아 들어감.
##     타이틀 [이어하기]는 방에서 시작해 마을로 날아 들어오고 (StartFlow "continue"), 뒤로 가기 → 방으로 날아 나간 뒤 타이틀.
##   - 저장: 세상 전체 (JarWorld — 땅·물·안개·무리마다 주민·곰팡이·하늘의 것) · 따라잡기도 세상 전체 (CatchUp world)
##   - 느린 기기(코어 4개 이하 또는 메모리 3 GB 미만)는 작은 세상 WorldCfg.SMALL_SIZE (default_size)
## 땅은 view/world_terrain.gd (조각·LOD·안개), 시뮬레이션은 sim/jar_world.gd. 병 돌리기는 데이터 대신 병 노드가 돈다.
## 개발 키: G = 안개 켜고 끄기, K = 다른 추천 자리에 키트 하나 더.
extends "res://view/test_village.gd"

@export var world_seed := 0          # 0 = 새 무작위 세상 (창조할 때마다 새 시드)
@export var world_size := 0          # 0 = 기기에 맞게 (default_size)
@export var kit_variant := ""
@export var pick_spot := true        # 새 병이면 키트 자리를 거인이 고른다 (시험·캡처는 끔 — force_pick이면 직접 띄워도)
@export var force_pick := false        # (7단계) 첫 키트의 종류 — Kits.VARIANTS 이름 (예: "힘센 가족"), 비우면 기본 키트

signal zoom_beyond_world(amount: float)   # 거인의 방보다 더 오므림 (log2 몫) — 나중 선반 화면(UI 05)이 이어받을 곳
@export var room_view := true        # (B1) 병 밖 = 거인의 방 (시험·캡처는 끌 수 있음)

var room_zoom: RoomZoom
var out_btn: Button                  # [병 밖으로] (UI 09 — 방까지 지름길)
var _tap_t := -1.0                   # 병 밖에서 병 두 번 톡 = 들어가기
var _proc_ms := 0.0                  # 이 장면 _process 시간 (시뮬레이션 + 화면 갱신, 평균 — 성능 측정용)
var _enter_fly := false              # 타이틀 [이어하기] → 방에서 마을로 날아 들어오는 중 (따라잡기가 끝나면)
var _last_letter: Dictionary = {}     # 마지막 '자리를 비운 동안' 편지 (유리에 붙은 편지로 다시 읽기)
var letter_unread := false            # 아직 안 읽음 → 병 밖(④⑤)에서 유리에 붙어 보임

const LOW_CORES := 4
const ARRIVE_PPU := 16.0             # 날아가서 내려앉는 확대 (기본 확대)
const LOW_MEM := 3.0 * 1024.0 * 1024.0 * 1024.0
const TITLE_HANDOFF := 0.62          # 타이틀이 병 쪽으로 다가가다 넘겨주는 beyond (④ 병 전체 — 유리 바깥)
const LEAVE_TIME := 0.9              # 뒤로 가기 → 방으로 날아 나가는 시간
const DOUBLE_TAP := 0.35

var world: JarWorld
var wterrain: WorldTerrain
var extra_views: Array = []          # 두 번째 무리부터 [Village, VillageView]
var minimap: WorldMinimap
var _focus: Village
var _rot_shown := 0
var _fog_v := -1
var _rev_r := 0.0
var _outline_off := false
var _outline_was: Variant = true
var _lid_sync := false
var _seen_v := -1
var _seen_n := 0
# 분가 자리 고르기 (기획서 3.1 '거인이 안개 밖 자리를 고르면')
var split_from: Village = null
var split_bar: PanelContainer
var split_label: Label
var goto_btn: Button
var goto_list: PanelContainer
var goto_box: VBoxContainer


## 이 기기의 세상 크기 — 느린 기기는 작은 세상 (지름 512칸)
static func default_size() -> int:
	var mem := float(OS.get_memory_info().get("physical", 0))
	if OS.get_processor_count() <= LOW_CORES or (mem > 0.0 and mem < LOW_MEM):
		return WorldCfg.SMALL_SIZE
	return WorldCfg.SIZE


func _make_village() -> Village:
	if world != null and not world.settlements.is_empty():     # 키트 자리 고르기에서 이미 놓음
		return world.primary()
	var sd := world_seed if world_seed != 0 else WorldGen.new_seed()
	var size := world_size if world_size > 0 else default_size()
	world = JarWorld.create(sd, size)
	var rec := world.recommended_kit_spots()
	var v := world.place_kit(rec[0].x, rec[0].y, Kits.make(_kit_ups(use_save), kit_variant))
	print("세상 시드 %d · 지름 %d칸 · 추천 자리 %d곳 · 첫 키트 %s" % [sd, size, rec.size(), str(v.center)])
	return v


## 새 세상의 스타터킷에 함께 놓일 키트 업그레이드 (선반에서 산 것 중 켠 것 — C1 · 기획서 5.5). 저장을 쓰지 않는 장면(시험·캡처)은 기본 키트
func _kit_ups(saving: bool) -> Array:
	var sm := GameSave.get_instance()
	if not saving or sm == null or not sm.enabled:
		return []
	return sm.kit_upgrades()


# ───────────────────────── 키트 자리 고르기 (OPENING 단계 8 '스타터킷 풀기' — 최소판) ─────────────────────────
## 안개 없는 세상 전체를 내려다보고 빛나는 추천 자리를 누른다 → 키트를 놓고 나서야 병 안 장면(위아래 띠·마을)을 만든다
var _pick: Dictionary = {}           # 고르는 중인 화면 {root, cam, terrain, layer, marks: [[node, label, choice]], confirm, caption, t}
var _pick_ups: Array = []            # 첫 키트에 넣을 키트 업그레이드 (선반 — C1)


func _ready() -> void:
	if (pick_spot and StartFlow.mode == "new") or force_pick:
		_begin_pick()
		return
	super()


func _begin_pick() -> void:
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var gsm := GameSave.get_instance()
	_pick_ups = []
	if gsm != null and gsm.enabled and not force_pick:        # 선반에서 산 새 병 (C1): 거인 묶음(키트 업그레이드)을 먼저 — 앱을 다시 켠 뒤에도
		if gsm.order.is_empty() and gsm.has_save():
			gsm.load_all(false)
		_pick_ups = gsm.kit_upgrades()
	var sd := world_seed if world_seed != 0 else WorldGen.new_seed()
	var size := world_size if world_size > 0 else default_size()
	if StartFlow.pending_world != null:            # 창조 오프닝이 만든 세상 (거인의 선택이 담긴)
		world = StartFlow.pending_world
		StartFlow.pending_world = null
		_plan = StartFlow.plan
		sd = world.seed_v
		size = world.water.n
	else:
		world = JarWorld.create(sd, size)
	var root := Node3D.new()
	add_child(root)
	JarTerrain.make_world(root)
	var pt := WorldTerrain.new(world.water)
	pt.reveal_all = true               # 아직 안개 없음
	root.add_child(pt)
	pt.set_fog_visible(false)
	var g := pt.make_glass()
	root.add_child(g)
	var pc := JarCamera.new()
	root.add_child(pc)
	pc.ppu_min = 0.2
	pc.ground_radius = world.water.rr + 40.0
	var vs := get_viewport().get_visible_rect().size
	var fit := minf(vs.x, vs.y * 0.8) / (world.water.n * 1.08)    # 세상 전체 + 유리벽
	pc.ppu = fit
	pc.ppu_goal = fit
	pc.target = Vector3(0, 0, 0)
	pc._apply()
	pt.zoom_ppu(fit)
	pt.set_focus(Vector2.ZERO, pc.view_radius())
	pt.update_now()
	OutlinePost.attach(pc.camera).set_shader_parameter("use_outline", false)
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.get_theme()
	layer.add_child(ui)
	var cap := Label.new()
	cap.text = "이 세상에 살 사람들을 데려왔어요.\n빛나는 곳은 물가·숲 곁이에요. 내려놓을 곳을 눌러 주세요."
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cap.offset_top = SafeArea.insets(get_viewport()).x + 24.0
	cap.offset_left = 16
	cap.offset_right = -16
	cap.add_theme_color_override("font_color", Color("fffbea"))
	cap.add_theme_color_override("font_shadow_color", Color("242121"))
	cap.add_theme_constant_override("shadow_offset_x", 1)
	cap.add_theme_constant_override("shadow_offset_y", 1)
	ui.add_child(cap)
	var marks: Array = []
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.82, 0.3, 0.7)
	mat.no_depth_test = true
	for ch: Dictionary in world.spot_choices(5):
		var p: Vector2 = ch["p"]
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 26.0
		cm.bottom_radius = 26.0
		cm.height = 0.4
		cm.radial_segments = 32
		disc.mesh = cm
		disc.material_override = mat.duplicate()
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position = Vector3(p.x, pt.ground_y(p.x, p.y) + 3.0, p.y)
		root.add_child(disc)
		var l := Label.new()
		l.text = String(ch["reason"])
		l.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
		l.add_theme_color_override("font_color", Color("242121"))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("fffbea")
		sb.border_color = Color("242121")
		sb.set_border_width_all(1)
		sb.set_content_margin_all(2)
		l.add_theme_stylebox_override("normal", sb)
		ui.add_child(l)
		marks.append([disc, l, ch])
	var cs := ConfirmSheet.new()
	layer.add_child(cs)
	_pick = {"root": root, "cam": pc, "terrain": pt, "layer": layer, "marks": marks, "confirm": cs, "caption": cap, "t": 0.0, "pending": null}
	cs.answered.connect(func(yes: bool) -> void:
		var pp: Variant = _pick.get("pending")
		_pick["pending"] = null
		if yes and pp != null:
			_place_first_kit(pp as Vector2))
	print("세상 시드 %d · 지름 %d칸 · 키트 자리 고르기 (추천 %d곳)" % [sd, size, marks.size()])
	if _plan != null:
		cap.add_theme_font_override("font", UiTheme.font(true))
		GameAudio.fx("paper", "Room", -8.0)
		if _plan.stage == "name" and _plan.spot.size() == 2:    # 이름 짓다가 꺼졌음 → 고른 자리 그대로
			_place_first_kit(Vector2(float(_plan.spot[0]), float(_plan.spot[1])))


func _pick_process(dt: float) -> void:
	_pick["t"] = float(_pick["t"]) + dt
	var pc: JarCamera = _pick["cam"]
	var a := 0.62 + 0.25 * sin(float(_pick["t"]) * 3.0)         # 은은하게 빛남
	for m: Array in _pick["marks"]:
		var disc: MeshInstance3D = m[0]
		(disc.material_override as StandardMaterial3D).albedo_color.a = a
		var l: Label = m[1]
		var sp := pc.camera.unproject_position(disc.global_position)
		l.position = Vector2(roundf(sp.x - l.get_minimum_size().x * 0.5), roundf(sp.y + 10.0))


## 고르는 화면 위 한 점 → 땅 위 점 (세상 좌표)
func _pick_ground(sp: Vector2) -> Vector2:
	var pc: JarCamera = _pick["cam"]
	var pt: WorldTerrain = _pick["terrain"]
	var o := pc.camera.project_ray_origin(sp)
	var n := pc.camera.project_ray_normal(sp)
	var y := 0.0
	var hit := Vector3.ZERO
	for i in 3:
		var t := (y - o.y) / n.y if absf(n.y) > 1e-5 else 0.0
		hit = o + n * t
		y = pt.ground_y(hit.x, hit.z)
	return Vector2(hit.x, hit.z)


## 누른 곳: 빛나는 자리 가까이면 그 자리, 아니면 누른 땅. 놓을 수 없으면 까닭, 물이 멀면 "정말 여기에 둘까요?"
func pick_at(sp: Vector2) -> void:
	var pc: JarCamera = _pick["cam"]
	var p := _pick_ground(sp)
	for m: Array in _pick["marks"]:
		var c: Vector2 = m[2]["p"]
		if pc.camera.unproject_position((m[0] as Node3D).global_position).distance_to(sp) < 28.0:
			p = c
	choose_spot(p)


func choose_spot(p: Vector2) -> void:
	var r := world.kit_spot_ok(p.x, p.y)
	var cap: Label = _pick["caption"]
	if not r["ok"]:
		cap.text = "%s. 다른 곳을 눌러 주세요." % r["why"]
		GameAudio.fx("glass_tap_light")
		return
	if r["warn"] != "":
		_pick["pending"] = p
		(_pick["confirm"] as ConfirmSheet).ask("%s. 정말 여기에 둘까요?" % world.spot_reason(p.x, p.y), "여기에 둔다", "다시 고르기")
		return
	_drop_kit(p)


## 거인의 손이 상자를 그 자리에 내려놓는다 (창조에서 왔을 때만 — 시험·개발 고르기는 바로)
func _drop_kit(p: Vector2) -> void:
	if _plan == null or not kit_anim or _pick.has("dropping"):
		_place_first_kit(p)
		return
	_pick["dropping"] = true
	var pc: JarCamera = _pick["cam"]
	var pt: WorldTerrain = _pick["terrain"]
	var u := 40.0 / maxf(pc.ppu, 0.01)                 # 화면에서 약 40px 상자
	var gy := pt.ground_y(p.x, p.y)
	var root := Node3D.new()
	(_pick["root"] as Node3D).add_child(root)
	root.position = Vector3(p.x, gy + u * 9.0, p.y)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(u, u * 0.62, u * 0.75)
	box.mesh = bm
	box.material_override = Toon.mat(Color("e8c99a"))
	box.position.y = u * 0.31
	root.add_child(box)
	var lid := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(u * 1.06, u * 0.14, u * 0.8)
	lid.mesh = lm
	lid.material_override = Toon.mat(Color("d6694f"))
	lid.position.y = u * 0.69
	root.add_child(lid)
	var hand := _giant_hand(u)
	hand.position = Vector3(0, u * 0.95, 0)
	root.add_child(hand)
	for m: Array in _pick["marks"]:
		(m[1] as Label).visible = false
	(_pick["caption"] as Label).text = "이 세상에 살 사람들을 데려왔어요."
	var tw := create_tween()
	tw.tween_property(root, "position:y", gy + 0.5, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		GameAudio.fx("drop_thud")
		GameAudio.buzz())
	tw.tween_property(hand, "position:y", u * 8.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(hand, "position:x", u * 3.0, 0.6)
	tw.tween_callback(func() -> void: GameAudio.fx("box_open", "Room", -4.0))     # 뚜껑이 열리는 소리 (A17)
	tw.tween_property(lid, "rotation:x", -1.8, 0.3).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(lid, "position:z", -u * 0.5, 0.3)
	tw.tween_interval(0.35)
	tw.tween_callback(func() -> void: _place_first_kit(p))


## 거인의 손 (낮은 폴리곤: 손바닥 + 손가락 넷 + 엄지) — 상자 위에서 잡고 있다가 놓고 올라감
static func _giant_hand(u: float) -> Node3D:
	var h := Node3D.new()
	var skin := Toon.mat(Color("f2c4a0"))
	var palm := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(u * 1.1, u * 0.35, u * 1.0)
	palm.mesh = pm
	palm.material_override = skin
	palm.position = Vector3(0, u * 0.35, -u * 0.2)
	h.add_child(palm)
	for i in 4:
		var f := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = u * 0.12
		cm.height = u * 0.75
		f.mesh = cm
		f.material_override = skin
		f.rotation.x = PI * 0.5 + 0.5
		f.position = Vector3(-u * 0.39 + i * u * 0.26, u * 0.12, u * 0.45)
		h.add_child(f)
	var th := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = u * 0.13
	tm.height = u * 0.6
	th.mesh = tm
	th.material_override = skin
	th.rotation = Vector3(0.4, 0, 1.1)
	th.position = Vector3(-u * 0.62, u * 0.2, -u * 0.05)
	h.add_child(th)
	var arm := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = u * 0.42
	am.bottom_radius = u * 0.48
	am.height = u * 6.0
	arm.mesh = am
	arm.material_override = Toon.mat(Color("8fb3c9"))      # 거인의 소매
	arm.rotation.x = -0.9
	arm.position = Vector3(0, u * 2.6, -u * 2.6)
	h.add_child(arm)
	return h


## 키트를 놓는다 → 안개가 나머지를 덮고 → 병 안 장면을 만들고 → 멀리서 그 빈터로 날아 내려감
func _place_first_kit(p: Vector2) -> void:
	var far_ppu: float = (_pick["cam"] as JarCamera).ppu
	print("첫 키트 자리 %s (%s)" % [str(p), world.spot_reason(p.x, p.y)])
	var v := world.place_kit(p.x, p.y, Kits.make(_pick_ups, kit_variant))
	if _plan != null:                              # 이름 짓기 전 (앱이 꺼지면 이 자리에서 다시) · 주민들은 상자에서 걸어 나온다
		_plan.spot = [p.x, p.y]
		_plan.stage = "name"
		_plan.save(StartFlow.save_dir())
		var r := RandomNumberGenerator.new()
		r.seed = world.seed_v + 3
		for q in v.people:
			q.x = p.x + r.randf_range(-1.2, 1.2)
			q.y = p.y + r.randf_range(-1.2, 1.2)
			q.px = q.x
			q.py = q.y
	(_pick["root"] as Node).queue_free()
	(_pick["layer"] as Node).queue_free()
	_pick = {}
	super._ready()
	cam.ppu_min = minf(cam.ppu_min, far_ppu)
	cam.ppu = far_ppu
	cam.ppu_goal = far_ppu
	cam.target = Vector3(0, 0, 0)
	cam._apply()
	fly_to_settlement(village)
	if _plan != null:
		_begin_arrival()


# ───────────────────────── 첫 주민 소개 · 지구 이름 (OPENING 8 끝 · 9) ─────────────────────────
var _plan: CreationPlan = null
var kit_anim := true                 # 창조에서 왔을 때 상자 내려놓는 연출 (시험은 끔)
var arrival: FirstArrival
var _arrival_wait := false


func _begin_arrival() -> void:
	_set_hud(false)
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	arrival = FirstArrival.new()
	arrival.visible = false
	layer.add_child(arrival)
	arrival.named.connect(_on_named)
	arrival.done.connect(func() -> void:
		_set_hud(true)
		arrival = null)
	_arrival_wait = true


## 날아 내려앉으면 소개 시작
func _arrival_process() -> void:
	if _arrival_wait and not cam.flying:
		_arrival_wait = false
		arrival.visible = true
		arrival.start(village, _plan, world.water)


func _set_hud(on: bool) -> void:
	for n: Control in [top_bar, bottom_bar, stack, minimap, goto_btn, out_btn, speed_btn, lamp_ctl.badge if lamp_ctl != null else null]:
		if n != null:
			n.visible = on


## 이름을 정함 → 이제야 저장 대상으로 (창세의 날 ×12) · 만들던 창조 파일은 지움
func _on_named(nm: String) -> void:
	entry["name"] = nm
	_named = true
	_defer_save = false
	_start_save()
	CreationPlan.clear(StartFlow.save_dir())
	StartFlow.plan = null
	if shelf_sheet != null:
		shelf_sheet.current_id = jar_id if use_save else -1
	if shelf_hud != null:
		refresh_shelf()
	print("지구 이름 '%s'" % nm)


var _defer_save := false
var _named := false


func _start_save() -> void:
	if _plan != null and not _named:
		_defer_save = true                   # 이름을 지을 때까지 (꺼지면 creation.json에서 그 자리로 다시)
		return
	super._start_save()


func _from_save(sm: GameSave) -> Village:
	if sm.jars[jar_id]["kind"] != "world":
		return null
	world = sm.jars[jar_id]["world"]
	world._update_interest()
	return world.primary()


func jar_world() -> JarWorld:
	return world


func _make_terrain() -> JarTerrain:
	wterrain = WorldTerrain.new(world.water)
	wterrain.villages = world.settlements
	wterrain.focus = village.center
	return wterrain


func _after_ready() -> void:
	altar_sheet.set_meta("world", world)
	altar_sheet.split_requested.connect(begin_split_pick)
	_sync_views()
	_rot_shown = 0                    # 등불을 옮겨도 병·땅·화면은 그대로 — 빛만 돈다 (GD 4.6 · A11). 옛 저장의 rot도 빛으로
	jar.rotation.y = 0.0
	_lamp_rot = world.water.rot
	_lamp_goal = world.water.light.angle()
	_lamp_from = _lamp_goal
	_lamp_cur = _lamp_goal
	_lamp_t = Balance.LAMP_TURN_SECS
	_apply_light(world.water.light)
	cam.ground_center = village.center
	cam.ground_radius = WorldCfg.REVEAL_KIT + 6.0
	cam.ppu_min = 0.3                 # 세상 전체 + 유리벽이 보이는 데까지 (병·거인의 방 단계가 붙으면 더 낮춤)
	cam.zoom_beyond_world.connect(func(a: float) -> void: zoom_beyond_world.emit(a))
	if room_view:
		room_zoom = RoomZoom.new()
		room_zoom.name = "RoomZoom"
		add_child(room_zoom)
		room_zoom.setup(self, world.water.rr, wterrain.ground_y, world.water.light)
	# 날아가기 '쉭~' (fly_whoosh)은 JarCamera.fly_to가 직접 낸다 (가까운 날아가기는 조용히 · 빠른 확대에도)
	cam.set_zoom(1)
	look_at_ground(village.center + Vector2(1.0, 1.0))
	_update_limits()
	if room_zoom != null and entry["mode"] == "continue":     # 타이틀(방 ⑤)에서 들어옴 → 같은 자리에서 시작해 마을로 날아 들어감
		cam.set_ext_zoom(cam.ext_min() + (1.0 - TITLE_HANDOFF) * JarCamera.BEYOND_SPAN)
		_enter_fly = true
		room_zoom.update(0.0)
	wterrain.set_focus(Vector2(cam.target.x, cam.target.z), cam.view_radius())
	wterrain.update_now()
	_setup_world_ui()
	_setup_shelf()


# ───────────────────────── 선반 (C1 — UI 05 · GIANT_ROOM 1 '병이 여러 개면 선반에 나란히 — 좌우로 밀어 넘김') ─────────────────────────
## 거인의 방(⑤) 선반 위 지금 병 옆에 다른 병들 (꾸민 병 — 저장된 시대의 작은 마을) · 좌우로 밀면 옆 병 · 옆 병 아래 [들어가기].
## 들어가면 지금 병을 저장해 선반에 내려놓고 그 병을 불러온다 (GameSave.switch_jar → 장면을 다시 — 쉬던 동안은 등불 상한까지 따라잡기).
## 선반 시트(UI 05)의 [들어가기]·[새 병 사기]도 여기로
var shelf_slots: Array = []          # [{x: cm, id, empty, info}] — 지금 병(x 0) 포함, 선반 순서
var shelf_hud: PanelContainer
var shelf_hud_l: Label
var shelf_hud_btn: Button
var _shelf_focus := -1               # 지금 화면 가운데의 병 자리 (shelf_slots 번호)


func _setup_shelf() -> void:
	shelf_sheet.current_id = jar_id if use_save else -1
	shelf_sheet.enter_requested.connect(enter_jar)
	shelf_sheet.make_jar_requested.connect(make_new_jar)
	refresh_shelf()
	var root: Control = minimap.get_parent()
	shelf_hud = PanelContainer.new()
	shelf_hud.theme_type_variation = "TopBar"
	shelf_hud.mouse_filter = Control.MOUSE_FILTER_STOP
	shelf_hud.visible = false
	root.add_child(shelf_hud)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP)
	shelf_hud.add_child(row)
	shelf_hud_l = Label.new()
	shelf_hud_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelf_hud_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(shelf_hud_l)
	shelf_hud_btn = _bar_button(row, "들어가기", func() -> void: _enter_focused())
	shelf_hud_btn.custom_minimum_size = Vector2(96, UiTheme.TOUCH)


## 선반의 병 자리를 다시 (선반 순서 그대로 — 지금 병이 가운데 0, 왼쪽 병은 −, 오른쪽 병은 +) + 사 둔 빈 병은 맨 끝
func refresh_shelf() -> void:
	shelf_slots.clear()
	var sm := GameSave.get_instance()
	var list: Array = sm.shelf_list() if use_save and sm != null else []
	var ci := 0
	for i in list.size():
		if int((list[i] as Dictionary).get("id", -1)) == jar_id:
			ci = i
	for i in list.size():
		var j: Dictionary = list[i]
		shelf_slots.append({"x": (i - ci) * GiantRoom.SHELF_GAP, "id": int(j.get("id", -1)), "empty": false, "info": j})
	if use_save and sm != null and not sm.pending_jar().is_empty():
		shelf_slots.append({"x": (list.size() - ci) * GiantRoom.SHELF_GAP, "id": -1, "empty": true, "info": sm.pending_jar()})
	if shelf_slots.is_empty():
		shelf_slots.append({"x": 0.0, "id": jar_id, "empty": false, "info": {}})
	var others: Array = []
	var lo := 0.0
	var hi := 0.0
	for s: Dictionary in shelf_slots:
		lo = minf(lo, float(s["x"]))
		hi = maxf(hi, float(s["x"]))
		if float(s["x"]) != 0.0:
			others.append({"x": s["x"], "id": s["id"], "empty": s["empty"], "era": int((s["info"] as Dictionary).get("era", 0)),
				"preview": (s["info"] as Dictionary).get("preview", {})})
	if room_zoom != null:
		room_zoom.room.set_shelf_jars(others)
	cam.shelf_range = Vector2(lo, hi) if others.size() > 0 else Vector2.ZERO
	cam.shelf_pan = clampf(cam.shelf_pan, lo, hi)


## 화면 가운데에 가장 가까운 병 자리
func shelf_focus() -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for s: Dictionary in shelf_slots:
		var d := absf(float(s["x"]) - cam.shelf_pan)
		if d < bd:
			bd = d
			best = s
	return best


## 선반 밀기: 손을 떼면 가장 가까운 병으로 미끄러져 멈춤 · 방(⑤)을 떠나면 지금 병으로 돌아옴 · 옆 병이면 아래에 이름과 [들어가기]
func _shelf_process(dt: float) -> void:
	if room_zoom == null or shelf_hud == null:
		return
	var in_room := cam.beyond >= JarCamera.B_ROOM - 0.02 and not cam.flying
	var held := not _touches.is_empty() or _drag
	var goal := 0.0
	if in_room:
		var f := shelf_focus()
		goal = float(f.get("x", 0.0))
	if not held or not in_room:
		var np := lerpf(cam.shelf_pan, goal, 1.0 - exp(-10.0 * dt))
		if absf(np - goal) < 0.02:
			np = goal
		if np != cam.shelf_pan:
			cam.shelf_pan = np
			cam._apply()
	var f2 := shelf_focus() if in_room else {}
	var show := in_room and not f2.is_empty() and float(f2["x"]) != 0.0 and absf(cam.shelf_pan - float(f2["x"])) < GiantRoom.SHELF_GAP * 0.35
	shelf_hud.visible = show
	if show:
		if bool(f2["empty"]):
			shelf_hud_l.text = "사 둔 빈 병 · %s\n아직 세상이 없어요" % String((f2["info"] as Dictionary).get("climate", "온대"))
			shelf_hud_btn.text = "만들기"
		else:
			var ln := ShelfSheet.jar_lines(f2["info"])
			shelf_hud_l.text = "%s\n%s" % [ln[0], ln[1]]
			shelf_hud_btn.text = "들어가기"
		var vs := get_viewport().get_visible_rect().size
		shelf_hud.position = Vector2(12.0, vs.y - bottom_h - 92.0)
		shelf_hud.size = Vector2(vs.x - 24.0, 0.0)


func _enter_focused() -> void:
	var f := shelf_focus()
	if f.is_empty():
		return
	if bool(f["empty"]):
		make_new_jar()
	elif int(f["id"]) != jar_id:
		enter_jar(int(f["id"]))


## 다른 병으로 들어간다 (선반 시트 [들어가기] · 방에서 옆 병): 지금 병을 저장해 선반에 내려놓고 그 병으로 장면을 다시 (이어하기와 같은 길 —
## 방에서 시작해 그 병의 마을로 날아 들어감, 쉬던 동안은 등불 상한까지 따라잡기 + 편지)
func enter_jar(id: int) -> bool:
	var sm := GameSave.get_instance()
	if leaving or not use_save or sm == null or id == jar_id or not id in sm.order:
		return false
	leaving = true
	paused = true
	shelf_sheet.visible = false
	sm.switch_jar(id)
	GameAudio.fx("glass_tap_light", "Room", -6.0)
	StartFlow.enter_game(get_tree(), "continue")
	return true


## 새 병 (산 직후 · 사 둔 빈 병 [만들기]): 지금 병을 저장해 내려놓고 빠른 창조로 (OPENING 4) → 키트 자리 → 이름 → 그 병 안
func make_new_jar() -> bool:
	var sm := GameSave.get_instance()
	if leaving or not use_save or sm == null or sm.pending_jar().is_empty():
		return false
	leaving = true
	paused = true
	shelf_sheet.visible = false
	sm.unload()
	var a := GameAudio.get_instance()
	if a != null:
		a.attach(null)
		a.set_menu(true)
	StartFlow.to_new_jar(get_tree())
	return true


# ───────────────────────── 무리마다 화면 ─────────────────────────
func village_views() -> Array:
	var out: Array = [[village, view]]
	out.append_array(extra_views)
	return out


## 새로 선 무리(분가·키트)의 화면을 붙인다
func _sync_views() -> void:
	while 1 + extra_views.size() < world.settlements.size():
		var q: Village = world.settlements[1 + extra_views.size()]
		var vw := VillageView.new(q, terrain)
		jar.add_child(vw)
		extra_views.append([q, vw])
	wterrain.villages = world.settlements


## 카메라가 보는 곳에서 가장 가까운 무리
func focus_village() -> Village:
	if _focus == null or not _focus in world.settlements:
		_focus = _nearest_settlement()
	return _focus


func _nearest_settlement() -> Village:
	var t := ground_at_camera()
	var best: Village = village
	var bd := INF
	for q in world.settlements:
		var d := q.center.distance_squared_to(t)
		if d < bd:
			bd = d
			best = q
	return best


## 카메라가 보는 땅 (세상 데이터 좌표 — 병이 돌았으면 되돌려서)
func ground_at_camera() -> Vector2:
	return Vector2(cam.target.x, cam.target.z).rotated(-PI * 0.5 * _rot_shown)


func _update_focus(dt: float) -> void:
	var f := _nearest_settlement()
	if f != _focus:
		_focus = f
		air_overlay.setup(f)
		if altar_sheet.visible:
			altar_sheet.setup(f)
		if shop_sheet.visible:
			shop_sheet.setup(f)


# ───────────────────────── 매 화면 ─────────────────────────
func _process(dt: float) -> void:
	if not _pick.is_empty():
		_pick_process(dt)
		return
	if village == null:
		return
	if arrival != null:
		_arrival_process()
	var t0 := Time.get_ticks_usec()
	super(dt)
	if catching:
		return
	if 1 + extra_views.size() < world.settlements.size():
		_sync_views()
	_update_focus(dt)
	_update_limits()
	_lamp_anim(dt)                    # 등불을 옮기면 해(그림자·언덕 명암·폭포)가 3초 동안 돈다 (A11)
	wterrain.set_focus(ground_at_camera(), cam.view_radius())
	wterrain.zoom_ppu(cam.ppu)
	far_outline_check()
	_rim_check()
	_lid_follow()
	if room_zoom != null:
		room_zoom.update(dt)
		_shelf_process(dt)
		if room_zoom.room != null and room_zoom.room.curtain_step != world.water.curtain:     # [거인의 손 B6] 방의 3D 커튼 = 병의 커튼 (GiantRoom.set_curtain)
			room_zoom.room.set_curtain(world.water.curtain)
		if _enter_fly and not catching and not leaving:
			_enter_fly = false
			fly_to_settlement(village)
		if out_btn != null:
			out_btn.visible = goto_btn.visible and cam.stage() < 4
	if minimap != null:
		minimap.update_view(ground_at_camera(), cam.view_radius(), _map_angle(), focus_village())
	_proc_ms = lerpf(_proc_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.1)


## 멀리 축소하면 세상 끝 유리벽(JarGlass의 얇은 띠)이 화면에서 사라진다 → 확대에 맞춰 굵어지는 빛나는 테두리 (화면 약 3·8 px)
var _rim: Node3D
var _rim_w := -1.0


func _rim_check() -> void:
	var w := 3.0 / cam.ppu
	if cam.ppu > 6.0:
		if _rim != null:
			_rim.visible = false
		return
	if _rim != null and absf(w - _rim_w) < _rim_w * 0.15:
		_rim.visible = true
		return
	_rim_w = w
	if _rim != null:
		_rim.queue_free()
	_rim = Node3D.new()
	glass.add_child(_rim)
	var top := func(_x: float, _z: float) -> float: return glass.top_y
	_rim.add_child(glass._band(top, world.water.rr, w * 2.6, 0.0, Style.GLASS_RIM, 0.35, false))
	_rim.add_child(glass._band(top, world.water.rr, w, 0.05, Style.GLASS_LINE, 0.95, false))


## 첫 무리의 뚜껑이 (현실 1분 뒤) 저절로 닫히면 다른 무리도 함께 — 뚜껑은 병 하나에 하나
func _lid_follow() -> void:
	if village.air.lid_open or _lid_sync:
		return
	for q in world.settlements:
		if q.air.lid_open:
			_lid_sync = true
			q.close_lid()
			_lid_sync = false


## 멀리 축소하면 깊이 외곽선(render/outline_post)이 화면 전체에 걸려 땅이 어두워진다 → 그동안만 끔
func far_outline_check() -> void:
	var far := cam.ppu < 6.0
	if far and not _outline_off:
		_outline_off = true
		_outline_was = post_mat.get_shader_parameter("use_outline")
		post_mat.set_shader_parameter("use_outline", false)
	elif not far and _outline_off:
		_outline_off = false
		post_mat.set_shader_parameter("use_outline", _outline_was)


## 카메라가 갈 수 있는 곳: 가까이선 본 땅(안개가 걷힌 곳) 안, 멀리 축소할수록 세상 한가운데로 — 다 축소하면 병 전체와 유리벽
func _update_limits() -> void:
	var rr := world.water.rr
	if not wterrain.show_fog or wterrain.reveal_all or split_from != null or cam.flying:
		cam.ground_center = Vector2.ZERO
		cam.ground_radius = rr + 40.0
		return
	var c := village.center
	if world.water.fog_version != _fog_v:
		_fog_v = world.water.fog_version
		_rev_r = world.water.revealed_radius(c)
	var near_r := _rev_r + 8.0
	var k := clampf((cam.view_radius() - _rev_r) / maxf(1.0, rr - _rev_r), 0.0, 1.0)
	cam.ground_center = c.lerp(Vector2.ZERO, k).rotated(PI * 0.5 * _rot_shown)
	cam.ground_radius = lerpf(near_r, rr + 40.0, k)


func look_at_ground(p: Vector2) -> void:
	var q := p.rotated(PI * 0.5 * _rot_shown)
	cam.target = Vector3(q.x, terrain.ground_y(p.x, p.y), q.y)
	cam._apply()


## 지도 돌리기: 화면 위쪽(카메라가 보는 쪽)이 지도 위쪽이 되게
func _map_angle() -> float:
	var b := cam.camera.global_transform.basis
	var fwd := Vector2(-b.z.x, -b.z.z).rotated(-PI * 0.5 * _rot_shown)
	return Vector2(0, -1).angle() - fwd.angle()


# ───────────────────────── 거인의 도구 (세상 전체 / 보고 있는 무리) ─────────────────────────
func advance(seconds: float) -> void:
	world.advance(seconds)
	_sync_views()
	refresh()


func refresh() -> void:
	super()
	for vv: Array in extra_views:
		(vv[1] as VillageView).sync(0.0, true)


func dev_rotate() -> void:
	world.rotate_jar()
	GameAudio.fx("jar_turn")
	refresh()


# ───────────────────────── 등불 옮기기 (A11 — view/lamp_ctl.gd) ─────────────────────────
var _lamp_rot := 0
var _lamp_goal := 0.0                 # 빛 방향 각 (풀어 둔 값 — 옮길 때마다 −90° × 칸 수)
var _lamp_from := 0.0
var _lamp_t := 0.0
var _lamp_shown := Vector2.ZERO
var _lamp_cur := 0.0                  # 지금 보이는 빛의 각 (풀어 둔 값)


## 물의 빛이 바뀌면(등불을 옮김) 지금 보이는 빛에서 새 빛으로 3초 동안 (옮긴 방향 그대로 돈다)
func _lamp_anim(dt: float) -> void:
	var ww := world.water
	if ww.rot != _lamp_rot:
		var k := posmod(ww.rot - _lamp_rot, 4)
		_lamp_rot = ww.rot
		_lamp_from = _lamp_cur
		_lamp_goal -= k * PI * 0.5
		_lamp_t = 0.0
	if _lamp_t >= Balance.LAMP_TURN_SECS:
		return
	_lamp_t += dt
	var u := smoothstep(0.0, 1.0, clampf(_lamp_t / Balance.LAMP_TURN_SECS, 0.0, 1.0))
	var a := lerpf(_lamp_from, _lamp_goal, u)
	_lamp_cur = a
	var l := Vector2(cos(a), sin(a)) * ww.light.length()
	if _lamp_t >= Balance.LAMP_TURN_SECS:
		l = ww.light
	_apply_light(l)


func _apply_light(l: Vector2) -> void:
	_lamp_shown = l
	var d := Style.sun_direction_for(l)
	sun.look_at_from_position(-d * 50.0, Vector3.ZERO, Vector3.UP)
	wterrain.set_light_shown(l)
	if room_zoom != null:
		room_zoom.set_light_dir(l)                # 방의 등불도 그쪽으로


func lamp_water() -> JarWater:
	return world.water


func lamp_villages() -> Array:
	return world.settlements


func lamp_screen(p: Vector2, flat := false) -> Vector2:
	var q := p.rotated(PI * 0.5 * _rot_shown)
	var y := cam.target.y if flat else terrain.ground_y(p.x, p.y)
	return cam.camera.unproject_position(Vector3(q.x, y, q.y))


func lamp_data_of(p: Vector2) -> Vector2:
	return p.rotated(-PI * 0.5 * _rot_shown)


func lamp_light_shown() -> Vector2:
	return _lamp_shown if _lamp_shown != Vector2.ZERO else world.water.light


func lamp_apply(dir: int) -> void:
	world.move_lamp(dir)                  # 소리(lamp_move)는 LampCtl.confirm
	refresh()


## 미리보기: 세상 전체가 보이게 날아 올라감 (유리벽의 골까지) + 땅에 볕·그늘 색. 끝나면 보던 곳으로 돌아옴
func lamp_preview_begin(pv: Dictionary) -> void:
	_stop_follow()
	_lamp_cam = {"ppu": cam.ppu, "target": cam.target}
	var vs := get_viewport().get_visible_rect().size
	var panel_h := lamp_ctl.prev_panel.get_combined_minimum_size().y if lamp_ctl != null else 220.0
	var free_h := maxf(200.0, vs.y - top_h - bottom_h - panel_h)
	var fit := clampf(minf(vs.x, free_h / sin(deg_to_rad(JarCamera.PITCH_DEG))) / (world.water.n * 1.16), cam.ppu_min, JarCamera.PPU_MAX)
	# 화면 위쪽 빈 곳 가운데에 세상이 오게: 바라보는 점을 화면 아래쪽(카메라 쪽)으로 조금
	var b := cam.camera.global_transform.basis
	var back := Vector2(b.z.x, b.z.z).normalized()
	var shift := (panel_h + bottom_h - top_h) * 0.5 / fit / sin(deg_to_rad(JarCamera.PITCH_DEG))
	var g := back * shift
	cam.fly_to(Vector3(g.x, 0.0, g.y), fit)
	terrain.set_lamp_preview(1.0, pv["l0"], pv["l1"], world.water.rr)


func lamp_preview_end() -> void:
	terrain.set_lamp_preview(0.0, Vector2.ZERO, Vector2.ZERO, 1.0)
	if not _lamp_cam.is_empty():
		cam.fly_to(_lamp_cam["target"], float(_lamp_cam["ppu"]))
		_lamp_cam = {}


## 뚜껑은 병에 하나 — 모든 무리가 함께 열리고 닫힌다 (첫 무리의 뚜껑이 기준: JarClock의 1분 자동 닫힘)
func toggle_lid() -> void:
	var open := not village.air.lid_open
	_lid_sync = true
	for q in world.settlements:
		if open:
			q.open_lid()
		else:
			q.close_lid()
	_lid_sync = false
	if open:
		clock.lid_real = 0.0


func _on_return_all(away: float) -> Array:
	return CatchUp.on_return_world(world, away)


## 알림 한 줄: 모든 무리에서 하나씩 (첫 무리가 아니면 무리 이름을 앞에)
func next_warning() -> String:
	for q in world.settlements:
		if not q.warnings.is_empty():
			var t := str(q.warnings.pop_front()["text"])
			return t if q == village else "[%s] %s" % [q.settlement_name, t]
	return ""


func top_text() -> String:
	var f := focus_village()
	var name := ""
	if world.settlements.size() > 1:
		name = " · " + f.settlement_name
	return "%s%s · %s · %d명" % [earth_name(), name, Balance.ERAS[f.era], f.people.size()]


## 떨어뜨린 자리의 무리 = 그 자리에서 가장 가까운 무리
func village_at(p: Vector2) -> Village:
	var best: Village = focus_village()
	var bd := INF
	for q in world.settlements:
		var d := q.center.distance_squared_to(p)
		if d < bd:
			bd = d
			best = q
	return best


func status_text() -> String:
	var pop := 0
	for q in world.settlements:
		pop += q.people.size()
	if _seen_v != world.water.fog_version:
		_seen_v = world.water.fog_version
		_seen_n = 0
		for b in world.water.fog:
			if b != 0:
				_seen_n += 1
	var seen := _seen_n
	return super() + "\n세상 %d칸 · 무리 %d곳 · 세상 인구 %d · 본 땅 %.1f%% · 확대 %.2f" % [world.water.n, world.settlements.size(), pop,
		100.0 * seen / maxf(1.0, PI * pow(world.water.fn * 0.5, 2.0)), cam.ppu]


# ───────────────────────── 둥근 지도 (UI 09) · 분가 자리 고르기 ─────────────────────────
func _setup_world_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.get_theme()
	layer.add_child(root)
	minimap = WorldMinimap.new()
	minimap.setup(world)
	minimap.pressed_at.connect(_on_map_pressed)
	root.add_child(minimap)
	split_bar = PanelContainer.new()
	split_bar.theme_type_variation = "TopBar"
	split_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	split_bar.visible = false
	root.add_child(split_bar)
	var col := VBoxContainer.new()
	split_bar.add_child(col)
	split_label = Label.new()
	split_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	split_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(split_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTheme.GAP)
	col.add_child(row)
	_bar_button(row, "알아서 고르기", func() -> void: _split_auto()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar_button(row, "그만두기", end_split_pick).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# [마을로 가기] (지도 아래) + 무리가 여럿일 때의 작은 목록
	goto_btn = _bar_button(root, "마을로 가기", open_goto)
	goto_btn.clip_text = false
	goto_btn.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL + 1)
	goto_btn.custom_minimum_size = Vector2(WorldMinimap.SIZE, 32)
	if room_view:
		out_btn = _bar_button(root, "병 밖으로", go_outside)
		out_btn.clip_text = false
		out_btn.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL + 1)
		out_btn.custom_minimum_size = Vector2(WorldMinimap.SIZE, 32)
	goto_list = PanelContainer.new()
	goto_list.theme_type_variation = "TopBar"
	goto_list.mouse_filter = Control.MOUSE_FILTER_STOP
	goto_list.visible = false
	root.add_child(goto_list)
	goto_box = VBoxContainer.new()
	goto_list.add_child(goto_box)
	get_viewport().size_changed.connect(_layout_world_ui)
	_layout_world_ui()


func layout_bars() -> void:
	super()
	_layout_world_ui()


## [창고] 창고 띠는 둥근 지도 왼쪽까지
func store_right() -> float:
	return WorldMinimap.SIZE + 16.0


func _layout_world_ui() -> void:
	if minimap == null:
		return
	var d := WorldMinimap.SIZE
	minimap.position = Vector2(get_viewport().get_visible_rect().size.x - d - 8.0, top_h + 8.0)
	minimap.size = Vector2(d, d)
	var vw := get_viewport().get_visible_rect().size.x
	goto_btn.position = Vector2(vw - d - 8.0, top_h + 8.0 + d + 6.0)
	goto_btn.size = Vector2(d, 32)
	if out_btn != null:
		out_btn.position = goto_btn.position + Vector2(0, 38.0)
		out_btn.size = Vector2(d, 32)
	goto_list.position = Vector2(vw - 200.0 - 8.0, goto_btn.position.y + 38.0)
	goto_list.size = Vector2(200.0, 0)
	split_bar.anchor_left = 0.0
	split_bar.anchor_right = 1.0
	split_bar.offset_left = 0
	split_bar.offset_right = 0
	split_bar.offset_top = top_h
	split_bar.offset_bottom = top_h + 96.0


## 지도를 누르면 그곳으로 날아감 — 무리 점 가까이면 그 마을 광장으로 내려앉고, 아니면 그 땅 위로 (반쯤 축소)
func _on_map_pressed(p: Vector2) -> void:
	var near: Village = null
	var nd := world.water.rr * 0.06               # 지도 위 약 3 px
	for q in world.settlements:
		if q.center.distance_to(p) < nd:
			nd = q.center.distance_to(p)
			near = q
	if near != null and split_from == null:
		fly_to_settlement(near)
	else:
		fly_to_ground(p, minf(cam.ppu, 6.0) if split_from == null else cam.ppu)


# ───────────────────────── 날아가기 (GIANT_ROOM 4 '[마을로 가기] — 쉭~ 날아 들어가기') ─────────────────────────
## 땅 위 점 p(세상 데이터 좌표)로 날아가 확대 end_ppu로 내려앉는다
func fly_to_ground(p: Vector2, end_ppu: float) -> void:
	_stop_follow()
	goto_list.visible = false
	var q := p.rotated(PI * 0.5 * _rot_shown)
	cam.fly_to(Vector3(q.x, terrain.ground_y(p.x, p.y), q.y), end_ppu)


## 그 무리의 광장(모닥불)으로
func fly_to_settlement(v: Village) -> void:
	var sq := v.fire if v.fire.distance_to(v.center) < 30.0 else v.center
	fly_to_ground(sq, ARRIVE_PPU)


## [마을로 가기]: 무리가 하나면 바로 날아감, 여럿이면 작은 목록 (다시 누르면 닫힘)
func open_goto() -> void:
	if world.settlements.size() <= 1:
		fly_to_settlement(village)
		return
	if goto_list.visible:
		goto_list.visible = false
		return
	for c in goto_box.get_children():
		c.queue_free()
	for q in world.settlements:
		var b := _bar_button(goto_box, "%s · %d명" % [q.settlement_name, q.people.size()], fly_to_settlement.bind(q))
		b.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL + 1)
		b.custom_minimum_size = Vector2(0, 36)
	goto_list.visible = true


## [병 밖으로] (UI 09): 거인의 방까지 부드럽게 (손가락으로 오므리는 것과 같은 길 — 지름길)
func go_outside() -> void:
	if room_zoom == null:
		return
	_stop_follow()
	goto_list.visible = false
	cam.zoom_to_ext(cam.ext_min())


## 병 밖(④⑤)에서 누름: 유리에 붙은 편지 = 그 편지 · 병을 두 번 톡 = 들어가기 (마을로 날아감) · 한 번 = 유리 톡
func _room_tap(sp: Vector2) -> void:
	var note := room_zoom.notes.pick(cam.camera, sp)
	if not note.is_empty():
		open_glass_note(note)
		return
	var now := Time.get_ticks_msec() / 1000.0
	var f := shelf_focus()
	var fx := float(f.get("x", 0.0))                  # 옆 병을 보고 있으면 그 병 (C1)
	var c := room_zoom.room.cm(Vector3(fx, 7.0, 0))
	var e := room_zoom.room.cm(Vector3(fx + GiantRoom.JAR_OUT, 7.0, 0))
	var cp := cam.camera.unproject_position(c)
	var on_jar := absf(sp.x - cp.x) < absf(cam.camera.unproject_position(e).x - cp.x) * 1.05 and absf(sp.y - cp.y) < absf(cam.camera.unproject_position(e).x - cp.x) * 1.4
	if not on_jar:
		return
	if _tap_t > 0.0 and now - _tap_t < DOUBLE_TAP:
		_tap_t = -1.0
		if fx != 0.0:
			_enter_focused()
		else:
			fly_to_settlement(focus_village())
		return
	_tap_t = now
	if fx != 0.0:
		GameAudio.fx("glass_tap_light", "Room", -6.0)     # 옆 병 유리 톡 (그 병의 주민은 지금 자는 중 — 들어가면 깨어남)
	else:
		tap_glass(false)


## 유리에 붙은 편지 (GIANT_ROOM 3 — 빨간 점 대신): 안 읽은 '자리를 비운 동안' 편지 · 계시를 기다리는 무리 · 소원 편지가 있는 무리
func glass_note_items() -> Array:
	var out: Array = []
	if letter_unread and not _last_letter.is_empty():
		out.append({"kind": "return", "key": "return", "label": "편지"})
	for i in world.settlements.size():
		var q: Village = world.settlements[i]
		var who := "" if world.settlements.size() <= 1 else "\n" + q.settlement_name
		if q.revelation_pending():
			out.append({"kind": "reveal", "key": "reveal:%d" % i, "label": "계시" + who, "v": q})
		var n := q.open_letters("wish").size()
		if n > 0:
			out.append({"kind": "wish", "key": "wish:%d" % i, "label": ("소원" if n == 1 else "소원 %d" % n) + who, "v": q})
	return out


## 유리에 붙은 편지를 누름 → 그 시트 (편지 = ReturnLetter · 계시·소원 = 그 무리의 제단 시트 — 맨 위에 [계시] / 소원 편지 칸)
func open_glass_note(it: Dictionary) -> void:
	GameAudio.fx("glass_tap_light", "Room", -10.0)
	match String(it.get("kind", "")):
		"return":
			if not _last_letter.is_empty():
				_open_return_letter(_last_letter)
		"reveal", "wish":
			var q: Village = it.get("v", village)
			close_sheets(altar_sheet)
			altar_sheet.setup(q)
			altar_sheet.open()


## (B1) '자리를 비운 동안' 편지: 병 밖(④⑤ 방)에 있는 동안 오면 펼치지 않고 유리에 붙여 둔다 (누르면 펼침).
## 타이틀에서 들어와 마을로 날아 들어가는 중이면 그대로 펼침
func show_return_letter(letter: Dictionary) -> void:
	_last_letter = letter
	letter_unread = true
	if room_zoom != null and cam.stage() >= 4 and not _enter_fly:
		room_zoom.refresh_notes()
		return
	_open_return_letter(letter)


func _open_return_letter(letter: Dictionary) -> void:
	super.show_return_letter(letter)
	if not return_letter.closed.is_connected(_on_glass_letter_read):
		return_letter.closed.connect(_on_glass_letter_read)


func _on_glass_letter_read() -> void:
	letter_unread = false
	if room_zoom != null:
		room_zoom.refresh_notes()


## 분가 편지 [새 땅 고르기] → 세상을 멀리 보여 주고 거인이 땅을 누른다
func begin_split_pick(from: Village) -> void:
	split_from = from
	altar_sheet.close()
	detail.close()
	split_bar.visible = true
	split_label.text = "%s의 젊은 부부들이 떠날 새 땅을 눌러 주세요." % from.settlement_name
	cam.ppu_goal = 2.0
	look_at_ground(from.center)


func end_split_pick() -> void:
	split_from = null
	split_bar.visible = false


func _split_auto() -> void:
	if split_from == null:
		return
	var p: Variant = world.split_spot(split_from)
	if p == null:
		split_label.text = "가까이에 좋은 자리가 없어요. 직접 눌러 주세요."
		return
	_do_split(p as Vector2)


## 화면 위 한 점 → 땅 위 점 (세상 데이터 좌표). 정사영 카메라의 광선을 땅 높이에 맞춰 두 번 고친다
func screen_to_ground(sp: Vector2) -> Vector2:
	var o := cam.camera.project_ray_origin(sp)
	var n := cam.camera.project_ray_normal(sp)
	var y := cam.target.y
	var hit := Vector3.ZERO
	for i in 3:
		var t := (y - o.y) / n.y if absf(n.y) > 1e-5 else 0.0
		hit = o + n * t
		var dp := Vector2(hit.x, hit.z).rotated(-PI * 0.5 * _rot_shown)
		y = terrain.ground_y(dp.x, dp.y)
	return Vector2(hit.x, hit.z).rotated(-PI * 0.5 * _rot_shown)


func _do_split(p: Vector2) -> void:
	var from := split_from
	var ok := world.kit_spot_ok(p.x, p.y)
	if not ok["ok"]:
		split_label.text = "%s — 다른 곳을 눌러 주세요." % ok["why"]
		GameAudio.fx("glass_tap_light")
		return
	var nv := world.split_out(from, p.x, p.y)
	if nv == null:
		split_label.text = "지금은 떠날 사람이 없어요."
		return
	end_split_pick()
	from.giant_acted()
	_sync_views()
	refresh()
	clock.notice = "%s%s 세워졌어요 (%d명)." % [nv.settlement_name, Village.josa(nv.settlement_name, "이", "가"), nv.people.size()]
	clock.notice_t = 6.0
	cam.ppu_goal = 16.0
	look_at_ground(nv.center)


func _on_tap(sp: Vector2) -> void:
	if split_from != null:
		_do_split(screen_to_ground(sp))
		return
	if room_zoom != null and cam.stage() >= 4:
		_room_tap(sp)
		return
	super(sp)


## (B1) 뒤로 가기 → 거인의 방으로 날아 나간 뒤 타이틀 (타이틀은 같은 방 ⑤ — 끊김 없이)
var _leave_fly := false


func leave_to_title() -> void:
	if leaving or _leave_fly:
		return
	if room_zoom == null or not is_inside_tree() or not StartFlow.navigate:
		super()
		return
	_leave_fly = true
	_stop_follow()
	cam.zoom_to_ext(cam.ext_min())
	var tw := create_tween()
	tw.tween_interval(LEAVE_TIME)
	tw.tween_callback(_leave_now)


func _leave_now() -> void:
	cam.set_ext_zoom(cam.ext_min())
	title_cover = false
	super.leave_to_title()


func _update_audio() -> void:
	super()
	var a := GameAudio.get_instance()
	if a != null and room_zoom != null:
		a.outside = room_zoom.outside_amount()


func on_back() -> void:
	if split_from != null:
		end_split_pick()
		return
	super()


func _unhandled_input(e: InputEvent) -> void:
	if not _pick.is_empty():                          # 키트 자리 고르기: 누르면 고름
		if (_pick["confirm"] as ConfirmSheet).visible:
			return
		if e is InputEventScreenTouch and not (e as InputEventScreenTouch).pressed:
			pick_at((e as InputEventScreenTouch).position)
		elif e is InputEventMouseButton and not (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and e.device != InputEvent.DEVICE_ID_EMULATION:
			pick_at((e as InputEventMouseButton).position)
		return
	if village == null:
		return
	# 날아가는 중에 화면을 누르면 그 자리에서 멈춤
	if cam.flying and ((e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
			or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)):
		cam.stop_fly()
		get_viewport().set_input_as_handled()
		return
	if goto_list != null and goto_list.visible and (e is InputEventScreenTouch or e is InputEventMouseButton) and e.is_pressed():
		goto_list.visible = false
	if e is InputEventKey and e.pressed:
		match (e as InputEventKey).keycode:
			KEY_G:
				wterrain.set_fog_visible(not wterrain.show_fog)
				_update_limits()
				return
			KEY_K:
				var rec := world.recommended_kit_spots()
				if not rec.is_empty():
					world.place_kit(rec[0].x, rec[0].y)
					_sync_views()
				return
	super(e)
