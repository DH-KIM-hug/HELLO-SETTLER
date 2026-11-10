## 하늘의 것 그림 — 큰 버섯 · 큰 민들레 · 날리는 꽃씨 (WORLD_EVENTS 1.1 · 2.6 · 2.7).
## 기준 그림: design/concept/small_world/giant_mushrooms_b.png · dandelion_seeds_b.png.
## 바깥의 생물은 거인 세상의 진짜 크기 — 같은 셀 채색 그림체로 '크기만 다르게', 결은 크고 단순하게 (가까이서 본 진짜 버섯·꽃처럼).
##   흰갓버섯: 나무보다 큰 흰 갓 (아래 주름 · 대의 턱받이 · 갓 위 물방울) · 부채버섯: 회청색 부채가 층층이 · 갈색갓버섯: 집채만 한 갈라진 갈색 갓 ·
##   얼룩버섯: 붉은 갓에 흰 점 · 빛버섯: 무릎만 한 푸르스름한 갓 세 개 — 밤에 은은히 빛남 (발밑에 빛 웅덩이).
##   민들레: 톱니 잎 방석 + 주민 서너 배 줄기 + 해만 한 노란 꽃 / 닫힌 꽃봉오리 / 하얀 솜털 공 (꽃씨가 줄면 듬성듬성) · 꽃씨: 작은 우산 (MultiMesh).
## 시뮬레이션(sim/flora.gd)은 읽기만. 자람·시듦·피어남·흔들림은 화면 시간으로 부드럽게. 꽃씨는 5초 걸음 사이를 보간 + 살랑임.
class_name FloraView
extends Node3D

const SEED_SIZE := 0.42                     # 꽃씨 우산 지름 (칸) — 주민 키의 절반이 조금 안 됨
const WHITE := Color("f2eee4")
const WHITE_SH := Color("d9d2c2")
const GILL := Color("cfc3ad")
const STEM := Color("efe9dc")
const FAN := Color("9fb1b8")
const FAN_DARK := Color("7f939c")
const BROWN := Color("8a5a36")
const BROWN_LIGHT := Color("b98552")
const CRACK := Color("e8d3ae")
const RED := Color("d2442f")
const RED_DARK := Color("a8321f")
const SPOT := Color("f6f0e2")
const GLOW_CAP := Color("bfe8ef")
const GLOW_STEM := Color("e4f2f0")
const LEAF := Color("5f9a3a")
const LEAF_DARK := Color("4a7d2c")
const D_STEM := Color("8fbf55")
const YELLOW := Color("f6c624")
const YELLOW_DARK := Color("e09a16")
const BUD := Color("6f9f3c")
const FLUFF := Color("f7f5ee")
const FLUFF_CORE := Color("cbb58a")
const DROP := Color("cdeef2")

## Blender 모델 (art/src/build_giants.py → art/models/*.glb)이 있으면 그것을 씀 (없으면 아래 절차 메시)
const ART_SHROOM := {"흰갓버섯": "great_white", "갈색갓버섯": "great_brown", "얼룩버섯": "great_red", "부채버섯": "great_fan", "빛버섯": "great_glow"}
const ART_DAND := {"flower": "dand_flower", "closed": "dand_closed", "puff": "dand_puff", "bare": "dand_bare"}

static var _meshes: Dictionary = {}
static var _glow_mat: ShaderMaterial
static var _night_cap: ShaderMaterial

const DAND_TALL := 3.3                      # (Q6) 민들레 그림 키 어림: 꽃대 + 머리 (dand_stem 2.41 + 머리 반)
const DAND_LEAF := 3.0                      # 잎 방석 그림 (dand_rosette) · 어린 것 (dand_rosette_small)
const DAND_LEAF_SMALL := 1.2
const DAND_HALF_W := 0.8                    # 잎 방석 폭의 ¼ (꽃·풀과 같은 어림 — BldEcon.apron_scale)
const DAND_DF := 1.66                       # 잎 방석 그림 밑변이 원점보다 카메라 쪽으로 나오는 거리 (dand_rosette front)

var v: Village
var alpha := 1.0
var _t := 0.0
var _sh := {}                               # 버섯 id → {root, body, glow, scale, kind}
var _dd := {}                               # 민들레 id → {root, head, leaves, st, open}
var _seeds: MultiMeshInstance3D
var _rider_seeds := {}                      # 주민 id → 큰 꽃씨 (매달린 아이)
var _weeds: Node3D
var _weed_key := ""
var _racks: Node3D
var _rack_key := ""
var night := 0.0                            # 장면이 넣어 줌 (0~1)
## (2D 그림책 — view/flora2d, RENDERING.md 확정 2026-11-08) 큰 버섯·민들레(잎 방석·줄기·머리 네 단계)·꽃씨 = 그림. 3D 메시는 그림자 대역
## (SHADOWS_ONLY). 자람·시듦·피어남·부풂은 노드 배율 그대로 (그림 판이 부모 배율을 따름). 꽃씨는 그림 MultiMesh 하나.
var pics2d := false


func _init(village: Village) -> void:
	v = village


func _ready() -> void:
	pics2d = Flora2D.enabled()
	_seeds = Flora2D.new_multi("giants", "seeds2d") if pics2d else MultiMeshInstance3D.new()
	var mm := _seeds.multimesh if pics2d else MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	if not pics2d:
		mm.mesh = seed_mesh()
	mm.instance_count = Balance.SEED_MAX
	mm.visible_instance_count = 0
	_seeds.multimesh = mm
	if not pics2d:
		_seeds.material_override = Toon.vc_mat()
	_seeds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_seeds)
	_weeds = Node3D.new()
	add_child(_weeds)
	_racks = Node3D.new()
	add_child(_racks)


