## (재기 전용) 시뮬 계통별 시간 재기 — tools/profile_sim.gd가 켠다. 꺼져 있으면 mark()는 아무것도 안 한다.
class_name SimProf
extends RefCounted

static var on := false
static var acc: Dictionary = {}       # 이름 → 쌓인 마이크로초
static var cnt: Dictionary = {}       # 이름 → 부른 횟수
static var _last := 0


## 구간 시작 (지금 시각을 기억)
static func begin() -> void:
	if on:
		_last = Time.get_ticks_usec()


## 직전 begin/mark부터 지금까지를 name에 더한다
static func mark(name: String) -> void:
	if not on:
		return
	var now := Time.get_ticks_usec()
	acc[name] = int(acc.get(name, 0)) + (now - _last)
	cnt[name] = int(cnt.get(name, 0)) + 1
	_last = now


## 따로 재기 (안쪽 구간): var u := SimProf.now() … SimProf.add("이름", u)
static func now() -> int:
	return Time.get_ticks_usec() if on else 0


static func add(name: String, since: int) -> void:
	if not on:
		return
	acc[name] = int(acc.get(name, 0)) + (Time.get_ticks_usec() - since)
	cnt[name] = int(cnt.get(name, 0)) + 1


static func reset() -> void:
	acc.clear()
	cnt.clear()
