## 개미굴 원정 — 시뮬레이션 핵심 (docs/WORLD_EVENTS.md 2.1c "개미굴 원정" · ROADMAP Q10 1걸음: 따로 도는 시험판).
## 원정대(지킴이 셋~다섯 + 강아지)가 스스로 굴에 들어가 병정개미를 창으로 밀어내고, 방패로 버티고, 비운 방에 연기를 피운다.
## 여왕 방에 연기가 차면 굴 전체가 이사 간다 (= 이김). 아무도 죽지 않는다 — 개미는 뒤집혀 버둥대다 알을 물고 달아나고, 주민은 지치거나 다치면 스스로 물러난다.
## 거인은 명령하지 않는다. 다섯 손짓(등불 · 물 · 핀셋 · 유리 톡 · 각설탕)만 — 모두 양날이고 다시 쓸 때까지 시간이 걸린다.
##
## 화면과 분리된 순수 로직 (ADR-0001): Node·장면·카메라·'보고 있는지'를 읽지 않는다. static 상태 없음. 씨앗 + 같은 걸음의 같은 손짓 → 같은 결과.
## 일어난 일은 EventStream으로만 낸다 (kind 목록: docs/architecture/event-kinds.md "개미굴 원정"). 사건의 at = Vector2(seg, s) — 굴 길 위의 자리.
## 값은 data/nest_balance.gd.
##
## 쓰는 법:
##   var ex := NestExpedition.new()
##   ex.setup(seed, NestExpedition.default_roster(4, 1, 1), true)      # 명단 [{id, name, spear, shield, skill}] · 강아지
##   while not ex.done: ex.step()                                       # 고정 걸음 NestBalance.DT
##   ex.gesture(&"lamp", 0, 18.0)  → bool (받아들여졌는가)              # 손짓: lamp · water · tweezers · tap · sugar (seg, s)
##   ex.result  → {outcome, secs, deepest, cleared, hurt, left, loot, …}
##
## 굴 길: seg 0 = 큰길 (s = 0 입구 … DEEP_END), seg 1 = 옆 굴 (s = 0 큰길과 만나는 곳 … SIDE_LEN 원군이 나오는 끝).
class_name NestExpedition
extends RefCounted

const MAIN := 0
const SIDE := 1
const GESTURES: Array[StringName] = [&"lamp", &"water", &"tweezers", &"tap", &"sugar"]


class Guard:
	extends RefCounted
	var id := 0
	var name := ""
	var spear := 1
	var shield := 1
	var skill := 3
	var s := 0.0                       # 큰길 위의 자리 (지킴이는 옆 굴에 들어가지 않는다)
	var stam := 1.0                    # 기운 0~1
	var nerve := 1.0                   # 담력 0~1
	var state: StringName = &"go"      # go · retreat · out
	var why: StringName = &""          # tired · scared · hurt · withdraw · timeout · won
	var hurt := false
	var hold := false                  # 방패로 버티는 자세
	var doing: StringName = &"walk"    # 화면용: walk · push · hold · dig · pot · rest · back
	var biters := 0
	var dark := false


class Ant:
	extends RefCounted
	var id := 0
	var kind: StringName = &"worker"   # worker · scout · soldier · big · queen
	var seg := 0
	var s := 0.0
	var home := 0                      # 지키는 방 (0~2), -1 = 원군
	var grit := 1.0
	var grit0 := 1.0
	var state: StringName = &"home"    # home · attack · lured · alarm · flip · stun · flee · out
	var back: StringName = &"home"     # stun이 끝나면 돌아갈 상태
	var timer := 0.0
	var goal := 0.0                    # home일 때 어슬렁거리는 자리
	var target := -1                   # 물고 있는 지킴이 id
	var charge_t := 0.0                # 큰 병정: 다음 들이받기까지
	var wind := 0.0                    # 몸을 세우는 중 (> 0)
	var egg := false                   # 알을 물고 달아나는 중
	var angry := false
	var drawn := false                 # 등불 빛을 보고 올라온 병정
	var fed := false                   # 각설탕을 먹고 힘이 난 병정
	var biting := false

	func standing() -> bool:
		return state != &"flip" and state != &"flee" and state != &"out"

	func fighter() -> bool:
		return kind == &"soldier" or kind == &"big"


var seed_v := 0
var rng := RandomNumberGenerator.new()
var events: EventStream
var t := 0.0
var step_n := 0
var guards: Array[Guard] = []
var ants: Array[Ant] = []
var has_dog := false
var dog_s := 0.0
var dog_bark_cd := 0.0
var dog_bark_left := 0.0
var dog_out := false
var _next_ant := 1

var cleared: Array[bool] = [false, false, false]
var entered: Array[bool] = [false, false, false]
var deepest := 0                       # 가장 깊이 들어간 방 (0 = 입구까지)
var lit_room := 0                      # 등불이 켜진 방 (1~3, 0 = 없음)
var lamp_left := 0.0
var _draw_t := 0.0
var lamp_drawn := 0                    # 빛에 끌려 올라온 병정 수
var pebble := true
var pebble_work := 0.0
var rubble: Array[Dictionary] = []     # [{s, work}]
var mud: Array[Dictionary] = []        # [{s, left}]
var water_left := 0.0                  # 옆 굴이 물에 막힌 남은 시간
var sugar_on := false
var sugar_seg := 0
var sugar_s := 0.0
var sugar_left := 0.0
var _sugar_hit := false
var tweeze_on := false
var tweeze_seg := 0
var tweeze_s := 0.0
var tweeze_left := 0.0
var freeze_left := 0.0                  # 유리 톡: 주민이 굳은 남은 시간
var ant_freeze_left := 0.0              # 개미가 굳은 남은 시간 (주민보다 먼저 풀린다)
var mood := 1.0                        # 이 굴의 사나움 (무는 힘 ×) — 굴마다 다르다
var reinf_max := 0                     # 이 굴의 원군 총수
var cd := {}                           # 손짓 → 다시 쓸 때까지 남은 초
var alarm := false
var reinf_t := 0.0
var reinf_sent := 0
var pot_who := -1
var pot_prog := 0.0                    # 0~1
var rest_left := 0.0
var withdrawing := false
var done := false
var over := false                      # 끝이 정해짐 (이김·모두 물러남) — done은 마무리 시간 뒤
var outcome: StringName = &""
var _linger := 0.0
var loot := {}
var result := {}
var used := {}                         # 손짓 → 쓴 횟수
var flipped := 0
var washed := 0
var inputs: Array = []                 # 받아들여진 손짓 [걸음, kind, seg, s] — 다시 돌려 보기용
var _noted := {}                       # 한 번만 내는 알림
var _fumble_t := -100.0                # '어두워서 더듬는 중' 알림은 8초에 한 번까지


