## 건강·기후·두려움 — docs/HEALTH.md (병 날짜·온도·노출·땔감·질병·부상·사람마다 두려움).
## 화면과 분리된 순수 로직. 상태는 Village(달력·난수·타이머)와 Resident(sick_left·injured_left·fear·cold·heat)에 있다.
## 질병 v1.3 (HEALTH.md 2): 병마다 표는 Balance.DISEASES. 앓는 병·중증·면역은 Resident(disease·severe·immune·overcome), 유행(독함)은 Village.outbreaks.
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


## 철에 따른 밭 자람 (BALANCE v5-0): 그날의 철 기온(낮밤 뺌)으로 — 바탕 기온에서 1.0, 추울수록 느림 (SEASON_GROW_*).
## 첫 빵 전(창세·첫날 튜토리얼)에는 1.0 — 첫 여정의 숫자가 계절에 흔들리지 않게. 병 하루에 한 번 셈.
static func season_grow(v: Village) -> float:
	if not Production.bread_made(v):
		return 1.0
	var day := int(floor((v.start_clock + v.t) / Balance.DAY))
	if day == v._sg_day:
		return v._sg
	var row := climate_row(v)
	var c: Dictionary = v.created_date
	var dd := float(doy(int(c["month"]), int(c["day"]))) + float(day) + 0.5
	var ts := float(row[0]) + CoreWarmth.temp(v) - float(row[1]) * cos(TAU * (dd - Balance.COLDEST_DOY) / 365.0)   # [핵] 병의 따뜻함 (A28b)
	v._sg_day = day
	v._sg = clampf(1.0 + (ts - Balance.SEASON_GROW_T) * Balance.SEASON_GROW_K, Balance.SEASON_GROW_MIN, Balance.SEASON_GROW_MAX + CoreWarmth.grow_cap(v))
	return v._sg


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
	return float(row[0]) + CoreWarmth.temp(v) + season + float(row[2]) * day_curve(h)     # [핵] 서늘한 별 −·뜨거운 별 + (A28b)


static func temperature_at(v: Village, x: float, y: float) -> float:
	var tb := base_temp(v, v.t)
	if v.air != null:
		tb += v.air.temp_shift(tb)        # [곰팡이·뚜껑] 뚜껑으로 섞여 든 거인의 방 기온 (WORLD_EVENTS 3)
	return tb + Balance.SPOT_WARM * v.water.warm_at(x, y)


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
	var indoor := hm != null and hm.built and Vector2(r.x - hm.x, r.y - hm.y).length() <= hm.size() + Balance.HOUSE_IN_R
	if indoor:
		var pr: Array = Balance.PROTECT_HOUSE_FUEL if hm.fuel_on else Balance.PROTECT_HOUSE_COLD
		mc = minf(mc, pr[0])
		mh = minf(mh, pr[1])
	if Vector2(r.x - v.fire.x, r.y - v.fire.y).length() <= Balance.FIRE_R:
		mc = minf(mc, Balance.PROTECT_FIRE[0])
		mh = minf(mh, Balance.PROTECT_FIRE[1])
	# 그늘 지도 하나 (flower-forest R2 · F2): 꽃숲 1.5칸 · 큰 갓 · 해바라기 꽃판 그림자 · 큰 나무 잎 아래 — 겹쳐도 ×0.6 한 번
	if heat_raw > 0.0 and mh > Balance.SHADE_HEAT and GiantPlants.shade_at(v, r.x, r.y):
		mh = Balance.SHADE_HEAT
	if v.flora != null and v.flora.cotton_on(v, r):
		mc *= Balance.COTTON_COLD                     # [하늘의 것] 솜을 넣은 옷 ×0.8 (입는 것이라 다른 것과 겹침 — WORLD_EVENTS 2.7)
	if indoor and GiantPlants.quilt_on(v, r):
		mc *= Balance.QUILT_COLD                      # 솜 이불 — 집 안 추위 ×0.75 (덮는 것이라 곱함, health.md 메인 판단 ①)
	if indoor:
		mc *= CoreWarmth.bed_cold(v)                  # [핵] 서늘한 별의 이끼 이불 (A28b — 보통 별은 1)
	mc *= CoreWarmth.spring_cold(v)                   # [핵] 뜨거운 별의 온천을 알면 (발견 L5 — 아니면 1)
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
	var tk := Balance.HEALTH_TICK * v.tick_mult       # 따라잡기 빠른 길이면 성기게 (같은 규칙 — 모든 값이 간격에 비례)
	while v._health_acc >= tk - 1e-6:
		v._health_acc -= tk
		tick(v, tk, v.t - v._health_acc)


