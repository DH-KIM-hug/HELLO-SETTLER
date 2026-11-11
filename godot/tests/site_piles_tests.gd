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
	run.timed(self, ["test_pics", "test_rules", "test_site", "test_workplace", "test_gather", "test_apron", "test_yaw", "test_plants", "test_wheat", "test_front", "test_stall_gather", "test_bubbles", "test_sim_unchanged"])
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


## 게임 카메라와 같은 각(기울기 48° · 방위 45° + 90° × st)의 넓은 카메라 — '앞'이 카메라 방위를 따라가는지 볼 때 (v3)
func _yaw_cam(scene: Node, vw: VillageView, st: int) -> void:
	var c := Vector3.ZERO
	for id: int in vw._blds:
		c = (vw._blds[id] as Node3D).global_position
		break
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG + 90.0 * float(st))
	var pitch := deg_to_rad(JarCamera.PITCH_DEG)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4000.0
	cam.far = 8000.0
	scene.add_child(cam)
	cam.look_at_from_position(c + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 2000.0, c)
	cam.make_current()


## 건물 자리 org 둘레 r 안의, 이름이 pre로 시작하는 더미들의 자리 [화면 오른쪽, 카메라 쪽] (건물 자리에서)
func _pile_xy(econ: BldEcon, org: Vector3, pre: String, r: float) -> Array:
	var out: Array = []
	for it: Array in econ.items:
		var d := Vector2((it[1] as Vector3).x - org.x, (it[1] as Vector3).z - org.z)
		if String(it[0]).begins_with(pre) and d.length() < r:
			out.append(Vector2(d.dot(econ._r2), d.dot(econ._f2)))
	return out


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
## 다 지은 집 하나 (없으면 오두막을 놓음)
func _house(a: Village) -> Building:
	for x: Building in a.buildings:
		if x.is_house() and x.built and x.upgrade_to == "":
			return x
	return _add(a, "오두막", true)


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
	for nm: String in BldEcon.WANT.values() + ["bub_want_goods", "bub_noworker", "bub_full", "bub_no_tree", "bub_no_rock", "peg_on", "peg_off", "leaf", "puff", "star"]:
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
	var house := _house(a)
	check(house != null, "집이 있음")
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


## 자리 p 둘레 r 안의 그림 (이름이 pre로 시작하는 것) 수
func _at_point(vw: VillageView, p: Vector2, r: float, pre: String) -> int:
	var n := 0
	for it: Array in vw.econ.items:
		if String(it[0]).begins_with(pre) and Vector2((it[1] as Vector3).x - p.x, (it[1] as Vector3).z - p.y).length() < r:
			n += 1
	return n


