## 자람의 보상 — 고비 (docs/PROGRESSION.md 4.5 · ROADMAP Q9 첫 묶음).
## 병마다 한 번씩: 첫 빵 · 첫걸음마 · 식구 열둘 · 마을에서 난 첫 아이가 어른이 됨 · 식구 스물 · 첫 겨울을 넘김. 고비를 넘으면 이끈 주민에게 별명이 붙고(연대기 한 줄),
## 그날 저녁 모닥불 둘레에서 잔치가 열린다(연대기 한 줄). 수첩의 도장·다음 고비 한 줄과 영구 장식(빵 간판·마을 표지판)은 이 기록을 읽기만 한다.
## 화면과 분리된 순수 로직 (ADR-0001) — 지켜보는지 여부를 읽지 않는다: 잔치는 비운 동안에도 병 시계로 열리고 지나간다 (돌아와서 다시 틀지 않음).
## 상태는 Village.milestones (저장됨, 병의 첫 정착지 것 하나):
##   {"v": 2, "passed": {id → {"t", "who", "name", "nick", "silent"}}, "winter": 지낸 겨울 날 수, "day": 마지막으로 센 병의 날,
##    "feasts": [{"id", "day"}] 기다리는 잔치, "feast": {"id", "t0", "until", "day"} 마지막(지금) 잔치,
##    "born_n": 센 출생 수, "kids": [이 마을에서 난 아이 id — 아직 어른이 아닌], "steps_call": {"baby", "at"} 첫걸음마를 보러 이웃을 부른 것}
## 옛 저장: "v"가 없으면 첫 걸음에 이미 넘은 고비를 조용히 넘은 것으로 적는다 (사건·별명·잔치 없음). "v" 1(고비 넷이던 때)이면 새 고비 둘만 같은 규칙으로.
## 첫걸음마 (Q9 ⑦): 잔치 없음 — 병의 첫 걸음마 때는 이웃을 먼저 부르고(steps_hold) STEPS_GATHER_SECS 뒤 아기가 걸음을 뗀다 (ChildPlay._care_tick → on_first_steps).
##   부르는 이웃: 문 가까이(STEPS_CLAP_R)에서 쉬던 사람 먼저, 모자라면 일하던 어른이 하던 일을 잠깐 내려놓고 (병마다 한 번뿐인 일 — 잔치에 부를 때처럼).
##   모인 이웃은 손뼉을 치고 (걸음에 "ms" 표시 — 화면이 손뼉 몸짓으로), 부모가 문 앞에 바람개비를 단다 (기록의 "b" 집 · "x","y").
## 마을에서 난 첫 아이가 어른이 됨: 태어난 아이를 적어 두었다가("kids") 나이가 AGE_ADULT를 넘으면. 키 재는 기둥 자리("x","y")를 적는다.
## 값은 data/balance.gd 맨 끝 'Q9 자람의 보상' 묶음에 있다 (2026-11-11 옮김) — 아래 이름들은 그 값을 가리킨다 (시험·도구가 Milestones.POP_SMALL로 읽음).
class_name Milestones
extends RefCounted

const VERSION := 2
const ORDER := ["bread", "steps", "pop12", "grown", "pop20", "winter"]     # 보통 넘는 차례 (2026-11-11 측정 — 도장 띠·다음 고비 한 줄의 차례)
const FEAST_RANK := ["bread", "pop12", "grown", "winter", "pop20"]         # 잔치가 있는 고비 — 뒤로 갈수록 큰 잔치 (같은 날 겹치면 뒤쪽이 먼저). 첫걸음마는 잔치가 없다
const FEAST_SMALL := ["grown"]                                # 작은 잔치 (Balance.FEAST_SMALL_SECS — 저녁 한때)
const POP_SMALL := Balance.MILESTONE_POP_SMALL                # 식구 열둘
const POP_BIG := Balance.MILESTONE_POP_BIG                    # 식구 스물
const WINTER_MIN_DAYS := Balance.MILESTONE_WINTER_MIN_DAYS    # 이만큼은 겨울을 지내야 '겨울을 넘겼다'
const FEAST_HOUR := Balance.FEAST_HOUR                        # 잔치가 시작되는 병 시각 (저녁 종 뒤)
const FEAST_LATEST := Balance.FEAST_LATEST                    # 이 뒤에 넘은 고비·못 연 잔치는 다음 날 저녁으로
const FEAST_SECS := Balance.FEAST_SECS                        # 병의 한 저녁 (18:30 → 21:00)
const FEAST_EAT := Balance.FEAST_EAT_SECS                     # 한 번 먹는 길이
const FEAST_DANCE := Balance.FEAST_DANCE_SECS                 # 한 번 춤추는 길이
const FEAST_REACH := Balance.FEAST_REACH                      # 모닥불에서 이보다 먼 사람은 부르지 않는다
const FEAST_DOING := "잔치를 즐기는 중"
const CLAP_DOING := "첫걸음마를 보러 온 중"
const PULL_ACTS := ["work", "build", "forage", "chores", "rest", "social", "play", "idle", ""]     # 첫걸음마를 보러 잠깐 내려놓아도 되는 일 (밥·잠·짐 나르기·기도·위기 대응은 그대로)

