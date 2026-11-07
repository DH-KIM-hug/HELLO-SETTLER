## 꽃숲·풀·소품 묶음 (ROADMAP P1 성능 — 폰 실측 docs/PERF_PHONE_2026-11-07.md: 꽃숲·풀이 삼각형의 2/3).
## 예전 VillageView._flush는 모양마다 MultiMesh 하나를 마을 둘레 전체(반지름 40칸, 먼 숲은 200칸)에 깔았다 →
## AABB가 땅 전체라 화면 밖 자르기가 한 번도 일어나지 않고, 세상 전체로 축소해도 같은 삼각형을 다 그렸다.
## 여기서는 같은 모양끼리 MultiMesh 하나(그리기 횟수는 그대로)이되:
##   ① 화면 자르기 (CPU): 인스턴스를 CELL칸 격자에 미리 나눠 두고, 카메라가 땅에서 보는 볼록 다각형(화면 네 귀퉁이 × 땅 높이 둘
##      + 키 큰 꽃 몫 TALL, 둘레 여유)에 든 칸만 버퍼에 담는다. 보는 땅이 REFRESH칸 넘게 움직일 때만 다시 담는다 (몇 화면에 한 번).
##      보이는 것이 없으면 그 모양은 그리지 않음. (사각형으로 자르면 기본 확대의 비스듬한 화면이 마을 장식 전체를 덮어 효과가 없었다.)
##      — 덩이를 칸마다 MultiMesh로 쪼개면 그리기 횟수가 칸 수 × 모양 수로 늘어난다 (예산 300번을 바로 넘음). 그래서 쪼개지 않는다.
##   ② 거리 단계 (LOD): 확대가 FAR_PPU 아래면 모양마다 '멀리' 덩이 (높이 띠 4개 × 육각 기둥, 띠마다 그 높이의 평균 색 — 삼각형 약 64,
##      껍데기 외곽선 그대로, 접힌 곳 선 없음). FAR_PPU + LOD_GAP 위로 돌아오면 가까이 (모바일은 visibility_range 페이드가 없어
##      확대 값으로 바꾸고 틈을 둬서 경계에서 깜빡이지 않게). 아주 멀리(TINY_PPU 아래)는 납작한 것(이끼·클로버·풀 포기…)을 숨김.
## 자식 MultiMeshInstance3D의 multimesh.mesh는 가까이 단계에서 Art.model(이름)["mesh"] 그대로 (시험이 모양을 확인함).
class_name FloraBatch
extends RefCounted

const CELL := 4.0                 # 미리 나눠 두는 격자 (칸)
const REFRESH := 2.0              # 카메라가 보는 땅의 테두리가 이만큼(칸) 넘게 움직이면 다시 담음
const MARGIN := 3.0               # 화면 둘레 여유 (칸, 칸의 반 대각선과 REFRESH 몫은 따로 더함) — 그림자가 화면 안으로 드리우는 몫
const TALL := 13.0                # 키 큰 꽃이 화면 아래 밖에서 위로 솟아 들어오는 몫 (땅 위 칸, 화면 높이 14 × cos 48° / sin 48°)
## 멀리 덩이는 아직 끔 (2026-11-08 캡처 perf_ta_after3_forest_5: 면 방향이 뒤집혀 껍데기 외곽선 색만 보이고, 육각 기둥이
## 줄기 + 꽃 머리 실루엣을 못 살림 → '꽃숲'으로 안 읽힘). 블렌더에서 모양마다 "__far" 노드를 만들면 그것을 쓰도록 바꿀 자리.
const FAR_LOD := false
const FAR_PPU := 6.0              # 이보다 멀리 축소하면 멀리 덩이
const LOD_GAP := 1.5
const TINY_PPU := 1.5             # 이보다 멀리: 납작한 것은 숨김 (1~2px도 안 됨)
const TINY_GAP := 0.5
## 아주 멀리서 숨기는 납작한 것
const TINY := ["tuft", "clover", "lily", "flora/moss_a", "flora/moss_c", "flora/clover_a", "flora/grass_b", "flora/twig_pile_a",
	"flora/twig_pile_b", "flora/fallen_leaf_dry", "rock_small", "flowers", "flowers_b"]

