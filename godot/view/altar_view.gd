## 마을 제단 (기획서 11.1 · 6.5 깨달음 — ROADMAP A4b · E1-2 · EVENTS_STAGING 2b). village_view.gd가 하나 가진다 (모든 무리 — 소형 병·넓은 세상).
## 소인의 제단 (GD 3.0 — 나무 판자 없이): 조약돌·진흙·이끼·꽃잎·도토리 깍정이. 블렌더 모델 대신 여기서 바로 만든다 (단계마다 모양이 바뀌어야 해서).
## 짓는 다섯 단계 (2b — 단계가 바뀔 때마다 쿵 소리 + 흙먼지): ① 둥글게 조약돌을 깐 바닥 ② 진흙을 바른 낮은 단 ③ 조약돌 기둥 위 평평한 윗돌 +
##   가운데 도토리 깍정이 그릇 ④ 앞의 작은 돌계단 · 양옆 작은 조약돌 기둥 ⑤ 둘레에 꽃잎·이끼. 짓는 동안 둘레에 주워 온 돌무더기 (단계마다 줄어듦).
## 넓힌 제단 (Village.altar_level): 1 조약돌 한 겹 더 · 2 기둥에 꽃 화환 · 3 잎 지붕 작은 사당.
## 제단이 아직 없으면(깨달음 전) 아무것도 없다. 제물이 기다리면 윗돌 위에 그 물건들이 쌓인 더미 + 따뜻한 빛 (천천히 숨 쉼). 자리는 Village.altar_pos.
class_name AltarView
extends Node3D

const STAGES := 5
const FLOOR_R := 1.55                # ① 조약돌 바닥 반지름
const RING_R := 1.62                 # 바닥 가장자리 조약돌 고리
const PEBBLES := 22
const DRUM_R := 1.12                 # ② 낮은 단
const DRUM_H := 0.2
const PED_H := 0.42                  # ③ 윗돌을 받치는 조약돌 기둥
const SLAB_R := 0.78
const SLAB_H := 0.13
const FLOOR_H := 0.05
const TOP_Y := FLOOR_H + DRUM_H + PED_H + SLAB_H     # 제물이 놓이는 높이 (윗돌 윗면)
const CLAY := Color("b98a5c")
const CLAY_DARK := Color("9a6d45")
const ACORN := Color("8a5a32")
const ACORN_DARK := Color("6a4224")
const MOSS_C := Color("7fa957")
const PETALS := [Color("f3a9bb"), Color("f7d86e"), Color("fbf3e2"), Color("c9a3e8")]

var v: Village
var terrain: JarTerrain
var _body: Node3D                    # 단·제단 (상태가 바뀔 때만 다시)
var _pile: Node3D                    # 제물 더미
var _glow: MeshInstance3D
var _key := ""
var _stage := -1
var thuds := 0                       # (시험) 단계가 바뀌어 쿵 한 횟수
var _dust: Array = []                # 단계가 바뀔 때 피어오르는 흙먼지 [MeshInstance3D, 남은 초]
var _pile_key := ""
var _t := 0.0
## (2026-11-08 EVENTS_STAGING 2b) 제단 돌을 나르는 사람 손의 둥근 돌 — 종이 인형엔 돌 소품이 없어 여기서 따로 (화면만, 읽기만).
## 줍는 동안(숙임)은 발 앞 땅 위, 나르는 동안은 가슴 앞 손에, 제단 곁에서 숙여 내려놓는 동안은 다시 발 앞. 아이 돌은 작게
var _stones: Dictionary = {}         # 주민 id → MeshInstance3D
var _stone_root: Node3D
const STONE_R := 0.13
const STONE_R_CHILD := 0.085
static var _glow_m: ShaderMaterial


func _init(village: Village, t: JarTerrain) -> void:
	v = village
	terrain = t
	name = "Altar"


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_pile = Node3D.new()
	add_child(_pile)
	_glow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4.2, 4.2)
	q.orientation = PlaneMesh.FACE_Y
	_glow.mesh = q
	_glow.material_override = glow_mat().duplicate()     # 무리마다 따로 숨 쉼
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	_stage = stage_of(progress(), Awakening.altar_site(v) != null)       # 처음 그릴 때는 쿵 없이
	sync(0.0)


