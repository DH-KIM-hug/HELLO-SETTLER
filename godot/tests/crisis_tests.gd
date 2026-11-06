## 작은 위기 셋 테스트 — docs/WORLD_EVENTS.md 2.2 · 2.3 · 4.3 · 5 (sim/small_crises.gd — ROADMAP B5).
## 날벌레 (뚜껑 → 조짐 → 내려와 먹음 · 숨음 · 모깃불 · 물어서 병 · 핀셋) · 떠돌이 물방울 (식음 × 김 → 매달려 부풂 → 비킴 → 톡 → 굴러 터짐 · 연못) ·
## 먼지 뭉치 (뚜껑 열린 시간 → 굴러다님 · 밭 덮음 · 뜯어 실 · 불기) · 공통 규칙 (첫 3일 · 둘까지 · 거인이 없으면 기다림 · 아무도 죽지 않음) ·
## 저장·결정론 · 말 (금지어 · 깨닫기 전엔 거인 이야기 없음). tests/run.gd가 부름 (`-- crisis` = 이것만, 1분 안).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const H := Balance.HOUR
const D := Balance.DAY
const FORBID := ["게임", "앱", "플레이어", "휴대폰", "키트", "상자", "구매", "상점"]


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 작은 위기 셋 — 날벌레 · 떠돌이 물방울 · 먼지 뭉치 (WORLD_EVENTS 2.2 · B5)")
	run.timed(self, ["test_rules", "test_gnat_lifecycle", "test_gnat_omen_lid", "test_gnat_bites", "test_tweeze", "test_drop_lifecycle",
		"test_drop_knock", "test_drop_pressure", "test_dust_lifecycle", "test_not_watching", "test_save_and_determinism", "test_words"])


## 4일차 낮 (첫 3일 보호가 지난 뒤) — 여름이면 날벌레가 들어온다
static func village(climate := "온대", month := 7, day := 15, seed_v := 7, aware := true) -> Village:
	var keep := Village.default_created
	var keep_a := Village.start_aware
	Village.default_created = {"year": 2026, "month": month, "day": day}
	Village.start_aware = aware
	var v := Village.new_prototype(seed_v)
	Village.default_created = keep
	Village.start_aware = keep_a
	v.climate_override = climate
	v.water.offline = true
	v.advance(2.0 * H)
	v.t = Balance.MOLD_FIRST_DAY * D + 3.0 * H          # 사흘 보호가 지난 낮 (시계만 — 마을은 그대로)
	return v


static func farm_near(v: Village, p: Vector2) -> Building:
	var b := v.add_building("농장", p.x, p.y, true)
	b.ready_at = v.t - 1.0
	return b


func _lines(v: Village, from_book := 0) -> Array:
	var out: Array = []
	for i in range(from_book, v.book.size()):
		out.append(String(v.book[i]["text"]))
	for w: Dictionary in v.warnings:
		out.append(String(w["text"]))
	return out


func _said(v: Village) -> Array:
	var out: Array = []
	for r in v.people:
		if r.say != "":
			out.append(r.say)
	return out


# ───────────────────────── 공통 규칙 ─────────────────────────
func test_rules() -> void:
	var v := village()
	var early := village()
	early.t = 2.0 * D
	check(not early.smalls.gnat_in(early) and early.smalls.gnat_phase == "calm", "첫 3일은 날벌레 위기가 없다 (그냥 날아 나감)")
	check(SmallCrises.active_count(v) == 0 and not v.smalls.busy(), "처음엔 진행 중인 위기 없음")
	v.mold.force_swarm(v, "검은")
	v.smalls.force_drop(v)
	check(SmallCrises.active_count(v) == 2, "곰팡이 + 물방울 = 둘")
	check(not v.smalls.gnat_in(v), "위기가 이미 둘이면 날벌레는 들어와도 그냥 날아 나감 (동시에 둘까지)")
	# 위기가 없는 병: 난수 흐름을 쓰지 않는다 (다른 결과가 그대로)
	var q := village("온대", 4, 15)
	var st := q.smalls.rng.state
	q.advance(6.0 * H)
	check(q.smalls.rng.state == st and q.smalls.things.is_empty(), "위기가 없으면 작은 위기 난수를 하나도 쓰지 않음")


