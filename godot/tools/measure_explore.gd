## 탐험 재 보기 (ROADMAP Q39, 2026-11-14) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다 (시뮬 상태를 읽기만 — 주사위는 제 것만).
## 시작은 tools/measure_milestones.gd와 같다: 넓은 세상 + 기본 키트 · 4월 15일 · 깨닫기 전 · 창세의 날 톡 세 번 · 떨어뜨리기 한 번 ·
## 제단 공물 걷기 · 계시. 병 한 시간씩, 30초 걸음. 거인 none = 돕지 않음 · help = 흔히 돕는 거인 (measure_milestones의 help와 같음).
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_explore.gd -- <씨앗 처음> <씨앗 끝> [일수 200] [거인 none|help] [그림 앞 경로]
## 그림 앞 경로를 주면 병 60 · 120 · 200일에 안개 지도 (<앞>_s<씨앗>_d<날>.png — WorldMap: 빨강 마을 · 금색 본 큰 나무 · 회색 못 본 큰 나무)와
##   세상 덤프 (<앞>_s<씨앗>_d<날>.bin — var_to_bytes(JarWorld.to_dict), 캡처 도구 tools/shot_explore_q39.gd가 읽음)를 적는다
## 씨앗마다 EXPL 줄 하나 (JSON):
##   fog     표시한 날 → 이 무리가 걷은 안개 (병 안 땅의 %, 소수 한 자리)
##   rad     표시한 날 → 마을 가운데에서 가장 먼 걷힌 칸까지 (칸)
##   edge    표시한 날 → 걷힌 칸 가운데 세상 끝(유리벽)에 가장 가까운 곳까지 남은 거리 (칸)
##   trips   표시한 날 → 그때까지 떠난 탐험 수 (stats.explore) · tries 떠나려다 갈 곳이 없던 수 포함 시도 수
##   trees   큰 나무 종류 → [처음 본 날 (-1 = 못 봄), 마을 가운데에서 거리]
##   wall    처음 유리벽 곁(EDGE_NEAR칸)까지 걷힌 날 (-1 = 못 감)
##   why     50일 묶음마다 탐험하지 않던 시간의 까닭 (시간 수): busy 누가 다녀오는 중 · wait 간격이 아직 · held 첫 며칠 먹을 것 막기 ·
##           none 갈 곳 없음 (제 주사위로 40번 찾아봐도 안개 가장자리가 EXPLORE_MAX 안에 없음) · nopick 떠날 수 있는데 아무도 안 고름 · night 밤 ·
##           go 그 시간에 떠남
##   ms      고비 id → 넘은 날 · pop · food 표시한 날의 식구 · 먹을 것 날치
##   d20     병 20일 마을 저장 지문 (SaveCodec.digest — 앞뒤 견주기: Q39가 새로 넣은 칸은 뺌)
##   log     (Q39 뒤 트리) 탐험 기록 [날, 목표 종류, 거리] (있으면)
extends SceneTree

const H := 3600.0
const D := 86400.0
const MARKS := [10, 20, 30, 45, 60, 90, 120, 150, 200, 250, 300]
const EDGE_NEAR := 24.0
const Q39_KEYS := ["explore_rng", "explore_party", "explore_more_t", "explore_goals", "explore_seen", "explore_v", "explore_hero", "explore_log"]

var jw: JarWorld
var mode := "none"
var last_help := -1.0e9
var probe := RandomNumberGenerator.new()
var out_pre := ""
const PIC_DAYS := [60, 120, 200]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	var s0 := int(args[0]) if args.size() > 0 else 1
	var s1 := int(args[1]) if args.size() > 1 else s0
	var days := int(args[2]) if args.size() > 2 else 200
	mode = args[3] if args.size() > 3 else "none"
	out_pre = args[4] if args.size() > 4 else ""
	for s in range(s0, s1 + 1):
		_run(s, days)
	quit()


