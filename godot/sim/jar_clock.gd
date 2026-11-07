## 병의 시계 — 거인이 보고 있을 때 시간을 흘린다 (기획서 4.1 · 6.6 시간 빨리 돌리기, v4.3).
## 배속 (Balance.SPEEDS): 느리게 (1일=20분) · 조금 느리게 (10분) · 보통 (1일=5분, 기본 ×288) · 빠르게 (2분) · 아주 빠르게 (1분)
##   · 1초=5분 · 1초=10분 · 1초=1시간 · 1초=5시간 · 1초=12시간. 칩을 누르면 앞 다섯이 돌고, 길게 누르면 목록.
## 모든 배속은 따라잡기(CatchUp)와 같은 정밀 걸음 — Village.step_dt(10초) 걸음 + 물 오프라인 간격(300초) +
##   넓은 세상 정리(JarWorld 분가·고운 물 범위)를 FAST_HOOK_EVERY(300초)마다. 배속은 '한 화면에 몇 걸음을 걷는가'만 바꾼다 →
##   같은 병 시간이면 어느 배속이든, 화면 길이·계산 예산이 어떻든 결과가 똑같다 (= JarWorld.advance(300)씩 흘린 것, 테스트).
##   한 화면에 Balance.FAST_BUDGET_MS 동안만 걷고, 못 따라가면 밀린 시간은 버린다 (실제 배속 rate가 내려가고 칩에 작게 — 화면은 멈추지 않음).
## 위기(굶주림·재해)가 시작되면 보통보다 빠를 때 보통으로 + 알림. 보통보다 빠를 때 중요한 일(출생·사망·깨달음·계시·편지·위기 예고)이
##   생기면 보통으로 + 무슨 일인지 (events — 화면이 '느려진 까닭' 카드로: 누구·어디 · [보러 가기] · [계속 빠르게] = resume_fast).
##   멈출 일은 설정 "빠르게 갈 때 멈출 일" (GameSettings.stop_*) — 끈 일·자잘한 일(잇단 편지·큰 버섯)은 멈추지 않고 짧은 알림만. 빨리 돌려도 거인이 지켜보는 시간 (Village.watching 그대로).
## 창세의 날(첫 병 첫날, CREATION_SPEED)만은 1초 걸음 (Balance.WATCH_STEP — 옛 방식).
## 오프라인(앱을 끈 동안)은 이 시계를 쓰지 않는다 — CatchUp (등불 · 자리를 비운 동안 배율).
## 밤 건너뛰기: 다음 새벽(6시)까지 현실 약 3초 — 같은 굵은 걸음 (Village.step_dt, 물 오프라인).
##   → 결과는 같은 구간을 Village.advance(skip_span)로 몰아서 계산한 것과 똑같다 (테스트). 끝나면 보통으로.
class_name JarClock
extends RefCounted

