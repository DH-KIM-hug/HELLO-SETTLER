## 개미굴 원정 시험판 재기 (ROADMAP Q10 1.5걸음) — 머리 없는 측정. 굴(1·2) × 생김새(가·나·다) × 자동 거인 × 장비 단계.
## 실행: godot --headless --path godot -s res://tools/measure_nest.gd -- [씨앗 수=200] [지킴이 수=4] [short] [trace <봇> <단계> <씨앗> [굴] [생김새]]
## 자동 거인 다섯(tools/nest_bots.gd: none · random · scripted · clumsy · sensible).
## 한 줄: 이김 % · 가장 깊이 간 방 분포 · 비운 방 평균 · 다친 사람 평균(다친 판 %) · 스스로 물러난 사람 (지침/겁/다침) · 한 판 길이(초 p10/중앙/p90)
##        · 곳간 방 걸린 초 · 손짓 횟수 평균 · 넘친 물/눈먼 손짓 평균
## short = 첫 굴 큰 표만. custom bot:tier[:k=v,…] … = 고른 줄만 (예: custom sensible:1:ng=3 random:2:only=lamp). 결과 글: docs/measure/nest_proto2_2026-11-11.md
extends SceneTree

const LAY := ["가", "나", "다"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 and args[0].is_valid_int() else 200
	var ng := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 4
	var ti := args.find("trace")
	if ti >= 0 and args.size() > ti + 3:
		_trace(args[ti + 1], int(args[ti + 2]), int(args[ti + 3]), ng, int(args[ti + 4]) if args.size() > ti + 4 else 1, int(args[ti + 5]) if args.size() > ti + 5 else -1)
		quit()
		return
	print("개미굴 원정 — 씨앗 %d개 · 지킴이 %d + 강아지 · 걸음 %.1f초" % [n, ng, NestBalance.DT])
	print("bot            | gear | win%  | deepest 0/1/2/3(/4) %        | cleared | hurt/run (runs%) | left t/s/h      | secs p10/med/p90   | room1 s | lamp water twz  tap sugar | ovf  blind")
	var t0 := Time.get_ticks_msec()
	var li := args.find("list")                # list <봇> <단계> [굴] — 씨앗마다 한 줄 (어느 판을 따라가 볼지 고를 때)
	if li >= 0 and args.size() > li + 2:
		for i in n:
			var ex := run_cfg({"bot": args[li + 1], "tier": int(args[li + 2]), "ng": ng, "nest": int(args[li + 3]) if args.size() > li + 3 else 1}, 1000 + i)
			var r: Dictionary = ex.result
			print("%d %s %-8s %5.1fs cleared %d left %s used %s ovf %d blind %d" % [1000 + i, ex.layout_name, r["outcome"], float(r["secs"]), int(r["cleared"]), str(r["left"]), str(r["used"]), int(r["overflows"]), int(r["blind"])])
		quit()
		return
	var ci := args.find("custom")              # custom bot:tier[:k=v,k=v] … — 고른 줄만 (값 맞추기용). k = ng·nest·layout·only·without
	if ci >= 0:
		for j in range(ci + 1, args.size()):
			var parts := args[j].split(":")
			var c := {"bot": parts[0], "tier": int(parts[1]), "n": n, "ng": ng}
			if parts.size() > 2:
				for kv: String in parts[2].split(","):
					var k := kv.get_slice("=", 0)
					var v := kv.get_slice("=", 1)
					c[k] = StringName(v) if k == "only" or k == "without" else int(v)
			print(row(c))
		print("%.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
		quit()
		return
	print("== 첫 굴 (생김새는 씨앗이 고름) ==")
	for tier: int in [1, 2]:
		for bot: String in NestBots.KINDS:
			print(row({"bot": bot, "tier": tier, "n": n, "ng": ng}))
	if not "short" in args:
		print("== 첫 굴, 생김새마다 (장비 1/1) ==")
		for l in 3:
			for bot: String in ["none", "scripted", "clumsy", "sensible"]:
				print(row({"bot": bot, "tier": 1, "n": n, "ng": ng, "layout": l}))
		print("== 첫 굴, 생김새마다 (장비 2/2: 돕지 않음 · 마구) ==")
		for l in 3:
			for bot: String in ["none", "random"]:
				print(row({"bot": bot, "tier": 2, "n": n, "ng": ng, "layout": l}))
		print("== 첫 굴, 손짓 하나 빼기 (sensible, 장비 1/1) — 생김새마다 ==")
		for g: StringName in NestExpedition.GESTURES:
			for l in 3:
				print(row({"bot": "sensible", "tier": 1, "n": n, "ng": ng, "layout": l, "without": g}))
		print("== 첫 굴, 인원 3 / 5 (장비 1/1) ==")
		for k: int in [3, 5]:
			for bot: String in ["none", "clumsy", "sensible"]:
				print(row({"bot": bot, "tier": 1, "n": n, "ng": k}))
		print("== 둘째 굴 (방 넷) ==")
		for tier: int in [1, 2]:
			for bot: String in ["none", "random", "clumsy", "sensible"]:
				print(row({"bot": bot, "tier": tier, "n": n, "ng": ng, "nest": 2}))
		for l in 3:
			print(row({"bot": "sensible", "tier": 2, "n": n, "ng": ng, "nest": 2, "layout": l}))
	print("%.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	quit()


## c = {bot, tier | spear·shield, ng, only, without, nest, layout}
static func run_cfg(c: Dictionary, seed_value: int) -> NestExpedition:
	var ex := NestExpedition.new()
	var tier := int(c.get("tier", 1))
	ex.setup(seed_value, NestExpedition.default_roster(int(c.get("ng", 4)), int(c.get("spear", tier)), int(c.get("shield", tier))), true, null,
		int(c.get("nest", 1)), int(c.get("layout", -1)))
	var only: StringName = c.get("only", &"")
	var without: StringName = c.get("without", &"")
	if only != &"":
		for g: StringName in NestExpedition.GESTURES:
			if g != only:
				ex.cd[g] = 1.0e9
	if without != &"":
		ex.cd[without] = 1.0e9
	var b := NestBots.new(String(c.get("bot", "none")), seed_value)
	while not ex.done:
		b.act(ex)
		ex.step()
	return ex


## 옛 부름 (시험이 쓴다)
static func run_one(bot: String, spear: int, shield: int, seed_value: int, ng: int, only: StringName = &"", without: StringName = &"", nest := 1, layout := -1) -> NestExpedition:
	return run_cfg({"bot": bot, "spear": spear, "shield": shield, "ng": ng, "only": only, "without": without, "nest": nest, "layout": layout}, seed_value)


static func pct(vals: Array, q: float) -> float:
	if vals.is_empty():
		return 0.0
	var s := vals.duplicate()
	s.sort()
	return float(s[clampi(int(q * s.size()), 0, s.size() - 1)])


## 한 줄의 수치 {win, n, …} — 시험도 쓴다
static func stats(c: Dictionary) -> Dictionary:
	var n := int(c.get("n", 100))
	var o := {"n": n, "win": 0, "deep": [0, 0, 0, 0, 0], "cleared": 0, "hurt": 0, "hurt_runs": 0, "tired": 0, "scared": 0, "hurt_left": 0,
		"secs": [], "room1": [], "used": {}, "dead": 0, "ovf": 0, "blind": 0}
	for g: StringName in NestExpedition.GESTURES:
		o["used"][g] = 0
	for i in n:
		var ex := run_cfg(c, 1000 + i)
		var r: Dictionary = ex.result
		if r["outcome"] == &"won":
			o["win"] += 1
		o["deep"][int(r["deepest"])] += 1
		o["cleared"] += int(r["cleared"])
		o["hurt"] += (r["hurt"] as Array).size()
		if not (r["hurt"] as Array).is_empty():
			o["hurt_runs"] += 1
		for l: Dictionary in r["left"]:
			match l["why"]:
				&"tired":
					o["tired"] += 1
				&"scared":
					o["scared"] += 1
				&"hurt":
					o["hurt_left"] += 1
		(o["secs"] as Array).append(float(r["secs"]))
		if float(r["room_secs"][0]) >= 0.0:
			(o["room1"] as Array).append(float(r["room_secs"][0]))
		o["dead"] += int(r["dead"])
		o["ovf"] += int(r["overflows"])
		o["blind"] += int(r["blind"])
		for g: StringName in NestExpedition.GESTURES:
			o["used"][g] += int(r["used"][g])
	o["win_pct"] = 100.0 * float(o["win"]) / float(n)
	return o


func row(c: Dictionary) -> String:
	var o := stats(c)
	var fn := float(o["n"])
	var tag := String(c.get("bot", "none"))
	if c.has("only"):
		tag = "+" + String(c["only"])
	elif c.has("without"):
		tag = "-" + String(c["without"])
	if int(c.get("nest", 1)) != 1:
		tag += " 굴%d" % int(c["nest"])
	if int(c.get("layout", -1)) >= 0:
		tag += " " + LAY[int(c["layout"])]
	if int(c.get("ng", 4)) != 4:
		tag += " x%d" % int(c["ng"])
	var d: Array = o["deep"]
	var u: Dictionary = o["used"]
	var tier := int(c.get("tier", 1))
	return "%-14s | %d/%d  | %5.1f | %4.1f/%4.1f/%4.1f/%4.1f/%4.1f | %4.2f    | %4.2f (%4.1f%%)    | %4d/%4d/%4d  | %5.1f/%5.1f/%5.1f  | %5.1f   | %4.1f %4.1f %4.1f %4.1f %4.1f  | %4.2f %4.2f%s" % [
		tag, tier, tier, o["win_pct"], 100.0 * d[0] / fn, 100.0 * d[1] / fn, 100.0 * d[2] / fn, 100.0 * d[3] / fn, 100.0 * d[4] / fn,
		o["cleared"] / fn, o["hurt"] / fn, 100.0 * o["hurt_runs"] / fn, o["tired"], o["scared"], o["hurt_left"],
		pct(o["secs"], 0.1), pct(o["secs"], 0.5), pct(o["secs"], 0.9), pct(o["room1"], 0.5),
		u[&"lamp"] / fn, u[&"water"] / fn, u[&"tweezers"] / fn, u[&"tap"] / fn, u[&"sugar"] / fn, o["ovf"] / fn, o["blind"] / fn,
		"" if int(o["dead"]) == 0 else "  DEAD %d" % int(o["dead"])]


## 한 판을 사건 줄로 따라가 본다
func _trace(bot: String, tier: int, seed_value: int, ng: int, nest: int, layout: int) -> void:
	var ex := NestExpedition.new()
	ex.setup(seed_value, NestExpedition.default_roster(ng, tier, tier), true, null, nest, layout)
	print("굴 %d · 생김새 %s · 옆 굴 %s · 막힌 것 %s @%.1f · 큰 병정 방 %s" % [ex.nest, ex.layout_name, str(ex.side_at), ex.block_kind, ex.block_s, str(ex.big_rooms)])
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
