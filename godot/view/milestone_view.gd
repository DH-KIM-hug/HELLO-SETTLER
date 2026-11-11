## 자람의 보상 — 영구 장식(빵 간판 · 마을 이름 표지판)과 잔치 춤 (docs/PROGRESSION.md 4.5 · ROADMAP Q9 첫 묶음).
## 화면만 (ADR-0001): 병의 고비 기록(sim/milestones.gd)과 주민의 하는 일을 읽기만 한다. 새 건물 종류 없음 · 시뮬레이션 효과 없음 · 난수 없음.
##   - 빵 간판: 첫 빵을 넘은 병 — 다 지은 화덕(빵집) 앞 오른쪽에 (기본 보기에서 카메라 쪽)
##   - 마을 이름 표지판: 식구 열둘을 넘은 병 — 마을 어귀 (고비를 넘을 때 적어 둔 자리 — 꽃·길·건물·무덤을 피한 곳, 나중에 건물이 서면 그 옆 빈자리).
##     그 둘레·앞의 키 큰 꽃 그림은 낮추고 발치의 잔것은 비운다 (VillageView.sign_spot — 무덤과 같은 방식)
##   - 잔치 춤: 잔치 중(Milestones.feast_on) 모닥불 둘레에서 "play" 몸짓인 사람이 폴짝이며 좌우로 흔들림 (인형 통째 — 새 그림 없음)
## 그림은 자기 것(art/milestones/*.png — tools/milestone_signs.py), 카드는 Flora2D의 그림 판 셰이더를 그대로 쓴다 (늘 카메라를 보고, 아래 끝이 땅에).
## 멀리서도 읽히게: 화면에서 SIGN_PX보다 작아지면 그만큼 키운다 (K_MAX까지 — GraveView.stone_k와 같은 생각).
class_name MilestoneView
extends Node3D

const TEX := {"bread": "res://art/milestones/bread_sign.png", "pop12": "res://art/milestones/village_sign.png"}
const SIZE := {"bread": Vector2(0.88, 1.2), "pop12": Vector2(1.3, 1.24)}     # 그림 크기 (칸 — 어른 키 0.88)
const SIGN_PX := 34.0                 # 장식이 화면에서 적어도 이만큼(세로 점)은 보이게
const K_MAX := 1.7                    # 멀리서 키우는 상한
const CHECK := 0.5                    # 자리를 다시 세는 간격 (현실 초)
const NODE_NAME := "MilestoneView"
const DANCE_R := 4.5                  # 모닥불에서 이 안에 선 사람만 춤춘다 (걸어오는 중엔 아님)
const HOP := 0.11                     # 폴짝 높이 (칸)
const SWAY := 0.11                    # 좌우 흔들림 (라디안)
const BEAT := 5.2                     # 춤 빠르기

var view: VillageView
var _signs: Dictionary = {}           # 고비 id → MeshInstance3D
var _mats: Dictionary = {}            # 고비 id → ShaderMaterial
var _dancing: Dictionary = {}         # 주민 id → true (여기서 얹은 몸짓 — 끝나면 되돌림)
var _since := 1.0e9
var _k := 1.0
var _t := 0.0


## 그 마을 화면의 것 (없으면 만듦)
static func of(vw: VillageView) -> MilestoneView:
	if vw == null or not is_instance_valid(vw):
		return null
	var m: MilestoneView = vw.get_node_or_null(NODE_NAME)
	if m == null:
		m = MilestoneView.new()
		m.name = NODE_NAME
		m.view = vw
		vw.add_child(m)
	return m


## 기본 보기에서 화면 오른쪽 · 카메라 쪽 (마을 데이터 좌표)
static func _right() -> Vector2:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector2(cos(yaw), -sin(yaw))


static func _front() -> Vector2:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector2(sin(yaw), cos(yaw))


## 지금 서 있어야 할 장식: 고비 id → 자리 (마을 데이터 좌표). 고비를 넘지 않았으면 없음. 시뮬레이션을 바꾸지 않는다.
static func wanted(q: Village) -> Dictionary:
	var out := {}
	if q == null or not q.owns_water:
		return out
	if Milestones.is_passed(q, "bread"):
		var b := Milestones.oven(q)
		if b != null:
			out["bread"] = Vector2(b.x, b.y) + _right() * (b.size() * 1.25 + 0.45) + _front() * (b.size() * 1.2 + 0.15)
	if Milestones.is_passed(q, "pop12"):
		var rec: Dictionary = (q.milestones["passed"] as Dictionary)["pop12"]
		var p := Vector2(float(rec.get("x", 0.0)), float(rec.get("y", 0.0)))
		if not rec.has("x") or not Milestones.spot_free(q, p):
			p = Milestones.edge_spot(q)                 # 옛 저장(자리 없음) · 그 자리에 건물이 선 뒤
		out["pop12"] = p
	return out


