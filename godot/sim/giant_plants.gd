## 거대 식물 — 초거대 해바라기·씨앗비·목화·그늘 지도 (design/gdd/flower-forest.md R2·R3·R4 · F1~F3, ROADMAP F-2).
## 병(물) 하나의 상태라 WorldWater에 저장한다 (sunflowers · sf_seeds · cotton) — 소형 병(JarWater)엔 없음 (경우 4).
##   · 해바라기: 병마다 SF_COUNT(2) 그루. 하나는 첫 마을 터 가장자리 밖 20~26칸 (마을에서 그림자가 보이게, AC3), 하나는 멀리.
##     꽃판은 늘 등불 쪽 (F1) — 등불을 옮기면 SF_TURN(병 2시간)에 걸쳐 돌아간다. 꽃판 그림자 = 줄기 − 빛 × SF_SHADOW_OFF.
##   · 씨앗비 (MVP): 늦여름(8월 24~28일) 핀 꽃판이 하루 몇 알 — 그림자가 먼저 커지고(SEED_WARN) 땅에 박힘(먼지) →
##     아이들이 달려가고 어른이 굴려 와 창고에 '해바라기씨' (village-economy R6). 떨어진 자리에 서 있던 사람은 작은 확률로 다침.
##   · 목화: 꽃숲 가장자리·볕 드는 촉촉한 자리에 덤불 → 9~11월 다래가 터짐 → 솜뭉치를 굴려 창고 '솜' (민들레 솜과 같은 자원).
##   · 그늘 지도 shade_at: 꽃숲 1.5칸 · 큰 갓 · 해바라기 그림자 · 큰 나무 잎 아래 — 겹쳐도 한 번 (F2, Health.protection이 읽음).
##   · 솜 이불 quilt_on: 집 안 추위 ×QUILT_COLD (health.md 메인 판단 ①).
## 결정성 (R7): 마을 난수를 쓰지 않는다 — 시드·시간으로 정한 난수만 (다른 흐름을 흔들지 않게).
class_name GiantPlants
extends RefCounted

const STAGES := {3: "grow", 4: "grow", 5: "grow", 6: "bloom", 7: "bloom", 8: "bloom", 9: "droop", 10: "droop", 11: "droop",
	12: "dry", 1: "dry", 2: "dry"}
const SEED_LINE := "늦여름, 하늘 높이 핀 해바라기 꽃판에서 커다란 씨앗이 떨어졌다. 아이들이 먼저 달려가고, 어른들이 씨앗을 굴려 와 창고에 넣었다."
const COTTON_LINE := "숲 가장자리 덤불에서 하얀 솜뭉치가 터져 나왔다. 사람들은 솜을 굴려 와 겨울 이불을 꿈꾸었다."
const SAY_SEED := "씨앗이 떨어졌어! 가 보자!"
const SAY_SHADOW := "그림자가 커져… 비켜!"


# ───────────────────────── 자리 (세상 만들기 · 첫 키트) ─────────────────────────
## 첫 무리가 서면 (JarWorld.place_kit · 옛 저장은 ensure) 두 그루를 세운다. 결정론: 같은 시드·같은 터 → 같은 자리
static func place(ww: WorldWater, v: Village) -> void:
	ww.sunflowers.clear()
	ww.sf_seeds.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = ww.seed_v * 271 + 13
	var c := v.center
	var terr := v.territory_r()
	# 1) 마을 곁: 터 가장자리 밖 SF_NEAR, 네 등불 자리 중 둘 이상에서 그림자가 영역에 닿는 곳
	var best := Vector2.INF
	var best_v := -INF
	for tries in 160:
		var a := rng.randf() * TAU
		var d := Balance.SF_SITE_R + rng.randf_range(Balance.SF_NEAR[0], Balance.SF_NEAR[1])
		var p := c + Vector2(cos(a), sin(a)) * d
		var s := _score(ww, v, p) + 4.0 * minf(2.0, float(lamp_overlaps(ww, p, c, terr)) - 2.0)
		if s > best_v:
			best_v = s
			best = p
		if s >= 0.0:
			break
	if best != Vector2.INF:
		_add(ww, v, best, rng)
	# 2) 멀리: 첫 마을에서 SF_FAR_MIN 넘게, 큰 나무·물에서 멀리
	for i in Balance.SF_COUNT - 1:
		best = Vector2.INF
		best_v = -INF
		for tries in 160:
			var a := rng.randf() * TAU
			var p := Vector2(cos(a), sin(a)) * ww.rr * rng.randf_range(0.2, 0.8)
			var s := _score(ww, v, p) - maxf(0.0, Balance.SF_FAR_MIN - p.distance_to(c))
			for o: Dictionary in ww.sunflowers:
				s -= maxf(0.0, Balance.SF_FAR_MIN - p.distance_to(Vector2(o["x"], o["y"])))
			if s > best_v:
				best_v = s
				best = p
			if s >= 0.0:
				break
		if best != Vector2.INF:
			_add(ww, v, best, rng)


