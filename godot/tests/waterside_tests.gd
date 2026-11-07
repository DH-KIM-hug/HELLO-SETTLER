## E3-6 물가 세트 연결 + E3-3 열매 줍기 (GAME_DESIGN 3.0) — tests/run.gd가 부름 (`-- waterside`).
## 징검돌·다리 위 높이 (돌에서 돌로 폴짝) · 둘이 메는 물고기 짝짓기 · 장대 두 쪽이 가운데서 만남 · 혼자면 끌기 ·
## 나루터 배 (개척 = 갈대 뗏목, 그 뒤 = 잎 배) · 거대한 열매를 여럿이 잘라 나름 (먹을거리 · 연대기 첫 줄) · 하늘 낟알 연출이 짧고 가벼움.
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
	print("== E3-6 물가 세트 · E3-3 열매 줍기")
	run.timed(self, ["test_crossing_height", "test_river_width", "test_fish_pairs", "test_fish_props", "test_raft_models",
		"test_fruit_fetch", "test_fruit_reach", "test_manna_light"])


func test_crossing_height() -> void:
	var vv := VillageView.new(null, null)
	vv.crossings = [{"kind": "stones", "c": Vector2(10, 5), "u": Vector2(1, 0), "half": 1.8, "y": 0.5, "step": 0.6},
		{"kind": "bridge", "c": Vector2(30, 5), "u": Vector2(0, 1), "half": 1.95, "y": 0.2}]
	var on_stone := vv.crossing_y(10.0 - 1.8 + 0.6 * 2.0, 5.0)
	var between := vv.crossing_y(10.0 - 1.8 + 0.6 * 2.5, 5.0)
	var off := vv.crossing_y(10.0, 7.0)
	var mid := vv.crossing_y(30.0, 5.0)
	var end := vv.crossing_y(30.0, 5.0 + 1.9)
	check(absf(on_stone - 0.5) < 0.01 and absf(between - (0.5 + VillageView.HOP_H)) < 0.01 and off == -INF,
		"징검돌: 돌 위 %.2f · 돌 사이 폴짝 %.2f · 곁은 아님" % [on_stone, between])
	check(mid > end and end > 0.2, "갈대 다리: 가운데가 높은 둥근 다리 위 (%.2f > %.2f)" % [mid, end])
	vv.free()


func test_river_width() -> void:
	var jw := JarWorld.create_with_kit(11, WorldCfg.SMALL_SIZE, Kits.make([]))
	var w := jw.water
	var c := jw.primary().center
	var dry := VillageView.river_width(w, c, Vector2(1, 0)) if w.depth(w.idx(c.x, c.y)) <= Balance.WADE_DEPTH else -1
	var best := 0
	for k in w.village_cells(c, 60.0):
		if w.is_river(k):
			best = maxi(best, VillageView.river_width(w, Vector2(w.cx(k), w.cy(k)), Vector2(1, 0)))
			best = maxi(best, VillageView.river_width(w, Vector2(w.cx(k), w.cy(k)), Vector2(0, 1)))
	check(dry == 1 or dry == -1, "강 폭: 마른 칸 = 1 (%d)" % dry)
	check(best == 0 or (best >= 1 and best <= 15), "강 폭을 셈 (가장 넓은 곳 %d칸 — 좁으면 징검돌, 넓으면 갈대 다리)" % best)


static func _res(id: int, x: float, y: float, facing: float, carry := "생선", age := 10.0) -> Resident:
	var r := Resident.new()
	r.id = id
	r.age = age
	r.x = x
	r.y = y
	r.facing = facing
	r.carry = carry
	r.anim = "carry" if carry != "" else "walk"
	return r


