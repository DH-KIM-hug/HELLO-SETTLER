## 수명·출산 속도 재 보기 (ROADMAP Q5, 2026-11-10) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다.
## 넓은 세상 + 기본 키트를 병 N일 돌리며 (tools/balance_v5_report.gd와 같은 하루: 지켜봄 → 비움(CatchUp ×6) 되풀이),
## 날마다 인구·나이 구성·출생·사망·집·먹을 것·시대 점수·지폐를 한 줄씩 찍는다. 모으기는 밖에서 (로그의 DAY · CHIEF · DEATH · PACE · END 줄).
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_lifespan.gd -- consts
##   godot --headless --path godot -s res://tools/measure_lifespan.gd -- run <변형> <시드> <일수> [light|typical|heavy] [이주민 뽑기/현실 하루=0]
##
## 변형: game (= base) — 게임 코드 그대로. 뒤에 '+이름'을 붙여 거인의 손만 바꾼다:
##   game+nohelp    거인이 아무것도 주지 않는다 (하늘 낟알 없음 · 소원 안 들어줌) — 공물 거두기·제단 넓히기는 그대로
##   game+nofloor   '어린것이 드물면 한 집이 아기를 맞는다'(Balance.BIRTH_LITTLE_MIN)만 끈 것처럼 — 걸음 묶음마다 Village.birth_floor_t를 지금으로 써서 쉬는 날이 끝나지 않게 한다
##   game+calmfloor 흉내 (게임에 없는 안 — 6.9장): 지난 병 하루 안에 먹을 것이 바닥난 적이 있으면(Village.last_short_t · Balance.STARVED_RECENT) 그 걸음 묶음에는 아기를 맞지 않는다.
##                  쉬는 날 셈은 건드리지 않는다 (묶음 앞에 birth_floor_t를 지금으로 써 두었다가 묶음 뒤에 되돌림)
##   (여럿: game+nohelp+nofloor)
##
## 1단계(2026-11-10 오전)에는 나이 먹는 빠르기(x2 · adult3 …)와 출산 속도 규칙(kids · room · gap · floor …)을 이 도구가 흉내 냈다 —
## docs/measure/lifespan_2026-11-10.md 1~6.8장의 숫자가 그것. 규칙이 게임에 들어간 뒤(Balance.AGE_K_ADULT · BIRTH_LITTLE_*)로는 흉내와 진짜가 겹치지 않게
## 흉내 쪽을 지웠다 (옛 도구는 커밋 197e1a0). 6.9장부터는 이 도구의 'game'.
##   날마다 CHIEF 줄(창고·집 필요·땅)과 끝에 PACE 줄(36일 인구·출생, 40일부터 어린것 평균·최소·4명 이상인 날·0명이 이어진 날·빠듯한 때 맞은 아기 수) · MOMS 줄(엄마마다 낳은 수)을 더 찍는다.
extends SceneTree

const H := 3600.0
const D := 86400.0

## 놀이 패턴 → [현실 하루 접속 횟수, 한 번에 지켜보는 현실 분]. 비운 시간 = (24시간 − 지켜본 시간) ÷ 횟수 (모두 등불 12시간 안)
const PATTERNS := {"light": [2, 5.0], "typical": [3, 10.0], "heavy": [3, 20.0]}

var jw: JarWorld
var variant := "game"
var no_help := false               # '+nohelp': 하늘 낟알·소원 없음
var no_floor := false              # '+nofloor': 빠듯한 때 아기 맞기를 끈 것처럼
var calm_floor := false            # '+calmfloor': 지난 하루 안에 먹을 것이 바닥났으면 아기를 맞지 않는 것처럼 (흉내)
var held := {}                     # 마을 instance id → [되돌릴 birth_floor_t, 써 둔 값]
var drng := RandomNumberGenerator.new()
var seed_v := 0
var mig_per_day := 0
var mig_bought := 0
var mig_people := 0

