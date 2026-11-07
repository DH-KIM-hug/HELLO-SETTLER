## 거인의 장터와 지갑 — 기획서 11.1 · BALANCE v3-1·v3-2. 병 밖(거인의 세상)의 것이라 **모든 병이 함께 쓴다** (static).
## 지폐 = 거인(플레이어)의 돈. 부락의 돈(주화)과는 다르다.
## 값: 같은 물건 n번째 단가 = 기본가 × 0.5^((n−1)/60). '그날' = 현실 하루 (기기 날짜), 모든 병 합산.
## 저장·불러오기는 GameSave의 거인 묶음 (save/save_manager.gd).
## 거인의 등불 (SAVE.md 3 v1.1 · SHOP.md): 거인이 자리를 비운 동안 병이 흐르는 시간 — 12시간, 지폐로 16 → 20 → 24시간 (영구, 모든 병).
class_name Market
extends RefCounted

static var notes := 0.0               # 지폐
static var sold: Dictionary = {}      # 그날 물건별 거둔 개수
static var day_key := ""              # sold가 세는 현실 날짜
static var today_override := ""       # 테스트: 비어 있지 않으면 이 날짜를 '오늘'로
static var first_paid := false        # 첫 제물 웃돈을 받았다 (BALANCE v4-4 — 거인에게 한 번, Village.take_offering)
static var lamp_level := 0            # 등불 단계 0~3 (LAMP_HOURS)
static var hand: Array = []           # 거인의 손에 든 물건 (SHOP 3 — 상점에서 산 것, 최대 5개, 모든 병이 함께) {id, item, paid}
static var hand_serial := 0           # 손에 든 물건 번호
# 이주민 뽑기 (sim/immigrants.gd — 기획서 11.2 · SAVE 1 '이주민 뽑기 횟수(그날)'): 거인 묶음의 "draws"에 저장
static var mig_day := ""              # mig_n이 세는 현실 날짜
static var mig_n := 0                 # 그날 뽑은 횟수 (하루 5번 · 값 ×1.5씩)
static var mig_serial := 0            # 지금까지 뽑은 횟수 (꾸러미 seed)
static var mig_seed := 0              # 거인의 뽑기 흐름 (0 = 처음 뽑을 때 정함)

const LAMP_HOURS := [12, 16, 20, 24]                       # 단계별 등불 시간 (비운 동안 병이 흐르는 최대 시간)
const LAMP_COST := [1500.0, 5000.0, 12000.0]               # 다음 단계 값 (지폐) — LAMP_COST[n] = n → n+1 (BALANCE v5 — 가격 연구 2장)
const LAMP_NAMES := ["큰 기름병", "더 큰 등잔", "거인의 램프"]


static func reset(start_notes := 0.0) -> void:
	notes = start_notes
	sold = {}
	day_key = ""
	first_paid = false
	lamp_level = 0
	hand = []
	hand_serial = 0
	mig_day = ""
	mig_n = 0
	mig_serial = 0
	mig_seed = 0


## 이주민 뽑기 상태 (저장 — 거인 묶음 "draws")
static func draws_dict() -> Dictionary:
	return {"day": mig_day, "n": mig_n, "serial": mig_serial, "seed": mig_seed}


static func set_draws(d: Dictionary) -> void:
	mig_day = String(d.get("day", ""))
	mig_n = int(d.get("n", 0))
	mig_serial = int(d.get("serial", 0))
	mig_seed = int(d.get("seed", 0))


# ───────────────────────── 거인의 등불 ─────────────────────────
## 지금 등불이 타는 시간 (시간)
static func lamp_hours() -> int:
	return int(LAMP_HOURS[clampi(lamp_level, 0, LAMP_HOURS.size() - 1)])


## 지금 등불이 타는 시간 (초) — 비운 시간 따라잡기의 상한 (CatchUp)
static func lamp_seconds() -> float:
	return float(lamp_hours()) * Balance.HOUR


## 다음 등불 {name, hours, cost} — 다 올렸으면 {}
static func next_lamp() -> Dictionary:
	if lamp_level >= LAMP_COST.size():
		return {}
	return {"name": LAMP_NAMES[lamp_level], "hours": int(LAMP_HOURS[lamp_level + 1]), "cost": float(LAMP_COST[lamp_level])}


## 등불을 한 단계 올린다 (지폐를 낸다). 못 사면 false — 저장은 부르는 쪽 (GameSave.buy_lamp_upgrade)
static func buy_lamp_upgrade() -> bool:
	var nx := next_lamp()
	if nx.is_empty() or not pay(float(nx["cost"])):
		return false
	lamp_level += 1
	return true


static func _today() -> String:
	if today_override != "":
		return today_override
	return Time.get_date_string_from_system()


static func _roll_day() -> void:
	var d := _today()
	if d != day_key:
		day_key = d
		sold = {}


static func base_price(item: String) -> float:
	return float(Balance.PRICE.get(item, 0.0))


## n번째(1부터) 단가
static func unit_price(item: String, nth: int) -> float:
	return base_price(item) * pow(0.5, float(nth - 1) / Balance.MARKET_HALF)


## 지금 amt개를 거두면 받을 값 (거두지는 않음)
static func quote(item: String, amt: int) -> float:
	_roll_day()
	if amt <= 0:
		return 0.0
	var n0 := int(sold.get(item, 0))
	var q := pow(0.5, 1.0 / Balance.MARKET_HALF)          # 등비 합 (v5 — 반값 600개라 한 번에 수천 개도 바로)
	return base_price(item) * pow(q, float(n0)) * (1.0 - pow(q, float(amt))) / (1.0 - q)


## amt개를 판다 → 받은 지폐 (지갑에 더함)
static func sell(item: String, amt: int) -> float:
	var v := quote(item, amt)
	sold[item] = int(sold.get(item, 0)) + amt
	notes += v
	return v


static func can_pay(cost: float) -> bool:
	return notes + 1e-6 >= cost


static func pay(cost: float) -> bool:
	if not can_pay(cost):
		return false
	notes -= cost
	return true
