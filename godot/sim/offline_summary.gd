## 비운 시간의 요약 계산 — docs/SAVE.md 3 (12시간보다 오래 비웠을 때 앞부분).
## 사람 하나하나 걷고 일하는 대신 **한 시간씩 통계로** 흘린다 (tools/sim_life.py처럼 1시간 단위, 하루가 쌓이면 '하루 단위' 요약):
##   - 인구: 혼인·출산·사망·나이 = Village.life_events 그대로 (같은 규칙·같은 난수 흐름), 집·일자리 배정도 그대로.
##   - 먹기: Village.step과 같은 식 (낟알 → 들판 낟알 → 건량 → 빵 → 밀), 굶주림·건강·숙련·행복.
##   - 생산: 일꾼이 있는 일터는 60초 조각으로 Village._update_building 그대로 (재료는 창고에서 바로, 산출물은 바로 창고로 — 나르기 생략).
##           나무꾼·채석장·버섯꾼·산림관(걸어서 일함)은 '한 번 다녀오는 시간'(걷기 + 일)으로 시간당 몇 번인지 센다 × 일하는 몫.
##   - 짓기: 촌장 자율 건설 = Village.chief_build 그대로 (15분마다), 자재는 창고에서 바로, 짓는 손 = 일 없는 어른 × 몫.
##   - 물·호수·소금: 물 계산의 거친 단계 (water.offline = 300초 간격 — 정밀 계산과 같은 물).
##   - 믿음·두려움·병·추위: Village._update_belief(거인 없음) + 기도 몫, Health.step · JarAir · Mold · Flora (60초 고정 걸음 그대로).
##   - 비운 동안의 규칙은 Village 쪽이 그대로 지킨다 (위기 사망 하루 1명·부부 2쌍, 시대 점수 30%, 제물 이틀, 곰팡이는 조짐에서 기다림).
## 평균이 정밀 계산과 맞는지 시험한다 (tests/save_tests.gd test_summary_matches_exact — 10일 인구·창고 ±15%).
class_name OfflineSummary
extends RefCounted

## 일하는 시간(6~20:30) 가운데 실제로 일터 일을 하는 몫 — 밥·기도·어울림·나르기를 뺀 것 (정밀 계산에서 잼)
const WORK_SHARE := 0.65
## 일 없는 어른이 짓기에 쓰는 몫 (일하는 시간 중) · 일터가 있는 어른이 거드는 몫
const BUILD_SHARE := 0.15
const BUILD_SHARE_JOB := 0.05
## 기도 — 깨어 있는 사람(2.5일↑)이 하루에 하는 기도 횟수 (정밀 계산 평균, 한 번에 +Balance.BELIEF_PRAYER)
const PRAYERS_PER_DAY := 20.0
const AWAKE_SHARE := 16.0 / 24.0      # 깨어 있는 시간 (6~22시)
## 터를 잡은 뒤 짓기 시작하기까지 (자재를 나르고 사람이 모이는 데 걸리는 시간 — 정밀 계산에서 터 → 완공 평균 1~8시간)
const SITE_LAG := 3.0 * 3600.0
static var _site_seen: Dictionary = {}  # 마을(instance id) → {건물 id: 터를 처음 본 병 시각} — 요약 계산 동안만
static var prof: Dictionary = {}      # 걸린 시간 (마이크로초) — 성능 확인용 (summary_calib 도구)
const WATER_EVERY := 300.0              # 물 계산 간격 (정밀 계산의 비운 동안 300초보다 거칠게 — 호수 면적은 시험으로 비교)
const SUB := 60.0                   # 생산 조각 (초)


## 요약 계산을 시작하기 전에: 하던 일을 모두 내려놓고(짐·예약은 되돌림) 집(없으면 모닥불 곁)에 둔다
static func begin(v: Village) -> void:
	for p in v.people:
		ResidentAI.cancel(v, p)
		p.action = ""
		_park(v, p)


static func _park(v: Village, p: Resident) -> void:
	var hm := v.bld(p.home)
	var pos := Vector2(hm.x, hm.y + 0.3) if (hm != null and hm.built) else v.fire + Vector2(cos(p.id * 1.3), sin(p.id * 1.3)) * 1.6
	p.x = pos.x
	p.y = pos.y
	p.px = p.x
	p.py = p.y
	p.anim = "idle"
	p.doing = "쉬는 중"


