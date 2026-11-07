## 따라잡기 속도 재기 (ROADMAP 4 '따라잡기 속도'): 붐비는 넓은 세상을 만들어 (또는 NAZAKJI_SPEED_CACHE에서 읽어) 비운 12시간 × 배율로
## CatchUp을 끝까지 돌리고 — 걸린 시간 · 계통별 몫 (SimProf) · 결과 (인구·먹을 것·제물·건물)를 찍는다.
## 실행: godot --headless --path godot -s res://tools/bench_catchup.gd -- [일 수=30] [시드=2] [배율=12] [exact|fast] [prof]
##   exact = 옛 정밀 걸음 (CatchUp.fast = false) · fast = 따라잡기 빠른 길 (기본)
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 30
	var seed_v := int(args[1]) if args.size() > 1 else 2
	var rate := float(args[2]) if args.size() > 2 else 12.0
	var mode := String(args[3]) if args.size() > 3 else "fast"
	var prof := "prof" in args
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
	var pop0 := 0
	for q: Village in jw.settlements:
		q.watching = true
		pop0 += q.people.size()
	var pv := jw.primary()
	for a: String in args:
		if a.begins_with("reseed="):         # 같은 세상, 다른 난수 — 결과의 흩어짐을 보려고
			var k := int(a.substr(7))
			for q: Village in jw.settlements:
				q.rng.seed = hash([q.sid, k])
				q.health_rng.seed = hash([q.sid, k, 1])
	print("세상: 무리 %d · 인구 %d · 건물 %d · 나무 %d" % [jw.settlements.size(), pop0, pv.buildings.size(), pv.trees.size()])
	var keep := CatchUp.fast
	CatchUp.fast = mode != "exact"
	if prof:
		SimProf.reset()
		SimProf.on = true
	var c := CatchUp.new(pv, 12.0 * Balance.HOUR, 12.0 * Balance.HOUR, jw, rate)
	for a: String in args:
		if a.begins_with("step="):
			c.step_dt = float(a.substr(5))
	var t0 := Time.get_ticks_usec()
	var frames := 0
	var worst := 0.0
	while true:                          # 화면처럼 나눠서 (40 ms 예산) — 한 화면이 가장 오래 걸린 때도 잰다
		var f0 := Time.get_ticks_usec()
		var done := c.run(40.0)
		worst = maxf(worst, (Time.get_ticks_usec() - f0) / 1000.0)
		frames += 1
		if done:
			break
	var l := c.finish()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	SimProf.on = false
	CatchUp.fast = keep
	var s := summary(jw)
	print("%s · 병 %.1f일 · %.0f ms (휴대폰 어림 ×4 = %.1f초) · 화면 %d개 · 가장 긴 화면 %.1f ms" % [mode, c.exact_total / Balance.DAY, ms, ms * 4.0 / 1000.0, frames, worst])
	print("결과: %s" % str(s))
	print("편지: 인구 %d → %d · %s" % [l["pop0"], l["pop1"], " / ".join(PackedStringArray(l["events"]))])
	if prof:
		var keys: Array = SimProf.acc.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(SimProf.acc[a]) > int(SimProf.acc[b]))
		for k: String in keys.slice(0, 40):
			print("  %s %.0f ms (%d번)" % [k, int(SimProf.acc[k]) / 1000.0, int(SimProf.cnt[k])])
	quit(0)


## 결과 요약 (시험 tests/run.gd 따라잡기 비교와 같은 값)
static func summary(jw: JarWorld) -> Dictionary:
	var pop := 0
	var food := 0.0
	var offer := 0
	var built := 0
	var dead := 0
	for q: Village in jw.settlements:
		pop += q.people.size()
		dead += q.dead.size()
		food += q.food_total()
		for k: String in q.altar_items():
			offer += int(q.altar_items()[k])
		for b in q.buildings:
			if b.built:
				built += 1
	return {"pop": pop, "dead": dead, "food": snappedf(food, 0.1), "offer": offer, "built": built, "groups": jw.settlements.size()}


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
