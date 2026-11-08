## 꽃숲·풀·소품 묶음 (ROADMAP P1 성능 — 폰 실측 docs/PERF_PHONE_2026-11-07.md: 꽃숲·풀이 삼각형의 2/3).
## 예전 VillageView._flush는 모양마다 MultiMesh 하나를 마을 둘레 전체(반지름 40칸, 먼 숲은 200칸)에 깔았다 →
## AABB가 땅 전체라 화면 밖 자르기가 한 번도 일어나지 않고, 세상 전체로 축소해도 같은 삼각형을 다 그렸다.
## 여기서는 같은 모양끼리 MultiMesh 하나(그리기 횟수는 그대로)이되:
##   ① 화면 자르기 (CPU): 인스턴스를 CELL칸 격자에 미리 나눠 두고, 카메라가 땅에서 보는 볼록 다각형(화면 네 귀퉁이 × 땅 높이 둘
##      + 키 큰 꽃 몫 TALL, 둘레 여유)에 든 칸만 버퍼에 담는다. 보는 땅이 REFRESH칸 넘게 움직일 때만 다시 담는다 (몇 화면에 한 번).
##      보이는 것이 없으면 그 모양은 그리지 않음. (사각형으로 자르면 기본 확대의 비스듬한 화면이 마을 장식 전체를 덮어 효과가 없었다.)
##      — 덩이를 칸마다 MultiMesh로 쪼개면 그리기 횟수가 칸 수 × 모양 수로 늘어난다 (예산 300번을 바로 넘음). 그래서 쪼개지 않는다.
##   ② 거리 단계 (LOD, P1 3차): 모델의 "__far" 노드 (art/src/flora_far.py — 가까이 모양을 줄인 것, 삼각형 약 15~35%)를
##      Art.model_far로 — 접힌 곳 선·껍데기 외곽선 없음 (화면 깊이 외곽선이 둘레를 그림). 땅에 붙은 잔것(CLUTTER: 덤불·클로버·
##      버섯·고사리)은 ppu < LOW_FAR_PPU, 그 밖(꽃·장미 덤불·수국·이끼 둔덕…)은 ppu < BIG_FAR_PPU에서 바꾼다 (경계 ±FAR_GAP 이력 — 모바일은
##      visibility_range 페이드가 없어 확대 값으로). 아주 멀리(TINY_PPU 아래)는 납작한 것(이끼·클로버·풀 포기…)을 숨김.
## 자식 MultiMeshInstance3D의 multimesh.mesh는 가까이 단계에서 Art.model(이름)["mesh"] 그대로 (시험이 모양을 확인함).
class_name FloraBatch
extends RefCounted

const CELL := 4.0                 # 미리 나눠 두는 격자 (칸)
const REFRESH := 2.0              # 카메라가 보는 땅의 테두리가 이만큼(칸) 넘게 움직이면 다시 담음
const MARGIN := 3.0               # 화면 둘레 여유 (칸, 칸의 반 대각선과 REFRESH 몫은 따로 더함) — 그림자가 화면 안으로 드리우는 몫
const TALL := 13.0                # 키 큰 꽃이 화면 아래 밖에서 위로 솟아 들어오는 몫 (땅 위 칸, 화면 높이 14 × cos 48° / sin 48°)
## 멀리 모양으로 바꾸는 확대 (P1 3차 — 메인 판단 2026-11-08: 낮은 것은 24, 큰 꽃은 ppu 16에서 나란히 비교해 구별이 어려우면 24, 아니면 12)
const LOW_FAR_PPU := 24.0
const BIG_FAR_PPU := 8.0          # 12에서는 장미 소용돌이·데이지 꽃잎이 바뀌는 게 보였음 (p1c_fc2_village_ppu10_*)
const FAR_GAP := 0.1              # 경계 ±10%
## ppu 16에서 나란히 비교해 가까이와 구별이 안 되는 잔것만 (2026-11-08 p1c_fc_* 캡처 — 장미·수국·이끼 둔덕은 줄이면 티가 남)
const CLUTTER := ["clover", "mushrooms", "bush", "bush_b", "bush_flower", "bush_berry", "fern", "flowers", "flowers_b",
	"flora/clover_a", "flora/clover_b", "flora/clover_flower", "flora/fern_a", "flora/fern_b",
	"props/pf_cairn", "props/pf_moss", "props/pf_fern"]          # polyfork 잔것 (2026-11-08 — ppu 16에서 멀리 모양 하나만 그림)
