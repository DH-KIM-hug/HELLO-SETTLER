## 6단계 — 넓은 세상 테스트 (tests/run.gd가 부름). 세상 만들기·키트·물 보존·결정성·먼 호수·안개·탐험·만남·시간 예산.
extends RefCounted

var run: SceneTree          # tests/run.gd (check · words_ok)
var quick := false
const SLOW: Array = ["test_world_seeds"]           # 오래 걸리는 통계 시험 — run.gd의 long·전체 모드에서만 (quick은 건너뜀)


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	run.timed(self, ["test_world_seeds", "test_world_determinism", "test_world_water", "test_far_lakes", "test_kits_and_fog", "test_two_kits_contact", "test_world_rotation", "test_world_budget",
		"test_sim_speed", "test_world_carriers", "test_dew_rhythm"])


## BALANCE v5 · E0 (사용자 2026-11-07: "게임 화면에서 아무도 짐을 들고 있지 않았다"): 넓은 세상 키트 마을에서도 첫 병 하루 안에
## 짐을 든 사람이 보인다 — 걸음이 현실 사람 걸음이 되어 나르는 동안이 화면에 남는다 (예전엔 병 몇 초 만에 끝나 거의 안 보였다)
func test_world_carriers() -> void:
	print("== 넓은 세상: 첫날 짐 나르는 사람이 보인다")
	var jw := JarWorld.create_with_kit(23, WorldCfg.SIZE, Kits.make([]))
	var v := jw.primary()
	var seen := {}
	var samples := 0
	var with_carry := 0
	for i in 24 * 6:
		jw.advance(600.0)
		samples += 1
		var any := false
		for r in v.people:
			if r.carry != "":
				seen[r.carry] = int(seen.get(r.carry, 0)) + 1
				any = true
		if any:
			with_carry += 1
	print("  10분마다 본 %d번 중 짐을 든 사람이 있던 때 %d번 · 든 것 %s" % [samples, with_carry, seen])
	check(v.manna_falls == 0 and not v.auto_manna and v.food_total() > 0.0 and int(v.stats["starved"]) == 0,
		"새 세상: 하늘 낟알은 저절로 내리지 않는다 — 시작 건량·죽으로 첫날을 굶지 않고 넘김 (먹을 것 %.0f)" % v.food_total())
	check(with_carry >= samples / 5 and seen.size() >= 2, "첫 병 하루 안에 짐을 든 사람이 자주 보인다 (%d / %d번 · %d가지)" % [with_carry, samples, seen.size()])


static func h_sig(ww: WorldWater) -> String:
	var s := 0.0
	for k in range(0, ww.n * ww.n, 37):
		s += ww.h[k] * (1 + k % 13)
	var v := 0.0
	for c in ww.m * ww.m:
		v += ww.cV[c] * (1 + c % 7) + ww.cS[c] * 3.0
	return "%.6f|%.6f|%d|%d" % [s, v, ww.drips.size(), ww.features.size()]


## 기획서 5.1: 창조마다 새 무작위 세상. 어떤 시드든 좋은 키트 자리(물방울 호수·강·숲 곁)가 여러 곳 + 메이슨 자 돌기 8~12
func test_world_seeds() -> void:
	var n_seeds := 12 if quick else 50
	print("== 넓은 세상 — 무작위 시드 %d개 (지름 %d)" % [n_seeds, WorldCfg.SIZE])
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	var min_rec := 99
	var bad: Array = []
	var nan := false
	var drips_ok := true
	var ms := 0.0
	for i in n_seeds:
		var sd := int(rng.randi() & 0x7fffffff)
		var t0 := Time.get_ticks_usec()
		var jw := JarWorld.create(sd)
		ms += (Time.get_ticks_usec() - t0) / 1000.0
		var ww := jw.water
		var rec := jw.recommended_kit_spots()
		min_rec = mini(min_rec, rec.size())
		if rec.size() < 3:
			bad.append(sd)
		for k in range(0, ww.n * ww.n, 101):
			if is_nan(ww.h[k]) or is_nan(ww.w[k]):
				nan = true
		for c in ww.m * ww.m:
			if is_nan(ww.cV[c]) or ww.cV[c] < 0.0 or is_nan(ww.cS[c]) or ww.cS[c] < 0.0:
				nan = true
		drips_ok = drips_ok and ww.drips.size() >= 8 and ww.drips.size() <= 12
		# 추천 자리마다: 물방울 호수 + 강 + 숲 (kit_spot_ok가 경고 없음) — 그리고 놓을 수 있음
		for sp in rec:
			var r := jw.kit_spot_ok(sp.x, sp.y)
			if not r["ok"] or r["warn"] != "":
				bad.append(sd)
	print("  세상 하나 만들기 평균 %.0f ms (뚜껑 닫기 타임랩스 2일 포함)" % (ms / n_seeds))
	check(min_rec >= 3 and bad.is_empty(), "모든 시드에서 추천 키트 자리 3곳 이상 (가장 적은 세상 %d곳, 실패 시드 %s)" % [min_rec, str(bad)])
	check(not nan, "높이·물·소금에 NaN·음수 없음")
	check(drips_ok, "물방울 돌기 8~12개 (메이슨 자)")
	var a := WorldGen.new_seed()
	var b := WorldGen.new_seed()
	check(a != b, "새 창조마다 새 시드 (%d, %d)" % [a, b])