# ───────────────────────── 날벌레 ─────────────────────────
func test_gnat_lifecycle() -> void:
	var v := village()
	var s := v.smalls
	var bk := v.book.size()
	v.stock["밀"] = 200.0
	var twin := village()
	twin.stock["밀"] = 200.0
	check(s.gnat_in(v) and s.gnat_phase == "omen" and s.live("gnat").size() == 1 and s.live("gnat")[0].state == "high", "조짐: 날벌레 하나가 유리 밑을 높이 맴돎")
	check(v.warnings.any(func(w: Dictionary) -> bool: return String(w["kind"]) == "gnat") and _lines(v, bk).any(func(t: String) -> bool: return t.contains("날개 달린")), "알림 + 연대기 '날개 달린 것이 날아들었다'")
	check(v.people.any(func(r: Resident) -> bool: return r.say.contains("윙윙")), "주민: \"하늘에서 윙윙 소리가 나!\"")
	v.advance(Balance.GNAT_OMEN + 120.0)
	check(s.gnat_phase == "swarm" and v.crises.any(func(c: Dictionary) -> bool: return String(c["kind"]) == "gnat"), "한 시간 뒤 마을로 내려옴 (위기 알림 — 빨리 돌리기가 ×1로)")
	var dead0 := v.dead.size()
	# 날벌레를 창고로 (먹는 자리) — 사람들이 곁에 있다
	var g := s.live("gnat")[0]
	g.x = v.store().x + 1.0
	g.y = v.store().y + 0.8
	g.tx = g.x
	g.ty = g.y
	g.target_b = -1
	g.state = "eat"
	g.carry = ""
	v.advance(6.0 * H)
	twin.advance(6.0 * H)
	var food := v.food_total()
	var food2 := twin.food_total()
	print("  날벌레 6시간: 먹힌 양 %.1f · 식량 %.0f (날벌레 없는 병 %.0f) · 숨음 %d · 놀람 %d" % [s.stats["eaten"], food, food2, s.stats["hid"], s.gnat_startles])
	var lab := village()
	lab.stock["밀"] = 100.0
	lab.smalls._gnat_eat(lab, Balance.GNAT_EAT_FULL, {}, D)
	var ate := 1.0 - float(lab.stock["밀"]) / 100.0
	check(float(s.stats["eaten"]) > 0.2 and absf(ate - Balance.GNAT_EAT_DAY) < 0.01, "밭·창고의 식량을 먹는다 (창고에 둘이면 하루 %.1f%%)" % (ate * 100.0))
	check(int(s.stats["hid"]) > 0, "곁의 주민은 숨는다 (일이 멈춤)")
	# 두 번째부터는 곧바로 '연기 피우는 사람' — 모깃불에 쫓김
	s.gnat_episodes = 1
	s._name_smoker(v)
	var sm := v.person(s.smoker_id)
	check(sm != null and sm.is_adult(), "촌장이 '연기 피우는 사람'을 정함 (%s)" % (sm.name if sm != null else "-"))
	v.stock["통나무"] = 40.0
	var smoke0 := v.air.smoke
	var fled := false
	for i in int(8.0 * H / 60.0):
		v.advance(60.0)
		if s.live("gnat").all(func(q: CrisisThing) -> bool: return q.state == "flee" or q.state == "out"):
			fled = true
			break
	print("  모깃불 %d번 · 연기 %.3f → %.3f" % [s.stats["smokes"], smoke0, v.air.smoke])
	check(int(s.stats["smokes"]) >= 1 and fled, "모깃불 연기에 날벌레가 유리벽으로 쫓겨남")
	check(v.air.smoke > smoke0 - 0.05, "연기는 닫힌 병에 갇힌다 (병의 공기 연기 +)")
	# 쫓긴 날벌레는 뚜껑이 열리면 날아 나간다 (여름엔 열 때 또 들어올 수 있다 — 쫓기면 다시 열어 내보냄)
	for k in 6:
		v.open_lid()
		v.advance(60.0)
		v.close_lid()
		v.advance(5.0 * 60.0)
		if s.gnat_phase == "calm":
			break
		for i in 60:
			v.advance(60.0)
			if s.live("gnat").all(func(q: CrisisThing) -> bool: return q.state == "flee" or q.state == "out"):
				break
	check(s.gnat_phase == "calm" and s.gnat_episodes == 2 and int(s.stats["gnat_out"]) >= 1, "쫓긴 날벌레는 열린 하늘로 날아 나감 → 위기가 끝남")
	check(_lines(v, bk).any(func(t: String) -> bool: return t.contains("날개 괴물이 또 물러갔다")), "연대기: 물러갔다")
	check(v.dead.size() == dead0, "날벌레로 죽은 사람은 없다")
	# 첫 무리의 이름 · 1~3일 뒤 저절로 끝남 (유리에 붙은 채 떨어짐)
	var w := village("온대", 7, 15, 11)
	w.smalls.force_gnats(w)
	var n0 := w.book.size()
	w.advance(Balance.GNAT_PEAK[1] + 6.0 * H)
	check(w.smalls.gnat_phase == "calm" and w.smalls.gnat_episodes == 1, "1~3일 뒤 저절로 잦아듦")
	check(_lines(w, n0).any(func(t: String) -> bool: return t.contains("날개 괴물이 날아든 여름")), "연대기에 이름: '날개 괴물이 날아든 여름'")


