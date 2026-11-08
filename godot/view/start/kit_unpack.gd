## 스타터킷 풀기 (OPENING 단계 8 v3.9 + 2026-11-08 사용자 "처음 스타터킷 터부터 짓고 사람들 나오는 거로 하자") —
## 넓은 세상 장면(world_village)이 키트 자리를 정한 뒤 붙인다. 순서: 상자가 놓임 → 거인이 터를 꾸밈 → 사람들이 나와 새 터를 둘러봄.
##   fly    카메라가 고른 자리 위로 날아감 (상자는 하늘 높이 옅은 반짝임 속에 떠 있고, 땅엔 옅은 그림자)
##   drop   상자가 내려앉음 (그림자가 커지고 짙어짐) — 쿵 · 흙먼지 · 안개가 나머지 세상을 덮음
##          (A24 2026-11-08 그림 원칙: 거인의 손은 화면에 나오지 않는다 — view/sky_descent.gd)
##   settle 카메라가 상자 둘레가 보이는 놓는 높이로 (뚜껑은 닫힌 채 — 사람들은 아직 상자 안에서 잠듦)
##   tray   아래 칸에 상자에 든 것 (모닥불·창고·오두막·산 업그레이드 건물) — 하나 골라 땅을 누르면 그림자 미리보기 (초록 = 놓을 수 있음,
##          빨강 = 없음 + 까닭) → 놓으면 위에서 내려앉아 (자라는 그림자) 톡 · 흙먼지 · 쿵. [알아서 놓기] = 지금의 자동 배치. 상자 곁 Village.KIT_PLACE_R 안에서만
##   wait   마지막 건물이 내려앉을 때까지
##   rush   카메라가 상자 바로 앞까지 확 다가감 (주민 키 높이 — 정사영 그대로 낮은 각)
##   open   뚜껑이 열림
##   climb  주민이 한 명씩 상자 가장자리를 넘어 기어 나와 폴짝 내려서고 기지개 · 새 터를 두리번 ("어…?" — 한 아이는 하늘을 올려다보며 갸웃, 아직 거인을 모름)
##   gather 카메라가 물러나 새 터 전체가 보이고, 사람들이 건물을 비켜 모닥불 곁으로 걸어가 불을 바라보며 모임 (gather_layout — 결정적)
##   end    빈 상자의 뚜껑이 닫히고 반짝임 속에 하늘로 떠올라 감 → finished (장면이 첫 주민 소개 → 이름)
## 놓은 자리는 곧바로 시뮬레이션 자리 (Village.move_kit_building · move_fire) + creation.json의 placed (앱이 꺼지면 여기서 다시 —
## 상자는 닫힌 채, 사람들은 상자 안, 남은 것만 칸에). 연출이 없으면(시험) 다 놓는 즉시 모닥불 곁에 모인 자리로.
## 병 시간은 이름을 지을 때까지 멈춰 있다 (장면의 paused).
class_name KitUnpack
extends Node

signal finished

const BOX := Vector3(2.6, 1.15, 1.9)    # 상자 (칸) — 아이 키보다 조금 낮은 가장자리
const WALL := 0.12
const HOLD_H := 24.0                    # 상자가 떠서 기다리는 높이
const FLY_PPU := 11.0                   # 날아가서 내려앉는 확대 (상자가 보이는 높이)
const PLACE_PPU := 13.0                 # 건물을 놓는 확대 (상자 둘레 KIT_PLACE_R가 화면에 들게)
const CLOSE_SIZE := 9.5                 # 초확대: 화면 세로가 덮는 칸
const CLOSE_PITCH := [13.0, 17.0, 22.0, 28.0]   # 낮은 각부터 — 뒤 언덕에 가리지 않는 첫 각
const DROP_T := 0.9
const RUSH_T := 1.25
const OPEN_T := 0.45
const CLIMB_GAP := 0.4                  # 주민 사이 (잠이 덜 깨 느릿느릿)
const CLIMB_T := 2.3                    # 한 명이 기어 나와 제자리까지
const LINGER_T := 2.6                   # 기지개 + 두리번 (WAKE_T 포함)
const SETTLE_T := 1.2                   # 내려앉은 뒤 놓는 높이로
const WAIT_T := 0.5                     # 다 놓은 뒤 숨 한 번
const GATHER_SPEED := 1.25              # 모닥불 곁으로 걷는 빠르기 (칸/초 — 연출, 시뮬레이션 걸음과 따로)
const GATHER_MAX_T := 7.0               # 가장 먼 사람도 이 안에 (멀면 모두 조금 서두름)
const GATHER_PULL_T := 2.4              # 카메라가 상자 앞에서 새 터 전체로
const GATHER_LINGER := 2.0              # 모두 모인 뒤 불을 바라보는 동안
const FIRE_RING := [1.75, 2.6, 3.4]     # 모닥불 둘레 고리 (칸)
const GATHER_GAP := 0.95                # 고리 위 사람 사이
const OK_COL := Color(0.36, 0.86, 0.42)
const BAD_COL := Color(0.92, 0.24, 0.2)
const FIRE_SIZE := 0.9
const WAKE_T := 1.3                     # 내려선 뒤 기지개 (막 잠에서 깬 듯 — 클립 "stretch")
const BOARD := Color("eadcc0")          # 상품 상자 판지
const BAND := Color("6f9a92")           # 포장 색 띠·뚜껑
const PRINT := Color("a89878")          # 흐린 작은 글씨

var sc: Node                            # world_village 장면
var v: Village
var vw: VillageView
var plan: CreationPlan
var spot: Vector2
var gy0 := 0.0
var phase := ""
var t := 0.0
var yaw_deg := 45.0
var root: Node3D                        # 상자·그림자 (장면의 jar 아래 — 병 데이터 좌표)
var box: Node3D
var lid: Node3D
var glint: CPUParticles3D               # (A24) 떠 있는 상자 둘레의 반짝임
var box_shadow: MeshInstance3D          # (A24) 상자가 내려앉을 자리의 그림자 (내려올수록 커짐)
var _rush_from := {}
var _rush_to := {}
var _settle_from := {}
var _settle_to := {}
var _gather_to := {}
var _et := 0.0                          # 기어 나오기·모이기 시간 (climb · gather)
var _walk0 := 0.0                       # 각자 걷기 시작 (기어 나온 뒤)
var _speed := GATHER_SPEED
var climb: Array = []                   # [{r, t0, a, b, c, d, stand: Vector2, rot, babies, path, len, goal}]
var kid: Resident = null
var items: Array = []                   # [{key, type, label, b: Building | null, size, placed}]
var sel := -1
var ghost: Node3D
var ghost_ring: MeshInstance3D
var ghost_p := Vector2.ZERO
var ghost_r := {}
var ring: MeshInstance3D                # 놓을 수 있는 둘레 (상자 곁)
var layer: CanvasLayer
var ui: Control
var caption: StartCaption
var tray: PanelContainer
var tray_row: HBoxContainer
var hint: Label
var auto_btn: Button
var _btns: Dictionary = {}              # key → Button
var _press := false
var _busy := 0.0                        # 건물이 내려오는 동안 (다음 것을 고를 수는 있음)


