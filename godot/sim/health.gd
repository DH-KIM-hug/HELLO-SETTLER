## 건강·기후·두려움 — docs/HEALTH.md (병 날짜·온도·노출·땔감·질병·부상·사람마다 두려움).
## 화면과 분리된 순수 로직. 상태는 Village(달력·난수·타이머)와 Resident(sick_left·injured_left·fear·cold·heat)에 있다.
## 난수는 Village.health_rng 하나만 쓴다 (유전·기존 흐름을 흔들지 않게 — HEALTH.md 7).
## 계산은 병 시계 Balance.HEALTH_TICK(60초) 간격의 고정 걸음 → 걸음 크기(×1의 1초, 몰아서 계산의 10·30초)와 상관없이 같은 때에 일어난다.
## 발병·부상 굴림은 병 시계 정시(1시간)마다.
class_name Health
extends RefCounted

const DOY_START := [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
const CAUSES := ["굶주림", "병", "추위", "더위"]


# ───────────────────────── 병 날짜·온도 (1.1 · 1.2) ─────────────────────────
## 1월 1일 = 0 (윤년 무시 — 계절 계산용)
static func doy(month: int, day: int) -> int:
	return int(DOY_START[clampi(month, 1, 12) - 1]) + day - 1


static func season_of(month: int) -> String:
	return Balance.SEASONS[clampi(month, 1, 12) - 1]


## 병 날짜 = 세상을 만든 날 + 병 시계로 흐른 날 수 (자정마다 하루)
static func jar_date(v: Village) -> Dictionary:
	var c: Dictionary = v.created_date
	var base := Time.get_unix_time_from_datetime_dict({"year": int(c["year"]), "month": int(c["month"]), "day": int(c["day"]), "hour": 12, "minute": 0, "second": 0})
	var days := int((v.start_clock + v.t) / Balance.DAY)
	var d := Time.get_datetime_dict_from_unix_time(base + days * 86400)
	return {"year": int(d["year"]), "month": int(d["month"]), "day": int(d["day"]), "season": season_of(int(d["month"]))}


static func climate_row(v: Village) -> Array:
	return Balance.CLIMATES.get(v.climate(), Balance.CLIMATES[Balance.CLIMATE_DEFAULT])


## 낮밤 곡선 −1 (4시) ~ +1 (14시): 4→14시 오르는 반 코사인, 14→4시 내리는 반 코사인
static func day_curve(h: float) -> float:
	var a := Balance.COLDEST_HOUR
	var b := Balance.WARMEST_HOUR
	if h >= a and h < b:
		return -cos(PI * (h - a) / (b - a))
	var s := fmod(h - b + 24.0, 24.0) / (24.0 - (b - a))
	return cos(PI * s)


## 자리를 빼 온도 (병 시각 tt)
static func base_temp(v: Village, tt: float) -> float:
	var row := climate_row(v)
	var c: Dictionary = v.created_date
	var dd := float(doy(int(c["month"]), int(c["day"]))) + (v.start_clock + tt) / Balance.DAY
	var season := -float(row[1]) * cos(TAU * (dd - Balance.COLDEST_DOY) / 365.0)
	var h := fmod(v.start_clock + tt, Balance.DAY) / Balance.HOUR
	return float(row[0]) + season + float(row[2]) * day_curve(h)


static func temperature_at(v: Village, x: float, y: float) -> float:
	return base_temp(v, v.t) + Balance.SPOT_WARM * v.water.warm_at(x, y)


static func cold_of(temp: float) -> float:
	return clampf((Balance.COLD_FROM - temp) / Balance.COLD_DIV, 0.0, Balance.EXPOSE_MAX)


static func heat_of(temp: float) -> float:
	return clampf((temp - Balance.HEAT_FROM) / Balance.HEAT_DIV, 0.0, Balance.EXPOSE_MAX)


# ───────────────────────── 노출 (1.3 · 1.4) ─────────────────────────
## 막아 주는 것 (겹치면 가장 좋은 것 하나) → [추위 배율, 더위 배율]
static func protection(v: Village, r: Resident, heat_raw: float) -> Array:
	var mc := 1.0
	var mh := 1.0
	var hm := v.bld(r.home)
	if hm != null and hm.built and Vector2(r.x - hm.x, r.y - hm.y).length() <= hm.size() + Balance.HOUSE_IN_R:
		var pr: Array = Balance.PROTECT_HOUSE_FUEL if hm.fuel_on else Balance.PROTECT_HOUSE_COLD
		mc = minf(mc, pr[0])
		mh = minf(mh, pr[1])
	if Vector2(r.x - v.fire.x, r.y - v.fire.y).length() <= Balance.FIRE_R:
		mc = minf(mc, Balance.PROTECT_FIRE[0])
		mh = minf(mh, Balance.PROTECT_FIRE[1])
	if heat_raw > 0.0 and mh > Balance.PROTECT_SHADE[1]:
		var r2 := Balance.SHADE_R * Balance.SHADE_R
		for tr: Dictionary in v.trees:
			if tr["s"] == "tree" and Vector2(float(tr["x"]) - r.x, float(tr["y"]) - r.y).length_squared() <= r2:
				mh = minf(mh, Balance.PROTECT_SHADE[1])
				break
	return [mc, mh]


static func age_mult(r: Resident) -> float:
	return Balance.FRAIL_AGE_MULT if (r.is_baby() or r.is_elder()) else 1.0


## 혈통·나이를 곱한 노출 (건강을 깎는 세기, 하루 −0.25 × 이것)
static func exposure_load(r: Resident) -> float:
	return (r.cold * r.f("cold") + r.heat * r.f("heat")) * age_mult(r)


## 저절로 낫는가 (Village.step이 부른다): 앓는 중이거나 춥고 더우면 낫지 않는다
static func can_heal(r: Resident) -> bool:
	return r.sick_left <= 0.0 and exposure_load(r) < Balance.EXPOSE_BLOCKS_HEAL


## 밖의 추위·더위 정도 (막기 전 — 행동 점수용)
static func outdoor(v: Village, x: float, y: float) -> Vector2:
	var tp := temperature_at(v, x, y)
	return Vector2(cold_of(tp), heat_of(tp))


# ───────────────────────── 고정 걸음 ─────────────────────────
static func step(v: Village, dt: float) -> void:
	v._health_acc += dt
	while v._health_acc >= Balance.HEALTH_TICK - 1e-6:
		v._health_acc -= Balance.HEALTH_TICK
		tick(v, Balance.HEALTH_TICK, v.t - v._health_acc)


static func tick(v: Village, dt: float, tt: float) -> void:
	var tb := base_temp(v, tt)
	var hr := floori(tt / Balance.HOUR)
	var new_hour := hr > v._health_hour
	if new_hour:
		v._health_hour = hr
		v.cold_season = _cold_ahead(v, tt)
	_fuel(v, dt, tb)
	var n_sick := 0
	var clinic := _clinics(v)
	var half := pow(0.5, dt / Balance.DAY)
	var fest := tt - v.festival_t < Balance.FEAR_FESTIVAL
	for r in v.people:
		# 노출
		var tp := tb + Balance.SPOT_WARM * v.water.warm_at(r.x, r.y)
		var c0 := cold_of(tp)
		var h0 := heat_of(tp)
		if c0 > 0.0 or h0 > 0.0:
			var pr := protection(v, r, h0)
			r.cold = c0 * float(pr[0])
			r.heat = h0 * float(pr[1])
		else:
			r.cold = 0.0
			r.heat = 0.0
		for k: String in r.harm:
			r.harm[k] = float(r.harm[k]) * half
		var am := age_mult(r)
		var lc := r.cold * r.f("cold") * am * Balance.EXPOSE_HEALTH_DAY * dt / Balance.DAY
		var lh := r.heat * r.f("heat") * am * Balance.EXPOSE_HEALTH_DAY * dt / Balance.DAY
		if lc > 0.0:
			_hurt(r, "추위", lc)
		if lh > 0.0:
			_hurt(r, "더위", lh)
		# 앓음
		if r.sick_left > 0.0:
			n_sick += 1
			var in_clinic := _near_any(r, clinic, Balance.CLINIC_R)
			_hurt(r, "병", (Balance.ILL_HEALTH_CLINIC if in_clinic else Balance.ILL_HEALTH_DAY) * dt / Balance.DAY)
			if not r.herb_used and float(v.stock.get(Balance.HERB, 0.0)) >= 1.0:
				v.stock[Balance.HERB] = float(v.stock[Balance.HERB]) - 1.0
				r.herb_used = true
				r.sick_left *= 0.5
			r.sick_left = maxf(0.0, r.sick_left - dt)
			if r.sick_left <= 0.0:
				v.stats["recovered"] = int(v.stats.get("recovered", 0)) + 1
		if r.injured_left > 0.0:
			r.injured_left = maxf(0.0, r.injured_left - dt)
		# 힘쓰는 일 (부상 굴림용)
		if not r.sleeping and _heavy(v, r):
			r.heavy_secs += dt
		# 두려움 내려감 (반감기 12시간, 기도·축제에 함께하면 두 배 빨리)
		if r.fear > 0.0:
			var sp := 2.0 if (r.action == "pray" or fest) else 1.0
			r.fear *= pow(0.5, dt * sp / Balance.FEAR_HALF)
			if r.fear < 1e-4:
				r.fear = 0.0
	v.stats["sick_secs"] = float(v.stats.get("sick_secs", 0.0)) + n_sick * dt
	v.stats["person_secs"] = float(v.stats.get("person_secs", 0.0)) + v.people.size() * dt
	# 앓는 사람이 20% 넘음: 모두 하루 +0.05, 하루 한 번 말
	v.sick_share = float(n_sick) / v.people.size() if not v.people.is_empty() else 0.0
	if v.sick_share > Balance.SICK_WARN:
		for r in v.people:
			v.raise_fear(r, Balance.FEAR_SICK_DAY * dt / Balance.DAY)
		var dn := v.cal_day(tt)
		if v._sick_warn_day != dn:
			v._sick_warn_day = dn
			v.log_line("마을에 기침 소리가 늘었다. 앓아누운 집이 하나둘이 아니었다.")
			var awake := v.people.filter(func(q: Resident) -> bool: return not q.sleeping and q.sick_left <= 0.0 and q.age >= 2.5)
			if not awake.is_empty():
				v.speak(awake[0], Balance.LINE_SICK_WARN, 7)
			v.warnings.append({"t": tt, "kind": "sick", "text": Balance.LINE_SICK_WARN})
	if new_hour:
		_hourly(v, clinic)
	v.recalc_fear()


static func _hurt(r: Resident, cause: String, amt: float) -> void:
	r.health -= amt
	r.harm[cause] = float(r.harm.get(cause, 0.0)) + amt


static func _heavy(v: Village, r: Resident) -> bool:
	if r.action == "build" or r.action == "haul":
		return true
	if r.action == "work":
		var jb := v.bld(r.job)
		return jb != null and (jb.type == "나무꾼" or jb.type == "채석장")
	return false


static func _clinics(v: Village) -> Array:
	var out: Array = []
	for b in v.buildings:
		if b.built and b.type == Balance.CLINIC_TYPE:
			out.append(Vector2(b.x, b.y))
	return out


static func _near_any(r: Resident, pts: Array, rad: float) -> bool:
	for p: Vector2 in pts:
		if Vector2(r.x, r.y).distance_to(p) <= rad:
			return true
	return false


## 앞으로 반나절 안에 마을 자리가 추위 정도 > 0이 되는가 (땔감 운반·나무꾼 '넉넉함')
static func _cold_ahead(v: Village, tt: float) -> bool:
	var spot := Balance.SPOT_WARM * v.water.warm_at(v.center.x, v.center.y)
	var hrs := int(Balance.FUEL_SEASON_LOOKAHEAD / Balance.HOUR)
	for i in hrs + 1:
		if cold_of(base_temp(v, tt + i * Balance.HOUR) + spot) > 0.0:
			return true
	return false


# ───────────────────────── 땔감 (1.3) ─────────────────────────
## 사람이 사는 집마다: 그 자리의 추위 정도 > 0이면 10분마다 통나무 1개 (석조 주택 ×0.5). 땔감 = 집의 in_buf["통나무"] (운반 일이 창고에서 나른다)
static func _fuel(v: Village, dt: float, tb: float) -> void:
	var occ := v.occupancy()
	for b in v.buildings:
		if not b.built or not b.is_house():
			continue
		if int(occ.get(b.id, 0)) <= 0 or cold_of(tb + Balance.SPOT_WARM * v.water.warm_at(b.x, b.y)) <= 0.0:
			b.fuel_on = false
			continue
		if b.fuel_acc <= 1e-9:
			if float(b.in_buf.get("통나무", 0.0)) >= 1.0:
				b.in_buf["통나무"] = float(b.in_buf["통나무"]) - 1.0
				b.fuel_acc += 1.0
				v.stats["firewood"] = float(v.stats.get("firewood", 0.0)) + 1.0
			else:
				b.fuel_on = false
				v.stats["cold_house_secs"] = float(v.stats.get("cold_house_secs", 0.0)) + dt
				continue
		b.fuel_on = true
		b.fuel_acc = maxf(0.0, b.fuel_acc - dt * (Balance.FUEL_STONE if b.type == "석조주택" else 1.0) / Balance.FUEL_EVERY)


## 이 집에 땔감을 날라야 하나 — 몇 개까지
static func fuel_lack(v: Village, b: Building) -> float:
	if not v.cold_season or not b.built or not b.is_house():
		return 0.0
	return Balance.FUEL_TARGET - float(b.in_buf.get("통나무", 0.0)) - float(b.in_inc.get("통나무", 0.0))


# ───────────────────────── 질병·부상 굴림 (2 · 3) — 정시마다 ─────────────────────────
static func _hourly(v: Village, clinic: Array) -> void:
	var sick_home := {}
	var sick: Array[Resident] = []
	for r in v.people:
		if r.sick_left > 0.0:
			sick.append(r)
			if r.home >= 0:
				sick_home[r.home] = int(sick_home.get(r.home, 0)) + 1
	var wells: Array = []
	for b in v.buildings:
		if b.built and b.type == "우물":
			wells.append(Vector2(b.x, b.y))
	var occ := v.occupancy()
	var tropical := v.climate() == "열대"
	for r in v.people:
		var in_clinic := _near_any(r, clinic, Balance.CLINIC_R)
		# 부상: 이번 시간에 힘쓴 만큼
		if r.heavy_secs > 0.0:
			var pinj := Balance.INJURY_HOUR * r.heavy_secs / Balance.HOUR * r.f("illness")
			r.heavy_secs = 0.0
			if r.injured_left <= 0.0 and v.health_rng.randf() < pinj:
				r.injured_left = Balance.INJURY_DAYS * Balance.DAY * (Balance.CLINIC_TIME if in_clinic else 1.0)
				var hit := minf(Balance.INJURY_HEALTH, maxf(0.0, r.health - 0.01))     # 부상만으로는 죽지 않는다
				_hurt(r, "부상", hit)
				v.stats["injured"] = int(v.stats.get("injured", 0)) + 1
				v.speak(r, "아야, 다리를 삐었어…", 5)
		if r.sick_left > 0.0:
			continue
		var p := Balance.ILL_DAY
		if r.hunger >= Balance.STARVING_AT:
			p *= Balance.ILL_HUNGRY
		if r.health < Balance.ILL_WEAK_BELOW:
			p *= Balance.ILL_WEAK
		if r.cold + r.heat > 0.0:
			p *= 1.0 + r.cold + r.heat
		var hm := v.bld(r.home)
		if hm == null or not _near_pt(hm, wells, Balance.WELL_R):
			p *= Balance.ILL_NO_WELL
		if hm != null and int(occ.get(hm.id, 0)) >= hm.cap():
			p *= Balance.ILL_CROWDED
		p *= age_mult(r)
		if tropical:
			p *= Balance.ILL_TROPICAL
		# 전염: 같은 집 식구 (앓는 식구마다) · 반경 2칸에 앓는 사람
		var cg := 0.0
		if r.home >= 0:
			cg += Balance.CONTAGION_HOME * int(sick_home.get(r.home, 0))
		for s in sick:
			if s.home != r.home or r.home < 0:
				if Vector2(s.x - r.x, s.y - r.y).length() <= Balance.CONTAGION_R:
					cg += Balance.CONTAGION_NEAR
		if in_clinic:
			cg *= Balance.CONTAGION_CLINIC
		p = (p + cg) * r.f("illness")
		if v.health_rng.randf() < p / 24.0:
			fall_ill(v, r, in_clinic)


static func _near_pt(b: Building, pts: Array, rad: float) -> bool:
	for p: Vector2 in pts:
		if Vector2(b.x, b.y).distance_to(p) <= rad:
			return true
	return false


static func fall_ill(v: Village, r: Resident, in_clinic := false) -> void:
	r.sick_left = Balance.ILL_DAYS * Balance.DAY / maxf(0.1, r.f("heal")) * (Balance.CLINIC_TIME if in_clinic else 1.0)
	r.sick_since = v.t
	r.herb_used = false
	v.stats["sick"] = int(v.stats.get("sick", 0)) + 1
	if not r.is_baby():
		ResidentAI.cancel(r)          # 하던 일을 놓고 눕는다 (짐·예약은 되돌림)
		if r.age >= 2.5:
			v.speak(r, "몸이 으슬으슬해…", 5)


## 건강이 0이 된 사람의 사망 원인 — 최근 건강을 가장 많이 깎은 것 (부상만으로는 죽지 않는다 → 나머지 중에서)
static func death_cause(r: Resident) -> String:
	var best := ""
	var bv := 0.0
	for k: String in CAUSES:
		var x := float(r.harm.get(k, 0.0))
		if x > bv:
			bv = x
			best = k
	if best == "":
		best = "병" if r.sick_left > 0.0 else "굶주림"
	return best