func test_gnat_omen_lid() -> void:
	var v := village()
	var s := v.smalls
	s.gnat_in(v)
	v.close_lid()
	v.advance(10.0 * 60.0)
	check(s.gnat_phase == "omen", "조짐 동안 맴돎")
	v.open_lid()
	v.advance(60.0)
	check(s.gnat_phase == "calm" and int(s.stats["gnat_out"]) == 1, "조짐 때 뚜껑을 다시 열면 그 틈으로 날아 나감 (거인이 도움)")
	v.close_lid()
	v.advance(2.0 * H)
	check(s.live("gnat").is_empty() and s.gnat_episodes == 0, "내려오지 않았다 — 위기로 세지 않음")
	# 뚜껑 굴림으로 들어옴 (여름 8%)
	var q := village()
	var got := false
	for i in 200:
		q.open_lid()
		q.close_lid()
		if q.smalls.gnat_phase != "calm":
			got = true
			break
	check(got and q.air.gnat_new, "여름에 뚜껑을 여러 번 열면 날벌레가 들어온다 (JarAir 굴림 → 위기)")


func test_gnat_bites() -> void:
	var v := village("온대", 7, 15, 9)
	var s := v.smalls
	check(SmallCrises.by_water(v, Vector2(-14, -8)) or SmallCrises.by_water(v, Vector2(-12, -6)) or true, "물가 확인 함수")
	var lake := Vector2.INF
	for i in 400:
		var p := Vector2(-20 + (i % 20) * 2.0, -20 + (i / 20) * 2.0)
		if v.water.inside(p.x, p.y, 3.0) and not v.water_at(p.x, p.y) and SmallCrises.by_water(v, p):
			lake = p
			break
	var dry := Vector2.INF
	for i in 400:
		var p := Vector2(-20 + (i % 20) * 2.0, -20 + (i / 20) * 2.0)
		if v.water.inside(p.x, p.y, 3.0) and not SmallCrises.by_water(v, p):
			dry = p
			break
	check(lake != Vector2.INF and dry != Vector2.INF, "고인 물가와 마른 땅이 있다")
	# 역병을 지닌 날벌레 곁에 사람을 세워 두면 물려서 역병 (드물고 무서움 — 위기로 옴)
	s.force_gnats(v, Balance.PLAGUE)
	var g := s.live("gnat")[0]
	var r := v.people[2]
	var bites := 0
	var ill := false
	for hr in 60:
		for q: Resident in [r]:
			q.x = g.x + 0.3
			q.y = g.y
		g.state = "eat"
		s._bites(v)
		if r.disease == Balance.PLAGUE:
			ill = true
			break
	check(ill and int(s.stats["bite_ill"]) >= 1 and v.outbreaks.has(Balance.PLAGUE), "역병을 지닌 날벌레가 곁의 사람을 물면 역병 ('%s')" % str(v.outbreaks.get(Balance.PLAGUE, {}).get("name", "")))
	# 앓는 사람을 물면 그 병을 지님 (열병 — 물가에서 번짐)
	var w := village("온대", 7, 15, 12)
	w.smalls.force_gnats(w, "")
	var gg := w.smalls.live("gnat")[0]
	var pt := w.people[1]
	Health.fall_ill(w, pt, false, "열병")
	var picked := false
	for hr in 80:
		pt.x = gg.x + 0.2
		pt.y = gg.y
		gg.state = "eat"
		w.smalls._bites(w)
		if gg.carry == "열병":
			picked = true
			break
	check(picked, "열병 앓는 사람을 문 날벌레는 열병을 지닌다")
	# 고인 물가에서 더 문다 (같은 난수로 비교)
	var n_wet := 0
	var n_dry := 0
	for side in [0, 1]:
		var u := village("온대", 7, 15, 13)
		u.smalls.force_gnats(u, "")
		var b := u.smalls.live("gnat")[0]
		var at: Vector2 = lake if side == 0 else dry
		var who := u.people[3]
		for hr in 400:
			b.x = at.x
			b.y = at.y
			b.state = "eat"
			who.x = at.x + 0.2
			who.y = at.y
			who.sick_left = 0.0
			u.smalls._bites(u)
		if side == 0:
			n_wet = int(u.smalls.stats["bites"])
		else:
			n_dry = int(u.smalls.stats["bites"])
	print("  400시간 무는 수: 물가 %d · 마른 땅 %d" % [n_wet, n_dry])
	check(n_wet > n_dry * 1.4, "고인 물가에서 더 문다 (물가 %d > 마른 땅 %d)" % [n_wet, n_dry])
	# 지니는 병: 역병 20% · 열병은 열병이 사는 병에서만
	var n := 400
	var cnt := {"역병": 0, "열병": 0}
	var cnt_t := {"역병": 0, "열병": 0}
	for i in n:
		for k in [0, 1]:
			var vv: Village = v if k == 0 else w
			var c := CrisisThing.new()
			if k == 1:
				vv.climate_override = "열대"
			vv.smalls._roll_carry(vv, c)
			vv.climate_override = "온대"
			var tgt: Dictionary = cnt if k == 0 else cnt_t
			if c.carry != "":
				tgt[c.carry] = int(tgt[c.carry]) + 1
	print("  지닌 병 (온대 %s · 열대 %s / %d)" % [str(cnt), str(cnt_t), n])
	check(absf(cnt["역병"] / float(n) - 0.2) < 0.06 and cnt["열병"] == 0 and cnt_t["열병"] > n * 0.15, "날벌레가 지닌 병: 역병 ≈20%, 열병은 열대 병에서만")


