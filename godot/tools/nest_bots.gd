## 개미굴 원정 시험판의 자동 거인 (docs/WORLD_EVENTS.md 2.1c · ROADMAP Q10 1걸음) — 측정(tools/measure_nest.gd) · 캡처 · 시험이 같이 쓴다.
## 세 가지: none 돕지 않음 · random 아무 데나 마구 · sensible 알맞게
##   (원정대가 있는 방을 밝힘 · 원군이 옆 굴에 보이면 물 · 조약돌/큰 병정을 핀셋 · 병정 방에 들기 전에 각설탕 · 큰 병정이 몸을 세우면 유리 톡).
## 사람처럼 0.5초에 한 번 보고 한 번에 손짓 하나. 시뮬레이션 상태는 읽기만 하고 ex.gesture()로만 건드린다.
class_name NestBots
extends RefCounted

const KINDS: Array[String] = ["none", "random", "sensible"]
const LOOK_EVERY := 5                  # 걸음 (0.5초)

var kind := "none"
var brng := RandomNumberGenerator.new()
var acts: Array = []                   # [초, 손짓, seg, s] — 캡처·글용


func _init(k := "none", seed_value := 0) -> void:
	kind = k
	brng.seed = hash([seed_value, 0x626f74])


## 걸음마다 부른다 (ex.step() 앞)
func act(ex: NestExpedition) -> void:
	if ex.over or ex.step_n % LOOK_EVERY != 0:
		return
	match kind:
		"random":
			_random(ex)
		"sensible":
			_sensible(ex)


func _use(ex: NestExpedition, g: StringName, seg: int, s: float) -> bool:
	if ex.gesture(g, seg, s):
		acts.append([ex.t, g, seg, s])
		return true
	return false


## 마구: 쓸 수 있는 손짓을 가끔 아무 자리에나
func _random(ex: NestExpedition) -> void:
	for g: StringName in NestExpedition.GESTURES:
		if ex.can_use(g) and brng.randf() < 0.12:
			var seg := NestExpedition.SIDE if brng.randf() < 0.2 else NestExpedition.MAIN
			var s := brng.randf_range(1.0, NestBalance.SIDE_LEN - 1.0) if seg == NestExpedition.SIDE else brng.randf_range(NestBalance.ENTRY_END, NestBalance.DEEP_END - 4.0)
			if g == &"lamp":
				seg = NestExpedition.MAIN
			_use(ex, g, seg, s)
			return


func _sensible(ex: NestExpedition) -> void:
	var f := ex._front()
	if f == null:
		return
	var z := NestExpedition.zone_of(f.s)
	var cur := ex.cur_room()
	# 유리 톡: 큰 병정이 몸을 세웠다
	if ex.can_use(&"tap"):
		for a in ex.ants:
			if a.wind > 0.3:
				_use(ex, &"tap", 0, 0.0)
				return
	# 물: 옆 굴에 개미가 보이고 아직 젖지 않았다
	if ex.can_use(&"water") and ex.water_left <= 0.0:
		var deep := 0
		for a in ex.ants:
			if a.seg == NestExpedition.SIDE and a.standing() and a.s < NestBalance.SIDE_LEN - 3.0:
				deep += 1
		if deep > 0:
			_use(ex, &"water", NestExpedition.SIDE, NestBalance.SIDE_LEN * 0.5)
			return
	# 등불: 원정대가 있는 (아직 못 비운) 방
	if ex.can_use(&"lamp") and z >= 1 and not ex.cleared[z - 1] and (ex.lamp_left <= 1.0 or ex.lit_room != z):
		_use(ex, &"lamp", NestExpedition.MAIN, NestExpedition.room_mid(z - 1))
		return
	# 각설탕: 다음 방에 들기 바로 전에 옆 굴 어귀로
	if ex.can_use(&"sugar") and cur >= 1 and not ex.sugar_on:
		var gate := (NestBalance.PEBBLE_S + 0.5) if cur == 1 else float(NestBalance.ROOMS[1][1]) - 6.0
		var room0 := float(NestBalance.ROOMS[cur][0])
		if f.s >= gate and f.s < room0 + 2.0 and (cur != 1 or not ex.pebble) and ex.rest_left <= 0.5:
			var n := 0
			for a in ex.ants:
				if a.kind == &"soldier" and a.standing() and a.home == cur:
					n += 1
			if n >= 2:
				_use(ex, &"sugar", NestExpedition.SIDE, 5.0)
				return
	# 핀셋: 원정대와 맞붙은 큰 병정 · 길 막은 조약돌 (원정대가 닿았을 때)
	if ex.can_use(&"tweezers") and not ex.tweeze_on:
		for a in ex.ants:
			if a.kind == &"big" and a.standing() and a.seg == NestExpedition.MAIN and (a.state == &"attack" or absf(a.s - f.s) < 14.0) and NestExpedition.zone_of(a.s) == z:
				var lead := 0.0
				if a.state == &"attack" and absf(a.s - f.s) > NestBalance.CONTACT + 0.5:
					lead = -float(NestBalance.ANT_SPEED["big"]) * NestBalance.TWEEZE_SECS * 0.8
				_use(ex, &"tweezers", NestExpedition.MAIN, a.s + lead)
				return
		if ex.pebble and ex.cleared[0] and f.s >= NestBalance.PEBBLE_S - 6.0:
			_use(ex, &"tweezers", NestExpedition.MAIN, NestBalance.PEBBLE_S)
			return