static func _add(ww: WorldWater, v: Village, p: Vector2, rng: RandomNumberGenerator) -> void:
	var l := ww.light
	ww.sunflowers.append({"id": ww.sunflowers.size(), "x": p.x, "y": p.y, "hx": l.x, "hy": l.y, "fx": l.x, "fy": l.y,
		"lx": l.x, "ly": l.y, "t0": -1.0, "stage": stage_of(v), "yaw": rng.randf() * TAU})
	# 줄기 자리의 꽃숲은 비킨다
	var r2 := (Balance.SF_TRUNK_R + 1.0) * (Balance.SF_TRUNK_R + 1.0)
	for pv: Variant in (v.peers if not v.peers.is_empty() else [v]):
		var vv := pv as Village
		vv.trees = vv.trees.filter(func(t: Dictionary) -> bool: return Vector2(float(t["x"]), float(t["y"])).distance_squared_to(p) > r2)


## 자리 점수 (0 이상 = 좋음): 세상 안 · 물이 아닌 땅 · 큰 나무와 멀리 · 지은 것과 겹치지 않음 (경우 2·3)
static func _score(ww: WorldWater, v: Village, p: Vector2) -> float:
	var s := 0.0
	if not ww.inside(p.x, p.y, Balance.SF_SHADOW_OFF + Balance.SF_HEAD_R + 4.0):
		return -1000.0
	for k in ww.cells_near(p, Balance.SF_TRUNK_R + 2.0):
		if ww.depth(k) > 0.004:
			s -= 20.0
	for t: Dictionary in ww.great_trees:
		s -= 5.0 * maxf(0.0, float(t["r"]) * Balance.GREAT_SHADE_K + 12.0 - p.distance_to(Vector2(t["x"], t["y"])))
	for pv: Variant in (v.peers if not v.peers.is_empty() else [v]):
		for b in (pv as Village).buildings:
			s -= 10.0 * maxf(0.0, b.size() + Balance.SF_TRUNK_R + 2.0 - p.distance_to(Vector2(b.x, b.y)))
	return s


## 네 등불 자리 중 꽃판 그림자가 영역(반지름 terr)과 겹치는 수 (AC3)
static func lamp_overlaps(ww: WorldWater, p: Vector2, c: Vector2, terr: float) -> int:
	var l := ww.light
	var n := 0
	for i in 4:
		var sc := p - l * Balance.SF_SHADOW_OFF
		if sc.distance_to(c) <= terr + Balance.SF_HEAD_R:
			n += 1
		l = Vector2(l.y, -l.x)
	return n


## 옛 저장 (해바라기 없음): 불러올 때 한 번 (경우 3) — 지은 건물을 피해서
static func ensure(jw: JarWorld) -> void:
	if jw.water == null or jw.settlements.is_empty() or not jw.water.sunflowers.is_empty():
		return
	place(jw.water, jw.primary())


# ───────────────────────── 꽃판 방향·그림자 (F1) ─────────────────────────
## 지금 꽃판이 보는 쪽 (빛 방향 l과 같은 크기). 돌아가는 동안은 옛 → 새 방향을 SF_TURN에 걸쳐 선형 보간 후 정규화
static func head_dir(sf: Dictionary, t: float) -> Vector2:
	var to := Vector2(sf["lx"], sf["ly"])
	var t0 := float(sf.get("t0", -1.0))
	if t0 < 0.0:
		return to
	var u := clampf((t - t0) / Balance.SF_TURN, 0.0, 1.0)
	var d := Vector2(sf["fx"], sf["fy"]).lerp(to, u)
	if d.length() < 1e-4:                           # 정반대로 돌 때 가운데 — 옆으로 비켜 돈다
		d = Vector2(-to.y, to.x) * 0.01
	return d.normalized() * to.length()