static var _proxies := {}         # 모델 이름 → 멀리 덩이 ArrayMesh

var parent: Node3D
var cull := true                  # false = 늘 전부 (캡처·시험)
## 모양 → {"cells": {Vector2i: PackedFloat32Array}, "n": 전체 수, "near": [MMI…], "far": MMI 또는 null, "shadow": bool}
var _kinds := {}
var _rect := Rect2()              # 지금 담은 보는 땅의 테두리 사각형 (부모 좌표 xz)
var _vis := {}                    # 지금 담은 칸 (Vector2i → true)
var _all := true                  # 지금 전부 담겨 있나
var far := false
var tiny_off := false
var n_total := 0                  # 놓은 인스턴스 수
var n_drawn := 0                  # 지금 버퍼에 담긴 수 (시험·측정용)


func _init(p: Node3D) -> void:
	parent = p


## groups: 모양 이름 → Array[Transform3D] (부모 좌표). VillageView._flush가 부른다.
func set_groups(groups: Dictionary, no_shadow: Array = []) -> void:
	for c in parent.get_children():
		c.queue_free()
	_kinds.clear()
	n_total = 0
	for k: String in groups:
		var xfs: Array = groups[k]
		if xfs.is_empty():
			continue
		var m := Art.model(k)
		if m["mesh"] == null:
			continue
		var cells := {}
		for xf: Transform3D in xfs:
			var key := Vector2i(floori(xf.origin.x / CELL), floori(xf.origin.z / CELL))
			var b := xf.basis
			var o := xf.origin
			var arr: PackedFloat32Array = cells.get(key, PackedFloat32Array())     # 묶음 배열은 값 복사 — 붙인 뒤 다시 넣는다
			arr.append_array(PackedFloat32Array([b.x.x, b.y.x, b.z.x, o.x, b.x.y, b.y.y, b.z.y, o.y, b.x.z, b.y.z, b.z.z, o.z]))
			cells[key] = arr
		var shadow := not (k in no_shadow)
		var near: Array = []
		for key in ["mesh", "lines"]:
			if m[key] == null:
				continue
			near.append(_mmi(m[key], shadow and key == "mesh"))
		_kinds[k] = {"cells": cells, "n": xfs.size(), "near": near, "far": null, "shadow": shadow}
		n_total += xfs.size()
	_all = true
	_rect = Rect2()
	_fill(true)


func _mmi(mesh: Mesh, shadow: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


## 매 화면 (VillageView.sync): 확대(ppu)와 카메라가 땅에서 보는 사각형(부모 좌표 xz, 없으면 전부)
func update(ppu: float, view: Dictionary) -> void:
	var has_view := bool(view.get("ok", false))
	var rect: Rect2 = view.get("rect", Rect2())
	var want_far := far
	if not FAR_LOD:
		want_far = false
	elif ppu < FAR_PPU:
		want_far = true
	elif ppu > FAR_PPU + LOD_GAP:
		want_far = false
	var want_tiny := tiny_off
	if ppu < TINY_PPU:
		want_tiny = true
	elif ppu > TINY_PPU + TINY_GAP:
		want_tiny = false
	var lod_changed := want_far != far or want_tiny != tiny_off
	far = want_far
	tiny_off = want_tiny
	var everything := not cull or not has_view
	if not lod_changed:
		if everything and _all:
			return
		if not everything and not _all and _near(_rect, rect):
			return
	if everything:
		_all = true
	else:
		_all = false
		_rect = rect
		_vis = visible_cells(view["poly"])
	_fill(lod_changed)


static func _near(a: Rect2, b: Rect2) -> bool:
	return absf(a.position.x - b.position.x) < REFRESH and absf(a.position.y - b.position.y) < REFRESH \
		and absf(a.end.x - b.end.x) < REFRESH and absf(a.end.y - b.end.y) < REFRESH


## 볼록 다각형(부모 좌표 xz)에 걸치는 격자 칸 — 칸 가운데가 (다각형 + 반 대각선 + REFRESH + MARGIN) 안이면
static func visible_cells(poly: PackedVector2Array) -> Dictionary:
	var out := {}
	var grown := Geometry2D.offset_polygon(poly, CELL * 0.71 + REFRESH + MARGIN)
	if grown.is_empty():
		return out
	var g: PackedVector2Array = grown[0]
	var bb := Rect2(g[0], Vector2.ZERO)
	for p in g:
		bb = bb.expand(p)
	for cy in range(floori(bb.position.y / CELL), floori(bb.end.y / CELL) + 1):
		for cx in range(floori(bb.position.x / CELL), floori(bb.end.x / CELL) + 1):
			if Geometry2D.is_point_in_polygon(Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL), g):
				out[Vector2i(cx, cy)] = true
	return out