func _run(s: int, days: int) -> void:
	var t0 := Time.get_ticks_msec()
	Market.reset()
	Market.first_paid = false
	Market.mig_seed = s * 7919 + 13
	Market.today_override = "R1"
	jw = JarWorld.create_with_kit(s, WorldCfg.SIZE, Kits.make([]))
	var v := jw.primary()
	var ww := v.water as WorldWater
	probe.seed = s * 31 + 7
	last_help = -1.0e9
	var tapped := 0
	var dropped := false
	while v.t < 23.0 * H:
		jw.advance(5.0 * 60.0)
		if tapped < 3 and v.t > (20.0 + 20.0 * tapped) * 60.0:
			Awakening.witness(v, "tap")
			tapped += 1
		if not dropped and v.t > 50.0 * 60.0:
			Awakening.witness(v, "drop")
			dropped = true
		if _hour(v) >= 19.6 and v.cal_day(v.t) == 1:
			_collect()
	_collect()
	for q: Village in jw.settlements:
		q.step_dt = 30.0
	var land := 0
	for q in ww.fn * ww.fn:
		if _cell_in(ww, q):
			land += 1
	var out := {"seed": s, "mode": mode, "days": days, "fog": {}, "rad": {}, "edge": {}, "trips": {}, "tries": {}, "trees": {}, "wall": -1.0,
		"why": {}, "pop": {}, "food": {}, "ms": {}, "d20": ""}
	for t: Dictionary in ww.great_trees:
		out["trees"][String(t["kind"])] = [-1.0, snappedf(Vector2(t["x"], t["y"]).distance_to(v.center), 1.0)]
	var mi := 0
	var tries := 0
	var last_try := v.last_explore_t
	var why := {}
	while v.t < days * D - 1.0 and not v.people.is_empty():
		jw.advance(minf(H, days * D - v.t))
		for q: Village in jw.settlements:
			q.crises.clear()
			if q.revelation_pending():
				q.reveal()
		var hr := int(_hour(v))
		if hr == 8 or hr == 20:
			_collect()
		_giant(v)
		var day := v.t / D
		var bucket := str(int(day / 50.0) * 50)
		if not why.has(bucket):
			why[bucket] = {"busy": 0, "wait": 0, "held": 0, "none": 0, "nopick": 0, "night": 0, "go": 0}
		var w: Dictionary = why[bucket]
		if v.last_explore_t != last_try:
			last_try = v.last_explore_t
			tries += 1
			w["go"] += 1
		else:
			w[_why(v, ww)] += 1
		for t: Dictionary in ww.great_trees:
			var tr: Array = out["trees"][String(t["kind"])]
			if float(tr[0]) < 0.0 and _tree_seen(ww, v.sid, t):
				tr[0] = snappedf(day, 0.1)
		if float(out["wall"]) < 0.0 and hr % 6 == 0 and _edge_gap(ww, v.sid) <= EDGE_NEAR:
			out["wall"] = snappedf(day, 0.1)
		if absf(day - 20.0) < 0.5 / 24.0 and String(out["d20"]) == "":
			var dd := v.to_dict()
			for k: String in Q39_KEYS:
				dd.erase(k)
			out["d20"] = SaveCodec.digest(dd)
		while mi < MARKS.size() and day >= float(MARKS[mi]) - 0.01:
			var key := str(MARKS[mi])
			var st := _fog_stats(ww, v)
			out["fog"][key] = snappedf(100.0 * float(st[0]) / maxf(1.0, land), 0.1)
			out["rad"][key] = snappedf(float(st[1]), 1.0)
			out["edge"][key] = snappedf(float(st[2]), 1.0)
			out["trips"][key] = int(v.stats.get("explore", 0))
			out["tries"][key] = tries
			out["pop"][key] = v.people.size()
			out["food"][key] = snappedf(v.food_total() / maxf(1.0, Production.day_need(v)), 0.1)
			if out_pre != "" and int(MARKS[mi]) in PIC_DAYS:
				_pic(ww, v, s, int(MARKS[mi]))
			mi += 1
	var passed: Dictionary = v.milestones.get("passed", {})
	for id: String in Milestones.ORDER:
		out["ms"][id] = snappedf(float((passed[id] as Dictionary)["t"]) / D, 0.01) if passed.has(id) else -1.0
	out["why"] = why
	out["settlements"] = jw.settlements.size()
	out["secs"] = int((Time.get_ticks_msec() - t0) / 1000.0)
	var lg = v.get("explore_log")
	if lg is Array:
		var short: Array = []
		for e: Dictionary in lg:
			short.append([snappedf(float(e.get("t", 0.0)) / D, 0.1), String(e.get("goal", "")), int(e.get("d", 0))])
		out["log"] = short
	var hero = v.get("explore_hero")
	if hero is Dictionary and not (hero as Dictionary).is_empty():
		out["hero"] = [String(hero.get("name", "")), snappedf(float(hero.get("t", 0.0)) / D, 0.1)]
	var bad := 0
	for q: Village in jw.settlements:
		bad += q.check_invariants().size() + q.violations.size()
	out["bad"] = bad
	print("EXPL " + JSON.stringify(out))


## 탐험하지 않던 그 시간의 까닭 (읽기만)
func _why(v: Village, ww: WorldWater) -> String:
	var q39 := v.has_method("explorers_out")
	if q39:
		if int(v.call("explorers_out")) >= int(v.call("explore_cap")):
			return "busy"
	elif v.explorer >= 0:
		return "busy"
	if v.explore_held():
		return "held"
	var last := v.last_explore_t if v.explorer < 0 else float(v.get("explore_more_t"))
	if v.t - last < WorldCfg.EXPLORE_EVERY:
		return "wait"
	var h := _hour(v)
	if h < Balance.WORK_FROM or h >= Balance.WORK_TO:
		return "night"
	var reach := float(v.call("explore_reach")) if q39 and bool(v.call("explore_goal_on")) else WorldCfg.EXPLORE_MAX
	for i in 40:
		if ww.fog_target(v.sid, v.center, probe, reach) != null:
			return "nopick"
	return "none"


