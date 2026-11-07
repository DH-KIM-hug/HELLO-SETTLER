## 곰팡이 무리 — docs/WORLD_EVENTS.md 2.1 (대표 위기) · 2.3 (압력 · 세 번 겪으면 익숙해짐) · HEALTH.md 2.5b (곰팡이약).
## 화면과 분리된 순수 로직. Village.mold가 하나 가진다. 난수는 자기 흐름(rng) 하나만 (×1·×8 같음, 다른 흐름을 흔들지 않음).
##
## 흐름: 압력 (김 × 따뜻함이 높은 동안 쌓임 — 사흘쯤) → 조짐 (반나절: 유리가 뿌예지고 "빵에 푸른 털이 났어")
##       → 무리 (창고 곁 그늘·젖은 땅에서 3~6마리, 1~3일 한창) → 잦아듦 (쪼그라들어 흩어짐) → 쉼 (반나절↑).
## 무리가 하는 일: 창고로 몰려가 식량·통나무를 갉아 썩힘 (하루 5%), 습하면 나뉨 (하루 ×1.5), 둘레 주민 배앓이·기침병 ×2.
## 약점: 볕 드는 쪽에서 느려짐 · 횃불에 쪼그라듦 · 소금에 녹음 · 뚜껑을 열면 마른 공기에 쪼그라들어 흩어짐.
## 주민: 처음엔 숨는다 → 놀란 일이 쌓이면 촌장이 '곰팡이 쫓는 사람'을 정해 횃불(통나무 1)·소금으로 몰아냄 (숙련).
##       세 번 겪은 마을은 피해 절반. 누룩곰팡이는 아이가 발견하면 길들임 (빵 ×1.3). 푸른곰팡이를 횃불로 쫓으면 푸른 가루 →
##       곰팡이약 (일 없는 어른이 푸른 가루 + 빵으로 만듦). 약은 곪은 상처·기침병·역병에만 듣는다 — 마을은 써 보고 배운다.
## 이 파일 밖의 고리: Village.step (step) · Health.tick (medicine · ill_mult) · ResidentAI.decide (decide) · Village._update_building (빵 ×1.3).
class_name Mold
extends RefCounted

var rng := RandomNumberGenerator.new()
var pressure := 0.0                   # 0~1+ — 1이 넘으면 조짐
var phase := "calm"                   # calm · omen · swarm
var phase_t := 0.0                    # 이 단계가 시작된 병 시각
var peak_end := 0.0                   # 한창이 끝나는 병 시각 (그 뒤 잦아듦)
var rest_until := 0.0
var blobs: Array[MoldBlob] = []
var next_id := 1
var episodes := 0                     # 겪고 지나간 무리 수 (세 번 → 익숙해짐)
var startles := 0                     # 주민이 놀란 일 (쌓이면 촌장이 쫓는 사람을 정함)
var chaser_id := -1                   # 곰팡이 쫓는 사람
var maker_id := -1                    # 지금 곰팡이약을 만드는 사람
var omen_fog := 0.0                   # 조짐의 뿌연 유리 0~1 (화면)
var omen_extra := 0.0                 # 이번 조짐이 망루 덕에 먼저 온 만큼 (A6 — 조짐이 그만큼 길다)
var koji_known := false               # 누룩곰팡이를 알아봄 (아이가 발견)
var koji_tamed := false               # 길들인 누룩곰팡이가 있다 → 빵 ×1.3
var med_known := false                # 푸른 가루가 약이 된다는 걸 앎
var med_learned := false              # 약이 어느 병에 듣는지 앎 (몇 번 실패한 뒤)
var med_fail := 0
var teal_defeats := 0
var swarm_kind := ""                  # 이번 무리의 색 — 곰팡이는 다른 색을 싫어해 한 번에 한 색만 (WORLD_EVENTS 2.1)
var lid_helped := false               # 무리가 있을 때 하늘이 열려 무리가 흩어진 적이 있다 (노인의 귀띔)
var tried: Dictionary = {}            # 주민 id → 약을 써 본 병의 sick_since (한 번 앓을 때 한 번)
var stats := {"spawned": 0, "split": 0, "defeated": 0, "melted": 0, "dried": 0, "rot_food": 0.0, "rot_logs": 0.0,
	"powder": 0, "med_made": 0.0, "med_used": 0, "med_ok": 0, "hid": 0, "torch": 0}
var _acc := 0.0


func _init(seed_v: int) -> void:
	rng.seed = seed_v * 7333 + 911


## 주민 결정에 끼어들 일이 있나 (없으면 아무 난수도 쓰지 않는다 — 곰팡이 없는 병은 결과가 그대로)
func busy() -> bool:
	return not blobs.is_empty() or (med_known and maker_id < 0)


func wild() -> Array[MoldBlob]:
	var out: Array[MoldBlob] = []
	for b in blobs:
		if b.state != "tamed" and b.state != "gone":
			out.append(b)
	return out


