## 거인의 손 — 물 뿌리기 · 손으로 감싸기 · 커튼 3단 · 유리 닦기 · 핀셋 (ROADMAP B6).
## 기준: WORLD_EVENTS 4.2 (병 밖 — 뚜껑을 열지 않음, 무료, 쿨타임) · 4.3 (뚜껑을 열고) · 2.5 (병의 날씨) · 기획서 6.3 (양날의 검) · 6.4 (커튼) ·
##   GIANT_ROOM 2 (병 밖의 손짓). 화면과 분리된 순수 로직, 난수 없음 (×1·×8 같음 — 다른 흐름을 흔들지 않음).
## 병 하나의 상태 (커튼·손의 온기·유리의 먼지막·닦은 김)는 물(JarWater — 넓은 세상의 무리가 함께 씀)이 가지고 남은 초로 센다
##   (병 시계와 상관없이 같은 값 — 따라잡기에도 그대로). 무리 하나의 상태 (쿨타임·적신 자리·젖은 밭·하루 횟수·처음 쓴 것)는 Village.hand.
##
## 물 뿌리기 (뚜껑을 연 채, 쿨타임 SPRAY_COOLDOWN): 누른 자리 둘레에 거인의 물 (병 밖에서 들어온 물 — 물의 합이 는다) →
##   모깃불·연기를 끔 · 마른 밭은 하루 동안 잘 자람 (×1.3) · 낮은 자리엔 물이 고여 작은 연못 · 녹은 소금은 물과 함께 씻겨 내려감.
##   한 시간 안에 같은 자리에 세 번째 → 넘침 (밭 쓸림 · 집 잠김 · 두려움 — 아무도 죽지 않음). 같은 기적이 잦으면 감동↓ (하루 횟수).
## 손으로 감싸기 (병 밖, 무료): 병 전체 +6° 한 시간 (병 시계) — 손이 유리를 덮어 그동안 증발 ×0.7. 온기가 남은 동안은 다시 못 함.
##   하루 3번 넘으면 두려움↑ ("하늘이 우리를 쥐고 있어"). 추울 때 감싸면 깨달은 마을은 믿음↑.
## 커튼 3단 (열림·반쯤·닫힘, 병 밖, 제한 없음): 낮에만 — 증발 ×1·0.6·0.3 (볕 드는 쪽 강이 멀리 흐름) · 작물·나무 자람 ×1·0.85·0.6 ·
##   온기 0·−2.5°·−5° (기후 지도 한·두 단계 서늘). 낮에 '닫힘'이 12시간 넘게 이어지면 냉해 (밭이 자라지 않음 — 커튼을 열 때까지).
##   믿음·두려움에 영향 없음 (조용한 손 — "하늘이 흐려졌다"). 바꾸면 curtain_changed(단계) — 방의 3D 커튼은 GiantRoom.set_curtain.
## 유리 닦기 (병 밖, 쿨타임 WIPE_COOLDOWN): 서린 김·곰팡이로 뿌연 유리가 맑아짐 (보기만 — 병 안 습기는 그대로, 김은 몇 시간에 걸쳐 다시 서림) +
##   유리에 앉은 먼지막을 걷음 (먼지막이 두꺼우면 낮의 자람 최대 −15%) → 반나절 동안 또렷한 볕 (×1.08).
## 핀셋 (뚜껑을 연 채): 날벌레 (SmallCrises.tweeze) · 먼지 뭉치 · 떨어진 물건 (통나무·돌…) · 바위 하나를 집어냄 — to를 주면
##   짧은 거리(MOVE_MAX)만 옮겨 놓음. 물건에서 멀리 집으면 서툴러 곁의 집이 짓눌림 (날벌레와 같은 규칙).
## 모두: 깨닫기 전엔 경이 (Awakening.witness — '거인' 이야기 없음), 깨달은 뒤엔 믿음 · 처음 쓴 날 연대기 한 줄.
## 이 파일 밖의 고리: Village.step (step) · _update_building (farm_mult) · _update_trees (grow_mult) · Health (temp_add) ·
##   JarWater/WorldWater 증발 (evap_k) · Village.spray_water/cup_hands/set_curtain/wipe_glass/tweeze · view/jar_air_overlay.gd (fog_shown).
class_name GiantHand
extends RefCounted