static func tick(v: Village, dt: float, tt: float) -> void:
	var tb := base_temp(v, tt)
	if v.air != null:
		tb += v.air.temp_shift(tb)        # [곰팡이·뚜껑] 뚜껑이 열리면 방 기온이 섞인다 (겨울엔 잠깐 추위)
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
	var cases := {}
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
		# 밖에서 지니고 온 병: 잠복이 끝나면 앓기 시작 (WORLD_EVENTS 5 — 그 전엔 아프지도 옮기지도 않음)
		if r.latent != "" and tt >= r.latent_until:
			var lk := r.latent
			r.latent = ""
			r.latent_until = -1.0
			if r.sick_left <= 0.0 and not r.is_immune(lk, tt):
				fall_ill(v, r, _near_any(r, clinic, Balance.CLINIC_R), lk)
		# 앓음 (병마다 — HEALTH.md 2.1·2.2)
		if r.sick_left > 0.0:
			Mold.medicine(v, r)           # [곰팡이·뚜껑] 곰팡이약을 써 본다 (HEALTH 2.5b — 듣는 병: 중증 막음·기간 ×0.5)
			n_sick += 1
			cases[r.disease] = int(cases.get(r.disease, 0)) + 1
			var dz: Dictionary = Balance.DISEASES.get(r.disease, Balance.DISEASES["고뿔"])
			var in_clinic := _near_any(r, clinic, Balance.CLINIC_R)
			var loss: float
			var has_herb := float(v.stock.get(Balance.HERB, 0.0)) >= 1.0
			if r.severe:
				loss = Balance.SEVERE_HEALTH_CLINIC if in_clinic else Balance.SEVERE_HEALTH_DAY
				if tt >= r.herb_until and has_herb:     # 중증: 약초 1개 = 하루치 감소를 막음 (첫 개는 기간도 절반)
					v.stock[Balance.HERB] = float(v.stock[Balance.HERB]) - 1.0
					r.herb_until = tt + Balance.DAY
					if not r.herb_used:
						r.herb_used = true
						r.sick_left *= 0.5
				if tt < r.herb_until:
					loss = 0.0
			else:
				loss = float(dz["health"])
				if in_clinic:
					loss = minf(loss, Balance.ILL_HEALTH_CLINIC)
				if not r.herb_used and has_herb:
					v.stock[Balance.HERB] = float(v.stock[Balance.HERB]) - 1.0
					r.herb_used = true
					r.sick_left *= 0.5
			if loss > 0.0:
				_hurt(r, "병", loss * dt / Balance.DAY)
			r.sick_left = maxf(0.0, r.sick_left - dt)
			if r.sick_left <= 0.0:
				recover(v, r, tt)
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
	_end_outbreaks(v, cases)
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
		VillageEra.herb_watch(v)              # DISCOVERIES F2 약초 (앓는 사람 + 습한 숲가)
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
		if VillageEra.clinic_active(v, b):        # 약초사가 있는 치료소 (A6 — sim/village_era.gd)
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
## 사람이 사는 집마다: 그 자리의 추위 정도 > 0이면 병 시계 4시간마다 통나무 1개 (Balance.FUEL_EVERY — design/gdd/health.md R3) (석조 주택 ×0.5). 땔감 = 집의 in_buf["통나무"] (운반 일이 창고에서 나른다)
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
		b.fuel_acc = maxf(0.0, b.fuel_acc - dt * (Balance.FUEL_STONE if b.type == "석조주택" else 1.0) * CoreWarmth.fuel_mult(v) / Balance.FUEL_EVERY)   # [핵] 온천 (A28b)