# ───────────────────────── 꾸리기 ─────────────────────────
## 기본 명단 — 마을과 이어지기 전의 대역. 이름은 화면용.
static func default_roster(n: int, spear: int, shield: int, skill := 3) -> Array[Dictionary]:
	var names := ["보리", "솔이", "다래", "누리", "마루"]
	var out: Array[Dictionary] = []
	for i in clampi(n, 3, 5):
		out.append({"id": i + 1, "name": names[i], "spear": spear, "shield": shield, "skill": skill})
	return out


func setup(seed_value: int, roster: Array[Dictionary], dog := true, stream: EventStream = null) -> void:
	seed_v = seed_value
	rng.seed = hash([seed_value, 0x6e657374])
	events = stream if stream != null else EventStream.new()
	for k: StringName in GESTURES:
		cd[k] = 0.0
		used[k] = 0
	for k: String in NestBalance.LOOT_KEYS:
		loot[k] = 0
	var i := 0
	for r: Dictionary in roster:
		var g := Guard.new()
		g.id = int(r.get("id", i + 1))
		g.name = String(r.get("name", ""))
		g.spear = clampi(int(r.get("spear", 1)), 1, 2)
		g.shield = clampi(int(r.get("shield", 1)), 1, 2)
		g.skill = clampi(int(r.get("skill", 3)), 0, 10)
		g.s = -float(i) * NestBalance.SPACING
		guards.append(g)
		i += 1
	has_dog = dog
	mood = rng.randf_range(float(NestBalance.MOOD[0]), float(NestBalance.MOOD[1]))
	reinf_max = rng.randi_range(int(NestBalance.REINF_MAX[0]), int(NestBalance.REINF_MAX[1]))
	dog_s = 1.0
	for ri in 3:
		var room: Array = NestBalance.ROOMS[ri]
		var n: Array = (NestBalance.ROOM_ANTS[ri] as Array).duplicate()
		if ri > 0:
			n[2] = int(n[2]) + rng.randi_range(-NestBalance.SOLDIER_JITTER, NestBalance.SOLDIER_JITTER)
		var kinds: Array[StringName] = [&"worker", &"scout", &"soldier", &"big"]
		for ki in 4:
			for _j in int(n[ki]):
				var a := _spawn(kinds[ki], MAIN, rng.randf_range(float(room[0]) + 5.0, float(room[1]) - 2.0), ri)
				if kinds[ki] == &"big":
					a.s = float(room[1]) - 5.0
				a.goal = a.s
	var q := _spawn(&"queen", MAIN, float(NestBalance.ROOMS[2][1]) - 2.5, 2)
	q.goal = q.s
	_emit(&"nest_started", {"v": {"guards": guards.size(), "dog": dog, "seed": seed_value}})


func _spawn(kind: StringName, seg: int, s: float, home: int) -> Ant:
	var a := Ant.new()
	a.id = _next_ant
	_next_ant += 1
	a.kind = kind
	a.seg = seg
	a.s = s
	a.home = home
	a.grit = float(NestBalance.GRIT.get(String(kind), 99.0)) * rng.randf_range(1.0 - NestBalance.GRIT_JITTER, 1.0 + NestBalance.GRIT_JITTER)
	a.grit0 = a.grit
	a.charge_t = NestBalance.BIG_CHARGE_EVERY * 0.6
	ants.append(a)
	return a


func _emit(kind: StringName, data: Dictionary) -> void:
	data["t"] = t
	events.emit(kind, data)


func _note(code: StringName, seg: int, s: float, who := -1, once := false) -> void:
	if once:
		if _noted.has(code):
			return
		_noted[code] = true
	_emit(&"nest_note", {"v": code, "at": Vector2(seg, s), "who": who})


# ───────────────────────── 굴 길 ─────────────────────────
## 큰길 위 자리가 딸린 방 (1~3) — 등불·'제 방을 지킴'의 구역. 입구 굴은 0.
static func zone_of(s: float) -> int:
	if s < NestBalance.ENTRY_END:
		return 0
	if s < NestBalance.PEBBLE_S:
		return 1
	if s < NestBalance.JUNCTION_S:
		return 2
	return 3


## 방 안이면 1~3, 굴이면 0
static func room_at(s: float) -> int:
	for r in 3:
		if s >= float(NestBalance.ROOMS[r][0]) and s <= float(NestBalance.ROOMS[r][1]):
			return r + 1
	return 0


static func room_mid(r: int) -> float:
	return (float(NestBalance.ROOMS[r][0]) + float(NestBalance.ROOMS[r][1])) * 0.5


static func path_dist(seg_a: int, s_a: float, seg_b: int, s_b: float) -> float:
	if seg_a == seg_b:
		return absf(s_a - s_b)
	if seg_a == MAIN:
		return absf(s_a - NestBalance.JUNCTION_S) + s_b
	return s_a + absf(s_b - NestBalance.JUNCTION_S)


func is_dark(seg: int, s: float) -> bool:
	if seg == SIDE:
		return true
	var z := zone_of(s)
	if z == 0:
		return false
	return not (lamp_left > 0.0 and lit_room == z)


## 연기가 찬 곳의 깊은 쪽 끝 — 개미는 이보다 얕은 곳으로 오지 않는다
func smoke_end() -> float:
	var e := -1.0
	for r in 3:
		if cleared[r]:
			e = float(NestBalance.ROOMS[r][1])
	return e


func active() -> Array[Guard]:
	var out: Array[Guard] = []
	for g in guards:
		if g.state == &"go":
			out.append(g)
	return out


func cur_room() -> int:
	for r in 3:
		if not cleared[r]:
			return r
	return -1


func cd_left(kind: StringName) -> float:
	return float(cd.get(kind, 0.0))


func can_use(kind: StringName) -> bool:
	return not over and cd_left(kind) <= 0.0


func big_in(room: int) -> Ant:
	for a in ants:
		if a.kind == &"big" and a.home == room and a.standing():
			return a
	return null


func side_ants() -> int:
	var n := 0
	for a in ants:
		if a.seg == SIDE and a.standing():
			n += 1
	return n


## 방 r(0~2)에 아직 서 있는 병정·큰 병정 수 (제 방을 지키는 것 + 그 구역에 들어와 있는 것)
func fighters_in(r: int) -> int:
	var n := 0
	for a in ants:
		if a.fighter() and a.standing() and ((a.seg == MAIN and zone_of(a.s) == r + 1) or (a.home == r and (a.state == &"home" or a.state == &"lured"))):
			n += 1
	return n