func adapted() -> bool:
	return episodes >= Balance.MOLD_ADAPT


# ───────────────────────── 걸음 ─────────────────────────
static func step(v: Village, dt: float) -> void:
	var m := v.mold
	m._move(v, dt)
	m._acc += dt
	while m._acc >= Balance.AIR_TICK - 1e-6:
		m._acc -= Balance.AIR_TICK
		m._tick(v, Balance.AIR_TICK)


## 걸음마다: 털뭉치가 통통 튀며 움직인다 (난수 없음 — 가려는 곳은 60초 걸음이 정함)
func _move(v: Village, dt: float) -> void:
	if blobs.is_empty():
		return
	var lid := v.air.lid_open
	for b in blobs:
		b.px = b.x
		b.py = b.y
		if b.startle > 0.0:
			b.startle = maxf(0.0, b.startle - dt)
		if b.burnt > 0.0:
			b.burnt = maxf(0.0, b.burnt - dt)
		if b.state == "gone":
			continue
		if lid and b.state != "tamed":            # 마른 공기 → 쪼그라들어 흩어짐
			b.size -= Balance.MOLD_DRY_SHRINK * dt / 60.0
			if b.state != "flee":
				b.state = "flee"
				_flee_target(v, b)
				b.startle = 2.0
				lid_helped = true
			if b.size < Balance.MOLD_SIZE_MIN:
				b.state = "gone"
				stats["dried"] += 1
				continue
		var to := Vector2(b.tx - b.x, b.ty - b.y)
		var d := to.length()
		if d < 0.05:
			continue
		var sun := maxf(0.0, v.water.sun_at(b.x, b.y))
		var sp := Balance.MOLD_SPEED * (1.0 - Balance.MOLD_SUN_SLOW * sun) * (1.6 if b.state == "flee" else 1.0)
		if b.state == "gnaw" or b.state == "tamed":
			sp *= 0.35
		var mv := minf(d, sp * dt)
		b.x += to.x / d * mv
		b.y += to.y / d * mv
		b.facing = atan2(to.x, to.y)
		if b.state == "flee" and d - mv < 0.1 and phase != "swarm":
			b.state = "gone"                     # 잦아듦: 흩어져 사라짐


func _store_pos(v: Village) -> Vector2:
	var s := v.store()
	return Vector2(s.x, s.y)


func _flee_target(v: Village, b: MoldBlob) -> void:
	var away := Vector2(b.x - v.center.x, b.y - v.center.y)
	if away.length() < 0.5:
		away = Vector2(cos(b.id * 2.3), sin(b.id * 2.3))
	var p := Vector2(b.x, b.y) + away.normalized() * 8.0
	var lim := v.water.radius() - 3.0
	if (water_free(v, p) == false) or p.length() > lim:
		p = Vector2(b.x, b.y) + away.normalized() * 4.0
	b.tx = p.x
	b.ty = p.y


static func water_free(v: Village, p: Vector2) -> bool:
	return v.water.inside(p.x, p.y, 2.0) and not v.water_at(p.x, p.y)


# ───────────────────────── 60초 걸음 ─────────────────────────
func _tick(v: Village, dt: float) -> void:
	if maker_id >= 0:                         # 약 만들던 사람이 죽거나 분가해 떠났으면 풀어 줌
		var mk := v.person(maker_id)
		if mk == null or mk.action != "mold_med":
			maker_id = -1
	_pressure(v, dt)
	match phase:
		"calm":
			omen_fog = maxf(0.0, omen_fog - dt / (0.25 * Balance.DAY))
			var lead := VillageEra.omen_lead(v)          # 망루: 조짐이 반나절 먼저 (A6) — 압력 문턱을 그만큼 낮추고 조짐을 그만큼 길게
			if v.t >= Balance.MOLD_FIRST_DAY * Balance.DAY and v.t >= rest_until and pressure >= 1.0 - lead / (Balance.MOLD_PRESSURE_DAYS * Balance.DAY) \
					and SmallCrises.active_count(v) < Balance.CRISIS_MAX_AT_ONCE:     # 위기는 동시에 둘까지 (WORLD_EVENTS 2.3 — 작은 위기 셋과 합쳐)
				omen_extra = lead if pressure < 1.0 else 0.0
				_start_omen(v)
		"omen":
			omen_fog = minf(1.0, omen_fog + dt / (0.3 * Balance.DAY))
			if hw_now(v) < Balance.MOLD_PRESSURE_AT:     # 거인이 김을 빼면 (뚜껑) 조짐이 빨리 걷힌다
				pressure = maxf(0.0, pressure - dt / (0.1 * Balance.DAY))
			if pressure < 0.5:                    # 거인이 김을 빼서 조짐이 걷힘
				phase = "calm"
				v.log_line("뿌옇던 하늘이 맑아졌다. 빵에 났던 털도 더 번지지 않았다.")
			elif v.t - phase_t >= Balance.MOLD_OMEN + omen_extra:
				if v.is_watching():
					_start_swarm(v)
				else:                             # 거인이 없을 때는 새 위기가 시작되지 않고 조짐에서 기다린다 (SAVE.md 3 · 기획서 14장)
					phase_t = v.t - Balance.MOLD_OMEN - omen_extra + Balance.HOUR     # → 거인이 돌아와 볼 수 있게 된 뒤 한 시간쯤에 온다
		"swarm":
			omen_fog = maxf(0.4, omen_fog - dt / Balance.DAY) if v.t < peak_end else maxf(0.0, omen_fog - dt / (0.3 * Balance.DAY))
			_swarm_tick(v, dt)
	if koji_tamed:
		for b in blobs:
			if b.state == "tamed":
				_tamed_target(v, b)