func test_world_determinism() -> void:
	print("== 넓은 세상 — 같은 시드 → 같은 세상 · 같은 키트 → 같은 무리")
	var sig := func(sd: int) -> String:
		var jw := JarWorld.create(sd)
		var s := h_sig(jw.water)
		var rec := jw.recommended_kit_spots()
		var v := jw.place_kit(rec[0].x, rec[0].y)
		v.water.offline = true
		v.step_dt = 30.0
		jw.advance(0.5 * Balance.DAY)
		s += "|%d|%d|%d|%.6f|%.6f" % [v.people.size(), v.book.size(), v.buildings.size(), jw.water.total_water(), jw.water.total_salt()]
		for p in v.people:
			s += "%.3f,%.3f;" % [p.x, p.y]
		var f := 0
		for q in jw.water.fog.size():
			f += jw.water.fog[q] * (q % 11)
		return s + "|%d" % f
	var a: String = sig.call(11)
	var b: String = sig.call(11)
	var c: String = sig.call(12)
	check(a == b, "시드 11 두 번 → 같은 땅·물·키트 무리·안개 (%d자)" % a.length())
	check(a != c, "시드 12는 다르다")


## E3-7 이슬의 하루 박자 (기획서 4.2b): 돌기 물은 새벽(4~8시)에 몰아서 떨어지고 낮엔 안 떨어진다 — 하루 총량은 예전의
## '늘 같은 빠르기'(DRIP_RATE × (0.6 + 습도) / 분)와 같다 · 시간 조각 크기와 상관없음 · 넓은 세상은 물 + 김이 보존
func test_dew_rhythm() -> void:
	print("== 이슬의 하루 박자 — 새벽에 몰아서, 하루 총량 그대로")
	# 1) 소형 병: 10초씩 흘리며 예전 빠르기를 따로 더해 비교 (8시 → 4일 뒤 8시 + 1시간 — 새벽 창이 끝난 뒤)
	var s := JarWater.new_prototype_world()
	var c0 := s.dew_cum
	var old := 0.0
	var day_rel := 0.0           # 낮 (9~16시)에 떨어진 몫
	var dawn_rel := 0.0          # 새벽 (4~8시)
	var steps := int((4.0 * JarWater.DAY + JarWater.HOUR) / JarWater.SUBSTEP)
	var max_bead := 0.0
	var noon_bead := 1.0
	for i in steps:
		old += JarWater.SUBSTEP / 60.0 * (0.6 + s.humid)
		var before := s.dew_cum
		s.advance(JarWater.SUBSTEP)
		var hr := s.hour_now()
		if hr > 9.0 and hr < 16.0:
			day_rel += s.dew_cum - before
			noon_bead = minf(noon_bead, 1.0 - s.dew_bead())
		elif hr > JarWater.DEW_FROM and hr < JarWater.DEW_TO + 0.1:
			dawn_rel += s.dew_cum - before
		if hr > 2.0 and hr < 4.0:
			max_bead = maxf(max_bead, s.dew_bead())
	var got := s.dew_cum - c0
	# 예전 방식은 그때그때 떨어졌고, 새 방식은 첫 새벽 전(8시 이전 = 시작 전 시간)까지 모인 것을 떨어뜨린다 → 시작 직후 모인 몫(마지막 새벽 뒤 1시간)만 다르다
	var lag := s.dew
	print("  4일: 예전 빠르기 합 %.1f · 떨어진 이슬 %.1f + 아직 모인 김 %.2f · 낮(9~16시)에 떨어진 몫 %.3f · 새벽 %.1f · 새벽 전 물방울 크기 %.2f" % [old, got, lag, day_rel, dawn_rel, max_bead])
	check(absf(got + lag - old) < 1e-6 * old, "모인 김 = 예전에 떨어지던 양 그대로 (차이 %.6f)" % absf(got + lag - old))
	check(absf(got - old) < 0.02 * old, "4일 동안 땅에 떨어진 이슬 = 예전 총량의 ±2%% (%.1f / %.1f = %.4f)" % [got, old, got / old])
	check(day_rel == 0.0 and absf(dawn_rel - got) < 1e-6 * got, "낮엔 안 떨어지고 새벽(4~8시)에 다 떨어진다")
	check(max_bead > 0.6 and noon_bead > 0.999, "새벽 전엔 돌기에 물방울이 크게 맺히고 (%.2f), 한낮엔 없다" % max_bead)
	# 2) 조각 크기: 같은 시간을 한 번에 / 7초씩 흘려도 거의 같다 (10초 조각 안에서 끊긴 것만 다름)
	var a := JarWater.new_prototype_world()
	var b := JarWater.new_prototype_world()
	a.advance(2.0 * JarWater.DAY)
	for i in int(2.0 * JarWater.DAY / 7.0):
		b.advance(7.0)
	b.advance(2.0 * JarWater.DAY - int(2.0 * JarWater.DAY / 7.0) * 7.0)
	check(absf(a.dew_cum - b.dew_cum) < 1e-3 * a.dew_cum, "시간 조각 크기와 상관없음 (한 번에 %.3f · 7초씩 %.3f)" % [a.dew_cum, b.dew_cum])
	# 3) 넓은 세상: 돌기마다 받은 물 = DRIP_RATE × 배율 × 떨어진 이슬 × 김 배율 (거친 칸이 SLICES번에 한 번 받아도) ·
	#    물 보존 (water.md, ROADMAP F-2): 증발·스며듦은 김으로, 이슬·골은 김에서 → 땅의 물 + 김 = 그대로 (뚜껑 닫힘)
	var days := 2 if quick else 4
	var nw: Dictionary = _dew_world(days)
	print("  넓은 세상 %d일 (10시 → 10시): 떨어진 이슬 %.1f · 땅의 물 %.3f → %.3f · 김 %.3f → %.3f · 합 차이 %.6f · 김 배율 %.2f · 돌기 호수 %s · 첫 호수 새벽 전→10시%s" % [
		days, nw["cum"], nw["w0"], nw["water"], nw["v0"], nw["vap"], nw["drift"], nw["ink"], nw["lakes"], nw["swing"]])
	check(nw["all_got"], "10시엔 모든 돌기가 그날 새벽 이슬을 다 받았다 (거친 칸 포함)")
	check(float(nw["v0"]) > 0.0 and float(nw["vap"]) >= 0.0, "뚜껑을 닫을 때 김이 차 있고 (%.3f) 음수가 되지 않는다 (%.3f)" % [nw["v0"], nw["vap"]])
	check(absf(float(nw["drift"])) < 1e-6 * maxf(1.0, float(nw["w0"]) + float(nw["v0"])), "땅의 물 + 김이 그대로 (물은 뚜껑으로만 나감 — 차이 %.6f)" % nw["drift"])
	var big := 0
	for la: Variant in nw["lakes"]:
		if int(la) > 15:
			big += 1
	check(big >= 1, "돌기 호수는 그대로 선다 (%s)" % [nw["lakes"]])


