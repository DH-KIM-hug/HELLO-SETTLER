## 거인의 손 테스트 — ROADMAP B6 (sim/giant_hand.gd): 물 뿌리기 · 손으로 감싸기 · 커튼 3단 · 유리 닦기 · 핀셋.
## docs/WORLD_EVENTS.md 4.2 (병 밖 — 무료·쿨타임) · 4.3 (뚜껑을 열고) · 7.1 (서툰 핀셋) · 기획서 6.3 · 6.4 (커튼: 증발·강·자람·온기).
## 효과 · 쿨타임 · 뚜껑 규칙 · 깨닫기 전/뒤 반응 · 연대기 · 금지어 · 저장·결정론. tests/run.gd가 부름 (`-- hand` = 이것만, 1분 안).
extends RefCounted

const CT := preload("res://tests/crisis_tests.gd")

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
	print("== 거인의 손 — 물 뿌리기 · 감싸기 · 커튼 · 유리 닦기 · 핀셋 (B6)")
	run.timed(self, ["test_spray", "test_spray_flood", "test_cup", "test_curtain", "test_curtain_frost_and_river", "test_wipe",
		"test_tweeze", "test_unaware", "test_save_and_determinism", "test_words"])


static func village(aware := true, month := 7, seed_v := 7) -> Village:
	return CT.village("온대", month, 15, seed_v, aware)


## 낮 (병 안의 볕) / 밤이 될 때까지 10분씩
static func to_light(v: Village, light: bool) -> void:
	for i in 200:
		if GiantHand.is_light(v.hour_now()) == light and GiantHand.is_light(v.water.hour_now()) == light:
			return
		v.advance(600.0)


## 마을 곁 마른 빈 땅 (물·건물·모닥불에서 떨어진 곳)
static func dry_spot(v: Village) -> Vector2:
	var best := v.center + Vector2(7, 7)
	var bw := INF
	for rr in range(5, 16, 2):
		for i in 12:
			var a := TAU * i / 12.0 + 0.3
			var p := v.center + Vector2(cos(a), sin(a)) * rr
			if not v.water.inside(p.x, p.y, 5.0) or v.water_at(p.x, p.y) or SmallCrises.by_water(v, p):
				continue
			if not v.buildings.all(func(b: Building) -> bool: return Vector2(b.x, b.y).distance_to(p) > 4.5):
				continue
			if p.distance_to(v.fire) < 5.0 or p.distance_to(v.altar_pos) < 5.0:
				continue
			var w := v.wetness(p.x, p.y)
			if w < bw:
				bw = w
				best = p
	return best


static func water_sum(v: Village) -> float:
	var s := 0.0
	for k in v.water.cells:
		s += v.water.w[k]
	return s


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


func _belief(v: Village) -> float:
	var s := 0.0
	for r in v.people:
		s += r.belief
	return s


