## 개미굴 원정 시험판 재기 (ROADMAP Q10 1걸음) — 머리 없는 측정. '거인이 도우면 달라지는가'를 숫자로.
## 실행: godot --headless --path godot -s res://tools/measure_nest.gd -- [씨앗 수=200] [지킴이 수=4] [short] [trace <봇> <단계> <씨앗>]
## 자동 거인 셋(tools/nest_bots.gd: none · random · sensible) × 장비 단계(창/방패 1/1 · 2/2)마다 씨앗 N개를 돌려 한 줄씩:
##   이김 % · 가장 깊이 간 방 분포(0~3) · 비운 방 평균 · 다친 사람 평균(다친 판 %) · 스스로 물러난 사람 평균 · 한 판 길이(초) · 전리품 평균 · 손짓 횟수 평균
## short = 위 여섯 줄만 (손짓 하나씩·하나 빼기·인원 표는 건너뜀). 결과 글: docs/measure/nest_proto_2026-11-11.md
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 and args[0].is_valid_int() else 200
	var ng := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 4
	var ti := args.find("trace")
	if ti >= 0 and args.size() > ti + 3:
		_trace(args[ti + 1], int(args[ti + 2]), int(args[ti + 3]), ng)
		quit()
		return
	print("개미굴 원정 — 씨앗 %d개 · 지킴이 %d + 강아지 · 걸음 %.1f초" % [n, ng, NestBalance.DT])
	print("bot       | gear | win%  | deepest 0/1/2/3 %      | cleared | hurt/run (runs%) | left/run | secs p10/med/p90   | loot/run | lamp water twz  tap sugar")
	var t0 := Time.get_ticks_msec()
	for tier: int in [1, 2]:
		for bot: String in NestBots.KINDS:
			print(row(bot, tier, tier, n, ng))
	if not "short" in args:
		for mix: Array in [[2, 1], [1, 2]]:
			print(row("none", int(mix[0]), int(mix[1]), n, ng))
		print("only one gesture (sensible bot, gear 1/1):")
		for g: StringName in NestExpedition.GESTURES:
			print(row("sensible", 1, 1, n, ng, g))
		print("all but one gesture (sensible bot, gear 1/1):")
		for g: StringName in NestExpedition.GESTURES:
			print(row("sensible", 1, 1, n, ng, &"", g))
		print("squad size 3 / 5 (none · sensible, gear 1/1):")
		for k: int in [3, 5]:
			print(row("none", 1, 1, n, k))
			print(row("sensible", 1, 1, n, k))
	print("%.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


static func run_one(bot: String, spear: int, shield: int, seed_value: int, ng: int, only: StringName = &"", without: StringName = &"") -> NestExpedition:
	var ex := NestExpedition.new()
	ex.setup(seed_value, NestExpedition.default_roster(ng, spear, shield), true)
	if only != &"":
		for g: StringName in NestExpedition.GESTURES:
			if g != only:
				ex.cd[g] = 1.0e9
	if without != &"":
		ex.cd[without] = 1.0e9
	var b := NestBots.new(bot, seed_value)
	while not ex.done:
		b.act(ex)
		ex.step()
	return ex


static func pct(vals: Array, q: float) -> float:
	var s := vals.duplicate()
	s.sort()
	return float(s[clampi(int(q * s.size()), 0, s.size() - 1)])


func row(bot: String, spear: int, shield: int, n: int, ng: int, only: StringName = &"", without: StringName = &"") -> String:
	var win := 0
	var deep := [0, 0, 0, 0]
	var cleared := 0
	var hurt := 0
	var hurt_runs := 0
	var left := 0
	var secs: Array = []
	var loot := 0
	var used := {}
	var dead := 0
	for g: StringName in NestExpedition.GESTURES:
		used[g] = 0
	for i in n:
		var ex := run_one(bot, spear, shield, 1000 + i, ng, only, without)
		var r: Dictionary = ex.result
		if r["outcome"] == &"won":
			win += 1
		deep[int(r["deepest"])] += 1
		cleared += int(r["cleared"])
		hurt += (r["hurt"] as Array).size()
		if not (r["hurt"] as Array).is_empty():
			hurt_runs += 1
		left += (r["left"] as Array).size()
		secs.append(float(r["secs"]))
		dead += int(r["dead"])
		for k: String in r["loot"]:
			loot += int(r["loot"][k])
		for g: StringName in NestExpedition.GESTURES:
			used[g] += int(r["used"][g])
	var fn := float(n)
	var tag := bot
	if only != &"":
		tag = "+" + String(only)
	elif without != &"":
		tag = "-" + String(without)
	if ng != 4:
		tag += " x%d" % ng
	return "%-9s | %d/%d  | %5.1f | %4.1f/%4.1f/%4.1f/%4.1f | %4.2f    | %4.2f (%4.1f%%)    | %4.2f     | %5.1f/%5.1f/%5.1f  | %5.1f    | %4.1f %4.1f %4.1f %4.1f %4.1f%s" % [
		tag, spear, shield, 100.0 * win / fn, 100.0 * deep[0] / fn, 100.0 * deep[1] / fn, 100.0 * deep[2] / fn, 100.0 * deep[3] / fn,
		cleared / fn, hurt / fn, 100.0 * hurt_runs / fn, left / fn, pct(secs, 0.1), pct(secs, 0.5), pct(secs, 0.9), loot / fn,
		used[&"lamp"] / fn, used[&"water"] / fn, used[&"tweezers"] / fn, used[&"tap"] / fn, used[&"sugar"] / fn,
		"" if dead == 0 else "  DEAD %d" % dead]


## 한 판을 사건 줄로 따라가 본다
func _trace(bot: String, tier: int, seed_value: int, ng: int) -> void:
	var ex := NestExpedition.new()
	ex.setup(seed_value, NestExpedition.default_roster(ng, tier, tier), true)
	var b := NestBots.new(bot, seed_value)
	var cur := 0
	while not ex.done:
		b.act(ex)
		ex.step()
		for e: Dictionary in ex.events.since(cur):
			cur = int(e["n"])
			print("%6.1f  %-18s who=%2d at=%s  %s" % [float(e["t"]), e["kind"], int(e["who"]), str(e["at"]), str(e["v"])])
		if ex.step_n % 50 == 0:
			var line := "        · "
			for g in ex.guards:
				line += "%s[%s s%.0f st%.2f nv%.2f %s] " % [g.name, g.state, g.s, g.stam, g.nerve, g.doing]
			var st := 0
			for a in ex.ants:
				if a.standing() and a.fighter():
					st += 1
			print(line + " fighters=%d" % st)
