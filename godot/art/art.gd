## 모델 에셋 읽기 — art/models/*.glb (Blender 스크립트 art/src/*.py가 만듦, 다시 만들기: art/src/build_all.sh).
## glb 하나 = 한 모델. 노드 이름이 "_nl"로 끝나면 접힌 곳 선을 만들지 않음 (잎 덩어리처럼 면 경계가 '선'이 아닌 것),
## "_nh"로 끝나면 껍데기 외곽선도 없음 (얇은 풀잎·고사리 잎 — 선을 두르면 검은 낙서처럼 보임).
## 읽을 때 한 번만:
##   · 꼭짓점 색: glTF는 선형 → sRGB로 되돌림 (공용 툰 셰이더 render/toon.gdshader가 sRGB를 받음)
##   · CUSTOM0 = 같은 자리 꼭짓점들의 평균 노멀 → 뒤집은 껍데기 외곽선(render/hull.gdshader)이 모서리에서 끊기지 않게
##   · 접힌 곳 선 메시: 각진 모서리(양쪽 면 노멀이 갈라진 곳, CREASE_DEG 이상)와 열린 가장자리 → render/crease_lines.gdshader
## 결과: {"mesh": 몸 ArrayMesh (재질 = 툰 + 껍데기 next_pass), "lines": 선 ArrayMesh 또는 null}. 같은 이름은 캐시.
class_name Art
extends RefCounted

const DIR := "res://art/models/"
const CREASE_DEG := 24.0          # 이보다 덜 꺾인 모서리엔 선 없음
const WELD := 1000.0              # 같은 자리 판정 (1/1000칸)
const ANIMAL_FUR := "res://art/models/animal_fur.png"     # 동물 결 그림 묶음 (art/src/pack_animal_atlas.py)

## 땅 겉모습 덮개 (A13 준비, art/src/build_ground.py) — 땅 종류마다 변형 2~3개. 원점 = 조각 가운데 땅 위, 지름 약 1.2~1.4칸.
## 평평한 부분은 외곽선 없음. 아직 배치 안 함 — dev가 땅 종류별로 흩뿌릴 때 이 이름을 쓴다.
const GROUND_COVER := {
	"이끼": ["gc_moss_a", "gc_moss_b", "gc_moss_c"],
	"모래·자갈 물가": ["gc_shore_a", "gc_shore_b", "gc_shore_c"],
	"진흙": ["gc_mud_a", "gc_mud_b"],
	"낙엽": ["gc_leaves_a", "gc_leaves_b", "gc_leaves_c"],
	"오솔길 디딤돌": ["gc_pathstones_a", "gc_pathstones_b", "gc_pathstones_c"],
}
## 유리벽 폭포 (A12 준비, art/src/build_water.py) — art/models/water/README.md 참고. 게임에는 아직 안 씀.
const WATERFALL := {"strip": "water/waterfall_strip", "foam": "water/splash_foam", "rim": "water/splash_rim",
	"mist": "res://art/models/water/mist_puffs.png"}

static var _models: Dictionary = {}
static var _parts: Dictionary = {}
static var _body_mat: ShaderMaterial
static var _line_mat: ShaderMaterial


static func exists(name: String) -> bool:
	return ResourceLoader.exists(DIR + name + ".glb")


## 한 모델 (모든 노드를 한 메시로)
static func model(name: String) -> Dictionary:
	if _models.has(name):
		return _models[name]
	var acc := _Acc.new()
	var root := _instantiate(name)
	if root != null:
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var nm := String(mi.name)
			acc.add(mi.mesh, _rel_xf(mi, root), not (nm.ends_with("_nl") or nm.ends_with("_nh")), not nm.ends_with("_nh"))
		root.free()
	var res := acc.build(body_mat(), line_mat())
	_models[name] = res
	return res


## 부품 모음 (주민): 노드마다 따로 — {부품 이름: {"mesh", "lines", "origin": 관절 자리}}. "이름_body_nl" · "이름_body_nh" 노드는 "이름"에 합침.
static func parts(name: String) -> Dictionary:
	if _parts.has(name):
		return _parts[name]
	var by_part := {}
	var root := _instantiate(name)
	if root != null:
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var nm := String(mi.name)
			var pn := nm.trim_suffix("_body_nl").trim_suffix("_body_nh")
			if not by_part.has(pn):
				by_part[pn] = {"acc": _Acc.new(), "origin": _rel_xf(mi, root).origin}
			var nh := nm.ends_with("_nh")          # 안쪽 면 (주민 머리카락 안쪽 — A20): 선도 껍데기도 없음
			(by_part[pn]["acc"] as _Acc).add(mi.mesh, Transform3D(_rel_xf(mi, root).basis, Vector3.ZERO), not (nm.ends_with("_nl") or nh), not nh)
		root.free()
	var out := {}
	for pn: String in by_part:
		var r: Dictionary = (by_part[pn]["acc"] as _Acc).build(null, line_mat())
		r["origin"] = by_part[pn]["origin"]
		out[pn] = r
	_parts[name] = out
	return out