## 압력: 마을 자리의 김 × 따뜻함
func _pressure(v: Village, dt: float) -> void:
	var tp := Health.base_temp(v, v.t) + Balance.SPOT_WARM * v.water.warm_at(v.center.x, v.center.y)
	tp += v.air.temp_shift(tp)
	var warm := clampf((tp - Balance.MOLD_WARM_FROM) / Balance.MOLD_WARM_DIV, 0.0, 1.3)
	var hw := v.air.humid * warm
	if hw > Balance.MOLD_PRESSURE_AT:
		var f := clampf((hw - Balance.MOLD_PRESSURE_AT) / (Balance.MOLD_PRESSURE_FULL - Balance.MOLD_PRESSURE_AT), 0.0, 1.0)
		pressure += f * dt / (Balance.MOLD_PRESSURE_DAYS * Balance.DAY)
	else:
		pressure = maxf(0.0, pressure - dt / (Balance.MOLD_PRESSURE_FALL * Balance.DAY))
	if phase == "swarm":
		pressure = minf(pressure, 1.0)


func hw_now(v: Village) -> float:
	var tp := Health.base_temp(v, v.t) + Balance.SPOT_WARM * v.water.warm_at(v.center.x, v.center.y)
	tp += v.air.temp_shift(tp)
	return v.air.humid * clampf((tp - Balance.MOLD_WARM_FROM) / Balance.MOLD_WARM_DIV, 0.0, 1.3)


func _start_omen(v: Village) -> void:
	phase = "omen"
	phase_t = v.t
	swarm_kind = _roll_kind()
	var col := color_word(swarm_kind)
	var teller := _awake_teller(v)
	if teller != null:
		v.speak(teller, "빵에 %s 털이 났어!" % col, 7)
	v.warnings.append({"t": v.t, "kind": "mold_omen", "text": (WatcherName.fill(v, "{w}, 빵에 %s 털이 났어요.") if v.aware else "빵에 %s 털이 났어요.") % col})
	if omen_extra > 0.0:
		v.log_line("망루에서 먼 하늘이 뿌옇게 흐려지는 것이 먼저 보였다. 사람들은 서둘러 빵을 덮었다.")
	v.log_line("창고의 빵에 %s 털이 돋았다. 하늘이 뿌옇게 흐려졌다." % col)
	if not v.is_watching():
		v.log_line("유리에 김이 서리기 시작했다.")
	if lid_helped:                         # 노인의 귀띔 (WORLD_EVENTS 6장) — 해결 방법을 직접 말하지 않는다
		for r in v.people:
			if r.is_elder() and not r.sleeping:
				v.speak(r, "예전에 하늘이 열렸을 때 안개가 걷혔지…", 7)
				break


func _awake_teller(v: Village) -> Resident:
	for r in v.people:
		if not r.sleeping and r.sick_left <= 0.0 and r.age >= 2.5:
			return r
	return null


func _start_swarm(v: Village) -> void:
	phase = "swarm"
	phase_t = v.t
	peak_end = v.t + lerpf(float(Balance.MOLD_PEAK[0]), float(Balance.MOLD_PEAK[1]), rng.randf())
	var n := rng.randi_range(int(Balance.MOLD_SPAWN[0]), int(Balance.MOLD_SPAWN[1]))
	var spots := _damp_spots(v, n)
	if swarm_kind == "":
		swarm_kind = _roll_kind()
	for p: Vector2 in spots:
		_spawn(v, p, swarm_kind, 0.85 + 0.3 * rng.randf())   # 한 무리는 한 색
	if episodes >= 1 and chaser_id < 0:     # 한 번 겪은 마을: 촌장이 바로 쫓는 사람을 정한다 (처음엔 숨기만)
		_name_chaser(v)
	v.crisis("mold", "털뭉치 괴물 떼가 창고로 몰려왔다")
	if episodes == 0:
		v.log_line("그늘진 창고 뒤에서 털뭉치 괴물들이 통통 튀어나왔다. 주민 무릎만 한 것들이 떼로 몰려다녔다.")
	else:
		v.log_line("털뭉치 괴물들이 또 왔다. %d번째였다." % (episodes + 1))


