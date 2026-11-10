## 보이는 살림 — 건물 쪽 (view/bld2d/bld_econ.gd · ROADMAP Q6). tests/run.gd가 부름 (`-- site_piles` = 이것만).
## 장면을 띄우는 묶음 (TREE_SUITES). 내용: 그림 표(아틀라스 칸) · 더미 단계 규칙 · 짓는 터 자재·말뚝·다 지음 '퐁' ·
## 일터 재료·산출 더미 · 창고 · 돌아가는 일터만 움직임 · 막힘 풍선(늦게 뜸 · 몇 개만) · 끄기 · 시뮬레이션은 그대로 (ADR-0001).
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
	print("== 보이는 살림 (건물 쪽)")
	var old := Bld2D.override
	Bld2D.override = 1
	run.timed(self, ["test_pics", "test_rules", "test_site", "test_workplace", "test_bubbles", "test_sim_unchanged"])
	Bld2D.override = old


func _scene() -> Node:
	var scene: Node = load("res://scenes/test_village.tscn").instantiate()
	run.root.add_child(scene)
	scene.set("paused", true)
	return scene


## [장면, 마을, 화면] — 시드가 같은 새 마을에 화면을 붙임
func _village(scene: Node) -> Array:
	Village.start_aware = true
	var a := Village.new_prototype(20261109)
	Village.start_aware = false
	a.water.offline = true
	var vw := VillageView.new(a, scene.get("terrain"))
	scene.add_child(vw)
	vw.sync(0.1, true)
	return [a, vw]


## 마을 전체가 보이는 위 카메라 — 풍선은 화면 안에서만 뜨므로, 앞 묶음이 남긴 카메라에 기대지 않게 제 카메라를 둔다
func _wide_cam(scene: Node, vw: VillageView) -> void:
	var c := Vector3.ZERO
	for id: int in vw._blds:
		c = (vw._blds[id] as Node3D).global_position
		break
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4000.0
	cam.far = 4000.0
	scene.add_child(cam)
	cam.look_at_from_position(c + Vector3(0.0, 1000.0, 0.0), c, Vector3(0.0, 0.0, -1.0))
	cam.make_current()


func _add(a: Village, type: String, built: bool) -> Building:
	var sp: Variant = a.find_spot(type)
	if sp == null:
		return null
	return a.add_building(type, (sp as Vector2).x, (sp as Vector2).y, built)


## 건물 b 둘레의 그림 이름들 (머리말 pre로 시작하는 것)
func _near(vw: VillageView, b: Building, pre: String) -> Array:
	var out: Array = []
	var org: Vector3 = (vw._blds[b.id] as Node3D).position
	for it: Array in vw.econ.items:
		if String(it[0]).begins_with(pre) and Vector2((it[1] as Vector3).x - org.x, (it[1] as Vector3).z - org.z).length() < b.size() * 2.0 + 3.0:
			out.append(String(it[0]))
	return out


## 건물 b의 칸(더미·말뚝) 그림 — 칸 이름(p 판자 · s 돌 · g0..4 말뚝 · i0 재료 · o0 산출 · f 땔감 · w0..3 창고)이 pre로 시작하는 것
func _slots(econ: BldEcon, b: Building, pre: String) -> Array:
	var out: Array = []
	for key: String in econ._lv:
		if key.begins_with("%d:%s" % [b.id, pre]):
			out.append(String(econ._lv[key][0]))
	return out


func test_pics() -> void:
	var pics: Dictionary = BldEcon.Pics.PICS
	var idx := {}
	for nm: String in pics:
		idx[int(pics[nm]["i"])] = true
	check(pics.size() <= 64 and idx.size() == pics.size(), "그림 %d장 ≤ 64 (셰이더 표 크기) · 칸 번호가 겹치지 않음" % pics.size())
	var missing: Array = []
	var fams := BldEcon.GOODS.values()
	fams.append("goods")
	for f: String in fams:
		for lv in [1, 2, 3]:
			if not BldEcon.has("%s_%d" % [f, lv]):
				missing.append("%s_%d" % [f, lv])
	for nm: String in BldEcon.WANT.values() + ["bub_want_goods", "bub_noworker", "bub_full", "peg_on", "peg_off", "leaf", "puff", "star"]:
		if not BldEcon.has(nm):
			missing.append(nm)
	for k: StringName in BldEcon.FX:
		if not BldEcon.has(String(BldEcon.FX[k]["pic"])):
			missing.append(String(BldEcon.FX[k]["pic"]))
	for pic: String in BldEcon.LAYOUT:
		if not Bld2D.has(pic):
			missing.append("layout:" + pic)
		if BldEcon.LAYOUT[pic].has("fx") and not BldEcon.FX.has(BldEcon.LAYOUT[pic]["fx"]):
			missing.append("fx:" + pic)
	check(missing.is_empty(), "물건마다 더미 세 단계 · 풍선 · 말뚝 · 움직임 그림이 표에 있음 %s" % [missing])
	check(load(BldEcon.Pics.ATLAS) is Texture2D, "아틀라스는 가져온 텍스처 (내보낸 빌드에서 읽힘)")