func test_tweeze() -> void:
	var v := village()
	var s := v.smalls
	s.force_gnats(v)
	var g := s.live("gnat")[0]
	var r0 := v.tweeze(g.pos())
	check(not bool(r0["ok"]) and String(r0["why"]).contains("뚜껑"), "핀셋은 뚜껑을 연 채로만 (병의 법칙)")
	v.open_lid()
	var b0 := v.buildings.size()
	var belief0 := v.people[0].belief
	var r1 := v.tweeze(g.pos() + Vector2(0.3, 0.0))
	check(bool(r1["picked"]) and String(r1["crushed"]) == "" and v.buildings.size() == b0, "가까이 집으면 깔끔히 집어냄 (부서진 것 없음)")
	check(v.people[0].belief > belief0 and v.book.back()["text"].contains("거인님"), "깨달은 마을: 믿음↑ · '거인님의 커다란 집게'")
	v.advance(60.0)
	# 서툰 핀셋: 날벌레가 집 곁 — 멀리 집으면 지붕을 짓누름
	var w := village()
	w.smalls.force_gnats(w)
	var house: Building = null
	for b in w.buildings:
		if b.is_house() and b.built:
			house = b
			break
	if house == null:
		house = w.add_building("오두막", 6.0, -6.0, true)
	var gg := w.smalls.live("gnat")[0]
	gg.x = house.x + 2.2
	gg.y = house.y
	w.open_lid()
	var r2 := w.tweeze(Vector2(house.x + 0.2, house.y))
	check(bool(r2["picked"]) and String(r2["crushed"]) != "" and not house in w.buildings, "멀리 집으면 서툴러 곁의 %s%s 부서짐" % [str(r2["crushed"]), Village.josa(str(r2["crushed"]), "이", "가")])
	check(w.dead.is_empty() and w.check_invariants().is_empty(), "다친 사람은 없다 · 마을 규칙 그대로")
	# 깨닫기 전: 경이가 쌓인다 (거인 이야기 없음)
	var u := village("온대", 7, 15, 7, false)
	check(not u.aware, "깨닫기 전 마을")
	u.smalls.force_gnats(u)
	u.open_lid()
	var w0 := u.wonder
	var bk := u.book.size()
	u.tweeze(u.smalls.live("gnat")[0].pos())
	check(u.wonder > w0 and not _lines(u, bk).any(func(t: String) -> bool: return t.contains("거인")), "깨닫기 전: 핀셋은 경이 (%.1f → %.1f), 거인 이야기 없음" % [w0, u.wonder])


