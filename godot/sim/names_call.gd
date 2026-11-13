## 벚꽃 철 이름 부르기 (ROADMAP Q31 · STORY 2 "벚꽃 철 이름 부르기" · REVIEW_2026-11-12 긴장 곡선 — 2026-11-14 메인 판단, 사용자 위임).
## 해마다 벚꽃잎이 지는 철(Balance.NAMES_FROM ~ NAMES_UNTIL)의 첫 잔잔한 저녁, 지난 모임 뒤로 누군가 떠났으면
## 사람들이 해 질 녘 벚나무 아래(멀면 묘지 곁 · 그것도 없으면 모닥불 곁)에 등불을 들고 모여 떠난 이들의 이름을 부른다.
## 잔치가 아니다 — 조용한 장례 연출의 변형 (view/stagings.gd "names_call" · view/moment_cast.gd "names").
##
## 규칙:
##   · 시뮬레이션 값은 하나도 바꾸지 않는다 — 주민의 할 일 · 걸음 · 행복 · 슬픔 · 난수 · 창고 모두 그대로. 남기는 것은 연대기 한 줄 · 고비 기록의 "call" ·
##     사건 &"names_called" (화면이 연출) · 처음 한 번 고비 '첫 이름 부르기'(잔치 · 별명 없음 — 도장 · 기념품 · 연대기 줄)뿐.
##   · 지켜보는지 읽지 않는다: 비운 동안에도 병 시계로 모이고 지나간다 (돌아와서 다시 틀지 않음 — 연대기 줄만 남음).
##   · 막히는 저녁: 첫 한 시간 · 깨달음 장면 중 · 위기(작은 위기 · 큰 위기 · 먹을 것 모자람) · 추운 저녁 · 그날 저녁 잔치가 기다림 · 아무도 없음
##     → 그 저녁은 건너뛰고 철 안의 다음 저녁. 철이 끝나도록 못 모이면 그해는 건너뛰고, 이름은 다음 해에 함께 부른다.
##   · 아무도 떠나지 않은 해에는 모이지 않는다. 이름은 병의 첫 정착지(owns_water — Milestones.step이 부름)의 무덤에서.
##   · 주민 쪽 글이라 숫자 없음 — 이름이 많으면 몇만 적고 "그리고 여러 이웃". 지켜보는 이 이야기 없음 (깨닫기 전 · 뒤 같음).
## 상태: Village.milestones["call"] = {"year" 마지막으로 모인 해, "t" 그때의 병 시각, "n" 모인 횟수, "log": [{t, day, date, names, place, x, y, who}] 최근 것}
##   — 처음 모일 때(또는 옛 저장을 올릴 때) 생긴다. 모인 적이 없으면 "call"이 없다 (새 병의 저장은 이 작업 전과 같음).
## static 함수만 (ADR-0001).
class_name NamesCall
extends RefCounted

const LOG_KEEP := 12                     # 기록에 남기는 최근 모임 수 (수첩 · 시험 · 측정용)
const PLACE_WORD := {"tree": "벚나무 아래에", "yard": "묘지 곁에", "fire": "모닥불 곁에"}
const LINE := "벚꽃잎이 지는 저녁, 사람들이 등불을 들고 %s 모였다. 그동안 떠난 %s의 이름을 불렀다."
const MANY := "그리고 여러 이웃"
const FIRE_GAP := 4.6                    # 모닥불 곁에서 모일 때 불에서 떨어지는 거리 (칸 — 화면만 쓰는 자리)


# ───────────────────────── 한 걸음 (Milestones.step — 첫 정착지만) ─────────────────────────
static func step(v: Village) -> void:
	var h := v.hour_now()
	if h < Balance.NAMES_HOUR or h > Balance.NAMES_LATEST:
		return
	var date := Health.jar_date(v)
	if not in_season(int(date["month"]), int(date["day"])):
		return
	var st: Dictionary = v.milestones.get("call", {})
	if int(st.get("year", -1)) == int(date["year"]):
		return                                        # 올해는 이미 모였다
	if blocked(v) != "":
		return
	var gone := departed_since(v, float(st.get("t", -1.0)))
	if gone.is_empty():
		return                                        # 아무도 떠나지 않았다 — 올해는 모이지 않는다 (다음 저녁에 다시 살피는 값은 싸다)
	gather(v, gone, date)


## 벚꽃잎이 지는 철인가 (달 · 날)
static func in_season(month: int, day: int) -> bool:
	var md := month * 100 + day
	return md >= Balance.NAMES_FROM.x * 100 + Balance.NAMES_FROM.y and md <= Balance.NAMES_UNTIL.x * 100 + Balance.NAMES_UNTIL.y


## 오늘 저녁 모일 수 없는 까닭 ("" = 모일 수 있음) — 읽기만
static func blocked(v: Village) -> String:
	if v.people.is_empty():
		return "empty"
	if v.in_opening() or v.staged():
		return "opening"
	if in_crisis(v):
		return "crisis"
	if Health.cold_of(Health.base_temp(v, v.t)) > Balance.NAMES_COLD_MAX:
		return "cold"
	if Milestones.feast_on(v) or VillageEra.wedding_on(v):
		return "feast"
	var today := v.cal_day(v.t)
	for f: Dictionary in v.milestones.get("feasts", []):
		if int(f.get("day", 0)) <= today:
			return "feast"                            # 오늘 저녁 잔치가 기다린다 — 같은 저녁에 겹치지 않게
	return ""