static func shadow_center(sf: Dictionary, t: float) -> Vector2:
	return Vector2(sf["x"], sf["y"]) - head_dir(sf, t) * Balance.SF_SHADOW_OFF


static func shadow_r(sf: Dictionary) -> float:
	return Balance.SF_HEAD_R * float(Balance.SF_STAGE_SHADOW.get(String(sf.get("stage", "bloom")), 1.0))


static func in_sf_shadow(ww: WorldWater, x: float, y: float, t: float) -> bool:
	for sf: Dictionary in ww.sunflowers:
		var r := shadow_r(sf)
		if shadow_center(sf, t).distance_squared_to(Vector2(x, y)) <= r * r:
			return true
	return false


static func stage_of(v: Village) -> String:
	return String(STAGES[int(Health.jar_date(v)["month"])])


# ───────────────────────── 그늘 지도 (R2 · F2) ─────────────────────────
## 이 자리가 그늘인가 — 꽃숲 1.5칸 · 큰 갓 · 해바라기 꽃판 그림자 · 큰 나무 잎 아래. 하나만 참이어도 (겹쳐도 한 번)
static func shade_at(v: Village, x: float, y: float) -> bool:
	var r2 := Balance.SHADE_R * Balance.SHADE_R
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree":
			var dx := float(tr["x"]) - x
			if absf(dx) > Balance.SHADE_R:
				continue
			var dy := float(tr["y"]) - y
			if dx * dx + dy * dy <= r2:
				return true
	if v.flora != null and v.flora.shade_at(x, y):
		return true
	if v.water is WorldWater:
		var ww := v.water as WorldWater
		if in_sf_shadow(ww, x, y, v.t):
			return true
		for t: Dictionary in ww.great_trees:
			var rr := float(t["r"]) * Balance.GREAT_SHADE_K
			if Vector2(float(t["x"]) - x, float(t["y"]) - y).length_squared() <= rr * rr:
				return true
	return false


## 짓기·숲 퍼지기를 막는 곳 (줄기 둘레 SF_TRUNK_R)
static func blocks(w: JarWater, x: float, y: float, size: float) -> bool:
	if not w is WorldWater:
		return false
	for sf: Dictionary in (w as WorldWater).sunflowers:
		if Vector2(float(sf["x"]) - x, float(sf["y"]) - y).length() < Balance.SF_TRUNK_R + size:
			return true
	return false


# ───────────────────────── 솜 이불 (health.md 메인 판단 ①) ─────────────────────────
## 이 사람 몫의 이불이 집에 있는가 — 이불 수 = 창고의 '솜 이불'(#15) + 옷 몫을 넘는 솜 / QUILT_PER. 모자라면 사람마다 정해진 순서로
static func quilt_on(v: Village, r: Resident) -> bool:
	var n := v.people.size()
	if n == 0:
		return false
	var c := float(v.stock.get("솜", 0.0))
	var q := float(v.stock.get("솜 이불", 0.0)) + maxf(0.0, c - n * Balance.COTTON_PER) / Balance.QUILT_PER
	if q <= 0.0:
		return false
	var share := clampf(q / n, 0.0, 1.0)
	return fposmod(r.id * 0.381966 + 0.27, 1.0) < share