# ───────────────────────── 떠돌이 물방울 ─────────────────────────
func test_drop_lifecycle() -> void:
	var v := village("온대", 4, 15, 21)
	var s := v.smalls
	var bk := v.book.size()
	s.force_drop(v)
	check(s.drop_phase == "hang" and s.drop_size < 0.3 and _lines(v, bk).any(func(t: String) -> bool: return t.contains("물덩이가 맺혔다")), "조짐: 하늘에 물덩이가 맺힘 (연대기)")
	check(v.warnings.any(func(w: Dictionary) -> bool: return String(w["kind"]) == "drop_omen"), "알림: 물방울이 매달려 부풀어요")
	var p0 := Vector2(s.drop_x, s.drop_y)
	# 그 아래에 사람·밭
	var fb := farm_near(v, p0 + Vector2(0.8, 0.0))
	fb.timer = 100.0
	var who := v.people[3]
	ResidentAI.cancel(v, who)
	who.x = p0.x + 0.5
	who.y = p0.y
	v.advance(0.6 * D)
	var drift := Vector2(s.drop_x, s.drop_y).distance_to(p0)
	print("  반나절: 크기 %.2f · 떠돈 거리 %.2f칸 · 비킴 %s" % [s.drop_size, drift, s.drop_evac])
	check(s.drop_size > 0.55 and s.drop_size < 1.0 and drift > 0.5, "하루 동안 부풀며 유리를 따라 떠돎")
	check(s.drop_evac and not s.in_drop_zone(Vector2(who.x, who.y)), "반쯤 부풀면 그 아래 사람들이 비켜남 (%s: %s)" % [who.name, who.doing])
	v.advance(0.5 * D)
	check(s.drop_phase == "roll" or s.drop_phase == "calm", "하루 뒤 떨어짐")
	v.advance(Balance.DROP_ROLL + 300.0)
	print("  물바다: 더한 물 %.3f · 쓸린 밭 %d · 잠긴 집 %d · 물자국 %d · 다침 %d" % [s.stats["water"], s.stats["fields"], s.stats["flooded"], s.drop_trail.size(), s.stats["hurt"]])
	check(s.drop_phase == "calm" and s.drop_episodes == 1 and not s.drop_splash.is_empty() and float(s.stats["water"]) > 0.0, "구르다 터져 물바다 → 끝남")
	var total0 := v.water.total(v.water.w)
	var added := s._pour(v, Vector2(s.drop_splash["x"], s.drop_splash["y"]), 3.0, 0.05)
	var total1 := v.water.total(v.water.w)
	check(added > 0.0 and absf(total1 - total0) < total0 * 1e-4, "물은 병의 물에서 덜어 온 것 (닫힌 순환 — 합 %.3f → %.3f, 부은 물 %.3f)" % [total0, total1, added])
	check(s.drop_trail.size() >= 3, "구른 자리에 물자국")
	check(_lines(v, bk).any(func(t: String) -> bool: return t.contains("하늘 물덩이가 떨어진 날")), "연대기 이름: '하늘 물덩이가 떨어진 날'")
	check(not v.dead.any(func(r: Resident) -> bool: return r.death_t >= Balance.MOLD_FIRST_DAY * D and r.death_why == "부상"), "물바다로 죽은 사람은 없다 (다칠 뿐)")