signal curtain_changed(step: int)

const DAY := 86400.0
const HOUR := 3600.0
const LIGHT_FROM := 7.0                # 병 안의 볕 (JarWater.advance의 낮 물 순환과 같은 시각)
const LIGHT_TO := 18.0

# 커튼 3단 (기획서 6.4 — 0 열림 · 1 반쯤 · 2 닫힘)
const CURTAIN_NAMES := ["열림", "반쯤", "닫힘"]
const CURTAIN_LIGHT := [1.0, 0.6, 0.25]
const CURTAIN_EVAP := [1.0, 0.6, 0.3]
const CURTAIN_GROW := [1.0, 0.85, 0.6]
const CURTAIN_COOL := [0.0, -2.5, -5.0]
const FROST_AFTER := 12.0 * HOUR       # 낮에 닫힘이 이만큼 이어지면 냉해
# 손으로 감싸기 (WORLD_EVENTS 4.2)
const CUP_WARM := 6.0
const CUP_TIME := 1.0 * HOUR
const CUP_EVAP := 0.7
const CUP_FREE_PER_DAY := 3
const CUP_FEAR := 0.05
const CUP_BELIEF := 0.02
# 물 뿌리기 (WORLD_EVENTS 4.3 · 기획서 6.3)
const SPRAY_R := 3.0
const SPRAY_WATER := 0.012             # 가운데 칸의 물 깊이 (호수 깊이 0.015보다 조금 얕게 — 땅을 적심)
const SPRAY_FLOOD_WATER := 0.05        # 넘칠 때 (한 번 더 쏟아짐)
const SPRAY_COOLDOWN := 30.0           # 병 초
const SPRAY_SOAK := 1.0 * HOUR         # 같은 자리를 적신 기억
const SPRAY_FLOOD_AT := 3              # 한 시간 안에 같은 자리 세 번째 = 넘침
const SPRAY_DRY := 0.35                # 이보다 마른 밭은 물을 반김
const SPRAY_FIELD_TIME := 1.0 * DAY
const SPRAY_FIELD_MULT := 1.3
const SPRAY_BELIEF := 0.03
const SPRAY_FADE := 0.6                # 그날 거듭될수록 감동 ×0.6
const SPRAY_SMOKE := 0.8               # 불을 끄면 병의 연기 ×0.8
# 유리 닦기 (WORLD_EVENTS 4.2 · GIANT_ROOM 2)
const WIPE_COOLDOWN := 10.0 * 60.0
const WIPE_FOG_TAU := 3.0 * HOUR       # 닦은 김이 다시 서리는 빠르기
const DUST_DAYS := 40.0                # 먼지막이 다 덮일 때까지 (닫힌 병)
const DUST_LID := 1.0 / (6.0 * HOUR)   # 뚜껑이 열린 동안 더 (방의 먼지)
const DUST_FROM := 0.25                # 이보다 얇은 먼지막은 볕을 가리지 않음
const DUST_GROW := 0.15
const BRIGHT_MIN := 0.15               # 이만큼은 쌓여 있어야 닦은 뒤 볕이 또렷함
const BRIGHT_TIME := 12.0 * HOUR
const BRIGHT_GROW := 1.08
# 핀셋 (WORLD_EVENTS 4.3 · 7.1)
const TWEEZE_R := 2.5                  # 누른 자리에서 이만큼 (+ 물건 크기) 안의 것을 집음
const TWEEZE_CLEAN := 1.0              # 이만큼 가까우면 깔끔히
const TWEEZE_CRUSH_R := 1.8
const MOVE_MAX := 6.0                  # 옮겨 놓을 수 있는 거리 (칸)
const PICK_BELIEF := 0.02

