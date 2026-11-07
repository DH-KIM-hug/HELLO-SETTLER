## A4b 깨달음 · A5 계시 · A10 연대기 — tests/run.gd가 부름 (`-- era` = 이것만). 장면(연대기 시트·제단 시트)을 띄우므로 장면 묶음(첫 화면에서).
## 깨달음: 처음엔 제단·기도·제물·소원이 없음 · 목격 → 경이 · 깨달음 사건 · 제단 짓기 · 첫 기도 → 제물 → 지폐 · 안내 따라 ×12로 10분 안 ·
##   안내 없이도 며칠 안 · 저장/불러오기 중간 · 넓은 세상 첫 무리 · 옛 저장은 그대로 앎.
## 계시: 점수가 차면 계시를 기다림(편지·노인 말) → 계시 → 시대 1 · 새 건물 · 연대기 · 저장 · 비운 동안 저절로 오지 않음 · 넓은 세상 무리마다.
## 연대기: 최근(최신부터·날마다·무리 이름) · 창세 신화 · 사람들(살아 있음·잠듦·분가로 떠남) · 발견 도감.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const X12 := 12.0                     # 창세의 날 배속 (현실 1초 = 병 12초)

var _old_aware := true
var _old_notes := 0.0
var _old_paid := false


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 깨달음 · 계시 · 연대기 (A4b · A5 · A10)")
	_old_aware = Village.start_aware
	_old_notes = Market.notes
	_old_paid = Market.first_paid
	Village.start_aware = false
	run.timed(self, ["test_unaware_start", "test_witness_wonder", "test_awakening_and_altar", "test_guided_path", "test_unguided",
		"test_save_midway", "test_world_first", "test_old_save_aware",
		"test_revelation_flow", "test_era_pace", "test_offline_no_auto_reveal", "test_revelation_world",
		"test_chronicle_recent_myth", "test_chronicle_people", "test_codex", "test_sheets"])
	Village.start_aware = _old_aware
	Market.notes = _old_notes
	Market.first_paid = _old_paid


func proto(seed_v := 20261105) -> Village:
	var v := Village.new_prototype(seed_v)
	v.water.offline = true            # 물 격자를 성기게 (빠르게 — 다른 시험과 같음)
	return v


## 이미 안 마을 (계시·연대기 시험용 — 예전 규칙)
func aware_proto(seed_v := 20261105) -> Village:
	Village.start_aware = true
	var v := proto(seed_v)
	Village.start_aware = false
	return v


func through_bytes(v: Village) -> Village:
	var d := v.to_dict()
	var b := var_to_bytes(d)
	return Village.from_dict(bytes_to_var(b))


func has_line(v: Village, part: String) -> bool:
	for e: Dictionary in v.book:
		if String(e["text"]).contains(part):
			return true
	return false


# ───────────────────────── A4b 깨달음 ─────────────────────────
func test_unaware_start() -> void:
	var v := proto()
	check(not v.aware and not v.altar_built and v.faith == 0.0 and Awakening.altar_site(v) == null, "새 병: 주민은 거인을 모르고 제단이 없다 (믿음 0)")
	var prayed := false
	var t_end := 20.0 * Balance.HOUR
	while v.t < t_end and not v.aware:
		v.advance(60.0)
		for r in v.people:
			if r.anim == "pray" or r.action == "pray":
				prayed = true
	check(not v.aware, "아무것도 안 하면 첫날엔 아직 모른다 (경이 %.1f / %.0f)" % [v.wonder, Awakening.WONDER_NEED])
	check(not prayed, "제단 전에는 아무도 기도하지 않는다")
	check(v.altar.is_empty() and int(v.stats.get("offered", 0)) == 0, "제단 전에는 제물이 없다 (저녁이 지나도)")
	check(v.letters.is_empty(), "제단 전에는 소원 편지가 없다")
	check(v.evening_offering().is_empty(), "evening_offering도 제단이 없으면 빈손")
	var all_zero := v.people.all(func(r: Resident) -> bool: return r.belief == 0.0)
	check(all_zero and v.faith == 0.0, "믿음은 0 그대로 (아기까지)")
	check(has_line(v, "하늘이 주는 것") and not has_line(v, "거인이 하늘에서 낟알"), "하늘 낟알은 '하늘이 주는 것' — 거인이라는 말 없음")
	check(has_line(v, "모닥불 곁에 모여 손뼉을 쳤다") and not has_line(v, "감사 기도"), "첫 집이 서면 기도 대신 모닥불 곁에 모여 기뻐함")


