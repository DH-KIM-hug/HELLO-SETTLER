## 병의 공기와 뚜껑 — docs/WORLD_EVENTS.md 1 (닫혀 있다 · 뚜껑으로만 드나든다) · 3 (뚜껑 열기) · 7 (김·연기·공기 0~1).
## 화면과 분리된 순수 로직. Village.air가 하나 가진다. 난수는 자기 흐름(rng) 하나만 — 다른 흐름의 순서를 바꾸지 않는다.
## 닫힌 병: 김(humid)·연기(smoke)·탁한 공기(stale)는 병 시계 Balance.AIR_TICK(60초)마다 병의 상태가 정하는 목표로 천천히 다가간다.
## 뚜껑이 열린 동안(걸음마다): 세 값이 바깥 값으로 빠지고, 거인의 방 기온이 섞여 들어오고(Health.tick이 temp_shift를 더함),
## 물이 조금 증발해 나간다. 열 때마다 날벌레 굴림 (들어오면 SmallCrises.gnat_in — 2.2). 닫지 않으면 JarClock이 현실 1분 뒤 닫는다.
class_name JarAir
extends RefCounted

var rng := RandomNumberGenerator.new()
var humid := 0.4                      # 김 0~1
var smoke := 0.0                      # 연기 0~1
var stale := 0.0                      # 탁한 공기 0~1
var lid_open := false
var lid_t := 0.0                      # 이번에 열린 뒤 흐른 병 시간 (초)
var lid_total := 0.0                  # 지금까지 열려 있던 병 시간 합 (뚜껑 기록 — 2.3 압력용)
var lid_count := 0                    # 연 횟수
var lid_mix := 0.0                    # 거인의 방 기온이 섞인 정도 0~LID_MIX_MAX
var room_temp := 16.0                 # 지금 거인의 방 기온 (계절)
var open_secs_pending := 0.0          # 다음 공기 계산 때 물을 덜어 낼 열린 시간 (초)
var water_lost := 0.0                 # 뚜껑으로 빠져나간 물 (합)
var gnats := 0                        # 날벌레가 들어오려 한 횟수 (2.2 — 위기는 sim/small_crises.gd)
var gnat_new := false                 # 방금 날벌레가 들어옴 (화면이 가져감)
var just_opened := false              # 화면 연출용 (방금 열림)
var _acc := 0.0
var _ready := false


func _init(seed_v: int) -> void:
	rng.seed = seed_v * 4241 + 17


# ───────────────────────── 뚜껑 ─────────────────────────
func open_lid(v: Village) -> bool:
	if lid_open:
		return false
	lid_open = true
	lid_t = 0.0
	lid_count += 1
	just_opened = true
	var season: String = Health.jar_date(v)["season"]
	room_temp = float(Balance.ROOM_TEMP.get(season, 16.0))
	# 날벌레 (여름 8% · 봄가을 3% · 겨울 0%) — 열 때마다 한 번 굴림
	if rng.randf() < float(Balance.GNAT_P.get(season, 0.0)):
		gnats += 1
		if v.smalls != null and v.smalls.gnat_in(v):     # [작은 위기] 날벌레 위기 (조짐·연대기·알림은 SmallCrises — 첫 3일·위기가 둘이면 그냥 날아 나감)
			gnat_new = true
	_awe(v)
	return true


func close_lid(_v: Village) -> bool:
	if not lid_open:
		return false
	lid_open = false
	return true


## "하늘이 열렸다!" — 깨어 있는 사람 몇 명이 올려다본다. 처음엔 경외 (연대기·믿음), 자주 열면 익숙해짐
func _awe(v: Village) -> void:
	var said := 0
	var limit := 3 if lid_count <= 3 else 1
	for r in v.people:
		if said >= limit:
			break
		if r.sleeping or r.sick_left > 0.0 or r.age < 2.5:
			continue
		v.speak(r, Balance.LID_AWE_LINE if said == 0 or lid_count <= 3 else "바람이 불어…", 5)
		said += 1
	if lid_count == 1:
		var cold := room_temp < Health.base_temp(v, v.t) - 3.0
		v.log_line("하늘이 열렸다! %s 바람이 마을까지 불어 들었다. 모두 일손을 놓고 하늘을 올려다보았다." % ("차가운" if cold else "따뜻한"))
		v.bless_all(0.02)
	elif lid_count == 10:
		v.log_line("하늘이 열리는 일에도 이제 아이들만 손을 흔든다.")


