## 땅 위 잔것 크기 재기 (headless): 모델 높이·폭 × 놓는 배율 → 화면 크기 (주민 키 = 1칸)
##   godot --headless --path godot -s tools/probe_scale.gd
extends SceneTree

const KINDS := ["bush", "bush_b", "bush_flower", "bush_berry", "fern", "props/pf_fern", "props/pf_moss", "props/pf_cairn",
	"mushrooms", "rocks", "rocks_b", "rock_small", "clover", "tuft", "flowers", "flowers_b", "flora/twig_pile_a", "flora/twig_pile_b",
	"flora/fallen_leaf_dry", "flora/moss_a", "flora/moss_c", "flora/clover_a", "props/pf_bench", "props/pf_cordwood", "props/pf_fence"]


func _initialize() -> void:
	for k: String in KINDS:
		var m: Mesh = Art.model(k).get("mesh")
		if m == null:
			print(k, " MISSING")
			continue
		var sz := m.get_aabb().size
		var s := VillageView.clutter_scale(k)
		print("%-24s model h=%.2f w=%.2f  x%.3f => h=%.2f w=%.2f tris=%d" % [k, sz.y, maxf(sz.x, sz.z), s, sz.y * s,
			maxf(sz.x, sz.z) * s, _tris(m)])
	quit()


func _tris(m: Mesh) -> int:
	var n := 0
	for i in m.get_surface_count():
		var a := m.surface_get_arrays(i)
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		n += (idx.size() if idx.size() > 0 else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n
