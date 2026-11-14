## 큰 나무 넷의 쓰임 재 보기 (ROADMAP Q40, 2026-11-14) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다 (시뮬 상태를 읽기만).
## 시작은 tools/measure_explore.gd와 같다: 넓은 세상 + 기본 키트 · 깨닫기 전 · 창세의 날 톡 세 번 · 떨어뜨리기 한 번 · 제단 공물 걷기 · 계시.
## 병 한 시간씩, 30초 걸음. 거인 none = 돕지 않음 · help = 흔히 돕는 거인 (measure_explore의 help와 같음). Q40 전 트리에서도 돈다 (없는 칸은 비워 둠).
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_treeuse.gd -- <씨앗 처음> <씨앗 끝> [일수 200] [거인 none|help] [시작 달 4] [시작 날 15]
## 씨앗마다 TUSE 줄 하나 (JSON):
##   trips · people · arrive · gain   나무 → 떠난 나들이 수 · 간 사람 수 · 나무에 닿은 사람 · 얻은 것 (송진 · 은행알(먹을 것 단위) · 단풍 엿)
##   first   나무 → 처음 쓴 날 (연대기 한 줄) · seen 나무 → 처음 본 날 · dist 나무 → 마을 가운데에서 거리
##   block   떠나지 않은 아침의 까닭 (tree_use 주사위 날 — crisis · feast · cold · food · team)
##   happy   병 20일 뒤 평균 행복 (시간마다) · food 병 20일 뒤 평균 먹을 것 날치 · feasts 축제 · 고비 잔치가 열린 수 · sweet 엿이 돈 잔치
##   resin   송진을 쓴 횃불 · 모깃불 수 · torch 곰팡이 횃불 수 · smokes 모깃불 수
##   idle    병 20일 뒤 아침 10시 · 낮 15시 한가한 어른 평균 (TUSE_IDLE 하는 일) · jobless 일터 없는 어른 평균 · away 나들이로 나가 있던 사람 평균
##   pop · ms (고비 → 넘은 날) · d20 (병 20일 지문 — Q39 · Q40 칸은 뺌) · log (나들이 기록 [날, 나무, 사람, 거리])
extends SceneTree

const H := 3600.0
const D := 86400.0
const SKIP_KEYS := ["explore_rng", "explore_party", "explore_more_t", "explore_goals", "explore_seen", "explore_v", "explore_hero", "explore_log", "tree_use"]
const IDLE := ["", "idle", "rest", "social", "play", "chores", "wander"]
const KINDS := ["cherry", "pine", "ginkgo", "maple", "fruit"]