## dt초(한 시간 이하)를 요약으로 흘린다
static func hour(v: Village, dt: float) -> void:
	var t0 := v.t
	v.t += dt
	if v.owns_water:
		var u0 := Time.get_ticks_usec()
		var c0 := v.water.coarse
		v.water.coarse = WATER_EVERY
		v.water.advance(dt)
		v.water.coarse = c0
		_p("물", u0)
	if not v._arrival_manna and v.t >= Balance.MANNA_DELAY:
		v._arrival_manna = true
		v.manna_fall("arrival")
	var dawn_idx := floori((v.start_clock + v.t - Balance.DAWN_HOUR * Balance.HOUR) / Balance.DAY)
	if v._last_dawn < 0:
		v._last_dawn = floori((v.start_clock - Balance.DAWN_HOUR * Balance.HOUR) / Balance.DAY)
	# 일한 시간 (숙련 — 새벽에 하루치로 셈): 이 조각 중 일하는 시간 몫
	var work_frac := _work_frac(v, t0, dt)
	for p in v.people:
		if p.is_adult():
			p.work_secs_today += dt * work_frac * WORK_SHARE
	if dawn_idx > v._last_dawn:
		v._last_dawn = dawn_idx
		v._on_dawn()
	# 낟알 상함
	for m: Dictionary in v.manna:
		if v.t - m["born"] >= Balance.MANNA_SPOIL:
			m["amt"] = 0.0
	for m: Dictionary in v.manna_batches:
		if v.t - m["born"] >= Balance.MANNA_SPOIL:
			m["amt"] = 0.0
	v.manna = v.manna.filter(func(m: Dictionary) -> bool: return m["amt"] > 0.001)
	v.manna_batches = v.manna_batches.filter(func(m: Dictionary) -> bool: return m["amt"] > 0.001)
	# 생산 (먹기 전에 — 정밀 계산에서도 밭은 쉬지 않고 돈다)
	var u1 := Time.get_ticks_usec()
	_produce(v, dt, work_frac)
	_p("생산", u1)
	# 먹기 (Village.step과 같은 식)
	var need := v._food_people() * dt / Balance.FOOD_IV
	var unmet := v.consume(need)
	v.deficit = unmet / need if need > 0.0 else 0.0
	if v.deficit > 0.0:
		v.last_short_t = v.t
	for p in v.people:
		if v.deficit > 0.0:
			p.hunger = minf(4.0, p.hunger + v.deficit * dt / Balance.FOOD_IV)
		else:
			p.hunger = maxf(0.0, p.hunger - dt / Balance.FOOD_IV)
		if p.hunger >= Balance.STARVING_AT:
			p.health -= dt / Balance.STARVE_HEALTH_TIME
			p.harm["굶주림"] = float(p.harm.get("굶주림", 0.0)) + dt / Balance.STARVE_HEALTH_TIME
		elif Health.can_heal(p):
			p.health = minf(1.0, p.health + dt * p.f("heal") / Balance.HEAL_TIME)
		p.age += dt / Balance.DAY
		p.say_t = 0.0
		p.sleeping = v.is_night()
	var u2 := Time.get_ticks_usec()
	Health.step(v, dt)
	_p("건강", u2)
	u2 = Time.get_ticks_usec()
	v.air.step(v, dt)
	Mold.step(v, dt)
	Flora.step(v, dt)
	_p("공기·곰팡이·버섯", u2)
	u2 = Time.get_ticks_usec()
	for tr: Dictionary in v.trees:
		if tr["s"] != "tree":
			tr["g"] -= dt
			if tr["g"] <= 0.0:
				tr["s"] = "tree"
	# 짓기 (촌장은 15분마다 — 정밀 계산과 같은 횟수)
	var n_chief := maxi(1, roundi(dt / Balance.CHIEF_EVERY))
	var q := dt / n_chief
	for i in n_chief:                 # 15분마다: 생로병사(넓은 집으로 옮기기 포함) → 촌장이 터를 잡고 → 짓고 → 집에 사람이 든다
		for k in maxi(1, roundi(q / Balance.LIFE_EVERY)):     # 정밀 계산과 같은 1분 간격 (혼인·출산·사망 판정)
			v.life_events(q / maxi(1, roundi(q / Balance.LIFE_EVERY)))
		if not v.chief_off:
			v.chief_build()
		_build(v, q, _work_frac(v, t0 + i * q, q))
		v.assign_homes()
	# 집·일자리 · 제물·소원 · 호수·소금
	v.trees = v.trees.filter(func(tr: Dictionary) -> bool: return v.water.depth(v.water.idx(tr["x"], tr["y"])) < 0.03)
	v.assign_jobs()
	v.assign_homes()
	for p in v.people:
		if p.home >= 0:
			_park(v, p)
	v._economy_tick()
	v.lake_watch()
	v.salt_discovery()
	var f := pow(0.997, dt / 60.0)
	for i in v.paths.size():
		if v.paths[i] > 0.0:
			v.paths[i] *= f
	# 믿음: 거인 없음(줄어듦) + 기도 몫
	var awake := 1.0 - _night_frac(v, t0, dt)
	for p in v.people:
		if p.age >= 2.5:              # 기도 점수는 믿음에 비례 (ResidentAI.decide) → 하루 기도 수 ∝ 믿음, 깨어 있는 시간에 고루
			p.belief = minf(1.0, p.belief + PRAYERS_PER_DAY * p.belief * Balance.BELIEF_PRAYER * dt * awake / (Balance.DAY * AWAKE_SHARE))
	v._update_era(dt)
	v._update_belief(dt)
	v.recalc_fear()
	_p("나머지", u2)
	v.crises.clear()                  # 비운 동안의 위기 알림은 화면에 띄우지 않는다 (편지가 대신)