# ───────────────────────── 물 뿌리기 ─────────────────────────
func test_spray() -> void:
	var v := village()
	var p := dry_spot(v)
	var fb := CT.farm_near(v, p)
	var r0 := v.spray_water(p)
	check(not bool(r0["ok"]) and String(r0["why"]).contains("뚜껑"), "물 뿌리기는 뚜껑을 연 채로만 (병의 법칙)")
	v.open_lid()
	var w0 := water_sum(v)
	var dep0 := v.water.depth(v.water.idx(p.x, p.y))
	var belief0 := _belief(v)
	var bk := v.book.size()
	var dry := v.wetness(fb.x, fb.y) < GiantHand.SPRAY_DRY
	var r1 := v.spray_water(p)
	var w1 := water_sum(v)
	print("  뿌린 물 %.3f (물 합 %.3f → %.3f) · 젖음 %.2f · 밭 %d" % [float(r1["water"]), w0, w1, v.wetness(fb.x, fb.y), int(r1["fields"])])
	check(bool(r1["ok"]) and float(r1["water"]) > 0.0 and absf((w1 - w0) - float(r1["water"])) < 1e-3, "거인의 물이 병에 들어온다 (물의 합이 그만큼 는다)")
	check(v.water.depth(v.water.idx(p.x, p.y)) > dep0, "누른 자리 땅이 젖는다")
	check(dry and int(r1["fields"]) == 1 and GiantHand.farm_mult(v, fb) > GiantHand.grow_mult(v) * 1.2, "마른 밭은 물을 반겨 하루 동안 더 잘 자람 (×%.1f)" % GiantHand.SPRAY_FIELD_MULT)
	check(_belief(v) > belief0 and _lines(v, bk).any(func(t: String) -> bool: return t.contains("물을 뿌려")), "깨달은 마을: 믿음↑ · 처음 쓴 날 연대기")
	check(v.people.any(func(q: Resident) -> bool: return q.say.contains("밭") or q.say.contains("물")), "주민이 반응 (\"마른 밭이 살아난다!\")")
	var r2 := v.spray_water(p + Vector2(8, 0))
	check(not bool(r2["ok"]) and String(r2["why"]).contains("채우"), "쿨타임 (%.0f초) 동안은 다시 못 뿌림" % GiantHand.SPRAY_COOLDOWN)
	v.advance(GiantHand.SPRAY_COOLDOWN + 1.0)
	if not v.air.lid_open:
		v.open_lid()
	# 불 끄기: 모깃불 곁에 뿌림
	var fp := p + Vector2(0, -6)
	v.smalls.smokes.append({"x": fp.x, "y": fp.y, "until": v.t + 3.0 * H})
	var sm0 := v.air.smoke
	var r3 := v.spray_water(fp)
	check(int(r3["fires_out"]) == 1 and float(v.smalls.smokes.back()["until"]) <= v.t and v.air.smoke <= sm0, "피우던 불(모깃불)을 끈다 · 연기도 조금 걷힘")
	# 하루 뒤: 물을 반긴 밭은 원래대로
	v.advance(GiantHand.SPRAY_FIELD_TIME + 120.0)
	check(v.hand.watered.is_empty(), "물을 반긴 기운은 하루 뒤 끝남")
	# 같은 기적이 잦으면 감동↓
	var q := village()
	q.open_lid()
	var gains: Array = []
	for i in 3:
		var b0 := _belief(q)
		q.spray_water(dry_spot(q) + Vector2(i * 7.0 - 7.0, 0) if i != 1 else q.center + Vector2(0, 9))
		gains.append(_belief(q) - b0)
		q.advance(GiantHand.SPRAY_COOLDOWN + 1.0)
		if not q.air.lid_open:
			q.open_lid()
	check(float(gains[0]) > float(gains[1]) and float(gains[1]) > float(gains[2]), "그날 거듭될수록 감동이 덜함 (믿음 +%.3f · +%.3f · +%.3f)" % gains)


func test_spray_flood() -> void:
	var v := village()
	var p := dry_spot(v)
	var fb := CT.farm_near(v, p + Vector2(0.5, 0))
	fb.timer = 30.0
	v.open_lid()
	var fear0 := v.fear
	var floods := []
	for i in 3:
		var r := v.spray_water(p)
		floods.append(bool(r["flood"]))
		v.advance(GiantHand.SPRAY_COOLDOWN + 1.0)
		if not v.air.lid_open:
			v.open_lid()
	print("  세 번 뿌림: 넘침 %s · 두려움 %.1f → %.1f · 깊이 %.3f" % [str(floods), fear0, v.fear, v.water.depth(v.water.idx(p.x, p.y))])
	check(not floods[0] and not floods[1] and floods[2], "한 시간 안에 같은 자리 세 번째 = 넘침 (지나친 기적)")
	check(fb.timer == 0.0 and fb.ready_at > v.t - 120.0, "넘친 물에 밭이 쓸려 감")
	check(v.fear > fear0, "넘치면 두려움↑")
	check(v.dead.is_empty() and v.check_invariants().is_empty(), "아무도 죽지 않음 · 마을 규칙 그대로")
	check(_lines(v).any(func(t: String) -> bool: return t.contains("물바다")), "연대기: 물바다")
	# 시간이 지나면 같은 자리를 다시 적셔도 괜찮다
	var w := village()
	var wp := dry_spot(w)
	w.open_lid()
	w.spray_water(wp)
	w.advance(GiantHand.SPRAY_SOAK + 60.0)
	w.open_lid()
	var rr := w.spray_water(wp)
	check(bool(rr["ok"]) and not bool(rr["flood"]), "한 시간이 지나면 같은 자리라도 넘치지 않음")