## (v2) 채집 일터(나무꾼·채석장): 건물에 쌓이는 값이 없다 — 더미는 마을 창고에 든 것, 움직임은 그 일꾼이 나무·바위에서 일하는 동안만
func test_gather() -> void:
	var scene := _scene()
	var av := _village(scene)
	var a: Village = av[0]
	var vw: VillageView = av[1]
	var econ: BldEcon = vw.econ
	for row: Array in [["나무꾼", "통나무", "logs_", "chip", &"chips"], ["채석장", "돌", "stone_", "pebble", &"pebbles"]]:
		var ty := String(row[0])
		var k := String(row[1])
		var b := _add(a, ty, true)
		check(b != null, "%s를 놓음" % ty)
		if b == null:
			continue
		var n := int(BldEcon.FX[row[4]]["n"])
		b.worker = -1
		a.stock[k] = 0.0
		vw.sync(0.1, true)
		check(_slots(econ, b, "o").is_empty() and _near(vw, b, String(row[3])).is_empty(), "%s: 창고가 비고 일꾼이 없으면 더미도 움직임도 없음" % ty)
		a.stock[k] = BldEcon.store_full(k)
		vw.sync(0.1, true)
		check(_slots(econ, b, "o") == [String(row[2]) + "3"], "%s: 더미 = 마을 창고에 든 %s (가득) %s" % [ty, k, _slots(econ, b, "o")])
		a.stock[k] = 1.0
		vw.sync(0.1, true)
		check(_slots(econ, b, "o") == [String(row[2]) + "1"], "%s: 창고가 줄면 더미도 줄어듦 %s" % [ty, _slots(econ, b, "o")])
		# 일꾼: 일터에서 떨어진 나무·바위에서 정말 베고 캐는 중 (ResidentAI.work_task가 주는 걸음 그대로)
		var r: Resident = null
		for q: Resident in a.people:
			if q.is_adult() and not q.dead and q.job < 0:
				r = q
				break
		if r == null:
			r = a.people[0]
		var rock := ty == "채석장"
		var node := {}
		var best := 1.0e9
		for q: Dictionary in (a.rocks if rock else a.trees):
			if (float(q["amt"]) <= 0.0 if rock else String(q["s"]) != "tree"):
				continue
			var dq := Vector2(float(q["x"]) - b.x, float(q["y"]) - b.y).length()
			var sq := econ.stand_of(q)
			if dq > b.size() * 2.0 + 5.0 and dq < best and not econ._card_covers(Vector2(sq.x, sq.y)):
				best = dq
				node = q
		check(not node.is_empty(), "%s: 건물 그림에 안 가리는 %s가 있음" % [ty, "바위" if rock else "나무"])
		if node.is_empty():
			continue
		var keep := [r.job, r.x, r.y, r.action, r.anim, r.carry, r.sleeping, r.steps.duplicate()]
		var np := Vector2(float(node["x"]), float(node["y"]))
		var spot := np + (BldEcon.ROCK_AT if rock else BldEcon.TREE_AT)
		var gstep := ResidentAI.act(1.0e6, "work", ResidentAI.op("dig", {"rk": node}) if rock else ResidentAI.op("chop", {"tr": node}), true, ResidentAI.op("unres", {"q": node}))
		r.job = b.id
		b.worker = r.id
		r.x = spot.x
		r.y = spot.y
		r.px = spot.x
		r.py = spot.y
		r.sleeping = false
		r.carry = ""
		r.action = "work"
		r.anim = "work"
		r.steps.clear()
		r.steps.append(gstep)
		check(BldEcon.gather_worker(a, b) == r, "%s: 일하는 중인 일꾼을 읽음" % ty)
		for i in 8:
			vw.sync(0.5, true)
		var st := econ.stand_of(node)
		var sp2 := Vector2(st.x, st.y)
		var fx_at := sp2 + econ._f2 * BldEcon.GATHER_FRONT
		check(_at_point(vw, fx_at, 1.0, String(row[3])) == n, "%s: 일꾼 인형이 선 자리에 조각이 튐 (%d개)" % [ty, _at_point(vw, fx_at, 1.0, String(row[3]))])
		check(_near(vw, b, String(row[3])).size() == (n if BldEcon.GATHER_AT_CAMP else 0), "%s: 일터 그림에도 '일하는 중' 움직임" % ty)
		# (v3) 인형은 나무·바위 그림에 가리지 않는 자리에: 그림 밑변보다 카메라 쪽 · 옆으로 비켜 · 나무·바위를 봄 — 시뮬 자리는 그대로
		var m: Node3D = vw.residents[r.id]
		var dn := sp2 - np
		var inf := Flora2D.info(Flora2D.pic_for("rocks"))
		var dk := float(econ.rock_draw.get(np, minf(0.8 + float(node["amt"]) / 25.0, 2.4))) if rock else 0.0
		var toe := (float(inf.get("front", 0.0)) * dk + BldEcon.STAND_TOE) if rock else BldEcon.STAND_FRONT
		var look := Vector2(sin(st.z), cos(st.z))
		var off := Vector2(m.position.x - st.x, m.position.z - st.y).length()
		check(off < 0.05 and absf(angle_difference(m.rotation.y, st.z)) < 0.01, "%s: 일하는 동안 인형은 선 자리에 (%.2f 떨어짐)" % [ty, off])
		check(dn.dot(econ._sf) >= toe - 0.01 and absf(dn.dot(econ._sr)) >= 0.3 and look.dot(-dn) > 0.0 and not econ._card_covers(sp2),
			"%s: 선 자리 = 그림 밑변 앞(%.2f ≥ %.2f) · 옆으로 %.2f · 나무·바위 쪽을 봄" % [ty, dn.dot(econ._sf), toe, dn.dot(econ._sr)])
		check(r.x == spot.x and r.y == spot.y and r.steps.size() == 1 and r.steps[0] == gstep, "%s: 주민의 시뮬 자리·걸음은 그대로" % ty)
		var keep_cov: Array = econ._covers
		var sgn := signf(dn.dot(econ._sr))
		var cb := sp2 + econ._f2 * 1.0 + econ._r2 * (sgn * 0.5)
		econ._covers = [[cb.x, cb.y, 0.4, 3.0, -99]]       # 그 자리 앞에 건물 그림이 서면 → 반대편
		var st2 := econ.stand_of(node)
		var flip := (Vector2(st2.x, st2.y) - np).dot(econ._sr)
		econ._covers = [[cb.x, cb.y, 50.0, 30.0, -99]]     # 어디에 서도 가리면 → 제자리 (자리를 거짓으로 멀리 옮기지 않음)
		var st3 := econ.stand_of(node)
		econ._covers = keep_cov
		check(signf(flip) == -sgn and Vector2(st3.x - st.x, st3.y - st.y).length() < 0.01, "%s: 선 자리가 건물 그림에 가리면 반대편 (%.2f → %.2f)" % [ty, dn.dot(econ._sr), flip])
		# (v3 · 5) 조각은 정말 베고 캐는 동안만: 같은 '일하는 몸짓'이라도 다른 일이면 일꾼 곁에도 일터에도 없음
		r.steps.clear()
		r.steps.append(ResidentAI.act(1.0e6, "work"))
		check(BldEcon.gather_worker(a, b) == null, "%s: 다른 일을 하는 몸짓은 채집이 아님" % ty)
		vw.sync(0.1, true)
		check(_at_point(vw, fx_at, 1.5, String(row[3])) == 0 and _near(vw, b, String(row[3])).is_empty(), "%s: 채집이 아니면 일꾼 곁에도 일터에도 조각 없음" % ty)
		r.steps.clear()
		r.steps.append(ResidentAI.act(1.0e6, "work", ResidentAI.op("chop", {"tr": node}) if rock else ResidentAI.op("dig", {"rk": node}), true))
		check(BldEcon.gather_worker(a, b) == null, "%s: 다른 일터의 채집 걸음은 세지 않음" % ty)
		r.steps.clear()
		r.steps.append(gstep)
		check(BldEcon.gather_worker(a, b) == r, "%s: 다시 베고 캐면 일하는 중" % ty)
		r.anim = "carry"
		r.action = "haul"
		r.carry = k
		check(BldEcon.gather_worker(a, b) == null, "%s: 나르는 중에는 일하는 중이 아님" % ty)
		vw.sync(0.1, true)
		check(_at_point(vw, fx_at, 1.5, String(row[3])) == 0 and _near(vw, b, String(row[3])).is_empty(), "%s: 일을 멈추면 고요" % ty)
		r.carry = ""
		r.anim = "work"
		r.action = "work"
		r.job = -1
		check(BldEcon.gather_worker(a, b) == null, "%s: 그 일터 사람이 아니면 세지 않음" % ty)
		r.job = b.id
		b.worker = -1
		check(BldEcon.gather_worker(a, b) == null, "%s: 일꾼 자리가 비면 세지 않음" % ty)
		r.job = keep[0]
		r.x = keep[1]
		r.y = keep[2]
		r.px = r.x
		r.py = r.y
		r.action = keep[3]
		r.anim = keep[4]
		r.carry = keep[5]
		r.sleeping = keep[6]
		r.steps.clear()
		r.steps.append_array(keep[7])
	scene.queue_free()