## test_dew_rhythm용: 시드 21 세상을 10시부터 days일 (온·오프라인 번갈아)
func _dew_world(days: int) -> Dictionary:
	var ww := WorldGen.generate(21)
	var sp := ww.spots[0]
	var list: Array[Dictionary] = [{"x": sp.x, "y": sp.y, "r": 36.0}]
	ww.set_interest(list)
	ww.advance(fposmod(10.0 * JarWater.HOUR - ww.clock(), JarWater.DAY))     # 10시부터 (새벽 창이 끝나 모두 받은 뒤)
	var cum0 := ww.dew_cum
	var w0 := ww.total_water()
	var v0 := ww.vapour
	var swing := ""
	for dd in days:
		ww.offline = dd % 2 == 1
		ww.advance(17.0 * JarWater.HOUR)      # 3시: 새벽 전 (호수가 가장 낮을 때)
		var pre_dawn := ww.lake_cells_in(Vector2(ww.drips[0]["x"], ww.drips[0]["y"]), 14.0)
		ww.advance(7.0 * JarWater.HOUR)       # 10시
		swing += " %d→%d" % [pre_dawn, ww.lake_cells_in(Vector2(ww.drips[0]["x"], ww.drips[0]["y"]), 14.0)]
	var lakes: Array = []
	for d: Dictionary in ww.drips:
		lakes.append(ww.lake_cells_in(Vector2(d["x"], d["y"]), 14.0))
	var all_got := true
	for i in ww.drip_k.size():
		all_got = all_got and ww.drip_got[i] == ww.dew_cum
	var wt := ww.total_water()
	return {"lakes": lakes, "cum": ww.dew_cum - cum0, "water": wt, "w0": w0, "v0": v0, "vap": ww.vapour,
		"drift": (wt + ww.vapour) - (w0 + v0), "ink": ww.inflow_k(), "all_got": all_got, "swing": swing}