# ───────────────────────── 손으로 감싸기 ─────────────────────────
func test_cup() -> void:
	var v := village(true, 1)                      # 한겨울
	to_light(v, true)
	var t0 := Health.temperature_at(v, v.center.x, v.center.y)
	var belief0 := _belief(v)
	var bk := v.book.size()
	var r := v.cup_hands()
	var t1 := Health.temperature_at(v, v.center.x, v.center.y)
	print("  겨울 낮 기온 %.1f° → 감싸면 %.1f°" % [t0, t1])
	check(bool(r["ok"]) and absf(t1 - t0 - GiantHand.CUP_WARM) < 0.01 and not v.air.lid_open, "뚜껑을 열지 않고 병 전체 +%.0f°" % GiantHand.CUP_WARM)
	check(_belief(v) > belief0 and _lines(v, bk).any(func(t: String) -> bool: return t.contains("손이 세상을 감싸")), "추울 때 감싸면 믿음↑ · 첫 연대기")
	check(absf(v.water.evap_k() - (GiantHand.CUP_EVAP * (GiantHand.CURTAIN_EVAP[0] as float))) < 1e-6, "손이 유리를 덮어 그동안 증발 ×%.1f" % GiantHand.CUP_EVAP)
	var r2 := v.cup_hands()
	check(not bool(r2["ok"]) and String(r2["why"]).contains("온기"), "온기가 남은 동안은 다시 못 함 (쿨타임)")
	v.advance(GiantHand.CUP_TIME + 60.0)
	var t2 := Health.temperature_at(v, v.center.x, v.center.y)
	check(v.water.cup_left == 0.0 and absf(v.water.evap_k() - 1.0) < 1e-6, "한 시간(병 시계) 뒤 끝남 (기온 %.1f°)" % t2)
	# 하루 4번째부터 두려움
	var q := village(true, 1)
	var fears: Array = []
	for i in 4:
		var f0 := q.fear
		var rq := q.cup_hands()
		fears.append(q.fear - f0)
		if i == 0 or i == 3:
			check(bool(rq["ok"]) and bool(rq["fear"]) == (i >= GiantHand.CUP_FREE_PER_DAY), "감싸기 %d번째: %s" % [i + 1, "두려움↑" if i >= 3 else "괜찮음"])
		if i == 3:
			check(q.people.any(func(r3: Resident) -> bool: return r3.say.contains("쥐고")), "4번째에 주민 \"하늘이 우리를 쥐고 있어\"")
		q.advance(GiantHand.CUP_TIME + 30.0)
		if q.cal_day(q.t) != int(q.hand.cups[0]):
			break
	check(fears.size() == 4 and float(fears[3]) > 0.0 and float(fears[0]) <= 0.0, "하루 3번까지는 괜찮고 넘으면 두려움↑")


