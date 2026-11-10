## 자람의 보상 — 고비 (docs/PROGRESSION.md 4.5 · ROADMAP Q9 첫 묶음).
## 병마다 한 번씩: 첫 빵 · 식구 열둘 · 첫 겨울을 넘김 · 식구 스물. 고비를 넘으면 이끈 주민에게 별명이 붙고(연대기 한 줄),
## 그날 저녁 모닥불 둘레에서 잔치가 열린다(연대기 한 줄). 수첩의 도장·다음 고비 한 줄과 영구 장식(빵 간판·마을 표지판)은 이 기록을 읽기만 한다.
## 화면과 분리된 순수 로직 (ADR-0001) — 지켜보는지 여부를 읽지 않는다: 잔치는 비운 동안에도 병 시계로 열리고 지나간다 (돌아와서 다시 틀지 않음).
## 상태는 Village.milestones (저장됨, 병의 첫 정착지 것 하나):
##   {"v": 1, "passed": {id → {"t", "who", "name", "nick", "silent"}}, "winter": 지낸 겨울 날 수, "day": 마지막으로 센 병의 날,
##    "feasts": [{"id", "day"}] 기다리는 잔치, "feast": {"id", "t0", "until", "day"} 마지막(지금) 잔치}
## 옛 저장: "v"가 없으면 첫 걸음에 이미 넘은 고비를 조용히 넘은 것으로 적는다 (사건·별명·잔치 없음).
## 값은 BALANCE 표에 옮길 후보 (다른 작업이 data/balance.gd를 고치는 중이라 여기에 둠).
class_name Milestones
extends RefCounted

const ORDER := ["bread", "pop12", "winter", "pop20"]     # 뒤로 갈수록 큰 고비 (같은 날 겹치면 뒤쪽 잔치가 먼저)
const POP_SMALL := 12                 # 식구 열둘
const POP_BIG := 20                   # 식구 스물
const WINTER_MIN_DAYS := 14           # 이만큼은 겨울을 지내야 '겨울을 넘겼다' (늦겨울에 시작한 병은 다음 겨울에)
const FEAST_HOUR := 18.5              # 잔치가 시작되는 병 시각 (저녁 종 뒤)
const FEAST_LATEST := 20.0            # 이 뒤에 넘은 고비·못 연 잔치는 다음 날 저녁으로
const FEAST_SECS := 2.5 * 3600.0      # 병의 한 저녁 (18:30 → 21:00)
const FEAST_EAT := 1200.0             # 한 번 먹는 길이
const FEAST_DANCE := 1500.0           # 한 번 춤추는 길이
const FEAST_REACH := 24.0             # 모닥불에서 이보다 먼 사람(안개 너머를 살피는 중 등)은 부르지 않는다 — 저녁 안에 못 온다
const FEAST_DOING := "잔치를 즐기는 중"

