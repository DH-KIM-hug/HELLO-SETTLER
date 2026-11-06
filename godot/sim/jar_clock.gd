## 병의 시계 — 거인이 보고 있을 때 시간을 흘린다 (기획서 4.1 · 6.6 시간 빨리 돌리기).
## ×1 / ×2 / ×4 / ×8, 밤 건너뛰기(주민이 모두 잠든 밤 → 다음 새벽 6시까지 현실 약 3초 타임랩스 → ×1), 위기(굶주림·재해)가 시작되면 ×1 + 알림.
## 배속은 '한 화면에 몇 걸음을 걷는가'만 바꾼다 — 걸음 크기는 늘 Balance.WATCH_STEP(병 시계 1초) →
## 같은 병 시간이면 ×1이든 ×8이든 결과가 똑같다 (테스트). 빨리 돌려도 거인이 지켜보는 시간 (Village.watching 그대로).
## 오프라인(앱을 끈 동안)은 이 시계를 쓰지 않는다 — Village.advance로 비운 현실 시간만큼 (×1과 같음).
## 밤 건너뛰기만은 몰아서 계산하는 굵은 걸음을 쓴다 (주민은 어차피 자는 중, 3초 안에 끝내야 하므로):
##   걸음 = Village.step_dt (Balance.STEP 10초), 물 = 오프라인 간격(water.offline, 300초). 거인이 보는 중(watching)은 그대로.
##   → 결과는 같은 구간을 Village.advance(skip_span)로 몰아서 계산한 것과 똑같다 (water.offline = true 동안. 테스트).
##   현실 시간에 따라 몇 걸음까지 갔는지만 나눠서 걷는다 (skip_progress 0 → 1).
class_name JarClock
extends RefCounted

var v: Village
var step := Balance.WATCH_STEP
var speed_i := 0                      # Balance.SPEEDS 번호
var skipping := false                 # 밤 건너뛰는 중
var skip_span := 0.0                  # 이번 밤 건너뛰기의 병 시간 (초) — 누른 때부터 다음 06:00까지
var skip_real := 0.0                  # 건너뛰기를 시작한 뒤 흐른 현실 시간 (초)
var skip_progress := 0.0              # 0~1 (화면 연출용)
var _skip_left := 0.0                 # 아직 걷지 않은 병 시간 — Village.advance와 같은 방식으로 줄여 감
var _skip_steps := 0                  # 지금까지 걸은 굵은 걸음 수
var _skip_total := 0                  # 전체 굵은 걸음 수
var _water_offline_before := false
var acc := 0.0                        # 아직 걷지 않은 병 시간 (초)
var max_steps := Balance.MAX_STEPS_PER_FRAME
var steps_done := 0
var dropped := 0.0                    # 화면이 느려 버린 병 시간 (초) — 0이어야 정상
var notice := ""                      # 화면에 띄울 알림 (UI 문구)
var notice_t := 0.0                   # 알림이 남은 현실 시간 (초)
var last_crisis: Dictionary = {}
var lid_real := 0.0                   # [곰팡이·뚜껑] 뚜껑이 열린 뒤 흐른 현실 시간 (초) — 1분이면 저절로 닫힘 (WORLD_EVENTS 3)


func _init(village: Village) -> void:
	v = village
	v.crises.clear()


## 지금 배속 (밤 건너뛰는 중이면 남은 밤 ÷ 3초 — 표시용)
func speed() -> float:
	if skipping:
		return skip_span / Balance.SKIP_NIGHT_SECONDS
	return float(Balance.SPEEDS[speed_i])


func set_speed(i: int) -> void:
	if skipping:
		_end_skip()
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


## 지금부터 다음 새벽(Balance.NIGHT_TO, 6시)까지의 병 시간 (초). 06:00 표시가 05:59로 내려가지 않게 1 ms 더함.
func time_to_dawn() -> float:
	var c := fmod(v.start_clock + v.t, Balance.DAY)
	var dawn := Balance.NIGHT_TO * Balance.HOUR
	var left := dawn - c
	if left <= 0.0:
		left += Balance.DAY
	return left + 0.001


func start_skip_night() -> bool:
	if not can_skip_night():
		return false
	skipping = true
	skip_span = time_to_dawn()
	skip_real = 0.0
	skip_progress = 0.0
	_skip_left = skip_span
	_skip_steps = 0
	_skip_total = ceili(skip_span / v.step_dt - 1e-9)
	_water_offline_before = v.water.offline
	v.water.offline = true
	acc = 0.0
	return true


func _end_skip() -> void:
	skipping = false
	v.water.offline = _water_offline_before
	acc = 0.0


## 밤 건너뛰기 한 화면: 현실 시간 비율만큼의 굵은 걸음까지 걷는다 (Village.advance와 같은 조각: min(step_dt, 남은 시간))
func _tick_skip(real_dt: float) -> int:
	skip_real += real_dt
	var f := skip_real / Balance.SKIP_NIGHT_SECONDS
	var goal := ceili(_skip_total * f) if f < 1.0 else 1 << 30
	var n := 0
	while _skip_steps < goal and _skip_left > 1e-6:
		var dt := minf(v.step_dt, _skip_left)
		_skip_left -= dt
		v.step(dt)
		_skip_steps += 1
		steps_done += 1
		n += 1
		if not v.crises.is_empty():
			_after_step()             # 위기 → ×1 + 알림 (건너뛰기 끝)
			return n
	skip_progress = float(_skip_steps) / maxf(1.0, _skip_total)
	if _skip_left <= 1e-6:
		_end_skip()
		set_speed(0)
		notice = "아침이 밝았어요"
		notice_t = 4.0
	return n


## 현실 시간 real_dt초 → 병 시간 real_dt × 배속을 WATCH_STEP 걸음으로. 걸은 걸음 수를 돌려준다.
func tick(real_dt: float) -> int:
	if notice_t > 0.0:
		notice_t = maxf(0.0, notice_t - real_dt)
	_lid_auto_close(real_dt)
	if skipping:
		return _tick_skip(real_dt)
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
	return changed


## [곰팡이·뚜껑] 안 닫으면 현실 1분 뒤 저절로 닫힘 (배속과 상관없이 현실 시간 — 병 시계 안전장치는 JarAir)
func _lid_auto_close(real_dt: float) -> void:
	if v.air == null or not v.air.lid_open:
		lid_real = 0.0
		return
	lid_real += real_dt
	if lid_real >= Balance.LID_AUTO_CLOSE_REAL:
		v.close_lid()
		lid_real = 0.0
		notice = "뚜껑이 저절로 닫혔어요"
		notice_t = 3.0
