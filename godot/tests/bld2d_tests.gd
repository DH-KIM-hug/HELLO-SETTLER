## 2D 그림책 건물 (view/bld2d — RENDERING.md 확정 2026-11-08: 세상은 3D, 건물은 그림). tests/run.gd가 부름 (`-- bld2d` = 이것만).
## 장면을 띄우는 묶음 (TREE_SUITES). 내용: 모든 건물 종류·변형·단계에 그림이 있음 (가져온 텍스처 · 아틀라스 칸) ·
## 장면: 건물마다 그림 판 + 3D 모델은 보이지 않는 그림자 대역(SHADOWS_ONLY) · 기본 확대 = 아틀라스 MultiMesh 하나 ·
## 접촉 그림자 · 무덤 · 제단 · 카드 그림(BuildingThumb) · 설정 · 시뮬레이션은 그대로 (ADR-0001).
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
	print("== 2D 그림책 건물")
	var old := Bld2D.override
	Bld2D.override = 1
	run.timed(self, ["test_every_type_has_picture", "test_stage_pictures", "test_atlas", "test_scene_cards_and_proxies",
		"test_altar", "test_thumbs", "test_switch", "test_sim_unchanged"])
	Bld2D.override = old


## 시뮬레이션의 모든 건물 종류 (Balance.B, 제단 빼고) + 화면 모델 표의 잠긴 종류 (목장·방직소·대장간) — 변형마다
func test_every_type_has_picture() -> void:
	var types := {}
	for t: String in Balance.B:
		if t != Awakening.ALTAR:
			types[t] = true
	for t: String in VillageView.BUILDING_MODELS:
		types[t] = true
	var missing: Array = []
	var no_tex: Array = []
	for t: String in types:
		var n := maxi((VillageView.BUILDING_MODELS.get(t, [""]) as Array).size(), (Bld2D.Pics.TYPES.get(t, [""]) as Array).size())
		for vi in n:
			for era in [0, 2]:
				var pic := Bld2D.wheat_pic(1) if t == "농장" else Bld2D.type_pic(t, vi, era)
				if pic == "" or not Bld2D.has(pic):
					missing.append("%s/%d/%d" % [t, vi, era])
				elif Bld2D.near_texture(pic) == null:
					no_tex.append(pic)
	check(missing.is_empty(), "건물 종류·변형·시대마다 그림이 있음 (%d종류) %s" % [types.size(), missing])
	check(no_tex.is_empty(), "그림은 가져온 텍스처 (내보낸 빌드에서 읽힘) %s" % [no_tex])
	var huts := {}
	for vi in 4:
		huts[Bld2D.type_pic("오두막", vi)] = true
	check(huts.size() == 4, "오두막 네 가지 (마을 모델 표와 같은 변형 규칙)")
	check(Bld2D.type_pic("나루터", 0, 0) == "ferry_raft" and Bld2D.type_pic("나루터", 0, 1) == "ferry", "나루터: 개척 시대 갈대 뗏목 · 그 뒤 잎 배")


func test_stage_pictures() -> void:
	var ok := true
	for st in 3:
		ok = ok and Bld2D.has(Bld2D.wheat_pic(st))
	check(ok and Bld2D.wheat_pic(0) != Bld2D.wheat_pic(2), "밀밭 자람 세 단계 그림")
	var sites := {}
	for st in VillageView.SITE_STAGES:
		var p := Bld2D.site_pic(st, VillageView.SITE_STAGES)
		ok = ok and Bld2D.has(p)
		sites[p] = true
	check(ok and sites.size() == 4, "짓는 터 여덟 단계 → 그림 네 장 (말뚝·바닥 → 뼈대 → 벽 → 서까래)")
	check(Bld2D.has("field_site") and Bld2D.has("scaffold"), "밭 고랑 · 개축 비계 그림")
	var alt := {}
	for st in range(0, AltarView.STAGES + 1):
		for lv in 4:
			var p := Bld2D.altar_pic(st, lv)
			ok = ok and Bld2D.has(p)
			alt[p] = true
	check(ok and alt.size() >= 7 and Bld2D.altar_pic(-1, 0) == "", "제단: 짓는 단계 · 다 지음 · 넓힌 셋 (%d장)" % alt.size())
	check(Bld2D.has("grave"), "무덤 그림")


