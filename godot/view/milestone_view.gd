## 자람의 보상 — 영구 장식(빵 간판 · 마을 이름 표지판 · 문 앞 바람개비 · 키 재는 기둥 · 창고 문 위 햇밀 다발)과 잔치 춤 · 첫걸음마 손뼉 (docs/PROGRESSION.md 4.5 · ROADMAP Q9).
## 화면만 (ADR-0001): 병의 고비 기록(sim/milestones.gd)과 주민의 하는 일을 읽기만 한다. 새 건물 종류 없음 · 시뮬레이션 효과 없음 · 난수 없음.
##   - 빵 간판: 첫 빵을 넘은 병 — 다 지은 화덕(빵집) 앞 오른쪽에 (기본 보기에서 카메라 쪽)
##   - 마을 이름 표지판: 식구 열둘을 넘은 병 — 마을 어귀 (고비를 넘을 때 적어 둔 자리 — 꽃·길·건물·무덤을 피한 곳, 나중에 건물이 서면 그 옆 빈자리).
##     그 둘레·앞의 키 큰 꽃 그림은 낮추고 발치의 잔것은 비운다 (VillageView.sign_spot — 무덤과 같은 방식)
##   - 문 앞 작은 바람개비 (Q9 ⑦): 첫걸음마를 넘은 병 — 그 아기네 집 문 옆 요람 곁 (집이 없어졌으면 그때 적어 둔 자리). 날개가 돈다 (여섯 장면).
##     조용히 넘은 옛 저장은 어느 집인지 모르니 세우지 않는다.
##   - 키 재는 기둥 (Q9 ⑦): 마을에서 난 첫 아이가 어른이 된 병 — 모닥불 곁 (적어 둔 자리, 없거나 건물이 섰으면 다시 찾은 빈자리)
##   - 햇밀 다발 (Q9 ⑭): 첫 푸른 밀 고개를 넘긴 병 — 창고 문 위 (창고 그림의 문틀 높이에, 그림 바로 앞 — 카메라가 돌아도 늘 보이는 쪽).
##     창고가 없으면 첫 밭 울타리 앞에, 밭도 없으면 적어 둔 자리(모닥불 곁)에 세워 둔다. 조용히 넘은 옛 저장도 창고에 건다 (자리를 알 수 있으니).
##   - 첫걸음마 손뼉 (Q9 ⑦): 아기의 첫걸음마를 보러 문 앞에 온 이웃(걸음의 "ms" 표시 — Milestones._gather)이 아기 쪽을 보고,
##     손뼉 걸음("play") 동안 콩콩 뛰며 한마디 (인형 통째 — 컷아웃 인형에는 손뼉 그림이 따로 없다)
##   - 잔치 춤: 잔치 중(Milestones.feast_on) 모닥불 둘레에서 "play" 몸짓인 사람이 폴짝이며 좌우로 흔들림 (인형 통째 — 새 그림 없음)
## 그림은 자기 것(art/milestones/*.png — tools/milestone_signs.py), 카드는 Flora2D의 그림 판 셰이더를 그대로 쓴다 (늘 카메라를 보고, 아래 끝이 땅에).
## 멀리서도 읽히게: 화면에서 SIGN_PX보다 작아지면 그만큼 키운다 (K_MAX까지 — GraveView.stone_k와 같은 생각).
class_name MilestoneView
extends Node3D

const TEX := {"bread": "res://art/milestones/bread_sign.png", "pop12": "res://art/milestones/village_sign.png",
	"steps": "res://art/milestones/pinwheel.png", "grown": "res://art/milestones/height_post.png", "green": "res://art/milestones/wheat_sheaf.png"}
