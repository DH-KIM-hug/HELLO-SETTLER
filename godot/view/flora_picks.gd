## 꽃숲 덩이 누르기 (docs/UI.md '꽃 정보 카드') — 화면이 그린 꽃·풀·고사리·이끼 덩이 하나하나의 가벼운 기록.
## VillageView가 MultiMesh 묶음을 다시 만들 때 (나무 = 시뮬 나무 · 장식 숲 · 소품 무리 · 멀리 숲) 층마다 하나씩 새로 채운다.
## 기록: 자리 (VillageView 좌표 = 병 데이터 좌표) · 화면 높이·반지름 (칸) · 모델 이름 · 시뮬 나무인가 (나무꾼이 베는 꽃대).
## 고르기는 화면 거리로 (주민 누르기와 같은 방식 — 밑동~꼭대기 선분까지, 화면 반지름은 폭만큼). 시뮬은 읽지도 바꾸지도 않는다 (ADR-0001).
## 하늘의 것 (큰 민들레 · 초거대 해바라기 · 목화 덤불)은 시뮬 자리를 읽어 같은 줄에서 함께 고른다 (extras).
class_name FloraPicks
extends RefCounted

const PICK_PX := 20.0             # 화면 최소 반지름 (px) — 멀리서도 손가락으로 누를 수 있게
const MAX_PX := 70.0              # 화면 최대 반지름 (큰 고사리 하나가 화면 절반을 먹지 않게)

var xs := PackedFloat32Array()
var ys := PackedFloat32Array()
var zs := PackedFloat32Array()
var hs := PackedFloat32Array()    # 화면 높이 (칸)
var rs := PackedFloat32Array()    # 땅 위 반지름 (칸)
var names := PackedStringArray()
var sim := PackedByteArray()      # 1 = 시뮬 나무 (Village.trees) 자리


## 누를 수 있는 모양인가 (꽃·풀·고사리·이끼 — 나뭇가지 더미·돌·버섯·잔것은 아님)
static func pickable(name: String) -> bool:
	return FlowerInfo.SPECIES.has(name)


func add(name: String, at: Vector3, s: float, is_sim := false) -> void:
	var m: Mesh = Art.model(name).get("mesh")
	var sz := m.get_aabb().size if m != null else Vector3.ONE
	xs.append(at.x)
	ys.append(at.y)
	zs.append(at.z)
	hs.append(maxf(0.3, sz.y * s))
	rs.append(maxf(0.4, maxf(sz.x, sz.z) * s * 0.42))
	names.append(name)
	sim.append(1 if is_sim else 0)


func size() -> int:
	return names.size()


## 가까운 같은 이름 수 / 전체 수 (반지름 r칸 안) — 군락 한 줄 ("이 근처는 양귀비 들판")
func count_near(p: Vector2, r: float, name: String) -> Vector2i:
	var same := 0
	var all := 0
	var r2 := r * r
	for i in names.size():
		var dx := xs[i] - p.x
		var dz := zs[i] - p.y
		if dx * dx + dz * dz > r2:
			continue
		all += 1
		if names[i] == name:
			same += 1
	return Vector2i(same, all)


## 누른 곳의 꽃숲 덩이 → {name, at (데이터 좌표 Vector2), top (전역 Vector3 — 카메라 비키기), sim, village, view, kind ("clump"·"dandelion"·"sunflower"·"cotton"), stage, layer, src (하늘의 것 = 시뮬 사전 — 읽기만)}
## views = [[Village, VillageView], …] · 없으면 빈 사전
static func pick(cam: Camera3D, views: Array, sp: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for vi in views.size():
		var vv: Array = views[vi]
		var q: Village = vv[0]
		var vw: VillageView = vv[1]
		if vw == null or not vw.is_visible_in_tree():
			continue
		var xf := vw.global_transform
		for layer: String in vw.flora_picks:
			var fp: FloraPicks = vw.flora_picks[layer]
			var node: Node3D = vw.get(layer) as Node3D
			if node != null and not node.is_visible_in_tree():
				continue
			for i in fp.names.size():
				var d := _score(cam, xf, Vector3(fp.xs[i], fp.ys[i], fp.zs[i]), fp.hs[i], fp.rs[i], sp)
				if d < best_d:
					best_d = d
					best = {"name": fp.names[i], "at": Vector2(fp.xs[i], fp.zs[i]), "top": xf * Vector3(fp.xs[i], fp.ys[i] + fp.hs[i] * 0.5, fp.zs[i]),
						"sim": fp.sim[i] == 1, "village": q, "view": vw, "kind": "clump", "stage": "", "layer": layer, "src": {}}
		for e: Dictionary in extras(q, vw, vi == 0):
			var d := _score(cam, xf, e["pos"], float(e["h"]), float(e["r"]), sp)
			if d < best_d:
				best_d = d
				best = {"name": e["name"], "at": Vector2(e["pos"].x, e["pos"].z), "top": xf * (e["pos"] + Vector3(0, float(e["h"]) * 0.5, 0)),
					"sim": false, "village": q, "view": vw, "kind": e["kind"], "stage": e["stage"], "layer": "", "src": e["src"]}
	return best


## 화면 거리 / 반지름 (1보다 작으면 눌림 — 작을수록 가까움). 카메라 뒤 = INF
static func _score(cam: Camera3D, xf: Transform3D, base: Vector3, h: float, r: float, sp: Vector2) -> float:
	var g0 := xf * base
	var g1 := xf * (base + Vector3(0, h, 0))
	if cam.is_position_behind(g0) or cam.is_position_behind(g1):
		return INF
	var a := cam.unproject_position(g0)
	var b := cam.unproject_position(g1)
	var d := Geometry2D.get_closest_point_to_segment(sp, a, b).distance_to(sp)
	if d > MAX_PX * 1.5:
		return INF
	var side := cam.unproject_position(g0 + cam.global_basis.x * r).distance_to(a)
	var rad := clampf(side, PICK_PX, MAX_PX)
	if d >= rad:
		return INF
	return d / rad


## 하늘의 것 (시뮬 자리 — 읽기만): 큰 민들레 (Flora.dands) · 초거대 해바라기·목화 (WorldWater — 세상에 하나뿐이라 첫 화면만)
static func extras(q: Village, vw: VillageView, world_too := true) -> Array:
	var out: Array = []
	if q.flora != null:
		for d: Dictionary in q.flora.dands:
			var st := String(d.get("st", "leaf"))
			var x := float(d["x"])
			var z := float(d["y"])
			var h := 1.0 if st == "sprout" else (1.2 if st == "leaf" else 3.6)
			out.append({"name": "big/dandelion", "pos": Vector3(x, vw.gy(x, z), z), "h": h, "r": 1.0, "kind": "dandelion", "stage": st, "src": d})
	if q.water is WorldWater and world_too:
		var ww := q.water as WorldWater
		for sf: Dictionary in ww.sunflowers:
			var x := float(sf["x"])
			var z := float(sf["y"])
			out.append({"name": "big/sunflower", "pos": Vector3(x, vw.gy(x, z), z), "h": 24.0, "r": 2.6, "kind": "sunflower", "stage": String(sf.get("stage", "")), "src": sf})
		for b: Dictionary in ww.cotton:
			var x := float(b["x"])
			var z := float(b["y"])
			out.append({"name": "big/cotton", "pos": Vector3(x, vw.gy(x, z), z), "h": 3.2, "r": 1.8, "kind": "cotton", "stage": "boll" if b.get("boll", false) else "", "src": b})
	return out