# ───────────────────────── 도형 도우미 ─────────────────────────
static func _sphere(r: float, rings := 8, segs := 12) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.rings = rings
	s.radial_segments = segs
	return s


static func _hemi(r: float, rings := 6, segs := 16) -> SphereMesh:
	var s := _sphere(r, rings, segs)
	s.is_hemisphere = true
	s.height = r
	return s


static func _cyl(r_top: float, r_bot: float, h: float, segs := 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


static func _xf(pos: Vector3, scale := Vector3.ONE, basis := Basis()) -> Transform3D:
	return Transform3D(_ls(basis, scale), pos)


## 기저의 자기 축으로 늘리기 (Basis.scaled는 세상 축으로 늘려서 돌린 도형이 일그러짐)
static func _ls(b: Basis, s: Vector3) -> Basis:
	return b * Basis.from_scale(s)


## 대: 아래가 굵고 위로 가늘어지는 기둥 (마디 몇 개 — 살짝 휨)
static func _stalk(st: SurfaceTool, base: Vector3, h: float, r0: float, r1: float, c: Color, bend := 0.0, segs := 12, parts := 4) -> Vector3:
	var p := base
	for i in parts:
		var u0 := float(i) / parts
		var u1 := float(i + 1) / parts
		var hh := h / parts
		var ra := lerpf(r0, r1, u0)
		var rb := lerpf(r0, r1, u1)
		var off := Vector3(bend * (u1 * u1 - u0 * u0) * h * 0.08, 0, 0)
		var mid := p + Vector3(off.x * 0.5, hh * 0.5, 0)
		var tilt := atan2(off.x, hh)
		Toon.append(st, _cyl(rb, ra, hh * 1.04, segs), Transform3D(Basis(Vector3(0, 0, 1), -tilt), mid), c.darkened(0.03 * i))
		p += Vector3(off.x, hh, 0)
	return p


# ───────────────────────── 버섯 메시 (종류마다 한 번, 키 = Balance.SHROOM h) ─────────────────────────
static func shroom_mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	if Art.exists(ART_SHROOM.get(kind, "")):
		_meshes[kind] = Art.model(ART_SHROOM[kind])["mesh"]
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var d: Dictionary = Balance.SHROOM[kind]
	var h: float = d["h"]
	var cr: float = d["cap_r"]
	match kind:
		"흰갓버섯":
			Toon.append(st, _sphere(0.95, 6, 14), _xf(Vector3(0, 0.35, 0), Vector3(1.0, 0.55, 1.0)), STEM.darkened(0.05))     # 밑동 불룩
			var top := _stalk(st, Vector3(0, 0.2, 0), h - 1.25, 0.82, 0.62, STEM, 0.4, 14)
			Toon.append(st, _cyl(0.66, 1.05, 0.42, 16), _xf(top - Vector3(0, 1.1, 0)), WHITE_SH)             # 턱받이 (치마)
			Toon.append(st, _cyl(1.05, 1.12, 0.12, 16), _xf(top - Vector3(0, 1.32, 0)), WHITE_SH.darkened(0.06))
			Toon.append(st, _cyl(0.4, cr * 0.96, 0.32, 24), _xf(top + Vector3(0, 0.05, 0)), GILL)            # 갓 아래 주름
			Toon.append(st, _hemi(cr, 7, 24), _xf(top + Vector3(0, 0.18, 0), Vector3(1.0, 0.52, 1.0)), WHITE)  # 둥근 흰 갓
			Toon.append(st, _cyl(cr, cr * 1.01, 0.22, 24), _xf(top + Vector3(0, 0.12, 0)), WHITE.darkened(0.04))   # 갓 가장자리 두께
			for i in 5:                                                                                  # 갓 위 물방울 (습한 병) — 납작한 이슬
				var a := i * 2.39996 + 0.8
				var rr := cr * (0.2 + 0.55 * fposmod(i * 0.618, 1.0))
				var yy := top.y + 0.18 + cr * 0.52 * sqrt(maxf(0.0, 1.0 - pow(rr / cr, 2.0))) - 0.02
				Toon.append(st, _sphere(0.2 + 0.08 * fposmod(i * 0.37, 1.0), 4, 10), _xf(Vector3(cos(a) * rr, yy, sin(a) * rr), Vector3(1, 0.42, 1)), DROP)
		"부채버섯":
			Toon.append(st, _cyl(0.35, 0.55, 2.2, 10), _xf(Vector3(0, 1.1, 0)), FAN_DARK.darkened(0.15))    # 썩은 밑동
			var shelves := [[0.5, 1.9, 0.0], [1.15, 1.6, 2.2], [1.75, 1.35, 4.1], [2.35, 1.1, 1.0], [2.85, 0.85, 3.2]]
			for sh: Array in shelves:
				var y: float = sh[0]
				var r: float = sh[1] * cr / 1.9
				var a: float = sh[2]
				var dir := Vector3(cos(a), 0, sin(a))
				var b := Basis(Vector3.UP, -a)
				Toon.append(st, _sphere(r, 5, 16), Transform3D(_ls(b, Vector3(1.0, 0.2, 0.78)), Vector3(0, y, 0) + dir * r * 0.55), FAN)
				Toon.append(st, _sphere(r * 0.92, 4, 14), Transform3D(_ls(b, Vector3(1.0, 0.12, 0.72)), Vector3(0, y - 0.09, 0) + dir * r * 0.55), FAN_DARK)
				Toon.append(st, _sphere(r * 0.55, 4, 10), Transform3D(_ls(b, Vector3(1.0, 0.24, 0.7)), Vector3(0, y + 0.07, 0) + dir * r * 0.4), FAN.lightened(0.12))
		"갈색갓버섯":
			Toon.append(st, _sphere(1.2, 6, 14), _xf(Vector3(0, 0.4, 0), Vector3(1.0, 0.5, 1.0)), STEM.darkened(0.12))
			var top2 := _stalk(st, Vector3(0, 0.2, 0), h - 1.6, 1.0, 0.85, STEM.darkened(0.06), -0.3, 14)
			Toon.append(st, _cyl(0.6, cr * 0.95, 0.4, 26), _xf(top2 + Vector3(0, 0.05, 0)), GILL.darkened(0.1))
			Toon.append(st, _hemi(cr, 7, 26), _xf(top2 + Vector3(0, 0.15, 0), Vector3(1.0, 0.42, 1.0)), BROWN)
			Toon.append(st, _cyl(cr, cr * 1.02, 0.3, 26), _xf(top2 + Vector3(0, 0.1, 0)), BROWN.darkened(0.1))
			Toon.append(st, _hemi(cr * 0.55, 5, 16), _xf(top2 + Vector3(0, 0.2 + cr * 0.3, 0), Vector3(1.0, 0.42, 1.0)), BROWN_LIGHT)   # 정수리 밝은 결
			for i in 5:                                                                                  # 갈라진 금 (정수리에서 가장자리로 갈라진 크림색 틈)
				var a := i * TAU / 5.0 + 0.5 + 0.25 * fposmod(i * 0.618, 1.0)
				var segs := 5
				for j in segs:
					var u0 := 0.36 + 0.58 * float(j) / segs
					var u1 := 0.36 + 0.58 * float(j + 1) / segs
					var w0 := Vector3(cos(a), 0, sin(a))
					var p0 := Vector3(w0.x * u0 * cr, top2.y + 0.15 + cr * 0.42 * sqrt(maxf(0.0, 1.0 - u0 * u0)) + 0.03, w0.z * u0 * cr)
					var p1 := Vector3(w0.x * u1 * cr, top2.y + 0.15 + cr * 0.42 * sqrt(maxf(0.0, 1.0 - u1 * u1)) + 0.03, w0.z * u1 * cr)
					var dv := p1 - p0
					var b := Basis.looking_at(dv.normalized(), Vector3.UP)
					Toon.append(st, BoxMesh.new(), Transform3D(_ls(b, Vector3(0.11 - 0.012 * j, 0.06, dv.length() * 1.15)), (p0 + p1) * 0.5), CRACK)
		"얼룩버섯":
			Toon.append(st, _sphere(0.9, 6, 14), _xf(Vector3(0, 0.45, 0), Vector3(1.0, 0.6, 1.0)), SPOT.darkened(0.06))
			var top3 := _stalk(st, Vector3(0, 0.3, 0), h - 1.3, 0.62, 0.45, SPOT, 0.2, 12)
			Toon.append(st, _cyl(0.5, 0.95, 0.36, 14), _xf(top3 - Vector3(0, 0.95, 0)), SPOT.darkened(0.04))
			Toon.append(st, _cyl(0.3, cr * 0.95, 0.3, 22), _xf(top3 + Vector3(0, 0.05, 0)), Color("f0e2c8"))
			Toon.append(st, _hemi(cr, 8, 24), _xf(top3 + Vector3(0, 0.15, 0), Vector3(1.0, 0.62, 1.0)), RED)
			Toon.append(st, _cyl(cr, cr * 1.01, 0.2, 24), _xf(top3 + Vector3(0, 0.1, 0)), RED_DARK)
			for i in 15:                                                                                 # 흰 점
				var u := (i + 0.5) / 15.0
				var a := i * 2.39996
				var rr := cr * sqrt(u) * 0.92
				var nrm := rr / cr
				var yy := top3.y + 0.15 + cr * 0.62 * sqrt(maxf(0.0, 1.0 - nrm * nrm))
				var up := Vector3(cos(a) * nrm, sqrt(maxf(0.05, 1.0 - nrm * nrm)) * 0.62, sin(a) * nrm).normalized()
				var b := Basis(Quaternion(Vector3.UP, up))
				var sr := 0.16 + 0.12 * fposmod(i * 0.618, 1.0)
				Toon.append(st, _sphere(sr, 3, 8), Transform3D(_ls(b, Vector3(1.0, 0.28, 1.0)), Vector3(cos(a) * rr, yy, sin(a) * rr)), SPOT)
		"빛버섯":
			for k in 3:
				var off: Vector3 = [Vector3(0, 0, 0), Vector3(0.26, 0, 0.12), Vector3(-0.18, 0, 0.22)][k]
				var sc: float = [1.0, 0.72, 0.58][k]
				var hh: float = h * sc
				Toon.append(st, _cyl(0.035 * sc, 0.05 * sc, hh, 6), _xf(off + Vector3(0, hh * 0.5, 0)), GLOW_STEM)
				Toon.append(st, _hemi(0.17 * sc, 4, 10), _xf(off + Vector3(0, hh, 0), Vector3(1.0, 0.75, 1.0)), GLOW_CAP)
	var m := st.commit()
	_meshes[kind] = m
	return m


## 빛버섯의 밤 빛: 갓은 스스로 빛남 (밤 색에 묻히지 않게 밝게) · 발밑은 푸른 빛 웅덩이
static func night_cap_mat() -> ShaderMaterial:
	if _night_cap == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, cull_back;
uniform float glow = 0.0;
void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = mix(c, c * vec3(1.4, 2.2, 2.5) + vec3(0.1, 0.35, 0.4), glow);
}"""
		_night_cap = ShaderMaterial.new()
		_night_cap.shader = sh
	return _night_cap


static func glow_mat() -> ShaderMaterial:
	if _glow_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float glow = 0.0;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = floor(clamp(1.0 - d, 0.0, 1.0) * 4.0) / 4.0;
	ALBEDO = vec3(0.35, 0.9, 1.0) * 1.6;
	ALPHA = a * 0.55 * glow;
}"""
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = sh
	return _glow_mat


