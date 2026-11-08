## 핵 크기 = 병의 따뜻함 — docs/OPENING.md v4.0-6 · ROADMAP A28b · docs/BALANCE.md A28b (메인 판단, 사용자 위임 2026-11-08).
## 핵 0 '서늘한 별' (느리지만 튼튼) · 1 '따뜻한 별' (기준 — 이 파일은 아무것도 바꾸지 않는다) · 2 '뜨거운 별' (빠르고 풍성).
##  · 온도: 병 바탕 기온 + CORE_TEMP (Health.base_temp · season_grow) → 겨울이 길거나 짧아짐은 기온에서 저절로.
##  · 밀·꽃: CORE_GROW (밭 — 촌장의 어림에도 넣음: 늘 그런 병이므로) · CORE_FLOWER (꽃숲 묘목 자람·퍼짐).
##  · 이슬·마른 철 (첫 빵 뒤): 서늘한 별은 밭 젖음이 CORE_DEW만큼 '1 쪽으로' 올라가고 (이슬 — 밭이 잘 마르지 않음),
##    뜨거운 별은 마른 철(CORE_DRY_MONTHS)에 밭 자람 × (1 − CORE_DRY × (1 − 젖음)) (마른 밭일수록 — 재해 아님, light-seasons R5).
##  · 이끼 (서늘한 별): 바탕 CORE_MOSS_BASE + 마을 둘레 25곳 표본에서 그늘·축축함이 문턱(CORE_MOSS_SUN·CORE_MOSS_WET)을 넘는 몫
##    = 이끼 덮임 0~1 (병 하루에 한 번). 이끼 → 탁한 공기 ÷ (1 + MOSS_STALE × 덮임) · 집 안 추위 × (1 − MOSS_BED × 덮임) (이끼 이불)
##    · 추운 철 발병 × (1 − MOSS_ILL × 덮임).
##  · 달팽이 (서늘한 별): 아침마다 아이들이 이끼에서 주워 옴 (하루 필요 × CORE_SNAIL_DAY × 이끼 덮임 → '버섯' 더미).
##  · 버섯: 큰 버섯 돋는 빠르기 × CORE_SHROOM, 버섯이 느끼는 김 + CORE_SHROOM_DAMP + MOSS_SHROOM_DAMP × 이끼 · 버섯꾼이 버섯을 내려놓을 때 달팽이 덤 × CORE_SNAIL (같은 '버섯' 더미에).
##  · 땅 흔들림 (뜨거운 별): 병 하루마다 CORE_TREMOR_DAY 확률 (마을 씨앗·날의 해시 — 난수 흐름을 쓰지 않음), 그날 해시의 시각에.
##    먼지 (사건 ground_tremor — 화면 연출) · 연대기 · 가끔 항아리 하나가 깨져 먹을 것이 조금 쏟아짐. 죽거나 다치는 사람은 없다.
##    흔들린 뒤 HOT_SPRING_P 확률로 발견 L5 '땅속의 열' (온천 — 집 땔감 × HOT_SPRING_FUEL · 추위 × HOT_SPRING_COLD).
##  · 느낌: 차이가 처음 보일 때 별지기의 수첩 한 줄 (Village.jar_notes — 저장됨, 사건 jar_trait_noticed). 숫자 없음.
## 상태: 캐시만 (Village.warmth — 저장 안 함, 날·시간에서 다시 셈). 알린 것은 jar_notes · stats (tremors). 정적 상태 없음 (ADR-0001 d).
## 거인이 보는지 여부를 읽지 않는다. 핵 1(또는 작은 병)이면 모든 함수가 곧바로 1.0 / 0.0을 돌려준다 — 기준 균형이 그대로.
class_name CoreWarmth
extends RefCounted

