## 요약 계산 맞추기 도구 — 같은 출발 상태에서 정밀 계산(10초 걸음, 거인 없음)과 요약 계산(1시간)을 days일 돌려 날마다 비교.
## 실행: godot --headless --path godot -s tools/summary_calib.gd -- [days] [시드 수]
## (상수는 sim/offline_summary.gd 맨 위 — 이 도구로 맞춘 값. 합격 기준 시험은 tests/save_tests.gd test_summary_matches_exact)
extends SceneTree


func _initialize() -> void:
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 10
	var n := int(args[1]) if args.size() > 1 else 3
	var acc := {}
	OfflineSummary.prof = {}
	for s in n:
		var seed_v := 100 + s
		var base := Village.new_prototype(seed_v)
		base.water.offline = true
		base.advance(Balance.DAY)            # 하루 지켜본 뒤 떠남
		var bytes := var_to_bytes(base.to_dict())
		var ex := Village.from_dict(bytes_to_var(bytes))
		var su := Village.from_dict(bytes_to_var(bytes))
		ex.watching = false
		su.watching = false
		OfflineSummary.begin(su)
		var te := 0.0
		var ts := 0.0
		var seen := [{}, {}]                 # 터가 처음 보인 때 (완공 걸린 시간 재기)
		var took := [[], []]
		for d in days:
			for h in 24:
				var t0 := Time.get_ticks_usec()
				ex.advance(Balance.HOUR)
				te += (Time.get_ticks_usec() - t0) / 1e6
				t0 = Time.get_ticks_usec()
				OfflineSummary.hour(su, Balance.HOUR)
				ts += (Time.get_ticks_usec() - t0) / 1e6
				for i in 2:
					var vv: Village = ex if i == 0 else su
					var key := "env%d" % i
					acc[key] = float(acc.get(key, 0.0)) + vv.birth_env()
					acc["hap%d" % i] = float(acc.get("hap%d" % i, 0.0)) + vv.avg_happiness()
					acc["n%d" % i] = float(acc.get("n%d" % i, 0.0)) + 1.0
				if OS.get_environment("CALIB_DIAG") != "" and d < 3:
					var line := "  %s" % ex.fmt_time(ex.t)
					for v: Village in [ex, su]:
						var hl := 0
						var pend := 0
						for p in v.people:
							if p.home < 0 and p.age >= Balance.AGE_ADULT:
								hl += 1
						for b in v.buildings:
							if b.is_site():
								pend += 1
						line += " | 집없음 %d 정원 %d 인구 %d 터 %d" % [hl, v.house_capacity(), v.people.size(), pend]
					print(line)
				for i in 2:
					var v: Village = ex if i == 0 else su
					for b in v.buildings:
						if b.is_site() and not seen[i].has(b.id):
							seen[i][b.id] = v.t
						elif not b.is_site() and seen[i].has(b.id) and float(seen[i][b.id]) >= 0.0:
							took[i].append((v.t - float(seen[i][b.id])) / 3600.0)
							seen[i][b.id] = -1.0
			for pair: Array in [["ex", ex], ["su", su]]:
				var v: Village = pair[1]
				var k := "%s%d" % [pair[0], d + 1]
				var row: Array = acc.get(k, [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
				row[0] += v.people.size()
				row[1] += v.food_total()
				row[2] += float(v.stock["판자"])
				row[3] += float(v.stock["돌"])
				row[4] += float(v.stock["통나무"])
				row[5] += v.faith
				row[6] += v.buildings.size()
				row[7] += v.water.basin_area(v.water.basins[0])
				acc[k] = row
		for i in 2:
			var sum := 0.0
			for x: float in took[i]:
				sum += x
			var vv: Village = ex if i == 0 else su
			var types := {}
			for b: Building in vv.buildings:
				var key: String = b.type + ("" if b.built else "(터)")
				types[key] = int(types.get(key, 0)) + 1
			print("  %s: 터 → 완공 평균 %.1f시간 (%d채) · 건물 %s · 혼인 %d" % ["정밀" if i == 0 else "요약", sum / maxf(1, took[i].size()), took[i].size(), str(types), vv.stats["marriages"]])
		if OS.get_environment("CALIB_BOOK") != "":
			for i in 2:
				var vv: Village = ex if i == 0 else su
				print("  -- %s 연대기 (촌장·집)" % ("정밀" if i == 0 else "요약"))
				for e: Dictionary in vv.book:
					if float(e["t"]) >= Balance.DAY and (String(e["text"]).contains("촌장") or String(e["text"]).contains("한 채")):
						print("    %s %s" % [vv.fmt_time(e["t"]), e["text"]])
		print("시드 %d: 정밀 %.1f s · 요약 %.2f s (%d일) · 정밀 출생 %d 사망 %d / 요약 출생 %d 사망 %d" % [seed_v, te, ts, days, ex.stats["born"], ex.stats["died"], su.stats["born"], su.stats["died"]])
	var ps := ""
	for k: String in OfflineSummary.prof:
		ps += "%s %.2f s · " % [k, OfflineSummary.prof[k] / 1e6 / n]
	print("출산 환경 배율 평균 정밀 %.3f / 요약 %.3f · 행복 평균 %.3f / %.3f" % [acc["env0"] / acc["n0"], acc["env1"] / acc["n1"], acc["hap0"] / acc["n0"], acc["hap1"] / acc["n1"]])
	print("요약 계산 시간 나눔 (시드 하나 평균): " + ps)
	print("day | 인구 정밀/요약 | 식량 | 판자 | 돌 | 통나무 | 믿음 | 건물 | 서쪽 호수 칸")
	for d in days:
		var a: Array = acc["ex%d" % (d + 1)]
		var b: Array = acc["su%d" % (d + 1)]
		var line := "%3d" % (d + 1)
		for i in a.size():
			line += " | %.1f/%.1f" % [a[i] / n, b[i] / n]
		print(line)
	quit(0)
