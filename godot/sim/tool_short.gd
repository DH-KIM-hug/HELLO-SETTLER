## 연장이 모자람 — 신호와 손길 (ROADMAP Q25 · REVIEW_2026-11-12 1-2 · GAME_DESIGN 6.7 소원 · SHOP 2.2).
## 창고의 연장(stock "도구")이 곧 일터 수다: 연장이 바닥나면 지어 둔 일터가 비고 일손이 논다. 예전에는 화면에 아무 표시가 없었다.
##  · 신호 (보기 + 사건만 — 경제는 그대로): 병 한 시간마다 본다. 창고에 연장이 없고, 빈 일터가 있고, 일터 없는 성한 어른이
##    TOOL_SHORT_IDLE 명 이상인 때가 TOOL_SHORT_HOURS 시간 이어지면 '모자람'이 켜진다 (사건 &"tools_short" on) — 화면은 그 어른들
##    머리 위에 작은 연장 그림 말풍선을 가끔 띄운다 (view). 조건이 TOOL_SHORT_OFF_HOURS 시간 풀려 있으면 꺼진다 (on false).
##  · 촌장의 편지: 모자람이 켜져 있고 제단이 섰으면 촌장이 소원 편지 "연장이 모자라요"를 쓴다 (kind "wish", type TOOL_WISH) —
##    한 통이 열려 있는 동안·마지막 편지에서 TOOL_WISH_EVERY 안에는 또 쓰지 않는다. **난수를 쓰지 않는다** (편지 흐름 econ_rng ·
##    다음 소원 때를 건드리지 않음) · 말(say)을 하지 않는다 (say_t를 읽는 계통이 있어 — 경제가 한 비트도 바뀌지 않게).
##  · 손길: 상점의 연장 꾸러미 (Shop.ITEMS TOOL_ITEM — kind "stuff", res "도구"). 모자람이 처음 켜진 뒤에 진열이 열린다
##    (그 전에는 '일손이 남으면'). 떨어뜨리면 주민이 떼어 내 창고로 나르고 (SkyDrops 깎기 — 거인이 준 몫, 제물로 되돌아가지 않음),
##    열린 연장 편지는 '들어줌'이 된다 (given — 믿음 +, 촌장의 고맙다는 말, 연대기 한 줄, 사건 &"tools_given").
## 상태는 Village의 tools_short_* · tools_wish_t (이름 그대로 저장 — 옛 저장은 기본값 = 꺼짐).
class_name ToolShort
extends RefCounted

const TOOL_WISH := "연장"
const TOOL_ITEM := "연장 꾸러미"
const WISH_TEXT := "일손은 남는데 연장이 모자라요. 연장만 있으면 빈 일터에서 일할 수 있어요."
const THANKS := "이제 다들 연장을 쥐고 일하러 가요!"
const BOOK_GIVEN := "하늘에서 은빛 쇠붙이 무더기가 내려왔다. 사람들은 그것을 떼어 내 두드려 연장을 만들었다."


## 지금 모자란가 → {idle: 일터 없는 성한 어른 수, empty: 빈 일터 수, ids: 그 어른들 id} (모자라지 않으면 빈 사전).
## 읽기만 한다 (난수 · 상태 변경 없음)
static func shortage(v: Village) -> Dictionary:
	if float(v.stock.get("도구", 0.0)) >= 1.0:
		return {}
	var empty := 0
	for b: Building in v.buildings:
		if b.built and b.worker < 0 and b.def().get("job", false) and not (b.type == "채석장" and v.quarry_no_rock(b)):
			empty += 1
	if empty <= 0:
		return {}
	var ids: Array = []
	for p: Resident in v.people:
		if idle_hand(v, p):
			ids.append(p.id)
	if ids.size() < Balance.TOOL_SHORT_IDLE:
		return {}
	return {"idle": ids.size(), "empty": empty, "ids": ids}