## 수첩 도장 이름 (거인 UI)
const LABEL := {"bread": "첫 빵", "steps": "첫걸음마", "pop12": "식구 열둘", "grown": "첫 어른", "pop20": "식구 스물", "winter": "첫 겨울"}
## 다음 고비 한 줄 (거인 UI — 숫자를 써도 된다)
const NEXT := {
	"bread": "첫 빵을 구우면 잔치가 열려요",
	"steps": "아기가 첫걸음마를 떼면 이웃들이 모여 손뼉을 쳐요",
	"pop12": "식구가 열둘이 되면 잔치가 열려요",
	"grown": "마을에서 난 아이가 어른이 되면 잔치가 열려요",
	"winter": "첫 겨울을 넘기면 봄맞이 잔치가 열려요",
	"pop20": "식구가 스물이 되면 큰 잔치가 열려요",
}
const NEXT_DONE := "여기까지의 고비를 모두 넘었어요"
## 별명 (이름 앞에 붙는 말 — 주민 쪽 글이라 숫자 없음)
const NICK := {"bread": "첫 빵을 구운", "steps": "바람개비를 단", "pop12": "표지판을 세운", "grown": "마을이 키운 첫 어른", "winter": "첫 겨울을 지켜 낸", "pop20": "마을을 북적이게 한"}
## 고비 연대기 줄: [이끈 주민이 있을 때 ({n} = 이름, {ga} = 이/가), 없을 때]
const LINE := {
	"bread": ["{n}{ga} 화덕 앞에 빵 간판을 걸었다.", "화덕 앞에 빵 간판이 걸렸다."],
	"steps": ["이웃들이 모여 손뼉을 쳤다. {n}{ga} 문 앞에 작은 바람개비를 달았다.", "이웃들이 모여 손뼉을 쳤다. 문 앞에 작은 바람개비가 달렸다."],
	"grown": ["이 마을에서 나고 자란 {n}{ga} 어른이 되었다. 모닥불 곁에 아이들 키를 새긴 기둥이 섰다.", "이 마을에서 나고 자란 아이가 어른이 되었다. 모닥불 곁에 아이들 키를 새긴 기둥이 섰다."],
	"pop12": ["식구가 늘어 마을이 북적인다. {n}{ga} 어귀에 마을 이름 표지판을 세웠다.", "식구가 늘어 마을이 북적인다. 어귀에 마을 이름 표지판이 섰다."],
	"winter": ["긴 겨울이 가고 봄볕이 들었다. 마을은 첫 겨울을 넘겼다.", "긴 겨울이 가고 봄볕이 들었다. 마을은 첫 겨울을 넘겼다."],
	"pop20": ["마을이 사람 소리로 가득하다. 골목마다 웃음이 들린다.", "마을이 사람 소리로 가득하다. 골목마다 웃음이 들린다."],
}
## 잔치 연대기 줄
const STEPS_ALONE_LINE := ["{n}{ga} 문 앞에 작은 바람개비를 달았다.", "문 앞에 작은 바람개비가 달렸다."]     # 첫걸음마 — 이웃이 아무도 못 왔을 때 (모두 일하는 중)
const FEAST_LINE := {
	"bread": "저녁에 작은 잔치가 열렸다. 모닥불 둘레에서 갓 구운 빵을 나누어 먹고 춤을 추었다.",
	"pop12": "저녁에 작은 잔치가 열렸다. 새 표지판 이야기로 모닥불 둘레가 밤늦도록 떠들썩했다.",
	"grown": "저녁에 작은 잔치가 열렸다. 모닥불 둘레에서 다 자란 아이의 어릴 적 이야기를 나누며 먹고 춤을 추었다.",
	"winter": "봄맞이 잔치가 열렸다. 모닥불 둘레에서 겨울 이야기를 나누며 먹고 춤을 추었다.",
	"pop20": "큰 잔치가 열렸다. 온 마을이 모닥불 둘레에 모여 먹고 노래하고 춤을 추었다.",
}
## 잔치에 부르지 않는 행동 (위기·곰팡이 대응, 앓는 중, 아기 돌봄 밖 연출)
const BUSY_PREFIX := ["crisis_", "mold_", "skywatch"]
const BUSY := ["sick", "baby", "dand_ride"]


# ───────────────────────── 한 걸음 ─────────────────────────
## Village.step에서 병의 첫 정착지만 (owns_water) 부른다.
static func step(v: Village, _dt: float) -> void:
	var m: Dictionary = v.milestones
	if not m.has("v"):
		_baseline(v)
		return
	if int(m["v"]) < VERSION:
		_upgrade(v)
	var day := v.cal_day(v.t)
	if day != int(m.get("day", 0)):
		_new_day(v, day)
	if not is_passed(v, "bread") and int(v.stats.get("first_bread", 0)) > 0:
		_pass(v, "bread")
	var pop := v.people.size()
	if pop >= POP_SMALL and not is_passed(v, "pop12"):
		_pass(v, "pop12")
	if pop >= POP_BIG and not is_passed(v, "pop20"):
		_pass(v, "pop20")
	if not is_passed(v, "grown"):
		_grown_tick(v)
	if not (m.get("feasts", []) as Array).is_empty():
		_try_feast(v, day)
	var f: Dictionary = m.get("feast", {})
	if not f.is_empty() and not bool(f.get("done", false)) and v.t >= float(f.get("until", 0.0)):
		_end_feast(v, f)


## 처음 한 번: 이미 넘은 고비는 조용히 (옛 저장 — 사건·별명·잔치 없음). 새 병은 넘은 것이 없다.
static func _baseline(v: Village) -> void:
	var m: Dictionary = v.milestones
	m["v"] = VERSION
	m["passed"] = {}
	m["feasts"] = []
	m["feast"] = {}
	var day := v.cal_day(v.t)
	m["day"] = day
	var winter := 0
	for d in mini(day - 1, 400):                     # 지나온 날의 겨울 날 수 (한 번만 셈)
		if _season_at(v, float(d) * Balance.DAY) == "겨울":
			winter += 1
	m["winter"] = winter
	if int(v.stats.get("first_bread", 0)) > 0:
		_mark_silent(v, "bread")
	if v.people.size() >= POP_SMALL:
		_mark_silent(v, "pop12")
	if v.people.size() >= POP_BIG:
		_mark_silent(v, "pop20")
	if v.t >= 365.0 * Balance.DAY or (winter >= WINTER_MIN_DAYS and _season_at(v, v.t) != "겨울"):
		_mark_silent(v, "winter")
	_baseline_born(v)