func test_witness_wonder() -> void:
	var v := proto()
	v.advance(10.0 * 60.0)
	var w0 := v.wonder
	v.tap_glass(false)
	var d1 := v.wonder - w0
	check(d1 > 5.0, "유리 톡(약하게) → 경이 +%.1f" % d1)
	var w1 := v.wonder
	v.tap_glass(false)
	var d2 := v.wonder - w1
	check(d2 > 0.0 and d2 < d1, "같은 날 거듭 톡하면 줄어든다 (+%.1f < +%.1f)" % [d2, d1])
	var f0 := v.fear
	var w2 := v.wonder
	v.tap_glass(true)
	check(v.wonder == w2, "세게 친 톡은 경이 없이 두려움만 (두려움 %.1f → %.1f)" % [f0, v.fear])
	var w3 := v.wonder
	v.open_lid()
	check(v.wonder > w3, "뚜껑 열기 → 경이 +%.1f" % (v.wonder - w3))
	var w4 := v.wonder
	var n := v.blow_seeds(Vector2(1, 0))
	check(n > 0 and v.wonder - w4 >= 15.0, "꽃씨 불기 → 꽃씨 %d · 경이 +%.1f (첫 마을 곁 솜털 공은 꼭 있다)" % [n, v.wonder - w4])
	v.close_lid()
	var kid_said := false
	var adult_said := false
	for r in v.people:
		if r.say in Awakening.LINES_CHILD or r.say in Awakening.LINES_ELDER:
			kid_said = true
		if r.say in Awakening.LINES_ADULT:
			adult_said = true
	check(kid_said, "아이·노인이 먼저 알아챔 (\"하늘에 누가 있어!\")")
	var u := proto(7)
	u.advance(10.0)
	var wm := u.wonder
	check(wm > 0.0 and wm < 10.0, "하늘 낟알(도착) = 작은 경이 (%.1f)" % wm)
	var a := aware_proto()
	var wa := a.wonder
	a.tap_glass(false)
	check(a.wonder == wa, "이미 아는 마을은 경이를 세지 않는다")