const FIRST := {
	"water": ["거인님이 하늘에서 물을 뿌려 주셨다. 마른 땅이 촉촉해지고 사람들은 젖은 얼굴로 하늘을 올려다보았다.",
		"하늘에서 물이 쏟아져 내렸다. 사람들은 젖은 얼굴로 하늘을 올려다보며 어디서 온 물인지 물었다."],
	"cup": ["거인님의 커다란 손이 세상을 감싸자 차가운 땅에 온기가 돌았다.",
		"하늘이 어둑해지더니 어디선가 따뜻한 기운이 세상을 감쌌다."],
	"curtain": ["어느 날 하늘 한쪽이 어둑해졌다. 사람들은 하늘이 흐려졌다고 말했다.",
		"어느 날 하늘 한쪽이 어둑해졌다. 사람들은 하늘이 흐려졌다고 말했다."],
	"wipe": ["거인님이 하늘을 닦으시자 뿌옇던 하늘이 맑아지고 햇살이 또렷해졌다.",
		"뿌옇던 하늘이 한순간에 맑아지고 햇살이 또렷해졌다."],
	"pick": ["거인님의 커다란 집게가 내려와 땅에 떨어진 것을 집어 가셨다.",
		"하늘에서 커다란 집게가 내려와 땅에 떨어진 것을 집어 갔다."],
	"move": ["거인님의 커다란 집게가 내려와 떨어진 것을 옆으로 옮겨 놓으셨다.",
		"하늘에서 커다란 집게가 내려와 떨어진 것을 옆으로 옮겨 놓았다."],
}

# 무리 하나의 상태 (Village.hand — 저장)
var spray_cd := 0.0                    # 남은 쿨타임 (병 초)
var wipe_cd := 0.0
var soaks: Array = []                  # 최근 적신 자리 [x, y, 남은 초]
var watered: Array = []                # 물을 반긴 밭 [건물 id, 남은 초]
var sprays := [-1, 0]                  # [그날, 횟수]
var cups := [-1, 0]
var firsts: Array = []                 # 처음 쓴 손짓 (연대기 한 번)
var stats := {"sprays": 0, "water": 0.0, "fires_out": 0, "fields": 0, "floods": 0, "cups": 0, "cup_fear": 0, "curtain": 0,
	"wipes": 0, "picked": 0, "moved": 0, "crushed": 0, "frost": 0}


# ───────────────────────── 걸음 ─────────────────────────
static func step(v: Village, dt: float) -> void:
	var h := v.hand
	if h == null:
		return
	h.spray_cd = maxf(0.0, h.spray_cd - dt)
	h.wipe_cd = maxf(0.0, h.wipe_cd - dt)
	if not h.soaks.is_empty():
		for s: Array in h.soaks:
			s[2] = float(s[2]) - dt
		h.soaks = h.soaks.filter(func(s: Array) -> bool: return float(s[2]) > 0.0)
	if not h.watered.is_empty():
		var ended := false
		for e: Array in h.watered:
			e[1] = float(e[1]) - dt
			if float(e[1]) <= 0.0:
				ended = true
				var b := v.bld(int(e[0]))
				if b != null:
					b.farm_mult = -1.0          # 땅의 젖음으로 다시
		if ended:
			h.watered = h.watered.filter(func(e: Array) -> bool: return float(e[1]) > 0.0)
	if not v.owns_water:
		return
	var w := v.water
	if w.cup_left > 0.0:
		w.cup_left = maxf(0.0, w.cup_left - dt)
	if w.bright_left > 0.0:
		w.bright_left = maxf(0.0, w.bright_left - dt)
	if w.glass_clear > 0.0:
		w.glass_clear *= exp(-dt / WIPE_FOG_TAU)
		if w.glass_clear < 1e-3:
			w.glass_clear = 0.0
	if w.glass_dust < 1.0:
		w.glass_dust = minf(1.0, w.glass_dust + dt / (DUST_DAYS * DAY) + (dt * DUST_LID if v.air != null and v.air.lid_open else 0.0))
	if w.curtain == 2:
		if is_light(v.hour_now()):
			w.curtain_dark += dt
		if w.curtain_dark >= FROST_AFTER and not w.curtain_frost:
			w.curtain_frost = true
			h.stats["frost"] += 1
			v.log_line("해가 오래 가려져 밭의 싹이 냉해를 입었다. 밭은 더 자라지 않았다.")
			_warn(v, "frost", "하늘이 오래 어두워 밭이 얼어 가요", "하늘이 오래 어두워 밭이 얼어 가요")
			v.crisis("frost", "밭이 냉해를 입었다")


static func is_light(hr: float) -> bool:
	return hr >= LIGHT_FROM and hr < LIGHT_TO


static func _hour_at(v: Village, tt: float) -> float:
	return fmod(v.start_clock + tt, DAY) / HOUR