## 물·소금 보존: 고운 칸 ↔ 거친 칸을 오가도 (마을 둘레가 옮겨 다녀도) 들어온 − 나간 만큼만 바뀐다
func test_world_water() -> void:
	print("== 넓은 세상 — 물·소금 보존 (고운 ↔ 거친 경계·전환 포함)")
	var ww := WorldGen.generate(21)
	var sp := ww.spots[0]
	var sp2 := ww.spots[1]
	var list: Array[Dictionary] = [{"x": sp.x, "y": sp.y, "r": 36.0}]
	ww.set_interest(list)
	var w0 := ww.total_water()
	var s0 := ww.total_salt()
	ww.added = 0.0
	ww.removed = 0.0
	var ok_neg := true
	var days := 2 if quick else 4
	for d in days:
		ww.offline = d % 2 == 1
		ww.advance(Balance.DAY * 0.5)
		# 마을 둘레를 옮긴다 → 고운 ↔ 거친 전환
		var l2: Array[Dictionary] = [{"x": (sp2 if d % 2 == 0 else sp).x, "y": (sp2 if d % 2 == 0 else sp).y, "r": 30.0 + d * 4.0}]
		ww.set_interest(l2)
		ww.advance(Balance.DAY * 0.5)
		for k in ww.fcells:
			if ww.w[k] < 0.0 or ww.salt[k] < 0.0 or ww.halite[k] < 0.0 or is_nan(ww.w[k]):
				ok_neg = false
		for c in ww.m * ww.m:
			if ww.cV[c] < 0.0 or ww.cS[c] < -1e-9 or ww.cHal[c] < -1e-9:
				ok_neg = false
	var w1 := ww.total_water()
	var expect := w0 + ww.added - ww.removed
	print("  물 %.4f → %.4f (들어옴 %.3f · 나감 %.3f → 기대 %.4f) · 소금 %.6f → %.6f" % [w0, w1, ww.added, ww.removed, expect, s0, ww.total_salt()])
	check(absf(w1 - expect) < 1e-5 * w0, "물 총량 = 처음 + 들어온 물 − 나간 물 (차이 %.4f = %.1f ppm, 고운 칸 float32 반올림)" % [absf(w1 - expect), absf(w1 - expect) / w0 * 1e6])
	check(absf(ww.total_salt() - s0) < 1e-4 * maxf(1.0, s0), "소금 총량 보존 (%.6f → %.6f)" % [s0, ww.total_salt()])
	check(ok_neg, "물·소금·암염이 음수/NaN이 되지 않는다")