# ───────────────────────── 걸음 (Village.step) ─────────────────────────
static func step(v: Village, dt: float) -> void:
	if not v.water is WorldWater or not v.owns_water:
		return
	var ww := v.water as WorldWater
	if ww.sunflowers.is_empty() and ww.sf_seeds.is_empty():
		return
	var l := ww.light
	for sf: Dictionary in ww.sunflowers:
		if absf(float(sf["lx"]) - l.x) > 1e-5 or absf(float(sf["ly"]) - l.y) > 1e-5:     # 등불이 옮겨 갔다 → 돌기 시작
			var cur := head_dir(sf, v.t)
			sf["fx"] = cur.x
			sf["fy"] = cur.y
			sf["lx"] = l.x
			sf["ly"] = l.y
			sf["t0"] = v.t
		elif float(sf["t0"]) >= 0.0 and v.t - float(sf["t0"]) >= Balance.SF_TURN:
			sf["t0"] = -1.0
			v.emit(&"sunflower_turned", {"v": {"id": int(sf["id"])}, "who": -1, "at": Vector2(sf["x"], sf["y"])})
	var vills: Array = v.peers if not v.peers.is_empty() else [v]
	for s: Dictionary in ww.sf_seeds:
		match String(s["st"]):
			"sky":
				if not s.get("warned", false) and v.t >= float(s["t_land"]) - Balance.SEED_WARN:
					s["warned"] = true
					v.emit(&"seed_shadow", {"v": {"id": int(s["id"])}, "who": -1, "at": Vector2(s["x"], s["y"])})
				if v.t >= float(s["t_land"]):
					_land(v, ww, s, vills)
			"roll":
				var r := _person(vills, int(s["roller"]))
				if r == null or r.carry != "해바라기씨":
					s["st"] = "ground"
					s["roller"] = -1
				else:
					var f := Vector2(sin(r.facing), cos(r.facing))
					s["x"] = r.x + f.x * 0.9
					s["y"] = r.y + f.y * 0.9


static func _person(vills: Array, id: int) -> Resident:
	for pv: Variant in vills:
		for r in (pv as Village).people:
			if r.id == id:
				return r
	return null


## 씨앗이 땅에 박힘 (먼지) — 떨어진 자리에 서 있던 사람은 작은 확률로 다침, 둘레는 화들짝. 그다음 아이들·어른이 움직인다
static func _land(v: Village, ww: WorldWater, s: Dictionary, vills: Array) -> void:
	s["st"] = "ground"
	s["landed"] = v.t
	var at := Vector2(s["x"], s["y"])
	var rng := RandomNumberGenerator.new()
	rng.seed = ww.seed_v * 389 + int(s["id"]) * 31 + 7
	var hurt := 0
	for pv: Variant in vills:
		var vv := pv as Village
		for r in vv.people:
			var d := Vector2(r.x, r.y).distance_to(at)
			if d < Balance.SEED_HIT_R:
				if r.injured_left <= 0.0 and rng.randf() < Balance.SEED_HIT_P:
					r.injured_left = Balance.INJURY_DAYS * Balance.DAY * 0.5
					hurt += 1
				vv.raise_fear(r, 0.03)
			elif d < 5.0:
				vv.raise_fear(r, 0.01)
	s["hurt"] = hurt
	v.emit(&"seed_landed", {"v": {"id": int(s["id"]), "hurt": hurt}, "who": -1, "at": at})
	for pv: Variant in vills:
		var vv := pv as Village
		if vv.center.distance_to(at) <= vv.territory_r() + Balance.SEED_REACH:
			kids_run(vv, s)
			roll_fetch(vv)


# ───────────────────────── 한 시간 (Village 호숫가 시계) ─────────────────────────
static func hourly(v: Village) -> void:
	if not v.water is WorldWater:
		return
	var ww := v.water as WorldWater
	var date := Health.jar_date(v)
	var month := int(date["month"])
	if v.owns_water:
		var st := String(STAGES[month])
		for sf: Dictionary in ww.sunflowers:
			var old := String(sf.get("stage", st))
			if old != st:
				sf["stage"] = st
				if st == "bloom":
					v.emit(&"sunflower_bloomed", {"v": {"id": int(sf["id"])}, "who": -1, "at": Vector2(sf["x"], sf["y"])})
				elif st == "droop":
					v.emit(&"sunflower_drooped", {"v": {"id": int(sf["id"])}, "who": -1, "at": Vector2(sf["x"], sf["y"])})
		_schedule_rain(v, ww, date)
		var rot := Balance.SEED_ROT_DAYS * Balance.DAY
		ww.sf_seeds = ww.sf_seeds.filter(func(s: Dictionary) -> bool:
			return s["st"] != "ground" or v.t - float(s.get("landed", v.t)) < rot)
		_cotton_season(v, ww, date)
	_cotton_spawn(v, ww)
	if v.hour_now() >= 7.0 and v.hour_now() <= 17.0:
		roll_fetch(v)
		boll_fetch(v)


