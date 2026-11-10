## 수명 재 보기 (ROADMAP Q5, 2026-11-10) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다.
## 넓은 세상 + 기본 키트를 병 N일 돌리며 (tools/balance_v5_report.gd와 같은 하루: 지켜봄 → 비움(CatchUp ×6) 되풀이),
## 날마다 인구·나이 구성·출생·사망·집·먹을 것·시대 점수·지폐를 한 줄씩 찍는다. 모으기는 밖에서 (로그의 DAY · DEATH · END 줄).
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_lifespan.gd -- consts
##   godot --headless --path godot -s res://tools/measure_lifespan.gd -- run <변형> <시드> <일수> [light|typical|heavy] [이주민 뽑기/현실 하루=0]
##
## 변형 (나이 먹는 빠르기만 — 도구 안에서 덮어씀. Balance.AGE_K 등 상수는 그대로):
##   base      게임 그대로 (손대지 않음)
##   x1emu     ×1을 도구 방식으로 흉내 (검증용 — base와 통계로 같아야 한다)
##   x2 x3 x4  일생 전체 ×2·×3·×4 (AGE_K 8·12·16과 같은 뜻 — 모든 나이 구간 + 노환 굴림)
##   adult2 adult3 adult4  어린 시절(0~4 일생 날 = 병 16일)은 그대로, 어른·노년(4~)만 ×2·×3·×4
##   c15a3     어린 시절 ×1.5 + 어른·노년 ×3
##   child2    일생 길이는 그대로, 어린 시절(0~4)만 ×2 — 어른 구간(4~20)이 그만큼 짧아짐 (×0.75)
##   x2care x3care  일생 ×2·×3이되 아기 돌봄 기간(CARE_DAYS 0.8 일생 날)은 지금의 병 3.2일 그대로
##   adult2f adult3f  adult2·adult3 + 아이 낳는 나이 창(지금 병 56일)을 병 날로 그대로 — 그 나이를 넘긴 아내의 fert를 0으로
##                    (BIRTH_WIFE_MAX를 18 → 4 + 14 ÷ 배율로 낮춘 것의 어림. fertile_couples()는 여전히 18까지 센다)
##
## 출산 속도 규칙 (2026-11-10 — '어른 ×3'에서 아이가 끊기지 않게): 변형 이름 뒤에 '+규칙=값,값'을 붙인다. 여러 개면 곱한다.
##   예) adult3+kids=6 · adult3+room=0.5,0,24 · adult3+third=4,24+room=0.5,0,24 · adult3+kids=6+reserve=5
##   kids=M[,K]        마을의 어린것(아기 + 아이)이 max(M, 인구 ÷ K)명이면 다음 아기는 기다린다 (K를 안 주면 M만)
##   cradle=M          걸음마 전 아기(CARE_DAYS 전)가 M명이면 기다린다 (지금 규칙은 '아기 × CARE_CAP < 어른')
##   room=SHARE,FLOOR,N   (a) 인구 N명부터: 아내마다 확률 × clamp(빈 침대 ÷ (SHARE × 모든 침대), FLOOR, 1)
##   third=K,N[,AFTER]    (b) 인구 N명부터: AFTER(기본 2)명을 낳은 아내는 확률 ÷ K
##   gap=G,N[,AFTER]      (b) 인구 N명부터: AFTER(기본 2)명을 낳은 아내는 막내를 낳고 병 G × (낳은 수 − AFTER + 1)일을 기다린다
##   reserve=D[,BOOST]    (d) 어린것이 한 명도 없는 채로 병 D일이 지났고 빈 침대가 있으면 확률 × BOOST (기본 20, 다른 규칙을 누름)
##   floor=L,N[,G]        (d′) 인구 N명부터: 어린것이 L명이 안 되면 먹을 것 문이 닫혀 있어도 한 집이 아기를 맞는다 (빈 침대가 있는 집 · 아이가 가장 적은 아내,
##                        마지막 그런 출생 뒤 병 G일(기본 1)은 쉼). 이 규칙만 훅이 아니라 도구가 걸음 묶음 끝에 Village._give_birth를 직접 부른다 (먹을 것 문을 건너뛰어야 해서)
##   규칙은 Village.birth_pace(기본은 비어 있음 — 게임 그대로)에 이 도구의 함수를 걸어서 쓴다. Balance 값은 그대로.
##   날마다 CHIEF 줄(창고·집 필요·땅)과 끝에 PACE 줄(36일 인구·출생, 40일부터 어린것 평균·최소·4명 이상인 날·0명이 이어진 날) · MOMS 줄(엄마마다 낳은 수)을 더 찍는다.
##
## 덮어쓰는 법 (게임 코드 고치지 않음):
##   - 걸음 묶음(병 1시간 이하)이 끝날 때마다 그동안 먹은 나이를 구간 배율로 다시 계산해 Resident.age에 써 넣는다.
##   - 노환 굴림은 Resident.fx["lifespan"]을 아주 크게 해 게임 쪽 굴림을 끄고, 같은 식
##     (DEATH_BASE + DEATH_SLOPE × (la − DEATH_FROM)) × dt / (DAY × AGE_K × 배율), la > DEATH_MAX_AGE면 반드시 — 를 도구가 굴려 Village.kill(p, "노환").
##     혈통 장수·단명 배율은 Bloodlines.effects(blood)에서 읽어 그대로 쓴다.
extends SceneTree

