## 부락 시뮬레이션 — 주민·건물·물자·믿음·시대·자율 건설 (RESIDENT_AI.md, 기획서 7·8장, 밸런스 v2).
## 화면과 분리된 순수 로직 (Node 없음). 물·소금·습기는 sim/jar_water.gd(JarWater)를 같이 돌린다.
## 수치는 data/balance.gd. 난수는 시드 하나(RandomNumberGenerator) → 같은 시드면 같은 결과.
## 좌표는 JarWater와 같다 (x 동서, y 남북 / Godot 3D에서는 x, z).
## 원본: prototype/app.html (step·lifeEvents·autoBuild·assignHomes…), 고친 규칙은 RESIDENT_AI.md 9장 · BALANCE.md 0장.
class_name Village
extends RefCounted

const DAY := Balance.DAY
const HOUR := Balance.HOUR
const R := JarWater.R
const PATH_N := 128

var rng := RandomNumberGenerator.new()
var gene_rng := RandomNumberGenerator.new()   # 7단계: 겉모습 유전자·혈통 유전 전용 (시뮬레이션 난수 순서를 바꾸지 않게)
var health_rng := RandomNumberGenerator.new() # 건강·기후·두려움 전용 (HEALTH.md 7 — 유전·기존 흐름을 흔들지 않게)
# 병 날짜 (HEALTH.md 1.1): 세상을 만든 현실 날짜. 테스트는 Village.default_created로 고정 (비면 기기 날짜)
static var default_created: Dictionary = {}
var created_date: Dictionary = {"year": 2026, "month": 4, "day": 15}
var climate_override := ""            # 비면 물(병)의 기후대
var cold_season := false              # 앞으로 반나절 안에 추위가 온다 (땔감 운반·나무꾼 넉넉함 — 정시마다)
var sick_share := 0.0                 # 앓는 사람 비율
var warnings: Array = []              # 말풍선·편지로 띄울 위기 예고 {t, kind, text} (화면이 가져감)
var _health_acc := 0.0
var _health_hour := 0
var _sick_warn_day := -1
var _taps := [-1, 0]                  # [날, 그날 톡 횟수]
var _rots := [-1, 0]                  # [날, 그날 돌리기 횟수]
var _singers: Array = []              # 노래꾼 혈통 주민 (life_events마다 다시)
var _festival_mult := 1.0             # 마을에 노래꾼이 있으면 축제 효과 ×1.2
var water: JarWater                   # 소형 병(JarWater) 또는 넓은 세상(WorldWater — JarWater를 잇는다)
# 6단계 — 넓은 세상: 마을은 세상 좌표의 한 자리(center)에 있다. 소형 병은 (0, 0)
var center := Vector2.ZERO            # 마을 중심 (창고 자리)
var sid := 0                          # 무리 번호 (키트마다 하나 — 안개·만남)
var settlement_name := ""
var owns_water := true                # 이 마을이 물을 흘린다 (한 세상에 하나 — 나머지 무리는 others로 함께 걷는다)
var others: Array = []                # 같은 세상의 다른 무리 (Village) — 이 마을의 걸음에 맞춰 함께 걷는다
var explore_on := false               # [탐험] — 넓은 세상에서만 (소형 병 결과를 바꾸지 않게)
var path_r := R                       # 오솔길 격자가 덮는 반지름 (center 기준)
var path_n := PATH_N
var view_r := R                       # 화면이 소품을 까는 반지름 (center 기준)
var met: Dictionary = {}              # 만난 무리 sid → t
var _walker: Resident = null          # 지금 걷는 주민 (안개 걷기·발견 기록용)
var t := 0.0
var start_clock := Balance.START_CLOCK
var step_dt := Balance.STEP

# 거인
var watching := true                  # 거인이 지켜보는가 (앱 켜짐). watch_hours가 있으면 그 시각만
var watch_hours: Array = []           # 예: [20, 21] — sim_life.py처럼 하루 2시간만 지켜봄
var auto_build := true                # [주민 자율 건설] (기본 켜짐)
var auto_reveal := false              # 시대 점수가 차면 지켜보는 때에 계시 (테스트용: 거인이 바로 승인한다고 가정)

var era := 0
var era_pts := 0.0
var faith := 50.0
var fear := 0.0
var stock: Dictionary = {}
var manna: Array = []                 # 들판의 낟알 {x, y, amt, born, res}
var manna_batches: Array = []         # 창고에 주워 온 낟알 {amt, born}
var manna_falls := 0
var first_harvest_t := -1.0
var manna_ended := false
var festival_t := -1.0e9
var _last_dawn := -1
var _arrival_manna := false
var trees: Array = []                 # {x, y, s: "tree"/"stump"/"sapling", g, res}
var rocks: Array = []                 # {x, y, amt, res}
var buildings: Array[Building] = []
var people: Array[Resident] = []      # 살아 있는 주민
var dead: Array[Resident] = []
var fire := Vector2(2.2, 1.6)
var next_id := 1
var book: Array = []                  # 연대기 {t, text}
var paths := PackedFloat32Array()     # 오솔길 128×128
var deficit := 0.0
var last_short_t := -1.0e9            # 마지막으로 식량이 모자랐던 때
var salt_known := false
var crises: Array = []                # 위기가 시작됨 {t, kind, text} — JarClock이 가져가 ×1로 되돌리고 알림 (기획서 6.6)
var stats := {"born": 0, "died": 0, "built": 0, "starved": 0, "marriages": 0, "moves": 0, "upgrades": 0}
var birth_log: Array = []             # 테스트용: 출생 때 집 정원 {t, home, occ_before, cap}
var violations: Array = []            # 테스트용: 규칙 위반 기록
var basins_said: Array = []
var _starve_day := -1
var _timers := {"life": 0.0, "jobs": 0.0, "chief": 0.0, "lake": 0.0, "decay": 0.0, "speak": 0.0}
var _people_by_id: Dictionary = {}
var _bld_by_id: Dictionary = {}


# ───────────────────────── 처음 세계 ─────────────────────────
static func new_prototype(seed_v: int = 20261105) -> Village:
	var v := Village.new()
	v._init_prototype(seed_v)
	return v


func _init_prototype(seed_v: int) -> void:
	rng.seed = seed_v
	gene_rng.seed = seed_v * 7919 + 101
	_init_health(seed_v)
	water = JarWater.new_prototype_world()
	water.start_clock = start_clock
	water.t = 0.0
	stock = Balance.START_STOCK.duplicate()
	paths.resize(PATH_N * PATH_N)
	paths.fill(0.0)
	# 숲 다섯 군데 · 바위 · (호수는 물 시뮬레이션)
	for g: Vector2 in [Vector2(-12, 14), Vector2(-20, 4), Vector2(18, -6), Vector2(22, 12), Vector2(4, 22)]:
		for i in 24:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 6.5
			var x := g.x + cos(a) * d
			var y := g.y + sin(a) * d * 0.9
			if Vector2(x, y).length() < R - 1.5 and water.w[JarWater.cell_idx(x, y)] < 0.005:
				trees.append({"x": x, "y": y, "s": "tree", "g": 0.0, "res": 0})
	for p: Vector2 in [Vector2(-6, -18), Vector2(-3, -20), Vector2(4, 20), Vector2(7, 19), Vector2(-24, -2), Vector2(24, -10)]:
		rocks.append({"x": p.x, "y": p.y, "amt": 20, "res": 0})
	for b: Dictionary in water.basins:
		basins_said.append(0)
	var st := add_building("창고", 0.0, 0.0, true)
	st.is_store = true
	# 첫 정착민 두 가족 + 노인 + 젊은이
	var ids: Array[Resident] = []
	for f: Array in Balance.FIRST_SETTLERS:
		var r := add_person(f[0], f[1], f[2], f[3], fire.x + (rng.randf() - 0.5) * 3.0, fire.y + (rng.randf() - 0.5) * 3.0, null, null)
		ids.append(r)
	marry(ids[0], ids[1])
	for k in [2, 3]:
		ids[k].parents = PackedInt32Array([ids[0].id, ids[1].id])
	marry(ids[4], ids[5])
	ids[6].parents = PackedInt32Array([ids[4].id, ids[5].id])
	# 아이는 부모를 닮는다
	for k in [2, 3]:
		_inherit_look(ids[k], ids[0], ids[1])
	_inherit_look(ids[6], ids[4], ids[5])
	for r in ids:                     # 첫 정착민은 혈통 없음 (기본 키트 — BLOODLINES 5장)
		set_blood(r, PackedStringArray())
	stats["marriages"] = 0
	# 10명 중 최소 1명은 '재능' 이상 (OPENING 단계 8)
	if people.all(func(p: Resident) -> bool: return p.grade == 0):
		ids[4].grade = 1
	log_line("어느 새벽, 우리 조상 열 명이 숲 가장자리에 처음으로 불을 피웠다.")
	log_line("하늘의 두 점에서 거대한 물방울이 똑, 똑 떨어진다. 그 아래 호수는 마르지 않는다. 강은 그늘진 세상 끝 벽에서 흘러내려 낮은 곳으로 간다. 서쪽의 큰 호수에는 흘러드는 강이 없다.")


func _init_health(seed_v: int) -> void:
	health_rng.seed = seed_v * 104729 + 7
	if not default_created.is_empty():
		created_date = {"year": int(default_created["year"]), "month": int(default_created["month"]), "day": int(default_created["day"])}
	else:
		var d := Time.get_date_dict_from_system()
		created_date = {"year": int(d["year"]), "month": int(d["month"]), "day": int(d["day"])}
	_health_hour = 0


func add_building(type: String, x: float, y: float, built: bool) -> Building:
	var b := Building.new()
	b.id = next_id
	next_id += 1
	b.type = type
	b.x = x
	b.y = y
	b.built = built
	if built:
		b.prog = float(b.def()["time"])
		b.built_t = t
		if type == "농장":
			b.ready_at = t + Balance.GROW_FIRST
	buildings.append(b)
	_bld_by_id[b.id] = b
	return b


