## 개미굴 원정 시험판의 자동 거인 (docs/WORLD_EVENTS.md 2.1c · ROADMAP Q10 1.5걸음) — 측정(tools/measure_nest.gd) · 캡처 · 시험이 같이 쓴다.
## 다섯 가지:
##   none     돕지 않음
##   random   아무 데나 마구
##   scripted 첫 굴 '가' 생김새에 맞춘 정해진 순서·정해진 자리를 어느 굴에서나 그대로 되풀이 (굴이 다르면 헛손질)
##   clumsy   알맞게 하려 하지만 서툰 손: 2초에 한 번 보고, 넷에 한 번은 놓치고, 겨눈 뒤 0.5초 늦게 손이 간다
##   sensible 알맞게: 0.5초에 한 번 보고 바로 쓴다
## 자동 거인도 사람처럼 '보이는 것'만 본다 — 굴의 생김새(옆 굴·막힌 것)와 밝은 곳·횃불 곁의 개미, 보이지 않는 곳은 기척(ex.stir)만.
## 시뮬레이션 상태는 읽기만 하고 ex.gesture()로만 건드린다.
class_name NestBots
extends RefCounted

const KINDS: Array[String] = ["none", "random", "scripted", "clumsy", "sensible"]
const LOOK_EVERY := 5                  # 걸음 (0.5초)
const CLUMSY_LOOK := 20                # 서툰 손: 2초에 한 번
const CLUMSY_MISS := 0.25              #          넷에 한 번은 놓친다
const CLUMSY_DELAY := 5                #          겨눈 뒤 0.5초 늦게
## '가' 생김새(첫 굴)의 자리들 — scripted가 외운 것
const SCRIPT_PEBBLE_S := 5.6
const SCRIPT_FIGHT_S := 44.5           # 병정 방에서 큰 병정과 맞붙는 자리
const SCRIPT_SIDE := 2

var kind := "none"
var brng := RandomNumberGenerator.new()
var acts: Array = []                   # [초, 손짓, seg, s] — 캡처·글용
var _pend: Array = []                  # 서툰 손이 겨눠 둔 손짓 [손짓, seg, s]
var _pend_at := 0
var _z2_t := -1.0                      # scripted: 병정 방 구역에 든 때
var _alarm_t := -1.0
var _did := {}


func _init(k := "none", seed_value := 0) -> void:
	kind = k
	brng.seed = hash([seed_value, 0x626f74])


## 걸음마다 부른다 (ex.step() 앞)
func act(ex: NestExpedition) -> void:
	if ex.over:
		return
	if kind == "clumsy":
		if not _pend.is_empty() and ex.step_n >= _pend_at:
			_use(ex, _pend[0], int(_pend[1]), float(_pend[2]))
			_pend = []
		if ex.step_n % CLUMSY_LOOK == 0 and _pend.is_empty():
			var p := plan(ex)
			if not p.is_empty() and brng.randf() >= CLUMSY_MISS:
				_pend = p
				_pend_at = ex.step_n + CLUMSY_DELAY
		return
	if ex.step_n % LOOK_EVERY != 0:
		return
	match kind:
		"random":
			_random(ex)
		"scripted":
			_scripted(ex)
		"sensible":
			var p2 := plan(ex)
			if not p2.is_empty():
				_use(ex, p2[0], int(p2[1]), float(p2[2]))


func _use(ex: NestExpedition, g: StringName, seg: int, s: float) -> bool:
	if ex.gesture(g, seg, s):
		acts.append([ex.t, g, seg, s])
		return true
	return false


static func front(ex: NestExpedition) -> NestExpedition.Guard:
	var best: NestExpedition.Guard = null
	for g in ex.guards:
		if g.state == &"go" and (best == null or g.s > best.s):
			best = g
	return best


## 마구: 쓸 수 있는 손짓을 가끔 아무 자리에나
func _random(ex: NestExpedition) -> void:
	for g: StringName in NestExpedition.GESTURES:
		if ex.can_use(g) and brng.randf() < 0.12:
			var seg := NestExpedition.MAIN
			var segs: Array = ex.side_at.keys()
			if not segs.is_empty() and brng.randf() < 0.2:
				seg = int(segs[brng.randi() % segs.size()])
			var s := brng.randf_range(1.0, NestBalance.SIDE_LEN - 1.0) if seg != NestExpedition.MAIN else brng.randf_range(NestBalance.ENTRY_END * 0.5, ex.deep_end - 2.0)
			_use(ex, g, seg, s)
			return


