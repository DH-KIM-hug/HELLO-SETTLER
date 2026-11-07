## E3-3 · E3-4(모양) 소인의 세상 (GAME_DESIGN 3.0) — tests/run.gd가 부름 (`-- tinyworld`).
## 큰 나무 다섯 (한 그루씩 · 서로 멀리 · 키트 자리·물에서 멀리 · 베지 않음 · 저장 · 옛 저장) · 과일나무 열매 ·
## 시뮬레이션 나무 = 꽃숲 덩이로 그림 (옛 나무 모델 없음, 벤 자리 = 나뭇가지 더미) · 철마다 잎 · 짐 통나무 = 나뭇가지 다발 · 카메라 앞면.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== E3 소인의 세상: 큰 나무 다섯 · 꽃숲 · 나뭇가지")
	var old_nav := StartFlow.navigate
	StartFlow.navigate = false
	run.timed(self, ["test_great_trees", "test_great_trees_save", "test_world_tree_is_cherry", "test_great_tree_budget", "test_giant_fruit", "test_carry_twigs", "test_camera_clears_trees", "test_view_flora"])
	StartFlow.navigate = old_nav
	GroundLook.month_override = 0


func test_great_trees() -> void:
	for sz: int in [WorldCfg.SMALL_SIZE, WorldCfg.SIZE]:
		var jw := JarWorld.create_with_kit(23, sz, Kits.make([]))
		var ww := jw.water
		var kinds := {}
		for t: Dictionary in ww.great_trees:
			kinds[t["kind"]] = int(kinds.get(t["kind"], 0)) + 1
		var one_each := ww.great_trees.size() == 5
		for k: String in GreatTrees.KINDS:
			one_each = one_each and int(kinds.get(k, 0)) == 1
		check(one_each, "세상 %d: 큰 나무 다섯이 한 그루씩 (%s)" % [sz, kinds])
		var min_d := INF
		for i in ww.great_trees.size():
			for j in range(i + 1, ww.great_trees.size()):
				var a: Dictionary = ww.great_trees[i]
				var b: Dictionary = ww.great_trees[j]
				min_d = minf(min_d, Vector2(a["x"], a["y"]).distance_to(Vector2(b["x"], b["y"])))
		check(min_d > ww.rr * 0.4, "서로 멀리 (가장 가까운 둘 %.0f칸 > 반지름의 40%% %.0f)" % [min_d, ww.rr * 0.4])
		var v := jw.primary()
		var near_kit := INF
		var wet := 0
		var near_tree := 0
		var free_at := 0
		for t: Dictionary in ww.great_trees:
			var p := Vector2(t["x"], t["y"])
			near_kit = minf(near_kit, p.distance_to(v.center))
			for k in ww.cells_near(p, float(t["r"])):
				if ww.depth(k) > 0.004:
					wet += 1
			for tr: Dictionary in v.trees:
				if Vector2(tr["x"], tr["y"]).distance_to(p) < float(t["r"]):
					near_tree += 1
			if v.is_free(p.x, p.y, 1.0) or not GreatTrees.blocks(ww, p.x + float(t["r"]) * 0.5, p.y, 1.0):
				free_at += 1
		check(near_kit > GreatTrees.kit_apart(ww), "첫 무리 터에서 멀리 (가장 가까운 큰 나무 %.0f칸)" % near_kit)
		check(wet == 0, "큰 나무 줄기 둘레는 마른 땅 (물 칸 %d)" % wet)
		check(near_tree == 0 and free_at == 0, "베지 않음: 마을 나무(벌목 대상)에 없고 그 자리엔 짓지 못함 (나무 %d · 지을 수 있는 곳 %d)" % [near_tree, free_at])
		var t0: Dictionary = ww.great_trees[0]
		var ok: Dictionary = jw.kit_spot_ok(float(t0["x"]) + 10.0, float(t0["y"]))
		check(not bool(ok["ok"]), "큰 나무 곁엔 키트를 놓을 수 없다 (%s)" % ok["why"])
		if sz == WorldCfg.SMALL_SIZE:
			var jw2 := JarWorld.create_with_kit(23, sz, Kits.make([]))
			check(str(jw2.water.great_trees) == str(ww.great_trees), "같은 시드 → 같은 자리 (결정론)")
			var other := JarWorld.create(24, sz)
			check(str(other.water.great_trees) != str(ww.great_trees), "다른 시드 → 다른 자리")