func setup(scene: Node, village: Village, view: VillageView, p: Vector2, cplan: CreationPlan) -> void:
	sc = scene
	v = village
	vw = view
	spot = p
	plan = cplan
	gy0 = (sc.terrain as JarTerrain).ground_y(p.x, p.y)
	yaw_deg = (sc.cam as JarCamera)._yaw_deg
	_make_items()
	for it: Dictionary in items:
		if not bool(it["placed"]):
			_hide_item(it, true)
	root = Node3D.new()
	(sc.jar as Node3D).add_child(root)
	root.position = Vector3(p.x, gy0, p.y)
	root.rotation.y = deg_to_rad(yaw_deg)
	box = _make_box()
	root.add_child(box)
	_make_ui()


## 상자에 든 것: 모닥불 + 키트 건물 (번호 순 — 창고·오두막·산 업그레이드). 이미 놓은 것(creation.json placed)은 놓인 것으로
func _make_items() -> void:
	items.clear()
	items.append({"key": "fire", "type": "모닥불", "label": "모닥불", "b": null, "size": FIRE_SIZE, "placed": plan != null and plan.placed.has("fire")})
	for b in v.buildings:
		if b.site_type() == Awakening.ALTAR:
			continue
		var key := str(b.id)
		items.append({"key": key, "type": b.type, "label": Balance.label(b.type), "b": b, "size": b.size(), "placed": plan != null and plan.placed.has(key)})


## 거인이 놓은 자리를 시뮬레이션에 (앱을 다시 켰을 때 · 이름 짓기부터 다시) — 놓은 개수
static func apply_placed(village: Village, cplan: CreationPlan) -> int:
	var n := 0
	for key: String in cplan.placed:
		var xy: Array = cplan.placed[key]
		var p := Vector2(float(xy[0]), float(xy[1]))
		if key == "fire":
			village.move_fire(p)
			n += 1
		else:
			var b := village.bld(int(key))
			if b != null:
				village.move_kit_building(b, p)
				n += 1
	return n


## 상자에서 나온 주민이 서는 자리 — 상자 앞(카메라 쪽) 반원. 같은 마을이면 늘 같은 자리
static func stand_spots(village: Village, p: Vector2, yaw: float, n: int) -> Array:
	var out: Array = []
	var fwd := Vector2(sin(yaw), cos(yaw))
	var rows := [[2.3, 1.25], [3.15, 1.0], [4.0, 0.8]]         # [반지름, 양옆으로 벌어지는 각]
	var per := ceili(n / 3.0)
	for i in n:
		var row := mini(i / maxi(1, per), 2)
		var k := i - row * per
		var cnt := mini(per, n - row * per)
		var rr: Array = rows[row]
		var a := 0.0 if cnt <= 1 else lerpf(-float(rr[1]), float(rr[1]), float(k) / (cnt - 1.0))
		a += (0.12 if row == 1 else 0.0)
		out.append(p + fwd.rotated(-a) * (float(rr[0]) + 0.12 * sin(i * 2.3)))
	return out


# ───────────────────────── 상자 ─────────────────────────
## (OPENING v4.0 3 · STORY 1) 상자는 산 물건 — 상품 포장처럼: 판지 몸통 · 색 띠 · 둥근 상표 · 흐려서 읽을 수 없는 작은 글씨 줄 (글자는 없음)
func _make_box() -> Node3D:
	var b := Node3D.new()
	var board := Toon.mat(BOARD)
	var edge := Toon.mat(BOARD.darkened(0.18))
	_part(b, Vector3(BOX.x, WALL, BOX.z), Vector3(0, WALL * 0.5, 0), board)              # 바닥
	_part(b, Vector3(BOX.x, BOX.y, WALL), Vector3(0, BOX.y * 0.5, BOX.z * 0.5 - WALL * 0.5), board)     # 앞
	_part(b, Vector3(BOX.x, BOX.y, WALL), Vector3(0, BOX.y * 0.5, -BOX.z * 0.5 + WALL * 0.5), board)    # 뒤
	_part(b, Vector3(WALL, BOX.y, BOX.z), Vector3(BOX.x * 0.5 - WALL * 0.5, BOX.y * 0.5, 0), board)     # 옆
	_part(b, Vector3(WALL, BOX.y, BOX.z), Vector3(-BOX.x * 0.5 + WALL * 0.5, BOX.y * 0.5, 0), board)
	for s: float in [-1.0, 1.0]:                                                         # 접힌 모서리
		_part(b, Vector3(0.06, BOX.y + 0.01, 0.06), Vector3(s * (BOX.x * 0.5 - 0.02), BOX.y * 0.5, BOX.z * 0.5 - 0.02), edge)
	var front := BOX.z * 0.5 + 0.006
	var band := Toon.mat(BAND)
	_part(b, Vector3(BOX.x - 0.02, 0.3, 0.02), Vector3(0, BOX.y - 0.2, front), band)     # 위 색 띠
	_part(b, Vector3(BOX.x - 0.02, 0.06, 0.02), Vector3(0, 0.12, front), band)           # 아래 가는 띠
	var logo := MeshInstance3D.new()                                                     # 둥근 상표 (흰 원 + 안쪽 작은 원)
	var lc := CylinderMesh.new()
	lc.top_radius = 0.2
	lc.bottom_radius = 0.2
	lc.height = 0.02
	logo.mesh = lc
	logo.material_override = Toon.mat(Color("f7f1e3"))
	logo.rotation.x = PI * 0.5
	logo.position = Vector3(-BOX.x * 0.5 + 0.38, BOX.y - 0.2, front + 0.012)
	b.add_child(logo)
	var dot := logo.duplicate() as MeshInstance3D
	dot.scale = Vector3(0.5, 1.0, 0.5)
	dot.material_override = Toon.mat(BAND.darkened(0.2))
	dot.position.z += 0.006
	b.add_child(dot)
	var blur := StandardMaterial3D.new()                                                 # 흐린 작은 글씨 — 바탕과 비슷한 색, 반투명 (읽을 수 없음)
	blur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blur.albedo_color = Color(PRINT, 0.55)
	blur.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for row in 3:                                                                         # 상표 곁 작은 글씨 세 줄
		var x0 := -BOX.x * 0.5 + 0.66
		var x := x0
		while x < BOX.x * 0.5 - 0.2:
			var w := r.randf_range(0.08, 0.26)
			_part(b, Vector3(w, 0.035, 0.01), Vector3(x + w * 0.5, BOX.y - 0.12 - row * 0.075, front + 0.014), blur)
			x += w + 0.05
	for row in 4:                                                                         # 아래쪽 더 작은 글씨 (네 줄 — 반쯤만)
		var x := -BOX.x * 0.5 + 0.2
		while x < 0.2:
			var w := r.randf_range(0.05, 0.16)
			_part(b, Vector3(w, 0.022, 0.01), Vector3(x + w * 0.5, 0.42 - row * 0.055, front), blur)
			x += w + 0.035
	var ink := Toon.mat(BAND.darkened(0.25))                                              # 겉면 그림: 작은 집 한 채 + 두 사람 (기획서 5.5)
	_part(b, Vector3(0.4, 0.28, 0.02), Vector3(0.62, 0.42, front), ink)
	var roof := _part(b, Vector3(0.38, 0.38, 0.02), Vector3(0.62, 0.58, front), ink)
	roof.rotation.z = PI * 0.25
	roof.scale = Vector3(0.85, 0.85, 1.0)
	for i in 2:
		_part(b, Vector3(0.1, 0.22, 0.02), Vector3(0.95 + i * 0.2, 0.36, front), ink)
		_part(b, Vector3(0.1, 0.1, 0.02), Vector3(0.95 + i * 0.2, 0.53, front), ink)
	for i in 3:                                                                           # 옆면에도 흐린 글씨
		_part(b, Vector3(0.01, 0.03, BOX.z * r.randf_range(0.35, 0.7)), Vector3(BOX.x * 0.5 + 0.006, BOX.y - 0.25 - i * 0.07, 0), blur)
	# 뚜껑 (열면 들려서 상자 뒤에 기대 세워짐 — 낮은 카메라 앞을 가리지 않게)
	lid = Node3D.new()
	lid.position = Vector3(0, BOX.y, 0)
	b.add_child(lid)
	_part(lid, Vector3(BOX.x + 0.12, 0.14, BOX.z + 0.1), Vector3(0, 0.07, 0), band)
	_part(lid, Vector3(BOX.x + 0.13, 0.05, 0.3), Vector3(0, 0.07, 0.25), Toon.mat(Color("f7f1e3")))   # 뚜껑의 흰 줄
	return b