# ───────────────────────── 민들레 메시 ─────────────────────────
## 톱니 잎 하나를 st에 직접 (길쭉한 잎, 가장자리가 들쭉날쭉 — 땅에 눕고 끝이 조금 들림). 길이 len, xf 기준 +z 쪽으로 뻗음
static func _leaf_into(st: SurfaceTool, xf: Transform3D, len: float, w: float, c: Color, c2: Color) -> void:
	var n := 7
	var mid: Array[Vector3] = []
	var lft: Array[Vector3] = []
	var rgt: Array[Vector3] = []
	for i in n + 1:
		var u := float(i) / n
		var z := u * len
		var y := 0.05 + 0.12 * u * u * len
		var ww := w * sin(PI * minf(1.0, u * 1.08)) * (1.0 if i % 2 == 0 else 0.55)     # 톱니
		var back := 0.12 * len / n if i % 2 == 1 else 0.0
		mid.append(Vector3(0, y + 0.04, z))
		lft.append(Vector3(-ww, y, z - back))
		rgt.append(Vector3(ww, y, z - back))
	for i in n:
		for side in 2:
			var e: Array[Vector3] = lft if side == 0 else rgt
			var cc := c if side == 0 else c2
			var tris := [[mid[i], e[i], e[i + 1]], [mid[i], e[i + 1], mid[i + 1]]]
			for tri: Array in tris:
				var a: Vector3 = xf * (tri[0] as Vector3)
				var b: Vector3 = xf * (tri[1] as Vector3)
				var d: Vector3 = xf * (tri[2] as Vector3)
				var nrm := (b - a).cross(d - a).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				# 양면 (앞뒤 감김 둘 다 — 잎은 얇아서 어느 쪽에서 봐도 보이게, 빛은 위쪽 법선)
				for q: Vector3 in [a, b, d, a, d, b]:
					st.set_color(cc)
					st.set_normal(nrm)
					st.add_vertex(q)


