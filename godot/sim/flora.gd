## 하늘의 것 — 큰 버섯과 큰 민들레. docs/WORLD_EVENTS.md 1.1 (두 가지 크기) · 2.2 (하룻밤 버섯 숲) · 2.6 (큰 버섯) · 2.7 (큰 민들레).
## 화면과 분리된 순수 로직. Village.flora가 하나 가진다. 난수는 자기 흐름(rng) 하나만 (×1·×8 같음, 다른 흐름을 흔들지 않음).
##
## 바깥의 생물: 거인의 흙에 묻어 온 포자·씨앗이라 거인 세상의 진짜 크기 — 주민에게는 거대하다 (버섯 = 나무보다 큼, 민들레 = 주민 서너 배).
## 큰 버섯: 병의 김(JarAir.humid)이 높을 때 그늘·물가·숲 바닥처럼 축축한 자리에 하나씩 천천히 자라고, 습한 밤 다음 새벽엔
##          '하룻밤 버섯 숲'으로 한꺼번에 솟는다. 버섯꾼(직업)이 베어 나르고 (숙련이 낮으면 가끔 얼룩버섯을 섞어 옴 → 배앓이 ×5),
##          갈색갓버섯은 말림대에서 말린 버섯이 된다. 갓 아래는 그늘 (더위 노출 ×0.6). 김이 빠지면 (뚜껑) 시든다.
## 큰 민들레: 싹 → 노란 꽃 (2일) → 닫힘 (반나절) → 솜털 공 (1일) → 꽃씨가 날림 → 내려앉은 자리에서 3~4일 뒤 새 싹.
##          닫힌 병엔 바람이 없다 — 꽃씨는 볕 쪽에서 오르고 그늘 쪽에서 내려가는 느린 둥근 기류를 탄다 (결정론, 난수 없음).
##          꽃잎 → 꽃차(행복)·노란 물감, 잎 → 쓴 나물 (굶을 때), 솜털 → 솜 (옷 속 — 추위 ×0.8), 줄기 → 아이들 피리.
##          밭에 내려앉은 꽃씨 = 잡초 (그 밭 ×0.8, 농부가 뽑음). 뚜껑이 열릴 때 든 바람에 꽃씨가 한꺼번에 하늘 가득 (lid_breeze — 거인의 '불기' 손짓은 없앴다).
## 주민은 하늘의 것을 처음엔 두려워하다가 (가까이 가면 움찔) 하루쯤 지나 가장 담대한 사람이 맛본 뒤 익숙해진다 (연대기 한 줄).
## 이 파일 밖의 고리: Village.step (step) · Village.consume (on_eat) · Village._update_building (weed_mult) · Village.is_free (blocks) ·
##   Village.chief_build (버섯꾼) · ResidentAI.decide (decide) · ResidentAI.work_task (pick_task · weed_task) · Health (그늘·솜·배앓이 ×5).
class_name Flora
extends RefCounted

var rng := RandomNumberGenerator.new()
var shrooms: Array = []               # {id, kind, x, y, g 자람 0~1, gt 자라는 시간, food 남은 양, res, life 다 자란 뒤 흐른 시간, regrows, gone}
var dands: Array = []                 # {id, x, y, st: sprout/leaf/flower/closed/puff, st_t, cycles, seeds, res}
var pending: Array = []               # 내려앉아 싹을 기다리는 꽃씨 {x, y, at}
var seeds: Array = []                 # 날리는 꽃씨 {x, y, z, px, py, pz, k, born, bx, by, bz}
var weeds: Dictionary = {}            # 밭 건물 id → 잡초 수
var drying: Array = []                # 말림대 {b: 건물 id, amt, done}
var riders: Array = []                # 꽃씨에 매달린 아이 {id, fx, fy, tx, ty, t0}
var ride_h: Dictionary = {}           # 주민 id → 지금 떠 있는 높이 (화면)
var next_id := 1
var trust := false                    # 하늘의 것을 먹고 쓰는 데 익숙해짐
var seen_t := -1.0                    # 처음 하늘의 것을 알아본 때
var startled: Dictionary = {}         # 익숙해지기 전 움찔한 주민 id
var poison_known := false             # 마을이 얼룩버섯을 안다 (한 번 탈이 난 뒤)
var poison_until := -1.0              # 이때까지 배앓이 ×5 (얼룩버섯을 먹은 날)
var tainted := 0.0                    # 창고 버섯에 섞인 얼룩버섯 조각
var _poison_new := false
var grove_last := -1.0e9
var tea_until := -1.0
var last_ride := -1.0e9
var breezes := 0                      # 뚜껑 바람으로 꽃씨가 한꺼번에 날린 횟수 (옛 저장의 blown은 읽고 버림 — flower-forest AC8)
var just_breezed := false             # 화면 연출용 (방금 바람이 들었다)
var blow_dir := Vector2.ZERO
var stats := {"shrooms": 0, "groves": 0, "picked": 0.0, "dried": 0.0, "mixed": 0, "spotted": 0, "poisoned": 0, "withered": 0,
	"sprouts": 0, "released": 0, "landed": 0, "rooted": 0, "lost_water": 0, "escaped": 0, "weeds": 0, "pulled": 0,
	"petals": 0.0, "cotton": 0.0, "greens": 0.0, "rides": 0, "dye": 0.0}
var land_log: Variant = null          # 시험용: Array로 두면 내려앉은 자리 (Vector2)를 모은다
var _night_sum := 0.0
var _night_n := 0
var _last_dawn := -1000000000
var _acc := 0.0
var _sacc := 0.0
var _ready := false


func _init(seed_v: int) -> void:
	rng.seed = seed_v * 5167 + 433


# ───────────────────────── 걸음 ─────────────────────────
static func step(v: Village, dt: float) -> void:
	var f := v.flora
	if f == null:
		return
	if not f._ready:
		f._ready = true
		f._settle(v)
	if not f.riders.is_empty():
		f._move_riders(v)
	f._sacc += dt
	while f._sacc >= Balance.SEED_TICK - 1e-6:
		f._sacc -= Balance.SEED_TICK
		f._seed_tick(v, Balance.SEED_TICK)
	f._acc += dt
	var tk := Balance.FLORA_TICK * v.tick_mult        # 따라잡기 빠른 길이면 성기게
	while f._acc >= tk - 1e-6:
		f._acc -= tk
		f._tick(v, tk)


## 처음: 흙 붓기 때 묻어 온 민들레 몇 포기 (마을 둘레 들판, 한살이가 제각각)
func _settle(v: Village) -> void:
	_last_dawn = _dawn_idx(v)
	var month := int(Health.jar_date(v)["month"])
	var bloom := float(Balance.DAND_BLOOM.get(month, 0.0)) > 0.0
	var tries := 0
	while dands.size() < Balance.DAND_START and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var d := 4.0 + sqrt(rng.randf()) * 10.0          # 적게, 마을 가까이 (보이게)
		var p := v.center + Vector2(cos(a), sin(a)) * d
		if not _dand_ok(v, p):
			continue
		var st := "leaf"
		var u := rng.randf()
		if bloom:
			st = "sprout" if u < 0.2 else ("flower" if u < 0.62 else ("closed" if u < 0.72 else ("puff" if u < 0.9 else "leaf")))
		var dur := _stage_len(st)
		var dd := _add_dand(v, p, st)
		dd["st_t"] = v.t - rng.randf() * dur * 0.8          # 한살이 가운데쯤부터
		if st == "puff":
			dd["seeds"] = Balance.DAND_SEEDS
	if not v.aware:
		_first_puff(v)