func _part(parent: Node3D, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


# ───────────────────────── 연출 ─────────────────────────
## 처음부터 (창조에서 막 왔을 때): 날아가기 → 내려놓기 → 놓는 높이로 → 칸 (터 꾸미기) → 초확대 → 기어 나오기 → 모닥불 곁으로
func play() -> void:
	phase = "fly"
	t = 0.0
	yaw_deg = close_yaw()
	root.rotation.y = deg_to_rad(yaw_deg)
	glint = SkyDescent.shimmer(BOX.x * 0.75)
	glint.position.y = BOX.y * 0.5
	box.add_child(glint)
	box_shadow = SkyDescent.ground_shadow(BOX.x * 0.62)
	root.add_child(box_shadow)
	box.position.y = HOLD_H
	SkyDescent.set_shadow(box_shadow, 0.15)
	_hide_people()
	caption.say("상자 안에서 사람들이 잠들어 있어요.")
	var cam: JarCamera = sc.cam
	cam.fly_to(Vector3(spot.x, gy0, spot.y), FLY_PPU)


## 앱을 다시 켬 (놓던 중): 상자는 닫힌 채 그 자리에, 주민은 아직 상자 안, 카메라는 놓는 높이 — 바로 칸
func open_tray_now() -> void:
	_lid_pose(0.0)
	_hide_people()
	_cam_place()
	_begin_tray()


## (2026-11-08 사용자) 터를 다 꾸밀 때까지 사람들은 상자 안 — 보이지 않음
func _hide_people() -> void:
	for r in v.people:
		vw.staged[r.id] = {"vis": false}


func _cam_place() -> void:
	var cam: JarCamera = sc.cam
	cam.hold = {}
	cam.ppu = PLACE_PPU
	cam.ppu_goal = PLACE_PPU
	cam.target = Vector3(spot.x, gy0, spot.y)
	cam._apply()


func _process(dt: float) -> void:
	t += dt
	_busy = maxf(0.0, _busy - dt)
	match phase:
		"fly":
			if not (sc.cam as JarCamera).flying:
				phase = "drop"
				t = 0.0
		"drop":
			var u := clampf(t / DROP_T, 0.0, 1.0)
			box.position.y = HOLD_H * (1.0 - (1.0 - (1.0 - u) * (1.0 - u)))
			SkyDescent.set_shadow(box_shadow, lerpf(0.15, 1.0, u * u))
			if u >= 1.0:
				box.position.y = 0.0
				_thud(Vector3(spot.x, gy0, spot.y), 2.6)
				SkyDescent.fade_out(glint)
				glint = null
				var sh := box_shadow
				var tw := create_tween()
				tw.tween_method(func(a: float) -> void: SkyDescent.set_shadow(sh, 1.0, a), 1.0, 0.0, 0.5)
				phase = "settle"
				t = 0.0
				_settle_from = _cam_pose()
				_settle_to = _place_pose()
		"settle":                                       # 상자 둘레가 보이는 놓는 높이로 (건물부터 놓는다)
			var u := clampf(t / SETTLE_T, 0.0, 1.0)
			(sc.cam as JarCamera).hold = _blend(_settle_from, _settle_to, u * u * (3.0 - 2.0 * u))
			if u >= 1.0:
				_cam_place()
				_begin_tray()
		"tray":
			_tray_step()
		"wait":                                         # 마지막 건물이 내려앉을 때까지 → 상자 앞으로
			if _busy <= 0.0 and t >= WAIT_T:
				_start_rush()
		"rush":
			var u := clampf(t / RUSH_T, 0.0, 1.0)
			(sc.cam as JarCamera).hold = _blend(_rush_from, _rush_to, u * u * (3.0 - 2.0 * u))
			if u >= 1.0:
				phase = "open"
				t = 0.0
				GameAudio.fx("box_open", "Room", -4.0)
				var tw := create_tween()
				tw.tween_method(_lid_pose, 0.0, 1.0, OPEN_T).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		"open":
			if t >= OPEN_T + 0.15:
				caption.say("사람들이 막 잠에서 깼어요.")
				phase = "climb"
				t = 0.0
				_et = 0.0
				_plan_climb()
		"climb":
			_et += dt
			_climb_step()
			if _et >= _walk0:                           # 첫 사람이 걷기 시작 → 카메라가 물러나 새 터 전체를 보여 줌
				caption.say("새 터를 둘러보고 모닥불 곁으로 모여요.")
				phase = "gather"
				t = 0.0
				_gather_to = _gather_pose()
		"gather":
			_et += dt
			var u := clampf(t / GATHER_PULL_T, 0.0, 1.0)
			(sc.cam as JarCamera).hold = _blend(_rush_to, _gather_to, u * u * (3.0 - 2.0 * u))
			if _climb_step() and u >= 1.0:
				_stand_all()
				var cam: JarCamera = sc.cam
				cam.hold = {}
				cam.ppu = cam.view_height_px() / float(_gather_to["size"])
				cam.ppu_goal = cam.ppu
				cam.target = _gather_to["target"]
				cam._apply()
				_end_box()
	_layout()


## 뚜껑 열림 정도 u (0 닫힘 ~ 1 상자 뒤에 기대 세워짐) — 위로 들렸다가 뒤로
func _lid_pose(u: float) -> void:
	var a := Vector3(0, BOX.y, 0)
	var b := Vector3(0.25, 0.08, -BOX.z - 0.25)
	var p := a.lerp(b, u)
	p.y += sin(u * PI) * 1.1
	lid.position = p
	lid.rotation.x = sin(u * PI) * -0.9 + u * 0.06
	lid.rotation.y = u * 0.18


func _thud(at: Vector3, r: float) -> void:
	GameAudio.fx("drop_thud")
	GameAudio.buzz()
	if vw.drop_view != null:
		vw.drop_view._puff(at, r)


## 지금 카메라 자리 (정사영 — 보는 점·화면 세로·각·방위·거리)
func _cam_pose() -> Dictionary:
	var cam: JarCamera = sc.cam
	var size := cam.view_height_px() / cam.ppu
	var pitch := cam.pitch_deg
	return {"target": cam.target, "size": size, "pitch": pitch, "yaw": cam._yaw_deg, "dist": JarCamera.inside_dist(size, deg_to_rad(pitch)), "near": 1.0}


## 건물을 놓는 높이 (상자 둘레 KIT_PLACE_R가 화면에 듦 — 보통 각)
func _place_pose() -> Dictionary:
	var cam: JarCamera = sc.cam
	var size := cam.view_height_px() / PLACE_PPU
	return {"target": Vector3(spot.x, gy0, spot.y), "size": size, "pitch": JarCamera.PITCH_DEG, "yaw": cam._yaw_deg,
		"dist": JarCamera.inside_dist(size, deg_to_rad(JarCamera.PITCH_DEG)), "near": 1.0}


## 모닥불 곁에 모인 모습 — 상자와 모닥불이 함께 들게 (보통 각 · 지금 방위, 끝나면 그대로 보통 카메라로 넘김)
func _gather_pose() -> Dictionary:
	var cam: JarCamera = sc.cam
	var mid := (spot + v.fire) * 0.5
	var size := clampf(spot.distance_to(v.fire) * 1.5 + 8.0, CLOSE_SIZE + 2.0, cam.view_height_px() / PLACE_PPU)
	var tg := Vector3(mid.x, (sc.terrain as JarTerrain).ground_y(mid.x, mid.y), mid.y)
	return {"target": tg, "size": size, "pitch": JarCamera.PITCH_DEG, "yaw": cam._yaw_deg,
		"dist": JarCamera.inside_dist(size, deg_to_rad(JarCamera.PITCH_DEG)), "near": 1.0}


func _start_rush() -> void:
	phase = "rush"
	t = 0.0
	_rush_from = _cam_pose()
	_rush_to = close_pose()
	GameAudio.fx("fly_whoosh", "Room", -8.0)


## 초확대 방위: 지금 카메라 방위 ±90° 안에서 상자와 카메라 사이(앞 22칸 · 양옆 3칸)에 나무·숲이 가장 적은 쪽 (같으면 지금 방위에 가까운 쪽)
func close_yaw() -> float:
	var base := (sc.cam as JarCamera)._yaw_deg
	var best := base
	var best_n := 1.0e9
	for off: float in [0.0, 22.5, -22.5, 45.0, -45.0, 67.5, -67.5, 90.0, -90.0]:
		var yr := deg_to_rad(base + off)
		var fwd := Vector2(sin(yr), cos(yr))
		var side := Vector2(fwd.y, -fwd.x)
		var n := 0.0
		for tr: Dictionary in v.trees:
			var d := Vector2(float(tr["x"]), float(tr["y"])) - spot
			var along := d.dot(fwd)
			if along > 3.0 and along < 22.0 and absf(d.dot(side)) < 3.2:
				n += 1.0
		var dd := 4.0
		while dd < 22.0:                                  # 화면 장식 숲 (VillageView — 시뮬레이션에 없는 나무)
			for sx: float in [-2.0, 0.0, 2.0]:
				n += vw.forest_at(spot + fwd * dd + side * sx) * 0.6
			dd += 2.0
		n += absf(off) * 0.004
		if n < best_n:
			best_n = n
			best = base + off
	return best


## 상자 바로 앞 낮은 각 — 카메라 면(정사영)의 아래 끝이 땅 위에 있게 거리를 잡고, 상자까지 가운데 광선이 언덕에 막히면 각을 조금씩 높인다
func close_pose() -> Dictionary:
	var ter: JarTerrain = sc.terrain
	var tg := Vector3(spot.x, gy0 + 0.85, spot.y)
	var best := {}
	for pd: float in CLOSE_PITCH:
		var pr := deg_to_rad(pd)
		var half := CLOSE_SIZE * 0.5
		var dist := maxf(4.0, (half * cos(pr) - 0.85 + 0.6) / sin(pr))
		var yr := deg_to_rad(yaw_deg)
		var back := Vector3(sin(yr) * cos(pr), sin(pr), cos(yr) * cos(pr))
		var up := Vector3(-sin(yr) * sin(pr), cos(pr), -cos(yr) * sin(pr))
		var clear := true
		for k: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:      # 카메라 면 (화면 아래 끝 ~ 위 끝)이 땅 밖에
			var q := tg + back * dist + up * (half * k)
			if ter.ground_y(q.x, q.z) > q.y - 0.3:
				clear = false
		var s := 1.0
		while s < dist and clear:                          # 상자를 보는 가운데 광선이 언덕에 막히지 않게
			var q := tg + back * s
			if ter.ground_y(q.x, q.z) > q.y - 0.1:
				clear = false
			s += 0.5
		best = {"target": tg, "size": CLOSE_SIZE, "pitch": pd, "yaw": yaw_deg, "dist": dist, "near": 0.2}
		if clear:
			break
	return best


static func _blend(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var la := log(float(a["size"]))
	var lb := log(float(b["size"]))
	return {"target": (a["target"] as Vector3).lerp(b["target"], u), "size": exp(lerpf(la, lb, u)), "pitch": lerpf(a["pitch"], b["pitch"], u),
		"yaw": lerpf(a["yaw"], b["yaw"], u), "dist": lerpf(a["dist"], b["dist"], u), "near": lerpf(a.get("near", 1.0), b.get("near", 1.0), u)}


# ───────────────────────── 모닥불 곁 (모이는 자리) ─────────────────────────
## 모닥불 둘레 고리 (FIRE_RING) — 상자 쪽부터 양옆으로 번갈아. 건물·상자·물·바위·벽을 피함. 같은 마을이면 늘 같은 자리 (ADR-0001 결정적)
static func gather_spots(village: Village, box_spot: Vector2, n: int) -> Array:
	var obs: Array = [[box_spot, maxf(BOX.x, BOX.z) * 0.6]]
	for b in village.buildings:
		if b.site_type() != Awakening.ALTAR:
			obs.append([Vector2(b.x, b.y), b.size()])
	var f := village.fire
	var base := box_spot - f
	var a0 := atan2(base.y, base.x) if base.length() > 0.01 else PI * 0.5
	var out: Array = []
	for rr: float in FIRE_RING:
		var cnt := maxi(4, floori(TAU * rr / GATHER_GAP))
		var step := TAU / cnt
		for k in cnt:
			if out.size() >= n:
				return out
			var off := ceilf(k / 2.0) * step * (1.0 if k % 2 == 1 else -1.0)
			var p := f + Vector2(cos(a0 + off), sin(a0 + off)) * rr
			if _spot_free(village, p, obs):
				out.append(p)
	var rad: float = FIRE_RING[FIRE_RING.size() - 1] + GATHER_GAP       # 고리가 모자라면 바깥으로 (드묾)
	var k2 := 0
	while out.size() < n and k2 < 400:
		var p := f + Vector2(cos(a0 + k2 * 0.7), sin(a0 + k2 * 0.7)) * (rad + k2 * 0.05)
		if _spot_free(village, p, obs) or k2 >= 300:
			out.append(p)
		k2 += 1
	while out.size() < n:
		out.append(f + Vector2(rad, 0.0))
	return out


static func _spot_free(village: Village, p: Vector2, obs: Array) -> bool:
	if village.water == null or not village.water.inside(p.x, p.y, 0.8) or village.water_at(p.x, p.y):
		return false
	for r: Dictionary in village.rocks:
		if Vector2(r["x"] - p.x, r["y"] - p.y).length() < 0.9:
			return false
	for o: Array in obs:
		if (o[0] as Vector2).distance_to(p) < float(o[1]) + 0.45:
			return false
	return true


## 모닥불 곁에 모인 자리 — {id: Vector2}. 아이·어른 (아기 빼고) v.people 순서대로 고리에, 아기는 엄마(없으면 첫 사람) 곁
static func gather_layout(village: Village, box_spot: Vector2) -> Dictionary:
	var ppl: Array[Resident] = []
	for r in village.people:
		if not r.is_baby():
			ppl.append(r)
	var spots := gather_spots(village, box_spot, ppl.size())
	var out := {}
	for i in ppl.size():
		out[ppl[i].id] = spots[i]
	for r in village.people:
		if r.is_baby():
			var host: Vector2 = out.get(r.parents[0] if r.parents.size() > 0 else -1, spots[0] if not spots.is_empty() else village.fire + Vector2(2, 0))
			var d := host - village.fire
			out[r.id] = host + (d.normalized().rotated(PI * 0.5) * 0.45 if d.length() > 0.01 else Vector2(0.45, 0.0))
	return out


## 모두 모닥불 곁 자리에 (시뮬레이션 자리) — 모닥불을 바라봄. 앱을 다시 켰을 때·연출 없을 때도 같은 자리
static func gather_people(village: Village, box_spot: Vector2) -> void:
	var lay := gather_layout(village, box_spot)
	for r in village.people:
		var p: Vector2 = lay.get(r.id, village.fire + Vector2(2, 0))
		var d := village.fire - p
		_set_pos(r, p, atan2(d.x, d.y) if d.length() > 0.01 else 0.0)


## 상자 → 모닥불 곁: 건물·상자·불을 비켜 가는 꺾인 길 (곧은 줄이 가로막히면 옆으로 한 번씩 — 셋까지)
func _path(a: Vector2, b: Vector2) -> Array:
	var pts: Array = [a]
	var cur := a
	var obs: Array = [[spot, maxf(BOX.x, BOX.z) * 0.6], [v.fire, 1.0]]       # 모닥불 한가운데도 비켜 감
	for it: Dictionary in items:
		if String(it["key"]) != "fire":
			var bb: Building = it["b"]
			obs.append([Vector2(bb.x, bb.y), bb.size()])
	for _i in 3:
		var hit: Array = []
		var best := 1.0e9
		for o: Array in obs:
			var c: Vector2 = o[0]
			var need := float(o[1]) + 0.35
			if c.distance_to(b) < need or c.distance_to(cur) < need:
				continue
			var seg := b - cur
			var u := clampf((c - cur).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
			var q := cur + seg * u
			if q.distance_to(c) < need and u < best:
				best = u
				hit = o
		if hit.is_empty():
			break
		var c2: Vector2 = hit[0]
		var seg2 := (b - cur).normalized()
		var side := Vector2(-seg2.y, seg2.x)
		if (c2 - cur).dot(side) > 0.0:
			side = -side
		var w := c2 + side * (float(hit[1]) + 0.8)
		pts.append(w)
		cur = w
	pts.append(b)
	return pts


static func _path_len(pts: Array) -> float:
	var n := 0.0
	for i in range(1, pts.size()):
		n += (pts[i] as Vector2).distance_to(pts[i - 1])
	return n


static func _path_at(pts: Array, s: float) -> Dictionary:
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var l := a.distance_to(b)
		if s <= l or i == pts.size() - 1:
			var d := b - a
			return {"p": a.lerp(b, clampf(s / maxf(l, 0.0001), 0.0, 1.0)), "rot": atan2(d.x, d.y) if d.length() > 0.001 else 0.0}
		s -= l
	return {"p": pts[pts.size() - 1], "rot": 0.0}


# ───────────────────────── 기어 나오기 → 모닥불 곁으로 ─────────────────────────
func _plan_climb() -> void:
	climb.clear()
	var yr := deg_to_rad(yaw_deg)
	var ppl: Array[Resident] = []
	var babies: Array[Resident] = []
	for r in v.people:
		if r.is_baby():
			babies.append(r)
		else:
			ppl.append(r)
	var kids := FirstArrival.first_three(v)
	for r in kids:
		if r.is_child():
			kid = r
	if kid == null:                                  # 소개할 셋에 아이가 없으면 맨 처음 아이
		for r in ppl:
			if r.is_child():
				kid = r
				break
	if kid != null and ppl.has(kid):                 # 하늘을 올려다볼 아이는 맨 앞 가운데에
		ppl.erase(kid)
		ppl.insert(ceili(ppl.size() / 3.0) / 2, kid)
	var stands := stand_spots(v, spot, yr, ppl.size())
	for i in stands.size():                          # 건물을 먼저 놓았으니 상자 앞에 모닥불이 있을 수 있음 — 불 위에 서지 않게
		var sp: Vector2 = stands[i]
		var df := sp - v.fire
		if df.length() < FIRE_RING[0] - 0.1:
			stands[i] = v.fire + (df.normalized() if df.length() > 0.01 else Vector2(sin(yr), cos(yr))) * (FIRE_RING[0] - 0.1)
	var lay := gather_layout(v, spot)
	var xf := Transform3D(Basis(Vector3.UP, yr), Vector3(spot.x, gy0, spot.y))
	var longest := 0.0
	for i in ppl.size():
		var r := ppl[i]
		var lx := lerpf(-BOX.x * 0.3, BOX.x * 0.3, fposmod(i * 0.618, 1.0))
		var goal: Vector2 = lay[r.id]
		var path := _path(stands[i], goal)
		longest = maxf(longest, _path_len(path))
		var e := {"r": r, "t0": i * CLIMB_GAP,
			"a": xf * Vector3(lx, 0.0, -0.1),                                   # 상자 안 바닥
			"b": xf * Vector3(lx, BOX.y - 0.75, BOX.z * 0.5 - 0.32),             # 앞벽 안쪽에서 머리가 올라옴
			"c": xf * Vector3(lx, BOX.y, BOX.z * 0.5 + 0.02),                   # 가장자리 위
			"d": xf * Vector3(lx * 1.1, 0.0, BOX.z * 0.5 + 0.85),               # 폴짝 내려선 곳
			"stand": stands[i], "rot": yr, "babies": [], "path": path, "len": _path_len(path), "goal": goal}
		climb.append(e)
	_speed = maxf(GATHER_SPEED, longest / GATHER_MAX_T)       # 모두 같은 걸음 (멀면 조금 서두름)
	_walk0 = CLIMB_T + LINGER_T
	for bb in babies:                       # 아기는 엄마(없으면 어른 아무나) 품에서 — 엄마가 내려서면 곁에
		var host: Dictionary = {}
		for e: Dictionary in climb:
			var rr: Resident = e["r"]
			if bb.parents.size() > 0 and rr.id == bb.parents[0]:
				host = e
		if host.is_empty():
			for e: Dictionary in climb:
				if (e["r"] as Resident).is_adult() and (e["r"] as Resident).sex == "f":
					host = e
					break
		if host.is_empty() and not climb.is_empty():
			host = climb[0]
		if not host.is_empty():
			(host["babies"] as Array).append(bb)


## 한 명씩: 기어 나옴 → 폴짝 → 상자 앞 자리 → 기지개 → 두리번 (아이 갸웃 "어…?") → 모닥불 곁으로 걸어감 → 불을 바라봄. 모두 끝나면 true
func _climb_step() -> bool:
	var done := true
	var ter: JarTerrain = sc.terrain
	for e: Dictionary in climb:
		var r: Resident = e["r"]
		var lt := _et - float(e["t0"])
		var st := {"vis": lt >= 0.0, "rot": float(e["rot"]), "anim": "idle"}
		if lt < 0.0:
			vw.staged[r.id] = st
			done = false
			continue
		var a: Vector3 = e["a"]
		var b: Vector3 = e["b"]
		var c: Vector3 = e["c"]
		var d: Vector3 = e["d"]
		var sp: Vector2 = e["stand"]
		var s3 := Vector3(sp.x, ter.ground_y(sp.x, sp.y), sp.y)
		d.y = ter.ground_y(d.x, d.z)
		var walk_t := float(e["len"]) / _speed
		if lt < 0.55:                                   # 안에서 가장자리로 기어오름
			var u := lt / 0.55
			st["pos"] = a.lerp(b, u * (2.0 - u))
			st["anim"] = "walk"
		elif lt < 0.9:                                  # 가장자리를 넘음
			var u := (lt - 0.55) / 0.35
			st["pos"] = b.lerp(c, u)
			st["anim"] = "crouch"
		elif lt < 1.25:                                 # 폴짝
			var u := (lt - 0.9) / 0.35
			var p := c.lerp(d, u)
			p.y = lerpf(c.y, d.y, u) + sin(u * PI) * 0.4
			st["pos"] = p
			st["anim"] = "run"
			if not e.has("hop"):
				e["hop"] = true
				GameAudio.fx("paper", "Room", -16.0)
		elif lt < 1.4:                                  # 내려섬 (살짝 웅크림)
			st["pos"] = d
			st["anim"] = "crouch"
		elif lt < CLIMB_T:                              # 상자 앞 자리로 몇 걸음
			var u := (lt - 1.4) / (CLIMB_T - 1.4)
			st["pos"] = d.lerp(s3, u)
			var dv := s3 - d
			st["rot"] = atan2(dv.x, dv.z)
			st["anim"] = "walk"
		elif lt < CLIMB_T + WAKE_T:                     # 막 잠에서 깬 듯 기지개 (OPENING v4.0 3)
			st["pos"] = s3
			st["rot"] = float(e["rot"])
			st["anim"] = "stretch"
			st["face"] = "sleep"                     # 눈을 감은 채
		elif lt < _walk0:                               # 새 터를 두리번거림 (아이 하나는 하늘을 올려다보며 갸웃)
			st["pos"] = s3
			st["rot"] = float(e["rot"]) + sin(lt * 0.9 + r.id) * 0.6
			st["anim"] = "look"
			st["face"] = "surprised" if lt < CLIMB_T + WAKE_T + 0.8 else ""
			if r == kid:
				st["anim"] = "idle"
				st["rot"] = float(e["rot"])
				var k := clampf((lt - CLIMB_T - WAKE_T) / 0.6, 0.0, 1.0)
				st["tilt"] = Vector2(0.75 * k, 0.32 * k * (1.0 + 0.25 * sin(lt * 1.3)))
				if k >= 1.0 and not e.has("wonder"):    # 낯선 하늘을 올려다보며 갸웃 (아직 거인을 모름 — 손 흔들기 없음)
					e["wonder"] = true
					r.say = "어…?"
					r.say_t = 2.2
		elif lt < _walk0 + walk_t:                      # 모닥불 곁으로 (건물을 비켜)
			var at := _path_at(e["path"], (lt - _walk0) * _speed)
			var q: Vector2 = at["p"]
			st["pos"] = Vector3(q.x, ter.ground_y(q.x, q.y), q.y)
			st["rot"] = float(at["rot"])
			st["anim"] = "run" if _speed > 1.7 else "walk"
			if r == kid and lt < _walk0 + 0.8:          # 아이는 걸으면서도 잠깐 하늘을
				st["tilt"] = Vector2(0.75, 0.32).lerp(Vector2.ZERO, (lt - _walk0) / 0.8)
		else:                                           # 모닥불을 바라보며 섬
			var g: Vector2 = e["goal"]
			st["pos"] = Vector3(g.x, ter.ground_y(g.x, g.y), g.y)
			var df := v.fire - g
			st["rot"] = atan2(df.x, df.y)
			st["anim"] = "idle"
		vw.staged[r.id] = st
		for i in (e["babies"] as Array).size():
			var bb: Resident = e["babies"][i]
			var bs: Dictionary = {"vis": lt >= 1.25, "anim": "idle", "rot": float(st["rot"])}
			var bp: Vector3 = st["pos"]
			bs["pos"] = bp + Vector3(0.45 + 0.35 * i, 0.0, 0.3).rotated(Vector3.UP, float(st["rot"]))
			vw.staged[bb.id] = bs
		if lt < _walk0 + walk_t + GATHER_LINGER:
			done = false
	return done


## 모두 모닥불 곁 자리에 (시뮬레이션 자리 = 모인 자리) — 연출 끝
func _stand_all() -> void:
	gather_people(v, spot)
	vw.staged.clear()


static func _set_pos(r: Resident, p: Vector2, rot: float) -> void:
	r.x = p.x
	r.y = p.y
	r.px = p.x
	r.py = p.y
	r.facing = rot


# ───────────────────────── 칸 (건물 놓기) ─────────────────────────
func _make_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 14
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.get_theme()
	layer.add_child(ui)
	caption = StartCaption.new()
	caption.visible = false
	ui.add_child(caption)
	tray = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.988, 0.965, 0.905, 0.96)
	sb.border_color = Color(0.145, 0.13, 0.133, 0.3)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(10)
	tray.add_theme_stylebox_override("panel", sb)
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	tray.visible = false
	ui.add_child(tray)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	tray.add_child(col)
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", UiTheme.SIZE)
	hint.add_theme_color_override("font_color", UiTheme.INK)
	col.add_child(hint)
	var sc_box := ScrollContainer.new()
	sc_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sc_box.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc_box.custom_minimum_size = Vector2(0, 66)
	col.add_child(sc_box)
	tray_row = HBoxContainer.new()
	tray_row.add_theme_constant_override("separation", 6)
	tray_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tray_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc_box.add_child(tray_row)
	for it: Dictionary in items:
		var b := Button.new()
		b.text = String(it["label"])
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(62, 62)
		b.toggle_mode = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", UiTheme.SIZE_SMALL)
		var icon := "모닥불" if String(it["key"]) == "fire" else String(it["type"])
		if GameIcons.has(icon):
			GameIcons.button_icon(b, icon, 28)
		var key := String(it["key"])
		b.pressed.connect(GameAudio.ui_click)
		b.pressed.connect(func() -> void: select(key))
		tray_row.add_child(b)
		_btns[key] = b
	auto_btn = Button.new()
	auto_btn.text = "알아서 놓기"
	auto_btn.focus_mode = Control.FOCUS_NONE
	auto_btn.custom_minimum_size = Vector2(0, UiTheme.TOUCH)
	auto_btn.pressed.connect(GameAudio.ui_click)
	auto_btn.pressed.connect(auto_place)
	col.add_child(auto_btn)


func _layout() -> void:
	if ui == null or not ui.is_inside_tree():
		return
	var ins := SafeArea.insets(ui.get_viewport())
	var vs := ui.get_viewport().get_visible_rect().size
	var w := minf(360.0, vs.x - 24.0)
	caption.custom_minimum_size.x = minf(330.0, vs.x - 32.0)
	caption.reset_size()
	caption.position = Vector2((vs.x - caption.size.x) * 0.5, ins.x + 36.0)
	tray.custom_minimum_size.x = w
	tray.size = Vector2(w, 0)
	tray.reset_size()
	tray.position = Vector2((vs.x - w) * 0.5, vs.y - ins.y - 14.0 - tray.size.y)


func _begin_tray() -> void:
	phase = "tray"
	t = 0.0
	if ring == null:
		ring = MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = Village.KIT_PLACE_R - 0.12
		tm.outer_radius = Village.KIT_PLACE_R + 0.12
		tm.rings = 64
		ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1.0, 0.97, 0.85, 0.55)
		ring.material_override = m
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(sc.jar as Node3D).add_child(ring)
		ring.position = Vector3(spot.x, gy0 + 0.12, spot.y)
	ring.visible = true
	caption.say("사람들이 깨기 전에, 상자에 든 것으로 터를 꾸며 주세요.", true)
	tray.visible = true
	_refresh_tray()
	if remaining() == 0:
		_finish()
		return
	_select_first()


func remaining() -> int:
	var n := 0
	for it: Dictionary in items:
		if not bool(it["placed"]):
			n += 1
	return n


func _item(key: String) -> Dictionary:
	for it: Dictionary in items:
		if String(it["key"]) == key:
			return it
	return {}


func _refresh_tray() -> void:
	for it: Dictionary in items:
		var b: Button = _btns.get(String(it["key"]))
		if b == null:
			continue
		b.visible = not bool(it["placed"])
		b.set_pressed_no_signal(sel >= 0 and items[sel] == it)
	if sel < 0:
		hint.text = "놓을 것을 고르세요"
	auto_btn.visible = remaining() > 0


func _select_first() -> void:
	for it: Dictionary in items:
		if not bool(it["placed"]):
			select(String(it["key"]))
			return


## 칸에서 하나 고름 → 그림자 미리보기 (처음엔 상자 앞 놓을 수 있는 곳)
func select(key: String) -> void:
	var it := _item(key)
	if it.is_empty() or bool(it["placed"]):
		return
	sel = items.find(it)
	_make_ghost(it)
	var p0: Variant = _suggest(it)
	aim_ground(p0 if p0 != null else spot + Vector2(0, 4))
	_refresh_tray()


func _make_ghost(it: Dictionary) -> void:
	if ghost != null:
		ghost.queue_free()
	ghost = Node3D.new()
	(sc.jar as Node3D).add_child(ghost)
	var model := Node3D.new()
	ghost.add_child(model)
	var nm := "campfire"
	var b: Building = it["b"]
	if b != null:
		var names: Array = VillageView.BUILDING_MODELS.get(b.type, ["hut"])
		nm = String(names[b.id % names.size()])
	Art.instance(model, nm)
	ghost_ring = MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = float(it["size"]) + 0.15
	cy.bottom_radius = float(it["size"]) + 0.15
	cy.height = 0.04
	cy.radial_segments = 32
	ghost_ring.mesh = cy
	ghost_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost_ring.position.y = 0.08
	ghost.add_child(ghost_ring)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tint(true)


func _tint(ok: bool) -> void:
	if ghost == null:
		return
	var c := OK_COL if ok else BAD_COL
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c, 0.62)
	for mi: MeshInstance3D in ghost.get_child(0).find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = m
	var rm := m.duplicate() as StandardMaterial3D
	rm.albedo_color = Color(c, 0.7)
	ghost_ring.material_override = rm