static func day_index(v: Village) -> int:
	return int((v.start_clock + v.t) / Balance.DAY)


## 씨앗비 날 (8월 24~28일): 그날 처음 한 번, 핀 꽃판마다 SEEDS_PER_DAY알의 떨어질 때·자리를 정한다
static func _schedule_rain(v: Village, ww: WorldWater, date: Dictionary) -> void:
	if int(date["month"]) != Balance.SEED_RAIN_MONTH or int(date["day"]) < Balance.SEED_RAIN_DAYS[0] or int(date["day"]) > Balance.SEED_RAIN_DAYS[1]:
		return
	var di := day_index(v)
	if ww.seed_rain_day == di:
		return
	ww.seed_rain_day = di
	var day0 := di * Balance.DAY - v.start_clock          # 그날 0시의 v.t
	var rng := RandomNumberGenerator.new()
	rng.seed = ww.seed_v * 613 + di
	for sf: Dictionary in ww.sunflowers:
		if String(sf.get("stage", "")) != "bloom":
			continue
		for i in Balance.SEEDS_PER_DAY:
			var tl := day0 + rng.randf_range(Balance.SEED_HOURS[0], Balance.SEED_HOURS[1]) * Balance.HOUR
			tl = maxf(tl, v.t + Balance.SEED_WARN + 5.0)
			var c := shadow_center(sf, tl)
			for k in 10:
				var a := rng.randf() * TAU
				var p := c + Vector2(cos(a), sin(a)) * shadow_r(sf) * sqrt(rng.randf()) * 0.8
				if not ww.inside(p.x, p.y, 2.0) or ww.depth(ww.idx(p.x, p.y)) > 0.004:
					continue
				ww.seed_serial += 1
				ww.sf_seeds.append({"id": ww.seed_serial, "sf": int(sf["id"]), "x": p.x, "y": p.y, "t_land": tl, "st": "sky",
					"food": Balance.SEED_FOOD, "roller": -1, "claim_until": -1.0, "yaw": rng.randf() * TAU})
				break


## 떨어진 씨앗으로 아이들이 달려간다 (놀이 — 결과 무관, #46)
static func kids_run(v: Village, s: Dictionary) -> int:
	var at := Vector2(s["x"], s["y"])
	var kids: Array = []
	for r in v.people:
		if r.dead or r.sleeping or not r.is_child() or r.age < 2.5 or r.sick_left > 0.0 or r.injured_left > 0.0:
			continue
		if not r.action in ["", "idle", "play", "wander", "social"] or r.carry != "":
			continue
		kids.append(r)
	kids.sort_custom(func(a: Resident, b: Resident) -> bool: return Vector2(a.x, a.y).distance_squared_to(at) < Vector2(b.x, b.y).distance_squared_to(at))
	kids = kids.slice(0, Balance.SEED_KIDS)
	for i in kids.size():
		var r: Resident = kids[i]
		ResidentAI.cancel(v, r)
		r.action = "play"
		r.last_action = "play"
		r.doing = "떨어진 해바라기씨 보러 달려가는 중"
		var a := TAU * i / maxf(1.0, kids.size()) + 0.7
		r.steps.append(ResidentAI.walk(at.x + cos(a) * 1.6, at.y + sin(a) * 1.6))
		r.steps.append(ResidentAI.act(30.0, "play"))
	if not kids.is_empty():
		v.speak(kids[0], SAY_SEED, 5)
	return kids.size()


## 닿는 곳의 씨앗을 한가한 어른이 하나씩 굴려 온다 → 보낸 사람 수
static func roll_fetch(v: Village) -> int:
	if not v.water is WorldWater:
		return 0
	var ww := v.water as WorldWater
	var reach := v.territory_r() + Balance.SEED_REACH
	var sent := 0
	for s: Dictionary in ww.sf_seeds:
		if s["st"] != "ground" or v.t < float(s.get("claim_until", -1.0)):
			continue
		var at := Vector2(s["x"], s["y"])
		if at.distance_to(v.center) > reach:
			continue
		var r := _free_adult(v, at)
		if r == null:
			break
		s["claim_until"] = v.t + 0.5 * Balance.DAY
		var st := v.store()
		var home := Vector2(st.x, st.y) if st != null else v.center
		ResidentAI.cancel(v, r)
		r.action = "haul"
		r.last_action = "haul"
		r.doing = "해바라기씨를 굴리러 가는 중"
		r.steps.append(ResidentAI.walk(at.x + 1.0, at.y + 0.4))
		r.steps.append(ResidentAI.act(Balance.SEED_ROLL_TIME, "work", ResidentAI.op("gplant_seed_take", {"sid": int(s["id"])})))
		r.steps.append(ResidentAI.walk(home.x + 1.2, home.y + 0.8))
		r.steps.append(ResidentAI.act(3.0, "idle", ResidentAI.op("gplant_seed_put", {"sid": int(s["id"])})))
		sent += 1
	return sent