func test_atlas() -> void:
	var tex: Texture2D = load(Bld2D.Pics.ATLAS)
	check(tex != null and tex.get_width() == Bld2D.Pics.ATLAS_SIZE.x and tex.get_height() == Bld2D.Pics.ATLAS_SIZE.y, "멀리 아틀라스 하나")
	var ok := true
	var idx := {}
	for n: String in Bld2D.Pics.PICS:
		var d: Dictionary = Bld2D.Pics.PICS[n]
		var r: Rect2 = d["uv"]
		ok = ok and r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= 1.0001 and r.end.y <= 1.0001 and r.size.x > 0.0
		ok = ok and float(d["w"]) > 0.0 and float(d["h"]) > 0.0
		idx[int(d["i"])] = true
	check(ok and idx.size() == Bld2D.Pics.PICS.size(), "그림마다 아틀라스 칸 · 크기 (번호 겹침 없음)")
	check(Bld2D.Pics.PICS.size() <= 96, "셰이더 표 크기 안 (MAX_PICS 96)")


func _scene() -> Node:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	return scene


static func _shadowy(root: Node) -> Array:
	var vis := 0
	var sh := 0
	for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
		if not g.visible:
			continue
		if g.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			sh += 1
		else:
			vis += 1
	return [vis, sh]