## 거인을 아직 모르는 첫 마을 (A4b — OPENING 3.1 v3 3:00 "뚜껑을 열어 꽃씨를 불어 보세요"): 마을 곁에 솜털 공 하나는 꼭 (난수 없이).
## 철과 상관없이 — 거인의 흙에 묻어 온 씨앗이 막 여문 것
func _first_puff(v: Village) -> void:
	for d: Dictionary in dands:
		if (d["st"] == "puff" or d["st"] == "closed") and Vector2(float(d["x"]), float(d["y"])).distance_to(v.center) < 14.0:
			return
	var best: Dictionary = {}
	var bd := INF
	for d: Dictionary in dands:
		var dist := Vector2(float(d["x"]), float(d["y"])).distance_to(v.center)
		if dist < bd:
			bd = dist
			best = d
	if best.is_empty() or bd > 14.0:
		for i in 24:
			var a := TAU * i / 24.0
			var p := v.center + Vector2(cos(a), sin(a)) * (6.0 + (i % 3) * 2.0)
			if _dand_ok(v, p):
				best = _add_dand(v, p, "puff")
				break
	if best.is_empty():
		return
	best["st"] = "puff"
	best["st_t"] = v.t
	best["seeds"] = Balance.DAND_SEEDS


static func _stage_len(st: String) -> float:
	match st:
		"sprout":
			return Balance.DAND_SPROUT
		"flower":
			return Balance.DAND_FLOWER
		"closed":
			return Balance.DAND_CLOSED
		"puff":
			return Balance.DAND_PUFF
	return Balance.DAND_REST


func _add_dand(v: Village, p: Vector2, st := "sprout") -> Dictionary:
	var d := {"id": next_id, "x": p.x, "y": p.y, "st": st, "st_t": v.t, "cycles": 0, "seeds": 0, "res": 0, "born": v.t}
	next_id += 1
	dands.append(d)
	return d


func _dawn_idx(v: Village) -> int:
	return floori((v.start_clock + v.t - Balance.DAWN_HOUR * Balance.HOUR) / Balance.DAY)


# ───────────────────────── 60초 걸음 ─────────────────────────
func _tick(v: Village, dt: float) -> void:
	var humid := v.air.humid if v.air != null else 0.4
	if v.is_night():
		_night_sum += humid
		_night_n += 1
	var di := _dawn_idx(v)
	if di > _last_dawn:
		_last_dawn = di
		_on_dawn(v)
	_grow_shrooms(v, dt, humid)
	_spawn_single(v, dt, humid)
	_dand_tick(v, dt)
	_pending_tick(v)
	_drying_tick(v)
	# 생버섯 상함은 Production.spoil (새벽 — 표 하나 Balance.SPOIL_DAY["버섯"], 섞인 얼룩버섯 조각도 같은 몫 · production-chain R4)
	if _poison_new:
		_poison_new = false
		_poisoned(v)
	_sky_fear(v)


func _on_dawn(v: Village) -> void:
	var avg := _night_sum / _night_n if _night_n > 0 else 0.0
	_night_sum = 0.0
	_night_n = 0
	if v.t >= Balance.GROVE_FIRST and v.t - grove_last >= Balance.GROVE_REST and avg >= Balance.GROVE_HUMID:
		var p := clampf(Balance.GROVE_P * (1.0 + (avg - Balance.GROVE_HUMID) / 0.15) * CoreWarmth.shroom(v), 0.0, 0.95)     # [핵] 서늘한 별은 버섯이 잦음 (A28b)
		if rng.randf() < p:
			grove(v)
	# 꽃차 (행복 +, 그날) · 남는 꽃잎 → 노란 물감
	var petals := float(v.stock.get("꽃잎", 0.0))
	var need := v.people.size() * Balance.TEA_PER
	if petals >= need and need > 0.0:
		v.stock["꽃잎"] = petals - need
		if tea_until < 0.0:
			v.log_line("사람들이 노란 꽃잎을 말려 차를 끓였다. 쌉쌀하고 향긋했다.")
		tea_until = v.t + 1.5 * Balance.DAY        # 다음 새벽의 행복 계산까지
		petals -= need
	if petals > Balance.DYE_PETALS:
		var dye := floorf((petals - Balance.DYE_PETALS) / 4.0)
		if dye >= 1.0:
			v.stock["꽃잎"] = petals - dye * 4.0
			v.stock["노란 물감"] = float(v.stock.get("노란 물감", 0.0)) + dye
			stats["dye"] += dye


## 꽃잎을 이만큼까지만 쌓는다 — 꽃차 이틀치 + 물감 한 번치 (v5)
static func petal_cap(v: Village) -> float:
	return Balance.DYE_PETALS + v.people.size() * Balance.TEA_PER * 2.0


## 꽃차를 마신 날 — 행복 + (Village._update_happiness)
func tea_on(v: Village) -> bool:
	return v.t < tea_until


# ───────────────────────── 큰 버섯 ─────────────────────────
## 그 자리의 축축함 = 땅의 젖음 + 그늘 + 물가 + 숲 바닥 (0~1.6 남짓). 버섯은 SHROOM_DAMP_MIN 위에서만 난다
func damp_at(v: Village, x: float, y: float) -> float:
	var shade := clampf(-v.water.sun_at(x, y), 0.0, 1.0)
	var near_w := 0.0
	for a in 8:
		var ang := a * TAU / 8.0
		if v.water_at(x + cos(ang) * 3.0, y + sin(ang) * 3.0):
			near_w = 1.0
			break
	var n := 0
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree" and absf(float(tr["x"]) - x) < 3.5 and absf(float(tr["y"]) - y) < 3.5:
			n += 1
			if n >= 3:
				break
	return v.wetness(x, y) + 0.5 * shade + 0.25 * near_w + 0.05 * n


func _shroom_ok(v: Village, p: Vector2, kind: String, gap_mult := 1.0) -> bool:
	if not v.water.inside(p.x, p.y, 2.5) or v.water_at(p.x, p.y):
		return false
	if not v.in_territory(p.x, p.y, 1.0):
		return false
	var cr: float = Balance.SHROOM[kind]["cap_r"]
	if Vector2(p.x - v.fire.x, p.y - v.fire.y).length() < 4.0 + cr * 0.5:
		return false
	if Vector2(p.x - v.altar_pos.x, p.y - v.altar_pos.y).length() < 2.5 + cr * 0.5:
		return false
	for b in v.buildings:
		if Vector2(b.x - p.x, b.y - p.y).length() < b.size() + 0.8 + cr * 0.6:
			return false
	var gap := (Balance.SHROOM_GAP if cr > 0.0 else 1.2) * gap_mult
	for s: Dictionary in shrooms:
		if not s["gone"] and Vector2(float(s["x"]) - p.x, float(s["y"]) - p.y).length() < gap:
			return false
	return true


func _roll_kind(key: String) -> String:
	var tot := 0.0
	for k: String in Balance.SHROOM_KINDS:
		tot += float(Balance.SHROOM[k][key])
	var u := rng.randf() * tot
	for k: String in Balance.SHROOM_KINDS:
		u -= float(Balance.SHROOM[k][key])
		if u < 0.0:
			return k
	return Balance.SHROOM_KINDS[0]


func add_shroom(v: Village, p: Vector2, kind: String, g := 0.02) -> Dictionary:
	var d: Dictionary = Balance.SHROOM[kind]
	var s := {"id": next_id, "kind": kind, "x": p.x, "y": p.y, "g": g, "gt": float(d["grow"]), "food": float(d["food"]),
		"res": 0, "life": 0.0, "regrows": 0, "gone": false, "born": v.t}
	next_id += 1
	shrooms.append(s)
	stats["shrooms"] += 1
	if g >= 1.0:
		_seen(v)
	return s