static func _p(k: String, u0: int) -> void:
	prof[k] = int(prof.get(k, 0)) + Time.get_ticks_usec() - u0


## 이 조각 중 일하는 시간(WORK_FROM~WORK_TO) 몫 0~1 — 10분 간격으로 셈
static func _work_frac(v: Village, t0: float, dt: float) -> float:
	var n := maxi(1, ceili(dt / 600.0))
	var w := 0
	for i in n:
		var h := fmod(v.start_clock + t0 + (i + 0.5) * dt / n, Balance.DAY) / Balance.HOUR
		if h >= Balance.WORK_FROM and h < Balance.WORK_TO:
			w += 1
	return float(w) / n


static func _night_frac(v: Village, t0: float, dt: float) -> float:
	var n := maxi(1, ceili(dt / 600.0))
	var w := 0
	for i in n:
		var h := fmod(v.start_clock + t0 + (i + 0.5) * dt / n, Balance.DAY) / Balance.HOUR
		if h >= Balance.NIGHT_FROM or h < Balance.NIGHT_TO:
			w += 1
	return float(w) / n


# ───────────────────────── 생산 ─────────────────────────
static func _produce(v: Village, dt: float, work_frac: float) -> void:
	var s := v.store()
	for b in v.buildings:
		if not b.built:
			continue
		var d := b.def()
		if not d.get("job", false):
			continue
		var w := v.person(b.worker) if b.worker >= 0 else null
		if d.get("gather", false):
			if w != null and w.sick_left <= 0.0 and work_frac > 0.0:
				_gather(v, b, w, s, dt * work_frac * WORK_SHARE)
			continue
		# 건물에서 돌아가는 일터: 60초 조각으로 Village._update_building 그대로 (재료는 창고에서 바로 채움)
		var ins: Dictionary = d.get("in", {})
		var left := dt
		while left > 1e-6:
			var sd := minf(SUB, left)
			left -= sd
			for k: String in ins:
				var want := float(ins[k]) * 2.0 - float(b.in_buf.get(k, 0.0))
				var have := float(v.stock.get(k, 0.0))
				var take := minf(floorf(have), ceilf(maxf(0.0, want)))
				if take > 0.0:
					v.stock[k] = have - take
					b.in_buf[k] = float(b.in_buf.get(k, 0.0)) + take
			v._update_building(b, sd)
		for k: String in b.out.keys():           # 산출물은 바로 창고로 (나르는 사람 생략)
			var n := float(b.out[k])
			if n > 0.0:
				v.stock[k] = float(v.stock.get(k, 0.0)) + n
				b.out[k] = 0.0