const SIZE := {"bread": Vector2(0.88, 1.2), "pop12": Vector2(1.3, 1.24), "steps": Vector2(0.5, 0.79), "grown": Vector2(0.68, 1.32), "green": Vector2(0.56, 0.62)}     # 그림 크기 (칸 — 어른 키 0.88)
const FRAMES := {"steps": 6}          # 옆으로 이어 붙인 장면 수 (tools/milestone_signs.py PINWHEEL_FRAMES) — 차례로 넘겨 날개가 돈다
const FRAME_FPS := 7.0
const PIN_OFF := Vector2(1.55, 0.3)   # 바람개비: 집 앞 가장자리 가운데에서 (옆, 앞) — 문 옆 요람(CRADLE_OFF)의 화면 오른쪽 곁
const SHEAF_PIC := "storehouse"       # 햇밀 다발을 거는 건물 그림 (view/bld2d — 창고)
const SHEAF_AT := 1.93                # 그 그림의 밑변에서 문틀 위까지 (칸 — 그림 높이 3.91 가운데)
const SHEAF_FRONT := 0.06             # 건물 그림 판보다 이만큼 카메라 쪽에 (그림 위에 그려지게)
const SHEAF_3D := Vector2(0.8, 1.0)   # 그림 건물을 끈 화면(3D 창고): (건물 크기의 몇 배 앞, 땅에서 높이)
const SHEAF_FENCE := 0.3              # 밭 울타리 그림에서 이만큼 앞에 세운다
const CLAP_HOP := 0.07                # 손뼉 치며 콩콩 (칸)
const CLAP_BEAT := 10.5
const CLAP_SAY := ["짝짝짝!", "걸었다, 걸었어!", "잘한다!", "아이고, 장해라."]
const CLAP_SAY_SECS := 2.4
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
var _clapping: Dictionary = {}        # 주민 id → true (첫걸음마 손뼉 — 끝나면 되돌림)
var _hang := {}                       # 햇밀 다발을 거는 높이 {"h": 그림 높이(칸 — 카메라 기울기로 나눔), "lift": 땅에서 높이(칸)} (refresh가 적음)
var _hang_lift := -1.0                # 지금 넣어 둔 높이
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
	if Milestones.is_passed(q, "steps"):
		var rec: Dictionary = (q.milestones["passed"] as Dictionary)["steps"]
		if rec.has("x"):                                # 조용히 넘은 옛 저장은 어느 집인지 모른다 — 세우지 않음
			var hm := q.bld(int(rec.get("b", -1)))
			var base := Vector2(hm.x, hm.y + hm.size() * 0.5) if hm != null else Vector2(float(rec["x"]), float(rec["y"]))
			out["steps"] = base + PIN_OFF
	if Milestones.is_passed(q, "grown"):
		var rec: Dictionary = (q.milestones["passed"] as Dictionary)["grown"]
		var p := Vector2(float(rec.get("x", 0.0)), float(rec.get("y", 0.0)))
		if not rec.has("x") or not Milestones.post_ok(q, p):
			p = Milestones.post_spot(q)                 # 옛 저장(자리 없음) · 그 자리에 건물이 선 뒤
		out["grown"] = p
	if Milestones.is_passed(q, "green"):
		out["green"] = sheaf(q)["pos"]
	return out


## 햇밀 다발 자리: {"pos": 자리 (마을 데이터 좌표), "front": 카메라 쪽으로 당기는 거리, "h": 그림 위 높이 (칸 — 건물 그림처럼 카메라 기울기로
## 나누어 올림), "lift": 땅에서 높이 (칸)}. 적어 둔 건물이 아직 있으면 거기 (없어졌거나 옛 저장이면 지금의 창고 → 첫 밭), 아무것도 없으면 적어 둔 자리
## (모닥불 곁) 땅 위에. 시뮬레이션을 바꾸지 않는다.
static func sheaf(q: Village) -> Dictionary:
	var rec: Dictionary = (q.milestones.get("passed", {}) as Dictionary).get("green", {})
	var st := q.bld(int(rec.get("b", -1)))
	if st == null or not st.built or (st.type != "창고" and st.type != "농장"):
		st = Milestones.sheaf_house(q)
	if st == null:
		var at := Vector2(float(rec["x"]), float(rec["y"])) if rec.has("x") else q.fire + Vector2(0.9, 0.9)
		return {"pos": at, "front": 0.0, "h": 0.0, "lift": 0.0}
	var pos := Vector2(st.x, st.y)
	var pics := Bld2D.enabled()
	if st.type == "농장":
		var fence := float(Bld2D.info(Bld2D.Pics.WHEAT_FENCE).get("front", st.size())) if pics else st.size()
		return {"pos": pos, "front": fence + SHEAF_FENCE, "h": 0.0, "lift": 0.0}
	if pics and Bld2D.has(SHEAF_PIC):
		var front := float(Bld2D.info(SHEAF_PIC).get("front", st.size())) * VillageView.BUILDING_SCALE + SHEAF_FRONT
		return {"pos": pos, "front": front, "h": SHEAF_AT * VillageView.BUILDING_SCALE + SHEAF_FRONT * sin(deg_to_rad(JarCamera.PITCH_DEG)), "lift": 0.0}
	return {"pos": pos, "front": st.size() * VillageView.BUILDING_SCALE * SHEAF_3D.x, "h": 0.0, "lift": SHEAF_3D.y * VillageView.BUILDING_SCALE}


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
	_lift_sheaf()
	_dance(view.v)
	_clap(view.v)


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
		if id == "green":                               # 햇밀 다발: 건물 그림 바로 앞 · 문틀 높이 (높이는 _lift_sheaf가 카메라 기울기에 맞춰 넣는다)
			_hang = sheaf(q)
			var front := float(_hang["front"])
			(mi.material_override as ShaderMaterial).set_shader_parameter("geo", Vector4(sz.x, sz.y, front, 0.0))
			(mi.material_override as ShaderMaterial).set_shader_parameter("ex", Vector4(0.0, 0.0, 0.0, front))
			var e := r + front
			mi.custom_aabb = AABB(Vector3(-e, -r, -e), Vector3(e * 2.0, r * 2.0 + float(_hang["lift"]) + float(_hang["h"]) / 0.3, e * 2.0))
			_hang_lift = -1.0
	_lift_sheaf()
	_dance(q)