func test_great_trees_save() -> void:
	var jw := JarWorld.create_with_kit(5, WorldCfg.SMALL_SIZE, Kits.make([]))
	var d := jw.to_dict(false)
	var back := JarWorld.from_dict(d)
	check(str(back.water.great_trees) == str(jw.water.great_trees), "저장·불러오기: 큰 나무 자리 그대로")
	var old: Dictionary = d.duplicate(true)
	(old["water"] as Dictionary).erase("great_trees")
	var ob := JarWorld.from_dict(old)
	var far := true
	for t: Dictionary in ob.water.great_trees:
		far = far and Vector2(t["x"], t["y"]).distance_to(ob.primary().center) > GreatTrees.kit_apart(ob.water)
	check(ob.water.great_trees.size() == 5 and far, "옛 저장(큰 나무 없음): 불러올 때 다섯을 무리에서 먼 자리에 세움")


## E3-11: 옛 저장의 세계수("world")는 불러오면 벚나무 — 자리·반지름은 그대로
func test_world_tree_is_cherry() -> void:
	var jw := JarWorld.create_with_kit(5, WorldCfg.SMALL_SIZE, Kits.make([]))
	var d := jw.to_dict(false)
	var old: Dictionary = d.duplicate(true)
	var t0: Dictionary = (old["water"]["great_trees"] as Array)[0]
	t0["kind"] = "world"
	t0["name"] = "세계수"
	t0["r"] = 22.0
	var back := JarWorld.from_dict(old)
	var t1: Dictionary = back.water.great_trees[0]
	check(t1["kind"] == "cherry" and t1["name"] == "벚나무" and float(t1["r"]) == 22.0 and float(t1["x"]) == float(t0["x"])
		and back.water.great_trees.size() == 5, "옛 저장 세계수 → 벚나무 (자리·반지름 그대로) %s" % [t1])
	check(FloraLook.great_model("world", "봄")["parts"] == "flora/tree_cherry", "화면도 옛 이름을 벚나무로 받음")
	var kinds := {}
	for t: Dictionary in jw.water.great_trees:
		kinds[t["kind"]] = true
	check(kinds.has("cherry") and not kinds.has("world"), "새 세상에는 세계수 없이 벚나무")


## 아트 바이블 8.7: 큰 나무 철마다 보이는 부품 합 — 가까이 몸 ≤ 6,000 · 접힌 곳 선 ≤ 800 · 멀리 ≤ 1,200 (선 없음, 늘 있음)
func test_great_tree_budget() -> void:
	var bad: Array = []
	var worst := {}
	for k: String in GreatTrees.KINDS:
		for se: String in ["봄", "여름", "가을", "겨울"]:
			var spec := FloraLook.great_model(k, se)
			var parts := Art.parts(spec["parts"])
			var body := 0
			var lines := 0
			var far := 0
			var far_lines := 0
			for pn: String in spec["keep"]:
				if not parts.has(pn):
					bad.append("%s %s 부품 없음 %s" % [k, se, pn])
					continue
				body += _tris(parts[pn]["mesh"])
				lines += _tris(parts[pn]["lines"])
				if parts.has(pn + "__far"):
					far += _tris(parts[pn + "__far"]["mesh"])
					far_lines += _tris(parts[pn + "__far"]["lines"])
			if not parts.has("trunk__far") or far == 0:
				bad.append("%s %s 멀리 LOD 없음" % [k, se])
			if body > 6000 or lines > 800 or far > 1200 or far_lines > 0:
				bad.append("%s %s 몸 %d 선 %d 멀리 %d/%d" % [k, se, body, lines, far, far_lines])
			var w: Array = worst.get(k, [0, 0, 0])
			worst[k] = [maxi(w[0], body), maxi(w[1], lines), maxi(w[2], far)]
	check(bad.is_empty(), "큰 나무 예산 (가장 큰 철 [몸, 선, 멀리]) %s %s" % [worst, bad])


