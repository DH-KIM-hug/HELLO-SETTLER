## 우유·계란 없는 부엌 화면 (ROADMAP E3-14 · docs/FOOD.md 5) — sim/kitchen.gd (Village.kitchen)의 상태와 사건을 읽기만 한다 (ADR-0001:
## 결과를 바꾸지 않음 · 정적 상태 없음). VillageView의 아이 (병 데이터 좌표, x = x · z = y).
##  · 진딧물 목장 (Kitchen.ranch): 장미 줄기 + 풀줄기 울타리 + 단물 통 (props/kit_ranch, 문은 목장지기가 서는 쪽) ·
##    진딧물 = MultiMesh 하나 (props/kit_aphid, 마리 수 = ranch.n, 12까지 — 줄기에 붙은 것·바닥의 것이 번갈아) ·
##    아침에 목장지기가 톡톡 (그 자리에서 일하는 동안 팔을 진딧물 쪽으로) · honeydew_collected → 단물 방울이 목장지기 손으로 ·
##    ladybug_raid → 무당벌레 (critters/ladybug)가 울타리 밖에서 기어 와 잠시 머물다 감. 목장이 비면 울타리만 남음 (이 화면이 기억).
##  · 하늘의 큰 알 (Kitchen.eggs): 메추리알 (props/kit_quail_egg — 진짜 크기: 3.5 × 2.7cm = 누우면 소인 허리 높이, 기획서 3.0) —
##    새로 떨어진 것은 하늘에서 쿵 (SkyDropView.fall). 굴리는 사람 = 걸음에 이 알의 kit_egg_crack이 든 사람:
##    파내는 중 (kit_egg_roll 일) = 알이 흔들 · 굴리는 중 (걸음) = 알이 그들 앞에서 데굴데굴 (이동 거리 ÷ 반지름만큼 돎) · 깨는 중 = 덜덜.
##  · 깬 자리 (Kitchen.shells, 깬 뒤 FEAST_SHOW 동안): 노른자 웅덩이 + 돌판 알부침 + 잎 접시 (props/kit_egg_feast) + 껍데기 반쪽 둘 (갓 깼으면 벌어짐).
##    그 뒤 껍데기는 쓰임대로: basin = 깬 자리에서 가장 가까운 집 옆 빗물 통 (props/kit_shell_basin, MultiMesh) ·
##    boat = 가까운 물 위 돛단배 (props/kit_shell_boat, 출렁). 최근 SHELL_MAX개만.
##  · 씨앗 짜개 (맷돌간·방앗간 마당, 한 번이라도 빻았으면): props/kit_press + 지렛대 (seed_pressed 뒤 PRESS_SHOW 동안 꾹꾹).
## 그리기: 목장 2 + 진딧물 2 + 알 2 + 잔치 묶음 + 빗물 통 MultiMesh 2 + 배·짜개 몇 — 멀리(bld_far)에선 진딧물·방울·무당벌레를 숨김.
class_name KitchenView
extends Node3D

const M_RANCH := "props/kit_ranch"
const M_APHID := "props/kit_aphid"
const M_DEW := "props/kit_dew"
const M_EGG := "props/kit_quail_egg"
const M_HALF := "props/kit_egg_half"
const M_BASIN := "props/kit_shell_basin"
const M_BOAT := "props/kit_shell_boat"
const M_FEAST := "props/kit_egg_feast"
const M_PRESS := "props/kit_press"
const M_LEVER := "props/kit_press_lever"
const MODELS := [M_RANCH, M_APHID, M_DEW, M_EGG, M_HALF, M_BASIN, M_BOAT, M_FEAST, M_PRESS, M_LEVER]