## 잎 방석 (싹이면 작게)
static func rosette_mesh(big: bool) -> ArrayMesh:
	var key := "rosette_%s" % big
	if _meshes.has(key):
		return _meshes[key]
	var an := "dand_leaves" if big else "dand_leaves_small"
	if Art.exists(an):
		_meshes[key] = Art.model(an)["mesh"]
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 7 if big else 4
	for i in n:
		var a := i * TAU / n + 0.3 * fposmod(i * 0.618, 1.0)
		var len := (1.9 if big else 0.9) * (0.8 + 0.3 * fposmod(i * 0.37, 1.0))
		_leaf_into(st, Transform3D(Basis(Vector3.UP, a), Vector3.ZERO), len, 0.34 if big else 0.2, LEAF, LEAF_DARK)
	var m := st.commit()
	_meshes[key] = m
	return m


static var _stem_top := Vector3.ZERO


## 줄기 (주민 서너 배) — 꼭대기 자리는 stem_top()
static func stem_mesh() -> ArrayMesh:
	if _meshes.has("stem"):
		return _meshes["stem"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_stem_top = _stalk(st, Vector3.ZERO, Balance.DAND_H, 0.085, 0.07, D_STEM, 0.5, 8, 5)
	var m := st.commit()
	_meshes["stem"] = m
	return m


static func stem_top() -> Vector3:
	stem_mesh()
	return _stem_top


## 머리 (꽃 · 꽃봉오리 · 솜털 공) — 줄기 꼭대기 = 원점. 머리는 +z(카메라 쪽)로 조금 기욺
static func dand_mesh(st_name: String) -> ArrayMesh:
	var key := "dand_" + st_name
	if _meshes.has(key):
		return _meshes[key]
	if Art.exists(ART_DAND.get(st_name, "")):
		_meshes[key] = Art.model(ART_DAND[st_name])["mesh"]
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := Vector3.ZERO
	var tilt := Basis(Vector3(1, 0, 0), 0.5)          # 머리가 카메라 쪽으로 기욺
	match st_name:
		"flower":                                                                                         # 해만 한 노란 꽃 — 겹겹의 꽃잎이 둥근 방석처럼
			Toon.append(st, _sphere(0.26, 5, 10), _xf(top + Vector3(0, 0.05, 0), Vector3(1, 0.6, 1)), BUD)   # 꽃받침
			var c := top + tilt * Vector3(0, 0.16, 0)
			Toon.append(st, _sphere(0.86, 6, 18), Transform3D(_ls(tilt, Vector3(1, 0.28, 1)), c), YELLOW_DARK)   # 꽃잎 밑 (가득 찬 원판)
			for ring in 4:
				var nr: int = [26, 22, 16, 10][ring]
				var rr: float = [0.98, 0.78, 0.56, 0.34][ring]
				var lift: float = [0.0, 0.1, 0.2, 0.28][ring]
				var up: float = [0.12, 0.38, 0.62, 0.85][ring]
				for i in nr:
					var a: float = (i + 0.5 * ring) * TAU / nr
					var dir := Vector3(cos(a), 0, sin(a))
					var b := tilt * Basis(Vector3.UP, -a) * Basis(Vector3(0, 0, 1), up)
					var p := c + tilt * (dir * rr * 0.55 + Vector3(0, lift, 0))
					var col := YELLOW if (i + ring) % 3 != 0 else YELLOW.lightened(0.12)
					if ring == 3:
						col = YELLOW.darkened(0.06)
					Toon.append(st, _sphere(0.5, 3, 6), Transform3D(_ls(b, Vector3(rr * 0.95, 0.07, 0.26 - 0.03 * ring)), p), col)
			Toon.append(st, _sphere(0.2, 4, 8), Transform3D(_ls(tilt, Vector3(1, 0.6, 1)), c + tilt * Vector3(0, 0.36, 0)), YELLOW_DARK)
		"closed":
			Toon.append(st, _sphere(0.28, 6, 10), _xf(top + Vector3(0, 0.32, 0), Vector3(0.85, 1.5, 0.85)), BUD)
			Toon.append(st, _sphere(0.14, 4, 8), _xf(top + Vector3(0, 0.78, 0), Vector3(0.8, 1.2, 0.8)), YELLOW_DARK)    # 닫힌 꽃잎 끝
			for i in 6:                                                                                   # 꽃받침이 뒤로 젖혀짐
				var a := i * TAU / 6.0
				var b := Basis(Vector3.UP, -a) * Basis(Vector3(0, 0, 1), 2.3)
				Toon.append(st, BoxMesh.new(), Transform3D(_ls(b, Vector3(0.4, 0.035, 0.08)), top + Vector3(cos(a), 0, sin(a)) * 0.18 + Vector3(0, 0.02, 0)), BUD.darkened(0.1))
		"puff":
			var c2 := top + Vector3(0, 0.75, 0)
			Toon.append(st, _sphere(0.62, 7, 14), _xf(c2), FLUFF.darkened(0.04))                       # 솜털 덩어리
			Toon.append(st, _sphere(0.16, 4, 8), _xf(top + Vector3(0, 0.1, 0)), FLUFF_CORE)
			var n := 70
			for i in n:                                                                                  # 솜털 우산 (바깥으로 뻗은 털 + 끝의 솜)
				var yy := 1.0 - (i + 0.5) / n * 1.8
				var rr := sqrt(maxf(0.0, 1.0 - yy * yy))
				var a := i * 2.39996
				var dir := Vector3(cos(a) * rr, yy, sin(a) * rr).normalized()
				var b := Basis(Quaternion(Vector3.UP, dir))
				Toon.append(st, _cyl(0.008, 0.012, 0.42, 3), Transform3D(b, c2 + dir * 0.55), FLUFF.darkened(0.08))
				Toon.append(st, _sphere(0.1, 3, 6), Transform3D(_ls(b, Vector3(1.0, 0.45, 1.0)), c2 + dir * 0.82), FLUFF)
		"bare":                                                                                          # 꽃씨가 다 날아간 줄기 (잠깐) — 빈 꽃턱 + 남은 솜 몇
			Toon.append(st, _sphere(0.24, 4, 10), _xf(top + Vector3(0, 0.08, 0), Vector3(1, 0.5, 1)), FLUFF_CORE)
			for i in 5:
				var a := i * 2.39996
				var dir := Vector3(cos(a) * 0.8, 0.6, sin(a) * 0.8).normalized()
				Toon.append(st, _sphere(0.1, 3, 6), _xf(top + Vector3(0, 0.1, 0) + dir * 0.35, Vector3(1, 0.6, 1)), FLUFF)
	var m := st.commit()
	_meshes[key] = m
	return m


## 꽃씨 하나: 아래 씨앗 + 가는 대 + 위의 우산털 (지름 SEED_SIZE)
static func seed_mesh() -> ArrayMesh:
	if _meshes.has("seed"):
		return _meshes["seed"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := SEED_SIZE                         # 가는 털은 외곽선에 묻혀 검게 보이므로 — 작게 봐도 하얀 솜 우산으로 읽히게 통통하게
	Toon.append(st, _sphere(0.05, 3, 5), _xf(Vector3(0, 0, 0), Vector3(0.7, 1.6, 0.7)), Color("9a7a4a"))
	Toon.append(st, _cyl(0.012, 0.016, s * 0.5, 4), _xf(Vector3(0, s * 0.27, 0)), FLUFF.darkened(0.06))
	Toon.append(st, _hemi(s * 0.5, 3, 10), _xf(Vector3(0, s * 0.5, 0), Vector3(1, 0.32, 1)), FLUFF)
	for i in 7:
		var a := i * TAU / 7.0
		var dir := Vector3(cos(a), 0.2, sin(a)).normalized()
		Toon.append(st, _sphere(0.075, 2, 5), _xf(Vector3(0, s * 0.5, 0) + dir * s * 0.5, Vector3(1, 0.7, 1)), FLUFF)
	var m := st.commit()
	_meshes["seed"] = m
	return m


## 메시에 맞는 재질: Blender 모델(툰 + 껍데기 외곽선 재질이 붙어 있음)이면 그대로, 절차 메시면 꼭짓점 색 툰
static func vc_for(mesh: Mesh) -> Material:
	if mesh != null and mesh.get_surface_count() > 0 and mesh.surface_get_material(0) != null:
		return null
	return Toon.vc_mat()


# ───────────────────────── 매 화면 ─────────────────────────
func _gy(x: float, z: float) -> float:
	var p := get_parent()
	if p is VillageView:
		return (p as VillageView).gy(x, z)
	return 0.0


## [보이는 살림 Q6] 건물 앞 더미 · 채집 일꾼 앞에 선 민들레·큰 버섯은 가리지 않는 키까지만 (화면만 — BldEcon.plant_cap).
## nd = 그 식물의 화면 기록 · h = 지금 키 · hw = 반 폭 어림 · df = 그림의 깊이 면. 앞마당(apron_ver)이나 키가 바뀔 때만 다시 잰다
func _apron_cap(nd: Dictionary, x: float, z: float, h: float, hw: float, df: float) -> float:
	if not pics2d:
		return 1.0
	var p := get_parent() as VillageView
	if p == null or p.econ == null:
		return 1.0
	var ver: int = p.econ.apron_ver
	if int(nd.get("cap_v", -1)) != ver or absf(float(nd.get("cap_h", -1.0)) - h) > 0.05:
		nd["cap_v"] = ver
		nd["cap_h"] = h
		nd["cap"] = p.econ.plant_cap(x, z, h, hw, df)
	return float(nd["cap"])


func _cam_yaw() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return 0.0
	var f := cam.global_transform.basis.z
	return atan2(f.x, f.z)


func sync(dt: float) -> void:
	_t += dt
	var f := v.flora
	if f == null:
		return
	night = Style.night_amount(v.hour_now())
	var yaw := _cam_yaw()
	_sync_shrooms(f, dt)
	_sync_dands(f, dt, yaw)
	_sync_seeds(f, yaw)
	_sync_weeds(f)
	_sync_racks(f)


## 화면 위 수 (캡처·확인용)
func counts() -> Dictionary:
	return {"shrooms": _sh.size(), "dands": _dd.size(), "seeds": _seeds.multimesh.visible_instance_count if _seeds != null else 0}


func _sync_shrooms(f: Flora, dt: float) -> void:
	var seen := {}
	var glow := clampf((night - 0.25) / 0.5, 0.0, 1.0)
	for s: Dictionary in f.shrooms:
		if s["gone"]:
			continue
		var id: int = s["id"]
		seen[id] = true
		var nd: Dictionary = _sh.get(id, {})
		if nd.is_empty():
			nd = _make_shroom(s)
			_sh[id] = nd
		var root: Node3D = nd["root"]
		var x: float = s["x"]
		var z: float = s["y"]
		root.position = Vector3(x, _gy(x, z) - 0.05, z)
		# 자람: 어릴 땐 작고 동그랗게 → 다 자라면 진짜 크기. 시들면 갓이 처지고 기욺
		var g: float = s["g"]
		var goal := 0.22 + 0.78 * smoothstep(0.0, 1.0, g)
		nd["scale"] = lerpf(float(nd["scale"]), goal, 1.0 - exp(-3.0 * dt))
		var sc: float = nd["scale"]
		var life := float(s["life"]) / Balance.SHROOM_LIFE
		var droop := clampf((life - 0.75) / 0.25, 0.0, 1.0)
		var cap := 1.0
		if nd.has("pic_h"):              # (2D · Q6) 더미·일꾼 앞마당에서는 낮게
			cap = _apron_cap(nd, x, z, float(nd["pic_h"]) * sc, float(nd["pic_w"]) * sc * 0.25, float(nd["pic_df"]) * sc)
		root.scale = Vector3(sc, sc * (1.0 - 0.12 * droop), sc) * cap
		root.rotation.z = droop * 0.18 * (1.0 if id % 2 == 0 else -1.0)
		var body: MeshInstance3D = nd["body"]
		if s["kind"] == "빛버섯":
			(body.material_override as ShaderMaterial).set_shader_parameter("glow", glow * (0.85 + 0.15 * sin(_t * 1.7 + id)))
			var gl: MeshInstance3D = nd["glow"]
			gl.visible = glow > 0.02
			gl.position = root.position + Vector3(0, 0.4, 0)          # 비탈에 묻히지 않게 조금 띄움 (더하기 섞기라 떠 보이지 않음)
			(gl.material_override as ShaderMaterial).set_shader_parameter("glow", glow)
	for id in _sh.keys():
		if not seen.has(id):
			var nd: Dictionary = _sh[id]
			var r: Node3D = nd["root"]
			nd["fade"] = float(nd.get("fade", 1.0)) - dt / 0.6           # 베어지거나 쓰러짐: 줄어들며 사라짐
			r.scale = Vector3.ONE * maxf(0.001, float(nd["scale"]) * float(nd["fade"]))
			if float(nd["fade"]) <= 0.0:
				r.queue_free()
				if nd.has("glow"):
					(nd["glow"] as Node3D).queue_free()
				_sh.erase(id)


func _make_shroom(s: Dictionary) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.rotation.y = fposmod(float(s["id"]) * 2.17, TAU)
	var body := MeshInstance3D.new()
	body.mesh = shroom_mesh(s["kind"])
	root.add_child(body)
	var nd := {"root": root, "body": body, "scale": 0.05 if float(s["g"]) < 1.0 else 0.15}
	if s["kind"] == "빛버섯":
		var m := night_cap_mat().duplicate() as ShaderMaterial
		body.material_override = m
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var gl := MeshInstance3D.new()
		var disc := PlaneMesh.new()
		disc.size = Vector2(3.4, 3.4)
		gl.mesh = disc
		gl.material_override = glow_mat().duplicate()
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gl.visible = false
		add_child(gl)
		nd["glow"] = gl
	else:
		body.material_override = vc_for(body.mesh)
		var an: String = ART_SHROOM.get(s["kind"], "")
		if body.material_override == null and Art.exists(an) and Art.model(an)["lines"] != null:
			var ln := MeshInstance3D.new()                  # 접힌 곳 선 (갓 가장자리·턱받이·갈라진 금 둘레)
			ln.mesh = Art.model(an)["lines"]
			ln.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(ln)
	if pics2d:                       # (2D) 버섯 그림 + 3D는 그림자 대역 (빛버섯은 원래 그림자 없음 → 숨김)
		var pic := Flora2D.pic_for(String(ART_SHROOM.get(s["kind"], "")))
		if Flora2D.has(pic):
			Flora2D.proxify(root)
			root.add_child(Flora2D.card(pic, 1.0, int(s["id"]) % 2 == 1))
			var inf := Flora2D.info(pic)
			nd["pic_h"] = float(inf.get("h", 0.0))
			nd["pic_w"] = float(inf.get("w", 0.0))
			nd["pic_df"] = float(inf.get("front", 0.0))
	return nd


func _sync_dands(f: Flora, dt: float, yaw: float) -> void:
	var seen := {}
	for d: Dictionary in f.dands:
		var id: int = d["id"]
		seen[id] = true
		var nd: Dictionary = _dd.get(id, {})
		if nd.is_empty():
			nd = _make_dand(d)
			_dd[id] = nd
		var root: Node3D = nd["root"]
		var x: float = d["x"]
		var z: float = d["y"]
		root.position = Vector3(x, _gy(x, z) - 0.02, z)
		var st: String = d["st"]
		var u := f.stage_u(v, d)
		var leaves: MeshInstance3D = nd["leaves"]
		var stem: MeshInstance3D = nd["stem"]
		var head: MeshInstance3D = nd["head"]
		var pivot: Node3D = nd["pivot"]
		var big := st != "sprout" or u > 0.6
		if nd["big"] != big:
			nd["big"] = big
			leaves.mesh = rosette_mesh(big)
			leaves.material_override = vc_for(leaves.mesh)
			if nd.has("rosette"):
				Flora2D.set_pic(nd["rosette"], "dand_rosette" if big else "dand_rosette_small")
		var shape := ""
		match st:
			"flower", "closed", "puff":
				shape = st
			"leaf":
				if int(d["cycles"]) > 0 and v.t - float(d["st_t"]) < 0.08 * Balance.DAY:
					shape = "bare"                       # 꽃씨가 다 날아간 줄기 (잠깐)
		if nd["st"] != shape:
			nd["st"] = shape
			stem.visible = shape != ""
			head.visible = shape != ""
			if shape != "":
				head.mesh = dand_mesh(shape)
				head.material_override = vc_for(head.mesh)
				if nd.has("headpic"):
					Flora2D.set_pic(nd["headpic"], "dand_" + shape, 2)
			if shape == "flower" or shape == "puff":
				nd["grow"] = 0.5
		# 피어남·부풂: 단계가 바뀌면 머리가 부드럽게 자람 · 솜털 공은 꽃씨가 줄면 작아짐 · 첫 꽃대는 쑥 올라옴
		var gs := 1.0
		if st == "flower":
			gs = 0.55 + 0.45 * smoothstep(0.0, 0.08, u)
		elif st == "puff":
			gs = 0.55 + 0.45 * float(d["seeds"]) / float(Balance.DAND_SEEDS)
		nd["grow"] = lerpf(float(nd["grow"]), gs, 1.0 - exp(-4.0 * dt))
		var rise := 1.0
		if st == "flower" and int(d["cycles"]) == 0:
			rise = 0.4 + 0.6 * smoothstep(0.0, 0.12, u)
		var hr: Node3D = nd["head_root"]
		hr.rotation.y = lerp_angle(hr.rotation.y, yaw, 1.0 - exp(-4.0 * dt))
		hr.rotation.x = sin(_t * 0.9 + id * 1.3) * 0.035          # 살랑
		hr.rotation.z = sin(_t * 0.7 + id * 0.7) * 0.03
		hr.scale = Vector3(1.0, rise, 1.0)
		pivot.position = stem_top()
		pivot.scale = Vector3(1.0, 1.0 / maxf(0.2, rise), 1.0) * float(nd["grow"])
		leaves.scale = Vector3.ONE * (0.55 + 0.45 * u if st == "sprout" else 1.0)
		if pics2d:                       # (2D · Q6) 더미·일꾼 앞마당에서는 낮게 — 꽃대가 섰으면 꽃대 + 머리 키, 아니면 잎 방석 키
			var dh := (DAND_TALL * rise if shape != "" else (DAND_LEAF if big else DAND_LEAF_SMALL) * leaves.scale.y)
			root.scale = Vector3.ONE * _apron_cap(nd, x, z, dh, DAND_HALF_W, DAND_DF)
	for id in _dd.keys():
		if not seen.has(id):
			var nd: Dictionary = _dd[id]
			(nd["root"] as Node3D).queue_free()
			_dd.erase(id)


func _make_dand(d: Dictionary) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var leaves := MeshInstance3D.new()
	leaves.mesh = rosette_mesh(d["st"] != "sprout")
	leaves.material_override = vc_for(leaves.mesh)
	leaves.rotation.y = fposmod(float(d["id"]) * 1.37, TAU)
	root.add_child(leaves)
	var hr := Node3D.new()
	root.add_child(hr)
	var stem := MeshInstance3D.new()
	stem.mesh = stem_mesh()
	stem.material_override = Toon.vc_mat()
	stem.visible = false
	hr.add_child(stem)
	var pivot := Node3D.new()
	pivot.position = stem_top()
	hr.add_child(pivot)
	var head := MeshInstance3D.new()
	head.material_override = Toon.vc_mat()
	head.visible = false
	pivot.add_child(head)
	var out := {"root": root, "leaves": leaves, "stem": stem, "head": head, "pivot": pivot, "head_root": hr, "st": "?", "big": d["st"] != "sprout", "grow": 1.0}
	if pics2d:                       # (2D) 잎 방석·줄기·머리 그림 — 3D는 그림자 대역, 그림 판은 각 노드의 자식 (보임·배율을 따름)
		for g: GeometryInstance3D in [leaves, stem, head]:
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		out["rosette"] = Flora2D.card("dand_rosette" if d["st"] != "sprout" else "dand_rosette_small")
		leaves.add_child(out["rosette"])
		stem.add_child(Flora2D.card("dand_stem"))
		out["headpic"] = Flora2D.card("dand_flower", 1.0, false, 0.0, 2)
		head.add_child(out["headpic"])
	return out


## 날리는 꽃씨: 5초 걸음 사이를 보간 + 살랑살랑 (화면만)
func _sync_seeds(f: Flora, yaw: float) -> void:
	var mm := _seeds.multimesh
	var n := mini(f.seeds.size(), mm.instance_count)
	var u := clampf((f._sacc + alpha * Balance.WATCH_STEP) / Balance.SEED_TICK, 0.0, 1.0)
	var buf := PackedFloat32Array()
	for i in n:
		var s: Dictionary = f.seeds[i]
		var x := lerpf(float(s["px"]), float(s["x"]), u)
		var z := lerpf(float(s["py"]), float(s["y"]), u)
		var hgt := lerpf(float(s["pz"]), float(s["z"]), u)
		var ph := i * 1.618 + _t
		x += sin(ph * 0.9) * 0.18
		z += cos(ph * 0.7) * 0.18
		hgt += sin(ph * 1.3) * 0.08
		# 카메라 쪽으로 옆모습이 보이게 기울임 (위에서 보면 우산이 톱니 원판처럼 보임) + 살랑
		if pics2d:
			buf.append_array(Flora2D.inst_floats("dand_seed", Vector3(x, _gy(x, z) + maxf(0.05, hgt), z), 1.0, false, ph))
			continue
		var b := Basis(Vector3.UP, yaw + sin(ph * 0.5) * 0.6) * Basis(Vector3(1, 0, 0), -0.85 + sin(ph * 1.1) * 0.25)
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, _gy(x, z) + maxf(0.05, hgt), z)))
	if pics2d:
		if n > 0:
			buf.resize(mm.instance_count * 20)
			mm.buffer = buf
	mm.visible_instance_count = n


