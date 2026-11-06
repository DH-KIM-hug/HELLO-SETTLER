## 비운 시간 따라잡기 — docs/SAVE.md 3 · 기획서 14장 · 6.6 ('병은 거인이 없어도 ×1로 흐른다').
## 비운 현실 시간 = 병 시간. 10분 이하·12시간 이하 = 정밀 계산(10초 걸음, 물 300초 간격 — 화면 없이 최대 속도),
## 12시간 초과 = 앞부분은 요약 계산(sim/offline_summary.gd, 1시간씩) + 마지막 12시간은 정밀 → 돌아왔을 때 화면은 늘 정밀 상태.
## 비운 동안 거인은 보고 있지 않다 (Village.watching = false): 위기 사망 하루 1명·부부 2쌍 아래로는 없음, 시대 점수 30%,
## 새 위기(곰팡이)는 조짐에서 기다림, 제물은 이틀치까지 — 모두 Village·Mold가 지킨다.
## 쓰는 법: var c := CatchUp.new(village, elapsed) → 화면마다 c.run(ms) (true면 끝) → c.finish() = 편지 내용 → CatchUp.on_return(village, elapsed).
class_name CatchUp
extends RefCounted

const QUICK := 600.0                  # 10분 이하: 불러오는 동안 바로 (로딩 화면 없음)
const EXACT_MAX := 12.0 * 3600.0      # 마지막 12시간은 정밀
const EXACT_CHUNK := 300.0            # 정밀 계산을 한 번에 흘리는 양 (진행 막대·시간 예산 확인 간격)
const SUMMARY_HOUR_W := 0.45          # 진행 막대 무게: 요약 1시간 ≈ 정밀 1시간의 0.45배 (Mac 측정)
const FESTIVAL_AWAY := 24.0 * 3600.0  # 하루 넘게 비우면 귀환 축제
const LONG_AWAY := 7.0 * 86400.0      # 일주일 넘게 = 믿음이 조금 식어 있다
const COOL := 0.85                    # 오래 비웠을 때 믿음 × (의심하는 사람↑ — 기획서 7장)

var v: Village
var away := 0.0
var summary_total := 0.0
var exact_total := 0.0
var summary_left := 0.0
var exact_left := 0.0
var real_ms := 0.0                    # 실제로 걸린 계산 시간
var before: Dictionary = {}
var _water_offline := false
var _began_summary := false
var _done := false


## 비운 시간을 나눈다 → {summary, exact} (초)
static func plan(elapsed: float) -> Dictionary:
	var e := maxf(0.0, elapsed)
	return {"summary": maxf(0.0, e - EXACT_MAX), "exact": minf(e, EXACT_MAX)}


## 기기 시각으로 비운 시간: 뒤로 갔으면 0 (시각 조작), 앞으로 크게 간 것은 그냥 오래 비운 것 (SAVE.md 3)
static func elapsed_since(last_unix: float, now_unix: float) -> float:
	if last_unix <= 0.0 or now_unix <= last_unix:
		return 0.0
	return now_unix - last_unix


func _init(village: Village, elapsed: float) -> void:
	v = village
	away = maxf(0.0, elapsed)
	var p := plan(away)
	summary_total = p["summary"]
	exact_total = p["exact"]
	summary_left = summary_total
	exact_left = exact_total
	before = snapshot(v)
	_water_offline = v.water.offline
	v.watching = false
	v.water.offline = true


func needs_screen() -> bool:
	return away > QUICK


func is_done() -> bool:
	return summary_left <= 1e-6 and exact_left <= 1e-6


## 0~1 (로딩 화면 진행 막대)
func progress() -> float:
	var tot := summary_total / 3600.0 * SUMMARY_HOUR_W + exact_total / 3600.0
	if tot <= 0.0:
		return 1.0
	var done := (summary_total - summary_left) / 3600.0 * SUMMARY_HOUR_W + (exact_total - exact_left) / 3600.0
	return clampf(done / tot, 0.0, 1.0)