func add_person(name: String, sex: String, age: float, trait_n: String, x: float, y: float, mom: Resident, dad: Resident) -> Resident:
	var r := Resident.new()
	r.id = next_id
	next_id += 1
	r.name = name
	r.sex = sex
	r.age = age
	r.born_t = t - age * DAY
	var tr: Array = Balance.TRAITS[rng.randi() % Balance.TRAITS.size()]
	if trait_n != "":
		for q: Array in Balance.TRAITS:
			if q[0] == trait_n:
				tr = q
	r.trait_name = tr[0]
	r.trait_desc = tr[1]
	r.work_mult = tr[2]
	r.trait_mod = tr[3]
	r.fert = _triangular(Balance.FERT_LO, Balance.FERT_HI, 1.0)
	r.talent = _triangular(Balance.TALENT_LO, Balance.TALENT_HI, 1.0)
	r.grade = _roll_grade()
	r.x = x
	r.y = y
	r.px = x
	r.py = y
	r.belief = Balance.BELIEF_START if age > 0.0 else (Balance.BELIEF_BABY_WATCHED if is_watching() else Balance.BELIEF_BABY_ALONE)
	# 겉모습
	r.look_head = rng.randi() % Balance.LOOK_HEADS
	r.look_clothes = 1 if sex == "f" else 0
	if rng.randf() < 0.25:
		r.look_clothes = 1 - r.look_clothes
	r.look_hat = rng.randi() % Balance.LOOK_HATS
	r.look_hair = rng.randi() % Balance.HAIR_COLORS.size()
	r.look_skin = rng.randi() % Balance.SKIN_COLORS.size()
	r.look_cloth = rng.randi() % Balance.CLOTH_COLORS.size()
	r.genes = Genetics.random_genes(gene_rng)
	if mom != null and dad != null:
		_inherit_look(r, mom, dad)
	# 처음 정착민의 숙련: 성인이 된 뒤 일한 날만큼 (sim_life.py와 같은 가정)
	if age > Balance.AGE_ADULT:
		r.skills["일꾼"] = minf(Balance.SKILL_MAX, Balance.SKILL_RATE * r.talent * (minf(age, Balance.AGE_ELDER) - Balance.AGE_ADULT))
	people.append(r)
	_people_by_id[r.id] = r
	return r


func _inherit_look(r: Resident, a: Resident, b: Resident) -> void:
	r.look_hair = (a if rng.randf() < 0.5 else b).look_hair
	r.look_skin = (a if rng.randf() < 0.5 else b).look_skin
	r.look_head = (a if rng.randf() < 0.5 else b).look_head if rng.randf() < 0.7 else rng.randi() % Balance.LOOK_HEADS
	# 7단계: 겉모습 유전자 + 혈통 (BLOODLINES 7장·1장) — gene_rng만 씀
	r.genes = Genetics.inherit(gene_rng, a.genes, b.genes)
	var pb := a.blood.duplicate()
	for id in b.blood:
		if not id in pb:
			pb.append(id)
	r.parent_blood = pb
	r.parent_blood_sex = {}
	for q: Resident in ([a, b] if b != a else [a]):
		for id in q.blood:
			if not r.parent_blood_sex.has(id):
				r.parent_blood_sex[id] = q.sex
	var grand := a.parent_blood.duplicate()
	grand.append_array(b.parent_blood)
	set_blood(r, Bloodlines.inherit(gene_rng, a.blood, b.blood if b != a else PackedStringArray(), grand))
	# 혈통이 어디서 왔나 (화면용 — 난수를 쓰지 않는다). 부모 둘 다 가졌으면 아이 번호로 번갈아
	r.blood_src = {}
	for id in r.blood:
		var in_a := id in a.blood
		var in_b := b != a and id in b.blood
		if in_a or in_b:
			var who: Resident = a if (in_a and (not in_b or r.id % 2 == 0)) else b
			r.blood_src[id] = "mother" if who.sex == "f" else "father"
		elif a.parent_blood_sex.has(id) or b.parent_blood_sex.has(id):
			var sx: String = a.parent_blood_sex.get(id, b.parent_blood_sex.get(id, "m"))
			r.blood_src[id] = "grandmother" if sx == "f" else "grandfather"
		else:
			r.blood_src[id] = "new"


## 혈통을 정한다 — 효과(fx)와, '다산'·'난산'이면 타고난 출산 배율. src = 모두 같은 출처 ("kit"·"migrant"…, 비면 그대로)
func set_blood(r: Resident, b: PackedStringArray, src := "") -> void:
	r.set_blood(b)
	if src != "":
		r.blood_src = {}
		for id in b:
			r.blood_src[id] = src
	var fr: Variant = r.fx.get("fert")
	if fr is Array:
		r.fert = gene_rng.randf_range(float(fr[0]), float(fr[1]))


func _triangular(lo: float, hi: float, mode: float) -> float:
	var u := rng.randf()
	var c := (mode - lo) / (hi - lo)
	if u < c:
		return lo + sqrt(u * (hi - lo) * (mode - lo))
	return hi - sqrt((1.0 - u) * (hi - lo) * (hi - mode))


func _roll_grade() -> int:
	var u := rng.randf()
	for g in range(Balance.GRADE_P.size() - 1, 0, -1):
		if u < Balance.GRADE_P[g]:
			return g
		u -= Balance.GRADE_P[g]
	return 0


func marry(a: Resident, b: Resident) -> void:
	a.partner = b.id
	b.partner = a.id
	stats["marriages"] += 1


func person(id: int) -> Resident:
	return _people_by_id.get(id, null)


func bld(id: int) -> Building:
	return _bld_by_id.get(id, null)


func store() -> Building:
	for b in buildings:
		if b.is_store and b.built:
			return b
	return buildings[0]


# ───────────────────────── 시간 ─────────────────────────
func clock() -> float:
	return fmod(start_clock + t, DAY)


func hour_now() -> float:
	return clock() / HOUR


func day_no() -> int:
	## N일차 — 도착한 순간부터 24시간마다 (1부터)
	return int(t / DAY) + 1


func is_night() -> bool:
	var h := hour_now()
	return h >= Balance.NIGHT_FROM or h < Balance.NIGHT_TO


func is_work_time() -> bool:
	var h := hour_now()
	return h >= Balance.WORK_FROM and h < Balance.WORK_TO


func is_watching() -> bool:
	if watch_hours.is_empty():
		return watching
	return int(hour_now()) in watch_hours


## 표시용 'N일차 HH:MM' — 달력 날짜 (도착한 날 = 1일차, 자정마다 +1, 프로토타입 fmtTime)
func fmt_time(tt: float) -> String:
	var c := fmod(start_clock + tt, DAY)
	return "%d일차 %02d:%02d" % [cal_day(tt), int(c / HOUR), int(fmod(c, HOUR) / 60.0)]


func cal_day(tt: float) -> int:
	return int((start_clock + tt) / DAY) - int(start_clock / DAY) + 1


# ───────────────────────── 기록 ─────────────────────────
func log_line(text: String) -> void:
	book.append({"t": t, "text": text})


## 위기 시작 (굶주림·재해) — 화면 쪽(JarClock)이 빨리 돌리기를 ×1로 되돌리고 알림을 띄운다
func crisis(kind: String, text: String) -> void:
	crises.append({"t": t, "kind": kind, "text": text})


func speak(r: Resident, text: String, dur := 6.0) -> void:
	r.say = text
	r.say_t = dur


static func josa(w: String, a: String, b: String) -> String:
	if w.is_empty():
		return b
	var c := w.unicode_at(w.length() - 1) - 0xAC00
	return a if (c >= 0 and c < 11172 and c % 28 != 0) else b


# ───────────────────────── 땅·물·기후 (JarWater) ─────────────────────────
func wetness(x: float, y: float) -> float:
	return clampf(0.12 + water.wet_k(water.idx(x, y)) * 0.9 - 0.1 * water.sun_at(x, y), 0.0, 1.0)


func salt_at(x: float, y: float) -> float:
	return water.salt_k(water.idx(x, y))


## 농사 효율 = 따뜻함 × 습기 ÷ (1 + 소금기) — 기획서 4.4, 프로토타입 farmMult
func farm_mult(x: float, y: float) -> float:
	var w := water.warm_at(x, y)
	var m := wetness(x, y)
	return clampf((0.6 + 0.6 * w) * (0.65 + 0.7 * m) / (1.0 + salt_at(x, y) * 300.0), 0.15, 1.5)


func water_at(x: float, y: float) -> bool:
	var k := water.idx(x, y)
	return water.is_lake(k) or water.is_river(k)


## 품을 수 있는 인구 = 대지 넓이 × 0.5 ÷ 1인당 땅 (기획서 3.1)
func land_capacity() -> float:
	return PI * R * R * Balance.LAND_USABLE / Balance.LAND_PER_PERSON[mini(era, 3)]


# ───────────────────────── 식량 ─────────────────────────
func food_total() -> float:
	var n := 0.0
	for k in Balance.FOODS:
		n += float(stock[k])
	for m: Dictionary in manna_batches:
		n += float(m["amt"])
	for m: Dictionary in manna:
		n += float(m["amt"])
	for b in buildings:
		n += float(b.out.get("밀", 0.0)) + float(b.out.get("빵", 0.0))
	return n


func food_types() -> int:
	var n := 0
	for k in Balance.FOODS:
		if float(stock[k]) >= 1.0:
			n += 1
	if not manna_batches.is_empty() or not manna.is_empty():
		n += 1
	return n


## 식량을 먹는다. 남은 못 먹은 양을 돌려준다. 낟알(상하기 전) → 들판 낟알 → 건량 → 빵 → 밀(죽)
## 식량을 먹는 사람 수 (혈통 '소식' ×0.85 · '대식가' ×1.2 — 혈통이 없으면 인구 그대로)
func _food_people() -> float:
	var n := 0.0
	for p in people:
		n += p.f("food")
	return n


func consume(need: float) -> float:
	if float(stock["소금"]) > 0.0:
		stock["소금"] = maxf(0.0, float(stock["소금"]) - need / 400.0)
		need *= Balance.SALT_SAVING
	for m: Dictionary in manna_batches:
		var take := minf(m["amt"], need)
		m["amt"] -= take
		need -= take
		if need <= 0.0:
			break
	if need > 0.0:
		for m: Dictionary in manna:
			var take := minf(m["amt"], need)
			m["amt"] -= take
			need -= take
			if need <= 0.0:
				break
	for k: String in Balance.FOODS:
		if need <= 0.0:
			break
		var take := minf(float(stock[k]), need)
		stock[k] = float(stock[k]) - take
		need -= take
		if need > 0.0 and (k == "빵" or k == "밀"):
			for b in buildings:
				if need <= 0.0:
					break
				var t2 := minf(float(b.out.get(k, 0.0)), need)
				if t2 > 0.0:
					b.out[k] = float(b.out[k]) - t2
					need -= t2
	manna_batches = manna_batches.filter(func(m: Dictionary) -> bool: return m["amt"] > 0.001)
	return maxf(0.0, need)


