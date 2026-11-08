## 창조 4단계 '물 붓기'에서 거인이 본 호수 = 세상의 호수 (docs/OPENING.md 단계 4 '파낸 골짜기부터 물이 차오름 → 호수',
## sim/creation_plan.gd shown_* · sim/world_gen.gd _shown_lakes/_carve_shown). 2026-11-08 사용자 버그: "산과 골짜기 + 물 넉넉히면
## 큰 호수가 생기는데 나중에 반영이 안 됨" — 세상이 과장 없는 높이로 따로 덩어리를 찾아 작은 분지만 팠다 (겹침 약 1%).
## tests/run.gd가 부름 (`-- creation_lake`).
extends RefCounted

var run: SceneTree
var quick := false
const N := 96                           # 비교 격자 한 변 (원판 [-1, 1])


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 창조의 물 (거인이 본 호수 = 세상의 호수)")
	run.timed(self, ["test_preview_matches_world", "test_shown_level_shared", "test_dry_kit_spots"])


func _plan(seed_v: int, land: int, water: int) -> CreationPlan:
	var p := CreationPlan.make(seed_v, WorldCfg.SIZE)
	p.land_preset(land)
	p.water = CreationPlan.WATER_PICKS[water]
	p.auto_drips()
	p.seed_preset(0)
	return p


## 창조 화면이 그리는 물 (CreationJar.water_h와 같은 식 — shape 1): 원판 격자에서 물 아래 칸
static func preview_mask(p: CreationPlan) -> PackedByteArray:
	var R := p.size * 0.5
	var nzs := WorldGen.noises(p.seed_v)
	var flat := CreationPlan.flat_h(nzs, R)
	var wl := CreationPlan.shown_level(nzs, p.sculpt, R, flat, p.water)
	var m := PackedByteArray()
	m.resize(N * N)
	for j in N:
		for i in N:
			var u := (i + 0.5) / N * 2.0 - 1.0
			var v := (j + 0.5) / N * 2.0 - 1.0
			if u * u + v * v <= 1.0 and CreationPlan.shown_h(nzs, p.sculpt, u, v, R, flat) < wl:
				m[j * N + i] = 1
	return m


## 세상의 호수 칸 (깊이 > LAKE_DEPTH) — 같은 격자
static func world_mask(ww: WorldWater) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(N * N)
	for j in N:
		for i in N:
			var u := (i + 0.5) / N * 2.0 - 1.0
			var v := (j + 0.5) / N * 2.0 - 1.0
			if u * u + v * v > 1.0:
				continue
			var x := u * ww.rr
			var y := v * ww.rr
			if ww.inside(x, y, 1.0) and ww.depth(ww.idx(x, y)) > JarWater.LAKE_DEPTH:
				m[j * N + i] = 1
	return m


static func _count(m: PackedByteArray) -> int:
	var n := 0
	for x in m:
		n += x
	return n


## 원판 안 칸 수 (같은 격자)
static func _disc() -> int:
	var n := 0
	for j in N:
		for i in N:
			var u := (i + 0.5) / N * 2.0 - 1.0
			var v := (j + 0.5) / N * 2.0 - 1.0
			if u * u + v * v <= 1.0:
				n += 1
	return n


## 본 물 칸 중 세상에서도 물인 몫
static func _overlap(pv: PackedByteArray, wm: PackedByteArray) -> float:
	var a := 0
	var ab := 0
	for i in pv.size():
		if pv[i] == 1:
			a += 1
			ab += wm[i]
	return float(ab) / maxf(1.0, a)