## 하나씩 천천히: 김이 높을 때만, 축축한 자리를 골라
func _spawn_single(v: Village, dt: float, humid: float) -> void:
	humid += CoreWarmth.shroom_damp(v)            # [핵] 서늘한 별: 이끼가 버섯 발치의 축축함을 붙듦 (A28b — 병의 김은 그대로, 보통 별은 0)
	if v.t < Balance.SHROOM_FIRST or humid < Balance.SHROOM_HUMID_MIN or live_shrooms() >= Balance.SHROOM_MAX:
		return
	var f := clampf((humid - Balance.SHROOM_HUMID_MIN) / (Balance.SHROOM_HUMID_FULL - Balance.SHROOM_HUMID_MIN), 0.0, 1.0)
	if rng.randf() >= Balance.SHROOM_RATE_DAY * f * CoreWarmth.shroom(v) * dt / Balance.DAY:     # [핵] 서늘한 별 ×·뜨거운 별 × (A28b)
		return
	var kind := _roll_kind("w")
	var best: Variant = null
	var bs := Balance.SHROOM_DAMP_MIN
	var rad := minf(v.territory_r(), v.water.radius()) - 2.0
	for i in 16:
		var a := rng.randf() * TAU
		var p := v.center + Vector2(cos(a), sin(a)) * (4.0 + sqrt(rng.randf()) * (rad - 4.0))
		if not _shroom_ok(v, p, kind):
			continue
		var sc := damp_at(v, p.x, p.y)
		if sc >= bs:
			bs = sc
			best = p
	if best != null:
		add_shroom(v, best, kind)


func live_shrooms() -> int:
	var n := 0
	for s: Dictionary in shrooms:
		if not s["gone"]:
			n += 1
	return n


## 하룻밤 버섯 숲 — 가장 축축한 곳(물가 그늘)에 다 자란 버섯 5~8개가 한꺼번에. 성공하면 솟은 수
func grove(v: Village) -> int:
	var c: Variant = null
	var bs := -1.0
	var rad := minf(v.territory_r(), v.water.radius()) - 3.0
	for i in 40:
		var a := rng.randf() * TAU
		var p := v.center + Vector2(cos(a), sin(a)) * (6.0 + sqrt(rng.randf()) * (rad - 6.0))
		if not _shroom_ok(v, p, "흰갓버섯"):
			continue
		var sc := damp_at(v, p.x, p.y)
		if sc > bs:
			bs = sc
			c = p
	if c == null or bs < Balance.SHROOM_DAMP_MIN:
		return 0
	var cp: Vector2 = c
	var want := rng.randi_range(int(Balance.GROVE_N[0]), int(Balance.GROVE_N[1]))
	var made := 0
	for i in 60:
		if made >= want:
			break
		var kind := _roll_kind("gw") if made > 0 else "흰갓버섯"
		var a := rng.randf() * TAU
		var p := cp + Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * Balance.GROVE_R
		if made > 0 and (not _shroom_ok(v, p, kind, 0.8) or damp_at(v, p.x, p.y) < Balance.SHROOM_DAMP_MIN - 0.15):
			continue
		if made == 0:
			p = cp
		add_shroom(v, p, kind, 1.0)
		made += 1
	if made < 3:
		return made
	grove_last = v.t
	stats["groves"] += 1
	var where := "물가" if _near_water(v, cp, 4.0) else ("그늘진 숲 바닥" if _near_trees(v, cp, 4.0) else "그늘진 들판")
	var kids := v.people.any(func(q: Resident) -> bool: return q.is_child() and q.age >= 2.5)
	v.log_line("밤새 %s에 집채만 한 버섯이 솟았다.%s" % [where, " 아이들이 갓 위에서 뛰어놀았다." if kids and trust else ""])
	v.warnings.append({"t": v.t, "kind": "grove", "text": "밤새 큰 버섯이 솟았어요!"})
	var believer: Resident = null
	var doubter: Resident = null
	for r in v.people:
		if r.sleeping or r.age < Balance.AGE_ADULT or r.sick_left > 0.0:
			continue
		if believer == null and r.belief >= 0.6:
			believer = r
		elif doubter == null and r.belief < 0.45:
			doubter = r
	if believer != null:
		v.speak(believer, "{w:이/가} 내려 주신 양식이야!" if trust else "하늘의 것이 솟았다…!", 7)
	if doubter != null:
		v.speak(doubter, "젖은 땅에선 원래 나.", 6)
	return made


func _near_water(v: Village, p: Vector2, r: float) -> bool:
	for a in 8:
		var ang := a * TAU / 8.0
		if v.water_at(p.x + cos(ang) * r, p.y + sin(ang) * r):
			return true
	return false


func _near_trees(v: Village, p: Vector2, r: float) -> bool:
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree" and Vector2(float(tr["x"]) - p.x, float(tr["y"]) - p.y).length() < r:
			return true
	return false


## 자라기 · 시들기 (김이 빠지면 4배 빨리) · 부채버섯은 베어도 다시 자람
func _grow_shrooms(v: Village, dt: float, humid: float) -> void:
	if shrooms.is_empty():
		return
	humid += CoreWarmth.shroom_damp(v)            # [핵] (A28b — _spawn_single과 같게)
	var any_gone := false
	for s: Dictionary in shrooms:
		if s["gone"]:
			any_gone = true
			continue
		if float(s["g"]) < 1.0:
			var gf := 1.0 if humid >= Balance.SHROOM_HUMID_MIN else 0.3
			s["g"] = minf(1.0, float(s["g"]) + dt / float(s["gt"]) * gf)
			if float(s["g"]) >= 1.0:
				_seen(v)
		else:
			s["life"] = float(s["life"]) + dt * (4.0 if humid < Balance.SHROOM_WITHER_HUMID else 1.0)
			if float(s["life"]) >= Balance.SHROOM_LIFE and int(s["res"]) == 0:
				s["gone"] = true
				stats["withered"] += 1
				any_gone = true
	if any_gone:
		shrooms = shrooms.filter(func(s: Dictionary) -> bool: return not s["gone"] or int(s["res"]) > 0)


func mature(s: Dictionary) -> bool:
	return float(s["g"]) >= 1.0 and not s["gone"]


## 먹는 버섯 중 다 자란 것 (버섯꾼을 둘 만한가)
func edible_mature(near := Vector2.INF, rad := INF) -> int:
	var n := 0
	for s: Dictionary in shrooms:
		if mature(s) and not Balance.SHROOM[s["kind"]].get("poison", false) and float(s["food"]) > 0.0:
			if near == Vector2.INF or Vector2(float(s["x"]) - near.x, float(s["y"]) - near.y).length() <= rad:
				n += 1
	return n


## 이 자리에 집을 지을 수 없다 (큰 버섯의 굵은 대 둘레)
func blocks(x: float, y: float, size: float) -> bool:
	for s: Dictionary in shrooms:
		if s["gone"]:
			continue
		var cr: float = Balance.SHROOM[s["kind"]]["cap_r"]
		if Vector2(float(s["x"]) - x, float(s["y"]) - y).length() < size + 0.5 + cr * Balance.SHROOM_BLOCK:
			return true
	return false


## 큰 갓 아래 그늘인가 (Health.protection — 더위 ×0.6)
func shade_at(x: float, y: float) -> bool:
	for s: Dictionary in shrooms:
		if s["gone"] or float(s["g"]) < 0.6:
			continue
		var cr: float = Balance.SHROOM[s["kind"]]["cap_r"] * float(s["g"])
		if cr > 0.0 and absf(float(s["x"]) - x) <= cr and absf(float(s["y"]) - y) <= cr and Vector2(float(s["x"]) - x, float(s["y"]) - y).length() <= cr:
			return true
	return false