func test_scene_cards_and_proxies() -> void:
	var scene := _scene()
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	v.water.offline = true
	for t: String in ["창고", "우물", "빵집", "광장", "묘지", "약초꾼", "교회", "목조주택"]:
		var sp: Variant = v.find_spot(t)
		if sp != null:
			var b := v.add_building(t, (sp as Vector2).x, (sp as Vector2).y, true)
			b.built_t = v.t
	var sp2: Variant = v.find_spot("오두막")
	var site: Building = null
	if sp2 != null:
		site = v.add_building("오두막", (sp2 as Vector2).x, (sp2 as Vector2).y, false)
	vw.bld_force_lod = 0
	vw._bld_key.clear()
	vw.sync(0.0, true)
	vw._bld_lod(true)
	var no_card: Array = []
	var leaks: Array = []
	var shadows := 0
	var n_built := 0
	for b in v.buildings:
		if b.site_type() == Awakening.ALTAR or not vw._blds.has(b.id):
			continue
		var n: Node3D = vw._blds[b.id]
		var cards := n.find_children(String(Bld2D.CARD) + "*", "MeshInstance3D", false, false)
		if cards.is_empty():
			no_card.append(b.type)
			continue
		for part: String in ["near", "far"]:
			var br := n.get_node_or_null(part)
			if br == null:
				continue
			var c := _shadowy(br)
			if int(c[0]) > 0:
				leaks.append("%s/%s" % [b.type, part])
			shadows += int(c[1])
		if b.built:
			n_built += 1
	check(no_card.is_empty(), "건물마다 그림 판 (%d채) %s" % [vw._blds.size(), no_card])
	check(leaks.is_empty(), "3D 모델은 보이지 않음 — 그림자만 (SHADOWS_ONLY) %s" % [leaks])
	var ns: Node3D = vw._near_shadow
	var batch_sh := 0 if ns == null else int(_shadowy(ns)[1])
	var cast_ok := true
	for b in v.buildings:
		if b.built and vw._blds.has(b.id) and b.site_type() != Awakening.ALTAR:
			var near := (vw._blds[b.id] as Node3D).get_node_or_null("near")
			var own := 0 if near == null else int(_shadowy(near)[1])
			cast_ok = cast_ok and (own > 0 or (vw._shadow_items.has(b.id) and batch_sh > 0))
	check(cast_ok and shadows + batch_sh > 0, "다 지은 건물마다 그림자 대역이 그림자를 드리움 (제 모델 %d · 묶음 %d, %d채)" % [shadows, batch_sh, n_built])
	check(ns == null or _shadowy(ns)[0] == 0, "가까이 그림자 묶음도 그림자만")
	if site != null:
		var sn: Node3D = vw._blds.get(site.id)
		var sc := sn.find_children(String(Bld2D.CARD) + "*", "MeshInstance3D", false, false)
		check(sc.size() == 1 and String(sc[0].get_meta(&"pic")).begins_with("site_"), "짓는 터 = 짓는 단계 그림 (%s)" % (sc[0].get_meta(&"pic") if sc.size() > 0 else "-"))
	check(vw._contact != null and vw._contact.multimesh.instance_count > 0, "발밑 접촉 그림자 = MultiMesh 하나 (%d)" % (vw._contact.multimesh.instance_count if vw._contact != null else 0))
	var yard_ok := true
	for id in vw._yard_xf:
		for e: Array in vw._yard_xf[id]:
			yard_ok = yard_ok and e[0] in VillageView.YARD_FLORA_2D
	check(yard_ok, "그림 건물의 마당 소품은 꽃만 (단지·화덕·울타리는 그림에)")
	# 기본 확대 (멀리 LOD): 묶음에 든 건물의 그림은 아틀라스 MultiMesh 하나로, 제 판은 숨김
	vw.bld_force_lod = 1
	vw._bld_lod(true)
	vw._sync_far_batch(true)
	var mm: MultiMeshInstance3D = null
	if vw._far_batch != null:
		for c in vw._far_batch.get_children():
			if c is MultiMeshInstance3D and c.name.begins_with("cards2d"):
				mm = c
	var batched := 0
	var shown_own := 0
	for id in vw._blds:
		var n: Node3D = vw._blds[id]
		if vw._batched(n):
			batched += (vw._card_items.get(id, []) as Array).size()
			for c in n.get_children():
				if c.has_meta(&"pic") and (c as Node3D).visible:
					shown_own += 1
	check(mm != null and mm.multimesh.instance_count == batched and batched > 0, "기본 확대: 그림 %d장 = 아틀라스 MultiMesh 하나 (그리기 1번)" % batched)
	check(shown_own == 0, "묶음에 든 건물은 제 그림 판을 숨김")
	var far_sh := 0
	for c in vw._far_batch.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			far_sh += 1
	check(far_sh > 0, "멀리 묶음: 건물 3D 모양은 그림자만 드리우는 묶음으로 (쌓인 짐 더미는 아직 3D 소품)")
	# 무덤
	if not v.people.is_empty():
		var p: Resident = v.people[0]
		v.graves.append({"id": 99901, "name": "시험", "x": v.center.x + 3.0, "y": v.center.y + 3.0, "t": v.t, "yard": false, "yard_id": -1})
		vw.sync(0.0, true)
		var gm := vw._graves.find_children("cards2d*", "MultiMeshInstance3D", true, false) if vw._graves != null else []
		check(gm.size() == 1 and (gm[0] as MultiMeshInstance3D).multimesh.instance_count == v.graves.size(), "무덤 = 그림 (MultiMesh 하나, %d기)" % v.graves.size())
		v.graves.pop_back()
		p = null
	vw.bld_force_lod = -1
	scene.queue_free()