static func _instantiate(name: String) -> Node:
	var path := DIR + name + ".glb"
	if not ResourceLoader.exists(path):
		push_warning("Art: 모델 없음 " + path)
		return null
	var ps := load(path) as PackedScene
	return ps.instantiate() if ps != null else null


static func _rel_xf(n: Node3D, root: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	if root is Node3D:
		xf = (root as Node3D).transform * xf
	return xf


## 몸 재질: 툰(꼭짓점 색) + 뒤집은 껍데기 외곽선. 동물 v2의 털·깃털·비늘 결 그림(art/models/animal_fur.png)도 여기 —
## 동물 꼭짓점만 UV에 표시가 있어 결을 입는다 (render/toon.gdshader). view/animal_view.gd는 이 재질을 그대로 쓴다.
static func body_mat() -> ShaderMaterial:
	if _body_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://render/toon.gdshader")
		m.set_shader_parameter("albedo", Color.WHITE)
		Toon._light(m)
		m.set_shader_parameter("view_fill", Style.VIEW_FILL)
		if ResourceLoader.exists(ANIMAL_FUR):
			m.set_shader_parameter("animal_tex", load(ANIMAL_FUR))
		m.next_pass = hull_mat(true)
		_body_mat = m
	return _body_mat


static func hull_mat(vertex_color: bool, fixed := Color("4a3a30")) -> ShaderMaterial:
	var h := ShaderMaterial.new()
	h.shader = load("res://render/hull.gdshader")
	h.set_shader_parameter("line_mul", Style.OUTLINE_MUL if vertex_color else Color.WHITE)
	h.set_shader_parameter("use_vertex_color", vertex_color)
	h.set_shader_parameter("fixed_color", fixed)
	h.set_shader_parameter("width_px_1080p", Style.OUTLINE_HULL_PX_1080P)
	return h


static func line_mat() -> ShaderMaterial:
	if _line_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://render/crease_lines.gdshader")
		m.set_shader_parameter("line_mul", Style.OUTLINE_CREASE_MUL)
		m.set_shader_parameter("width_px_1080p", Style.OUTLINE_CREASE_PX_1080P)
		_line_mat = m
	return _line_mat


## 같은 모양 여러 개 → MultiMesh (몸 + 선). 몸만 그림자를 드리운다.
static func multi(parent: Node3D, name: String, xfs: Array[Transform3D], shadows := true) -> void:
	if xfs.is_empty():
		return
	var m := model(name)
	for key in ["mesh", "lines"]:
		var mesh: Mesh = m[key]
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (shadows and key == "mesh") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)


## 모델 하나 → 노드 (몸 + 선)
static func instance(parent: Node3D, name: String, xf := Transform3D.IDENTITY) -> Node3D:
	var n := Node3D.new()
	n.transform = xf
	parent.add_child(n)
	var m := model(name)
	for key in ["mesh", "lines"]:
		if m[key] == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = m[key]
		if key == "lines":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
	return n