var helps := 0
var last_help := -1.0e9
var lean := 0
var in_lean := false
var income := 0.0
var era_at := [-1.0, -1.0, -1.0]
# 하루 모음
var cur_day := 0
var d_samples := 0
var d_short := 0
var d_gate_food := 0
var d_gate_care := 0
var d_blocked := 0
var d_food_min := 1.0e9
var short_days := 0
var floor_last := {}               # 마을 instance id → 마지막으로 본 Village.birth_floor_t
var floor_births := 0              # 빠듯한 때 (먹을 것 문이 닫힌 채) 맞은 아기 수
var kid_days: Array = []           # 날마다 [병 날, 어린것 수, 인구, 태어난 수] — 끝에 PACE 줄


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "consts"
	if mode == "consts":
		_consts()
		quit()
		return
	variant = args[1] if args.size() > 1 else "game"
	var parts := variant.split("+")
	if not parts[0] in ["game", "base"]:
		push_error("unknown variant %s — only 'game' (the real code) is left; the simulated variants were removed when the rule went into the game" % parts[0])
		quit(1)
		return
	for i in range(1, parts.size()):
		match parts[i]:
			"nohelp":
				no_help = true
			"nofloor":
				no_floor = true
			"calmfloor":
				calm_floor = true
			_:
				push_error("unknown option " + parts[i])
				quit(1)
				return
	seed_v = int(args[2]) if args.size() > 2 else 11
	var days := int(args[3]) if args.size() > 3 else 60
	var pat := args[4] if args.size() > 4 else "typical"
	mig_per_day = int(args[5]) if args.size() > 5 else 0
	drng.seed = hash([seed_v, "lifespan-tool"])
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	_run(days, pat)
	quit()


# ───────────────────────── 상수 + 노환 분포 (식 그대로 적분) ─────────────────────────
func _consts() -> void:
	print("CONST AGE_K=%.1f AGE_K_ADULT=%.1f BIRTH_LITTLE max=%d min=%d min_pop=%d rest=%.1f AGE_BABY=%.1f AGE_ADULT=%.1f AGE_ELDER=%.1f CARE_DAYS=%.2f MARRY=%.0f~%.0f BIRTH_WIFE=%.0f~%.0f YEARS_PER_DAY=%.1f" % [
		Balance.AGE_K, Balance.AGE_K_ADULT, Balance.BIRTH_LITTLE_MAX, Balance.BIRTH_LITTLE_MIN, Balance.BIRTH_LITTLE_MIN_POP, Balance.BIRTH_LITTLE_REST_DAYS, Balance.AGE_BABY, Balance.AGE_ADULT, Balance.AGE_ELDER, Balance.CARE_DAYS, Balance.MARRY_MIN, Balance.MARRY_MAX,
		Balance.BIRTH_WIFE_MIN, Balance.BIRTH_WIFE_MAX, Balance.YEARS_PER_DAY])
	print("CONST DEATH_FROM=%.0f DEATH_BASE=%.2f DEATH_SLOPE=%.2f DEATH_MAX_AGE=%.0f MARRY_RATE=%.2f BIRTH_RATE=%.2f CARE_CAP=%d BIRTH_FOOD_DAYS=%.1f" % [
		Balance.DEATH_FROM, Balance.DEATH_BASE, Balance.DEATH_SLOPE, Balance.DEATH_MAX_AGE, Balance.MARRY_RATE, Balance.BIRTH_RATE, Balance.CARE_CAP, Balance.BIRTH_FOOD_DAYS])
	print("CONST SPEED normal=x%.0f (1 jar day = %.1f real min) AWAY_RATES=%s default=x%.0f LAMP_HOURS=%s" % [
		float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I]), D / float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I]) / 60.0, str(Balance.AWAY_RATES),
		float(Balance.AWAY_RATES[Balance.AWAY_DEFAULT_I]), str(Market.LAMP_HOURS)])
	print("CONST jar days: baby<%.0f child<%.0f adult<%.0f (elder from) certain death>%.0f" % [
		_jar(Balance.AGE_BABY), _jar(Balance.AGE_ADULT), _jar(Balance.AGE_ELDER), _jar(Balance.DEATH_MAX_AGE)])
	for mult: float in [1.0, 0.8, 1.15]:
		var s := 1.0                    # 살아 있을 몫
		var la := Balance.DEATH_FROM
		var step := 0.001
		var mean := 0.0
		var q := {0.1: -1.0, 0.5: -1.0, 0.9: -1.0}
		while la < Balance.DEATH_MAX_AGE and s > 1e-9:
			var pd := Balance.DEATH_BASE + Balance.DEATH_SLOPE * (la - Balance.DEATH_FROM)
			var die := s * (1.0 - exp(-pd * step))
			mean += die * (la + step * 0.5)
			s -= die
			la += step
			for k: float in q:
				if float(q[k]) < 0.0 and 1.0 - s >= k:
					q[k] = la
		mean += s * Balance.DEATH_MAX_AGE          # 상한에 닿은 몫
		for k: float in q:
			if float(q[k]) < 0.0:
				q[k] = Balance.DEATH_MAX_AGE
		print("OLDAGE lifespan_mult=%.2f | life days mean %.2f p10 %.2f p50 %.2f p90 %.2f | jar days mean %.1f p10 %.1f p50 %.1f p90 %.1f max %.0f | reach cap %.1f%%" % [
			mult, mean * mult, float(q[0.1]) * mult, float(q[0.5]) * mult, float(q[0.9]) * mult,
			_jar(mean * mult), _jar(float(q[0.1]) * mult), _jar(float(q[0.5]) * mult), _jar(float(q[0.9]) * mult),
			_jar(Balance.DEATH_MAX_AGE * mult), 100.0 * s])
	var ages := PackedStringArray()
	for f: Array in Balance.FIRST_SETTLERS:
		ages.append("%.1f" % float(f[2]))
	print("FOUNDERS ages (life days): ", ", ".join(ages))


