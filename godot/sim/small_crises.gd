## 작은 세계의 위기 셋 — docs/WORLD_EVENTS.md 2.2 (날벌레 · 떠돌이 물방울 · 먼지 뭉치) · 2.3 (얼마나 자주) · 5 (날벌레가 옮기는 병) — ROADMAP B5.
## 화면과 분리된 순수 로직. Village.smalls가 하나 가진다. 난수는 자기 흐름(rng) 하나만 (×1·×8 같음, 다른 흐름을 흔들지 않음 —
## 위기가 없는 병에서는 난수를 하나도 쓰지 않는다). 계산은 병 시계 Balance.AIR_TICK(60초) 고정 걸음, 움직임만 걸음마다.
##
## 날벌레 (하늘 괴물): 따뜻한 철에 뚜껑을 열면 들어옴 (JarAir.open_lid의 굴림 → gnat_in). 조짐 = 유리 밑을 높이 윙윙 맴돎 (한 시간 —
##   그 사이 뚜껑을 다시 열면 그 틈으로 날아 나감) → 내려와 밭·창고를 먹음 (하루 10%) · 곁의 주민은 숨어 일이 멈춤 · 두려움↑ ·
##   역병(20%)·열병(열병이 사는 병)을 지니면 곁의 사람을 물어 옮김 — 고인 물가에서 더 문다 (앓는 사람을 물면 그 병을 지님).
##   주민: 놀란 일이 쌓이면 (두 번째부터는 곧바로) 촌장이 '연기 피우는 사람'을 정해 모깃불(통나무 1)로 쫓음 → 쫓긴 날벌레는 유리벽에 붙고,
##   뚜껑이 열리면 날아 나감. 1~3일 뒤 유리에 붙은 채 떨어짐. 거인: 핀셋 (뚜껑을 연 채 — 서툴면 곁의 집이 부서짐).
## 떠돌이 물방울: 병이 식는 만큼 × 김이 쌓이면 유리에 큰 물방울이 맺혀 하루 동안 부풂 (유리를 따라 천천히 떠돎, 땅에 둥근 그림자) →
##   떨어져 내리막으로 구르며 물자국 → 터져 물바다 (집 잠김 · 밭 쓸림 · 창고 젖음 — 물은 병의 물에서 덜어 온 것: 닫힌 순환).
##   주민: 반쯤 부풀면 그 아래에서 비켜 남 (익숙해지면 맺히자마자). 거인: 유리를 톡 쳐서 미리 떨어뜨림 — 누른 곳 쪽으로 (빈 땅이면 새 연못).
## 먼지 뭉치: 뚜껑이 오래 열릴수록 거인의 방 먼지가 쌓여 → 조짐 (방 빛 속에 반짝이며 내려옴) → 굴러다니는 회색 덩어리 1~3개 (밭을 덮으면 자람 멈춤).
##   해롭진 않지만 성가심. 아이가 만져 보고 (아니면 노인이 옛말을 떠올려) 뜯어 실을 잣는다 → 먼지 실 (작은 세계의 자원). 거인: 입으로 불어 날림.
## 모두: 첫 3일 없음 · 곰팡이까지 합쳐 동시에 둘까지 · 끝나고 반나절 쉼 · 거인이 없을 때는 조짐에서 기다림 · 망루가 있으면 조짐이 먼저 ·
##   세 번 겪으면 피해 절반 · 아무도 죽지 않는다 (다치거나 앓을 뿐 — 게임 오버 없음). 깨닫기 전에는 '거인' 이야기를 하지 않는다.
## 이 파일 밖의 고리: Village.step (step) · JarAir.open_lid (gnat_in) · Village.tap_glass (knock) · Village.lid_breeze (blow_dust — 뚜껑 바람) ·
##   Village.tweeze · ResidentAI.decide (decide) · ResidentAI.run_op ("crisis_*") · Village._update_building (farm_mult) · CatchUp (waiting_lines).
class_name SmallCrises
extends RefCounted

## 먼지 뭉치가 물가에서 멈출 때 길을 짚어 보는 간격 (칸) · 물 위에서 마른 자리를 찾는 고리 수·방향 수 (난수 없음 — 2026-11-11 Q7)
const SHORE_STEP := 0.25
const SHORE_RINGS := 12
const SHORE_DIRS := 16

var rng := RandomNumberGenerator.new()
var things: Array[CrisisThing] = []
var next_id := 1
var smokes: Array = []                # 모깃불 {x, y, until}
var _acc := 0.0
var _hour := -1
# 날벌레
var gnat_phase := "calm"              # calm · omen (높이 맴돎) · swarm
var gnat_t := 0.0
var gnat_end := 0.0
var gnat_rest := 0.0
var gnat_lid_n := 0                   # 조짐이 시작될 때의 뚜껑 연 횟수 (그 뒤 다시 열면 날아 나감)
var gnat_extra := 0.0                 # 망루 덕에 길어진 조짐
var gnat_episodes := 0
var gnat_startles := 0
var smoker_id := -1
# 떠돌이 물방울
var drop_phase := "calm"              # calm · hang (매달려 부풂) · roll (떨어져 구름)
var drop_p := 0.0
var drop_t := 0.0
var drop_x := 0.0
var drop_y := 0.0
var drop_px := 0.0
var drop_py := 0.0
var drop_tx := 0.0                    # 구를 때 가려는 곳
var drop_ty := 0.0
var drop_dir := 0.0                   # 떠도는 방향 (라디안)
var drop_size := 0.0                  # 0~1 (1 = 다 부풂)
var drop_rest := 0.0
var drop_extra := 0.0
var drop_evac := false                # 아래 사람들이 피하기 시작함
var drop_knocked := false             # 거인이 톡 쳐서 떨어뜨림
var drop_episodes := 0
var drop_last_tp := -999.0
var drop_trail: Array = []            # 구른 자리 [x, y, t] (화면: 젖은 물자국)
var drop_splash: Dictionary = {}      # 마지막 물바다 {x, y, r, t} (화면)
# 먼지 뭉치
var dust_phase := "calm"              # calm · omen · roll
var dust_p := 0.0
var dust_t := 0.0
var dust_rest := 0.0
var dust_extra := 0.0
var dust_lid_seen := -1.0             # 압력에 넣은 뚜껑 열린 시간 (JarAir.lid_total)
var dust_known := false               # 뜯어 실을 잣는 법을 앎
var dust_episodes := 0
var pulling: Dictionary = {}          # 뜯는 사람 id → 먼지 뭉치 id
var stats := {"gnats": 0, "gnat_out": 0, "gnat_died": 0, "tweezed": 0, "crushed": 0, "eaten": 0.0, "hid": 0, "smokes": 0,
	"bites": 0, "bite_ill": 0, "drops": 0, "knocked": 0, "flooded": 0, "fields": 0, "ponds": 0, "hurt": 0, "water": 0.0,
	"dust": 0, "pulled": 0, "yarn": 0.0, "blown": 0, "settled": 0, "covered_secs": 0.0}


func _init(seed_v: int) -> void:
	rng.seed = seed_v * 5021 + 313


# ───────────────────────── 공통 ─────────────────────────
func live(kind: String) -> Array[CrisisThing]:
	var out: Array[CrisisThing] = []
	for c in things:
		if c.kind == kind and c.state != "gone":
			out.append(c)
	return out


func busy() -> bool:
	return gnat_phase == "swarm" or drop_phase != "calm" or dust_phase == "roll"


## 곰팡이까지 합쳐 지금 진행 중인 위기 수 (조짐 포함)
static func active_count(v: Village) -> int:
	var n := 0
	if v.mold != null and v.mold.phase != "calm":
		n += 1
	var s := v.smalls
	if s != null:
		n += int(s.gnat_phase != "calm") + int(s.drop_phase != "calm") + int(s.dust_phase != "calm")
	return n