const H := 3600.0
const D := 86400.0
const BIG := 1.0e9
const INF_AGE := 1.0e9

## 놀이 패턴 → [현실 하루 접속 횟수, 한 번에 지켜보는 현실 분]. 비운 시간 = (24시간 − 지켜본 시간) ÷ 횟수 (모두 등불 12시간 안)
const PATTERNS := {"light": [2, 5.0], "typical": [3, 10.0], "heavy": [3, 20.0]}

var jw: JarWorld
var variant := "base"
var bands: Array = []              # [[나이 끝, 배율], …] — 비면 게임 그대로
var fert_cut := 0.0                # > 0이면 이 나이(일생 날)를 넘긴 여자의 fert를 0으로 (adult2f · adult3f)
var age_prev := {}                 # instance id → 고쳐 쓴 나이
var life_mult := {}                # instance id → 혈통 수명 배율 (장수 1.15 · 단명 0.8)
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
var tool_deaths := 0
# 출산 속도 규칙 (변형 이름의 '+규칙=값' — 비면 게임 그대로)
var pace := {}                     # 규칙 이름 → [값, …]
var pstate := {}                   # 마을 instance id → 그 마을의 셈 (걸음마다 한 번 다시 셈)
var floor_last := {}               # 마을 instance id → 'floor' 규칙으로 마지막에 태어난 때
var floor_births := 0
var kid_days: Array = []           # 날마다 [병 날, 어린것 수, 인구, 태어난 수] — 끝에 PACE 줄


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "consts"
	if mode == "consts":
		_consts()
		quit()
		return
	variant = args[1] if args.size() > 1 else "base"
	var parts := variant.split("+")
	var aging := parts[0]
	for i in range(1, parts.size()):
		var kv := parts[i].split("=")
		var vals := []
		if kv.size() > 1:
			for x: String in kv[1].split(","):
				vals.append(float(x))
		if not kv[0] in ["kids", "cradle", "room", "third", "gap", "reserve", "floor"] or vals.is_empty():
			push_error("unknown pacing rule " + parts[i])
			quit(1)
			return
		pace[kv[0]] = vals
	seed_v = int(args[2]) if args.size() > 2 else 11
	var days := int(args[3]) if args.size() > 3 else 60
	var pat := args[4] if args.size() > 4 else "typical"
	mig_per_day = int(args[5]) if args.size() > 5 else 0
	if aging == "adult2f" or aging == "adult3f":
		var s := 2.0 if aging == "adult2f" else 3.0
		fert_cut = Balance.AGE_ADULT + (Balance.BIRTH_WIFE_MAX - Balance.BIRTH_WIFE_MIN) / s
		bands = _bands("adult2" if s == 2.0 else "adult3")
	else:
		bands = _bands(aging)
	drng.seed = hash([seed_v, "lifespan-tool"])
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	_run(days, pat)
	quit()