## 걸어서 일하는 일터: 한 번 다녀오는 시간 = 걷기(일터→대상→창고→다시) + 일. busy초 동안 몇 번 다녀오나
static func _gather(v: Village, b: Building, w: Resident, s: Building, busy: float) -> void:
	var d := b.def()
	var sp := Balance.WALK * w.f("walk")
	var spd := w.job_speed(b.type)
	match b.type:
		"나무꾼":
			while busy > 0.0 and float(v.stock.get("통나무", 0.0)) < v.enough("통나무"):
				var tr := ResidentAI._nearest(v.trees, Vector2(b.x, b.y), func(q: Dictionary) -> bool: return q["s"] == "tree" and q["res"] == 0)
				if tr.is_empty() or Vector2(tr["x"] - b.x, tr["y"] - b.y).length() > Balance.GATHER_RANGE:
					break
				var trip := 2.0 * Vector2(tr["x"] - s.x, tr["y"] - s.y).length() / sp + float(d["chop"]) / spd + 10.0
				busy -= trip
				if busy < 0.0 and v.rng.randf() > 1.0 + busy / trip:
					break
				tr["s"] = "stump"
				tr["g"] = Balance.TREE_REGROW / (0.6 + v.wetness(tr["x"], tr["y"]))
				v.stock["통나무"] = float(v.stock.get("통나무", 0.0)) + 1.0
		"채석장":
			while busy > 0.0 and float(v.stock.get("돌", 0.0)) < v.enough("돌"):
				var rk := ResidentAI._nearest(v.rocks, Vector2(b.x, b.y), func(q: Dictionary) -> bool: return q["amt"] > 0 and q["res"] == 0)
				if rk.is_empty() or Vector2(rk["x"] - b.x, rk["y"] - b.y).length() > Balance.GATHER_RANGE:
					break
				var trip := 2.0 * Vector2(rk["x"] - s.x, rk["y"] - s.y).length() / sp + float(d["dig"]) / spd + 10.0
				busy -= trip
				if busy < 0.0 and v.rng.randf() > 1.0 + busy / trip:
					break
				rk["amt"] = int(rk["amt"]) - 1
				v.stock["돌"] = float(v.stock.get("돌", 0.0)) + 1.0
		"산림관":
			while busy > 0.0 and v._standing_trees() < Balance.FORESTER_STOP:
				var trip := 2.0 * 4.5 / sp + float(d["plant"]) / spd + 5.0
				busy -= trip
				var p := ResidentAI.near(v, b.x, b.y, 2.0 + v.rng.randf() * 5.0)
				if v.water.inside(p.x, p.y, 2.0) and not v.water_at(p.x, p.y):
					v.trees.append({"x": p.x, "y": p.y, "s": "sapling", "g": 3.0 * Balance.HOUR, "res": 0})
		"버섯꾼":
			if v.flora == null:
				return
			while busy > 0.0 and float(v.stock.get("버섯", 0.0)) < v.enough("버섯"):
				var best: Dictionary = {}
				var bd := INF
				for q: Dictionary in v.flora.shrooms:
					if q["gone"] or not v.flora.mature(q) or float(q["food"]) <= 0.0 or q["kind"] == "빛버섯" or Balance.SHROOM[q["kind"]].get("poison", false):
						continue
					var dd := Vector2(q["x"] - b.x, q["y"] - b.y).length()
					if dd < bd:
						bd = dd
						best = q
				if best.is_empty():
					break
				var trip := 2.0 * Vector2(best["x"] - s.x, best["y"] - s.y).length() / sp + float(d["pick"]) / spd + 10.0
				busy -= trip
				var amt := minf(Balance.PICK_CHUNK, float(best["food"]))
				best["food"] = float(best["food"]) - amt
				v.stock["버섯"] = float(v.stock.get("버섯", 0.0)) + amt
				v.flora.stats["picked"] += amt
				if float(best["food"]) <= 0.0:
					v.flora._spent(best)


# ───────────────────────── 짓기 ─────────────────────────
static func _build(v: Village, dt: float, work_frac: float) -> void:
	var sites: Array[Building] = []
	for b in v.buildings:
		if b.is_site():
			sites.append(b)
	if sites.is_empty():
		return
	sites.sort_custom(func(a: Building, c: Building) -> bool: return (a.wished and not c.wished) or (a.wished == c.wished and a.id < c.id))
	# 자재: 창고에서 바로 (나르는 중인 몫이 남아 있으면 도착한 것으로)
	for b in sites:
		for k: String in ["판자", "돌"]:
			b.delivered[k] = int(b.delivered[k]) + int(b.incoming[k])
			b.incoming[k] = 0
			var lack := b.need(k) - int(b.delivered[k])
			var have := int(floorf(float(v.stock[k])))
			var take := mini(lack, have)
			if take > 0:
				v.stock[k] = float(v.stock[k]) - take
				b.delivered[k] = int(b.delivered[k]) + take
	if work_frac <= 0.0:
		return
	var labor := 0.0
	for p in v.people:
		if not p.is_adult() or p.sick_left > 0.0 or p.injured_left > 0.0:
			continue
		labor += dt * work_frac * (BUILD_SHARE_JOB if p.job >= 0 else BUILD_SHARE)
	var seen: Dictionary = _site_seen.get(v.get_instance_id(), {})
	_site_seen[v.get_instance_id()] = seen
	for b in sites:
		if not seen.has(b.id):
			seen[b.id] = v.t
	for b in sites:
		if labor <= 0.0:
			break
		if not b.materials_ready() or v.t - float(seen[b.id]) < SITE_LAG:
			continue
		var total := float(Balance.B[b.site_type()]["time"])
		var m := v.build_mult(b)
		var use := minf(labor, maxf(0.0, (total - b.prog) / m))
		b.prog += use * m
		labor -= use
		if b.prog >= total - 1e-6:
			v.on_built(b)