## 일생 날 나이 → 태어나서 그 나이가 될 때까지의 병 날 (어린 시절 AGE_K · 어른·노인 AGE_K_ADULT)
static func _jar(age: float) -> float:
	return minf(age, Balance.AGE_ADULT) * Balance.AGE_K + maxf(0.0, age - Balance.AGE_ADULT) * Balance.AGE_K_ADULT


# ───────────────────────── 빠듯한 때 맞은 아기 (Village.birth_floor_t) ─────────────────────────
## 걸음 묶음(병 1시간 이하) 앞: '+nofloor'면 쉬는 날이 끝나지 않게 한다
func _before() -> void:
	for q: Village in jw.settlements:
		var id := q.get_instance_id()
		if no_floor:
			q.birth_floor_t = q.t
			floor_last[id] = q.t
		elif calm_floor and q.t - q.last_short_t < Balance.STARVED_RECENT:
			held[id] = [q.birth_floor_t, q.t]
			q.birth_floor_t = q.t


## 걸음 묶음 뒤: birth_floor_t가 바뀌었으면 그런 아기가 하나 태어난 것 (병 하루에 하나까지라 놓치지 않는다)
func _after() -> void:
	for q: Village in jw.settlements:
		var id := q.get_instance_id()
		if held.has(id):                  # '+calmfloor': 묶음 동안 막아 둔 것을 되돌린다 (쉬는 날 셈은 그대로)
			if q.birth_floor_t == float(held[id][1]):
				q.birth_floor_t = float(held[id][0])
			held.erase(id)
		var was := float(floor_last.get(id, -1.0))
		if q.birth_floor_t != was:
			if not no_floor and q.birth_floor_t >= 0.0:
				floor_births += 1
			floor_last[id] = q.birth_floor_t