## 하늘 낟알 — 도착 직후 1회, 첫 수확 전까지 매일 새벽 하루치 (기획서 8.4)
func manna_fall(reason: String) -> void:
	var amt := people.size() * DAY / Balance.FOOD_IV
	var s := store()
	for i in Balance.MANNA_PILES:
		var a := rng.randf() * TAU
		var d := 5.0 + rng.randf() * 9.0
		var x := s.x + cos(a) * d
		var y := s.y + sin(a) * d
		if water_at(x, y):
			x = s.x + cos(a) * 4.0
			y = s.y + sin(a) * 4.0
		manna.append({"x": x, "y": y, "amt": amt / Balance.MANNA_PILES, "born": t, "res": 0})
	manna_falls += 1
	bless_all(Balance.BELIEF_MANNA)
	var kids := people.filter(func(p: Resident) -> bool: return p.is_child() and not p.is_baby())
	var who: Resident = kids[rng.randi() % kids.size()] if not kids.is_empty() else people[rng.randi() % people.size()]
	if reason == "arrival":
		speak(who, "엄마, 하늘에서 뭐가 내렸어요!", 8)
		log_line("굶주린 조상들에게 거인이 하늘에서 낟알을 내렸다.")
	else:
		speak(who, "거인님의 낟알이다!", 6)
		log_line("새벽, 들판에 하늘의 낟알이 하얗게 깔렸다.")


func harvest_check(r: Resident) -> void:
	if first_harvest_t < 0.0:
		first_harvest_t = t
		log_line("%s%s 들에서 첫 곡식을 거두었다." % [r.name, josa(r.name, "이", "가")])
		speak(r, "첫 곡식이다!", 7)


# ───────────────────────── 메인 걸음 ─────────────────────────
## seconds만큼 시간을 흘린다 (step_dt 조각으로)
func advance(seconds: float) -> void:
	var left := seconds
	while left > 1e-6:
		var dt := minf(step_dt, left)
		left -= dt
		step(dt)


func step(dt: float) -> void:
	for p in people:              # 화면이 걸음 사이를 보간하도록 직전 위치
		p.px = p.x
		p.py = p.y
	t += dt
	if owns_water:
		water.advance(dt)
	if not _arrival_manna and t >= Balance.MANNA_DELAY:
		_arrival_manna = true
		manna_fall("arrival")
	# 새벽 (6시)
	var dawn_idx := floori((start_clock + t - Balance.DAWN_HOUR * HOUR) / DAY)
	if _last_dawn < 0:
		_last_dawn = floori((start_clock - Balance.DAWN_HOUR * HOUR) / DAY)
	if dawn_idx > _last_dawn:
		_last_dawn = dawn_idx
		_on_dawn()
	# 낟알 상함 (하루)
	for m: Dictionary in manna:
		if t - m["born"] >= Balance.MANNA_SPOIL:
			m["amt"] = 0.0
	for m: Dictionary in manna_batches:
		if t - m["born"] >= Balance.MANNA_SPOIL:
			m["amt"] = 0.0
	manna = manna.filter(func(m: Dictionary) -> bool: return m["amt"] > 0.001)
	manna_batches = manna_batches.filter(func(m: Dictionary) -> bool: return m["amt"] > 0.001)
	# 식량 소비 (집계 — 1명당 15분에 1개)
	var need := _food_people() * dt / Balance.FOOD_IV
	var unmet := consume(need)
	deficit = unmet / need if need > 0.0 else 0.0
	if deficit > 0.0:
		if t - last_short_t > HOUR:
			crisis("hunger", "창고에 먹을 것이 떨어졌다")
		last_short_t = t
	for p in people:
		if deficit > 0.0:
			p.hunger = minf(4.0, p.hunger + deficit * dt / Balance.FOOD_IV)
		else:
			p.hunger = maxf(0.0, p.hunger - dt / Balance.FOOD_IV)
		if p.hunger >= Balance.STARVING_AT:
			p.health -= dt / Balance.STARVE_HEALTH_TIME
			p.harm["굶주림"] = float(p.harm.get("굶주림", 0.0)) + dt / Balance.STARVE_HEALTH_TIME
			if p.is_child() and not p.stunted and p.genes.size() >= Genetics.GENE_BYTES:     # 어릴 때 굶주리면 키 −0.05 (겉모습만)
				p.stunted = true
				p.genes[Genetics.HEIGHT] = maxi(0, p.genes[Genetics.HEIGHT] - roundi(Genetics.STUNT * 255.0))
		elif Health.can_heal(p):         # 앓는 중·추위·더위 속에서는 저절로 낫지 않는다 (HEALTH.md 1.4 · 2)
			p.health = minf(1.0, p.health + dt * p.f("heal") / Balance.HEAL_TIME)
		p.age += dt / DAY
		if p.say_t > 0.0:
			p.say_t -= dt
	Health.step(self, dt)
	for b in buildings:
		_update_building(b, dt)
	for p in people.duplicate():
		_walker = p
		ResidentAI.update(self, p, dt)
	_walker = null
	for tr: Dictionary in trees:
		if tr["s"] != "tree":
			tr["g"] -= dt
			if tr["g"] <= 0.0:
				tr["s"] = "tree"
	# 주기 처리
	for k in _timers:
		_timers[k] += dt
	if _timers["life"] >= Balance.LIFE_EVERY:
		life_events(_timers["life"])
		_timers["life"] = 0.0
		trees = trees.filter(func(tr: Dictionary) -> bool: return water.depth(water.idx(tr["x"], tr["y"])) < 0.03)   # 물에 잠긴 나무는 죽는다
	if _timers["jobs"] >= Balance.JOBS_EVERY:
		assign_jobs()
		assign_homes()
		_timers["jobs"] = 0.0
	if _timers["chief"] >= Balance.CHIEF_EVERY:
		if auto_build or not is_watching():
			chief_build()
		_timers["chief"] = 0.0
	if _timers["lake"] >= Balance.LAKE_EVERY:
		_timers["lake"] = 0.0
		lake_watch()
		salt_discovery()
	if _timers["decay"] >= HOUR:      # 오솔길은 다니지 않으면 옅어진다 (1분에 ×0.997)
		var f := pow(0.997, _timers["decay"] / 60.0)
		for i in paths.size():
			if paths[i] > 0.0:
				paths[i] *= f
		_timers["decay"] = 0.0
	if _timers["speak"] >= Balance.SPEAK_EVERY:
		idle_chatter()
		_timers["speak"] = 0.0
	_update_era(dt)
	_update_belief(dt)
	for o: Village in others:        # 같은 세상의 다른 무리 (물은 이 마을이 이미 흘렸다)
		o.step(dt)


func _on_dawn() -> void:
	if first_harvest_t < 0.0:
		manna_fall("dawn")
	elif not manna_ended:
		manna_ended = true
		festival_t = t
		log_line("들에서 첫 곡식을 거둔 다음 날, 하늘의 낟알이 그쳤다. 이제 우리는 우리 손으로 먹고산다.")
		log_line("첫 수확 축제가 열렸다. 모두 모닥불 둘레에서 밤늦게까지 춤을 추었다.")
	# 일한 날 → 숙련 (기획서 11장: 하루 0.6 × 재주, 최대 10)
	for p in people:
		if p.work_secs_today >= Balance.WORKED_DAY_SECS and p.is_adult():
			var key := "일꾼"
			var jb := bld(p.job)
			if jb != null:
				key = jb.type
			p.skills[key] = minf(Balance.SKILL_MAX, float(p.skills.get(key, 0.0)) + Balance.SKILL_RATE * p.talent * p.f("skill_growth"))
		p.work_secs_today = 0.0
	_update_happiness()


func _update_era(dt: float) -> void:
	if era >= Balance.ERA_NEED.size():
		return
	var built_n := 0
	for b in buildings:
		if b.built:
			built_n += 1
	var rate: float = (people.size() * Balance.ERA_POP + built_n * Balance.ERA_BUILDING) * Balance.ERA_MULT[era]
	if not is_watching():
		rate *= Balance.OFFLINE_ERA
	era_pts = minf(Balance.ERA_NEED[era], era_pts + rate * dt / HOUR)
	if auto_reveal and is_watching() and era_pts >= Balance.ERA_NEED[era]:
		reveal()


## 거인의 계시 — 시대 점수가 다 찼을 때만 (6.3)
func reveal() -> bool:
	if era >= Balance.ERA_NEED.size() or era_pts < Balance.ERA_NEED[era]:
		return false
	era += 1
	era_pts = 0.0
	bless_all(0.15)
	log_line("거인님의 계시가 내렸다. 우리는 '%s'%s 되었다." % [Balance.ERAS[era], josa(Balance.ERAS[era], "이", "가")])
	return true


func _update_belief(dt: float) -> void:
	var w := is_watching()
	var sum := 0.0
	for p in people:
		if w:
			p.belief += dt * p.f("belief_up") / (DAY * Balance.BELIEF_UP_DAYS)
		else:
			p.belief -= dt * p.f("belief_down") / (DAY * (Balance.BELIEF_DOWN_CHILD_DAYS if p.is_child() else Balance.BELIEF_DOWN_ADULT_DAYS))
		p.belief = clampf(p.belief, 0.0, 1.0)
		sum += p.belief
	faith = sum / people.size() * 100.0 if not people.is_empty() else 0.0
	# 부락의 두려움(0~100) = 주민 두려움 평균 × 100 — sim/health.gd가 사람마다 내린다 (HEALTH.md 4)


func bless_all(d: float) -> void:
	for p in people:
		p.belief = minf(1.0, p.belief + d)


## 부락의 신앙 상태 (RESIDENT_AI 2.3)
func faith_state() -> String:
	if fear >= 50.0:
		return "경외" if faith >= 60.0 else "공포"
	if faith >= 60.0:
		return "경건"
	if faith < 30.0:
		return "무관심"
	return ""


func doubters() -> int:
	var n := 0
	for p in people:
		if p.belief < Balance.DOUBT_BELOW and p.age >= 2.5:
			n += 1
	return n