func test_awakening_and_altar() -> void:
	Market.reset(0.0)
	var v := proto()
	v.advance(20.0 * 60.0)
	v.wonder = Awakening.WONDER_NEED - 1.0
	v.tap_glass(false)
	check(v.awaken_at > v.t, "경이가 차면 잠시 뒤 깨달음 (%.0f초 뒤)" % (v.awaken_at - v.t))
	v.advance(Awakening.AWAKEN_DELAY + 30.0)
	check(v.aware and v.awakened_t > 0.0, "깨달음 사건이 일어남")
	check(has_line(v, Awakening.LINE_AWAKEN), "연대기: \"%s\"" % Awakening.LINE_AWAKEN)
	check(v.faith > 0.0, "믿음이 처음 생김 (%.0f)" % v.faith)
	var site := Awakening.altar_site(v)
	check(site != null and site.wished and site.x == v.altar_pos.x, "촌장이 모닥불 곁에 제단 터를 잡음 (맨 앞)")
	check(has_line(v, WatcherName.fill(v, Awakening.LINE_CHIEF)), "촌장: \"%s\"" % WatcherName.fill(v, Awakening.LINE_CHIEF))
	check(v.altar_pos.distance_to(v.fire) >= 2.9 and v.altar_spot_ok(v.altar_pos), "제단 자리는 모닥불에서 3칸, 건물·물과 겹치지 않음")
	var t0 := v.t
	while not v.altar_built and v.t - t0 < 3.0 * Balance.HOUR:
		v.advance(30.0)
	var build_min := (v.t - t0) / 60.0
	check(v.altar_built and build_min <= 45.0, "제단이 짧게 지어짐 (병 %.0f분 — ×12로 현실 %.1f분)" % [build_min, build_min / X12])
	var ring := 0
	for r in v.people:
		if r.doing == "첫 기도를 드리는 중":
			ring += 1
	check(ring >= 5, "첫 기도: %d명이 제단 둘레에 모임" % ring)
	check(not v.altar.is_empty(), "첫 기도 때 제단에 올린 것: %s" % str(v.altar_items()))
	v.advance(Awakening.FIRST_PRAYER * 0.5)
	var near := 0
	var facing := 0
	for r in v.people:
		var d := Vector2(r.x, r.y).distance_to(v.altar_pos)
		if d < Awakening.RING_R + 1.0 and r.anim == "pray":
			near += 1
			var to := (v.altar_pos - Vector2(r.x, r.y)).normalized()
			if Vector2(sin(r.facing), cos(r.facing)).dot(to) > 0.7:
				facing += 1
	check(near >= 4 and facing >= near - 1, "제단 둘레 고리에서 제단을 바라보며 기도 (%d명 중 %d명)" % [near, facing])
	var got := v.take_all()
	check(got >= Balance.FIRST_OFFER_BONUS and Market.notes >= Balance.FIRST_OFFER_BONUS, "첫 제물 [받기] → 첫 지폐 %.0f (웃돈 포함)" % got)
	var tw := v.t
	while v.open_letters("wish").is_empty() and v.t - tw < 2.0 * Balance.HOUR:
		v.advance(60.0)
	check(not v.open_letters("wish").is_empty() and (v.t - tw) / 60.0 <= 30.0, "제단 뒤 첫 소원 편지 (병 %.0f분 뒤)" % ((v.t - tw) / 60.0))
	var c := fmod(v.start_clock + v.t, Balance.DAY)
	v.advance(fposmod(Balance.OFFER_HOUR * Balance.HOUR + 120.0 - c, Balance.DAY))
	check(v._offer_key == v.cal_day(v.t) * 2 + 1 and v.book.size() > 0, "그 저녁부터 평소 저녁 기도 (기도 번호 %d — v5: 남는 물건이 있을 때만 제물, 넉넉함이 인구에 맞게 늘어 첫날 저녁엔 없을 수 있음)" % v._offer_key)


## OPENING 3.1 v3.3: 2:00 톡 → 3:00 물 뿌리기 (뚜껑은 손짓마다 저절로) → 깨달음 → 제단 — ×12로 현실 10분 안 (자막은 톡 하나뿐)
func test_guided_path() -> void:
	var v := proto()
	v.guide = {"on": true}
	var marks := {}
	while v.t < 10.0 * 60.0 * X12 and not v.altar_built:
		v.advance(30.0)
		var real := v.t / X12
		if real < 110.0:
			if GuideCaption.step(v) != "":
				marks["early"] = true
		if real >= 120.0 and not marks.has("tap"):
			marks["tap"] = GuideCaption.step(v)
			v.tap_glass(false)
			GuideCaption.done(v, "tap")
			marks["after_tap"] = GuideCaption.step(v)
			marks["hl"] = GuideCaption.highlight(v)
		if real >= 180.0 and not marks.has("water"):
			marks["water"] = true
			v.open_lid()
			v.spray_water(v.fire + Vector2(3, 3))
			v.close_lid()
		if v.aware and not marks.has("aware"):
			marks["aware"] = v.t / X12 / 60.0
	check(not marks.has("early"), "안내 자막은 2분쯤부터 (그 전엔 없음)")
	check(marks.get("tap", "") == "tap" and marks.get("after_tap", "x") == "" and marks.get("hl", "x") == "", "자막 ① 유리 톡 → 톡 하면 끝 (뚜껑·불기 안내 없음)")
	var aw: float = marks.get("aware", 99.0)
	check(aw >= 3.0 and aw <= 6.5, "깨달음 현실 %.1f분 (목표 4~6분)" % aw)
	check(v.altar_built and v.t / X12 / 60.0 <= 10.0, "제단 완공 현실 %.1f분 (10분 안)" % (v.t / X12 / 60.0))
	check(GuideCaption.step(v) == "", "깨달은 뒤엔 안내 끝")