## (v2) 더미 앞마당: 건물 앞(카메라 쪽)에 선 키 큰 그림은 더미를 가리지 않는 키까지만 · 집 땔감은 문 옆 단지를 비켜 벽 옆에
func test_apron() -> void:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var tw := Vector2(sin(yaw), cos(yaw))
	var rt := Vector2(cos(yaw), -sin(yaw))
	var ap := [[10.0, 20.0, 1.5, 3.0]]      # 건물 (10, 20) · 더미 줄 1.5 · 옆 폭 3
	var o := Vector2(10.0, 20.0)
	var p := o + tw * 3.5                    # 더미 줄에서 카메라 쪽으로 2
	check(is_equal_approx(BldEcon.apron_h(ap, p.x, p.y, 6.0), 2.0 * BldEcon.APRON_SIN), "앞마당: 줄 앞 2칸에 선 큰 그림은 2 × sin 48° 키까지 (%.2f)" % BldEcon.apron_h(ap, p.x, p.y, 6.0))
	check(is_equal_approx(BldEcon.apron_h(ap, p.x, p.y, 1.2), 1.2), "앞마당: 가리지 않는 키는 그대로")
	p = o + tw * 1.6
	check(is_equal_approx(BldEcon.apron_h(ap, p.x, p.y, 3.0), BldEcon.APRON_MIN_H), "앞마당: 더미 바로 앞은 가장 낮게 (%.2f)" % BldEcon.APRON_MIN_H)
	check(is_equal_approx(BldEcon.apron_h(ap, p.x, p.y, BldEcon.APRON_MIN_H), BldEcon.APRON_MIN_H), "앞마당: 낮은 풀은 그대로")
	p = o - tw * 2.0
	check(is_equal_approx(BldEcon.apron_h(ap, p.x, p.y, 6.0), 6.0), "앞마당: 건물 뒤는 그대로")
	p = o + tw * 3.5 + rt * 3.6
	check(is_equal_approx(BldEcon.apron_h(ap, p.x, p.y, 6.0), 6.0), "앞마당: 옆으로 비켜 선 것은 그대로")
	check(BldEcon.apron_h(ap, p.x, p.y, 6.0, 1.0) < 6.0, "앞마당: 폭이 넓어 걸치는 그림은 낮춤")
	p = o + tw * 12.0
	check(is_equal_approx(BldEcon.apron_h(ap, p.x, p.y, 6.0), 6.0), "앞마당: 멀리 앞에 선 것은 그대로 (가리지 않음)")
	check(is_equal_approx(BldEcon.apron_h([], 0.0, 0.0, 6.0), 6.0), "앞마당: 건물이 없으면 그대로")

	var scene := _scene()
	var av := _village(scene)
	var a: Village = av[0]
	var vw: VillageView = av[1]
	var econ: BldEcon = vw.econ
	var b := _house(a)
	check(b != null, "집이 있음")
	vw.sync(0.1, true)
	var list := BldEcon.apron_list(a)
	var altars := 0
	for x: Building in a.buildings:
		if x.site_type() == Awakening.ALTAR:
			altars += 1
	check(not list.is_empty() and list.size() <= a.buildings.size() - altars, "앞마당 목록: 건물마다 하나 (제단은 뺌) %d / %d" % [list.size(), a.buildings.size()])
	if b != null:
		var line := 0.0
		for e: Array in list:
			if is_equal_approx(float(e[0]), b.x) and is_equal_approx(float(e[1]), b.y):
				line = float(e[2])
		check(line > BldEcon.FRONT_GAP, "앞마당 목록: 집의 더미 줄 = 그림 밑변 앞 (%.2f)" % line)
		var q := Vector2(b.x, b.y) + tw * (line + 1.0)
		var s0 := 0.5
		var h0 := float(Flora2D.info(Flora2D.pic_for("flora/poppy_red")).get("h", 0.0)) * s0
		var s1 := econ.apron_scale("flora/poppy_red", q.x, q.y, s0)
		check(h0 > 3.0 and s1 < s0 and s1 * h0 / s0 <= 1.0 * BldEcon.APRON_SIN + 0.01, "앞마당: 집 앞 1칸의 큰 양귀비(키 %.1f)는 %.2f로 낮춤" % [h0, s1 * h0 / s0])
		check(is_equal_approx(econ.apron_scale("flora/fallen_leaf_dry", q.x, q.y, 1.0), 1.0), "앞마당: 땅에 눕힌 그림은 그대로")
		check(is_equal_approx(econ.apron_scale("no_such_model", q.x, q.y, 1.0), 1.0), "앞마당: 그림이 없는 모델은 그대로")
		# 집 땔감: 그림 왼쪽 벽 밖에 (문 옆 단지는 그림 안쪽 — 그림 반 폭 안)
		b.in_buf["통나무"] = Balance.FUEL_TARGET
		vw.sync(0.1, true)
		var org: Vector3 = (vw._blds[b.id] as Node3D).position
		var w := float(Bld2D.info(String(BldEcon.pic_k(a, b)[0]))["w"])
		var side := 1.0e9
		for it: Array in econ.items:
			if String(it[0]).begins_with("logs_") and Vector2((it[1] as Vector3).x - org.x, (it[1] as Vector3).z - org.z).length() < w + 3.0:
				side = minf(side, Vector2((it[1] as Vector3).x - org.x, (it[1] as Vector3).z - org.z).dot(econ._r2))
		check(_slots(econ, b, "f") == ["logs_3"] and side <= -(w * 0.5 + BldEcon.HOUSE_WOOD.x) + 0.01, "집 땔감: 그림 왼쪽 벽 밖에 (%.2f ≤ -%.2f)" % [side, w * 0.5 + BldEcon.HOUSE_WOOD.x])
	scene.queue_free()