func _update_happiness() -> void:
	var variety := food_types() >= 3
	var fest := t - festival_t < Balance.FESTIVAL_DAYS * DAY
	var cheer := {}               # 집 → 그 집 '명랑' 식구 몫의 합
	for p in people:
		var hh := p.f("house_happy", 0.0)
		if hh != 0.0 and p.home >= 0:
			cheer[p.home] = float(cheer.get(p.home, 0.0)) + hh
	for p in people:
		var h := Balance.HAPPY_BASE
		h += Balance.HAPPY_HOME if p.home >= 0 else Balance.HAPPY_NO_HOME
		if variety:
			h += Balance.HAPPY_VARIETY
		if p.hunger > 0.5:
			h += Balance.HAPPY_HUNGRY
		if fest:
			h += Balance.HAPPY_FESTIVAL * _festival_mult * p.f("festival")
		if t < p.grief_until:
			h += Balance.HAPPY_GRIEF
		h += p.f("happiness", 0.0)
		h += Balance.FEAR_HAPPY * p.fear                  # 행복 −0.1 × 두려움 (HEALTH.md 4)
		if p.home >= 0 and not cheer.is_empty():
			h += float(cheer.get(p.home, 0.0)) - p.f("house_happy", 0.0)      # 같은 집 식구의 '명랑' (자기 몫은 빼고)
		p.happiness = clampf(h, 0.0, 1.0)


func avg_happiness() -> float:
	if people.is_empty():
		return 0.0
	var s := 0.0
	for p in people:
		s += p.happiness
	return s / people.size()


## 출산 환경 배율 = 식량 × 행복 × 축제 (기획서 7.3 — 이 셋만)
func birth_env() -> float:
	var f: float = Balance.ENV_FOOD[1]
	if t - last_short_t < Balance.STARVED_RECENT:
		f = Balance.ENV_FOOD[0]
	elif food_types() >= 3:
		f = Balance.ENV_FOOD[2]
	var hp := avg_happiness()
	var h: float = Balance.ENV_HAPPY[0] if hp < Balance.HAPPY_LOW else (Balance.ENV_HAPPY[2] if hp > Balance.HAPPY_HIGH else Balance.ENV_HAPPY[1])
	var fe := Balance.ENV_FESTIVAL if t - festival_t < Balance.FESTIVAL_DAYS * DAY else 1.0
	return f * h * fe


# ───────────────────────── 건물 ─────────────────────────
func _update_building(b: Building, dt: float) -> void:
	if not b.built:
		return
	var d := b.def()
	if b.type == "농장" and b.ready_at < 0.0:
		b.ready_at = t + Balance.GROW_FIRST
	# 생산·가공: 일꾼이 배정돼 있으면 밤에도 돌아간다 (RESIDENT_AI 9장). 채집형만 일꾼이 직접 걸어가서 일함
	if not d.get("job", false) or not d.has("out") or d.get("gather", false) or b.worker < 0:
		return
	var w := person(b.worker)
	if w != null and w.sick_left > 0.0:
		return                        # 일꾼이 앓아누우면 일터가 쉰다 (HEALTH.md 2)
	if b.type == "소금밭":
		_update_salt_works(b, dt, w)
		return
	if b.type == "농장" and t < b.ready_at:
		return
	var outs: Dictionary = d["out"]
	var all_full := true
	for k in outs:
		if not (Balance.ENOUGH.has(k) and float(stock.get(k, 0.0)) + float(b.out.get(k, 0.0)) >= Balance.ENOUGH[k]):
			all_full = false
	if all_full:
		return
	var ins: Dictionary = d.get("in", {})
	if not _inputs_ready(b, ins):
		return
	var place := 1.0
	if b.type == "농장":
		if b.farm_mult < 0.0:
			b.farm_mult = farm_mult(b.x, b.y)
		place = b.farm_mult
	b.timer += dt * (w.job_speed(b.type) if w != null else 1.0) * place * _singer_aura(b, w)
	var cyc: float = d["cycle"]
	while b.timer >= cyc:
		b.timer -= cyc
		if not _inputs_ready(b, ins):
			b.timer = 0.0
			break
		for k in ins:
			b.in_buf[k] = float(b.in_buf[k]) - float(ins[k])
		for k in outs:
			b.out[k] = float(b.out.get(k, 0.0)) + float(outs[k])
		if b.type == "농장" and w != null:
			harvest_check(w)


## '노래꾼'이 근처에서 일하고 있으면 그 일터 +3% (자기 일터 포함, 본인 제외)
func _singer_aura(b: Building, w: Resident) -> float:
	if _singers.is_empty():
		return 1.0
	for s: Resident in _singers:
		if s != w and not s.dead and s.action == "work" and Vector2(s.x - b.x, s.y - b.y).length() < Bloodlines.SINGER_RANGE:
			return 1.0 + s.f("work_aura", 0.0)
	return 1.0


func _inputs_ready(b: Building, ins: Dictionary) -> bool:
	for k in ins:
		if float(b.in_buf.get(k, 0.0)) < float(ins[k]):
			return false
	return true


func _update_salt_works(b: Building, dt: float, w: Resident) -> void:
	if float(stock["소금"]) + float(b.out.get("소금", 0.0)) >= Balance.ENOUGH["소금"]:
		return
	b.timer += dt
	if b.timer < float(b.def()["cycle"]):
		return
	b.timer = 0.0
	var got := 0.0
	for k in water.cells_near(Vector2(b.x, b.y), 3.5):
		if got >= 0.0005:
			break
		if water.depth(k) < 0.004 and water.salt_k(k) > 0.0004:
			var tk := minf(water.salt_k(k), 0.0005 - got)
			water.take_salt(k, tk)
			got += tk
	if got >= 0.00045:
		b.out["소금"] = float(b.out.get("소금", 0.0)) + 1.0
		if stats.get("first_salt", 0) == 0:
			stats["first_salt"] = 1
			var nm := w.name if w != null else "누군가"
			log_line("%s%s 마른 호수 바닥에서 흰 소금을 긁어 모았다. 소금에 절인 생선은 겨울을 난다." % [nm, josa(nm, "이", "가")])


func on_built(b: Building) -> void:
	stats["built"] += 1
	reveal_building(b)
	b.built_t = t
	if b.upgrade_to != "":
		b.type = b.upgrade_to
		b.upgrade_to = ""
		stats["upgrades"] += 1
		log_line("작은 옛 집을 %s%s 넓혀 지었다." % [b.type, josa(b.type, "으로", "로")])
		return
	b.built = true
	if b.type == "농장":
		b.ready_at = t + Balance.GROW_FIRST
		log_line("밭을 갈았다. 첫 곡식이 여물려면 반나절은 걸리겠지.")
	elif b.is_house():
		log_line("%s 한 채가 다 지어졌다. 이제 한 가족이 지붕 아래에서 잔다." % b.type)
	else:
		log_line("%s%s 다 지어졌다." % [b.type, josa(b.type, "이", "가")])


# ───────────────────────── 일자리·집 ─────────────────────────
func assign_jobs() -> void:
	for p in people:
		if p.job >= 0 and not p.is_adult():
			var b := bld(p.job)
			if b != null:
				b.worker = -1
			p.job = -1
			stock["도구"] = float(stock["도구"]) + 1.0     # 일을 내려놓으면 도구는 창고로 (정함 — 도구 닳음은 아직 없음)
			if p.is_elder():
				log_line("%s%s 늙어서 일을 내려놓았다." % [p.name, josa(p.name, "은", "는")])
	for b in buildings:
		if not b.built or not b.def().get("job", false):
			continue
		if b.worker >= 0 and person(b.worker) == null:
			b.worker = -1
		if b.worker >= 0:
			continue
		if float(stock["도구"]) < 1.0:
			continue
		# 후보 점수 = 해당 숙련 × 2 − 거리 (RESIDENT_AI 5.1, 특징·현재 직업 숙련은 아직 없음)
		var best: Resident = null
		var bs := -1.0e9
		for p in people:
			if not p.is_adult() or p.job >= 0:
				continue
			var s := float(p.skills.get(b.type, 0.0)) * 2.0 - Vector2(p.x - b.x, p.y - b.y).length() * 0.1
			if s > bs:
				bs = s
				best = p
		if best == null:
			continue
		best.job = b.id
		b.worker = best.id
		stock["도구"] = float(stock["도구"]) - 1.0
		speak(best, "오늘부터 %s 일을 해요" % b.type, 5)


func household_of(p: Resident) -> Array[Resident]:
	## 부부 + 둘의 아직 성인 아닌 아이들
	var ids := {p.id: true}
	if p.partner >= 0:
		ids[p.partner] = true
	var out: Array[Resident] = [p]
	if p.partner >= 0 and person(p.partner) != null:
		out.append(person(p.partner))
	for q in people:
		if q.is_child() and not ids.has(q.id) and q.parents.size() == 2 and (ids.has(q.parents[0]) or ids.has(q.parents[1])):
			out.append(q)
	return out


func occupants(b: Building) -> int:
	var n := 0
	for p in people:
		if p.home == b.id:
			n += 1
	return n


func houses() -> Array[Building]:
	var out: Array[Building] = []
	for b in buildings:
		if b.built and b.is_house():
			out.append(b)
	return out


func occupancy() -> Dictionary:
	var occ := {}
	for p in people:
		if p.home >= 0:
			occ[p.home] = int(occ.get(p.home, 0)) + 1
	return occ


func _set_home(p: Resident, h: int, occ: Dictionary) -> void:
	if p.home >= 0:
		occ[p.home] = int(occ.get(p.home, 0)) - 1
	p.home = h
	if h >= 0:
		occ[h] = int(occ.get(h, 0)) + 1


func _lives_with_parent(p: Resident) -> bool:
	for pid in p.parents:
		var q := person(pid)
		if q != null and q.home == p.home:
			return true
	return false


func assign_homes() -> void:
	var hs := houses()
	var occ := occupancy()
	for p in people:
		if p.home >= 0 and bld(p.home) == null:
			_set_home(p, -1, occ)
	for p in people:
		if p.home < 0 and (p.partner >= 0 or p.age >= Balance.AGE_ADULT):
			var hh := household_of(p).filter(func(q: Resident) -> bool: return q.home < 0)
			for h in hs:
				if h.cap() - int(occ.get(h.id, 0)) >= hh.size():
					for q: Resident in hh:
						_set_home(q, h.id, occ)
					break
	# 다 자란 미혼 자녀는 집이 꽉 차면 빈자리 있는 집으로 독립
	for p in people:
		if p.age >= Balance.AGE_ADULT and p.partner < 0 and p.parents.size() == 2 and p.home >= 0 and _lives_with_parent(p):
			var h := bld(p.home)
			if int(occ.get(h.id, 0)) < h.cap():
				continue
			var to: Building = null
			var best := 1 << 30
			for b in hs:
				var o := int(occ.get(b.id, 0))
				if b.id != h.id and o < b.cap() and o < best:
					best = o
					to = b
			if to != null:
				_set_home(p, to.id, occ)
				log_line("%s%s 부모 집을 나와 따로 살기 시작했다." % [p.name, josa(p.name, "이", "가")])
	# 집 없는 아이는 부모 집으로
	for p in people:
		if p.home < 0 and p.parents.size() == 2:
			var par := person(p.parents[0])
			if par == null or par.home < 0:
				par = person(p.parents[1])
			if par != null and par.home >= 0:
				var h := bld(par.home)
				if int(occ.get(h.id, 0)) < h.cap():
					_set_home(p, h.id, occ)