func test_unguided() -> void:
	var v := proto(11)
	var t_end := 6.0 * Balance.DAY
	while v.t < t_end and not v.altar_built:
		v.advance(300.0)
	check(v.aware, "아무것도 안 해도 언젠가 깨닫는다 (%.1f일째 — 하늘 낟알·물방울만으로)" % (v.awakened_t / Balance.DAY))
	check(v.awakened_t > 1.0 * Balance.DAY, "안내 없이는 며칠 걸린다 (하루 넘게)")
	check(v.altar_built, "그 뒤 제단을 짓는다")
	var w := proto(12)                  # 비운 동안(거인 없음)에도 경이는 천천히
	var c := CatchUp.new(w, 12.0 * Balance.HOUR, 12.0 * Balance.HOUR)
	c.finish()
	check(w.wonder > 5.0 and not w.aware, "비운 12시간: 하늘 낟알·물방울로 경이 %.1f (아직 모름)" % w.wonder)


func test_save_midway() -> void:
	var v := proto()
	v.advance(20.0 * 60.0)
	v.tap_glass(false)
	v.guide = {"on": true, "tap": true}
	var b := through_bytes(v)
	check(not b.aware and not b.altar_built and absf(b.wonder - v.wonder) < 1e-6 and b.guide.get("tap", false), "저장/불러오기: 깨닫기 전 (경이 %.1f · 안내 상태)" % b.wonder)
	v.wonder = Awakening.WONDER_NEED
	Awakening._add(v, 0.0)
	v.advance(Awakening.AWAKEN_DELAY + 60.0)
	var t0 := v.t
	while v.t - t0 < 8.0 * 60.0:
		v.advance(30.0)
	var site := Awakening.altar_site(v)
	check(site != null and not site.built and site.prog > 0.0, "제단을 짓는 중 (%.0f%%)" % (100.0 * site.prog / float(Balance.B["제단"]["time"]) if site != null else -1.0))
	var c := through_bytes(v)
	var cs := Awakening.altar_site(c)
	check(c.aware and cs != null and absf(cs.prog - site.prog) < 1e-3, "저장/불러오기: 짓는 중인 제단 그대로")
	var t1 := c.t
	while not c.altar_built and c.t - t1 < 2.0 * Balance.HOUR:
		c.advance(30.0)
	check(c.altar_built and not c.altar.is_empty(), "불러온 뒤 이어서 완공 → 첫 기도 제물")


func test_world_first() -> void:
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y)
	v.water.offline = true
	check(not v.aware and not v.altar_built and v.faith == 0.0, "넓은 세상 첫 무리도 처음엔 모른다")
	var st := v.store()
	check(v.altar_pos.distance_to(Vector2(st.x, st.y)) > st.size() + 1.5, "제단 자리가 창고와 겹치지 않음 (%.1f칸)" % v.altar_pos.distance_to(Vector2(st.x, st.y)))
	jw.advance(20.0 * 60.0)
	v.tap_glass(false)
	jw.advance(10.0 * 60.0)
	v.open_lid()
	var n := v.blow_seeds(Vector2(1, 0))
	v.close_lid()
	check(n > 0, "첫 무리 곁 솜털 공 → 꽃씨 %d" % n)
	var t0 := v.t
	while not v.altar_built and v.t - t0 < 3.0 * Balance.HOUR:
		jw.advance(60.0)
	check(v.aware and v.altar_built, "넓은 세상: 깨달음 → 제단 (병 %.0f분)" % ((v.t - t0) / 60.0))


func test_old_save_aware() -> void:
	var v := aware_proto()
	v.advance(Balance.HOUR)
	var d := v.to_dict()
	for k: String in ["aware", "altar_built", "wonder", "awaken_at", "awakened_t", "_wonder_taps", "guide", "revelation", "myth", "departed", "discoveries"]:
		d.erase(k)
	d["altar_pos"] = Vector2(v.store().x, v.store().y)          # 옛 저장: 제단이 창고 자리에
	var b := Village.from_dict(d)
	check(b.aware and b.altar_built, "옛 저장(이 값들이 없음) → 이미 앎 · 제단 있음")
	check(b.altar_spot_ok(b.altar_pos) and b.altar_pos.distance_to(Vector2(b.store().x, b.store().y)) > 2.0, "옛 저장의 창고에 묻힌 제단 → 모닥불 곁 빈자리로")
	check(b.revelation.is_empty() and b.departed.is_empty() and b.discoveries.is_empty(), "새 값은 기본값")