## (v3) '앞'은 카메라 방위를 따라간다: 네 걸음 어디서나 카메라 쪽 앞마당만 낮춤 · 가만히 있으면 다시 놓지 않음
func test_yaw() -> void:
	var ap := [[10.0, 20.0, 1.5, 3.0]]
	var o := Vector2(10.0, 20.0)
	var bad: Array = []
	for st in 4:
		var tw: Vector2 = BldEcon.step_dirs(st)[0]
		if BldEcon.step_of(tw) != st or BldEcon.step_of(tw.rotated(0.3)) != st:
			bad.append("걸음 %d" % st)
		var p := o + tw * 3.5
		if not is_equal_approx(BldEcon.apron_h(ap, p.x, p.y, 6.0, 0.0, st), 2.0 * BldEcon.APRON_SIN):
			bad.append("앞 %d" % st)
		if not is_equal_approx(BldEcon.apron_h(ap, p.x, p.y, 6.0, 0.0, (st + 2) % 4), 6.0) or not is_equal_approx(BldEcon.apron_h(ap, p.x, p.y, 6.0, 0.0, (st + 1) % 4), 6.0):
			bad.append("뒤·옆 %d" % st)
	check(bad.is_empty(), "방위 네 걸음: 그 방위에서 카메라 쪽에 선 것만 낮춤 %s" % [bad])
	var tw1: Vector2 = BldEcon.step_dirs(1)[0]
	var rt1: Vector2 = BldEcon.step_dirs(1)[1]
	var q := o + tw1 * 0.5                   # 더미 줄보다 1 뒤에 선 큰 꽃 — 그림 밑변(front × 크기 = 2)이 줄 앞으로 나온다
	var cap := BldEcon.apron_h(ap, q.x, q.y, 6.0, 0.0, 1, 2.0)
	check(is_equal_approx(BldEcon.apron_h(ap, q.x, q.y, 6.0, 0.0, 1), 6.0) and cap < 6.0 and 2.0 * cap / 6.0 <= 1.0 - BldEcon.APRON_CLEAR + 0.001,
		"줄 뒤에 선 큰 꽃: 그림 밑변이 줄 뒤로 물러날 만큼만 줄임 (키 6 → %.2f)" % cap)
	q = o - tw1 * 1.0
	check(is_equal_approx(BldEcon.apron_h(ap, q.x, q.y, 6.0, 0.0, 1, 2.0), 6.0), "밑변이 줄에 닿지 않는 뒤쪽 꽃은 그대로")
	var nd := Vector2(30.0, 40.0)            # 일꾼이 베는 꽃 · 그 앞 일꾼 자리의 앞마당 한 줄
	var own := [[nd.x + tw1.x, nd.y + tw1.y, 0.0, 0.5, nd.x, nd.y]]
	var mate := nd + rt1 * 0.3
	var fr := nd + tw1 * 2.0
	check(is_equal_approx(BldEcon.apron_h(own, nd.x, nd.y, 6.0, 0.0, 1, 2.0), 6.0) and BldEcon.apron_h(own, mate.x, mate.y, 6.0, 0.0, 1, 2.0) < 6.0
		and is_equal_approx(BldEcon.apron_h(own, fr.x, fr.y, 6.0, 0.0, 1), 1.0 * BldEcon.APRON_SIN), "채집 일꾼 앞마당: 베는 꽃은 그대로 · 곁의 꽃과 일꾼 앞의 꽃은 낮춤")

	var scene := _scene()
	var av := _village(scene)
	var a: Village = av[0]
	var vw: VillageView = av[1]
	var econ: BldEcon = vw.econ
	_yaw_cam(scene, vw, 0)
	vw.sync(0.1, true)
	var v0 := econ.apron_ver
	var k0 := econ.place_key()
	vw.sync(0.1, true)
	vw.sync(0.3, true)
	check(econ.step == 0 and econ.apron_ver == v0 and econ.place_key() == k0, "카메라가 가만히 있으면 앞마당을 다시 재지 않음 (꽃·풀을 다시 놓지 않음)")
	_yaw_cam(scene, vw, 1)
	vw.sync(0.1, true)
	var v1 := econ.apron_ver
	check(econ.step == 1 and v1 > v0 and econ.place_key() != k0 and econ._sf.distance_to(tw1) < 0.001 and econ._f2.distance_to(tw1) < 0.01,
		"카메라가 한 걸음 돌면 '앞'도 돈다 (걸음 %d · 앞마당 %d → %d)" % [econ.step, v0, v1])
	vw.sync(0.1, true)
	vw.sync(0.3, true)
	check(econ.apron_ver == v1, "돈 뒤에도 가만히 있으면 그대로")
	var b := _house(a)
	check(b != null, "집이 있음")
	if b != null:
		b.in_buf["통나무"] = Balance.FUEL_TARGET
		econ._apron_frame = -1
		vw.sync(0.1, true)
		var line := 0.0
		for e: Array in BldEcon.apron_list(a):
			if is_equal_approx(float(e[0]), b.x) and is_equal_approx(float(e[1]), b.y):
				line = float(e[2])
		q = Vector2(b.x, b.y) + tw1 * (line + 1.0)
		var s0 := 0.5
		var h0 := float(Flora2D.info(Flora2D.pic_for("flora/poppy_red")).get("h", 0.0)) * s0
		var s1 := econ.apron_scale("flora/poppy_red", q.x, q.y, s0)
		check(s1 < s0 and s1 * h0 / s0 <= 1.0 * BldEcon.APRON_SIN + 0.01, "돈 방위에서 집 앞 1칸의 큰 양귀비는 %.2f로 낮춤" % (s1 * h0 / s0))
		var pc := econ.plant_cap(q.x, q.y, 3.3, 0.8, 1.66)
		econ.on = false
		var pc_off := econ.plant_cap(q.x, q.y, 3.3, 0.8, 1.66)
		econ.on = true
		check(pc * 3.3 <= 1.0 * BldEcon.APRON_SIN + 0.01 and is_equal_approx(pc_off, 1.0), "민들레·큰 버섯도 같은 규칙 (키 3.3 → %.2f · 끄면 그대로)" % (pc * 3.3))
		var org: Vector3 = (vw._blds[b.id] as Node3D).position
		var w := float(Bld2D.info(String(BldEcon.pic_k(a, b)[0]))["w"])
		var logs := _pile_xy(econ, org, "logs_", w * 0.5 + BldEcon.NUDGE_OUT + 0.6)
		var okp := false
		for lp: Vector2 in logs:
			var wd := econ._r2 * lp.x + econ._f2 * lp.y
			okp = okp or (wd.dot(tw1) > 0.0 and absf(wd.dot(rt1)) <= w * 0.5 + BldEcon.NUDGE_OUT + 0.01)
		check(okp, "돈 방위에서도 집 땔감 더미는 그림 앞(카메라 쪽) · 집 곁 %s" % [logs])
	# 모든 건물의 더미 줄: 그 앞 어디에 큰 꽃을 놓아도 줄을 가리지 않는 키까지만 (두 방위)
	for st in [0, 1]:
		_yaw_cam(scene, vw, st)
		vw.sync(0.1, true)
		var sd := BldEcon.step_dirs(st)
		var s0 := 0.5
		var h0 := float(Flora2D.info(Flora2D.pic_for("flora/poppy_red")).get("h", 0.0)) * s0
		var over := 0
		var seen := 0
		for e: Array in BldEcon.apron_list(a):
			for d: float in [0.2, 1.0, 2.0, 4.0]:
				for lat: float in [-float(e[3]) + 0.1, 0.0, float(e[3]) - 0.1]:
					var pp: Vector2 = Vector2(float(e[0]), float(e[1])) + (sd[0] as Vector2) * (float(e[2]) + d) + (sd[1] as Vector2) * lat
					seen += 1
					if econ.apron_scale("flora/poppy_red", pp.x, pp.y, s0) * h0 / s0 > maxf(BldEcon.APRON_MIN_H, d * BldEcon.APRON_SIN) + 0.01:
						over += 1
		check(econ.step == st and seen > 0 and over == 0, "방위 걸음 %d: 건물 %d채의 더미 줄 앞 %d곳 — 줄을 가리는 키로 남는 꽃 없음 (%d)" % [st, a.buildings.size(), seen, over])
	scene.queue_free()