# ───────────────────────── 생로병사 (밸런스 v2) ─────────────────────────
func life_events(dt: float) -> void:
	_singers = people.filter(func(q: Resident) -> bool: return q.f("work_aura", 0.0) > 0.0)
	_festival_mult = 1.0
	for s: Resident in _singers:
		_festival_mult = maxf(_festival_mult, s.f("festival"))
	_marriages(dt)
	_births(dt)
	_deaths(dt)


func _siblings(a: Resident, b: Resident) -> bool:
	for x in a.parents:
		if x in b.parents:
			return true
	return false


## 혼인: 성인(4일)~20일 미혼 남녀 짝마다 하루 0.5 (남매 제외). 짝은 sim_life.py처럼 섞어서 한 명씩 맞춘다
func _marriages(dt: float) -> void:
	var men: Array[Resident] = []
	var women: Array[Resident] = []
	for p in people:
		if p.partner < 0 and p.age >= Balance.MARRY_MIN and p.age < Balance.MARRY_MAX:
			(men if p.sex == "m" else women).append(p)
	if men.is_empty() or women.is_empty():
		return
	_shuffle(men)
	_shuffle(women)
	for i in mini(men.size(), women.size()):
		var a := men[i]
		var b := women[i]
		if _siblings(a, b):
			continue
		if rng.randf() < Balance.MARRY_RATE * dt / DAY:
			marry(a, b)
			if a.home != b.home:
				a.home = -1
				b.home = -1
			log_line("%s%s %s%s 모닥불 앞에서 혼인을 약속했다." % [a.name, josa(a.name, "과", "와"), b.name, josa(b.name, "이", "가")])
			speak(a, "거인님, 저희를 지켜봐 주세요", 6)


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


## 출산: 부부(아내 4~18일) + 집에 빈자리. 꽉 차면 '가족 + 1명'이 들어갈 집으로 옮겨야 낳는다 (집 크기 병목 — 의도한 규칙)
func _births(dt: float) -> void:
	var env := birth_env()
	var guarantee: bool = Balance.FIRST_BIRTH_GUARANTEE and stats["born"] == 0 and t >= DAY - Balance.LIFE_EVERY and t < 2.0 * DAY
	for w in people.duplicate():
		if not (w.sex == "f" and w.partner >= 0 and w.age >= Balance.BIRTH_WIFE_MIN and w.age < Balance.BIRTH_WIFE_MAX):
			continue
		var h := bld(w.home) if w.home >= 0 else null
		if h == null or occupants(h) >= h.cap():
			var hh := household_of(w)
			var to: Building = null
			for b in houses():
				if (h == null or b.id != h.id) and b.cap() - occupants(b) >= hh.size() + 1:
					to = b
					break
			if to == null:
				continue
			for q in hh:
				q.home = to.id
			h = to
			stats["moves"] += 1
			log_line("%s의 가족이 더 넓은 집으로 옮겼다." % w.name)
		if guarantee or rng.randf() < Balance.BIRTH_RATE * w.fert * env * dt / DAY:
			guarantee = false
			_give_birth(w, h)


func _give_birth(w: Resident, h: Building) -> void:
	var occ := occupants(h)
	birth_log.append({"t": t, "home": h.id, "occ_before": occ, "cap": h.cap()})
	if occ >= h.cap():
		violations.append("출생 때 집이 꽉 참 (%s, %d/%d)" % [fmt_time(t), occ, h.cap()])
	var sex := "m" if rng.randf() < 0.5 else "f"
	var pool: Array = Balance.NAMES_M if sex == "m" else Balance.NAMES_F
	var nm: String = pool[rng.randi() % pool.size()]
	var dad := person(w.partner)
	var baby := add_person(nm, sex, 0.0, "", h.x, h.y, w, dad if dad != null else w)
	baby.parents = PackedInt32Array([w.id, w.partner])
	baby.home = h.id
	stats["born"] += 1
	log_line("%s%s %s%s 낳았다. 아이는 '%s' 아이였다." % [w.name, josa(w.name, "이", "가"), nm, josa(nm, "을", "를"), baby.trait_name])
	if Genetics.piebald(baby.genes):
		log_line("눈송이 아이가 태어났다. 사람들은 %s%s '하늘의 눈송이가 내려앉은 아이'라 부르며 귀하게 여겼다." % [nm, josa(nm, "을", "를")])
	speak(w, "%s, 반가워!" % nm, 7)


func _deaths(dt: float) -> void:
	var couples := 0
	for p in people:
		if p.sex == "f" and p.partner >= 0:
			couples += 1
	for p in people.duplicate():
		var why := ""
		var la: float = p.age / p.f("lifespan")          # 혈통 '장수' ×1.15 · '단명' ×0.8 → 늙는 빠르기로 (노환 확률·상한 나이)
		if la >= Balance.DEATH_FROM:
			var pd: float = Balance.DEATH_BASE + Balance.DEATH_SLOPE * (la - Balance.DEATH_FROM)
			if rng.randf() < pd * dt / DAY or la > Balance.DEATH_MAX_AGE:
				why = "노환"
		if why == "" and p.health <= 0.0:
			# 거인이 없을 때: 위기 사망(굶주림·병·추위·더위)은 하루 1명까지, 부부 2쌍 아래로는 일어나지 않음 (멸망 방지)
			if not is_watching() and (couples <= Balance.OFFLINE_MIN_COUPLES or _starve_day == day_no()):
				p.health = 0.05
				stats["spared"] = int(stats.get("spared", 0)) + 1
			else:
				why = Health.death_cause(p)
				var what: String = {"굶주림": "굶주림으로", "병": "병으로", "추위": "추위에", "더위": "더위에"}.get(why, "굶주림으로")
				crisis("starve" if why == "굶주림" else ("sick" if why == "병" else why), "%s%s %s 쓰러졌다" % [p.name, josa(p.name, "이", "가"), what])
				_starve_day = day_no()
				if why == "굶주림":
					stats["starved"] += 1
				var key: String = {"병": "died_sick", "추위": "died_cold", "더위": "died_heat"}.get(why, "")
				if key != "":
					stats[key] = int(stats.get(key, 0)) + 1
		if why != "":
			kill(p, why)


func kill(p: Resident, why: String) -> void:
	ResidentAI.cancel(p)
	p.dead = true
	p.death_t = t
	p.death_why = why
	stats["died"] += 1
	if p.job >= 0:
		var b := bld(p.job)
		if b != null:
			b.worker = -1
		stock["도구"] = float(stock["도구"]) + 1.0
	if p.partner >= 0:
		var q := person(p.partner)
		if q != null:
			q.partner = -1
	# 가족 슬픔
	for q in people:
		if q.id == p.partner or q.id in p.parents or p.id in q.parents:
			q.grief_until = t + Balance.GRIEF_DAYS * DAY
	people.erase(p)
	_people_by_id.erase(p.id)
	dead.append(p)
	var age := p.shown_age()
	var ga := josa(p.name, "이", "가")
	var nb := josa(p.name, "은", "는")
	match why:
		"노환":
			log_line("%s(%d세)%s 잠들 듯 숨을 거두었다." % [p.name, age, ga])
		"병":
			log_line("%s(%d세)%s 앓아누운 끝에 끝내 일어나지 못했다." % [p.name, age, ga])
		"추위":
			var ssn: String = jar_date()["season"]
			log_line("%s, %s(%d세)%s 끝내 따뜻해지지 못했다." % ["그 겨울" if ssn == "겨울" else "그 추운 날", p.name, age, nb])
		"더위":
			var ssn: String = jar_date()["season"]
			log_line("%s, %s(%d세)%s 끝내 더위를 이기지 못했다." % ["그 여름" if ssn == "여름" else "그 무더운 날", p.name, age, nb])
		_:
			log_line("%s(%d세)%s 굶주림 끝에 숨을 거두었다." % [p.name, age, ga])
	# 두려움: 가족(부모·자식·배우자·형제) +0.2, 반경 6칸에서 본 사람 +0.05 (HEALTH.md 4)
	for q in people:
		if q.id == p.partner or q.id in p.parents or p.id in q.parents or _siblings(p, q):
			raise_fear(q, Balance.FEAR_FAMILY_DEATH)
		elif Vector2(q.x - p.x, q.y - p.y).length() <= Balance.FEAR_SAW_R and not q.sleeping:
			raise_fear(q, Balance.FEAR_SAW_DEATH)
	recalc_fear()


func idle_chatter() -> void:
	var awake := people.filter(func(q: Resident) -> bool: return not q.sleeping and q.age >= 2.5)
	if awake.is_empty():
		return
	var dbt := awake.filter(func(q: Resident) -> bool: return q.belief < Balance.DOUBT_BELOW)
	if not dbt.is_empty() and rng.randf() < 0.6:
		var kid: Resident = dbt[0]
		for q: Resident in dbt:
			if q.age < 6.0:
				kid = q
				break
		speak(kid, Balance.LINES_DOUBT[rng.randi() % Balance.LINES_DOUBT.size()], 6)
		var elder: Resident = null
		for q: Resident in awake:
			if q.age >= 15.0 and q.belief > 0.5 and (elder == null or q.age > elder.age):
				elder = q
		if elder != null:
			speak(elder, Balance.LINE_ELDER_SCOLD, 6)
		return
	var p: Resident = awake[rng.randi() % awake.size()]
	if is_watching() and rng.randf() < 0.4:
		speak(p, Balance.LINES_WATCHED[rng.randi() % Balance.LINES_WATCHED.size()], 5)
	elif deficit > 0.0:
		speak(p, "창고가 비었어…", 5)


# ───────────────────────── 자율 건설 — 촌장 (RESIDENT_AI 6.2 · 9장) ─────────────────────────
func chief() -> Resident:
	var c: Resident = null
	for p in people:
		if p.age >= Balance.AGE_ADULT and (c == null or p.age > c.age):
			c = p
	return c