## 먼 곳(거친 칸)의 호수: 물방울 호수는 남고, 물이 안 들어오는 큰 호수는 줄어들어 소금을 남긴다 (기획서 4.3·4.5)
func test_far_lakes() -> void:
	print("== 넓은 세상 — 먼 호수 (거친 칸만)")
	var ww := WorldGen.generate(5)
	ww.offline = true
	var drip0: Array = []
	var b: Dictionary = ww.basins[0]
	var a0: int = b["area0"]
	var line := "  첫 부은 호수 '%s' %d칸:" % [b["name"], a0]
	var days := 6 if quick else 12
	var gone := -1
	for d in days:
		ww.advance(Balance.DAY)
		var a := ww.basin_area(b)
		line += " %d" % a
		if d == 1:          # 물방울 호수는 처음 부은 물에서 물방울과 증발이 맞는 크기로 하루쯤 자리 잡는다 → 그 뒤로 유지
			for dd: Dictionary in ww.drips:
				drip0.append(ww.lake_cells_in(Vector2(dd["x"], dd["y"]), 14.0))
		if gone < 0 and a < 0.12 * a0:
			gone = d + 1
	print(line + (" (사라진 날 %d일째)" % gone if gone > 0 else ""))
	var kept := 0
	for i in ww.drips.size():
		var d: Dictionary = ww.drips[i]
		if ww.lake_cells_in(Vector2(d["x"], d["y"]), 14.0) >= 0.7 * float(drip0[i]) and int(drip0[i]) > 15:
			kept += 1
	print("  물방울 호수 (2일째 → 끝): %s" % str(drip0))
	check(kept >= ww.drips.size() - 1, "물방울 호수 유지 (%d/%d곳이 2일째 크기의 70%% 이상, 15칸 넘음)" % [kept, ww.drips.size()])
	check(ww.basin_area(b) < 0.7 * a0, "물이 안 들어오는 큰 호수가 줄어든다 (%d → %d칸, %d일)" % [a0, ww.basin_area(b), days])
	if not quick:
		check(gone >= 5 and gone <= 14, "약 1~2주에 사라짐 (%d일째, 소형 병은 약 9일)" % gone)
		var flat: Variant = ww.salt_flat_in(Vector2(b["x"], b["y"]), float(b["r"]) * 1.5)
		check(flat != null, "마른 호수 바닥에 소금 들판 (%s)" % str(flat))


## 키트·안개 (기획서 5.5 · 3.1): 키트를 놓기 전엔 온통 안개, 놓으면 둘레가 걷힘 · 발견 연대기 · 탐험
func test_kits_and_fog() -> void:
	print("== 키트 · 안개 · 탐험")
	var jw := JarWorld.create(3)
	var any := 0
	for q in jw.water.fog.size():
		any += 1 if jw.water.fog[q] != 0 else 0
	check(any == 0, "키트를 놓기 전에는 온 세상이 안개")
	var rec := jw.recommended_kit_spots()
	var r0 := jw.kit_spot_ok(rec[0].x, rec[0].y)
	check(r0["ok"] and r0["warn"] == "", "추천 자리는 놓을 수 있고 경고 없음")
	var edge := jw.kit_spot_ok(jw.water.rr - 5.0, 0.0)
	check(not edge["ok"], "세상 끝 벽 곁은 안 됨 ('%s')" % edge["why"])
	# 물이 없는 곳 찾기 → 경고
	var dry_warn := false
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 200:
		var p := Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300))
		var r := jw.kit_spot_ok(p.x, p.y)
		if r["ok"] and r["warn"] == "곁에 물이 없어요":
			dry_warn = true
			break
	check(dry_warn, "물가가 없는 자리는 경고 (놓을 수는 있음)")
	var v := jw.place_kit(rec[0].x, rec[0].y, Kits.make(["밀밭"]))
	var huts := 0
	for b in v.buildings:
		if b.type == "오두막":
			huts += 1
	check(v.people.size() == 10 and huts == 2 and v.count_type("농장") == 1 and v.store().is_store, "기본 키트 = 10명 · 오두막 2채 · 창고 + 업그레이드(밀밭 — 씨앗)")
	check(jw.water.revealed(v.center.x, v.center.y, 0) and not jw.water.revealed(v.center.x + 120.0, v.center.y, -1), "키트 둘레만 안개가 걷힘")
	check(not jw.kit_spot_ok(v.center.x + 30.0, v.center.y)["ok"], "다른 무리 곁에는 또 놓을 수 없음")
	var near_water := 0
	for k in jw.water.cells_near(v.center, 36.0):
		if jw.water.is_lake(k):
			near_water += 1
	check(near_water > 30, "키트 곁에 물방울 호수 (%d칸)" % near_water)
	v.water.offline = true
	v.step_dt = 30.0
	var fog0 := _revealed(jw.water)
	jw.advance(2.0 * Balance.DAY)
	var fog1 := _revealed(jw.water)
	var lines: Array = []
	for e: Dictionary in v.book:
		lines.append(e["text"])
	var found := lines.filter(func(t: String) -> bool: return t.contains("불렀다") or t.contains("하얀 바위"))
	print("  탐험 %d번 · 본 안개 칸 %d → %d · 발견 연대기 %d줄" % [int(v.stats.get("explore", 0)), fog0, fog1, found.size()])
	# (A28) 첫 한 시간의 걸음 덤(WALK_OPENING)도 없어져 첫 탐험이 더 짧다 — 예전 4번·1.5배
	check(int(v.stats.get("explore", 0)) >= 2 and fog1 > fog0 * 1.25, "주민이 탐험하며 안개가 걷힌다 (탐험 %d번 — v5: 현실 사람 걸음이라 한 번이 길다, 예전 6번 이상)" % int(v.stats.get("explore", 0)))
	check(found.size() >= 2, "처음 본 호수·강·흰 바위를 연대기에 적는다 (%d줄)" % found.size())
	var wbad: String = run.words_ok(lines)
	check(wbad == "", "연대기에 금지어 없음 %s" % wbad)
	var bad := v.check_invariants()
	check(bad.is_empty(), "무리의 물자·주민 값 정상 %s" % ("" if bad.is_empty() else str(bad.slice(0, 3))))


