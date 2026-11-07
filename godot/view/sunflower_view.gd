## 초거대 해바라기·씨앗비·목화 화면 (design/gdd/flower-forest.md Visual · R3·R4, ROADMAP F-2) — WorldWater.sunflowers·sf_seeds·cotton.
## 마을 확대 (ppu ≥ FAR_PPU): 주민 대여섯 폭의 줄기 기둥 + 잎 — 6칸 위는 엷어지는 재질(render/toon_fade.gdshader, 아트 바이블 겹 2)로
##   그 아래 마을이 보이게 — 와 땅 위 꽃판 그림자 (꽃잎 고리 + 씨앗 원판 실루엣 데칼) + 줄기·잎 그림자 (GD 3.0).
## 멀리 (거인의 방·세상 전체): 멀리 LOD 줄기 + 밝은 꽃판 (하늘 쪽으로 74° 들어 등불 쪽으로 고개, 가을엔 숙임).
## 그림자는 모두 데칼 — 시뮬레이션 F1 자리 (GiantPlants.shadow_center): 높이 h의 점은 줄기에서 −head_dir × SF_SHADOW_OFF × h/꽃판 높이.
##   (해바라기 몸은 진짜 그림자를 드리우지 않는다 — 시뮬 그늘과 어긋나지 않게. 몸은 SF_LAYER 층이라 자기 데칼을 받지 않음.)
## 씨앗비: 떨어지기 SEED_WARN 전부터 땅 위 작은 그림자가 커지고 → 씨앗이 내려와 박힘 + 먼지 → 땅 위 씨앗 (굴리면 굴러감).
class_name SunflowerView
extends Node3D

const SCALE := 0.6                # 모델 (줄기 85) → 51칸 = 주민 키 51배 (GD 3.0 40~60배)
const MODEL := "flora/giant_sunflower"
const STALK_R := 4.0              # 모델 줄기 반지름 (그림자 띠 폭, build_sunflower STALK_R0~R1 사이)
## 잎 (build_sunflower.py LEAF_SPEC 거울): [높이 몫, 방위 (블렌더 XY, rad), 길이, 반폭] — 잎 그림자 자리
const LEAVES := [[0.20, 0.4, 24.0, 9.0], [0.33, 2.6, 22.0, 8.4], [0.46, 4.6, 20.0, 7.6], [0.60, 1.4, 17.0, 6.6], [0.73, 3.6, 14.0, 5.4]]
const FADE_FROM := 6.0            # 칸 (세상) — 여기서부터 엷어짐 (밀 숲과 같은 겹 2)
const FADE_TO := 16.0
const FADE_MIN := 0.4             # 줄기
const FADE_MIN_LEAF := 0.2        # 잎·꽃판 — 넓어서 더 많이 비움
const LEAF_FADE_FROM := 2.0
const LEAF_FADE_TO := 8.0
const RING_K := 2.6               # 꽃잎 끝 반지름 = 그늘 반지름(shadow_r) × 이것 (모델 꽃판 반지름 14.4 ≈ 5 × 2.6, 원판 ≈ 시뮬 그늘)
const SF_LAYER := 1 << 10         # 해바라기 몸의 렌더 층 (층 11) — 그림자 데칼이 줄기에 번지지 않게
const SF_SHADOW := Color(0.07, 0.14, 0.2, 0.68)   # 꽃판·줄기·잎 그림자 (원판은 텍스처 알파 1, 꽃잎 0.88)
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
static var _ring_tex: Texture2D
static var _band_tex: Texture2D
static var _leaf_tex: Texture2D
static var _fade_mat: ShaderMaterial
static var _fade_leaf_mat: ShaderMaterial
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


static func _part(parent: Node3D, model: String, pn: String, giant := false) -> MeshInstance3D:
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
	if giant:                                     # 초거대 해바라기: 그림자는 데칼만, 자기 데칼을 받지 않음
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.layers = SF_LAYER
		for c in mi.get_children():
			(c as VisualInstance3D).layers = SF_LAYER
	return mi