## 외운 순서 ('가' 생김새): 어귀의 조약돌을 집고 → 병정 방에 들 때 등불 + 아래 옆 굴에 각설탕 → 맞붙는 자리에 핀셋 → 경보 뒤 아래 옆 굴에 물 → 여왕 방에 등불
func _scripted(ex: NestExpedition) -> void:
	var f := front(ex)
	if f == null:
		return
	var z := ex.zone_of(f.s)
	if z >= 2 and _z2_t < 0.0:
		_z2_t = ex.t
	if ex.alarm and _alarm_t < 0.0:
		_alarm_t = ex.t
	if not _did.has("pebble") and ex.can_use(&"tweezers"):
		_did["pebble"] = true
		_use(ex, &"tweezers", NestExpedition.MAIN, SCRIPT_PEBBLE_S)
		return
	if _z2_t >= 0.0 and not _did.has("lamp2") and ex.can_use(&"lamp"):
		_did["lamp2"] = true
		_use(ex, &"lamp", NestExpedition.MAIN, ex.room_mid(1))
		return
	if _z2_t >= 0.0 and not _did.has("sugar") and ex.can_use(&"sugar"):
		_did["sugar"] = true
		_use(ex, &"sugar", SCRIPT_SIDE, 6.0)
		return
	if _z2_t >= 0.0 and ex.t >= _z2_t + 6.0 and not _did.has("big") and ex.can_use(&"tweezers"):
		_did["big"] = true
		_use(ex, &"tweezers", NestExpedition.MAIN, SCRIPT_FIGHT_S)
		return
	if _alarm_t >= 0.0 and ex.t >= _alarm_t + 26.0 and ex.can_use(&"water"):
		_use(ex, &"water", SCRIPT_SIDE, NestBalance.SIDE_LEN * 0.5)
		return
	if z >= 3 and ex.can_use(&"lamp"):
		_use(ex, &"lamp", NestExpedition.MAIN, ex.room_mid(2))


## 알맞은 손짓 하나 [손짓, seg, s] (없으면 []) — 보이는 것만 보고 고른다
func plan(ex: NestExpedition) -> Array:
	var f := front(ex)
	if f == null:
		return []
	var M := NestExpedition.MAIN
	var z := ex.zone_of(f.s)
	var cur := ex.cur_room()
	# 유리 톡: 큰 병정이 몸을 세웠다
	if ex.can_use(&"tap"):
		for a in ex.ants:
			if a.kind == &"big" and a.wind > 0.3 and ex.ant_visible(a):
				return [&"tap", M, f.s]
	# 핀셋: 길을 막은 것 · 맞붙은 큰 병정
	if ex.can_use(&"tweezers") and not ex.tweeze_on:
		for a in ex.ants:
			if a.kind == &"big" and a.standing() and a.seg == M and ex.ant_visible(a) and a.state != &"stun":
				if absf(a.s - f.s) <= NestBalance.CONTACT + 1.2 or a.state == &"home":
					return [&"tweezers", M, a.s]
		if ex.pebble and f.s >= ex.block_s - 8.0 and f.s < ex.block_s:
			return [&"tweezers", M, ex.block_s]
		for rb: Dictionary in ex.rubble:
			var rs := float(rb["s"])
			if rs > f.s - 0.5 and rs < f.s + 8.0:
				return [&"tweezers", M, rs]
	# 등불: 곧 들어설 어두운 방 · 어둠 속 물웅덩이
	if ex.can_use(&"lamp"):
		var za := ex.zone_of(f.s + 5.0)
		if za >= 2 and not ex.cleared[za - 1] and ex.is_dark(M, f.s + 5.0) and f.s >= float(ex.rooms[za - 1][0]) - NestBalance.LAMP_NEAR + 1.0 and (ex.stir(za - 1) > 0 or (ex.puddle and ex.zone_of(ex.block_s) == za and f.s < ex.block_s + 2.0)):
			return [&"lamp", M, ex.room_mid(za - 1)]
		if z >= 2 and not ex.cleared[z - 1] and ex.is_dark(M, f.s) and ex.stir(z - 1) > 0:
			return [&"lamp", M, ex.room_mid(z - 1)]
	# 물: 옆 굴에 원군의 기척이 있고, 우글우글하지는 않을 때 (꽉 차면 넘친다)
	if ex.can_use(&"water"):
		for k: int in ex.side_at:
			if ex.junction(k) > ex.smoke_end() and ex.water_in(k) <= 0.0 and ex.stir(k, true) == 1 and not (ex.sugar_on and ex.sugar_seg == k):
				return [&"water", k, NestBalance.SIDE_LEN * 0.5]
	# 각설탕: 방 어귀에서, 그 방이 밝아 큰 병정이 없는 것이 보일 때 (또는 핀셋이 내려오는 중) — 원정대를 지나지 않고 갈 수 있는 옆 굴로.
	# 병정들이 방을 비운 사이에 연기를 피우면 돌아오지 못한다. 늦으면 단것을 먹고 더 세져서 돌아온다.
	if ex.can_use(&"sugar") and cur >= 1:
		var room0 := float(ex.rooms[cur][0])
		var big_here := false
		var soldiers := 0
		for a in ex.ants:
			if a.standing() and a.seg == M and ex.zone_of(a.s) == cur + 1 and ex.ant_visible(a):
				if a.kind == &"big":
					big_here = true
				elif a.kind == &"soldier":
					soldiers += 1
		if f.s >= room0 - 3.0 and not ex.is_dark(M, ex.room_mid(cur)) and soldiers > 0 and (not big_here or ex.tweeze_on):
			for k: int in ex.side_at:
				var j := ex.junction(k)
				if j <= ex.smoke_end() or ex.water_in(k) > 0.0 or ex.stir(k, true) > 0:
					continue
				if j > f.s + 4.0 and absf(j - ex.room_mid(cur)) <= NestBalance.SUGAR_RANGE - 8.0:
					return [&"sugar", k, 6.0]
	return []