## 햇밀 다발의 높이: 건물 그림은 카메라 기울기만큼 위로 늘여 그리므로(화면에서 1:1) 그림 위의 한 점도 같은 몫으로 올린다 — 카메라가 기울어도 문틀 위에
func _lift_sheaf() -> void:
	var mi: MeshInstance3D = _signs.get("green")
	if mi == null or _hang.is_empty():
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cu := maxf(cam.global_transform.basis.y.y, 0.3) if cam != null else cos(deg_to_rad(JarCamera.PITCH_DEG))
	var lift := float(_hang["lift"]) + float(_hang["h"]) / cu
	if not is_equal_approx(lift, _hang_lift):
		_hang_lift = lift
		mi.set_instance_shader_parameter("lift", lift)


## (화면 · 시험) 햇밀 다발을 지금 올려 둔 높이 (칸 — 땅에서)
func sheaf_lift() -> float:
	return _hang_lift


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
		var n := int(FRAMES.get(id, 1))
		if n > 1:                                       # 옆으로 이어 붙인 장면을 차례로 (바람개비 날개)
			var fr: Array = []
			for i in 8:
				fr.append(Vector4(float(i % n) / float(n), 0.0, 1.0 / float(n), 1.0))
			mat.set_shader_parameter("frames", n)
			mat.set_shader_parameter("fps", FRAME_FPS)
			mat.set_shader_parameter("frame_uv", fr)
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


## 첫걸음마를 보러 온 이웃 (VillageView.sync가 사람마다 부른다): 문 앞에 서면 아기 쪽을 본다. 걸어오는 중·아기를 보는 사람은 그대로
func pose(r: Resident, m: ResidentModel) -> void:
	if r.steps.is_empty():
		return
	var s0: Dictionary = r.steps[0]
	if not s0.has("ms") or String(s0.get("k", "")) != "do" or bool(s0.get("par", false)):
		return
	var bm: Node3D = view.residents.get(int(s0["ms"]))
	if bm == null or not is_instance_valid(bm):
		return
	var d := bm.position - m.position
	if d.x * d.x + d.z * d.z > 0.01:
		m.rotation.y = atan2(d.x, d.z)


## 첫걸음마 손뼉: "ms" 표시가 붙은 손뼉 걸음("play") 중인 이웃 — 콩콩 뛰며 한마디. 걸음이 끝나면 되돌림
func _clap(q: Village) -> void:
	var live := {}
	if not view.fast and (q.milestones.has("steps_call") or not _clapping.is_empty() or _clap_recent(q)):
		for p in q.people:
			if p.steps.is_empty() or p.anim != "play":
				continue
			var s0: Dictionary = p.steps[0]
			if not s0.has("ms") or String(s0.get("k", "")) != "do":
				continue
			var cm := view.residents.get(p.id) as CutoutResident
			if cm == null or not is_instance_valid(cm):
				continue
			live[p.id] = true
			var hop := absf(sin(_t * CLAP_BEAT + float(p.id) * 1.3))
			cm.set_body_lift(CLAP_HOP * hop)
			cm.set_body_warp(1.0 + 0.04 * hop, 1.0 - 0.025 * hop, 0.0)
			if not _clapping.has(p.id):
				if _clapping.is_empty() and live.size() == 1:
					GameAudio.fx("small_cheer", "Village", -11.0, Vector2(p.x, p.y))
				if not view.stage_say.has(p.id):
					view.stage_say[p.id] = [String(CLAP_SAY[p.id % CLAP_SAY.size()]), "cheer", CLAP_SAY_SECS]
	for rid: int in _clapping.keys():
		if live.has(rid):
			continue
		var cm := view.residents.get(rid) as CutoutResident
		if cm != null and is_instance_valid(cm):
			cm.set_body_lift()
			cm.set_body_warp()
		_clapping.erase(rid)
	for rid: int in live:
		_clapping[rid] = true


## 첫걸음마 고비를 방금 넘었나 (손뼉 걸음이 아직 남아 있을 동안만 사람들을 살핀다)
func _clap_recent(q: Village) -> bool:
	var rec: Dictionary = (q.milestones.get("passed", {}) as Dictionary).get("steps", {})
	return not rec.is_empty() and not bool(rec.get("silent", false)) and q.t - float(rec.get("t", -1.0e12)) < Balance.STEPS_CLAP_SECS * 2.0


## (화면 · 시험) 지금 손뼉 치는 이웃 수
func clappers() -> int:
	return _clapping.size()


## (화면 · 시험) 지금 춤추는 사람 수
func dancers() -> int:
	return _dancing.size()