const EGG_R := 0.28                     # 알 반지름 (누운 높이의 반 — art/src/build_kitchen.py EGG_R)
const EGG_LEAD := 0.75                  # 굴리는 사람들 가운데에서 가는 쪽으로 이만큼 앞
const FRESH := 30.0                     # 병 시간 이 안에 내려온 알만 떨어지는 모습
const FEAST_SHOW := Balance.DAY         # 깬 뒤 잔치 자리를 보이는 병 시간
const CRACK_OPEN := 0.9                 # 갓 깬 껍데기가 벌어지는 화면 초
const SHELL_MAX := 8
const BASIN_R := 1.2                    # 빗물 통: 집 가운데에서 집 크기 × 이만큼
const BASIN_A0 := 0.45                  # 카메라 쪽(BASE_YAW)에서 왼쪽으로 돌린 각 (집 id 짝 · 홀)
const BASIN_A1 := 1.05
const BOAT_IN := 2.0                    # 껍데기 배: 물가에서 물 안쪽으로 이만큼까지 (깊은 데를 찾아)
const PRESS_SHOW := 3.0 * Balance.HOUR  # 빻은 뒤 지렛대가 움직이는 병 시간
const LADY_IN := 6.0                    # 무당벌레: 기어 옴 · 머묾 · 돌아감 (화면 초)
const LADY_STAY := 9.0
const LADY_OUT := 6.0
const DEW_SECS := 1.4
const KEEPER_SPOT := Vector2(0.6, 0.5)  # sim/kitchen.gd _send_keeper — 목장지기가 서는 자리 (목장 기준)
## 진딧물 자리 (목장 기준, 문 = +Z 쪽): [0 바닥 · 1 줄기, 값들]. 바닥 = (x, z, 돌림) · 줄기 = (t 높이 몫, 둘레 각, 머리 위 1·아래 −1)
const SLOTS := [[0, -0.18, 0.42, 2.6], [1, 0.12, 0.4, 1.0], [0, 0.32, -0.12, 1.2], [1, 0.2, 2.6, 1.0], [0, -0.42, 0.05, 4.2],
	[1, 0.3, 4.4, -1.0], [0, 0.2, 0.36, 3.4], [1, 0.4, 1.4, 1.0], [0, -0.1, -0.5, 0.3], [1, 0.48, 3.3, -1.0],
	[0, 0.55, 0.2, 5.0], [1, 0.08, 5.6, 1.0]]

var v: Village
var vv: VillageView
var enabled := true
var _t := 0.0
var _cur := 0                           # 사건 줄 커서
var _ranch: Node3D
var _ranch_at := Vector2(1.0e9, 1.0e9)  # 마지막으로 그린 목장 자리 (비어도 울타리는 남김)
var _ranch_yaw := 0.0
var _aphids: MultiMeshInstance3D
var _aphid_lines: MultiMeshInstance3D
var _dews: Array = []                   # [{node, from: Vector3, who, t}]
var _lady: Dictionary = {}              # {node, ap, a (들어오는 각), t}
var _eggs := {}                         # 알 id → {root, spin, pos: Vector2, yaw, roll, seen_t}
var _feasts := {}                       # 껍데기 t 키 → {node, halves: [Node3D], t (화면 초), fresh}
var _basin_mm: Node3D
var _basin_key := ""
var _boats := {}                        # 껍데기 t 키 → {node, at: Vector2, y}
var _decor_t := 0.0
var _presses := {}                      # 건물 id → {node, lever}
var _press_t := {}                      # 건물 id → 마지막으로 빻은 병 시각 (사건)
# (시험·캡처) 지금 그린 것
var shown_aphids := 0
var shown_basins := 0
var shown_boats := 0
var egg_phase := {}                     # 알 id → "rest" · "dig" · "roll" · "crack"


func _init(village: Village, view: VillageView) -> void:
	v = village
	vv = view
	name = "kitchen"
	_cur = village.events.serial if village.events != null else 0


func _ready() -> void:
	for nm: String in MODELS:
		Art.model(nm)


func _gy(x: float, z: float) -> float:
	return vv.gy(x, z) if vv != null and vv.terrain != null else 0.0


func _k() -> Kitchen:
	return v.kitchen


# ───────────────────────── 매 화면 ─────────────────────────
func sync(dt: float) -> void:
	if not enabled or v == null or _k() == null:
		visible = false
		return
	visible = true
	_t += dt
	var still := vv != null and vv.fast
	_read_events()
	_sync_ranch(dt, still)
	_sync_dews(dt)
	_sync_lady(dt, still)
	_sync_eggs(dt, still)
	_sync_shells(dt)
	_sync_presses(dt, still)


func _far() -> bool:
	return vv != null and vv.bld_far


