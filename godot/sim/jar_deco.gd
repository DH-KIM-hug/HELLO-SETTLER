## 꾸미기 — 별지기가 병을 꾸미는 것 (SHOP 1 · 2.7 · ROADMAP Q32). 지폐를 쓰는 곳 — 효과는 아주 작게, 주민 쪽엔 숫자 없음.
## 순수 로직. 화면: 조약돌 = view/sky_drop_view.gd · 받침·유리 빛깔·코르크 무늬 = view/room/giant_room.gd (set_deco) ·
##   흔들림 = view/tremor_fx.gd · view/stage_director.gd (JarCamera.shake 폭 × shake_mult).
## 상태는 Village.deco (사전 — 아무것도 안 산 병은 비어 있음 → 저장 지문이 예전과 같음 · 옛 저장은 빈 사전으로 읽힘):
##   pebbles: [{id, x, y, t}] — 이 무리 땅에 내려놓은 조약돌 (병과 함께 돎 — Village._turn_data)
##   stand: true · tints: [이름] · tint: 쓰는 이름 ("" = 맑은 유리) · corks: [이름] · cork: 쓰는 이름 ("" = 민무늬)
##   받침·빛깔·코르크는 병 하나에 하나 — 같은 병의 무리 가운데 sid가 가장 작은 무리(home)에 적는다.
## 탭이 열리는 때 (Shop.tab_open): 병 DECO_OPEN_DAY일 또는 첫 수확 뒤 — shop_open에 적지 않고 그때그때 셈 (도움 없는 마을의 저장이 그대로).
## 조약돌: 손으로 떨어뜨림 (SHOP 3 손의 흐름) → 그 자리에 매끈한 둥근 돌이 남음. 광장 가에 놓이면 집이 광장 곁인 사람들 행복이
##   아주 조금 (Balance.DECO_PEBBLE_HAPPY가 상한 — 광장 조약돌 DECO_PEBBLE_FULL개면 다 참). 한 병 무리에 DECO_PEBBLE_MAX개까지 (손에 든 것 포함).
## 병 받침: 흔들림 연출 폭 × DECO_STAND_SHAKE. 유리 빛깔 · 코르크 무늬: 순수 꾸미기 (산 것 가운데 골라 씀 — 상점 카드의 [바꾸기]).
class_name JarDeco
extends RefCounted

const TAB := "꾸미기"
const PEBBLE := "조약돌"
const STAND := "병 받침"
const PEBBLE_SIZE := 0.38                # 병 안 조약돌 반지름 (칸) — 사람 하나가 걸터앉을 만한 둥근 돌
const PEBBLE_GAP := 0.25                 # 조약돌끼리 띄울 틈 (칸)
## 유리 빛깔 (RENDERING 2.3 — 채도 낮게, 맑은 유리 0.86/0.95/0.95 곁의 옅은 빛). 값 = 유리 색
const TINTS := {
	"호박빛 유리": Color(0.95, 0.76, 0.50),
	"물빛 유리": Color(0.55, 0.83, 0.88),
	"이끼빛 유리": Color(0.66, 0.84, 0.58),
	"안개빛 유리": Color(0.79, 0.75, 0.92),
}
## 코르크 무늬 → 방 모델 (art/src/build_room.py — room/<모델>.glb, 코르크 위에 얹힘)
const CORKS := {
	"삼끈 코르크": "cork_twine",
	"밀랍 코르크": "cork_wax",
	"불도장 코르크": "cork_brand",
}
## 주민의 말 · 연대기 (금지어 없음 — '하늘에서 내려온 것'). [깨달은 뒤, 깨닫기 전]
const SAY := ["하늘에서 매끈한 돌이 내려왔다!", "어, 매끈한 돌이 떨어졌어!"]
const BOOK_FIRST := "광장 곁에 하늘에서 매끈한 둥근 돌이 내려앉았다. 아이들이 그 위에 올라앉아 볕을 쬐었다."
const BOOK_FAR := "하늘에서 매끈한 둥근 돌이 내려앉았다. 지나는 사람들이 손바닥으로 쓸어 보았다."


# ───────────────────────── 어디에 적나 ─────────────────────────
## 이 병(같은 세상의 무리들)에서 병 꾸미기를 적는 무리 — sid가 가장 작은 무리 (소형 병 = 자기)
static func home(v: Village) -> Village:
	var best := v
	for q: Variant in v.peers:
		if q is Village and (q as Village).sid < best.sid:
			best = q
	return best


static func pebbles(v: Village) -> Array:
	return v.deco.get("pebbles", []) if not v.deco.is_empty() else []


