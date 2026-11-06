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
##   - 구글 어스식 확대: 마을 → 넓은 땅 → 세상 전체(유리벽)까지 한 번에 오므림. 그 너머(병·거인의 방)는 cam.zoom_beyond_world 신호로 넘길 자리
##     (zoom_beyond_world → 이 장면의 같은 이름 신호. 지금은 받는 곳 없음 — 거인의 방 단계가 붙일 곳)
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

signal zoom_beyond_world(amount: float)   # 세상 전체보다 더 오므림 (log2 몫) — 병·거인의 방 단계(GIANT_ROOM 4)가 이어받을 곳

const LOW_CORES := 4
const ARRIVE_PPU := 16.0             # 날아가서 내려앉는 확대 (기본 확대)
const LOW_MEM := 3.0 * 1024.0 * 1024.0 * 1024.0

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
	var v := world.place_kit(rec[0].x, rec[0].y, Kits.make([], kit_variant))
	print("세상 시드 %d · 지름 %d칸 · 추천 자리 %d곳 · 첫 키트 %s" % [sd, size, rec.size(), str(v.center)])
	return v


# ───────────────────────── 키트 자리 고르기 (OPENING 단계 8 '스타터킷 풀기' — 최소판) ─────────────────────────
## 안개 없는 세상 전체를 내려다보고 빛나는 추천 자리를 누른다 → 키트를 놓고 나서야 병 안 장면(위아래 띠·마을)을 만든다
var _pick: Dictionary = {}           # 고르는 중인 화면 {root, cam, terrain, layer, marks: [[node, label, choice]], confirm, caption, t}


func _ready() -> void:
	if (pick_spot and StartFlow.mode == "new") or force_pick:
		_begin_pick()
		return
	super()


func _begin_pick() -> void:
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var sd := world_seed if world_seed != 0 else WorldGen.new_seed()
	var size := world_size if world_size > 0 else default_size()
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
		l.add_theme_font_size_override("font_size", 11)
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
	_place_first_kit(p)


## 키트를 놓는다 → 안개가 나머지를 덮고 → 병 안 장면을 만들고 → 멀리서 그 빈터로 날아 내려감
func _place_first_kit(p: Vector2) -> void:
	var far_ppu: float = (_pick["cam"] as JarCamera).ppu
	print("첫 키트 자리 %s (%s)" % [str(p), world.spot_reason(p.x, p.y)])
	world.place_kit(p.x, p.y, Kits.make([], kit_variant))
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


func _from_save(sm: GameSave) -> Village:
	if sm.jars[JAR_ID]["kind"] != "world":
		return null
	world = sm.jars[JAR_ID]["world"]
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
	_rot_shown = world.water.rot
	jar.rotation.y = -PI * 0.5 * _rot_shown
	cam.ground_center = village.center
	cam.ground_radius = WorldCfg.REVEAL_KIT + 6.0
	cam.ppu_min = 0.3                 # 세상 전체 + 유리벽이 보이는 데까지 (병·거인의 방 단계가 붙으면 더 낮춤)
	cam.zoom_beyond_world.connect(func(a: float) -> void: zoom_beyond_world.emit(a))
	cam.fly_started.connect(func(_d: float) -> void: GameAudio.fx("fly_whoosh"))   # 쉭~ (소리 파일이 생기면 들림 — 지금은 자리만)
	cam.set_zoom(1)
	look_at_ground(village.center + Vector2(1.0, 1.0))
	_update_limits()
	wterrain.set_focus(Vector2(cam.target.x, cam.target.z), cam.view_radius())
	wterrain.update_now()
	_setup_world_ui()


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


# ───────────────────────── 매 화면 ─────────────────────────
func _process(dt: float) -> void:
	if not _pick.is_empty():
		_pick_process(dt)
		return
	if village == null:
		return
	super(dt)
	if catching:
		return
	if 1 + extra_views.size() < world.settlements.size():
		_sync_views()
	_update_focus(dt)
	_update_limits()
	# 병이 돈 만큼 병 노드를 돌린다 (데이터는 그대로, 빛만 돈다 — WorldWater.rotate_jar)
	if world.water.rot != _rot_shown:
		_rot_shown = world.water.rot
		jar.rotation.y = -PI * 0.5 * _rot_shown
	wterrain.set_focus(ground_at_camera(), cam.view_radius())
	wterrain.zoom_ppu(cam.ppu)
	far_outline_check()
	_rim_check()
	_lid_follow()
	if minimap != null:
		minimap.update_view(ground_at_camera(), cam.view_radius(), _map_angle(), focus_village())


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
		name = f.settlement_name + " · "
	return "%s · %s인구 %d · %s 지폐" % [f.fmt_time(f.t), name, f.people.size(), AltarSheet._num(Market.notes)]


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
	goto_btn.add_theme_font_size_override("font_size", 11)
	goto_btn.custom_minimum_size = Vector2(WorldMinimap.SIZE, 32)
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


func _layout_world_ui() -> void:
	if minimap == null:
		return
	var d := WorldMinimap.SIZE
	minimap.position = Vector2(get_viewport().get_visible_rect().size.x - d - 8.0, top_h + 8.0)
	minimap.size = Vector2(d, d)
	var vw := get_viewport().get_visible_rect().size.x
	goto_btn.position = Vector2(vw - d - 8.0, top_h + 8.0 + d + 6.0)
	goto_btn.size = Vector2(d, 32)
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
		b.add_theme_font_size_override("font_size", 11)
		b.custom_minimum_size = Vector2(0, 36)
	goto_list.visible = true


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
	super(sp)


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