# ───────────────────────── 다른 계산이 읽는 값 ─────────────────────────
## 작물·나무가 자라는 배율 (밤엔 커튼·유리와 상관없음 — 볕이 없으니). 기본(열림·맑은 유리) = 정확히 1
static func grow_mult(v: Village) -> float:
	var w := v.water
	if w == null:
		return 1.0
	if w.curtain_frost:
		return 0.0
	if not is_light(v.hour_now()):
		return 1.0
	var m: float = CURTAIN_GROW[clampi(w.curtain, 0, 2)]
	if w.glass_dust > DUST_FROM:
		m *= 1.0 - DUST_GROW * (w.glass_dust - DUST_FROM) / (1.0 - DUST_FROM)
	if w.bright_left > 0.0:
		m *= BRIGHT_GROW
	return m


## 밭 하나의 배율 = 자람 × 물을 반긴 밭 ×1.3
static func farm_mult(v: Village, b: Building) -> float:
	var m := grow_mult(v)
	var h := v.hand
	if h != null and not h.watered.is_empty():
		for e: Array in h.watered:
			if int(e[0]) == b.id:
				m *= SPRAY_FIELD_MULT
				break
	return m


## 병 기온에 더할 값 (Health.tick · temperature_at) — 손의 온기 + 낮의 커튼 그늘. 기본 = 0
static func temp_add(v: Village, tt: float) -> float:
	var w := v.water
	if w == null:
		return 0.0
	var a := 0.0
	if w.cup_left > 0.0:
		a += CUP_WARM
	if w.curtain > 0 and is_light(_hour_at(v, tt)):
		a += float(CURTAIN_COOL[clampi(w.curtain, 0, 2)])
	return a


## 화면의 서린 김 (닦으면 걷히고 천천히 다시 서림) 0~1
static func fog_shown(v: Village) -> float:
	var f := 0.0
	if v.air != null:
		f = v.air.glass_fog()
	if v.mold != null:
		f = maxf(f, v.mold.omen_fog)
	return f * (1.0 - (v.water.glass_clear if v.water != null else 0.0))


## 화면의 먼지막 (얇으면 보이지 않음) 0~1
static func dust_shown(v: Village) -> float:
	return clampf((v.water.glass_dust - 0.1) / 0.9, 0.0, 1.0) if v.water != null else 0.0


## 방의 3D 커튼이 부르는 값 — 단계의 볕 (GiantRoom.CURTAIN_LIGHT와 같은 값)
static func curtain_light(step_i: int) -> float:
	return float(CURTAIN_LIGHT[clampi(step_i, 0, 2)])