static func _free_adult(v: Village, p: Vector2, kids_ok := false) -> Resident:
	var best: Resident = null
	var bd := INF
	for r in v.people:
		if r.dead or r.sleeping or r.sick_left > 0.0 or r.injured_left > 0.0 or r.hunger >= 1.0:
			continue
		if not (r.is_adult() or (kids_ok and r.is_child() and r.age >= 5.0)):
			continue
		if not r.action in ["", "idle", "rest", "social", "work", "haul", "build", "play", "wander"] or r.carry != "":
			continue
		var d := Vector2(r.x, r.y).distance_squared_to(p)
		if d < bd:
			bd = d
			best = r
	return best


static func _seed_by_id(ww: WorldWater, id: int) -> Dictionary:
	for s: Dictionary in ww.sf_seeds:
		if int(s["id"]) == id:
			return s
	return {}


static func run_op(v: Village, r: Resident, d: Dictionary) -> void:
	if not v.water is WorldWater:
		return
	var ww := v.water as WorldWater
	match String(d["op"]):
		"gplant_seed_take":
			var s := _seed_by_id(ww, int(d["sid"]))
			if s.is_empty() or s["st"] != "ground":
				r.doing = "빈손으로 돌아오는 중"
				return
			s["st"] = "roll"
			s["roller"] = r.id
			r.carry = "해바라기씨"
			r.carry_amt = float(s["food"])
			r.doing = "해바라기씨를 굴려 오는 중"
		"gplant_seed_put":
			if r.carry == "해바라기씨" and r.carry_amt > 0.0:
				v.stock["해바라기씨"] = float(v.stock.get("해바라기씨", 0.0)) + r.carry_amt
				v.stats["seed_food"] = float(v.stats.get("seed_food", 0.0)) + r.carry_amt
				v.emit(&"seed_stored", {"v": {"amt": r.carry_amt}, "who": r.id, "at": Vector2(r.x, r.y)})
				if not v.stats.has("seed_first"):
					v.stats["seed_first"] = v.t
					v.log_line(SEED_LINE)
			ww.sf_seeds = ww.sf_seeds.filter(func(s: Dictionary) -> bool: return int(s["id"]) != int(d["sid"]))
			if r.carry == "해바라기씨":
				r.carry = ""
				r.carry_amt = 0.0
		"gplant_boll_take":
			var b := _bush_by_id(ww, int(d["bid"]))
			if b.is_empty() or not b.get("boll", false):
				r.doing = "빈손으로 돌아오는 중"
				return
			b["boll"] = false
			r.carry = "솜"
			r.carry_amt = Balance.COTTON_BOLL
			r.doing = "솜뭉치를 굴려 오는 중"
		"gplant_boll_put":
			if r.carry == "솜" and r.carry_amt > 0.0:
				v.stock["솜"] = float(v.stock.get("솜", 0.0)) + r.carry_amt
				v.stats["cotton_got"] = float(v.stats.get("cotton_got", 0.0)) + r.carry_amt
				if not v.stats.has("cotton_first"):        # 민들레 솜과 따로 첫 줄 (경우 5)
					v.stats["cotton_first"] = v.t
					v.log_line(COTTON_LINE)
			if r.carry == "솜":
				r.carry = ""
				r.carry_amt = 0.0
		_:
			push_error("GiantPlants.run_op: 모르는 할 일 %s" % d["op"])


# ───────────────────────── 목화 (R4 · F3) ─────────────────────────
static func _bush_by_id(ww: WorldWater, id: int) -> Dictionary:
	for b: Dictionary in ww.cotton:
		if int(b["id"]) == id:
			return b
	return {}


