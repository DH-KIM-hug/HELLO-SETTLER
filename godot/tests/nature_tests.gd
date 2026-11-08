## 자연 계통 정리 (ROADMAP F-2 · design/gdd/water.md 메인 판단 ① 물 보존 · ADR-0001 static 없음 · 깨닫기 전 거인 모름).
## 물 보존: 뚜껑이 닫힌 병에서 땅의 물 + 공기의 김 = 그대로. 바뀌는 길은 뚜껑(나감 — JarAir.water_lost)과 거인의 물(들어옴)뿐.
## 습도 하나: 병의 습도 상태는 JarAir.humid, JarWater.humid는 병 시계의 함수 (저장하지 않음). 결정론: 같은 씨앗 → 같은 자연.
## tests/run.gd가 부름 (`-- nature`).
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []
const H := 3600.0
const D := 86400.0


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== F-2 자연 계통 정리 — 물 보존 · 습도 하나 · static 없음 · 결정론")
	run.timed(self, ["test_closed_jar", "test_lid_exchange", "test_drop_from_vapour", "test_giant_water_in", "test_day_humid",
		"test_determinism", "test_save_continues", "test_dict_no_alias", "test_no_statics", "test_unaware_grove_line"])


func _world(seed_v := 7) -> JarWorld:
	return JarWorld.create_with_kit(seed_v, WorldCfg.SMALL_SIZE, Kits.make([]))


func _stock(ww: JarWater) -> float:
	var g: float = (ww as WorldWater).total_water() if ww is WorldWater else ww.total(ww.w)
	return g + maxf(ww.vapour, 0.0)


## 마을이 사는 진짜 병 (넓은 세상): 뚜껑을 닫아 두면 며칠이 흘러도 물 + 김이 그대로 (주민·작은 위기·버섯·해바라기가 돌아도)
func test_closed_jar() -> void:
	var jw := _world()
	var ww := jw.water
	check(ww.vapour > 0.0, "세상을 만든 뒤 뚜껑이 닫혀 김이 차 있다 (%.3f)" % ww.vapour)
	var s0 := _stock(ww)
	var v0 := ww.vapour
	var days := 2 if quick else 4
	var worst := 0.0
	for d in days:
		jw.advance(D)
		worst = maxf(worst, absf(_stock(ww) - s0))
	var lost := 0.0
	for v in jw.settlements:
		lost += v.air.water_lost
	print("  %d일: 물 + 김 %.4f → %.4f (가장 큰 차이 %.6f) · 김 %.3f → %.3f · 김 배율 %.2f · 뚜껑 손실 %.4f" % [
		days, s0, _stock(ww), worst, v0, ww.vapour, ww.inflow_k(), lost])
	check(lost == 0.0, "뚜껑을 열지 않았다")
	check(worst < 1e-5 * s0, "닫힌 병: 물 + 김 = 그대로 (가장 큰 차이 %.2f ppm)" % (worst / s0 * 1e6))
	check(ww.vapour >= 0.0 and ww.inflow_k() > 0.2, "김이 바닥나지 않고 이슬이 계속 맺힌다 (배율 %.2f)" % ww.inflow_k())


## 뚜껑: 열린 동안 나간 물(땅 + 김) = 줄어든 물 + 김 (넓은 세상에서도 — 예전엔 소형 병의 칸 목록만 보아 하나도 안 나갔다)
func test_lid_exchange() -> void:
	var jw := _world()
	var v := jw.primary()
	var ww := jw.water
	jw.advance(H)
	var s0 := _stock(ww)
	var vap0 := ww.vapour
	var l0 := v.air.water_lost
	v.open_lid()
	jw.advance(60.0)
	v.close_lid()
	jw.advance(120.0)                       # 열린 시간의 물 손실은 다음 공기 걸음(60초)에 셈
	var lost := v.air.water_lost - l0
	var s1 := _stock(ww)
	print("  1분 열림: 물 + 김 %.4f → %.4f (−%.4f) · 뚜껑으로 나감 %.4f · 김 %.3f → %.3f" % [s0, s1, s0 - s1, lost, vap0, ww.vapour])
	check(lost > 1e-4 * s0, "넓은 세상에서도 뚜껑으로 물이 나간다 (%.4f = %.2f%%)" % [lost, lost / s0 * 100.0])
	check(absf((s0 - s1) - lost) < 1e-5 * s0, "줄어든 물 + 김 = 뚜껑으로 나간 물 (차이 %.6f)" % absf((s0 - s1) - lost))
	check(ww.vapour < vap0, "열린 동안 공기의 김도 빠진다")


