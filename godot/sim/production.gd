## BALANCE v5 — 먹을 것·빵 사슬·거인이 준 몫·설계도·아기 돌봄 (순수 로직, 상태는 Village · Resident).
##  · 밀은 날로 먹지 않는다: 다른 먹을 것이 모자라면 모닥불에서 죽으로 끓여 먹는다 (밀 1 → 0.75, 행복 없음).
##    맷돌간(개척기)·방앗간(마을)이 밀을 가루로, 공용 화덕(개척기)·빵집(읍내)이 가루 + 물을 빵 1.5로 굽는다 (밀 1 → 빵 1.5 = 죽의 두 배).
##    빵은 창고에서 거의 상하지 않고 (밀은 하루 3%), 먹은 날 행복 +, 제물 값도 밀의 3.2배.
##  · 거인이 준 것 (Village.gift): 하늘에서 내려와 창고로 나른 몫은 제물로 되돌아가지 않는다 (되팔기 막기 — 가격 연구 3장 ⑥).
##    먹거나 쓰면 줄고, 가공하면 가공품의 몫으로 옮겨 간다 (밀 → 가루 → 빵).
##  · 설계도: 상점이 파는 것은 다 지은 건물이 아니라 그림 종이. 그 병 주민이 그 건물을 지을 줄 알게 되고 촌장이 곧바로 첫 터를 잡는다.
##  · 아기 돌봄 (GD 7.3): 아기가 걸음마를 할 때까지 부모 둘 다 집에서 돌본다 (같은 집에 노인이 있으면 한 사람은 일찍 일터로).
class_name Production
extends RefCounted


# ───────────────────────── 먹을 것 ─────────────────────────
## 하루에 먹는 양 (식량 단위)
static func day_need(v: Village) -> float:
	return v._food_people() * Balance.DAY / Balance.FOOD_IV


## 창고·건물 앞의 밀 + 창고 밀가루 (죽으로 끓일 수 있는 것)
static func wheat_total(v: Village) -> float:
	var n := float(v.stock.get(Balance.PORRIDGE, 0.0)) + float(v.stock.get("밀가루", 0.0))
	for b in v.buildings:
		n += float(b.out.get(Balance.PORRIDGE, 0.0))
	return n


## 먹을 수 있는 양 (식량 단위) — 창고 먹을 것 + 건물 앞의 빵 + 낟알 + 밀을 죽으로 끓인 몫
static func food_total(v: Village) -> float:
	var n := 0.0
	for k in Balance.FOODS_ALL:          # 부엌 것(알·단물·씨앗 우유) 포함 (E3-14)
		n += float(v.stock.get(k, 0.0))
	for m: Dictionary in v.manna_batches:
		n += float(m["amt"])
	for m: Dictionary in v.manna:
		n += float(m["amt"])
	for b in v.buildings:
		n += float(b.out.get("빵", 0.0))
	return n + wheat_total(v) * Balance.PORRIDGE_YIELD


## 배고픈 사람이 먹으러 갈 만큼 있는가 (2026-11-11 Q7-b · docs/measure/opening_food_b_2026-11-11.md): 먹을 수 있는 것(창고·밭 앞 + 창고로 오는 길)이 온 마을의 EAT_AT_HAND_HOURS 시간치 이상.
## 없으면 '먹기'를 고르지 않는다 (ResidentAI.decide) — 빈 창고 앞에 모여 서서 밭·나르기·짓기가 멎던 고리를 끊는다. 밭에서 나는 대로 먹어 치우는 부스러기는 '있다'로 치지 않는다
static func food_at_hand(v: Village) -> bool:
	var want := day_need(v) * Balance.EAT_AT_HAND_HOURS / 24.0
	return food_total(v) >= want or food_total(v) + food_on_way(v) >= want


## 첫 며칠의 맨손 채집 때인가 (2026-11-11 Q7-b): 도착하고 FORAGE_FIRST_DAYS 날 안이고, 먹을 것(창고·밭 앞 + 창고로 오는 길)이 FORAGE_FIRST_FOOD_DAYS 날치 아래.
## Village.forage_open이 연장 수와 상관없이 문을 열고, ResidentAI.decide가 채집 점수를 나르기·짓기보다 앞세운다 (OPENING 3.1 '건량 하루치 + 열매·버섯 조금 + 모닥불 죽')
static func forage_first(v: Village) -> bool:
	if v.t >= Balance.FORAGE_FIRST_DAYS * Balance.DAY or not bread_chain_built(v):
		return false
	return food_total(v) + food_on_way(v) < Balance.FORAGE_FIRST_FOOD_DAYS * day_need(v)


