## 창고 장부 — 마을 창고에 무엇이 얼마나 있고, 지난 병 하루 동안 얼마나 늘고 줄었나 (위 띠 아래 창고 띠 · 창고 시트가 함께 씀).
##   - 값은 숫자로 보여 준다 (마을 창고 — 숨긴 확률이 아님). 짧게: 980 · 1.2천 · 3.4만
##   - 하루 변화 = 만든 것 − 쓴 것 (지난 병 하루, 창고 양의 차이). 병 시간 1시간마다 한 번 적어 두고 하루 전 것과 비교 — 화면마다 새로 만들지 않음
##   - 식량 = 창고의 모든 먹을 것 (건량·빵·밀·생선·고기·버섯… + 낟알 + 일터 앞에 쌓인 밀·빵 — Village.food_total)
##   - 식량이 2일 안에 떨어질 것 같으면 부드러운 주의 색 (빨강은 쓰지 않음)
## 쓰는 법: var book := StoreBook.new() → book.sample(v) (자주 불러도 됨 — 1시간에 한 번만 적음) → book.day_change(v, "판자")
class_name StoreBook
extends RefCounted

const FOOD := "식량"                     # 띠의 식량 칸 (모든 먹을 것)
const BASE := [FOOD, "통나무", "판자", "돌"]
const EXTRA := ["소금", "양털", "털", "철", "밀가루", "옷"]   # 시대에 따라 — 있거나 만드는 곳이 있으면 띠에
const WARN_DAYS := 2.0                   # 이보다 적게 남으면 식량 칸이 주의 색
const SAMPLE := Balance.HOUR             # 이만큼마다 한 번 적음
const GROUPS := [
	["먹을 것", ["빵", "건량", "설탕", "쌀", "밀", "생선", "고기", "버섯", "말린 버섯", "민들레 잎", "낟알", "우유", "치즈", "달걀", "꿀", "채소", "사과", "포도"]],
	["재료", ["통나무", "판자", "돌", "물", "밀가루", "소금", "솜", "먼지 실", "털", "양털", "가죽", "뿔", "철광석", "석탄", "철"]],
	["도구·옷", ["도구", "옷"]],
	["특별한 것", ["빛버섯", "꽃잎", "노란 물감", "붉은 물감", "약초", "푸른 가루", "곰팡이약", "맥주", "포도주"]]]
const NOTES := {"건량": "처음 가져온 오래가는 먹을 것이에요", "낟알": "하늘에서 내린 낟알이에요", "도구": "일하는 사람이 하나씩 들고 일해요",
	"물": "우물에서 길어 와요", "밀": "날로는 못 먹어요 — 죽으로 끓이면 4분의 3, 빵으로 구우면 1.5배", "빵": "오래 가고 먹으면 기뻐해요",
	"설탕": "하늘에서 내려온 단 덩어리예요", "쌀": "하늘에서 내려온 낟알이에요", "먼지 실": "회색 먼지 뭉치를 뜯어 자은 실이에요", "민들레 잎": "먹을 게 없을 때 마지막에 먹어요", "빛버섯": "밤에 은은하게 빛나요"}
const VERB := {"빵집": "구워요", "화덕": "구워요", "맷돌간": "빻아요", "농장": "거둬요", "나무꾼": "베어 와요", "채석장": "캐 와요", "제재소": "켜요", "방앗간": "빻아요",
	"어부": "낚아 와요", "사냥꾼": "잡아 와요", "버섯꾼": "따 와요", "약초꾼": "캐 와요", "소금밭": "모아요"}

var _log: Dictionary = {}                # Village → Array [{t, vals}] (오래된 것부터, 하루 조금 넘게)


## 짧은 숫자: 980 · 1.2천 · 12천은 1.2만 · 3.4만 · 12만
static func short(n: float) -> String:
	var a := absf(n)
	var sg := "-" if n < -0.5 else ""
	if a < 999.5:
		return sg + str(int(roundf(a)))
	if a < 9950.0:
		return sg + _dec(a / 1000.0) + "천"
	if a < 99500.0:
		return sg + _dec(a / 10000.0) + "만"
	return sg + str(int(roundf(a / 10000.0))) + "만"


static func _dec(x: float) -> String:
	var r := roundf(x * 10.0) / 10.0
	return str(int(r)) if is_equal_approx(r, roundf(r)) else "%.1f" % r


## 창고에 있는 양. FOOD = 모든 먹을 것. 밀·빵은 일터 앞에 쌓인 것까지, 낟알 = 주워 온 것 + 들판
static func amount(v: Village, k: String) -> float:
	if k == FOOD:
		return v.food_total()
	if k == "낟알":
		var n := 0.0
		for m: Dictionary in v.manna_batches:
			n += float(m["amt"])
		for m: Dictionary in v.manna:
			n += float(m["amt"])
		return n
	var a := float(v.stock.get(k, 0.0))
	if k == "밀" or k == "빵":
		for b in v.buildings:
			a += float(b.out.get(k, 0.0))
	return a


## 하루에 먹는 양 (사람 수 × 하루 끼니)
static func food_need(v: Village) -> float:
	var n := 0.0
	for p in v.people:
		n += p.f("food")
	return n * Balance.DAY / Balance.FOOD_IV