## 창고 둘레의 그늘·젖은 땅 (젖음 − 볕) — 가장 습한 곳부터 n자리
func _damp_spots(v: Village, n: int) -> Array[Vector2]:
	var sp := _store_pos(v)
	var cands: Array = []
	for i in 24:
		var a := rng.randf() * TAU
		var d := 2.5 + rng.randf() * 6.0
		var p := sp + Vector2(cos(a), sin(a)) * d
		if not water_free(v, p):
			continue
		var score := v.wetness(p.x, p.y) - 0.5 * v.water.sun_at(p.x, p.y) + 0.1 * rng.randf()
		cands.append([score, p])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	var out: Array[Vector2] = []
	for c: Array in cands:
		if out.size() >= n:
			break
		out.append(c[1])
	while out.size() < n:
		out.append(sp + Vector2(cos(out.size() * 1.7), sin(out.size() * 1.7)) * 3.0)
	return out


## 털 색 말 (조짐 대사·연대기)
static func color_word(kind: String) -> String:
	match kind:
		"검은": return "검은"
		"푸른": return "푸른"
		"흰": return "하얀"
		"누룩": return "노란"
	return "푸른"


func _roll_kind() -> String:
	var u := rng.randf()
	for i in Balance.MOLD_KINDS.size():
		u -= float(Balance.MOLD_KIND_W[i])
		if u < 0.0:
			return Balance.MOLD_KINDS[i]
	return Balance.MOLD_KINDS[0]


func _spawn(v: Village, p: Vector2, kind: String, size: float) -> MoldBlob:
	var b := MoldBlob.new()
	b.id = next_id
	next_id += 1
	b.kind = kind
	b.x = p.x
	b.y = p.y
	b.px = p.x
	b.py = p.y
	b.tx = p.x
	b.ty = p.y
	b.size = size
	b.born = v.t
	b.state = "wander"
	blobs.append(b)
	stats["spawned"] += 1
	return b


func _swarm_tick(v: Village, dt: float) -> void:
	var sp := _store_pos(v)
	var waning := v.t >= peak_end
	# 사라진 것 정리, 쫓는 사람이 죽었으면 다시
	blobs = blobs.filter(func(b: MoldBlob) -> bool: return b.state != "gone")
	if chaser_id >= 0 and v.person(chaser_id) == null:
		chaser_id = -1
	var n_gnaw := 0
	var n_wild := 0
	for b in blobs:
		if b.state == "tamed":
			continue
		n_wild += 1
		if waning and b.state != "flee":       # 잦아듦: 흩어져 사라짐
			b.state = "flee"
			_flee_target(v, b)
		if b.state == "flee":
			b.size -= 0.15 * dt / 60.0 * (1.0 if waning else 0.3)
			if b.size < Balance.MOLD_SIZE_MIN:
				b.state = "gone"
			elif not waning and not v.air.lid_open and Vector2(b.tx - b.x, b.ty - b.y).length() < 0.2:
				b.state = "wander"             # 횃불에 쫓겼다가 다시 창고로
			continue
		var ds := Vector2(b.x - sp.x, b.y - sp.y).length()
		if b.state == "wander":
			if ds < 3.1:
				b.state = "gnaw"
			else:
				var a := rng.randf() * TAU
				var j := sp + Vector2(cos(a), sin(a)) * (2.3 + rng.randf() * 0.8)
				b.tx = j.x
				b.ty = j.y
		if b.state == "gnaw":
			n_gnaw += 1
			var a2 := rng.randf() * TAU            # 창고 둘레를 뒤적임
			var j2 := sp + Vector2(cos(a2), sin(a2)) * (2.2 + rng.randf() * 0.8)
			b.tx = j2.x
			b.ty = j2.y
		# 습하면 나뉨 (하루 ×1.5)
		if not waning and v.air.humid >= Balance.MOLD_SPLIT_HUMID and blobs.size() < Balance.MOLD_MAX:
			if rng.randf() < log(Balance.MOLD_SPLIT_DAY) * dt / Balance.DAY:
				var a3 := rng.randf() * TAU
				var nb := _spawn(v, Vector2(b.x, b.y) + Vector2(cos(a3), sin(a3)) * 0.6, b.kind, 0.6)
				nb.tx = b.tx
				nb.ty = b.ty
				stats["split"] += 1
	_rot(v, n_gnaw, dt)
	_startle_and_hide(v)
	_koji(v)
	if n_wild == 0:
		_end_swarm(v)