var v: Village
var step := Balance.WATCH_STEP
var speed_i := Balance.SPEED_DEFAULT_I   # Balance.SPEEDS 번호 (v4.3 목록)
var speed_v := 2                      # 배속 목록 판 — 옛 저장(×1~×60 번호)은 불러올 때 보통으로
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
var world: JarWorld = null            # 넓은 세상이면 그 세상 (빠른 흐름의 무리 정리 — 화면이 넣어 줌, 저장 안 함)
var fast := false                     # 빠른 흐름 중 (물 오프라인 간격)
var _fast_water_before := false
var _fast_hook := 0.0                 # 빠른 흐름: 지난 무리 정리 뒤 흐른 병 시간 (초)
var rate := 0.0                       # 실제로 흐른 배속 (병 초 ÷ 현실 초, 부드럽게) — 빠른 흐름이 못 따라가면 목표보다 작다
var behind := 0.0                     # 빠른 흐름이 따라가지 못해 버린 병 시간 (초)
var budget_ms := -1.0                 # 빠른 흐름 한 화면 계산 시간 (ms) — <0이면 기기에 맞게 (fast_budget_ms)
var auto_slow := true                 # 빠른 흐름 중 중요한 일 → ×1 (시험은 끌 수 있음)
var last_event := ""                  # 마지막으로 천천히 되돌린 까닭 (born·died·aware·revelation·letter·omen·settle)
var events: Array = []                # 빠른 흐름 중 생긴 일 — 화면이 가져감 (take_events). {cat, kind, text, icon, village, who, pos, stop} (저장 안 함)
var prev_speed_i := -1                # 중요한 일로 보통이 되기 전 배속 ([계속 빠르게] — resume_fast). -1 = 없음
var stop_count := {}                  # 갈래 → 지금까지 그 일로 멈춘 횟수 (탄생·편지는 처음 몇 번만 — STOP_FIRST_FEW)
var stop_last_t := {}                 # 갈래 → 마지막으로 멈춘 병 시각 (편지가 잇달아 오면 알림만 — LETTER_GAP)
var _step_ms := 0.0                   # 빠른 걸음 하나의 평균 계산 시간 (예산 맞추기)
var lid_real := 0.0                   # [곰팡이·뚜껑] 뚜껑이 열린 뒤 흐른 현실 시간 (초) — 1분이면 저절로 닫힘 (WORLD_EVENTS 3)
# 창세의 날 (OPENING 3.0 v3.3): 첫 병의 첫날(7시 → 다음 6시)은 현실 약 12분 — 빠르기는 Notebook.day_speed (보통에 대한 몫,
# 수첩 쪽지·장면 앞에서 느리게, 수첩 뒤 빠르게) × 거인이 고른 배속 ÷ 보통. 첫 저녁 기도 뒤 모두 잠들면 밤을 저절로 건너뛰고, 아침이 되면 끝 →
# 보통으로 돌아오고 배속 단추를 한 줄로 알려 준다. 저장된다 (다시 켜도 되풀이하지 않음)
var creation := false
var creation_until := 0.0             # 끝나는 병 시각 t
var creation_done := false            # 창세의 날을 지났다 (끝까지 갔든 거인이 바꿨든)
var creation_real := 0.0              # [창세의 날 v3.3] 창세의 날이 흐른 현실 초 (빠르기 단계 — Notebook.day_speed)

const CREATION_SPEED := 12.0          # (옛 ×12 — 이제 창세의 날 빠르기는 Notebook.day_scale × 보통(1일=5분) × 고른 배속÷보통: 쪽지 동안 0.08 · 장면 앞 0.03~0.04 · 수첩 뒤 1.15, 첫날 ≈ 현실 10~12분)
const EVENT_NOTE := "중요한 일이 생겨서 천천히 흘러가요"     # (옛 알림 — 이제 무슨 일인지 이름으로: events[i].text)
const SAVE_SKIP := ["v", "world", "rate", "budget_ms", "auto_slow", "_step_ms", "events"]
const STOP_CATS := ["born", "died", "omen", "letter", "reveal", "settle"]   # 설정 "빠르게 갈 때 멈출 일" 갈래 (GameSettings.stop_<갈래>)
const STOP_FIRST_FEW := 3             # 탄생·편지는 설정이 꺼져 있어도 처음 세 번은 멈춘다
const LETTER_GAP := 6.0 * 3600.0      # 편지가 병 6시간 안에 또 오면 멈추지 않고 알림만
const MINOR_KINDS := ["grove"]        # 자잘한 일 (멈추지 않고 알림만) — 큰 버섯 같은 작은 발견
const OMEN_WORDS := {"mold_omen": "곰팡이 조짐", "gnat": "날벌레 조짐", "drop_omen": "물방울 조짐", "dust_omen": "잿빛 가루 조짐",
	"frost": "서리 조짐", "sick": "병 조짐", "severe": "아픈 사람"}
const OMEN_ICONS := {"mold_omen": "빵", "sick": "약초", "severe": "약초", "frost": "해", "drop_omen": "물", "dust_omen": "돌", "gnat": "불기", "grove": "버섯"}
const CREATION_HINT := "병의 첫날이 지났어요. 이제부터는 아래 [속도] 단추로 병의 시간을 빠르게 흘릴 수 있어요."