## budget_ms 동안 흘린다 (화면이 멈추지 않게 나눠서). 다 끝났으면 true
func run(budget_ms: float = 1.0e9) -> bool:
	var t0 := Time.get_ticks_usec()
	while not is_done():
		if summary_left > 1e-6:
			if not _began_summary:
				_began_summary = true
				OfflineSummary.begin(v)
			var dt := minf(Balance.HOUR, summary_left)
			OfflineSummary.hour(v, dt)
			summary_left -= dt
		else:
			var dt := minf(EXACT_CHUNK, exact_left)
			v.advance(dt)
			exact_left -= dt
			v.crises.clear()          # 비운 동안의 위기 알림은 화면에 띄우지 않는다 (편지가 대신)
		if (Time.get_ticks_usec() - t0) / 1000.0 >= budget_ms:
			break
	real_ms += (Time.get_ticks_usec() - t0) / 1000.0
	return is_done()


## 따라잡기 끝 — 거인이 다시 본다. 편지 내용을 돌려준다 (letter())
func finish() -> Dictionary:
	if not _done:
		_done = true
		run()
		v.watching = true
		v.water.offline = _water_offline
		v.crises.clear()
		while v.warnings.size() > 3:          # 비운 동안 쌓인 예고는 마지막 몇 개만 (나머지는 편지에)
			v.warnings.pop_front()
	return letter(v, before, away)


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
		"harvest": vv.first_harvest_t >= 0.0, "faith": vv.faith, "book": vv.book.size(), "era": vv.era}


static func _ga(w: String) -> String:
	return Village.josa(w, "이", "가")