# ───────────────────────── 한 판 ─────────────────────────
func _run(days: int, pat: String) -> void:
	var t0 := Time.get_ticks_msec()
	var pp: Array = PATTERNS.get(pat, PATTERNS["typical"])
	var sessions := int(pp[0])
	var watch_real := float(pp[1]) * 60.0                                   # 한 번 지켜보는 현실 초
	var away_real := (86400.0 - sessions * watch_real) / sessions           # 한 번 비우는 현실 초
	var lamp_s := float(Market.LAMP_HOURS[0]) * H
	var rate := float(Balance.AWAY_RATES[Balance.AWAY_DEFAULT_I])
	var watch_j := watch_real * float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I])   # 병 초
	var away_j := minf(away_real, lamp_s) * rate
	var per_real_day := sessions * (watch_j + away_j) / D
	Market.reset()
	Market.first_paid = false
	Market.mig_seed = seed_v * 7919 + 13
	jw = JarWorld.create_with_kit(seed_v, WorldCfg.SIZE, Kits.make([]))
	var v := jw.primary()
	Market.today_override = "R1"
	print("START variant %s seed %d days %d pattern %s | per session watch %.2f jar d + away %.2f jar d | %.2f jar days per real day | mig/day %d" % [
		variant, seed_v, days, pat, watch_j / D, away_j / D, per_real_day, mig_per_day])
	var tapped := 0
	var dropped := false
	while v.t < 23.0 * H:                  # 창세의 날 (balance_v5_report와 같음)
		_advance(5.0 * 60.0)
		if tapped < 3 and v.t > (20.0 + 20.0 * tapped) * 60.0:
			Awakening.witness(v, "tap")
			tapped += 1
		if not dropped and v.t > 50.0 * 60.0:
			Awakening.witness(v, "drop")
			dropped = true
		if fmod(v.t, H) < 300.0:
			_sample(v, true)
		if _hour(v) >= 19.6 and v.cal_day(v.t) == 1:
			_collect()
		_grant()
	_collect()
	var session_i := 0
	while v.t < days * D and not _all().is_empty():
		Market.today_override = "R%d" % (1 + int(v.t / (per_real_day * D)))
		if mig_per_day > 0 and session_i % sessions == 0:
			_buy_migrants(v)
		session_i += 1
		var t_end := v.t + watch_j
		while v.t < t_end - 1.0:           # 지켜봄: 한 시간씩
			_advance(minf(H, t_end - v.t))
			for q: Village in jw.settlements:
				q.crises.clear()
				if q.revelation_pending():
					q.reveal()
			var hr := int(_hour(v))
			if hr == 8 or hr == 20:
				_collect()
			_grant()
			_sample(v, true)
		_collect()
		_buy_altar()
		var left := away_j                 # 비움: 병 한 시간씩 따라잡기
		while left > 1.0:
			var chunk := minf(H, left)
			_before()
			var c := CatchUp.new(v, chunk / rate, lamp_s, jw, rate)
			c.run()
			c.finish()
			_after()
			left -= chunk
			_sample(v, false)
		_collect()
		_grant()
	_flush_day(v)
	_end(v, per_real_day, (Time.get_ticks_msec() - t0) / 1000.0)


func _advance(dt: float) -> void:
	_before()
	jw.advance(dt)
	_after()


func _all() -> Array:
	var out := []
	for q: Village in jw.settlements:
		out.append_array(q.people)
	return out


func _sample(v: Village, watching: bool) -> void:
	var day := int(v.t / D)
	if day != cur_day:
		_flush_day(v)
		cur_day = day
	var need := 0.0
	var food := 0.0
	for q: Village in jw.settlements:
		need += Production.day_need(q)
		food += q.food_total()
	var fd := food / maxf(1.0, need)
	d_samples += 1
	d_food_min = minf(d_food_min, fd)
	if v.deficit > 0.0 or v.t - v.last_short_t < H:
		d_short += 1
	if v.food_total() < Balance.BIRTH_FOOD_DAYS * Production.day_need(v):
		d_gate_food += 1
	var babies := 0
	var adults := 0
	for p: Resident in v.people:
		if p.age < Balance.CARE_DAYS:
			babies += 1
		elif p.is_adult():
			adults += 1
	if babies * Balance.CARE_CAP >= adults:
		d_gate_care += 1
	d_blocked += _blocked_wives(v)
	if fd < 1.0 and not in_lean and v.t > D:
		in_lean = true
		lean += 1
	elif fd >= 1.5:
		in_lean = false
	if watching and not no_help and fd < 1.0 and v.t - last_help >= D:      # 거인의 손: 비축이 하루치 아래면 하늘 낟알 (병 하루에 한 번까지)
		v.manna_fall("giant")
		helps += 1
		last_help = v.t
	for e in 3:
		if float(era_at[e]) < 0.0 and v.era > e:
			era_at[e] = v.t / D