# ───────────────────────── 커튼 ─────────────────────────
func test_curtain() -> void:
	var v := village()
	to_light(v, true)
	var got: Array = []
	v.hand.curtain_changed.connect(func(s: int) -> void: got.append(s))
	var belief0 := _belief(v)
	var fear0 := v.fear
	var t0 := Health.temperature_at(v, v.center.x, v.center.y)
	check(v.curtain() == 0 and GiantHand.grow_mult(v) == 1.0 and v.water.evap_k() == 1.0, "처음엔 열림 — 자람·증발 그대로 (정확히 ×1)")
	var expect := {1: [0.6, 0.85, -2.5], 2: [0.3, 0.6, -5.0]}
	for st: int in [1, 2]:
		var r := v.set_curtain(st)
		var e: Array = expect[st]
		var tt := Health.temperature_at(v, v.center.x, v.center.y)
		check(bool(r["ok"]) and absf(v.water.evap_k() - float(e[0])) < 1e-6 and absf(GiantHand.grow_mult(v) - float(e[1])) < 1e-6 and absf(tt - t0 - float(e[2])) < 0.01,
			"커튼 %s: 증발 ×%.1f · 자람 ×%.2f · 온기 %+.1f° (낮)" % [GiantHand.CURTAIN_NAMES[st], e[0], e[1], e[2]])
	check(got == [1, 2], "바뀔 때마다 curtain_changed(단계) — 방의 3D 커튼이 따라옴")
	check(not v.set_curtain(2)["ok"] and got.size() == 2, "같은 단은 아무 일 없음")
	check(absf(_belief(v) - belief0) < 1e-9 and absf(v.fear - fear0) < 1e-9, "믿음·두려움 영향 없음 (조용한 손)")
	check(v.people.any(func(q: Resident) -> bool: return q.say == "하늘이 흐려졌다"), "주민: \"하늘이 흐려졌다\"")
	# 밤엔 효과 없음
	to_light(v, false)
	var tn := Health.temperature_at(v, v.center.x, v.center.y)
	v.set_curtain(0)
	var tn0 := Health.temperature_at(v, v.center.x, v.center.y)
	v.set_curtain(2)
	check(absf(tn - tn0) < 1e-6 and GiantHand.grow_mult(v) == 1.0 and v.water.evap_k() == 1.0, "밤에는 커튼 효과 없음 (빛이 없으니)")
	# 밭: 반쯤이면 덜 자람
	var a := village()
	var b := village()
	to_light(a, true)
	to_light(b, true)
	var fa := CT.farm_near(a, dry_spot(a))
	var fb := CT.farm_near(b, dry_spot(b))
	b.set_curtain(1)
	a.advance(2.0 * H)
	b.advance(2.0 * H)
	print("  낮 두 시간 밭: 열림 %.1f · 반쯤 %.1f" % [fa.timer + fa.out_total() * 100.0, fb.timer + fb.out_total() * 100.0])
	# v5: 밭 앞 밀은 4분의 1 수레(25)가 쌓여야 나르러 가므로 timer + 쌓인 양으로는 비교가 흔들린다 → 자람 배율로 본다
	check(GiantHand.farm_mult(b, fb) < GiantHand.farm_mult(a, fa), "반쯤이면 밭이 덜 자람 (자람 ×%.2f < ×%.2f)" % [GiantHand.farm_mult(b, fb), GiantHand.farm_mult(a, fa)])


func test_curtain_frost_and_river() -> void:
	var v := village()
	var fb := CT.farm_near(v, dry_spot(v))
	v.set_curtain(2)
	var bk := v.book.size()
	v.advance(1.6 * D)
	print("  낮 닫힘 %.1f시간 · 냉해 %s" % [v.water.curtain_dark / H, str(v.water.curtain_frost)])
	check(v.water.curtain_frost and GiantHand.grow_mult(v) == 0.0 and GiantHand.farm_mult(v, fb) == 0.0, "낮에 닫힘이 12시간 넘게 이어지면 냉해 — 밭이 자라지 않음")
	check(_lines(v, bk).any(func(t: String) -> bool: return t.contains("냉해")) and v.crises.any(func(c: Dictionary) -> bool: return String(c["kind"]) == "frost"), "연대기·알림: 냉해")
	var tm := fb.timer
	v.advance(1.0 * H)
	check(fb.timer == tm, "냉해 동안 밭이 멈춤")
	v.set_curtain(0)
	check(not v.water.curtain_frost and v.water.curtain_dark == 0.0, "커튼을 열면 냉해가 풀림")
	# 증발이 줄면 물이 더 남는다 (볕 드는 쪽 강이 멀리 흐름)
	var sums: Array = []
	for st in [0, 2]:
		var q := village(true, 7, 31)
		q.set_curtain(st)
		q.advance(2.0 * D)
		sums.append(water_sum(q))
	print("  이틀 뒤 병의 물: 열림 %.3f · 닫힘 %.3f" % sums)
	check(float(sums[1]) > float(sums[0]), "닫힘: 증발이 줄어 물이 더 남음 (강이 그늘 쪽처럼 멀리)")


