## 초거대 해바라기·씨앗비·목화 화면 (design/gdd/flower-forest.md Visual · R3·R4, ROADMAP F-2) — WorldWater.sunflowers·sf_seeds·cotton.
## 마을 확대 (ppu ≥ FAR_PPU): 굵은 줄기 기둥 + 잎 + 땅 위 커다란 꽃판 그림자(데칼)만 — 꽃판은 화면 위로 사라진다 (GD 3.0).
## 멀리 (거인의 방·세상 전체): 멀리 LOD 줄기 + 꽃판 (등불 쪽으로 고개, 가을엔 숙임). 그림자는 시뮬레이션 F1 자리 (GiantPlants.shadow_center).
## 씨앗비: 떨어지기 SEED_WARN 전부터 땅 위 작은 그림자가 커지고 → 씨앗이 내려와 박힘 + 먼지 → 땅 위 씨앗 (굴리면 굴러감).
class_name SunflowerView
extends Node3D

const SCALE := 0.6                # 모델 (줄기 80) → 48칸
const FAR_PPU := 4.0
const LOD_GAP := 0.5
const FALL := 360.0               # 마지막 병 6분 (보통 배속 현실 1.25초)에 하늘에서 내려옴
const DUST := 900.0               # 박힌 뒤 먼지 (병 15분)
const SEED_SCALE := 0.8
const COTTON_SCALE := 0.6
const SHADOW_COLOR := Color(0.1, 0.12, 0.2, 0.58)

var ww: WorldWater
var terrain: JarTerrain
var src: Callable                 # () -> Village (시각·철)
var far_lod := false
var force_lod := -1               # −1 확대 따라 · 0 늘 가까이 · 1 늘 멀리 (캡처·시험)
var _flowers: Array = []          # [{root, near, far, head, shadow}]
var _seeds := {}                  # id → {node, decal, dust}
var _cotton_key := ""
var _cotton_root: Node3D
static var _shadow_tex: Texture2D
static var _dust_mat: StandardMaterial3D


func _init(w: WorldWater, t: JarTerrain, s: Callable = Callable()) -> void:
	ww = w
	terrain = t
	src = s
	name = "Sunflowers"


func _ready() -> void:
	_cotton_root = Node3D.new()
	_cotton_root.name = "Cotton"
	add_child(_cotton_root)
	_build()
	sync(0.0)


func _process(dt: float) -> void:
	sync(dt)


func now() -> float:
	var v: Village = src.call() if src.is_valid() else null
	return v.t if v != null else 0.0


func view_ppu() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL or cam.size <= 0.0:
		return 16.0
	return float(vp.get_visible_rect().size.y) / cam.size


func gy(x: float, z: float) -> float:
	return terrain.ground_y(x, z) if terrain != null else 0.0


static func shadow_tex() -> Texture2D:
	if _shadow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.72, Color(1, 1, 1, 0.9))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 128
		gt.height = 128
		_shadow_tex = gt
	return _shadow_tex


static func _part(parent: Node3D, model: String, pn: String) -> MeshInstance3D:
	var parts := Art.parts(model)
	if not parts.has(pn):
		return null
	var pd: Dictionary = parts[pn]
	var mi := MeshInstance3D.new()
	mi.name = pn
	mi.mesh = pd["mesh"]
	mi.material_override = Art.body_mat()
	mi.position = pd["origin"]
	parent.add_child(mi)
	if pd["lines"] != null and not pn.ends_with("__far"):
		var li := MeshInstance3D.new()
		li.mesh = pd["lines"]
		li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(li)
	return mi


func _decal(sz: float) -> Decal:
	var dc := Decal.new()
	dc.texture_albedo = shadow_tex()
	dc.modulate = SHADOW_COLOR
	dc.size = Vector3(sz, 60.0, sz)
	dc.upper_fade = 0.2
	dc.lower_fade = 0.2
	dc.albedo_mix = 1.0
	add_child(dc)
	return dc


func _build() -> void:
	for f: Dictionary in _flowers:
		(f["root"] as Node3D).queue_free()
		(f["shadow"] as Node3D).queue_free()
	_flowers.clear()
	for sf: Dictionary in ww.sunflowers:
		var root := Node3D.new()
		root.name = "Sunflower%d" % int(sf["id"])
		var x := float(sf["x"])
		var z := float(sf["y"])
		root.position = Vector3(x, gy(x, z) - 0.4, z)
		root.scale = Vector3.ONE * SCALE
		add_child(root)
		var near := Node3D.new()
		near.name = "near"
		root.add_child(near)
		_part(near, "flora/giant_sunflower", "stalk")
		_part(near, "flora/giant_sunflower", "leaves")
		var far := Node3D.new()
		far.name = "far"
		root.add_child(far)
		_part(far, "flora/giant_sunflower", "stalk__far")
		_part(far, "flora/giant_sunflower", "leaves__far")
		var heads := {}
		for pn: String in ["head__far", "head_dry__far"]:
			var h := _part(far, "flora/giant_sunflower", pn)
			if h != null:
				heads[pn] = h
		_flowers.append({"root": root, "near": near, "far": far, "heads": heads, "shadow": _decal(Balance.SF_HEAD_R * 2.0), "id": int(sf["id"])})
	_apply_lod()


func _apply_lod() -> void:
	for f: Dictionary in _flowers:
		(f["near"] as Node3D).visible = not far_lod
		(f["far"] as Node3D).visible = far_lod