static func _revealed(ww: WorldWater) -> int:
	var n := 0
	for q in ww.fog.size():
		if ww.fog[q] != 0:
			n += 1
	return n


## 키트 두 개 = 서로 모르는 두 무리 → 탐험하다 만난다 (기획서 5.5 · 13.1)
func test_two_kits_contact() -> void:
	print("== 키트 두 개 → 두 무리 → 만남")
	# 만나는 날은 주민 걸음 하나하나에 민감하다 (한 시드만 보면 6일 끝자락에서 갈림 — F-2) → 여러 시드에서 대부분이 8일 안에 만나는지
	var seeds := [8, 9, 10] if quick else [8, 9, 10, 11]
	var met := 0
	var days := []
	var lines_ok := true
	for sd: int in seeds:
		var r := _contact(sd, sd == seeds[0])
		if r.is_empty():
			return
		days.append(r["day"])
		if int(r["day"]) > 0:
			met += 1
			lines_ok = lines_ok and bool(r["lines"])
	check(met * 2 > seeds.size(), "탐험하다 만난다 — 시드 %s 중 %d곳이 8일 안에 (만난 날 %s)" % [seeds, met, days])
	check(lines_ok, "만난 두 무리의 연대기에 첫 만남 한 줄씩")


## 시드 하나: 첫 무리에서 약 110칸 떨어진 곳에 두 번째 키트 → 8일까지 흘려 만나는 날 (−1 = 못 만남)
func _contact(sd: int, checks: bool) -> Dictionary:
	var jw := JarWorld.create(sd)
	var rec := jw.recommended_kit_spots()
	var a := jw.place_kit(rec[0].x, rec[0].y)
	var second := Vector2.INF
	for i in 72:
		var ang := TAU * i / 72.0
		var p := a.center + Vector2(cos(ang), sin(ang)) * 110.0
		if jw.kit_spot_ok(p.x, p.y)["ok"]:
			second = p
			break
	if checks:
		check(second != Vector2.INF, "두 번째 키트 자리 (%s)" % str(second))
	if second == Vector2.INF:
		return {} if checks else {"day": -1, "lines": true}
	var b := jw.place_kit(second.x, second.y)
	if checks:
		check(jw.settlements.size() == 2 and a.sid == 0 and b.sid == 1 and a.others.has(b) and not b.owns_water, "무리 둘 (무리 번호 0·1, 물은 첫 무리가)")
	a.water.offline = true
	a.step_dt = 30.0
	b.step_dt = 30.0
	var met_day := -1
	for d in 8:
		jw.advance(Balance.DAY)
		if a.met.has(1) and met_day < 0:
			met_day = d + 1
			break
	if met_day > 0 and not b.met.has(0):
		met_day = -1
	var la: Array = a.book.filter(func(e: Dictionary) -> bool: return String(e["text"]).contains("낯선"))
	var lb: Array = b.book.filter(func(e: Dictionary) -> bool: return String(e["text"]).contains("낯선"))
	if checks:
		check(absf(a.t - b.t) < 1e-6 and b.people.size() >= 8, "두 무리가 같은 시계로 함께 걷는다 (인구 %d · %d)" % [a.people.size(), b.people.size()])
	return {"day": met_day, "lines": la.size() == 1 and lb.size() == 1}