## 맷돌간과 화덕이 다 섰는가 — 그 전에는 일손을 채집으로 빼지 않는다 (재 보니 한 사람만 빠져도 첫 빵이 둘째 날에서 셋째 날로 밀렸다)
static func bread_chain_built(v: Village) -> bool:
	var mill := false
	var oven := false
	for b in v.buildings:
		if not b.built:
			continue
		if _grinds(b):
			mill = true
		var d := b.def()
		if d.has("out") and (d["out"] as Dictionary).has("빵"):
			oven = true
	return mill and oven


## 지금 바구니를 들고 나가 있는 사람 수 (r 빼고) — 첫 며칠의 맨손 채집은 FORAGE_FIRST_HANDS 사람까지만 앞세운다 (나머지는 짓기·나르기)
static func foragers_out(v: Village, r: Resident) -> int:
	var n := 0
	for p in v.people:
		if p != r and p.action == "forage" and not p.steps.is_empty():
			n += 1
	return n


## 창고 먹을 것 (밀 제외) — 다른 먹을 것이 이만큼 있으면 죽을 끓이지 않는다
static func _take(v: Village, k: String, need: float) -> float:
	var have := float(v.stock.get(k, 0.0))
	var take := minf(have, need)
	if take <= 0.0:
		return 0.0
	v.stock[k] = have - take
	gift_use(v, k, take)
	if k == "버섯":
		v.flora.on_eat(v, have, take)     # [하늘의 것] 섞인 얼룩버섯 조각도 같은 몫 (WORLD_EVENTS 2.6)
	return take


## 먹는다 — 먹은 몫(got, 소금으로 줄인 뒤 실제로 꺼낸 식량)을 돌려준다 (design/gdd/production-chain.md R2-3 계약).
## 낟알 → 창고 먹을 것 (FOODS 순서) → 건물 앞의 빵 → 밀을 죽으로 (밀 1 → 0.75)
static func consume(v: Village, need: float) -> float:
	var eff := need * (Balance.SALT_SAVING if float(v.stock.get("소금", 0.0)) > 0.0 else 1.0)
	return maxf(0.0, eff - _eat(v, need))


## 옛 계약 (호환 — 한 줄 감싸기): 못 먹은 양 (소금으로 줄인 단위)
static func consume_unmet(v: Village, need: float) -> float:
	return _eat(v, need)


static func _eat(v: Village, need: float) -> float:
	if float(v.stock.get("소금", 0.0)) > 0.0:
		v.stock["소금"] = maxf(0.0, float(v.stock["소금"]) - need / 400.0)
		need *= Balance.SALT_SAVING
	for m: Dictionary in v.manna_batches:
		var take := minf(m["amt"], need)
		m["amt"] -= take
		need -= take
		if need <= 0.0:
			break
	if need > 0.0:
		for m: Dictionary in v.manna:
			var take := minf(m["amt"], need)
			m["amt"] -= take
			need -= take
			if need <= 0.0:
				break
	for k: String in Balance.FOODS_ALL:   # 알(잔치)이 먼저 · 단물·씨앗 우유는 맨 뒤 (평소엔 빵 반죽에 — E3-14)
		if need <= 0.0:
			break
		var got := _take(v, k, need)
		need -= got
		if k == "빵" and got > 0.0:
			v.ate_bread_t = v.t
		if k == "꿀" and got > 0.0:
			v.ate_honey_t = v.t
		if k == "빵" and need > 0.0:
			for b in v.buildings:
				if need <= 0.0:
					break
				var t2 := minf(float(b.out.get("빵", 0.0)), need)
				if t2 > 0.0:
					b.out["빵"] = float(b.out["빵"]) - t2
					need -= t2
					v.ate_bread_t = v.t
	if need > 0.0:                        # 죽 — 밀을 끓인다 (손실)
		var wneed := need / Balance.PORRIDGE_YIELD
		var w := _take(v, Balance.PORRIDGE, wneed)
		if w < wneed - 1e-9:
			w += _take(v, "밀가루", wneed - w)       # 밀가루도 죽으로 (빵을 굽지 못할 때)
		for b in v.buildings:
			if w >= wneed - 1e-9:
				break
			var t3 := minf(float(b.out.get(Balance.PORRIDGE, 0.0)), wneed - w)
			if t3 > 0.0:
				b.out[Balance.PORRIDGE] = float(b.out[Balance.PORRIDGE]) - t3
				w += t3
		if w > 0.0:
			v.ate_porridge_t = v.t
		need -= w * Balance.PORRIDGE_YIELD
	if need > 1e-6:                       # (2026-11-11 Q7-b) 그래도 모자라면 창고로 오는 길의 것 — 수레의 밀·바구니 (맨 끝에)
		need = _eat_way(v, need)
	if need > 1e-6:                       # … 그것도 없으면 맷돌간에 부려 둔·맷돌간으로 가는 (아직 갈지 않은) 밀을 죽으로
		need = _eat_mill(v, need)
	v.manna_batches = v.manna_batches.filter(func(m: Dictionary) -> bool: return m["amt"] > 0.001)
	return need if need > 1e-6 else 0.0     # 죽 나눗셈의 부스러기는 굶주림이 아니다