var jw: JarWorld
var mode := "none"
var last_help := -1.0e9


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var s0 := int(args[0]) if args.size() > 0 else 1
	var s1 := int(args[1]) if args.size() > 1 else s0
	var days := int(args[2]) if args.size() > 2 else 200
	mode = args[3] if args.size() > 3 else "none"
	var mo := int(args[4]) if args.size() > 4 else 4
	var dy := int(args[5]) if args.size() > 5 else 15
	Village.default_created = {"year": 2026, "month": mo, "day": dy}
	Village.start_aware = false
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
	var out := {"seed": s, "mode": mode, "days": days, "d20": "", "dist": {}, "seen": {}}
	for t: Dictionary in ww.great_trees:
		out["dist"][String(t["kind"])] = snappedf(Vector2(t["x"], t["y"]).distance_to(v.center), 1.0)
	var hs := 0.0
	var hn := 0
	var fs := 0.0
	var idle := 0.0
	var jobless := 0.0
	var away := 0.0
	var ni := 0
	var feasts := 0
	var last_fest := v.festival_t
	var last_mf := -1.0
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
		if v.festival_t != last_fest:
			last_fest = v.festival_t
			feasts += 1
		var mf: Dictionary = v.milestones.get("feast", {})
		if not mf.is_empty() and float(mf.get("t0", -1.0)) != last_mf:
			last_mf = float(mf.get("t0", -1.0))
			feasts += 1
		if absf(day - 20.0) < 0.5 / 24.0 and String(out["d20"]) == "":
			var dd := v.to_dict()
			for k: String in SKIP_KEYS:
				dd.erase(k)
			out["d20"] = SaveCodec.digest(dd)
		if day >= 20.0:
			hs += v.avg_happiness()
			hn += 1
			fs += v.food_total() / maxf(1.0, Production.day_need(v))
			if hr == 10 or hr == 15:
				var a := 0
				var j := 0
				var w := 0
				for p: Resident in v.people:
					if not p.is_adult():
						continue
					if p.action in IDLE:
						a += 1
					if p.job < 0:
						j += 1
					if p.action == "tree_trip":
						w += 1
				idle += a
				jobless += j
				away += w
				ni += 1
	var seen = v.get("explore_seen")
	if seen is Dictionary:
		for k: String in seen:
			out["seen"][k] = snappedf(float(seen[k]) / D, 0.1)
	var st: Dictionary = v.stats
	var trips := {}
	var people := {}
	var arrive := {}
	var gain := {}
	for k: String in KINDS:
		trips[k] = int(st.get("tuse_trips_" + k, 0))
		people[k] = int(st.get("tuse_people_" + k, 0))
		arrive[k] = int(st.get("tuse_arrive_" + k, 0))
		gain[k] = snappedf(float(st.get("tuse_gain_" + k, 0.0)), 0.1)
	trips["fruit"] = int(st.get("fruit_trips", 0))
	gain["fruit"] = snappedf(float(st.get("fruit_food", 0.0)), 1.0)
	out["trips"] = trips
	out["people"] = people
	out["arrive"] = arrive
	out["gain"] = gain
	var block := {}
	for k: String in st:
		if String(k).begins_with("tuse_block_"):
			block[String(k).trim_prefix("tuse_block_")] = int(st[k])
	out["block"] = block
	var tu = v.get("tree_use")
	if tu is Dictionary:
		var fd := {}
		for k: String in (tu as Dictionary).get("first", {}):
			fd[k] = snappedf(float(tu["first"][k]) / D, 0.1)
		out["first"] = fd
		out["log"] = (tu as Dictionary).get("log", [])
	out["happy"] = snappedf(hs / maxf(1.0, hn), 0.001)
	out["food"] = snappedf(fs / maxf(1.0, hn), 0.1)
	out["feasts"] = feasts
	out["sweet"] = int(st.get("tuse_sweet_feasts", 0))
	out["cherry_home"] = int(st.get("tuse_cherry_home", 0))
	out["resin"] = int(st.get("tuse_resin_fires", 0))
	out["torch"] = int(v.mold.stats.get("torch", 0))
	out["smokes"] = int(v.smalls.stats.get("smokes", 0))
	out["idle"] = snappedf(idle / maxf(1.0, ni), 0.1)
	out["jobless"] = snappedf(jobless / maxf(1.0, ni), 0.1)
	out["away"] = snappedf(away / maxf(1.0, ni), 0.01)
	out["pop"] = v.people.size()
	out["stock"] = {"송진": snappedf(float(v.stock.get("송진", 0.0)), 0.1), "은행알": snappedf(float(v.stock.get("은행알", 0.0)), 1.0), "단풍 엿": snappedf(float(v.stock.get("단풍 엿", 0.0)), 0.1)}
	var ms := {}
	var passed: Dictionary = v.milestones.get("passed", {})
	for id: String in Milestones.ORDER:
		ms[id] = snappedf(float((passed[id] as Dictionary)["t"]) / D, 0.01) if passed.has(id) else -1.0
	out["ms"] = ms
	var bad := 0
	for q: Village in jw.settlements:
		bad += q.check_invariants().size() + q.violations.size()
	out["bad"] = bad
	out["secs"] = int((Time.get_ticks_msec() - t0) / 1000.0)
	print("TUSE " + JSON.stringify(out))


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