func _fill(lod_changed: bool) -> void:
	n_drawn = 0
	for k: String in _kinds:
		var e: Dictionary = _kinds[k]
		var buf := PackedFloat32Array()
		if not (tiny_off and k in TINY):
			var cells: Dictionary = e["cells"]
			if _all:
				for key: Vector2i in cells:
					buf.append_array(cells[key])
			elif _vis.size() < cells.size():
				for key: Vector2i in _vis:
					if cells.has(key):
						buf.append_array(cells[key])
			else:
				for key: Vector2i in cells:
					if _vis.has(key):
						buf.append_array(cells[key])
		var n := buf.size() / 12
		n_drawn += n
		var show: Array = e["near"]
		var hide: Array = []
		if far:
			if e["far"] == null:
				e["far"] = _mmi(proxy(k), e["shadow"])
			show = [e["far"]]
			hide = e["near"]
		elif e["far"] != null:
			hide = [e["far"]]
		for mmi: MultiMeshInstance3D in hide:
			if mmi.multimesh.instance_count != 0:
				mmi.multimesh.instance_count = 0
			mmi.visible = false
		for mmi: MultiMeshInstance3D in show:
			var mm := mmi.multimesh
			mm.instance_count = n
			if n > 0:
				mm.buffer = buf
			mmi.visible = n > 0


## 카메라가 땅(높이 y0~y1 사이)에서 보는 사각형 → 부모 좌표 xz. 정사영·원근 모두 화면 네 귀퉁이 빛줄기를 두 높이 평면에 맞춘다.
## 키 큰 꽃이 화면 아래에서 솟아 들어오는 몫은 TALL만큼 카메라 쪽(화면 아래)으로 늘린다.
static func view_rect(cam: Camera3D, parent: Node3D, y0: float, y1: float) -> Dictionary:
	if cam == null or not cam.is_inside_tree():
		return {"ok": false}
	var vp := cam.get_viewport()
	var sz := vp.get_visible_rect().size
	var inv := parent.global_transform.affine_inverse()
	var pts: Array[Vector2] = []
	for uv: Vector2 in [Vector2.ZERO, Vector2(sz.x, 0), Vector2(0, sz.y), sz]:
		var o := cam.project_ray_origin(uv)
		var d := cam.project_ray_normal(uv)
		if absf(d.y) < 0.05:
			return {"ok": false}     # 거의 수평 (하늘까지 보임) — 자르지 않음
		for y in [y0, y1]:
			var t: float = (y - o.y) / d.y
			if t < 0.0:
				return {"ok": false}
			var p: Vector3 = inv * (o + d * t)
			pts.append(Vector2(p.x, p.z))
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	# 화면 아래(카메라 쪽)로 TALL — 카메라 앞 방향(-z 축)의 부모 좌표 수평 성분 반대쪽으로 늘림
	var fwd: Vector3 = inv.basis * (-cam.global_transform.basis.z)
	var f2 := Vector2(fwd.x, fwd.z)
	var all := PackedVector2Array(pts)
	if f2.length() > 0.01:
		var back := -f2.normalized() * TALL
		for p in pts:
			all.append(p + back)
	return {"ok": true, "rect": r, "poly": Geometry2D.convex_hull(all)}