## 여러 메시 → 몸 하나 + 선 하나
class _Acc:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()     # 동물 v2: 결 그림 자리 (UV.x ≥ 50 = 결 있음). 없는 메시는 0
	var has_uv := false
	var idx := PackedInt32Array()
	var hull := PackedByteArray()      # 꼭짓점마다 껍데기 외곽선을 둘지 (0 = 없음)
	var lpos := PackedVector3Array()
	var lcus := PackedFloat32Array()
	var lcol := PackedColorArray()
	var lidx := PackedInt32Array()

	func add(mesh: Mesh, xf: Transform3D, creases: bool, with_hull := true) -> void:
		if mesh == null:
			return
		var nb := xf.basis.inverse().transposed()
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL] if a[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var c: PackedColorArray = a[Mesh.ARRAY_COLOR] if a[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var t: PackedVector2Array = a[Mesh.ARRAY_TEX_UV] if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			if not t.is_empty():
				has_uv = true
			var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if ix.is_empty():
				ix = PackedInt32Array(range(v.size()))
			var base := pos.size()
			for i in v.size():
				pos.append(xf * v[i])
				nrm.append((nb * n[i]).normalized() if not n.is_empty() else Vector3.UP)
				col.append(c[i].linear_to_srgb() if not c.is_empty() else Color.WHITE)
				uv.append(t[i] if not t.is_empty() else Vector2.ZERO)
				hull.append(1 if with_hull else 0)
			var first_tri := idx.size()
			for i in ix:
				idx.append(base + i)
			if creases:
				_creases(first_tri, idx.size())

	func _key(p: Vector3) -> Vector3i:
		return Vector3i(roundi(p.x * Art.WELD), roundi(p.y * Art.WELD), roundi(p.z * Art.WELD))

	## 각진 모서리·열린 가장자리 → 선 사각형
	func _creases(from: int, to: int) -> void:
		var ids := {}
		var edges := {}           # Vector2i(작은 자리 id, 큰 자리 id) → [[삼각형 첫 인덱스, 꼭짓점 a, 꼭짓점 b], ...]
		for t in range(from, to, 3):
			var g := [idx[t], idx[t + 1], idx[t + 2]]
			var k := []
			for gi: int in g:
				var pk := _key(pos[gi])
				if not ids.has(pk):
					ids[pk] = ids.size()
				k.append(ids[pk])
			if k[0] == k[1] or k[1] == k[2] or k[0] == k[2]:
				continue
			for e in 3:
				var a: int = k[e]
				var b: int = k[(e + 1) % 3]
				var ek := Vector2i(mini(a, b), maxi(a, b))
				if not edges.has(ek):
					edges[ek] = []
				var ga: int = g[e] if a < b else g[(e + 1) % 3]
				var gb: int = g[(e + 1) % 3] if a < b else g[e]
				(edges[ek] as Array).append([t, ga, gb])
		var cos_lim := cos(deg_to_rad(Art.CREASE_DEG))
		for ek: Vector2i in edges:
			var lst: Array = edges[ek]
			var line := false
			var c: Color
			if lst.size() == 1:
				line = true
				c = col[lst[0][1]]
			elif lst.size() == 2:
				var e1: Array = lst[0]
				var e2: Array = lst[1]
				var hard := nrm[e1[1]].dot(nrm[e2[1]]) < 0.995 or nrm[e1[2]].dot(nrm[e2[2]]) < 0.995
				if hard and _fn(e1[0]).dot(_fn(e2[0])) < cos_lim:
					line = true
				var c1 := col[e1[1]]
				var c2 := col[e2[1]]
				c = c1 if c1.get_luminance() < c2.get_luminance() else c2
			else:
				line = true
				c = col[lst[0][1]]
			if line:
				_line(pos[lst[0][1]], pos[lst[0][2]], c)

	func _fn(t: int) -> Vector3:
		var a := pos[idx[t]]
		var n := (pos[idx[t + 1]] - a).cross(pos[idx[t + 2]] - a)
		return n.normalized() if n.length_squared() > 1e-14 else Vector3.ZERO

	func _line(a: Vector3, b: Vector3, c: Color) -> void:
		var base := lpos.size()
		# 0: A+  1: A-  2: B+  3: B-   (B 쪽은 방향이 반대라 옆 부호도 반대로 저장)
		for e: Array in [[a, b, 1.0], [a, b, -1.0], [b, a, -1.0], [b, a, 1.0]]:
			var p: Vector3 = e[0]
			var o: Vector3 = e[1]
			lpos.append(p)
			lcus.append_array(PackedFloat32Array([o.x, o.y, o.z, e[2]]))
			lcol.append(c)
		lidx.append_array(PackedInt32Array([base, base + 1, base + 3, base, base + 3, base + 2]))

	func build(mat: Material, lmat: Material) -> Dictionary:
		var out := {"mesh": null, "lines": null}
		if pos.is_empty():
			return out
		# 같은 자리 꼭짓점들의 평균 노멀 → CUSTOM0
		var sum := {}
		for i in pos.size():
			if hull[i] == 0:
				continue
			var k := _key(pos[i])
			sum[k] = sum.get(k, Vector3.ZERO) + nrm[i]
		var cus := PackedFloat32Array()
		cus.resize(pos.size() * 4)
		for i in pos.size():
			if hull[i] == 0:      # 껍데기 없음: 부풀리지 않음 (뒤로 밀린 뒷면은 자기 앞면에 가려 안 보임)
				cus[i * 4 + 3] = 1.0
				continue
			var s: Vector3 = sum[_key(pos[i])]
			var sn := s.normalized() if s.length_squared() > 1e-8 else nrm[i]
			cus[i * 4] = sn.x
			cus[i * 4 + 1] = sn.y
			cus[i * 4 + 2] = sn.z
			cus[i * 4 + 3] = 1.0
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_CUSTOM0] = cus
		if has_uv:
			arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		var fmt := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		var body := ArrayMesh.new()
		body.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
		if mat != null:
			body.surface_set_material(0, mat)
		out["mesh"] = body
		if not lpos.is_empty():
			var la := []
			la.resize(Mesh.ARRAY_MAX)
			la[Mesh.ARRAY_VERTEX] = lpos
			la[Mesh.ARRAY_COLOR] = lcol
			la[Mesh.ARRAY_CUSTOM0] = lcus
			la[Mesh.ARRAY_INDEX] = lidx
			var lm := ArrayMesh.new()
			lm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, la, [], {}, fmt)
			lm.surface_set_material(0, lmat)
			# 선은 화면에서 펴지므로 AABB를 조금 넉넉히
			lm.custom_aabb = body.get_aabb().grow(0.3)
			out["lines"] = lm
		return out