## 짓는 자리의 민들레·내려앉은 꽃씨는 치운다 (Village._clear_trees)
func clear_at(p: Vector2, size: float) -> void:
	dands = dands.filter(func(d: Dictionary) -> bool: return int(d["res"]) > 0 or Vector2(float(d["x"]) - p.x, float(d["y"]) - p.y).length() > size + 0.4)
	pending = pending.filter(func(d: Dictionary) -> bool: return Vector2(float(d["x"]) - p.x, float(d["y"]) - p.y).length() > size + 0.4)


# ───────────────────────── 하늘의 것을 두려워하다 익숙해짐 (1.1) ─────────────────────────
func _seen(v: Village) -> void:
	if seen_t >= 0.0:
		return
	seen_t = v.t
	for r in v.people:
		if not r.sleeping and r.age >= 2.5 and r.sick_left <= 0.0:
			v.speak(r, "하늘의 것이다… 가까이 가지 마!", 6)
			break


## 익숙해지기 전: 가까이 간 사람은 한 번 움찔 (두려움 조금). 하루쯤 지나면 (굶주리면 바로) 가장 담대한 어른이 맛본다
func _sky_fear(v: Village) -> void:
	if trust:
		return
	if seen_t < 0.0:
		for d: Dictionary in dands:
			if d["st"] == "flower" and Vector2(float(d["x"]) - v.fire.x, float(d["y"]) - v.fire.y).length() < 16.0:
				_seen(v)
				break
		if seen_t < 0.0:
			return
	var r2 := Balance.SKY_FEAR_R * Balance.SKY_FEAR_R
	for r in v.people:
		if r.sleeping or r.age < 2.5 or startled.has(r.id):
			continue
		var close := false
		for s: Dictionary in shrooms:
			if mature(s) and Vector2(float(s["x"]) - r.x, float(s["y"]) - r.y).length_squared() < r2 * 2.0:
				close = true
				break
		if not close:
			for d: Dictionary in dands:
				if d["st"] != "sprout" and d["st"] != "leaf" and Vector2(float(d["x"]) - r.x, float(d["y"]) - r.y).length_squared() < r2:
					close = true
					break
		if close:
			startled[r.id] = true
			v.raise_fear(r, Balance.SKY_FEAR * 8.0)
			if startled.size() <= 3:
				v.speak(r, "하늘의 것이야… 무서워", 5)
	var hungry := v.deficit > 0.0 or v.t - v.last_short_t < Balance.HOUR
	if v.t - seen_t < Balance.SKY_TRUST_AFTER and not hungry:
		return
	if v.is_night():
		return
	var brave: Resident = null
	for r in v.people:
		if r.is_adult() and not r.sleeping and r.sick_left <= 0.0 and (brave == null or r.fear < brave.fear or (r.fear == brave.fear and r.f("fear_rise") < brave.f("fear_rise"))):
			brave = r
	if brave == null:
		return
	trust = true
	startled.clear()
	var nm := brave.name
	if edible_mature() > 0:
		v.log_line("%s%s 하늘의 것을 처음 맛보았다. 큰 버섯 한 조각이 쫄깃하고 고소했다. 그 뒤로 사람들은 하늘에서 온 큰 것들을 두려워하지 않았다." % [nm, Village.josa(nm, "이", "가")])
	else:
		v.log_line("%s%s 하늘의 꽃 잎을 처음 씹어 보았다. 쌉쌀했지만 먹을 만했다. 그 뒤로 사람들은 하늘에서 온 큰 것들을 두려워하지 않았다." % [nm, Village.josa(nm, "이", "가")])
	v.speak(brave, "먹을 만한데?", 6)


# ───────────────────────── 버섯꾼 (ResidentAI.work_task의 한 갈래) ─────────────────────────
## 얼룩버섯을 알아볼 확률 (숙련·마을의 앎·노인)
func spot_p(r: Resident) -> float:
	var p := Balance.POISON_SPOT + Balance.POISON_SPOT_SKILL * float(r.skills.get("버섯꾼", 0.0))
	if poison_known:
		p += Balance.POISON_SPOT_KNOWN
	if r.is_elder():
		p += Balance.POISON_SPOT_ELDER
	return clampf(p, 0.0, 1.0)


## 무엇을 벨지 고른다 → [버섯 Dictionary, 방식 "food"/"dry"/"glow"/"dye"/"mix"] (없으면 [])
func choose(v: Village, r: Resident, b: Building) -> Array:
	var c := Vector2(b.x, b.y)
	var edible: Dictionary = {}
	var poison: Dictionary = {}
	var de := INF
	var dp := INF
	for s: Dictionary in shrooms:
		if not mature(s) or int(s["res"]) > 0 or float(s["food"]) <= 0.0:
			continue
		var d := Vector2(float(s["x"]) - c.x, float(s["y"]) - c.y).length()
		if d > Balance.GATHER_RANGE:
			continue
		if Balance.SHROOM[s["kind"]].get("poison", false):
			if d < dp:
				dp = d
				poison = s
		elif d < de:
			if s["kind"] == "빛버섯" and float(v.stock.get("빛버섯", 0.0)) >= v.enough("빛버섯"):
				continue
			de = d
			edible = s
	if not poison.is_empty() and dp < de:
		if rng.randf() < spot_p(r):             # 알아봄: 물감이 모자라면 일부러 베고, 아니면 피한다
			stats["spotted"] += 1
			if float(v.stock.get("붉은 물감", 0.0)) < v.enough("붉은 물감"):
				return [poison, "dye"]
		elif rng.randf() < Balance.POISON_MIX_P:  # 못 알아봄: 먹는 버섯인 줄 알고 벤다
			return [poison, "mix"]
	if edible.is_empty():
		return []
	var mode := "food"
	if edible["kind"] == "빛버섯":
		mode = "glow"
	elif Balance.SHROOM[edible["kind"]].get("dry", false) and float(v.stock.get("말린 버섯", 0.0)) < v.enough("말린 버섯"):
		mode = "dry"
	return [edible, mode]


## 버섯꾼 일: 가까운 큰 버섯으로 가서 베어 조각내 나름 (갈색갓은 말림대로). 할 일이 있으면 걸음을 짜고 true
func pick_task(v: Village, r: Resident, b: Building) -> bool:
	var ch := choose(v, r, b)
	if ch.is_empty():
		r.doing = "벨 버섯이 없어요"
		r.steps.append(ResidentAI.act(120.0, "idle"))
		return true
	var s: Dictionary = ch[0]
	var mode: String = ch[1]
	s["res"] = int(s["res"]) + 1
	var off := Vector2(r.x - float(s["x"]), r.y - float(s["y"]))
	if off.length() < 0.01:
		off = Vector2(1, 0)
	var stand := Vector2(float(s["x"]), float(s["y"])) + off.normalized() * (0.55 if s["kind"] != "빛버섯" else 0.4)
	r.doing = "큰 버섯을 베는 중" if mode != "glow" else "빛버섯을 캐는 중"
	var cut := ResidentAI.op("flora_cut", {"s": s, "mode": mode})
	var unres := ResidentAI.op("flora_unres", {"q": s})
	r.steps.append(ResidentAI.walk(stand.x, stand.y))
	r.steps.append(ResidentAI.act(float(b.def()["pick"]), "work", cut, true, unres))
	if mode == "dry":                          # 말림대 (버섯꾼 오두막 곁) → 반나절 뒤 말린 버섯
		var put := ResidentAI.op("flora_dry_put", {"bid": b.id})
		var undo := ResidentAI.op("flora_dry_undo", {"bid": b.id})
		r.steps.append(ResidentAI.walk(b.x - 1.2, b.y + 0.6))
		r.steps.append(ResidentAI.act(20.0, "work", put, false, undo))
		return true
	var st := v.store()
	var drop := ResidentAI.op("flora_drop", {"mode": mode})
	r.steps.append(ResidentAI.walk(st.x + 0.8, st.y + 0.6))
	r.steps.append(ResidentAI.act(4.0, "idle", drop, false, drop))
	return true