# ───────────────────────── 유리 닦기 ─────────────────────────
func test_wipe() -> void:
	var v := village()
	to_light(v, true)
	var r0 := v.wipe_glass()
	check(not bool(r0["ok"]) and String(r0["why"]).contains("맑"), "맑은 유리는 닦을 것이 없음")
	v.water.glass_dust = 0.8
	v.air.humid = 0.95
	var g0 := GiantHand.grow_mult(v)
	var fog0 := GiantHand.fog_shown(v)
	var bk := v.book.size()
	var h0 := v.air.humid
	var r := v.wipe_glass()
	print("  닦기 전 김 %.2f · 먼지막 0.8 · 자람 ×%.3f → 닦은 뒤 김 %.2f · 자람 ×%.3f" % [fog0, g0, GiantHand.fog_shown(v), GiantHand.grow_mult(v)])
	check(g0 < 0.95, "두꺼운 먼지막은 낮의 볕을 가림 (자람 ×%.2f)" % g0)
	check(bool(r["ok"]) and fog0 > 0.5 and GiantHand.fog_shown(v) < 0.01 and v.water.glass_dust == 0.0, "서린 김·먼지막이 걷힘 (뚜껑을 열지 않음)")
	check(v.air.humid == h0, "병 안 습기는 그대로 (보기만 — WORLD_EVENTS 4.2)")
	check(bool(r["bright"]) and absf(GiantHand.grow_mult(v) - GiantHand.BRIGHT_GROW) < 1e-6, "또렷한 볕 — 반나절 자람 ×%.2f" % GiantHand.BRIGHT_GROW)
	check(_lines(v, bk).any(func(t: String) -> bool: return t.contains("닦으시자")), "첫 연대기: 하늘을 닦으시자")
	var r2 := v.wipe_glass()
	check(not bool(r2["ok"]) and String(r2["why"]).contains("방금"), "쿨타임 (%.0f분)" % (GiantHand.WIPE_COOLDOWN / 60.0))
	v.advance(GiantHand.BRIGHT_TIME + 6.0 * H)
	var raw := maxf(v.air.glass_fog(), v.mold.omen_fog)
	check(v.water.bright_left == 0.0 and v.water.glass_clear < 0.02 and absf(GiantHand.fog_shown(v) - raw) < 0.02, "시간이 지나면 김이 다시 서리고 (닦은 자국이 사라짐) 또렷한 볕도 끝남")
	# 곰팡이로 뿌연 유리
	var m := village()
	m.mold.omen_fog = 1.0
	m.air.humid = 0.3
	check(m.wipe_glass()["ok"] and GiantHand.fog_shown(m) < 0.01, "곰팡이로 뿌연 유리도 닦임 (거인이 다시 잘 봄)")
	# 먼지막은 천천히 쌓이고 뚜껑을 열면 더
	var a := village()
	var b := village()
	b.open_lid()
	a.advance(2.0 * 60.0)
	b.advance(2.0 * 60.0)
	check(b.water.glass_dust > a.water.glass_dust and a.water.glass_dust > 0.0, "먼지막은 천천히 쌓이고 뚜껑이 열리면 더 (방의 먼지)")