## 고비 넷이던 때의 저장 ("v" 1): 새 고비 둘(첫걸음마 · 마을에서 난 첫 어른)만 같은 규칙으로 — 이미 넘었으면 조용히
static func _upgrade(v: Village) -> void:
	v.milestones["v"] = VERSION
	_baseline_born(v)


## 이 마을에서 난 사람을 살펴 (옛 저장 — 태어난 때와 나이로 가려냄): 이미 걷는 아이·이미 어른이 된 사람이 있으면 그 고비는 조용히 넘은 것으로,
## 아직 어린 아이는 적어 둔다 ("kids" — 어른이 되는 날 고비)
static func _baseline_born(v: Village) -> void:
	var m: Dictionary = v.milestones
	m["born_n"] = int(v.stats.get("born", 0))
	var kids: Array = []
	var walked := false
	var grown := false
	var toddling: Dictionary = v.kids.get("walked", {})
	for p in v.people:
		if not born_here(v, p, v.t):
			continue
		if p.age >= Balance.AGE_ADULT:
			grown = true
		else:
			kids.append(p.id)
		if not p.is_baby() or toddling.has(str(p.id)) or p.age >= ChildPlay.TODDLE_AGE + ChildPlay.FIRST_WINDOW:
			walked = true
	for p in v.dead:
		if born_here(v, p, p.death_t):
			walked = walked or p.age >= ChildPlay.TODDLE_AGE + ChildPlay.FIRST_WINDOW
			grown = grown or p.age >= Balance.AGE_ADULT
	m["kids"] = kids
	if (walked or not toddling.is_empty()) and not is_passed(v, "steps"):
		_mark_silent(v, "steps")
	if grown and not is_passed(v, "grown"):
		_mark_silent(v, "grown")


## 이 마을에서 태어난 사람인가 — 태어난 때(born_t)부터 흐른 병 날로 셈한 나이가 지금 나이와 맞는가 (처음 온 사람·이주민은 맞지 않는다:
## 그들의 born_t는 온 날에서 나이만큼 거슬러 적은 것). 옛 저장을 처음 볼 때만 쓴다 — 그 뒤로는 태어날 때 적어 둔다 (_grown_tick)
static func born_here(v: Village, p: Resident, now: float) -> bool:
	if p.parents.size() != 2 or p.born_t <= 0.0:             # 처음 온 사람은 병이 생기기 전에 난 것으로 적혀 있다
		return false
	var e := (now - p.born_t) / Balance.DAY
	if e < 0.0:
		return false
	var child_days := Balance.AGE_ADULT * Balance.AGE_K
	var want := e / Balance.AGE_K if e <= child_days else Balance.AGE_ADULT + (e - child_days) / Balance.AGE_K_ADULT
	return absf(p.age - want) < Balance.BORN_HERE_TOL


## 마을에서 난 아이를 적어 두고 (출생 수가 늘 때 — 갓난 아기), 그 가운데 처음 어른이 된 아이가 고비
static func _grown_tick(v: Village) -> void:
	var m: Dictionary = v.milestones
	var born := int(v.stats.get("born", 0))
	var kids: Array = m.get("kids", [])
	m["kids"] = kids
	var more := born - int(m.get("born_n", 0))
	m["born_n"] = born
	if more > 0:
		var fresh: Array = []
		for p in v.people:
			if p.age < Balance.NEWBORN_AGE and p.parents.size() == 2 and not kids.has(p.id):
				fresh.append(p.id)
		fresh.sort()
		for id: int in fresh.slice(maxi(fresh.size() - more, 0)):      # 가장 늦게 온 번호 = 방금 태어난 아이
			kids.append(id)
	for i in range(kids.size() - 1, -1, -1):
		var p := v.person(int(kids[i]))
		if p == null or p.dead:
			kids.remove_at(i)                         # 죽었거나 다른 무리로 떠남
	for id: int in kids:
		var p := v.person(id)
		if p.age >= Balance.AGE_ADULT:
			_pass(v, "grown", p)
			m["kids"] = []
			return


# ───────────────────────── 첫걸음마 (ChildPlay._care_tick이 부른다) ─────────────────────────
## 병의 첫 걸음마를 잠깐 미룰까 — 이웃을 먼저 부르고 STEPS_GATHER_SECS 뒤에 아기가 걸음을 뗀다. true = 아직 (아기는 기다린다).
## 고비를 이미 넘었거나, 첫 무리가 아니거나, 기록이 아직 없는 마을(첫 걸음 전)은 미루지 않는다. 지켜봄과 무관.
static func steps_hold(v: Village, b: Resident) -> bool:
	var m: Dictionary = v.milestones
	if not v.owns_water or not m.has("v") or is_passed(v, "steps"):
		return false
	var call: Dictionary = m.get("steps_call", {})
	if not call.is_empty():
		var cb := v.person(int(call.get("baby", -1)))
		var at := float(call.get("at", 0.0))
		if cb != null and not cb.dead and cb.is_baby() and v.t <= at + Balance.STEPS_GATHER_LATE:
			if cb.id != b.id:
				return true                           # 다른 아기의 첫걸음마를 기다리는 중 — 이 아기는 그 뒤에
			return v.t < at
	if v.staged() or v.in_opening():
		return true                                   # 깨달음·제단 장면이 끝난 뒤에 부른다 (그 사이 아기는 기다린다)
	var minder := ChildPlay.minder(v, b, v.people)
	if minder != null and not _free(v, minder) and b.age < ChildPlay.TODDLE_AGE + Balance.STEPS_PARENT_WAIT:
		return true                                   # 아기를 보는 사람이 밥을 먹거나 이야기 중 — 손이 날 때까지 조금 기다린다
	m["steps_call"] = {"baby": b.id, "at": v.t + Balance.STEPS_GATHER_SECS}
	_gather(v, b, minder, v.t + Balance.STEPS_GATHER_SECS)
	return true