func _can_start(v: Village, rest_until: float) -> bool:
	return v.t >= Balance.MOLD_FIRST_DAY * Balance.DAY and v.t >= rest_until and active_count(v) < Balance.CRISIS_MAX_AT_ONCE


func _awake(v: Village, elder := false, child := false) -> Resident:
	for r in v.people:
		if r.sleeping or r.sick_left > 0.0 or r.age < 2.5:
			continue
		if elder and not r.is_elder():
			continue
		if child and not r.is_child():
			continue
		return r
	return null


## 깨달은 뒤 / 깨닫기 전 말 (깨닫기 전에는 거인 이야기가 없다)
static func say_for(v: Village, aware_text: String, unaware_text: String) -> String:
	return aware_text if v.aware else unaware_text


func _warn(v: Village, kind: String, aware_text: String, unaware_text: String) -> void:
	v.warnings.append({"t": v.t, "kind": kind, "text": WatcherName.fill(v, say_for(v, aware_text, unaware_text))})
	if v.warnings.size() > 20:
		v.warnings.pop_front()


func _spawn(kind: String, p: Vector2, t: float) -> CrisisThing:
	var c := CrisisThing.new()
	c.id = next_id
	next_id += 1
	c.kind = kind
	c.x = p.x
	c.y = p.y
	c.px = p.x
	c.py = p.y
	c.tx = p.x
	c.ty = p.y
	c.born = t
	things.append(c)
	return c


func _inside(v: Village, p: Vector2, margin := 2.0) -> bool:
	return v.water.inside(p.x, p.y, margin)


## 유리벽 쪽 자리 (마을에서 멀어지는 쪽)
func _rim_point(v: Village, from: Vector2) -> Vector2:
	var away := from - v.center
	if away.length() < 0.5:
		away = Vector2(1, 0).rotated(rng.randf() * TAU)
	var p := from + away.normalized() * 9.0
	var k := 0
	while not _inside(v, p, 2.5) and k < 6:
		p = from + away.normalized() * (9.0 - k * 1.5)
		k += 1
	return p


# ───────────────────────── 걸음 ─────────────────────────
static func step(v: Village, dt: float) -> void:
	var s := v.smalls
	if s == null:
		return
	s._move(v, dt)
	s._acc += dt
	while s._acc >= Balance.AIR_TICK - 1e-6:
		s._acc -= Balance.AIR_TICK
		s._tick(v, Balance.AIR_TICK)


## 걸음마다: 움직임만 (난수 없음 — 가려는 곳은 60초 걸음이 정함)
func _move(v: Village, dt: float) -> void:
	for c in things:
		c.px = c.x
		c.py = c.y
		if c.startle > 0.0:
			c.startle = maxf(0.0, c.startle - dt)
		if c.state == "gone":
			continue
		if c.kind == "gnat":
			var goal_alt := 9.0 if c.state == "high" else (14.0 if c.state == "out" else (2.6 if c.state == "flee" else (0.9 if c.state == "eat" else 2.2)))
			c.alt = move_toward(c.alt, goal_alt, 1.5 * dt)
			if c.state == "out" and c.alt >= 13.5:
				c.state = "gone"
				continue
		var to := Vector2(c.tx - c.x, c.ty - c.y)
		var d := to.length()
		if d < 0.02:
			continue
		var sp := Balance.GNAT_SPEED if c.kind == "gnat" else Balance.DUST_SPEED
		if c.kind == "gnat" and c.state == "eat":
			sp *= 0.3
		if c.kind == "gnat" and c.state == "flee":
			sp *= 1.5
		var mv := minf(d, sp * dt)
		c.x += to.x / d * mv
		c.y += to.y / d * mv
		c.facing = atan2(to.x, to.y)
	drop_px = drop_x
	drop_py = drop_y
	if drop_phase == "hang":
		var p := Vector2(drop_x, drop_y) + Vector2(cos(drop_dir), sin(drop_dir)) * Balance.DROP_DRIFT * dt / Balance.HOUR
		if _inside(v, p, 4.0) and p.distance_to(v.center) < 16.0:
			drop_x = p.x
			drop_y = p.y
	elif drop_phase == "roll":
		var to2 := Vector2(drop_tx - drop_x, drop_ty - drop_y)
		var d2 := to2.length()
		if d2 > 0.01:
			var mv2 := minf(d2, Balance.DROP_ROLL_SPEED * dt)
			drop_x += to2.x / d2 * mv2
			drop_y += to2.y / d2 * mv2


# ───────────────────────── 60초 걸음 ─────────────────────────
func _tick(v: Village, dt: float) -> void:
	if not smokes.is_empty():
		smokes = smokes.filter(func(s: Dictionary) -> bool: return float(s["until"]) > v.t)
	if not things.is_empty():
		things = things.filter(func(c: CrisisThing) -> bool: return c.state != "gone")
	_gnat_tick(v, dt)
	_drop_tick(v, dt)
	_dust_tick(v, dt)
	var hr := floori(v.t / Balance.HOUR)
	if hr != _hour:
		_hour = hr
		if gnat_phase == "swarm":
			_bites(v)


# ═════════════════════════ 날벌레 ═════════════════════════
## 뚜껑이 열릴 때 날벌레가 들어왔다 (JarAir.open_lid의 굴림). 받아들였으면 true
func gnat_in(v: Village) -> bool:
	if gnat_phase == "swarm":
		if live("gnat").size() >= Balance.GNAT_MAX:
			return false
		var g := _spawn("gnat", _under_lid(v), v.t)
		g.alt = 9.0
		g.state = "fly"
		_roll_carry(v, g)
		stats["gnats"] += 1
		v.log_line("열린 하늘 틈으로 날개 달린 것이 또 하나 날아들었다.")
		return true
	if gnat_phase != "calm" or not _can_start(v, gnat_rest):
		return false
	gnat_phase = "omen"
	gnat_t = v.t
	gnat_lid_n = v.air.lid_count
	gnat_extra = VillageEra.omen_lead(v)
	var g := _spawn("gnat", _under_lid(v), v.t)
	g.alt = 9.0
	g.state = "high"
	_roll_carry(v, g)
	stats["gnats"] += 1
	v.log_line("열린 하늘 틈으로 집채만 한 날개 달린 것이 윙윙거리며 날아들었다.")
	_warn(v, "gnat", "{w}, 하늘에서 윙윙 소리가 나요!", "하늘에서 윙윙 소리가 나요!")
	if gnat_extra > 0.0:
		v.log_line("망루에서 먼저 윙윙 소리를 들은 사람들이 서둘러 마을에 알렸다.")
	var tl := _awake(v)
	if tl != null:
		v.speak(tl, "하늘에서 윙윙 소리가 나!", 7)
	var el := _awake(v, true)
	if el != null and el != tl:
		v.speak(el, "하늘의 것이 들어왔구나… 연기를 싫어한다더라" if gnat_episodes > 0 else "하늘의 것이 들어왔구나…", 7)
	return true


func _under_lid(v: Village) -> Vector2:
	var a := rng.randf() * TAU
	return v.center + Vector2(cos(a), sin(a)) * (3.0 + rng.randf() * 4.0)


## 들어온 날벌레가 지닌 병 (WORLD_EVENTS 5: 역병 20% · 열병이 사는 병에서는 열병)
func _roll_carry(v: Village, g: CrisisThing) -> void:
	var u := rng.randf()
	if u < Balance.GNAT_PLAGUE_P:
		g.carry = Balance.PLAGUE
	elif Health.endemic("열병", v.climate()) and u < Balance.GNAT_PLAGUE_P + Balance.GNAT_FEVER_P:
		g.carry = "열병"


func gnat_adapted() -> bool:
	return gnat_episodes >= Balance.CRISIS_ADAPT