# ───────────────────────── 걸음 ─────────────────────────
## Village.step이 걸음마다 부른다 (뚜껑이 열린 동안만 걸음마다 일한다 — 나머지는 60초 고정 걸음)
func step(v: Village, dt: float) -> void:
	if not _ready:
		_ready = true
		_settle(v)
	if lid_open:
		lid_t += dt
		lid_total += dt
		open_secs_pending += dt
		var k := 1.0 - exp(-dt / Balance.LID_DRAIN_TAU)
		humid += (Balance.OUTSIDE_HUMID - humid) * k
		smoke -= smoke * k
		stale -= stale * k
		lid_mix += (Balance.LID_MIX_MAX - lid_mix) * (1.0 - exp(-dt / Balance.LID_MIX_TAU))
		if lid_t >= Balance.LID_SAFETY_CLOSE:
			close_lid(v)
	elif lid_mix > 0.0:
		lid_mix *= pow(0.5, dt / Balance.LID_MIX_HALF)
		if lid_mix < 1e-4:
			lid_mix = 0.0
	_acc += dt
	while _acc >= Balance.AIR_TICK - 1e-6:
		_acc -= Balance.AIR_TICK
		_tick(v, Balance.AIR_TICK)


## 처음: 목표값에서 시작 (첫 걸음 — 병의 상태가 정해진 뒤)
func _settle(v: Village) -> void:
	humid = humid_target(v)
	smoke = smoke_target(v)
	stale = stale_target(v)


func _tick(v: Village, dt: float) -> void:
	if not lid_open:
		humid += (humid_target(v) - humid) * (1.0 - exp(-dt / Balance.HUMID_TAU))
		smoke += (smoke_target(v) - smoke) * (1.0 - exp(-dt / Balance.SMOKE_TAU))
		stale += (stale_target(v) - stale) * (1.0 - exp(-dt / Balance.STALE_TAU))
	humid = clampf(humid, 0.0, 1.0)
	smoke = clampf(smoke, 0.0, 1.0)
	stale = clampf(stale, 0.0, 1.0)
	if open_secs_pending > 0.0:
		_lose_water(v, open_secs_pending)
		open_secs_pending = 0.0


## 열린 동안 물이 조금 증발해 나감 (닫힌 순환이 깨짐 — 자주 열면 호수가 서서히 줄어듦)
func _lose_water(v: Village, secs: float) -> void:
	if not v.owns_water or v.water == null:
		return
	var f := 1.0 - exp(-Balance.LID_WATER_LOSS * secs)
	var w := v.water.w
	var lost := 0.0
	for k in v.water.cells:
		var x := w[k]
		if x > 0.0:
			lost += x * f
			w[k] = x * (1.0 - f)
	v.water.w = w
	water_lost += lost


# ───────────────────────── 목표값 (병의 상태) ─────────────────────────
## 땅의 젖음 — 마을 둘레 25곳 표본 (소형 병·넓은 세상 같은 방법)
func wet_avg(v: Village) -> float:
	var s := 0.0
	var n := 0
	for i in 5:
		for j in 5:
			var x := v.center.x + (i - 2) * 6.0
			var y := v.center.y + (j - 2) * 6.0
			if not v.water.inside(x, y, 1.0):
				continue
			s += v.water.wet_k(v.water.idx(x, y))
			n += 1
	return s / n if n > 0 else 0.0


func humid_target(v: Village) -> float:
	var c := float(Balance.HUMID_CLIMATE.get(v.climate(), 0.0))
	return clampf(Balance.HUMID_BASE + Balance.HUMID_WET * wet_avg(v) + c + Balance.HUMID_CYCLE * (v.water.humid - 0.6), 0.0, 1.0)


## 연기: 모닥불 + 불 때는 집 ÷ (숲) — 닫힌 병이라 빠지지 않고 나무가 천천히 거른다
func smoke_target(v: Village) -> float:
	var src := 1.0
	for b in v.buildings:
		if b.fuel_on:
			src += 0.6
	return clampf(src / (10.0 + 0.12 * v.trees.size()), 0.0, 1.0)


## 탁한 공기: (사람 + 모닥불) ÷ 나무 (2.2)
func stale_target(v: Village) -> float:
	var n := 0
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree":
			n += 1
	return clampf((v.people.size() + 2.0) * 0.02 / (0.4 + n / 100.0), 0.0, 1.0)


# ───────────────────────── 다른 계산이 읽는 값 ─────────────────────────
## 뚜껑으로 섞여 든 거인의 방 기온 → 병 기온에 더할 값 (Health.tick·temperature_at)
func temp_shift(base: float) -> float:
	return lid_mix * (room_temp - base) if lid_mix > 0.0 else 0.0


## 유리의 김 (화면: 뿌연 유리) 0~1
func glass_fog() -> float:
	return clampf((humid - 0.55) / 0.35, 0.0, 1.0)


# ───────────────────────── 저장 (docs/SAVE.md) ─────────────────────────
## 난수 흐름 포함
func to_dict() -> Dictionary:
	return SaveCodec.props(self)


static func from_dict(d: Dictionary) -> JarAir:
	var a := JarAir.new(0)
	SaveCodec.apply(a, d)
	return a