# ───────────────────────── 거인의 손짓 ─────────────────────────
## 손짓 하나. 받아들여지면 true (다시 쓸 때까지의 시간이 돈다). seg·s = 굴 길 위의 자리 (tap은 안 봄, lamp는 그 자리의 방).
func gesture(kind: StringName, seg := 0, s := 0.0) -> bool:
	if over or not cd.has(kind):
		return false
	if cd_left(kind) > 0.0:
		_emit(&"nest_gesture", {"v": {"kind": kind, "ok": false, "why": &"cooldown"}, "at": Vector2(seg, s)})
		return false
	var ok := false
	match kind:
		&"lamp":
			ok = _lamp(seg, s)
		&"water":
			ok = _water(seg, s)
		&"tweezers":
			ok = _tweezers(seg, s)
		&"tap":
			ok = _tap()
		&"sugar":
			ok = _sugar(seg, s)
	if not ok:
		_emit(&"nest_gesture", {"v": {"kind": kind, "ok": false, "why": &"no_spot"}, "at": Vector2(seg, s)})
		return false
	cd[kind] = float(NestBalance.CD[String(kind)])
	used[kind] = int(used[kind]) + 1
	inputs.append([step_n, kind, seg, s])
	_emit(&"nest_gesture", {"v": {"kind": kind, "ok": true}, "at": Vector2(seg, s)})
	return true


func _lamp(seg: int, s: float) -> bool:
	if seg != MAIN:
		return false
	var z := zone_of(s)
	if z == 0:
		return false
	lit_room = z
	lamp_left = NestBalance.LAMP_SECS
	_draw_t = NestBalance.LAMP_DRAW_EVERY
	for g in active():
		if zone_of(g.s) == z:
			g.nerve = minf(1.0, g.nerve + NestBalance.NERVE_LIT)
	_noted.erase(&"light_wakes")
	_note(&"lit", MAIN, room_mid(z - 1))
	return true


func _water(seg: int, s: float) -> bool:
	if seg == SIDE:
		if water_left > 0.0:                      # 이미 젖은 데 또 — 넘쳐서 큰길로
			water_left = NestBalance.WATER_BLOCK
			_splash(NestBalance.JUNCTION_S, NestBalance.WATER_R + 2.0)
			_note(&"overflow", MAIN, NestBalance.JUNCTION_S)
			return true
		water_left = NestBalance.WATER_BLOCK
		var n := 0
		for a in ants:
			if a.seg == SIDE and a.standing():
				_flee(a, false)
				n += 1
		washed += n
		_note(&"side_washed" if n > 0 else &"side_blocked", SIDE, clampf(s, 2.0, NestBalance.SIDE_LEN - 2.0))
		return true
	if s < NestBalance.ENTRY_END * 0.5 or s > NestBalance.DEEP_END:
		return false
	_splash(s, NestBalance.WATER_R)
	return true


## 큰길에 쏟아진 물 — 거기 있는 모두가 쓸린다 (지킴이는 입구 쪽으로, 개미는 깊은 쪽으로) + 진창
func _splash(s: float, r: float) -> void:
	var hit_g := 0
	var hit_a := 0
	for g in active():
		if absf(g.s - s) <= r:
			g.s = maxf(0.0, g.s - NestBalance.WATER_PUSH_GUARD)
			g.stam -= NestBalance.WATER_STAM
			g.nerve -= NestBalance.WATER_NERVE
			hit_g += 1
	for a in ants:
		if a.seg == MAIN and a.standing() and a.kind != &"queen" and absf(a.s - s) <= r:
			a.s = _ant_clamp(a, a.s, a.s + NestBalance.WATER_PUSH_ANT)
			_stun(a, NestBalance.WATER_STUN)
			hit_a += 1
	if hit_g > 0 and pot_prog > 0.0:
		pot_prog = 0.0
	mud.append({"s": s, "left": NestBalance.MUD_SECS, "r": r})
	if hit_g > 0:
		_note(&"splash_squad", MAIN, s)
	elif hit_a > 0:
		_note(&"splash_ants", MAIN, s)
	else:
		_note(&"splash_none", MAIN, s)


func _tweezers(seg: int, s: float) -> bool:
	if tweeze_on:
		return false
	if seg == MAIN and (s < NestBalance.ENTRY_END * 0.5 or s > NestBalance.DEEP_END):
		return false
	tweeze_on = true
	tweeze_seg = seg
	tweeze_s = s
	tweeze_left = NestBalance.TWEEZE_SECS
	return true


func _tweeze_close() -> void:
	tweeze_on = false
	var best: Ant = null
	var bd := NestBalance.TWEEZE_R
	for a in ants:
		if a.kind == &"big" and a.standing():
			var d := path_dist(a.seg, a.s, tweeze_seg, tweeze_s)
			if d <= bd:
				bd = d
				best = a
	if best != null:
		best.state = &"out"
		_big_gone(best, true)
		_note(&"big_picked", best.seg, best.s)
		_emit(&"nest_tweezed", {"v": {"what": &"big", "hit": true}, "at": Vector2(tweeze_seg, tweeze_s)})
		return
	if tweeze_seg == MAIN and pebble and absf(tweeze_s - NestBalance.PEBBLE_S) <= NestBalance.TWEEZE_R:
		pebble = false
		_note(&"pebble_picked", MAIN, NestBalance.PEBBLE_S)
		_emit(&"nest_tweezed", {"v": {"what": &"pebble", "hit": true}, "at": Vector2(tweeze_seg, tweeze_s)})
		return
	if tweeze_seg == MAIN:
		for i in rubble.size():
			if absf(float(rubble[i]["s"]) - tweeze_s) <= NestBalance.TWEEZE_R:
				_note(&"rubble_picked", MAIN, float(rubble[i]["s"]))
				rubble.remove_at(i)
				_emit(&"nest_tweezed", {"v": {"what": &"rubble", "hit": true}, "at": Vector2(tweeze_seg, tweeze_s)})
				return
		# 빗나감 — 흙이 무너져 길을 막는다
		rubble.append({"s": clampf(tweeze_s, NestBalance.ENTRY_END, NestBalance.DEEP_END - 4.0), "work": 0.0})
		for g in active():
			if absf(g.s - tweeze_s) <= 8.0:
				g.nerve -= NestBalance.TWEEZE_MISS_NERVE
	_note(&"tweeze_miss", tweeze_seg, tweeze_s)
	_emit(&"nest_tweezed", {"v": {"what": &"none", "hit": false}, "at": Vector2(tweeze_seg, tweeze_s)})