const NOTES := {
	"cool_slow": "서늘한 별이라 그런지, 꽃도 밀도 느긋하게 자란다.",
	"dew": "이 병은 이슬이 많아 밭이 잘 마르지 않는다.",
	"moss": "그늘마다 이끼가 두툼하게 덮였다. 병 안 공기가 맑다.",
	"snail": "이끼 사이에 달팽이가 많다. 아이들이 아침마다 주워 온다.",
	"moss_bed": "집집이 이끼를 깔고 잔다. 긴 겨울에도 덜 앓는 것 같다.",
	"hot_fast": "뜨거운 별이라 그런지, 꽃이 서둘러 피고 밀도 빨리 여문다.",
	"dry": "여름이 되자 밭이 빨리 마른다. 물을 뿌려 주면 좋겠다.",
	"tremor": "땅이 살짝 뒤척였다. 뜨거운 별이라 그런가 보다.",
	"short_winter": "이 병은 겨울이 늦게 오고 일찍 물러간다.",
}
const NOTE_AFTER := 2.0 * Balance.DAY       # 첫 빵 뒤 이만큼 지나야 '느리다·빠르다'를 느낀다
const LINE_TREMOR_FIRST := "땅이 잠깐 흔들렸다. 그릇이 달그락거렸고, 아이들은 어른 품으로 뛰어들었다. 흔들림은 곧 멎었다."
const LINE_TREMOR_POT := "땅이 또 흔들려 항아리 하나가 깨졌다. %s 조금 쏟아졌다."
const SAY_TREMOR := "어이쿠, 땅이 흔들려!"
const LINE_SNAIL := "버섯 갓 밑에 달팽이가 잔뜩 붙어 있었다. 사람들은 그것도 구워 먹었다."
const LINE_SNAIL_KIDS := "아침 이슬이 마르기 전, %s 이끼 사이에서 달팽이를 한 바구니 주워 왔다. 그날 저녁 국이 조금 더 진했다."

var moss_day := -1                    # 이끼 덮임을 셈한 병 날 번호
var moss := 0.0                       # 이끼 덮임 0~1
var farm_hour := -1                   # 밭 이슬·마른 철 배율을 셈한 병 시간 번호
var farm_k: Dictionary = {}           # 건물 id → 배율 (그 시간)


# ───────────────────────── 핵 ─────────────────────────
## 0 작게 · 1 보통 · 2 크게 — 넓은 세상만 (작은 병은 늘 보통)
static func core_of(v: Village) -> int:
	if v.water is WorldWater:
		return clampi((v.water as WorldWater).core, 0, 2)
	return 1


static func _st(v: Village) -> CoreWarmth:
	if v.warmth == null:
		v.warmth = CoreWarmth.new()
	return v.warmth


# ───────────────────────── 기온·자람 ─────────────────────────
## 병 바탕 기온에 더할 값 (Health.base_temp · season_grow)
static func temp(v: Village) -> float:
	var c := core_of(v)
	return 0.0 if c == 1 else float(Balance.CORE_TEMP[c])


## 철 자람 상한에 더할 값 (뜨거운 별은 한여름에 조금 더 자람)
static func grow_cap(v: Village) -> float:
	var c := core_of(v)
	return 0.0 if c == 1 else float(Balance.CORE_GROW_CAP[c])


## 밀 자람 (늘 그런 병 — 촌장의 어림 food_rate에도)
static func grow(v: Village) -> float:
	var c := core_of(v)
	return 1.0 if c == 1 else float(Balance.CORE_GROW[c])


## 꽃숲 묘목 자람·저절로 퍼짐
static func flower(v: Village) -> float:
	var c := core_of(v)
	return 1.0 if c == 1 else float(Balance.CORE_FLOWER[c])


## 밭 하나의 배율 = 밀 자람 × 이슬/마른 철 (Village._update_building — 농장만)
static func farm_mult(v: Village, b: Building) -> float:
	var c := core_of(v)
	if c == 1:
		return 1.0
	return float(Balance.CORE_GROW[c]) * field_wet_mult(v, b)


