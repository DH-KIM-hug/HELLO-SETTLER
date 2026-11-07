## 연대기 화면(UI 07 — view/ui/chronicle_sheet.gd)이 읽는 것 — 화면 없이 시험할 수 있게 여기 모은다.
## 최근: 연대기 줄을 최신부터, 병 달력의 날(n일차)마다 묶음 (넓은 세상은 무리 이름을 붙여 모든 무리를 합침) ·
## 창세 신화: Village.myth → 창조 오프닝의 신화(WorldWater.creation["myth"] — OPENING 9) → 없으면 연대기의 첫 기록(도착한 때) ·
## 사람들: 살아 있음 · 잠듦 · 분가로 떠남 (UI 07). 발견 도감은 sim/codex.gd.
class_name Chronicle
extends RefCounted

const MYTH_T := 60.0                  # 연대기의 이 시각(병 초)까지 쓰인 줄 = 첫 기록 (도착하던 때)


## 최근 — [{day, entries: [{t, text, where}]}] 최신 날부터, 날 안에서도 최신 줄부터. limit = 줄 수 상한 (오래된 줄은 '더 보기')
static func recent(villages: Array, limit := 200) -> Array:
	var all: Array = []
	var many := villages.size() > 1
	for q: Village in villages:
		var b := q.book
		var from := maxi(0, b.size() - limit)
		for i in range(from, b.size()):
			var e: Dictionary = b[i]
			all.append({"t": float(e["t"]), "text": String(e["text"]), "where": q.settlement_name if many else "", "day": q.cal_day(float(e["t"])), "i": i,
				"card": String(e.get("card", "")), "pic": String(e.get("pic", ""))})     # (E1-0) 사건 연출의 그림 카드
	all.sort_custom(func(a: Dictionary, c: Dictionary) -> bool:
		return a["t"] > c["t"] if a["t"] != c["t"] else a["i"] > c["i"])
	all = all.slice(0, limit)
	var groups: Array = []
	for e: Dictionary in all:
		if groups.is_empty() or int(groups[-1]["day"]) != int(e["day"]):
			groups.append({"day": int(e["day"]), "entries": []})
		(groups[-1]["entries"] as Array).append(e)
	return groups


## 모든 무리의 연대기 줄 수 (넓은 세상)
static func line_count(villages: Array) -> int:
	var n := 0
	for q: Village in villages:
		n += q.book.size()
	return n


## 창세 신화 — 창조가 적은 신화가 있으면 그것, 없으면 첫 무리 연대기의 첫 기록 (도착하던 때). 비면 [] (화면은 부드러운 빈 자리)
static func myth(v: Village) -> PackedStringArray:
	var out := PackedStringArray()
	if v == null:
		return out
	for l: Variant in v.myth:
		out.append(WatcherName.myth_line(v, String(l)))
	if out.is_empty() and v.water is WorldWater:      # 창조 오프닝이 남긴 신화 (OPENING 9 — CreationPlan.myth_of → WorldWater.creation)
		var cr: Variant = (v.water as WorldWater).creation
		if cr is Dictionary:
			for l: Variant in (cr as Dictionary).get("myth", []):
				out.append(WatcherName.myth_line(v, String(l)))     # {c} = 깨달은 뒤 부르는 말, 그 전 '어떤 분' (N2)
	if not out.is_empty():
		return out
	for e: Dictionary in v.book:
		if float(e["t"]) > MYTH_T:
			break
		out.append(String(e["text"]))
	return out


## 사람들 — {alive, dead, left}: 줄마다 {id, name, sex, age(표시 나이), note, r(Resident 또는 null), v(그 사람이 있는 마을 또는 null)}.
## alive = 나이 많은 순, dead = 최근에 잠든 순, left = 최근에 떠난 순. world를 주면 떠난 사람을 새 무리에서 찾아 얼굴·상세를 잇는다
static func people(v: Village, world: JarWorld = null) -> Dictionary:
	var alive: Array = []
	for r in v.people:
		alive.append({"id": r.id, "name": r.name, "sex": r.sex, "age": r.shown_age(), "note": "", "r": r, "v": v})
	alive.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["age"] > b["age"] if a["age"] != b["age"] else a["id"] < b["id"])
	var dead: Array = []
	for r in v.dead:
		dead.append({"id": r.id, "name": r.name, "sex": r.sex, "age": r.shown_age(), "note": "%d일차 잠듦" % v.cal_day(r.death_t), "why": r.death_why,
			"t": r.death_t, "r": r, "v": v})
	dead.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] > b["t"])
	var left: Array = []
	for d: Dictionary in v.departed:
		var row := {"id": int(d["id"]), "name": String(d["name"]), "sex": String(d.get("sex", "m")), "age": int(d.get("age", 0)), "t": float(d["t"]),
			"note": "%d일차 · %s%s" % [v.cal_day(float(d["t"])), String(d.get("to", "새 땅")), "(으)로"], "r": null, "v": null}
		row["note"] = "%d일차 · %s%s 떠남" % [v.cal_day(float(d["t"])), String(d.get("to", "새 땅")), Village.josa(String(d.get("to", "새 땅")), "으로", "로")]
		if world != null:
			for q in world.settlements:
				if q.sid != int(d.get("to_sid", -1)):
					continue
				var r := q.person(int(d["id"]))
				if r != null:
					row["r"] = r
					row["v"] = q
				else:
					for x in q.dead:
						if x.id == int(d["id"]):
							row["r"] = x
				break
		left.append(row)
	left.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["t"] > b["t"])
	return {"alive": alive, "dead": dead, "left": left}