static func _bands(vname: String) -> Array:
	match vname:
		"base":
			return []
		"x1emu":
			return [[INF_AGE, 1.0]]
		"x2":
			return [[INF_AGE, 2.0]]
		"x3":
			return [[INF_AGE, 3.0]]
		"x4":
			return [[INF_AGE, 4.0]]
		"adult2":       # 어린 시절(0~4)은 지금 그대로 병 16일, 어른·노년만 ×2·×3·×4
			return [[Balance.AGE_ADULT, 1.0], [INF_AGE, 2.0]]
		"adult3":
			return [[Balance.AGE_ADULT, 1.0], [INF_AGE, 3.0]]
		"adult4":
			return [[Balance.AGE_ADULT, 1.0], [INF_AGE, 4.0]]
		"c15a3":        # 어린 시절 ×1.5 (병 24일) + 어른·노년 ×3
			return [[Balance.AGE_ADULT, 1.5], [INF_AGE, 3.0]]
		"child2":       # 어린 시절 병 16일 → 32일, 어른 64일 → 48일, 노년 그대로
			return [[Balance.AGE_ADULT, 2.0], [Balance.AGE_ELDER, 0.75], [INF_AGE, 1.0]]
		"x2care", "x3care":
			var s := 2.0 if vname == "x2care" else 3.0
			var jar_child := Balance.AGE_ADULT * Balance.AGE_K * s          # 어린 시절 병 날
			var jar_care := Balance.CARE_DAYS * Balance.AGE_K                # 돌봄 병 3.2일 그대로
			var mid := (jar_child - jar_care) / ((Balance.AGE_ADULT - Balance.CARE_DAYS) * Balance.AGE_K)
			return [[Balance.CARE_DAYS, 1.0], [Balance.AGE_ADULT, mid], [INF_AGE, s]]
	push_error("unknown variant " + vname)
	return []


# ───────────────────────── 상수 + 노환 분포 (식 그대로 적분) ─────────────────────────
func _consts() -> void:
	print("CONST AGE_K=%.1f AGE_BABY=%.1f AGE_ADULT=%.1f AGE_ELDER=%.1f CARE_DAYS=%.2f MARRY=%.0f~%.0f BIRTH_WIFE=%.0f~%.0f YEARS_PER_DAY=%.1f" % [
		Balance.AGE_K, Balance.AGE_BABY, Balance.AGE_ADULT, Balance.AGE_ELDER, Balance.CARE_DAYS, Balance.MARRY_MIN, Balance.MARRY_MAX,
		Balance.BIRTH_WIFE_MIN, Balance.BIRTH_WIFE_MAX, Balance.YEARS_PER_DAY])
	print("CONST DEATH_FROM=%.0f DEATH_BASE=%.2f DEATH_SLOPE=%.2f DEATH_MAX_AGE=%.0f MARRY_RATE=%.2f BIRTH_RATE=%.2f CARE_CAP=%d BIRTH_FOOD_DAYS=%.1f" % [
		Balance.DEATH_FROM, Balance.DEATH_BASE, Balance.DEATH_SLOPE, Balance.DEATH_MAX_AGE, Balance.MARRY_RATE, Balance.BIRTH_RATE, Balance.CARE_CAP, Balance.BIRTH_FOOD_DAYS])
	print("CONST SPEED normal=x%.0f (1 jar day = %.1f real min) AWAY_RATES=%s default=x%.0f LAMP_HOURS=%s" % [
		float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I]), D / float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I]) / 60.0, str(Balance.AWAY_RATES),
		float(Balance.AWAY_RATES[Balance.AWAY_DEFAULT_I]), str(Market.LAMP_HOURS)])
	print("CONST jar days: baby<%.0f child<%.0f adult<%.0f (elder from) certain death>%.0f" % [
		Balance.AGE_BABY * Balance.AGE_K, Balance.AGE_ADULT * Balance.AGE_K, Balance.AGE_ELDER * Balance.AGE_K, Balance.DEATH_MAX_AGE * Balance.AGE_K])
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
			mean * mult * Balance.AGE_K, float(q[0.1]) * mult * Balance.AGE_K, float(q[0.5]) * mult * Balance.AGE_K, float(q[0.9]) * mult * Balance.AGE_K,
			Balance.DEATH_MAX_AGE * mult * Balance.AGE_K, 100.0 * s])
	var ages := PackedStringArray()
	for f: Array in Balance.FIRST_SETTLERS:
		ages.append("%.1f" % float(f[2]))
	print("FOUNDERS ages (life days): ", ", ".join(ages))


# ───────────────────────── 출산 속도 규칙 (Village.birth_pace 훅) ─────────────────────────
func _hooks() -> void:
	if pace.is_empty():
		return
	for q: Village in jw.settlements:
		if not q.birth_pace.is_valid():
			q.birth_pace = _pace


func _pv(rule: String, i: int, def: float) -> float:
	var a: Array = pace[rule]
	return float(a[i]) if i < a.size() else def


