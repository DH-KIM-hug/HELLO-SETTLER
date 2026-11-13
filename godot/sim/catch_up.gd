## 비운 시간 따라잡기 — docs/SAVE.md 3 (v1.1 등불) · 3.1 · 기획서 14장 · 6.6.
## v4.3: 비운 동안 병 시간 = min(비운 현실 시간, 등불) × 배율 rate (Balance.AWAY_RATES — 설정 "자리를 비운 동안 시간":
##   느리게 ×3 (12시간 → 1.5일) · 보통 ×6 (3일, 기본) · 빠르게 ×12 (6일)). 걸음은 Balance.AWAY_STEP (30초, 30일 인구 시험과 같은 걸음).
## (옛 설명) 병은 거인이 없어도 ×1로 흐르지만 **거인의 등불이 타는 동안만** (Market.lamp_seconds — 12시간, 업그레이드로 16·20·24시간).
## 그보다 오래 비우면 나머지는 잠든 시간 (병 시간이 멈춤 — 계절만 현실 달력대로 바뀐다), 연대기에 "긴 밤이 있었다." 한 줄.
## 그래서 따라잡기는 언제나 정밀 계산 (10초 걸음, 물 300초 간격 — 화면 없이 최대 속도, 최대 24시간치).
## 비운 동안 거인은 보고 있지 않다 (Village.watching = false): 위기 사망 하루 1명·부부 2쌍 아래로는 없음, 시대 점수 30%,
## 새 위기(곰팡이)는 조짐에서 기다림 — Village·Mold가 지킨다. 그동안 바친 제물은 이틀이 지나도 창고로 가지 않는다 — 상한은 늘 제단 크기 (Village.altar_hold, SAVE.md 3.1 · awakening-altar.md D4).
## 빠른 길 (CatchUp.fast, 기본 — ROADMAP 4 '따라잡기 속도'): 같은 규칙을 더 큰 간격으로 — 걸음 Balance.AWAY_STEP_FAST (60초),
##   물 계산 간격 ×AWAY_WATER_MULT, 건강·공기·버섯·혼인출산 간격 ×AWAY_TICK_MULT (Village.tick_mult), 일자리 배정 AWAY_JOBS_EVERY.
##   결과(인구·먹을 것·제물)는 정밀 따라잡기와 통계로 같다 (tests/run.gd test_catchup_fast). 재기: tools/bench_catchup.gd.
##   화면은 돌아오자마자 편지를 펼치고, 병 시간이 흐르는 동안 큰 일을 한 줄씩 쓴다 (CatchUpScreen — peek()).
## 쓰는 법: var c := CatchUp.new(village, elapsed) → 화면마다 c.run(ms) (true면 끝) → c.finish() = 편지 내용 → CatchUp.on_return(village, elapsed).
## 넓은 세상: CatchUp.new(world.primary(), elapsed, -1, world) — 세상 전체(모든 무리·물)가 JarWorld.advance로 흐른다
## (거인이 없으니 분가 편지는 하루 뒤 스스로 떠난다). 편지는 첫 무리 촌장이 쓰고 다른 무리 소식을 한 줄씩 더한다.
class_name CatchUp
extends RefCounted

const QUICK := 600.0                  # 10분 이하: 불러오는 동안 바로 (로딩 화면 없음)
const EXACT_CHUNK := 300.0            # 정밀 계산을 한 번에 흘리는 양 (진행 막대·시간 예산 확인 간격)
const FESTIVAL_AWAY := 24.0 * 3600.0  # 하루 넘게 비우면 귀환 축제 (현실 시간 — SAVE.md 4)
const LONG_AWAY := 7.0 * 86400.0      # 일주일 넘게 = 믿음이 조금 식어 있다
const COOL := 0.85                    # 오래 비웠을 때 믿음 × (의심하는 사람↑ — 기획서 7장)
const LONG_NIGHT := "긴 밤이 있었다."

