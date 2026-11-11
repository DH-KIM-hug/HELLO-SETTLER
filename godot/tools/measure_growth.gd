## 마을이 자라는 속도 재 보기 (ROADMAP Q11, 2026-11-11) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다.
## 넓은 세상 + 기본 키트 (tools/measure_opening_food.gd · measure_lifespan.gd와 같은 시작), 거인은 아무것도 주지 않는다
## (하늘 낟알 없음 · 소원 안 들어줌 — 톡 세 번 · 떨어뜨리기 한 번(목격)과 공물 받기 · 계시는 한다).
## 병 한 시간마다 본다: 식구 수(첫 무리 · 병 전체) · 어린것 · 출생 · 죽음(까닭) · 분가 · 고비(Milestones) · 먹을 것(빈 창고 시간 · 배고픔) ·
## 집(빈자리 · 집 없는 사람) · 출산 문(먹을 것 · 돌봄 · 어린것 상한 · 집)이 닫혀 있던 몫. 씨앗마다 GROW 줄 하나(JSON) — 모으기는 밖에서.
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_growth.gd -- run <거인> <씨앗 처음> <씨앗 끝> <일수> [지켜보는 걸음 초]
##
## 거인:
##   watch   내내 지켜본다 (병 한 시간씩 JarWorld.advance). 걸음은 기본 30초 (tests/run.gd test_village_population과 같은 걸음 — 병 120일을 재려고)
##   mixed   현실의 하루 흉내: 하루 세 번 접속, 한 번에 현실 10분(보통 속도 = 병 2일) 지켜보고, 사이는 비움
##           (현실 7시간 50분 → CatchUp 보통 배율 ×6 = 병 약 1.96일, 등불 12시간 안). 현실 하루 = 병 약 11.9일. 지켜보는 걸음은 기본 10초
extends SceneTree

const H := 3600.0
const D := 86400.0
const WINDOWS := [0.0, 20.0, 40.0, 60.0, 120.0]      # 병 날 구간 (0~20 · 20~40 · 40~60 · 60~120)
const POP_DAYS := [10, 20, 30, 36, 60, 120]

var jw: JarWorld
var mode := "watch"
var seed_v := 0
var watch_step := -1.0

var births: Array = []               # 태어난 때 (병 날)
var splits: Array = []               # [병 날, 떠난 사람 수]
var pop_at := {}                     # 병 날 → [첫 무리, 병 전체, 어린것, 아기, 집 자리, 집 없는 사람]
var born_seen := 0
var sett_seen := 1
var hunger_max := 0.0
var win: Array = []                  # 구간마다 {n, short, hungry, gate_food, gate_care, gate_little, blocked, wives, homeless, nofree, littles, babies, baby_h}
var hungry_first := -1.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	mode = args[1] if args.size() > 1 else "watch"
	if not mode in ["watch", "mixed"]:
		push_error("unknown watcher %s (watch | mixed)" % mode)
		quit(1)
		return
	var s0 := int(args[2]) if args.size() > 2 else 1
	var s1 := int(args[3]) if args.size() > 3 else s0
	var days := int(args[4]) if args.size() > 4 else 60
	watch_step = float(args[5]) if args.size() > 5 else (30.0 if mode == "watch" else Balance.STEP)
	print("CONST BIRTH_RATE %.2f BIRTH_FOOD_DAYS %.2f CARE_CAP %d CARE_DAYS %.2f LITTLE_MAX %d LITTLE_MIN %d LITTLE_MIN_POP %d MARRY_RATE %.2f AGE_K %.1f | watch_step %.0f" % [
		Balance.BIRTH_RATE, Balance.BIRTH_FOOD_DAYS, Balance.CARE_CAP, Balance.CARE_DAYS, Balance.BIRTH_LITTLE_MAX, Balance.BIRTH_LITTLE_MIN,
		Balance.BIRTH_LITTLE_MIN_POP, Balance.MARRY_RATE, Balance.AGE_K, watch_step])
	for s in range(s0, s1 + 1):
		_run(s, days)
	quit()


func _new_world(s: int) -> Village:
	seed_v = s
	Market.reset()
	Market.first_paid = false
	Market.mig_seed = s * 7919 + 13
	Market.today_override = "R1"
	jw = JarWorld.create_with_kit(s, WorldCfg.SIZE, Kits.make([]))
	return jw.primary()