## 멀리서 키우는 몫 (ppu = 한 칸이 화면 점 몇 개인가). 0.05 걸음
static func sign_k(ppu: float, h: float) -> float:
	return snappedf(clampf(SIGN_PX / (h * maxf(ppu, 1.0)), 1.0, K_MAX), 0.05)


func _process(dt: float) -> void:
	if view == null or not is_instance_valid(view) or view.v == null:
		return
	_t += dt
	_since += dt
	if _since >= CHECK:
		_since = 0.0
		refresh()
	_dance(view.v)


## 장식과 잔치 몸짓을 지금 기록에 맞춤 (시험·캡처가 바로 부를 수 있다).
## VillageView.sync(…, force)가 부른다 — 큰 시간 건너뛰기(비운 뒤 돌아옴·빠른 흐름) 바로 뒤 첫 화면부터 맞게.
func refresh() -> void:
	var q: Village = view.v
	if q == null:
		return
	var want := wanted(q)
	view.sign_spot = want.get("pop12", Vector2.INF)     # 화면이 그 둘레의 키 큰 꽃 그림을 낮추고 잔것을 비운다 (VillageView._grave_scale · _decor_items)
	for id: String in _signs.keys():
		if not want.has(id):
			(_signs[id] as Node).queue_free()
			_signs.erase(id)
	var ppu := _ppu()
	for id: String in want:
		var mi: MeshInstance3D = _signs.get(id)
		if mi == null:
			mi = _make(id)
			_signs[id] = mi
		var p: Vector2 = want[id]
		mi.position = Vector3(p.x, view.gy(p.x, p.y), p.y)
		var sz: Vector2 = SIZE[id]
		var k := sign_k(ppu, sz.y)
		mi.set_instance_shader_parameter("k", k)
		var r := maxf(sz.x, sz.y) * 1.6 * k
		mi.custom_aabb = AABB(Vector3(-r, -r, -r), Vector3(r * 2.0, r * 2.0, r * 2.0))
	_dance(q)


func _make(id: String) -> MeshInstance3D:
	var mat: ShaderMaterial = _mats.get(id)
	if mat == null:
		var sz: Vector2 = SIZE[id]
		mat = ShaderMaterial.new()
		mat.shader = Flora2D.CARD_SHADER
		mat.set_shader_parameter("tex", load(String(TEX[id])))
		mat.set_shader_parameter("uv_rect", Vector4(0.0, 0.0, 1.0, 1.0))
		mat.set_shader_parameter("geo", Vector4(sz.x, sz.y, 0.0, 0.0))
		mat.set_shader_parameter("ex", Vector4(0.0, 0.0, 0.0, 0.0))
		_mats[id] = mat
	var mi := MeshInstance3D.new()
	mi.name = "Sign_" + id
	mi.mesh = Flora2D.quad()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("k", 1.0)
	mi.set_instance_shader_parameter("flip", 1.0)
	mi.set_instance_shader_parameter("lift", 0.0)
	mi.set_instance_shader_parameter("phase", 0.0)
	mi.set_instance_shader_parameter("tint", Color(1, 1, 1))
	add_child(mi)
	return mi


## (화면 · 시험) 지금 서 있는 장식의 노드 (없으면 null)
func sign_node(id: String) -> MeshInstance3D:
	return _signs.get(id)


## 지금 화면 확대 (GraveView._ppu와 같은 셈). 카메라가 없으면 (시험) 마을 기본 확대
func _ppu() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL or cam.size <= 0.0:
		return float(JarCamera.ZOOM_PPU[1])
	return float(get_viewport().get_visible_rect().size.y) / cam.size


## 잔치 춤: 모닥불 둘레에서 "play" 몸짓인 잔치 손님 — 폴짝 + 좌우 흔들림. 잔치가 끝나거나 자리를 뜨면 되돌림
func _dance(q: Village) -> void:
	var on := Milestones.feast_on(q) and not view.fast
	if not on and _dancing.is_empty():
		return
	var live := {}
	if on:
		for p in q.people:
			if p.action != "festival" or p.anim != "play" or Vector2(p.x, p.y).distance_to(q.fire) > DANCE_R:
				continue
			var cm := view.residents.get(p.id) as CutoutResident
			if cm == null or not is_instance_valid(cm):
				continue
			live[p.id] = true
			var ph := _t * BEAT + float(p.id) * 1.7
			var hop := absf(sin(ph))
			cm.set_body_lift(HOP * hop)
			cm.set_body_warp(1.0 + 0.05 * hop, 1.0 - 0.03 * hop, SWAY * sin(ph * 0.5))
	for rid: int in _dancing.keys():
		if live.has(rid):
			continue
		var cm := view.residents.get(rid) as CutoutResident
		if cm != null and is_instance_valid(cm):
			cm.set_body_lift()
			cm.set_body_warp()
		_dancing.erase(rid)
	for rid: int in live:
		_dancing[rid] = true


## (화면 · 시험) 지금 춤추는 사람 수
func dancers() -> int:
	return _dancing.size()
