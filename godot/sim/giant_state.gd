## 별지기(거인) 단위 상태 — ADR-0001 5절 'Giant' 행선지. 병이 아니라 별지기에게 속한 것을 인스턴스로 담는다 (static 금지).
## 지금 담는 것: 처음 겪는 사건 안내·열린 손 도구 (Firsts — design/gdd/notebook.md R8·N2).
## 지갑(Market의 지폐·손에 든 물건·등불·뽑기)은 아직 Market static — 옮길 자리 (systems-index #22, 다른 담당).
## 게임: SaveManager(GameSave)가 하나를 가진다 (GameSave.player) — 저장은 거인 묶음 giant.dat의 "firsts" 칸 (옛 저장 그대로 읽힘).
## 시험: GiantState.new()를 저마다 — 시험 둘을 이어 돌려도 섞이지 않는다.
class_name GiantState
extends RefCounted

var firsts := Firsts.new()
## (Q17) 별지기가 주운 기념품 — 주운 차례. {id 고비, jar 지구 이름, day 병 며칠째, maker 만든 주민(모르면 없음), unix 주운 현실 시각, key 병+고비 (겹침 막이)}
## 병을 사고·바꾸고·끝내도 남는다. 처음부터 다시 시작(reset)만 비운다.
var souvenirs: Array = []
## (Q19) 방금 주운 기념품의 key — 다음에 방(선반)이 보이면 선반이 그쪽으로 한 번 미끄러진다 (미끄러지기 시작하면 비운다). "" = 없음
var souvenir_glide := ""
## (Q19) 처음 주웠을 때의 한 줄("선반에 올려 두었어요…")을 이미 띄웠나 — 한 번만
var souvenir_hint := false
## (Q19) 이번 줍기에 그 한 줄을 띄울 차례 (저장하지 않는다 — 화면이 take_hint_due()로 가져감)
var _hint_due := false


## 거인 묶음에 넣을 몫 (GameSave.giant_payload가 같은 칸 이름으로 합침)
func to_dict() -> Dictionary:
	return {"firsts": firsts.to_dict(), "souvenirs": souvenirs.duplicate(true), "souvenir_glide": souvenir_glide, "souvenir_hint": souvenir_hint}


## 거인 묶음에서 다시 채운다 — 인스턴스는 바꿔 끼우지 않는다 (화면이 들고 있음). 옛 저장(firsts 없음) → 모두 본 것·모두 열림
## (Q19) 옛 저장(새 칸 없음): 기념품은 '아직 안 본 것'(seen 없음) · 미끄러질 것 없음 · 한 줄은 기념품이 이미 있으면 띄운 것으로
func from_dict(gp: Dictionary) -> void:
	firsts.from_dict(gp.get("firsts", null))
	souvenirs = []                                   # 옛 거인 묶음(칸 없음) → 빈 선반
	var list: Variant = gp.get("souvenirs", null)
	if list is Array:
		for s: Variant in list:
			if s is Dictionary and (s as Dictionary).has("id"):
				add_souvenir((s as Dictionary).duplicate(true))
	souvenir_glide = String(gp.get("souvenir_glide", ""))
	souvenir_hint = bool(gp.get("souvenir_hint", not souvenirs.is_empty()))
	_hint_due = false


## 기념품 하나를 더한다 — 같은 병의 같은 고비(key)는 한 번만. 더했으면 true
func add_souvenir(rec: Dictionary) -> bool:
	var key := String(rec.get("key", ""))
	if not key.is_empty():
		for s: Dictionary in souvenirs:
			if String(s.get("key", "")) == key:
				return false
	souvenirs.append(rec)
	return true


## (Q19) 방금 주웠다 (GameSave.take_souvenir) — 선반에 더하고, 다음에 방이 보이면 미끄러질 것으로 적고, 맨 처음이면 한 줄을 띄울 차례로.
## 더했으면 true
func pick_up(rec: Dictionary) -> bool:
	if not add_souvenir(rec):
		return false
	souvenir_glide = String(rec.get("key", ""))
	if not souvenir_hint:
		souvenir_hint = true
		_hint_due = true
	return true


## (Q19) 처음 주운 한 줄을 띄울 차례였으면 true (한 번 — 가져가면 꺼진다)
func take_hint_due() -> bool:
	var due := _hint_due
	_hint_due = false
	return due


## (Q19) 아직 안 본 기념품이 있나 (선반을 그쪽으로 밀어 본 적 없는 것)
static func is_seen(rec: Dictionary) -> bool:
	return bool(rec.get("seen", false))


## (Q19) 이 key의 기념품들을 '본 것'으로 — 바뀐 것이 있으면 true. 병·경이·손길은 건드리지 않는다 (별지기의 선반 일)
func mark_seen(keys: Array) -> bool:
	var changed := false
	for s: Dictionary in souvenirs:
		if not is_seen(s) and String(s.get("key", "")) in keys:
			s["seen"] = true
			changed = true
	return changed


func reset() -> void:
	firsts.reset()
	souvenirs = []
	souvenir_glide = ""
	souvenir_hint = false
	_hint_due = false