## 지금 위기인가 — Village.in_crisis()와 같음 (옛 이름 그대로 둠)
static func in_crisis(v: Village) -> bool:
	return v.in_crisis()


## after(병 시각) 뒤에 무덤에 묻힌 사람들 (묻힌 차례) — 무덤 기록 [{id, name, t, …}]
static func departed_since(v: Village, after: float) -> Array:
	var out: Array = []
	for g: Dictionary in v.graves:
		if float(g.get("t", 0.0)) > after:
			out.append(g)
	return out


## 모임 자리 {place: "tree" | "yard" | "fire", at: Vector2, behind: 사람들 뒤에 오는 것의 가운데 (나무 · 묘지 · 모닥불 — 화면이 그쪽을 등지게 봄), tree: 벚나무 가운데 (나무 아래일 때)}
static func spot(v: Village) -> Dictionary:
	if v.water is WorldWater:
		var t := GreatTrees.of_kind(v.water as WorldWater, "cherry")
		if not t.is_empty():
			var c := Vector2(float(t["x"]), float(t["y"]))
			var r := float(t["r"])
			if c.distance_to(v.center) - r <= v.territory_r() + Balance.NAMES_TREE_REACH:
				var dir := v.center - c
				dir = dir.normalized() if dir.length() > 0.1 else Vector2(0, 1)
				return {"place": "tree", "at": c + dir * (r + 2.5), "tree": c, "behind": c}
	var gy := VillageEra.first_built(v, "묘지")
	if gy != null:
		return {"place": "yard", "at": Vector2(gy.x, gy.y + gy.size() * 0.5 + 1.6), "behind": Vector2(gy.x, gy.y)}
	var sq := v.fire if v.fire.distance_to(v.center) < 30.0 else v.center
	return {"place": "fire", "at": fire_side(v, sq), "behind": sq}     # 모닥불 그림이 커서 (불꽃이 사람을 가림) 조금 떨어져 불을 등지고


## 모닥불에서 FIRE_GAP 떨어진 자리 가운데, 그 자리와 화면 쪽(불의 반대쪽)으로 건물 · 꽃숲 덩이 · 바위 · 큰 꽃이 넉넉히 비어 있는 첫 자리
## (앞쪽(+y)부터 좌우로 벌려 가며 — 난수 없음 · 읽기만). 없으면 앞쪽. 화면만 쓰는 자리 (주민은 오지 않음)
static func fire_side(v: Village, sq: Vector2) -> Vector2:
	for deg: float in [0.0, 40.0, -40.0, 80.0, -80.0, 120.0, -120.0, 160.0, -160.0]:
		var a := deg_to_rad(90.0 + deg)
		var dir := Vector2(cos(a), sin(a))
		var p := sq + dir * FIRE_GAP
		if _open_around(v, [p, p + dir * 1.6, p + dir * 3.2]):
			return p
	return sq + Vector2(0.0, FIRE_GAP)


static func _open_around(v: Village, pts: Array) -> bool:
	for q: Vector2 in pts:
		if v.water == null or not v.water.inside(q.x, q.y, 1.5) or v.water_at(q.x, q.y):
			return false
		for b in v.buildings:
			if Vector2(b.x, b.y).distance_to(q) < b.size() * 0.5 + 2.2:
				return false
		for tr: Dictionary in v.trees:
			if Vector2(float(tr["x"]), float(tr["y"])).distance_to(q) < 2.2:
				return false
		for r: Dictionary in v.rocks:
			if Vector2(float(r["x"]), float(r["y"])).distance_to(q) < 2.0:
				return false
		if v.flora != null and v.flora.blocks(q.x, q.y, 1.2):
			return false
	return true


## 이름을 부르는 사람: 가장 나이 많은 성한 어른 (노인 포함 · 같으면 번호 차례) — 없으면 앓는 어른 · 없으면 null
static func caller(v: Village) -> Resident:
	var best: Resident = null
	for p in v.people:
		if not p.dead and p.age >= Balance.AGE_ADULT and (best == null or _before(p, best)):
			best = p
	return best


## 부르는 사람 차례: 성한 사람 먼저 → 나이 많은 사람 → 번호가 작은 사람
static func _before(a: Resident, b: Resident) -> bool:
	var wa := a.sick_left <= 0.0
	var wb := b.sick_left <= 0.0
	if wa != wb:
		return wa
	if a.age != b.age:
		return a.age > b.age
	return a.id < b.id


## 연대기에 적는 이름 줄 (숫자 없음): "가" · "가와 나" · "가, 나, 다" · "가, 나, 다 그리고 여러 이웃"
static func names_text(names: Array) -> String:
	if names.is_empty():
		return ""
	if names.size() == 1:
		return String(names[0])
	if names.size() == 2:
		return "%s%s %s" % [names[0], Village.josa(String(names[0]), "과", "와"), names[1]]
	var shown: Array = names.slice(0, Balance.NAMES_LINE_MAX)
	var s := ", ".join(PackedStringArray(shown))
	return s + (" " + MANY if names.size() > Balance.NAMES_LINE_MAX else "")