func test_rules() -> void:
	check(BldEcon.level(0.0, 4.0) == 0 and BldEcon.level(0.4, 4.0) == 0 and BldEcon.level(1.0, 4.0) == 1 and BldEcon.level(2.0, 4.0) == 2
		and BldEcon.level(4.0, 4.0) == 3 and BldEcon.level(99.0, 4.0) == 3 and BldEcon.level(70.0, 210.0) == 1 and BldEcon.level(71.0, 210.0) == 2,
		"더미 단계: 없음 0 · ⅓까지 1 · ⅔까지 2 · 그 위 3")
	check(BldEcon.site_level(0, 4) == 0 and BldEcon.site_level(1, 4) == 1 and BldEcon.site_level(2, 4) == 2 and BldEcon.site_level(4, 4) == 3
		and BldEcon.site_level(1, 0) == 3, "짓는 터 자재 더미: 드는 양에 견준 세 단계")
	check(BldEcon.site_left(0, 0.0) == 0 and BldEcon.site_left(4, 0.0) == 4 and BldEcon.site_left(4, 0.5) == 2 and BldEcon.site_left(4, 0.99) == 1
		and BldEcon.site_left(4, 1.0) == 1, "짓는 터 자재는 지은 만큼 줄어듦 (다 지을 때까지 하나는 남음)")
	var on := 0
	for i in BldEcon.PEGS:
		on += 1 if BldEcon.peg_on(i, 0.5) else 0
	check(not BldEcon.peg_on(0, 0.0) and on == 3 and BldEcon.peg_on(BldEcon.PEGS - 1, 0.95), "말뚝 깃발: 0% 없음 · 50% 셋 · 95% 다섯")
	check(is_equal_approx(BldEcon.zoom_k(60.0), 1.0) and is_equal_approx(BldEcon.zoom_k(10.0), BldEcon.ZOOM_FAR_K) and BldEcon.zoom_k(20.0) > 1.2,
		"기본 마을 확대에서는 더미를 키움 (폰에서 읽히게)")
	check(BldEcon.goods_pic("밀", 2) == "wheat_2" and BldEcon.goods_pic("없는 물건", 9) == "goods_3" and BldEcon.out_full("빵") == float(Balance.BULK["빵"])
		and BldEcon.out_full("판자") == BldEcon.UNIT_FULL and BldEcon.store_full("통나무") == float(Balance.ENOUGH["통나무"]), "물건 → 그림 · '가득' 기준은 밸런스 표에서")