## 마을 확대의 줄기·잎·꽃판: 세상 높이 FADE_FROM 위로 디더로 엷어짐 (선은 남김 — 아트 바이블 겹 2). 셰이더 높이는 모델 칸이라 ÷SCALE.
static func fade_mat(leaf := false) -> ShaderMaterial:
	if _fade_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://render/toon_fade.gdshader")
		Toon._light(m)
		m.set_shader_parameter("view_fill", Style.VIEW_FILL)
		m.set_shader_parameter("fade_from", FADE_FROM / SCALE)
		m.set_shader_parameter("fade_to", FADE_TO / SCALE)
		m.set_shader_parameter("min_alpha", FADE_MIN)
		_fade_mat = m
		_fade_leaf_mat = m.duplicate() as ShaderMaterial
		_fade_leaf_mat.set_shader_parameter("min_alpha", FADE_MIN_LEAF)
		_fade_leaf_mat.set_shader_parameter("fade_from", LEAF_FADE_FROM / SCALE)    # 잎은 넓은 덮개 — 맨 아래 잎(10칸)부터 엷게
		_fade_leaf_mat.set_shader_parameter("fade_to", LEAF_FADE_TO / SCALE)
	return _fade_leaf_mat if leaf else _fade_mat


static func _aa(d: float, px: float) -> float:
	return clampf(0.5 - d / px, 0.0, 1.0)


## 꽃판 그림자: 씨앗 원판(알파 1) + 꽃잎 두 겹 고리(0.82) — 위에서 본 꽃판 실루엣. 흰색 + 알파 (색은 데칼 modulate)
static func ring_tex() -> Texture2D:
	if _ring_tex == null:
		const N := 256
		const DISC := 0.47
		var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
		var px := 2.0 / N * 1.4
		var rings := [[26, 1.0, 0.0, 0.5], [22, 0.86, 0.5, 0.56]]     # [꽃잎 수, 끝 반지름, 위상, 반폭 몫]
		for y in N:
			for x in N:
				var q := Vector2((x + 0.5) / N * 2.0 - 1.0, (y + 0.5) / N * 2.0 - 1.0) / 0.98
				var r := q.length()
				var a := q.angle()
				var al := _aa(r - DISC, px)
				if r > DISC - 0.02 and r < 1.02:
					for ring: Array in rings:
						var sec: float = TAU / int(ring[0])
						var ph: float = a / sec - float(ring[2])
						var off: float = (ph - roundf(ph)) * sec
						var t: float = (r - DISC * 0.8) / (float(ring[1]) - DISC * 0.8)
						if t < 0.0 or t > 1.0:
							continue
						var hw: float = float(ring[3]) * sec * pow(sin(PI * clampf(t * 0.92 + 0.04, 0.0, 1.0)), 0.75)
						al = maxf(al, 0.88 * _aa((absf(off) - hw) * r, px))
				img.set_pixel(x, y, Color(1, 1, 1, al))
		img.generate_mipmaps()
		_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


## 줄기 그림자 띠: 가로로 또렷한 가장자리, 세로로 끝까지 (데칼 z = 띠 방향)
static func band_tex() -> Texture2D:
	if _band_tex == null:
		var img := Image.create(32, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 32:
				var u := absf((x + 0.5) / 32.0 * 2.0 - 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, _aa(u - 0.86, 0.12)))
		_band_tex = ImageTexture.create_from_image(img)
	return _band_tex


## 하트 잎 그림자 (v = 잎자루 → 잎끝, 데칼 z)
static func leaf_tex() -> Texture2D:
	if _leaf_tex == null:
		const W := 48
		const L := 96
		var img := Image.create(W, L, false, Image.FORMAT_RGBA8)
		for y in L:
			var v := (y + 0.5) / L
			var hw := sin(PI * minf(1.0, v * 1.15)) * (1.0 if v < 0.9 else 0.4 + 6.0 * (1.0 - v))
			hw = 0.95 * hw if v > 0.08 else 0.12
			for x in W:
				var u := absf((x + 0.5) / W * 2.0 - 1.0)
				var a := _aa(u - hw, 0.06)
				if u < 0.04 and v > 0.1 and v < 0.85:
					a *= 0.75                                  # 잎맥 한 줄
				img.set_pixel(x, y, Color(1, 1, 1, a))
		img.generate_mipmaps()
		_leaf_tex = ImageTexture.create_from_image(img)
	return _leaf_tex


func _decal(sz: float, tex: Texture2D = null, col := SHADOW_COLOR) -> Decal:
	var dc := Decal.new()
	dc.texture_albedo = tex if tex != null else shadow_tex()
	dc.modulate = col
	dc.size = Vector3(sz, 60.0, sz)
	dc.upper_fade = 0.2
	dc.lower_fade = 0.2
	dc.albedo_mix = 1.0
	dc.cull_mask = 0xFFFFF & ~SF_LAYER
	add_child(dc)
	return dc