## 아이를 낳을 수 있는 아내 가운데 집이 없거나 꽉 찼고, 옮길 집(가족 + 1 자리)도 없는 수 — Village._births의 집 문과 같은 셈
func _blocked_wives(v: Village) -> int:
	var occ := v.occupancy()
	var hs := v.houses()
	var n := 0
	for w: Resident in v.people:
		if not (w.sex == "f" and w.partner >= 0 and w.age >= Balance.BIRTH_WIFE_MIN and w.age < Balance.BIRTH_WIFE_MAX):
			continue
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
			n += 1
	return n


func _flush_day(v: Village) -> void:
	if d_samples == 0:
		return
	var n := [0, 0, 0, 0]              # 아기 · 아이 · 어른 · 노인
	var born := 0
	var died := 0
	var starved := 0
	var cap := 0
	var houses := 0
	var fert := 0
	var couples := 0
	var singles := 0
	var workers := 0
	var carers := 0
	var built := 0
	for q: Village in jw.settlements:
		born += int(q.stats["born"])
		died += int(q.stats["died"])
		starved += int(q.stats["starved"])
		fert += q.fertile_couples()
		for b: Building in q.buildings:
			if b.built:
				built += 1
				if b.is_house():
					houses += 1
					cap += b.cap()
		var has_baby := {}
		for p: Resident in q.people:
			if p.age < Balance.CARE_DAYS and p.parents.size() == 2:
				has_baby[p.parents[0]] = true
				has_baby[p.parents[1]] = true
		for p: Resident in q.people:
			n[0 if p.is_baby() else (1 if p.is_child() else (3 if p.is_elder() else 2))] += 1
			if p.sex == "f" and p.partner >= 0:
				couples += 1
			if p.partner < 0 and p.age >= Balance.MARRY_MIN and p.age < Balance.MARRY_MAX:
				singles += 1
			if p.job >= 0:
				workers += 1
			if has_baby.has(p.id):
				carers += 1
	var pop: int = n[0] + n[1] + n[2] + n[3]
	if d_short > 0:
		short_days += 1
	print("DAY v=%s seed=%d day=%d pop=%d baby=%d child=%d adult=%d elder=%d born=%d died=%d starved=%d houses=%d cap=%d built=%d couples=%d fert=%d singles=%d workers=%d carers=%d blocked=%.2f foodmin=%.2f short=%d gate_food=%.2f gate_care=%.2f lean=%d helps=%d era=%d pts=%.1f notes=%.0f sett=%d" % [
		variant, seed_v, cur_day + 1, pop, n[0], n[1], n[2], n[3], born, died, starved, houses, cap, built, couples, fert, singles, workers, carers,
		float(d_blocked) / d_samples, d_food_min, 1 if d_short > 0 else 0, float(d_gate_food) / d_samples, float(d_gate_care) / d_samples,
		lean, helps, v.era, v.era_pts, income, jw.settlements.size()])
	kid_days.append([cur_day + 1, int(n[0]) + int(n[1]), pop, born])
	# 촌장이 보는 것 (읽기만): 창고 · 집 필요(house_need) · 땅 한계 · 짓는 터 · 일 없는 어른
	var hn := v.house_need()
	var sites := 0
	var hcap := 0
	for b: Building in v.buildings:
		if b.is_site():
			sites += 1
		if b.built and b.is_house():
			hcap += b.cap()
	var idle := 0
	for p: Resident in v.people:
		if p.is_adult() and p.job < 0:
			idle += 1
	print("CHIEF v=%s seed=%d day=%d tools=%.0f plank=%.0f stone=%.0f logs=%.0f food_days=%.2f hn_free=%d hn_need=%d short=%d crowded=%d homeless=%d land=%.0f cap=%d era_house=%s farms=%d sites=%d idle=%d" % [
		variant, seed_v, cur_day + 1, float(v.stock["도구"]), float(v.stock["판자"]), float(v.stock["돌"]), float(v.stock.get("통나무", 0.0)),
		v.food_total() / maxf(1.0, Production.day_need(v)), int(hn["free"]), int(hn["need"]), 1 if bool(hn["short"]) else 0, 1 if bool(hn["crowded"]) else 0,
		1 if bool(hn["homeless"]) else 0, v.land_capacity() * Balance.HOUSE_SLACK, hcap, String(Balance.ERA_HOUSE[mini(v.era, 3)]), v.count_type("농장"), sites, idle])
	d_samples = 0
	d_short = 0
	d_gate_food = 0
	d_gate_care = 0
	d_blocked = 0
	d_food_min = 1.0e9


