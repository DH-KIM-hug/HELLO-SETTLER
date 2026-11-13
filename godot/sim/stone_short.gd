## 돌이 모자람 — 촌장의 '돌이 모자라요' 편지 (ROADMAP Q30 · BALANCE '돌 천장 (Q30)' · mayor-decisions 14번 칸).
## 병의 돌 바위는 창조 때 정해진다 (닫힌 병 — SHOP 2.4). 다 캐고 창고의 돌도 바닥나면 밭 · 맷돌간 · 화덕 · 제재소 · 돌집처럼 돌이 드는
## 일터를 더 짓지 못해 일손이 남는다 (Q26 측정: 200일에 노는 어른 ~33명). Q25 연장 편지(sim/tool_short.gd)와 같은 틀:
##  · 신호 (사건만 — 경제는 그대로): 병 한 시간마다 본다. 창고의 쓸 수 있는 돌(짓는 터 몫을 뺀 것)이 STONE_SHORT_MIN 아래이고,
##    캘 돌 바위가 닿는 곳에 하나도 없고 (채석장 둘레에도, 새 채석장을 놓을 만한 영역 + 캐는 거리 안에도), 떨어뜨린 돌 무더기를
##    떼어 나르는 중도 아니고, 일터 없는 성한 어른이 STONE_SHORT_IDLE 명 이상인 때가 STONE_SHORT_HOURS 시간 이어지면 켜진다
##    (사건 &"stone_short" on). STONE_SHORT_OFF_HOURS 시간 풀려 있으면 꺼진다.
##  · 촌장의 편지: 켜져 있고 제단이 섰으면 "돌이 모자라요" 소원 편지 (kind "wish", type STONE_WISH) — 연장 편지와 같은 간격
##    (열린 편지가 있는 동안 · 마지막 편지에서 STONE_WISH_EVERY 안엔 또 쓰지 않음). **연장 편지와 같은 병 날에는 쓰지 않는다 (연장 먼저)**.
##    들어주지 않고 닫힌 편지가 이어지면 닫힌 뒤 4 → 8 → 16일 기다린다 (STONE_WISH_BACKOFF_MAX까지 · 돌을 떨어뜨리면 처음으로 — backoff).
##    난수 · 말(say)을 쓰지 않는다 (경제가 한 비트도 바뀌지 않게 — 연장 편지와 같은 까닭).
##  · 손길: 상점의 자갈 한 알 · 회색 돌멩이 (있는 물건 그대로). 떨어뜨리면 열린 돌 편지가 '들어줌'이 된다 (given — 믿음 +,
##    촌장의 고맙다는 말, 사건 &"stone_given"). 편지가 열려 있는 동안 두 물건 카드에 작은 표시 (Shop.card "letter").
## 상태는 Village의 stone_short_* · stone_wish_t (이름 그대로 저장 — 옛 저장은 기본값 = 꺼짐).
class_name StoneShort
extends RefCounted

const STONE_WISH := "돌"
const ITEMS := ["자갈 한 알", "회색 돌멩이"]           # 떨어뜨리면 편지가 이루어지는 물건 (상점 카드에 편지 표시)
const WISH_TEXT := "돌이 모자라요. 둘레의 바위는 다 캐어 냈고, 지을 것은 있는데 손을 놓은 사람이 늘어 가요."
const THANKS := "돌이 생겼어요! 다시 지을 수 있겠어요."


## 지금 모자란가 → {idle, ids} (모자라지 않으면 빈 사전). 읽기만 한다 (난수 · 상태 변경 없음)
static func shortage(v: Village) -> Dictionary:
	if float(v.stock.get("돌", 0.0)) - float(v._owed("돌")) >= Balance.STONE_SHORT_MIN:
		return {}
	if pile_left(v) or rock_reachable(v):
		return {}
	var ids: Array = []
	for p: Resident in v.people:
		if ToolShort.idle_hand(v, p):
			ids.append(p.id)
	if ids.size() < Balance.STONE_SHORT_IDLE:
		return {}
	return {"idle": ids.size(), "ids": ids}


## 캘 돌 바위가 닿는 곳에 있나: 어느 채석장 둘레에 있거나, 영역 + 캐는 거리 안에 있다 (촌장이 그 곁에 채석장을 하나 더 짓는다 — Q13)
static func rock_reachable(v: Village) -> bool:
	var reach := v.territory_r() + Balance.GATHER_RANGE
	for rk: Dictionary in v.rocks:
		if not v._stone_rock(rk):
			continue
		if Vector2(float(rk["x"]) - v.center.x, float(rk["y"]) - v.center.y).length() <= reach:
			return true
	for b: Building in v.buildings:
		if b.type == "채석장" and v.stone_in_reach(b.x, b.y):
			return true
	return false


## 떨어뜨린 돌 무더기(자갈 한 알)를 아직 떼어 나르는 중인가 — 손길이 닿았으면 기다린다
static func pile_left(v: Village) -> bool:
	for d: Dictionary in v.drops:
		if String(d.get("res", "")) == "돌" and float(d.get("left", 0.0)) > 0.01:
			return true
	return false


static func on(v: Village) -> bool:
	return v.stone_short_t >= 0.0


