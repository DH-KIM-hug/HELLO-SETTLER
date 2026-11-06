## 작은 위기 셋의 그림 — WORLD_EVENTS 2.2 (sim/small_crises.gd를 읽기만 한다). 모델: art/src/build_crises.py.
##  · 날벌레: 집채만 한 보송한 몸 + 점 눈 + 투명한 날개 둘 (빠르게 팔랑임 — 화면 시간). 맴돌 땐 높이, 먹을 땐 낮게 둥실. 땅에 작은 그림자.
##  · 떠돌이 물방울: 매달린 동안 하늘 높이 부풂 (출렁임) + 땅에 둥근 그림자 (부풀수록 짙어짐). 떨어지면 출렁이며 구르고 젖은 물자국을 남김.
##    터지면 물결 고리가 퍼짐. 반쯤 비치는 물 재질.
##  · 먼지 뭉치: 회색 솜뭉치가 데굴데굴 (구르는 쪽으로 돎 + 납작해졌다 부풂). 거인이 불면 움찔.
##  · 모깃불: 땅 위 작은 불씨 + 피어오르는 회색 연기 덩어리.
class_name CrisisView
extends Node3D

const GNAT_SCALE := 1.5                # 집채만 한 날벌레 (주민 키의 두 배 남짓)
const DUST_SCALE := 1.0
const HANG_Y := 6.5                   # 매달린 물방울 높이 (땅 위 칸)
const DROP_SCALE := 2.2               # 하늘에 매달린 거대한 물 덩어리
const TRAIL_MAX := 40

var v: Village
var alpha := 1.0
var nodes := {}                        # thing id → {root, pose, wl, wr, shadow, kind, fade, scale, yaw, roll}
var _t := 0.0
var _drop: Node3D
var _drop_body: Node3D
var _drop_shadow: MeshInstance3D
var _ring: MeshInstance3D
var _ring_t := -1.0
var _trail: Array = []                 # MeshInstance3D 물자국
var _trail_sig := ""
var _smokes: Array = []                # {root, puffs}
static var _disc: CylinderMesh
static var _puff: SphereMesh
static var _water_mat: StandardMaterial3D
static var _shadow_mat: StandardMaterial3D
static var _wet_mat: StandardMaterial3D
static var _smoke_mat: StandardMaterial3D
static var _ember_mat: StandardMaterial3D


func _init(village: Village) -> void:
	v = village
	name = "CrisisView"


func _gy(x: float, z: float) -> float:
	var p := get_parent()
	if p is VillageView:
		return (p as VillageView).gy(x, z)
	return 0.0


static func _mats() -> void:
	if _disc != null:
		return
	_disc = CylinderMesh.new()
	_disc.top_radius = 1.0
	_disc.bottom_radius = 1.0
	_disc.height = 0.01
	_disc.radial_segments = 24
	_disc.rings = 1
	_puff = SphereMesh.new()
	_puff.radius = 0.5
	_puff.height = 1.0
	_puff.radial_segments = 8
	_puff.rings = 4
	_water_mat = StandardMaterial3D.new()
	_water_mat.vertex_color_use_as_albedo = true
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.albedo_color = Color(0.82, 0.96, 1.0, 0.86)
	_water_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_water_mat.rim_enabled = false
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.albedo_color = Color(0.12, 0.2, 0.26, 0.28)
	_wet_mat = StandardMaterial3D.new()
	_wet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wet_mat.albedo_color = Color(0.32, 0.5, 0.56, 0.35)
	_smoke_mat = StandardMaterial3D.new()
	_smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_smoke_mat.albedo_color = Color(0.9, 0.9, 0.87, 0.72)
	_smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ember_mat = StandardMaterial3D.new()
	_ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ember_mat.albedo_color = Color("f0a040")
	_ember_mat.emission_enabled = true
	_ember_mat.emission = Color("f08a30")


func _ready() -> void:
	_mats()
	for nm: String in ["gnat_body", "gnat_wing", "water_drop", "dust_bunny"]:
		if Art.exists(nm):
			Art.model(nm)