var v: Village
var away := 0.0                       # 비운 현실 시간 (초)
var lamp := 0.0                       # 등불이 타는 시간 (초)
var exact_total := 0.0                # 병이 흐르는 시간 = min(비운 시간, 등불) × rate
var rate := 1.0                       # 비운 현실 1초에 병 몇 초 (Balance.AWAY_RATES)
var step_dt := Balance.AWAY_STEP      # 따라잡기 걸음 (초)
var exact_left := 0.0
var slept := 0.0                      # 등불이 꺼진 뒤 잠든 시간
var real_ms := 0.0                    # 실제로 걸린 계산 시간
var before: Dictionary = {}
var world: JarWorld = null            # 넓은 세상이면 그 세상 (모든 무리가 함께)
var befores: Dictionary = {}          # (넓은 세상) 무리 sid → snapshot
var n_before := 1                     # (넓은 세상) 비우기 전 무리 수
var _water_offline := false
var _done := false
var fast_path := false                # 이 따라잡기가 빠른 길인가 (CatchUp.fast · 시험이 걸음을 정하지 않았을 때)


## 비운 시간을 나눈다 → {exact 흐르는 시간, slept 잠든 시간} (초)
## exact = 병 시간 (min(비운 시간, 등불) × rate), slept = 등불이 꺼진 뒤의 현실 시간
static func plan(elapsed: float, lamp_s: float, rate_x := 1.0) -> Dictionary:
	var e := maxf(0.0, elapsed)
	return {"exact": minf(e, lamp_s) * rate_x, "slept": maxf(0.0, e - lamp_s)}


static var step_override := -1.0      # (시험) 0보다 크면 Balance.AWAY_STEP 대신 이 걸음 — 옛 시험 묶음은 10초 (v4.2)
static var fast := true               # 따라잡기 빠른 길 (ROADMAP 4 — 화면에만 보이는 일 건너뛰기·느린 계통은 성기게). false = 옛 정밀 걸음 (비교 시험)
static var rate_override := -1.0      # (시험) 0보다 크면 설정 대신 이 배율 — 옛 시험 묶음은 1 (비운 시간 = 병 시간, v4.2 규칙)


## 설정의 '자리를 비운 동안 시간' 배율 (GameSettings.away_speed → Balance.AWAY_RATES)
static func away_rate() -> float:
	if rate_override > 0.0:
		return rate_override
	var i := GameSettings.get_current().away_speed
	return float(Balance.AWAY_RATES[clampi(i, 0, Balance.AWAY_RATES.size() - 1)])


## 기기 시각으로 비운 시간: 뒤로 갔으면 0 (시각 조작), 앞으로 크게 간 것은 그냥 오래 비운 것 — 등불 상한까지만 흐른다 (SAVE.md 3)
static func elapsed_since(last_unix: float, now_unix: float) -> float:
	if last_unix <= 0.0 or now_unix <= last_unix:
		return 0.0
	return now_unix - last_unix


## lamp_s < 0 = 거인의 지금 등불 (Market.lamp_seconds). rate_x < 0 = 설정의 배율 (away_rate). 시험은 다른 값을 줄 수 있다
func _init(village: Village, elapsed: float, lamp_s := -1.0, jw: JarWorld = null, rate_x := -1.0) -> void:
	v = village
	world = jw
	away = maxf(0.0, elapsed)
	lamp = Market.lamp_seconds() if lamp_s < 0.0 else lamp_s
	rate = away_rate() if rate_x < 0.0 else rate_x
	fast_path = fast and step_override <= 0.0
	if step_override > 0.0:
		step_dt = step_override
	elif fast_path:
		step_dt = Balance.AWAY_STEP_FAST
	var p := plan(away, lamp, rate)
	exact_total = p["exact"]
	exact_left = exact_total
	slept = p["slept"]
	before = snapshot(v)
	_water_offline = v.water.offline
	v.water.offline = true
	if world != null:
		n_before = world.settlements.size()
		for q in world.settlements:
			befores[q.sid] = snapshot(q)
	_leave_all()


## 모든 무리: 거인이 보고 있지 않다 · 바친 제물은 상한 없이 쌓인다 · (빠른 길) 느린 계통은 성기게
func _leave_all() -> void:
	for q: Village in group():
		q.watching = false
		q.away_doubt = "long" if slept > 0.0 else "short"     # (Q28) 아이가 지켜보는 이를 의심하는 말은 등불 상한을 넘겨 비웠을 때만 (Village._idle_chatter_main)
		q.altar_hold = true
		q.tick_mult = Balance.AWAY_TICK_MULT if fast_path else 1.0


