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


## 거인 묶음에 넣을 몫 (GameSave.giant_payload가 같은 칸 이름으로 합침)
func to_dict() -> Dictionary:
	return {"firsts": firsts.to_dict(), "souvenirs": souvenirs.duplicate(true)}


## 거인 묶음에서 다시 채운다 — 인스턴스는 바꿔 끼우지 않는다 (화면이 들고 있음). 옛 저장(firsts 없음) → 모두 본 것·모두 열림
func from_dict(gp: Dictionary) -> void:
	firsts.from_dict(gp.get("firsts", null))
	souvenirs = []                                   # 옛 거인 묶음(칸 없음) → 빈 선반
	var list: Variant = gp.get("souvenirs", null)
	if list is Array:
		for s: Variant in list:
			if s is Dictionary and (s as Dictionary).has("id"):
				add_souvenir((s as Dictionary).duplicate(true))


## 기념품 하나를 더한다 — 같은 병의 같은 고비(key)는 한 번만. 더했으면 true
func add_souvenir(rec: Dictionary) -> bool:
	var key := String(rec.get("key", ""))
	if not key.is_empty():
		for s: Dictionary in souvenirs:
			if String(s.get("key", "")) == key:
				return false
	souvenirs.append(rec)
	return true


func reset() -> void:
	firsts.reset()
	souvenirs = []