func _pic(ww: WorldWater, v: Village, s: int, day: int) -> void:
	var marks: Array = [{"p": v.center, "c": Color("d23a2a")}]
	var seen = v.get("explore_seen")
	for t: Dictionary in ww.great_trees:
		var ok := _tree_seen(ww, v.sid, t) if not seen is Dictionary else (seen as Dictionary).has(String(t["kind"]))
		marks.append({"p": Vector2(t["x"], t["y"]), "c": Color("e8a317") if ok else Color("7d776e")})
	var img := WorldMap.render(ww, 2, true, marks)
	var base := "%s_s%d_d%d" % [out_pre, s, day]
	img.save_png(base + ".png")
	var f := FileAccess.open(base + ".bin", FileAccess.WRITE)
	f.store_buffer(var_to_bytes(jw.to_dict()))
	f.close()


func _cell_in(ww: WorldWater, q: int) -> bool:
	var p := Vector2(-ww.rr + (q % ww.fn + 0.5) * WorldWater.FOG, -ww.rr + (q / ww.fn + 0.5) * WorldWater.FOG)
	return p.length() <= ww.rr - 2.0


func _tree_seen(ww: WorldWater, sid: int, t: Dictionary) -> bool:
	var c := Vector2(t["x"], t["y"])
	var r := float(t["r"])
	for k in 9:
		var p := c if k == 0 else c + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * r
		if ww.revealed(p.x, p.y, sid):
			return true
	return false


## [걷힌 칸 수, 마을 가운데에서 가장 먼 걷힌 칸, 걷힌 칸에서 유리벽까지 가장 가까운 거리]
func _fog_stats(ww: WorldWater, v: Village) -> Array:
	var bit := 1 << v.sid
	var n := 0
	var far := 0.0
	var gap := INF
	for q in ww.fn * ww.fn:
		if (ww.fog[q] & bit) == 0 or not _cell_in(ww, q):
			continue
		n += 1
		var p := Vector2(-ww.rr + (q % ww.fn + 0.5) * WorldWater.FOG, -ww.rr + (q / ww.fn + 0.5) * WorldWater.FOG)
		far = maxf(far, p.distance_to(v.center))
		gap = minf(gap, ww.rr - p.length())
	return [n, far, gap]


func _edge_gap(ww: WorldWater, sid: int) -> float:
	var bit := 1 << sid
	var gap := INF
	# 가장자리 둘레만 훑는다 (빠르게): 반지름 rr-EDGE_NEAR-4 바깥 칸
	var R := ww.rr
	for k in 720:
		var a := k * TAU / 720.0
		var d := R - 1.0
		while d > R - EDGE_NEAR - 4.0:
			var p := Vector2(cos(a), sin(a)) * d
			if ww.fog[ww.fog_idx(p.x, p.y)] & bit:
				gap = minf(gap, R - d)
				break
			d -= 2.0
	return gap


func _giant(v: Village) -> void:
	if mode != "help":
		return
	for q: Village in jw.settlements:
		for l: Dictionary in q.open_letters("wish"):
			if String(l["type"]) == "연장":
				_buy_tools(q)
			else:
				q.grant_wish(int(l["id"]))
	var d := v.food_total() / maxf(1.0, Production.day_need(v))
	if d < 1.0 and v.t - last_help >= D:
		v.manna_fall("giant")
		last_help = v.t


func _buy_tools(q: Village) -> void:
	var item := ToolShort.TOOL_ITEM
	if not Shop.ITEMS.has(item) or not bool(Shop.can_buy(q, item)["ok"]):
		return
	var r := Shop.buy(q, item)
	if not bool(r["ok"]):
		return
	if not q.air.lid_open:
		q.open_lid()
	var s := q.store()
	var at := Vector2(s.x, s.y)
	var res := {}
	for i in 24:
		var a := float(i) * 2.399
		var p := at + Vector2(cos(a), sin(a)) * (3.0 + 0.4 * i)
		res = SkyDrops.drop(q, item, p, Shop.hand_item(int(r["hand_id"])))
		if bool(res.get("ok", false)):
			Shop.hand_remove(int(r["hand_id"]))
			break
	if not bool(res.get("ok", false)):
		Shop.undo_buy(q, int(r["hand_id"]))


func _collect() -> void:
	for q: Village in jw.settlements:
		if q.altar_items().is_empty():
			continue
		q.take_all()
		if q.revelation_pending():
			q.reveal()


func _hour(v: Village) -> float:
	return fmod(v.start_clock + v.t, D) / H