func test_site() -> void:
	var scene := _scene()
	var av := _village(scene)
	var a: Village = av[0]
	var vw: VillageView = av[1]
	var econ: BldEcon = vw.econ
	var mms := econ.find_children("*", "MultiMeshInstance3D", true, false)
	check(econ != null and mms.size() == 1 and econ.get_child_count() == 1, "보이는 살림 = MultiMesh 하나 (그리기 1번)")
	var b := _add(a, "오두막", false)
	check(b != null, "오두막 터를 놓음")
	if b == null:
		scene.queue_free()
		return
	b.prog = 0.0
	vw.sync(0.1, true)
	var pegs := _slots(econ, b, "g")
	check(pegs.size() == BldEcon.PEGS and pegs.count("peg_off") == BldEcon.PEGS and _slots(econ, b, "p").is_empty() and _slots(econ, b, "s").is_empty(),
		"빈 터: 말뚝 다섯 (깃발 없음) · 자재 더미 없음 %s" % [pegs])
	var n: Node3D = vw._blds[b.id]
	var cards := 0
	var boxes := 0
	for c: Node in n.get_children():
		if String(c.name).begins_with("card2d"):
			cards += 1
		elif c is MeshInstance3D:
			boxes += 1
	check(cards == 1 and boxes == 0 and (n.get_node("piles") as Node3D).get_child_count() == 0,
		"짓는 터 노드 = 그림 한 장 (3D 말뚝·줄 그림자 대역 · 옛 더미 없음)")
	b.delivered["판자"] = b.need("판자")
	b.delivered["돌"] = b.need("돌")
	vw.sync(0.1, true)
	var full_p := _slots(econ, b, "p")
	check(full_p == ["planks_3"] and (b.need("돌") == 0 or _slots(econ, b, "s") == ["stone_3"]) and _near(vw, b, "planks_").has("planks_3"),
		"자재가 다 오면 터 앞에 가득 찬 더미 %s" % [full_p])
	b.prog = float(Balance.B[b.site_type()]["time"]) * 0.6
	vw.sync(0.1, true)
	var mid_p := _slots(econ, b, "p")
	check(_slots(econ, b, "g").count("peg_on") == 3 and mid_p.size() == 1 and mid_p[0] != "planks_3", "60%% 지음: 깃발 셋 · 자재 더미가 줄어듦 %s" % [mid_p])
	var plops := 0
	for it: Array in econ.items:
		if int(it[3]) == 1 and float(it[4]) > 0.0:
			plops += 1
	check(plops > 0, "바뀐 더미·말뚝은 통 튐 (처음 본 것은 가만히)")
	var pops0 := econ.n_pops
	b.prog = float(Balance.B[b.site_type()]["time"])
	b.built = true
	b.built_t = a.t
	vw.sync(0.1, true)
	var burst := 0
	for it: Array in econ.items:
		if int(it[3]) == 4:
			burst += 1
	check(econ.n_pops == pops0 + 1 and burst >= 10 and _slots(econ, b, "g").is_empty() and _slots(econ, b, "p").is_empty(), "다 지으면 '퐁' 한 번 (잎·먼지·별 %d조각) · 말뚝은 사라짐" % burst)
	for i in 12:
		vw.sync(0.2, i % 2 == 0)
	burst = 0
	for it: Array in econ.items:
		if int(it[3]) == 4:
			burst += 1
	var kk := 0.0
	for c: Node in (vw._blds[b.id] as Node3D).get_children():
		if c is MeshInstance3D and c.has_meta(&"pic"):
			kk = float((c as MeshInstance3D).get_instance_shader_parameter("k"))
	check(burst == 0 and econ.n_pops == pops0 + 1 and is_equal_approx(kk, 1.0), "조금 뒤 조각은 사라지고 그림은 제 크기로")
	scene.queue_free()