func _big_gone(big: Ant, picked: bool) -> void:
	for a in ants:
		if a.kind == &"soldier" and a.home == big.home and a.standing():
			a.grit *= NestBalance.LEADERLESS_GRIT
	for g in active():
		g.nerve = minf(1.0, g.nerve + NestBalance.NERVE_BIG_GONE)
	if not picked:
		loot["jaw"] = int(loot["jaw"]) + NestBalance.LOOT_BIG_JAW
	_note(&"leaderless", MAIN, room_mid(maxi(big.home, 0)))


func _tap() -> bool:
	freeze_left = NestBalance.TAP_SECS
	ant_freeze_left = NestBalance.TAP_ANT_SECS
	for g in active():
		g.nerve -= NestBalance.TAP_NERVE
	for a in ants:
		if a.wind > 0.0:
			a.wind = 0.0
			a.charge_t = NestBalance.BIG_CHARGE_EVERY
			_note(&"charge_cancelled", a.seg, a.s)
	if pot_prog > 0.0:
		pot_prog = 0.0
		var f := _front()
		_note(&"pot_reset", MAIN, f.s if f != null else 0.0)
	var fr := _front()
	_note(&"frozen", MAIN, fr.s if fr != null else 0.0)
	return true


func _sugar(seg: int, s: float) -> bool:
	if seg == MAIN and (s < NestBalance.ENTRY_END or s > NestBalance.DEEP_END - 2.0):
		return false
	if seg == MAIN and s < smoke_end():
		return false                               # 연기 찬 방에는 개미가 오지 않는다
	sugar_on = true
	sugar_seg = seg
	sugar_s = clampf(s, 0.5, NestBalance.SIDE_LEN - 1.0) if seg == SIDE else s
	sugar_left = NestBalance.SUGAR_SECS
	_sugar_hit = false
	# 가까운 병정부터 SUGAR_MAX마리까지만 끌린다 (같은 거리면 먼저 태어난 순 — 씨앗이 같으면 늘 같다)
	var near: Array = []
	for i in ants.size():
		var a := ants[i]
		var d := path_dist(a.seg, a.s, sugar_seg, sugar_s)
		if a.kind == &"soldier" and a.standing() and a.state != &"stun" and d <= NestBalance.SUGAR_RANGE:
			near.append([d, i])
	near.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0] if x[0] != y[0] else x[1] < y[1])
	var n := mini(near.size(), NestBalance.SUGAR_MAX)
	for j in n:
		var la := ants[int(near[j][1])]
		la.state = &"lured"
		la.target = -1
	_note(&"sugar_lure" if n > 0 else &"sugar_none", sugar_seg, sugar_s)
	return true


# ───────────────────────── 한 걸음 ─────────────────────────
func advance(secs: float) -> void:
	var n := int(round(secs / NestBalance.DT))
	for _i in n:
		if done:
			return
		step()


func step() -> void:
	if done:
		return
	var dt := NestBalance.DT
	step_n += 1
	t += dt
	_timers(dt)
	if over:
		_after(dt)
		return
	if freeze_left > 0.0:
		freeze_left -= dt
		if ant_freeze_left > 0.0:
			ant_freeze_left -= dt
		else:
			_ants(dt)                                  # 개미가 먼저 풀려 굳어 있는 주민을 문다
		return
	_brain(dt)
	if over:
		return
	_ants(dt)
	_guards(dt)
	_dog(dt)
	_reinforce(dt)
	_lamp_draw(dt)
	if t >= NestBalance.MAX_SECS and not withdrawing:
		_withdraw(&"timeout")


func _timers(dt: float) -> void:
	for k: StringName in GESTURES:
		if float(cd[k]) > 0.0:
			cd[k] = maxf(0.0, float(cd[k]) - dt)
	if lamp_left > 0.0:
		lamp_left -= dt
		if lamp_left <= 0.0:
			_note(&"lamp_out", MAIN, room_mid(lit_room - 1))
	if water_left > 0.0:
		water_left -= dt
		if water_left <= 0.0:
			_noted.erase(&"side_waiting")
			_note(&"side_open", SIDE, NestBalance.SIDE_LEN * 0.5)
	var i := mud.size() - 1
	while i >= 0:
		mud[i]["left"] = float(mud[i]["left"]) - dt
		if float(mud[i]["left"]) <= 0.0:
			mud.remove_at(i)
		i -= 1
	if sugar_on:
		sugar_left -= dt
		if sugar_left <= 0.0:
			sugar_on = false
			for a in ants:
				if a.state == &"lured":
					a.state = &"attack" if a.home < 0 else &"home"
					a.angry = false
					if path_dist(a.seg, a.s, sugar_seg, sugar_s) <= 2.0:      # 단것을 먹고 힘이 난다
						a.grit = maxf(a.grit, a.grit0 * NestBalance.SUGAR_FED_GRIT)
						a.fed = true
			_note(&"sugar_gone", sugar_seg, sugar_s)
	if tweeze_on and not over:
		tweeze_left -= dt
		if tweeze_left <= 0.0:
			_tweeze_close()


## 끝이 정해진 뒤: 개미는 달아나고 지킴이는 걸어 나온다 (화면 마무리용 — 결과는 이미 정해짐)
func _after(dt: float) -> void:
	_linger -= dt
	for a in ants:
		if a.state == &"flee" or a.state == &"flip":
			_ant_one(a, dt)
	for g in guards:
		if g.state == &"retreat":
			g.s = maxf(0.0, g.s - NestBalance.GUARD_SPEED * dt)
	if _linger <= 0.0:
		done = true


func _front() -> Guard:
	var best: Guard = null
	for g in guards:
		if g.state == &"go" and (best == null or g.s > best.s):
			best = g
	return best