## 이미 놓은 것·상자 (겹치면 안 되는 것) — [[자리, 반지름]]
func obstacles(with_box := true) -> Array:
	var out: Array = []
	if with_box and box != null:
		out.append([spot, maxf(BOX.x, BOX.z) * 0.55])
	for it: Dictionary in items:
		if not bool(it["placed"]):
			continue
		if String(it["key"]) == "fire":
			out.append([v.fire, FIRE_SIZE + 0.4])
		else:
			var b: Building = it["b"]
			out.append([Vector2(b.x, b.y), b.size()])
	return out


## 그 자리에 고른 것을 놓을 수 있나 (그림자를 옮김) → {ok, why}
func aim_ground(p: Vector2) -> Dictionary:
	if sel < 0:
		return {"ok": false, "why": "놓을 것을 고르세요"}
	var it: Dictionary = items[sel]
	ghost_p = p
	ghost_r = v.kit_item_ok(p, float(it["size"]), obstacles())
	if ghost != null:
		ghost.position = Vector3(p.x, (sc.terrain as JarTerrain).ground_y(p.x, p.y) + 0.02, p.y)
		var d := v.fire - p if String(it["key"]) != "fire" else Vector2(sin(deg_to_rad(yaw_deg)), cos(deg_to_rad(yaw_deg)))
		if d.length() < 0.5:
			d = spot - p
		ghost.rotation.y = atan2(d.x, d.y) if d.length() > 0.01 else 0.0
		_tint(bool(ghost_r["ok"]))
	if bool(ghost_r["ok"]):
		hint.text = "%s — 여기에 놓을 수 있어요. 손을 떼면 놓여요" % String(it["label"])
		hint.add_theme_color_override("font_color", UiTheme.INK)
	else:
		hint.text = "%s — %s" % [String(it["label"]), String(ghost_r["why"])]
		hint.add_theme_color_override("font_color", Color("b3261e"))
	return ghost_r