# ───────────────────────── 창고로 오는 길의 먹을 것 (2026-11-11 Q7-b · docs/measure/opening_food_b_2026-11-11.md) ─────────────────────────
## 나르는 사람이 창고에 내려놓으려고 잡은 먹을 것 — 밭·화덕 앞에서 덜어 낸 수레(ResidentAI._haul_out · work_task: "put" → "stock_add")와
## 손에 든 채집 바구니("store_put"). 건물 앞에서는 떠날 때 이미 빠졌고 창고에는 아직 없어서, 재 보니 창고가 비는 아침은 대개
## '밀은 있는데 길 위에 있어서'였다. 이 몫도 마을의 먹을 것으로 친다: 다른 것이 다 떨어졌을 때 맨 끝에 먹고, 먹은 만큼 내려놓을 짐이 준다.
## 가공 건물(맷돌간·화덕) 입구로 가는 짐은 치지 않는다 (가루·빵이 될 몫). 사람 순서 · 걸음 순서대로 — 난수 없음.
## 걸음 s가 그런 짐이면 물건 이름, 아니면 ""
static func _way_kind(r: Resident, s: Dictionary) -> String:
	if String(s.get("k", "")) != "do" or not (s.get("done") is Dictionary):
		return ""
	var d: Dictionary = s["done"]
	var k := ""
	match String(d.get("op", "")):
		"put":
			var drop: Variant = d.get("drop")
			if drop is Dictionary and String((drop as Dictionary).get("op", "")) == "stock_add" and float((drop as Dictionary).get("amt", 0.0)) > 0.0:
				k = String((drop as Dictionary)["k"])
		"store_put":
			if r.carry_amt > 0.0 and r.carry == String(d.get("k", "")) and float(d.get("amt", 0.0)) <= 0.0:
				k = r.carry
	if k == Balance.PORRIDGE or k == "밀가루" or k in Balance.FOODS_ALL:
		return k
	return ""


## 창고로 오는 길의 먹을 것 (식량 단위 — 밀·밀가루는 죽 값). food_total에는 넣지 않는다 (촌장·출산 문·화면이 보는 '창고'는 그대로)
static func food_on_way(v: Village) -> float:
	var n := 0.0
	for r in v.people:
		for s: Dictionary in r.steps:
			var k := _way_kind(r, s)
			if k == "":
				continue
			var amt := r.carry_amt if String(s["done"]["op"]) == "store_put" else float(s["done"]["drop"]["amt"])
			n += amt * (Balance.PORRIDGE_YIELD if (k == Balance.PORRIDGE or k == "밀가루") else 1.0)
	return n