# ───────────────────────── 원정대의 판단 (명령 없음 — 스스로) ─────────────────────────
func _brain(dt: float) -> void:
	var act := active()
	if not withdrawing and act.size() < NestBalance.WITHDRAW_BELOW:
		_withdraw(&"withdraw")
	if withdrawing:
		var all_out := true
		for g in guards:
			if g.state != &"out":
				all_out = false
		if all_out:
			_finish(&"withdrew")
		return
	if rest_left > 0.0:
		rest_left -= dt
	var cur := cur_room()
	if cur < 0:
		return
	# 방에 들어섬
	var f := _front()
	if f != null:
		var ra := room_at(f.s + NestBalance.DOOR)      # 방 어귀에 닿으면 들어선 것
		if ra > 0 and not entered[ra - 1]:
			entered[ra - 1] = true
			deepest = maxi(deepest, ra)
			_emit(&"nest_room_entered", {"v": {"room": ra, "dark": is_dark(MAIN, room_mid(ra - 1))}, "at": Vector2(MAIN, f.s), "who": f.id})
		if not alarm and f.s >= NestBalance.PEBBLE_S + 1.0:
			_alarm(&"fight")
	# 연기 화로: 이 방에 서 있는 병정이 없고 곁에 싸울 개미가 없으면 맨 뒤 사람이 피운다
	var room: Array = NestBalance.ROOMS[cur]
	var can_pot := f != null and rest_left <= 0.0 and f.s >= float(room[0]) + 3.0 and fighters_in(cur) == 0 and not _threat_near(act)
	if can_pot:
		var who: Guard = act[act.size() - 1]
		for g in act:
			if g.s < who.s:
				who = g
		if pot_who != who.id:
			pot_who = who.id
			if pot_prog <= 0.0:
				_note(&"pot_start", MAIN, who.s, who.id)
		var k := NestBalance.DARK_POT_K if is_dark(MAIN, who.s) else 1.0
		pot_prog += dt / (NestBalance.POT_SECS * k)
		if pot_prog >= 1.0:
			_clear_room(cur, who)
	else:
		pot_who = -1


func _threat_near(act: Array[Guard]) -> bool:
	for a in ants:
		if not a.fighter() or not a.standing() or a.state == &"stun":
			continue
		if a.state == &"lured" and not a.biting:
			continue
		for g in act:
			if path_dist(a.seg, a.s, MAIN, g.s) <= NestBalance.REACH + 1.5:
				return true
	return false


func _alarm(why: StringName) -> void:
	if alarm:
		return
	alarm = true
	reinf_t = NestBalance.REINF_FIRST
	_note(StringName("alarm_" + String(why)), SIDE, NestBalance.SIDE_LEN * 0.6)


func _clear_room(r: int, who: Guard) -> void:
	cleared[r] = true
	pot_prog = 0.0
	pot_who = -1
	rest_left = NestBalance.REST_SECS
	var room: Array = NestBalance.ROOMS[r]
	var got := {}
	var tbl: Dictionary = NestBalance.LOOT[r]
	for k: String in NestBalance.LOOT_KEYS:
		if tbl.has(k):
			var n := rng.randi_range(int(tbl[k][0]), int(tbl[k][1]))
			got[k] = n
			loot[k] = int(loot[k]) + n
	for a in ants:
		if not a.standing() and a.state != &"flip":
			continue
		if r == 2 or (a.seg == MAIN and a.s <= float(room[1]) + 1.0) or a.home == r:
			_flee(a, true)
	for g in active():
		g.nerve = minf(1.0, g.nerve + NestBalance.NERVE_ROOM)
	_note(&"smoke", MAIN, room_mid(r), who.id)
	_emit(&"nest_room_cleared", {"v": {"room": r + 1, "loot": got}, "at": Vector2(MAIN, room_mid(r)), "who": who.id})
	if r == 2:
		_note(&"moving_out", MAIN, room_mid(2))
		for g in guards:
			if g.state == &"go":
				g.doing = &"cheer"
		_finish(&"won")


func _withdraw(why: StringName) -> void:
	withdrawing = true
	pot_who = -1
	for g in guards:
		if g.state == &"go":
			g.state = &"retreat"
			g.why = why
			g.doing = &"back"
	var f := 0.0
	for g in guards:
		f = maxf(f, g.s)
	_emit(&"nest_withdrew", {"v": {"deepest": deepest, "why": why}, "at": Vector2(MAIN, f)})


func _finish(what: StringName) -> void:
	if over:
		return
	over = true
	outcome = what
	_linger = NestBalance.END_LINGER
	var hurt: Array[int] = []
	var left: Array[Dictionary] = []
	for g in guards:
		if g.hurt:
			hurt.append(g.id)
		if g.why != &"" and g.why != &"withdraw" and g.why != &"timeout":
			left.append({"id": g.id, "why": g.why})
	var n_clear := 0
	for c in cleared:
		if c:
			n_clear += 1
	result = {"outcome": what, "secs": t, "deepest": deepest, "cleared": n_clear, "hurt": hurt, "left": left,
		"loot": loot.duplicate(), "flipped": flipped, "washed": washed, "used": used.duplicate(), "seed": seed_v, "dead": 0}
	_emit(&"nest_ended", {"v": result.duplicate(true)})


# ───────────────────────── 개미 ─────────────────────────
func _flee(a: Ant, egg: bool) -> void:
	if a.state == &"out":
		return
	a.state = &"flee"
	a.egg = egg and a.kind != &"queen"
	a.target = -1
	a.wind = 0.0
	a.biting = false


func _stun(a: Ant, secs: float) -> void:
	if a.state == &"stun":
		a.timer = maxf(a.timer, secs)
		return
	a.back = a.state
	a.state = &"stun"
	a.timer = secs
	a.wind = 0.0
	a.biting = false


func _flip(a: Ant, by: Guard) -> void:
	a.state = &"flip"
	a.timer = NestBalance.FLIP_SECS
	a.target = -1
	a.wind = 0.0
	a.biting = false
	flipped += 1
	for g in active():
		g.nerve = minf(1.0, g.nerve + NestBalance.NERVE_FLIP)
	if a.kind == &"big":
		_big_gone(a, false)
		_emit(&"nest_big_flipped", {"v": {"room": a.home + 1}, "at": Vector2(a.seg, a.s), "who": by.id if by != null else -1})


## 개미가 갈 수 없는 곳을 막는다: 조약돌 건너편 · 연기 찬 방 · 깊은 끝
func _ant_clamp(a: Ant, from: float, to: float) -> float:
	if a.seg != MAIN:
		return clampf(to, 0.0, NestBalance.SIDE_LEN)
	if pebble and (from < NestBalance.PEBBLE_S) != (to < NestBalance.PEBBLE_S):
		to = NestBalance.PEBBLE_S + (0.5 if from >= NestBalance.PEBBLE_S else -0.5)
	if a.state != &"flee":
		to = maxf(to, smoke_end() + 0.6)
	return clampf(to, NestBalance.ENTRY_END, NestBalance.DEEP_END)