## 사건 줄 — 화면을 만든 뒤에 난 것만 (예전 사건은 연출하지 않음)
func _read_events() -> void:
	if v.events == null:
		return
	for e: Dictionary in v.events.since(_cur):
		if int(e.get("village", -1)) != v.sid:
			continue
		match e["kind"]:
			&"honeydew_collected":
				_dew(int(e.get("who", -1)))
			&"ladybug_raid":
				visit_ladybug()
			&"seed_pressed":
				var b := _mill_at(e.get("at", Vector2.ZERO))
				if b != null:
					_press_t[b.id] = float(e["t"])
	_cur = v.events.serial


# ───────────────────────── 진딧물 목장 ─────────────────────────
func _sync_ranch(_dt: float, still: bool) -> void:
	var k := _k()
	if not k.ranch.is_empty():
		_ranch_at = Vector2(float(k.ranch["x"]), float(k.ranch["y"]))
	if _ranch_at.x > 1.0e8:
		return
	if _ranch == null:
		_ranch = Node3D.new()
		_ranch.name = "ranch"
		add_child(_ranch)
		Art.instance(_ranch, M_RANCH)
		_make_aphids()
	_ranch_yaw = atan2(KEEPER_SPOT.x, KEEPER_SPOT.y)
	_ranch.position = Vector3(_ranch_at.x, _gy(_ranch_at.x, _ranch_at.y), _ranch_at.y)
	_ranch.rotation.y = _ranch_yaw
	var n := k.aphids()
	var show := 0 if _far() else mini(n, SLOTS.size())
	shown_aphids = show
	var mm := _aphids.multimesh
	if mm.visible_instance_count != show:
		mm.visible_instance_count = show
		if _aphid_lines != null:
			_aphid_lines.multimesh.visible_instance_count = show
	var active := Kitchen.month_of(v) in Balance.APHID_MONTHS
	if show > 0 and (not still or _t < 0.1):
		for i in show:
			var xf := _slot_xf(i, _t if active else 0.0)
			mm.set_instance_transform(i, xf)
			if _aphid_lines != null:
				_aphid_lines.multimesh.set_instance_transform(i, xf)
	_keeper_pose()


func _make_aphids() -> void:
	var m := Art.model(M_APHID)
	for key: String in ["mesh", "lines"]:
		if m[key] == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m[key]
		mm.instance_count = SLOTS.size()
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ranch.add_child(mmi)
		if key == "mesh":
			_aphids = mmi
		else:
			_aphid_lines = mmi


## 줄기 중심선 (art/src/build_kitchen.py stem_path — Blender (x, y, z) → Godot (x, z, −y))
static func stem_at(t: float) -> Vector3:
	return Vector3(0.12 * sin(t * 2.2), 2.4 * t, -(0.18 + 0.1 * t * t))


static func stem_r(t: float) -> float:
	return 0.075 - 0.03 * t


## 진딧물 한 마리의 자리 (목장 기준). ph = 화면 시각 (0 = 멈춤) — 바닥 것은 조금씩 고개를 돌리고, 줄기 것은 살짝 오르내림
func _slot_xf(i: int, ph: float) -> Transform3D:
	var s: Array = SLOTS[i]
	var w := 0.0 if ph == 0.0 else sin(ph * 0.9 + i * 1.7)
	if int(s[0]) == 0:
		var yaw := float(s[3]) + 0.35 * w
		var p := Vector3(float(s[1]), 0.0, float(s[2])) + Vector3(sin(ph * 0.3 + i), 0.0, cos(ph * 0.37 + i)) * (0.03 if ph != 0.0 else 0.0)
		return Transform3D(Basis(Vector3.UP, yaw), p)
	var t := float(s[1]) + 0.012 * w
	var a := float(s[2])
	var c := stem_at(t)
	var n := Vector3(cos(a), 0.0, sin(a))
	var head := Vector3.UP * float(s[3])
	var x := n.cross(head).normalized()
	# 모델: 앞(머리) = +Z, 등 = +Y → 머리 = 위/아래, 등 = 줄기 바깥쪽
	return Transform3D(Basis(x, n, head), c + n * (stem_r(t) + 0.005))


## 아침 톡톡: 목장 자리에서 '진딧물' 일을 하는 사람 — 진딧물 쪽을 보고 팔을 내려 쓰다듬음 (화면만)
func _keeper_pose() -> void:
	if vv == null or _ranch == null:
		return
	var spot := _ranch_at + KEEPER_SPOT
	for r in v.people:
		if r.anim != "work" or not r.doing.begins_with("진딧물"):
			continue
		if Vector2(r.x, r.y).distance_to(spot) > 0.6:
			continue
		var m: Node3D = vv.residents.get(r.id)
		if m == null:
			continue
		var to := _ranch_at - Vector2(m.position.x, m.position.z)
		m.rotation.y = atan2(to.x, to.y)
		if m.has_method("aim_arm_r"):
			m.call("aim_arm_r", -0.55 + 0.25 * sin(_t * 5.0 + r.id), 0.15)