## 아기가 걸음마를 뗐다 (ChildPlay._first_steps 바로 뒤) — 병에서 처음이면 고비
static func on_first_steps(v: Village, b: Resident) -> void:
	var m: Dictionary = v.milestones
	if not v.owns_water or not m.has("v") or is_passed(v, "steps"):
		return
	m.erase("steps_call")
	_pass(v, "steps", b)


## 지금 그 아기의 첫걸음마를 보러 문 앞에 와 선 이웃 수 (걸어오는 중인 사람은 세지 않는다)
static func clappers(v: Village, baby_id: int) -> int:
	var n := 0
	for q in v.people:
		if q.steps.is_empty():
			continue
		var s0: Dictionary = q.steps[0]
		if String(s0.get("k", "")) == "do" and int(s0.get("ms", -1)) == baby_id and not bool(s0.get("par", false)):
			n += 1
	return n


## 잠깐 불러도 되는 사람인가 — 요람 들여다보기(ChildPlay._peek)와 같은 규칙: 쉬는 사람만 (일·짐·놀이·끝에 할 일이 달린 걸음은 그대로)
static func _free(v: Village, q: Resident) -> bool:
	if q.is_baby() or q.dead or q.sleeping or q.carry != "" or q.sick_left > 0.0:
		return false
	if not ChildPlay.PEEK_ANIMS.has(q.anim) or not Social.FREE_ACTS.has(q.action) or q.action == "eat":
		return false
	var busy: Dictionary = v.social.get("busy", {})
	if float(busy.get(str(q.id), -1.0e9)) > v.t or not ChildPlay.game_of(v, q.id).is_empty():
		return false
	if not q.steps.is_empty() and ((q.steps[0] as Dictionary).has("g") or (q.steps[0] as Dictionary).get("done") != null):
		return false
	return true


## 하던 일을 잠깐 내려놓고 올 수 있는 어른인가 — 잔치에 부를 때의 규칙(can_join)에 더해: 자는 사람·밥 먹는 사람·짐 든 사람·
## 이야기 장면·놀이 속·이미 불린 사람은 그대로 둔다
static func _pullable(v: Village, q: Resident) -> bool:
	if q.is_child() or q.dead or q.sleeping or q.anim == "sleep" or q.carry != "" or not can_join(q) or not PULL_ACTS.has(q.action):
		return false
	var busy: Dictionary = v.social.get("busy", {})
	if float(busy.get(str(q.id), -1.0e9)) > v.t or not ChildPlay.game_of(v, q.id).is_empty():
		return false
	return q.steps.is_empty() or not ((q.steps[0] as Dictionary).has("ms") or (q.steps[0] as Dictionary).has("g"))


## 첫걸음마 자리를 차린다: 아기를 보는 사람(minder — 있고 손이 비었으면)은 아기를 데리고 문 앞으로, 문 가까이의 이웃은 문 앞 양옆으로 —
## 쉬던 사람 먼저, 모자라면 일하던 어른(하던 일은 내려놓는다 — 짐·예약은 되돌림). 걸어와 기다리다(when까지) 손뼉.
## 걸음에 "ms"(아기 id) 표시 — 화면이 아기 쪽을 보고 손뼉 몸짓으로 (view/milestone_view.gd).
static func _gather(v: Village, b: Resident, minder: Resident, when: float) -> void:
	var d := ChildPlay.door(v, b)
	if not v.social.has("busy"):
		v.social["busy"] = {}
	if minder != null and _free(v, minder):
		var to := d + Balance.STEPS_PARENT_SPOT
		if spot_free(v, to):
			var stay := ResidentAI.act(maxf(when - v.t, 1.0) + Balance.STEPS_CLAP_SECS, "idle", ResidentAI.op("social_done", {"was": minder.doing}), false,
				ResidentAI.op("social_done", {"was": minder.doing}))
			stay["ms"] = b.id
			stay["par"] = true
			_front(minder, [ResidentAI.walk(to.x, to.y), stay], "아기와 문 앞에 나온 중")
			v.social["busy"][str(minder.id)] = when + Balance.STEPS_CLAP_SECS
	var found: Array = []                             # [쉬던 사람 0 · 일하던 사람 1, 거리, id]
	for q in v.people:
		if q == minder or q.id == b.id:
			continue
		var rank := 0 if _free(v, q) else (1 if _pullable(v, q) else -1)
		if rank < 0:
			continue
		var dd := Vector2(q.x - d.x, q.y - d.y).length()
		if dd <= Balance.STEPS_CLAP_R:
			found.append([rank, dd, q.id])
	found.sort_custom(func(a: Array, c: Array) -> bool: return int(a[0]) < int(c[0]) if int(a[0]) != int(c[0]) else (
		float(a[1]) < float(c[1]) if float(a[1]) != float(c[1]) else int(a[2]) < int(c[2])))
	var spots: Array = []
	for off: Vector2 in Balance.STEPS_CLAP_SPOTS:
		if spot_free(v, d + off):
			spots.append(d + off)
	for i in mini(mini(found.size(), spots.size()), Balance.STEPS_CLAP_MAX):
		var q := v.person(int((found[i] as Array)[2]))
		if int((found[i] as Array)[0]) == 1:              # 일하던 사람: 하던 일을 내려놓고 온다 (손뼉이 끝나면 다시 할 일을 고른다)
			ResidentAI.cancel(v, q)
			q.action = "idle"
			q.doing = "쉬는 중"
		var to: Vector2 = spots[i]
		var walk_secs := Vector2(q.x - to.x, q.y - to.y).length() / maxf(q.walk_speed(), 1.0e-6)
		var done := ResidentAI.op("social_done", {"was": q.doing})
		var front: Array = [ResidentAI.walk(to.x, to.y)]
		var wait := when - (v.t + walk_secs)
		if wait > 1.0:
			var stand := ResidentAI.act(wait, "idle", null, false, done)
			stand["ms"] = b.id
			front.append(stand)
		var clap := ResidentAI.act(Balance.STEPS_CLAP_SECS, "play", done, false, done)
		clap["ms"] = b.id
		front.append(clap)
		_front(q, front, CLAP_DOING)
		v.social["busy"][str(q.id)] = maxf(when, v.t + walk_secs) + Balance.STEPS_CLAP_SECS