## 창세의 날을 시작한다 (첫 병을 막 만들었을 때만 — 두 번째 병부터는 부르지 않는다)
func start_creation_day() -> void:
	if creation_done:
		return
	creation = true
	creation_until = v.t + time_to_dawn()
	speed_i = Balance.SPEED_DEFAULT_I


func _end_creation(hint: bool) -> void:
	if not creation:
		return
	creation = false
	creation_done = true
	if hint:
		notice = CREATION_HINT
		notice_t = 12.0


func _init(village: Village) -> void:
	v = village
	v.crises.clear()


## 지금 배속 (밤 건너뛰는 중이면 남은 밤 ÷ 3초 — 표시용)
func speed() -> float:
	if skipping:
		return skip_span / Balance.SKIP_NIGHT_SECONDS
	if creation:                      # [창세의 날 v3.3] 첫날 빠르기 (보통에 대한 몫) × 거인이 고른 배속 ÷ 보통
		return Notebook.day_speed(v, creation_real) * float(Balance.SPEEDS[speed_i]) / normal_speed()
	return float(Balance.SPEEDS[speed_i])


## 배속 이름 (칩·목록): ×1 … ×60 · 1초=5분 … 1초=12시간
static func label_of(i: int) -> String:
	return String(Balance.SPEED_LABELS[clampi(i, 0, Balance.SPEED_LABELS.size() - 1)])


## 배속 목록의 작은 줄 ("1일=5분", "1초=…"는 "")
static func note_of(i: int) -> String:
	return String(Balance.SPEED_NOTES[clampi(i, 0, Balance.SPEED_NOTES.size() - 1)])


## 아무 배속이나 이름으로 (실제 배속 표시용): 아주 느림 = ×N · 1일=N분 · 1초=N분 · 1초=N시간
static func rate_label(x: float) -> String:
	if x < Balance.FAST_FROM:
		return "×%d" % maxi(1, roundi(x))
	if x < 300.0:
		return "1일=%d분" % maxi(1, roundi(Balance.DAY / x / 60.0))
	if x < Balance.HOUR:
		return "1초=%d분" % maxi(1, roundi(x / 60.0))
	var h := x / Balance.HOUR
	return "1초=%s시간" % (str(snappedf(h, 0.1)) if h < 10.0 else str(roundi(h)))


## 지금 칩에 띄울 배속 이름 — 빠른 흐름이 목표의 85%를 못 내면 실제 배속을 작게 덧붙인다 ("1초=12시간 (실제 1초=3시간)")
func speed_text() -> String:
	var s := label_of(speed_i)               # 창세의 날도 고른 배속 이름 그대로 (첫날의 빠르기 변화는 수첩·장면이 맡음)
	if fast and rate > 0.0 and rate < speed() * 0.85:
		s += " (실제 %s)" % rate_label(rate)
	return s


## 이 기기에서 고를 수 있는 마지막 배속 번호 — 느린 기기는 Balance.FAST_TOP_SLOW까지 (못 따라가는 배속은 목록에서 뺀다)
static func top_speed_i() -> int:
	return mini(Balance.SPEEDS.size() - 1, Balance.FAST_TOP_SLOW) if slow_device() else Balance.SPEEDS.size() - 1


## 휴대폰·코어 4개 이하·메모리 3 GB 미만 (넓은 세상의 작은 세상 기준과 같음)
static func slow_device() -> bool:
	if OS.has_feature("mobile"):
		return true
	var mem := float(OS.get_memory_info().get("physical", 0))
	return OS.get_processor_count() <= 4 or (mem > 0.0 and mem < 3.0e9)


func fast_budget_ms() -> float:
	if budget_ms >= 0.0:
		return budget_ms
	return Balance.FAST_BUDGET_MS_SLOW if slow_device() else Balance.FAST_BUDGET_MS