func _ant_move(a: Ant, tseg: int, ts: float, d: float) -> void:
	if a.seg == tseg:
		a.s = _ant_clamp(a, a.s, move_toward(a.s, ts, d))
	elif a.seg == MAIN:                            # 옆 굴로 들어가려면 만나는 곳까지
		var ns := _ant_clamp(a, a.s, move_toward(a.s, NestBalance.JUNCTION_S, d))
		a.s = ns
		if absf(ns - NestBalance.JUNCTION_S) < 0.01 and water_left <= 0.0:
			a.seg = SIDE
			a.s = 0.0
	else:                                          # 옆 굴에서 큰길로 (물이 차 있으면 끝에서 기다린다)
		if water_left > 0.0:
			_note(&"side_waiting", SIDE, a.s, -1, true)
			return
		a.s = move_toward(a.s, 0.0, d)
		if a.s <= 0.0:
			a.seg = MAIN
			a.s = _ant_clamp(a, NestBalance.JUNCTION_S, NestBalance.JUNCTION_S)


func _ants(dt: float) -> void:
	for g in guards:
		g.biters = 0
	for a in ants:
		if a.state != &"out":
			_ant_one(a, dt)


func _ant_one(a: Ant, dt: float) -> void:
	var speed := float(NestBalance.ANT_SPEED.get(String(a.kind), 3.0))
	a.biting = false
	match a.state:
		&"flip":
			a.timer -= dt
			if a.timer <= 0.0:
				_flee(a, true)
		&"stun":
			a.timer -= dt
			if a.timer <= 0.0:
				a.state = a.back
		&"flee":
			if a.seg == SIDE:
				a.s += NestBalance.FLEE_SPEED * dt
				if a.s >= NestBalance.SIDE_LEN:
					a.state = &"out"
			else:
				a.s += (NestBalance.QUEEN_FLEE_SPEED if a.kind == &"queen" else NestBalance.FLEE_SPEED) * dt
				if a.s >= NestBalance.DEEP_END:
					a.state = &"out"
		&"alarm":                                  # 정찰 개미가 병정 방으로 알리러 달린다
			var dest := room_mid(1)
			if cleared[1] or (pebble and a.s < NestBalance.PEBBLE_S):
				_flee(a, false)                        # 길이 막혀 알리지 못하고 숨는다
				return
			_ant_move(a, MAIN, dest, speed * dt)
			if absf(a.s - dest) < 0.5:
				_alarm(&"scout")
				_flee(a, false)
		&"lured":
			_ant_lured(a, speed, dt)
		&"home":
			_ant_home(a, speed, dt)
		&"attack":
			_ant_attack(a, speed, dt)


func _ant_home(a: Ant, speed: float, dt: float) -> void:
	if a.kind == &"queen":
		return
	if a.home >= 0 and cleared[a.home]:
		_flee(a, true)
		return
	if a.kind == &"scout":
		for g in guards:
			if g.state == &"go" and absf(g.s - a.s) <= NestBalance.SCOUT_ALARM_DIST:
				a.state = &"alarm"
				_note(&"scout_runs", a.seg, a.s, -1, true)
				return
	if a.fighter():
		for g in guards:
			if g.state == &"go" and zone_of(g.s) == a.home + 1:
				a.state = &"attack"
				return
		if a.kind == &"soldier" and _woken(a) and _front() != null:
			a.state = &"attack"                        # 빛에 깬 병정이 원정대를 찾아 나선다
			_note(&"light_wakes", MAIN, room_mid(a.home), -1, true)
			return
	# 제 방 안에서 어슬렁
	var room: Array = NestBalance.ROOMS[maxi(a.home, 0)]
	if a.seg != MAIN or absf(a.s - a.goal) < 0.3:
		if a.kind == &"big":
			a.goal = float(room[1]) - rng.randf_range(3.0, 9.0)
		else:
			a.goal = rng.randf_range(float(room[0]) + 4.0, float(room[1]) - 1.5)
	var k := 0.35 if (a.seg == MAIN and room_at(a.s) == a.home + 1) else 1.0   # 방 밖(설탕·등불에서 돌아오는 길)은 제 걸음
	_ant_move(a, MAIN, a.goal, speed * k * dt)
	_ant_nip(a, dt)


## 일개미·제자리의 개미도 붙은 지킴이는 살짝 문다
func _ant_nip(a: Ant, dt: float) -> void:
	if a.seg != MAIN:
		return
	for g in guards:
		if g.state == &"go" and absf(g.s - a.s) <= NestBalance.CONTACT:
			_bite(a, g, dt)
			return


func _ant_attack(a: Ant, speed: float, dt: float) -> void:
	# 물 상대: 가까운 지킴이들 가운데 덜 물린 사람
	var best: Guard = null
	var bd := 1.0e9
	for g in guards:
		if g.state != &"go":
			continue
		var d := path_dist(a.seg, a.s, MAIN, g.s)
		if d < bd:
			bd = d
	for g in guards:
		if g.state != &"go":
			continue
		var d := path_dist(a.seg, a.s, MAIN, g.s)
		if d <= bd + 2.0 and (best == null or g.biters < best.biters):
			best = g
	if best == null or (a.home >= 0 and zone_of(best.s) != a.home + 1 and bd > NestBalance.AGGRO and not _woken(a)):
		a.target = -1
		a.state = &"home" if a.home >= 0 else &"attack"
		return
	a.target = best.id
	var d2 := path_dist(a.seg, a.s, MAIN, best.s)
	if d2 > NestBalance.CONTACT:
		a.wind = 0.0
		_ant_move(a, MAIN, best.s, minf(speed * dt, d2 - NestBalance.CONTACT * 0.8))
		d2 = path_dist(a.seg, a.s, MAIN, best.s)
	if d2 <= NestBalance.CONTACT + 0.2:
		_bite(a, best, dt)
		if a.kind == &"big":
			_big_charge(a, best, dt)


## 등불이 원정대 없는 방을 비추면 그 방 병정이 깬다
func _woken(a: Ant) -> bool:
	return a.home >= 0 and lamp_left > 0.0 and lit_room == a.home + 1


func _ant_lured(a: Ant, speed: float, dt: float) -> void:
	if not sugar_on:
		a.state = &"attack" if a.home < 0 else &"home"
		return
	# 가는 길에 원정대가 있으면 덮친다
	for g in guards:
		if g.state == &"go" and path_dist(a.seg, a.s, MAIN, g.s) <= NestBalance.CONTACT + 0.3:
			var toward := path_dist(MAIN, g.s, sugar_seg, sugar_s) < path_dist(a.seg, a.s, sugar_seg, sugar_s)
			if toward:
				a.angry = true
				a.target = g.id
				_bite(a, g, dt)
				if not _sugar_hit:
					_sugar_hit = true
					_note(&"sugar_onto_squad", MAIN, g.s, g.id)
				return
	if path_dist(a.seg, a.s, sugar_seg, sugar_s) > 0.8:
		_ant_move(a, sugar_seg, sugar_s, speed * 1.15 * dt)