## 마을의 셈: 인구·어린것·걸음마 전 아기·침대. 걸음(시각)이나 태어난 수가 바뀌면 다시 센다 (읽기만 — 마을을 고치지 않는다)
func _pstate(v: Village) -> Dictionary:
	var id := v.get_instance_id()
	var st: Dictionary = pstate.get(id, {})
	if st.is_empty():
		st = {"t": -1.0, "born": -1, "nokid": -1.0, "moms_born": -1, "n": {}, "last": {}}
		pstate[id] = st
	var born := int(v.stats["born"])
	if float(st["t"]) == v.t and int(st["born"]) == born:
		return st
	st["t"] = v.t
	st["born"] = born
	var kids := 0
	var babies := 0
	var housed := 0
	for p: Resident in v.people:
		if p.age < Balance.AGE_ADULT:
			kids += 1
		if p.age < Balance.CARE_DAYS:
			babies += 1
		if p.home >= 0:
			housed += 1
	var beds := 0
	for b: Building in v.houses():
		beds += b.cap()
	st["pop"] = v.people.size()
	st["kids"] = kids
	st["babies"] = babies
	st["beds"] = beds
	st["free"] = beds - housed
	if kids > 0:
		st["nokid"] = -1.0
	elif float(st["nokid"]) < 0.0:
		st["nokid"] = v.t
	if (pace.has("third") or pace.has("gap")) and int(st["moms_born"]) != born:      # 엄마마다 낳은 수 · 막내를 낳은 때 (죽은 아이도 센다)
		st["moms_born"] = born
		var n := {}
		var last := {}
		for p: Resident in v.people + v.dead:
			if p.parents.size() != 2:
				continue
			for m: int in p.parents:
				n[m] = int(n.get(m, 0)) + 1
				last[m] = maxf(float(last.get(m, -1.0e18)), p.born_t)
		st["n"] = n
		st["last"] = last
	return st


## Village._births가 아내마다 부른다 → 그 아내의 출산 비율에 곱할 값
func _pace(v: Village, w: Resident) -> float:
	var st := _pstate(v)
	var pop := int(st["pop"])
	var k := 1.0
	if pace.has("kids"):
		var lim := _pv("kids", 0, 6.0)
		var per := _pv("kids", 1, 0.0)
		if per > 0.0:
			lim = maxf(lim, float(pop) / per)
		if float(st["kids"]) >= lim:
			k = 0.0
	if pace.has("cradle") and float(st["babies"]) >= _pv("cradle", 0, 1.0):
		k = 0.0
	if pace.has("room") and pop >= int(_pv("room", 2, 24.0)):
		var share := _pv("room", 0, 0.5)
		k *= clampf(float(st["free"]) / maxf(1.0, share * float(st["beds"])), _pv("room", 1, 0.0), 1.0)
	if pace.has("third") and pop >= int(_pv("third", 1, 24.0)):
		if int((st["n"] as Dictionary).get(w.id, 0)) >= int(_pv("third", 2, 2.0)):
			k /= maxf(1.0, _pv("third", 0, 4.0))
	if pace.has("gap") and pop >= int(_pv("gap", 1, 24.0)):
		var after := int(_pv("gap", 2, 2.0))
		var n := int((st["n"] as Dictionary).get(w.id, 0))
		if n >= after and v.t - float((st["last"] as Dictionary).get(w.id, -1.0e18)) < _pv("gap", 0, 20.0) * (n - after + 1) * D:
			k = 0.0
	if pace.has("reserve") and float(st["nokid"]) >= 0.0 and v.t - float(st["nokid"]) >= _pv("reserve", 0, 5.0) * D and int(st["free"]) > 0:
		k = _pv("reserve", 1, 20.0)
	return k


## 'floor' 규칙: 어린것이 L명이 안 되면 먹을 것 문과 상관없이 한 집이 아기를 맞는다 (걸음 묶음이 끝날 때마다 한 번, 마을마다 한 명까지)
func _floor() -> void:
	if not pace.has("floor"):
		return
	var need := int(_pv("floor", 0, 4.0))
	var from := int(_pv("floor", 1, 24.0))
	var rest := _pv("floor", 2, 1.0) * D
	for q: Village in jw.settlements:
		if q.people.size() < from:
			continue
		var id := q.get_instance_id()
		if q.t - float(floor_last.get(id, -1.0e18)) < rest:
			continue
		var kids := 0
		var n := {}                       # 엄마 id → 살아 있는 아이 수
		for p: Resident in q.people:
			if p.age < Balance.AGE_ADULT:
				kids += 1
			if p.parents.size() == 2:
				n[p.parents[0]] = int(n.get(p.parents[0], 0)) + 1
		if kids >= need:
			continue
		var occ := q.occupancy()
		var best: Resident = null
		var best_n := 1 << 30
		for w: Resident in q.people:
			if not (w.sex == "f" and w.partner >= 0 and w.fert > 0.0 and w.age >= Balance.BIRTH_WIFE_MIN and w.age < Balance.BIRTH_WIFE_MAX):
				continue
			var h := q.bld(w.home) if w.home >= 0 else null
			if h == null or int(occ.get(h.id, 0)) >= h.cap():
				continue
			var c := int(n.get(w.id, 0))
			if c < best_n:
				best_n = c
				best = w
		if best == null:
			continue
		q._give_birth(best, q.bld(best.home))
		floor_last[id] = q.t
		floor_births += 1