## 끝 요약 — 36일(현실 첫 3일) 인구·출생과 40일부터의 어린것(아기 + 아이): 평균 · 최소 · 4명 이상인 날의 몫 · 0명이 이어진 가장 긴 날 수
func _pace_line() -> void:
	var pop36 := -1
	var born36 := -1
	var sum := 0
	var cnt := 0
	var lo := 1 << 30
	var ge4 := 0
	var zero := 0
	var zero_max := 0
	for r: Array in kid_days:
		var day := int(r[0])
		var kids := int(r[1])
		if day == 36:
			pop36 = int(r[2])
			born36 = int(r[3])
		if day < 40:
			continue
		sum += kids
		cnt += 1
		lo = mini(lo, kids)
		if kids >= 4:
			ge4 += 1
		zero = zero + 1 if kids == 0 else 0
		zero_max = maxi(zero_max, zero)
	print("PACE v=%s seed=%d pop36=%d born36=%d from=40 days=%d kids_avg=%.2f kids_min=%d ge4=%.3f zero_run=%d floor_births=%d" % [
		variant, seed_v, pop36, born36, cnt, float(sum) / maxf(1, cnt), lo if cnt > 0 else -1, float(ge4) / maxf(1, cnt), zero_max, floor_births])


func _end(v: Village, per_real_day: float, secs: float) -> void:
	var why := {}
	for q: Village in jw.settlements:
		for p: Resident in q.dead:
			why[p.death_why] = int(why.get(p.death_why, 0)) + 1
			print("DEATH v=%s seed=%d day=%.1f age=%.2f why=%s native=%d" % [variant, seed_v, p.death_t / D, p.age, p.death_why, 1 if p.parents.size() == 2 else 0])
	# 엄마 나이 (일생 날): 이 판에서 태어난 사람마다 엄마 나이 − 아이 나이 (죽은 사람도 찾음) → 한 세대의 길이
	var mom_sum := 0.0
	var mom_n := 0
	for q: Village in jw.settlements:
		var by_id := {}
		for p: Resident in q.people + q.dead:
			by_id[p.id] = p
		for p: Resident in q.people + q.dead:
			if p.parents.size() != 2 or not by_id.has(p.parents[0]):
				continue
			if p.born_t <= 0.0:
				continue                      # 처음부터 있던 아이
			var mom: Resident = by_id[p.parents[0]]
			if mom.dead and (not p.dead or p.death_t > mom.death_t):
				continue                      # 엄마가 먼저 떠남 — 나이 차를 알 수 없음
			if p.dead and not mom.dead:
				continue
			var gap := mom.age - p.age
			if gap >= Balance.BIRTH_WIFE_MIN - 0.5 and gap <= Balance.BIRTH_WIFE_MAX + 0.5:
				mom_sum += gap
				mom_n += 1
	_pace_line()
	print("MOMAGE v=%s seed=%d mean=%.2f n=%d" % [variant, seed_v, mom_sum / maxf(1, mom_n), mom_n])
	# 엄마마다 낳은 수 (이 판에서 태어난 아이만, 죽은 사람도 셈) — 출산이 몇 집에 몰리는지. 여자는 낳는 나이(BIRTH_WIFE_MIN)에서 일생 2일이 지난 사람만
	var per := {}
	var hist := [0, 0, 0, 0, 0, 0, 0]          # 0 · 1 · 2 · 3 · 4 · 5 · 6명 이상
	var most := 0
	for q: Village in jw.settlements:
		for p: Resident in q.people + q.dead:
			if p.parents.size() == 2 and p.born_t > 0.0:
				per[p.parents[0]] = int(per.get(p.parents[0], 0)) + 1
	for q: Village in jw.settlements:
		for p: Resident in q.people + q.dead:
			if p.sex != "f" or p.age < Balance.BIRTH_WIFE_MIN + 2.0:
				continue
			var c := int(per.get(p.id, 0))
			hist[mini(c, 6)] += 1
			most = maxi(most, c)
	print("MOMS v=%s seed=%d none=%d one=%d two=%d three=%d four=%d five=%d six_up=%d most=%d" % [variant, seed_v, hist[0], hist[1], hist[2], hist[3], hist[4], hist[5], hist[6], most])
	for e in 3:
		if float(era_at[e]) < 0.0 and v.era > e:
			era_at[e] = v.t / D
	var bad := PackedStringArray()
	for q: Village in jw.settlements:
		bad.append_array(q.check_invariants())
		bad.append_array(PackedStringArray(q.violations))
	print("END v=%s seed=%d days=%.1f per_real_day=%.2f pop=%d era=%d era1_day=%.1f era2_day=%.1f short_days=%d lean=%d helps=%d notes=%.0f mig_bought=%d mig_people=%d causes=%s spared=%d marriages=%d moves=%d invariants=%d secs=%.0f" % [
		variant, seed_v, v.t / D, per_real_day, _all().size(), v.era, float(era_at[0]), float(era_at[1]), short_days, lean, helps, income,
		mig_bought, mig_people, JSON.stringify(why), int(v.stats.get("spared", 0)), int(v.stats["marriages"]), int(v.stats["moves"]), bad.size(), secs])
	if not bad.is_empty():
		print("  !! ", bad.slice(0, 5))