## 오는 길의 것을 먹는다 — 먹을 것(빵·버섯 …) 먼저, 그다음 밀·밀가루를 죽으로. 남은 못 먹은 양을 돌려준다
static func _eat_way(v: Village, need: float) -> float:
	for porridge: bool in [false, true]:
		for r in v.people:
			for i in r.steps.size():
				if need <= 1e-6:
					return need
				var s: Dictionary = r.steps[i]
				var k := _way_kind(r, s)
				if k == "" or (k == Balance.PORRIDGE or k == "밀가루") != porridge:
					continue
				var d: Dictionary = s["done"]
				var hand := String(d["op"]) == "store_put"
				var have := r.carry_amt if hand else float(d["drop"]["amt"])
				var yld := Balance.PORRIDGE_YIELD if porridge else 1.0
				var take := minf(have, need / yld)
				if take <= 0.0:
					continue
				need -= take * yld
				if hand:
					r.carry_amt = have - take
				else:
					var drop: Dictionary = d["drop"]
					drop["amt"] = have - take
					var c: Variant = s.get("cancel")          # 그만둘 때 되돌릴 양도 (저장했다 불러오면 내려놓기와 따로인 묶음)
					if c is Dictionary and not is_same(c, drop) and String((c as Dictionary).get("op", "")) == "stock_add":
						(c as Dictionary)["amt"] = have - take
					var picked := true
					for j in i:                               # 아직 집어 들기 전이면 집을 양을, 들었으면 든 양을 줄인다
						var pd: Variant = (r.steps[j] as Dictionary).get("done")
						if pd is Dictionary and String((pd as Dictionary).get("op", "")) == "pick" and String((pd as Dictionary).get("item", "")) == k:
							(pd as Dictionary)["amt"] = have - take
							picked = false
					if picked and r.carry == k:
						r.carry_amt = have - take
				if porridge:
					v.ate_porridge_t = v.t
				elif k == "빵":
					v.ate_bread_t = v.t
				elif k == "꿀":
					v.ate_honey_t = v.t
	return need


## 밀을 가루로 가는 건물인가 (맷돌간·방앗간)
static func _grinds(b: Building) -> bool:
	var d := b.def()
	return d.has("in") and (d["in"] as Dictionary).has(Balance.PORRIDGE) and d.has("out") and (d["out"] as Dictionary).has("밀가루")


## 맷돌간의 밀 (2026-11-11 Q7-b): 아직 갈지 않은 밀 — 입구에 부려 둔 것 먼저, 그다음 맷돌간으로 가는 수레. 굶기 직전의 맨 마지막 죽이다
## (맷돌은 시간에 MILL 몫만 갈아서 한 수레가 몇 시간씩 입구에 쌓여 있다 — 재 보니 셋째 날 아침의 빈 창고는 '밤새 쌓인 밀이 통째로 맷돌간에 들어간 뒤'였다).
## 화덕의 가루는 건드리지 않는다 (빵이 될 몫). 건물 순서 · 사람 순서 · 걸음 순서대로 — 난수 없음. 남은 못 먹은 양을 돌려준다
static func _eat_mill(v: Village, need: float) -> float:
	var k := Balance.PORRIDGE
	var yld := Balance.PORRIDGE_YIELD
	for b in v.buildings:
		if need <= 1e-6:
			return need
		if not b.built or not _grinds(b):
			continue
		var have := float(b.in_buf.get(k, 0.0))
		var take := minf(have, need / yld)
		if take <= 0.0:
			continue
		b.in_buf[k] = have - take
		if b.gift_in.has(k):                          # 먹은 만큼 받은 몫(거인이 준 몫)도 준다
			b.gift_in[k] = minf(float(b.gift_in[k]), have - take)
		need -= take * yld
		v.ate_porridge_t = v.t
	for r in v.people:
		for i in r.steps.size():
			if need <= 1e-6:
				return need
			var s: Dictionary = r.steps[i]
			if String(s.get("k", "")) != "do" or not (s.get("done") is Dictionary) or String(s["done"].get("op", "")) != "put":
				continue
			var dv: Variant = s["done"].get("drop")
			if not (dv is Dictionary) or String((dv as Dictionary).get("op", "")) != "inbuf_put" or String((dv as Dictionary).get("k", "")) != k:
				continue
			var drop: Dictionary = dv
			var to: Building = drop["b"]
			if to == null or not _grinds(to):
				continue
			var have := float(drop["amt"])
			var take := minf(have, need / yld)
			if take <= 0.0:
				continue
			need -= take * yld
			to.in_inc[k] = maxf(0.0, float(to.in_inc.get(k, 0.0)) - take)
			for dct: Variant in [drop, s.get("cancel")]:      # 내려놓을 양 · 그만둘 때 되돌릴 양 (같은 묶음일 수도, 불러온 뒤엔 따로일 수도)
				if dct is Dictionary and String((dct as Dictionary).get("op", "")) in ["inbuf_put", "inbuf_undo"]:
					(dct as Dictionary)["amt"] = have - take
					(dct as Dictionary)["gift"] = minf(float((dct as Dictionary).get("gift", 0.0)), have - take)
			var picked := true
			for j in i:
				var pd: Variant = (r.steps[j] as Dictionary).get("done")
				if pd is Dictionary and String((pd as Dictionary).get("op", "")) == "pick" and String((pd as Dictionary).get("item", "")) == k:
					(pd as Dictionary)["amt"] = have - take
					picked = false
			if picked and r.carry == k:
				r.carry_amt = have - take
			v.ate_porridge_t = v.t
	return need