# ───────────────────────── A5 계시 ─────────────────────────
func test_revelation_flow() -> void:
	var v := aware_proto()
	v.advance(2.0 * Balance.HOUR)
	check(not v.revelation_pending(), "점수가 차기 전엔 계시 없음 (%.0f / %.0f)" % [v.era_pts, Balance.ERA_NEED[0]])
	v.era_pts = Balance.ERA_NEED[0]
	v.advance(5.0)
	check(v.revelation_pending() and v.era == 0, "점수가 차면 계시를 기다림 (시대는 그대로)")
	check(String(v.revelation.get("text", "")).contains("하늘이 무언가를 알려 주실 것 같아요"), "노인의 편지: \"%s\"" % v.revelation.get("text", ""))
	check(has_line(v, "하늘을 올려다보았다"), "연대기: 노인들이 하늘을 올려다봄")
	var said := v.people.any(func(r: Resident) -> bool: return r.is_elder() and (r.say.contains("하늘") or r.say.contains(WatcherName.fill(v, "{w:이/가} 곧"))))
	check(said, "노인이 하늘을 보며 말함")
	var b := through_bytes(v)
	check(b.revelation_pending() and b.revelation == v.revelation, "저장/불러오기: 기다리는 계시 그대로")
	var t := v.t
	check(v.giant_reveal(), "[계시] → 내려짐")
	check(v.era == 1 and v.era_pts == 0.0 and not v.revelation_pending(), "시대 '마을' (1)")
	check(has_line(v, WatcherName.fill(v, "{w:이/가} 새 시대를 열었다 — 마을")), "연대기: \"%s\"" % WatcherName.fill(v, "{w:이/가} 새 시대를 열었다 — 마을"))
	check(v.festival_t == t, "광장 축제 (축제 음악)")
	var kneel := v.people.filter(func(r: Resident) -> bool: return not r.steps.is_empty() and r.steps[0].get("anim", "") == "pray").size()
	check(kneel >= 5, "깨어 있는 사람 %d명이 그 자리에서 무릎 꿇고 하늘을 봄" % kneel)
	var un := Village.era_unlocks(1)
	check("목조주택" in un and "방앗간" in un and "빵집" in Village.era_unlocks(2), "새로 열린 건물: %s (v5: 빵집은 읍내 — 공용 화덕을 넓힘)" % ", ".join(un))
	check(not v.giant_reveal(), "점수가 다시 찰 때까지 또 계시 없음")
	var c := through_bytes(v)
	check(c.era == 1 and has_line(c, "새 시대를 열었다"), "저장/불러오기: 시대 1 · 연대기 줄")
	var t0 := v.t
	var built := false
	while v.t - t0 < 2.0 * Balance.DAY and not built:
		v.advance(600.0)
		for bd in v.buildings:
			if bd.site_type() in ["목조주택", "방앗간", "빵집"]:
				built = true
	check(built, "촌장이 새 시대 건물(목조주택·방앗간·빵집)을 짓기 시작함")


## 시대 속도 (BALANCE v2 '마을 1.8일' · PROGRESSION '~2일'): 새 넓은 세상 + 기본 키트, 거인이 내내 지켜봐도 (창세의 날 ×12 · 배속)
## 첫날이 끝날 때는 아직 개척기 — 지켜봄 100%는 하루 ERA_WATCH_HOURS까지 (예전엔 1일차 저녁에 마을이 됐다)
func test_era_pace() -> void:
	var jw := JarWorld.create(7, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y, Kits.make())
	v.watching = true
	var k1 := v.era_watch_k(Balance.HOUR)
	var k2 := v.era_watch_k(Balance.HOUR)
	var k3 := v.era_watch_k(Balance.HOUR)
	check(is_equal_approx(k1, 1.0) and is_equal_approx(k2, 1.0) and is_equal_approx(k3, Balance.OFFLINE_ERA),
		"지켜봄 100%%는 하루 %.0f시간까지 (%.2f · %.2f · %.2f)" % [Balance.ERA_WATCH_HOURS, k1, k2, k3])
	v.era_watch_day = -1
	v.era_watch_secs = 0.0
	var end_day1 := Balance.DAY - v.start_clock          # 2일차 00:00
	while v.t < end_day1 - 0.5:
		v.advance(minf(Balance.HOUR, end_day1 - v.t))
	check(v.era == 0 and not v.era_full() and v.era_pts < Balance.ERA_NEED[0] * 0.8,
		"내내 지켜봐도 1일차가 끝날 때 아직 개척기 (점수 %.0f / %.0f)" % [v.era_pts, Balance.ERA_NEED[0]])
	while not v.era_full() and v.t < 12.0 * Balance.DAY:
		v.advance(Balance.HOUR)
	var d := v.t / Balance.DAY
	check(v.era_full() and d >= 3.0 and d <= 9.0, "마을 시대 점수가 차는 때: 시작에서 %.2f일 (BALANCE v5: 병 3~9일 = 현실 1일차 — 예전 1~2일)" % d)