func test_drop_knock() -> void:
	var v := village("온대", 4, 15, 22)
	var s := v.smalls
	var fp := Vector2(8.0, 6.0)
	for i in 60:
		var q := Vector2(cos(i * 0.9), sin(i * 0.9)) * (5.0 + i % 8)
		if v.water.inside(q.x, q.y, 4.0) and not SmallCrises.by_water(v, q) and v.buildings.all(func(b: Building) -> bool: return Vector2(b.x, b.y).distance_to(q) > 3.0):
			fp = q
			break
	var fb := farm_near(v, fp)
	fb.timer = 200.0
	fb.out = {"밀": 3.0}
	s.force_drop(v)
	v.advance(2.0 * H)
	check(s.drop_phase == "hang", "매달려 있음")
	var at := Vector2(fb.x, fb.y)
	s.drop_x = at.x + 2.0
	s.drop_y = at.y
	v.tap_glass(false, at)
	check(s.drop_phase == "roll" and Vector2(s.drop_x, s.drop_y).distance_to(at) < 0.1 and int(s.stats["knocked"]) == 1, "유리를 톡 치면 미리 떨어짐 — 누른 곳으로")
	v.advance(Balance.DROP_ROLL + 300.0)
	check(s.drop_phase == "calm" and int(s.stats["fields"]) >= 1 and fb.out.is_empty(), "밭에 떨어지면 밭이 쓸려 감 (다시 심음)")
	# 빈 땅으로 보내면 새 연못 · 믿음↑
	var w := village("온대", 4, 15, 23)
	w.smalls.force_drop(w)
	var empty := Vector2.INF
	for i in 200:
		var a := i * 0.7
		var q := Vector2(cos(a), sin(a)) * (6.0 + (i % 9))
		if not w.water.inside(q.x, q.y, 4.0) or w.water_at(q.x, q.y):
			continue
		var clear := w.buildings.all(func(b: Building) -> bool: return Vector2(b.x, b.y).distance_to(q) > 7.0)
		if clear:
			empty = q
			break
	check(empty != Vector2.INF, "빈 땅이 있다")
	w.smalls.drop_x = empty.x
	w.smalls.drop_y = empty.y
	var bel := w.people[0].belief
	var bk := w.book.size()
	w.tap_glass(false, empty)
	w.advance(Balance.DROP_ROLL + 300.0)
	var ln := _lines(w, bk)
	check(ln.any(func(t: String) -> bool: return t.contains("작은 연못")) and w.people[0].belief > bel, "빈 들에 떨어뜨리면 새 연못 · '거인님이 빈 들로' 믿음↑")
	# 너무 먼 곳을 누르면 고를 수 있는 만큼만
	var u := village("온대", 4, 15, 24)
	u.smalls.force_drop(u)
	var d0 := Vector2(u.smalls.drop_x, u.smalls.drop_y)
	u.smalls.knock(u, d0 + Vector2(40.0, 0.0))
	check(Vector2(u.smalls.drop_x, u.smalls.drop_y).distance_to(d0) <= Balance.DROP_KNOCK_REACH + 0.01, "떨어질 자리는 매달린 곳에서 가까운 만큼만 고를 수 있다")


func test_drop_pressure() -> void:
	var res := {}
	for cl: String in ["열대", "온대", "사막"]:
		var v := village(cl, 4, 15, 31)
		v.smalls.drop_rest = 1.0e12            # 압력만 잰다 (맺히지 않게)
		v.advance(2.0 * D)
		res[cl] = v.smalls.drop_p
	print("  이틀 압력: 열대 %.2f · 온대 %.2f · 사막 %.2f" % [res["열대"], res["온대"], res["사막"]])
	check(res["열대"] > res["온대"] and res["온대"] >= res["사막"] and res["사막"] < 0.05, "습하고 식는 병일수록 물방울이 잘 맺힌다 (사막은 거의 없음)")
	# 압력이 차면 조짐 (거인이 볼 때)
	var t := village("열대", 4, 15, 32)
	var at := -1.0
	for i in 40:
		t.advance(3.0 * H)
		if t.smalls.drop_phase != "calm":
			at = t.t / D
			break
	print("  열대 병: 물방울 조짐 %.1f일" % at)
	check(at > 0.0, "습한 병은 며칠 안에 물방울이 맺힌다")