## 창고에서 상함 (새벽마다 하루 몫 — 표 하나 Balance.SPOIL_DAY, production-chain R4 · F4).
## 생선·고기는 소금이 있으면 × Wildlife.SALT_KEEP · 질그릇 항아리(발견 W2) × keep_mult. 생버섯은 섞인 얼룩버섯 조각도 같은 몫.
## 물건마다 그날 상한 양을 `spoiled` 사건으로
static func spoil(v: Village) -> void:
	var salt := float(v.stock.get("소금", 0.0)) >= Wildlife.SALT_MIN
	for k: String in Balance.SPOIL_DAY.keys() + Balance.KITCHEN_SPOIL.keys():    # 부엌 것은 따로 붙인 표 (E3-14)
		var have := float(v.stock.get(k, 0.0))
		if have <= 0.0:
			continue
		var p := float(Balance.SPOIL_DAY[k]) if Balance.SPOIL_DAY.has(k) else float(Balance.KITCHEN_SPOIL[k])
		if k == "생선" or k == "고기":
			p *= (Wildlife.SALT_KEEP if salt else 1.0) * Discovery.keep_mult(v)
		var lost := have * p
		v.stock[k] = have - lost
		gift_use(v, k, lost * float(v.gift.get(k, 0.0)) / have)
		if k == "버섯" and v.flora != null:
			v.flora.tainted *= 1.0 - p
		if lost > 1e-6:
			v.emit(&"spoiled", {"v": {"k": StringName(k), "amt": lost}})


## 행복: 지난 하루 빵을 먹었다 + · 죽만 먹었다 −
static func food_happy(v: Village) -> float:
	var honey := Balance.HONEY_HAPPY if v.t - v.ate_honey_t < Balance.DAY else 0.0     # 꿀을 먹은 날 + (R2-4)
	if v.t - v.ate_bread_t < Balance.DAY:
		return Balance.HAPPY_BREAD + honey + Kitchen.happy(v)     # 단물 빵·우유 빵·기름 빵 (E3-14)
	if v.t - v.ate_porridge_t < Balance.DAY:
		return Balance.HAPPY_PORRIDGE_ONLY + honey
	return honey


## 빵을 구운 적이 있나 (그 전까지 거인이 낟알 한 줌을 무료로 내려 준다)
static func bread_made(v: Village) -> bool:
	return int(v.stats.get("first_bread", 0)) > 0


## 배고픈데 아직 빵이 없으면 거인에게 안내 (위기 예고 띠 — 화면이 가져감). 먹을 것이 반나절치 아래로 떨어지면
static func hunger_hint(v: Village) -> void:
	if bread_made(v) or not v.aware or v.people.is_empty():
		return
	if v.t - v._hunger_hint_t < Balance.HUNGER_HINT_EVERY:
		return
	if food_total(v) >= day_need(v) * 0.5 and v.deficit <= 0.0:
		return
	v._hunger_hint_t = v.t
	v.warnings.append({"t": v.t, "kind": "hunger", "text": "배고파 보여요. 낟알을 곁에 내려 줘요"})
	var c := v.chief()
	if c != null and not c.sleeping:
		v.speak(c, "배가 고파요… 먹을 게 모자라요", 6)