## 주민의 할 일 묶음 (ResidentAI.run_op가 "flora_*"를 넘겨줌) — 저장해도 그대로 이어지게 Callable 대신 값만 붙잡는다
func run_op(v: Village, r: Resident, o: Dictionary) -> void:
	match String(o["op"]):
		"flora_unres":                     # 버섯·민들레 예약 풀기
			var q: Dictionary = o["q"]
			q["res"] = int(q["res"]) - 1
		"flora_cut":
			var s: Dictionary = o["s"]
			var mode: String = o["mode"]
			s["res"] = int(s["res"]) - 1
			if s["gone"] or float(s["food"]) <= 0.0:
				return
			var amt := minf(Balance.PICK_CHUNK, float(s["food"]))
			if mode == "glow":
				amt = 1.0
			s["food"] = float(s["food"]) - amt
			var item := "버섯"
			var got := amt
			if mode == "dye":
				item = "붉은 물감"
				got = amt / 4.0
			elif mode == "glow":
				item = "빛버섯"
			r.carry = item
			r.carry_amt = got
			if float(s["food"]) <= 0.0:
				_spent(s)
			var sk := float(r.skills.get("버섯꾼", 0.0))
			r.skills["버섯꾼"] = minf(Balance.SKILL_MAX, sk + 0.02 * r.talent)     # 베면서 가려 보는 눈이 는다 (하루 숙련과 따로 조금)
		"flora_dry_put":
			if r.carry_amt > 0.0:
				drying.append({"b": int(o["bid"]), "amt": r.carry_amt, "done": v.t + Balance.DRY_TIME})
				stats["picked"] += r.carry_amt
			r.carry = ""
			r.carry_amt = 0.0
		"flora_dry_undo":
			if r.carry_amt > 0.0:
				drying.append({"b": int(o["bid"]), "amt": r.carry_amt, "done": v.t + Balance.DRY_TIME})
		"flora_drop":
			if r.carry_amt > 0.0:
				var k := r.carry
				v.stock[k] = float(v.stock.get(k, 0.0)) + r.carry_amt
				if k == "버섯":
					stats["picked"] += r.carry_amt
					if o["mode"] != "mix":
						CoreWarmth.snail_bonus(v, r.carry_amt)     # [핵] 서늘한 별 — 버섯 갓 밑의 달팽이 덤 (A28b, 보통 별은 0)
					if o["mode"] == "mix":
						tainted += r.carry_amt
						stats["mixed"] += 1
				elif k == "붉은 물감":
					stats["dye"] += r.carry_amt
			r.carry = ""
			r.carry_amt = 0.0
		"flora_pull":
			var bid := int(o["bid"])
			var m := int(weeds.get(bid, 0))
			if m <= 0:
				return
			weeds.erase(bid)
			stats["pulled"] += m
			v.stock["민들레 잎"] = float(v.stock.get("민들레 잎", 0.0)) + 2.0 * m
			stats["greens"] += 2.0 * m
			if int(stats["pulled"]) == m:
				v.log_line("%s%s 밭에 뿌리내린 하늘의 꽃을 뽑아냈다. 뿌리가 팔뚝만 했다." % [r.name, Village.josa(r.name, "이", "가")])
		"flora_gather":
			var d: Dictionary = o["d"]
			d["res"] = int(d["res"]) - 1
			match String(o["what"]):
				"petals":
					v.stock["꽃잎"] = float(v.stock.get("꽃잎", 0.0)) + 2.0
					stats["petals"] += 2.0
				"cotton":
					var n := mini(2, int(d["seeds"]))
					d["seeds"] = int(d["seeds"]) - n
					v.stock["솜"] = float(v.stock.get("솜", 0.0)) + 1.0 + n * 0.5
					stats["cotton"] += 1.0 + n * 0.5
					if float(stats["cotton"]) <= 2.0:
						v.log_line("%s%s 하늘 꽃의 솜털을 한 아름 안고 왔다. 옷 속에 넣으니 따뜻했다." % [r.name, Village.josa(r.name, "이", "가")])
				"greens":
					v.stock["민들레 잎"] = float(v.stock.get("민들레 잎", 0.0)) + 4.0
					stats["greens"] += 4.0
			if o["ride"]:
				_start_ride(v, r, d)
		"flora_landed":
			_end_ride(int(o["rid"]))
			r.doing = "걸어서 마을로 돌아가는 중"
			v.speak(r, "여기가 어디지…", 5)
		"flora_home":
			v.log_line("%s%s 꽃씨를 타고 %s 너머로 날아갔다. 한참 뒤 걸어서 돌아왔다." % [r.name, Village.josa(r.name, "이", "가"), o["place"]])
		"flora_abort":
			_end_ride(int(o["rid"]))
		_:
			push_error("Flora.run_op: 모르는 할 일 %s" % o["op"])


## 다 벤 버섯: 부채버섯은 밑동에서 다시 자람 (세 번까지), 나머지는 사라짐
func _spent(s: Dictionary) -> void:
	var d: Dictionary = Balance.SHROOM[s["kind"]]
	if d.has("regrow") and int(s["regrows"]) < 3:
		s["regrows"] = int(s["regrows"]) + 1
		s["g"] = 0.15
		s["gt"] = float(d["regrow"])
		s["food"] = float(d["food"])
		s["life"] = 0.0
	else:
		s["gone"] = true


func _drying_tick(v: Village) -> void:
	if drying.is_empty():
		return
	var keep: Array = []
	for e: Dictionary in drying:
		if v.t < float(e["done"]):
			keep.append(e)
			continue
		var b := v.bld(int(e["b"]))
		var amt := float(e["amt"])
		if b != null:
			b.out["말린 버섯"] = float(b.out.get("말린 버섯", 0.0)) + amt
		else:
			v.stock["말린 버섯"] = float(v.stock.get("말린 버섯", 0.0)) + amt
		stats["dried"] += amt
		if float(stats["dried"]) <= amt:
			v.log_line("말림대의 갈색 버섯 조각이 꾸덕꾸덕 말랐다. 겨울에도 두고 먹을 수 있겠다.")
	drying = keep


## 말림대에 걸린 양 (화면)
func drying_at(bid: int) -> float:
	var s := 0.0
	for e: Dictionary in drying:
		if int(e["b"]) == bid:
			s += float(e["amt"])
	return s


# ───────────────────────── 얼룩버섯 — 배앓이 (Village.consume · Health의 고리) ─────────────────────────
## 창고의 생버섯을 먹을 때 (Village.consume): 섞인 얼룩버섯 조각도 같은 몫을 먹는다
func on_eat(v: Village, have: float, take: float) -> void:
	if tainted <= 0.0 or have <= 0.0:
		return
	var eaten := tainted * take / have
	tainted = maxf(0.0, tainted - eaten)
	if eaten > 0.05:
		poison_until = v.t + Balance.POISON_DAYS
		if eaten > 0.5 or stats["poisoned"] == 0:     # 처음이면 한 입이라도, 그 뒤로는 조각을 제법 먹었을 때 바로 탈
			_poison_new = true