static func owns(v: Village, item: String) -> bool:
	var d := home(v).deco
	if d.is_empty():
		return false
	if item == STAND:
		return bool(d.get("stand", false))
	if TINTS.has(item):
		return item in (d.get("tints", []) as Array)
	if CORKS.has(item):
		return item in (d.get("corks", []) as Array)
	return false


static func using(v: Village, item: String) -> bool:
	var d := home(v).deco
	if TINTS.has(item):
		return String(d.get("tint", "")) == item
	if CORKS.has(item):
		return String(d.get("cork", "")) == item
	return item == STAND and bool(d.get("stand", false))


## 병에 바로 붙는 꾸미기 (손에 들지 않음 — 사면 곧바로)
static func is_jar_item(item: String) -> bool:
	return item == STAND or TINTS.has(item) or CORKS.has(item)


static func slot(item: String) -> String:
	return "stand" if item == STAND else ("tint" if TINTS.has(item) else ("cork" if CORKS.has(item) else ""))


# ───────────────────────── 탭 ─────────────────────────
static func tab_ready(v: Village) -> bool:
	return v.cal_day(v.t) >= Balance.DECO_OPEN_DAY or v.first_harvest_t >= 0.0


# ───────────────────────── 병에 붙이기 (받침 · 빛깔 · 코르크) ─────────────────────────
## 산 것을 병에 붙인다 (빛깔 · 코르크는 산 것을 곧바로 씀). 되돌리기용 이전 값 {slot, sel}
static func attach(v: Village, item: String) -> Dictionary:
	var h := home(v)
	var s := slot(item)
	var prev := {"slot": s, "sel": String(h.deco.get(s, ""))}
	match s:
		"stand":
			h.deco["stand"] = true
		"tint", "cork":
			var key := s + "s"
			var owned: Array = h.deco.get(key, [])
			if not item in owned:
				owned.append(item)
			h.deco[key] = owned
			h.deco[s] = item
	h.giant_acted()
	return prev


## 되돌리기 (Shop.undo_buy): 그 물건을 병에서 떼고 쓰던 것으로
static func detach(v: Village, item: String, prev: Dictionary) -> void:
	var h := home(v)
	var s := slot(item)
	match s:
		"stand":
			h.deco.erase("stand")
		"tint", "cork":
			var key := s + "s"
			var owned: Array = h.deco.get(key, [])
			owned.erase(item)
			if owned.is_empty():
				h.deco.erase(key)
			var back := String(prev.get("sel", ""))
			if back != "" and back in owned:
				h.deco[s] = back
			else:
				h.deco.erase(s)
	h.giant_acted()


## 산 빛깔 · 코르크 가운데 골라 씀. 이미 쓰는 것을 다시 고르면 맑은 유리 · 민무늬로. 지금 쓰는 이름 ("" = 기본)
static func choose(v: Village, item: String) -> String:
	if not owns(v, item):
		return ""
	var h := home(v)
	var s := slot(item)
	if String(h.deco.get(s, "")) == item:
		h.deco.erase(s)
	else:
		h.deco[s] = item
	h.giant_acted()
	return String(h.deco.get(s, ""))


## 화면이 읽는 병 모양 {stand: bool, tint: Color 또는 null, cork: 모델 이름 ""}
static func look(v: Village) -> Dictionary:
	var d := home(v).deco
	var tn := String(d.get("tint", ""))
	return {"stand": bool(d.get("stand", false)), "tint": TINTS.get(tn, null), "tint_name": tn,
		"cork": String(CORKS.get(String(d.get("cork", "")), ""))}


## 흔들림 연출 폭 배율 (병 받침이 있으면 줄어듦)
static func shake_mult(v: Village) -> float:
	if v == null:
		return 1.0
	return Balance.DECO_STAND_SHAKE if bool(home(v).deco.get("stand", false)) else 1.0


# ───────────────────────── 조약돌 ─────────────────────────
## 이 무리에 놓인 조약돌 + 손에 든 조약돌
static func pebbles_used(v: Village) -> int:
	return pebbles(v).size() + Shop.hand_count(PEBBLE)