# ───────────────────────── 바로 보냄 (production-chain R3) ─────────────────────────
## 가공 건물 입구의 가득 (한 수레 × IN_BUF_TRIPS — 수레 물건이 아니면 3)
static func in_cap(k: String) -> float:
	return float(Balance.BULK.get(k, 3.0)) * Balance.IN_BUF_TRIPS


## 이 아래로 떨어지면 채운다 (바로 보냄을 끄면 옛 방식: 가득에서 조금만 줄어도)
static func refill_low(v: Village, k: String) -> float:
	return in_cap(k) * (Balance.REFILL_AT if v.direct_route else 1.0)


## 입구 (안에 있는 것 + 오는 중)
static func in_have(b: Building, k: String) -> float:
	return float(b.in_buf.get(k, 0.0)) + float(b.in_inc.get(k, 0.0))


## 입구를 채울 건물인가 (지어졌고, 넓혀 짓는 중이 아니고, 재료로 k를 씀)
static func takes_input(b: Building, k: String) -> bool:
	if not b.built or b.upgrade_to != "":
		return false
	var d := b.def()
	return d.has("in") and (d["in"] as Dictionary).has(k)


## 건물 b 앞의 산출물 k를 바로 보낼 곳 — 입구가 refill_low 아래인 건물 중 가장 가까운 곳 (같으면 id가 작은 쪽).
## 없으면 null (창고로). 빵은 늘 창고로 (먹는 곳). 바로 보냄을 끄면 늘 null
static func dest_for(v: Village, b: Building, k: String) -> Building:
	if not v.direct_route or k == "빵":
		return null
	var best: Building = null
	var bd := INF
	for o in v.buildings:
		if o == b or not takes_input(o, k):
			continue
		if in_have(o, k) >= refill_low(v, k):
			continue
		var d := Vector2(o.x - b.x, o.y - b.y).length_squared()
		if d < bd - 1e-9 or (absf(d - bd) <= 1e-9 and best != null and o.id < best.id):
			bd = d
			best = o
	return best


# ───────────────────────── 막힘 (production-chain States · 사건 chain_stalled / chain_resumed) ─────────────────────────
## 건물 걸음마다: why = &"no_input"·&"no_worker"면 그 상태, &""면 돌아감·넉넉해서 쉼 (막힘 아님).
## 상태는 저장하지 않는다 (Village._stall — 불러온 첫 걸음엔 사건 없음, 처음부터 다시 잼)
static func stall_tick(v: Village, b: Building, why: StringName) -> void:
	var s: Dictionary = v._stall.get(b.id, {})
	if s.is_empty():
		s = {"why": &"", "since": v.t, "stalled": false, "at": 0.0, "ok": -1.0}
		v._stall[b.id] = s
	if why != &"":
		s["ok"] = -1.0
		if s["why"] != why:
			if not s["stalled"]:
				s["since"] = v.t
			s["why"] = why
		if not s["stalled"] and v.t - float(s["since"]) >= Balance.STALL_AFTER:
			s["stalled"] = true
			s["at"] = float(s["since"])
			v.emit(&"chain_stalled", {"v": {"b": b.id, "type": StringName(b.type), "why": why}})
		return
	s["why"] = &""
	if not s["stalled"]:
		s["since"] = v.t
		return
	if float(s["ok"]) < 0.0:
		s["ok"] = v.t
	elif v.t - float(s["ok"]) >= Balance.STALL_CLEAR:
		s["stalled"] = false
		s["since"] = v.t
		v.emit(&"chain_resumed", {"v": {"b": b.id, "secs": float(s["ok"]) - float(s["at"])}})
		s["ok"] = -1.0


## 첫 밀·첫 가루·첫 빵 (그 병에서 한 번씩 — stats에 표시)
static func first_made(v: Village, b: Building, w: Resident) -> void:
	var kind := &""
	var key := ""
	match b.type:
		"농장":
			kind = &"first_harvest"
			key = "first_wheat_ev"
		"맷돌간", "방앗간":
			kind = &"first_flour"
			key = "first_flour_ev"
		"화덕", "빵집":
			kind = &"first_bread"
			key = "first_bread_ev"
	if key == "" or int(v.stats.get(key, 0)) > 0:
		return
	v.stats[key] = 1
	v.emit(kind, {"who": w.id if w != null else -1, "v": {"b": b.id}})