# ───────────────────────── 물 뿌리기 ─────────────────────────
func spray(v: Village, p: Vector2) -> Dictionary:
	var no := {"ok": false, "why": "", "water": 0.0, "fields": 0, "fires_out": 0, "flood": false, "hit": 0}
	if v.air == null or not v.air.lid_open:
		no["why"] = "뚜껑을 먼저 열어 주세요"
		return no
	if spray_cd > 0.0:
		no["why"] = "물뿌리개에 물을 채우는 중이에요"
		return no
	if not v.water.inside(p.x, p.y, 1.5):
		no["why"] = "유리벽 가까이는 뿌릴 수 없어요"
		return no
	spray_cd = SPRAY_COOLDOWN
	var n := 1
	for s: Array in soaks:
		if Vector2(float(s[0]), float(s[1])).distance_to(p) < SPRAY_R:
			n += 1
	soaks.append([p.x, p.y, SPRAY_SOAK])
	var flood := n >= SPRAY_FLOOD_AT
	var added := _add_water(v, p, SPRAY_R + (1.0 if flood else 0.0), SPRAY_FLOOD_WATER if flood else SPRAY_WATER)
	# 불 (모깃불 — 불이 나는 위기가 생기면 여기에) · 연기
	var out := 0
	if v.smalls != null:
		for s: Dictionary in v.smalls.smokes:
			if float(s["until"]) > v.t and Vector2(float(s["x"]), float(s["y"])).distance_to(p) < SPRAY_R + 1.0:
				s["until"] = v.t
				out += 1
	if out > 0 and v.air != null:
		v.air.smoke *= SPRAY_SMOKE
	# 밭
	var fields := 0
	var hit: Array = []
	if flood:
		hit = v.smalls._wash_under(v, p, SPRAY_R + 1.0, true) if v.smalls != null else []
		var houses := hit.filter(func(b: Building) -> bool: return b.is_house()).size()
		if houses > 0:
			v.on_house_flooded(p.x, p.y, SPRAY_R + 2.0)
		else:
			v.raise_fear_all(Balance.FEAR_FLOOD * 0.3)
		for r in v.people:
			if Vector2(r.x - p.x, r.y - p.y).length() < SPRAY_R + 1.0 and not r.is_baby() and r.sick_left <= 0.0:
				ResidentAI.cancel(v, r)       # 물을 헤치고 나옴 (다치지 않음)
		stats["floods"] += 1
		v.log_line(SmallCrises.say_for(v, "거인님의 물이 넘쳐 둘레가 물바다가 되었다. 사람들은 물을 헤치고 높은 곳으로 피했다.",
			"하늘에서 물이 끝없이 쏟아져 둘레가 물바다가 되었다. 사람들은 물을 헤치고 높은 곳으로 피했다."))
	else:
		for b in v.buildings:
			if not b.built or b.type != "농장" or Vector2(b.x, b.y).distance_to(p) > SPRAY_R + b.size() * 0.5:
				continue
			b.farm_mult = -1.0
			if v.wetness(b.x, b.y) < SPRAY_DRY:
				var found := false
				for e: Array in watered:
					if int(e[0]) == b.id:
						e[1] = SPRAY_FIELD_TIME
						found = true
				if not found:
					watered.append([b.id, SPRAY_FIELD_TIME])
				fields += 1
	stats["sprays"] += 1
	stats["water"] += added
	stats["fires_out"] += out
	stats["fields"] += fields
	# 주민 — 같은 기적이 잦으면 감동이 덜함
	var d := v.cal_day(v.t)
	if int(sprays[0]) != d:
		sprays = [d, 0]
	sprays[1] = int(sprays[1]) + 1
	var near := _near_awake(v, p)
	if not flood:
		if v.aware:
			v.bless_all(SPRAY_BELIEF * pow(SPRAY_FADE, int(sprays[1]) - 1))
		else:
			Awakening.witness(v, "water")
		if near != null:
			var line := "거인님이 물을 내려 주셨다!" if v.aware else "하늘에서 물이 쏟아져!"
			if out > 0:
				line = "거인님의 물이 불을 꺼 주셨다!" if v.aware else "하늘에서 쏟아진 물에 불이 꺼졌어!"
			elif fields > 0:
				line = "마른 밭이 살아난다!"
			v.speak(near, line, 7)
		if out > 0:
			v.log_line(SmallCrises.say_for(v, "거인님의 물이 쏟아져 피우던 불이 꺼졌다.", "하늘에서 물이 쏟아져 피우던 불이 꺼졌다."))
	elif near != null:
		v.speak(near, "물이 넘친다! 높은 데로!", 7)
	_first(v, "water")
	v.giant_acted()
	return {"ok": true, "why": "", "water": added, "fields": fields, "fires_out": out, "flood": flood, "hit": hit.size()}


## 거인의 물을 붓는다 (가운데 깊고 가장자리 얕게 — 낮은 칸에 고여 연못). 넓은 세상의 거친 칸은 그 칸의 부피에. → 더한 물의 합
static func _add_water(v: Village, at: Vector2, rad: float, depth: float) -> float:
	var wt := v.water
	var cells := wt.cells_near(at, rad)
	var total := 0.0
	var w := wt.w
	var ww: WorldWater = wt as WorldWater if wt is WorldWater else null
	var coarse := {}
	for k in cells:
		var d := Vector2(wt.cx(k) - at.x, wt.cy(k) - at.y).length()
		if d > rad:
			continue
		var a := depth * (1.0 - 0.6 * d / rad)
		total += a
		if ww != null and not ww.is_fine_k(k):
			var c := ww.coarse_of(k)
			coarse[c] = float(coarse.get(c, 0.0)) + a
		else:
			w[k] += a
	wt.w = w
	if ww != null and not coarse.is_empty():
		var cv := ww.cV
		for c: int in coarse:
			cv[c] += float(coarse[c])
		ww.cV = cv
		for c: int in coarse:
			ww._relevel(c)
	return total