## 병 돌리기 (기획서 4.6): 넓은 세상은 빛이 돈다 — 따뜻함이 바뀌고, 물·소금 총량은 그대로, 네 번이면 제자리
func test_world_rotation() -> void:
	print("== 넓은 세상 — 병 돌리기")
	var jw := JarWorld.create(4)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	var p := Vector2(200, -200)
	var w0 := jw.water.warm_at(p.x, p.y)
	var pr := JarWater.rot_pt(p)
	var wpr := jw.water.warm_at(pr.x, pr.y)
	var tw := jw.water.total_water()
	var ts := jw.water.total_salt()
	jw.rotate_jar()
	var w1 := jw.water.warm_at(p.x, p.y)
	# JarWater와 같은 뜻: 데이터가 (x, y) → (−y, x)로 돈 것과 같다 → 이제 (x, y)의 따뜻함 = 돌리기 전 (−y, x)의 따뜻함
	check(absf(w1 - wpr) < 1e-5 and absf(w1 - w0) > 0.01, "빛이 돈다: (x, y)의 따뜻함이 돌리기 전 (−y, x)의 따뜻함으로 (%.2f → %.2f)" % [w0, w1])
	check(absf(jw.water.total_water() - tw) < 1e-9 and absf(jw.water.total_salt() - ts) < 1e-9, "돌려도 물·소금 총량 같음")
	for i in 3:
		jw.rotate_jar()
	check(jw.water.rot == 0 and absf(jw.water.warm_at(p.x, p.y) - w0) < 1e-6, "네 번 돌리면 제자리")
	check(v.book.filter(func(e: Dictionary) -> bool: return String(e["text"]).contains("해가") and String(e["text"]).contains("옮겨 갔다")).size() == 4, "옮길 때마다 연대기 (\"해가 …쪽으로 옮겨 갔다\")")


## 시간 예산 (Mac): 몰아서 계산 하루 ≤ 약 1.5초 · 지켜볼 때 물 한 번(고운 + 거친 한 묶음)이 한 화면을 넘지 않음
func test_world_budget() -> void:
	print("== 넓은 세상 — 계산 시간")
	var jw := JarWorld.create(2)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	v.water.offline = true
	v.step_dt = 30.0
	# 벽시계 시간은 다른 일(다른 시험·빌드)이 기기를 쓰면 튄다 (흔들리는 시험) — 반나절씩 두 번 재서 빠른 쪽 × 2
	var day_ms := INF
	for i in 2:
		var t0 := Time.get_ticks_usec()
		jw.advance(Balance.DAY * 0.5)
		day_ms = minf(day_ms, (Time.get_ticks_usec() - t0) / 1000.0 * 2.0)
	# 물만 (마을 빼고)
	var ww := jw.water
	var water_ms := INF
	for i in 2:
		var t0 := Time.get_ticks_usec()
		ww.advance(Balance.DAY * 0.5)
		water_ms = minf(water_ms, (Time.get_ticks_usec() - t0) / 1000.0 * 2.0)
	ww.offline = false
	var worst := 0.0
	var sum := 0.0
	var each: Array = []
	for i in 64:
		var t1 := Time.get_ticks_usec()
		ww.world_tick(1.0)
		var ms := (Time.get_ticks_usec() - t1) / 1000.0
		worst = maxf(worst, ms)
		sum += ms
		each.append(ms)
	print("  몰아서 하루 (마을 30초 걸음 + 물 600초 간격) %.0f ms · 그중 물만 %.0f ms · 고운 칸 %d · 거친 칸 %d" % [day_ms, water_ms, ww.fcells.size(), ww.m * ww.m])
	print("  지켜볼 때 물 한 번 (60초마다 = ×8에서 현실 7.5초마다) 평균 %.1f ms · 최대 %.1f ms" % [sum / 64.0, worst])
	check(day_ms < 2500.0, "몰아서 하루 계산 2.5초 안 (목표 1.5초, 실제 %.2f초)" % (day_ms / 1000.0))
	check(water_ms < 1000.0, "물만 하루 1초 안 (%.2f초)" % (water_ms / 1000.0))
	check(run.pctl(each, 0.95) < 16.0, "물 한 번이 한 화면(16 ms)을 넘지 않음 (95%% %.1f ms · 최대 %.1f ms — 한 번 튀는 건 기기 탓)" % [run.pctl(each, 0.95), worst])