## 0 = 없음, 0~1 = 짓는 중, 1 = 다 지어짐
func progress() -> float:
	if v.altar_built:
		return 1.0
	var b := Awakening.altar_site(v)
	if b == null:
		return 0.0
	return clampf(b.prog / float(Balance.B[Awakening.ALTAR]["time"]), 0.0, 0.999)


## 지금 단계 (−1 없음 · 0~4 짓는 중 · 5 다 지어짐)
func stage() -> int:
	return _stage


func sync(dt: float) -> void:
	_t += dt
	var p := v.altar_pos
	var y := terrain.ground_y(p.x, p.y)
	for a in 6:                          # 비탈에서 뜨지 않게 (둘레의 가장 낮은 곳)
		y = minf(y, terrain.ground_y(p.x + cos(a * TAU / 6.0) * 1.2, p.y + sin(a * TAU / 6.0) * 1.2))
	position = Vector3(p.x, y, p.y)
	var f := progress()
	var site := Awakening.altar_site(v) != null
	var st := stage_of(f, site)
	var key := "%d|%d|%d" % [st, int(f * 40.0), v.altar_level]
	if key != _key:
		var was := _stage
		_key = key
		_stage = st
		_rebuild(st, f)
		if was >= -1 and st > was and st >= 1:          # 단계가 바뀌면 쿵 (+ 흙먼지)
			_thud()
	_tick_dust(dt)
	_sync_stones()
	var items := v.altar_items() if v.altar_built else {}
	var pk := str(items)
	if pk != _pile_key:
		_pile_key = pk
		_rebuild_pile(items)
	var waiting := not items.is_empty()
	_glow.visible = waiting
	if waiting:                          # 따뜻한 빛이 천천히 숨 쉼
		var k := 0.75 + 0.25 * sin(_t * 1.6)
		_glow.scale = Vector3.ONE * (0.92 + 0.08 * k)
		_glow.position.y = FLOOR_H + DRUM_H + 0.02
		(_glow.material_override as ShaderMaterial).set_shader_parameter("strength", k)