## 밭의 잡초: 내려앉은 꽃씨가 밭에 뿌리내린 작은 민들레 (잡초 수만큼)
func _sync_weeds(f: Flora) -> void:
	var key := ""
	for bid in f.weeds:
		key += "%d:%d," % [bid, int(f.weeds[bid])]
	if key == _weed_key:
		return
	_weed_key = key
	for c in _weeds.get_children():
		c.queue_free()
	for bid: int in f.weeds:
		var b := v.bld(bid)
		if b == null:
			continue
		for i in int(f.weeds[bid]):
			var a := i * 2.39996 + bid
			var r := 0.5 + 0.9 * fposmod(i * 0.618 + bid * 0.1, 1.0)
			var x := b.x + cos(a) * r * b.size() * 0.8
			var z := b.y + sin(a) * r * b.size() * 0.8
			var lv := MeshInstance3D.new()
			lv.mesh = rosette_mesh(true)
			lv.material_override = vc_for(lv.mesh)
			lv.position = Vector3(x, _gy(x, z) + 0.02, z)
			lv.scale = Vector3.ONE * 0.5
			lv.rotation.y = a
			_weeds.add_child(lv)
			var hn := Node3D.new()
			hn.position = lv.position
			hn.scale = Vector3.ONE * 0.42
			hn.rotation.y = _cam_yaw()
			_weeds.add_child(hn)
			for pair: Array in [[stem_mesh(), Vector3.ZERO], [dand_mesh("flower"), stem_top()]]:
				var mi := MeshInstance3D.new()
				mi.mesh = pair[0]
				mi.material_override = vc_for(mi.mesh)
				mi.position = pair[1]
				hn.add_child(mi)