func _bite(a: Ant, g: Guard, dt: float) -> void:
	var take := float(NestBalance.SHIELD_TAKE[g.shield])
	if g.hold:
		take *= NestBalance.HOLD_TAKE_K
	take *= _dark_k(g, NestBalance.DARK_TAKE_K)
	if a.angry:
		take *= NestBalance.SUGAR_ANGRY_BITE
	g.stam -= float(NestBalance.BITE.get(String(a.kind), 0.0)) * mood * take * dt
	g.biters += 1
	a.biting = true


func _big_charge(a: Ant, g: Guard, dt: float) -> void:
	if a.wind > 0.0:
		a.wind -= dt
		if a.wind <= 0.0:
			var p := float(NestBalance.SHIELD_BLOCK[g.shield]) * _dark_k(g, NestBalance.DARK_BLOCK_K)
			if g.hold:
				p += NestBalance.HOLD_BLOCK_ADD
			if rng.randf() < p:
				g.stam -= NestBalance.BIG_CHARGE_BLOCKED
				_note(&"charge_blocked", MAIN, g.s, g.id)
			else:
				g.stam -= NestBalance.BIG_CHARGE_HIT
				g.nerve -= NestBalance.BIG_CHARGE_NERVE
				_note(&"charge_hit", MAIN, g.s, g.id)
			a.charge_t = NestBalance.BIG_CHARGE_EVERY
		return
	a.charge_t -= dt
	if a.charge_t <= 0.0:
		a.wind = NestBalance.BIG_CHARGE_WIND
		_note(&"charge", a.seg, a.s)


## 어둠 벌점 (1 = 없음). 강아지가 방금 짖어 알려 줬으면 덜하다.
func _dark_k(g: Guard, k: float) -> float:
	if not g.dark:
		return 1.0
	if has_dog and not dog_out and dog_bark_left > 0.0:
		return lerpf(1.0, k, NestBalance.BARK_DARK_EASE)
	return k


# ───────────────────────── 지킴이 ─────────────────────────
func _guards(dt: float) -> void:
	var act := active()
	# 줄 서기: 앞에서부터
	act.sort_custom(func(x: Guard, y: Guard) -> bool: return x.s > y.s if x.s != y.s else x.id < y.id)
	var cur := cur_room()
	var goal := room_mid(cur) + 1.0 if cur >= 0 else 0.0
	# 방 안에 남은 병정이 닿지 않으면 다가간다
	if cur >= 0 and not act.is_empty():
		var near := 1.0e9
		for a in ants:
			if a.fighter() and a.standing() and a.seg == MAIN and a.home == cur and a.state != &"lured" and a.s > act[0].s:
				near = minf(near, a.s)
		if near < 1.0e8 and near - (NestBalance.REACH - 1.0) > goal:
			goal = minf(near - (NestBalance.REACH - 1.0), float(NestBalance.ROOMS[cur][1]) - 1.0)
	# 길 막힘 (조약돌 · 무너진 흙) — 맨 앞사람 앞의 가장 가까운 것
	var block_s := 1.0e9
	var block_i := -2                              # -1 = 조약돌, 0~ = 흙더미 번호
	if not act.is_empty():
		if pebble and NestBalance.PEBBLE_S > act[0].s - 0.5 and NestBalance.PEBBLE_S < goal + 1.0:
			block_s = NestBalance.PEBBLE_S
			block_i = -1
		for i in rubble.size():
			var rs := float(rubble[i]["s"])
			if rs > act[0].s - 0.5 and rs < goal + 1.0 and rs < block_s:
				block_s = rs
				block_i = i
	if block_i != -2:
		goal = minf(goal, block_s - 0.8)
	var n_bite := 0
	for a in ants:
		if a.biting:
			n_bite += 1
	var outnum := maxi(0, n_bite - act.size())
	var diggers := 0
	var idx := 0
	for g in act:
		g.dark = is_dark(MAIN, g.s)
		# 스스로 물러남
		if g.stam <= NestBalance.HURT_AT:
			_leave(g, &"hurt")
			continue
		if g.stam < NestBalance.TIRED_AT:
			_leave(g, &"tired")
			continue
		if g.nerve < NestBalance.SCARED_AT:
			_leave(g, &"scared")
			continue
		var slot := goal - float(idx) * NestBalance.SPACING
		idx += 1
		# 닿는 개미 — 병정 먼저
		var tgt: Ant = null
		var td := NestBalance.REACH
		var tf := false
		for a in ants:
			if not a.standing() or a.kind == &"queen":
				continue
			var d := path_dist(a.seg, a.s, MAIN, g.s)
			if d > NestBalance.REACH:
				continue
			var f := a.fighter()
			if tgt == null or (f and not tf) or (f == tf and d < td):
				tgt = a
				td = d
				tf = f
		g.hold = g.biters >= 2 or g.stam < NestBalance.HOLD_BELOW
		if tgt != null:
			var push := float(NestBalance.SPEAR_PUSH[g.spear]) * (1.0 + NestBalance.SKILL_PUSH * g.skill)
			push *= _dark_k(g, NestBalance.DARK_PUSH_K) * lerpf(NestBalance.TIRED_PUSH_MIN, 1.0, clampf(g.stam, 0.0, 1.0))
			if g.hold:
				push *= NestBalance.HOLD_PUSH_K
			tgt.grit -= push * dt
			g.doing = &"hold" if g.hold else &"push"
			if tgt.grit <= 0.0:
				_flip(tgt, g)
			if tf:
				g.nerve -= (NestBalance.NERVE_OUTNUM * outnum + (NestBalance.NERVE_DARK if g.dark else 0.0)) * dt
				if g.dark and t - _fumble_t >= 8.0:
					_fumble_t = t
					_note(&"dark_fumble", MAIN, g.s, g.id)
				# 싸우는 동안에도 앞사람은 줄을 지킨다 (뒤로 밀리지 않음)
				continue
		# 싸우지 않을 때: 숨 고르기
		g.stam = minf(1.0, g.stam + (NestBalance.REST_REGEN if rest_left > 0.0 else NestBalance.STAM_REGEN) * dt)
		g.nerve = minf(1.0, g.nerve + NestBalance.NERVE_REGEN * dt)
		if rest_left > 0.0:
			g.doing = &"rest"
			continue
		if pot_who == g.id:
			g.doing = &"pot"
			continue
		if block_i != -2 and g.s >= block_s - 0.8 - float(act.size()) * NestBalance.SPACING - 0.2 and absf(g.s - slot) < 0.3:
			g.doing = &"dig"
			g.stam -= NestBalance.DIG_STAM * dt
			diggers += 1
			continue
		if tgt == null:
			g.doing = &"walk"
		var sp := NestBalance.GUARD_SPEED * (_dark_k(g, NestBalance.DARK_SPEED_K))
		for m: Dictionary in mud:
			if absf(g.s - float(m["s"])) <= float(m["r"]):
				sp *= NestBalance.MUD_SPEED_K
				_note(&"mud_slow", MAIN, g.s, g.id, true)
				break
		var ns := move_toward(g.s, slot, sp * dt)
		if block_i != -2:
			ns = minf(ns, block_s - 0.8)
		g.s = ns
	if diggers > 0:
		if block_i == -1:
			_note(&"pebble_block", MAIN, NestBalance.PEBBLE_S, -1, true)
			pebble_work += float(diggers) * dt
			if pebble_work >= NestBalance.PEBBLE_WORK:
				pebble = false
				_note(&"pebble_cleared", MAIN, NestBalance.PEBBLE_S)
		elif block_i >= 0 and block_i < rubble.size():
			_note(&"rubble_block", MAIN, block_s, -1, true)
			rubble[block_i]["work"] = float(rubble[block_i]["work"]) + float(diggers) * dt
			if float(rubble[block_i]["work"]) >= NestBalance.RUBBLE_WORK:
				rubble.remove_at(block_i)
				_noted.erase(&"rubble_block")
				_note(&"rubble_cleared", MAIN, block_s)
	# 물러나는 사람
	for g in guards:
		if g.state == &"retreat":
			g.s -= NestBalance.GUARD_SPEED * (NestBalance.HURT_SPEED_K if g.hurt else 1.0) * dt
			if g.s <= 0.0:
				g.s = 0.0
				g.state = &"out"