## 이슬(서늘한 별)·마른 철(뜨거운 별)이 밭 젖음을 바꾼 만큼의 자람 배율 — 첫 빵 뒤부터, 병 한 시간마다 셈
static func field_wet_mult(v: Village, b: Building) -> float:
	var c := core_of(v)
	if c == 1 or not Production.bread_made(v):
		return 1.0
	var s := _st(v)
	var hi := floori((v.start_clock + v.t) / Balance.HOUR)
	if hi != s.farm_hour:
		s.farm_hour = hi
		s.farm_k = {}
	if s.farm_k.has(b.id):
		return float(s.farm_k[b.id])
	var m := v.wetness(b.x, b.y)
	var k := 1.0
	var dew := float(Balance.CORE_DEW[c])
	if dew > 0.0:                                   # 이슬: 젖음이 1 쪽으로 (마른 밭일수록 덕을 봄 — Village.farm_mult의 젖음 몫과 같은 꼴)
		var m2 := m + (1.0 - m) * dew
		k = (0.65 + 0.7 * m2) / (0.65 + 0.7 * m)
	var dry := float(Balance.CORE_DRY[c])
	if dry > 0.0 and dry_season(v):                 # 마른 철: 마른 밭일수록 더 (물가 밭은 거의 그대로)
		k *= 1.0 - dry * (1.0 - m)
	s.farm_k[b.id] = k
	return k


static func dry_season(v: Village) -> bool:
	return int(Health.jar_date(v)["month"]) in Balance.CORE_DRY_MONTHS


# ───────────────────────── 이끼 (서늘한 별) ─────────────────────────
## 이끼 덮임 0~1 — 마을 둘레 25곳 (JarAir.wet_avg와 같은 표본), 병 하루에 한 번
static func moss_cover(v: Village) -> float:
	var c := core_of(v)
	if float(Balance.CORE_MOSS_K[c]) <= 0.0 or v.water == null:
		return 0.0
	var s := _st(v)
	var di := floori((v.start_clock + v.t) / Balance.DAY)
	if di == s.moss_day:
		return s.moss
	s.moss_day = di
	var sum := 0.0
	var n := 0
	for i in 5:
		for j in 5:
			var x := v.center.x + (i - 2) * 6.0
			var y := v.center.y + (j - 2) * 6.0
			if not v.water.inside(x, y, 1.0):
				continue
			var sun := v.water.sun_at(x, y)
			var wet := v.wetness(x, y)
			sum += clampf((float(Balance.CORE_MOSS_SUN[c]) - sun) * 2.5, 0.0, 1.0) * clampf((wet - float(Balance.CORE_MOSS_WET[c])) * 4.0, 0.0, 1.0)
			n += 1
	var base := float(Balance.CORE_MOSS_BASE[c])    # 서늘한 별은 볕 드는 마른 땅에도 얇게 — 그늘·축축한 곳일수록 두툼하게
	s.moss = clampf((base + (1.0 - base) * (sum / n)) * float(Balance.CORE_MOSS_K[c]), 0.0, 1.0) if n > 0 else 0.0
	return s.moss


## 탁한 공기 나눗수 (JarAir.stale_target)
static func stale_div(v: Village) -> float:
	if core_of(v) == 1:
		return 1.0
	return 1.0 + Balance.MOSS_STALE * moss_cover(v)


## 집 안 추위 배율 (Health.protection — 이끼 이불 · 온천)
static func bed_cold(v: Village) -> float:
	if core_of(v) == 1:
		return 1.0
	return 1.0 - Balance.MOSS_BED * moss_cover(v)


## 추운 철 앓을 몫 배율 (Health._hourly 발병 굴림 — 이끼 이불을 깔고 자서 긴 겨울에 덜 앓음)
static func ill_mult(v: Village) -> float:
	if core_of(v) == 1 or not v.cold_season:
		return 1.0
	return 1.0 - Balance.MOSS_ILL * moss_cover(v)


## 온천을 알면 추위 배율 (밖·안 모두 — 몸을 녹임)
static func spring_cold(v: Village) -> float:
	if core_of(v) != 2 or not Codex.knows(v, "hot_spring"):
		return 1.0
	return Balance.HOT_SPRING_COLD


## 집 땔감이 타는 빠르기 배율 (Health._fuel — 온천)
static func fuel_mult(v: Village) -> float:
	if core_of(v) != 2 or not Codex.knows(v, "hot_spring"):
		return 1.0
	return Balance.HOT_SPRING_FUEL