## 산과 골짜기 + 넉넉히 (사용자 버그) · 너른 들 + 조금: 창조 직후와 첫날 뒤 — 본 물 칸의 85% 넘게 세상도 물, 넓이는 본 것의 0.9배 이상 · 더 많은 물은 원판의 3% 이하
## (세상엔 물방울 호수·작은 분지가 더 있다 — 물 조금이면 배수로는 크게 보여 원판 몫으로 잰다). 첫날 동안 물 + 김은 그대로 (뚜껑으로 새지 않음)
func test_preview_matches_world() -> void:
	var cases := [[12345, 2, 2], [4242, 0, 0]] if quick else [[12345, 2, 2], [777, 2, 2], [4242, 0, 0], [777, 1, 1], [4242, 2, 0]]
	for c: Array in cases:
		var p := _plan(int(c[0]), int(c[1]), int(c[2]))
		var tag := "%s + %s (시드 %d)" % [CreationPlan.LAND_PICKS[int(c[1])], CreationPlan.WATER_PICKS_T[int(c[2])], int(c[0])]
		var pv := preview_mask(p)
		var jw := JarWorld.create(p.seed_v, p.size, p.gen_opts())
		var ww := jw.water
		var w0 := world_mask(ww)
		var np := _count(pv)
		var o0 := _overlap(pv, w0)
		var nd := _disc()
		var r0 := float(_count(w0)) / maxf(1.0, np)
		var x0 := float(_count(w0) - np) / nd
		check(np > 20, "%s: 창조 화면에 호수가 보임 (%d칸)" % [tag, np])
		check(o0 >= 0.85, "%s: 창조 직후 본 호수 자리가 세상에서도 물 (%.2f)" % [tag, o0])
		check(r0 >= 0.9 and x0 <= 0.03, "%s: 창조 직후 호수 넓이 ≈ 본 것 (%.2f배 · 원판의 %+.3f)" % [tag, r0, x0])
		var tot0 := ww.total_water() + maxf(ww.vapour, 0.0)
		ww.offline = true                       # 첫날 따라잡기 (비운 동안의 걸음)
		ww.advance(JarWater.DAY)
		ww.offline = false
		var w1 := world_mask(ww)
		var o1 := _overlap(pv, w1)
		var r1 := float(_count(w1)) / maxf(1.0, np)
		var x1 := float(_count(w1) - np) / nd
		check(o1 >= 0.85, "%s: 첫날 뒤에도 본 호수 자리가 물 (%.2f)" % [tag, o1])
		check(r1 >= 0.9 and x1 <= 0.03, "%s: 첫날 뒤 호수 넓이 ≈ 본 것 (%.2f배 · 원판의 %+.3f)" % [tag, r1, x1])
		var tot1 := ww.total_water() + maxf(ww.vapour, 0.0)
		check(absf(tot1 - tot0) <= tot0 * 0.01, "%s: 첫날 물 + 김 보존 (%.0f → %.0f)" % [tag, tot0, tot1])


## 창조 화면(CreationJar)과 세상 만들기가 같은 물 높이 식을 쓴다 — 화면 쪽 옛 복사본이 다시 생기지 않게
func test_shown_level_shared() -> void:
	var src := FileAccess.get_file_as_string("res://view/start/creation_jar.gd")
	check(src.contains("CreationPlan.shown_level(") and src.contains("CreationPlan.shown_h("), "창조 화면은 CreationPlan.shown_h · shown_level을 씀")
	check(not src.contains("CreationPlan.water_level("), "창조 화면에 물 높이 따로 셈 없음")
	var p := _plan(12345, 2, 2)
	var R := p.size * 0.5
	var nzs := WorldGen.noises(p.seed_v)
	var flat := CreationPlan.flat_h(nzs, R)
	var lv := [CreationPlan.shown_level(nzs, p.sculpt, R, flat, 0.22), CreationPlan.shown_level(nzs, p.sculpt, R, flat, 0.5),
		CreationPlan.shown_level(nzs, p.sculpt, R, flat, 0.82)]
	check(lv[0] < lv[1] and lv[1] < lv[2], "물을 더 부으면 수면이 높다 (%.3f < %.3f < %.3f)" % lv)
	check(CreationPlan.shown_water({}, 1, 1024).is_empty(), "창조 선택이 없으면 본 물도 없음 (옛 세상 그대로)")


## 키트 자리(추천 자리)는 거인이 본 물 밖 — 큰 호수 한가운데 섬으로 남지 않게
func test_dry_kit_spots() -> void:
	var p := _plan(12345, 2, 2)
	var pv := preview_mask(p)
	var jw := JarWorld.create(p.seed_v, p.size, p.gen_opts())
	var ww := jw.water
	var ok := true
	var wet := 0
	for s: Vector2 in ww.spots:
		var i := clampi(int((s.x / ww.rr + 1.0) * 0.5 * N), 0, N - 1)
		var j := clampi(int((s.y / ww.rr + 1.0) * 0.5 * N), 0, N - 1)
		if pv[j * N + i] == 1 or ww.depth(ww.idx(s.x, s.y)) > JarWater.LAKE_DEPTH:
			ok = false
			wet += 1
	check(ok, "키트 자리 %d곳 모두 마른 땅 (물 위 %d곳)" % [ww.spots.size(), wet])
	check(not jw.recommended_kit_spots().is_empty(), "추천 키트 자리가 있음")