# ───────────────────────── 먼지 뭉치 ─────────────────────────
func test_dust_lifecycle() -> void:
	var v := village("온대", 4, 15, 41)
	var s := v.smalls
	s.drop_rest = 1.0e12
	var bk := v.book.size()
	for i in 8:
		v.open_lid()
		v.advance(60.0)
		v.close_lid()
		v.advance(60.0)
	print("  뚜껑 8분 열림 → 먼지 압력 %.2f · %s" % [s.dust_p, s.dust_phase])
	check(s.dust_phase == "omen" and _lines(v, bk).any(func(t: String) -> bool: return t.contains("잿빛 가루")), "뚜껑을 오래 열면 → 조짐: 잿빛 가루가 반짝이며 내려옴")
	v.advance(Balance.DUST_OMEN + 120.0)
	var ds := s.live("dust")
	check(s.dust_phase == "roll" and ds.size() >= 1 and ds.size() <= 3, "회색 구름 덩어리 %d개가 굴러다님" % ds.size())
	# 밭을 덮으면 자람이 멈춤
	var c := ds[0]
	var fb := farm_near(v, c.pos() + Vector2(0.5, 0.0))
	v.advance(60.0)
	check(SmallCrises.farm_mult(v, fb) == 0.0, "밭을 덮은 먼지 뭉치 → 그 밭 자람이 멈춤")
	# 뜯어 실을 잣는다 (아이가 만지거나 반나절 뒤 노인이 옛말을 떠올림)
	var yarn0 := float(v.stock.get("양털", 0.0))
	v.advance(Balance.DUST_LEARN + 6.0 * H)
	print("  뜯기 %d번 · 양털 %.0f → %.0f · 남은 덩어리 %d" % [s.stats["pulled"], yarn0, float(v.stock.get("양털", 0.0)), s.live("dust").size()])
	check(s.dust_known and int(s.stats["pulled"]) >= 1 and float(v.stock.get("양털", 0.0)) > yarn0, "주민이 뜯어 실을 잣는다 → 양털 (작은 세계의 자원)")
	# 거인이 불면 흩어져 날아감
	if s.live("dust").is_empty():
		s.force_dust(v)
	var n0 := s.live("dust").size()
	v.open_lid()
	v.blow_seeds(Vector2(1, 0))
	v.blow_seeds(Vector2(1, 0))
	v.blow_seeds(Vector2(1, 0))
	v.advance(60.0)
	v.close_lid()
	check(int(s.stats["blown"]) >= 1 and s.live("dust").size() < n0, "거인이 불면 흩어져 열린 하늘로 날아감 (%d → %d)" % [n0, s.live("dust").size()])
	v.advance(Balance.DUST_LIFE)
	check(s.dust_phase == "calm" and s.dust_episodes >= 1, "모두 사라지면 끝 (그대로 두어도 사흘 뒤 땅에 내려앉음)")


# ───────────────────────── 거인이 없을 때 ─────────────────────────
func test_not_watching() -> void:
	var v := village("온대", 4, 15, 51)
	v.watching = false
	v.smalls.force_drop(v)
	v.advance(1.6 * D)
	check(v.smalls.drop_phase == "hang" and v.smalls.drop_size >= 0.99, "거인이 없으면 다 부푼 물방울이 매달린 채 기다린다")
	var c := CatchUp.new(v, 0.0)
	check(v.smalls.waiting_lines().size() >= 1, "귀환 편지: '하늘에 커다란 물방울이 매달려 있어요.'")
	v.watching = true
	v.advance(2.0 * H)
	check(v.smalls.drop_phase != "hang", "거인이 돌아와 보면 떨어진다")
	var g := village("온대", 7, 15, 52)
	g.smalls.gnat_in(g)
	g.watching = false
	g.advance(4.0 * H)
	check(g.smalls.gnat_phase == "omen", "날벌레도 거인이 없으면 높이 맴돌며 기다림")
	c = null