func _gnat_tick(v: Village, dt: float) -> void:
	if smoker_id >= 0:
		var sm := v.person(smoker_id)
		if sm == null:
			smoker_id = -1
	match gnat_phase:
		"omen":
			var gs := live("gnat")
			if gs.is_empty():
				gnat_phase = "calm"
				return
			if v.air.lid_open and v.air.lid_count > gnat_lid_n:       # 다시 열린 하늘 틈으로 날아 나감 (거인이 도움)
				for g in gs:
					g.state = "out"
					g.tx = g.x
					g.ty = g.y
				stats["gnat_out"] += gs.size()
				gnat_phase = "calm"
				gnat_rest = v.t + Balance.CRISIS_REST * 0.5
				v.log_line("윙윙 소리가 열린 하늘 틈으로 멀어져 갔다.")
				return
			for g in gs:                                    # 유리 밑을 높이 맴돎
				var p := _under_lid(v)
				g.tx = p.x
				g.ty = p.y
			if v.t - gnat_t >= Balance.GNAT_OMEN + gnat_extra:
				if v.is_watching():
					_start_gnats(v)
				else:                                       # 거인이 없을 때는 새 위기가 시작되지 않고 조짐에서 기다림 (SAVE.md 3)
					gnat_t = v.t - Balance.GNAT_OMEN - gnat_extra + Balance.HOUR
		"swarm":
			_gnat_swarm(v, dt)


func _start_gnats(v: Village) -> void:
	gnat_phase = "swarm"
	gnat_t = v.t
	gnat_end = v.t + lerpf(float(Balance.GNAT_PEAK[0]), float(Balance.GNAT_PEAK[1]), rng.randf())
	for g in live("gnat"):
		g.state = "fly"
		_gnat_target(v, g)
	if gnat_episodes >= 1 and smoker_id < 0:
		_name_smoker(v)
	v.crisis("gnat", "집채만 한 날벌레가 마을로 내려왔다")
	if gnat_episodes == 0:
		v.log_line("날개 달린 하늘 괴물이 마을로 내려왔다. 날갯짓 소리에 모두 집으로 숨었다.")
	else:
		v.log_line("날개 괴물이 또 내려왔다. %s 번째였다." % nth_word(gnat_episodes + 1))


## 차례를 말로 (첫 · 두 · 세 … 열, 그 뒤는 "여러") — 연대기에 숫자를 쓰지 않는다 (Q34)
static func nth_word(n: int) -> String:
	var w := ["", "첫", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]
	return w[n] if n < w.size() else "여러"


## 먹을 곳: 밭(농장)과 창고 — 모깃불 연기가 없는 곳
func _food_spots(v: Village) -> Array:
	var out: Array = []
	var s := v.store()
	if s != null and not _smoky(Vector2(s.x, s.y)):
		out.append([-1, Vector2(s.x, s.y)])
	for b in v.buildings:
		if b.built and b.type == "농장" and not _smoky(Vector2(b.x, b.y)):
			out.append([b.id, Vector2(b.x, b.y)])
	return out


func _smoky(p: Vector2) -> bool:
	for s: Dictionary in smokes:
		if Vector2(float(s["x"]) - p.x, float(s["y"]) - p.y).length() < Balance.GNAT_SMOKE_R:
			return true
	return false


func _gnat_target(v: Village, g: CrisisThing) -> void:
	var spots := _food_spots(v)
	if spots.is_empty():                                   # 다 연기 — 유리벽에 붙어 맴돎
		g.state = "flee"
		var rp := _rim_point(v, g.pos())
		g.tx = rp.x
		g.ty = rp.y
		return
	var pick: Array = spots[rng.randi() % spots.size()]
	g.target_b = int(pick[0])
	var a := rng.randf() * TAU
	var p: Vector2 = pick[1] + Vector2(cos(a), sin(a)) * 1.4
	g.tx = p.x
	g.ty = p.y


func _gnat_swarm(v: Village, dt: float) -> void:
	var waning := v.t >= gnat_end
	var n_eat_store := 0
	var field_eat := {}
	var gs := live("gnat")
	for g in gs:
		if g.state == "out":
			continue
		if v.air.lid_open and g.state == "flee":         # 쫓긴 날벌레는 열린 하늘로 날아 나감
			g.state = "out"
			stats["gnat_out"] += 1
			continue
		if waning and g.state != "flee":
			g.state = "flee"
			var rp := _rim_point(v, g.pos())
			g.tx = rp.x
			g.ty = rp.y
			continue
		if g.state != "flee" and _smoky(g.pos()):         # 모깃불 연기 → 유리벽으로 쫓겨남
			g.state = "flee"
			g.startle = 3.0
			var rp2 := _rim_point(v, g.pos())
			g.tx = rp2.x
			g.ty = rp2.y
			continue
		match g.state:
			"flee":
				if g.pos().distance_to(Vector2(g.tx, g.ty)) < 0.3:
					if waning:
						g.state = "gone"                     # 유리에 붙은 채 기운이 다해 떨어짐
						stats["gnat_died"] += 1
					elif rng.randf() < 0.08:
						g.state = "fly"
						_gnat_target(v, g)
			"fly":
				if g.pos().distance_to(Vector2(g.tx, g.ty)) < 0.4:
					g.state = "eat"
				elif rng.randf() < 0.05:
					_gnat_target(v, g)
			"eat":
				if g.target_b < 0:
					n_eat_store += 1
				else:
					field_eat[g.target_b] = int(field_eat.get(g.target_b, 0)) + 1
				var a := rng.randf() * TAU                     # 먹는 자리 둘레를 맴돎
				var base := Vector2(g.tx, g.ty)
				var b := v.bld(g.target_b) if g.target_b >= 0 else v.store()
				if b != null:
					base = Vector2(b.x, b.y)
				var j := base + Vector2(cos(a), sin(a)) * (1.0 + rng.randf() * 0.8)
				g.tx = j.x
				g.ty = j.y
				if b == null or (g.target_b >= 0 and not b.built):
					g.state = "fly"
					_gnat_target(v, g)
	_gnat_eat(v, n_eat_store, field_eat, dt)
	_gnat_startle(v)
	if live("gnat").is_empty():
		_end_gnats(v)


## 밭·창고 식량을 먹음 (하루 10% — 먹는 수에 비례, 익숙해지면 절반)
func _gnat_eat(v: Village, n_store: int, fields: Dictionary, dt: float) -> void:
	var adapt := 0.5 if gnat_adapted() else 1.0
	if n_store > 0:
		var f := Balance.GNAT_EAT_DAY * minf(1.0, float(n_store) / Balance.GNAT_EAT_FULL) * adapt * dt / Balance.DAY
		for k: String in Balance.STORE_FOODS:
			var have := float(v.stock.get(k, 0.0))
			if have > 0.0:
				v.stock[k] = have * (1.0 - f)
				stats["eaten"] += have * f
	for id: int in fields:
		var b := v.bld(id)
		if b == null:
			continue
		var f2 := Balance.GNAT_EAT_DAY * 2.0 * minf(1.0, float(fields[id]) / Balance.GNAT_EAT_FULL) * adapt * dt / Balance.DAY
		for k: String in b.out:
			var hv := float(b.out[k])
			if hv > 0.0:
				b.out[k] = hv * (1.0 - f2)
				stats["eaten"] += hv * f2
		b.timer = maxf(0.0, b.timer - f2 * float(b.def().get("cycle", 0.0)))     # 자라던 밀도 갉아 먹힘


## 가까이 온 날벌레 — 주민은 놀라 숨는다 (하던 일을 놓음). 쌓이면 촌장이 연기 피우는 사람을 정한다
func _gnat_startle(v: Village) -> void:
	var rad := Balance.GNAT_HIDE_R * (0.5 if gnat_adapted() else 1.0)
	var any := false
	for g in things:
		if g.kind != "gnat" or not (g.state == "fly" or g.state == "eat"):
			continue
		for r in v.people:
			if r.sleeping or r.age < 2.5 or r.id == smoker_id or r.sick_left > 0.0:
				continue
			if Vector2(r.x - g.x, r.y - g.y).length() >= rad:
				continue
			g.startle = 2.0
			any = true
			if r.action != "crisis_hide" and r.action != "crisis_smoke":
				v.raise_fear(r, Balance.GNAT_STARTLE_FEAR)
				if r.action in ["work", "build", "haul", "idle", "social", "play", "chop", "gather", "forage"]:
					ResidentAI.cancel(v, r)         # 일이 멈춘다 — 다음 결정에서 숨는다
	if any:
		gnat_startles += 1
	if smoker_id < 0 and (gnat_episodes >= 1 or gnat_startles >= Balance.GNAT_SMOKER_AFTER):
		_name_smoker(v)