# ───────────────────────── 버섯·달팽이 ─────────────────────────
static func shroom(v: Village) -> float:
	var c := core_of(v)
	return 1.0 if c == 1 else float(Balance.CORE_SHROOM[c])


## 큰 버섯이 느끼는 김에 더할 값 (Flora._spawn_single · _grow_shrooms — 병의 김 JarAir.humid 자체는 바꾸지 않음: 곰팡이 등은 그대로)
static func shroom_damp(v: Village) -> float:
	var c := core_of(v)
	if c == 1:
		return 0.0
	return float(Balance.CORE_SHROOM_DAMP[c]) + Balance.MOSS_SHROOM_DAMP * moss_cover(v)


## 버섯꾼이 버섯을 내려놓을 때 (Flora 'flora_drop') — 달팽이 덤을 같은 더미에 보탬, 보탠 양을 돌려줌
static func snail_bonus(v: Village, amt: float) -> float:
	var c := core_of(v)
	if c == 1 or amt <= 0.0:
		return 0.0
	var k := float(Balance.CORE_SNAIL[c])
	if k <= 0.0:
		return 0.0
	var add := amt * k
	v.stock["버섯"] = float(v.stock.get("버섯", 0.0)) + add
	v.stats["snails"] = float(v.stats.get("snails", 0.0)) + add
	if not has_note(v, "snail"):
		v.log_line(LINE_SNAIL)
		note(v, "snail")
	return add


## 아침 (SNAIL_HOUR 뒤 첫 시간, 하루 한 번): 아이들이 이끼에서 달팽이를 주워 옴 → '버섯' 더미 (곁 먹을거리 — 하루 필요 × CORE_SNAIL_DAY × 이끼)
static func _snail_morning(v: Village) -> void:
	var k := float(Balance.CORE_SNAIL_DAY[core_of(v)])
	if k <= 0.0:
		return
	var clock := v.start_clock + v.t
	var di := floori(clock / Balance.DAY)
	if int(v.stats.get("snail_day", -1)) == di or fmod(clock, Balance.DAY) / Balance.HOUR < Balance.SNAIL_HOUR:
		return
	v.stats["snail_day"] = di
	var kids := v.people.filter(func(r: Resident) -> bool: return r.is_child() and r.age >= 2.5 and r.sick_left <= 0.0)
	if kids.is_empty():
		return
	var add := Production.day_need(v) * k * moss_cover(v)
	if add <= 0.0:
		return
	v.stock["버섯"] = float(v.stock.get("버섯", 0.0)) + add
	v.stats["snails"] = float(v.stats.get("snails", 0.0)) + add
	if not has_note(v, "snail"):
		v.log_line(LINE_SNAIL_KIDS % ((kids[0] as Resident).name + Village.josa((kids[0] as Resident).name, "이", "가")))
		note(v, "snail")


# ───────────────────────── 수첩 한 줄 ─────────────────────────
static func has_note(v: Village, id: String) -> bool:
	for n: Dictionary in v.jar_notes:
		if String(n["id"]) == id:
			return true
	return false


## 처음 눈에 띈 차이를 한 줄 (같은 병의 다른 무리가 이미 적었으면 적지 않음 — 병의 것)
static func note(v: Village, id: String) -> bool:
	if has_note(v, id):
		return false
	for o: Village in v.peers:
		if o != v and has_note(o, id):
			return false
	var text: String = NOTES.get(id, "")
	v.jar_notes.append({"t": v.t, "id": id, "text": text})
	v.emit(&"jar_trait_noticed", {"v": {"id": id, "text": text, "core": core_of(v)}})
	return true