func _run(s: int, days: int) -> void:
	var t0 := Time.get_ticks_msec()
	var v := _new_world(s)
	births = []
	splits = []
	pop_at = {}
	born_seen = 0
	sett_seen = 1
	hunger_max = 0.0
	hungry_first = -1.0
	win = []
	for i in WINDOWS.size() - 1:
		win.append({"n": 0, "short": 0, "hungry": 0, "gate_food": 0, "gate_care": 0, "gate_little": 0, "blocked": 0, "wives": 0, "homeless": 0, "nofree": 0, "littles": 0, "babies": 0, "baby_h": 0})
	var lamp_s := float(Market.LAMP_HOURS[0]) * H
	var rate := float(Balance.AWAY_RATES[Balance.AWAY_DEFAULT_I])
	var watch_j := 10.0 * 60.0 * float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I])      # 한 번에 현실 10분 = 병 2일
	var away_j := minf((86400.0 - 3.0 * 600.0) / 3.0, lamp_s) * rate                   # 사이 비움 = 병 약 1.96일
	var tapped := 0
	var dropped := false
	while v.t < 23.0 * H:                  # 창세의 날 (measure_lifespan · measure_opening_food와 같음)
		jw.advance(5.0 * 60.0)
		if tapped < 3 and v.t > (20.0 + 20.0 * tapped) * 60.0:
			Awakening.witness(v, "tap")
			tapped += 1
		if not dropped and v.t > 50.0 * 60.0:
			Awakening.witness(v, "drop")
			dropped = true
		if fmod(v.t, H) < 300.0:
			_sample(v)
		if _hour(v) >= 19.6 and v.cal_day(v.t) == 1:
			_collect()
	_collect()
	var sdt0 := v.step_dt
	while v.t < days * D and not v.people.is_empty():
		var t_end := minf(v.t + (watch_j if mode == "mixed" else days * D), days * D)
		_set_step(watch_step)
		while v.t < t_end - 1.0:           # 지켜봄: 한 시간씩
			jw.advance(minf(H, t_end - v.t))
			for q: Village in jw.settlements:
				q.crises.clear()
				if q.revelation_pending():
					q.reveal()
			var hr := int(_hour(v))
			if hr == 8 or hr == 20:
				_collect()
			_sample(v)
		_set_step(sdt0)
		_collect()
		if mode == "watch":
			break
		var left := minf(away_j, days * D - v.t)     # 비움: 병 한 시간씩 따라잡기
		while left > 1.0:
			var chunk := minf(H, left)
			var c := CatchUp.new(v, chunk / rate, lamp_s, jw, rate)
			c.run()
			c.finish()
			left -= chunk
			_sample(v)
		_collect()
	_line(v, days, (Time.get_ticks_msec() - t0) / 1000.0)


func _set_step(dt: float) -> void:
	for q: Village in jw.settlements:
		q.step_dt = dt