# ───────────────────────── 핀셋 ─────────────────────────
func test_tweeze() -> void:
	var v := village()
	var s := v.smalls
	s.force_dust(v)
	s.dust_phase = "roll"
	var c := s.live("dust")[0]
	var r0 := v.tweeze(c.pos())
	check(not bool(r0["ok"]) and String(r0["why"]).contains("뚜껑"), "핀셋은 뚜껑을 연 채로만")
	v.open_lid()
	var bk := v.book.size()
	var b0 := v.buildings.size()
	var r1 := v.tweeze(c.pos() + Vector2(0.3, 0))
	check(bool(r1["picked"]) and String(r1["kind"]) == "dust" and c.state == "gone" and v.buildings.size() == b0, "먼지 뭉치를 집어냄 (깔끔히)")
	check(_lines(v, bk).any(func(t: String) -> bool: return t.contains("집게")), "첫 연대기: 커다란 집게")
	# 떨어진 물건 (나무젓가락 = 통나무 산): 집어냄 · 옮김
	var p := dry_spot(v)
	var dr := SkyDrops.drop(v, "나무젓가락", p)
	check(bool(dr["ok"]), "하늘에서 통나무 산이 떨어짐")
	var o: Dictionary = dr["drop"]
	var rm := {}
	for i in 8:                           # 비어 있는 쪽으로 (v5: 걸음이 느려 둘레에 짓는 터·사람이 다르게 남아 있을 수 있다)
		var to := p + Vector2(20, 0).rotated(TAU * i / 8.0)
		rm = v.tweeze(p, to)
		if bool(rm["ok"]):
			break
	var moved := Vector2(float(o["x"]), float(o["y"])).distance_to(p)
	check(bool(rm["ok"]) and bool(rm["moved"]) and o in v.drops and absf(moved - GiantHand.MOVE_MAX) < 0.01, "떨어진 물건을 짧은 거리(%.0f칸)만 옮겨 놓음" % GiantHand.MOVE_MAX)
	var at := Vector2(float(o["x"]), float(o["y"]))
	var rp := v.tweeze(at)
	check(bool(rp["picked"]) and not o in v.drops, "떨어진 물건을 집어냄")
	# 바위 하나 옮기기 · 집 위에는 못 놓음
	var rk: Dictionary = {}
	for q: Dictionary in v.rocks:
		if int(q["amt"]) > 0 and int(q.get("res", 0)) == 0:
			rk = q
			break
	if rk.is_empty():
		rk = {"x": p.x - 4.0, "y": p.y, "amt": 20, "res": 0}
		v.rocks.append(rk)
	var house: Building = null
	for b in v.buildings:
		if b.is_house():
			house = b
			break
	var rp0 := Vector2(float(rk["x"]), float(rk["y"]))
	if house != null and rp0.distance_to(Vector2(house.x, house.y)) <= GiantHand.MOVE_MAX:
		var rh := v.tweeze(rp0, Vector2(house.x, house.y))
		check(not bool(rh["ok"]) and String(rh["why"]).contains("내려놓을"), "집 위에는 내려놓을 수 없음")
	var rr := v.tweeze(rp0 + Vector2(0.2, 0), rp0 + Vector2(0, 2.5))
	if bool(rr["ok"]):
		check(bool(rr["moved"]) and String(rr["kind"]) == "rock" and Vector2(float(rk["x"]), float(rk["y"])).distance_to(rp0) > 2.0, "바위 하나를 옮김")
	else:
		check(String(rr["why"]) != "", "바위를 옮길 자리가 막힘 (%s)" % rr["why"])
	# 서툰 핀셋: 멀리서 집으면 곁의 집이 짓눌림
	var w := village()
	w.smalls.force_dust(w)
	w.smalls.dust_phase = "roll"
	var hs: Building = null
	for b in w.buildings:
		if b.is_house() and b.built:
			hs = b
			break
	if hs == null:
		hs = w.add_building("오두막", 6.0, -6.0, true)
	var cc := w.smalls.live("dust")[0]
	cc.size = 1.0
	cc.x = hs.x + 3.0
	cc.y = hs.y
	w.open_lid()
	var rc := w.tweeze(Vector2(hs.x + 0.4, hs.y))
	check(bool(rc["picked"]) and String(rc["crushed"]) != "" and not hs in w.buildings, "멀리서 집으면 서툴러 곁의 %s 부서짐" % str(rc["crushed"]))
	check(w.dead.is_empty() and w.check_invariants().is_empty(), "다친 사람은 없다 · 마을 규칙 그대로")
	# 날벌레는 그대로 (B5)
	var g := village()
	g.smalls.force_gnats(g)
	g.open_lid()
	var rg := g.tweeze(g.smalls.live("gnat")[0].pos())
	check(bool(rg["picked"]) and String(rg["kind"]) == "gnat", "날벌레도 핀셋으로 (B5 그대로)")
	var e := village()
	e.open_lid()
	var re := e.tweeze(e.center + Vector2(40, 40))
	check(not bool(re["ok"]) and String(re["why"]).contains("없어요"), "집을 것이 없으면 아무 일 없음")