## 창고의 식량·통나무를 갉아 썩힘 (하루 5% — 모인 수에 비례, 익숙해지면 절반)
func _rot(v: Village, n_gnaw: int, dt: float) -> void:
	if n_gnaw <= 0:
		return
	var rate := Balance.MOLD_ROT_DAY * minf(1.0, float(n_gnaw) / Balance.MOLD_ROT_FULL) * (0.5 if adapted() else 1.0)
	var f := rate * dt / Balance.DAY
	for k: String in Balance.STORE_FOODS:
		var have := float(v.stock.get(k, 0.0))
		if have > 0.0:
			v.stock[k] = have * (1.0 - f)
			stats["rot_food"] += have * f
	var logs := float(v.stock.get("통나무", 0.0))
	if logs > 0.0:
		v.stock["통나무"] = logs * (1.0 - f)
		stats["rot_logs"] += logs * f


## 가까이 온 주민 — 털이 곤두서고 주민은 놀란다. 쌓이면 촌장이 쫓는 사람을 정한다
func _startle_and_hide(v: Village) -> void:
	var r2 := Balance.MOLD_STARTLE_R * Balance.MOLD_STARTLE_R
	var any := false
	for b in blobs:
		if b.state == "tamed" or b.state == "gone":
			continue
		for r in v.people:
			if r.sleeping or r.age < 2.5 or r.id == chaser_id:
				continue
			if Vector2(r.x - b.x, r.y - b.y).length_squared() < r2:
				b.startle = 2.5
				any = true
				if episodes == 0 and chaser_id < 0:
					v.raise_fear(r, 0.01)
				break
	if any:
		startles += 1                         # 놀란 일 (60초에 한 번까지)
	if chaser_id < 0 and (episodes >= 1 or startles >= Balance.MOLD_CHASER_AFTER):
		_name_chaser(v)


## 촌장이 '곰팡이 쫓는 사람'을 정함 — 숙련이 가장 높은(없으면 가장 담대한) 어른
func _name_chaser(v: Village) -> void:
	var best: Resident = null
	var bs := -INF
	var ch := v.chief()
	for r in v.people:
		if not r.is_adult() or r.sick_left > 0.0 or r == ch:
			continue
		var s := float(r.skills.get(Balance.MOLD_SKILL, 0.0)) * 10.0 - r.fear * 5.0 + (0.5 if r.job < 0 else 0.0) + 0.01 * rng.randf()
		if s > bs:
			bs = s
			best = r
	if best == null:
		best = ch
	if best == null:
		return
	chaser_id = best.id
	if ch != null and ch != best:
		v.speak(ch, "%s, 횃불을 들고 저것들을 쫓아내게!" % best.name, 7)
	v.speak(best, "제가 쫓아낼게요!", 6)
	if episodes == 0:
		v.log_line("촌장이 %s에게 횃불을 들려 털뭉치를 쫓게 했다. 마을에 '곰팡이 쫓는 사람'이 생겼다." % best.name)
	ResidentAI.cancel(v, best)


## 누룩곰팡이 — 아이가 가까이서 보면 발견, 그 뒤로는 쫓지 않고 길들인다
func _koji(v: Village) -> void:
	for b in blobs:
		if b.kind != "누룩" or b.state == "gone":
			continue
		if not koji_known:
			for r in v.people:
				if r.is_child() and r.age >= 2.5 and not r.sleeping and Vector2(r.x - b.x, r.y - b.y).length() < Balance.KOJI_FIND_R:
					koji_known = true
					v.note_discovery("koji", r)
					v.speak(r, "노란 털이 묻은 반죽이 부풀었어!", 7)
					v.log_line("%s%s 노란 털뭉치가 스친 빵 반죽이 부푸는 것을 보았다. 노란 곰팡이는 나쁜 것이 아니었다." % [r.name, Village.josa(r.name, "이", "가")])
					break
		if koji_known and b.state != "tamed":
			b.state = "tamed"
			b.size = maxf(b.size, 0.8)
			_tamed_target(v, b)
			if not koji_tamed:
				koji_tamed = true
				v.log_line("마을은 노란 털뭉치를 빵 굽는 곳 곁에 두고 길렀다. 빵이 더 잘 부풀었다.")


func _tamed_target(v: Village, b: MoldBlob) -> void:
	var home := _store_pos(v)
	for bd in v.buildings:
		if bd.built and bd.type == "빵집":
			home = Vector2(bd.x, bd.y)
			break
	var a := float(b.id) * 1.3 + v.t / 900.0
	b.tx = home.x + 1.6 + cos(a) * 0.35
	b.ty = home.y + 0.8 + sin(a) * 0.35


func _end_swarm(v: Village) -> void:
	phase = "calm"
	swarm_kind = ""
	episodes += 1
	pressure = 0.0
	rest_until = v.t + Balance.MOLD_REST
	var nm := "털뭉치가 물러간 날"
	if stats["defeated"] + stats["melted"] > 0 and episodes == 1:
		nm = "횃불의 날"
	v.log_line("털뭉치 괴물들이 물러갔다. 마을은 그날을 '%s'이라 불렀다." % nm if episodes == 1 else "털뭉치 괴물들이 또 물러갔다.")
	if episodes == Balance.MOLD_ADAPT:
		v.log_line("세 번을 겪은 마을은 이제 털뭉치를 두려워하지 않았다. 창고 곁에 횃불과 소금을 늘 두었다.")