# ───────────────────────── 거인이 준 몫 ─────────────────────────
static func gift_add(v: Village, k: String, amt: float) -> void:
	if amt > 0.0:
		v.gift[k] = float(v.gift.get(k, 0.0)) + amt


## 쓰거나 먹은 만큼 거인이 준 몫도 준다 (준 몫부터 쓴다)
static func gift_use(v: Village, k: String, amt: float) -> float:
	var g := float(v.gift.get(k, 0.0))
	if g <= 0.0 or amt <= 0.0:
		return 0.0
	var u := minf(g, amt)
	if g - u <= 1e-6:
		v.gift.erase(k)
	else:
		v.gift[k] = g - u
	return u


## 가공: 재료로 쓴 거인 몫을 가공품으로 옮긴다 (밀 → 가루 ×1 · 가루 → 빵 × BREAD_YIELD · 통나무 → 판자)
static func gift_move(v: Village, from: String, amt: float) -> void:
	var u := gift_use(v, from, amt)
	if u <= 0.0:
		return
	match from:
		"밀":
			gift_add(v, "밀가루", u)
		"밀가루":
			gift_add(v, "빵", u * Balance.BREAD_YIELD)
		"통나무":
			gift_add(v, "판자", u)


## 창고에서 마을이 스스로 만든 몫 (제물로 바칠 수 있는 몫)
static func own_stock(v: Village, k: String) -> float:
	return maxf(0.0, float(v.stock.get(k, 0.0)) - float(v.gift.get(k, 0.0)))


# ───────────────────────── 설계도 ─────────────────────────
## 이 병 주민이 그 건물을 지을 줄 아나 — 하나뿐인 기준 (상점 진열 · 촌장 · 어부 … 모두 이것을 본다. Balance.MUST_LEARN 위 설명):
## 처음부터 아는 것 · 설계도 · 시대 기본 (그 시대가 열렸으면) · 새로 배워야 하는 건물은 다음 계시가 오거나 스스로 깨쳤을 때
static func knows(v: Village, type: String) -> bool:
	if v.blueprints.has(type) or type in Balance.KNOWN_FROM_START:
		return true
	if not Balance.B.has(type):
		return false
	var e := int(Balance.B[type]["era"])
	if type in Balance.MUST_LEARN:
		if v.era > e or v.self_learned.has(type):
			return true                 # 다음 계시가 가르쳐 줌 (3b — 막히지 않음) · 스스로 깨침
		if v.era == e and self_learn_due(v, type):
			return true                 # 시대가 열린 지 MUST_LEARN_SELF_DAYS (연대기 한 줄은 self_learn)
		return Balance.LEARN_LATE.has(type) and v.t >= float(Balance.LEARN_LATE[type])
	return e <= v.era                   # 시대 기본 — 계시가 그 시대를 열면 바로 안다


## 새로 배워야 하는 건물을 스스로 깨칠 때가 됐나 — 그 시대가 열린 지 MUST_LEARN_SELF_DAYS (줄이 있는 건물만, 아직 못 짓는 것은 아님)
static func self_learn_due(v: Village, type: String) -> bool:
	if not Balance.SELF_LEARN_LINE.has(type) or Balance.B_LOCKED.has(type) or not Balance.B.has(type):
		return false
	if int(Balance.B[type]["era"]) != v.era:
		return false
	return v.t - v.era_t >= Balance.MUST_LEARN_SELF_DAYS * Balance.DAY


## 스스로 깨친 건물을 적어 두고 연대기 한 줄 (촌장이 터를 볼 때마다 — Village.chief_build). 설계도로 이미 안 것은 조용히
static func self_learn(v: Village) -> void:
	for ty: String in Balance.SELF_LEARN_LINE:
		if v.self_learned.has(ty) or not self_learn_due(v, ty):
			continue
		v.self_learned[ty] = v.t
		if not v.blueprints.has(ty):
			v.log_line(String(Balance.SELF_LEARN_LINE[ty]))