func _name_smoker(v: Village) -> void:
	var best: Resident = null
	var bs := -INF
	var ch := v.chief()
	for r in v.people:
		if not r.is_adult() or r.sick_left > 0.0 or r == ch:
			continue
		var s := float(r.skills.get("연기 피우기", 0.0)) * 10.0 - r.fear * 5.0 + (0.5 if r.job < 0 else 0.0) + 0.01 * rng.randf()
		if s > bs:
			bs = s
			best = r
	if best == null:
		best = ch
	if best == null:
		return
	smoker_id = best.id
	if ch != null and ch != best:
		v.speak(ch, "%s, 젖은 장작으로 연기를 피워 저것을 쫓게!" % best.name, 7)
	v.speak(best, "연기를 피울게요!", 6)
	if gnat_episodes == 0:
		v.log_line("촌장이 %s에게 모깃불을 피우게 했다. 날개 괴물은 연기를 싫어했다." % best.name)
	ResidentAI.cancel(v, best)


func _end_gnats(v: Village) -> void:
	gnat_phase = "calm"
	gnat_episodes += 1
	gnat_rest = v.t + Balance.CRISIS_REST
	var season: String = Health.jar_date(v)["season"]
	if gnat_episodes == 1:
		v.log_line("날개 괴물이 물러갔다. 마을은 그 철을 '날개 괴물이 날아든 %s'이라 불렀다." % season)
	else:
		v.log_line("날개 괴물이 또 물러갔다.")
	if gnat_episodes == Balance.CRISIS_ADAPT:
		v.log_line("세 번을 겪은 마을은 이제 날개 괴물이 와도 숨지 않았다. 집집마다 젖은 장작을 쌓아 두었다.")


## 시간마다: 날벌레가 곁의 사람을 문다 — 지닌 병을 옮기고, 앓는 사람을 물면 그 병을 지닌다. 고인 물가에서는 더 문다
func _bites(v: Village) -> void:
	for g in things:
		if g.kind != "gnat" or not (g.state == "fly" or g.state == "eat"):
			continue
		var best: Resident = null
		var bd := Balance.GNAT_BITE_R
		for r in v.people:
			var d := Vector2(r.x - g.x, r.y - g.y).length()
			if d < bd:
				bd = d
				best = r
		if best == null:
			continue
		var p := Balance.GNAT_BITE_HOUR * (Balance.GNAT_WATER_BITE if by_water(v, g.pos()) else 1.0)
		if rng.randf() >= p:
			continue
		stats["bites"] += 1
		if g.carry == "" and best.sick_left > 0.0 and (best.disease == "열병" or best.disease == Balance.PLAGUE):
			g.carry = best.disease                      # 앓는 사람의 피 → 그 병을 지님
			continue
		if g.carry != "" and best.sick_left <= 0.0 and best.latent == "" and not best.is_immune(g.carry, v.t):
			Health.fall_ill(v, best, false, g.carry)
			stats["bite_ill"] += 1
			if best.age >= 2.5:
				v.speak(best, "날개 괴물에게 물렸어… 몸이 뜨거워", 6)


## 고인 물가 (호수·젖은 땅 곁)인가
static func by_water(v: Village, p: Vector2) -> bool:
	if v.water_at(p.x, p.y) or v.wetness(p.x, p.y) > 0.62:
		return true
	for i in 6:
		var q := p + Vector2(cos(i * TAU / 6.0), sin(i * TAU / 6.0)) * 2.5
		if v.water.inside(q.x, q.y, 0.5) and v.water_at(q.x, q.y):
			return true
	return false


## 거인의 핀셋 (뚜껑을 연 채 — WORLD_EVENTS 4.3): 누른 자리 둘레의 날벌레를 집어냄. 멀리 집으면 서툴러 곁의 집이 부서질 수 있음.
## → {ok, why, picked, crushed: 건물 종류 또는 ""}
func tweeze(v: Village, p: Vector2) -> Dictionary:
	if not v.air.lid_open:
		return {"ok": false, "why": "뚜껑을 먼저 열어 주세요", "picked": false, "crushed": ""}
	var best: CrisisThing = null
	var bd := Balance.GNAT_TWEEZE_R
	for g in things:
		if g.kind != "gnat" or g.state == "gone" or g.state == "out":
			continue
		var d := g.pos().distance_to(p)
		if d < bd:
			bd = d
			best = g
	if best == null:
		return {"ok": false, "why": "집을 것이 없어요", "picked": false, "crushed": ""}
	var crushed := ""
	if bd > Balance.GNAT_TWEEZE_CLEAN:                 # 서툰 핀셋: 손끝이 곁의 지붕을 짓누름
		var hit: Building = null
		var hd := Balance.GNAT_TWEEZE_CRUSH_R
		for b in v.buildings:
			if b.is_store or b.site_type() == Awakening.ALTAR:
				continue
			var d2 := Vector2(b.x, b.y).distance_to(p) - b.size() * 0.5
			if d2 < hd:
				hd = d2
				hit = b
		if hit != null:
			crushed = hit.label()
			SkyDrops.remove_building(v, hit)
			stats["crushed"] += 1
			v.log_line("하늘에서 내려온 집게가 빗나가 %s%s 짓눌렸다. 다친 사람은 없었다." % [crushed, Village.josa(crushed, "이", "가")])
			v.raise_fear_all(0.05)
	best.state = "out"
	best.alt = maxf(best.alt, 6.0)
	stats["tweezed"] += 1
	if v.aware:
		v.bless_all(0.03)
		v.log_line("{w}의 커다란 집게가 내려와 날개 괴물을 집어 가셨다.")
	else:
		Awakening.witness(v, "tweeze")
		v.log_line("하늘에서 커다란 집게가 내려와 날개 괴물을 집어 갔다.")
	var near: Array = v.people.filter(func(q: Resident) -> bool: return not q.sleeping and q.age >= 2.5)
	near.sort_custom(func(a: Resident, c: Resident) -> bool: return Vector2(a.x, a.y).distance_squared_to(p) < Vector2(c.x, c.y).distance_squared_to(p))
	if not near.is_empty():
		v.speak(near[0], say_for(v, "{w:이/가} 괴물을 집어 가셨다!", "하늘에서 커다란 손가락이…!"), 7)
	return {"ok": true, "why": "", "picked": true, "crushed": crushed}


# ═════════════════════════ 떠돌이 물방울 ═════════════════════════
func drop_adapted() -> bool:
	return drop_episodes >= Balance.CRISIS_ADAPT


## 압력: 병이 식는 만큼 × 김 (방이 갑자기 식으면 돌기 아닌 곳에 물방울이 맺힘)
func _drop_pressure(v: Village, dt: float) -> void:
	var tp := Health.base_temp(v, v.t)
	tp += v.air.temp_shift(tp)
	if drop_last_tp > -900.0 and tp < drop_last_tp:
		drop_p += (drop_last_tp - tp) * maxf(0.0, v.air.humid - Balance.DROP_HUMID_FROM) / Balance.DROP_NEED
	drop_last_tp = tp
	drop_p = maxf(0.0, drop_p - Balance.DROP_FALL_DAY * dt / Balance.DAY)