## 배속을 정한다 — 창세의 날이었다면 끝난다 (거인이 다른 배속을 골랐거나 위기·밤 건너뛰기가 끝나 ×1로)
func set_speed(i: int) -> void:
	if skipping:
		_end_skip()
	speed_i = clampi(i, 0, Balance.SPEEDS.size() - 1)     # [창세의 날 v3.3] 배속을 골라도 창세의 날은 이어짐 (그 위에 곱함)
	_sync_fast()
	rate = speed()


## 배속 버튼: 보통 → 빠르게 → 아주 빠르게 → 느리게 → 조금 느리게 → 보통 (앞 다섯, Balance.SPEED_TAP_N).
## 밤 건너뛰는 중·창세의 날·"1초=…" 배속에서 누르면 보통으로
func cycle_speed() -> void:
	if skipping or speed_i >= Balance.SPEED_TAP_N:
		set_speed(Balance.SPEED_DEFAULT_I)
	else:
		set_speed((speed_i + 1) % Balance.SPEED_TAP_N)


## 보통 (기본 배속) 값
static func normal_speed() -> float:
	return float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I])


## 화면을 가볍게 할 배속인가 (주민 몸짓 멈춤·말풍선 없음 — Balance.VIEW_FAST_FROM)
func view_fast() -> bool:
	return fast and speed() >= Balance.VIEW_FAST_FROM


## 빠른 흐름에 들어가고 나온다 (배속·밤 건너뛰기·창세의 날에 맞게): 물 간격을 오프라인으로 / 원래대로
func _sync_fast() -> void:
	var want := not skipping and not creation and float(Balance.SPEEDS[speed_i]) >= Balance.FAST_FROM
	if want == fast:
		return
	fast = want
	if fast:
		_fast_water_before = v.water.offline
		v.water.offline = true
		_fast_hook = 0.0
		rate = speed()
	else:
		v.water.offline = _fast_water_before
		acc = minf(acc, step)         # 빠른 걸음의 남은 조각은 버린다 (1초 걸음으로 돌아감)


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
	if fast:                          # 빠른 흐름에서 밤 건너뛰기 → 물 간격을 먼저 원래대로
		fast = false
		v.water.offline = _fast_water_before
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
		set_speed(Balance.SPEED_DEFAULT_I)
		notice = "아침이 밝았어요"
		notice_t = 4.0
		if creation and v.t >= creation_until - 1.0:     # [창세의 날 v3.3] 첫날 밤을 건너뛰면 창세의 날 끝
			_end_creation(true)
	return n


## 현실 시간 real_dt초 → 병 시간 real_dt × 배속을 WATCH_STEP 걸음으로. 걸은 걸음 수를 돌려준다.
func tick(real_dt: float) -> int:
	if notice_t > 0.0:
		notice_t = maxf(0.0, notice_t - real_dt)
	_lid_auto_close(real_dt)
	if skipping:
		rate = speed()
		return _tick_skip(real_dt)
	Notebook.tick(v, real_dt)         # [거인의 수첩] 쪽지 차례 (현실 시간)
	if creation:                      # [창세의 날 v3.3] 첫 저녁 기도 뒤 모두 잠들면 밤을 저절로 건너뜀 (약 3초)
		creation_real += real_dt
		if Notebook.nap_time(v) and can_skip_night() and start_skip_night():
			rate = speed()
			return _tick_skip(real_dt)
	_sync_fast()
	if fast:
		return _tick_fast(real_dt)
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
		if creation and v.t >= creation_until - 1e-6:
			_end_creation(true)       # 창세의 날 끝 (다음 6시) → ×1 + 배속 단추 한 줄
			acc = 0.0
			break
	if n >= max_steps and acc >= step:
		dropped += acc
		acc = 0.0
	if real_dt > 0.0:
		rate = speed()
	return n