static func _tris(m: Mesh) -> int:
	if m == null:
		return 0
	var n := 0
	for s in m.get_surface_count():
		var a := m.surface_get_arrays(s)
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		n += (ix.size() if not ix.is_empty() else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func test_giant_fruit() -> void:
	var jw := JarWorld.create_with_kit(7, WorldCfg.SMALL_SIZE, Kits.make([]))
	var ww := jw.water
	var v := jw.primary()
	var ft := GreatTrees.of_kind(ww, "fruit")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var f := GreatTrees.drop_fruit(ww, rng, v.t)
	var d := Vector2(f.get("x", 1.0e9), f.get("y", 1.0e9)).distance_to(Vector2(ft["x"], ft["y"]))
	check(not f.is_empty() and d < float(ft["r"]) + 15.0 and ww.depth(ww.idx(f["x"], f["y"])) <= 0.004, "과일나무 곁 마른 땅에 거대한 열매 (%.0f칸)" % d)
	ww.giant_fruits.clear()
	# 여름: 몇 날 동안 시간마다 굴리면 가끔 떨어지고, 땅엔 FRUIT_MAX까지
	v.created_date = {"year": 2026, "month": 7, "day": 1}
	var most := 0
	for h in 24 * 10:
		v.t += 3600.0
		GreatTrees.hourly(v)
		most = maxi(most, ww.giant_fruits.size())
	check(most >= 1 and most <= GreatTrees.FRUIT_MAX, "여름 열흘: 열매가 떨어진다 (땅에 가장 많을 때 %d ≤ %d)" % [most, GreatTrees.FRUIT_MAX])
	v.created_date = {"year": 2026, "month": 1, "day": 1}
	v.t += GreatTrees.FRUIT_ROT_DAYS * Balance.DAY + 10.0
	GreatTrees.hourly(v)
	check(ww.giant_fruits.is_empty(), "겨울엔 새로 안 떨어지고, 오래된 열매는 썩어 사라짐")


func test_carry_twigs() -> void:
	var a := ResidentModel.carry_spec("통나무")
	var b := ResidentModel.carry_spec("판자")
	check(a[0] == "twig_bundle" and b[0] == "twig_bundle" and a[1] == "shoulder", "짐 통나무·판자 = 나뭇가지 다발을 어깨에 (%s · %s)" % [a, b])
	var p := ResidentModel.carry_parts("twig_bundle")
	check(not p.is_empty() and p["mesh"] != null and p["far"] != null, "나뭇가지 다발 소품 (가까이 + 멀리 덩어리)")


## 기본 확대·가까이·멀리에서 화면 아래 끝에 선 가장 큰 나무 꼭대기도 카메라 앞면(near) 안쪽 (잘리지 않음)
func test_camera_clears_trees() -> void:
	var h := FloraLook.GREAT_MAX_H * FloraLook.GREAT_SCALE
	var tallest := 0.0
	for k: String in GreatTrees.KINDS:
		var parts := Art.parts("flora/tree_" + k)
		for pn: String in parts:
			var m: Mesh = parts[pn]["mesh"]
			if m != null:
				tallest = maxf(tallest, m.get_aabb().end.y + (parts[pn]["origin"] as Vector3).y)
	check(tallest > 40.0 and tallest <= FloraLook.GREAT_MAX_H, "가장 큰 나무 %.0f ≤ GREAT_MAX_H %.0f" % [tallest, FloraLook.GREAT_MAX_H])
	var p := deg_to_rad(JarCamera.PITCH_DEG)
	var bad: Array = []
	for ppu: float in [JarCamera.PPU_MAX, 32.0, 16.0, 9.0, 6.0]:
		var size := 1280.0 / ppu
		var need := h / sin(p) + size * 0.5 * cos(p) / sin(p) + 1.0
		if JarCamera.inside_dist(size, p) < need:
			bad.append("×%.0f %.0f<%.0f" % [ppu, JarCamera.inside_dist(size, p), need])
	check(bad.is_empty(), "카메라가 큰 나무(높이 %.0f)를 앞면에서 자르지 않음 %s" % [h, bad])


func test_view_flora() -> void:
	var n: Node = load(StartFlow.GAME_SCENE).instantiate()
	n.set("world_size", WorldCfg.SMALL_SIZE)
	n.set("world_seed", 3)
	n.set("pick_spot", false)
	run.root.add_child(n)
	var view: VillageView = n.get("view")
	var v: Village = n.get("village")
	GroundLook.month_override = 5
	view.sync(0.0, true)
	var n_tree := 0
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree":
			n_tree += 1
	check(n_tree > 0 and view.n_flora == n_tree, "시뮬레이션 나무 %d그루 = 꽃숲 덩이 %d (수 그대로)" % [n_tree, view.n_flora])
	var old := {}
	for nm: String in ["tree_a", "tree_b", "tree_c", "tree_d", "conifer", "stump", "sapling"]:
		old[Art.model(nm)["mesh"]] = nm
	var flora := {}
	for nm: String in FloraLook.GREEN + FloraLook.FLOWERS["봄"] + FloraLook.TWIGS + FloraLook.SPROUTS:
		flora[Art.model(nm)["mesh"]] = nm
	var used_old: Array = []
	var n_flora_mm := 0
	for node: Node3D in [view.get("_trees"), view.get("_props"), view.get("_far")]:
		for c in node.get_children():
			var mmi := c as MultiMeshInstance3D
			if mmi == null:
				continue
			if old.has(mmi.multimesh.mesh):
				used_old.append(old[mmi.multimesh.mesh])
			if flora.has(mmi.multimesh.mesh):
				n_flora_mm += 1
	check(used_old.is_empty() and n_flora_mm > 0, "보통 나무 모델 없음 — 꽃·풀·이끼 MultiMesh %d개 (옛 모델 %s)" % [n_flora_mm, used_old])
	# 벤 자리 → 나뭇가지 더미
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree":
			tr["s"] = "stump"
			tr["res"] = 1
			break
	view.sync(0.0, true)
	var twig := false
	var tw_mesh: Mesh = Art.model(FloraLook.TWIGS[0])["mesh"]
	var tw_mesh_b: Mesh = Art.model(FloraLook.TWIGS[1])["mesh"]
	for c in (view.get("_trees") as Node3D).get_children():
		var mmi := c as MultiMeshInstance3D
		if mmi != null and mmi.multimesh.mesh in [tw_mesh, tw_mesh_b] and not mmi.is_queued_for_deletion():
			twig = true
	check(twig and view.n_flora == n_tree - 1, "벤 나무 = 나뭇가지 더미")
	# 큰 나무 다섯: 철마다 잎
	var gv: GreatTreeView = n.get("great_view")
	var seen := {}
	for m: int in [4, 7, 10, 1]:
		GroundLook.month_override = m
		gv.sync(0.0, true)
		seen[m] = gv.models.duplicate()
	check(gv.n_trees == 5, "큰 나무 다섯을 그림 (%d)" % gv.n_trees)
	check(seen[10]["ginkgo"] == "flora/tree_ginkgo:trunk,foliage_autumn,carpet" and seen[7]["ginkgo"] == "flora/tree_ginkgo:trunk,foliage"
		and seen[10]["maple"] == "flora/tree_maple:trunk,foliage_autumn" and seen[7]["maple"] == "flora/tree_maple:trunk,foliage"
		and seen[4]["fruit"] == "flora/tree_fruit:trunk,foliage_bloom" and seen[7]["fruit"] == "flora/tree_fruit:trunk,foliage,fruit_green"
		and seen[10]["fruit"] == "flora/tree_fruit:trunk,foliage_autumn,fruit"
		and seen[4]["cherry"] == "flora/tree_cherry:trunk,blossom" and seen[7]["cherry"] == "flora/tree_cherry:trunk,foliage,cherries"
		and seen[1]["cherry"] == "flora/tree_cherry:trunk" and seen[1]["maple"] == "flora/tree_maple:trunk,seeds"
		and seen[1]["pine"] == "flora/tree_pine:trunk,foliage_winter" and seen[7]["pine"] == "flora/tree_pine:trunk,foliage",
		"철마다: 벚나무 봄 꽃구름/여름 버찌/겨울 맨가지 · 은행 가을 노랑+융단 · 단풍 가을 빨강 · 과일나무 봄 크림 꽃/여름 덜 익은 열매/가을 익은 열매 · 소나무 늘 푸름(겨울 서리) %s" % [seen])
	# 멀리 LOD: 축소하면 멀리 부품으로 바뀌고 사라지지 않음 (가까이 숨김 · 멀리 보임)
	gv.force_lod = 1
	gv.lod_check()
	var far_ok := gv.far_lod
	for c in gv.get_children():
		if c.has_node("near") and c.has_node("far") and not c.is_queued_for_deletion():
			far_ok = far_ok and not (c.get_node("near") as Node3D).visible and (c.get_node("far") as Node3D).visible \
				and (c.get_node("far") as Node3D).get_child_count() > 0
	gv.force_lod = 0
	gv.lod_check()
	check(far_ok and not gv.far_lod, "큰 나무 멀리 LOD: 축소하면 멀리 부품으로 (숨지 않음), 확대하면 가까이로")
	gv.force_lod = -1
	check(GreatTreeView.far_boost(16.0) == 1.0 and GreatTreeView.far_boost(0.5) > 1.5, "세상 전체에서만 멀리 LOD를 조금 키움 (랜드마크)")
	var ww: WorldWater = n.get("world").water
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	GreatTrees.drop_fruit(ww, rng, v.t)
	gv.sync(0.0, true)
	check(gv.n_fruits == ww.giant_fruits.size() and gv.n_fruits >= 1, "떨어진 거대한 열매를 그림 (%d)" % gv.n_fruits)
	GroundLook.month_override = 0
	run.root.remove_child(n)
	n.free()