## 함께 흐르는 무리 (소형 병 = 하나)
func group() -> Array:
	return world.settlements if world != null else [v]


func needs_screen() -> bool:
	return away > QUICK


func is_done() -> bool:
	return exact_left <= 1e-6


## 0~1 (로딩 화면 진행 막대)
func progress() -> float:
	if exact_total <= 0.0:
		return 1.0
	return clampf((exact_total - exact_left) / exact_total, 0.0, 1.0)


## budget_ms 동안 흘린다 (화면이 멈추지 않게 나눠서). 다 끝났으면 true
func run(budget_ms: float = 1.0e9) -> bool:
	var t0 := Time.get_ticks_usec()
	var sdt0 := v.step_dt
	v.step_dt = step_dt               # 첫 무리의 걸음 크기로 다른 무리도 함께 걷는다
	var wm0 := v.water.offline_mult
	v.water.offline_mult = Balance.AWAY_WATER_MULT if fast_path else 1.0
	while not is_done():
		var dt := minf(EXACT_CHUNK, exact_left)
		if world != null:
			var n0 := world.settlements.size()
			world.advance(dt)
			if world.settlements.size() != n0:
				_leave_all()          # 비운 동안 분가해 새로 선 무리도 거인 없이
		else:
			v.advance(dt)
		exact_left -= dt
		for q: Village in group():
			q.crises.clear()      # 비운 동안의 위기 알림은 화면에 띄우지 않는다 (편지가 대신)
		if (Time.get_ticks_usec() - t0) / 1000.0 >= budget_ms:
			break
	v.step_dt = sdt0
	v.water.offline_mult = wm0
	real_ms += (Time.get_ticks_usec() - t0) / 1000.0
	return is_done()


## (따라잡는 도중) 지금까지의 편지 — 평범한 날의 줄 없이 큰 일만 (화면이 편지를 쓰는 중에 한 줄씩 더한다)
func peek() -> Dictionary:
	return letter(v, before, away, false)


## 따라잡는 도중의 병 날짜 (비운 동안 며칠째 — 1부터)
func day_now() -> int:
	return 1 + int((exact_total - exact_left) / Balance.DAY)


## 따라잡기 끝 — 거인이 다시 본다. 편지 내용을 돌려준다 (letter())
func finish() -> Dictionary:
	if not _done:
		_done = true
		run()
		v.water.offline = _water_offline
		for q: Village in group():
			q.watching = true
			q.tick_mult = 1.0
			q.altar_hold = false              # 돌아온 뒤엔 제단 규칙이 평소대로 (이틀 지난 제물은 창고로)
			q.crises.clear()
			while q.warnings.size() > 3:      # 비운 동안 쌓인 예고는 마지막 몇 개만 (나머지는 편지에)
				q.warnings.pop_front()
			if slept > 0.0:
				q.log_line(LONG_NIGHT)        # 주민은 잠든 시간을 모른다 — 연대기에 한 줄만
	var l := letter(v, before, away)
	if world != null:
		_add_world(l)
	l["lamp_h"] = int(roundf(lamp / 3600.0))
	l["slept"] = slept
	return l


## (넓은 세상) 편지에 다른 무리 소식: 무리마다 한 줄 (인구 변화 + 가장 큰 일) · 비운 동안 새로 선 무리 · 세상 전체 인구
func _add_world(l: Dictionary) -> void:
	var events: Array = l["events"]
	var extra: Array = []
	var p0 := 0
	var p1 := 0
	for q: Village in world.settlements:
		p1 += q.people.size()
		if befores.has(q.sid):
			p0 += int(befores[q.sid]["pop"])
		if q == v:
			continue
		var nm := q.settlement_name if q.settlement_name != "" else "다른 무리"
		if not befores.has(q.sid):
			extra.append("젊은 부부들이 새 땅으로 떠나 '%s'%s 세웠어요." % [nm, Village.josa(nm, "을", "를")])     # 편지 본문엔 숫자 없음 (C1 — 수는 머리띠에)
			continue
		var ql := letter(q, befores[q.sid], away)
		var top := ""
		for e: String in ql["events"]:
			if not e in [filler_wait(q), "아이들이 들판에서 뛰어놀았어요.", "밤마다 모닥불 앞에 모여 노래했어요.", "다들 맡은 일을 부지런히 했어요."]:
				top = e
				break
		if top == "":
			top = "모두 잘 지냈어요."
		extra.append("%s 소식: %s" % [nm, top])     # 편지 본문엔 숫자 없음 (C1 — 인구는 머리띠 world_pop0/1)
		if not (ql["altar_line"] as String).is_empty():
			(l["waiting"] as Array).append("%s 제단에도 제물이 있어요." % nm)
		if q.open_letters("split").size() > 0:
			(l["waiting"] as Array).append("%s에서도 새 땅으로 떠나고 싶다는 편지가 와 있어요." % nm)
		if q.revelation_pending():
			(l["waiting"] as Array).append(WatcherName.fill(q, "%s에서도 {w}의 계시를 기다려요." % nm))
	# 첫 무리 소식은 4줄까지, 다른 무리 소식을 그 아래에 (모두 6줄까지)
	l["events"] = events.slice(0, maxi(3, 6 - extra.size())) + extra.slice(0, 3)
	l["world_pop0"] = p0
	l["world_pop1"] = p1
	l["settlements"] = world.settlements.size()
	l["new_settlements"] = world.settlements.size() - n_before