func _drop_tick(v: Village, dt: float) -> void:
	_drop_pressure(v, dt)
	match drop_phase:
		"calm":
			var lead := VillageEra.omen_lead(v)
			if drop_p >= (0.75 if lead > 0.0 else 1.0) and _can_start(v, drop_rest):
				drop_extra = lead
				_start_drop(v)
		"hang":
			drop_dir += (rng.randf() - 0.5) * 0.8          # 유리를 따라 천천히 떠돎
			drop_size = clampf(0.15 + 0.85 * (v.t - drop_t) / (Balance.DROP_OMEN + drop_extra), 0.15, 1.0)
			if not drop_evac and (drop_size >= Balance.DROP_EVAC_FROM or drop_adapted()):
				drop_evac = true
				var el := _awake(v, true)
				if el == null:
					el = _awake(v)
				if el != null:
					v.speak(el, "저 물덩이 아래에서 비켜라! 떨어지면 물바다다", 7)
				if drop_episodes == 0:
					v.log_line("하늘의 물덩이가 점점 부풀었다. 사람들은 그 아래 집을 비우고 모닥불 곁으로 옮겼다.")
				for r in v.people:
					if in_drop_zone(Vector2(r.x, r.y), 1.0) and r.action != "crisis_evac" and not r.is_baby() and r.sick_left <= 0.0:
						ResidentAI.cancel(v, r)
			if drop_size >= 1.0:
				if v.is_watching():
					_fall(v)
				else:
					drop_t = v.t - Balance.DROP_OMEN - drop_extra + Balance.HOUR * 0.5     # 거인이 돌아와 볼 수 있을 때까지 매달려 있다
		"roll":
			drop_trail.append([drop_x, drop_y, v.t])
			if drop_trail.size() > 60:
				drop_trail.pop_front()
			_wash_under(v, Vector2(drop_x, drop_y), 1.0, false)
			var at := Vector2(drop_x, drop_y)
			if v.water_at(at.x, at.y) or v.t - drop_t >= Balance.DROP_ROLL or at.distance_to(Vector2(drop_tx, drop_ty)) < 0.05:
				if v.t - drop_t >= Balance.DROP_ROLL or v.water_at(at.x, at.y):
					_burst(v)
				else:
					_roll_target(v)


func _start_drop(v: Village) -> void:
	drop_phase = "hang"
	drop_t = v.t
	drop_size = 0.15
	drop_evac = false
	drop_knocked = false
	drop_trail.clear()
	var p := v.center
	for i in 12:
		var a := rng.randf() * TAU
		var q := v.center + Vector2(cos(a), sin(a)) * (3.0 + rng.randf() * 10.0)
		if _inside(v, q, 4.0):
			p = q
			break
	drop_x = p.x
	drop_y = p.y
	drop_px = p.x
	drop_py = p.y
	drop_dir = rng.randf() * TAU
	stats["drops"] += 1
	if drop_extra > 0.0:
		v.log_line("망루에서 하늘 유리에 맺히는 물방울이 먼저 보였다.")
	v.log_line("하늘에 커다란 물덩이가 맺혔다. 그 아래 땅에 둥근 그림자가 졌다.")
	_warn(v, "drop_omen", "{w}, 하늘에 커다란 물방울이 매달려 부풀고 있어요.", "하늘에 커다란 물방울이 매달려 부풀고 있어요.")
	var tl := _awake(v)
	if tl != null:
		v.speak(tl, "하늘에 물덩이가 매달렸어!", 7)


## 매달린 물방울 아래 (떨어지면 잠기는 자리)인가
func in_drop_zone(p: Vector2, margin := 0.0) -> bool:
	if drop_phase != "hang":
		return false
	return p.distance_to(Vector2(drop_x, drop_y)) < drop_radius() + margin


func drop_radius(sz := -1.0) -> float:
	return Balance.DROP_R * sqrt(maxf(0.2, drop_size if sz < 0.0 else sz))


## 거인이 유리를 톡 친다 → 매달린 물방울이 미리 떨어진다. at(땅 위 자리)을 주면 그쪽으로 (멀면 고를 수 있는 만큼만). 떨어뜨렸으면 true
func knock(v: Village, at: Variant = null) -> bool:
	if drop_phase != "hang":
		return false
	if at != null:
		var aim: Vector2 = at
		var d := aim - Vector2(drop_x, drop_y)
		if d.length() > Balance.DROP_KNOCK_REACH:
			d = d.normalized() * Balance.DROP_KNOCK_REACH
		var q := Vector2(drop_x, drop_y) + d
		if _inside(v, q, 3.0):
			drop_x = q.x
			drop_y = q.y
			drop_px = q.x
			drop_py = q.y
	drop_knocked = true
	stats["knocked"] += 1
	_fall(v)
	return true


func _fall(v: Village) -> void:
	drop_phase = "roll"
	drop_t = v.t
	drop_trail = [[drop_x, drop_y, v.t]]
	var at := Vector2(drop_x, drop_y)
	v.crisis("drop", "하늘의 물덩이가 떨어졌다")
	# 떨어지는 자리: 비키지 못한 사람은 다친다 (죽지 않음), 둘레는 화들짝
	var hurt := 0
	for r in v.people:
		var d := Vector2(r.x - at.x, r.y - at.y).length()
		if d < 1.2 * sqrt(drop_size):
			if r.injured_left <= 0.0:
				r.injured_left = Balance.INJURY_DAYS * Balance.DAY
				hurt += 1
			v.raise_fear(r, 0.1)
		elif d < drop_radius() + 2.0:
			v.raise_fear(r, 0.04)
	stats["hurt"] += hurt
	if v.water_at(at.x, at.y):
		v.log_line("하늘의 물덩이가 호수에 떨어져 큰 물결이 일었다.")
		_burst(v)
		return
	v.log_line("하늘의 물덩이가 떨어졌다! 땅에 닿은 물덩이가 출렁이며 굴러갔다.")
	_roll_target(v)


## 내리막으로 — 둘레 여덟 곳 중 가장 낮은 곳 (물이면 그쪽으로 굴러 들어감)
func _roll_target(v: Village) -> void:
	var at := Vector2(drop_x, drop_y)
	var best := at
	var bh := v.water.ground(v.water.idx(at.x, at.y)) - 0.002
	for i in 8:
		var q := at + Vector2(cos(i * TAU / 8.0), sin(i * TAU / 8.0)) * 1.5
		if not _inside(v, q, 3.0):
			continue
		var h := v.water.ground(v.water.idx(q.x, q.y))
		if v.water_at(q.x, q.y):
			h -= 1.0
		if h < bh:
			bh = h
			best = q
	drop_tx = best.x
	drop_ty = best.y


## 지나간·터진 자리의 밭이 쓸림 (burst = 물바다: 집 잠김·창고 젖음까지)
func _wash_under(v: Village, p: Vector2, rad: float, burst: bool) -> Array:
	var hit: Array = []
	for b in v.buildings:
		if not b.built:
			continue
		if Vector2(b.x, b.y).distance_to(p) > rad + b.size() * 0.5:
			continue
		if b.type == "농장":
			if b.timer > 0.0 or b.out_total() > 0.0 or (b.ready_at >= 0.0 and v.t >= b.ready_at):
				b.timer = 0.0
				b.out = {}
				b.ready_at = v.t + Balance.GROW_FIRST
				stats["fields"] += 1
				hit.append(b)
		elif burst and b.is_house():
			b.in_buf["통나무"] = 0.0          # 땔감이 젖음
			b.fuel_on = false
			stats["flooded"] += 1
			hit.append(b)
		elif burst and b.is_store:
			var loss := Balance.DROP_STORE_LOSS * (0.5 if drop_adapted() else 1.0)
			for k: String in Balance.STORE_FOODS:
				var have := float(v.stock.get(k, 0.0))
				if have > 0.0:
					v.stock[k] = have * (1.0 - loss)
			hit.append(b)
	return hit