## 그 자리에 놓음 (놓을 수 없으면 false). 위에서 내려앉아 톡 · 흙먼지 · 쿵 → 시뮬레이션 자리 + creation.json
func place_at(p: Vector2) -> bool:
	var r := aim_ground(p)
	if not bool(r["ok"]):
		GameAudio.fx("glass_tap_light")
		return false
	var it: Dictionary = items[sel]
	_put(it, p, true)
	sel = -1
	if ghost != null:
		ghost.queue_free()
		ghost = null
	_after_put()
	return true


func _put(it: Dictionary, p: Vector2, fx: bool) -> void:
	var key := String(it["key"])
	if key == "fire":
		v.move_fire(p)
	else:
		v.move_kit_building(it["b"], p)
	it["placed"] = true
	_hide_item(it, false)
	if plan != null:
		plan.placed[key] = [p.x, p.y]
	if fx:
		_drop_fx(it, p)


func _after_put() -> void:
	if plan != null:
		plan.save(StartFlow.save_dir())
	_refresh_tray()
	if remaining() == 0:
		_finish()
	else:
		_select_first()


func view_hidden(id: int) -> bool:
	return vw.hidden_blds.has(id)


func _hide_item(it: Dictionary, on: bool) -> void:
	if String(it["key"]) == "fire":
		vw.hide_fire = on
	elif on:
		vw.hidden_blds[(it["b"] as Building).id] = true
	else:
		vw.hidden_blds.erase((it["b"] as Building).id)