## 로딩·귀환 화면 한 줄: 등불이 다 타고 꺼져 있었으면 "등불이 n시간 타고 꺼져 있었어요" (아니면 "")
static func lamp_words(lamp_s: float, away_s: float) -> String:
	if away_s <= lamp_s:
		return ""
	return "등불이 %d시간 타고 꺼져 있었어요" % int(roundf(lamp_s / 3600.0))


# ───────────────────────── 편지 ('자리를 비운 동안', SAVE.md 4) ─────────────────────────
static func snapshot(vv: Village) -> Dictionary:
	var ids := {}
	var partners := {}
	for p in vv.people:
		ids[p.id] = p.name
		partners[p.id] = p.partner
	var built := {}
	for b in vv.buildings:
		if b.built:
			built[b.id] = b.type
	return {"t": vv.t, "pop": vv.people.size(), "ids": ids, "partners": partners, "built": built, "salt": vv.salt_known,
		"harvest": vv.first_harvest_t >= 0.0, "faith": vv.faith, "book": vv.book.size(), "era": vv.era, "disc": vv.discoveries.keys()}


static func _ga(w: String) -> String:
	return Village.josa(w, "이", "가")


## 편지의 평범한 날 첫 줄 — 깨달은 마을은 부르는 말로 기다림 (N2 · STORY 4), 깨닫기 전엔 부름 없이
static func filler_wait(vv: Village) -> String:
	return WatcherName.fill(vv, "다들 {w:을/를} 기다리며 하루하루 잘 지냈어요.") if vv.aware else "다들 하루하루 잘 지냈어요."