# ───────────────────────── 거인의 하루 (balance_v5_report와 같음) ─────────────────────────
func _collect() -> void:
	for q: Village in jw.settlements:
		if q.altar_items().is_empty():
			continue
		var n0 := Market.notes
		q.take_all()
		income += Market.notes - n0
		if q.revelation_pending():
			q.reveal()


func _buy_altar() -> void:
	for q: Village in jw.settlements:
		var nx: Dictionary = Altar.next(q)
		if not nx.is_empty() and String(nx["lock"]) == "" and Market.notes >= float(nx["cost"]) * 1.5:
			Altar.expand(q)


func _grant() -> void:
	if no_help:
		return
	for q: Village in jw.settlements:
		for l: Dictionary in q.open_letters("wish"):
			q.grant_wish(int(l["id"]))


## 현실 하루의 첫 접속: 지폐가 되면 이주민 뽑기 (하루 mig_per_day번까지) — 마을 중심 곁에 내려놓는다
func _buy_migrants(v: Village) -> void:
	for i in mig_per_day:
		var price := Immigrants.price()
		if Market.notes < price or Immigrants.left_today() <= 0:
			return
		Market.notes -= price
		var sd := Immigrants.note_bought()
		var a := TAU * drng.randf()
		var p := v.center + Vector2(cos(a), sin(a)) * 3.0
		var made := Immigrants.land(v, p, sd)
		mig_bought += 1
		mig_people += made.size()


func _hour(v: Village) -> float:
	return fmod(v.start_clock + v.t, D) / H