# ───────────────────────── 주민 결정 (ResidentAI.decide의 한 줄) ─────────────────────────
## 곰팡이 때문에 할 일이 있으면 걸음을 짜고 true. 없으면 false (난수도 쓰지 않음)
static func decide(v: Village, r: Resident) -> bool:
	var m := v.mold
	if m == null or not m.busy() or r.is_baby():
		return false
	var night := v.is_night()
	if r.id == m.chaser_id:
		return not night and m._chase(v, r)
	# 처음 겪는 마을: 가까이 온 털뭉치를 보면 집으로 숨는다
	if m.chaser_id < 0 and m.episodes == 0 and not night and r.age >= 2.5:
		var b := m._nearest_wild(Vector2(r.x, r.y), Balance.MOLD_HIDE_R, false)
		if b != null and m._hide(v, r):
			return true
	# 곰팡이약 만들기 — 약초꾼이 있으면 약초꾼이 (A6), 없으면 일 없는 어른
	var hb := VillageEra.herbalist(v)
	if m.med_known and m.maker_id < 0 and r.is_adult() and v.is_work_time() and r.injured_left <= 0.0 and (hb == null or hb == r):
		if float(v.stock.get(Balance.BLUE_POWDER, 0.0)) >= 1.0 and float(v.stock.get(Balance.MOLD_MED, 0.0)) < Balance.MOLD_MED_KEEP + v.people.size() / 5.0:
			if (float(v.stock.get("빵", 0.0)) >= 1.0 or float(v.stock.get("건량", 0.0)) >= 2.0) and m.rng.randf() < (0.6 if (r.job < 0 or hb == r) else 0.08):
				return m._make_med(v, r)
	return false


func _nearest_wild(p: Vector2, rad: float, skip_koji: bool) -> MoldBlob:
	var best: MoldBlob = null
	var bd := rad
	for b in blobs:
		if b.state == "tamed" or b.state == "gone" or (skip_koji and b.kind == "누룩" and koji_known):
			continue
		var d := Vector2(b.x - p.x, b.y - p.y).length()
		if d < bd:
			bd = d
			best = b
	return best


func _hide(v: Village, r: Resident) -> bool:
	var hm := v.bld(r.home)
	var p: Vector2
	if hm != null and hm.built:
		p = Vector2(hm.x, hm.y + 0.3)
	else:
		p = v.fire + Vector2(cos(r.id * 1.1), sin(r.id * 1.1)) * 1.4
	r.action = "mold_hide"
	r.doing = "털뭉치 괴물을 피해 숨은 중"
	if rng.randf() < 0.35:
		v.speak(r, "털뭉치 괴물이다!" if rng.randf() < 0.6 else "무서워… 저리 가!", 5)
	r.steps.append(ResidentAI.walk(p.x, p.y))
	r.steps.append(ResidentAI.act(480.0, "sit"))
	stats["hid"] += 1
	return true


## 곰팡이 쫓는 사람: 횃불(통나무 1)을 들고 가장 가까운 털뭉치에게 → 휘둘러 쪼그라뜨림. 소금이 있으면 뿌려 녹임
func _chase(v: Village, r: Resident) -> bool:
	if r.sick_left > 0.0 or r.injured_left > 0.0:
		return false
	var b := _nearest_wild(Vector2(r.x, r.y), 1.0e9, true)
	if b == null:
		return false
	var has_salt := float(v.stock.get("소금", 0.0)) >= 1.0
	if not has_salt and float(v.stock.get("통나무", 0.0)) < Balance.MOLD_TORCH_LOG:
		return false
	r.action = "mold_chase"
	r.last_action = "mold_chase"
	r.doing = "횃불로 털뭉치를 쫓는 중" if not has_salt else "소금을 들고 털뭉치를 쫓는 중"
	var id := b.id
	var p := Vector2(b.x, b.y)
	var off := Vector2(r.x - b.x, r.y - b.y)
	if off.length() > 0.01:
		p += off.normalized() * 0.55
	r.steps.append(ResidentAI.walk(p.x, p.y))
	r.steps.append(ResidentAI.act(12.0, "torch", ResidentAI.op("mold_strike", {"id": id})))
	return true