## 촌장이 쓰는 편지 — {chief, away, pop0, pop1, events[3~5], born[id], lost[{id, name, why}], waiting[줄], festival, long,
##   altar_line 제단 줄 ("" = 빈 제단), offerings {물건: 개수}, offer_value 장터 값 (지폐)} + finish()가 lamp_h·slept를 더한다
static func letter(vv: Village, b: Dictionary, away_s: float, fill := true) -> Dictionary:
	var events: Array = []
	var t0 := float(b["t"])
	# 떠난 얼굴 (돌아가심)
	var lost: Array = []
	for r in vv.dead:
		if r.death_t > t0 and (b["ids"] as Dictionary).has(r.id):
			lost.append({"id": r.id, "name": r.name, "why": r.death_why})
	for r in vv.dead:
		if r.death_t > t0 and not (b["ids"] as Dictionary).has(r.id):
			lost.append({"id": r.id, "name": r.name, "why": r.death_why})     # 비운 동안 태어나 떠난 아이
	for l: Dictionary in lost.slice(0, 2):
		events.append("%s%s %s 세상을 떠났어요." % [l["name"], _ga(l["name"]), _death_words(String(l["why"]))])
	if lost.size() > 2:
		events.append("그 밖에도 %s 세상을 떠났어요." % count_words(lost.size() - 2, "분", "이", "가"))
	# 새 얼굴 (태어남)
	var born: Array = []
	var born_names: Array = []
	for r in vv.people:
		if not (b["ids"] as Dictionary).has(r.id) and r.born_t > t0 - 1.0:
			born.append(r.id)
			born_names.append(r.name)
	if born.size() == 1:
		var baby := vv.person(born[0])
		var mom := vv.person(baby.parents[0]) if baby.parents.size() > 0 else null
		if mom != null:
			events.append("%s%s %s%s 낳았어요." % [mom.name, _ga(mom.name), baby.name, Village.josa(baby.name, "을", "를")])
		else:
			events.append("%s%s 태어났어요." % [baby.name, _ga(baby.name)])
	elif born.size() > 1:
		events.append("아기 %s 태어났어요 — %s%s." % [count_words(born.size(), "", "이", "가"), ", ".join(PackedStringArray(born_names.slice(0, 3))), " 그리고 다른 아기들" if born.size() > 3 else ""])
	# 혼례
	var wed: Array = []
	var seen := {}
	for p in vv.people:
		if p.partner >= 0 and not seen.has(p.id) and int((b["partners"] as Dictionary).get(p.id, -1)) != p.partner:
			var q := vv.person(p.partner)
			if q != null:
				seen[q.id] = true
				seen[p.id] = true
				wed.append([p.name, q.name])
	if wed.size() == 1:
		events.append("%s%s %s%s 혼인했어요." % [wed[0][0], Village.josa(wed[0][0], "과", "와"), wed[0][1], _ga(wed[0][1])])
	elif wed.size() > 1:
		events.append("%s 모닥불 앞에서 혼인을 약속했어요." % count_words(wed.size(), "쌍", "이", "가"))
	# 새 건물
	var built_new := {}
	for bd in vv.buildings:
		if bd.built and not (b["built"] as Dictionary).has(bd.id):
			built_new[bd.type] = int(built_new.get(bd.type, 0)) + 1
	for ty: String in built_new:
		var n := int(built_new[ty])
		var lb := Balance.label(ty)
		events.append(("%s%s 다 지었어요." % [lb, Village.josa(lb, "을", "를")]) if n == 1 else ("%s %s 새로 지었어요." % [lb, count_words(n, "채", "을", "를")]))
	# 발견
	if vv.salt_known and not b["salt"]:
		events.append("마른 호수 바닥에서 짠 하얀 흙, '소금'을 찾았어요.")
	for id: String in vv.discoveries:             # 그 밖의 발견 (DISCOVERIES — sim/codex.gd 표). 소금은 위 한 줄
		if id == "salt" or id in b.get("disc", []) or (not b.has("disc") and float(vv.discoveries[id].get("t", 0.0)) < float(b["t"])):
			continue
		var nm := String(Codex.entry(id).get("name", ""))
		var who := String(vv.discoveries[id].get("name", ""))
		if nm != "":
			events.append(("%s%s '%s'%s 찾았어요." % [who, Village.josa(who, "이", "가"), nm, Village.josa(nm, "을", "를")]) if who != "" else ("'%s'%s 찾았어요." % [nm, Village.josa(nm, "을", "를")]))
	if vv.first_harvest_t >= 0.0 and not b["harvest"]:
		events.append("들에서 첫 곡식을 거두었어요.")
	for e: Dictionary in vv.book.slice(int(b["book"])):
		var tx: String = e["text"]
		if tx.contains("마침내 사라졌다"):
			events.append(tx.split(".")[0].replace("마침내 사라졌다", "마침내 사라졌어요") + ".")
	# 큰 일이 3줄이 안 되면 평범한 날의 줄로 채움 (SAVE.md 4장: 3~5줄)
	var fillers: Array = [filler_wait(vv)]
	if vv.people.any(func(q: Resident) -> bool: return q.is_child()):
		fillers.append("아이들이 들판에서 뛰어놀았어요.")
	fillers.append("밤마다 모닥불 앞에 모여 노래했어요.")
	fillers.append("다들 맡은 일을 부지런히 했어요.")
	var fi := 0
	while fill and events.size() < 3 and fi < fillers.size():
		events.append(fillers[fi])
		fi += 1
	# 기다리는 것
	var waiting: Array = []
	var alt := vv.altar_items()
	var value := 0.0
	var altar_line := ""
	if not alt.is_empty():                # 제단 줄은 따로 — 편지가 [모두 받기]를 곁에 단다 (SAVE.md 3.1)
		var parts := PackedStringArray()
		for item: String in alt:
			parts.append("%s %d개" % [item, int(alt[item])])
			value += Market.quote(item, int(alt[item]))
		altar_line = "제단에 %s%s 있어요 (장터 값 약 %s 지폐)." % ["·".join(parts), Village.josa(parts[parts.size() - 1], "이", "가"), _num(value)]
	var wishes := vv.open_letters("wish").size()
	if wishes > 0:
		waiting.append(WatcherName.fill(vv, "소원 편지 %s {w:을/를} 기다려요." % count_words(wishes, "통", "이", "가")))
	if vv.open_letters("split").size() > 0:
		waiting.append("새 땅으로 떠나고 싶다는 편지가 와 있어요.")
	if vv.revelation_pending():           # A5: 계시는 거인만 내린다 — 비운 동안 시대 점수가 찼으면 기다림 (GD 14)
		waiting.append(WatcherName.fill(vv, "노인들이 하늘을 올려다보며 {w}의 계시를 기다려요."))
	if vv.mold != null and vv.mold.phase == "omen":
		waiting.append("유리에 김이 서리기 시작했어요. 빵에 푸른 털이 났어요.")
	if vv.smalls != null:                 # [작은 위기] 조짐에서 기다리는 것 (물방울·날벌레·먼지)
		waiting.append_array(vv.smalls.waiting_lines())
	var c := vv.chief()
	return {"chief": c.name if c != null else "", "chief_id": c.id if c != null else -1, "away": away_s,
		"pop0": int(b["pop"]), "pop1": vv.people.size(), "events": events.slice(0, 5), "born": born, "lost": lost,
		"waiting": waiting, "festival": vv.aware and away_s > FESTIVAL_AWAY, "long": vv.aware and away_s >= LONG_AWAY,     # N2: 깨닫기 전엔 기다림·옛이야기 줄 없음
		"altar_line": altar_line, "offerings": alt, "offer_value": value}