# ───────────────────────── 시간마다 (Village.step 'lake' 타이머) ─────────────────────────
static func hourly(v: Village) -> void:
	var c := core_of(v)
	if c == 1 or v.people.is_empty():
		return
	var bread := Production.bread_made(v)
	if bread and not v.stats.has("warm_bread_t"):
		v.stats["warm_bread_t"] = v.t              # 첫 빵을 본 시각 (느림·빠름을 느끼기 시작)
	if bread and v.t - float(v.stats.get("warm_bread_t", v.t)) >= NOTE_AFTER:
		note(v, "cool_slow" if c == 0 else "hot_fast")
	if c == 0:
		if bread:
			_snail_morning(v)
		if bread and moss_cover(v) >= Balance.MOSS_NOTE:
			note(v, "moss")
		if bread and not has_note(v, "dew"):
			for b in v.buildings:
				if b.built and b.type == "농장" and field_wet_mult(v, b) >= Balance.CORE_NOTE_FIELD:
					note(v, "dew")
					break
		if bread and v.cold_season and moss_cover(v) >= Balance.MOSS_NOTE:
			note(v, "moss_bed")
	else:
		if bread and not has_note(v, "dry") and dry_season(v):
			for b in v.buildings:
				if b.built and b.type == "농장" and field_wet_mult(v, b) <= 2.0 - Balance.CORE_NOTE_FIELD:
					note(v, "dry")
					break
		if v.cold_season:
			v.stats["warm_cold_seen"] = 1          # 겨울을 한 번 겪음 → 추위가 끝나 갈 무렵 '겨울이 짧다' (봄 앞 2~4월)
		elif bread and v.stats.has("warm_cold_seen") and int(Health.jar_date(v)["month"]) in [2, 3, 4]:
			note(v, "short_winter")
		_tremor_check(v)


## 땅 흔들림 — 그날 해시가 CORE_TREMOR_DAY 아래면 해시의 시각에 한 번 (첫 빵 뒤 · 마을이 TREMOR_MIN_AGE 넘음)
static func tremor_today(v: Village, day_i: int) -> Variant:
	var p := float(Balance.CORE_TREMOR_DAY[core_of(v)])
	if p <= 0.0:
		return null
	var h := Wildlife._hash3(LeanSeasons.key(v), day_i, 9301)
	if h.x >= p:
		return null
	return int(floor(h.y * 24.0))


static func _tremor_check(v: Village) -> void:
	if not Production.bread_made(v) or v.t < Balance.TREMOR_MIN_AGE:
		return
	var clock := v.start_clock + v.t
	var di := floori(clock / Balance.DAY)
	if int(v.stats.get("tremor_day", -1)) == di:
		return
	var hr: Variant = tremor_today(v, di)
	if hr == null or int(fmod(clock, Balance.DAY) / Balance.HOUR) != int(hr):
		return
	v.stats["tremor_day"] = di
	tremor(v, di)


## 땅 흔들림 하나 (시험이 바로 부를 수 있음). 죽음·다침 없음
static func tremor(v: Village, di: int) -> Dictionary:
	var n := int(v.stats.get("tremors", 0)) + 1
	v.stats["tremors"] = n
	var h := Wildlife._hash3(LeanSeasons.key(v), di, 9419)
	var pot := ""
	var lost := 0.0
	if n > 1 and h.x < Balance.TREMOR_POT_P:
		for k: String in ["밀가루", "빵", "버섯", "밀"]:
			var have := float(v.stock.get(k, 0.0))
			if have >= Balance.TREMOR_POT_MIN:
				lost = have * Balance.TREMOR_POT_LOSS
				v.stock[k] = have - lost
				pot = k
				break
	if n == 1:
		v.log_line(LINE_TREMOR_FIRST)
	elif pot != "":
		v.log_line(LINE_TREMOR_POT % (pot + Village.josa(pot, "이", "가")))
	for r in v.people:
		if not r.sleeping and r.age >= 2.5:
			v.speak(r, SAY_TREMOR, 4)
			break
	for r in v.people:
		if not r.sleeping:
			v.raise_fear(r, Balance.TREMOR_FEAR)
	v.stats["tremor_lost"] = float(v.stats.get("tremor_lost", 0.0)) + lost
	v.emit(&"ground_tremor", {"at": v.center, "v": {"n": n, "pot": pot, "lost": lost}})
	note(v, "tremor")
	# 흔들린 자리에서 김이 오름 → 발견 L5 땅속의 열 (온천)
	if not Codex.knows(v, "hot_spring") and h.y < Balance.HOT_SPRING_P:
		var who := Discovery.finder(v, "hot_spring")
		if who != null:
			Discovery.make(v, "hot_spring", who)
	return {"n": n, "pot": pot, "lost": lost}