## 얼룩버섯을 먹은 날 — 배앓이 ×5 (Health._hourly)
static func ill_mult(v: Village) -> float:
	return Balance.POISON_ILL if v.flora != null and v.t < v.flora.poison_until else 1.0


## 아이 중증 ×2 (Health.fall_ill)
static func severe_mult(v: Village, r: Resident, kind: String) -> float:
	return Balance.POISON_CHILD_SEVERE if kind == "배앓이" and r.is_child() and v.flora != null and v.t < v.flora.poison_until else 1.0


## 처음 먹은 사람 하나는 바로 탈이 난다. 첫 탈이 나면 노인이 알아봄 → 마을이 얼룩버섯을 앎, 남은 조각은 버려 물감으로
func _poisoned(v: Village) -> void:
	var cands := v.people.filter(func(q: Resident) -> bool: return q.sick_left <= 0.0 and not q.is_baby())
	if cands.is_empty():
		return
	var who: Resident = cands[rng.randi() % cands.size()]
	Health.fall_ill(v, who, false, "배앓이")
	stats["poisoned"] += 1
	v.speak(who, "배가 뒤틀려…", 6)
	if poison_known:
		return
	poison_known = true
	var elder: Resident = null
	for q in v.people:
		if q.is_elder() and (elder == null or q.age > elder.age):
			elder = q
	if elder == null:
		elder = v.chief()
	var en := elder.name if elder != null else "늙은이"
	v.note_discovery("spotted_mushroom", elder)
	v.log_line("붉은 갓에 흰 점이 박힌 버섯 조각을 먹고 %s%s 배앓이를 했다. %s%s 말했다. \"붉은 갓에 흰 점이 있는 건 먹는 게 아니다. 물감으로나 쓰거라.\"" % [who.name, Village.josa(who.name, "이", "가"), en, Village.josa(en, "이", "가")])
	if elder != null and not elder.sleeping:
		v.speak(elder, "붉은 갓에 흰 점이 있는 건 먹는 게 아니다", 7)
	# 남은 조각을 골라내 버린다 → 붉은 물감
	if tainted > 0.0:
		v.stock["버섯"] = maxf(0.0, float(v.stock.get("버섯", 0.0)) - tainted)
		v.stock["붉은 물감"] = float(v.stock.get("붉은 물감", 0.0)) + tainted / 4.0
		tainted = 0.0


# ───────────────────────── 큰 민들레 ─────────────────────────
func _dand_ok(v: Village, p: Vector2) -> bool:
	if not v.water.inside(p.x, p.y, 2.0) or v.water_at(p.x, p.y):
		return false
	if Vector2(p.x - v.fire.x, p.y - v.fire.y).length() < 3.0 or Vector2(p.x - v.altar_pos.x, p.y - v.altar_pos.y).length() < Village.ALTAR_CLEAR + 1.6:     # 큰 민들레 잎·꽃대가 제단을 가리지 않게
		return false
	for b in v.buildings:
		if Vector2(b.x - p.x, b.y - p.y).length() < b.size() + 0.7:
			return false
	for d: Dictionary in dands:
		if Vector2(float(d["x"]) - p.x, float(d["y"]) - p.y).length() < 1.3:
			return false
	return true


## 지금 달의 꽃 피는 정도 (3~5월 1, 겨울 0)
func bloom_w(v: Village) -> float:
	return float(Balance.DAND_BLOOM.get(int(Health.jar_date(v)["month"]), 0.0))


func _dand_tick(v: Village, dt: float) -> void:
	if dands.is_empty():
		return
	var bw := bloom_w(v)
	var dead := false
	for d: Dictionary in dands:
		var el := v.t - float(d["st_t"])
		match String(d["st"]):
			"sprout":
				if el >= Balance.DAND_SPROUT:
					_set_st(v, d, "flower" if bw >= 0.99 else "leaf")
			"leaf":
				if bw > 0.0 and el >= Balance.DAND_REST and rng.randf() < bw * dt / Balance.DAY:
					_set_st(v, d, "flower")
			"flower":
				if el >= Balance.DAND_FLOWER:
					_set_st(v, d, "closed")
			"closed":
				if el >= Balance.DAND_CLOSED:
					_set_st(v, d, "puff")
					d["seeds"] = Balance.DAND_SEEDS
			"puff":
				if el >= Balance.DAND_PUFF:
					release(v, d)
					d["cycles"] = int(d["cycles"]) + 1
					if int(d["cycles"]) >= Balance.DAND_CYCLES and int(d["res"]) == 0:
						d["st"] = "dead"
						dead = true
					else:
						_set_st(v, d, "leaf")
	if dead:
		dands = dands.filter(func(d: Dictionary) -> bool: return d["st"] != "dead")


func _set_st(v: Village, d: Dictionary, st: String) -> void:
	d["st"] = st
	d["st_t"] = v.t
	if st == "flower":
		stats["bloomed"] = int(stats.get("bloomed", 0)) + 1


## 솜털 공의 꽃씨를 날린다 (남은 꽃씨 — 아이들이 솜을 따 가면 줄어듦)
func release(v: Village, d: Dictionary, push := Vector2.ZERO, lift := 0.0) -> int:
	var n := int(d["seeds"])
	d["seeds"] = 0
	var made := 0
	for i in n:
		if seeds.size() >= Balance.SEED_MAX:
			break
		var a := rng.randf() * TAU
		var x := float(d["x"]) + cos(a) * 0.5 * rng.randf()
		var y := float(d["y"]) + sin(a) * 0.5 * rng.randf()
		var z := Balance.SEED_START_Z + rng.randf() * 0.4
		var k := 0.8 + 0.4 * rng.randf()
		var j := 0.7 + 0.6 * rng.randf()
		var sp := Vector2(cos(a), sin(a)) * 0.15 * lift if lift > 0.0 else Vector2.ZERO    # 불면 사방으로 조금 퍼짐
		seeds.append({"x": x, "y": y, "z": z, "px": x, "py": y, "pz": z, "k": k, "born": v.t,
			"bx": push.x * j + sp.x, "by": push.y * j + sp.y, "bz": lift * j})
		made += 1
	stats["released"] += made
	if made > 0 and int(stats["released"]) == made and not just_breezed:
		v.log_line("하얀 솜털 공에서 꽃씨가 떨어져 나와 천천히 하늘로 떠올랐다.")
	return made


## 꽃씨 한 걸음 (5초): 볕 쪽에서 오르고 높은 곳에서 그늘 쪽으로 흘러 그늘 쪽에 내려앉는다 (결정론)
func _seed_tick(v: Village, dt: float) -> void:
	if seeds.is_empty():
		return
	var keep: Array = []
	var lid := v.air != null and v.air.lid_open
	var decay := exp(-dt / Balance.BLOW_TAU)
	var lim := v.water.radius() - 2.5
	for s: Dictionary in seeds:
		var x := float(s["x"])
		var y := float(s["y"])
		var z := float(s["z"])
		s["px"] = x
		s["py"] = y
		s["pz"] = z
		var sun := v.water.sun_at(x, y)
		var g := Vector2(v.water.sun_at(x + 0.5, y) - v.water.sun_at(x - 0.5, y), v.water.sun_at(x, y + 0.5) - v.water.sun_at(x, y - 0.5))
		var to_shade := -g.normalized() if g.length() > 1e-6 else Vector2.ZERO
		var hz := Balance.SEED_FLOW * float(s["k"]) * clampf((z - Balance.SEED_MID) / 3.0, -0.3, 1.0)
		var vx := to_shade.x * hz + float(s["bx"])
		var vy := to_shade.y * hz + float(s["by"])
		var vz := Balance.SEED_UP * sun - Balance.SEED_SINK + float(s["bz"])
		s["bx"] = float(s["bx"]) * decay
		s["by"] = float(s["by"]) * decay
		s["bz"] = float(s["bz"]) * decay
		x += vx * dt
		y += vy * dt
		z = minf(Balance.SEED_TOP, z + vz * dt)
		var p := Vector2(x, y)
		if p.length() > lim and v.water is JarWater:      # 유리벽: 차가운 벽을 타고 내려앉는다
			p = p.normalized() * lim
			z -= 0.05 * dt
		elif not v.water.inside(p.x, p.y, 1.5):
			z -= 0.05 * dt
			p = Vector2(float(s["px"]), float(s["py"]))
		s["x"] = p.x
		s["y"] = p.y
		s["z"] = z
		if lid and z > 6.0 and rng.randf() < Balance.SEED_LID_ESCAPE:
			stats["escaped"] += 1                  # 뚜껑으로 병 밖으로
			continue
		if z <= 0.0 or v.t - float(s["born"]) >= Balance.SEED_FLIGHT_MAX:
			_land(v, p)
			continue
		keep.append(s)
	seeds = keep


