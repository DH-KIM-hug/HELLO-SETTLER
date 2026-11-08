## 땅 흔들림 연출 (뜨거운 별 — docs/BALANCE.md A28b · OPENING v4.0-6, 사건 &"ground_tremor" — sim/core_warmth.gd, ADR-0001 화면은 읽기만).
## 한 번 흔들리면 (약 2초): 카메라가 짧게 떨림 (JarCamera.shake — 움직임 줄이기 설정이 있으면 안 떪, 마을이 화면 곁일 때만) ·
## 모닥불·집 몇 곳 발치에서 흙먼지가 피어오름 · 마당 소품(단지·꽃·울타리 묶음)이 살짝 달그락 · 낮은 '쿵' 소리 (+ 진동 설정이 켜져 있으면 짧은 진동).
## 먹을 것이 쏟아졌으면 (v.lost > 0) 마당 단지 곁에 깨진 항아리 조각 + 쏟아진 것 자국이 한동안 (SHARD_LIFE 병 시간) 남는다.
## 가볍게: 먼지는 MultiMesh 하나 (조각 18개 · 흔들리는 동안만 변환을 고침 — 그리기 1번), 조각은 작은 상자 몇 개. 저장 안 함 (사건 줄처럼).
class_name TremorFx
extends Node3D

const DUR := 1.9                      # 먼지가 피고 사라지는 시간 (현실 초)
const WOBBLE_DUR := 1.3               # 마당 소품 달그락 (현실 초)
const WOBBLE := 0.05                  # 달그락 폭 (칸)
const SPOTS := 6                      # 먼지가 이는 자리 (모닥불 + 가까운 건물)
const PER_SPOT := 3                   # 자리마다 먼지 덩이
const PUFF_LIFE := 1.35               # 덩이 하나 (현실 초)
const PUFF_SIZE := 2.1                # 덩이 다 피었을 때 지름 (칸)
const DUST := Color("b49b74")         # 마른 흙먼지 (흙길 색 쪽 — 연한 풀밭 위에서도 보이게)
const SHAKE_AMP := 0.006              # 화면 세로의 몫
const SHAKE_DUR := 0.95
const RECENT := 600.0                 # 이보다 오래된 사건(병 초)은 연출하지 않음 (보통 빠르기 ≈ 2초)
const SHARD_LIFE := 0.5 * 86400.0     # 깨진 조각이 남는 병 시간 (반나절)
const SHARD := Color("b8734a")        # 옹기 조각 (pf_yard_jars 단지 색 쪽)
const SPILL := {"밀가루": Color("f1ead8"), "빵": Color("c48a4c"), "버섯": Color("b99a74"), "밀": Color("e2c46a")}

var v: Village
var vv: VillageView
var _ev_cur := 0
var _t := -1.0                       # 흔들림이 시작된 뒤 (현실 초), −1 = 쉼
var _puffs: Array = []               # [{at: Vector3, delay, size, drift: Vector3}]
var _mm: MultiMeshInstance3D
var _shards: Node3D
var _shard_t := -1.0e9               # 조각이 생긴 병 시각
var n_tremors := 0                   # 연출한 흔들림 (시험·캡처용)
static var _dust_m: ShaderMaterial


func _init(village: Village, view: VillageView) -> void:
	v = village
	vv = view
	name = "TremorFx"


func _ready() -> void:
	_ev_cur = v.events.serial            # 지난 사건은 연출하지 않음


func _gy(x: float, z: float) -> float:
	return vv.gy(x, z) if vv != null and vv.terrain != null else 0.0


func playing() -> bool:
	return _t >= 0.0


## 마당 소품 달그락 — VillageView가 _yard 노드 자리에 더한다 (흔들리지 않으면 0)
func wobble() -> Vector3:
	if _t < 0.0 or _t > WOBBLE_DUR:
		return Vector3.ZERO
	var k := (1.0 - _t / WOBBLE_DUR) * WOBBLE
	return Vector3(sin(_t * 53.0) * k, 0.0, sin(_t * 41.0 + 1.1) * k * 0.8)


func sync(dt: float) -> void:
	for e: Dictionary in v.events.since(_ev_cur):
		if e["kind"] == &"ground_tremor" and int(e["village"]) == v.sid and float(e["t"]) >= v.t - RECENT:
			var d: Dictionary = e["v"] if e["v"] is Dictionary else {}
			start(float(d.get("lost", 0.0)), String(d.get("pot", "")))
	_ev_cur = v.events.serial
	if _shards != null and v.t - _shard_t > SHARD_LIFE:
		_shards.queue_free()
		_shards = null
	elif _shards != null:
		var left := 1.0 - (v.t - _shard_t) / SHARD_LIFE      # 끝 무렵 작아지며 사라짐 (주민이 치움)
		_shards.scale = Vector3.ONE * clampf(left * 5.0, 0.0, 1.0)
	if _t < 0.0:
		return
	_t += dt
	_update_puffs()
	if _t > DUR + 0.2:
		_stop()