func _drop_fx(it: Dictionary, p: Vector2) -> void:
	var gy := (sc.terrain as JarTerrain).ground_y(p.x, p.y)
	var size := float(it["size"])
	_busy = SkyDropView.FALL_SECS
	if String(it["key"]) == "fire":                # (A24) 모닥불은 따로 떨어지는 노드가 없음 — 그 자리에 그림자가 자라고 반짝임이 내려옴
		SkyDescent.landing(sc.jar as Node3D, Vector3(p.x, gy, p.y), maxf(0.8, size), SkyDropView.FALL_SECS, 8.0)
		var tw2 := create_tween()
		tw2.tween_interval(SkyDropView.FALL_SECS)
		tw2.tween_callback(func() -> void: _thud(Vector3(p.x, gy, p.y), 1.6))
		return
	vw._sync_buildings()
	var n: Node3D = vw._blds.get((it["b"] as Building).id)
	if n != null and vw.drop_view != null:
		vw.drop_view.fall(n, n.position.y)       # 떨어져 쿵 + 흙먼지 (SkyDropView)


## 자동 배치 자리가 비었으면 그 자리, 아니면 상자 앞부터 나선으로 놓을 수 있는 가까운 곳
func _suggest(it: Dictionary, with_box := true) -> Variant:
	var obs := obstacles(with_box)
	var size := float(it["size"])
	var base: Vector2 = v.fire if String(it["key"]) == "fire" else Vector2((it["b"] as Building).x, (it["b"] as Building).y)
	if bool(v.kit_item_ok(base, size, obs)["ok"]):
		return base
	var fwd := Vector2(sin(deg_to_rad(yaw_deg)), cos(deg_to_rad(yaw_deg)))
	var rad := 3.0
	while rad <= Village.KIT_PLACE_R:
		for i in 16:
			var q := spot + fwd.rotated(i * TAU / 16.0 * (1.0 if i % 2 == 0 else -1.0) * 0.5) * rad
			if bool(v.kit_item_ok(q, size, obs)["ok"]):
				return q
		rad += 1.0
	return null