func test_fish_pairs() -> void:
	# 같은 쪽(+z)으로 걷는 둘 → 앞(더 나아간 쪽)·뒤 · 반대로 걷는 사람 · 아이 · 생선이 아닌 짐은 짝이 없음
	var a := _res(1, 0.0, 0.0, 0.0)
	var b := _res(2, 0.3, 1.2, 0.1)
	var c := _res(3, 1.0, 0.5, PI)
	var kid := _res(4, -0.5, 0.4, 0.0, "생선", 3.0)
	var bread := _res(5, 0.2, -0.8, 0.0, "빵")
	var p := VillageView.fish_pairs([a, b, c, kid, bread])
	check(p.size() == 2 and p.get(2, [""])[0] == "앞" and p.get(1, [""])[0] == "뒤" and int(p[1][1]) == 2,
		"둘이 메기: 같은 길을 가는 어른 둘 = 앞(2)·뒤(1), 반대로 가는 사람·아이·빵 든 사람은 혼자 %s" % p)
	var far := _res(6, 0.0, 9.0, 0.0)
	check(VillageView.fish_pairs([a, far]).is_empty(), "멀리 떨어진 둘은 각자 끌고 감")
	var e := _res(7, 0.2, 0.9, 0.0)
	var f := _res(8, 0.4, 2.1, 0.0)
	check(VillageView.fish_pairs([a, e, f]).size() == 2, "셋이면 둘은 메고 하나는 끎")


func test_fish_props() -> void:
	var drag := ResidentModel.carry_spec("생선")
	var front := ResidentModel.carry_spec("생선:앞")
	var back := ResidentModel.carry_spec("생선:뒤")
	var kid := ResidentModel.carry_spec("생선", true)
	check(drag[0] == "medaka" and drag[1] == "front" and front[0] == "fish_pole" and back[0] == "pole_half" and front[1] == "pole"
		and kid[0] == "medaka" and ResidentModel.carry_spec("과일")[0] == "fruit_piece",
		"송사리: 혼자 = 두 팔로 안기 · 둘 = 장대 (앞 송사리·뒤 장대 반쪽) · 아이도 안기 · 과일 = 열매 조각")
	var r := Resident.new()
	r.id = 1
	r.age = 10.0
	r.sex = "m"
	var m := ResidentModel.new()
	m.setup_from(r)
	m.set_item("생선")
	check(m.item.get_parent() == m.chest and m._carry_style == "front", "혼자: 송사리를 가슴 앞에 안음")
	m.set_item("생선:뒤")
	var bb := m.item.transform * (m._carry_close.mesh as Mesh).get_aabb()
	var s: Vector3 = ResidentModel.CARRY_SOCKET["pole"]
	var meet := -ResidentModel.POLE_GAP + bb.end.z                # 앞 사람 자리 기준, 뒤 사람 장대 끝
	check(absf(meet - (s.z - ResidentModel.POLE_GAP * 0.5)) < 0.2 and absf(bb.end.y - s.y) < 0.12,
		"장대 두 쪽이 둘 사이 가운데서 만남 (뒤 장대 끝 %.2f · 가운데 %.2f)" % [meet, s.z - ResidentModel.POLE_GAP * 0.5])
	m.set_item("생선:앞")
	var fb := m.item.transform * (m._carry_close.mesh as Mesh).get_aabb()
	check(fb.end.z < s.z + 0.25 and fb.position.z < s.z - ResidentModel.POLE_GAP * 0.5, "앞 사람: 장대가 뒤로 뻗고 물고기는 가운데 아래 (z %.2f~%.2f)" % [fb.position.z, fb.end.z])
	m.free()


func test_raft_models() -> void:
	check(VillageView.raft_model(0) == "raft_reed" and VillageView.raft_model(1) == "boat_leaf" and VillageView.raft_model(3) == "boat_leaf",
		"나루터 배: 개척 시대 = 갈대 뗏목 · 그 뒤 = 잎 배")
	check(Art.exists("raft_reed") and Art.exists("boat_leaf") and Art.exists("ferry_raft") and Art.exists("bridge_stones"),
		"모델: 갈대 뗏목 · 잎 배 · 뗏목 맨 나루터 · 징검돌")