## 그 사람의 할 일 앞에 걸음을 끼워 넣는다 (하던 일은 그 뒤에 이어서)
static func _front(q: Resident, front: Array, doing: String) -> void:
	for s: Dictionary in q.steps:
		front.append(s)
	q.steps = front
	q.doing = doing


static func _mark_silent(v: Village, id: String) -> void:
	(v.milestones["passed"] as Dictionary)[id] = {"t": v.t, "who": -1, "name": "", "nick": "", "silent": true}


## 병의 날이 바뀔 때: 겨울 날 수를 세고, 겨울을 지낸 뒤 봄이 오면 고비
static func _new_day(v: Village, day: int) -> void:
	var m: Dictionary = v.milestones
	m["day"] = day
	if is_passed(v, "winter"):
		return
	var season := _season_at(v, v.t)
	if season == "겨울":
		if not v.people.is_empty():
			m["winter"] = int(m.get("winter", 0)) + 1
	elif season == "봄" and int(m.get("winter", 0)) >= WINTER_MIN_DAYS and not v.people.is_empty():
		_pass(v, "winter")


## 병 시각 tt의 철 (Health.jar_date와 같은 달력)
static func _season_at(v: Village, tt: float) -> String:
	var c: Dictionary = v.created_date
	var base := Time.get_unix_time_from_datetime_dict({"year": int(c["year"]), "month": int(c["month"]), "day": int(c["day"]), "hour": 12, "minute": 0, "second": 0})
	var days := int((v.start_clock + tt) / Balance.DAY)
	var d := Time.get_datetime_dict_from_unix_time(base + days * 86400)
	return Health.season_of(int(d["month"]))


# ───────────────────────── 고비를 넘음 ─────────────────────────
static func _pass(v: Village, id: String, lead: Resident = null) -> void:
	var m: Dictionary = v.milestones
	var cands := _leaders(v, id, lead)
	var who: Resident = null
	var nick := ""
	for c: Resident in cands:                         # 별명은 한 사람에 하나 — 이미 있으면 다음 사람에게
		if c.nickname.is_empty():
			who = c
			nick = String(NICK[id])
			c.nickname = nick
			break
	if who == null and not cands.is_empty():
		who = cands[0]
	var day := v.cal_day(v.t)
	var feast_day := -1                               # 잔치가 없는 고비(첫걸음마)는 -1
	if FEAST_RANK.has(id):
		feast_day = day if v.hour_now() < FEAST_LATEST else day + 1
	(m["passed"] as Dictionary)[id] = {"t": v.t, "who": who.id if who != null else -1, "name": who.name if who != null else "", "nick": nick, "silent": false}
	var rec: Dictionary = (m["passed"] as Dictionary)[id]
	if id == "pop12":                                 # 마을 이름 표지판 자리 (어귀) — 화면이 읽기만 한다
		var sp := edge_spot(v)
		rec["x"] = sp.x
		rec["y"] = sp.y
	elif id == "grown":                               # 키 재는 기둥 자리 (모닥불 곁)
		var sp := post_spot(v)
		rec["x"] = sp.x
		rec["y"] = sp.y
	elif id == "steps" and lead != null:              # 바람개비: 그 아기네 집 문 앞 (집이 없으면 모닥불 곁) — 집 번호와 그때의 자리
		var hm := v.bld(lead.home)
		rec["b"] = hm.id if hm != null else -1
		rec["baby"] = lead.id
		rec["x"] = hm.x if hm != null else v.fire.x
		rec["y"] = (hm.y + hm.size() * 0.5) if hm != null else v.fire.y + 0.6
	if feast_day >= 0:
		(m["feasts"] as Array).append({"id": id, "day": feast_day})
	var pair: Array = LINE[id]
	if id == "steps":
		rec["n"] = clappers(v, lead.id) if lead != null else 0     # 보러 온 이웃 수 — 아무도 못 왔으면 손뼉 이야기는 뺀다
		if int(rec["n"]) == 0:
			pair = STEPS_ALONE_LINE
	var text := String(pair[1])
	if who != null:
		text = String(pair[0]).replace("{n}", who.name).replace("{ga}", Village.josa(who.name, "이", "가"))
		if not nick.is_empty():
			text += " 사람들은 이제 '%s'%s 부른다." % [title_of(who), Village.josa(who.name, "이라", "라")]
	v.log_line(text)
	v.emit(&"milestone", {"who": who.id if who != null else -1, "at": _spot(v, id, lead), "v": {"id": id, "nick": nick, "feast_day": feast_day}})