## 이 집에 땔감을 날라야 하나 — 몇 개까지
static func fuel_lack(v: Village, b: Building) -> float:
	if not v.cold_season or not b.built or not b.is_house():
		return 0.0
	return Balance.FUEL_TARGET - float(b.in_buf.get("통나무", 0.0)) - float(b.in_inc.get("통나무", 0.0))


# ───────────────────────── 질병·부상 굴림 (2 · 3) — 정시마다 ─────────────────────────
## 병마다의 발병 = 하루 1% × 공통 배율 × 몫 × '어디서' 배율 + 같은 병 전염 (식구·반경 2칸) × 유행의 전염 배율.
## 한 사람에 난수 하나로 '걸리나'를 굴리고, 걸리면 하나 더로 '무슨 병'을 고른다 (병 순서 고정 — 결정론).
## 빠르게: 옮는 병을 앓는 사람이 없으면 '어디서' 배율의 최댓값으로 먼저 걸러 낸다 (같은 난수 하나 — 결과는 똑같음)
static func _hourly(v: Village, clinic: Array) -> void:
	var sick_home := {}               # 병 → {집 id → 앓는 식구 수}
	var sick: Array[Resident] = []
	for r in v.people:
		if r.sick_left > 0.0 and r.disease != "" and _contagious(r.disease):
			sick.append(r)
			if r.home >= 0:                # 치료소에 따로 누운 사람은 식구에게 덜 옮긴다 (격리 — ROADMAP B7)
				var hm0: Dictionary = sick_home.get(r.disease, {})
				hm0[r.home] = float(hm0.get(r.home, 0.0)) + (Balance.QUARANTINE_HOME if r.doing == "치료소에 누운 중" else 1.0)
				sick_home[r.disease] = hm0
	var wells: Array = []
	for b in v.buildings:
		if b.built and b.type == "우물":
			wells.append(Vector2(b.x, b.y))
	var occ := v.occupancy()
	var ctx := {}
	var wmax := -1.0
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
				# 10%는 덧나 곪은 상처 (HEALTH.md 3) — 이미 앓는 중이면 그대로
				if v.health_rng.randf() < Balance.FESTER * SkyDrops.fester_mult(v) and r.sick_left <= 0.0:     # [상점] 반창고 조각 5일: 곪지 않음
					fall_ill(v, r, in_clinic, Balance.FESTER_KIND)
		if r.sick_left > 0.0:
			continue
		var hm := v.bld(r.home)
		var p0 := Balance.ILL_DAY
		if r.hunger >= Balance.STARVING_AT:
			p0 *= Balance.ILL_HUNGRY
		if r.health < Balance.ILL_WEAK_BELOW:
			p0 *= Balance.ILL_WEAK
		if hm != null and int(occ.get(hm.id, 0)) >= hm.cap():
			p0 *= Balance.ILL_CROWDED
		p0 *= age_mult(r)
		p0 *= CoreWarmth.ill_mult(v)          # [핵] 서늘한 별: 추운 철엔 이끼 이불로 덜 앓음 (A28b — 보통 별은 1, 난수 흐름 그대로)
		var u := v.health_rng.randf()
		if wmax < 0.0:
			wmax = _where_max(v.climate())
		var mold_m := Mold.ill_mult(v, r)     # [곰팡이·뚜껑] 털뭉치 둘레: 배앓이·기침병 ×2 → 거르기 상한도 그만큼 (결과는 곰팡이 없으면 그대로)
		var fl_m := Flora.ill_mult(v) * SkyDrops.ill_mult(v)    # [하늘의 것] 얼룩버섯을 먹은 날: 배앓이 ×5 (WORLD_EVENTS 2.6) · [상점] 녹조 배앓이↑
		if sick.is_empty() and u >= p0 * wmax * mold_m * fl_m * r.f("illness") / 24.0:
			continue                  # 어떤 '어디서' 배율이어도 안 걸림
		if ctx.is_empty():
			var season: String = jar_date(v)["season"]
			var cl := v.climate()
			ctx = {"winter": season == "겨울", "tropic_summer": season == "여름" and (cl == "열대" or cl == "아열대"), "climate": cl}
		ctx["no_well"] = hm == null or not _near_pt(hm, wells, Balance.WELL_R)
		ctx["hungry"] = r.hunger >= Balance.STARVING_AT
		ctx["hot"] = r.heat >= Balance.DISEASE_EXPOSED
		ctx["cold"] = r.cold >= Balance.DISEASE_EXPOSED
		ctx["elder"] = r.is_elder()
		var ps: Array[float] = []
		var total := 0.0
		for kind: String in Balance.DISEASE_ORDER:
			var pd := 0.0
			if not r.is_immune(kind, v.t):
				var dz: Dictionary = Balance.DISEASES[kind]
				pd = p0 * share_of(kind, String(ctx["climate"])) * where_mult(dz, ctx) * Mold.kind_mult(kind, mold_m)
				if kind == "배앓이":
					pd *= fl_m
				var cg := 0.0
				if float(dz["home"]) > 0.0 or float(dz["near"]) > 0.0:
					if r.home >= 0:
						cg += float(dz["home"]) * float((sick_home.get(kind, {}) as Dictionary).get(r.home, 0.0))
					for s in sick:
						if s.disease == kind and (s.home != r.home or r.home < 0):
							if Vector2(s.x - r.x, s.y - r.y).length() <= Balance.CONTAGION_R:
								cg += float(dz["near"])
					if cg > 0.0:
						cg *= float(outbreak(v, kind)["c"])
						if in_clinic:
							cg *= Balance.CONTAGION_CLINIC
				pd = (pd + cg) * r.f("illness")
			ps.append(pd)
			total += pd
		if total > 0.0 and u < total / 24.0:
			var pick := v.health_rng.randf() * total
			var kind: String = Balance.DISEASE_ORDER[0]
			for i in ps.size():
				if ps[i] <= 0.0:
					continue
				kind = Balance.DISEASE_ORDER[i]
				pick -= ps[i]
				if pick < 0.0:
					break
			fall_ill(v, r, in_clinic, kind)


