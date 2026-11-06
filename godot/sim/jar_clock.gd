## 병의 시계 — 거인이 보고 있을 때 시간을 흘린다 (기획서 4.1 · 6.6 시간 빨리 돌리기).
## ×1 / ×2 / ×4 / ×8, 밤 건너뛰기(×60, 주민이 모두 잠든 밤 → 아침 6시에 ×1로), 위기(굶주림·재해)가 시작되면 ×1 + 알림.
## 배속은 '한 화면에 몇 걸음을 걷는가'만 바꾼다 — 걸음 크기는 늘 Balance.WATCH_STEP(병 시계 1초) →
## 같은 병 시간이면 ×1이든 ×8이든 결과가 똑같다 (테스트). 빨리 돌려도 거인이 지켜보는 시간 (Village.watching 그대로).
## 오프라인(앱을 끈 동안)은 이 시계를 쓰지 않는다 — Village.advance로 비운 현실 시간만큼 (×1과 같음).
class_name JarClock
extends RefCounted

var v: Village
var step := Balance.WATCH_STEP
var speed_i := 0                      # Balance.SPEEDS 번호
var skipping := false                 # 밤 건너뛰는 중
var acc := 0.0                        # 아직 걷지 않은 병 시간 (초)
var max_steps := Balance.MAX_STEPS_PER_FRAME
var steps_done := 0
var dropped := 0.0                    # 화면이 느려 버린 병 시간 (초) — 0이어야 정상
var notice := ""                      # 화면에 띄울 알림 (UI 문구)
var notice_t := 0.0                   # 알림이 남은 현실 시간 (초)
var last_crisis: Dictionary = {}


func _init(village: Village) -> void:
	v = village
	v.crises.clear()


func speed() -> float:
	return Balance.SKIP_NIGHT_SPEED if skipping else float(Balance.SPEEDS[speed_i])


func set_speed(i: int) -> void:
	skipping = false
	speed_i = clampi(i, 0, Balance.SPEEDS.size() - 1)


## 배속 버튼: ×1 → ×2 → ×4 → ×8 → ×1 (밤 건너뛰는 중이면 그만두고 ×1)
func cycle_speed() -> void:
	if skipping:
		set_speed(0)
	else:
		set_speed((speed_i + 1) % Balance.SPEEDS.size())


## 밤 건너뛰기 버튼은 밤에 주민이 모두 잠들었을 때만
func can_skip_night() -> bool:
	if skipping or not v.is_night() or v.people.is_empty():
		return false
	for p in v.people:
		if not p.sleeping:
			return false
	return true


func start_skip_night() -> bool:
	if not can_skip_night():
		return false
	skipping = true
	return true


## 현실 시간 real_dt초 → 병 시간 real_dt × 배속을 WATCH_STEP 걸음으로. 걸은 걸음 수를 돌려준다.
func tick(real_dt: float) -> int:
	if notice_t > 0.0:
		notice_t = maxf(0.0, notice_t - real_dt)
	acc += real_dt * speed()
	var n := 0
	while acc >= step and n < max_steps:
		v.step(step)
		acc -= step
		n += 1
		steps_done += 1
		if _after_step():
			acc = 0.0                 # 배속이 바뀌었으면 쌓인 빠른 시간은 버린다
			break
	if n >= max_steps and acc >= step:
		dropped += acc
		acc = 0.0
	return n


## 걸음마다: 위기 → ×1 + 알림, 밤 건너뛰기는 아침이 되면 끝. 배속이 바뀌었으면 true
func _after_step() -> bool:
	var changed := false
	if not v.crises.is_empty():
		last_crisis = v.crises.back()
		v.crises.clear()
		var was_fast := skipping or speed_i > 0
		set_speed(0)
		notice = "%s — 시간을 1배로 되돌렸어요" % last_crisis["text"] if was_fast else String(last_crisis["text"])
		notice_t = 8.0
		changed = was_fast
	elif skipping and not v.is_night():
		set_speed(0)
		notice = "아침이 밝았어요"
		notice_t = 4.0
		changed = true
	return changed