## 내려앉음: 물 → 사라짐 · 밭 → 잡초 · 집 → 사라짐 · 빈 땅 → 45%가 3~4일 뒤 싹
func _land(v: Village, p: Vector2) -> void:
	stats["landed"] += 1
	if land_log != null:
		(land_log as Array).append(p)
	if v.water_at(p.x, p.y):
		stats["lost_water"] += 1
		return
	for b in v.buildings:
		if Vector2(b.x - p.x, b.y - p.y).length() < b.size() + 0.3:
			if b.built and b.type == "농장":
				var n := int(weeds.get(b.id, 0))
				if n == 0 and int(stats["weeds"]) == 0:
					v.log_line("밭에 하늘의 꽃씨가 내려앉아 싹을 틔웠다. 밀 사이로 큰 잎이 퍼졌다.")
				weeds[b.id] = mini(5, n + 1)
				stats["weeds"] += 1
			return
	if rng.randf() >= Balance.DAND_TAKE_ROOT:
		return
	if dands.size() + pending.size() >= Balance.DAND_MAX or not _dand_ok(v, p):
		return
	for e: Dictionary in pending:
		if Vector2(float(e["x"]) - p.x, float(e["y"]) - p.y).length() < 1.3:
			return
	var days := rng.randf_range(float(Balance.DAND_ROOT_DAYS[0]), float(Balance.DAND_ROOT_DAYS[1]))
	pending.append({"x": p.x, "y": p.y, "at": v.t + days * Balance.DAY, "landed": v.t})
	stats["rooted"] += 1


func _pending_tick(v: Village) -> void:
	if pending.is_empty():
		return
	var keep: Array = []
	for e: Dictionary in pending:
		if v.t < float(e["at"]):
			keep.append(e)
			continue
		var p := Vector2(float(e["x"]), float(e["y"]))
		if _dand_ok(v, p) and dands.size() < Balance.DAND_MAX:
			var d := _add_dand(v, p, "sprout")
			d["landed"] = float(e["landed"])
			stats["sprouts"] += 1
	pending = keep


## 그 밭의 잡초 배율 (Village._update_building)
static func weed_mult(v: Village, b: Building) -> float:
	if v.flora == null or not v.flora.weeds.has(b.id):
		return 1.0
	return Balance.WEED_MULT


## 농부: 밭에 잡초가 있으면 먼저 뽑는다 (뽑은 큰 잎은 쓴 나물). 할 일이 있으면 걸음을 짜고 true
func weed_task(v: Village, r: Resident, b: Building) -> bool:
	if int(weeds.get(b.id, 0)) <= 0 or r.injured_left > 0.0:
		return false
	var n := int(weeds[b.id])
	r.doing = "밭의 큰 잡초를 뽑는 중"
	var pull := ResidentAI.op("flora_pull", {"bid": b.id})
	r.steps.append(ResidentAI.walk(b.x + 0.6, b.y - 0.4))
	r.steps.append(ResidentAI.act(Balance.WEED_PULL_TIME * (1.0 + 0.2 * (n - 1)), "work", pull, true))
	if rng.randf() < 0.3:
		v.speak(r, "하늘 꽃이 또 밭에 났네", 4)
	return true


## 솜옷을 입은 사람인가 (솜이 넉넉한 만큼 — 추위 ×0.8, Health.protection)
func cotton_on(v: Village, r: Resident) -> bool:
	var c := float(v.stock.get("솜", 0.0))
	if c <= 0.0 or v.people.is_empty():
		return false
	var share := clampf(c / (v.people.size() * Balance.COTTON_PER), 0.0, 1.0)
	return fposmod(r.id * 0.618034, 1.0) < share


# ───────────────────────── 민들레 따기 (ResidentAI.decide의 한 줄) ─────────────────────────
## 놀던 아이·일 없는 어른이 가까운 민들레로: 꽃잎 · 솜 · (굶을 땐) 잎. 할 일이 있으면 걸음을 짜고 true (난수는 자기 흐름만)
static func decide(v: Village, r: Resident) -> bool:
	var f := v.flora
	if f == null or not f.trust or f.dands.is_empty() or r.is_baby() or r.age < 2.5:
		return false
	if v.is_night() or not v.is_work_time() or r.sick_left > 0.0 or r.injured_left > 0.0:
		return false
	var child := r.is_child()
	if not child and not (r.is_adult() and r.job < 0):
		return false
	if f.rng.randf() >= (Balance.GATHER_P_CHILD if child else Balance.GATHER_P_IDLE):
		return false
	var hungry := not child and (v.deficit > 0.0 or v.t - v.last_short_t < 6.0 * Balance.HOUR)
	var best: Dictionary = {}
	var bd := Balance.GATHER_R
	for d: Dictionary in f.dands:
		if int(d["res"]) > 0:
			continue
		var st: String = d["st"]
		var ok := st == "flower" or (st == "puff" and int(d["seeds"]) > 0) or (hungry and st != "sprout")
		if not ok:
			continue
		var dist := Vector2(float(d["x"]) - r.x, float(d["y"]) - r.y).length()
		if dist < bd:
			bd = dist
			best = d
	if best.is_empty():
		return false
	return f._gather(v, r, best, hungry)


func _gather(v: Village, r: Resident, d: Dictionary, hungry: bool) -> bool:
	var st: String = d["st"]
	var what := "greens" if hungry else ("petals" if st == "flower" else ("cotton" if st == "puff" else "greens"))
	if what == "petals" and float(v.stock.get("꽃잎", 0.0)) >= petal_cap(v):
		return false                      # v5: 꽃잎은 꽃차·물감에 쓸 만큼만 딴다 (창고에 149장씩 쌓이지 않게)
	d["res"] = int(d["res"]) + 1
	r.action = "flora"
	r.last_action = "flora"
	r.doing = {"petals": "큰 민들레 꽃잎을 따는 중", "cotton": "민들레 솜털을 모으는 중", "greens": "민들레 잎을 뜯는 중"}[what]
	var ride := what == "cotton" and r.is_child() and v.t - last_ride >= Balance.RIDE_REST and rng.randf() < Balance.RIDE_P
	var pick := ResidentAI.op("flora_gather", {"d": d, "what": what, "ride": ride})
	var unres := ResidentAI.op("flora_unres", {"q": d})
	var p := Vector2(float(d["x"]), float(d["y"])) + Vector2(cos(r.id * 1.7), sin(r.id * 1.7)) * 0.7
	r.steps.append(ResidentAI.walk(p.x, p.y))
	r.steps.append(ResidentAI.act(60.0 + rng.randf() * 40.0, "play" if r.is_child() else "work", pick, false, unres))
	if r.is_child() and rng.randf() < 0.25:
		v.speak(r, "줄기로 피리를 만들었어!" if rng.randf() < 0.5 else "꽃이 해만 해!", 4)
	return true