## 이끈 주민 후보 (앞에서부터 — 별명이 이미 있으면 다음 후보)
## lead = 그 고비의 주인공 (첫걸음마 = 아기, 어른이 됨 = 그 젊은이)
static func _leaders(v: Village, id: String, lead: Resident = null) -> Array:
	var out: Array = []
	match id:
		"steps":                                          # 아기의 부모 (어머니 먼저)
			if lead != null:
				for pid in lead.parents:
					_add(out, v.person(pid))
		"grown":                                          # 그 젊은이 — 이미 별명이 있으면 별명은 없다 (다른 사람에게 가지 않는다)
			_add(out, lead)
		"bread":
			var evs := v.events.since(maxi(v.events.serial - 256, 0))
			for i in range(evs.size() - 1, -1, -1):          # 방금 난 first_bread 사건의 주민
				var e: Dictionary = evs[i]
				if e["kind"] == &"first_bread" and int(e["village"]) == v.sid:
					_add(out, v.person(int(e["who"])))
					break
			for p in v.people:                                # 화덕·빵집에서 일하는 사람
				var b := v.bld(p.job) if p.job >= 0 else null
				if b != null and (b.type == "화덕" or b.type == "빵집"):
					_add(out, p)
			_add(out, v.chief())
		"pop12", "pop20":
			var ids: Array = []
			for p in v.people:
				ids.append(p.id)
			ids.sort()
			for i in range(ids.size() - 1, -1, -1):           # 가장 늦게 온 식구부터: 태어난 아이 → 부모, 이주민 → 그 사람
				var p := v.person(int(ids[i]))
				if p == null:
					continue
				if not p.parents.is_empty():
					var found := false
					for pid in p.parents:
						var par := v.person(pid)
						if par != null and not par.dead:
							_add(out, par)
							found = true
					if found:
						break
				elif not p.is_child():
					_add(out, p)
					break
			_add(out, v.chief())
		"winter":
			var adults: Array = []
			for p in v.people:
				if p.age >= Balance.AGE_ADULT:
					adults.append(p)
			adults.sort_custom(func(a: Resident, b: Resident) -> bool: return a.age > b.age if a.age != b.age else a.id < b.id)
			for p: Resident in adults.slice(0, 3):            # 가장 나이 많은 어른부터
				_add(out, p)
	return out


static func _add(out: Array, r: Resident) -> void:
	if r != null and not r.dead and not out.has(r):
		out.append(r)


## 사건 자리: 첫 빵 = 화덕, 첫걸음마 = 그 집 문 앞, 나머지 = 모닥불
static func _spot(v: Village, id: String, lead: Resident = null) -> Vector2:
	if id == "bread":
		var b := oven(v)
		if b != null:
			return Vector2(b.x, b.y)
	if id == "steps" and lead != null:
		return ChildPlay.door(v, lead)
	return v.fire


## 키 재는 기둥 자리: 모닥불 곁 (잔치 둘레 바로 밖), 정한 방향부터 좌우로 벌려 가며 찾은 첫 빈자리 (난수 없음). 광장 안이라 길·광장은 가리지 않는다.
static func post_spot(v: Village) -> Vector2:
	for rr: float in Balance.POST_RINGS:
		for i in Balance.POST_TURNS:
			var side := 1.0 if i % 2 == 1 else -1.0
			var a := deg_to_rad(Balance.POST_START_DEG + side * float((i + 1) / 2) * Balance.POST_TURN_DEG)
			var p := v.fire + Vector2(cos(a), sin(a)) * rr
			if post_ok(v, p):
				return p
	return v.fire + Vector2(cos(deg_to_rad(Balance.POST_START_DEG)), sin(deg_to_rad(Balance.POST_START_DEG))) * float(Balance.POST_RINGS[0])


## 기둥이 설 수 있나 — 물·건물·무덤(spot_free)·제단·하늘의 것·큰 줄기가 아님. 읽기만 한다
static func post_ok(v: Village, p: Vector2) -> bool:
	if not spot_free(v, p) or p.distance_to(v.altar_pos) < Village.ALTAR_CLEAR + 0.5:
		return false
	if SkyDrops.blocks(v, p.x, p.y, 0.5) or (v.flora != null and v.flora.blocks(p.x, p.y, 0.5)):
		return false
	return not (GreatTrees.blocks(v.water, p.x, p.y, 0.5) or GiantPlants.blocks(v.water, p.x, p.y, 0.5))


## 다 지은 화덕 (없으면 빵집) — 빵 간판 자리
static func oven(v: Village) -> Building:
	var bakery: Building = null
	for b in v.buildings:
		if not b.built:
			continue
		if b.type == "화덕":
			return b
		if b.type == "빵집" and bakery == null:
			bakery = b
	return bakery


