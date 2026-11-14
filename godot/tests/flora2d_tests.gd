## 2D 그림책 꽃·풀·소품 (view/flora2d — RENDERING.md 확정 2026-11-08: 세상은 3D, 나머지는 그림). tests/run.gd가 부름 (`-- flora2d` = 이것만).
## 장면을 띄우는 묶음 (TREE_SUITES). 내용: 꽃숲·초록·잔것·소품·부엌·찾은 물건·큰 나무(철마다)·해바라기 고개 방향·민들레·버섯·더미·불꽃마다
## 그림이 있음 · 아틀라스 · 장면: 철마다 마을의 모든 꽃숲·소품 모양이 그림 (3D로 남는 것 = 선착장·다리뿐) · 묶음 그리기 횟수 ·
## 큰 꽃 그림자 대역 · 큰 나무 · 설정 · 시뮬레이션은 그대로 (ADR-0001).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
## 그림으로 바꾸지 않는 것: 물을 건너는 구조물 (선착장·다리·디딤돌 — 땅·물과 함께 3D 세상의 일부)
const KEEP_3D := ["pier", "bridge", "bridge_stones"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 2D 그림책 꽃·풀·소품")
	var old := Flora2D.override
	Flora2D.override = 1
	run.timed(self, ["test_lists_have_pictures", "test_atlases", "test_scene_seasons", "test_great_trees", "test_campfire", "test_switch",
		"test_sim_unchanged"])
	Flora2D.override = old


func _pic_ok(model: String, missing: Array) -> void:
	var p := Flora2D.pic_for(model)
	if p == "" or not Flora2D.has(p):
		missing.append(model)


## 화면이 쓰는 모델 이름 표 전부 → 그림
func test_lists_have_pictures() -> void:
	var missing: Array = []
	var names := {}
	for se: String in FloraLook.FLOWERS:
		for m: String in FloraLook.FLOWERS[se]:
			names[m] = true
	for se: String in FloraLook.ROLES:
		for m: String in FloraLook.ROLES[se]:
			names[m] = true
	for l: Array in [FloraLook.GREEN, FloraLook.FAR_GREEN, FloraLook.TWIGS, FloraLook.SPROUTS, FloraLook.GREEN_OPEN,
			FloraLook.GREEN_SHADE, VillageView.FRINGE, VillageView.OPEN, VillageView.CLUTTER_ONE, VillageView.YARD_FLORA_2D,
			VillageView.PF_FAR_YARD, KitchenView.MODELS, ["rocks", "rock_small", "rocks_b", "lily", "lotus", "flowers", "flowers_b",
			"bush_flower", "bush", "bush_b", VillageView.PF_POT_HOUSE, VillageView.PF_BENCH, "campfire", "campfire_extra",
			"flora/great_fruit", "flora/great_fruit_cut", "flora/sunflower_seed", "dand_leaves", "dand_leaves_small"]]:
		for m: String in l:
			names[m] = true
	for m: String in VillageView.FOUND_MODELS.values():
		names[m] = true
	for m: String in FloraView.ART_SHROOM.values():
		names[m] = true
	for m: String in FloraView.ART_DAND.values():
		names[m] = true
	for m: String in names:
		_pic_ok(m, missing)
	check(missing.is_empty(), "꽃·초록·잔것·마당 소품·부엌·찾은 물건·버섯·민들레 모델마다 그림 (%d개) %s" % [names.size(), missing])
	var trees: Array = []
	for k: String in FloraLook.GREAT_PARTS:
		for se: String in ["봄", "여름", "가을", "겨울"]:
			var p := Flora2D.great_pic(k, se)
			if not Flora2D.has(p) or not p.contains(k) or Flora2D.pic_texture(p) == null:
				trees.append("%s/%s" % [k, se])
	check(trees.is_empty(), "큰 나무 다섯 × 철 넷 = 그림 스무 장 %s" % [trees])
	var sf := true
	for st: int in SunflowerView.HEAD_STEPS:
		sf = sf and Flora2D.has("sf_head_%d" % st) and Flora2D.has("sf_dry_%d" % st)
	check(sf and Flora2D.has("sf_stalk") and Flora2D.has("sf_column"), "초거대 해바라기: 줄기·기둥 + 고개 방향 다섯 × (핀 꽃 · 숙인 꽃)")
	var goods: Array = []
	for g: String in Style.ITEM_COLORS:
		if not Flora2D.has(Flora2D.goods_pic(g)) or Flora2D.goods_pic(g) == "pile_goods":
			goods.append(g)
	check(goods.is_empty(), "쌓인 물건마다 더미 그림 %s" % [goods])
	var fl := true
	for i in 6:
		fl = fl and Flora2D.has("flame_%d" % i)
	check(fl and Flora2D.has("smoke_a") and Flora2D.has("ember") and Flora2D.has("pile_offering") and Flora2D.has("pile_stone")
		and Flora2D.has("dand_seed") and Flora2D.has("dand_stem"), "불꽃 여섯 장 · 연기 · 불티 · 제물 더미 · 돌 더미 · 꽃씨 · 민들레 줄기")


func test_atlases() -> void:
	var counts := {}
	var bad: Array = []
	for pic: String in Flora2D.Pics.PICS:
		var d: Dictionary = Flora2D.Pics.PICS[pic]
		var g := String(d["group"])
		var r: Rect2 = d["uv"]
		if not (r.position.x >= 0.0 and r.end.x <= 1.0001 and r.end.y <= 1.0001 and float(d["w"]) > 0.0 and float(d["h"]) > 0.0):
			bad.append(pic)
		if g != "single":
			counts[g] = int(counts.get(g, 0)) + 1
			if int(d["i"]) >= Flora2D.MAX_PICS:
				bad.append(pic)
	for g: String in Flora2D.Pics.ATLASES:
		var t := Flora2D.texture(g)
		if t == null:
			bad.append("atlas " + g)
	check(bad.is_empty(), "그림마다 아틀라스 칸·크기 · 아틀라스 텍스처를 읽음 · 셰이더 표 안 (≤ %d) %s" % [Flora2D.MAX_PICS, bad])
	check(counts.has("common") and counts.has("spring") and counts.has("winter"), "무리: common + 철마다 꽃 (%s)" % [counts])


func _scene() -> Node:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	return scene


## 철 넷: 마을 화면의 모든 꽃숲·소품·바위·연잎 모양이 그림 · 묶음마다 그리기 몇 번 · 큰 꽃 그림자 대역은 그림자만
func test_scene_seasons() -> void:
	var scene := _scene()
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	v.water.offline = true
	for t: String in ["오두막", "창고", "빵집", "나무꾼", "우물"]:
		var sp: Variant = v.find_spot(t)
		if sp != null:
			var b := v.add_building(t, (sp as Vector2).x, (sp as Vector2).y, true)
			b.built_t = v.t
			if t == "빵집":
				b.out["빵"] = 3
	var leftover := {}
	var draws_ok := true
	var shadow_ok := true
	var cards := 0
	for month in [4, 7, 10, 1]:
		GroundLook.month_override = month
		vw._tree_key = ""
		vw._prop_key = ""
		vw._rock_key = ""
		vw.sync(0.0, true)
		for b: FloraBatch in vw._batches.values():
			for k: String in b.no_pic:
				leftover[k] = true
			cards += b.n_cards
			var mm := 0
			for c in b.parent.get_children():
				if c is MultiMeshInstance3D and (c as MultiMeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY \
						and String(c.name).begins_with("cards2d"):
					mm += 1
				if c is MultiMeshInstance3D and String(c.name).begins_with("shadow2d"):
					shadow_ok = shadow_ok and (c as MultiMeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			draws_ok = draws_ok and mm <= 2
		for k: String in vw.no_pic2d:
			leftover[k] = true
	GroundLook.month_override = -1
	for k: String in KEEP_3D:
		leftover.erase(k)
	check(leftover.is_empty(), "철 넷 모두 마을 화면의 꽃숲·소품·바위·연잎 모양이 그림 (3D로 남은 것 = 선착장·다리뿐) %s" % [leftover.keys()])
	check(cards > 0 and draws_ok, "묶음마다 그림 MultiMesh ≤ 2 (common + 지금 철 꽃) — 그림 %d장" % cards)
	check(shadow_ok, "큰 꽃 그림자 대역은 그림자만 (SHADOWS_ONLY)")
	var pile := false
	for id in vw._fcard_items:
		for it: Array in vw._fcard_items[id]:
			pile = pile or String(it[0]) == "pile_bread"
	for it: Array in vw.econ.items:              # Q6: 그림 건물의 더미는 보이는 살림(BldEcon)이 그린다
		pile = pile or String(it[0]).begins_with("bread_")
	check(pile, "빵집 앞 빵 더미 = 그림 (보이는 살림 묶음)")
	scene.queue_free()


func test_great_trees() -> void:
	var n: Node = load(StartFlow.GAME_SCENE).instantiate()
	n.set("world_size", WorldCfg.SMALL_SIZE)
	n.set("world_seed", 3)
	n.set("pick_spot", false)
	run.root.add_child(n)
	var gv: GreatTreeView = n.get("great_view")
	var by_season := {}
	for m: int in [4, 7, 10, 1]:
		GroundLook.month_override = m
		gv.sync(0.0, true)
		by_season[m] = gv.cards.duplicate()
	GroundLook.month_override = -1
	var shown := 0
	var leak := 0
	var list: Array = []
	for top: Node in gv.get_children():
		if not top.is_queued_for_deletion():
			list.append_array(top.find_children("*", "GeometryInstance3D", true, false))
	var leaks: Array = []
	for g: GeometryInstance3D in list:
		if not g.is_visible_in_tree():
			continue
		if g.has_meta(&"pic"):
			shown += 1
		elif g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY and not g.has_meta(&"cards2d") \
				and not String(g.name).begins_with("contact2d") and not g.has_meta(&"ground_decal"):      # (Q41) 둘레 깔개 = 3D 땅
			leak += 1
			leaks.append(String(g.get_path()).get_slice("GreatTrees/", 1))
	check(gv.pics2d and gv.n_trees == 5 and shown >= 5 and leak == 0, "큰 나무 다섯 = 그림 한 장씩 (%d) · 3D는 그림자 대역만 (새는 것 %d %s)" % [shown, leak, leaks.slice(0, 4)])
	check(String(by_season[10].get("ginkgo", "")) == "tree_ginkgo_autumn" and String(by_season[4].get("cherry", "")) == "tree_cherry_spring"
		and String(by_season[1].get("maple", "")) == "tree_maple_winter", "철마다 그림이 바뀜 (가을 은행 · 봄 벚 · 겨울 단풍) %s" % [by_season[10]])
	n.queue_free()


## 모닥불: 돌 고리·장작 = 그림 판 (3D는 그림자 대역) · 불꽃 = 그린 여섯 장 넘김 · 연기·불티 = 그림
func test_campfire() -> void:
	var cf := Campfire.new()
	run.root.add_child(cf)
	var body_card := cf.body.find_children(String(Flora2D.CARD) + "*", "MeshInstance3D", false, false)
	var fl := cf.get_node_or_null("Flame2D") as MeshInstance3D
	var fr: PackedVector4Array = (fl.material_override as ShaderMaterial).get_shader_parameter("frame_uv") if fl != null else PackedVector4Array()
	check(body_card.size() == 1 and fl != null and fl == cf.flame and fr.size() == 6, "모닥불 = 그림 판 + 불꽃 그림 여섯 장 (Flame2D)")
	var leak := 0
	for g: GeometryInstance3D in cf.body.find_children("*", "GeometryInstance3D", true, false):
		if g.visible and not g.has_meta(&"pic") and g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			leak += 1
	var sm := (cf.smoke.draw_pass_1 as QuadMesh).material as StandardMaterial3D
	check(leak == 0 and sm.albedo_texture == Flora2D.texture("common"), "돌 고리 3D는 그림자만 · 연기 = 그린 연기 구름")
	cf.queue_free()


func test_switch() -> void:
	var s := GameSettings.new()
	check(s.picture_flora, "그림 꽃·소품이 기본")
	var p := "user://test_flora2d_settings_%d.cfg" % OS.get_process_id()
	s.picture_flora = false
	s.save(p)
	check(not GameSettings.load_from(p).picture_flora, "설정 저장 → 읽기 (꺼짐)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## 화면은 시뮬레이션을 바꾸지 않는다 (ADR-0001): 그림 꽃·소품 화면을 맞추며 흘린 마을 = 화면 없이 흘린 마을
func test_sim_unchanged() -> void:
	for f: String in ["res://view/flora2d/flora2d.gd", "res://view/flora_batch.gd"]:
		var src := FileAccess.get_file_as_string(f)
		var re := RegEx.create_from_string("\\b(b|v|r|village)\\.[a-z_]+\\s*(=|\\+=|-=)[^=]")
		check(re.search(src) == null, "%s가 마을 데이터를 쓰지 않음" % f.get_file())
	var scene := _scene()
	Village.start_aware = true
	var a := Village.new_prototype(20261110)
	var b := Village.new_prototype(20261110)
	Village.start_aware = false
	a.water.offline = true
	b.water.offline = true
	var vw := VillageView.new(a, scene.get("terrain"))
	scene.add_child(vw)
	for i in 6:
		a.advance(0.05 * Balance.DAY)
		vw.sync(0.1, true)
		b.advance(0.05 * Balance.DAY)
	var pa := a.people.map(func(r: Resident) -> String: return "%d:%.3f,%.3f" % [r.id, r.x, r.y])
	var pb := b.people.map(func(r: Resident) -> String: return "%d:%.3f,%.3f" % [r.id, r.x, r.y])
	var ta := a.trees.map(func(x: Dictionary) -> String: return "%.2f,%.2f,%s" % [x["x"], x["y"], x["s"]])
	var tb := b.trees.map(func(x: Dictionary) -> String: return "%.2f,%.2f,%s" % [x["x"], x["y"], x["s"]])
	check(pa == pb and ta == tb and a.stock == b.stock and vw.n_flora > 0, "그림 꽃숲 화면을 돌려도 주민·나무·창고가 같음 (ADR-0001, 꽃숲 %d)" % vw.n_flora)
	scene.queue_free()