## 떠돌이 물방울의 물덩이 = 공기의 김이 맺힌 것 → 김이 줄고 땅이 그만큼 는다 (합 그대로)
func test_drop_from_vapour() -> void:
	var jw := _world()
	var v := jw.primary()
	var ww := jw.water
	var g0: float = (ww as WorldWater).total_water()
	var vap0 := ww.vapour
	var got := v.smalls._pour(v, v.center + Vector2(6.0, 0.0), 3.0, 0.05)
	var g1: float = (ww as WorldWater).total_water()
	print("  물덩이 %.4f: 땅 %.4f → %.4f · 김 %.4f → %.4f" % [got, g0, g1, vap0, ww.vapour])
	check(got > 0.0 and absf((g1 - g0) - got) < 1e-4, "땅에 부은 만큼 땅의 물이 는다")
	check(absf((vap0 - ww.vapour) - got) < 1e-9, "그 물은 김에서 왔다 (김이 넉넉할 때)")
	# 김이 모자라면 나머지는 땅의 다른 물에서 (합 그대로)
	ww.vapour = 0.01
	var s0 := _stock(ww)
	var got2 := v.smalls._pour(v, v.center + Vector2(-6.0, 0.0), 3.0, 0.05)
	check(got2 > 0.01 and ww.vapour == 0.0 and absf(_stock(ww) - s0) < 1e-5 * s0, "김이 모자라면 나머지는 병의 물에서 (합 %.4f → %.4f)" % [s0, _stock(ww)])


## 들어오는 길은 거인의 물뿐: 부은 만큼 는다
func test_giant_water_in() -> void:
	var jw := _world()
	var v := jw.primary()
	var s0 := _stock(jw.water)
	var add := GiantHand._add_water(v, v.center + Vector2(4.0, 4.0), 2.0, 0.02)
	var s1 := _stock(jw.water)
	check(add > 0.0 and absf((s1 - s0) - add) < 1e-4, "거인의 물만큼 물이 는다 (%.4f · 늘어남 %.4f)" % [add, s1 - s0])


## 하루 물 순환 박자 = 예전에 조각마다 쌓던 값과 같다 (첫날 뒤) · 0.2~1 · 저장하지 않는다 · 병의 습도 상태는 JarAir.humid 하나
func test_day_humid() -> void:
	var old := 0.5
	var t := 0.0
	var start := 8.0 * H
	var worst := 0.0
	var lo := 1.0
	var hi := 0.0
	for i in int(3.0 * D / JarWater.SUBSTEP):
		t += JarWater.SUBSTEP
		var hr := fmod(start + t, D) / H
		if hr >= 7.0 and hr < 18.0:
			old = minf(1.0, old + JarWater.SUBSTEP / (D * 0.45))
		else:
			old = maxf(0.2, old - JarWater.SUBSTEP / (D * 0.9))
		var now := JarWater.day_humid(start + t)
		lo = minf(lo, now)
		hi = maxf(hi, now)
		if t > D:
			worst = maxf(worst, absf(now - old))
	print("  박자 %.3f~%.3f · 예전 쌓던 값과 가장 큰 차이 %.5f (둘째 날부터)" % [lo, hi, worst])
	check(worst < 1e-3, "닫힌 식 = 예전 박자 (차이 %.5f)" % worst)
	check(lo >= 0.2 and hi <= 1.0 and hi > 0.99 and lo < 0.45, "박자 0.2~1, 밤에 내려가고 낮에 1")
	var s := JarWater.new_prototype_world()
	s.advance(5.0 * H)
	check(is_equal_approx(s.humid, JarWater.day_humid(s.clock())), "JarWater.humid = 병 시계의 함수")
	var d := s.to_dict()
	check(not d.has("humid"), "물 순환 박자는 저장하지 않는다 (상태가 아님)")
	var jw := _world()
	check(not jw.water.to_dict().has("humid"), "넓은 세상도 저장하지 않는다")


func _finger(jw: JarWorld) -> String:
	var ww := jw.water
	var v := jw.primary()
	return "%d|%.6f|%.6f|%.6f|%.6f|%d|%d|%d|%d|%s" % [hash(ww.w), ww.total_water(), ww.vapour, ww.dew_cum, v.air.humid,
		v.flora.rng.state, v.flora.shrooms.size(), v.flora.dands.size(), v.people.size(), str(ww.sunflowers)]