## 마을 어귀: 아래쪽(+y)부터 좌우로 벌려 가며, '그 방향'의 가장 바깥 건물 바로 밖에서부터 찾은 첫 깨끗한 자리 (난수 없음 — 같은 병이면 늘 같은 자리).
## (Q9 ⑦ 2026-11-11: 예전에는 온 마을에서 가장 먼 건물의 거리를 모든 방향에 썼다 — 표지판이 마을에서 외따로 떨어졌다. 이미 적힌 자리는 그대로.)
## 깨끗한 자리(spot_clear: 꽃·바위·길·광장·건물·무덤·물이 아님)가 없으면 꽃만 피한 자리(spot_open), 그것도 없으면 설 수만 있는 자리(spot_free).
static func edge_spot(v: Village) -> Vector2:
	var rad := Balance.SIGN_MIN_R                     # 온 마을의 바깥 둘레 (꽃숲 덩이를 미리 추리는 데만 쓴다)
	var edges: Array = []                             # 건물마다 [모닥불에서 본 방향, 바깥 끝까지의 거리, 모닥불을 덮는가]
	for b in v.buildings:
		var off := Vector2(b.x, b.y) - v.fire
		var out := off.length() + b.size() + Balance.SIGN_CLEAR_BUILDING + Balance.SIGN_RING_STEP * 0.5
		edges.append([off.angle(), out, off.length() < b.size() + 0.5])
		rad = maxf(rad, out)
	var starts: Array = []                            # 방향(돌림 번호)마다 찾기 시작하는 거리
	for i in Balance.SIGN_TURNS:
		var a := _sign_angle(i)
		var r0 := Balance.SIGN_MIN_R
		for e: Array in edges:
			if bool(e[2]) or absf(angle_difference(a, float(e[0]))) <= deg_to_rad(Balance.SIGN_SECTOR_DEG):
				r0 = maxf(r0, float(e[1]))
		starts.append(r0)
	var reach := rad + float(Balance.SIGN_RINGS) * Balance.SIGN_RING_STEP + Balance.SIGN_CLEAR_FLOWER
	var near: Array = []                              # 둘레의 꽃숲 덩이만 미리 추림 (넓은 세상은 나무가 수백 그루)
	for tr: Dictionary in v.trees:
		var q := Vector2(float(tr["x"]), float(tr["y"]))
		if q.distance_to(v.fire) < reach:
			near.append(q)
	var open := Vector2.INF
	var bare := Vector2.INF
	for ring in Balance.SIGN_RINGS:
		for i in Balance.SIGN_TURNS:
			var a := _sign_angle(i)
			var p := v.fire + Vector2(cos(a), sin(a)) * (float(starts[i]) + float(ring) * Balance.SIGN_RING_STEP)
			if not spot_free(v, p):
				continue
			if bare.x > 1.0e8:
				bare = p
			if not spot_open(v, p, near):
				continue
			if open.x > 1.0e8:
				open = p
			if spot_clear(v, p, near):
				return p
	if open.x < 1.0e8:
		return open
	return bare if bare.x < 1.0e8 else v.fire + Vector2(0.0, float(starts[0]))


## 표지판 자리를 찾는 방향: 아래쪽(+y, 화면의 앞)부터 좌우로 번갈아 벌린다
static func _sign_angle(i: int) -> float:
	var side := 1.0 if i % 2 == 1 else -1.0
	return PI * 0.5 + side * float((i + 1) / 2) * deg_to_rad(Balance.SIGN_TURN_DEG)


## 그 자리에 장식이 설 수 있나 (물·세상 끝·건물·무덤이 아님)
static func spot_free(v: Village, p: Vector2) -> bool:
	if v.water == null or not v.water.inside(p.x, p.y, 1.5) or v.water_at(p.x, p.y):
		return false
	for b in v.buildings:
		if Vector2(b.x, b.y).distance_to(p) < b.size() + Balance.SIGN_CLEAR_BUILDING:
			return false
	for g: Dictionary in v.graves:
		if Vector2(float(g["x"]), float(g["y"])).distance_to(p) < Balance.SIGN_CLEAR_GRAVE:
			return false
	return true


## 꽃 속이 아닌가 — 꽃숲 덩이(시뮬레이션 나무: 선 것·벤 자리·싹)와 바위에서 떨어진 자리.
## flowers = 미리 추린 나무 자리 (없으면 마을의 나무 전부를 본다)
static func spot_open(v: Village, p: Vector2, flowers: Variant = null) -> bool:
	if flowers == null:
		for tr: Dictionary in v.trees:
			if Vector2(float(tr["x"]), float(tr["y"])).distance_to(p) < Balance.SIGN_CLEAR_FLOWER:
				return false
	else:
		for q: Vector2 in flowers:
			if q.distance_to(p) < Balance.SIGN_CLEAR_FLOWER:
				return false
	for r: Dictionary in v.rocks:
		if Vector2(float(r["x"]), float(r["y"])).distance_to(p) < Balance.SIGN_CLEAR_ROCK:
			return false
	return true


## 깨끗한 자리인가 — 설 수 있고(spot_free) 꽃 속이 아니며(spot_open), 발길 난 칸(오솔길·흙길)·광장과 큰길·모닥불·제단 자리·
## 하늘의 것(큰 버섯·하늘에서 온 물건)·큰 나무와 해바라기 줄기 둘레도 아님. 읽기만 한다 (난수·상태 변화 없음)
static func spot_clear(v: Village, p: Vector2, flowers: Variant = null) -> bool:
	if not spot_free(v, p) or not spot_open(v, p, flowers):
		return false
	var c := Balance.SIGN_CLEAR_PATH
	for d: Vector2 in [Vector2.ZERO, Vector2(c, 0.0), Vector2(-c, 0.0), Vector2(0.0, c), Vector2(0.0, -c)]:
		if v.path_at(p.x + d.x, p.y + d.y) >= Balance.SIGN_PATH_MIN or v.water_at(p.x + d.x, p.y + d.y):
			return false
	if p.distance_to(v.fire) < 2.0 or p.distance_to(v.altar_pos) < Village.ALTAR_CLEAR + 0.5:
		return false
	if VillagePlan.blocks(v, p.x, p.y, 0.5) or SkyDrops.blocks(v, p.x, p.y, 0.5):
		return false
	if v.flora != null and v.flora.blocks(p.x, p.y, 0.5):
		return false
	if GreatTrees.blocks(v.water, p.x, p.y, 0.5) or GiantPlants.blocks(v.water, p.x, p.y, 0.5):
		return false
	return true


