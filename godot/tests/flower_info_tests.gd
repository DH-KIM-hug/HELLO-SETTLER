## 꽃 정보 카드 (docs/UI.md '꽃 정보 카드' — view/ui/flower_info.gd · view/flora_picks.gd · test_village.open_flower).
## tests/run.gd가 부름 (`-- flower_info` = 이것만). 장면을 띄우는 묶음 (TREE_SUITES).
## 내용: 화면이 그리는 모든 꽃·초록 모델이 이름을 가짐 · 크기감·피는 철·쓰임 (시뮬 나무 = 그늘·통나무, 장미 = 진딧물, 이끼 = 서늘한 별만) ·
##   하늘의 것 (큰 민들레·초거대 해바라기·목화)의 단계 · 군락 한 줄 · 시뮬레이션을 바꾸지 않음 ·
##   장면: 꽃을 누름 → 카드 · 건물이 먼저 · 빈 곳 = 닫기 (유리 톡 아님) · 아래로 밀기 = 닫기 · 카메라 비켜 주기
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
	print("== 꽃 정보 카드")
	run.timed(self, ["test_species_cover", "test_facts_clump", "test_extras", "test_colony", "test_readonly", "test_scene_pick"])


func proto() -> Village:
	Village.start_aware = true
	var v := Village.new_prototype(20261108)
	Village.start_aware = false
	v.water.offline = true
	v.advance(0.2 * Balance.DAY)
	return v


func _has(lines: PackedStringArray, part: String) -> bool:
	for l in lines:
		if l.contains(part):
			return true
	return false


func test_species_cover() -> void:
	var miss := PackedStringArray()
	for season: String in FloraLook.ROLES:
		for nm: String in FloraLook.ROLES[season] + FloraLook.FLOWERS[season]:
			if not FloraPicks.pickable(nm):
				miss.append(nm)
	for nm: String in FloraLook.GREEN + FloraLook.FAR_GREEN + FloraLook.SPROUTS:
		if not FloraPicks.pickable(nm):
			miss.append(nm)
	check(miss.is_empty(), "화면이 그리는 꽃·초록 모델이 모두 이름을 가짐 (빠짐: %s)" % ", ".join(miss))
	check(not FloraPicks.pickable("flora/twig_pile_a") and not FloraPicks.pickable("rocks") and not FloraPicks.pickable("tuft"), "나뭇가지 더미·돌·풀 포기는 누르지 않음")
	var noart := PackedStringArray()
	for nm: String in FlowerInfo.SPECIES:
		if not Art.exists(nm):
			noart.append(nm)
	check(noart.is_empty(), "이름이 있는 모양은 모두 그림(모델)이 있음 (없음: %s)" % ", ".join(noart))


func test_facts_clump() -> void:
	var v := proto()
	GroundLook.month_override = 4            # 봄
	var p := {"name": "flora/poppy_red", "at": Vector2.ZERO, "sim": true, "kind": "clump", "view": null}
	var f := FlowerInfo.facts(v, p)
	check(String(f["title"]) == "양귀비", "이름 = 양귀비 (%s)" % f["title"])
	check(String(f["desc"]).begins_with("주민 ") and String(f["desc"]).contains("명 키만 한 양귀비"), "소인 눈높이 크기감 (%s)" % f["desc"])
	check(String(f["season"]) == "여름에 피어요", "지금 철이 아니면 '여름에 피어요' (%s)" % f["season"])
	check(_has(f["uses"], "그늘") and _has(f["uses"], "통나무"), "시뮬 나무 자리 = 꽃숲 그늘 · 나무꾼의 통나무")
	check(_has(f["uses"], "나비") and _has(f["uses"], "꿀"), "꽃 = 나비 · 꿀방울")
	check(String(f["thumb"]) == "flora/poppy_red", "그림 = 그 모델")
	GroundLook.month_override = 7            # 여름
	f = FlowerInfo.facts(v, p)
	check(String(f["season"]).contains("지금 한창"), "제철이면 '지금 한창 피었어요' (%s)" % f["season"])
	p["sim"] = false
	f = FlowerInfo.facts(v, p)
	check(not _has(f["uses"], "통나무") and not _has(f["uses"], "그늘"), "장식 꽃숲 (시뮬 나무 아님) = 그늘·통나무 줄 없음")
	f = FlowerInfo.facts(v, {"name": "flora/rose_pink", "kind": "clump", "sim": false})
	check(_has(f["uses"], "진딧물"), "장미 = 진딧물 목장")
	f = FlowerInfo.facts(v, {"name": "flora/moss_a", "kind": "clump", "sim": false})
	check(String(f["title"]) == "이끼" and not _has(f["uses"], "이끼 이불") and not _has(f["uses"], "나비"), "이끼 (보통 별) = 이끼 이불·나비 줄 없음")
	check(String(f["desc"]).contains("발목") or String(f["desc"]).contains("허리") or String(f["desc"]).contains("키만 한"), "이끼 크기감 (%s)" % f["desc"])
	check(String(f["season"]).contains("푸르"), "초록은 철 없이 푸름 (%s)" % f["season"])
	for bad: String in ["게임", "플레이어", "구매", "상점"]:
		var hit := false
		for nm: String in FlowerInfo.SPECIES:
			var ff := FlowerInfo.facts(v, {"name": nm, "kind": "clump", "sim": true})
			if (String(ff["desc"]) + String(ff["season"]) + "".join(ff["uses"])).contains(bad):
				hit = true
		check(not hit, "카드 말에 '%s' 없음" % bad)
	GroundLook.month_override = 0