## 자연 발병 배율의 최댓값 (모든 '어디서'가 참일 때 몫 × 배율의 합) — 거르기용. 기후마다 (그 병에 사는 병만).
## 시간마다 한 번만 부르므로 그때 셈 (static 캐시 없음 — ADR-0001 d, ROADMAP F-2)
static func _where_max(climate := "") -> float:
	var w := 0.0
	for kind: String in Balance.DISEASE_ORDER:
		var dz: Dictionary = Balance.DISEASES[kind]
		var m := share_of(kind, climate) if climate != "" else float(dz["share"])
		for k: String in dz["where"]:
			m *= maxf(1.0, float(dz["where"][k]))
		w += m
	return w


# ───────────────────────── 병이 들어오는 길 (WORLD_EVENTS 5 · HEALTH 2.6 — ROADMAP B7) ─────────────────────────
## 이 병이 이 기후의 병에 처음부터 사는가 (고뿔·배앓이·기침병·곪은 상처는 모든 병, 열병은 열대·아열대, 역병은 어디에도)
static func endemic(kind: String, climate: String) -> bool:
	if not Balance.DISEASE_ENDEMIC.has(kind):
		return true
	return climate in (Balance.DISEASE_ENDEMIC[kind] as Array)


## 자연 발병의 몫 — 사는 병만. 살지 않는 병의 몫은 나머지 병에 비율대로 나눈다 (HEALTH 2.6)
static func share_of(kind: String, climate: String) -> float:
	if not endemic(kind, climate):
		return 0.0
	var all := 0.0
	var here := 0.0
	for k: String in Balance.DISEASE_ORDER:
		var sh := float(Balance.DISEASES[k]["share"])
		all += sh
		if endemic(k, climate):
			here += sh
	return float(Balance.DISEASES[kind]["share"]) * (all / here if here > 0.0 else 1.0)


## 밖에서 병을 지니고 왔다 — 하루 잠복 (아프지도 옮기지도 않음 — 거인에게는 창백한 얼굴빛). 이미 앓거나 면역이면 아무 일 없음
static func make_latent(v: Village, r: Resident, kind: String) -> bool:
	if r.sick_left > 0.0 or r.latent != "" or r.is_immune(kind, v.t):
		return false
	r.latent = kind
	r.latent_until = v.t + Balance.LATENT
	var by: Dictionary = v.stats.get("carried_by", {})
	by[kind] = int(by.get(kind, 0)) + 1
	v.stats["carried_by"] = by
	return true