## 버섯꾼 오두막 곁 말림대: 나무 시렁 + 말리는 갈색 버섯 조각 (말리는 양만큼)
func _sync_racks(f: Flora) -> void:
	var key := ""
	for b in v.buildings:
		if b.built and b.type == "버섯꾼":
			key += "%d:%d:%.1f,%.1f;" % [b.id, mini(8, ceili(f.drying_at(b.id) / 8.0)), b.x, b.y]
	if key == _rack_key:
		return
	_rack_key = key
	for c in _racks.get_children():
		c.queue_free()
	for b in v.buildings:
		if not (b.built and b.type == "버섯꾼"):
			continue
		var n := Node3D.new()
		_racks.add_child(n)
		var x := b.x - 1.25
		var z := b.y + 0.7
		n.position = Vector3(x, _gy(x, z), z)
		n.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG)
		var wood := Style.WOOD_DARK
		for px: float in [-0.55, 0.55]:
			_box(n, Vector3(0.09, 1.0, 0.09), Vector3(px, 0.5, 0), wood)
		_box(n, Vector3(1.3, 0.07, 0.07), Vector3(0, 0.95, 0), wood)
		_box(n, Vector3(1.3, 0.07, 0.07), Vector3(0, 0.6, 0), wood)
		var k := mini(8, ceili(f.drying_at(b.id) / 8.0))
		for i in k:
			var row := 0.95 if i % 2 == 0 else 0.6
			var sx := -0.45 + (i / 2) * 0.3
			var sl := MeshInstance3D.new()
			sl.mesh = _sphere(0.15, 3, 8)
			sl.material_override = Toon.mat(BROWN_LIGHT if i % 3 else BROWN)
			sl.position = Vector3(sx, row - 0.13, 0.0)
			sl.scale = Vector3(1.0, 0.75, 0.3)
			n.add_child(sl)
		# 바구니
		var bk := MeshInstance3D.new()
		bk.mesh = _cyl(0.28, 0.22, 0.26, 10)
		bk.material_override = Toon.mat(Style.WOOD)
		bk.position = Vector3(0.9, 0.13, 0.25)
		n.add_child(bk)


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = ResidentModel.box_of(size)
	mi.material_override = Toon.mat(c)
	mi.position = pos
	parent.add_child(mi)


## 꽃씨에 매달린 아이 머리 위의 큰 꽃씨 (VillageView._sync_residents가 부름)
func rider_seed(rid: int, on: bool) -> Node3D:
	var n: Node3D = _rider_seeds.get(rid)
	if not on:
		if n != null:
			n.queue_free()
			_rider_seeds.erase(rid)
		return null
	if n == null:
		n = Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = seed_mesh()
		mi.material_override = Toon.vc_mat()
		mi.scale = Vector3.ONE * 2.6
		n.add_child(mi)
		add_child(n)
		_rider_seeds[rid] = n
	return n