func test_offline_no_auto_reveal() -> void:
	var v := aware_proto()
	v.advance(Balance.HOUR)
	v.era_pts = Balance.ERA_NEED[0]
	var c := CatchUp.new(v, 12.0 * Balance.HOUR, 12.0 * Balance.HOUR)
	c.run()
	check(v.era == 0 and v.revelation_pending(), "비운 12시간 동안 계시는 저절로 오지 않는다 (GD 14)")
	check(not v.giant_reveal(), "거인이 보고 있지 않으면 계시를 내릴 수 없다")
	var l := c.finish()
	var w := " ".join(PackedStringArray(l.get("waiting", [])))
	check(w.contains("계시"), "돌아온 편지 '기다리는 것'에 계시 (%s)" % w)
	v.auto_reveal = true
	v.watching = false
	v._update_era(1.0)
	check(v.era == 0, "auto_reveal(시험용)도 거인이 없을 땐 안 함")
	v.watching = true
	check(v.giant_reveal() and v.era == 1, "돌아와서 [계시] → 시대 1")


func test_revelation_world() -> void:
	Village.start_aware = true
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var a := jw.place_kit(sp[0].x, sp[0].y)
	var b := jw.place_kit(sp[1].x, sp[1].y)
	Village.start_aware = false
	a.water.offline = true
	b.era_pts = Balance.ERA_NEED[0]
	jw.advance(10.0)
	check(b.revelation_pending() and not a.revelation_pending(), "넓은 세상: 점수가 찬 무리만 계시를 기다림")
	check(b.giant_reveal() and b.era == 1 and a.era == 0, "그 무리만 시대가 오른다")


# ───────────────────────── A10 연대기 ─────────────────────────
func test_chronicle_recent_myth() -> void:
	var v := aware_proto()
	v.advance(1.5 * Balance.DAY)
	var g := Chronicle.recent([v], 500)
	var ok := not g.is_empty()
	var last_t := INF
	var last_day := 1 << 30
	var n := 0
	for grp: Dictionary in g:
		ok = ok and int(grp["day"]) < last_day
		last_day = int(grp["day"])
		for e: Dictionary in grp["entries"]:
			ok = ok and float(e["t"]) <= last_t and v.cal_day(float(e["t"])) == int(grp["day"])
			last_t = float(e["t"])
			n += 1
	check(ok and n == v.book.size(), "최근: 최신부터 · 날(%d묶음)마다 · 줄 %d개" % [g.size(), n])
	check(Chronicle.recent([v], 5)[0]["entries"].size() <= 5, "최근: 줄 수 상한 (더 보기)")
	var m := Chronicle.myth(v)
	check(m.size() >= 2 and m[0].contains("조상 열 명"), "창세 신화 = 첫 기록 (%d줄)" % m.size())
	v.myth = ["태초에 {c:이/가} 어둠 속에 붉은 별 하나를 심었다."]
	var mw := WatcherName.of(v) if v.aware else WatcherName.UNKNOWN
	check(Chronicle.myth(v) == PackedStringArray(["태초에 %s이 어둠 속에 붉은 별 하나를 심었다." % mw]), "창조가 적은 신화가 있으면 그것 (부르는 말로: %s)" % mw)
	var e := Village.new()
	check(Chronicle.myth(e).is_empty() and Chronicle.recent([e]).is_empty(), "기록이 없으면 빈 자리 (화면은 부드러운 안내)")
	Village.start_aware = true
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var a := jw.place_kit(sp[0].x, sp[0].y)
	var b := jw.place_kit(sp[1].x, sp[1].y)
	Village.start_aware = false
	a.settlement_name = "첫 무리"
	b.settlement_name = "둘째 무리"
	a.log_line("첫 무리의 일")
	b.log_line("둘째 무리의 일")
	var wg := Chronicle.recent(jw.settlements)
	var wheres := {}
	for grp: Dictionary in wg:
		for x: Dictionary in grp["entries"]:
			wheres[x["where"]] = true
	check(wheres.has("첫 무리") and wheres.has("둘째 무리"), "넓은 세상: 모든 무리의 줄 + 무리 이름")