# ───────────────────────── 손으로 감싸기 ─────────────────────────
func cup(v: Village) -> Dictionary:
	var w := v.water
	if w.cup_left > 0.0:
		return {"ok": false, "why": "손의 온기가 아직 남아 있어요", "fear": false}
	var before := Health.temperature_at(v, v.center.x, v.center.y)
	w.cup_left = CUP_TIME
	var d := v.cal_day(v.t)
	if int(cups[0]) != d:
		cups = [d, 0]
	cups[1] = int(cups[1]) + 1
	stats["cups"] += 1
	var near := _near_awake(v, v.center)
	var fear := int(cups[1]) > CUP_FREE_PER_DAY
	if fear:
		v.raise_fear_all(CUP_FEAR)
		stats["cup_fear"] += 1
		if near != null:
			v.speak(near, "하늘이 우리를 쥐고 있어", 7)
	else:
		var cold := before < Balance.COLD_FROM + 3.0
		if v.aware:
			if cold:
				v.bless_all(CUP_BELIEF)
			if near != null:
				v.speak(near, "거인님의 손이 따뜻해요" if cold else "하늘이 포근해졌어", 7)
		else:
			Awakening.witness(v, "cup")
			if near != null:
				v.speak(near, "하늘이 따뜻해졌어!", 7)
	_first(v, "cup")
	v.giant_acted()
	return {"ok": true, "why": "", "fear": fear}


# ───────────────────────── 커튼 ─────────────────────────
func set_curtain(v: Village, step_i: int) -> Dictionary:
	step_i = clampi(step_i, 0, 2)
	var w := v.water
	if w.curtain == step_i:
		return {"ok": false, "why": "", "step": step_i}
	var was := w.curtain
	w.curtain = step_i
	if step_i != 2:
		w.curtain_dark = 0.0
		if w.curtain_frost:
			w.curtain_frost = false
			v.log_line("가려졌던 해가 다시 비치자 얼었던 밭에 싹이 다시 돋았다.")
			for b in v.buildings:
				if b.type == "농장":
					b.farm_mult = -1.0
	stats["curtain"] += 1
	if is_light(v.hour_now()):
		var near := _near_awake(v, v.center)
		if near != null:
			v.speak(near, "하늘이 흐려졌다" if step_i > was else "하늘이 다시 밝아졌다", 6)
	if step_i > 0:
		_first(v, "curtain")
	curtain_changed.emit(step_i)
	v.giant_acted()
	return {"ok": true, "why": "", "step": step_i}


# ───────────────────────── 유리 닦기 ─────────────────────────
func wipe(v: Village) -> Dictionary:
	if wipe_cd > 0.0:
		return {"ok": false, "why": "방금 닦았어요", "fog": 0.0, "dust": 0.0, "bright": false}
	var w := v.water
	var fog := fog_shown(v)
	var dust := w.glass_dust
	if fog < 0.05 and dust < 0.05:
		return {"ok": false, "why": "유리가 이미 맑아요", "fog": fog, "dust": dust, "bright": false}
	wipe_cd = WIPE_COOLDOWN
	w.glass_clear = 1.0
	var bright := dust >= BRIGHT_MIN
	if bright:
		w.bright_left = BRIGHT_TIME
	w.glass_dust = 0.0
	stats["wipes"] += 1
	if is_light(v.hour_now()) and (bright or fog >= 0.2):
		var near := _near_awake(v, v.center)
		if v.aware:
			v.bless_all(0.01)
			if near != null:
				v.speak(near, "거인님이 하늘을 닦아 주셨다", 6)
		else:
			Awakening.witness(v, "wipe")
			if near != null:
				v.speak(near, "하늘이 맑아졌어!", 6)
		_first(v, "wipe")
	v.giant_acted()
	return {"ok": true, "why": "", "fog": fog, "dust": dust, "bright": bright}