## 주민의 할 일 묶음 (ResidentAI.run_op가 "mold_*"를 넘겨줌) — 저장해도 그대로 이어지게 Callable 대신 값만
func run_op(v: Village, r: Resident, o: Dictionary) -> void:
	match String(o["op"]):
		"mold_strike":
			_strike(v, r, int(o["id"]))
		"mold_med_done":
			maker_id = -1
			if float(v.stock.get(Balance.BLUE_POWDER, 0.0)) < 1.0:
				return
			if float(v.stock.get("빵", 0.0)) >= 1.0:
				v.stock["빵"] = float(v.stock["빵"]) - 1.0
			elif float(v.stock.get("건량", 0.0)) >= 2.0:
				v.stock["건량"] = float(v.stock["건량"]) - 2.0
			else:
				return
			v.stock[Balance.BLUE_POWDER] = float(v.stock[Balance.BLUE_POWDER]) - 1.0
			v.stock[Balance.MOLD_MED] = float(v.stock.get(Balance.MOLD_MED, 0.0)) + Balance.MOLD_MED_OUT
			stats["med_made"] += Balance.MOLD_MED_OUT
			if stats["med_made"] <= Balance.MOLD_MED_OUT:
				v.log_line("%s%s 푸른 가루를 빵에 개어 첫 '곰팡이약'을 만들었다." % [r.name, Village.josa(r.name, "이", "가")])
		"mold_med_undo":
			if maker_id == int(o["rid"]):
				maker_id = -1
		_:
			push_error("Mold.run_op: 모르는 할 일 %s" % o["op"])


func _strike(v: Village, r: Resident, id: int) -> void:
	var b: MoldBlob = null
	for q in blobs:
		if q.id == id and q.state != "gone" and q.state != "tamed":
			b = q
	if b == null or Vector2(b.x - r.x, b.y - r.y).length() > 1.6:
		return                                 # 놓쳤다 — 다음 결정에서 다시 쫓는다
	var sk := float(r.skills.get(Balance.MOLD_SKILL, 0.0))
	r.skills[Balance.MOLD_SKILL] = minf(Balance.SKILL_MAX, sk + 0.15 * r.talent)
	b.startle = 2.5
	if float(v.stock.get("소금", 0.0)) >= 1.0:   # 소금을 뿌리면 녹는다
		v.stock["소금"] = float(v.stock["소금"]) - 1.0
		b.state = "gone"
		stats["melted"] += 1
		if rng.randf() < 0.4:
			v.speak(r, "소금이 닿자 녹아 버렸어!", 4)
		return
	v.stock["통나무"] = maxf(0.0, float(v.stock.get("통나무", 0.0)) - Balance.MOLD_TORCH_LOG / 3.0)   # 횃불 한 자루로 세 번
	stats["torch"] += 1
	b.burnt = 2.0
	b.size -= Balance.MOLD_TORCH * (1.0 + 0.08 * sk)
	if b.size < Balance.MOLD_SIZE_MIN:
		_defeat(v, r, b)
	else:
		b.state = "flee"                       # 화들짝 물러섬
		var away := Vector2(b.x - r.x, b.y - r.y).normalized()
		b.tx = b.x + away.x * 2.5
		b.ty = b.y + away.y * 2.5


## 횃불에 쪼그라들어 사라짐. 푸른곰팡이는 푸른 가루를 남긴다 (→ 곰팡이약)
func _defeat(v: Village, r: Resident, b: MoldBlob) -> void:
	b.state = "gone"
	stats["defeated"] += 1
	if b.kind != "푸른":
		return
	teal_defeats += 1
	v.stock[Balance.BLUE_POWDER] = float(v.stock.get(Balance.BLUE_POWDER, 0.0)) + 1.0
	stats["powder"] += 1
	if med_known:
		return
	# 발견: 곪은 상처를 앓던 사람이 퇴치 현장에서 가루를 묻혀 빨리 나음 → 약초꾼이 알아챔
	for q in v.people:
		if q.sick_left > 0.0 and q.disease == Balance.FESTER_KIND and Vector2(q.x - b.x, q.y - b.y).length() < 8.0:
			med_known = true
			v.note_discovery("blue_powder", q)
			q.sick_left *= Balance.MOLD_MED_TIME
			v.log_line("푸른 털 괴물이 남긴 가루가 %s의 곪은 상처를 말렸다." % q.name)
			return
	if teal_defeats >= Balance.MOLD_MED_DISCOVER:
		med_known = true
		v.note_discovery("blue_powder", r)
		v.log_line("%s%s 푸른 털뭉치가 남긴 가루를 모아 두었다. 곪은 데 바르면 낫는다는 옛말이 있었다." % [r.name, Village.josa(r.name, "이", "가")])


