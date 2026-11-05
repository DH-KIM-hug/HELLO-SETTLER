## 시뮬레이션 테스트 (헤드리스) — 실패하면 0이 아닌 값으로 끝난다.
## 실행: godot --headless --path godot -s res://tests/run.gd
extends SceneTree

const DAYS := 9
var fails := 0


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	var t0 := Time.get_ticks_msec()
	test_nine_days()
	test_rotation()
	print("\n%s — %d failure(s), %.1f s" % ["PASS" if fails == 0 else "FAIL", fails, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if fails > 0 else 0)


func drip_basin(s: JarWater, i: int) -> Dictionary:
	var d: Dictionary = s.drips[i]
	return {"x": d["x"], "y": d["y"], "r": 7.0 if i == 0 else 5.0}


func grids_ok(s: JarWater) -> bool:
	for k in s.cells:
		if s.w[k] < 0.0 or s.salt[k] < 0.0 or s.halite[k] < 0.0 or is_nan(s.w[k]) or is_nan(s.salt[k]):
			return false
	return true


## 기획서 4.3: 볕 드는 쪽 큰 호수 → 약 9일 만에 사라짐, 물방울 호수는 그대로. 4.5: 소금은 사라지지 않는다.
func test_nine_days() -> void:
	print("== 9일: 서쪽 큰 호수 소멸 · 물방울 호수 유지 · 소금 보존")
	var ti := Time.get_ticks_usec()
	var s := JarWater.new_prototype_world()
	print("  처음 세계 (물 60걸음 포함) %.0f ms" % ((Time.get_ticks_usec() - ti) / 1000.0))
	var west: Dictionary = s.basins[0]
	var a0: int = west["area0"]
	var d0 := [s.basin_area(drip_basin(s, 0)), s.basin_area(drip_basin(s, 1))]
	var salt0 := s.total_salt()
	var gone_day := -1
	var all_ok := true
	print("  day | 서쪽 호수 칸 (비율) | 큰/작은 물방울 호수 | 소금 들판 칸 | 물 총량 | 소금 총량 | ms")
	print("    0 | %4d (1.00) | %3d / %3d | %3d | %.3f | %.5f |" % [a0, d0[0], d0[1], s.salt_flat_cells(), s.total(s.w), salt0])
	var ms_sum := 0.0
	for day in range(1, DAYS + 1):
		var t := Time.get_ticks_usec()
		s.advance(JarWater.DAY)
		var ms := (Time.get_ticks_usec() - t) / 1000.0
		ms_sum += ms
		var a := s.basin_area(west)
		if gone_day < 0 and a < 0.12 * a0:
			gone_day = day
		all_ok = all_ok and grids_ok(s)
		print("  %3d | %4d (%.2f) | %3d / %3d | %3d | %.3f | %.5f | %.0f" % [day, a, float(a) / a0, s.basin_area(drip_basin(s, 0)), s.basin_area(drip_basin(s, 1)), s.salt_flat_cells(), s.total(s.w), s.total_salt(), ms])
	print("  하루 계산 평균 %.0f ms (물 1440걸음, 거인이 볼 때 60초 간격)" % (ms_sum / DAYS))
	var a9 := s.basin_area(west)
	check(a0 >= 100, "처음 서쪽 큰 호수가 크다 (%d칸, 기획서 약 144칸)" % a0)
	check(a9 < 0.12 * a0, "9일 뒤 서쪽 큰 호수 사라짐 (%d → %d칸, 사라진 날 %d일째)" % [a0, a9, gone_day])
	check(gone_day >= 6, "너무 빨리 마르지 않는다 (6일 이후, 실제 %d일)" % gone_day)
	for i in 2:
		var ai := s.basin_area(drip_basin(s, i))
		check(ai >= 0.8 * d0[i] and ai > 10, "물방울 호수 %d 유지 (%d → %d칸)" % [i, d0[i], ai])
	check(all_ok, "물·소금·암염이 음수/NaN이 되지 않는다")
	check(absf(s.total_salt() - salt0) < 1e-4 * maxf(1.0, salt0) + 1e-5, "소금 총량 보존 (%.6f → %.6f)" % [salt0, s.total_salt()])
	check(s.salt_flat_cells() >= 45 and s.salt_flat() != null, "마른 호수 바닥에 소금 들판 (%d칸)" % s.salt_flat_cells())
	var flat: Variant = s.salt_flat()
	if flat != null:
		check((flat as Vector2).distance_to(Vector2(west["x"], west["y"])) < 12.0, "가장 짠 곳이 서쪽 호수 자리 %s" % str(flat))
	# 거인이 없을 때 (300초 간격) 도 같은 결과인지 — 오프라인 몰아서 계산
	var o := JarWater.new_prototype_world()
	o.offline = true
	var t2 := Time.get_ticks_usec()
	o.advance(DAYS * JarWater.DAY)
	var oa := o.basin_area(o.basins[0])
	print("  오프라인 계산 9일 %.0f ms (하루 %.0f ms)" % [(Time.get_ticks_usec() - t2) / 1000.0, (Time.get_ticks_usec() - t2) / 1000.0 / DAYS])
	check(oa < 0.12 * a0, "오프라인(300초 간격)에서도 9일 뒤 서쪽 호수 사라짐 (%d칸)" % oa)


## 기획서 4.6: 병을 돌리면 골의 물줄기가 바뀌고, 물방울 호수 자리는 그대로
func test_rotation() -> void:
	print("== 병 돌리기")
	var s := JarWater.new_prototype_world()
	s.advance(JarWater.DAY)
	var h0 := s.h.duplicate()
	var w0 := s.w.duplicate()
	var salt0 := s.total_salt()
	var water0 := s.total(s.w)
	var lakes0 := [s.basin_area(drip_basin(s, 0)), s.basin_area(drip_basin(s, 1))]
	var g0 := s.groove_flux()
	s.rotate_jar()
	var k := JarWater.cell_idx(10.5, -20.5)
	var kr := JarWater.cell_idx(20.5, 10.5)       # (x, y) → (−y, x)
	check(is_equal_approx(s.h[kr], h0[k]) and is_equal_approx(s.w[kr], w0[k]), "격자가 (x, y) → (−y, x)로 돈다")
	check(absf(s.total_salt() - salt0) < 1e-6 and absf(s.total(s.w) - water0) < 1e-6, "돌려도 물·소금 총량 같음")
	var lakes1 := [s.basin_area(drip_basin(s, 0)), s.basin_area(drip_basin(s, 1))]
	check(lakes1 == lakes0, "물방울 호수가 병과 함께 돈다 (%s → %s칸)" % [str(lakes0), str(lakes1)])
	s.advance(JarWater.DAY)
	var g1 := s.groove_flux()
	var fmt := func(a: PackedFloat32Array) -> String:
		var parts: PackedStringArray = []
		for v in a:
			parts.append("%.0f" % (v * 1e6))
		return "·".join(parts)
	print("  골 다섯 곳의 흐름 (×1e-6): %s → 하루 뒤 %s" % [fmt.call(g0), fmt.call(g1)])
	var changed := 0
	for i in g0.size():
		if absf(g1[i] - g0[i]) > 0.3 * maxf(g0[i], 1e-5):
			changed += 1
	check(changed >= 2, "돌린 뒤 골의 물줄기가 달라진다 (%d곳)" % changed)
	var l2 := [s.basin_area(drip_basin(s, 0)), s.basin_area(drip_basin(s, 1))]
	check(l2[0] >= 0.8 * lakes0[0] and l2[1] >= 0.8 * lakes0[1], "돌린 뒤에도 물방울 호수 유지 (%s칸)" % str(l2))
	# 네 번 돌리면 제자리
	var s2 := JarWater.new_prototype_world()
	var hb := s2.h.duplicate()
	var wb := s2.w.duplicate()
	for i in 4:
		s2.rotate_jar()
	check(s2.h == hb and s2.w == wb and s2.rot == 0, "네 번 돌리면 제자리")