func _clear(n: Node3D) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _cyl(parent: Node3D, r: float, h: float, y: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r * 0.97
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 16
	m.rings = 1
	mi.mesh = m
	mi.material_override = Toon.mat(c)
	mi.position = Vector3(0, y + h * 0.5, 0)
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ResidentModel.box_of(size)
	mi.material_override = Toon.mat(c)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


## 둥근 조약돌 (납작한 공)
func _peb(parent: Node3D, pos: Vector3, s: Vector3, c: Color, rot := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 9
	m.rings = 5
	mi.mesh = m
	mi.material_override = Toon.mat(c)
	mi.scale = s
	mi.position = pos
	mi.rotation.y = rot
	parent.add_child(mi)
	return mi


static func _h(i: int, k: float) -> float:
	return fposmod(sin(i * 12.9898 + k * 78.233) * 43758.5453, 1.0)


func _stone_c(i: int) -> Color:
	var k := _h(i, 3.0)
	return Style.STONE.lerp(Style.STONE_DARK, k * 0.8).lerp(Color("c9b9a0"), 0.25 if i % 4 == 0 else 0.0)


## 단계: −1 없음 · 0~4 그 단계를 짓는 중 (앞 단계는 다 됨) · 5 다 지어짐
static func stage_of(f: float, site: bool) -> int:
	if f <= 0.0 and not site:
		return -1
	if f >= 1.0:
		return STAGES
	return clampi(int(f * STAGES), 0, STAGES - 1)


## 앞쪽 (기본 카메라 쪽 — 계단·그릇이 보이게)
func _front() -> float:
	return deg_to_rad(JarCamera.BASE_YAW_DEG)


func _rebuild(st: int, f: float) -> void:
	_clear(_body)
	if st < 0:
		return
	var part := clampf(f * STAGES - float(st), 0.0, 1.0) if st < STAGES else 1.0     # 짓는 중인 단계의 진행
	var fr := _front()
	var fwd := Vector3(sin(fr), 0.0, cos(fr))
	var side := Vector3(fwd.z, 0.0, -fwd.x)
	var base := FLOOR_H + DRUM_H
	# ① 둥글게 깐 조약돌 바닥 (가운데 진흙 + 가장자리 조약돌 고리)
	var n := PEBBLES if st >= 1 else maxi(3, int(PEBBLES * part))
	for i in n:
		var a := TAU * i / PEBBLES + 0.13
		var sz := 0.2 + _h(i, 1.0) * 0.12
		_peb(_body, Vector3(cos(a) * RING_R, sz * 0.22, sin(a) * RING_R), Vector3(sz * 1.3, sz * 0.62, sz), _stone_c(i), a)
	if st >= 1 or part > 0.5:
		_cyl(_body, FLOOR_R - 0.1, FLOOR_H, 0.0, CLAY_DARK)
	# ② 진흙을 바른 낮은 단 (둘레에 박힌 조약돌)
	if st >= 1:
		var dh := DRUM_H * (maxf(0.25, part) if st == 1 else 1.0)
		_cyl(_body, DRUM_R, dh, FLOOR_H, CLAY)
		var m2 := 14 if st >= 2 else maxi(2, int(14 * part))
		for i in m2:
			var a := TAU * i / 14.0
			_peb(_body, Vector3(cos(a) * DRUM_R, FLOOR_H + dh * 0.5, sin(a) * DRUM_R), Vector3(0.22, minf(0.18, dh), 0.18), _stone_c(i + 40), a)
	# ③ 조약돌 기둥 위 평평한 윗돌 + 도토리 깍정이 그릇
	if st >= 2:
		var ph := PED_H * (clampf(0.3 + part * 1.4, 0.0, 1.0) if st == 2 else 1.0)
		var layers := maxi(1, int(round(ph / 0.14)))
		for L in layers:
			for i in 5:
				var a := TAU * i / 5.0 + L * 0.6
				_peb(_body, Vector3(cos(a) * 0.22, base + 0.07 + L * 0.14, sin(a) * 0.22), Vector3(0.3, 0.16, 0.26), _stone_c(i + L * 7 + 60), a)
			_peb(_body, Vector3(0, base + 0.07 + L * 0.14, 0), Vector3(0.36, 0.17, 0.34), _stone_c(L + 80))
		if st > 2 or part > 0.6:
			var slab := _cyl(_body, SLAB_R, SLAB_H, base + PED_H, Style.STONE.lerp(Color("d7d2c4"), 0.35))
			slab.scale = Vector3(1.0, 1.0, 0.82)
			slab.rotation.y = fr
			if st > 2 or part > 0.85:
				var top := base + PED_H + SLAB_H
				_peb(_body, Vector3(0, top + 0.035, 0), Vector3(0.5, 0.09, 0.5), ACORN)       # 도토리 깍정이 그릇
				for i in 10:                                  # 깍정이의 비늘 무늬 (테두리)
					var a := TAU * i / 10.0
					_peb(_body, Vector3(cos(a) * 0.23, top + 0.06, sin(a) * 0.23), Vector3(0.09, 0.06, 0.09), ACORN_DARK, a)
	# ④ 앞의 작은 돌계단 · 양옆 작은 조약돌 기둥
	if st >= 3:
		var k4 := part if st == 3 else 1.0
		for j in 2:
			if k4 > 0.1 + j * 0.25:
				var sp := fwd * (DRUM_R + 0.2 + j * 0.26) + Vector3(0, 0.1 - j * 0.04, 0)
				_peb(_body, sp, Vector3(0.66 - j * 0.08, 0.16 - j * 0.04, 0.3), _stone_c(90 + j), fr)
		var ph2 := 0.75 * clampf((k4 - 0.3) / 0.7, 0.0, 1.0)
		for sgn: float in [-1.0, 1.0]:
			var cpos := side * sgn * (SLAB_R + 0.14) + fwd * 0.05
			var cnt := int(ph2 / 0.15)
			for L in cnt:
				_peb(_body, cpos + Vector3(0, base + 0.08 + L * 0.15, 0), Vector3(0.24 - L * 0.012, 0.16, 0.22), _stone_c(100 + L + int(sgn * 3)), L * 0.9)
			if cnt >= 5:
				_peb(_body, cpos + Vector3(0, base + 0.08 + cnt * 0.15, 0), Vector3(0.14, 0.13, 0.14), Color("eee8da"))      # 꼭대기 흰 조약돌
	# ⑤ 둘레에 꽃잎·이끼
	if st >= 4:
		var k5 := part if st == 4 else 1.0
		for i in int(16 * k5):
			var a := TAU * (i + 0.5) / 16.0 + 0.2
			var r := FLOOR_R * (0.78 + _h(i, 5.0) * 0.14)
			_peb(_body, Vector3(cos(a) * r, FLOOR_H + 0.03, sin(a) * r), Vector3(0.36, 0.11, 0.3), MOSS_C.lerp(Color("5c8a3d"), _h(i, 6.0) * 0.6), a)
		for i in int(12 * k5):
			var a := TAU * i / 12.0 + 0.5
			var r := FLOOR_R * (0.66 + _h(i, 7.0) * 0.3)
			var pc: Color = PETALS[i % PETALS.size()]
			var pt := _peb(_body, Vector3(cos(a) * r, FLOOR_H + 0.08, sin(a) * r), Vector3(0.28, 0.045, 0.16), pc, a + 0.8)
			pt.rotation.x = 0.25
		if st >= STAGES:                               # 꽃 한 송이 (윗돌 가장자리)
			var fp := side * (SLAB_R * 0.55) - fwd * 0.25 + Vector3(0, base + PED_H + SLAB_H + 0.04, 0)
			for i in 5:
				var a := TAU * i / 5.0
				_peb(_body, fp + Vector3(cos(a) * 0.08, 0.0, sin(a) * 0.08), Vector3(0.12, 0.03, 0.08), PETALS[0], a)
			_peb(_body, fp + Vector3(0, 0.02, 0), Vector3(0.06, 0.05, 0.06), PETALS[1])
	# 넓힌 제단 (altar_level)
	if st >= STAGES and v.altar_level >= 1:
		for i in 18:
			var a := TAU * i / 18.0
			_peb(_body, Vector3(cos(a) * (RING_R + 0.34), 0.06, sin(a) * (RING_R + 0.34)), Vector3(0.22, 0.12, 0.18), _stone_c(i + 140), a)
	if st >= STAGES and v.altar_level >= 2:            # 기둥에 꽃 화환
		for sgn: float in [-1.0, 1.0]:
			var cpos := side * sgn * (SLAB_R + 0.14) + fwd * 0.05 + Vector3(0, base + 0.55, 0)
			for i in 7:
				var a := TAU * i / 7.0
				_peb(_body, cpos + Vector3(cos(a) * 0.17, sin(i * 1.3) * 0.03, sin(a) * 0.17), Vector3(0.09, 0.07, 0.09), PETALS[i % PETALS.size()])
	if st >= STAGES and v.altar_level >= 3:            # 잎 지붕 작은 사당 (풀대 두 개 위 큰 잎 한 장)
		for sgn: float in [-1.0, 1.0]:
			var tw := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.04
			cm.bottom_radius = 0.05
			cm.height = 1.5
			cm.radial_segments = 5
			tw.mesh = cm
			tw.material_override = Toon.mat(Color("8f7a4a"))
			tw.position = side * sgn * (SLAB_R + 0.14) - fwd * 0.35 + Vector3(0, base + 0.75, 0)
			_body.add_child(tw)
		var leaf := _peb(_body, -fwd * 0.2 + Vector3(0, base + 1.55, 0), Vector3(2.0, 0.14, 1.3), Color("6f9f4c"), fr + PI * 0.5)
		leaf.rotation.z = 0.12
	if st < STAGES:                      # 둘레에 주워 온 돌무더기 + 진흙 덩이 (단계마다 줄어듦)
		var left := STAGES - st
		for i in left * 3:
			var a := 2.2 + i * 0.37
			var r := RING_R + 0.6 + (i % 2) * 0.22
			_peb(_body, Vector3(cos(a) * r, 0.1 + (i / 5) * 0.14, sin(a) * r), Vector3(0.26, 0.18, 0.22), _stone_c(i + 200), i * 0.7)
		if st <= 2:
			_peb(_body, Vector3(cos(1.6) * (RING_R + 0.75), 0.06, sin(1.6) * (RING_R + 0.75)), Vector3(0.6, 0.16, 0.5), CLAY)


## 제단 돌을 줍고·나르고·내려놓는 사람의 돌 (위 _stones 설명). 사람 그림은 VillageView.residents (부모)
func _sync_stones() -> void:
	var vv := get_parent()
	var models: Dictionary = vv.get("residents") if vv != null and vv.get("residents") is Dictionary else {}
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var toward := Vector3(0, 0, 1)
	if cam != null:
		var bz := cam.global_transform.basis.z
		toward = Vector3(bz.x, 0.0, bz.z).normalized() if Vector2(bz.x, bz.z).length() > 0.01 else Vector3(0, 0, 1)
	var site := Awakening.altar_site(v) != null and not v.altar_built
	var seen := {}
	for r in v.people:
		var picking := site and r.anim == "gather" and r.action == "build"
		if r.carry != "돌" and not picking:
			continue
		var m: Node3D = models.get(r.id)
		if m == null or not m.visible:
			continue
		if _stone_root == null:
			_stone_root = Node3D.new()
			_stone_root.top_level = true
			add_child(_stone_root)
		var st: MeshInstance3D = _stones.get(r.id)
		if st == null:
			st = MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.5
			sm.height = 1.0
			sm.radial_segments = 9
			sm.rings = 5
			st.mesh = sm
			st.material_override = Toon.mat(_stone_c(r.id))
			st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_stone_root.add_child(st)
			_stones[r.id] = st
		seen[r.id] = true
		var rad := STONE_R_CHILD if r.is_child() else STONE_R
		st.scale = Vector3(rad * 2.3, rad * 1.6, rad * 2.0)
		var feet := m.global_position
		if r.anim == "gather":           # 숙여 줍기·내려놓기: 발 앞 땅 위
			st.global_position = feet + toward * 0.14 + Vector3(0, rad * 0.75, 0)
		else:                            # 안고 나름: 가슴 앞 손에
			st.global_position = feet + toward * 0.09 + Vector3(0, CutoutResident.DOLL_H * m.scale.y * 0.42, 0)
		st.visible = true
	for id: int in _stones.keys():
		if not seen.has(id):
			(_stones[id] as Node3D).queue_free()
			_stones.erase(id)


## 지금 손에 그린 돌 수 (시험)
func carried_stones() -> int:
	return _stones.size()


## 단계가 바뀜: 쿵 + 흙먼지 고리
func _thud() -> void:
	thuds += 1
	GameAudio.fx("drop_thud", "Village", -5.0)
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.7
	tm.outer_radius = 1.0
	tm.rings = 14
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.86, 0.78, 0.62, 0.55)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.15
	mi.scale = Vector3(1, 0.4, 1)
	add_child(mi)
	_dust.append([mi, 0.7])


func _tick_dust(dt: float) -> void:
	for i in range(_dust.size() - 1, -1, -1):
		var d: Array = _dust[i]
		d[1] = float(d[1]) - dt
		var mi: MeshInstance3D = d[0]
		var u := 1.0 - clampf(float(d[1]) / 0.7, 0.0, 1.0)
		var sc := 1.0 + u * 1.4
		mi.scale = Vector3(sc, 0.4 * sc, sc)
		mi.position.y = 0.15 + u * 0.35
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.55 * (1.0 - u)
		if float(d[1]) <= 0.0:
			mi.queue_free()
			_dust.remove_at(i)


## 제물 더미: 물건마다 색 상자 몇 개 (개수만큼, 많으면 8개까지) — 윗돌 위 그릇 둘레에서 앞쪽 단으로 흘러넘치게
func _rebuild_pile(items: Dictionary) -> void:
	_clear(_pile)
	if items.is_empty():
		return
	var top := TOP_Y
	var i := 0
	for item: String in items:
		var c: Color = Style.ITEM_COLORS.get(item, Style.GRAIN)
		var cnt := clampi(int(items[item]) / 2 + 1, 1, 8)
		for j in cnt:
			var k := i * 8 + j
			var on_top := k < 6
			var pos := Vector3((k % 3 - 1) * 0.24, top + 0.1 + (k / 3) * 0.13, -0.05 + (k % 2) * 0.12) if on_top \
				else Vector3(-0.9 + (k % 4) * 0.5, FLOOR_H + DRUM_H + 0.08 + ((k - 6) / 4) * 0.15, 0.6 + (k % 2) * 0.12)
			_box(_pile, Vector3(0.24, 0.14, 0.2), pos, c, k * 0.6)
		i += 1


static func glow_mat() -> ShaderMaterial:
	if _glow_m == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 1.0;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = floor(clamp(1.0 - d, 0.0, 1.0) * 5.0) / 5.0;
	ALBEDO = vec3(1.0, 0.78, 0.38);
	ALPHA = a * 0.6 * strength;
}"""
		_glow_m = ShaderMaterial.new()
		_glow_m.shader = sh
	return _glow_m
