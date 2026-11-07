## 비운 시간 따라잡기 — docs/SAVE.md 3 (v1.1 등불) · 3.1 · 기획서 14장 · 6.6.
## 병은 거인이 없어도 ×1로 흐르지만 **거인의 등불이 타는 동안만** (Market.lamp_seconds — 12시간, 업그레이드로 16·20·24시간).
## 그보다 오래 비우면 나머지는 잠든 시간 (병 시간이 멈춤 — 계절만 현실 달력대로 바뀐다), 연대기에 "긴 밤이 있었다." 한 줄.
## 그래서 따라잡기는 언제나 정밀 계산 (10초 걸음, 물 300초 간격 — 화면 없이 최대 속도, 최대 24시간치).
## 비운 동안 거인은 보고 있지 않다 (Village.watching = false): 위기 사망 하루 1명·부부 2쌍 아래로는 없음, 시대 점수 30%,
## 새 위기(곰팡이)는 조짐에서 기다림 — Village·Mold가 지킨다. 그동안 바친 제물은 이틀 상한 없이 쌓인다 (Village.altar_hold, SAVE.md 3.1).
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
var exact_total := 0.0                # 병이 흐르는 시간 = min(비운 시간, 등불)
var exact_left := 0.0
var slept := 0.0                      # 등불이 꺼진 뒤 잠든 시간
var real_ms := 0.0                    # 실제로 걸린 계산 시간
var before: Dictionary = {}
var world: JarWorld = null            # 넓은 세상이면 그 세상 (모든 무리가 함께)
var befores: Dictionary = {}          # (넓은 세상) 무리 sid → snapshot
var n_before := 1                     # (넓은 세상) 비우기 전 무리 수
var _water_offline := false
var _done := false


## 비운 시간을 나눈다 → {exact 흐르는 시간, slept 잠든 시간} (초)
static func plan(elapsed: float, lamp_s: float) -> Dictionary:
	var e := maxf(0.0, elapsed)
	return {"exact": minf(e, lamp_s), "slept": maxf(0.0, e - lamp_s)}


## 기기 시각으로 비운 시간: 뒤로 갔으면 0 (시각 조작), 앞으로 크게 간 것은 그냥 오래 비운 것 — 등불 상한까지만 흐른다 (SAVE.md 3)
static func elapsed_since(last_unix: float, now_unix: float) -> float:
	if last_unix <= 0.0 or now_unix <= last_unix:
		return 0.0
	return now_unix - last_unix


## lamp_s < 0 = 거인의 지금 등불 (Market.lamp_seconds). 시험은 다른 값을 줄 수 있다
func _init(village: Village, elapsed: float, lamp_s := -1.0, jw: JarWorld = null) -> void:
	v = village
	world = jw
	away = maxf(0.0, elapsed)
	lamp = Market.lamp_seconds() if lamp_s < 0.0 else lamp_s
	var p := plan(away, lamp)
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


## 모든 무리: 거인이 보고 있지 않다 · 바친 제물은 상한 없이 쌓인다
func _leave_all() -> void:
	for q: Village in group():
		q.watching = false
		q.altar_hold = true


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
	real_ms += (Time.get_ticks_usec() - t0) / 1000.0
	return is_done()


## 따라잡기 끝 — 거인이 다시 본다. 편지 내용을 돌려준다 (letter())
func finish() -> Dictionary:
	if not _done:
		_done = true
		run()
		v.water.offline = _water_offline
		for q: Village in group():
			q.watching = true
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
			extra.append("젊은 부부들이 새 땅으로 떠나 '%s'%s 세웠어요 (%d명)." % [nm, Village.josa(nm, "을", "를"), q.people.size()])
			continue
		var ql := letter(q, befores[q.sid], away)
		var b0 := int(befores[q.sid]["pop"])
		var top := ""
		for e: String in ql["events"]:
			if not e in ["다들 거인님을 기다리며 하루하루 잘 지냈어요.", "아이들이 들판에서 뛰어놀았어요.", "밤마다 모닥불 앞에 모여 노래했어요.", "다들 맡은 일을 부지런히 했어요."]:
				top = e
				break
		if top == "":
			top = "모두 잘 지냈어요."
		extra.append("%s (%d명 → %d명): %s" % [nm, b0, q.people.size(), top])
		if not (ql["altar_line"] as String).is_empty():
			(l["waiting"] as Array).append("%s 제단에도 제물이 있어요." % nm)
		if q.open_letters("split").size() > 0:
			(l["waiting"] as Array).append("%s에서도 새 땅으로 떠나고 싶다는 편지가 와 있어요." % nm)
		if q.revelation_pending():
			(l["waiting"] as Array).append("%s에서도 거인님의 계시를 기다려요." % nm)
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


## 촌장이 쓰는 편지 — {chief, away, pop0, pop1, events[3~5], born[id], lost[{id, name, why}], waiting[줄], festival, long,
##   altar_line 제단 줄 ("" = 빈 제단), offerings {물건: 개수}, offer_value 장터 값 (지폐)} + finish()가 lamp_h·slept를 더한다
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
		var lb := Balance.label(ty)
		events.append(("%s%s 다 지었어요." % [lb, Village.josa(lb, "을", "를")]) if n == 1 else ("%s %d채를 새로 지었어요." % [lb, n]))
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
		waiting.append("소원 편지 %d통이 거인님을 기다려요." % wishes)
	if vv.open_letters("split").size() > 0:
		waiting.append("새 땅으로 떠나고 싶다는 편지가 와 있어요.")
	if vv.revelation_pending():           # A5: 계시는 거인만 내린다 — 비운 동안 시대 점수가 찼으면 기다림 (GD 14)
		waiting.append("노인들이 하늘을 올려다보며 거인님의 계시를 기다려요.")
	if vv.mold != null and vv.mold.phase == "omen":
		waiting.append("유리에 김이 서리기 시작했어요. 빵에 푸른 털이 났어요.")
	if vv.smalls != null:                 # [작은 위기] 조짐에서 기다리는 것 (물방울·날벌레·먼지)
		waiting.append_array(vv.smalls.waiting_lines())
	var c := vv.chief()
	return {"chief": c.name if c != null else "", "chief_id": c.id if c != null else -1, "away": away_s,
		"pop0": int(b["pop"]), "pop1": vv.people.size(), "events": events.slice(0, 5), "born": born, "lost": lost,
		"waiting": waiting, "festival": away_s > FESTIVAL_AWAY, "long": away_s >= LONG_AWAY,
		"altar_line": altar_line, "offerings": alt, "offer_value": value}


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