const TINY_PPU := 1.5             # 이보다 멀리: 납작한 것은 숨김 (1~2px도 안 됨)
const TINY_GAP := 0.5
## (P1 2차) 아트 바이블 8.9: ppu < 24에서 꽃·풀의 접힌 곳 선(lines MultiMesh)을 끈다 — 경계 ±10% 이력.
## 껍데기 외곽선·화면 깊이 외곽선은 그대로라 둘레는 남고, 꽃잎 안쪽 가는 선만 빠진다 (16 px 주민 크기에선 거의 안 보임).
const LINES_PPU := 24.0
const LINES_GAP := 0.1
## (P1 2차) 그림자는 큰 꽃만 (아트 바이블 8.10 · 메인 판단 2026-11-08): 화면 높이(모델 높이 × 놓은 배율 중앙값)가 이 칸 이상인 모양만
## 그림자를 드리운다. 주민 키 = 1칸. 작은 꽃·풀대·고사리·덤불·작은 바위는 그림자 패스에서 빠진다 (그리기·그림자 삼각형 절약).
const SHADOW_MIN_H := 9.0
## (P1 2차) 아트 바이블 8.7 각주: 땅에 낮게 붙은 것(덤불·클로버·버섯·고사리 포기·조약돌 — 화면 높이가 이 칸 미만)은 ppu < 24에서
## 껍데기 외곽선 패스도 끈다 (화면 깊이 외곽선이 둘레를 대신). 삼각형·그리기 반으로. 키 큰 꽃은 껍데기 그대로.
const HULL_MIN_H := 2.0
## 아주 멀리서 숨기는 납작한 것
const TINY := ["tuft", "clover", "lily", "flora/moss_a", "flora/moss_c", "flora/clover_a", "flora/grass_b", "flora/twig_pile_a",
	"flora/twig_pile_b", "flora/fallen_leaf_dry", "rock_small", "flowers", "flowers_b"]

var parent: Node3D
var cull := true                  # false = 늘 전부 (캡처·시험)
## 모양 → {"cells": {Vector2i: PackedFloat32Array}, "n": 전체 수, "near": [MMI…], "far": MMI 또는 null (모델에 "__far"가 없으면 늘 null),
##   "far_mesh": Mesh 또는 null, "big": 키 큰 꽃인가, "shadow": bool}
var _kinds := {}
var _rect := Rect2()              # 지금 담은 보는 땅의 테두리 사각형 (부모 좌표 xz)
var _vis := {}                    # 지금 담은 칸 (Vector2i → true)
var _all := true                  # 지금 전부 담겨 있나
var far := false                  # 꽃(잔것 밖)이 멀리 모양인가
var far_low := false              # 잔것(CLUTTER)이 멀리 모양인가
var force_far := -1               # -1 = 확대 따라 · 0 = 늘 가까이 · 1 = 늘 멀리 (나란히 비교 캡처)
var tiny_off := false
var lines_off := false            # ppu < LINES_PPU: 접힌 곳 선 끔
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
		var hgt := shown_height(m["mesh"], xfs)
		var shadow := not (k in no_shadow) and hgt >= SHADOW_MIN_H
		var near: Array = []
		var lines: MultiMeshInstance3D = null
		for key in ["mesh", "lines"]:
			if m[key] == null:
				continue
			var mmi := _mmi(m[key], shadow and key == "mesh")
			near.append(mmi)
			if key == "lines":
				lines = mmi
		_kinds[k] = {"cells": cells, "n": xfs.size(), "near": near, "lines": lines, "far": null, "shadow": shadow, "low": hgt < HULL_MIN_H,
			"far_mesh": Art.model_far(k)["mesh"], "big": not (k in CLUTTER)}
		n_total += xfs.size()
	_all = true
	_rect = Rect2()
	_fill(true)


## 화면에서의 높이 (칸): 모델 높이 × 놓은 세로 배율의 중앙값
static func shown_height(mesh: Mesh, xfs: Array) -> float:
	if mesh == null or xfs.is_empty():
		return 0.0
	var sy: Array = []
	for xf: Transform3D in xfs:
		sy.append(xf.basis.y.length())
	sy.sort()
	return mesh.get_aabb().size.y * float(sy[sy.size() / 2])


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
	var want_far := _hyst(far, ppu, BIG_FAR_PPU, FAR_GAP)
	var want_far_low := _hyst(far_low, ppu, LOW_FAR_PPU, FAR_GAP)
	if force_far >= 0:
		want_far = force_far == 1
		want_far_low = want_far
	var want_tiny := tiny_off
	if ppu < TINY_PPU:
		want_tiny = true
	elif ppu > TINY_PPU + TINY_GAP:
		want_tiny = false
	var want_lines_off := lines_off
	if ppu < LINES_PPU * (1.0 - LINES_GAP):
		want_lines_off = true
	elif ppu > LINES_PPU * (1.0 + LINES_GAP):
		want_lines_off = false
	var lod_changed := want_far != far or want_far_low != far_low or want_tiny != tiny_off or want_lines_off != lines_off
	far = want_far
	far_low = want_far_low
	tiny_off = want_tiny
	lines_off = want_lines_off
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


## 확대가 at×(1−gap) 아래면 멀리, at×(1+gap) 위면 가까이, 그 사이는 그대로
static func _hyst(cur: bool, ppu: float, at: float, gap: float) -> bool:
	if ppu < at * (1.0 - gap):
		return true
	if ppu > at * (1.0 + gap):
		return false
	return cur


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
		if lines_off and e["lines"] != null:
			show = show.filter(func(x: MultiMeshInstance3D) -> bool: return x != e["lines"])
			hide = [e["lines"]]
		if not (e["near"] as Array).is_empty():
			var body: MultiMeshInstance3D = e["near"][0]
			var want_mat: Material = Art.flat_mat() if lines_off and bool(e["low"]) else null
			if body.material_override != want_mat:
				body.material_override = want_mat
		var kf := far if bool(e["big"]) else far_low
		if kf and e["far_mesh"] != null:
			if e["far"] == null:
				e["far"] = _mmi(e["far_mesh"], e["shadow"])
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
