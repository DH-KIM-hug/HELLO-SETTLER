## 병의 공기·뚜껑·곰팡이 무리 테스트 — docs/WORLD_EVENTS.md 2.1 · 2.3 · 3, HEALTH.md 2.5b (sim/jar_air.gd · sim/mold.gd).
## tests/run.gd가 부름 (`-- mold` = 이것만, 1분 안).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = ["test_pressure"]           # 오래 걸리는 통계 시험 — run.gd의 long·전체 모드에서만 (quick은 건너뜀)
const H := Balance.HOUR
const D := Balance.DAY


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 병의 공기·뚜껑·곰팡이 무리 (WORLD_EVENTS 2.1 · 3)")
	run.timed(self, ["test_air_values", "test_lid", "test_lid_auto_close", "test_gnats", "test_pressure", "test_swarm_first_time", "test_chaser_and_adapt", "test_weaknesses", "test_illness", "test_koji", "test_blue_medicine", "test_determinism"])


static func village(climate := "온대", month := 4, day := 15, seed_v := 5) -> Village:
	var keep := Village.default_created
	Village.default_created = {"year": 2026, "month": month, "day": day}
	var v := Village.new_prototype(seed_v)
	Village.default_created = keep
	v.climate_override = climate
	return v


## 무리가 창고에 모여 있는 열대 병 (첫 걸음 뒤)
static func swarm_village(seed_v := 5) -> Village:
	var v := village("열대", 4, 15, seed_v)
	v.water.offline = true
	v.advance(2.0 * H)                 # 09:00 — 낮
	v.mold.force_swarm(v, "검은")
	return v


func _blob_sig(v: Village) -> String:
	var s := "%s|%d|%.6f|" % [v.mold.phase, v.mold.rng.state, v.air.humid]
	for b in v.mold.blobs:
		s += "%d:%s:%.4f,%.4f,%.4f;" % [b.id, b.state, b.x, b.y, b.size]
	return s


# ───────────────────────── 공기 ─────────────────────────
func test_air_values() -> void:
	var t := village("온대")
	var w := village("열대")
	var dsr := village("사막")
	for v in [t, w, dsr]:
		v.water.offline = true
		v.advance(D)
	var ok := true
	for v in [t, w, dsr]:
		for x in [v.air.humid, v.air.smoke, v.air.stale]:
			ok = ok and x >= 0.0 and x <= 1.0
	check(ok, "김·연기·탁한 공기는 0~1")
	check(w.air.humid > t.air.humid + 0.2 and t.air.humid > dsr.air.humid + 0.15, "김: 열대 %.2f > 온대 %.2f > 사막 %.2f" % [w.air.humid, t.air.humid, dsr.air.humid])
	check(t.air.glass_fog() == 0.0 and w.air.glass_fog() > 0.2, "열대 병은 유리가 김으로 뿌옇다 (온대 %.2f · 열대 %.2f)" % [t.air.glass_fog(), w.air.glass_fog()])


