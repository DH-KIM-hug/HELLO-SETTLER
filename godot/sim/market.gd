## 거인의 장터와 지갑 — 기획서 11.1 · BALANCE v3-1·v3-2. 병 밖(거인의 세상)의 것이라 **모든 병이 함께 쓴다** (static).
## 지폐 = 거인(플레이어)의 돈. 부락의 돈(주화)과는 다르다.
## 값: 같은 물건 n번째 단가 = 기본가 × 0.5^((n−1)/60). '그날' = 현실 하루 (기기 날짜), 모든 병 합산.
## 저장·불러오기는 아직 없음 — 앱을 다시 켜면 0부터 (열린 일).
class_name Market
extends RefCounted

static var notes := 0.0               # 지폐
static var sold: Dictionary = {}      # 그날 물건별 거둔 개수
static var day_key := ""              # sold가 세는 현실 날짜
static var today_override := ""       # 테스트: 비어 있지 않으면 이 날짜를 '오늘'로


static func reset(start_notes := 0.0) -> void:
	notes = start_notes
	sold = {}
	day_key = ""


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
	var n0 := int(sold.get(item, 0))
	var s := 0.0
	for i in amt:
		s += unit_price(item, n0 + i + 1)
	return s


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
