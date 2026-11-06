## 곰팡이 무리 그림 — WORLD_EVENTS 2.1 '모습' (기준 그림: design/concept/small_world/mold_lineup_a.png · mold_swarm_b.png).
## 주민 무릎~허리만 한 동글동글한 털뭉치: 뭉게뭉게한 털 덩어리(구 + 둘레에 작은 털 뭉치) + 점 눈 두 개 + 정수리의 포자 대롱 1~2가닥
## (검은·흰 = 솜털 공, 푸른·누룩 = 작은 갓) + 털 속에 숨은 짧은 뿌리 발. 큰 흰 눈·막대 팔다리는 쓰지 않는다.
## 색: 검은(숯빛) · 푸른(청록) · 흰(솜털) · 누룩(노란 금빛). 공용 툰 빛 (밝은 면 + 청록 그늘) — 종류마다 메시 하나(꼭짓점 색)를 나눠 씀.
## 움직임 (화면 시간, 시뮬레이션은 읽기만): 통통 튀며 걷기 (내려앉을 때 납작) · 포자 가루 퐁퐁 · 놀라면 털이 곤두섬(가시 털) ·
## 볕을 받으면 쪼그라들어 납작 · 횃불에 그을리면 움찔 · 길들인 누룩은 느긋하게 흔들림. 늘 카메라 쪽을 본다 (점 눈이 보이게).
class_name MoldView
extends Node3D

const SCALE := 1.1                # 화면 크기 배율 (몸 지름 약 0.5칸, 대롱까지 어른 키의 절반 남짓 — 기본 확대에서 읽히게)
const BODY_R := 0.2
const COLORS := {"검은": Color("44474d"), "푸른": Color("4f9590"), "흰": Color("eeeae0"), "누룩": Color("e9c45c")}
const TIPS := {"검은": "puff", "푸른": "cap", "흰": "puff", "누룩": "cap"}
const CAP_COLORS := {"푸른": Color("efe2bf"), "누룩": Color("f0c86a")}
const PUFF := Color("f6f1e3")
const STALK := Color("ddd3b8")
const EYE := Color("1b1718")
const FOOT := Color("c9a57a")

static var _meshes: Dictionary = {}     # 종류 → ArrayMesh (몸·털·눈·대롱·발)
static var _spikes: ArrayMesh            # 곤두선 털 (종류 색은 재질로)
static var _puff_mesh: SphereMesh

var v: Village
var nodes := {}                          # blob id → Dictionary {root, pose, spikes, puffs: Array, t, last, hop, ...}
var alpha := 1.0
var _t := 0.0


func _init(village: Village) -> void:
	v = village


