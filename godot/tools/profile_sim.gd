## 시뮬 계통별 시간표 (E0-1): 붐비는 넓은 세상을 병 몇 시간 걸려 보고 계통마다 병 1시간에 몇 ms를 쓰는지, 가장 무거운 걸음은 얼마인지.
## 세상은 tools/measure_speeds.gd와 같은 방법으로 만들고 (NAZAKJI_SPEED_CACHE 파일이 있으면 읽는다), SimProf로 Village.step 안을 잰다.
## 실행: godot --headless --path godot -s res://tools/profile_sim.gd -- [병 시간=24] [live|away] [일 수=30] [시드=2] [걸음 초]
##   live = 지켜볼 때 (watching, 걸음 Balance.STEP) · away = 따라잡기 (거인 없음, 걸음 Balance.AWAY_STEP)
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var hours := float(args[0]) if args.size() > 0 else 24.0
	var mode := String(args[1]) if args.size() > 1 else "away"
	var days := int(args[2]) if args.size() > 2 else 30
	var seed_v := int(args[3]) if args.size() > 3 else 2
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	var cache := OS.get_environment("NAZAKJI_SPEED_CACHE")
	var jw: JarWorld
	if cache != "" and FileAccess.file_exists(cache):
		jw = JarWorld.from_dict(bytes_to_var(FileAccess.get_file_as_bytes(cache)))
	else:
		jw = _make(seed_v, days)
		if cache != "":
			var fa := FileAccess.open(cache, FileAccess.WRITE)
			fa.store_buffer(var_to_bytes(jw.to_dict()))
			fa.close()
	var pv := jw.primary()
	var live := mode == "live"
	var sdt := Balance.STEP if live else Balance.AWAY_STEP
	if args.size() > 4:
		sdt = float(args[4])
	pv.step_dt = sdt
	pv.water.offline = true
	var pop := 0
	for q: Village in jw.settlements:
		q.watching = live
		q.crises.clear()
		pop += q.people.size()
	print("모드 %s · 걸음 %.0f초 · 무리 %d · 인구 %d · 건물 %d · 나무 %d" % [mode, sdt, jw.settlements.size(), pop, pv.buildings.size(), pv.trees.size()])
	SimProf.reset()
	SimProf.on = true
	var steps := int(hours * Balance.HOUR / sdt)
	var hook := 0.0
	var times := PackedFloat64Array()
	var worst := []                    # [ms, 걸음 번호, {계통: µs}]
	var t0 := Time.get_ticks_usec()
	for i in steps:
		var before := SimProf.acc.duplicate()
		var ts := Time.get_ticks_usec()
		pv.step(sdt)
		hook += sdt
		if hook >= Balance.FAST_HOOK_EVERY - 1e-6:
			hook = 0.0
			var u0 := SimProf.now()
			var n0 := jw.settlements.size()
			jw._auto_split()
			SimProf.add("world_split" if jw.settlements.size() != n0 else "world_hook", u0)
			u0 = SimProf.now()
			jw._update_interest()
			SimProf.add("world_interest", u0)
		var ms := (Time.get_ticks_usec() - ts) / 1000.0
		times.append(ms)
		if worst.size() < 6 or ms > float(worst.back()[0]):
			var diff := {}
			for k: String in SimProf.acc:
				var d := int(SimProf.acc[k]) - int(before.get(k, 0))
				if d > 300:
					diff[k] = d
			worst.append([ms, i, diff])
			worst.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
			if worst.size() > 6:
				worst.pop_back()
		for q: Village in jw.settlements:
			q.crises.clear()
	var total_ms := (Time.get_ticks_usec() - t0) / 1000.0
	SimProf.on = false
	var keys: Array = SimProf.acc.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(SimProf.acc[a]) > int(SimProf.acc[b]))
	print("병 %.0f시간 · %d걸음 · 모두 %.0f ms → 병 1시간 %.1f ms · 병 6일 어림 %.1f초" % [hours, steps, total_ms, total_ms / hours, total_ms / hours * 144.0 / 1000.0])
	print("계통 | 병 1시간 ms | 몫 % | 부른 횟수")
	var sum := 0
	for k: String in keys:
		sum += int(SimProf.acc[k])
	for k: String in keys:
		var us := int(SimProf.acc[k])
		print("%s | %.2f | %.1f | %d" % [k, us / 1000.0 / hours, 100.0 * us / maxf(1, sum), int(SimProf.cnt[k])])
	print("(재지 못한 몫 = 무리 정리 등: %.1f ms/h)" % ((total_ms - sum / 1000.0) / hours))
	var sorted := times.duplicate()
	sorted.sort()
	print("걸음 ms: 평균 %.3f · 95%% %.3f · 99%% %.3f · 최대 %.3f" % [total_ms / steps, sorted[int(steps * 0.95)], sorted[int(steps * 0.99)], sorted[steps - 1]])
	for w: Array in worst:
		print("  무거운 걸음 #%d %.2f ms: %s" % [w[1], w[0], str(w[2])])
	quit(0)


static func _make(seed_v: int, days: int) -> JarWorld:
	var jw := JarWorld.create(seed_v)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y)
	v.auto_reveal = true
	v.water.offline = true
	v.step_dt = 30.0
	for d in days:
		for q: Village in jw.settlements:
			q.watching = false
		jw.advance(Balance.DAY)
	return jw