## 곰팡이약 만들기: 창고에서 푸른 가루 1 + 빵 1 (없으면 건량 2) → 곰팡이약 2
func _make_med(v: Village, r: Resident) -> bool:
	var s := v.store()
	maker_id = r.id
	r.action = "mold_med"
	r.last_action = "mold_med"
	r.doing = "푸른 가루로 약을 만드는 중"
	var done := ResidentAI.op("mold_med_done")
	var undo := ResidentAI.op("mold_med_undo", {"rid": r.id})
	var hut := v.bld(r.job)
	if hut != null and hut.type == "약초꾼" and hut.built:      # 약초꾼은 자기 오두막에서 (A6)
		r.doing = "약초원에서 푸른 가루로 약을 만드는 중"
		r.steps.append(ResidentAI.walk(hut.x + 0.9, hut.y + 0.7))
		r.steps.append(ResidentAI.act(Balance.MOLD_MED_MAKE_TIME, "work", done, false, undo))
		return true
	r.steps.append(ResidentAI.walk(s.x + 1.2, s.y + 0.9))
	r.steps.append(ResidentAI.act(Balance.MOLD_MED_MAKE_TIME, "work", done, false, undo))
	return true


# ───────────────────────── 건강 (Health.tick · Health._hourly의 고리) ─────────────────────────
## 이 사람 둘레에 털뭉치가 있으면 포자 → 배앓이·기침병 배율 (익숙해지면 ×1.5). 거르기용 상한에도 쓴다
static func ill_mult(v: Village, r: Resident) -> float:
	var m := v.mold
	if m == null or m.blobs.is_empty():
		return 1.0
	var r2 := Balance.MOLD_ILL_R * Balance.MOLD_ILL_R
	for b in m.blobs:
		if b.state != "tamed" and b.state != "gone" and Vector2(b.x - r.x, b.y - r.y).length_squared() <= r2:
			return 1.0 + (Balance.MOLD_ILL_MULT - 1.0) * (0.5 if m.adapted() else 1.0)
	return 1.0


static func kind_mult(kind: String, near: float) -> float:
	return near if near > 1.0 and kind in Balance.MOLD_ILL_KINDS else 1.0


## 앓는 사람이 곰팡이약을 먹어 본다 (한 번 앓을 때 한 번). 곪은 상처·기침병·역병: 중증을 막고 남은 기간 ×0.5.
## 다른 병엔 듣지 않는다 — 마을은 모르고 써 보다가 몇 번 실패하면 배운다 (그 뒤로는 듣는 병에만 씀)
static func medicine(v: Village, r: Resident) -> void:
	var m := v.mold
	if m == null or float(v.stock.get(Balance.MOLD_MED, 0.0)) < 1.0 or r.disease == "":
		return
	if float(m.tried.get(r.id, -1.0e18)) == r.sick_since:
		return
	var works := r.disease in Balance.MOLD_MED_KINDS
	if m.med_learned and not works:
		return
	m.tried[r.id] = r.sick_since
	v.stock[Balance.MOLD_MED] = float(v.stock[Balance.MOLD_MED]) - 1.0
	m.stats["med_used"] += 1
	if works:
		m.stats["med_ok"] += 1
		r.sick_left *= Balance.MOLD_MED_TIME
		r.severe = false
		if m.stats["med_ok"] == 1:
			v.log_line("푸른 약을 먹은 %s의 %s%s 금세 가라앉았다." % [r.name, r.disease, Village.josa(r.disease, "이", "가")])
		return
	m.med_fail += 1
	if r.age >= 2.5 and not r.sleeping:
		v.speak(r, "푸른 약을 먹었는데 그대로야…", 5)
	if m.med_fail >= Balance.MOLD_MED_LEARN and not m.med_learned:
		m.med_learned = true
		v.log_line("푸른 약은 기침과 곪은 데만 듣는다. 고뿔과 배앓이에는 소용이 없었다.")


# ───────────────────────── 병 돌리기 ─────────────────────────
func rotate() -> void:
	for b in blobs:
		var p := JarWater.rot_pt(Vector2(b.x, b.y))
		var q := JarWater.rot_pt(Vector2(b.tx, b.ty))
		b.x = p.x
		b.y = p.y
		b.px = p.x
		b.py = p.y
		b.tx = q.x
		b.ty = q.y


# ───────────────────────── 개발·시험용 ─────────────────────────
## 압력을 채워 바로 조짐부터 (개발 버튼·캡처용 — 게임에는 없음)
func force_omen(v: Village) -> void:
	pressure = 1.0
	rest_until = 0.0
	_start_omen(v)


func force_swarm(v: Village, kind := "") -> void:
	pressure = 1.0
	if kind != "":
		swarm_kind = kind
	_start_swarm(v)


# ───────────────────────── 저장 (docs/SAVE.md) ─────────────────────────
## 난수 흐름 포함
func to_dict() -> Dictionary:
	var d := SaveCodec.props(self, ["blobs"])
	var bl := []
	for b in blobs:
		bl.append(b.to_dict())
	d["blobs"] = bl
	return d


static func from_dict(d: Dictionary) -> Mold:
	var m := Mold.new(0)
	SaveCodec.apply(m, d, ["blobs"])
	m.blobs.clear()
	for bd: Dictionary in d.get("blobs", []):
		m.blobs.append(MoldBlob.from_dict(bd))
	return m