## 단물 방울: 진딧물 곁에서 떠올라 목장지기 손으로
func _dew(who: int) -> void:
	if _ranch == null:
		return
	var n := Node3D.new()
	add_child(n)
	Art.instance(n, M_DEW)
	var from := _ranch.transform * Vector3(-0.15, 0.12, 0.42)
	n.position = from
	_dews.append({"node": n, "from": from, "who": who, "t": 0.0})


func _sync_dews(dt: float) -> void:
	var keep: Array = []
	for d: Dictionary in _dews:
		var n: Node3D = d["node"]
		d["t"] = float(d["t"]) + dt
		var u := float(d["t"]) / DEW_SECS
		if u >= 1.0 or not is_instance_valid(n):
			if is_instance_valid(n):
				n.queue_free()
			continue
		var to: Vector3 = d["from"] + Vector3(0, 0.5, 0)
		var m: Node3D = vv.residents.get(int(d["who"])) if vv != null else null
		if m != null:
			to = m.position + Vector3(0, 0.5, 0)
		var p := (d["from"] as Vector3).lerp(to, smoothstep(0.0, 1.0, u))
		p.y += sin(u * PI) * 0.35
		n.position = p
		n.scale = Vector3.ONE * (1.0 + 0.3 * sin(u * PI))
		n.visible = not _far()
		keep.append(d)
	_dews = keep


## 무당벌레가 옴 (사건 ladybug_raid · 캡처). 울타리 밖에서 줄기 밑까지 기어 와 머물다 돌아감
func visit_ladybug() -> void:
	if _ranch == null or not FaunaView.has_model("ladybug"):
		return
	if not _lady.is_empty() and is_instance_valid(_lady["node"]):
		(_lady["node"] as Node3D).queue_free()
	var n := FaunaView.instance("ladybug")
	FaunaView._set_lod(n, false)
	_ranch.add_child(n)
	var ap := FaunaView._ap(n)
	FaunaView._play(ap, "walk")
	var a := -1.9 + 0.7 * float(v.sid % 3)                 # 문 반대쪽 뒤에서
	_lady = {"node": n, "ap": ap, "a": a, "t": 0.0}


func has_ladybug() -> bool:
	return not _lady.is_empty()


func _sync_lady(dt: float, still: bool) -> void:
	if _lady.is_empty():
		return
	var n: Node3D = _lady["node"]
	if not is_instance_valid(n) or _ranch == null:
		_lady = {}
		return
	_lady["t"] = float(_lady["t"]) + (0.0 if still else dt)
	var t := float(_lady["t"])
	var a := float(_lady["a"])
	var out := Vector3(cos(a), 0, sin(a)) * 2.3
	var inn := Vector3(cos(a + 0.4), 0, sin(a + 0.4)) * 0.38
	var p: Vector3
	var face: Vector3
	var ap: AnimationPlayer = _lady["ap"]
	if t < LADY_IN:
		var u := t / LADY_IN
		p = out.lerp(inn, u) + Vector3(0, 0.35 * sin(u * PI) if u > 0.38 and u < 0.62 else 0.0, 0)   # 울타리를 넘음
		face = inn - out
		FaunaView._play(ap, "walk")
	elif t < LADY_IN + LADY_STAY:
		p = inn + Vector3(sin(t * 0.7), 0, cos(t * 0.6)) * 0.08
		face = -inn + Vector3(sin(t * 0.5), 0, cos(t * 0.5)) * 0.5
		FaunaView._play(ap, "idle")
	elif t < LADY_IN + LADY_STAY + LADY_OUT:
		var u := (t - LADY_IN - LADY_STAY) / LADY_OUT
		var out2 := Vector3(cos(a - 0.9), 0, sin(a - 0.9)) * 2.4
		p = inn.lerp(out2, u) + Vector3(0, 0.35 * sin(u * PI) if u > 0.38 and u < 0.62 else 0.0, 0)
		face = out2 - inn
		FaunaView._play(ap, "walk")
	else:
		n.queue_free()
		_lady = {}
		return
	n.position = p
	n.rotation.y = atan2(face.x, face.z)
	n.visible = not _far()