## 거인이 넣은 먹는 물건 (각설탕·마른 약초)에 바깥의 열병이 묻어 옴 (2%) — 먹은 사람 하나가 잠복
static func food_carry(v: Village, item: String) -> bool:
	if not item in Balance.FOOD_FEVER_ITEMS or v.people.is_empty():
		return false
	if v.health_rng.randf() >= Balance.FOOD_FEVER_P:
		return false
	var r: Resident = v.people[v.health_rng.randi() % v.people.size()]
	return make_latent(v, r, "열병")


## 잠복 중인 사람이 있는 병 (사라지지 않은 병)
static func latent_kinds(v: Village) -> Dictionary:
	var out := {}
	for r in v.people:
		if r.latent != "":
			out[r.latent] = true
	return out


static func _contagious(kind: String) -> bool:
	var dz: Dictionary = Balance.DISEASES.get(kind, {})
	return not dz.is_empty() and (float(dz["home"]) > 0.0 or float(dz["near"]) > 0.0)


## '어디서' 배율 (HEALTH.md 2.1) — ctx의 참인 항목마다 곱함
static func where_mult(dz: Dictionary, ctx: Dictionary) -> float:
	var m := 1.0
	var wh: Dictionary = dz["where"]
	for k: String in wh:
		if bool(ctx.get(k, false)):
			m *= float(wh[k])
	return m


static func _near_pt(b: Building, pts: Array, rad: float) -> bool:
	for p: Vector2 in pts:
		if Vector2(b.x, b.y).distance_to(p) <= rad:
			return true
	return false


# ───────────────────────── 유행 (2.5 ①) ─────────────────────────
## 삼각 분포의 역누적 (u 0~1, 폭 a~b, 최빈값 c)
static func tri(u: float, a: float, b: float, c: float) -> float:
	if b <= a:
		return a
	c = clampf(c, a, b)
	var fc := (c - a) / (b - a)
	if u < fc:
		return a + sqrt(u * (b - a) * (c - a))
	return b - sqrt((1.0 - u) * (b - a) * (b - c))


## 이 병의 유행 독함 (값 하나를 한 번 굴려 전염 배율·치사율 둘 다 정함). 0~1 = 치사율이 폭의 어디쯤 (치사율 폭이 없으면 전염 배율)
static func roll_strain(kind: String, u: float) -> Dictionary:
	var dz: Dictionary = Balance.DISEASES[kind]
	var cr: Array = dz["contagion_range"]
	var lr: Array = dz["lethal_range"]
	var c := tri(u, float(cr[0]), float(cr[1]), 1.0)
	var l := tri(u, float(lr[0]), float(lr[1]), float(dz["lethal"]))
	var s := 0.5
	if float(lr[1]) > float(lr[0]):
		s = (l - float(lr[0])) / (float(lr[1]) - float(lr[0]))
	elif float(cr[1]) > float(cr[0]):
		s = (c - float(cr[0])) / (float(cr[1]) - float(cr[0]))
	var nm := kind
	if s >= 0.75 and str(dz["strong"]) != "":
		nm = str(dz["strong"])
	elif s <= 0.25 and str(dz["mild"]) != "":
		nm = str(dz["mild"])
	return {"c": c, "l": l, "s": s, "name": nm}


## 지금 이 병의 유행 — 없으면 새로 시작 (독함을 건강 난수로 한 번 굴림). 곪은 상처는 상처마다 같아 유행이 없다
static func outbreak(v: Village, kind: String) -> Dictionary:
	if v.outbreaks.has(kind):
		return v.outbreaks[kind]
	var ob := roll_strain(kind, v.health_rng.randf())
	ob["t"] = v.t
	ob["n"] = 0
	ob["won"] = 0
	if kind == Balance.FESTER_KIND:
		return ob
	v.outbreaks[kind] = ob
	var dz: Dictionary = Balance.DISEASES[kind]
	var nm: String = ob["name"]
	if kind == Balance.PLAGUE or nm == str(dz["strong"]) or (nm == str(dz["mild"]) and float(dz["lethal"]) >= 0.05):
		v.log_line("%s%s 돌기 시작했다." % [nm, Village.josa(nm, "이", "가")])
	return ob