## [알아서 놓기]: 남은 것을 지금의 자동 배치대로 (그 자리가 이미 찼으면 가까운 빈 곳)
func auto_place() -> void:
	if phase != "tray":
		return
	var k := 0
	for it: Dictionary in items:
		if bool(it["placed"]):
			continue
		var p: Variant = _suggest(it, false)
		if p == null:
			p = v.fire if String(it["key"]) == "fire" else Vector2((it["b"] as Building).x, (it["b"] as Building).y)
		var tw := create_tween()
		tw.tween_interval(0.12 * k)
		var pp: Vector2 = p
		_put(it, pp, false)
		_hide_item(it, true)
		tw.tween_callback(func() -> void:
			_hide_item(it, false)
			_drop_fx(it, pp))
		k += 1
	_busy = maxf(_busy, 0.12 * k + SkyDropView.FALL_SECS + 0.2)
	sel = -1
	if ghost != null:
		ghost.queue_free()
		ghost = null
	_after_put()


## 다 놓음 → (연출) 상자 앞으로 · 열림 · 사람들이 나와 모닥불 곁으로 → 상자가 떠나감. 연출 없음(시험) = 바로 모닥불 곁에 모인 자리로
func _finish() -> void:
	tray.visible = false
	if ring != null:
		ring.visible = false
	if plan != null:
		plan.save(StartFlow.save_dir())
	if not bool(sc.get("kit_anim")):                # 시험 (연출 없이): 바로
		caption.visible = false
		if box != null:
			box.visible = false
		_stand_all()
		phase = "done"
		finished.emit()
		return
	caption.say("터가 다 꾸며졌어요.")
	phase = "wait"
	t = 0.0