## 편지 본문(촌장 손글씨)의 수를 말로 (chronicle-letters.md R6·C1 — 1·2·3 → 한·두·세, 4 이상 → 여럿, 숫자 없음).
## unit = 세는 말 ("분"·"쌍"·"채"·"통", 없으면 ""), a/b = 받침 있을 때/없을 때 조사 (Village.josa — "이"/"가" · "을"/"를")
## 예: (2, "", 이/가) → "둘이" · (2, "쌍", 이/가) → "두 쌍이" · (5, "채", 을/를) → "여러 채를" · (5, "", 이/가) → "여럿이"
static func count_words(n: int, unit: String, a: String, b: String) -> String:
	if unit == "":
		var bare := ["", "하나", "둘", "셋"]
		var w: String = bare[n] if n >= 1 and n <= 3 else "여럿"
		return w + Village.josa(w, a, b)
	var pre := ["", "한", "두", "세"]
	var word: String = (pre[n] if n >= 1 and n <= 3 else "여러") + " " + unit
	return word + Village.josa(unit, a, b)


## 지폐 숫자 (1,234)
static func _num(x: float) -> String:
	var n := int(roundf(x))
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func _death_words(why: String) -> String:
	if Balance.DISEASES.has(why):
		return "%s%s" % [why, Health.ro(why)]
	match why:
		"노환":
			return "나이가 들어 잠들 듯"
		"추위":
			return "추위를 이기지 못하고"
		"더위":
			return "더위를 이기지 못하고"
		"굶주림":
			return "굶주림 끝에"
	return "앓다가"


## '자리를 비운 동안' 편지 아래쪽 문구: 비운 시간 (병 날짜가 아니라 현실 — 촌장은 '며칠·몇 시간'으로 말한다)
static func away_words(s: float) -> String:
	var d := int(s / 86400.0)
	var h := int(fmod(s, 86400.0) / 3600.0)
	if d >= 1:
		return "%d일%s" % [d, (" %d시간" % h) if h > 0 and d < 3 else ""]
	if h >= 1:
		return "%d시간" % h
	return "%d분" % maxi(1, int(s / 60.0))