# ───────────────────────── 하늘의 큰 알 ─────────────────────────
## 이 알을 굴리는 사람들 — 걸음에 kit_egg_crack(e = id)이 남은 사람. 지금 첫 걸음으로 단계를 나눔
func _crew(id: int) -> Dictionary:
	var out := {"dig": [], "roll": [], "crack": [], "to": Vector2.ZERO}
	var nto := 0
	for r in v.people:
		if r.dead or r.steps.is_empty():
			continue
		var mine := false
		for st: Dictionary in r.steps:
			var d: Variant = st.get("done")
			if d is Dictionary and String((d as Dictionary).get("op", "")) == "kit_egg_crack" and int((d as Dictionary).get("e", -1)) == id:
				mine = true
				break
		if not mine:
			continue
		var s0: Dictionary = r.steps[0]
		var op0 := ""
		if s0.get("done") is Dictionary:
			op0 = String((s0["done"] as Dictionary).get("op", ""))
		if s0["k"] == "do" and op0 == "kit_egg_roll":
			(out["dig"] as Array).append(r)
		elif s0["k"] == "do" and op0 == "kit_egg_crack":
			(out["crack"] as Array).append(r)
		elif s0["k"] == "walk":
			var rolled := true                  # 아직 파내는 일이 앞에 남았으면 다가가는 중
			for st: Dictionary in r.steps:
				if st.get("done") is Dictionary and String((st["done"] as Dictionary).get("op", "")) == "kit_egg_roll":
					rolled = false
					break
			if rolled:
				(out["roll"] as Array).append(r)
				out["to"] = (out["to"] as Vector2) + Vector2(float(s0["x"]), float(s0["y"]))
				nto += 1
	if nto > 0:
		out["to"] = (out["to"] as Vector2) / float(nto)
	return out


func _rpos(r: Resident) -> Vector2:
	var m: Node3D = vv.residents.get(r.id) if vv != null else null
	return Vector2(m.position.x, m.position.z) if m != null else Vector2(r.x, r.y)


func _sync_eggs(dt: float, still: bool) -> void:
	var seen := {}
	for e: Dictionary in _k().eggs:
		var id := int(e["id"])
		seen[id] = true
		var g: Dictionary = _eggs.get(id, {})
		var home := Vector2(float(e["x"]), float(e["y"]))
		if g.is_empty():
			var root := Node3D.new()
			root.name = "egg_%d" % id
			add_child(root)
			var spin := Node3D.new()
			root.add_child(spin)
			Art.instance(spin, M_EGG)
			g = {"root": root, "spin": spin, "pos": home, "yaw": fposmod(id * 1.3, TAU), "roll": 0.0}
			_eggs[id] = g
			root.position = Vector3(home.x, _gy(home.x, home.y) + EGG_R, home.y)
			if v.t - float(e["t"]) < FRESH and vv != null and vv.drop_view != null and is_inside_tree():
				vv.drop_view.fall(root, root.position.y)
		var root: Node3D = g["root"]
		var spin: Node3D = g["spin"]
		var crew := _crew(id)
		var phase := "rest"
		var target: Vector2 = g["pos"]
		var pushers: Array = []
		if not (crew["roll"] as Array).is_empty():
			phase = "roll"
			pushers = crew["roll"]
			var c := Vector2.ZERO
			for r: Resident in pushers:
				c += _rpos(r)
			c /= float(pushers.size())
			var dir: Vector2 = (crew["to"] as Vector2) - c
			target = c + (dir.normalized() * minf(EGG_LEAD, dir.length()) if dir.length() > 0.05 else Vector2.ZERO)
		elif not (crew["crack"] as Array).is_empty():
			phase = "crack"
			pushers = crew["crack"]
		elif not (crew["dig"] as Array).is_empty():
			phase = "dig"
			pushers = crew["dig"]
			target = home if not bool(e["rolled"]) else target
		elif not bool(e["rolled"]):
			target = home
		egg_phase[id] = phase
		var falling := vv != null and vv.drop_view != null and vv.drop_view._falling(root)
		if falling:
			continue
		var old: Vector2 = g["pos"]
		var np := old.lerp(target, 1.0 - exp(-dt * 6.0)) if dt > 0.0 else target
		var mv := np - old
		if mv.length() > 0.002:
			var want := atan2(mv.x, mv.y) + PI * 0.5      # 긴 축(X)이 가는 쪽과 직각 → 옆으로 데굴데굴
			g["yaw"] = lerp_angle(float(g["yaw"]), want, 1.0 - exp(-dt * 4.0))
			g["roll"] = float(g["roll"]) + mv.length() / EGG_R
		g["pos"] = np
		var wob := 0.0
		if not still:
			if phase == "dig":
				wob = 0.09 * sin(_t * 7.0)
			elif phase == "crack":
				wob = 0.06 * sin(_t * 31.0)
		root.position = Vector3(np.x, _gy(np.x, np.y) + EGG_R, np.y)
		spin.basis = Basis(Vector3.UP, float(g["yaw"])) * Basis(Vector3.RIGHT, float(g["roll"])) * Basis(Vector3.BACK, wob)
		for r: Resident in pushers:
			var m: Node3D = vv.residents.get(r.id) if vv != null else null
			if m == null:
				continue
			if phase != "roll":
				var to := np - Vector2(m.position.x, m.position.z)
				m.rotation.y = atan2(to.x, to.y)
			if m.has_method("aim_arm_r"):
				m.call("aim_arm_r", -1.25 + (0.15 * sin(_t * 6.0 + r.id) if not still else 0.0), 0.1)
	for id: int in _eggs.keys():
		if not seen.has(id):
			var root: Node3D = _eggs[id]["root"]
			if vv != null and vv.drop_view != null and is_inside_tree():
				vv.drop_view._puff(root.position - Vector3(0, EGG_R, 0), 0.9)
			root.queue_free()
			_eggs.erase(id)
			egg_phase.erase(id)