# ───────────────────────── 저장 · 결정론 ─────────────────────────
func _sig(v: Village) -> String:
	var s := v.smalls
	var out := "%s|%s|%s|%d|%.5f,%.5f,%.4f|%.5f|" % [s.gnat_phase, s.drop_phase, s.dust_phase, s.rng.state, s.drop_x, s.drop_y, s.drop_size, s.dust_p]
	for c in s.things:
		out += "%d:%s:%s:%.4f,%.4f,%.3f;" % [c.id, c.kind, c.state, c.x, c.y, c.size]
	return out + "|%d|%.3f" % [v.rng.state, v.food_total()]


func test_save_and_determinism() -> void:
	var v := village("온대", 7, 15, 61)
	v.smalls.force_gnats(v)
	v.smalls.force_drop(v)
	v.advance(3.0 * H)
	v.smalls.force_dust(v)
	v.advance(1.0 * H)
	var d := v.to_dict()
	check(SaveCodec.errors == 0, "저장할 수 없는 값 없음")
	var w := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(_sig(w) == _sig(v), "저장 → 불러오기: 위기 셋이 그대로")
	v.advance(6.0 * H)
	w.advance(6.0 * H)
	check(_sig(w) == _sig(v), "불러온 뒤 6시간: 같은 결과 (난수 흐름까지)")
	# 옛 저장 (작은 위기·잠복이 없던 때)
	var od := v.to_dict()
	od.erase("smalls")
	for rd: Dictionary in od["people"]:
		rd.erase("latent")
		rd.erase("latent_until")
	var o := Village.from_dict(bytes_to_var(var_to_bytes(od)))
	o.advance(2.0 * H)
	check(o.smalls != null and o.smalls.things.is_empty() and o.people.all(func(r: Resident) -> bool: return r.latent == ""), "옛 저장도 읽힌다 (위기 없이 이어짐)")
	# ×1 과 ×8 (JarClock은 배속과 상관없이 같은 걸음)
	var sigs := []
	for sp in [0, 3]:
		var q := village("온대", 7, 15, 62)
		q.smalls.force_gnats(q)
		q.smalls.force_drop(q)
		q.smalls.force_dust(q)
		var ck := JarClock.new(q)
		ck.set_speed(sp)
		var dt := 1.0 / 30.0 if sp == 0 else 0.25
		while ck.steps_done < int(1.5 * H):
			ck.tick(dt)
		sigs.append(_sig(q))
	check(sigs[0] == sigs[1], "위기가 있는 병: ×1과 ×8 결과가 같다")


# ───────────────────────── 말 ─────────────────────────
func _bad(texts: Array, no_giant: bool) -> String:
	for tx: String in texts:
		for w: String in FORBID:
			if tx.contains(w):
				return "'%s' in %s" % [w, tx]
		if no_giant and tx.contains("거인"):
			return "'거인' (깨닫기 전) in %s" % tx
	return ""


func test_words() -> void:
	for aware in [true, false]:
		var v := village("온대", 7, 15, 71, aware)
		var s := v.smalls
		var said: Array = []
		s.force_gnats(v)
		s.gnat_episodes = 1
		s._name_smoker(v)
		v.stock["통나무"] = 30.0
		var fb := farm_near(v, Vector2(6.0, 5.0))
		s.force_drop(v)
		for i in 30:
			v.advance(60.0)
			said.append_array(_said(v))
		v.open_lid()
		v.tweeze(s.live("gnat")[0].pos() if not s.live("gnat").is_empty() else Vector2.ZERO)
		v.tap_glass(false, Vector2(fb.x, fb.y))
		s.force_dust(v)
		v.blow_seeds(Vector2(0, 1))
		v.close_lid()
		for i in 60:
			v.advance(5.0 * 60.0)
			said.append_array(_said(v))
		said.append_array(s.waiting_lines())
		var all_t := _lines(v) + said
		var bad := _bad(all_t, not v.aware)
		check(bad == "", "%s: 위기의 말·연대기·알림에 금지어 없음%s (%d줄) %s" % ["깨달은 마을" if aware else "깨닫기 전", "" if aware else " · 거인 이야기 없음", all_t.size(), bad])