## 빠른 흐름 한 화면: 병 시간 real_dt × 배속을 따라잡기와 같은 정밀 걸음(step_dt)으로, 계산 시간 예산 안에서만.
## 못 따라간 시간은 버린다 (behind) — 다음 화면에 쌓아 두면 점점 더 느려지므로. 걸은 걸음 수를 돌려준다.
func _tick_fast(real_dt: float) -> int:
	var t_start := v.t
	acc += real_dt * speed()
	var sdt := v.step_dt
	var budget := fast_budget_ms()
	var t0 := Time.get_ticks_usec()
	var n := 0
	while acc >= sdt - 1e-6:
		var used := (Time.get_ticks_usec() - t0) / 1000.0
		if n > 0 and used + _step_ms > budget:
			break
		var ts := Time.get_ticks_usec()
		var marks := _marks()
		v.step(sdt)
		acc -= sdt
		n += 1
		steps_done += 1
		_fast_hook += sdt
		if _fast_hook >= Balance.FAST_HOOK_EVERY - 1e-6:
			_fast_hook = 0.0
			_world_hooks()
		var ms := (Time.get_ticks_usec() - ts) / 1000.0
		_step_ms = ms if _step_ms <= 0.0 else lerpf(_step_ms, ms, 0.1)
		if _after_step() or _important(marks):
			break                     # 배속이 바뀜 (빠른 흐름 끝)
	if fast and acc >= sdt:
		behind += acc - fmod(acc, sdt)
		acc = fmod(acc, sdt)
	if real_dt > 0.0:
		var got := (v.t - t_start) / real_dt
		rate = lerpf(rate, got, 1.0 - exp(-real_dt / 0.8)) if fast else speed()
	return n


## (시험) 남은 n_left걸음을 넘지 않는 화면 길이 — real_dt와 남은 걸음에 꼭 맞는 길이 중 짧은 쪽 (배속이 달라도 같은 걸음 수에서 멈춤)
func dt_for_steps(n_left: int, real_dt: float) -> float:
	var sdt := v.step_dt if fast or float(Balance.SPEEDS[speed_i]) >= Balance.FAST_FROM else step
	return minf(real_dt, maxf(0.0, (n_left * sdt - acc) / maxf(1e-9, speed())))


## 넓은 세상: 따라잡기의 JarWorld.advance가 한 묶음마다 하는 정리 (거인이 없는 무리의 분가 · 고운 물 범위)
func _world_hooks() -> void:
	if world != null:
		world._auto_split()
		world._update_interest()


## 함께 걷는 무리 (넓은 세상 = 첫 무리 + others)
func _group() -> Array:
	return [v] + v.others


## 중요한 일 표식 — 걸음 앞뒤를 비교한다: 출생·사망 수 · 깨달음 · 계시 · 편지 수 · 위기 예고(warnings) 수
##   + 누구인지 찾을 실마리: 다음 주민 번호 · 잠든 사람 수 · 마지막 위기 예고 (warnings는 20개에서 앞이 잘리므로 수 대신 마지막 것)
func _marks() -> Array:
	var m: Array = []
	for q: Village in _group():
		m.append([int(q.stats["born"]), int(q.stats["died"]), q.aware, q.revelation.is_empty(), q.letters.size(), q.warnings.size(),
			q.next_id, q.dead.size(), q.warnings.back() if not q.warnings.is_empty() else null, q])
	return m