func count_type(type: String) -> int:
	var n := 0
	for b in buildings:
		if b.type == type:
			n += 1
	return n


func farm_rate() -> float:
	## 농장들의 시간당 밀 (농사 배율 포함)
	var s := 0.0
	for b in buildings:
		if b.type == "농장":
			if b.farm_mult < 0.0:
				b.farm_mult = farm_mult(b.x, b.y)
			s += 3600.0 / float(Balance.B["농장"]["cycle"]) * b.farm_mult
	return s


func house_capacity() -> int:
	var c := 0
	for b in buildings:
		if b.is_house():
			c += int(Balance.B[b.site_type()]["cap"])
	return c


func _owed(k: String) -> int:
	var s := 0
	for b in buildings:
		if b.is_site():
			s += maxi(0, b.need(k) - int(b.delivered[k]) - int(b.incoming[k]))
	return s


func chief_build() -> void:
	var pending := 0
	for b in buildings:
		if b.is_site():
			pending += 1
	if pending >= 2:
		return
	var pop := people.size()
	var cap := house_capacity()
	var homeless := 0
	var idle := 0
	for p in people:
		if p.home < 0 and p.age >= Balance.AGE_ADULT:
			homeless += 1
		if p.is_adult() and p.job < 0:
			idle += 1
	var era_house: String = Balance.ERA_HOUSE[mini(era, 3)]
	var era_cap := int(Balance.B[era_house]["cap"])
	# 집이 꽉 차서 아이를 못 낳는 부부 (새 집으로 옮기면 해결되는 크기의 가족만)
	var crowded := false
	for w in people:
		if w.sex == "f" and w.partner >= 0 and w.age >= Balance.BIRTH_WIFE_MIN and w.age < Balance.BIRTH_WIFE_MAX and w.home >= 0:
			var h := bld(w.home)
			if occupants(h) >= h.cap() and household_of(w).size() + 1 <= era_cap:
				crowded = true
				break
	var n_houses := 0
	for b in buildings:
		if b.is_house():
			n_houses += 1
	var basics := count_type("농장") > 0 and count_type("나무꾼") > 0
	var food_short := farm_rate() < pop * (HOUR / Balance.FOOD_IV) * Balance.FARM_SAFETY
	var want := ""
	if count_type("농장") == 0 and n_houses >= 1:
		want = "농장"
	elif count_type("나무꾼") == 0 and n_houses >= 1:
		want = "나무꾼"
	elif homeless > 0 or cap - pop <= 1 or (crowded and basics):
		want = "집"
	elif food_short:
		want = "농장"
	elif count_type("우물") == 0:
		want = "우물"
	elif count_type("나무꾼") < 2:
		want = "나무꾼"
	elif float(stock["판자"]) < 12.0 and count_type("제재소") == 0:
		want = "제재소"
	elif float(stock["돌"]) < 6.0 and count_type("채석장") == 0:
		want = "채석장"
	elif _standing_trees() < Balance.FOREST_MIN and count_type("산림관") == 0:
		want = "산림관"
	elif salt_known and count_type("소금밭") == 0 and salt_flat_near() != null:
		want = "소금밭"
	elif era >= 1 and count_type("방앗간") == 0:
		want = "방앗간"
	elif era >= 1 and count_type("빵집") == 0:
		want = "빵집"
	if want == "":
		return
	var upgrade: Building = null
	if want == "집":
		want = era_house
		# 땅이 한계: 집 정원 합계는 품을 수 있는 인구 × 1.1까지. 넘으면 작은 옛 집을 그 시대 집으로 넓혀 짓는다
		if cap + era_cap > land_capacity() * Balance.HOUSE_SLACK:
			for b in buildings:
				if b.built and b.is_house() and b.upgrade_to == "" and b.cap() < era_cap:
					if cap + era_cap - b.cap() <= land_capacity() * Balance.HOUSE_SLACK:
						upgrade = b
					break
			if upgrade == null:
				return
	if upgrade == null and want == era_house and not _affordable(want) and _affordable("오두막"):
		want = "오두막"          # 판자가 모자라면 작은 집이라도 (프로토타입)
	if not _affordable(want):
		# 자재가 모자라 못 지으면 그 자재를 만드는 일터부터 (교착 방지 — 정함)
		var free_plank := float(stock["판자"]) - _owed("판자")
		var need_p := int(Balance.B[want]["plank"]) + (0 if (want == "나무꾼" or want == "제재소") else Balance.PLANK_RESERVE)
		if free_plank < need_p and count_type("제재소") == 0 and _affordable("제재소"):
			want = "제재소"
			upgrade = null
		elif count_type("채석장") == 0 and _affordable("채석장"):
			want = "채석장"
			upgrade = null
		else:
			return
	var d: Dictionary = Balance.B[want]
	if int(d["era"]) > era:
		return
	# 촌장은 직장 없는 성인이 2명 이상일 때만 새 일터 (식량 부족 시 농장 예외)
	if d.get("job", false) and idle < Balance.IDLE_FOR_NEW_JOB and not (want == "농장" and food_short):
		return
	var c := chief()
	var cn := c.name if c != null else ""
	if upgrade != null:
		upgrade.upgrade_to = want
		upgrade.prog = 0.0
		upgrade.delivered = {"판자": 0, "돌": 0}
		upgrade.incoming = {"판자": 0, "돌": 0}
		log_line("촌장 %s%s 작은 옛 집을 %s%s 넓히기로 했다." % [cn, josa(cn, "이", "가"), want, josa(want, "으로", "로")])
		return
	var spot: Variant = find_spot(want)
	if spot == null:
		return
	var sp: Vector2 = spot
	add_building(want, sp.x, sp.y, false)
	log_line("촌장 %s%s %s 자리를 정했다." % [cn, josa(cn, "이", "가"), want])


## 자재가 넉넉한가 — 짓고 있는 현장에 줄 몫을 빼고, 비상용 판자 4장은 남긴다 (나무꾼·제재소 제외, 9장)
func _affordable(type: String) -> bool:
	var d: Dictionary = Balance.B[type]
	var free_plank := float(stock["판자"]) - _owed("판자")
	var free_stone := float(stock["돌"]) - _owed("돌")
	var reserve := 0 if (type == "나무꾼" or type == "제재소") else Balance.PLANK_RESERVE
	return free_plank - int(d["plank"]) >= reserve and free_stone - int(d["stone"]) >= 0


func _standing_trees() -> int:
	var n := 0
	for tr: Dictionary in trees:
		if tr["s"] == "tree":
			n += 1
	return n


func is_free(x: float, y: float, size: float) -> bool:
	if not water.inside(x, y, size + 1.2):
		return false
	if water_at(x, y):
		return false
	for a in 6:
		if water_at(x + cos(a) * (size + 0.4), y + sin(a) * (size + 0.4)):
			return false
	for b in buildings:
		if Vector2(b.x - x, b.y - y).length() < b.size() + size + 0.6:
			return false
	if Vector2(fire.x - x, fire.y - y).length() < size + 1.2:
		return false
	for r: Dictionary in rocks:
		if Vector2(r["x"] - x, r["y"] - y).length() < size + 0.8:
			return false
	return true


## 마을 중심에서 가까운 빈 땅부터 나선형으로. 나무꾼은 숲 옆, 채석장은 바위 옆, 농장은 따뜻하고 촉촉한 곳
func find_spot(type: String) -> Variant:
	var size: float = Balance.B[type]["size"]
	var c := center
	if type == "나무꾼" or type == "산림관":
		var best: Dictionary = {}
		for tr: Dictionary in trees:
			if tr["s"] == "tree" and (best.is_empty() or Vector2(tr["x"], tr["y"]).distance_to(center) < Vector2(best["x"], best["y"]).distance_to(center)):
				best = tr
		if not best.is_empty():
			c = center + (Vector2(best["x"], best["y"]) - center) * 0.85
	elif type == "채석장":
		var best: Dictionary = {}
		for r: Dictionary in rocks:
			if r["amt"] > 0 and (best.is_empty() or Vector2(r["x"], r["y"]).distance_to(center) < Vector2(best["x"], best["y"]).distance_to(center)):
				best = r
		if not best.is_empty():
			c = center + (Vector2(best["x"], best["y"]) - center) * 0.8
	elif type == "농장":
		var best_p: Variant = null
		var bv := 0.0
		for k in 200:
			var a := rng.randf() * TAU
			var d := 3.0 + rng.randf() * 14.0
			var x := center.x + cos(a) * d
			var y := center.y + sin(a) * d
			var val := farm_mult(x, y) - d * 0.02
			if val > bv and is_free(x, y, size):
				bv = val
				best_p = Vector2(x, y)
		if best_p != null:
			_clear_trees(best_p, size)
			return best_p
	elif type == "소금밭":
		var f: Variant = salt_flat_near()
		if f != null:
			var fv: Vector2 = f
			var d := 0.0
			while d < 6.0:
				for a in 12:
					var p := fv + Vector2(cos(a / 2.0), sin(a / 2.0)) * d
					if is_free(p.x, p.y, size):
						_clear_trees(p, size)
						return p
				d += 0.5
	var rad := 2.0
	while rad < path_r:
		for k in 24:
			var a := k / 24.0 * TAU + rad
			var p := c + Vector2(cos(a), sin(a)) * rad
			if is_free(p.x, p.y, size):
				_clear_trees(p, size)
				return p
		rad += 0.8
	return null


func _clear_trees(p: Vector2, size: float) -> void:
	trees = trees.filter(func(tr: Dictionary) -> bool: return Vector2(tr["x"] - p.x, tr["y"] - p.y).length() > size + 0.4)