func _sample(v: Village) -> void:
	var day := v.t / D
	var wi := -1
	for i in WINDOWS.size() - 1:
		if day >= float(WINDOWS[i]) and day < float(WINDOWS[i + 1]) + 1e-6:
			wi = i
			break
	# 출생 · 분가 (병 전체)
	var born := 0
	var total := 0
	for q: Village in jw.settlements:
		born += int(q.stats["born"])
		total += q.people.size()
	while born_seen < born:
		births.append(snappedf(day, 0.01))
		born_seen += 1
	if jw.settlements.size() > sett_seen:
		var moved := 0
		for i in range(sett_seen, jw.settlements.size()):
			moved += (jw.settlements[i] as Village).people.size()
		splits.append([snappedf(day, 0.01), moved])
		sett_seen = jw.settlements.size()
	# 식구 · 집 (첫 무리)
	var littles := 0
	var babies := 0
	var adults := 0
	var homeless := 0
	var hungry := false
	for p: Resident in v.people:
		hunger_max = maxf(hunger_max, p.hunger)
		if p.hunger >= Balance.HUNGRY_AT:
			hungry = true
		if p.age < Balance.AGE_ADULT:
			littles += 1
		if p.age < Balance.CARE_DAYS:
			babies += 1
		elif p.is_adult():
			adults += 1
		if p.home < 0:
			homeless += 1
	if hungry and hungry_first < 0.0:
		hungry_first = day
	var occ := v.occupancy()
	var hcap := 0
	var free := 0
	for b: Building in v.houses():
		hcap += b.cap()
		free += maxi(0, b.cap() - int(occ.get(b.id, 0)))
	var dn := int(day + 0.001)
	if POP_DAYS.has(dn) and not pop_at.has(dn) and absf(v.t - dn * D) < 1800.0:
		pop_at[dn] = [v.people.size(), total, littles, babies, hcap, homeless]
	if wi < 0:
		return
	var w: Dictionary = win[wi]
	w["n"] += 1
	if v.deficit > 0.0 or v.t - v.last_short_t < H:
		w["short"] += 1
	if hungry:
		w["hungry"] += 1
	if v.food_total() < Balance.BIRTH_FOOD_DAYS * Production.day_need(v):
		w["gate_food"] += 1
	if babies * Balance.CARE_CAP >= adults:
		w["gate_care"] += 1
	if littles >= Balance.BIRTH_LITTLE_MAX:
		w["gate_little"] += 1
	var bw := _wives(v, occ)
	w["wives"] += bw[0]
	w["blocked"] += bw[1]
	w["homeless"] = maxi(int(w["homeless"]), homeless)
	if free == 0:
		w["nofree"] += 1
	w["littles"] += littles
	w["babies"] += babies
	if babies > 0:
		w["baby_h"] += 1


## [아이를 낳을 수 있는 아내 수, 그 가운데 집 때문에 못 낳는 수] (Village._births의 집 문과 같은 셈 — 읽기만)
func _wives(v: Village, occ: Dictionary) -> Array:
	var hs := v.houses()
	var n := 0
	var blocked := 0
	for w: Resident in v.people:
		if not (w.sex == "f" and w.partner >= 0 and w.age >= Balance.BIRTH_WIFE_MIN and w.age < Balance.BIRTH_WIFE_MAX):
			continue
		n += 1
		var h := v.bld(w.home) if w.home >= 0 else null
		if h != null and int(occ.get(h.id, 0)) < h.cap():
			continue
		var hh := v.household_of(w).size()
		var ok := false
		for b: Building in hs:
			if (h == null or b.id != h.id) and b.cap() - int(occ.get(b.id, 0)) >= hh + 1:
				ok = true
				break
		if not ok:
			blocked += 1
	return [n, blocked]


func _line(v: Village, days: int, secs: float) -> void:
	var deaths := []
	var starved := 0
	var spared := 0
	var bad := 0
	var built := {}
	for q: Village in jw.settlements:
		for p: Resident in q.dead:
			deaths.append([snappedf(p.death_t / D, 0.01), p.death_why])
		starved += int(q.stats["starved"])
		spared += int(q.stats.get("spared", 0))
		bad += q.check_invariants().size() + q.violations.size()
	for b: Building in v.buildings:
		if b.built:
			built[b.type] = int(built.get(b.type, 0)) + 1
	var ms := {}
	var passed: Dictionary = v.milestones.get("passed", {})
	for id: String in Milestones.ORDER:
		ms[id] = snappedf(float((passed[id] as Dictionary)["t"]) / D, 0.01) if passed.has(id) else -1.0
	var out := {"mode": mode, "seed": seed_v, "days": days, "pop": pop_at, "end_pop": v.people.size(), "ms": ms, "births": births, "deaths": deaths, "splits": splits,
		"starved": starved, "spared": spared, "hunger_max": snappedf(hunger_max, 0.01), "hungry_first": snappedf(hungry_first, 0.01), "win": win,
		"built": built, "era": v.era, "aware": v.aware, "settlements": jw.settlements.size(), "bad": bad, "secs": int(secs),
		"steps_n": int((passed["steps"] as Dictionary).get("n", -1)) if passed.has("steps") else -1}     # 첫걸음마에 와 선 이웃 수 (Q9 ⑮)
	print("GROW " + JSON.stringify(out))


func _collect() -> void:
	for q: Village in jw.settlements:
		if q.altar_items().is_empty():
			continue
		q.take_all()
		if q.revelation_pending():
			q.reveal()


func _hour(v: Village) -> float:
	return fmod(v.start_clock + v.t, D) / H
