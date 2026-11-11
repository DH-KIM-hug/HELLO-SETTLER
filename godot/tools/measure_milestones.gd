## 고비 간격 재 보기 (ROADMAP Q9 ⑦, 2026-11-11) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다.
## '마을이 여기까지 왔다'고 할 만한 일이 병 며칠째에 일어나는지 씨앗마다 적는다 — 고비(Milestones)로 삼을 후보를 고르고,
## 고비 없는 가장 긴 동안(병 0~36일)을 세는 데 쓴다 (docs/PROGRESSION.md 4.5 '고비 간격').
## 시작은 tools/measure_growth.gd의 watch와 같다: 넓은 세상 + 기본 키트 · 4월 15일 · 깨닫기 전 · 거인은 아무것도 주지 않는다
## (창조 첫날의 톡 세 번 · 떨어뜨리기 한 번(목격)과 제단 공물 걷기 · 계시만). 병 한 시간씩, 30초 걸음.
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_milestones.gd -- <씨앗 처음> <씨앗 끝> [일수 40] [걸음 초 30]
## 씨앗마다 MILE 줄 하나 (JSON) — 모으기는 밖에서 (tools/measure_milestones_sum.py):
##   ms      고비 id → 넘은 병 날 (Milestones.ORDER 전부, 못 넘었으면 -1)
##   ev      일 이름 → 처음 일어난 병 날 (없으면 -1):
##           born 첫 아기 · steps 첫걸음마 · weaned 마을에서 난 아이가 처음 아기 티를 벗음 · grown 마을에서 난 아이가 처음 어른이 됨 ·
##           grown_kit 처음 온 아이가 처음 어른이 됨 · wedding 첫 혼인 · migrant 첫 이주민 · death 첫 죽음 · elder_death 첫 노환 ·
##           upgrade 처음 넓혀 지음 · house1~3 스스로 다 지은 집 (첫날 뒤 n번째) · pop13~19 식구 수 · era 시대가 바뀜 · aware 깨달음 · split 분가
##   steps_n 첫걸음마 고비에 문 앞까지 와 선 이웃 수 (고비를 못 넘었으면 -1)
##   kinds   사건 kind → [처음 병 날, 횟수] (첫 무리 것만 · 흔한 것은 뺌)
##   built   [병 날, 건물 종류] 다 지은 순서 (첫 무리)
##   firsts  연대기에 '첫'·'처음'이 든 줄 [병 날, 글] (앞에서 40줄)
extends SceneTree

const H := 3600.0
const D := 86400.0
const SKIP_KINDS := [&"chronicle", &"talk_started", &"giant_acted", &"giant_refused", &"manna_fall", &"chain_stalled", &"chain_resumed", &"spoiled",
	&"kid_tagged", &"kid_stack_fell", &"kid_hop_done", &"kid_skip_thrown", &"baby_peeked", &"dog_bark", &"crisis"]

var jw: JarWorld
var seed_v := 0
var watch_step := 30.0
var cursor := 0
var ev := {}
var kinds := {}
var firsts: Array = []
var born_ids: Array = []
var kit_kids: Array = []
var day1_houses := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	var s0 := int(args[0]) if args.size() > 0 else 1
	var s1 := int(args[1]) if args.size() > 1 else s0
	var days := int(args[2]) if args.size() > 2 else 40
	watch_step = float(args[3]) if args.size() > 3 else 30.0
	print("CONST ORDER %s | AGE_K %.1f AGE_BABY %.1f AGE_ADULT %.1f TODDLE %.3f | watch_step %.0f" % [str(Milestones.ORDER), Balance.AGE_K, Balance.AGE_BABY,
		Balance.AGE_ADULT, ChildPlay.TODDLE_AGE, watch_step])
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
	cursor = 0
	ev = {}
	kinds = {}
	firsts = []
	born_ids = []
	kit_kids = []
	day1_houses = {}
	for p: Resident in v.people:
		if p.age < Balance.AGE_ADULT:
			kit_kids.append(p.id)
	var tapped := 0
	var dropped := false
	while v.t < 23.0 * H:                  # 창세의 날 (measure_growth와 같음)
		jw.advance(5.0 * 60.0)
		if tapped < 3 and v.t > (20.0 + 20.0 * tapped) * 60.0:
			Awakening.witness(v, "tap")
			tapped += 1
		if not dropped and v.t > 50.0 * 60.0:
			Awakening.witness(v, "drop")
			dropped = true
		_sample(v)
		if _hour(v) >= 19.6 and v.cal_day(v.t) == 1:
			_collect()
	_collect()
	for b: Building in v.buildings:        # 첫날에 선 집 (처음 받은 것 + 첫날 지은 것) — 그 뒤에 다 지은 집이 '스스로 지은 집'
		if b.built and b.is_house():
			day1_houses[b.id] = true
	for q: Village in jw.settlements:
		q.step_dt = watch_step
	while v.t < days * D and not v.people.is_empty():
		jw.advance(minf(H, days * D - v.t))
		for q: Village in jw.settlements:
			q.crises.clear()
			if q.revelation_pending():
				q.reveal()
		var hr := int(_hour(v))
		if hr == 8 or hr == 20:
			_collect()
		_sample(v)
	_line(v, days, (Time.get_ticks_msec() - t0) / 1000.0)


