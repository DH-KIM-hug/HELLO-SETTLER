## 따라잡기 빠른 길 vs 정밀 (Q35): 시드마다 정밀/빠른 길 결과를 나란히 찍는다 (tests/run.gd test_catchup_fast와 같은 조건).
## 실행: godot --headless --path godot -s res://tools/measure_catchup_fast.gd -- [배율=6] [시드 시작=31] [시드 수=8] [null]
##   null = 빠른 길 대신 걸음만 31초로 바꾼 정밀 따라잡기와 견줌 (같은 규칙끼리도 시드마다 얼마나 갈라지는지 — 잡음의 크기)
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var rate := float(args[0]) if args.size() > 0 else 6.0
	var s0 := int(args[1]) if args.size() > 1 else 31
	var n := int(args[2]) if args.size() > 2 else 8
	var null_run := args.size() > 3 and args[3] == "null"     # 영가설: '빠른 길' 자리에 걸음만 31초로 바꾼 정밀 (시드 안 혼돈 크기)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}     # tests/run.gd와 같은 고정값
	Village.start_aware = true
	CatchUp.rate_override = -1.0
	CatchUp.step_override = -1.0
	var keys := ["pop", "food", "favg", "offer", "dead", "built"]
	var sums := {"exact": {}, "fast": {}}
	for sd in range(s0, s0 + n):
		var rows := {}
		for mode: String in ["exact", "fast"]:
			CatchUp.fast = mode == "fast" and not null_run
			CatchUp.step_override = 31.0 if mode == "fast" and null_run else -1.0
			var v := Village.new_prototype(sd)
			var c := CatchUp.new(v, 12.0 * Balance.HOUR, 12.0 * Balance.HOUR, null, rate)
			var samples: Array = []          # 병 시간 300초마다 먹을 것 (EXACT_CHUNK — run(0)은 한 덩이씩)
			while not c.run(0.0):
				samples.append(v.food_total())
			samples.append(v.food_total())
			c.finish()
			var last := samples.slice(samples.size() - int(Balance.DAY / CatchUp.EXACT_CHUNK))
			var avg := 0.0
			for x: float in last:
				avg += x
			avg /= maxf(1.0, float(last.size()))
			var offer := 0
			var alt := v.altar_items()
			for k: String in alt:
				offer += int(alt[k])
			var row := {"pop": v.people.size(), "food": v.food_total(), "favg": avg, "offer": offer, "dead": v.dead.size(), "built": v.buildings.filter(func(b: Building) -> bool: return b.built).size()}
			rows[mode] = row
			for k: String in row:
				sums[mode][k] = float(sums[mode].get(k, 0.0)) + float(row[k])
		var parts := PackedStringArray()
		for k: String in keys:
			parts.append("%s %d/%d" % [k, int(rows["exact"][k]), int(rows["fast"][k])])
		print("SEED %d: %s" % [sd, " · ".join(parts)])
	var parts2 := PackedStringArray()
	for k: String in keys:
		parts2.append("%s %.1f/%.1f" % [k, float(sums["exact"][k]) / n, float(sums["fast"][k]) / n])
	print("MEAN (n=%d rate=%.0f): %s" % [n, rate, " · ".join(parts2)])
	quit()