# ───────────────────────── 나이 덮어쓰기 ─────────────────────────
## 나이 a에서 게임이 d(일생 날 — 병 날 ÷ AGE_K)만큼 먹였을 때, 구간 배율로 다시 계산한 나이
func _adv(a: float, d: float) -> float:
	for b: Array in bands:
		if d <= 0.0:
			break
		if a >= float(b[0]):
			continue
		var sl := float(b[1])
		var room := (float(b[0]) - a) * sl
		if d <= room:
			return a + d / sl
		d -= room
		a = float(b[0])
	return a


func _slow(a: float) -> float:
	for b: Array in bands:
		if a < float(b[0]):
			return float(b[1])
	return 1.0


## 병 dt_j초가 흐른 뒤: 나이를 고쳐 쓰고 노환을 굴린다
func _fix(dt_j: float) -> void:
	if bands.is_empty():
		return
	var born_max := dt_j / (D * Balance.AGE_K) + 1e-6
	for q: Village in jw.settlements:
		for p: Resident in q.people.duplicate():
			var id := p.get_instance_id()
			var a := p.age
			if age_prev.has(id):
				a = _adv(float(age_prev[id]), p.age - float(age_prev[id]))
			elif p.age <= born_max:           # 이 묶음에서 태어남
				a = _adv(0.0, p.age)
			p.age = a
			age_prev[id] = a
			if fert_cut > 0.0 and p.sex == "f" and a >= fert_cut and p.fert != 0.0:
				p.fert = 0.0
			if float(p.fx.get("lifespan", 0.0)) != BIG:      # 새 사람 · 혈통이 다시 정해짐 → 게임 쪽 노환 굴림 끄기
				life_mult[id] = float(Bloodlines.effects(p.blood).get("lifespan", 1.0))
				var fx := p.fx.duplicate()
				fx["lifespan"] = BIG
				p.fx = fx
			var la := a / float(life_mult[id])
			if la >= Balance.DEATH_FROM:
				var pd := Balance.DEATH_BASE + Balance.DEATH_SLOPE * (la - Balance.DEATH_FROM)
				if drng.randf() < pd * dt_j / (D * Balance.AGE_K * _slow(a)) or la > Balance.DEATH_MAX_AGE:
					q.kill(p, "노환")
					tool_deaths += 1


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
	_hooks()
	_fix(0.0)
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
			var c := CatchUp.new(v, chunk / rate, lamp_s, jw, rate)
			c.run()
			c.finish()
			_hooks()
			_fix(chunk)
			_floor()
			left -= chunk
			_sample(v, false)
		_collect()
		_grant()
	_flush_day(v)
	_end(v, per_real_day, (Time.get_ticks_msec() - t0) / 1000.0)


func _advance(dt: float) -> void:
	jw.advance(dt)
	_hooks()
	_fix(dt)
	_floor()


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
	if watching and fd < 1.0 and v.t - last_help >= D:      # 거인의 손: 비축이 하루치 아래면 하늘 낟알 (병 하루에 한 번까지)
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
			var born_t := (p.death_t if p.dead else q.t) - p.age * Balance.AGE_K * D      # 게임 그대로일 때만 정확 (변형은 어림)
			if bands.is_empty() and born_t < -1.0:
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
	print("END v=%s seed=%d days=%.1f per_real_day=%.2f pop=%d era=%d era1_day=%.1f era2_day=%.1f short_days=%d lean=%d helps=%d notes=%.0f mig_bought=%d mig_people=%d tool_deaths=%d causes=%s spared=%d marriages=%d moves=%d invariants=%d secs=%.0f" % [
		variant, seed_v, v.t / D, per_real_day, _all().size(), v.era, float(era_at[0]), float(era_at[1]), short_days, lean, helps, income,
		mig_bought, mig_people, tool_deaths, JSON.stringify(why), int(v.stats.get("spared", 0)), int(v.stats["marriages"]), int(v.stats["moves"]), bad.size(), secs])
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