func test_workplace() -> void:
	var scene := _scene()
	var av := _village(scene)
	var a: Village = av[0]
	var vw: VillageView = av[1]
	var econ: BldEcon = vw.econ
	var b := _add(a, "제재소", true)
	check(b != null, "제재소를 놓음")
	if b == null:
		scene.queue_free()
		return
	b.worker = -1
	b.in_buf["통나무"] = 0.0
	b.out["판자"] = 0.0
	vw.sync(0.1, true)
	check(_slots(econ, b, "i").is_empty() and _slots(econ, b, "o").is_empty() and _near(vw, b, "chip").is_empty(), "빈 일터: 더미도 움직임도 없음")
	b.in_buf["통나무"] = Production.in_cap("통나무")
	b.out["판자"] = 2.0
	vw.sync(0.1, true)
	check(_slots(econ, b, "i") == ["logs_3"] and _slots(econ, b, "o") == ["planks_2"], "재료 더미(가득) · 산출 더미(절반) %s %s" % [_slots(econ, b, "i"), _slots(econ, b, "o")])
	check(_near(vw, b, "chip").is_empty(), "일꾼이 없으면 고요")
	b.worker = (a.people[0] as Resident).id
	for i in 3:
		b.timer += 1.0
		vw.sync(0.1, true)
	check(_near(vw, b, "chip").size() == int(BldEcon.FX[&"chips"]["n"]), "일터 시계가 도는 동안 톱밥이 튐")
	for i in 6:
		vw.sync(0.25, true)
	check(_near(vw, b, "chip").is_empty(), "시계가 멈추면 다시 고요")
	var store: Building = null
	for x: Building in a.buildings:
		if x.is_store and x.built:
			store = x
	if store != null:
		a.stock["통나무"] = float(Balance.ENOUGH["통나무"])
		a.stock["돌"] = 1.0
		vw.sync(0.1, true)
		var ws := _slots(econ, store, "w")
		check(ws.has("logs_3") and ws.has("stone_1"), "창고 앞 더미 = 창고에 든 것 %s" % [ws])
	var house: Building = null
	for x: Building in a.buildings:
		if x.is_house() and x.built and x.upgrade_to == "":
			house = x
	if house != null:
		house.in_buf["통나무"] = Balance.FUEL_TARGET
		house.fuel_on = true
		vw.sync(0.1, true)
		check(_slots(econ, house, "f") == ["logs_3"] and _near(vw, house, "puff").size() >= 3, "집: 땔감 더미 · 불을 때면 연기")
	check(econ.items.size() <= BldEcon.CAP, "그림 수 %d ≤ %d" % [econ.items.size(), BldEcon.CAP])
	econ.on = false
	vw.sync(0.1, true)
	check(econ.items.is_empty() and not (econ.get_child(0) as Node3D).visible, "끄면 아무것도 그리지 않음")
	econ.on = true
	Bld2D.override = 0
	vw.sync(0.1, true)
	check(econ.items.is_empty(), "3D 대역 건물에서는 그리지 않음 (옛 더미 그대로)")
	Bld2D.override = 1
	vw.sync(0.1, true)
	check(not econ.items.is_empty(), "그림 건물로 돌아오면 다시")
	scene.queue_free()


func test_bubbles() -> void:
	var scene := _scene()
	var av := _village(scene)
	var a: Village = av[0]
	var vw: VillageView = av[1]
	var econ: BldEcon = vw.econ
	_wide_cam(scene, vw)
	var saw := _add(a, "제재소", true)
	if saw == null:
		check(false, "제재소를 놓음")
		scene.queue_free()
		return
	saw.in_buf["통나무"] = 0.0
	saw.out["판자"] = 0.0
	check(BldEcon.stall_pic(a, saw) == "", "막히지 않은 일터는 풍선 없음")
	a._stall[saw.id] = {"why": &"no_input", "since": a.t - 7200.0, "stalled": true, "at": a.t, "ok": -1.0}
	check(BldEcon.stall_pic(a, saw) == "bub_want_logs", "재료가 없어 막힘 → 모자란 재료 그림")
	a._stall[saw.id] = {"why": &"no_worker", "since": a.t - 7200.0, "stalled": true, "at": a.t, "ok": -1.0}
	check(BldEcon.stall_pic(a, saw) == "bub_noworker", "일손이 없어 막힘 → 빈 밀짚모자")
	a._stall[saw.id] = {"why": &"no_input", "since": a.t - 60.0, "stalled": false, "at": -1.0, "ok": -1.0}
	check(BldEcon.stall_pic(a, saw) == "", "잠깐 기다림은 막힘이 아님")
	saw.out["판자"] = BldEcon.out_full("판자") * BldEcon.OVERFLOW
	check(BldEcon.stall_pic(a, saw) == "bub_full", "산출물이 넘치게 쌓임 → 넘치는 바구니")
	var site := _add(a, "오두막", false)
	if site != null:
		var keep_p: float = a.stock.get("판자", 0.0)
		var keep_s: float = a.stock.get("돌", 0.0)
		a.stock["판자"] = 0.0
		a.stock["돌"] = 0.0
		site.delivered["판자"] = 0
		site.incoming["판자"] = 0
		check(BldEcon.stall_pic(a, site) == ("bub_want_planks" if site.need("판자") > 0 else "bub_want_stone"), "자재가 떨어진 짓는 터 → 모자란 자재 그림")
		a.stock["판자"] = maxf(keep_p, 50.0)
		a.stock["돌"] = maxf(keep_s, 50.0)
		check(BldEcon.stall_pic(a, site) == "", "창고에 자재가 있으면 (곧 온다) 풍선 없음")
	for t: String in ["우물", "맷돌간", "화덕", "나무꾼", "오두막"]:      # 막힌 곳을 풍선 수보다 많게
		var nb := _add(a, t, true)
		if nb != null:
			nb.built_t = a.t
	var n := 0
	for b: Building in a.buildings:
		if b.built and b.site_type() != Awakening.ALTAR:
			a._stall[b.id] = {"why": &"no_worker", "since": a.t - 7200.0, "stalled": true, "at": a.t, "ok": -1.0}
			n += 1
	vw.sync(0.3, true)
	var shown := 0
	for id: int in econ.bubbles:
		shown += 1 if float(econ.bubbles[id]["t0"]) >= 0.0 else 0
	check(n > BldEcon.BUBBLE_MAX and econ.bubbles.size() >= n and shown == 0, "막힌 일터 %d곳 — 풍선은 바로 뜨지 않음" % n)
	vw.sync(BldEcon.BUBBLE_DELAY, true)
	vw.sync(0.3, true)
	shown = 0
	for id: int in econ.bubbles:
		shown += 1 if float(econ.bubbles[id]["t0"]) >= 0.0 else 0
	var drawn := 0
	for it: Array in econ.items:
		drawn += 1 if String(it[0]).begins_with("bub_") else 0
	check(shown >= 1 and shown <= BldEcon.BUBBLE_MAX and drawn == shown, "조금 뒤 풍선 %d개 (한 화면에 %d개까지)" % [shown, BldEcon.BUBBLE_MAX])
	a._stall.clear()
	saw.out["판자"] = 0.0
	vw.sync(0.3, true)
	drawn = 0
	for it: Array in econ.items:
		drawn += 1 if String(it[0]).begins_with("bub_") else 0
	check(drawn == 0, "풀리면 풍선이 사라짐")
	scene.queue_free()