# ───────────────────────── 메시 (종류마다 한 번) ─────────────────────────
static func _sphere(r: float, rings := 8, segs := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.rings = rings
	s.radial_segments = segs
	return s


static func body_mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var c: Color = COLORS[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cy := BODY_R * 0.92             # 몸 가운데 높이 (발 위)
	# 몸: 살짝 납작한 구
	Toon.append(st, _sphere(BODY_R, 10, 16), Transform3D(Basis().scaled(Vector3(1.08, 0.95, 1.0)), Vector3(0, cy, 0)), c)
	# 뭉게뭉게한 털: 겉면에 작은 털 뭉치 (피보나치 배치 — 위쪽과 옆이 촘촘, 바닥은 비움)
	var n := 34
	for i in n:
		var yy := 1.0 - (float(i) + 0.5) / n * 1.7          # 1 → −0.7 (바닥 아래는 없음)
		var rr := sqrt(maxf(0.0, 1.0 - yy * yy))
		var a := float(i) * 2.39996
		var d := Vector3(cos(a) * rr, yy, sin(a) * rr)
		if d.z > 0.55 and absf(d.y - 0.3) < 0.5 and absf(d.x) < 0.75:
			continue                         # 얼굴 자리는 비움 (점 눈이 털에 묻히지 않게)
		var lump := BODY_R * (0.34 + 0.1 * fposmod(float(i) * 0.618, 1.0))
		var pos := Vector3(d.x * BODY_R * 1.0, cy + d.y * BODY_R * 0.92, d.z * BODY_R * 0.95)
		Toon.append(st, _sphere(lump, 5, 8), Transform3D(Basis(), pos), c.darkened(0.04 * fposmod(float(i) * 0.37, 1.0)))
	# 점 눈 두 개 (앞 = +z, 주민과 같은 점 눈)
	for sx in [-1.0, 1.0]:
		Toon.append(st, _sphere(BODY_R * 0.14, 5, 8), Transform3D(Basis().scaled(Vector3(0.9, 1.25, 0.6)), Vector3(sx * BODY_R * 0.34, cy + BODY_R * 0.36, BODY_R * 0.9)), EYE)
	# 짧은 뿌리 발 (털 속에서 살짝)
	for sx in [-1.0, 1.0]:
		Toon.append(st, _sphere(BODY_R * 0.16, 4, 6), Transform3D(Basis().scaled(Vector3(1.0, 0.6, 1.3)), Vector3(sx * BODY_R * 0.42, BODY_R * 0.07, BODY_R * 0.55)), FOOT)
	# 정수리의 포자 대롱 1~2가닥 (검은·흰 = 솜털 공, 푸른·누룩 = 작은 갓)
	var stalks := [[Vector3(-0.05, 0, -0.01), 0.3, 0.27], [Vector3(0.07, 0, -0.04), -0.36, 0.2]]
	for k in stalks.size():
		var base: Vector3 = stalks[k][0] + Vector3(0, cy + BODY_R * 1.05, 0)
		var lean: float = stalks[k][1]
		var h: float = stalks[k][2]
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.013
		cyl.bottom_radius = 0.019
		cyl.height = h
		cyl.radial_segments = 6
		cyl.rings = 1
		var b := Basis(Vector3(0, 0, 1), lean)
		Toon.append(st, cyl, Transform3D(b, base + b * Vector3(0, h * 0.5, 0)), STALK)
		var tip := base + b * Vector3(0, h, 0)
		if TIPS[kind] == "puff":
			var pr := 0.058 if k == 0 else 0.047
			Toon.append(st, _sphere(pr, 5, 8), Transform3D(Basis(), tip), PUFF)
			for j in 4:                     # 솜털 공도 뭉게뭉게
				var aa := j * PI * 0.5 + 0.4
				Toon.append(st, _sphere(pr * 0.55, 4, 6), Transform3D(Basis(), tip + Vector3(cos(aa), 0.3, sin(aa)) * pr * 0.75), PUFF)
		else:
			var cr := 0.085 if k == 0 else 0.065
			var cap := _sphere(cr, 5, 10)
			Toon.append(st, cap, Transform3D(Basis().scaled(Vector3(1.0, 0.45, 1.0)), tip + Vector3(0, cr * 0.2, 0)), CAP_COLORS[kind])
			Toon.append(st, _sphere(cr * 0.55, 4, 8), Transform3D(Basis().scaled(Vector3(1.0, 0.4, 1.0)), tip - Vector3(0, cr * 0.05, 0)), CAP_COLORS[kind].darkened(0.18))
	var m := st.commit()
	_meshes[kind] = m
	return m


## 곤두선 털: 몸 둘레에 뾰족한 털 (놀랐을 때만 보임)
static func spike_mesh() -> ArrayMesh:
	if _spikes != null:
		return _spikes
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cy := BODY_R * 0.92
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.035
	cone.height = 0.13
	cone.radial_segments = 5
	cone.rings = 1
	var n := 26
	for i in n:
		var yy := 0.95 - (float(i) + 0.5) / n * 1.45
		var rr := sqrt(maxf(0.0, 1.0 - yy * yy))
		var a := float(i) * 2.39996 + 0.7
		var d := Vector3(cos(a) * rr, yy, sin(a) * rr).normalized()
		var b := Basis(Quaternion(Vector3.UP, d))
		Toon.append(st, cone, Transform3D(b, Vector3(0, cy, 0) + d * (BODY_R * 1.1 + 0.05)), Color.WHITE)
	_spikes = st.commit()
	return _spikes


# ───────────────────────── 매 화면 ─────────────────────────
func sync(dt: float) -> void:
	_t += dt
	var m := v.mold
	var seen := {}
	if m != null:
		var cam := get_viewport().get_camera_3d()
		var cam_yaw := 0.0
		if cam != null:
			var f := cam.global_transform.basis.z
			cam_yaw = atan2(f.x, f.z)
		var night := v.is_night()
		for b in m.blobs:
			if b.state == "gone":
				continue
			seen[b.id] = true
			var nd: Dictionary = nodes.get(b.id, {})
			if nd.is_empty():
				nd = _make(b)
				nodes[b.id] = nd
			_pose(nd, b, dt, cam_yaw, night)
	for id in nodes.keys():
		if not seen.has(id):
			_vanish(nodes[id], dt)
			if float(nodes[id]["fade"]) <= 0.0:
				(nodes[id]["root"] as Node3D).queue_free()
				nodes.erase(id)


func _make(b: MoldBlob) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var pose := Node3D.new()
	root.add_child(pose)
	var body := MeshInstance3D.new()
	body.mesh = body_mesh(b.kind)
	body.material_override = Toon.vc_mat()
	pose.add_child(body)
	var sp := MeshInstance3D.new()
	sp.mesh = spike_mesh()
	sp.material_override = Toon.mat(COLORS[b.kind])
	sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sp.visible = false
	pose.add_child(sp)
	var puffs: Array = []
	if _puff_mesh == null:
		_puff_mesh = _sphere(0.035, 4, 6)
	for i in 5:                           # 포자 가루 퐁퐁 (튈 때 내려앉는 순간)
		var p := MeshInstance3D.new()
		p.mesh = _puff_mesh
		p.material_override = Toon.mat(PUFF if b.kind != "누룩" else Color("fbe7a6"))
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visible = false
		root.add_child(p)
		puffs.append({"n": p, "t": -1.0, "o": Vector3.ZERO})
	var x := b.x
	var z := b.y
	root.position = Vector3(x, _gy(x, z), z)
	return {"root": root, "pose": pose, "body": body, "spikes": sp, "puffs": puffs, "ph": fposmod(b.id * 0.37, 1.0) * TAU,
		"hop": 0.0, "was_air": false, "bristle": 0.0, "flat": 0.0, "fade": 1.0, "scale": 0.0, "yaw": 0.0}


func _gy(x: float, z: float) -> float:
	var p := get_parent()
	if p is VillageView:
		return (p as VillageView).gy(x, z)
	return 0.0


func _pose(nd: Dictionary, b: MoldBlob, dt: float, cam_yaw: float, night: bool) -> void:
	var root: Node3D = nd["root"]
	var pose: Node3D = nd["pose"]
	var x := b.x
	var z := b.y
	if alpha < 1.0 and absf(b.x - b.px) + absf(b.y - b.py) < 3.0:
		x = lerpf(b.px, b.x, alpha)
		z = lerpf(b.py, b.y, alpha)
	var prev: Vector3 = root.position
	var gy := _gy(x, z)
	root.position = Vector3(x, gy, z)
	var moving := Vector2(x - prev.x, z - prev.z).length() > 0.0005 and b.state != "tamed"
	# 크기: 자라기·쪼그라들기는 부드럽게 (태어날 때 0 → 크기)
	var goal := b.size * SCALE
	nd["scale"] = lerpf(float(nd["scale"]), goal, 1.0 - exp(-6.0 * dt))
	var s: float = nd["scale"]
	# 볕을 받으면 쪼그라들어 납작 (낮의 볕 드는 쪽) · 놀라면 털이 곤두섬
	var sun := maxf(0.0, v.water.sun_at(x, z)) if not night else 0.0
	nd["flat"] = lerpf(float(nd["flat"]), clampf((sun - 0.35) / 0.4, 0.0, 1.0), 1.0 - exp(-3.0 * dt))
	var alarm := 1.0 if (b.burnt > 0.0 or b.state == "flee") else (0.45 if b.startle > 0.0 else 0.0)   # 횃불·마른 바람 = 털이 곤두섬, 주민이 다가옴 = 살짝
	nd["bristle"] = lerpf(float(nd["bristle"]), alarm, 1.0 - exp(-(14.0 if alarm > float(nd["bristle"]) else 4.0) * dt))
	# 통통 튀기
	var hz := 2.6 if b.state != "flee" else 3.6
	var y := 0.0
	var sq := 1.0                         # 세로 배율 (내려앉을 때 납작)
	var t: float = _t * hz * TAU + float(nd["ph"])
	if moving:
		var hop := sin(t)
		y = maxf(0.0, hop) * 0.13 * s
		sq = 1.0 + 0.1 * maxf(0.0, hop) - 0.22 * clampf(-hop * 2.0, 0.0, 1.0) * 0.6
		var in_air := hop > 0.0
		if nd["was_air"] and not in_air:
			_puff(nd, s)
		nd["was_air"] = in_air
	elif b.state == "gnaw":
		var c := sin(_t * 7.0 + float(nd["ph"]))   # 갉작갉작 (앞으로 숙였다 폈다)
		pose.rotation.x = 0.12 + 0.1 * c
		sq = 1.0 - 0.05 * absf(c)
		if fposmod(_t * 0.7 + float(nd["ph"]), 2.0) < dt * 0.7:
			_puff(nd, s)
	else:
		sq = 1.0 + 0.035 * sin(_t * 2.2 + float(nd["ph"]))      # 숨쉬기
	if b.state != "gnaw":
		pose.rotation.x = 0.0
	var flat: float = nd["flat"]
	var br: float = nd["bristle"]
	sq *= lerpf(1.0, 0.62, flat)
	var wide := lerpf(1.0, 1.22, flat) * (1.0 + 0.08 * br)
	if b.burnt > 0.0:                     # 횃불에 그을림: 움찔 떨림
		pose.position.x = sin(_t * 60.0) * 0.015
		sq *= 0.9
	else:
		pose.position.x = 0.0
	pose.position.y = y
	pose.scale = Vector3(wide, sq * (1.0 + 0.06 * br), wide)
	root.scale = Vector3.ONE * s
	var sp: MeshInstance3D = nd["spikes"]
	sp.visible = br > 0.05
	sp.scale = Vector3.ONE * (0.4 + 0.6 * br)
	# 카메라 쪽을 본다 (점 눈이 보이게) — 걸을 땐 가는 쪽으로 조금 기욺
	var face := cam_yaw
	if moving:
		face = lerp_angle(cam_yaw, b.facing, 0.35)
	nd["yaw"] = lerp_angle(float(nd["yaw"]), face, 1.0 - exp(-8.0 * dt))
	root.rotation.y = nd["yaw"]
	if b.state == "tamed":
		root.rotation.z = sin(_t * 1.4 + float(nd["ph"])) * 0.08
	# 포자 가루: 떠올라 흩어짐
	for p: Dictionary in nd["puffs"]:
		var pt: float = p["t"]
		var n: MeshInstance3D = p["n"]
		if pt < 0.0:
			continue
		pt += dt
		p["t"] = pt
		if pt > 0.9:
			p["t"] = -1.0
			n.visible = false
			continue
		var o: Vector3 = p["o"]
		n.position = o * (0.6 + pt * 1.6) + Vector3(0, 0.05 + pt * 0.35, 0)
		n.scale = Vector3.ONE * (1.0 - pt / 0.9) * 1.2


func _puff(nd: Dictionary, s: float) -> void:
	var k := 0
	for p: Dictionary in nd["puffs"]:
		if float(p["t"]) < 0.0 and k < 3:
			var a := randf() * TAU
			p["t"] = 0.0
			p["o"] = Vector3(cos(a) * BODY_R * 1.3, 0.0, sin(a) * BODY_R * 1.3) / maxf(0.3, s)
			(p["n"] as MeshInstance3D).visible = true
			k += 1


## 사라진 털뭉치: 쪼그라들며 포자를 흩뿌리고 없어짐
func _vanish(nd: Dictionary, dt: float) -> void:
	var f: float = nd["fade"]
	if f >= 1.0:
		_puff(nd, 1.0)
	f -= dt / 0.5
	nd["fade"] = f
	var root: Node3D = nd["root"]
	root.scale = Vector3.ONE * maxf(0.001, float(nd["scale"]) * maxf(0.0, f))
	(nd["spikes"] as MeshInstance3D).visible = true


## 화면 위 털뭉치 수 (캡처·확인용)
func count() -> int:
	return nodes.size()