# ───────────────────────── 핀셋 ─────────────────────────
## 누른 자리 p 둘레에서 집을 것 (날벌레 → 먼지 뭉치 → 떨어진 물건 → 바위 순, 가까운 것) → {kind, pos, d, ref} 또는 {}
static func pick_target(v: Village, p: Vector2, reach := TWEEZE_R) -> Dictionary:
	var best := {}
	var bd := INF
	if v.smalls != null:
		for g in v.smalls.things:
			if g.state == "gone" or g.state == "out":
				continue
			var lim := maxf(Balance.GNAT_TWEEZE_R, reach) if g.kind == "gnat" else reach + g.size * 0.6
			var d := g.pos().distance_to(p)
			if d < lim and d < bd:
				bd = d
				best = {"kind": g.kind, "pos": g.pos(), "d": d, "ref": g}
		if not best.is_empty():
			return best
	for dr: Dictionary in v.drops:
		if dr.has("people") or float(dr["left"]) <= 1e-4:
			continue
		var q := Vector2(float(dr["x"]), float(dr["y"]))
		var d := q.distance_to(p)
		if d < reach + float(dr["size"]) * SkyDrops.shrink(dr) and d < bd:
			bd = d
			best = {"kind": "drop", "pos": q, "d": maxf(0.0, d - float(dr["size"]) * SkyDrops.shrink(dr) * 0.5), "ref": dr}
	if not best.is_empty():
		return best
	for rk: Dictionary in v.rocks:
		if int(rk["amt"]) <= 0 or int(rk.get("res", 0)) > 0:
			continue
		var q := Vector2(float(rk["x"]), float(rk["y"]))
		var d := q.distance_to(p)
		if d < reach and d < bd:
			bd = d
			best = {"kind": "rock", "pos": q, "d": d, "ref": rk}
	return best


## 핀셋 — p에서 집음. to를 주면 집은 것(먼지 뭉치·물건·바위)을 그 쪽으로 MOVE_MAX까지 옮겨 놓음 → {ok, why, picked, moved, kind, crushed}
func tweeze(v: Village, p: Vector2, to: Variant = null) -> Dictionary:
	if v.air == null or not v.air.lid_open:
		return {"ok": false, "why": "뚜껑을 먼저 열어 주세요", "picked": false, "moved": false, "kind": "", "crushed": ""}
	var tg := pick_target(v, p)
	if tg.is_empty():
		return {"ok": false, "why": "집을 것이 없어요", "picked": false, "moved": false, "kind": "", "crushed": ""}
	var kind := String(tg["kind"])
	if kind == "gnat":
		var r := v.smalls.tweeze(v, p)
		r["kind"] = "gnat"
		r["moved"] = false
		return r
	var dest: Variant = null
	if to != null:
		var tv: Vector2 = to
		var from: Vector2 = tg["pos"]
		dest = from + (tv - from).limit_length(MOVE_MAX)
		var size := _size_of(tg)
		if not _free_spot(v, dest, size):
			return {"ok": false, "why": "거기에는 내려놓을 수 없어요", "picked": false, "moved": false, "kind": kind, "crushed": ""}
	var crushed := _clumsy(v, p, float(tg["d"]))
	var name := ""
	match kind:
		"dust":
			var c: CrisisThing = tg["ref"]
			name = "회색 구름 덩어리"
			if dest == null:
				c.state = "gone"
				v.smalls.stats["blown"] += 1
			else:
				var q: Vector2 = dest
				c.x = q.x
				c.y = q.y
				c.px = q.x
				c.py = q.y
				c.tx = q.x
				c.ty = q.y
				c.cover_b = -1
		"drop":
			var dr: Dictionary = tg["ref"]
			name = "하늘에서 내려온 것"
			_free_carvers(v, dr)
			if dest == null:
				dr["left"] = 0.0
				v.drops.erase(dr)
			else:
				var q: Vector2 = dest
				dr["x"] = q.x
				dr["y"] = q.y
		"rock":
			var rk: Dictionary = tg["ref"]
			name = "바위"
			if dest == null:
				v.rocks.erase(rk)
			else:
				var q: Vector2 = dest
				rk["x"] = q.x
				rk["y"] = q.y
	if dest == null:
		stats["picked"] += 1
	else:
		stats["moved"] += 1
	var near := _near_awake(v, p)
	if v.aware:
		if crushed == "":
			v.bless_all(PICK_BELIEF)
		if near != null:
			v.speak(near, "거인님이 %s%s 집어 가셨다!" % [name, Village.josa(name, "을", "를")] if dest == null else "거인님이 %s%s 옮기셨다!" % [name, Village.josa(name, "을", "를")], 7)
	else:
		Awakening.witness(v, "tweeze")
		if near != null:
			v.speak(near, "하늘에서 커다란 손가락이…!", 7)
	_first(v, "pick" if dest == null else "move")
	v.giant_acted()
	return {"ok": true, "why": "", "picked": dest == null, "moved": dest != null, "kind": kind, "crushed": crushed}