# ───────────────────────── 깨닫기 전 ─────────────────────────
func test_unaware() -> void:
	var u := village(false, 1)
	check(not u.aware, "깨닫기 전 마을")
	to_light(u, true)
	var bk := u.book.size()
	u.open_lid()
	var b0 := _belief(u)
	var acts := [func() -> void: u.spray_water(dry_spot(u)), func() -> void: u.cup_hands(),
		func() -> void:
			u.water.glass_dust = 0.6
			u.wipe_glass(),
		func() -> void:
			u.smalls.force_dust(u)
			u.smalls.dust_phase = "roll"
			u.tweeze(u.smalls.live("dust")[0].pos())]
	var gains: Array = []
	for f: Callable in acts:
		u.wonder = 0.0
		u.awaken_at = -1.0
		f.call()
		gains.append(u.wonder)
	print("  경이: 물 %.1f · 감싸기 %.1f · 닦기 %.1f · 핀셋 %.1f" % gains)
	check(gains.all(func(g: float) -> bool: return g > 0.0) and absf(_belief(u) - b0) < 1e-9, "깨닫기 전: 손짓마다 경이가 쌓임 (믿음이 아니라)")
	var lines := _lines(u, bk) + _said(u)
	check(not lines.any(func(t: String) -> bool: return t.contains("거인")) and lines.size() >= 4, "깨닫기 전: 연대기·말에 '거인' 이야기 없음 (%d줄)" % lines.size())


# ───────────────────────── 저장 · 결정론 ─────────────────────────
func _sig(v: Village) -> String:
	var h := v.hand
	var w := v.water
	var out := "%d|%.4f|%s|%.4f|%.6f|%.4f|%.4f|%.3f,%.3f|" % [w.curtain, w.curtain_dark, str(w.curtain_frost), w.cup_left, w.glass_dust, w.glass_clear, w.bright_left, h.spray_cd, h.wipe_cd]
	out += str(h.soaks) + str(h.watered) + str(h.sprays) + str(h.cups) + str(h.firsts) + str(h.stats)
	return out + "|%d|%.3f|%.5f" % [v.rng.state, v.food_total(), water_sum(v)]


func _busy(v: Village) -> void:
	v.open_lid()
	v.spray_water(dry_spot(v))
	v.cup_hands()
	# (6c-1) 커튼은 도구에서 없앰 — 불러오면 열림으로 돌아가므로 쳐 두지 않는다
	v.water.glass_dust = 0.5
	v.wipe_glass()
	CT.farm_near(v, dry_spot(v) + Vector2(0, 1))
	v.close_lid()                                  # 뚜껑은 현실 1분 뒤 저절로 닫히므로 (배속마다 다름) 닫아 두고 비교