func lod_check() -> void:
	var want := far_lod
	if force_lod >= 0:
		want = force_lod == 1
	else:
		var p := view_ppu()
		if p < FAR_PPU:
			want = true
		elif p > FAR_PPU + LOD_GAP:
			want = false
	if want != far_lod:
		far_lod = want
		_apply_lod()


func sync(_dt: float) -> void:
	if _flowers.size() != ww.sunflowers.size():
		_build()
	lod_check()
	var t := now()
	for i in _flowers.size():
		var f: Dictionary = _flowers[i]
		var sf: Dictionary = ww.sunflowers[i]
		var d := GiantPlants.head_dir(sf, t)
		var st := String(sf.get("stage", "bloom"))
		var dry := st == "droop" or st == "dry"
		var yaw := atan2(d.x, d.y)
		for pn: String in f["heads"]:
			var h: MeshInstance3D = f["heads"][pn]
			h.visible = (pn == "head_dry__far") == dry and st != "grow"
			h.rotation = Vector3(0.6 if dry else 0.0, yaw, 0.0)     # 가을엔 숙임
		var c := GiantPlants.shadow_center(sf, t)
		var r := GiantPlants.shadow_r(sf)
		var dc: Decal = f["shadow"]
		dc.position = Vector3(c.x, gy(c.x, c.y), c.y)
		dc.size = Vector3(r * 2.2, 60.0, r * 2.2)
	_sync_seeds(t)
	_sync_cotton()


func _sync_seeds(t: float) -> void:
	var seen := {}
	for s: Dictionary in ww.sf_seeds:
		var id := int(s["id"])
		var x := float(s["x"])
		var z := float(s["y"])
		var left := float(s["t_land"]) - t
		if s["st"] == "sky" and left > Balance.SEED_WARN:
			continue
		seen[id] = true
		var e: Dictionary = _seeds.get(id, {})
		if e.is_empty():
			var n := Art.instance(self, "flora/sunflower_seed", Transform3D(Basis(Vector3.UP, float(s.get("yaw", 0.0))).scaled(Vector3.ONE * SEED_SCALE), Vector3(x, gy(x, z), z)))
			var dc := _decal(1.0)
			var dust := Node3D.new()
			add_child(dust)
			for k in 6:
				var mi := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.6
				sm.height = 1.0
				sm.radial_segments = 8
				sm.rings = 4
				mi.mesh = sm
				mi.material_override = dust_mat()
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				dust.add_child(mi)
			e = {"node": n, "decal": dc, "dust": dust}
			_seeds[id] = e
		var node: Node3D = e["node"]
		var dcl: Decal = e["decal"]
		var dust_n: Node3D = e["dust"]
		var g := gy(x, z)
		if s["st"] == "sky":
			var k := clampf(1.0 - left / Balance.SEED_WARN, 0.0, 1.0)
			dcl.visible = true
			dcl.position = Vector3(x, g, z)
			dcl.size = Vector3(0.6 + 2.4 * k, 60.0, 0.6 + 2.4 * k)
			dcl.modulate = Color(SHADOW_COLOR, 0.25 + 0.4 * k)
			var fall := clampf(left / FALL, 0.0, 1.0)
			node.visible = left < FALL
			node.position = Vector3(x, g + fall * fall * 40.0, z)
			node.rotation = Vector3(fall * 6.0, float(s.get("yaw", 0.0)) + fall * 4.0, 0.0)
			dust_n.visible = false
		else:
			dcl.visible = false
			node.visible = true
			var rolling: bool = s["st"] == "roll"
			node.position = Vector3(x, g + (0.25 if rolling else -0.15), z)
			node.rotation = Vector3(0.0, float(s.get("yaw", 0.0)), (t * 0.02) if rolling else 0.35)
			var age := t - float(s.get("landed", t))
			dust_n.visible = age < DUST
			if dust_n.visible:
				var u := clampf(age / DUST, 0.0, 1.0)
				for k in dust_n.get_child_count():
					var mi := dust_n.get_child(k) as MeshInstance3D
					var a := k * TAU / 6.0
					mi.position = Vector3(x + cos(a) * (0.6 + 2.2 * u), g + 0.3 + 0.8 * u, z + sin(a) * (0.6 + 2.2 * u))
					mi.scale = Vector3.ONE * (0.7 + 1.6 * u) * (1.0 - u * 0.5)
					mi.transparency = u
	for id: int in _seeds.keys():
		if not seen.has(id):
			for k: String in ["node", "decal", "dust"]:
				(_seeds[id][k] as Node).queue_free()
			_seeds.erase(id)


static func dust_mat() -> StandardMaterial3D:
	if _dust_mat == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.86, 0.78, 0.62, 0.7)
		_dust_mat = m
	return _dust_mat


func _sync_cotton() -> void:
	var key := ""
	for b: Dictionary in ww.cotton:
		key += "%d%s," % [int(b["id"]), "b" if b.get("boll", false) else ""]
	if key == _cotton_key:
		return
	_cotton_key = key
	for c in _cotton_root.get_children():
		c.queue_free()
	for b: Dictionary in ww.cotton:
		var x := float(b["x"])
		var z := float(b["y"])
		var n := Node3D.new()
		n.position = Vector3(x, gy(x, z) - 0.1, z)
		n.rotation.y = float(b.get("yaw", 0.0))
		n.scale = Vector3.ONE * COTTON_SCALE
		_cotton_root.add_child(n)
		_part(n, "flora/cotton_bush", "bush")
		if b.get("boll", false):
			_part(n, "flora/cotton_bush", "boll")