func test_extras() -> void:
	var v := proto()
	var d := {"st": "puff"}
	var f := FlowerInfo.facts(v, {"kind": "dandelion", "src": d})
	check(String(f["title"]) == "큰 민들레" and String(f["season"]).contains("솜털 공") and _has(f["uses"], "꽃차"), "큰 민들레: 솜털 공 단계 · 꽃차 (%s)" % f["season"])
	d["st"] = "flower"
	f = FlowerInfo.facts(v, {"kind": "dandelion", "src": d})
	check(String(f["season"]).contains("노란 꽃"), "큰 민들레 단계는 시뮬 사전을 다시 읽음 (%s)" % f["season"])
	f = FlowerInfo.facts(v, {"kind": "sunflower", "src": {"stage": "bloom"}})
	check(String(f["title"]) == "초거대 해바라기" and String(f["season"]).contains("씨앗비") and _has(f["uses"], "해바라기씨"), "초거대 해바라기: 꽃판 · 씨앗비 · 해바라기씨")
	f = FlowerInfo.facts(v, {"kind": "cotton", "src": {"boll": true}})
	check(String(f["title"]) == "목화 덤불" and String(f["season"]).contains("다래") and _has(f["uses"], "솜"), "목화: 다래 · 솜")
	f = FlowerInfo.facts(v, {"kind": "cotton", "src": {"boll": false}})
	check(String(f["season"]).contains("가을"), "목화 다래 전: '가을에 터져요'")


func test_colony() -> void:
	var v := proto()
	var recs := {}
	var fp := FloraPicks.new()
	for i in 8:
		fp.add("flora/poppy_red", Vector3(cos(i) * 2.0, 0, sin(i) * 2.0), 0.5)
	fp.add("flora/grass_a", Vector3(1, 0, 1), 0.5)
	fp.add("flora/daisy_a", Vector3(30, 0, 30), 0.5)
	recs["_trees"] = fp
	var f := FlowerInfo.facts(v, {"name": "flora/poppy_red", "at": Vector2.ZERO, "kind": "clump", "sim": false, "picks": recs})
	check(String(f["colony"]) == "이 근처는 양귀비 들판", "군락 한 줄 (%s)" % f["colony"])
	f = FlowerInfo.facts(v, {"name": "flora/daisy_a", "at": Vector2(30, 30), "kind": "clump", "sim": false, "picks": recs})
	check(String(f["colony"]) == "", "홀로 핀 꽃은 군락 줄 없음")
	check(fp.count_near(Vector2.ZERO, 5.0, "flora/poppy_red") == Vector2i(8, 9), "둘레 셈 (같은 꽃 8 / 전체 9)")


func test_readonly() -> void:
	var v := proto()
	var before := var_to_str(v.trees) + var_to_str(v.flora.dands) + str(v.rng.state)
	for nm: String in FlowerInfo.SPECIES:
		FlowerInfo.facts(v, {"name": nm, "kind": "clump", "sim": true})
	for d: Dictionary in v.flora.dands:
		FlowerInfo.facts(v, {"kind": "dandelion", "src": d})
	check(var_to_str(v.trees) + var_to_str(v.flora.dands) + str(v.rng.state) == before, "카드 내용을 만들어도 시뮬레이션은 그대로")