func test_altar() -> void:
	var scene := _scene()
	var v: Village = scene.get("village")
	var vw: VillageView = scene.get("view")
	var av := vw.altar_view
	if av == null or not v.altar_built:
		check(true, "(제단 없음 — 건너뜀)")
		scene.queue_free()
		return
	av._key = ""
	av.sync(0.0)
	var cards := av._body.find_children(String(Bld2D.CARD) + "*", "MeshInstance3D", false, false)
	check(cards.size() == 1 and String(cards[0].get_meta(&"pic")).begins_with("altar_"), "제단 = 단계 그림 (%s)" % (cards[0].get_meta(&"pic") if cards.size() > 0 else "-"))
	var c := _shadowy(av._body)
	check(int(c[0]) == 1 and int(c[1]) > 0, "제단 3D 조약돌은 그림자 대역 (보이는 것 = 그림 판 하나)")
	scene.queue_free()


func test_thumbs() -> void:
	var t := BuildingThumb.rect("우물", 56)
	check(t is TextureRect and t.has_meta(&"pic") and (t as TextureRect).texture != null, "건물 카드 그림 = 2D 그림 (우물)")
	t.free()
	var h0 := BuildingThumb.rect("오두막", 56, 0)
	var h1 := BuildingThumb.rect("오두막", 56, 1)
	check(h0.get_meta(&"pic") != h1.get_meta(&"pic"), "오두막 카드 그림 = 마을의 그 집 변형")
	h0.free()
	h1.free()
	var f := BuildingThumb.rect("농장", 56)
	check(String(f.get_meta(&"pic", "")) == "wheat_ripe", "밀밭 카드 = 익은 밀")
	f.free()
	Bld2D.override = 0
	var t3 := BuildingThumb.rect("우물", 56)
	check(not t3.has_meta(&"pic"), "그림을 끄면 예전 3D 카드 그림")
	t3.free()
	Bld2D.override = 1


func test_switch() -> void:
	var s := GameSettings.new()
	check(s.picture_buildings, "그림 건물이 기본")
	var p := "user://test_bld2d_settings_%d.cfg" % OS.get_process_id()
	s.picture_buildings = false
	s.save(p)
	check(not GameSettings.load_from(p).picture_buildings, "설정 저장 → 읽기 (꺼짐)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## 화면은 시뮬레이션을 바꾸지 않는다 (ADR-0001): 그림 건물 화면을 매번 맞추며 흘린 마을 = 화면 없이 흘린 마을
func test_sim_unchanged() -> void:
	for f: String in ["res://view/bld2d/bld2d.gd"]:
		var src := FileAccess.get_file_as_string(f)
		var re := RegEx.create_from_string("\\b(b|v|r|village)\\.[a-z_]+\\s*(=|\\+=|-=)[^=]")
		check(re.search(src) == null, "%s가 건물·마을 데이터를 쓰지 않음" % f.get_file())
	var scene := _scene()
	Village.start_aware = true
	var a := Village.new_prototype(20261109)
	var b := Village.new_prototype(20261109)
	Village.start_aware = false
	a.water.offline = true
	b.water.offline = true
	var vw := VillageView.new(a, scene.get("terrain"))
	scene.add_child(vw)
	for i in 6:
		a.advance(0.05 * Balance.DAY)
		vw.sync(0.1, true)
		vw._bld_lod(true)
		b.advance(0.05 * Balance.DAY)
	var pa := a.people.map(func(r: Resident) -> String: return "%d:%.3f,%.3f" % [r.id, r.x, r.y])
	var pb := b.people.map(func(r: Resident) -> String: return "%d:%.3f,%.3f" % [r.id, r.x, r.y])
	var ba := a.buildings.map(func(x: Building) -> String: return "%d:%s:%.2f:%s" % [x.id, x.type, x.prog, x.built])
	var bb := b.buildings.map(func(x: Building) -> String: return "%d:%s:%.2f:%s" % [x.id, x.type, x.prog, x.built])
	check(pa == pb and ba == bb and a.stock == b.stock and a.buildings.size() > 2, "그림 건물 화면을 돌려도 주민·건물·창고가 같음 (ADR-0001, 건물 %d채)" % a.buildings.size())
	scene.queue_free()