## 일터 없이 노는 성한 어른인가 (아기 돌봄 · 앓음은 빼고) — 화면의 연장 말풍선도 이것으로 고른다
static func idle_hand(v: Village, p: Resident) -> bool:
	return p.is_adult() and p.job < 0 and p.sick_left <= 0.0 and Production.caring_for(v, p) == null


## 모자람 신호가 켜져 있나 (화면 · 상점)
static func on(v: Village) -> bool:
	return v.tools_short_t >= 0.0


## 병 한 시간마다 (Village.step — 호수 관찰과 같은 시계)
static func hourly(v: Village) -> void:
	if v.tools_signal_off:
		return
	var s := shortage(v)
	if not s.is_empty():
		v.tools_short_h = maxi(1, v.tools_short_h + 1)
	else:
		v.tools_short_h = mini(-1, v.tools_short_h - 1)
	if not on(v):
		if v.tools_short_h >= Balance.TOOL_SHORT_HOURS:
			v.tools_short_t = v.t
			if v.tools_short_first < 0.0:
				v.tools_short_first = v.t
			v.emit(&"tools_short", {"v": {"on": true, "idle": int(s["idle"]), "empty": int(s["empty"]), "ids": s["ids"]}})
	elif v.tools_short_h <= -Balance.TOOL_SHORT_OFF_HOURS:
		v.emit(&"tools_short", {"v": {"on": false, "secs": v.t - v.tools_short_t}})
		v.tools_short_t = -1.0
	if on(v):
		_maybe_wish(v)


## 촌장의 '연장이 모자라요' 편지 (난수 없음 · 말 없음)
static func _maybe_wish(v: Village) -> void:
	if not v.altar_built or not open_wish(v).is_empty():
		return
	if v.tools_wish_t >= 0.0 and v.t - v.tools_wish_t < Balance.TOOL_WISH_EVERY:
		return
	var c := v.chief()
	if c == null:
		return
	v._letter_id += 1
	var l := {"id": v._letter_id, "kind": "wish", "t": v.t, "from": c.id, "name": "촌장 %s" % c.name, "type": TOOL_WISH, "text": WISH_TEXT, "state": "open"}
	v.letters.append(l)
	v.tools_wish_t = v.t
	v.emit(&"tools_wish", {"who": c.id, "v": {"id": int(l["id"])}})


## 화면의 연장 말풍선을 띄울 때인가: 모자람이 켜져 있고, 떨어뜨린 연장 꾸러미를 아직 떼어 나르는 중이 아님 (손길이 닿았으면 기다림)
static func bubbles(v: Village) -> bool:
	if not on(v):
		return false
	for d: Dictionary in v.drops:
		if String(d.get("res", "")) == "도구" and float(d.get("left", 0.0)) > 0.01:
			return false
	return true


## 열린 연장 편지 (없으면 빈 사전)
static func open_wish(v: Village) -> Dictionary:
	for l: Dictionary in v.letters:
		if l["kind"] == "wish" and l["state"] == "open" and String(l["type"]) == TOOL_WISH:
			return l
	return {}


static func is_tool_wish(l: Dictionary) -> bool:
	return String(l.get("type", "")) == TOOL_WISH


## 연장 꾸러미를 떨어뜨렸다 (SkyDrops.drop) — 열린 연장 편지는 들어준 것이 된다
static func given(v: Village, amt: float) -> void:
	var l := open_wish(v)
	var lid := -1
	if not l.is_empty():
		l["state"] = "granted"
		lid = int(l["id"])
		v.bless_all(Balance.WISH_BELIEF)
		v._update_belief(0.0)
		var who := v.person(int(l["from"]))
		if who != null and not who.sleeping:
			v.speak(who, THANKS, 7)
	v.stats["tool_given"] = float(v.stats.get("tool_given", 0.0)) + amt
	v.emit(&"tools_given", {"v": {"amt": amt, "wish": lid}})