## 병 한 시간마다 (Village.step — ToolShort.hourly 바로 뒤)
static func hourly(v: Village) -> void:
	if v.stone_signal_off:
		return
	_watch_letter(v)
	var s := shortage(v)
	if not s.is_empty():
		v.stone_short_h = maxi(1, v.stone_short_h + 1)
	else:
		v.stone_short_h = mini(-1, v.stone_short_h - 1)
	if not on(v):
		if v.stone_short_h >= Balance.STONE_SHORT_HOURS:
			v.stone_short_t = v.t
			if v.stone_short_first < 0.0:
				v.stone_short_first = v.t
			v.emit(&"stone_short", {"v": {"on": true, "idle": int(s["idle"]), "ids": s["ids"]}})
	elif v.stone_short_h <= -Balance.STONE_SHORT_OFF_HOURS:
		v.emit(&"stone_short", {"v": {"on": false, "secs": v.t - v.stone_short_t}})
		v.stone_short_t = -1.0
	if on(v):
		_maybe_wish(v)


## 병의 날 (달력 — 같은 날인지 견줄 때)
static func day_of(v: Village, tt: float) -> int:
	return int(floor((v.start_clock + tt) / Balance.DAY))


## 지난 돌 편지가 닫혔나 살핀다 — 들어주지 않고 닫혔으면 miss + 1 (다음 편지가 더 늦게), 들어줬으면 0
static func _watch_letter(v: Village) -> void:
	if v.stone_wish_id < 0:
		return
	for l: Dictionary in v.letters:
		if int(l["id"]) == v.stone_wish_id:
			if String(l["state"]) == "open":
				return
			if String(l["state"]) == "granted":
				v.stone_wish_miss = 0
			else:
				v.stone_wish_miss += 1
				v.stone_wish_closed_t = v.t
			break
	v.stone_wish_id = -1


## 들어주지 않은 편지가 닫힌 뒤 다음 편지까지 기다리는 병 시간: 4 → 8 → 16일 (STONE_WISH_BACKOFF_MAX까지). 들어줬으면 0
static func backoff(v: Village) -> float:
	if v.stone_wish_miss <= 0:
		return 0.0
	return minf(Balance.STONE_WISH_EVERY * pow(2.0, float(v.stone_wish_miss - 1)), Balance.STONE_WISH_BACKOFF_MAX)


## 촌장의 '돌이 모자라요' 편지 (난수 없음 · 말 없음)
static func _maybe_wish(v: Village) -> void:
	if not v.altar_built or not open_wish(v).is_empty():
		return
	if v.stone_wish_t >= 0.0 and v.t - v.stone_wish_t < Balance.STONE_WISH_EVERY:
		return
	if v.stone_wish_miss > 0 and v.t - v.stone_wish_closed_t < backoff(v):
		return                                   # 들어주지 않은 편지가 이어지면 점점 뜸하게 (2026-11-14 메인 판단 — 조르지 않게)
	if v.tools_wish_t >= 0.0 and day_of(v, v.tools_wish_t) == day_of(v, v.t):
		return                                   # 오늘 연장 편지를 썼다 — 돌 편지는 다음 날 (연장 먼저)
	var c := v.chief()
	if c == null:
		return
	v._letter_id += 1
	var l := {"id": v._letter_id, "kind": "wish", "t": v.t, "from": c.id, "name": "촌장 %s" % c.name, "type": STONE_WISH, "text": WISH_TEXT, "state": "open"}
	v.letters.append(l)
	v.stone_wish_t = v.t
	v.stone_wish_id = int(l["id"])
	v.emit(&"stone_wish", {"who": c.id, "v": {"id": int(l["id"])}})


## 오늘 돌 편지를 썼나 (ToolShort — 같은 날 두 통을 쓰지 않게)
static func wrote_today(v: Village) -> bool:
	return v.stone_wish_t >= 0.0 and day_of(v, v.stone_wish_t) == day_of(v, v.t)


## 열린 돌 편지 (없으면 빈 사전)
static func open_wish(v: Village) -> Dictionary:
	for l: Dictionary in v.letters:
		if l["kind"] == "wish" and l["state"] == "open" and String(l["type"]) == STONE_WISH:
			return l
	return {}


static func is_stone_wish(l: Dictionary) -> bool:
	return String(l.get("type", "")) == STONE_WISH


## 돌을 주는 물건인가 (자갈 한 알 · 회색 돌멩이)
static func is_stone_item(item: String) -> bool:
	return ITEMS.has(item)


## 자갈 한 알 · 회색 돌멩이를 떨어뜨렸다 (SkyDrops.drop) — 열린 돌 편지는 들어준 것이 된다
static func given(v: Village, item: String) -> void:
	var l := open_wish(v)
	var lid := -1
	v.stone_wish_miss = 0                        # 돌이 닿았다 — 다음 편지는 다시 4일 간격부터
	if not l.is_empty():
		l["state"] = "granted"
		lid = int(l["id"])
		v.bless_all(Balance.WISH_BELIEF)
		v._update_belief(0.0)
		var who := v.person(int(l["from"]))
		if who != null and not who.sleeping:
			v.speak(who, THANKS, 7)
	v.emit(&"stone_given", {"v": {"item": item, "wish": lid}})