func _disc_node(parent: Node3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _disc
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# ───────────────────────── 매 화면 ─────────────────────────
func sync(dt: float) -> void:
	_t += dt
	_mats()
	var s := v.smalls
	if s == null:
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cam_yaw := 0.0
	if cam != null:
		var f := cam.global_transform.basis.z
		cam_yaw = atan2(f.x, f.z)
	var seen := {}
	for c in s.things:
		if c.state == "gone":
			continue
		seen[c.id] = true
		var nd: Dictionary = nodes.get(c.id, {})
		if nd.is_empty():
			nd = _make(c)
			nodes[c.id] = nd
		if c.kind == "gnat":
			_pose_gnat(nd, c, dt, cam_yaw)
		else:
			_pose_dust(nd, c, dt, cam_yaw)
	for id in nodes.keys():
		if not seen.has(id):
			var nd: Dictionary = nodes[id]
			nd["fade"] = float(nd["fade"]) - dt / 0.6
			var root: Node3D = nd["root"]
			if String(nd["kind"]) == "gnat":
				root.position.y += dt * 4.0          # 날아 나감
			root.scale = Vector3.ONE * maxf(0.001, float(nd["scale"]) * maxf(0.0, float(nd["fade"])))
			if float(nd["fade"]) <= 0.0:
				root.queue_free()
				nodes.erase(id)
	_sync_drop(s, dt)
	_sync_smokes(s, dt)


func _make(c: CrisisThing) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var pose := Node3D.new()
	root.add_child(pose)
	var nd := {"root": root, "pose": pose, "kind": c.kind, "fade": 1.0, "scale": 0.0, "yaw": 0.0, "roll": 0.0, "ph": fposmod(c.id * 0.37, 1.0) * TAU}
	if c.kind == "gnat":
		if Art.exists("gnat_body"):
			Art.instance(pose, "gnat_body")
		else:
			_fallback(pose, Color("8a7a6a"), 0.45)
		for side in [-1.0, 1.0]:
			var root_w := Node3D.new()                       # 날개 뿌리: 등 위, 뒤로 비스듬히
			root_w.position = Vector3(side * 0.16, 0.36, 0.2)
			root_w.rotation.y = side * 0.55
			pose.add_child(root_w)
			var piv := Node3D.new()                          # 팔랑이는 축
			root_w.add_child(piv)
			if Art.exists("gnat_wing"):
				var w := Art.instance(piv, "gnat_wing")
				w.scale = Vector3(side, 1, 1)
				for mi: MeshInstance3D in w.find_children("*", "MeshInstance3D", true, false):
					mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					mi.transparency = 0.35
			nd["w%d" % int(side)] = piv
		var sh := _disc_node(root, _shadow_mat)
		nd["shadow"] = sh
	else:
		if Art.exists("dust_bunny"):
			Art.instance(pose, "dust_bunny")
		else:
			_fallback(pose, Color("a7a6a3"), 0.9)
	root.position = Vector3(c.x, _gy(c.x, c.y), c.y)
	return nd


func _fallback(parent: Node3D, col: Color, r: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = Toon.mat(col)
	mi.position.y = r
	parent.add_child(mi)


func _lerp_pos(c: CrisisThing) -> Vector2:
	if alpha < 1.0 and absf(c.x - c.px) + absf(c.y - c.py) < 3.0:
		return Vector2(lerpf(c.px, c.x, alpha), lerpf(c.py, c.y, alpha))
	return Vector2(c.x, c.y)


func _pose_gnat(nd: Dictionary, c: CrisisThing, dt: float, cam_yaw: float) -> void:
	var root: Node3D = nd["root"]
	var pose: Node3D = nd["pose"]
	var p := _lerp_pos(c)
	var gy := _gy(p.x, p.y)
	var ph: float = nd["ph"]
	var bob := sin(_t * 2.3 + ph) * 0.18
	root.position = Vector3(p.x, gy, p.y)
	pose.position.y = c.alt + 0.6 + bob
	nd["scale"] = lerpf(float(nd["scale"]), GNAT_SCALE, 1.0 - exp(-5.0 * dt))
	root.scale = Vector3.ONE * float(nd["scale"])
	var moving := Vector2(c.x - c.px, c.y - c.py).length() > 0.0005
	var face := c.facing if moving else cam_yaw
	nd["yaw"] = lerp_angle(float(nd["yaw"]), face, 1.0 - exp(-5.0 * dt))
	pose.rotation.y = float(nd["yaw"])                # 모델의 앞(Godot +Z)이 가는 쪽 (멈추면 카메라 쪽 — 점 눈이 보이게)
	pose.rotation.x = 0.12 if moving else 0.0
	# 날개 팔랑 (놀라면 더 빨리)
	var hz := 9.0 if c.startle <= 0.0 else 14.0
	var flap := sin(_t * hz * TAU + ph) * 0.7
	for side in [-1, 1]:
		var piv: Node3D = nd.get("w%d" % side)
		if piv != null:
			piv.rotation = Vector3(0.0, 0.0, float(side) * (0.25 + flap))
	var sh: MeshInstance3D = nd["shadow"]
	var k := clampf(1.0 - c.alt / 12.0, 0.15, 1.0)
	sh.position.y = 0.03
	sh.scale = Vector3(0.6 + 0.3 * k, 1, 0.6 + 0.3 * k)
	sh.transparency = 1.0 - k


func _pose_dust(nd: Dictionary, c: CrisisThing, dt: float, cam_yaw: float) -> void:
	var root: Node3D = nd["root"]
	var pose: Node3D = nd["pose"]
	var p := _lerp_pos(c)
	var prev := root.position
	root.position = Vector3(p.x, _gy(p.x, p.y), p.y)
	nd["scale"] = lerpf(float(nd["scale"]), DUST_SCALE * maxf(0.3, c.size), 1.0 - exp(-4.0 * dt))
	var s: float = nd["scale"]
	root.scale = Vector3.ONE * s
	var mv := Vector2(root.position.x - prev.x, root.position.z - prev.z)
	if mv.length() > 0.0002:
		nd["yaw"] = lerp_angle(float(nd["yaw"]), atan2(mv.x, mv.y), 1.0 - exp(-3.0 * dt))
		nd["roll"] = float(nd["roll"]) + mv.length() / maxf(0.3, s)     # 데굴데굴
	var ph: float = nd["ph"]
	var breathe := 1.0 + 0.04 * sin(_t * 1.6 + ph)
	if c.startle > 0.0:
		breathe *= 1.0 + 0.12 * sin(_t * 30.0)
	pose.scale = Vector3(1.0 / sqrt(breathe), breathe, 1.0 / sqrt(breathe))
	# 눈이 보이게 대체로 카메라 쪽 + 구르는 만큼 살짝 기울어 흔들림
	root.rotation.y = lerp_angle(cam_yaw, float(nd["yaw"]), 0.3)
	pose.rotation.x = sin(float(nd["roll"])) * 0.18


# ───────────────────────── 떠돌이 물방울 ─────────────────────────
func _sync_drop(s: SmallCrises, dt: float) -> void:
	if _drop == null:
		_drop = Node3D.new()
		add_child(_drop)
		_drop_body = Node3D.new()
		_drop.add_child(_drop_body)
		if Art.exists("water_drop"):
			var n := Art.instance(_drop_body, "water_drop")
			for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
				if mi.mesh == Art.model("water_drop")["mesh"]:
					mi.material_override = _water_mat
		else:
			_fallback(_drop_body, Color("8fd3dc"), 0.9)
		_drop_shadow = _disc_node(self, _shadow_mat)
		_ring = _disc_node(self, _wet_mat)
		_ring.visible = false
	var on := s.drop_phase != "calm"
	_drop.visible = on
	_drop_shadow.visible = s.drop_phase == "hang"
	var x := lerpf(s.drop_px, s.drop_x, alpha) if alpha < 1.0 else s.drop_x
	var z := lerpf(s.drop_py, s.drop_y, alpha) if alpha < 1.0 else s.drop_y
	var gy := _gy(x, z)
	if s.drop_phase == "hang":
		var sz := maxf(0.15, s.drop_size) * DROP_SCALE
		var wob := 1.0 + 0.05 * sin(_t * 3.1) * sz
		_drop.position = Vector3(x, gy + HANG_Y - 1.9 * sz * 1.15, z)     # 뾰족한 끝이 유리에 붙고 둥근 배가 아래로 처짐
		_drop_body.scale = Vector3(sz / wob, sz * wob * 1.15, sz / wob)
		_drop_shadow.position = Vector3(x, gy + 0.03, z)
		var rr := s.drop_radius()
		_drop_shadow.scale = Vector3(rr, 1, rr)
		_drop_shadow.transparency = 1.0 - clampf(0.25 + 0.75 * s.drop_size, 0.0, 1.0)
	elif s.drop_phase == "roll":
		var sz2 := maxf(0.4, s.drop_size) * DROP_SCALE * 0.75
		var w := sin(_t * 5.0)
		_drop.position = Vector3(x, gy, z)
		_drop_body.scale = Vector3(sz2 * (1.0 + 0.1 * w), sz2 * (0.72 - 0.08 * w), sz2 * (1.0 - 0.06 * w))
	_sync_trail(s, dt)
	# 터짐: 물결 고리가 퍼졌다 사라짐
	if not s.drop_splash.is_empty():
		var age := v.t - float(s.drop_splash["t"])
		if age >= 0.0 and age < 600.0:
			var k := age / 600.0
			var rr2 := float(s.drop_splash["r"]) * (0.4 + 1.0 * k)
			_ring.visible = true
			_ring.position = Vector3(float(s.drop_splash["x"]), _gy(float(s.drop_splash["x"]), float(s.drop_splash["y"])) + 0.04, float(s.drop_splash["y"]))
			_ring.scale = Vector3(rr2, 1, rr2)
			_ring.transparency = k
		else:
			_ring.visible = false


## 구른 자리의 젖은 물자국 (시간이 지나면 마름 — 하루)
func _sync_trail(s: SmallCrises, _dt: float) -> void:
	var sig := "%d:%s" % [s.drop_trail.size(), str(s.drop_trail.back()) if not s.drop_trail.is_empty() else ""]
	if sig != _trail_sig:
		_trail_sig = sig
		while _trail.size() < mini(TRAIL_MAX, s.drop_trail.size()):
			_trail.append(_disc_node(self, _wet_mat))
		for i in _trail.size():
			var mi: MeshInstance3D = _trail[i]
			var j := s.drop_trail.size() - 1 - i
			if j < 0:
				mi.visible = false
				continue
			var p: Array = s.drop_trail[j]
			mi.visible = true
			mi.position = Vector3(float(p[0]), _gy(float(p[0]), float(p[1])) + 0.02 + 0.001 * i, float(p[1]))
			var r := 0.9 + 0.25 * fposmod(i * 0.618, 1.0)
			mi.scale = Vector3(r, 1, r * 0.8)
			mi.set_meta("t", float(p[2]))
	for mi: MeshInstance3D in _trail:
		if mi.visible and mi.has_meta("t"):
			mi.transparency = clampf((v.t - float(mi.get_meta("t"))) / Balance.DAY, 0.0, 1.0)


# ───────────────────────── 모깃불 ─────────────────────────
func _sync_smokes(s: SmallCrises, dt: float) -> void:
	while _smokes.size() < s.smokes.size():
		var root := Node3D.new()
		add_child(root)
		var ember := MeshInstance3D.new()
		ember.mesh = _puff
		ember.material_override = _ember_mat
		ember.scale = Vector3(0.35, 0.15, 0.35)
		root.add_child(ember)
		var puffs: Array = []
		for i in 6:
			var p := MeshInstance3D.new()
			p.mesh = _puff
			p.material_override = _smoke_mat
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(p)
			puffs.append(p)
		_smokes.append({"root": root, "puffs": puffs})
	for i in _smokes.size():
		var sm: Dictionary = _smokes[i]
		var root: Node3D = sm["root"]
		if i >= s.smokes.size():
			root.visible = false
			continue
		var d: Dictionary = s.smokes[i]
		root.visible = true
		var x := float(d["x"])
		var z := float(d["y"])
		root.position = Vector3(x, _gy(x, z), z)
		var puffs: Array = sm["puffs"]
		for k in puffs.size():
			var p: MeshInstance3D = puffs[k]
			var ph := fposmod(_t * 0.25 + k / float(puffs.size()), 1.0)
			p.position = Vector3(sin(k * 2.1 + _t * 0.4) * 0.3 * ph, 0.3 + ph * 3.2, cos(k * 1.7) * 0.25 * ph)
			p.scale = Vector3.ONE * (0.35 + ph * 1.1)
			p.transparency = ph * 0.9
	if dt < 0.0:
		pass


## 화면 위 작은 것 수 (캡처·확인용)
func count() -> int:
	return nodes.size()