# ───────────────────────── 깬 자리 · 껍데기 ─────────────────────────
func _skey(s: Dictionary) -> String:
	return "%.1f|%.2f|%.2f" % [float(s["t"]), float(s["x"]), float(s["y"])]


func _sync_shells(dt: float) -> void:
	var shells: Array = _k().shells
	var from := maxi(0, shells.size() - SHELL_MAX)
	var feast_seen := {}
	var decor: Array = []
	for i in range(from, shells.size()):
		var s: Dictionary = shells[i]
		var key := _skey(s)
		if v.t - float(s["t"]) < FEAST_SHOW:
			feast_seen[key] = true
			_feast(s, key, dt)
		else:
			decor.append(s)
	for key: String in _feasts.keys():
		if not feast_seen.has(key):
			(_feasts[key]["node"] as Node3D).queue_free()
			_feasts.erase(key)
	_decor_t -= dt
	if _decor_t <= 0.0 or dt == 0.0:
		_decor_t = 2.0
		_place_decor(decor)
	for key: String in _boats:
		var b: Dictionary = _boats[key]
		var at: Vector2 = b["at"]
		var ph := float(hash(key) % 100) * 0.1
		var n: Node3D = b["node"]
		var drift := Vector2(sin(_t * 0.11 + ph), cos(_t * 0.09 + ph)) * 0.25
		n.position = Vector3(at.x + drift.x, float(b["y"]) - 0.12 + 0.025 * sin(_t * 1.6 + ph), at.y + drift.y)
		n.rotation = Vector3(0.06 * sin(_t * 1.3 + ph), _t * 0.05 + ph, 0.05 * cos(_t * 1.1 + ph))