## 놓인 꽃숲(나무)·바위 가운데 더미 줄을 가리는 것 수 [가리는 것, 앞마당에 든 것] — VillageView가 실제로 그린 크기(tree_draw · rock_draw)로
func _plants_over(econ: BldEcon, st: int) -> Array:
	var sd := BldEcon.step_dirs(st)
	var tw: Vector2 = sd[0]
	var rt: Vector2 = sd[1]
	var drawn: Array = []                # [자리, 그림 이름, 크기]
	for tp: Vector2 in econ.tree_draw:
		drawn.append([tp, Flora2D.pic_for(String(econ.tree_draw[tp][0])), float(econ.tree_draw[tp][1])])
	for rp: Vector2 in econ.rock_draw:
		drawn.append([rp, Flora2D.pic_for("rocks"), float(econ.rock_draw[rp])])
	var over := 0
	var inside := 0
	for e: Array in drawn:
		var inf := Flora2D.info(String(e[1]))
		if inf.is_empty() or int(inf.get("mode", 0)) != 0:
			continue
		var p: Vector2 = e[0]
		var h := float(inf.get("h", 0.0)) * float(e[2])
		var base := float(inf.get("front", 0.0)) * float(e[2])
		for ap: Array in econ._aprons_now():
			var d := p - Vector2(float(ap[0]), float(ap[1]))
			var along := d.dot(tw) - float(ap[2])
			if absf(d.dot(rt)) > float(ap[3]) or along > 8.0 or along < -4.0:
				continue
			if ap.size() > 5 and absf(p.x - float(ap[4])) < 0.01 and absf(p.y - float(ap[5])) < 0.01:
				continue
			inside += 1
			if along >= 0.0:
				over += 1 if h > maxf(BldEcon.APRON_MIN_H, along * BldEcon.APRON_SIN) + 0.02 else 0
			elif h > BldEcon.APRON_MIN_H + 0.02 and base > -along + 0.02:      # 줄 뒤에 섰는데 그림 밑변이 줄 앞으로 나옴
				over += 1
	return [over, inside]


## (v3) 실제로 놓인 꽃숲·바위: 두 방위에서 어느 건물의 더미 줄도 가리지 않는다 (제 카메라로 — 그린 크기를 읽음)
func test_plants() -> void:
	var oldf := Flora2D.override
	Flora2D.override = 1
	var scene := _scene()
	var av := _village(scene)
	var a: Village = av[0]
	var vw: VillageView = av[1]
	var econ: BldEcon = vw.econ
	var b := _house(a)
	check(b != null, "집이 있음")
	if b != null:
		var line := 0.0
		for e: Array in BldEcon.apron_list(a):
			if is_equal_approx(float(e[0]), b.x) and is_equal_approx(float(e[1]), b.y):
				line = float(e[2])
		var mine: Array = []             # 집 더미 줄 앞 1칸에 심은 큰 꽃 · 큰 바위 (방위마다)
		for st in [0, 1]:
			var sd := BldEcon.step_dirs(st)
			var tp: Vector2 = Vector2(b.x, b.y) + (sd[0] as Vector2) * (line + 1.0)
			var rp: Vector2 = tp + (sd[1] as Vector2) * 0.9
			a.trees.append({"x": tp.x, "y": tp.y, "s": "tree", "g": 0.0, "res": 0})
			a.rocks.append({"x": rp.x, "y": rp.y, "amt": 40, "res": 0})
			mine.append([Vector2(tp.x, tp.y), Vector2(rp.x, rp.y)])
		for st in [0, 1]:
			_yaw_cam(scene, vw, st)
			econ._apron_frame = -1
			vw.sync(0.1, true)
			vw.sync(0.3, true)
			var res := _plants_over(econ, st)
			check(econ.step == st and int(res[1]) >= 2 and int(res[0]) == 0,
				"방위 걸음 %d: 놓인 꽃숲 %d · 바위 %d 가운데 앞마당 %d곳 — 더미 줄을 가리는 것 없음 (%d)" % [st, econ.tree_draw.size(), econ.rock_draw.size(), res[1], res[0]])
			var te: Array = econ.tree_draw.get(mine[st][0], [])
			var th := 99.0
			if not te.is_empty():
				th = float(Flora2D.info(Flora2D.pic_for(String(te[0]))).get("h", 0.0)) * float(te[1])
			var rh := float(Flora2D.info(Flora2D.pic_for("rocks")).get("h", 0.0)) * float(econ.rock_draw.get(mine[st][1], 99.0))
			check(th <= 1.0 * BldEcon.APRON_SIN + 0.02 and rh <= 1.0 * BldEcon.APRON_SIN + 0.02, "방위 걸음 %d: 집 앞 1칸의 큰 꽃(키 %.2f) · 큰 바위(키 %.2f)는 낮게" % [st, th, rh])
	scene.queue_free()
	Flora2D.override = oldf