## 빠른 흐름 중 중요한 일이 생겼으면 ×1 + 무슨 일인지 (true). 새로 선 무리(분가)도 중요한 일.
## 생긴 일은 모두 events에 (화면이 카드·알림으로) — 설정이 끈 일·자잘한 일은 stop = false (멈추지 않음)
func _important(before: Array) -> bool:
	if not fast or not auto_slow or speed() <= normal_speed() + 1e-6:
		return false
	var now := _marks()
	var found: Array = []
	if now.size() > before.size():
		for k in range(before.size(), now.size()):
			var nv: Village = now[k][9]
			found.append(_ev("settle", "settle", "새 마을이 생겼어요: %s" % nv.settlement_name, "마을로 가기", nv, -1, nv.center))
	for k in mini(now.size(), before.size()):
		var a: Array = before[k]
		var b: Array = now[k]
		var q: Village = b[9] if b.size() > 9 else _group()[k]
		if a.size() <= 9 or a[9] != q:
			continue
		if b[0] > a[0]:
			found.append_array(_births(q, a))
		if b[1] > a[1]:
			for i in range(mini(int(a[7]), q.dead.size()), q.dead.size()):
				var d: Resident = q.dead[i]
				found.append(_ev("died", "died", "%s%s 세상을 떠났어요" % [d.name, Village.josa(d.name, "이", "가")], "", q, d.id, Vector2(d.x, d.y)))
		if b[2] and not a[2]:
			found.append(_ev("reveal", "aware", "하늘 너머에 누군가 있다는 걸 알았어요", "disc_stars", q, -1, _square(q)))
		if a[3] and not b[3]:
			var who := int(q.revelation.get("from", -1))
			var nm := String(q.revelation.get("name", ""))
			found.append(_ev("reveal", "revelation", "노인들이 자꾸 하늘을 올려다봐요" + (" (%s)" % nm if nm != "" else ""), "제단", q, who, _pos_of(q, who)))
		if b[4] > a[4]:
			for i in range(clampi(int(a[4]), 0, q.letters.size()), q.letters.size()):
				var l: Dictionary = q.letters[i]
				var who := int(l.get("from", -1))
				var nm := String(l.get("name", ""))
				var txt := ("새 땅으로 떠나고 싶대요 (%s)" if String(l.get("kind", "")) == "split" else "소원 편지가 왔어요 (%s)") % nm
				found.append(_ev("letter", String(l.get("kind", "wish")), txt, "편지", q, who, _pos_of(q, who)))
		for w: Dictionary in _new_warnings(q, a[8]):
			found.append(_omen(q, w))
	if found.is_empty():
		return false
	var stop := false
	for e: Dictionary in found:
		e["stop"] = _should_stop(e)
		if e["stop"]:
			stop = true
			stop_count[e["cat"]] = int(stop_count.get(e["cat"], 0)) + 1
			stop_last_t[e["cat"]] = (e["village"] as Village).t
	events.append_array(found)
	if events.size() > 12:
		events = events.slice(events.size() - 12)
	if not stop:
		return false
	var first: Dictionary = found.filter(func(e: Dictionary) -> bool: return e["stop"])[0]
	last_event = String(first["kind"]) if first["cat"] == "reveal" else String(first["cat"])
	prev_speed_i = speed_i
	set_speed(Balance.EVENT_SLOW_I)
	notice = String(first["text"])        # 화면이 카드를 띄우면 이 한 줄은 지운다 (카드 없는 곳 — 시험·캡처 — 에서도 무슨 일인지)
	notice_t = 5.0
	return true


## 화면이 가져가는 생긴 일 (가져가면 비움)
func take_events() -> Array:
	var e := events
	events = []
	return e


## [계속 빠르게] — 중요한 일로 느려지기 전 배속으로 (없으면 false)
func resume_fast() -> bool:
	if prev_speed_i < 0:
		return false
	var i := prev_speed_i
	prev_speed_i = -1
	set_speed(i)
	return true


## 이 일로 멈출까: 설정 "빠르게 갈 때 멈출 일" · 탄생·편지는 처음 몇 번은 늘 · 잇단 편지·자잘한 일은 알림만
func _should_stop(e: Dictionary) -> bool:
	var cat := String(e["cat"])
	if String(e["kind"]) in MINOR_KINDS:
		return false
	if cat == "letter" and stop_last_t.has("letter") and (e["village"] as Village).t - float(stop_last_t["letter"]) < LETTER_GAP:
		return false
	if stop_on(cat):
		return true
	return cat in ["born", "letter"] and int(stop_count.get(cat, 0)) < STOP_FIRST_FEW


## 설정의 갈래 켜짐 (GameSettings.stop_<갈래>)
static func stop_on(cat: String) -> bool:
	var gs := GameSettings.get_current()
	var key := "stop_" + cat
	return bool(gs.get(key)) if key in gs else true


func _ev(cat: String, kind: String, text: String, icon: String, q: Village, who: int, pos: Vector2) -> Dictionary:
	return {"cat": cat, "kind": kind, "text": text, "icon": icon, "village": q, "who": who, "pos": pos, "stop": false}