# ───────────────────────── 뚜껑 ─────────────────────────
func test_lid() -> void:
	# 겨울: 열면 방의 찬 기운이 들어와 잠깐 추움, 닫으면 돌아옴
	var v := village("온대", 1, 20)
	var twin := village("온대", 1, 20)
	for q in [v, twin]:
		q.water.offline = true
		q.advance(5.0 * H)              # 12:00
	var p := Vector2(0, 0)
	var t0 := v.temperature_at(p.x, p.y)
	var h0 := v.air.humid
	var w0 := v.water.total(v.water.w)
	check(v.open_lid() and v.air.lid_open and not v.open_lid(), "뚜껑을 연다 (두 번 열리지 않음)")
	var said := v.people.any(func(r: Resident) -> bool: return r.say == Balance.LID_AWE_LINE)
	check(said and v.book.back()["text"].begins_with("하늘이 열렸다!"), "\"하늘이 열렸다!\" 말풍선 + 연대기")
	v.advance(60.0)
	twin.advance(60.0)
	var t1 := v.temperature_at(p.x, p.y)
	var tt1 := twin.temperature_at(p.x, p.y)
	print("  1월 한낮 %.1f° → 1분 열림 %.1f° (닫힌 병 %.1f°) · 김 %.2f → %.2f" % [t0, t1, tt1, h0, v.air.humid])
	check(t1 < tt1 - 1.5, "겨울에 열면 차가운 바람 (%.1f° < 닫힌 병 %.1f°)" % [t1, tt1])
	var hv := village("열대")
	hv.step(1.0)
	var hh0 := hv.air.humid
	hv.open_lid()
	hv.advance(60.0)
	check(hv.air.humid < hh0 - 0.1, "열린 동안 김이 빠진다 (열대 1분 %.2f → %.2f)" % [hh0, hv.air.humid])
	v.close_lid()
	v.advance(60.0)
	twin.advance(60.0)
	var wl := 1.0 - v.water.total(v.water.w) / twin.water.total(twin.water.w)
	check(wl > 0.01 and wl < 0.08 and v.air.water_lost > 0.0, "물이 조금 증발해 나감 (1분 열림 → %.1f%%)" % (wl * 100.0))
	v.advance(2.0 * H)
	twin.advance(2.0 * H)
	check(absf(v.temperature_at(p.x, p.y) - twin.temperature_at(p.x, p.y)) < 0.5, "닫고 두 시간이면 기온이 돌아온다")
	# 안전장치: 병 시계 8분 넘게 열려 있으면 닫힘 (오프라인·몰아서 계산)
	var s := village()
	s.water.offline = true
	s.open_lid()
	s.advance(20.0 * 60.0)
	check(not s.air.lid_open and absf(s.air.lid_total - Balance.LID_SAFETY_CLOSE) <= Balance.STEP + 1e-6, "병 시계 8분 뒤 저절로 닫힘 (열린 시간 %.0f초)" % s.air.lid_total)


func test_lid_auto_close() -> void:
	for sp in [0, 3]:
		var v := village()
		var c := JarClock.new(v)
		c.set_speed(sp)
		v.open_lid()
		var real := 0.0
		while v.air.lid_open and real < 120.0:
			c.tick(0.25)
			real += 0.25
		check(not v.air.lid_open and real <= 60.5 and real >= 59.5 - (52.0 if sp == 3 else 0.0), "×%d: 현실 1분이면 저절로 닫힘 (%.1f초, 병 시계 %.0f초 열림)" % [int(c.speed()), real, v.air.lid_total])


func test_gnats() -> void:
	var res := {}
	for m: int in [7, 4, 1]:
		var v := village("온대", m, 15)
		v.step(1.0)
		var n := 1500 if not quick else 600
		for i in n:
			v.open_lid()
			v.close_lid()
		res[m] = float(v.air.gnats) / n
	print("  날벌레: 여름 %.3f · 봄 %.3f · 겨울 %.3f" % [res[7], res[4], res[1]])
	check(absf(res[7] - 0.08) < 0.03 and absf(res[4] - 0.03) < 0.02 and res[1] == 0.0, "날벌레 확률: 여름 8% · 봄 3% · 겨울 0%")


# ───────────────────────── 압력 ─────────────────────────
func test_pressure() -> void:
	var t := village("온대")
	var su := village("온대", 7, 15)
	var w := village("열대")
	var omen_day := -1.0
	var swarm_day := -1.0
	var max_fog := 0.0
	for v in [t, su, w]:
		v.water.offline = true
	for i in 6 * 24:
		for v in [t, su, w]:
			v.advance(H)
		if omen_day < 0.0 and w.mold.phase == "omen":
			omen_day = w.t / D
		if swarm_day < 0.0 and w.mold.phase == "swarm":
			swarm_day = w.t / D
		max_fog = maxf(max_fog, w.mold.omen_fog)
	print("  6일: 온대 봄 압력 %.2f · 온대 여름 %.2f (김×따뜻함 %.2f) · 열대 조짐 %.1f일 · 무리 %.1f일" % [t.mold.pressure, su.mold.pressure, su.mold.hw_now(su), omen_day, swarm_day])
	check(t.mold.stats["spawned"] == 0 and su.mold.stats["spawned"] == 0 and t.mold.pressure < 0.1, "온대 병은 보통 곰팡이 압력 아래 (봄·여름 6일)")
	check(omen_day >= Balance.MOLD_FIRST_DAY and omen_day < 3.6, "열대 병은 사흘쯤 뒤 조짐 (%.1f일 — 첫 3일은 없음)" % omen_day)
	check(swarm_day - omen_day > 0.45 and swarm_day - omen_day < 0.6, "조짐 반나절 뒤 무리 (%.2f일)" % (swarm_day - omen_day))
	check(max_fog > 0.8, "조짐 동안 유리가 뿌예짐 (%.2f)" % max_fog)
	var told := w.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("빵에 ") and String(e["text"]).contains(" 털이 돋았다"))
	check(told, "연대기: 빵에 (그 무리 색) 털이 돋았다")
	# 거인이 조짐 동안 김을 빼면 조짐이 걷힌다
	var g := village("열대")
	g.water.offline = true
	g.advance(2.0 * H)
	g.mold.force_omen(g)
	var opened := 0
	while g.mold.phase == "omen" and opened < 20:
		g.open_lid()
		g.advance(8.0 * 60.0)
		opened += 1
	check(g.mold.phase == "calm" and g.mold.blobs.is_empty(), "조짐 때 뚜껑을 열어 김을 빼면 무리가 오지 않음 (%d번 열기)" % opened)