## 모임 — 연대기 한 줄 · 기록 · 사건 (처음이면 고비). 주민은 건드리지 않는다
static func gather(v: Village, gone: Array, date: Dictionary) -> void:
	var m: Dictionary = v.milestones
	var st: Dictionary = m.get("call", {})
	var names: Array = []
	var ids: Array = []
	for g: Dictionary in gone:
		names.append(String(g.get("name", "")))
		ids.append(int(g.get("id", -1)))
	var sp := spot(v)
	var at: Vector2 = sp["at"]
	var who := caller(v)
	st["year"] = int(date["year"])
	st["t"] = v.t
	st["n"] = int(st.get("n", 0)) + 1
	var rec := {"t": v.t, "day": v.cal_day(v.t), "date": "%d-%02d-%02d" % [date["year"], date["month"], date["day"]], "names": names,
		"place": String(sp["place"]), "x": at.x, "y": at.y, "who": who.id if who != null else -1}
	var lg: Array = st.get("log", [])
	lg.append(rec)
	while lg.size() > LOG_KEEP:
		lg.pop_front()
	st["log"] = lg
	m["call"] = st
	v.log_line(LINE % [String(PLACE_WORD[sp["place"]]), names_text(names)])
	var ev := {"names": names, "graves": ids, "place": String(sp["place"]), "first": not Milestones.is_passed(v, "names")}
	if sp.has("tree"):
		ev["tree"] = sp["tree"]
	ev["behind"] = sp["behind"]
	v.emit(&"names_called", {"who": who.id if who != null else -1, "at": at, "v": ev})
	if not Milestones.is_passed(v, "names"):
		Milestones.pass_names(v, who)


## 지난 모임 (없으면 빈 사전)
static func last(v: Village) -> Dictionary:
	var lg: Array = (v.milestones.get("call", {}) as Dictionary).get("log", [])
	return lg[lg.size() - 1] if not lg.is_empty() else {}


# ───────────────────────── 옛 저장 (Milestones 판 6 전) ─────────────────────────
## 지난 벚꽃 철에 이미 모였어야 했다면 (그 철의 첫 저녁 전에 떠난 사람이 있음) 조용히 넘은 것으로 — 사건 · 연대기 줄 · 연출 없이
## 고비 도장과 기념품만 (Milestones._mark_silent), 그 저녁까지의 이름은 부른 것으로 친다 (다음 모임에 다시 나오지 않게).
## 아직 그런 철이 없었으면 아무것도 적지 않는다 (새 병과 같음).
static func quiet_past(v: Village) -> void:
	if v.milestones.has("call"):
		return
	var t_s := last_season_start(v)
	if t_s < 0.0:
		return
	if departed_since(v, -1.0).filter(func(g: Dictionary) -> bool: return float(g.get("t", 0.0)) < t_s).is_empty():
		return
	var d := _date_at(v, t_s)
	v.milestones["call"] = {"year": int(d["year"]), "t": t_s, "n": 1, "log": [], "quiet": true}
	if not Milestones.is_passed(v, "names"):
		Milestones.mark_silent(v, "names")


## 지금보다 앞선 가장 가까운 '철의 첫 저녁'(NAMES_FROM의 NAMES_HOUR)의 병 시각 — 병이 생긴 뒤의 것만 (없으면 -1)
static func last_season_start(v: Village) -> float:
	var now := Health.jar_date(v)
	for back in 3:
		var y := int(now["year"]) - back
		var tt := _t_of(v, y, Balance.NAMES_FROM.x, Balance.NAMES_FROM.y) + Balance.NAMES_HOUR * Balance.HOUR
		if tt <= v.t and tt >= 0.0:
			return tt
	return -1.0


## 달력 날짜(그날 0시)의 병 시각 (Health.jar_date의 거꾸로)
static func _t_of(v: Village, y: int, mo: int, d: int) -> float:
	var c: Dictionary = v.created_date
	var base := Time.get_unix_time_from_datetime_dict({"year": int(c["year"]), "month": int(c["month"]), "day": int(c["day"]), "hour": 12, "minute": 0, "second": 0})
	var u := Time.get_unix_time_from_datetime_dict({"year": y, "month": mo, "day": d, "hour": 12, "minute": 0, "second": 0})
	var days := roundi(float(u - base) / 86400.0)
	return float(days) * Balance.DAY - v.start_clock


static func _date_at(v: Village, tt: float) -> Dictionary:
	var c: Dictionary = v.created_date
	var base := Time.get_unix_time_from_datetime_dict({"year": int(c["year"]), "month": int(c["month"]), "day": int(c["day"]), "hour": 12, "minute": 0, "second": 0})
	var days := int((v.start_clock + tt) / Balance.DAY)
	return Time.get_datetime_dict_from_unix_time(base + days * 86400)
