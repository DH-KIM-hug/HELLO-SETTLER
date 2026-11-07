## 빠른 흐름 재기 (기획서 6.6 — 1초=5분 ~ 1초=12시간): 30일 지난 붐비는 넓은 세상에서 배속마다 현실 1초에 병 몇 시간이 흐르는가.
## 화면 없이 60fps 화면(1/60초)을 흉내 내 JarClock.tick을 부른다 — 한 화면 계산 예산 Balance.FAST_BUDGET_MS (기기가 4배 느리면 휴대폰 어림).
## 실행: godot --headless --path godot -s res://tools/measure_speeds.gd -- [일 수=30] [시드=2] [재는 현실 초=4]
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 30
	var seed_v := int(args[1]) if args.size() > 1 else 2
	var secs := float(args[2]) if args.size() > 2 else 4.0
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	var t0 := Time.get_ticks_msec()
	var cache := OS.get_environment("NAZAKJI_SPEED_CACHE")    # (선택) 만든 세상을 이 파일에 두고 다음엔 바로 읽음
	var jw: JarWorld
	if cache != "" and FileAccess.file_exists(cache):
		jw = JarWorld.from_dict(bytes_to_var(FileAccess.get_file_as_bytes(cache)))
	else:
		jw = _make(seed_v, days)
		if cache != "":
			var fa := FileAccess.open(cache, FileAccess.WRITE)
			fa.store_buffer(var_to_bytes(jw.to_dict()))
			fa.close()
	var v := jw.primary()
	v.step_dt = Balance.STEP
	v.water.offline = false
	var pop := 0
	for q: Village in jw.settlements:
		q.watching = true
		q.crises.clear()
		pop += q.people.size()
	print("세상 %d일 · 무리 %d곳 · 인구 %d · 만드는 데 %.1f초" % [days, jw.settlements.size(), pop, (Time.get_ticks_msec() - t0) / 1000.0])
	var snap := var_to_bytes(jw.to_dict())
	if "catchup" in args:                 # 따라잡기 (자리를 비운 동안): 병 하루를 걸음 크기마다 몇 초에 계산하는가
		for sdt: float in [10.0, 20.0, 30.0]:
			var w3 := JarWorld.from_dict(bytes_to_var(snap))
			var c := CatchUp.new(w3.primary(), Balance.DAY / Balance.AWAY_RATES[1], 24.0 * Balance.HOUR, w3)
			c.step_dt = sdt
			var tc := Time.get_ticks_msec()
			c.run()
			var ms := Time.get_ticks_msec() - tc
			c.finish()
			var p2 := 0
			for q: Village in w3.settlements:
				p2 += q.people.size()
			print("따라잡기 걸음 %.0f초: 병 %.2f일 %.1f초 → 병 6일 %.1f초 (휴대폰 어림 ×4 = %.0f초) · 인구 %d" % [sdt, c.exact_total / Balance.DAY, ms / 1000.0,
				ms / 1000.0 * 6.0 * Balance.DAY / c.exact_total, ms / 1000.0 * 24.0 * Balance.DAY / c.exact_total, p2])
		quit(0)
		return
	print("배속 | 목표 (병 시간/현실 1초) | 컴퓨터 실제 (예산 %.0f ms) · 화면당 계산 평균/95%%/최대 ms | 휴대폰 어림 (4배 느림 · 예산 %.0f ms = 여기서 %.1f ms)" % [
		Balance.FAST_BUDGET_MS, Balance.FAST_BUDGET_MS_SLOW, Balance.FAST_BUDGET_MS_SLOW / 4.0])
	for i in Balance.SPEEDS.size():
		var desk := _run(snap, i, Balance.FAST_BUDGET_MS, secs)
		var phone := _run(snap, i, Balance.FAST_BUDGET_MS_SLOW / 4.0, secs)
		print("%s | %.2f h | %.2f h (%s) · %.2f/%.2f/%.2f ms · 걸음당 %.2f ms | %.2f h (%s)" % [JarClock.label_of(i), float(Balance.SPEEDS[i]) / Balance.HOUR,
			desk["h"], JarClock.rate_label(desk["h"] * Balance.HOUR), desk["avg"], desk["p95"], desk["max"], desk["step"],
			phone["h"], JarClock.rate_label(phone["h"] * Balance.HOUR)])
	quit(0)


## 한 배속을 secs초(60fps 화면) 돌려 본다 → {h: 현실 1초에 병 몇 시간, avg·p95·max: 화면당 계산 ms, step: 걸음당 ms}
static func _run(snap: PackedByteArray, i: int, budget: float, secs: float) -> Dictionary:
	var w2 := JarWorld.from_dict(bytes_to_var(snap))
	var pv := w2.primary()
	var c := JarClock.new(pv)
	c.world = w2
	c.auto_slow = false
	c.budget_ms = budget
	c.set_speed(i)
	var frames := int(secs * 60.0)
	var t_start := pv.t
	var each: Array = []
	var tot := 0.0
	var n := 0
	for f in frames:
		var tf := Time.get_ticks_usec()
		n += c.tick(1.0 / 60.0)
		var ms := (Time.get_ticks_usec() - tf) / 1000.0
		tot += ms
		each.append(ms)
		for q: Village in w2.settlements:
			q.crises.clear()
	each.sort()
	return {"h": (pv.t - t_start) / Balance.HOUR / secs, "avg": tot / frames, "p95": each[int(each.size() * 0.95)], "max": each.back(),
		"step": tot / maxf(1.0, n)}


## 붐비는 세상: 거인 없이 (분가도 스스로) days일을 몰아서 (30초 걸음 · 물 오프라인)
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