# ───────────────────────── 처음 겪는 무리 ─────────────────────────
func test_swarm_first_time() -> void:
	var v := swarm_village()
	var m := v.mold
	var n0 := m.blobs.size()
	check(n0 >= Balance.MOLD_SPAWN[0] and n0 <= Balance.MOLD_SPAWN[1] and m.phase == "swarm", "무리 %d마리가 나타남" % n0)
	var sp := Vector2(v.store().x, v.store().y)
	var near_store := m.blobs.all(func(b: MoldBlob) -> bool: return b.pos().distance_to(sp) < 10.0)
	check(near_store, "창고 곁 그늘·젖은 땅에서 생긴다")
	check(m.blobs.all(func(b: MoldBlob) -> bool: return b.kind == m.blobs[0].kind), "한 무리는 한 색 (%s)" % m.blobs[0].kind)
	m.peak_end = v.t + 2.0 * D
	v.advance(4.0 * H)
	var gnaw := m.blobs.filter(func(b: MoldBlob) -> bool: return b.state == "gnaw").size()
	check(gnaw >= 2, "창고로 몰려가 갉는다 (%d마리)" % gnaw)
	check(m.stats["rot_food"] > 1.0, "식량이 썩는다 (%.1f)" % m.stats["rot_food"])
	check(m.stats["hid"] > 0 and m.chaser_id < 0, "처음 겪는 마을은 숨기만 한다 (숨음 %d번, 쫓는 사람 없음)" % m.stats["hid"])
	v.advance(D)
	print("  첫 무리: %d → %d마리 (나뉨 %d) · 썩은 식량 %.0f · 숨음 %d · 놀람 %d" % [n0, m.blobs.size(), m.stats["split"], m.stats["rot_food"], m.stats["hid"], m.startles])
	check(m.stats["split"] >= 1, "습하면 나뉜다 (%d번)" % m.stats["split"])
	var k := 0
	while m.phase == "swarm" and k < 48:
		v.advance(H)
		k += 1
	check(m.phase == "calm" and m.episodes == 1, "한창이 지나면 잦아들어 물러감 (%d시간 더)" % k)
	check(m.wild().is_empty(), "흩어진 털뭉치가 모두 사라짐")
	# 마른 병에서는 나뉘지 않는다
	var d := village("온대")
	d.water.offline = true
	d.advance(2.0 * H)
	d.mold.force_swarm(d, "검은")
	d.mold.peak_end = d.t + 2.0 * D
	d.advance(D)
	check(d.mold.stats["split"] == 0, "마른 병에서는 나뉘지 않는다 (김 %.2f)" % d.air.humid)
	# 썩는 빠르기: 4마리면 하루 5%, 2마리면 2.5%, 세 번 겪은 마을은 절반
	var r := village()
	r.stock["건량"] = 1000.0
	r.mold._rot(r, 4, D)
	var a := float(r.stock["건량"])
	r.stock["건량"] = 1000.0
	r.mold._rot(r, 2, D)
	var b := float(r.stock["건량"])
	r.stock["건량"] = 1000.0
	r.mold.episodes = 3
	r.mold._rot(r, 4, D)
	var c := float(r.stock["건량"])
	check(absf(a - 950.0) < 0.01 and absf(b - 975.0) < 0.01 and absf(c - 975.0) < 0.01, "창고 하루 5%% (4마리 %.0f · 2마리 %.0f · 익숙해진 마을 %.0f)" % [a, b, c])


