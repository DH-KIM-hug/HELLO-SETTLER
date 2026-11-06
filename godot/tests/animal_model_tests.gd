## B3 동물 3D 모델 (art/src/build_animals.py → art/models/animals/<종>.glb). tests/run.gd가 부름 (`-- animals` = 이것만, 몇 초).
## 종마다 부품(몸·머리·다리·꼬리 …)이 glb에 모두 있는지 · 삼각형이 예산 안인지 (v2: 물고기 120, 나머지 400~900) ·
## 크기가 주민과 맞는지 (토끼는 발목~정강이, 사슴 등은 어른 어깨 아래, 들소는 사람보다 큼 — 같은 모델 단위, 어른 키 약 1.9).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []

const QUAD := ["body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail"]
const SPECIES := {
	"fish_a": ["body", "tail"], "fish_b": ["body", "tail"],
	"deer": QUAD, "fawn": QUAD, "rabbit": QUAD, "wolf": QUAD, "boar": QUAD, "wild_sheep": QUAD, "aurochs": QUAD,
	"dog": QUAD, "puppy": QUAD, "pig": QUAD, "sheep": QUAD, "cow": QUAD, "donkey": QUAD,
	"chicken": ["body", "head", "leg_l", "leg_r", "wing_l", "wing_r", "tail"],
}
const RESIDENT_TOP := 1.9


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== B3 동물 3D 모델: 부품 · 삼각형 · 크기")
	run.timed(self, ["test_parts_exist", "test_tri_budget", "test_scale"])


static func _tris(m: Mesh) -> int:
	var n := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		n += (ix.size() if not ix.is_empty() else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


## 모델 맨 위 높이 (부품 메시 AABB + 관절 자리, 쉬는 자세)
static func _top(parts: Dictionary) -> float:
	var top := -INF
	for pn: String in parts:
		var d: Dictionary = parts[pn]
		var bb: AABB = (d["mesh"] as Mesh).get_aabb()
		top = maxf(top, (d["origin"] as Vector3).y + bb.end.y)
	return top


func test_parts_exist() -> void:
	var missing: Array = []
	for k: String in SPECIES:
		if not Art.exists("animals/" + k):
			missing.append(k + ".glb")
			continue
		var p := Art.parts("animals/" + k)
		for pn: String in SPECIES[k]:
			if not p.has(pn) or p[pn]["mesh"] == null:
				missing.append(k + "/" + pn)
		for pn: String in p:
			if not pn in SPECIES[k]:
				missing.append(k + " 남는 부품 " + pn)
	check(missing.is_empty(), "동물 %d종 부품이 glb에 모두 있음 %s" % [SPECIES.size(), "" if missing.is_empty() else str(missing)])


func test_tri_budget() -> void:
	var bad: Array = []
	var row: Array = []
	for k: String in SPECIES:
		var p := Art.parts("animals/" + k)
		var n := 0
		for pn: String in p:
			n += _tris(p[pn]["mesh"])
		row.append("%s %d" % [k, n])
		var lo := 40 if k.begins_with("fish") else 400
		var hi := 120 if k.begins_with("fish") else 900
		if n < lo or n > hi:
			bad.append("%s %d (%d~%d)" % [k, n, lo, hi])
	print("  삼각형: ", ", ".join(row))
	check(bad.is_empty(), "삼각형 예산 (물고기 ≤ 120, 나머지 400~900) %s" % ("" if bad.is_empty() else str(bad)))


func test_scale() -> void:
	var top := {}
	for k: String in SPECIES:
		top[k] = _top(Art.parts("animals/" + k))
	print("  높이 (주민 ≈ %.1f): %s" % [RESIDENT_TOP, ", ".join(top.keys().map(func(k: String) -> String: return "%s %.2f" % [k, top[k]]))])
	check(top["rabbit"] < 0.65, "토끼는 작다 (발목~정강이, %.2f)" % top["rabbit"])
	check(top["chicken"] < 0.8 and top["puppy"] < top["dog"] and top["fawn"] < top["deer"], "닭 작음 · 새끼가 어미보다 작음")
	check(top["deer"] > 1.2 and top["deer"] < RESIDENT_TOP, "사슴 ≈ 주민 키 아래 (%.2f)" % top["deer"])
	check(top["aurochs"] > RESIDENT_TOP and top["aurochs"] > top["cow"], "들소는 사람보다 크고 소보다 큼 (%.2f)" % top["aurochs"])
	check(top["fish_a"] < 0.3, "물고기는 아주 작음")