static func bushes_of(ww: WorldWater, sid: int) -> Array:
	return ww.cotton.filter(func(b: Dictionary) -> bool: return int(b["sid"]) == sid)


## 시간마다 p = COTTON_DAY / 24 — 꽃숲 가장자리의 볕 들고 촉촉한 자리에 덤불 하나 (무리마다 COTTON_MAX까지)
static func _cotton_spawn(v: Village, ww: WorldWater) -> void:
	if bushes_of(ww, v.sid).size() >= Balance.COTTON_MAX or v.trees.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = ww.seed_v * 331 + int(v.t / Balance.HOUR) * 17 + v.sid * 7919
	if rng.randf() >= Balance.COTTON_DAY / 24.0:
		return
	for k in 8:
		var tr: Dictionary = v.trees[rng.randi() % v.trees.size()]
		if tr["s"] != "tree":
			continue
		var a := rng.randf() * TAU
		var p := Vector2(float(tr["x"]), float(tr["y"])) + Vector2(cos(a), sin(a)) * rng.randf_range(1.6, 3.0)
		if not cotton_spot_ok(v, ww, p):
			continue
		ww.cotton_serial += 1
		ww.cotton.append({"id": ww.cotton_serial, "sid": v.sid, "x": p.x, "y": p.y, "boll": false, "yr": -1, "yaw": rng.randf() * TAU})
		return


static func cotton_spot_ok(v: Village, ww: WorldWater, p: Vector2) -> bool:
	if not ww.inside(p.x, p.y, 3.0):
		return false
	var k := ww.idx(p.x, p.y)
	if ww.depth(k) > 0.002 or ww.sun_at(p.x, p.y) < 0.0 or ww.wet_k(k) < Balance.COTTON_WET:
		return false
	for t: Dictionary in v.trees:
		if Vector2(float(t["x"]), float(t["y"])).distance_squared_to(p) < 1.0:
			return false
	for b: Dictionary in ww.cotton:
		if Vector2(b["x"], b["y"]).distance_squared_to(p) < 4.0:
			return false
	return v.is_free(p.x, p.y, 0.6)


## 9~11월: 덤불마다 그 해 한 번 다래가 터짐 (그 해 첫 터짐에 cotton_burst) · 12월이면 거두지 않은 다래는 시듦
static func _cotton_season(v: Village, ww: WorldWater, date: Dictionary) -> void:
	var month := int(date["month"])
	var yr := int(date["year"])
	if not month in Balance.COTTON_MONTHS:
		for b: Dictionary in ww.cotton:
			b["boll"] = false
		return
	var n := 0
	for b: Dictionary in ww.cotton:
		if int(b.get("yr", -1)) != yr:
			b["yr"] = yr
			b["boll"] = true
			n += 1
	if n > 0 and ww.cotton_year != yr:
		ww.cotton_year = yr
		v.emit(&"cotton_burst", {"v": {"n": n}, "who": -1, "at": null})


## 다래가 터진 자기 덤불로 한가한 사람(어른·큰 아이) 하나씩
static func boll_fetch(v: Village) -> int:
	if not v.water is WorldWater:
		return 0
	var ww := v.water as WorldWater
	var sent := 0
	for b: Dictionary in ww.cotton:
		if int(b["sid"]) != v.sid or not b.get("boll", false) or v.t < float(b.get("claim_until", -1.0)):
			continue
		var at := Vector2(b["x"], b["y"])
		var r := _free_adult(v, at, true)
		if r == null:
			break
		b["claim_until"] = v.t + 0.5 * Balance.DAY
		var st := v.store()
		var home := Vector2(st.x, st.y) if st != null else v.center
		ResidentAI.cancel(v, r)
		r.action = "haul"
		r.last_action = "haul"
		r.doing = "솜뭉치를 거두러 가는 중"
		r.steps.append(ResidentAI.walk(at.x + 0.9, at.y + 0.3))
		r.steps.append(ResidentAI.act(15.0, "work", ResidentAI.op("gplant_boll_take", {"bid": int(b["id"])})))
		r.steps.append(ResidentAI.walk(home.x + 1.0, home.y - 0.8))
		r.steps.append(ResidentAI.act(3.0, "idle", ResidentAI.op("gplant_boll_put")))
		sent += 1
	return sent