## 이번 걸음에 태어난 아기 (번호가 before 뒤인 사람 중 부모가 있는) — 못 찾으면 이름 없이 한 줄
func _births(q: Village, a: Array) -> Array:
	var out: Array = []
	for r in q.people:
		if r.id >= int(a[6]) and not r.parents.is_empty() and r.age < 0.5:
			var mom := q.person(r.parents[0])
			var mn := mom.name if mom != null else ""
			var txt := "%s%s 아기를 낳았어요 (%s)" % [mn, Village.josa(mn, "이", "가"), r.name] if mn != "" else "아기 %s%s 태어났어요" % [r.name, Village.josa(r.name, "이", "가")]
			out.append(_ev("born", "born", txt, "", q, r.id, Vector2(r.x, r.y)))
	if out.is_empty():
		out.append(_ev("born", "born", "아기가 태어났어요", "", q, -1, _square(q)))
	return out


## 마지막 위기 예고(last) 뒤에 새로 붙은 것들
func _new_warnings(q: Village, last: Variant) -> Array:
	if q.warnings.is_empty():
		return []
	if last == null:
		return q.warnings.duplicate()
	for i in range(q.warnings.size() - 1, -1, -1):
		if is_same(q.warnings[i], last):
			return q.warnings.slice(i + 1)
	return [q.warnings.back()]


## 위기 예고 한 줄 → 카드 줄 ("빵에 하얀 털이 났어요 (곰팡이 조짐)"). 깨닫기 전에는 거인 이야기를 빼고
func _omen(q: Village, w: Dictionary) -> Dictionary:
	var kind := String(w.get("kind", ""))
	var txt := String(w.get("text", "")).trim_prefix("거인님, ").trim_suffix(".")
	if not q.aware and txt.contains("거인"):
		txt = "이상한 조짐이 보여요"
	if OMEN_WORDS.has(kind) and kind != "severe":
		txt += " (%s)" % OMEN_WORDS[kind]
	var who := int(w.get("who", -1))
	var e := _ev("omen", kind, txt, String(OMEN_ICONS.get(kind, "")), q, who, _pos_of(q, who))
	e["ref"] = w                      # 화면이 같은 위기 예고를 알림 줄로 또 띄우지 않게
	return e


static func _square(q: Village) -> Vector2:
	return q.fire if q.fire.distance_to(q.center) < 30.0 else q.center


static func _pos_of(q: Village, who: int) -> Vector2:
	var r := q.person(who) if who >= 0 else null
	return Vector2(r.x, r.y) if r != null else _square(q)


## 걸음마다: 위기 → ×1 + 알림, 밤 건너뛰기는 아침이 되면 끝. 배속이 바뀌었으면 true
func _after_step() -> bool:
	var changed := false
	if not v.crises.is_empty():
		last_crisis = v.crises.back()
		v.crises.clear()
		var was_fast := skipping or creation or speed() > normal_speed() + 1e-6
		if was_fast:
			set_speed(Balance.SPEED_DEFAULT_I)
			acc = 0.0
		notice = "%s — 시간을 보통 빠르기로 되돌렸어요" % last_crisis["text"] if was_fast else String(last_crisis["text"])
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
		lid_real = 0.0                # (v3.3) 뚜껑은 손짓마다 저절로 열고 닫힌다 — 닫힘 알림은 없음 (화면은 CorkPop)


# ───────────────────────── 저장 (docs/SAVE.md) ─────────────────────────
func to_dict() -> Dictionary:
	speed_v = 2
	return SaveCodec.props(self, SAVE_SKIP)


static func from_dict(village: Village, d: Dictionary) -> JarClock:
	var c := JarClock.new(village)
	SaveCodec.apply(c, d, SAVE_SKIP)
	if int(d.get("speed_v", 0)) < 2:      # 옛 저장의 배속 번호(×1~×60)는 지금 목록과 뜻이 달라 보통으로
		c.speed_i = Balance.SPEED_DEFAULT_I
		c.speed_v = 2
		c.fast = false
	c.speed_i = clampi(c.speed_i, 0, Balance.SPEEDS.size() - 1)
	return c