## 수첩 도장 이름 (거인 UI)
const LABEL := {"bread": "첫 빵", "pop12": "식구 열둘", "winter": "첫 겨울", "pop20": "식구 스물"}
## 다음 고비 한 줄 (거인 UI — 숫자를 써도 된다)
const NEXT := {
	"bread": "첫 빵을 구우면 잔치가 열려요",
	"pop12": "식구가 열둘이 되면 잔치가 열려요",
	"winter": "첫 겨울을 넘기면 봄맞이 잔치가 열려요",
	"pop20": "식구가 스물이 되면 큰 잔치가 열려요",
}
const NEXT_DONE := "여기까지의 고비를 모두 넘었어요"
## 별명 (이름 앞에 붙는 말 — 주민 쪽 글이라 숫자 없음)
const NICK := {"bread": "첫 빵을 구운", "pop12": "표지판을 세운", "winter": "첫 겨울을 지켜 낸", "pop20": "마을을 북적이게 한"}
## 고비 연대기 줄: [이끈 주민이 있을 때 ({n} = 이름, {ga} = 이/가), 없을 때]
const LINE := {
	"bread": ["{n}{ga} 화덕 앞에 빵 간판을 걸었다.", "화덕 앞에 빵 간판이 걸렸다."],
	"pop12": ["식구가 늘어 마을이 북적인다. {n}{ga} 어귀에 마을 이름 표지판을 세웠다.", "식구가 늘어 마을이 북적인다. 어귀에 마을 이름 표지판이 섰다."],
	"winter": ["긴 겨울이 가고 봄볕이 들었다. 마을은 첫 겨울을 넘겼다.", "긴 겨울이 가고 봄볕이 들었다. 마을은 첫 겨울을 넘겼다."],
	"pop20": ["마을이 사람 소리로 가득하다. 골목마다 웃음이 들린다.", "마을이 사람 소리로 가득하다. 골목마다 웃음이 들린다."],
}
## 잔치 연대기 줄
const FEAST_LINE := {
	"bread": "저녁에 작은 잔치가 열렸다. 모닥불 둘레에서 갓 구운 빵을 나누어 먹고 춤을 추었다.",
	"pop12": "저녁에 작은 잔치가 열렸다. 새 표지판 이야기로 모닥불 둘레가 밤늦도록 떠들썩했다.",
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
	if not (m.get("feasts", []) as Array).is_empty():
		_try_feast(v, day)
	var f: Dictionary = m.get("feast", {})
	if not f.is_empty() and not bool(f.get("done", false)) and v.t >= float(f.get("until", 0.0)):
		_end_feast(v, f)


## 처음 한 번: 이미 넘은 고비는 조용히 (옛 저장 — 사건·별명·잔치 없음). 새 병은 넘은 것이 없다.
static func _baseline(v: Village) -> void:
	var m: Dictionary = v.milestones
	m["v"] = 1
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
static func _pass(v: Village, id: String) -> void:
	var m: Dictionary = v.milestones
	var cands := _leaders(v, id)
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
	var feast_day := day if v.hour_now() < FEAST_LATEST else day + 1
	(m["passed"] as Dictionary)[id] = {"t": v.t, "who": who.id if who != null else -1, "name": who.name if who != null else "", "nick": nick, "silent": false}
	if id == "pop12":                                 # 마을 이름 표지판 자리 (어귀) — 화면이 읽기만 한다
		var sp := edge_spot(v)
		var rec: Dictionary = (m["passed"] as Dictionary)[id]
		rec["x"] = sp.x
		rec["y"] = sp.y
	(m["feasts"] as Array).append({"id": id, "day": feast_day})
	var pair: Array = LINE[id]
	var text := String(pair[1])
	if who != null:
		text = String(pair[0]).replace("{n}", who.name).replace("{ga}", Village.josa(who.name, "이", "가"))
		if not nick.is_empty():
			text += " 사람들은 이제 '%s'%s 부른다." % [title_of(who), Village.josa(who.name, "이라", "라")]
	v.log_line(text)
	v.emit(&"milestone", {"who": who.id if who != null else -1, "at": _spot(v, id), "v": {"id": id, "nick": nick, "feast_day": feast_day}})


## 이끈 주민 후보 (앞에서부터 — 별명이 이미 있으면 다음 후보)
static func _leaders(v: Village, id: String) -> Array:
	var out: Array = []
	match id:
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


## 사건 자리: 첫 빵 = 화덕, 나머지 = 모닥불
static func _spot(v: Village, id: String) -> Vector2:
	if id == "bread":
		var b := oven(v)
		if b != null:
			return Vector2(b.x, b.y)
	return v.fire


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


## 마을 어귀: 모닥불에서 가장 먼 건물 바로 바깥 둘레에서, 아래쪽(+y)부터 좌우로 벌려 가며 찾은 첫 빈자리 (난수 없음)
static func edge_spot(v: Village) -> Vector2:
	var rad := 4.0
	for b in v.buildings:
		rad = maxf(rad, Vector2(b.x, b.y).distance_to(v.fire) + b.size() + 1.0)
	for ring in 4:
		var rr := rad + float(ring)
		for i in 15:
			var side := 1.0 if i % 2 == 1 else -1.0
			var a := PI * 0.5 + side * float((i + 1) / 2) * deg_to_rad(24.0)
			var p := v.fire + Vector2(cos(a), sin(a)) * rr
			if spot_free(v, p):
				return p
	return v.fire + Vector2(0.0, rad)


## 그 자리에 장식이 설 수 있나 (물·세상 끝·건물·무덤이 아님)
static func spot_free(v: Village, p: Vector2) -> bool:
	if v.water == null or not v.water.inside(p.x, p.y, 1.5) or v.water_at(p.x, p.y):
		return false
	for b in v.buildings:
		if Vector2(b.x, b.y).distance_to(p) < b.size() + 0.9:
			return false
	for g: Dictionary in v.graves:
		if Vector2(float(g["x"]), float(g["y"])).distance_to(p) < 1.0:
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
		if best < 0 or ORDER.find(String(f["id"])) > ORDER.find(String((q[best] as Dictionary)["id"])):
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
	var until := v.t + FEAST_SECS
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
		var a := float(i) * 2.399
		var spot := v.fire + Vector2(cos(a), sin(a)) * (1.6 + 0.35 * sqrt(float(i)))
		p.steps.append(ResidentAI.walk(spot.x, spot.y))
		var left := FEAST_SECS - 600.0                 # 걸어오는 몫을 빼고, 먹고 춤추기를 번갈아
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