# ───────────────────────── 잔치 ─────────────────────────
## 저녁(FEAST_HOUR~FEAST_LATEST)에 기다리는 잔치 가운데 가장 큰 것 하나 — 나머지와 못 연 잔치는 다음 날 저녁
static func _try_feast(v: Village, day: int) -> void:
	var m: Dictionary = v.milestones
	var h := v.hour_now()
	if h < FEAST_HOUR or h > FEAST_LATEST or v.staged() or v.people.is_empty():
		return
	if int((m.get("feast", {}) as Dictionary).get("day", -1)) == day:
		return                                        # 오늘 잔치는 이미 열렸다
	var q: Array = m["feasts"]
	var best := -1
	for i in q.size():
		var f: Dictionary = q[i]
		if int(f["day"]) > day:
			continue
		if best < 0 or FEAST_RANK.find(String(f["id"])) > FEAST_RANK.find(String((q[best] as Dictionary)["id"])):
			best = i
	if best < 0:
		return
	var id := String((q[best] as Dictionary)["id"])
	q.remove_at(best)
	for f: Dictionary in q:
		if int(f["day"]) <= day:
			f["day"] = day + 1
	_feast(v, id, day)


static func _feast(v: Village, id: String, day: int) -> void:
	var secs_all := Balance.FEAST_SMALL_SECS if FEAST_SMALL.has(id) else FEAST_SECS     # 작은 잔치는 일찍 끝난다
	var until := v.t + secs_all
	v.milestones["feast"] = {"id": id, "t0": v.t, "until": until, "day": day}
	var i := 0
	for p in v.people:
		if not can_join(p):
			continue
		if Vector2(p.x, p.y).distance_to(v.fire) > FEAST_REACH:
			continue
		ResidentAI.cancel(v, p)
		p.sleeping = false
		p.action = "festival"
		p.last_action = "festival"
		p.doing = FEAST_DOING
		var a := float(i) * Balance.FEAST_RING_TURN
		var spot := v.fire + Vector2(cos(a), sin(a)) * (Balance.FEAST_RING_R + Balance.FEAST_RING_GROW * sqrt(float(i)))
		p.steps.append(ResidentAI.walk(spot.x, spot.y))
		var left := secs_all - Balance.FEAST_WALK_SECS     # 걸어오는 몫을 빼고, 먹고 춤추기를 번갈아
		var eat := (i % 2 == 0) and not p.is_child()
		while left > 0.0:
			var secs := minf(left, FEAST_EAT if eat else FEAST_DANCE)
			p.steps.append(ResidentAI.act(secs, "eat" if eat else "play"))
			left -= secs
			eat = not eat
		i += 1
	v.log_line(String(FEAST_LINE[id]))
	var rec: Dictionary = (v.milestones["passed"] as Dictionary).get(id, {})
	v.emit(&"feast", {"who": int(rec.get("who", -1)), "at": v.fire, "v": {"id": id, "until": until, "n": i}})


## 잔치는 병의 한 저녁 — 끝나는 때에 아직 남아 있는 사람(늦게 닿은 사람)을 놓아 준다. 한 번만
static func _end_feast(v: Village, f: Dictionary) -> void:
	f["done"] = true
	for p in v.people:
		if p.action == "festival" and p.doing == FEAST_DOING and not p.steps.is_empty():
			ResidentAI.cancel(v, p)


static func can_join(p: Resident) -> bool:
	if p.dead or p.is_baby() or p.sick_left > 0.0 or BUSY.has(p.action):
		return false
	for pre: String in BUSY_PREFIX:
		if p.action.begins_with(pre):
			return false
	return true


# ───────────────────────── 읽기 (화면·수첩·시험) ─────────────────────────
static func is_passed(v: Village, id: String) -> bool:
	return (v.milestones.get("passed", {}) as Dictionary).has(id)


## 넘은 고비 수 (수첩이 다시 그릴 때를 아는 데)
static func count(v: Village) -> int:
	return (v.milestones.get("passed", {}) as Dictionary).size()


## 지금 잔치 중인가 (모닥불이 커지고 사람들이 춤춘다)
static func feast_on(v: Village) -> bool:
	var f: Dictionary = v.milestones.get("feast", {})
	return not f.is_empty() and v.t >= float(f.get("t0", 0.0)) and v.t < float(f.get("until", 0.0))


static func feast_id(v: Village) -> String:
	return String((v.milestones.get("feast", {}) as Dictionary).get("id", "")) if feast_on(v) else ""


## 수첩의 도장 줄: [{"id", "label", "passed"}] (ORDER 순)
static func stamps(v: Village) -> Array:
	var out: Array = []
	for id: String in ORDER:
		out.append({"id": id, "label": String(LABEL[id]), "passed": is_passed(v, id)})
	return out


## 다음 고비 한 줄 (거인 UI)
static func next_line(v: Village) -> String:
	for id: String in ORDER:
		if not is_passed(v, id):
			return String(NEXT[id])
	return NEXT_DONE


## "첫 빵을 구운 ○○" — 별명이 없으면 ""
static func title_of(r: Resident) -> String:
	return "" if r == null or r.nickname.is_empty() else "%s %s" % [r.nickname, r.name]


## 병의 고비 기록을 가진 마을 (첫 정착지)
static func owner(villages: Array) -> Village:
	for q: Village in villages:
		if q.owns_water:
			return q
	return villages[0] if not villages.is_empty() else null