# ───────────────────────── 호수·소금의 발견 ─────────────────────────
func lake_watch() -> void:
	for i in water.basins.size():
		var b: Dictionary = water.basins[i]
		var a0: int = b["area0"]
		if a0 <= 0:
			continue
		if _fog_on and (not water.revealed(b["x"], b["y"], sid) or Vector2(b["x"], b["y"]).distance_to(center) > WorldCfg.LAKE_WATCH_R):
			continue
		var f := float(water.basin_area(b)) / a0
		var nm: String = b["name"]
		if basins_said[i] < 1 and f < 0.8:
			basins_said[i] = 1
			log_line("%s의 물가가 조금씩 물러난다. 이 호수로 흘러드는 강이 없다." % nm)
		if basins_said[i] < 2 and f < 0.5:
			basins_said[i] = 2
			crisis("lake", "%s%s 절반 넘게 말랐다" % [nm, josa(nm, "이", "가")])
			log_line("%s%s 절반 넘게 말랐다. 드러난 호수 바닥에 흰 소금기가 번진다." % [nm, josa(nm, "이", "가")])
			var elder: Resident = null
			for q in people:
				if q.age >= 15.0 and (elder == null or q.age > elder.age):
					elder = q
			if elder != null:
				speak(elder, "내가 어릴 적엔 저기까지 물이었지", 7)
		if basins_said[i] < 3 and f < 0.12:
			basins_said[i] = 3
			crisis("lake", "%s%s 사라졌다" % [nm, josa(nm, "이", "가")])
			log_line("%s%s 마침내 사라졌다. 그 자리에 하얀 소금 들판이 남았다. 아이들은 그곳에 호수가 있었다는 걸 믿지 않는다." % [nm, josa(nm, "이", "가")])


## 소금의 발견: 하얀 들판이 넓게 드러나면 곁을 지나던 누군가(주로 아이)가 맛본다 (기획서 4.5)
func salt_discovery() -> void:
	if salt_known:
		return
	var flat := 0
	var fc := Vector2.ZERO
	for k in water.village_cells(center, view_r * 1.5):
		if water.depth(k) < 0.004 and water.salt_k(k) > 0.003:
			flat += 1
			fc += Vector2(water.cx(k), water.cy(k))
	if flat < 45:
		return
	fc /= flat
	var near := people.filter(func(q: Resident) -> bool: return not q.sleeping and q.age >= 2.5 and Vector2(q.x, q.y).distance_to(fc) < 12.0)
	if near.is_empty() and rng.randf() > 0.25:
		return
	var who: Resident = null
	for q: Resident in near:
		if q.age < 8.0:
			who = q
			break
	if who == null and not near.is_empty():
		who = near[0]
	if who == null:
		var any := people.filter(func(q: Resident) -> bool: return q.age >= 2.5)
		if any.is_empty():
			return
		who = any[rng.randi() % any.size()]
	salt_known = true
	if era < Balance.ERA_NEED.size():
		era_pts = minf(Balance.ERA_NEED[era], era_pts + Balance.SALT_DISCOVERY_PTS)
	log_line("%s%s 마른 호수 바닥의 하얀 흙을 손가락으로 찍어 맛보았다. 짰다! 사람들은 그것을 '소금'이라 불렀다. 호수 바닥 아래 하얀 바위가 오래도록 녹아든 것이었다." % [who.name, josa(who.name, "이", "가")])
	log_line("어떤 이는 거인님이 호수를 소금으로 바꾸셨다 하고, 어떤 이는 그냥 물이 마른 것뿐이라 했다." if doubters() > 0 else "사람들은 거인님이 호수를 거두어 소금을 남기셨다고 믿었다.")
	speak(who, "짜다! 이 하얀 흙, 짜!", 8)


# ───────────────────────── 판매가 (기획서 11장 — 판매는 거인만, 여기선 값 계산만) ─────────────────────────
## 판매가 = 100지폐 × 등급 × (0.5 + 0.1 × 가장 높은 숙련) × 나이(1.0/0.8/0.6) × 혈통 × 건강 × 0.95^(n−1)
static func sale_price(r: Resident, nth := 1, lineage := false, sick := false) -> float:
	if r.is_child():
		return 0.0
	var age_m: float = Balance.PRICE_AGE[0]
	if r.age >= Balance.PRICE_AGE_OLD:
		age_m = Balance.PRICE_AGE[2]
	elif r.age >= Balance.AGE_ELDER:
		age_m = Balance.PRICE_AGE[1]
	var p: float = Balance.PRICE_BASE * Balance.GRADE_MULT[r.grade] * (Balance.PRICE_SKILL_BASE + Balance.PRICE_SKILL_STEP * r.best_skill()) * age_m
	if lineage:
		p *= Balance.PRICE_LINEAGE
	if sick:
		p *= Balance.PRICE_SICK
	return p * pow(Balance.PRICE_REPEAT, nth - 1)


# ───────────────────────── 오솔길 ─────────────────────────
func mark_path(x: float, y: float, amt: float) -> void:
	var gx := floori((x - center.x + path_r) / (2.0 * path_r) * path_n)
	var gy := floori((y - center.y + path_r) / (2.0 * path_r) * path_n)
	if gx >= 0 and gy >= 0 and gx < path_n and gy < path_n:
		paths[gy * path_n + gx] = minf(60.0, paths[gy * path_n + gx] + amt)
	if _fog_on:
		_reveal_walk(x, y)


# ───────────────────────── 병 돌리기 ─────────────────────────
## 물·지형과 함께 병 안의 모든 것이 (x, y) → (−y, x)로 돈다 (JarWater.rotate_jar)
func rotate_jar() -> void:
	if water is WorldWater:        # 넓은 세상: 데이터는 그대로, 빛이 돈다 (WorldWater.rotate_jar) — 화면이 병을 돌려 보여 준다
		water.rotate_jar()
		for v: Village in [self] + others:
			v._fear_rotate()
			for b in v.buildings:
				b.farm_mult = -1.0
			v.bless_all(0.06)
			v.log_line("땅이 흔들리지도 않았는데 해가 하늘을 건너 옮겨갔다. 그늘이던 쪽이 따뜻해지고, 세상 끝 벽을 타던 물줄기가 다른 곳에서 흘러내리기 시작했다.")
		return
	water.rotate_jar()
	var rp := func(o: Dictionary) -> void:
		var x: float = o["x"]
		o["x"] = -float(o["y"])
		o["y"] = x
	for list: Array in [trees, rocks, manna]:
		for o: Dictionary in list:
			rp.call(o)
	for b in buildings:
		var x := b.x
		b.x = -b.y
		b.y = x
		b.farm_mult = -1.0
	for p in people:
		var x := p.x
		p.x = -p.y
		p.y = x
		for s: Dictionary in p.steps:
			if s["k"] == "walk":
				rp.call(s)
	fire = JarWater.rot_pt(fire)
	var np := PackedFloat32Array()
	np.resize(PATH_N * PATH_N)
	for j in PATH_N:
		for i in PATH_N:
			np[i * PATH_N + (PATH_N - 1 - j)] = paths[j * PATH_N + i]
	paths = np
	_fear_rotate()
	bless_all(0.06)
	log_line("땅이 흔들리지도 않았는데 해가 하늘을 건너 옮겨갔다. 그늘이던 쪽이 따뜻해지고, 세상 끝 벽을 타던 물줄기가 다른 곳에서 흘러내리기 시작했다.")


# ───────────────────────── 점검 (테스트용) ─────────────────────────
func check_invariants() -> PackedStringArray:
	var bad := PackedStringArray()
	for k in stock:
		var v := float(stock[k])
		if is_nan(v) or v < -1e-6:
			bad.append("창고 %s = %f" % [k, v])
	for b in buildings:
		for dct: Dictionary in [b.out, b.in_buf, b.in_inc]:
			for k in dct:
				var v := float(dct[k])
				if is_nan(v) or v < -1e-6:
					bad.append("%s %s = %f" % [b.type, k, v])
		if b.built and b.is_house() and occupants(b) > b.cap():
			bad.append("%s 정원 초과 %d/%d" % [b.type, occupants(b), b.cap()])
	for p in people:
		for v: float in [p.x, p.y, p.hunger, p.health, p.belief, p.age]:
			if is_nan(v):
				bad.append("%s NaN" % p.name)
		if p.hunger < 0.0 or p.belief < 0.0:
			bad.append("%s 음수" % p.name)
	for m: Dictionary in manna:
		if float(m["amt"]) < 0.0:
			bad.append("낟알 음수")
	return bad


# ───────────────────────── 6단계 — 넓은 세상의 무리 (키트) ─────────────────────────
var _fog_on := false
var last_explore_t := -1.0e9
var explorer := -1                    # 지금 탐험 중인 주민 id
var peers: Array = []                 # 같은 세상의 모든 무리 (자기 포함 — JarWorld가 채움)
var kit: Dictionary = {}


## 거인이 세상 지도에서 고른 자리 spot에 키트를 푼다 (JarWorld.place_kit이 부름). 좌표는 세상 좌표.
static func new_settlement(ww: WorldWater, spot: Vector2, kit_def: Dictionary, seed_v: int, sid_v: int) -> Village:
	var v := Village.new()
	v._init_world(ww, spot, kit_def, seed_v, sid_v)
	return v