## 식량이 며칠 가나 (먹는 사람이 없으면 아주 큼)
static func food_days(v: Village) -> float:
	var need := food_need(v)
	return v.food_total() / need if need > 0.0 else 9999.0


static func food_warn(v: Village) -> bool:
	return food_days(v) < WARN_DAYS


## 띠에 보일 것 (순서대로 — 자리가 모자라면 뒤에서부터 뺌)
static func strip_keys(v: Village) -> Array:
	var out: Array = BASE.duplicate()
	for k: String in EXTRA:
		if amount(v, k) >= 1.0 or _makers(v, k) > 0:
			out.append(k)
	return out


## 그 물건을 만드는 (다 지은) 일터 수
static func _makers(v: Village, k: String) -> int:
	var tys: Array = _maker_types(k)
	var n := 0
	for b in v.buildings:
		if b.type in tys and b.built:
			n += 1
	return n


## 그 물건을 만드는 건물 종류 (v5 — 맷돌간·방앗간 / 공용 화덕·빵집)
static func _maker_types(k: String) -> Array:
	var ty: String = Balance.PRODUCER.get(k, "")
	if ty == "":
		return []
	return [ty] + Balance.PRODUCER_ALSO.get(k, [])


## 지금 그 물건을 만드는 건물 중 가장 큰 종류 (설명 글)
static func _maker_name(v: Village, k: String) -> String:
	var tys: Array = _maker_types(k)
	var best := ""
	for ty: String in tys:
		for b in v.buildings:
			if b.type == ty and b.built:
				best = ty
				break
	return best


## 창고 시트의 묶음: [[제목, [이름…]]…] — 창고에 1개 이상 있는 것은 모두 어딘가에 (모르는 것은 '특별한 것')
static func groups(v: Village) -> Array:
	var seen := {}
	var out: Array = []
	for g: Array in GROUPS:
		var ks: Array = []
		for k: String in g[1]:
			seen[k] = true
			if amount(v, k) >= 1.0:
				ks.append(k)
		out.append([g[0], ks])
	for k: String in v.stock:
		if not seen.has(k) and float(v.stock[k]) >= 1.0:
			(out[3][1] as Array).append(k)
	return out


## 한 줄 설명 ("빵집 2곳에서 구워요 · 하루 12개 늘었어요" 식)
static func note(v: Village, k: String, change: float) -> String:
	var n := _makers(v, k)
	var ty := _maker_name(v, k)
	var who := ""
	if n > 0:
		who = "%s%s %s" % [Balance.label(ty), (" %d곳에서" % n) if n > 1 else "에서", VERB.get(ty, "만들어요")]
	var d := int(roundf(change))
	if who != "":
		if d > 0:
			return "%s · 하루 %s개 늘었어요" % [who, short(d)]
		if d < 0:
			return "%s · 쓰는 게 더 많아 하루 %s개 줄었어요" % [who, short(-d)]
		return who
	if NOTES.has(k):
		return NOTES[k]
	if d < 0:
		return "만드는 곳이 없어 쓰는 만큼 줄어요"
	if d > 0:
		return "하루 %s개 늘었어요" % short(d)
	return "창고에 두고 있어요"


## 늘었나 줄었나: 1 ▲ · -1 ▼ · 0 그대로 (작은 흔들림은 무시)
static func trend(change: float, value: float) -> int:
	var th := maxf(1.0, absf(value) * 0.02)
	if change >= th:
		return 1
	if change <= -th:
		return -1
	return 0


# ───────────────────────── 하루 변화 (병 1시간마다 적어 둠) ─────────────────────────
func sample(v: Village) -> void:
	var lg: Array = _log.get(v, [])
	if not _log.has(v):
		_log[v] = lg
	if not lg.is_empty():
		var last: float = lg[lg.size() - 1]["t"]
		if v.t < last - 1.0:                  # 시간이 거꾸로 (다른 병) — 다시 적음
			lg.clear()
		elif v.t - last < SAMPLE:
			return
	lg.append({"t": v.t, "vals": _vals(v)})
	while lg.size() > 1 and float(lg[1]["t"]) <= v.t - Balance.DAY:   # 하루 전 기록 하나는 남긴다
		lg.pop_front()


## 지금 기록 (모든 물건 + 식량 합)
func _vals(v: Village) -> Dictionary:
	var d := {}
	for k: String in v.stock:
		d[k] = amount(v, k)
	d[FOOD] = v.food_total()
	d["낟알"] = amount(v, "낟알")
	return d


## 지난 하루 (기록이 하루가 안 되면 있는 만큼) 동안의 변화 = 지금 − 하루 전
func day_change(v: Village, k: String) -> float:
	var lg: Array = _log.get(v, [])
	if lg.is_empty():
		return 0.0
	return amount(v, k) - float((lg[0]["vals"] as Dictionary).get(k, 0.0))


## 기록이 덮는 시간 (초)
func span(v: Village) -> float:
	var lg: Array = _log.get(v, [])
	return v.t - float(lg[0]["t"]) if not lg.is_empty() else 0.0


func forget(v: Village) -> void:
	_log.erase(v)