## 멀리 덩이: 모델을 높이 띠 BANDS개로 나눠, 띠마다 그 띠 삼각형들의 넓이 가중 평균 색 · 축에서의 폭(넓이 가중 85% 지점)으로
## 육각 기둥을 쌓는다 (옆 6면 + 윗면). 원점·축은 모델 그대로라 같은 Transform을 쓴다. 껍데기 외곽선용 CUSTOM0은 Art._Acc가 채움.
const BANDS := 4
const SIDES := 6


static func proxy(name: String) -> Mesh:
	if _proxies.has(name):
		return _proxies[name]
	var src: ArrayMesh = Art.model(name)["mesh"]
	var a := src.surface_get_arrays(0)
	var pv: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var pc: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var bb := src.get_aabb()
	var h0 := bb.position.y
	var hh := maxf(bb.size.y, 0.001)
	var cx := (bb.position.x + bb.end.x) * 0.5
	var cz := (bb.position.z + bb.end.z) * 0.5
	var col_sum: Array = []
	var w_sum: Array = []
	var rads: Array = []          # 띠마다 [[반지름, 넓이]…]
	for b in BANDS:
		col_sum.append(Color(0, 0, 0, 0))
		w_sum.append(0.0)
		rads.append([])
	for t in range(0, ix.size(), 3):
		var p0 := pv[ix[t]]
		var p1 := pv[ix[t + 1]]
		var p2 := pv[ix[t + 2]]
		var area := (p1 - p0).cross(p2 - p0).length() * 0.5 + 1e-6
		var c := (p0 + p1 + p2) / 3.0
		var b := clampi(int((c.y - h0) / hh * BANDS), 0, BANDS - 1)
		var cc: Color = (pc[ix[t]] + pc[ix[t + 1]] + pc[ix[t + 2]]) / 3.0
		col_sum[b] = (col_sum[b] as Color) + cc * area
		w_sum[b] = float(w_sum[b]) + area
		for p: Vector3 in [p0, p1, p2]:
			(rads[b] as Array).append([Vector2(p.x - cx, p.z - cz).length(), area])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last_col := Color(0.4, 0.6, 0.3)
	for b in BANDS:
		var wb: float = w_sum[b]
		if wb <= 1e-5:
			continue
		var col: Color = (col_sum[b] as Color) / wb
		col.a = 1.0
		last_col = col
		var rl: Array = rads[b]
		rl.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		var tot := 0.0
		for e: Array in rl:
			tot += e[1]
		var acc := 0.0
		var r := 0.05
		for e: Array in rl:
			acc += e[1]
			r = e[0]
			if acc >= tot * 0.85:
				break
		r = maxf(r, hh * 0.02)
		var y_lo := h0 + hh * b / BANDS
		var y_hi := h0 + hh * (b + 1) / BANDS
		var lin := col.srgb_to_linear()          # Art._Acc가 sRGB로 되돌린다 (glTF 꼭짓점 색과 같게)
		for s in SIDES:
			var a0 := TAU * s / SIDES
			var a1 := TAU * (s + 1) / SIDES
			var q0 := Vector3(cx + cos(a0) * r, y_lo, cz + sin(a0) * r)
			var q1 := Vector3(cx + cos(a1) * r, y_lo, cz + sin(a1) * r)
			var q2 := Vector3(cx + cos(a1) * r, y_hi, cz + sin(a1) * r)
			var q3 := Vector3(cx + cos(a0) * r, y_hi, cz + sin(a0) * r)
			var nn := Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
			for q: Vector3 in [q0, q2, q1, q0, q3, q2]:
				st.set_color(lin)
				st.set_normal(nn)
				st.add_vertex(q)
			var top := Vector3(cx, y_hi, cz)
			for q: Vector3 in [top, q2, q3]:
				st.set_color(lin)
				st.set_normal(Vector3.UP)
				st.add_vertex(q)
	var raw := st.commit()
	var acc2 := Art._Acc.new()
	acc2.add(raw, Transform3D.IDENTITY, false, true)
	var res: Dictionary = acc2.build(Art.body_mat(), Art.line_mat())
	var mesh: Mesh = res["mesh"] if res["mesh"] != null else src
	_proxies[name] = mesh
	return mesh