func _init_world(ww: WorldWater, spot: Vector2, kit_def: Dictionary, seed_v: int, sid_v: int) -> void:
	rng.seed = seed_v
	gene_rng.seed = seed_v * 7919 + 101
	_init_health(seed_v)
	water = ww
	kit = kit_def
	sid = sid_v
	center = spot
	start_clock = ww.start_clock
	path_r = 64.0
	path_n = 256
	view_r = 40.0
	explore_on = true
	_fog_on = true
	stock = Kits.stock(kit_def)
	paths.resize(path_n * path_n)
	paths.fill(0.0)
	var fo: Array = kit_def["fire"]
	fire = spot + Vector2(fo[0], fo[1])
	# 숲: 둘레 숲 무리를 나무 하나하나로 (키트 자리 바로 곁은 치움)
	for f: Dictionary in ww.forests:
		var fc := Vector2(f["x"], f["y"])
		var fr: float = f["r"]
		if fc.distance_to(spot) > WorldCfg.KIT_TREES_R + fr:
			continue
		var cnt := int(PI * fr * fr * float(f["dens"]) * 0.32)
		for i in cnt:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * fr
			var x := fc.x + cos(a) * d
			var y := fc.y + sin(a) * d * 0.9
			var p := Vector2(x, y)
			if p.distance_to(spot) < WorldCfg.KIT_CLEAR_R or p.distance_to(spot) > WorldCfg.KIT_TREES_R:
				continue
			if not ww.inside(x, y, 1.5) or ww.depth(ww.idx(x, y)) >= 0.005:
				continue
			trees.append({"x": x, "y": y, "s": "tree", "g": 0.0, "res": 0})
	for rp in ww.rock_spots:
		if rp.distance_to(spot) < WorldCfg.KIT_ROCKS_R and ww.depth(ww.idx(rp.x, rp.y)) < 0.005:
			rocks.append({"x": rp.x, "y": rp.y, "amt": 20, "res": 0})
	var guard := 0
	while rocks.size() < 2 and guard < 50:      # 고른 자리가 추천 자리가 아니어도 바위 둘은
		guard += 1
		var a := rng.randf() * TAU
		var p := spot + Vector2(cos(a), sin(a)) * rng.randf_range(10.0, 18.0)
		if ww.inside(p.x, p.y, 2.0) and ww.depth(ww.idx(p.x, p.y)) < 0.005:
			rocks.append({"x": p.x, "y": p.y, "amt": 20, "res": 0})
	for b: Dictionary in ww.basins:
		basins_said.append(0)
	for bd: Array in kit_def["buildings"]:
		var b := add_building(bd[0], spot.x + float(bd[1]), spot.y + float(bd[2]), true)
		if bd[0] == "창고":
			b.is_store = true
		_clear_trees(Vector2(b.x, b.y), b.size())
	var ids: Array[Resident] = []
	var looks := Kits.looks(kit_def)
	for f: Array in Kits.people(kit_def):
		var r := add_person(f[0], f[1], f[2], f[3], fire.x + (rng.randf() - 0.5) * 3.0, fire.y + (rng.randf() - 0.5) * 3.0, null, null)
		if ids.size() < looks.size() and looks[ids.size()] is Dictionary:      # 거인이 고른 겉모습 (숨은 열성 유전자는 무작위)
			r.genes = Genetics.from_look(gene_rng, looks[ids.size()])
		ids.append(r)
	if ids.size() >= 7:
		marry(ids[0], ids[1])
		for k in [2, 3]:
			ids[k].parents = PackedInt32Array([ids[0].id, ids[1].id])
		marry(ids[4], ids[5])
		ids[6].parents = PackedInt32Array([ids[4].id, ids[5].id])
		for k: int in [2, 3, 6]:
			var g := ids[k].genes
			_inherit_look(ids[k], ids[0] if k < 6 else ids[4], ids[1] if k < 6 else ids[5])     # 아이는 부모를 닮는다 (추천값)
			if k < looks.size() and looks[k] is Dictionary:
				ids[k].genes = g                  # 고른 겉모습이 있으면 그대로
	# 키트 혈통: 가족 전원이 같은 혈통 (기본 키트는 없음). 키트로 오는 사람에게 나쁜 혈통은 없다
	var kb := Kits.blood(kit_def)
	for r in ids:
		set_blood(r, kb, "kit")
		r.parent_blood = kb.duplicate() if r.parents.size() > 0 else PackedStringArray()
		r.parent_blood_sex = {}
		if r.parents.size() > 0:
			for id in kb:
				r.parent_blood_sex[id] = "m"
	stats["marriages"] = 0
	if people.all(func(p: Resident) -> bool: return p.grade == 0) and ids.size() > 4:
		ids[4].grade = 1
	assign_homes()
	log_line("어느 아침, 거인의 손이 하늘에서 내려와 우리 조상 %d명과 오두막 두 채를 이 땅에 내려놓았다." % people.size())
	log_line("사방은 하얀 안개다. 안개 너머가 어디까지 이어지는지 아무도 모른다. 하늘의 물방울이 똑, 똑 떨어지는 곳에는 마르지 않는 호수가 있다.")
	_reveal_at(center, WorldCfg.REVEAL_KIT, null, true)


func salt_flat_near() -> Variant:
	return water.salt_flat_in(center, view_r * 1.5)


## 걷는 주민 둘레의 안개를 걷는다 (mark_path가 부름 — 안개 칸이 바뀔 때만 실제로 일함)
## 한 걸음이 길면 (몰아서 계산 30초 = 37칸) 걸음 시작점부터 안개 칸 크기 간격으로 걷는다
func _reveal_walk(x: float, y: float) -> void:
	var to := Vector2(x, y)
	if _walker != null:
		var from := Vector2(_walker.px, _walker.py)
		var d := from.distance_to(to)
		var n := int(d / WorldWater.FOG)
		for i in n:
			_reveal_at(from.lerp(to, float(i + 1) / (n + 1)), WorldCfg.REVEAL_WALK, _walker)
	_reveal_at(to, WorldCfg.REVEAL_WALK, _walker)



func _reveal_at(p: Vector2, rad: float, who: Resident, force := false) -> void:
	if who != null:
		rad *= who.f("fog")              # 혈통 '탐험가' 안개 반경 +50%
	var ev: Array = water.reveal(sid, p.x, p.y, rad, force)
	if ev.is_empty():
		return
	for e: Dictionary in ev:
		_on_seen(e, who)


func _on_seen(e: Dictionary, who: Resident) -> void:
	var nm: String = (who.name if who != null else "")
	var subj := ("%s%s " % [nm, josa(nm, "이", "가")]) if nm != "" else "우리는 "
	match String(e["kind"]):
		"lake":
			var ln: String = e["name"]
			if nm == "":
				log_line("가까이에 맑은 호수가 있었다. 사람들은 그곳을 '%s'%s 불렀다." % [ln, josa(ln, "이라", "라")])
			else:
				log_line("%s안개 너머에서 처음 보는 호수를 찾았다. 사람들은 그곳을 '%s'%s 불렀다." % [subj, ln, josa(ln, "이라", "라")])
		"river":
			var rn: String = e["name"]
			log_line("%s세상 끝 벽 쪽에서 흘러오는 물줄기를 보았다. 사람들은 그 물을 '%s'%s 불렀다." % [subj, rn, josa(rn, "이라", "라")])
		"salt":
			log_line("%s땅 위로 솟은 하얀 바위를 보았다. 물이 닿는 자리마다 바위가 조금씩 녹아 있었다." % subj)
		"contact":
			_meet(int(e["other"]), who)


## 다른 무리와 처음 만남 (기획서 13.1 '추가 키트' — 서로 모르다 탐험으로 만남)
func _meet(other_sid: int, who: Resident) -> void:
	if met.has(other_sid):
		return
	var o: Village = null
	for q: Village in peers:
		if q.sid == other_sid:
			o = q
	if o == null:
		return
	met[other_sid] = t
	o.met[sid] = t
	var nm := who.name if who != null else "누군가"
	log_line("%s%s 안개 너머에서 낯선 사람들의 연기를 보았다. 이 세상에 우리 말고도 사람이 있었다!" % [nm, josa(nm, "이", "가")])
	o.log_line("우리 땅 가장자리에 낯선 이가 나타났다. 그들도 거인의 손이 내려놓은 사람들이라고 했다.")
	if who != null:
		speak(who, "저 너머에 사람이 있어요!", 8)


## 탐험할 곳 (안개 가장자리) — 없으면 null
func explore_target() -> Variant:
	return water.fog_target(sid, center, rng, WorldCfg.EXPLORE_MAX)


func can_explore(r: Resident = null) -> bool:
	var every := WorldCfg.EXPLORE_EVERY
	if r != null:
		every /= r.f("explore")          # 혈통 '탐험가'는 더 자주 나선다
	return explore_on and explorer < 0 and t - last_explore_t >= every


## 건물이 다 지어지면 둘레 안개도 걷힌다
func reveal_building(b: Building) -> void:
	if _fog_on:
		_reveal_at(Vector2(b.x, b.y), WorldCfg.REVEAL_BUILD, null, true)


# ───────────────────────── 건강·기후·두려움 (docs/HEALTH.md — 계산은 sim/health.gd) ─────────────────────────
## 병 날짜 {year, month, day, season("봄/여름/가을/겨울")} — 세상을 만든 날 + 병 시계로 흐른 날 수
func jar_date() -> Dictionary:
	return Health.jar_date(self)


## 그 자리의 온도 (°C 느낌) = 기후대 바탕 + 계절 + 낮밤 + 자리(따뜻함 0~1 → +0~+3)
func temperature_at(x: float, y: float) -> float:
	return Health.temperature_at(self, x, y)


## 기후대 (Balance.CLIMATES의 키) — 병(물)이 정한다. 기본 온대
func climate() -> String:
	if climate_override != "":
		return climate_override
	if water != null and Balance.CLIMATES.has(water.climate):
		return water.climate
	return Balance.CLIMATE_DEFAULT


## 창고 물자의 '넉넉함' — 추운 철에는 통나무를 집마다 더 쌓는다 (땔감)
func enough(k: String) -> float:
	var e: float = Balance.ENOUGH.get(k, INF)
	if k == "통나무" and cold_season:
		e += houses().size() * Balance.FUEL_STOCK_PER_HOUSE
	return e


func raise_fear(r: Resident, amt: float) -> void:
	r.fear = clampf(r.fear + amt * r.f("fear_rise"), 0.0, 1.0)      # 담대 ×0.5 · 겁 많음 ×1.5 (내려감은 같음)


func raise_fear_all(amt: float) -> void:
	for r in people:
		raise_fear(r, amt)
	recalc_fear()


## 부락의 두려움 0~100 = 주민 두려움 평균 × 100 (신앙 상태가 그대로 쓴다)
func recalc_fear() -> void:
	if people.is_empty():
		fear = 0.0
		return
	var s := 0.0
	for r in people:
		s += r.fear
	fear = s / people.size() * 100.0


## 거인이 유리를 톡 친다 (그날 4번째부터 모두 +0.05) · 크게 친 톡 = 지진 (모두 +0.2)
func tap_glass(hard := false) -> void:
	var d := cal_day(t)
	if _taps[0] != d:
		_taps = [d, 0]
	_taps[1] += 1
	if hard:
		raise_fear_all(Balance.FEAR_TAP_HARD)
	elif _taps[1] > Balance.FEAR_FREE_PER_DAY:
		raise_fear_all(Balance.FEAR_TAP)


func _fear_rotate() -> void:
	var d := cal_day(t)
	if _rots[0] != d:
		_rots = [d, 0]
	_rots[1] += 1
	if _rots[1] > Balance.FEAR_FREE_PER_DAY:
		raise_fear_all(Balance.FEAR_ROTATE)


## 거인이 식량을 거둠 — 굶주리는 때면 모두 +0.1 (기획서 11.1)
func on_food_taken() -> void:
	if deficit > 0.0 or t - last_short_t < Balance.STARVED_RECENT:
		raise_fear_all(Balance.FEAR_TAKE_FOOD)


## 물 뿌리기가 집을 잠기게 함 — 반경 안 주민 +0.15
func on_house_flooded(x: float, y: float, radius: float) -> void:
	for r in people:
		if Vector2(r.x - x, r.y - y).length() <= radius:
			raise_fear(r, Balance.FEAR_FLOOD)
	recalc_fear()