# ───────────────────────── 꽃씨 타고 날기 (드문 일) ─────────────────────────
func _start_ride(v: Village, r: Resident, d: Dictionary) -> void:
	var from := Vector2(r.x, r.y)
	var sun_g := Vector2(v.water.sun_at(from.x + 0.5, from.y) - v.water.sun_at(from.x - 0.5, from.y), v.water.sun_at(from.x, from.y + 0.5) - v.water.sun_at(from.x, from.y - 0.5))
	var dir := -sun_g.normalized() if sun_g.length() > 1e-6 else Vector2(1, 0)
	dir = dir.rotated(rng.randf_range(-0.7, 0.7))
	var dist := rng.randf_range(float(Balance.RIDE_DIST[0]), float(Balance.RIDE_DIST[1]))
	var to := from + dir * dist
	for i in 8:                                   # 물 위·병 밖이면 조금씩 줄여서
		if v.water.inside(to.x, to.y, 2.5) and not v.water_at(to.x, to.y):
			break
		dist *= 0.8
		to = from + dir * dist
	if not v.water.inside(to.x, to.y, 2.5) or v.water_at(to.x, to.y):
		return
	last_ride = v.t
	stats["rides"] += 1
	d["seeds"] = maxi(0, int(d["seeds"]) - 1)
	riders.append({"id": r.id, "fx": from.x, "fy": from.y, "tx": to.x, "ty": to.y, "t0": v.t})
	ResidentAI.cancel(v, r)
	r.action = "dand_ride"
	r.last_action = "dand_ride"
	r.doing = "꽃씨에 매달려 날아가는 중"
	v.speak(r, "와아, 날아간다!", 6)
	for q in v.people:
		if q.is_adult() and not q.sleeping and Vector2(q.x - r.x, q.y - r.y).length() < 10.0:
			v.speak(q, "%s, 놓치면 안 돼!" % r.name, 5)
			break
	var rid := r.id
	var place := "들판"
	if _near_trees(v, to, 4.0):
		place = "숲"
	elif _near_water(v, to, 4.0):
		place = "물가"
	var landed := ResidentAI.op("flora_landed", {"rid": rid})
	var home := ResidentAI.op("flora_home", {"place": place})
	var abort := ResidentAI.op("flora_abort", {"rid": rid})
	r.steps.append(ResidentAI.act(Balance.RIDE_TIME, "fly", landed, false, abort))
	var hp := v.fire + Vector2(cos(r.id * 0.9), sin(r.id * 0.9)) * 2.0
	r.steps.append(ResidentAI.walk(hp.x, hp.y))
	r.steps.append(ResidentAI.act(2.0, "idle", home))


func _end_ride(rid: int) -> void:
	for e: Dictionary in riders:
		if int(e["id"]) == rid:
			riders.erase(e)
			break
	ride_h.erase(rid)


func _move_riders(v: Village) -> void:
	for e: Dictionary in riders.duplicate():
		var r := v.person(int(e["id"]))
		if r == null:
			_end_ride(int(e["id"]))
			continue
		var u := clampf((v.t - float(e["t0"])) / Balance.RIDE_TIME, 0.0, 1.0)
		var w := u * u * (3.0 - 2.0 * u)
		r.x = lerpf(float(e["fx"]), float(e["tx"]), w)
		r.y = lerpf(float(e["fy"]), float(e["ty"]), w)
		r.facing = atan2(float(e["tx"]) - float(e["fx"]), float(e["ty"]) - float(e["fy"]))
		ride_h[r.id] = sin(PI * u) * 5.5


# ───────────────────────── 뚜껑 바람 (EVENTS_STAGING 6c-1 — '불기' 손짓은 없앰, flower-forest R7·경우 8) ─────────────────────────
## 뚜껑이 열릴 때 든 바람이 dir 쪽으로 — 다 핀 솜털 공(과 닫힌 꽃)의 꽃씨가 한꺼번에. 손짓이 아니라 믿음·경이 없음
## (깨닫기 전에도 뒤에도 하늘의 숨결 이야기 없음 — 그냥 바람). 날린 꽃씨 수 (뚜껑이 닫혀 있으면 −1)
func lid_breeze(v: Village, dir: Vector2) -> int:
	if v.air == null or not v.air.lid_open:
		return -1
	var dn := dir.normalized() if dir.length() > 1e-6 else Vector2(1, 0)
	breezes += 1
	just_breezed = true
	blow_dir = dn
	var n := 0
	for d: Dictionary in dands:
		if d["st"] == "puff" or d["st"] == "closed":
			if d["st"] == "closed":
				d["seeds"] = Balance.DAND_SEEDS / 2
			n += release(v, d, dn * Balance.BLOW_PUSH, Balance.BLOW_LIFT)
			d["cycles"] = int(d["cycles"]) + 1
			_set_st(v, d, "leaf")
	for s: Dictionary in seeds:                   # 이미 날던 꽃씨도 밀려남
		s["bx"] = float(s["bx"]) + dn.x * Balance.BLOW_PUSH
		s["by"] = float(s["by"]) + dn.y * Balance.BLOW_PUSH
		s["bz"] = float(s["bz"]) + Balance.BLOW_LIFT * 0.5
	if n > 0:
		var said := 0
		for r in v.people:
			if said >= 2:
				break
			if r.sleeping or r.age < 2.5 or r.sick_left > 0.0:
				continue
			v.speak(r, Balance.BLOW_LINE if said == 0 else "꽃씨가 하늘을 덮었어!", 6)
			said += 1
	if breezes == 1 and n > 0:
		v.log_line("들판이 노랗게 물들었다가 하얗게 바뀌었다. 그리고 어디선가 큰 바람이 불어오자 하늘 가득 꽃씨가 떠올랐다. 사람들은 \"하늘에 눈이 내린다!\" 하고 외쳤다.")
	return n


# ───────────────────────── 병 돌리기 ─────────────────────────
func rotate() -> void:
	var rp := func(o: Dictionary, kx: String, ky: String) -> void:
		var x: float = o[kx]
		o[kx] = -float(o[ky])
		o[ky] = x
	for list: Array in [shrooms, dands, pending]:
		for o: Dictionary in list:
			rp.call(o, "x", "y")
	for s: Dictionary in seeds:
		rp.call(s, "x", "y")
		rp.call(s, "px", "py")
		rp.call(s, "bx", "by")
	for e: Dictionary in riders:
		rp.call(e, "fx", "fy")
		rp.call(e, "tx", "ty")
	blow_dir = JarWater.rot_pt(blow_dir)


# ───────────────────────── 화면·시험용 ─────────────────────────
## 이 단계의 몇 %를 지났나 (화면: 꽃이 피어나는 정도·솜털 공이 부푸는 정도)
func stage_u(v: Village, d: Dictionary) -> float:
	return clampf((v.t - float(d["st_t"])) / _stage_len(d["st"]), 0.0, 1.0)


func count_st(st: String) -> int:
	var n := 0
	for d: Dictionary in dands:
		if d["st"] == st:
			n += 1
	return n


# ───────────────────────── 저장 (docs/SAVE.md) ─────────────────────────
## 난수 흐름 포함
func to_dict() -> Dictionary:
	return SaveCodec.props(self)


static func from_dict(d: Dictionary) -> Flora:
	var f := Flora.new(0)
	SaveCodec.apply(f, d)
	return f