## 터짐: 물바다 — 맺힌 김(모자라면 병의 물)에서 덜어 와 그 자리에 붓는다 (닫힌 순환 — 물 + 김의 합은 그대로)
func _burst(v: Village) -> void:
	var at := Vector2(drop_x, drop_y)
	var rad := drop_radius()
	var sz := drop_size
	var hit := _wash_under(v, at, rad, true)
	var added := _pour(v, at, rad, Balance.DROP_WATER * sz)
	stats["water"] += added
	if added > 0.0:
		stats["ponds"] += 1
	drop_splash = {"x": at.x, "y": at.y, "r": rad, "t": v.t}
	var houses := 0
	var fields := 0
	var store := false
	for b: Building in hit:
		if b.is_house():
			houses += 1
		elif b.type == "농장":
			fields += 1
		elif b.is_store:
			store = true
	if houses > 0:
		v.on_house_flooded(at.x, at.y, rad + 1.0)
	for r in v.people:                                   # 물바다 속 사람은 물을 헤치고 나옴 (다치지 않음)
		if Vector2(r.x - at.x, r.y - at.y).length() < rad and not r.is_baby() and r.sick_left <= 0.0:
			ResidentAI.cancel(v, r)
	if hit.is_empty():
		v.log_line("물덩이가 빈 들에서 터져 작은 연못이 되었다.")
		if drop_knocked and v.aware:
			v.bless_all(0.02)
			v.log_line("{w:이/가} 물덩이를 빈 들로 떨어뜨려 주셨다고 사람들은 말했다.")
	else:
		var parts := PackedStringArray()
		if houses > 0:
			parts.append("집이 잠겼고")
		if fields > 0:
			parts.append("밭이 쓸려 갔고")
		if store:
			parts.append("창고의 양식이 젖었다")
		var s := " ".join(parts)
		if s.ends_with("고"):
			s = s.substr(0, s.length() - 1) + "다"
		v.log_line("물덩이가 터져 둘레가 물바다가 되었다. %s." % s)
	drop_phase = "calm"
	drop_p = 0.0
	drop_size = 0.0
	drop_evac = false
	drop_episodes += 1
	drop_rest = v.t + Balance.CRISIS_REST
	if drop_episodes == 1:
		v.log_line("마을은 그날을 '하늘 물덩이가 떨어진 날'이라 불렀다.")
	elif drop_episodes == Balance.CRISIS_ADAPT:
		v.log_line("세 번을 겪은 마을은 이제 하늘에 물덩이가 맺히자마자 그 아래를 비웠다.")


## 물을 붓는다 (가운데 깊고 가장자리 얕게). 유리에 맺힌 물덩이 = 공기의 김 → 김에서, 모자라면 병의 다른 물에서 고르게
## 덜어 온다 (JarWater.condense — 땅의 물 + 김 = 그대로, F-2 물 보존) → 더한 물의 합
func _pour(v: Village, at: Vector2, rad: float, depth: float) -> float:
	if v.water == null:
		return 0.0
	return v.water.condense(at, rad, depth)


# ═════════════════════════ 먼지 뭉치 ═════════════════════════
func dust_adapted() -> bool:
	return dust_episodes >= Balance.CRISIS_ADAPT


func _dust_tick(v: Village, dt: float) -> void:
	if dust_lid_seen < 0.0:
		dust_lid_seen = v.air.lid_total
	if v.air.lid_total > dust_lid_seen:
		dust_p += (v.air.lid_total - dust_lid_seen) / Balance.DUST_LID_SECS
		dust_lid_seen = v.air.lid_total
	if dust_phase == "calm":
		dust_p = maxf(0.0, dust_p - Balance.DUST_FALL_DAY * dt / Balance.DAY)
	match dust_phase:
		"calm":
			var lead := VillageEra.omen_lead(v)
			if dust_p >= (0.8 if lead > 0.0 else 1.0) and _can_start(v, dust_rest):
				dust_extra = lead
				dust_phase = "omen"
				dust_t = v.t
				v.log_line("열린 하늘 틈으로 들어온 빛 속에 잿빛 가루가 반짝이며 내려왔다.")
				_warn(v, "dust_omen", "{w}, 하늘에서 잿빛 가루가 내려와요.", "하늘에서 잿빛 가루가 내려와요.")
				var el := _awake(v, true)
				if el == null:
					el = _awake(v)
				if el != null:
					v.speak(el, "하늘 틈으로 잿빛 솜이 내려앉는구나…", 7)
		"omen":
			if v.t - dust_t >= Balance.DUST_OMEN + dust_extra:
				if v.is_watching():
					_start_dust(v)
				else:
					dust_t = v.t - Balance.DUST_OMEN - dust_extra + Balance.HOUR
		"roll":
			_dust_roll(v, dt)


func _start_dust(v: Village) -> void:
	dust_phase = "roll"
	dust_t = v.t
	dust_p = 0.0
	var n := rng.randi_range(int(Balance.DUST_SPAWN[0]), int(Balance.DUST_SPAWN[1]))
	for i in n:
		var p := v.center
		for k in 10:
			var a := rng.randf() * TAU
			var q := v.center + Vector2(cos(a), sin(a)) * (4.0 + rng.randf() * 9.0)
			if _inside(v, q, 3.0) and not v.water_at(q.x, q.y):
				p = q
				break
		var c := _spawn("dust", p, v.t)
		c.state = "roll"
		c.size = 0.85 + 0.45 * rng.randf()
		stats["dust"] += 1
	v.crisis("dust", "회색 구름 덩어리가 마을을 굴러다닌다")
	if dust_episodes == 0:
		v.log_line("집채만 한 회색 구름 덩어리가 내려앉아 데굴데굴 굴러다녔다. 길도 밭도 덮였다.")
	else:
		v.log_line("회색 구름 덩어리가 또 굴러왔다.")


func _dust_roll(v: Village, dt: float) -> void:
	var ds := live("dust")
	for c in ds:
		if v.t - c.born >= Balance.DUST_LIFE:          # 그대로 두면 땅에 내려앉아 흙이 됨
			c.state = "gone"
			stats["settled"] += 1
			continue
		var wet := v.water_at(c.x, c.y)
		if wet and c.touched:                            # 뜯기거나 불려 풀어진 뭉치는 물에 젖어 가라앉음
			c.state = "gone"
			continue
		c.cover_b = -1
		for b in v.buildings:
			if b.built and b.type == "농장" and Vector2(b.x, b.y).distance_to(c.pos()) < Balance.DUST_FIELD_R + c.size:
				c.cover_b = b.id
				stats["covered_secs"] += dt
				break
		if wet:                                          # 아직 아무도 손대지 않은 뭉치는 물에 들지 않는다 — 불어난 물에 잠겼으면 물가로 밀려 나온다 (2026-11-11 Q7)
			_dust_ashore(v, c)
		elif c.pos().distance_to(Vector2(c.tx, c.ty)) < 0.2 or rng.randf() < 0.04:
			_dust_target(v, c)
		if not dust_known:                               # 아이가 만져 보고 → 뜯어 실을 잣는다
			for r in v.people:
				if r.is_child() and r.age >= 2.5 and not r.sleeping and Vector2(r.x - c.x, r.y - c.y).length() < Balance.DUST_FIND_R + c.size:
					_learn_dust(v, r, true)
					break
	if not dust_known and v.t - dust_t >= Balance.DUST_LEARN:
		_learn_dust(v, _awake(v, true), false)
	for rid: int in pulling.keys():
		var q := v.person(rid)
		if q == null or q.action != "crisis_pull":
			pulling.erase(rid)
	if live("dust").is_empty():
		dust_phase = "calm"
		dust_episodes += 1
		dust_rest = v.t + Balance.CRISIS_REST
		pulling.clear()
		if dust_episodes == 1:
			v.log_line("회색 구름 덩어리가 모두 사라졌다. 마을은 그날을 '회색 구름이 굴러온 날'이라 불렀다.")
		else:
			v.log_line("회색 구름 덩어리가 또 사라졌다.")