func test_scene_pick() -> void:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	v.water.offline = true
	var tries := 0
	while tries < 12 and v.buildings.filter(func(b: Building) -> bool: return b.built and b.is_house()).is_empty():
		v.advance(0.1 * Balance.DAY)
		tries += 1
	vw.sync(0.0, true)
	var cam: JarCamera = scene.get("cam")
	var card: FlowerInfo = scene.get("fcard")
	var bcard: BuildingInfo = scene.get("bcard")
	check(card != null, "장면에 꽃 정보 카드가 있음")
	var n_rec := 0
	for layer: String in vw.flora_picks:
		n_rec += (vw.flora_picks[layer] as FloraPicks).size()
	check(n_rec > 0, "그린 꽃숲 덩이 기록이 있음 (%d)" % n_rec)
	# 시뮬 나무 자리 꽃 하나 — 건물에서 떨어진 것
	var fp: FloraPicks = vw.flora_picks.get("_trees")
	var idx := -1
	if fp != null:
		for i in fp.size():
			if fp.sim[i] != 1:
				continue
			var far_ok := true
			for b in v.buildings:
				if Vector2(b.x, b.y).distance_to(Vector2(fp.xs[i], fp.zs[i])) < b.size() + 3.0:
					far_ok = false
					break
			if far_ok:
				idx = i
				break
	check(idx >= 0, "건물에서 떨어진 꽃숲 덩이를 찾음")
	if idx < 0:
		scene.queue_free()
		return
	var at := Vector2(fp.xs[idx], fp.zs[idx])
	scene.call("look_at_ground", at)
	for m: ResidentModel in vw.residents.values():
		m.global_position = vw.global_transform * Vector3(at.x + 60, 0, at.y + 60)
	var base := vw.global_transform * Vector3(fp.xs[idx], fp.ys[idx] + fp.hs[idx] * 0.4, fp.zs[idx])
	var sp := cam.camera.unproject_position(base)
	var pk := FloraPicks.pick(cam.camera, scene.call("village_views"), sp)
	check(not pk.is_empty() and pk["at"].distance_to(at) < 3.0, "누른 곳 = 그 꽃숲 덩이 (또는 바로 곁)")
	var taps := int(v._taps[1])
	scene.call("_on_tap", sp)
	check(card.visible and not bcard.visible and String(card.title_l.text) != "", "꽃을 누름 → 꽃 정보 카드 (%s — %s)" % [card.title_l.text, card.desc_l.text])
	check(int(v._taps[1]) == taps, "꽃을 누른 것은 유리 톡이 아님")
	check(not card.pick.is_empty() and FlowerInfo.SPECIES.has(String(card.pick["name"])), "카드 이름 = 꽃 표의 이름")
	# 카메라 비켜 주기 (open_flower instant)
	scene.call("open_flower", card.pick, true)
	var pf := cam.camera.unproject_position(card.pick["top"])
	check(card.free_rect().has_point(pf), "카메라가 비켜 줌: 꽃이 카드에 가리지 않음 (%.0f, %.0f)" % [pf.x, pf.y])
	# 아래로 밀기 = 닫기
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.relative = Vector2(0, 30)
	card._on_panel_input(mm)
	check(card.visible, "조금만 밀면 그대로")
	card._on_panel_input(mm)
	check(not card.visible, "아래로 밀면 닫힘")
	# 건물이 먼저 (건물 위를 누르면 건물 카드)
	var h: Building = null
	for b in v.buildings:
		if b.built and b.is_house() and vw._blds.has(b.id):
			h = b
			break
	if h != null:
		var n: Node3D = vw._blds.get(h.id)
		scene.call("look_at_ground", Vector2(h.x, h.y))
		for m: ResidentModel in vw.residents.values():
			m.global_position = n.global_position + Vector3(60, 0, 60)
		scene.call("_on_tap", cam.camera.unproject_position(n.global_position + Vector3(0, 0.6, 0)))
		check(bcard.visible and not card.visible, "건물과 꽃이 함께 눌리면 건물 먼저")
		bcard.close()
	check(h != null, "다 지은 집이 있음 (건물 먼저 확인)")
	# 빈 곳 = 닫기 (유리 톡 아님)
	scene.call("look_at_ground", at)
	scene.call("open_flower", pk, true)
	var empty := Vector2(-1, -1)
	var vs: Vector2 = scene.get_viewport().get_visible_rect().size
	var fr := card.free_rect()
	var views: Array = scene.call("village_views")
	for yy in range(int(scene.get("top_h")) + 30, int(fr.end.y) - 10, 10):
		for xx in range(20, int(vs.x) - 20, 10):
			var p := Vector2(xx, yy)
			if scene.call("pick_building", p) == null and scene.call("pick_resident", p) == null and scene.call("pick_altar", p) == null \
					and FloraPicks.pick(cam.camera, views, p).is_empty():
				empty = p
				break
		if empty.x >= 0.0:
			break
	check(empty.x >= 0.0, "아무것도 없는 자리를 찾음")
	if empty.x >= 0.0:
		taps = int(v._taps[1])
		scene.call("_on_tap", empty)
		check(not card.visible, "빈 곳을 누르면 카드가 닫힘")
		check(int(v._taps[1]) == taps, "카드를 닫는 누름은 유리 톡이 아님")
	scene.queue_free()