## 땅 위 데칼 하나를 a → b 띠로 (폭 w): 데칼 z축이 a→b
func _lay(dc: Decal, a: Vector2, b: Vector2, w: float) -> void:
	var d := b - a
	var ln := d.length()
	dc.visible = ln > 0.05
	if not dc.visible:
		return
	var m := (a + b) * 0.5
	dc.position = Vector3(m.x, gy(m.x, m.y), m.y)
	dc.rotation = Vector3(0.0, atan2(d.x, d.y), 0.0)
	dc.size = Vector3(w, 60.0, ln)


func _build() -> void:
	for f: Dictionary in _flowers:
		(f["root"] as Node3D).queue_free()
		(f["shadow"] as Node3D).queue_free()
		(f["band"] as Node3D).queue_free()
		for dl: Node3D in f["leaves"]:
			dl.queue_free()
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
		var heads := {}
		for pn: String in ["stalk", "leaves", "head", "head_dry"]:
			var mi := _part(near, MODEL, pn, true)
			if mi != null:
				mi.material_override = fade_mat(pn != "stalk")    # 6칸 위로 엷어짐 — 꽃판은 대개 화면 위 밖, 들어와도 엷게
				if pn.begins_with("head"):
					heads[pn] = mi
		var far := Node3D.new()
		far.name = "far"
		root.add_child(far)
		for pn: String in ["stalk__far", "leaves__far", "head__far", "head_dry__far"]:
			var mi := _part(far, MODEL, pn, true)
			if mi != null and pn.begins_with("head"):
				heads[pn] = mi
		var lv: Array = []
		for k in LEAVES.size():
			lv.append(_decal(1.0, leaf_tex(), SF_SHADOW))
		_flowers.append({"root": root, "near": near, "far": far, "heads": heads, "id": int(sf["id"]),
			"band": _decal(1.0, band_tex(), SF_SHADOW), "leaves": lv, "shadow": _decal(1.0, ring_tex(), SF_SHADOW)})
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
			h.visible = pn.begins_with("head_dry") == dry and st != "grow"
			h.rotation = Vector3(1.3 if dry else 0.0, yaw, 0.0)     # 가을엔 숙임 (얼굴이 땅 쪽으로)
		_sync_shadow(f, sf, t, d, dry)
	_sync_seeds(t)
	_sync_cotton()


## 꽃판·줄기·잎 그림자 — 높이 h의 점은 줄기에서 −d × SF_SHADOW_OFF × h / 꽃판 높이 (F1과 같은 빛)
func _sync_shadow(f: Dictionary, sf: Dictionary, t: float, d: Vector2, dry: bool) -> void:
	var foot := Vector2(sf["x"], sf["y"])
	var c := GiantPlants.shadow_center(sf, t)
	var r := GiantPlants.shadow_r(sf)
	var off := c - foot                             # 꽃판 높이의 점이 밀리는 만큼
	var ring: Decal = f["shadow"]
	ring.position = Vector3(c.x, gy(c.x, c.y), c.y)
	ring.rotation = Vector3(0.0, atan2(d.x, d.y) + float(sf.get("yaw", 0.0)), 0.0)   # 고개를 돌리면 꽃잎 무늬도 돈다
	var squash := 0.62 if dry else 1.0             # 숙인 꽃판은 납작한 그림자
	ring.size = Vector3(r * RING_K * 2.0, 60.0, r * RING_K * 2.0 * squash)
	_lay(f["band"], foot, c, STALK_R * SCALE * 2.0)
	var lv: Array = f["leaves"]
	var bare := String(sf.get("stage", "bloom")) == "dry"
	for k in LEAVES.size():
		var spec: Array = LEAVES[k]
		var az: float = spec[1]
		var dir := Vector2(cos(az), -sin(az))         # 블렌더 XY → 고도 XZ
		var base := foot + off * float(spec[0]) + dir * STALK_R * SCALE * 0.8
		var tip := base + dir * float(spec[2]) * SCALE * 0.9 + off * 0.03
		var dl: Decal = lv[k]
		_lay(dl, base, tip, float(spec[3]) * SCALE * 2.0)
		dl.visible = dl.visible and not bare


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