# ───────────────────────── 쫓는 사람 · 익숙해짐 ─────────────────────────
func test_chaser_and_adapt() -> void:
	var v := swarm_village(9)
	var m := v.mold
	m.episodes = 1                      # 한 번 겪은 마을
	m.blobs.clear()
	m.force_swarm(v, "검은")
	v.stock["소금"] = 0.0
	v.stock["통나무"] = 40.0
	var ch := v.person(m.chaser_id)
	check(ch != null and ch.is_adult(), "두 번째 무리: 촌장이 '곰팡이 쫓는 사람'을 정함 (%s)" % (ch.name if ch != null else "-"))
	var n0 := m.wild().size()
	var torch_seen := false
	for i in 6 * 60:
		v.advance(10.0)
		if ch != null and ch.action == "mold_chase" and ch.anim == "torch":
			torch_seen = true
		if m.wild().is_empty():
			break
	print("  횃불: %d마리 중 쫓아냄 %d (횃불질 %d, 숙련 %.2f) · 통나무 %.1f" % [n0, m.stats["defeated"], m.stats["torch"], float(ch.skills.get(Balance.MOLD_SKILL, 0.0)) if ch != null else 0.0, float(v.stock["통나무"])])
	check(torch_seen and m.stats["defeated"] >= 2, "횃불을 들고 쫓아가 쪼그라뜨린다 (%d마리)" % m.stats["defeated"])
	check(ch != null and float(ch.skills.get(Balance.MOLD_SKILL, 0.0)) > 0.0, "쫓을수록 숙련이 쌓인다")
	check(float(v.stock["통나무"]) < 40.0, "횃불은 통나무를 쓴다")
	# 익숙해짐: 세 번 겪으면 포자 배율도 절반 (×2 → ×1.5)
	var a := swarm_village()
	var r := a.people[0]
	var b := a.mold.blobs[0]
	b.x = r.x
	b.y = r.y
	var m1 := Mold.ill_mult(a, r)
	a.mold.episodes = 3
	var m3 := Mold.ill_mult(a, r)
	check(m1 == 2.0 and m3 == 1.5, "세 번 겪은 마을은 피해 절반 (포자 ×%.1f → ×%.1f)" % [m1, m3])


# ───────────────────────── 약점 ─────────────────────────
func test_weaknesses() -> void:
	# 볕 드는 쪽에서 느려짐
	var v := village("열대")
	var m := v.mold
	var sunny := JarWater.LIGHT * 22.0
	var shade := -JarWater.LIGHT * 22.0
	var bs := m._spawn(v, sunny, "검은", 1.0)
	var bd := m._spawn(v, shade, "검은", 1.0)
	bs.tx = sunny.x + 6.0
	bs.ty = sunny.y
	bd.tx = shade.x + 6.0
	bd.ty = shade.y
	for i in 4:
		m._move(v, 1.0)
	var ds := bs.pos().distance_to(sunny)
	var dd := bd.pos().distance_to(shade)
	check(ds < dd * 0.7, "볕 드는 쪽에서 느려진다 (4초: 볕 %.2f칸 · 그늘 %.2f칸)" % [ds, dd])
	# 소금 → 녹음, 횃불 → 쪼그라듦
	var r := v.people[0]
	r.x = bd.x
	r.y = bd.y
	v.stock["소금"] = 2.0
	m._strike(v, r, bd.id)
	check(bd.state == "gone" and m.stats["melted"] == 1 and float(v.stock["소금"]) == 1.0, "소금을 뿌리면 녹는다")
	v.stock["소금"] = 0.0
	v.stock["통나무"] = 5.0
	r.x = bs.x
	r.y = bs.y
	m._strike(v, r, bs.id)
	check(bs.size < 1.0 and bs.state == "flee" and bs.burnt > 0.0, "횃불에 오그라들고 물러선다 (크기 %.2f)" % bs.size)
	# 뚜껑을 열면 마른 공기에 쪼그라들어 흩어짐
	var w := swarm_village()
	w.advance(H)
	var n := w.mold.wild().size()
	w.open_lid()
	w.advance(60.0)
	var fled := w.mold.wild().all(func(b: MoldBlob) -> bool: return b.state == "flee")
	w.advance(4.0 * 60.0)
	print("  뚜껑: %d마리 → 5분 뒤 %d마리 (마름 %d)" % [n, w.mold.wild().size(), w.mold.stats["dried"]])
	check(fled and w.mold.wild().size() < n and w.mold.stats["dried"] >= 1 and w.mold.lid_helped, "뚜껑을 열면 마른 공기에 흩어져 쪼그라든다")
	# 병을 돌리면 털뭉치도 함께 돈다
	var q := swarm_village()
	var b0 := q.mold.blobs[0].pos()
	q.rotate_jar()
	check(q.mold.blobs[0].pos().distance_to(Vector2(-b0.y, b0.x)) < 1e-4, "병을 돌리면 털뭉치도 돈다")