func test_chronicle_people() -> void:
	Village.start_aware = true
	var jw := JarWorld.create(3, WorldCfg.SMALL_SIZE)
	var sp: Array[Vector2] = jw.recommended_kit_spots()
	var v := jw.place_kit(sp[0].x, sp[0].y)
	Village.start_aware = false
	v.water.offline = true
	jw.advance(2.0 * Balance.DAY)
	var old: Resident = v.people[0]
	for r in v.people:
		if r.age > old.age:
			old = r
	var old_name := old.name
	v.kill(old, "노환")
	var p: Variant = jw.split_spot(v)
	var nv: Village = null
	if p != null and not v.split_movers().is_empty():
		nv = jw.split_out(v, (p as Vector2).x, (p as Vector2).y)
	if nv == null:                       # 분가할 젊은 부부가 아직 없으면: 새 무리 하나에 두 사람을 옮김 (같은 기록 길)
		Village.start_aware = true
		nv = jw.place_kit(sp[1].x, sp[1].y)
		Village.start_aware = false
		nv.settlement_name = "새 무리"
		var movers: Array[Resident] = []      # 새 무리의 번호와 겹치지 않는 두 사람 (v5: 첫 아기가 일찍 태어나 마지막 두 사람의 번호가 새 무리 번호와 겹칠 수 있다)
		for i in range(v.people.size() - 1, -1, -1):
			if movers.size() < 2 and nv.person(v.people[i].id) == null:
				movers.append(v.people[i])
		v.move_people_to(nv, movers)
	var moved := 0
	for r in nv.people:
		for dd: Dictionary in v.departed:
			if int(dd["id"]) == r.id:
				moved += 1
	var d := Chronicle.people(v, jw)
	var alive: Array = d["alive"]
	var dead: Array = d["dead"]
	var left: Array = d["left"]
	check(alive.size() == v.people.size() and alive.all(func(x: Dictionary) -> bool: return x["r"] != null and not (x["r"] as Resident).dead), "살아 있음 %d명 (모두 살아 있음)" % alive.size())
	var sorted := true
	for i in range(1, alive.size()):
		sorted = sorted and int(alive[i - 1]["age"]) >= int(alive[i]["age"])
	check(sorted, "살아 있음: 나이 많은 순")
	check(dead.any(func(x: Dictionary) -> bool: return x["name"] == old_name and String(x["note"]).contains("잠듦")), "잠듦: %s (%s)" % [old_name, dead[0]["note"] if not dead.is_empty() else "-"])
	check(not left.is_empty() and left.size() == moved, "분가로 떠남 %d명 (새 무리에 간 사람 %d명)" % [left.size(), moved])
	check(not left.is_empty() and left[0]["r"] != null and left[0]["v"] == nv and String(left[0]["note"]).contains(nv.settlement_name), "떠난 사람 → 새 무리에서 찾아 얼굴·상세 (%s)" % (left[0]["note"] if not left.is_empty() else "-"))
	var b := through_bytes(v)
	check(b.departed.size() == v.departed.size(), "저장/불러오기: 떠난 사람 기록 그대로")