func _snap(a: Village) -> Array:
	var out: Array = []
	for r: Resident in a.people:
		out.append("%d:%.3f,%.3f" % [r.id, r.x, r.y])
	for x: Building in a.buildings:
		out.append("%d:%s:%.3f:%s:%.3f:%s:%s:%d:%s:%s" % [x.id, x.type, x.prog, x.built, x.timer, x.in_buf, x.out, x.worker, x.delivered, x.fuel_on])
	out.append(str(a.stock))
	out.append(str(a._stall.keys()))
	out.append("%.3f" % a.t)
	return out


## 화면(보이는 살림 켬 / 끔 / 화면 없음)을 달리해도 시뮬레이션 결과가 같다 (ADR-0001)
func test_sim_unchanged() -> void:
	for f: String in ["res://view/bld2d/bld_econ.gd"]:
		var src := FileAccess.get_file_as_string(f)
		var re := RegEx.create_from_string("\\b(b|v|r|village|vil)\\.[a-z_]+\\s*(=|\\+=|-=)[^=]")
		check(src != "" and re.search(src) == null, "%s가 건물·마을 데이터를 쓰지 않음" % f.get_file())
		check(src.find("static var") < 0 and src.find("randf") < 0 and src.find("randi") < 0 and src.find(".rng") < 0,
			"%s: static var 없음 · 난수 없음 (ADR-0001)" % f.get_file())
	var scene := _scene()
	Village.start_aware = true
	var a := Village.new_prototype(20261109)
	var b := Village.new_prototype(20261109)
	var c := Village.new_prototype(20261109)
	Village.start_aware = false
	a.water.offline = true
	b.water.offline = true
	c.water.offline = true
	var va := VillageView.new(a, scene.get("terrain"))
	scene.add_child(va)
	var vb := VillageView.new(b, scene.get("terrain"))
	scene.add_child(vb)
	vb.econ.on = false
	var seen := 0
	for i in 8:
		a.advance(0.05 * Balance.DAY)
		for j in 4:
			va.sync(0.4, j == 0)
		va._bld_lod(true)
		seen = maxi(seen, va.econ.items.size())
		b.advance(0.05 * Balance.DAY)
		for j in 4:
			vb.sync(0.4, j == 0)
		c.advance(0.05 * Balance.DAY)
	var sa := _snap(a)
	check(sa == _snap(b) and sa == _snap(c) and a.buildings.size() > 2 and seen > 0 and vb.econ.items.is_empty(),
		"보이는 살림을 켜든 끄든 · 화면이 없든 주민·건물·창고·막힘 판정이 같음 (건물 %d채, 그림 %d장까지)" % [a.buildings.size(), seen])
	scene.queue_free()