func _leave(g: Guard, why: StringName) -> void:
	g.state = &"retreat"
	g.why = why
	g.doing = &"back"
	g.hold = false
	if why == &"hurt":
		g.hurt = true
	if pot_who == g.id:
		pot_who = -1
	for o in active():
		o.nerve -= NestBalance.NERVE_MATE_HURT if why == &"hurt" else NestBalance.NERVE_MATE_LEFT
	_emit(&"nest_guard_left", {"v": {"why": why, "room": zone_of(g.s)}, "at": Vector2(MAIN, g.s), "who": g.id})


# ───────────────────────── 강아지 ─────────────────────────
func _dog(dt: float) -> void:
	if not has_dog or dog_out:
		return
	if dog_bark_left > 0.0:
		dog_bark_left -= dt
	if dog_bark_cd > 0.0:
		dog_bark_cd -= dt
	var f := _front()
	if f == null:                                  # 원정대가 돌아서면 따라 나온다
		dog_s -= NestBalance.GUARD_SPEED * 1.2 * dt
		if dog_s <= 0.0:
			dog_s = 0.0
			dog_out = true
		return
	var want := f.s + NestBalance.DOG_AHEAD
	var hide := false
	for a in ants:
		if not a.standing() or a.seg != MAIN:
			continue
		if a.kind == &"big" and absf(a.s - f.s) <= NestBalance.DOG_SCARE_BIG:
			hide = true
		if a.fighter() and a.s > f.s:
			want = minf(want, a.s - 1.6)
	if hide:
		want = f.s - 2.5
		_note(&"dog_hides", MAIN, dog_s, -1, true)
	if pebble and f.s < NestBalance.PEBBLE_S:
		want = minf(want, NestBalance.PEBBLE_S - 0.6)
	dog_s = move_toward(dog_s, maxf(0.0, want), NestBalance.GUARD_SPEED * 1.4 * dt)
	if dog_bark_cd <= 0.0:
		var n := 0
		var startled := 0
		for a in ants:
			if a.standing() and a.seg == MAIN and a.kind != &"queen" and absf(a.s - dog_s) <= NestBalance.DOG_RANGE:
				n += 1
				if (a.kind == &"worker" or a.kind == &"scout") and a.state != &"stun":
					if a.kind == &"scout":
						_note(&"scout_startled", a.seg, a.s)
					_flip(a, null)
					startled += 1
		if n > 0:
			dog_bark_cd = NestBalance.BARK_EVERY
			dog_bark_left = NestBalance.BARK_SECS
			_note(&"bark", MAIN, dog_s)


# ───────────────────────── 원군 · 빛에 끌림 ─────────────────────────
func _reinforce(dt: float) -> void:
	if not alarm or reinf_sent >= reinf_max:
		return
	reinf_t -= dt
	if reinf_t > 0.0:
		return
	reinf_t = NestBalance.REINF_EVERY
	var n := mini(NestBalance.REINF_N, reinf_max - reinf_sent)
	for i in n:
		var a := _spawn(&"soldier", SIDE, NestBalance.SIDE_LEN - float(i) * 1.2, -1)
		a.state = &"attack"
	reinf_sent += n
	_emit(&"nest_reinforce", {"v": {"n": n, "sent": reinf_sent}, "at": Vector2(SIDE, NestBalance.SIDE_LEN)})


func _lamp_draw(dt: float) -> void:
	if lamp_left <= 0.0 or lit_room <= 0 or cleared[lit_room - 1] or lamp_drawn >= NestBalance.LAMP_DRAW_MAX:
		return
	_draw_t -= dt
	if _draw_t > 0.0:
		return
	_draw_t = NestBalance.LAMP_DRAW_EVERY
	# 빛을 보고 깊은 곳에서 병정 하나가 더 올라온다 (굴에 원래 있던 수와 따로)
	var a := _spawn(&"soldier", MAIN, NestBalance.DEEP_END, -1)
	a.state = &"attack"
	a.drawn = true
	lamp_drawn += 1
	_note(&"light_draws", MAIN, NestBalance.DEEP_END - 2.0)


# ───────────────────────── 시험·측정용 ─────────────────────────
## 지금 상태의 지문 (결정성 시험)
func state_hash() -> int:
	var parts: Array = [step_n, outcome, deepest, pebble, lit_room, snappedf(lamp_left, 0.001), snappedf(water_left, 0.001), reinf_sent, flipped, washed]
	for g in guards:
		parts.append([g.id, snappedf(g.s, 0.0001), snappedf(g.stam, 0.0001), snappedf(g.nerve, 0.0001), g.state, g.why])
	for a in ants:
		parts.append([a.id, a.kind, a.seg, snappedf(a.s, 0.0001), snappedf(a.grit, 0.0001), a.state])
	parts.append(loot)
	return hash(parts)