## 열매 하나를 마을 곁(닿는 곳)에 떨어뜨리고 낮에 → 여럿이 가서 자르고 조각을 지고 와 창고에 (먹을거리 합 = FRUIT_FOOD)
func _fruit_world(dist: float) -> Array:
	var jw := JarWorld.create_with_kit(5, WorldCfg.SMALL_SIZE, Kits.make([]))
	var v := jw.primary()
	var ww := jw.water as WorldWater
	ww.giant_fruits.clear()
	var p := v.center
	for k in 48:
		var q := v.center + Vector2(cos(k * 0.4), sin(k * 0.4)) * dist
		if ww.inside(q.x, q.y, 2.0) and ww.depth(ww.idx(q.x, q.y)) <= 0.004:
			p = q
			break
	var f := {"x": p.x, "y": p.y, "t": v.t, "yaw": 0.0, "food": Balance.FRUIT_FOOD, "left": Balance.FRUIT_FOOD}
	f["id"] = GreatTrees.fruit_id(f)
	ww.giant_fruits.append(f)
	v.start_clock = fposmod(9.0 * Balance.HOUR - v.t, Balance.DAY)
	return [jw, v, ww, f]


func test_fruit_fetch() -> void:
	var a := _fruit_world(12.0)
	var jw: JarWorld = a[0]
	var v: Village = a[1]
	var ww: WorldWater = a[2]
	var f: Dictionary = a[3]
	var n := GreatTrees.fetch(v)
	check(n >= Balance.FRUIT_TEAM_MIN and n <= Balance.FRUIT_TEAM and float(f.get("claim_until", 0.0)) > v.t,
		"닿는 곳의 열매: 낮에 한가한 어른 %d명이 함께 감 (맡음 표시)" % n)
	check(GreatTrees.fetch(v) == 0, "맡은 열매엔 또 가지 않음")
	var cut := false
	for i in 8 * 60:
		jw.advance(60.0)
		cut = cut or bool(f.get("cut", false))
		if float(v.stats.get("fruit_food", 0.0)) >= Balance.FRUIT_FOOD * float(n) / Balance.FRUIT_TEAM - 1.0:
			break
	var got := float(v.stats.get("fruit_food", 0.0))
	var want := Balance.FRUIT_FOOD * float(n) / Balance.FRUIT_TEAM
	check(cut and absf(got - want) < 1.0, "잘린 열매 → 조각 %d개를 지고 와 창고에 과일 %.0f (열매 하나 %.0f = 넷이 사흘)" % [n, got, Balance.FRUIT_FOOD])
	check(n < Balance.FRUIT_TEAM or ww.giant_fruits.is_empty(), "다 나르면 열매가 사라짐")
	var line := ""
	for e: Dictionary in v.book:
		if String(e["text"]).contains("열매"):
			line = e["text"]
	var bad := false
	for w: String in ["거인", "하늘의 분", "게임", "상자"]:
		bad = bad or line.contains(w)
	check(line != "" and not bad and v.stats.has("fruit_first"), "연대기 첫 줄 (거인 이야기 없음): %s" % line)
	check(Balance.FRUIT_FOOD >= 3.0 * Balance.DAY / Balance.FOOD_IV * 3.0 and "과일" in Balance.FOODS and Balance.SPOIL_DAY.has("과일"),
		"열매 하나 = 여럿이 며칠 먹는 양 (%.0f) · 먹을거리 · 상함" % Balance.FRUIT_FOOD)


func test_fruit_reach() -> void:
	var a := _fruit_world(12.0)
	var v: Village = a[1]
	var f: Dictionary = a[3]
	v.start_clock = fposmod(22.0 * Balance.HOUR - v.t, Balance.DAY)
	check(GreatTrees.fetch(v) == 0, "밤엔 가지 않음")
	v.start_clock = fposmod(9.0 * Balance.HOUR - v.t, Balance.DAY)
	f["x"] = v.center.x + v.territory_r() + Balance.FRUIT_REACH + 5.0
	f["y"] = v.center.y
	check(GreatTrees.reachable_fruit(v).is_empty() and GreatTrees.fetch(v) == 0, "영역 + %.0f칸 밖의 열매엔 가지 않음" % Balance.FRUIT_REACH)


func test_manna_light() -> void:
	var src := FileAccess.get_file_as_string("res://view/manna_fx.gd")
	check(not src.contains("SkyBeam") and MannaFx.DUR <= 2.5 and MannaFx.PER_PILE <= 6 and MannaFx.FROM_H <= 6.0 and MannaFx.LAND_GLOW <= 1.6,
		"하늘 낟알: 빛기둥 없음 · 짧게 (%.1f초) · 무더기마다 낟알 %d알이 반짝이며" % [MannaFx.DUR, MannaFx.PER_PILE])
