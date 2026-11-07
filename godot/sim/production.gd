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
	for k in Balance.FOODS:
		n += float(v.stock.get(k, 0.0))
	for m: Dictionary in v.manna_batches:
		n += float(m["amt"])
	for m: Dictionary in v.manna:
		n += float(m["amt"])
	for b in v.buildings:
		n += float(b.out.get("빵", 0.0))
	return n + wheat_total(v) * Balance.PORRIDGE_YIELD


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


## 먹는다 — 못 먹은 양을 돌려준다. 낟알 → 창고 먹을 것 (FOODS 순서) → 건물 앞의 빵 → 밀을 죽으로 (밀 1 → 0.75)
static func consume(v: Village, need: float) -> float:
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
	for k: String in Balance.FOODS:
		if need <= 0.0:
			break
		var got := _take(v, k, need)
		need -= got
		if k == "빵" and got > 0.0:
			v.ate_bread_t = v.t
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
	v.manna_batches = v.manna_batches.filter(func(m: Dictionary) -> bool: return m["amt"] > 0.001)
	return need if need > 1e-6 else 0.0     # 죽 나눗셈의 부스러기는 굶주림이 아니다


## 창고에서 상함 (새벽마다 하루 몫 — 밀 3% · 가루 1% · 빵 0.4%)
static func spoil(v: Village) -> void:
	for k: String in Balance.SPOIL_DAY:
		var have := float(v.stock.get(k, 0.0))
		if have <= 0.0:
			continue
		var lost := have * float(Balance.SPOIL_DAY[k])
		v.stock[k] = have - lost
		gift_use(v, k, lost * float(v.gift.get(k, 0.0)) / have)


## 행복: 지난 하루 빵을 먹었다 + · 죽만 먹었다 −
static func food_happy(v: Village) -> float:
	if v.t - v.ate_bread_t < Balance.DAY:
		return Balance.HAPPY_BREAD
	if v.t - v.ate_porridge_t < Balance.DAY:
		return Balance.HAPPY_PORRIDGE_ONLY
	return 0.0


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
## 이 병 주민이 그 건물을 지을 줄 아나 — 처음부터 아는 것 · 계시로 배운 시대 건물 (마을 시대부터) · 설계도 · 스스로 깨친 것
static func knows(v: Village, type: String) -> bool:
	if v.blueprints.has(type) or type in Balance.KNOWN_FROM_START:
		return true
	if not Balance.B.has(type):
		return false
	if int(Balance.B[type]["era"]) >= 1:
		return true                     # 계시가 가르쳐 준 시대 건물 (지금은 시대가 열리면 그 시대 건물을 모두 안다)
	return v.t >= float(Balance.LEARN_LATE.get(type, 0.0))


## 설계도를 살 수 있는 건물인가 (그 시대가 열렸고, 아직 이 병에 없고, 처음부터 아는 것이 아님)
static func blueprint_lock(v: Village, type: String) -> String:
	if not Balance.SHOP.has(type) or not Balance.B.has(type):
		return "곧"
	if Balance.B_LOCKED.has(type):
		return String(Balance.B_LOCKED[type])
	if int(Balance.B[type]["era"]) > v.era:
		return "곧"
	if v.blueprints.has(type):
		return "이미 알아요"
	return ""


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