## (Q8) 금빛 밀 숲: 싹(발목~무릎) → 푸른 밀(허리~머리) → 익은 밀 숲(주민 키의 1.5배쯤). 그림을 줄이는 규칙은 없다 (늘 제 크기) —
## 키 큰 익은 밭이 뒤쪽 건물의 더미 줄을 가리면 더미가 옆으로 비킨다 (건물 앞에 선 다른 건물과 같은 규칙 · 두 방위).
## 밭은 눕힌 흙 + 세운 밀 줄 여섯 + 앞 울타리로 겹쳐 그리고, 가리는지 보는 판(_covers)도 줄마다 하나씩 (제 키로). 밭 자리·수확은 그대로
func test_wheat() -> void:
	var scene := _scene()
	var av := _village(scene)
	var a: Village = av[0]
	var vw: VillageView = av[1]
	var econ: BldEcon = vw.econ
	var saw := _add(a, "제재소", true)
	var farm := _add(a, "농장", true)
	check(saw != null and farm != null, "제재소 · 농장을 놓음")
	if saw == null or farm == null:
		scene.queue_free()
		return
	saw.worker = -1
	saw.in_buf["통나무"] = 0.0
	saw.out["판자"] = 2.0
	a.stock["판자"] = 0.0
	var band := BldEcon.pile_band(a, saw)
	check(band.size() == 3 and float(band[1]) < float(band[2]) and float(band[0]) > 0.0, "제재소의 더미 줄 %s" % [band])
	# 그림: 세 단계 모두 흙 한 장(눕힘) + 줄 여섯 + 울타리. 같은 밀이 자란다 — 단계마다 가장 키 큰 줄 (주민 키 = 화면 0.83칸쯤):
	# 싹은 무릎 아래 · 푸른 밀은 허리~머리 · 익은 밀 숲은 주민 키의 1.3~2배 (가운데 줄 평균 1.5배 + 삐죽 솟은 이삭)
	var man := 0.83
	var tops := [0.0, 0.0, 0.0]
	var layered := true
	for stg in 3:
		var names := Bld2D.wheat_cards(stg)
		var up := 0
		for nm: String in names:
			var rd := Bld2D.info(nm)
			layered = layered and not rd.is_empty()
			if not rd.is_empty() and int(rd.get("mode", 0)) == 0:
				up += 1
				if Bld2D.Pics.WHEAT_ROWS[stg].has(nm):       # 밀 줄만 (울타리는 빼고)
					tops[stg] = maxf(float(tops[stg]), float(rd["h"]))
		layered = layered and names.size() == 8 and up == 7
	var tall := float(tops[2])
	check(layered and float(tops[0]) > 0.1 and float(tops[0]) < man * 0.4 and float(tops[1]) > man * 0.5 and float(tops[1]) < man
		and tall > man * 1.3 and tall < man * 2.0,
		"밀밭 = 흙 + 밀 줄 여섯 + 울타리 (세 단계) · 가장 키 큰 줄: 싹 %.2f칸 · 푸른 밀 %.2f칸 · 익은 밀 숲 %.2f칸 (주민 키의 1.5배쯤)" % tops)
	check(Bld2D.wheat_cards(2, "scarecrow").size() == 9 and Bld2D.wheat_cards(2, "없는 꾸밈").size() == 8, "꾸밈 그림은 고른 때만 한 장 더")
	# 익은 숲의 윤곽: 상자가 아니라 둔덕 — 맨 앞줄과 맨 뒷줄이 가운데 줄보다 낮고 좁다 (앞에서 뒤로 층층이 · 옆은 둥글게)
	var ripe: Array = Bld2D.Pics.WHEAT_ROWS[Bld2D.ROW_RIPE]
	var mid_h := 0.0
	var mid_w := 0.0
	for i in range(1, ripe.size() - 1):
		mid_h = maxf(mid_h, float(Bld2D.info(String(ripe[i]))["h"]))
		mid_w = maxf(mid_w, float(Bld2D.info(String(ripe[i]))["w"]))
	var front_r := Bld2D.info(String(ripe[ripe.size() - 1]))
	var back_r := Bld2D.info(String(ripe[0]))
	check(float(front_r["h"]) < mid_h - 0.1 and float(front_r["w"]) < mid_w - 0.3 and float(back_r["w"]) < mid_w - 0.3 and float(back_r["h"]) <= mid_h,
		"익은 밀 숲은 둔덕: 앞줄 키 %.2f칸 · 폭 %.2f칸 / 가운데 줄 키 %.2f칸 · 폭 %.2f칸 / 뒷줄 폭 %.2f칸"
		% [float(front_r["h"]), float(front_r["w"]), mid_h, mid_w, float(back_r["w"])])
	# 벤 줄: wheat_cards의 줄 상태(2 익음 · 1 푸름 · 0 싹 · -1 그루터기)대로 그 이랑의 그림이 바뀐다 — 장수·순서는 그대로
	var cut_rows := [2, 2, 2, 2, -1, -1]
	var mixed := Bld2D.wheat_cards(2, "", cut_rows)
	var mixed_ok: bool = mixed.size() == 8 and mixed[0] == Bld2D.wheat_cards(2)[0] and mixed[7] == Bld2D.wheat_cards(2)[7]
	for i in 6:
		var want: String = String(Bld2D.Pics.WHEAT_STUBBLE[i]) if int(cut_rows[i]) < 0 else String(ripe[i])
		mixed_ok = mixed_ok and String(mixed[1 + i]) == want and Bld2D.has(want)
		mixed_ok = mixed_ok and Bld2D.row_stubble(String(ripe[i])) == String(Bld2D.Pics.WHEAT_STUBBLE[i])
		mixed_ok = mixed_ok and float(Bld2D.info(String(Bld2D.Pics.WHEAT_STUBBLE[i]))["h"]) < man * 0.3
	check(mixed_ok and Bld2D.row_stubble(String(mixed[0])) == "", "벤 줄은 그루터기 그림 (앞 두 줄을 벤 밭: 그림 여덟 장 그대로 · 그루터기는 발목 높이)")
	var mid := (float(band[1]) + float(band[2])) * 0.5
	farm.ready_at = a.t - 1.0                # 익은 밀 (가장 키 큰 그림)
	for st in [0, 1]:
		var sd := BldEcon.step_dirs(st)
		var tw: Vector2 = sd[0]
		var rt: Vector2 = sd[1]
		var o := Vector2(saw.x, saw.y) + rt * mid + tw * float(band[0])
		for ahead: float in [5.0, 2.0]:      # 더미 줄 5칸 앞 · 2칸 앞 (바로 앞) — 밭 그림은 줄이지 않고, 가려지는 더미가 옆으로 비킨다
			farm.x = o.x + tw.x * ahead
			farm.y = o.y + tw.y * ahead
			vw._bld_key.erase(farm.id)
			_yaw_cam(scene, vw, st)
			econ._apron_frame = -1
			for i in 4:
				vw.sync(0.3, true)
			var cards := 0
			var full := true
			for c: Node in (vw._blds[farm.id] as Node3D).get_children():
				if c is MeshInstance3D and c.has_meta(&"pic"):
					cards += 1
					full = full and is_equal_approx(float((c as MeshInstance3D).get_instance_shader_parameter("k")), 1.0)
			var org: Vector3 = (vw._blds[saw.id] as Node3D).position
			var piles := _pile_xy(econ, org, "planks_", 4.5)
			var hid := piles.is_empty()
			var covers := 0
			var low := true
			for c: Array in econ._covers:
				if int(c[4]) != farm.id:
					continue
				covers += 1
				low = low and float(c[3]) <= tall + 0.001
				for pl: Vector2 in piles:
					var dv := Vector2(float(c[0]), float(c[1])) - (Vector2(org.x, org.z) + econ._r2 * pl.x + econ._f2 * pl.y)
					var al := dv.dot(econ._f2)
					if al > 0.05 and al * BldEcon.APRON_SIN < float(c[3]) and absf(dv.dot(econ._r2)) < float(c[2]) + BldEcon.PILE_HALF:
						hid = true
			check(econ.step == st and cards == 8 and full and covers == 7 and low and not hid,
				"방위 걸음 %d · 더미 줄 %d칸 앞의 익은 밭: 그림 %d장 제 크기 · 가림 판 %d개(줄마다, 제 키) · 제재소 판자 더미 %d개는 안 가림" % [st, int(ahead), cards, covers, piles.size()])
	# (Q8) 제 건물보다 넓은 밀 숲이 바로 앞 한가운데에 서면 (좁은 우물 — 곁의 자리가 모두 숲 뒤): 더미가 숲 옆 끝 바로 밖으로 나온다
	var well := _add(a, "우물", true)
	check(well != null, "우물을 놓음")
	if well != null:
		well.out["물"] = BldEcon.out_full("물")
		var tw0: Vector2 = BldEcon.step_dirs(0)[0]
		var ww := float(Bld2D.info(String(BldEcon.pic_k(a, well)[0]))["w"]) * float(BldEcon.pic_k(a, well)[1])
		var reach := 0.0                # 가장 멀리 나간 더미 — 곁의 자리(NUDGE_OUT) 밖이면 숲 옆 끝 규칙(_field_side)이 쓰인 것
		_yaw_cam(scene, vw, 0)
		for gap: float in [2.6, 2.2, 1.9]:
			farm.x = well.x + tw0.x * gap
			farm.y = well.y + tw0.y * gap
			vw._bld_key.erase(farm.id)
			econ._apron_frame = -1
			for i in 4:
				vw.sync(0.3, true)
			var worg: Vector3 = (vw._blds[well.id] as Node3D).position
			var wp := _pile_xy(econ, worg, "water_", 3.6)
			var whid := wp.is_empty()
			var far := 0.0
			for pl: Vector2 in wp:
				far = maxf(far, absf(pl.x))
				for c: Array in econ._covers:
					if int(c[4]) != farm.id:
						continue
					var dv := Vector2(float(c[0]), float(c[1])) - (Vector2(worg.x, worg.z) + econ._r2 * pl.x + econ._f2 * pl.y)
					var al := dv.dot(econ._f2)
					if al > 0.05 and al * BldEcon.APRON_SIN < float(c[3]) and absf(dv.dot(econ._r2)) < float(c[2]) + BldEcon.PILE_HALF:
						whid = true
			reach = maxf(reach, far)
			check(econ.step == 0 and not whid and far <= ww * 0.5 + BldEcon.NUDGE_OUT + BldEcon.FIELD_OUT + 0.01,
				"우물 %.1f칸 앞 한가운데의 익은 밭: 물 더미 %d개가 숲 옆 끝 밖에 보임 (우물에서 옆으로 %.2f칸 — 곁 %.2f칸 · 더 나가도 %.2f칸 안)"
				% [gap, wp.size(), far, ww * 0.5 + BldEcon.NUDGE_OUT, ww * 0.5 + BldEcon.NUDGE_OUT + BldEcon.FIELD_OUT])
		print("     (Q8) 우물 물 더미가 가장 멀리 나간 자리 %.2f칸 · 곁의 자리 끝 %.2f칸" % [reach, ww * 0.5 + BldEcon.NUDGE_OUT])
	scene.queue_free()