## 촌장이 쓰는 편지 — {chief, away, pop0, pop1, events[3~5], born[id], lost[{id, name, why}], waiting[줄], festival, long}
static func letter(vv: Village, b: Dictionary, away_s: float) -> Dictionary:
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
		events.append("그 밖에도 %d명이 세상을 떠났어요." % (lost.size() - 2))
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
		events.append("아기가 %d명 태어났어요 — %s%s." % [born.size(), ", ".join(PackedStringArray(born_names.slice(0, 3))), (" 외 %d명" % (born.size() - 3)) if born.size() > 3 else ""])
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
		events.append("%d쌍이 모닥불 앞에서 혼인을 약속했어요." % wed.size())
	# 새 건물
	var built_new := {}
	for bd in vv.buildings:
		if bd.built and not (b["built"] as Dictionary).has(bd.id):
			built_new[bd.type] = int(built_new.get(bd.type, 0)) + 1
	for ty: String in built_new:
		var n := int(built_new[ty])
		events.append(("%s%s 다 지었어요." % [ty, Village.josa(ty, "을", "를")]) if n == 1 else ("%s %d채를 새로 지었어요." % [ty, n]))
	# 발견
	if vv.salt_known and not b["salt"]:
		events.append("마른 호수 바닥에서 짠 하얀 흙, '소금'을 찾았어요.")
	if vv.first_harvest_t >= 0.0 and not b["harvest"]:
		events.append("들에서 첫 곡식을 거두었어요.")
	for e: Dictionary in vv.book.slice(int(b["book"])):
		var tx: String = e["text"]
		if tx.contains("마침내 사라졌다"):
			events.append(tx.split(".")[0].replace("마침내 사라졌다", "마침내 사라졌어요") + ".")
	# 큰 일이 3줄이 안 되면 평범한 날의 줄로 채움 (SAVE.md 4장: 3~5줄)
	var fillers: Array = ["다들 거인님을 기다리며 하루하루 잘 지냈어요."]
	if vv.people.any(func(q: Resident) -> bool: return q.is_child()):
		fillers.append("아이들이 들판에서 뛰어놀았어요.")
	fillers.append("밤마다 모닥불 앞에 모여 노래했어요.")
	fillers.append("다들 맡은 일을 부지런히 했어요.")
	var fi := 0
	while events.size() < 3 and fi < fillers.size():
		events.append(fillers[fi])
		fi += 1
	# 기다리는 것
	var waiting: Array = []
	var alt := vv.altar_items()
	if not alt.is_empty():
		var parts := PackedStringArray()
		for item: String in alt:
			parts.append("%s %d개" % [item, int(alt[item])])
		waiting.append("제단에 %s%s 있어요." % [", ".join(parts), Village.josa(parts[parts.size() - 1], "이", "가")])
	var wishes := vv.open_letters("wish").size()
	if wishes > 0:
		waiting.append("소원 편지 %d통이 거인님을 기다려요." % wishes)
	if vv.open_letters("split").size() > 0:
		waiting.append("새 땅으로 떠나고 싶다는 편지가 와 있어요.")
	if vv.mold != null and vv.mold.phase == "omen":
		waiting.append("유리에 김이 서리기 시작했어요. 빵에 푸른 털이 났어요.")
	var c := vv.chief()
	return {"chief": c.name if c != null else "", "chief_id": c.id if c != null else -1, "away": away_s,
		"pop0": int(b["pop"]), "pop1": vv.people.size(), "events": events.slice(0, 5), "born": born, "lost": lost,
		"waiting": waiting, "festival": away_s > FESTIVAL_AWAY, "long": away_s >= LONG_AWAY}


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
## 하루 넘게: 귀환 축제 (광장에 모여 하늘을 보고 환호, 제단 가득, 믿음↑). 하루 안: 반가운 말풍선 몇 개.
## 일주일 넘게: 믿음이 조금 식어 있다 + 노인이 아이에게 거인 이야기를 들려준다. 돌려줌 = 환호한 주민들 (화면이 목소리를 낸다)
static func on_return(vv: Village, away_s: float) -> Array:
	var crowd: Array = []
	if away_s <= QUICK:
		return crowd
	if away_s >= LONG_AWAY:
		for p in vv.people:
			p.belief *= COOL
		vv.log_line("거인님이 오래 보이지 않자, 거인 이야기를 옛날이야기로 여기는 아이들이 생겼다.")
		var elder: Resident = null
		var kid: Resident = null
		for p in vv.people:
			if p.is_elder() and (elder == null or p.age > elder.age):
				elder = p
			if p.is_child() and not p.is_baby() and kid == null:
				kid = p
		if elder != null:
			vv.speak(elder, "옛날 옛적, 하늘의 거인님이 우리 조상을 이 땅에 내려놓으셨단다…", 10)
			if kid != null:
				vv.speak(kid, "정말요? 거인님이 진짜 있어요?", 8)
	if away_s > FESTIVAL_AWAY:
		vv.festival_t = vv.t
		var days := minf(5.0, away_s / 86400.0)
		vv.bless_all(0.06 + 0.02 * days)           # 비운 시간에 비례해 모두 크게 (RESIDENT_AI 2.2), 일주일 넘으면 식은 만큼 덜
		if vv.altar.size() < 2:
			vv.evening_offering()                  # 제단 가득 — 기쁜 마음에 남는 것을 더 바친다
		var lines := ["거인님이 돌아오셨다!", "거인님!", "돌아오셨어요!", "하늘을 봐!"]
		var i := 0
		for p in vv.people:
			if p.is_baby() or p.sick_left > 0.0:
				continue
			ResidentAI.cancel(vv, p)
			p.sleeping = false
			p.action = "festival"
			p.last_action = "festival"
			p.doing = "거인님의 귀환을 반기는 중"
			var a := float(i) * 2.399
			var spot := vv.fire + Vector2(cos(a), sin(a)) * (1.6 + 0.35 * sqrt(float(i)))
			p.steps.append(ResidentAI.walk(spot.x, spot.y))
			p.steps.append(ResidentAI.act(1200.0, "play" if p.is_child() else "pray"))
			if i < 4:
				vv.speak(p, lines[i], 8)
			crowd.append(p)
			i += 1
		vv.log_line("거인님이 돌아오셨다. 사람들은 광장에 모여 하늘을 올려다보며 환호했다.")
	else:
		var n := 0
		for p in vv.people:
			if not p.sleeping and p.age >= 2.5 and n < 3:
				vv.speak(p, ["거인님, 다시 오셨네요!", "거인님이다!", "어서 오세요, 거인님."][n], 6)
				crowd.append(p)
				n += 1
	vv._update_belief(0.0)
	return crowd