## 그 병을 앓는 사람이 0이 되면 유행이 끝난다 (다음 유행은 새로 굴림)
static func _end_outbreaks(v: Village, cases: Dictionary) -> void:
	for kind: String in v.outbreaks.keys():
		if int(cases.get(kind, 0)) > 0:
			continue
		var ob: Dictionary = v.outbreaks[kind]
		if float(Balance.DISEASES[kind]["immune_days"]) == Balance.IMMUNE_LIFE and int(ob["won"]) >= 2:
			var nm: String = ob["name"]
			v.log_line("그 %s%s 이겨 낸 사람들은 다시 앓지 않았다." % [nm, Village.josa(nm, "을", "를")])
		v.outbreaks.erase(kind)
		if not endemic(kind, v.climate()) and not latent_kinds(v).has(kind) and int(ob["n"]) >= 2:     # 닫힌 병: 앓는 사람이 0이면 바깥의 병은 사라진다
			v.log_line("%s%s 마을에서 자취를 감추었다." % [kind, Village.josa(kind, "은", "는")])


## 역병 위기 (기획서 10장 · HEALTH.md 2.4) — 자연 발병은 없다. 면역 없는 사람 중 n명이 처음 걸린다. 걸린 사람 수를 돌려줌
static func start_plague(v: Village, n := Balance.PLAGUE_FIRST) -> int:
	var pool: Array[Resident] = []
	for r in v.people:
		if r.sick_left <= 0.0 and not r.is_immune(Balance.PLAGUE, v.t):
			pool.append(r)
	var got := 0
	while got < n and not pool.is_empty():
		var r: Resident = pool[v.health_rng.randi() % pool.size()]
		pool.erase(r)
		fall_ill(v, r, false, Balance.PLAGUE)
		got += 1
	return got


# ───────────────────────── 앓기 시작·중증·낫기 ─────────────────────────
## 나이 칸: 0 아기 · 1 아이 · 2 어른 · 3 노인
static func age_class(r: Resident) -> int:
	if r.is_baby():
		return 0
	if r.is_child():
		return 1
	if r.is_elder():
		return 3
	return 2


## 중증 확률 (HEALTH.md 2.2 · 2.5) = 유행의 치사율 × 병마다 나이 배율 × 굶주림 ×2 · 건강 0.5 미만 ×1.5 · 강인한 ×0.7 / 병약 ×1.3
static func severe_p(r: Resident, kind: String, lethal: float) -> float:
	var p := lethal * float((Balance.DISEASES[kind]["age_severity"] as Array)[age_class(r)])
	if r.hunger >= Balance.STARVING_AT:
		p *= Balance.ILL_HUNGRY
	if r.health < Balance.ILL_WEAK_BELOW:
		p *= Balance.ILL_WEAK
	return clampf(p * r.f("illness"), 0.0, 1.0)


static func fall_ill(v: Village, r: Resident, in_clinic := false, kind := "고뿔") -> void:
	var dz: Dictionary = Balance.DISEASES[kind]
	var ob := outbreak(v, kind)
	ob["n"] = int(ob["n"]) + 1
	r.disease = kind
	r.disease_name = ob["name"]
	r.last_disease = kind
	r.sick_left = float(dz["days"]) * Balance.DAY / maxf(0.1, r.f("heal")) * (Balance.CLINIC_TIME if in_clinic else 1.0)
	r.sick_since = v.t
	r.herb_used = false
	r.herb_until = -1.0
	r.severe = v.health_rng.randf() < severe_p(r, kind, float(ob["l"])) * Flora.severe_mult(v, r, kind) * SkyDrops.severe_mult(v)   # [하늘의 것] 얼룩버섯: 아이 중증 ×2 · [상점] 알약 부스러기 3일 ×0.3
	v.stats["sick"] = int(v.stats.get("sick", 0)) + 1
	var by: Dictionary = v.stats.get("sick_by", {})
	by[kind] = int(by.get(kind, 0)) + 1
	v.stats["sick_by"] = by
	if r.severe:
		v.stats["severe"] = int(v.stats.get("severe", 0)) + 1
	if not r.is_baby():
		ResidentAI.cancel(v, r)          # 하던 일을 놓고 눕는다 (짐·예약은 되돌림)
		if r.age >= 2.5:
			v.speak(r, "몸이 으슬으슬해…", 5)
	if r.severe:
		_severe_notice(v, r)