## 설계도를 살 수 있는 건물인가 (새로 배워야 하는 건물이고, 그 시대가 열렸고, 아직 모름) — 까닭 (비면 살 수 있음)
static func blueprint_lock(v: Village, type: String) -> String:
	if not Balance.SHOP.has(type) or not Balance.B.has(type):
		return "곧"
	if Balance.B_LOCKED.has(type):
		return String(Balance.B_LOCKED[type])
	if int(Balance.B[type]["era"]) > v.era:
		return "곧"
	if knows(v, type):
		return "이미 알아요"
	return ""


## 상점 건물 탭에 내놓나 — 새로 배워야 하는 건물 중 그 시대가 열렸고 주민이 아직 모르는 것만 (2026-11-08 사용자).
## 아직 못 짓는 것 (목장·방직소·대장간 — B_LOCKED)은 '곧'으로 보인다
static func blueprint_offered(v: Village, type: String) -> bool:
	if not type in Balance.MUST_LEARN or knows(v, type):
		return false
	var e := int(Balance.B[type]["era"]) if Balance.B.has(type) else int(Shop.BUILDING_ERA.get(type, 0))
	return e <= v.era


## 설계도를 내려 준다 (지폐는 부르는 쪽이 이미 냄) — 주민이 지을 줄 알게 되고 촌장이 곧바로 첫 터를 잡는다. 잡은 터 (없으면 null)
static func give_blueprint(v: Village, type: String) -> Building:
	if v.blueprints.has(type) or not Balance.B.has(type):
		return null
	v.blueprints[type] = v.t
	var lb := Balance.label(type)
	var c := v.chief()
	if v.aware:
		v.log_line("하늘에서 커다란 그림 종이가 내려왔다. 사람들은 그것을 보고 %s 짓는 법을 알았다." % lb)
	else:
		v.log_line("하늘에서 커다란 그림 종이가 내려왔다. 펼쳐 보니 %s 짓는 법이 그려져 있었다." % lb)
	if c != null:
		v.speak(c, "이렇게 지으면 되는구나!", 7)
	v.bless_all(Balance.WISH_BELIEF)
	v._update_belief(0.0)
	v.wishes.erase(type)
	for l: Dictionary in v.letters:
		if l["kind"] == "wish" and l["type"] == type and l["state"] == "open":
			l["state"] = "done"
	Awakening.witness(v, "drop")
	v.giant_acted()
	if not VillageEra.can_build(v, type):
		return null
	var spot: Variant = v.find_spot(type)
	if spot == null:
		return null
	var sp: Vector2 = spot
	var nb := v.add_building(type, sp.x, sp.y, false)
	nb.wished = true                      # 첫 터는 먼저 나르고 서둘러 짓는다
	var cn := c.name if c != null else ""
	v.log_line("촌장 %s%s 그림 종이대로 %s 자리를 정했다." % [cn, Village.josa(cn, "이", "가"), lb])
	return nb


# ───────────────────────── 아기 돌봄 (GD 7.3) ─────────────────────────
## 이 사람이 집에서 아기를 돌보는 중이면 그 아기 (아니면 null)
static func caring_for(v: Village, r: Resident) -> Resident:
	if not r.is_adult() or r.home < 0 or v.in_opening() or v.staged():
		return null                       # 첫 한 시간·제단 짓기 장면엔 온 마을이 함께 (아기는 품에 안고)
	for q in v.people:
		if q.age < Balance.CARE_DAYS and q.home == r.home and r.id in q.parents:
			if r.sex == "m" and q.age >= Balance.CARE_ELDER_DAYS and _elder_home(v, r.home):
				return null               # 할머니·할아버지가 같은 집에 있으면 아빠는 일찍 일터로
			var ft := v.food_total()
			if r.sex == "m" and ft < Balance.BIRTH_FOOD_DAYS * day_need(v):
				return null               # 먹을 것이 모자라면 아빠는 밭으로 (꼭 필요한 일 — GD 7.3)
			if ft < day_need(v):
				return null               # 하루치도 안 남으면 엄마도 번갈아 일터로 (아기는 이웃·노인이 봄)
			return q
	return null


static func _elder_home(v: Village, home: int) -> bool:
	for q in v.people:
		if q.home == home and q.is_elder():
			return true
	return false