## (v3) 앞에 다른 건물이 서서 더미 자리를 가리면: 건물은 그대로 두고 더미만 제 건물 곁의 보이는 자리로 (화면만 · 늘 같은 답)
func test_front() -> void:
	var scene := _scene()
	var av := _village(scene)
	var a: Village = av[0]
	var vw: VillageView = av[1]
	var econ: BldEcon = vw.econ
	_yaw_cam(scene, vw, 1)
	var saw := _add(a, "제재소", true)
	check(saw != null, "제재소를 놓음")
	if saw == null:
		scene.queue_free()
		return
	saw.worker = -1
	saw.in_buf["통나무"] = 0.0
	saw.out["판자"] = 2.0
	a.stock["판자"] = 0.0
	vw.sync(0.1, true)
	var org: Vector3 = (vw._blds[saw.id] as Node3D).position
	var w := float(Bld2D.info(String(BldEcon.pic_k(a, saw)[0]))["w"])
	var rad := w * 0.5 + BldEcon.NUDGE_OUT + 1.5
	var p0s := _pile_xy(econ, org, "planks_", rad)
	check(p0s.size() == 1, "제재소 앞 판자 더미 하나 %s" % [p0s])
	if p0s.size() != 1:
		scene.queue_free()
		return
	var p0: Vector2 = p0s[0]
	var at := Vector2(org.x, org.z) + econ._f2 * (p0.y + 0.3) + econ._r2 * p0.x
	var hut := a.add_building("오두막", at.x, at.y, true)      # 그 더미 바로 앞(카메라 쪽)에 오두막
	vw.sync(0.1, true)
	vw.sync(0.3, true)
	econ._cov = econ._cov_for(saw.id, org)
	var p1s := _pile_xy(econ, org, "planks_", rad)
	check(hut != null and econ._covered(p0.x, p0.y), "오두막 그림이 제자리의 더미를 가림")
	check(p1s.size() == 1, "더미는 여전히 하나 %s" % [p1s])
	if p1s.size() == 1:
		var p1: Vector2 = p1s[0]
		var in_x := float((BldEcon.LAYOUT["sawmill"]["in"] as Vector2).x)
		check(absf(p1.x - p0.x) >= 0.3 and not econ._covered(p1.x, p1.y) and absf(p1.x) <= w * 0.5 + BldEcon.NUDGE_OUT + 0.01 and p1.y > 0.0
			and absf(p1.x - in_x) >= BldEcon.NUDGE_GAP - 0.01, "더미가 보이는 자리로 비켜 남 (옆 %.2f → %.2f) — 제 건물 곁 · 재료 더미 자리와 안 겹침" % [p0.x, p1.x])
		vw.sync(0.3, true)
		var p2s := _pile_xy(econ, org, "planks_", rad)
		check(p2s.size() == 1 and (p2s[0] as Vector2).distance_to(p1) < 0.001 and (vw._blds[saw.id] as Node3D).position == org
			and is_equal_approx(hut.x, at.x) and is_equal_approx(hut.y, at.y), "다시 봐도 같은 자리 · 건물은 옮기지 않음")
	scene.queue_free()