func test_codex() -> void:
	var v := aware_proto()
	var rows := Codex.entries([v])
	check(rows.size() == Codex.ENTRIES.size() and rows.size() >= 25, "도감 %d칸 (DISCOVERIES 25종 + 지금 있는 발견)" % rows.size())
	var ids := rows.map(func(r: Dictionary) -> String: return r["id"])
	check("salt" in ids and "koji" in ids and "blue_powder" in ids and "spotted_mushroom" in ids, "소금·누룩·푸른 가루·얼룩버섯 칸")
	check(rows.all(func(r: Dictionary) -> bool: return not r["known"] and String(r["hint"]) != ""), "처음엔 모두 실루엣 + 힌트 한 줄")
	v.advance(Balance.DAY)
	var who: Resident = v.people[0]
	v.salt_known = true
	v.note_discovery("salt", who)
	v.mold.koji_known = true             # 기록 없이 상태만 (옛 저장)
	rows = Codex.entries([v])
	var salt: Dictionary = rows.filter(func(r: Dictionary) -> bool: return r["id"] == "salt")[0]
	var koji: Dictionary = rows.filter(func(r: Dictionary) -> bool: return r["id"] == "koji")[0]
	check(salt["known"] and salt["who"] == who.name and int(salt["day"]) == v.cal_day(v.t), "소금: %s" % Codex.credit(salt))
	check(koji["known"] and koji["who"] == "", "누룩 (발견 기록이 없는 옛 상태도 앎): %s" % Codex.credit(koji))
	check(Codex.count([v]) == Vector2i(2, Codex.ENTRIES.size()), "발견 2 / %d" % Codex.ENTRIES.size())
	var b := through_bytes(v)
	check(b.discoveries.has("salt") and String(b.discoveries["salt"]["name"]) == who.name, "저장/불러오기: 발견한 사람 그대로")
	var s := proto(5)
	s.advance(10.0)
	s.note_discovery("koji", s.people[1])
	check(s.discoveries["koji"]["name"] == s.people[1].name and Codex.knows(s, "koji"), "note_discovery → 도감")


# ───────────────────────── 화면 (연대기 시트 · 제단 [계시]) ─────────────────────────
func test_sheets() -> void:
	var v := aware_proto()
	v.advance(Balance.DAY)
	v.kill(v.people[v.people.size() - 1], "노환")
	var sh := ChronicleSheet.new()
	run.root.add_child(sh)
	sh.setup(v, null)
	var counts: Array = []
	for i in ChronicleSheet.TABS.size():
		sh.open(i)
		counts.append(sh.body.get_child_count())
	check(counts.all(func(c: int) -> bool: return c > 0), "연대기 시트: 탭 넷 모두 내용 (%s)" % str(counts))
	sh.open(2)
	var btns := 0
	var enabled := 0
	for g in sh.body.get_children():
		if g is GridContainer:
			for b in g.get_children():
				if b is Button:
					btns += 1
					if not (b as Button).disabled:
						enabled += 1
	check(btns == v.people.size() + v.dead.size() and enabled == v.people.size(), "사람들: 살아 있는 사람만 누를 수 있음 (%d / %d)" % [enabled, btns])
	var got: Array = []
	sh.resident_pressed.connect(func(q: Village, r: Resident) -> void: got.append(r))
	for g in sh.body.get_children():
		if g is GridContainer:
			for b in g.get_children():
				if b is Button and not (b as Button).disabled and got.is_empty():
					(b as Button).pressed.emit()
	check(got.size() == 1 and (got[0] as Resident) in v.people, "살아 있는 사람을 누르면 주민 상세로 (신호)")
	sh.close()
	run.root.remove_child(sh)
	sh.free()
	var al := AltarSheet.new()
	run.root.add_child(al)
	v.era_pts = 0.0
	v.revelation = {}
	al.setup(v)
	al.open()
	check(al.reveal_box.get_child_count() == 0, "제단 시트: 점수가 차기 전엔 [계시] 칸 없음")
	v.era_pts = Balance.ERA_NEED[0]
	v.advance(2.0)
	al._sig = ""
	al._refresh()
	check(al.reveal_box.get_child_count() == 1, "점수가 차면 제단 시트 맨 위에 빛나는 [계시]")
	al._on_reveal()
	check(v.era == 1 and al.reveal_box.get_child_count() == 0, "[계시 내리기] (장면 없이) → 시대 1 · 칸 사라짐")
	run.root.remove_child(al)
	al.free()
	var u := proto()
	var al2 := AltarSheet.new()
	run.root.add_child(al2)
	al2.setup(u)
	al2.open()
	var txt := ""
	for c in al2.offer_box.get_children():
		if c is Label:
			txt += (c as Label).text
	check(txt.contains("제단이 없어요"), "깨닫기 전 제단 시트: \"%s\"" % txt)
	run.root.remove_child(al2)
	al2.free()