func _dust_target(v: Village, c: CrisisThing) -> void:
	var a := rng.randf() * TAU
	var p := c.pos() + Vector2(cos(a), sin(a)) * (2.0 + rng.randf() * 3.0)
	if not _inside(v, p, 3.0) or v.water_at(p.x, p.y) or p.distance_to(v.center) > 18.0:
		p = c.pos() + (v.center - c.pos()).normalized() * 2.5
	if not c.touched:                                    # 아무도 뜯기 전에 물로 굴러가 사라지지 않게 — 가는 길에 물이 있으면 물가에서 멈춘다 (2026-11-11 Q7 · docs/measure/opening_food_2026-11-11.md 2장)
		p = _dust_dry(v, c.pos(), p)
	c.tx = p.x
	c.ty = p.y


## from에서 to로 곧게 굴러갈 때 물에 닿기 전 마지막 마른 자리 (난수 없음 — 길을 SHORE_STEP 칸씩 짚어 본다)
func _dust_dry(v: Village, from: Vector2, to: Vector2) -> Vector2:
	var d := to - from
	var n := maxi(1, ceili(d.length() / SHORE_STEP))
	var last := from
	for i in range(1, n + 1):
		var q := from + d * (float(i) / float(n))
		if v.water_at(q.x, q.y):
			return last
		last = q
	return to


## 물 위에 놓인 (아직 손대지 않은) 뭉치가 갈 가장 가까운 마른 자리 — 같은 거리면 마을 쪽. 둘레에 없으면 마을 한가운데 쪽 (난수 없음)
func _dust_ashore(v: Village, c: CrisisThing) -> void:
	var best := v.center
	var bd := 1.0e9
	for ring in range(1, SHORE_RINGS + 1):
		for i in SHORE_DIRS:
			var a := TAU * float(i) / float(SHORE_DIRS)
			var q := c.pos() + Vector2(cos(a), sin(a)) * (SHORE_STEP * 2.0 * float(ring))
			if _inside(v, q, 3.0) and not v.water_at(q.x, q.y):
				var dc := q.distance_to(v.center)
				if dc < bd:
					bd = dc
					best = q
		if bd < 1.0e9:
			break
	c.tx = best.x
	c.ty = best.y


func _learn_dust(v: Village, r: Resident, child: bool) -> void:
	if dust_known:
		return
	dust_known = true
	if r == null:
		v.log_line("사람들은 회색 구름 덩어리를 뜯어 실을 자았다.")
		return
	if child:
		v.speak(r, "솜처럼 뜯겨! 실이 돼!", 7)
		v.log_line("%s%s 회색 구름 덩어리를 뜯어 보았다. 솜처럼 뜯겨 실이 되었다." % [r.name, Village.josa(r.name, "이", "가")])
	else:
		v.speak(r, "옛날엔 저런 걸 뜯어 실을 자았단다", 7)
		v.log_line("%s%s 회색 구름 덩어리를 뜯어 실을 잣던 옛말을 떠올렸다." % [r.name, Village.josa(r.name, "이", "가")])


## 밭을 덮은 먼지 뭉치가 있으면 그 밭의 자람이 멈춘다 (Village._update_building)
static func farm_mult(v: Village, b: Building) -> float:
	var s := v.smalls
	if s == null or s.dust_phase != "roll":
		return 1.0
	for c in s.things:
		if c.kind == "dust" and c.state != "gone" and Vector2(b.x, b.y).distance_to(c.pos()) < Balance.DUST_FIELD_R + c.size:
			return 0.0
	return 1.0


## 거인이 뚜껑을 열고 dir 쪽으로 분다 → 먼지 뭉치가 밀려나며 흩어진다 (작아지면 열린 하늘로 날아감). 불린 수
func blow_dust(v: Village, dir: Vector2) -> int:
	if not v.air.lid_open:
		return 0
	var n := 0
	var d := dir.normalized() if dir.length() > 0.01 else Vector2(1, 0)
	for c in things:
		if c.kind != "dust" or c.state == "gone":
			continue
		n += 1
		c.size *= 0.5
		c.touched = true                                 # 거인의 숨에 풀어진 뭉치는 물에 닿으면 가라앉는다
		c.startle = 2.0
		var p := c.pos() + d * Balance.DUST_BLOW_PUSH
		var k := 0
		while not _inside(v, p, 2.5) and k < 6:
			p = c.pos() + d * (Balance.DUST_BLOW_PUSH - k)
			k += 1
		if _inside(v, p, 2.5):
			c.x = p.x
			c.y = p.y
			c.tx = p.x
			c.ty = p.y
		if c.size < Balance.DUST_MIN:
			c.state = "gone"
			stats["blown"] += 1
	if n > 0:
		v.log_line(say_for(v, "{w}의 숨결에 회색 구름 덩어리가 흩어져 날아갔다.", "하늘에서 큰 바람이 불어 회색 구름 덩어리가 흩어져 날아갔다."))
		if v.aware:
			v.bless_all(0.01)
	return n


# ───────────────────────── 주민 결정 (ResidentAI.decide의 한 줄) ─────────────────────────
## 위기 때문에 할 일이 있으면 걸음을 짜고 true. 없으면 false (난수도 쓰지 않음 — 위기가 없으면 결과가 그대로)
static func decide(v: Village, r: Resident) -> bool:
	var s := v.smalls
	if s == null or not s.busy() or r.is_baby():
		return false
	# 물방울: 아래에서 비켜 남 · 구르는 물덩이에서 달아남
	if s.drop_phase == "hang" and s.drop_evac and s.in_drop_zone(Vector2(r.x, r.y), 1.0):
		return s._evac(v, r)
	if s.drop_phase == "roll" and Vector2(r.x - s.drop_x, r.y - s.drop_y).length() < 2.5:
		return s._evac(v, r)
	var night := v.is_night()
	if s.gnat_phase == "swarm":
		if r.id == s.smoker_id:
			if not night and s._smoke(v, r):
				return true
		elif not night and r.age >= 2.5:
			var rad := Balance.GNAT_HIDE_R * (0.5 if s.gnat_adapted() else 1.0)
			for g in s.things:
				if g.kind == "gnat" and (g.state == "fly" or g.state == "eat") and Vector2(r.x - g.x, r.y - g.y).length() < rad:
					return s._hide(v, r)
	if s.dust_phase == "roll" and s.dust_known and r.is_adult() and v.is_work_time() and r.injured_left <= 0.0 and r.sick_left <= 0.0:
		if s.pulling.size() < 3 and s.rng.randf() < (0.5 if r.job < 0 else 0.06):
			return s._pull(v, r)
	return false


func _safe_spot(v: Village, r: Resident) -> Vector2:
	var p := v.fire + Vector2(cos(r.id * 1.1), sin(r.id * 1.1)) * 1.6
	if drop_phase != "calm" and p.distance_to(Vector2(drop_x, drop_y)) < drop_radius() + 1.5:
		var away := (Vector2(r.x, r.y) - Vector2(drop_x, drop_y))
		if away.length() < 0.1:
			away = Vector2(1, 0).rotated(r.id * 2.39)
		p = Vector2(drop_x, drop_y) + away.normalized() * (drop_radius() + 3.0)
		if not _inside(v, p, 2.0) or v.water_at(p.x, p.y):
			p = Vector2(drop_x, drop_y) - away.normalized() * (drop_radius() + 3.0)
	return p


func _evac(v: Village, r: Resident) -> bool:
	var p := _safe_spot(v, r)
	r.action = "crisis_evac"
	r.doing = "하늘의 물덩이를 피해 비켜난 중"
	r.sleeping = false
	r.steps.append(ResidentAI.walk(p.x, p.y))
	r.steps.append(ResidentAI.act(600.0, "sit"))
	return true