## 떨어뜨릴 자리 미리보기 (SkyDrops.preview가 부름) → {ok, why, warn, crush, people, field, size, good}
static func preview(v: Village, p: Vector2) -> Dictionary:
	var size := PEBBLE_SIZE
	var no := func(why: String) -> Dictionary: return {"ok": false, "why": why, "warn": "", "crush": [], "people": 0, "field": false, "size": size}
	if not v.water.inside(p.x, p.y, size + 0.5):
		return no.call("유리벽 가까이엔 놓을 수 없어요")
	if v.water_at(p.x, p.y):
		return no.call("물 위에는 놓을 수 없어요")
	if Vector2(v.fire.x - p.x, v.fire.y - p.y).length() < size + 1.0:
		return no.call("모닥불 위에는 놓을 수 없어요")
	if (v.altar_built or Awakening.altar_site(v) != null) and Vector2(v.altar_pos.x - p.x, v.altar_pos.y - p.y).length() < size + 1.6:
		return no.call("제단 위에는 놓을 수 없어요")
	for b in v.buildings:
		if Vector2(b.x - p.x, b.y - p.y).length() < b.size() + size * 0.85:
			return no.call("건물 위에는 놓을 수 없어요")
	for o: Dictionary in v.drops:
		if Vector2(float(o["x"]) - p.x, float(o["y"]) - p.y).length() < float(o["size"]) * SkyDrops.shrink(o) + size:
			return no.call("먼저 내려온 것 위에는 놓을 수 없어요")
	for tw: Dictionary in v.towers:
		if Vector2(float(tw["x"]) - p.x, float(tw["y"]) - p.y).length() < 1.8 + size:
			return no.call("탑 위에는 놓을 수 없어요")
	for pb: Dictionary in pebbles(v):
		if Vector2(float(pb["x"]) - p.x, float(pb["y"]) - p.y).length() < size * 2.0 + PEBBLE_GAP:
			return no.call("조약돌이 이미 있어요")
	if pebbles(v).size() >= Balance.DECO_PEBBLE_MAX:
		return no.call("조약돌은 한 마을에 %d개까지예요" % Balance.DECO_PEBBLE_MAX)
	var good := "광장 곁이에요 — 오가는 사람들이 쉬어 가요" if on_plaza(v, p) else "광장에서 멀어요 — 보기에만 좋아요"
	return {"ok": true, "why": "", "warn": "", "crush": [], "people": 0, "field": false, "size": size, "good": good}


## 광장 가인가 (모닥불 둘레 광장 반지름 + DECO_PEBBLE_PLAZA)
static func on_plaza(v: Village, p: Vector2) -> bool:
	return Vector2(v.fire.x, v.fire.y).distance_to(p) <= VillagePlan.plaza_r(v) + Balance.DECO_PEBBLE_PLAZA


## 내려놓는다 (뚜껑 · 미리보기는 SkyDrops.drop이 이미 봄). → 놓인 조약돌 사전
static func place(v: Village, p: Vector2) -> Dictionary:
	v._drop_id += 1
	var o := {"id": v._drop_id, "x": p.x, "y": p.y, "t": v.t}
	var first := pebbles(v).is_empty()
	var list := pebbles(v)
	list.append(o)
	v.deco["pebbles"] = list
	v._clear_trees(p, PEBBLE_SIZE)
	Awakening.witness(v, "drop")                 # 하늘에서 내려온 것 (믿음은 보태지 않음 — 작은 장식)
	var near := v.people.filter(func(q: Resident) -> bool: return not q.sleeping and q.age >= 2.5 and q.sick_left <= 0.0)
	if not near.is_empty():
		near.sort_custom(func(a: Resident, c: Resident) -> bool: return Vector2(a.x, a.y).distance_squared_to(p) < Vector2(c.x, c.y).distance_squared_to(p))
		v.speak(near[0], SAY[0] if v.aware else SAY[1], 7)
	if first:
		v.log_line(BOOK_FIRST if on_plaza(v, p) else BOOK_FAR)      # 연대기는 처음 하나만 (값싼 장식이라 줄이 넘치지 않게)
	return o


## 짓는 자리를 막는가 (SkyDrops.blocks가 부름 — 조약돌이 없으면 곧바로 false)
static func blocks(v: Village, x: float, y: float, size: float) -> bool:
	if v.deco.is_empty():
		return false
	for pb: Dictionary in pebbles(v):
		if Vector2(float(pb["x"]) - x, float(pb["y"]) - y).length() < PEBBLE_SIZE + size + 0.3:
			return true
	return false


## 광장 조약돌이 곁 사람에게 보태는 행복 (Village._update_happiness가 한 번 셈 — 조약돌이 없으면 0)
static func plaza_bonus(v: Village) -> float:
	if v.deco.is_empty():
		return 0.0
	var n := 0
	for pb: Dictionary in pebbles(v):
		if on_plaza(v, Vector2(float(pb["x"]), float(pb["y"]))):
			n += 1
	return Balance.DECO_PEBBLE_HAPPY * minf(1.0, float(n) / float(Balance.DECO_PEBBLE_FULL))


## 그 사람 집이 광장 곁인가 (보탬을 받는 사람)
static func near_plaza(v: Village, p: Resident) -> bool:
	var hm := v.bld(p.home)
	return hm != null and Vector2(hm.x - v.fire.x, hm.y - v.fire.y).length() <= Balance.DECO_PEBBLE_NEAR