## 흔들림 하나 (사건 · 시험·캡처가 바로 부를 수 있음)
func start(lost := 0.0, pot := "") -> void:
	n_tremors += 1
	_t = 0.0
	_build_puffs()
	if lost > 0.0:
		_place_shards(pot)
	var jc := _camera()
	if jc != null:
		jc.shake(SHAKE_AMP, SHAKE_DUR)
		if GameSettings.get_current().vibration and OS.has_feature("mobile"):
			Input.vibrate_handheld(260, 0.45)
	GameAudio.fx("drop_thud", "Village", -3.0, v.center, 0.55)
	GameAudio.fx("soil_pour", "Village", -12.0, v.center, 1.25)
	if lost > 0.0:
		GameAudio.fx("glass_tap_hard", "Village", -10.0, v.center, 0.62)


func _stop() -> void:
	_t = -1.0
	if _mm != null:
		_mm.visible = false


## 이 마을이 지금 화면 곁인가 → 그 카메라 (병 밖 방에서는 떨지 않음)
func _camera() -> JarCamera:
	if not is_inside_tree():
		return null
	var cam := get_viewport().get_camera_3d()
	var jc := cam.get_parent() as JarCamera if cam != null else null
	if jc == null or jc.beyond > 0.3:
		return null
	if Vector2(jc.target.x, jc.target.z).distance_to(v.center) > jc.view_radius() + 10.0:
		return null
	return jc


# ───────────────────────── 먼지 ─────────────────────────
func _spots() -> Array:
	var out: Array = [Vector2(v.fire.x, v.fire.y)]
	var bs: Array = v.buildings.filter(func(b: Building) -> bool: return b.built)
	bs.sort_custom(func(a: Building, b: Building) -> bool:
		return Vector2(a.x, a.y).distance_squared_to(v.fire) < Vector2(b.x, b.y).distance_squared_to(v.fire))
	for b: Building in bs:
		if out.size() >= SPOTS:
			break
		var m := 1.0 if b.id % 2 == 0 else -1.0
		out.append(Vector2(b.x + 1.1 * m * b.size(), b.y + 0.9 * b.size()))     # 집 앞 귀퉁이 (마당 쪽)
	var i := 0
	while out.size() < SPOTS:                      # 집이 적으면 모닥불 둘레 빈 땅
		var a := 1.3 + i * 2.1
		out.append(Vector2(v.fire.x, v.fire.y) + Vector2(cos(a), sin(a)) * (3.0 + i))
		i += 1
	return out


func _build_puffs() -> void:
	_puffs.clear()
	var sp := _spots()
	for i in sp.size():
		var p: Vector2 = sp[i]
		for j in PER_SPOT:
			var a := (i * PER_SPOT + j) * 2.39996
			var off := Vector2(cos(a), sin(a)) * (0.25 + 0.3 * j)
			var x := p.x + off.x
			var z := p.y + off.y
			_puffs.append({"at": Vector3(x, _gy(x, z) + 0.15, z), "delay": i * 0.07 + j * 0.16,
				"size": PUFF_SIZE * (0.8 + 0.25 * j), "drift": Vector3(off.x, 0.0, off.y) * 0.6})
	if _mm == null:
		_mm = MultiMeshInstance3D.new()
		_mm.name = "dust"
		_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mm.material_override = dust_mat()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		mm.mesh = q
		_mm.multimesh = mm
		add_child(_mm)
	_mm.multimesh.instance_count = _puffs.size()
	_mm.visible = true
	_update_puffs()


func _update_puffs() -> void:
	if _mm == null:
		return
	var mm := _mm.multimesh
	var night := Style.night_amount(v.hour_now())
	dust_mat().set_shader_parameter("night_amount", night)
	var aabb := AABB()
	for i in _puffs.size():
		var p: Dictionary = _puffs[i]
		var u := clampf((_t - float(p["delay"])) / PUFF_LIFE, 0.0, 1.0)
		var on := _t >= float(p["delay"]) and u < 1.0
		var grow := 1.0 - pow(1.0 - u, 2.5)
		var s := float(p["size"]) * (0.45 + 0.55 * grow) if on else 0.0001
		var pos: Vector3 = (p["at"] as Vector3) + (p["drift"] as Vector3) * grow + Vector3(0, 0.25 + 0.75 * grow, 0)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), pos))
		var a := smoothstep(0.0, 0.12, u) * pow(1.0 - u, 1.4) * 0.8 if on else 0.0
		mm.set_instance_color(i, Color(DUST, a))
		aabb = AABB(pos, Vector3.ZERO) if i == 0 else aabb.expand(pos)
	_mm.custom_aabb = aabb.grow(PUFF_SIZE * 1.5)


