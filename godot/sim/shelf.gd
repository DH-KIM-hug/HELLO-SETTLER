## 거인의 선반 (UI 05 · 기획서 12 · 5.5 · BALANCE v3-4 통합표 · v4-2) — 병 밖(거인)의 규칙만. 저장은 GameSave (거인 묶음 giant).
##   새 병: 지폐로만 — 두 번째 5,000 · 세 번째 25,000 · 네 번째부터 60,000 (JAR_PRICES, BALANCE v5 — Q24). 운영할 수 있는 병 수 = 선반 슬롯 (MAX_JARS, 안).
##   기후: 한 병 = 한 기후대 (5.2). 지금 세상이 다르게 자라는 기후는 온대뿐 → 나머지는 '곧' (5.3 해금 조건은 그 기후가 생기면).
##   키트 업그레이드 (영구 — 모든 새 세상): Kits.UPGRADES의 값. 그 건물을 한 번이라도 지어 본 뒤 열림 (UNLOCK_BY) · 산 것은 끄고 켤 수 있다.
## giant 사전의 칸: "upgrades" 산 업그레이드 이름 (여러 번 산 것은 그만큼) · "upgrades_off" 끈 이름 · "built" 지어 본 건물 종류 ·
##   "pending_jar" 사 두고 아직 만들지 않은 빈 병 {climate, paid, unix}
class_name Shelf
extends RefCounted

const JAR_PRICES := [5000.0, 25000.0, 60000.0]     # BALANCE v5 (가격 연구 2장 — 둘째 병 현실 6~8일차)     # 두 번째 · 세 번째 · 네 번째부터
const MAX_JARS := 5                                 # 선반 슬롯 (안)
## 기후대 (기획서 5.2 순서) — ready = 그 기후의 세상이 지금 만들어지는가 (작물·집 양식·위기가 기후마다 다른 것은 아직 → 온대만)
const CLIMATES := [["온대", true], ["냉대", false], ["아열대", false], ["열대", false], ["툰드라", false], ["사막", false]]
## 키트 업그레이드가 열리는 건물 (그 건물을 한 번이라도 지어 본 뒤 — GD 5.5). 없으면 언제나 열림
const UNLOCK_BY := {"밀밭": "농장", "목조 주택": "목조주택"}
const UPGRADE_ORDER := ["밀밭", "목조 주택", "가족 하나 더", "암반 컵 하나 더"]


## 선반에 병이 n_jars개일 때 다음 병 값
static func jar_price(n_jars: int) -> float:
	return float(JAR_PRICES[clampi(n_jars - 1, 0, JAR_PRICES.size() - 1)])


## 새 병을 살 수 있는가 → {ok, why, price}
static func can_buy_jar(giant: Dictionary, n_jars: int) -> Dictionary:
	var price := jar_price(n_jars)
	if giant.has("pending_jar"):
		return {"ok": false, "why": "사 둔 빈 병이 있어요", "price": price}
	if n_jars >= MAX_JARS:
		return {"ok": false, "why": "선반이 가득 찼어요", "price": price}
	if not Market.can_pay(price):
		return {"ok": false, "why": "지폐가 모자라요", "price": price}
	return {"ok": true, "why": "", "price": price}


## 고를 수 있는 기후 [{name, ready}] — 지금은 온대만 ready
static func climate_choices() -> Array:
	var out: Array = []
	for c: Array in CLIMATES:
		out.append({"name": c[0], "ready": bool(c[1])})
	return out


static func climate_ready(name: String) -> bool:
	for c: Array in CLIMATES:
		if c[0] == name:
			return bool(c[1])
	return false


# ───────────────────────── 키트 업그레이드 ─────────────────────────
static func owned(giant: Dictionary, name: String) -> int:
	var n := 0
	for u: Variant in giant.get("upgrades", []):
		if String(u) == name:
			n += 1
	return n


static func built_ever(giant: Dictionary, kind: String) -> bool:
	return kind in (giant.get("built", []) as Array)


static func unlocked(giant: Dictionary, name: String) -> bool:
	return not UNLOCK_BY.has(name) or built_ever(giant, String(UNLOCK_BY[name]))


## 잠긴 까닭 한 줄 ("밀밭을 한 번 지어 보면 열려요" — 건물 이름은 Balance.label)
static func unlock_hint(name: String) -> String:
	if not UNLOCK_BY.has(name):
		return ""
	var b := String(UNLOCK_BY[name])
	var shown := "목조 주택" if b == "목조주택" else Balance.label(b)
	return "%s%s 한 번 지어 보면 열려요" % [shown, Village.josa(shown, "을", "를")]


static func is_on(giant: Dictionary, name: String) -> bool:
	return owned(giant, name) > 0 and not name in (giant.get("upgrades_off", []) as Array)


## 카드에 보일 상태 {owned, max, price(다음 값, 더 못 사면 −1), unlocked, on, what}
static func upgrade_state(giant: Dictionary, name: String) -> Dictionary:
	var u: Dictionary = Kits.UPGRADES.get(name, {})
	var n := owned(giant, name)
	return {"owned": n, "max": int(u.get("max", 1)), "price": Kits.upgrade_price(name, n), "unlocked": unlocked(giant, name),
		"on": is_on(giant, name), "what": String(u.get("what", ""))}


## 업그레이드 하나 사기 (지폐를 냄) — 열리지 않았거나 다 샀거나 지폐가 모자라면 false. 저장은 부르는 쪽 (GameSave.buy_upgrade)
static func buy_upgrade(giant: Dictionary, name: String) -> bool:
	if not Kits.UPGRADES.has(name) or not unlocked(giant, name):
		return false
	var price := Kits.upgrade_price(name, owned(giant, name))
	if price < 0 or not Market.pay(float(price)):
		return false
	var ups: Array = (giant.get("upgrades", []) as Array).duplicate()
	ups.append(name)
	giant["upgrades"] = ups
	set_on(giant, name, true)
	return true


## 산 업그레이드를 끄고 켬 (다음 새 세상부터)
static func set_on(giant: Dictionary, name: String, on: bool) -> void:
	var off: Array = (giant.get("upgrades_off", []) as Array).duplicate()
	if on:
		off.erase(name)
	elif not name in off:
		off.append(name)
	giant["upgrades_off"] = off


## 새 세상에 함께 놓일 업그레이드 (Kits.make에 넘김) — 산 것 중 켠 것만, 산 횟수만큼
static func active_upgrades(giant: Dictionary) -> Array:
	var out: Array = []
	var off: Array = giant.get("upgrades_off", [])
	for u: Variant in giant.get("upgrades", []):
		if not String(u) in off:
			out.append(String(u))
	return out


## 지어 본 건물을 거인 묶음에 적는다 (병 안 모든 무리의 다 지은 건물) — 바뀌었으면 true
static func note_built(giant: Dictionary, villages: Array) -> bool:
	var have: Array = (giant.get("built", []) as Array).duplicate()
	var changed := false
	for q: Village in villages:
		for b: Building in q.buildings:
			if b.built and not b.type in have:
				have.append(b.type)
				changed = true
	if changed:
		giant["built"] = have
	return changed