## 중증 환자를 말풍선·편지로 알린다 ("마르타가 열병으로 몹시 아파요.") — 거인이 도울 기회 (HEALTH.md 2.2)
static func _severe_notice(v: Village, r: Resident) -> void:
	var text := severe_line(r)
	v.warnings.append({"t": v.t, "kind": "severe", "text": text, "who": r.id})
	if v.warnings.size() > 20:          # 화면이 가져가지 않는 동안(오프라인·시험) 끝없이 쌓이지 않게
		v.warnings.pop_front()
	var teller: Resident = null
	for q in v.people:
		if q == r or q.sleeping or q.sick_left > 0.0 or q.age < 2.5:
			continue
		if teller == null or (q.home == r.home and teller.home != r.home):
			teller = q
		if teller.home == r.home and r.home >= 0:
			break
	if teller != null:
		v.speak(teller, text, 7)


static func severe_line(r: Resident) -> String:
	var nm := r.disease_name if r.disease_name != "" else r.disease
	return "%s%s %s%s 몹시 아파요." % [r.name, Village.josa(r.name, "이", "가"), nm, ro(nm)]


## 나음: 그 병에만 면역 (표의 기간, 평생은 죽을 때까지) · '이겨 낸 병'에 더함
static func recover(v: Village, r: Resident, tt: float) -> void:
	v.stats["recovered"] = int(v.stats.get("recovered", 0)) + 1
	var kind := r.disease
	if Balance.DISEASES.has(kind):
		var im := float(Balance.DISEASES[kind]["immune_days"])
		if im == Balance.IMMUNE_LIFE:
			r.immune[kind] = Balance.IMMUNE_LIFE
		elif im > 0.0:
			r.immune[kind] = tt + im * Balance.DAY
		if not kind in r.overcome:
			r.overcome.append(kind)
		if v.outbreaks.has(kind):
			v.outbreaks[kind]["won"] = int(v.outbreaks[kind]["won"]) + 1
	r.sick_left = 0.0
	r.disease = ""
	r.disease_name = ""
	r.severe = false
	r.herb_until = -1.0


## 아기는 엄마의 면역을 태어나서 1일(아기 시기) 동안 물려받는다 (유전 아님 — HEALTH.md 2.3)
static func inherit_immunity(baby: Resident, mom: Resident, t: float) -> void:
	var until := t + Balance.AGE_BABY * Balance.DAY
	for kind: String in mom.immune:
		if mom.is_immune(kind, t):
			var u := float(mom.immune[kind])
			baby.immune[kind] = until if u == Balance.IMMUNE_LIFE else minf(u, until)


## '으로/로' (받침 없음·ㄹ받침 → 로)
static func ro(w: String) -> String:
	if w.is_empty():
		return "로"
	var c := w.unicode_at(w.length() - 1) - 0xAC00
	if c < 0 or c >= 11172:
		return "로"
	var jong := c % 28
	return "로" if (jong == 0 or jong == 8) else "으로"


## 병으로 죽음인가 ("병" 또는 병 이름)
static func is_illness(why: String) -> bool:
	return why == "병" or Balance.DISEASES.has(why)


## 건강이 0이 된 사람의 사망 원인 — 최근 건강을 가장 많이 깎은 것 (부상만으로는 죽지 않는다 → 나머지 중에서).
## 병이면 병 이름 (앓는 중인 병, 아니면 마지막으로 앓은 병)
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
	if best == "병":
		var kind := r.disease if (r.sick_left > 0.0 and r.disease != "") else r.last_disease
		if kind != "":
			return kind
	return best