func _first(key: String, day: float) -> void:
	if not ev.has(key):
		ev[key] = snappedf(day, 0.01)


func _sample(v: Village) -> void:
	var day := v.t / D
	for e: Dictionary in v.events.since(cursor):
		cursor = int(e["n"])
		if int(e["village"]) != v.sid:
			continue
		var k: StringName = e["kind"]
		var ed := float(e["t"]) / D
		if k == &"chronicle":
			var text := String(e["v"])
			if firsts.size() < 40 and (text.contains("첫") or text.contains("처음")):
				firsts.append([snappedf(ed, 0.01), text])
			continue
		if SKIP_KINDS.has(k):
			continue
		var key := String(k)
		if k == &"kid_play_started" and e["v"] is Dictionary:
			key = "play:" + String((e["v"] as Dictionary).get("kind", ""))
		elif k == &"found_object" and e["v"] is Dictionary:
			key = "found:" + String((e["v"] as Dictionary).get("kind", ""))
		if not kinds.has(key):
			kinds[key] = [snappedf(ed, 0.01), 0]
		(kinds[key] as Array)[1] = int((kinds[key] as Array)[1]) + 1
		match k:
			&"born":
				_first("born", ed)
				born_ids.append(int(e["who"]))
			&"first_steps":
				_first("steps", ed)
			&"died":
				_first("death", ed)
			&"awakened":
				_first("aware", ed)
	var pop := v.people.size()
	for n in range(13, 20):
		if pop >= n:
			_first("pop%d" % n, day)
	for id: int in born_ids:
		var p := v.person(id)
		if p == null:
			continue
		if p.age >= Balance.AGE_BABY:
			_first("weaned", day)
		if p.age >= Balance.AGE_ADULT:
			_first("grown", day)
	for id: int in kit_kids:
		var p := v.person(id)
		if p != null and p.age >= Balance.AGE_ADULT:
			_first("grown_kit", day)
	if int(v.stats.get("marriages", 0)) > 0:
		_first("wedding", day)
	if int(v.stats.get("migrants", 0)) > 0:
		_first("migrant", day)
	if int(v.stats.get("upgrades", 0)) > 0:
		_first("upgrade", day)
	if v.era > 0:
		_first("era", day)
	if v.aware:
		_first("aware", day)
	if jw.settlements.size() > 1:
		_first("split", day)
	for p: Resident in v.dead:
		if p.death_why == "노환":
			_first("elder_death", p.death_t / D)


func _line(v: Village, days: int, secs: float) -> void:
	var ms := {}
	var passed: Dictionary = v.milestones.get("passed", {})
	for id: String in Milestones.ORDER:
		ms[id] = snappedf(float((passed[id] as Dictionary)["t"]) / D, 0.01) if passed.has(id) else -1.0
	var built: Array = []
	var own: Array = []
	for b: Building in v.buildings:
		if not b.built:
			continue
		built.append([snappedf(b.built_t / D, 0.01), b.type])
		if b.is_house() and not day1_houses.has(b.id):
			own.append(b.built_t / D)
	built.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	own.sort()
	for i in mini(own.size(), 3):
		ev["house%d" % (i + 1)] = snappedf(float(own[i]), 0.01)
	var bad := 0
	for q: Village in jw.settlements:
		bad += q.check_invariants().size() + q.violations.size()
	var out := {"seed": seed_v, "days": days, "ms": ms, "ev": ev, "kinds": kinds, "built": built, "firsts": firsts, "end_pop": v.people.size(),
		"born": int(v.stats["born"]), "died": int(v.stats["died"]), "day1_houses": day1_houses.size(), "era": v.era, "aware": v.aware,
		"settlements": jw.settlements.size(), "bad": bad, "secs": int(secs),
		"steps_n": int((passed["steps"] as Dictionary).get("n", -1)) if passed.has("steps") else -1}
	print("MILE " + JSON.stringify(out))


func _collect() -> void:
	for q: Village in jw.settlements:
		if q.altar_items().is_empty():
			continue
		q.take_all()
		if q.revelation_pending():
			q.reveal()


func _hour(v: Village) -> float:
	return fmod(v.start_clock + v.t, D) / H