## 잔치 자리: 노른자 웅덩이 + 알부침 + 껍데기 반쪽 둘 (갓 깼으면 벌어지는 모습)
func _feast(s: Dictionary, key: String, dt: float) -> void:
	var f: Dictionary = _feasts.get(key, {})
	var at := Vector2(float(s["x"]), float(s["y"]))
	if f.is_empty():
		var n := Node3D.new()
		n.name = "feast"
		add_child(n)
		n.position = Vector3(at.x, _gy(at.x, at.y), at.y)
		n.rotation.y = fposmod(float(s["t"]) * 0.37, TAU)
		Art.instance(n, M_FEAST)
		var halves: Array = []
		for j in 2:
			var h := Art.instance(n, M_HALF)
			halves.append(h)
		var fresh := v.t - float(s["t"]) < 120.0
		f = {"node": n, "halves": halves, "t": 0.0 if fresh else CRACK_OPEN}
		_feasts[key] = f
		if fresh and vv != null and vv.drop_view != null and is_inside_tree():
			vv.drop_view._puff(n.position, 0.7)
	f["t"] = float(f["t"]) + dt
	var u := clampf(float(f["t"]) / CRACK_OPEN, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - u, 3.0)
	var hs: Array = f["halves"]
	# 0: 바로 선 그릇 (웅덩이 왼쪽 뒤) · 1: 옆으로 누운 반쪽 (오른쪽 앞) — 처음엔 붙어 선 알 모양에서 벌어짐
	var h0: Node3D = hs[0]
	var h1: Node3D = hs[1]
	var p0 := Vector3(-0.15, 0.0, -0.05).lerp(Vector3(-0.62, 0.0, -0.42), e)
	var p1 := Vector3(0.15, 0.45, -0.05).lerp(Vector3(0.05, 0.12, 0.72), e)
	h0.transform = Transform3D(Basis(Vector3.BACK, lerpf(-0.3, 0.12, e)), p0)
	h1.transform = Transform3D(Basis(Vector3.UP, 0.8) * Basis(Vector3.RIGHT, lerpf(PI, PI * 0.55, e)), p1 + Vector3(0, 0.12 * sin(u * PI), 0))


## 껍데기 쓰임: basin = 가까운 집 옆 (집마다 하나씩) · boat = 가까운 물 위. 2초마다 다시 놓음 (집이 새로 서면 따라감)
func _place_decor(decor: Array) -> void:
	var xfs: Array[Transform3D] = []
	var used := {}
	var boat_seen := {}
	for s: Dictionary in decor:
		var key := _skey(s)
		var at := Vector2(float(s["x"]), float(s["y"]))
		if String(s.get("use", "basin")) == "boat":
			var wp := _water_spot(at)
			if wp.z > -1.0e8:
				boat_seen[key] = true
				var b: Dictionary = _boats.get(key, {})
				if b.is_empty():
					var n := Node3D.new()
					n.name = "shell_boat"
					add_child(n)
					Art.instance(n, M_BOAT)
					b = {"node": n}
					_boats[key] = b
				b["at"] = Vector2(wp.x, wp.y)
				b["y"] = wp.z
				continue
		xfs.append(_basin_xf(at, used, float(s["t"])))
	for key: String in _boats.keys():
		if not boat_seen.has(key):
			(_boats[key]["node"] as Node3D).queue_free()
			_boats.erase(key)
	shown_boats = _boats.size()
	shown_basins = xfs.size()
	var bk := ""
	for x in xfs:
		bk += "%.2f,%.2f;" % [x.origin.x, x.origin.z]
	if bk == _basin_key:
		return
	_basin_key = bk
	if _basin_mm != null:
		_basin_mm.queue_free()
	_basin_mm = Node3D.new()
	_basin_mm.name = "basins"
	add_child(_basin_mm)
	Art.multi(_basin_mm, M_BASIN, xfs, false)


## 깬 자리에서 가까운 집 (아직 빗물 통이 없는 집) 처마 밑 — 카메라 쪽 앞 귀퉁이 (마당 덤불·꽃은 집 오른쪽 뒤
## 76°~207° — village_view _decor_yards — 이라 겹치지 않고, 집 뒤에 가려지지 않는다)
func _basin_xf(at: Vector2, used: Dictionary, t: float) -> Transform3D:
	var best: Building = null
	var bd := INF
	for b in v.buildings:
		if not b.built or not b.is_house() or used.has(b.id):
			continue
		var d := Vector2(b.x, b.y).distance_squared_to(at)
		if d < bd:
			bd = d
			best = b
	var rot := Basis(Vector3.UP, fposmod(t * 0.53, TAU))
	if best == null or bd > 400.0:
		return Transform3D(rot, Vector3(at.x, _gy(at.x, at.y) - 0.06, at.y))
	used[best.id] = true
	var r := best.size() * VillageView.BUILDING_SCALE * BASIN_R
	var a := deg_to_rad(JarCamera.BASE_YAW_DEG) - (BASIN_A0 if best.id % 2 == 0 else BASIN_A1)
	var p := Vector2(best.x + sin(a) * r, best.y + cos(a) * r)
	return Transform3D(rot, Vector3(p.x, _gy(p.x, p.y) - 0.06, p.y))