# ───────────────────────── 포자 → 배앓이·기침병 ×2 ─────────────────────────
func test_illness() -> void:
	var counts := []
	for with_mold in [false, true]:
		var v := village("열대")
		var m := v.mold
		if with_mold:
			for r in v.people:
				var b := m._spawn(v, Vector2(r.x, r.y), "검은", 1.0)
				b.state = "gnaw"
		var by := {}
		var n := 30000 if not quick else 12000
		for i in n:
			for r in v.people:
				r.hunger = Balance.STARVING_AT
				r.health = 0.4
			Health._hourly(v, [])
			for r in v.people:
				if r.sick_left > 0.0:
					by[r.disease] = int(by.get(r.disease, 0)) + 1
					r.sick_left = 0.0
					r.disease = ""
					r.severe = false
					r.immune.clear()
		counts.append(by)
	var a: Dictionary = counts[0]
	var b: Dictionary = counts[1]
	var ill_a := int(a.get("배앓이", 0)) + int(a.get("기침병", 0))
	var ill_b := int(b.get("배앓이", 0)) + int(b.get("기침병", 0))
	var cold_a := int(a.get("고뿔", 0))
	var cold_b := int(b.get("고뿔", 0))
	var ratio := float(ill_b) / maxf(1.0, ill_a)
	var cr := float(cold_b) / maxf(1.0, cold_a)
	print("  포자: 배앓이+기침병 %d → %d (×%.2f) · 고뿔 %d → %d (×%.2f)" % [ill_a, ill_b, ratio, cold_a, cold_b, cr])
	check(ratio > 1.6 and ratio < 2.5, "털뭉치 곁: 배앓이·기침병 ×2 (×%.2f)" % ratio)
	check(cr > 0.75 and cr < 1.3, "고뿔은 그대로 (×%.2f)" % cr)


# ───────────────────────── 누룩곰팡이 ─────────────────────────
func test_koji() -> void:
	var v := swarm_village()
	var m := v.mold
	var kid: Resident = null
	for r in v.people:
		if r.is_child() and r.age >= 2.5:
			kid = r
	if kid == null:
		kid = v.people[2]
		kid.age = 3.0
	kid.sleeping = false
	var b := m._spawn(v, Vector2(kid.x + 1.0, kid.y), "누룩", 1.0)
	m._koji(v)
	check(m.koji_known and m.koji_tamed and b.state == "tamed", "아이가 노란 털뭉치를 알아봄 → 길들임")
	check(v.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("노란 곰팡이는 나쁜 것이 아니었다")), "연대기: 노란 곰팡이는 나쁜 것이 아니었다")
	check(m._nearest_wild(b.pos(), 0.5, true) == null and not b in m.wild(), "길들인 누룩은 쫓지 않고 창고를 갉지 않는다")
	# 빵 ×1.3
	var rates := []
	for tamed in [false, true]:
		var q := village()
		var bk := q.add_building("빵집", 6.0, 6.0, true)
		var w := q.people[0]
		w.job = bk.id
		bk.worker = w.id
		bk.in_buf = {"밀가루": 50.0, "물": 50.0}
		q.mold.koji_tamed = tamed
		q._update_building(bk, 10.0)
		rates.append(bk.timer)
	check(absf(rates[1] / rates[0] - Balance.KOJI_BREAD) < 1e-4, "길들인 누룩 → 빵 ×1.3 (%.2f)" % (rates[1] / rates[0]))