## E0-1 시뮬 속도: (1) 빨라진 물 계산(젖은 칸만 도는 고운·거친 계산, 소금 들판 훑기)이 옛 계산과 같은 값
## (2) 며칠 지난 넓은 세상에서 따라잡기 걸음(30초) 병 하루 · 지켜보는 걸음(10초) 병 2시간이 넉넉한 한도 안 (느려지면 알림 — 벽시계라 한도는 크게)
func test_sim_speed() -> void:
	print("== 시뮬 속도 (E0-1) — 빠른 물 계산 = 옛 계산 · 계산 시간 한도")
	var jw := JarWorld.create(2)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	v.auto_reveal = true
	v.water.offline = true
	v.step_dt = Balance.AWAY_STEP
	for q: Village in jw.settlements:
		q.watching = false
	jw.advance((2.0 if quick else 4.0) * Balance.DAY)
	# (1) 물: 같은 상태 둘 → 새 계산 / 옛 계산 40번 (중간에 바깥에서 물 붓기)
	var a := jw.water as WorldWater
	var b := JarWater.from_dict(bytes_to_var(var_to_bytes(a.to_dict()))) as WorldWater
	for it in 40:
		a.fine_step(10.0)
		b.fine_step_ref(10.0)
		a.coarse_slice(80.0, it % WorldWater.SLICES)
		b.coarse_slice_ref(80.0, it % WorldWater.SLICES)
		a.tick += 1
		b.tick += 1
		if it % 13 == 0:
			var k := a.fcells[(it * 7919) % a.fcells.size()]
			a.w[k] += 0.02
			b.w[k] += 0.02
	var same := a.w == b.w and a.flux == b.flux and a.salt == b.salt and a.halite == b.halite and a.wet_c == b.wet_c and a.cV == b.cV and a.cS == b.cS \
		and a.cL == b.cL and a.cK == b.cK and a.cFL == b.cFL and a.cHal == b.cHal and a.cwet == b.cwet and a.added == b.added and a.removed == b.removed
	check(same, "빠른 물 계산 (젖은 칸만) = 옛 계산 (모든 칸) — 40번 뒤 물·흐름·소금·습기·거친 칸이 똑같다 (고운 칸 %d)" % a.fcells.size())
	var scan_ok := true
	for cr: Array in [[v.center, v.view_r * 1.5, 0.004, 0.003], [v.center, 90.0, 1.0, 0.0], [Vector2(-120, 80), 60.0, 0.004, 0.0]]:
		var flat := 0
		var fc := Vector2.ZERO
		for k in a.village_cells(cr[0], cr[1]):
			if a.depth(k) < cr[2] and a.salt_k(k) > cr[3]:
				flat += 1
				fc += Vector2(a.cx(k), a.cy(k))
		var sc := a.salt_flat_scan(cr[0], cr[1], cr[2], cr[3])
		scan_ok = scan_ok and int(sc[0]) == flat and sc[1] == fc
	check(scan_ok, "소금 들판 훑기 (빠른 길) = 칸마다 depth·salt_k 본 것")
	# (2) 계산 시간: 따라잡기 걸음 병 하루 (반나절 두 번 중 빠른 쪽 × 2) · 지켜보는 걸음 병 2시간
	var pop := 0
	for q: Village in jw.settlements:
		pop += q.people.size()
	var w2 := JarWorld.from_dict(bytes_to_var(var_to_bytes(jw.to_dict())))
	w2.primary().step_dt = Balance.AWAY_STEP
	w2.water.offline = true
	for q: Village in w2.settlements:
		q.watching = false
	var away_ms := INF
	for i in 2:
		var t0 := Time.get_ticks_usec()
		w2.advance(Balance.DAY * 0.5)
		away_ms = minf(away_ms, (Time.get_ticks_usec() - t0) / 1000.0 * 2.0)
	var lv := w2.primary()
	lv.step_dt = Balance.STEP
	for q: Village in w2.settlements:
		q.watching = true
	var each: Array = []
	var live_ms := 0.0
	for i in int(2.0 * Balance.HOUR / Balance.STEP):
		var t1 := Time.get_ticks_usec()
		lv.step(Balance.STEP)
		var ms := (Time.get_ticks_usec() - t1) / 1000.0
		each.append(ms)
		live_ms += ms
		for q: Village in w2.settlements:
			q.crises.clear()
	print("  세상 %d일 · 무리 %d · 인구 %d — 따라잡기 걸음 병 하루 %.0f ms · 지켜보는 10초 걸음 병 1시간 %.0f ms (걸음 99%% %.1f ms · 최대 %.1f ms)" % [
		int(lv.t / Balance.DAY), w2.settlements.size(), pop, away_ms, live_ms / 2.0, run.pctl(each, 0.99), each.max()])
	check(away_ms < 6000.0, "따라잡기 걸음(30초) 병 하루 6초 안 (실제 %.2f초)" % (away_ms / 1000.0))
	check(live_ms / 2.0 < 1500.0, "지켜보는 걸음(10초) 병 1시간 1.5초 안 (실제 %.0f ms)" % (live_ms / 2.0))
	check(run.pctl(each, 0.99) < 30.0, "걸음 하나 99%% 30 ms 안 (실제 %.1f ms)" % run.pctl(each, 0.99))