## (v3) 채집 일터가 멈춘 까닭: 일꾼은 있는데 둘레에 벨 나무 · 캘 바위가 없다 → 그림 풍선 (다른 막힌 일터처럼 늦게 뜸)
func test_stall_gather() -> void:
	var scene := _scene()
	var av := _village(scene)
	var a: Village = av[0]
	var vw: VillageView = av[1]
	var econ: BldEcon = vw.econ
	_wide_cam(scene, vw)
	var rr := Balance.GATHER_RANGE + 1.0
	for row: Array in [["나무꾼", "bub_no_tree"], ["채석장", "bub_no_rock"]]:
		var ty := String(row[0])
		var pic := String(row[1])
		var b := _add(a, ty, true)
		check(b != null, "%s를 놓음" % ty)
		if b == null:
			continue
		var rock := ty == "채석장"
		var r: Resident = a.people[1 if rock else 0]
		var keep_job := r.job
		var near: Array = []
		for q: Dictionary in (a.rocks if rock else a.trees):
			if Vector2(float(q["x"]) - b.x, float(q["y"]) - b.y).length() <= rr and (float(q["amt"]) > 0.0 if rock else String(q["s"]) == "tree"):
				near.append(q)
		if near.is_empty():              # 둘레에 하나도 없는 자리면 하나 놓고 시작
			var nq := {"x": b.x + 6.0, "y": b.y + 6.0, "amt": 20, "res": 0} if rock else {"x": b.x + 6.0, "y": b.y + 6.0, "s": "tree", "g": 0.0, "res": 0}
			(a.rocks if rock else a.trees).append(nq)
			near.append(nq)
		b.worker = r.id
		r.job = b.id
		check(not BldEcon.gather_empty(a, b) and BldEcon.stall_pic(a, b) == "", "%s: 둘레에 있으면 풍선 없음" % ty)
		var keep_v: Array = []
		for q: Dictionary in near:       # 둘레의 것을 다 베고 캠
			keep_v.append(q["amt"] if rock else q["s"])
			if rock:
				q["amt"] = 0
			else:
				q["s"] = "stump"
		check(BldEcon.gather_empty(a, b) and BldEcon.stall_pic(a, b) == pic, "%s: 둘레에 하나도 없으면 '%s' 풍선" % [ty, pic])
		b.worker = -1
		check(BldEcon.stall_pic(a, b) == "", "%s: 일꾼이 없는 일터는 이 풍선이 아님 (빈 밀짚모자 쪽)" % ty)
		b.worker = r.id
		vw.sync(0.3, true)
		var early := _near(vw, b, pic).size()
		vw.sync(BldEcon.BUBBLE_DELAY, true)
		vw.sync(0.3, true)
		var late := _near(vw, b, pic).size()
		check(econ.bubbles.has(b.id) and String(econ.bubbles[b.id]["pic"]) == pic and early == 0 and (late == 1 or econ.bubbles.size() > BldEcon.BUBBLE_MAX),
			"%s: 풍선은 조금 뒤에 일터 위에 뜸 (%d → %d · 후보 %d)" % [ty, early, late, econ.bubbles.size()])
		if rock:
			near[0]["amt"] = keep_v[0]
		else:
			near[0]["s"] = keep_v[0]
		check(BldEcon.stall_pic(a, b) == "", "%s: 하나라도 다시 생기면 풍선 없음" % ty)
		vw.sync(0.3, true)
		check(_near(vw, b, pic).is_empty() and not econ.bubbles.has(b.id), "%s: 풍선이 사라짐" % ty)
		b.worker = -1
		r.job = keep_job
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