func _hide(v: Village, r: Resident) -> bool:
	var hm := v.bld(r.home)
	var p: Vector2
	if hm != null and hm.built:
		p = Vector2(hm.x, hm.y + 0.3)
	else:
		p = v.fire + Vector2(cos(r.id * 1.1), sin(r.id * 1.1)) * 1.4
	r.action = "crisis_hide"
	r.doing = "날개 괴물을 피해 숨은 중"
	if rng.randf() < 0.3:
		v.speak(r, "날개 괴물이다! 숨어!" if rng.randf() < 0.6 else "윙윙 소리가 무서워…", 5)
	r.steps.append(ResidentAI.walk(p.x, p.y))
	r.steps.append(ResidentAI.act(420.0, "sit"))
	stats["hid"] += 1
	return true


## 연기 피우는 사람: 날벌레 곁에 모깃불 (통나무 1)
func _smoke(v: Village, r: Resident) -> bool:
	if r.sick_left > 0.0 or r.injured_left > 0.0 or float(v.stock.get("통나무", 0.0)) < Balance.GNAT_SMOKE_LOG:
		return false
	var best: CrisisThing = null
	var bd := 1.0e9
	for g in things:
		if g.kind == "gnat" and (g.state == "fly" or g.state == "eat"):
			var d := Vector2(r.x - g.x, r.y - g.y).length()
			if d < bd:
				bd = d
				best = g
	if best == null:
		return false
	var at := Vector2(best.tx, best.ty)
	if best.state == "eat":
		var b := v.bld(best.target_b) if best.target_b >= 0 else v.store()
		if b != null:
			at = Vector2(b.x, b.y) + Vector2(1.2, 0.9)
	r.action = "crisis_smoke"
	r.last_action = "crisis_smoke"
	r.doing = "모깃불을 피워 날개 괴물을 쫓는 중"
	r.steps.append(ResidentAI.walk(at.x, at.y))
	r.steps.append(ResidentAI.act(60.0, "torch", ResidentAI.op("crisis_smoke", {"x": at.x, "y": at.y})))
	return true


## 먼지 뭉치를 뜯어 실을 잣는다
func _pull(v: Village, r: Resident) -> bool:
	var best: CrisisThing = null
	var bd := 1.0e9
	for c in things:
		if c.kind == "dust" and c.state != "gone":
			var d := Vector2(r.x - c.x, r.y - c.y).length()
			if d < bd:
				bd = d
				best = c
	if best == null:
		return false
	var off := Vector2(r.x - best.x, r.y - best.y)
	var p := best.pos() + (off.normalized() if off.length() > 0.05 else Vector2(1, 0)) * (best.size * 0.9 + 0.3)
	pulling[r.id] = best.id
	r.action = "crisis_pull"
	r.last_action = "crisis_pull"
	r.doing = "회색 구름을 뜯어 실을 잣는 중"
	r.steps.append(ResidentAI.walk(p.x, p.y))
	r.steps.append(ResidentAI.act(Balance.DUST_PULL_TIME, "work", ResidentAI.op("crisis_pull", {"id": best.id, "rid": r.id}), false, ResidentAI.op("crisis_pull_undo", {"rid": r.id})))
	return true


## 주민의 할 일 묶음 (ResidentAI.run_op가 "crisis_*"를 넘겨줌) — 저장해도 그대로 이어지게 값만
func run_op(v: Village, r: Resident, o: Dictionary) -> void:
	match String(o["op"]):
		"crisis_smoke":
			if float(v.stock.get("통나무", 0.0)) < Balance.GNAT_SMOKE_LOG:
				return
			v.stock["통나무"] = float(v.stock["통나무"]) - Balance.GNAT_SMOKE_LOG
			smokes.append({"x": float(o["x"]), "y": float(o["y"]), "until": v.t + Balance.GNAT_SMOKE_TIME})
			v.air.smoke = minf(1.0, v.air.smoke + Balance.GNAT_SMOKE_AIR)      # 연기는 닫힌 병에 갇힌다
			stats["smokes"] += 1
			r.skills["연기 피우기"] = minf(Balance.SKILL_MAX, float(r.skills.get("연기 피우기", 0.0)) + 0.15 * r.talent)
			if stats["smokes"] == 1:
				v.speak(r, "연기다! 저리 가!", 5)
		"crisis_pull":
			pulling.erase(int(o["rid"]))
			for c in things:
				if c.id == int(o["id"]) and c.kind == "dust" and c.state != "gone":
					c.size -= Balance.DUST_PULL
					c.touched = true                         # 한 번 뜯긴 뭉치는 풀어져서 물에 닿으면 가라앉는다 (그 전엔 물가에서 멈춘다)
					v.stock["먼지 실"] = float(v.stock.get("먼지 실", 0.0)) + Balance.DUST_YARN     # v5: 양 없이 양털이 생기지 않게 — 제 물건 '먼지 실'
					stats["yarn"] += Balance.DUST_YARN
					stats["pulled"] += 1
					if stats["pulled"] == 1:
						v.log_line("회색 구름을 뜯어 자은 먼지 실은 뜻밖에 따뜻했다.")
					if c.size < Balance.DUST_MIN:
						c.state = "gone"
					return
		"crisis_pull_undo":
			pulling.erase(int(o["rid"]))
		_:
			push_error("SmallCrises.run_op: 모르는 할 일 %s" % o["op"])


# ───────────────────────── 비운 동안 · 병 돌리기 ─────────────────────────
## 귀환 편지의 '기다리는 것' (CatchUp)
func waiting_lines() -> Array:
	var out: Array = []
	if drop_phase == "hang":
		out.append("하늘에 커다란 물방울이 매달려 있어요.")
	if gnat_phase == "omen":
		out.append("하늘 높이 날개 달린 것이 윙윙 맴돌아요.")
	if dust_phase == "omen":
		out.append("하늘에서 잿빛 가루가 내려와요.")
	return out


func rotate() -> void:
	for c in things:
		var p := JarWater.rot_pt(Vector2(c.x, c.y))
		var q := JarWater.rot_pt(Vector2(c.tx, c.ty))
		c.x = p.x
		c.y = p.y
		c.px = p.x
		c.py = p.y
		c.tx = q.x
		c.ty = q.y
	for s: Dictionary in smokes:
		var sp := JarWater.rot_pt(Vector2(float(s["x"]), float(s["y"])))
		s["x"] = sp.x
		s["y"] = sp.y
	var d := JarWater.rot_pt(Vector2(drop_x, drop_y))
	var dt2 := JarWater.rot_pt(Vector2(drop_tx, drop_ty))
	drop_x = d.x
	drop_y = d.y
	drop_px = d.x
	drop_py = d.y
	drop_tx = dt2.x
	drop_ty = dt2.y
	drop_trail.clear()


# ───────────────────────── 개발·시험용 ─────────────────────────
func force_gnats(v: Village, carry := "") -> void:
	gnat_rest = 0.0
	gnat_phase = "calm"
	var keep := v.t
	if v.t < Balance.MOLD_FIRST_DAY * Balance.DAY:
		v.t = Balance.MOLD_FIRST_DAY * Balance.DAY
	gnat_in(v)
	v.t = keep
	for g in live("gnat"):
		if carry != "":
			g.carry = carry
	_start_gnats(v)


func force_drop(v: Village) -> void:
	drop_rest = 0.0
	drop_extra = 0.0
	_start_drop(v)


func force_dust(v: Village) -> void:
	dust_rest = 0.0
	dust_extra = 0.0
	_start_dust(v)


# ───────────────────────── 저장 (docs/SAVE.md) ─────────────────────────
func to_dict() -> Dictionary:
	var d := SaveCodec.props(self, ["things"])
	var tl := []
	for c in things:
		tl.append(c.to_dict())
	d["things"] = tl
	return d


static func from_dict(d: Dictionary) -> SmallCrises:
	var s := SmallCrises.new(0)
	SaveCodec.apply(s, d, ["things"])
	s.things.clear()
	for cd: Dictionary in d.get("things", []):
		s.things.append(CrisisThing.from_dict(cd))
	return s