func test_save_and_determinism() -> void:
	var v := village(true, 7, 41)
	_busy(v)
	v.advance(30.0 * 60.0)
	var d := v.to_dict()
	check(SaveCodec.errors == 0, "저장할 수 없는 값 없음")
	var w := Village.from_dict(bytes_to_var(var_to_bytes(d)))
	check(_sig(w) == _sig(v), "저장 → 불러오기: 손의 상태가 그대로 (온기·먼지막·쿨타임·적신 자리)")
	v.advance(6.0 * H)
	w.advance(6.0 * H)
	check(_sig(w) == _sig(v), "불러온 뒤 6시간: 같은 결과")
	var od := v.to_dict()
	od.erase("hand")
	var o := Village.from_dict(bytes_to_var(var_to_bytes(od)))
	o.advance(1.0 * H)
	check(o.hand != null and o.hand.firsts.is_empty(), "옛 저장도 읽힌다 (손을 쓴 기록 없이)")
	var sigs := []
	for sp in [0, 3]:
		var q := village(true, 7, 42)
		_busy(q)
		var ck := JarClock.new(q)
		ck.set_speed(sp)
		var dt := 1.0 / 30.0 if sp == 0 else 0.25
		while ck.steps_done < int(1.5 * H):
			ck.tick(dt)
		sigs.append(_sig(q))
	if sigs[0] != sigs[1]:
		print("  ×1 ", sigs[0], "\n  ×8 ", sigs[1])
	check(sigs[0] == sigs[1], "손을 쓴 병: ×1과 ×8 결과가 같다")
	# 따라잡기 (거인이 없을 때 몰아서): 온기·커튼이 그대로 흐름
	var c := village(true, 7, 43)
	c.set_curtain(2)
	c.cup_hands()
	c.water.offline = true
	c.advance(2.0 * D)
	check(c.water.cup_left == 0.0 and c.curtain() == 2 and c.water.curtain_frost, "비운 동안에도 그대로 (온기는 끝나고 커튼은 남음 — 냉해까지)")


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
		var v := village(aware, 1, 51)
		to_light(v, true)
		var said: Array = []
		var whys: Array = []
		whys.append(String(v.spray_water(v.center)["why"]))
		whys.append(String(v.tweeze(v.center)["why"]))
		v.open_lid()
		var p := dry_spot(v)
		CT.farm_near(v, p)
		for i in 3:
			v.spray_water(p)
			said.append_array(_said(v))
			whys.append(String(v.spray_water(p)["why"]))
			v.advance(GiantHand.SPRAY_COOLDOWN + 1.0)
			if not v.air.lid_open:
				v.open_lid()
		for i in 4:
			v.cup_hands()
			said.append_array(_said(v))
			whys.append(String(v.cup_hands()["why"]))
			v.advance(GiantHand.CUP_TIME + 10.0)
		for st in [1, 2, 0]:
			v.set_curtain(st)
			said.append_array(_said(v))
		v.water.glass_dust = 0.7
		v.wipe_glass()
		said.append_array(_said(v))
		whys.append(String(v.wipe_glass()["why"]))
		v.open_lid()
		v.smalls.force_dust(v)
		v.smalls.dust_phase = "roll"
		v.tweeze(v.smalls.live("dust")[0].pos())
		said.append_array(_said(v))
		var dr := SkyDrops.drop(v, "나무젓가락", dry_spot(v) + Vector2(2, 2))
		if bool(dr["ok"]):
			var o: Dictionary = dr["drop"]
			v.tweeze(Vector2(float(o["x"]), float(o["y"])), Vector2(float(o["x"]) + 3.0, float(o["y"])))
			said.append_array(_said(v))
		v.set_curtain(2)
		v.advance(1.6 * D)
		said.append_array(_said(v))
		var all_t := _lines(v) + said + whys
		var bad := _bad(all_t, not v.aware)
		check(bad == "", "%s: 손의 말·연대기·알림·안내에 금지어 없음%s (%d줄) %s" % ["깨달은 마을" if aware else "깨닫기 전", "" if aware else " · 거인 이야기 없음", all_t.size(), bad])