# ───────────────────────── 돌아왔을 때 (SAVE.md 4 · RESIDENT_AI 2.2 '거인의 귀환') ─────────────────────────
## 넓은 세상: 무리마다 (환호한 주민을 모두 합쳐 돌려줌)
static func on_return_world(jw: JarWorld, away_s: float) -> Array:
	var crowd: Array = []
	for q: Village in jw.settlements:
		crowd.append_array(on_return(q, away_s))
	return crowd


## 하루 넘게: 귀환 축제 (광장에 모여 하늘을 보고 환호, 제단 가득, 믿음↑). 하루 안: 반가운 말풍선 몇 개.
## 일주일 넘게: 믿음이 조금 식어 있다 + 노인이 아이에게 거인 이야기를 들려준다. 돌려줌 = 환호한 주민들 (화면이 목소리를 낸다)
static func on_return(vv: Village, away_s: float) -> Array:
	var crowd: Array = []
	if away_s <= QUICK:
		return crowd
	if not vv.aware:                     # N2: 깨닫기 전에는 지켜보는 이를 모른다 — 귀환 축제·축복·반기는 말 없음 (STORY 4 · CLAUDE.md 1)
		return crowd
	if away_s >= LONG_AWAY:                # 믿음이 조금 식음 — 그래도 이번 비움의 바닥(떠날 때의 절반, Q28) 아래로는 아님
		for p in vv.people:
			p.belief = vv.away_lower(p, p.belief * COOL)
	vv.away_floor.clear()
	# (Q28) 반김이 먼저 — 귀환 축제·반기는 말을 먼저 쓰고, 식은 믿음 이야기(일주일 넘게)는 그 뒤에
	if away_s > FESTIVAL_AWAY:
		vv.festival_t = vv.t
		var days := minf(5.0, away_s / 86400.0)
		vv.bless_all(0.06 + 0.02 * days)           # 비운 시간에 비례해 모두 크게 (RESIDENT_AI 2.2), 일주일 넘으면 식은 만큼 덜
		if vv.altar.size() < 2:
			vv.evening_offering()                  # 제단 가득 — 기쁜 마음에 남는 것을 더 바친다
		var lines := ["{w:이/가} 돌아오셨다!", "{w}!", "돌아오셨어요!", "하늘을 봐!"]
		var i := 0
		for p in vv.people:
			if p.is_baby() or p.sick_left > 0.0:
				continue
			ResidentAI.cancel(vv, p)
			p.sleeping = false
			p.action = "festival"
			p.last_action = "festival"
			p.doing = WatcherName.fill(vv, "{w}의 귀환을 반기는 중")
			var a := float(i) * 2.399
			var spot := vv.fire + Vector2(cos(a), sin(a)) * (1.6 + 0.35 * sqrt(float(i)))
			p.steps.append(ResidentAI.walk(spot.x, spot.y))
			p.steps.append(ResidentAI.act(1200.0, "play" if p.is_child() else "pray"))
			if i < 4:
				vv.speak(p, lines[i], 8)
			crowd.append(p)
			i += 1
		vv.log_line("{w:이/가} 돌아오셨다. 사람들은 광장에 모여 하늘을 올려다보며 환호했다.")
	else:
		var n := 0
		for p in vv.people:
			if not p.sleeping and p.age >= 2.5 and n < 3:
				vv.speak(p, ["{w}, 다시 오셨네요!", "{w:이다/다}!", "어서 오세요, {w}."][n], 6)
				crowd.append(p)
				n += 1
	if away_s >= LONG_AWAY:                # 오래 비운 뒤 — 노인이 아이에게 옛이야기를 다시 들려준다 (반김 다음, 벌주는 말 없이)
		vv.log_line("{w:이/가} 오래 보이지 않던 동안, {w} 이야기를 옛날이야기처럼 듣는 아이들도 생겼다. 노인들이 다시 들려주기 시작했다.")
		var elder: Resident = null
		var kid: Resident = null
		for p in vv.people:
			if p.is_elder() and (elder == null or p.age > elder.age):
				elder = p
			if p.is_child() and not p.is_baby() and kid == null:
				kid = p
		if elder != null:
			vv.speak(elder, "옛날 옛적, {w:이/가} 우리 조상을 이 땅에 내려놓으셨단다…", 10)
			if kid != null:
				vv.speak(kid, "정말요? {w:이/가} 진짜 계세요?", 8)
	vv._update_belief(0.0)
	return crowd