## 결정론: 같은 씨앗 두 번 → 같은 물·김·이슬·버섯·민들레·해바라기
func test_determinism() -> void:
	var a := _world(9)
	var b := _world(9)
	var days := 1.5 if quick else 3.0
	a.advance(days * D)
	b.advance(days * D)
	var fa := _finger(a)
	check(fa == _finger(b), "같은 씨앗 → 같은 자연 (%.1f일)" % days)
	var c := _world(10)
	c.advance(days * D)
	check(fa != _finger(c), "씨앗이 다르면 다르다")


## 저장 → 불러온 뒤에도 물 + 김이 그대로 (김 vapour가 저장되고, 불러온 병도 닫힌 고리). 파일처럼 바이트로 한 번 바꿔 —
## 같은 메모리를 나눠 쓰지 않게 (사전 그대로 넘기면 PackedFloat32Array를 함께 써서 두 병이 같은 땅을 고친다)
func test_save_continues() -> void:
	var a := _world(11)
	a.advance(0.75 * D)
	var s0 := _stock(a.water)
	var b := JarWorld.from_dict(bytes_to_var(var_to_bytes(a.to_dict(false))))
	check(is_equal_approx(b.water.vapour, a.water.vapour) and absf(_stock(b.water) - s0) < 1e-6 * s0,
		"김이 저장되고 불러온 물 + 김이 같다 (%.4f / %.4f)" % [s0, _stock(b.water)])
	b.advance(0.5 * D)
	check(absf(_stock(b.water) - s0) < 1e-5 * s0, "불러온 병도 반나절 뒤 물 + 김 그대로 (%.4f → %.4f)" % [s0, _stock(b.water)])


## 저장 사전을 파일을 거치지 않고 바로 불러와도 (되돌리기·미리보기) 두 병이 같은 격자를 나눠 쓰지 않는다 (SaveCodec.dec가 묶음 배열을 새로 만듦)
func test_dict_no_alias() -> void:
	var a := _world(11)
	a.advance(0.25 * D)
	var d := a.to_dict(false)
	var snap := a.water.w.duplicate()
	var b := JarWorld.from_dict(d)
	var s0 := _stock(a.water)
	var k := a.water.fcells[0]
	var w_a := a.water.w[k]
	b.water.w[k] = w_a + 5.0
	check(a.water.w[k] == w_a, "불러온 병의 땅 물을 고쳐도 원래 병은 그대로")
	b.water.w[k] = w_a
	a.advance(0.5 * D)
	b.advance(0.5 * D)
	check(absf(_stock(a.water) - s0) < 1e-5 * s0 and absf(_stock(b.water) - s0) < 1e-5 * s0,
		"사전으로 바로 넘긴 두 병을 함께 흘려도 둘 다 물 + 김 그대로 (%.4f · %.4f / %.4f)" % [_stock(a.water), _stock(b.water), s0])
	var c := JarWorld.from_dict(d)
	check(c.water.w == snap and c.water.w != a.water.w, "저장 사전은 저장한 때 그대로 (흐른 병을 따라 바뀌지 않음)")


## ADR-0001: 자연 계통 파일에 static var 없음 (상태는 모두 인스턴스 → 저장됨)
func test_no_statics() -> void:
	for f: String in ["jar_water", "world_water", "jar_air", "flora", "giant_plants", "great_trees", "wildlife", "mold", "mold_blob",
			"core_warmth", "lamp", "health", "caterpillars", "lean_seasons"]:
		var src := FileAccess.get_file_as_string("res://sim/%s.gd" % f)
		var bad := false
		for line in src.split("\n"):
			if line.strip_edges().begins_with("static var"):
				bad = true
		check(not bad, "%s.gd에 static var 없음" % f)


## 깨닫기 전엔 주민이 거인을 모른다: 하룻밤 버섯 숲을 익숙하게 맞아도 거인을 부르는 말이 없다 (CLAUDE.md 1)
func test_unaware_grove_line() -> void:
	var jw := _world(13)
	var v := jw.primary()
	jw.advance(2.0 * H)
	v.aware = false                         # 깨닫기 전 마을로
	v.flora.trust = true
	for r in v.people:
		r.belief = 0.9
		r.say = ""
	v.flora.grove(v)
	var said := ""
	for r in v.people:
		said += r.say + "|"
	check(not said.contains("내려 주신"), "깨닫기 전 버섯 숲 말에 거인 이야기 없음 (%s)" % said.replace("||", ""))