## 흙먼지 덩이: 화면을 향한 판 · 둥글고 가장자리가 울퉁불퉁한 덩어리 (셀 채색처럼 단계 둘) · 밤엔 화면 셰이더와 같은 남색
## (반투명은 outline_post 뒤에 그려지므로 밤 색은 night_amount로 따로 — render/mist.gdshader와 같은 값)
static func dust_mat() -> ShaderMaterial:
	if _dust_m == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float night_amount = 0.0;
uniform vec3 night_mul : source_color = vec3(0.3, 0.37, 0.6);
uniform vec3 night_add : source_color = vec3(0.01, 0.02, 0.05);
varying float seed;
void vertex() {
	seed = fract(MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.61);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 d = UV - 0.5;
	float ang = atan(d.y, d.x);
	float r = length(d) * 2.0;
	float edge = 0.78 + 0.1 * sin(ang * 5.0 + seed * 20.0) + 0.06 * sin(ang * 9.0 - seed * 13.0);
	float body = 1.0 - smoothstep(edge - 0.06, edge, r);
	float core = 1.0 - smoothstep(edge * 0.55 - 0.05, edge * 0.55, length(d - vec2(-0.08, -0.1)) * 2.0);
	vec3 c = COLOR.rgb * (0.88 + 0.22 * core);
	c = mix(c, c * night_mul + night_add, night_amount);
	ALBEDO = c;
	ALPHA = body * COLOR.a;
}"""
		_dust_m = ShaderMaterial.new()
		_dust_m.shader = sh
	return _dust_m


# ───────────────────────── 깨진 항아리 ─────────────────────────
## 마당 단지 곁 (창고 → 집 순) — 없으면 모닥불 곁
func pot_spot() -> Vector3:
	var best_id := -1
	var best_rank := 9
	for id: int in vv._yard_xf:
		var b := v.bld(id)
		var rank := 0 if b != null and b.type == "창고" else 1
		if rank < best_rank and vv._blds.has(id):
			for e: Array in vv._yard_xf[id]:
				if e[0] == VillageView.PF_JARS:
					best_rank = rank
					best_id = id
					break
	if best_id >= 0:
		var n: Node3D = vv._blds[best_id]
		for e: Array in vv._yard_xf[best_id]:
			if e[0] == VillageView.PF_JARS:
				var p: Vector3 = n.transform * ((e[1] as Transform3D).origin + Vector3(0.45, 0.0, 0.4))
				return Vector3(p.x, _gy(p.x, p.z), p.z)
	var f := Vector2(v.fire.x + 1.6, v.fire.y + 1.2)
	return Vector3(f.x, _gy(f.x, f.y), f.y)


func _place_shards(pot: String) -> void:
	if _shards != null:
		_shards.queue_free()
	_shards = Node3D.new()
	_shards.name = "shards"
	add_child(_shards)
	_shard_t = v.t
	var at := pot_spot()
	_shards.position = at
	var spill := MeshInstance3D.new()           # 쏟아진 것 — 납작한 둥근 자국
	var cy := CylinderMesh.new()
	cy.top_radius = 0.55
	cy.bottom_radius = 0.6
	cy.height = 0.03
	cy.radial_segments = 10
	cy.rings = 1
	spill.mesh = cy
	spill.material_override = Toon.mat(SPILL.get(pot, SPILL["밀"]))
	spill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spill.position = Vector3(0.08, 0.02, 0.05)
	spill.scale = Vector3(1.25, 1.0, 0.85)
	_shards.add_child(spill)
	for i in 6:                                   # 옹기 조각 — 굽은 조각 대신 납작한 상자 (작아서 충분), 하나는 바닥 쪽 큰 조각
		var mi := MeshInstance3D.new()
		var big := i == 0
		mi.mesh = ResidentModel.box_of(Vector3(0.38, 0.13, 0.3) if big else Vector3(0.24 - 0.018 * i, 0.06, 0.16))
		mi.material_override = Toon.mat(SHARD if i % 3 != 2 else SHARD.darkened(0.18))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := i * 2.39996 + 0.4
		var r := 0.0 if big else 0.3 + 0.12 * i
		mi.position = Vector3(cos(a) * r, 0.05, sin(a) * r)
		mi.rotation = Vector3(0.25 * sin(i * 1.7), a * 1.3, 0.3 * cos(i * 2.3))
		_shards.add_child(mi)


func has_shards() -> bool:
	return _shards != null