func _end_box() -> void:
	phase = "end"
	t = 0.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_callback(func() -> void: caption.visible = false)
	if box != null and is_instance_valid(box) and box.is_inside_tree():      # (A24) 빈 상자는 뚜껑이 닫히고 반짝임 속에 떠올라 감 (손 없이)
		tw.tween_method(_lid_pose, 1.0, 0.0, 0.3)
		tw.tween_callback(func() -> void:
			var g := SkyDescent.shimmer(BOX.x * 0.75)
			g.position.y = BOX.y * 0.5
			box.add_child(g))
		tw.tween_interval(0.35)
		if box_shadow != null:
			var sh := box_shadow
			tw.tween_method(func(k: float) -> void: SkyDescent.set_shadow(sh, 1.0 - k, 1.0 - k), 0.0, 1.0, 0.9)
			tw.parallel().tween_property(box, "position:y", 70.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		else:
			tw.tween_property(box, "position:y", 70.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: box.visible = false)
	tw.tween_callback(func() -> void:
		phase = "done"
		finished.emit())


func _exit_tree() -> void:
	for n: Node in [root, ring, ghost]:
		if n != null and is_instance_valid(n):
			n.queue_free()


## 장면이 넘겨주는 누름 (자리 고르기 중) — 쓰면 true
func handle_input(e: InputEvent) -> bool:
	if phase in ["", "done"]:
		return false
	if phase != "tray":
		return e is InputEventScreenTouch or e is InputEventScreenDrag or e is InputEventMouseButton or (e is InputEventMouseMotion and _press)
	if sel < 0:
		return false
	if e is InputEventScreenTouch:
		var st := e as InputEventScreenTouch
		if st.index != 0:
			return true                                 # 놓는 동안 두 손가락은 쓰지 않음
		if st.pressed:
			_press = true
			aim_ground(_ground(st.position, true))
		elif _press:
			_press = false
			if not st.canceled:
				place_at(_ground(st.position, true))
		return true
	if e is InputEventScreenDrag:
		var sd := e as InputEventScreenDrag
		if sd.index == 0 and _press:
			aim_ground(_ground(sd.position, true))
		return true
	if e.device == InputEvent.DEVICE_ID_EMULATION:
		return true
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		if mb.pressed:
			_press = true
			aim_ground(_ground(mb.position, false))
		elif _press:
			_press = false
			place_at(_ground(mb.position, false))
		return true
	if e is InputEventMouseMotion:
		aim_ground(_ground((e as InputEventMouseMotion).position, false))     # 컴퓨터: 마우스를 따라 그림자
		return true
	return false


## 손가락 위로 조금 띄워 (그림자가 손가락에 가리지 않게)
func _ground(sp: Vector2, touch: bool) -> Vector2:
	return sc.screen_to_ground(sp - Vector2(0, 46.0 if touch else 0.0))


func _tray_step() -> void:
	if ghost != null:
		var ov := ghost_ring.material_override as StandardMaterial3D
		if ov != null:
			ov.albedo_color.a = 0.6 + 0.15 * sin(t * 4.0)