static func _size_of(tg: Dictionary) -> float:
	match String(tg["kind"]):
		"dust":
			return (tg["ref"] as CrisisThing).size
		"drop":
			var dr: Dictionary = tg["ref"]
			return float(dr["size"]) * SkyDrops.shrink(dr)
	return 0.8


## 내려놓을 자리: 유리벽 안 · 물 밖 · 건물·모닥불과 떨어진 곳
static func _free_spot(v: Village, q: Vector2, size: float) -> bool:
	if not v.water.inside(q.x, q.y, 1.5 + size * 0.5) or v.water_at(q.x, q.y):
		return false
	if q.distance_to(v.fire) < 2.0 + size * 0.5 or q.distance_to(v.altar_pos) < Village.ALTAR_CLEAR:
		return false
	for b in v.buildings:
		if Vector2(b.x, b.y).distance_to(q) < b.size() * 0.5 + size * 0.5 + 0.6:
			return false
	return true


## 깎던 사람들을 놓아줌 (물건이 사라지거나 옮겨짐 — 든 것은 그대로 되돌림)
static func _free_carvers(v: Village, dr: Dictionary) -> void:
	for r in v.people:
		for s: Dictionary in r.steps:
			var o: Variant = s.get("done")
			if o is Dictionary and (o as Dictionary).get("d") == dr:
				ResidentAI.cancel(v, r)
				break


## 서툰 핀셋 (WORLD_EVENTS 7.1 — 멀리서 집으면 곁의 집이 부서질 수 있음, 난수 없이 거리로): 부서진 건물 종류 또는 ""
func _clumsy(v: Village, p: Vector2, grab_d: float) -> String:
	if grab_d <= TWEEZE_CLEAN:
		return ""
	var hit: Building = null
	var hd := TWEEZE_CRUSH_R
	for b in v.buildings:
		if b.is_store or b.site_type() == Awakening.ALTAR:
			continue
		var d2 := Vector2(b.x, b.y).distance_to(p) - b.size() * 0.5
		if d2 < hd:
			hd = d2
			hit = b
	if hit == null:
		return ""
	var crushed := hit.type
	SkyDrops.remove_building(v, hit)
	stats["crushed"] += 1
	v.log_line("하늘에서 내려온 집게가 빗나가 %s%s 짓눌렸다. 다친 사람은 없었다." % [crushed, Village.josa(crushed, "이", "가")])
	v.raise_fear_all(0.05)
	return crushed


# ───────────────────────── 공통 ─────────────────────────
static func _near_awake(v: Village, p: Vector2) -> Resident:
	var best: Resident = null
	var bd := INF
	for r in v.people:
		if r.sleeping or r.sick_left > 0.0 or r.age < 2.5:
			continue
		var d := Vector2(r.x, r.y).distance_squared_to(p)
		if d < bd:
			bd = d
			best = r
	return best


static func _warn(v: Village, kind: String, aware_text: String, unaware_text: String) -> void:
	v.warnings.append({"t": v.t, "kind": kind, "text": SmallCrises.say_for(v, aware_text, unaware_text)})
	if v.warnings.size() > 20:
		v.warnings.pop_front()


## 처음 쓴 날의 연대기 (깨달은 뒤 / 깨닫기 전)
func _first(v: Village, kind: String) -> void:
	if kind in firsts:
		return
	firsts.append(kind)
	var l: Array = FIRST[kind]
	v.log_line(String(l[0] if v.aware else l[1]))


func rotate() -> void:
	for s: Array in soaks:
		var q := JarWater.rot_pt(Vector2(float(s[0]), float(s[1])))
		s[0] = q.x
		s[1] = q.y


# ───────────────────────── 저장 ─────────────────────────
func to_dict() -> Dictionary:
	return SaveCodec.props(self)


static func from_dict(d: Dictionary) -> GiantHand:
	var h := GiantHand.new()
	SaveCodec.apply(h, d)
	return h