## 깬 자리 곁 물 (호수·강, 얕지 않은 칸) — (x, z, 수면 높이). 없으면 z = −1e9
func _water_spot(at: Vector2) -> Vector3:
	var w := v.water
	if w == null:
		return Vector3(0, 0, -1.0e9)
	var rr := Balance.SHELL_WATER_R + 2.0
	var steps := int(rr / 0.5)
	for ri in range(1, steps + 1):
		var r := ri * 0.5
		for i in 16:
			var a := TAU * i / 16.0 + 0.2
			var p := at + Vector2(cos(a), sin(a)) * r
			var k := w.idx(p.x, p.y)
			if k < 0 or not (w.is_lake(k) or w.is_river(k)):
				continue
			# 물가에서 안쪽으로 — 물 칸이 이어지는 동안 BOAT_IN까지 (가장 깊은 데)
			var best_d := w.depth(k)
			for j in range(1, int(BOAT_IN / 0.25) + 1):
				var q := p + Vector2(cos(a), sin(a)) * (0.25 * j)
				var kq := w.idx(q.x, q.y)
				if kq < 0 or not (w.is_lake(kq) or w.is_river(kq)):
					break
				if j * 0.25 >= 0.9 and w.depth(kq) >= best_d * 0.9:
					p = q
					k = kq
					best_d = maxf(best_d, w.depth(kq))
			return Vector3(p.x, p.y, (w.ground(k) + w.depth(k)) * JarTerrain.HS - JarTerrain.WATER_SINK)
	return Vector3(0, 0, -1.0e9)


# ───────────────────────── 씨앗 짜개 ─────────────────────────
func _mill_at(p: Variant) -> Building:
	if not p is Vector2:
		return null
	var best: Building = null
	var bd := 4.0
	for b in v.buildings:
		if b.type != "맷돌간" and b.type != "방앗간":
			continue
		var d := Vector2(b.x, b.y).distance_squared_to(p)
		if d < bd:
			bd = d
			best = b
	return best


const PRESS_PIVOT := Vector3(-0.45, 0.62, 0.0)   # build_kitchen.py PRESS_PIVOT (Blender (x, y, z) → Godot (x, z, −y))


func _sync_presses(_dt: float, still: bool) -> void:
	var seen := {}
	var ever := float(_k().stats.get("pressed", 0.0)) > 0.0
	for b in v.buildings:
		if not b.built or (b.type != "맷돌간" and b.type != "방앗간"):
			continue
		if not ever and not _press_t.has(b.id):
			continue
		seen[b.id] = true
		var p: Dictionary = _presses.get(b.id, {})
		if p.is_empty():
			var n := Node3D.new()
			n.name = "seed_press"
			add_child(n)
			Art.instance(n, M_PRESS)
			var lever := Node3D.new()
			n.add_child(lever)
			lever.position = PRESS_PIVOT
			Art.instance(lever, M_LEVER)
			p = {"node": n, "lever": lever}
			_presses[b.id] = p
		var n: Node3D = p["node"]
		var s := b.size()
		var m := 1.0 if b.id % 2 == 0 else -1.0
		var local := Transform3D(Basis(Vector3.UP, PI * 0.5 * m + 0.2), Vector3(-1.2 * m * s, 0.0, 1.25 * s))
		var bn: Node3D = vv._blds.get(b.id) if vv != null else null
		var xf := bn.transform * local if bn != null else Transform3D(local.basis, Vector3(b.x, 0.0, b.y) + local.origin)
		xf.origin.y = _gy(xf.origin.x, xf.origin.z)
		n.transform = xf
		var lever: Node3D = p["lever"]
		var on := press_active(b.id)
		lever.rotation.z = (-0.06 + 0.14 * sin(_t * 2.4)) if (on and not still) else 0.08
	for id: int in _presses.keys():
		if not seen.has(id):
			(_presses[id]["node"] as Node3D).queue_free()
			_presses.erase(id)


func press_active(bid: int) -> bool:
	return _press_t.has(bid) and v.t - float(_press_t[bid]) < PRESS_SHOW


func n_presses() -> int:
	return _presses.size()


func n_eggs() -> int:
	return _eggs.size()


func n_feasts() -> int:
	return _feasts.size()


func has_ranch() -> bool:
	return _ranch != null