# ───────────────────────── 푸른곰팡이 약 ─────────────────────────
func test_blue_medicine() -> void:
	var v := swarm_village()
	var m := v.mold
	var teal := m._spawn(v, Vector2(3, 3), "푸른", 0.3)
	var hurt := v.people[3]
	hurt.x = 4.0
	hurt.y = 4.0
	Health.fall_ill(v, hurt, false, Balance.FESTER_KIND)
	var left0 := hurt.sick_left
	m._defeat(v, v.people[0], teal)
	check(float(v.stock.get(Balance.BLUE_POWDER, 0.0)) == 1.0, "푸른곰팡이를 쫓으면 푸른 가루가 남는다")
	check(m.med_known and hurt.sick_left < left0 * 0.6, "곪은 상처에 가루가 묻어 빨리 나음 → 약이 된다는 걸 앎")
	# 일 없는 어른이 푸른 가루 + 빵으로 곰팡이약을 만든다
	m.blobs.clear()
	m.phase = "calm"
	v.stock[Balance.BLUE_POWDER] = 3.0
	v.stock["빵"] = 5.0
	v.advance(6.0 * H)
	print("  곰팡이약: %.0f개 (푸른 가루 %.0f · 빵 %.0f)" % [float(v.stock.get(Balance.MOLD_MED, 0.0)), float(v.stock[Balance.BLUE_POWDER]), float(v.stock["빵"])])
	check(float(v.stock.get(Balance.MOLD_MED, 0.0)) >= 2.0 and float(v.stock[Balance.BLUE_POWDER]) < 3.0, "곰팡이약을 만든다 (푸른 가루 + 빵)")
	# 듣는 병: 중증을 막고 기간 ×0.5
	var q := village()
	q.mold.med_known = true
	q.stock[Balance.MOLD_MED] = 10.0
	var r := q.people[1]
	Health.fall_ill(q, r, false, "기침병")
	r.severe = true
	var s0 := r.sick_left
	Mold.medicine(q, r)
	check(not r.severe and absf(r.sick_left - s0 * 0.5) < 1e-3 and float(q.stock[Balance.MOLD_MED]) == 9.0, "기침병: 중증을 막고 앓는 기간 ×0.5")
	Mold.medicine(q, r)
	check(float(q.stock[Balance.MOLD_MED]) == 9.0, "한 번 앓을 때 한 번만 먹는다")
	# 듣지 않는 병: 써 보고 실패 → 세 번이면 마을이 배움 → 그 뒤로는 쓰지 않음
	var fails := 0
	for i in 3:
		var p := q.people[4 + i]
		Health.fall_ill(q, p, false, "고뿔")
		var sl := p.sick_left
		Mold.medicine(q, p)
		if absf(p.sick_left - sl) < 1e-6:
			fails += 1
	check(fails == 3 and q.mold.med_learned, "고뿔엔 듣지 않는다 — 세 번 써 보고 마을이 배움")
	check(q.book.any(func(e: Dictionary) -> bool: return String(e["text"]).contains("기침과 곪은 데만 듣는다")), "연대기: 푸른 약은 기침과 곪은 데만 듣는다")
	var before := float(q.stock[Balance.MOLD_MED])
	var p2 := q.people[8]
	Health.fall_ill(q, p2, false, "배앓이")
	Mold.medicine(q, p2)
	check(float(q.stock[Balance.MOLD_MED]) == before, "배운 뒤로는 배앓이에 쓰지 않는다")
	check(Market.base_price(Balance.MOLD_MED) == 8.0, "제물 값: 곰팡이약 8")


# ───────────────────────── 결정론 ─────────────────────────
func test_determinism() -> void:
	var sigs := []
	for sp in [0, 3]:
		var v := village("열대", 4, 15, 3)
		v.step(1.0)
		v.mold.force_swarm(v, "검은")
		v.mold.episodes = 1
		v.mold._name_chaser(v)
		var c := JarClock.new(v)
		c.set_speed(sp)
		var steps := int(1.5 * H)
		var dt := 1.0 / 30.0 if sp == 0 else 0.25
		while c.steps_done < steps:
			c.tick(dt)
		sigs.append(_blob_sig(v) + "|%d|%s" % [v.rng.state, str(v.food_total())])
	check(sigs[0] == sigs[1], "무리가 있는 병: ×1과 ×8 결과가 같다 (털뭉치 자리·크기·난수)")
