## 거인의 기념품 1차 (docs/ROADMAP.md Q17 · PROGRESSION 4.5 ③) — 고비(Milestones)를 넘을 때마다 주민이 작은 것 하나를 내어 놓는다.
## 병마다 고비 하나에 꼭 하나. 깨닫기 전(또는 제단이 서기 전)에는 어귀의 납작한 돌 위에, 깨달은 뒤 제단이 서면 제단 위에 놓여 기다린다.
## 별지기가 톡 하면 별지기의 것이 되어 (GameSave.take_souvenir → GiantState.souvenirs) 방의 선반에 놓인다.
##
## 상태는 Village.milestones["souvenirs"] = {"wait": [{id, day, who, name, t}], "made": [id…], "x", "y"} — 병과 함께 저장된다.
## 규칙: 사라지지 않는다 · 창고에서 아무것도 쓰지 않는다 · 난수를 뽑지 않는다 · 주민의 일과 걸음을 바꾸지 않는다.
## 줍기는 기적이 아니다 — 경이(Village.wonder)·그날 톡/등불 횟수·손길 사건(giant_acted)을 건드리지 않는다.
## static 함수만 (상태는 모두 Village 안 — ADR-0001).
class_name Souvenirs
extends RefCounted

const NAME := {
	"bread": "첫 빵 한 조각", "steps": "아기 발도장 잎", "pop12": "꽃목걸이", "grown": "눈금 새긴 나뭇가지",
	"green": "햇밀 이삭 하나", "pop20": "작은 등", "winter": "마른 꽃다발",
	"work20": "작은 나무 망치", "stone": "새 집 문패", "gen3": "함께 땋은 실 끈", "pop35": "말린 열매 꾸러미",     # (Q27)
	"names": "말린 벚꽃 한 가지",     # (Q31) 첫 이름 부르기
}
## 연대기 한 줄 (주민 쪽 말 — 숫자·지켜보는 이 이야기 없음). [이끈 주민이 있을 때, 없을 때] · {it} = 기념품 이름 + 을/를 · {itga} = 이름 + 이/가
const LINE_STONE := ["{n}{ga} {it} 어귀의 납작한 돌 위에 올려 두었다.", "어귀의 납작한 돌 위에 {itga} 놓였다."]
const LINE_ALTAR := ["{n}{ga} {it} 제단에 올렸다.", "제단에 {itga} 올라왔다."]


# ───────────────────────── 읽기 ─────────────────────────
static func _state(v: Village) -> Dictionary:
	var s: Variant = v.milestones.get("souvenirs", null)
	return s if s is Dictionary else {}


## 기다리는 기념품 (만든 차례). 읽기만 — 돌려받은 배열을 고치지 말 것
static func waiting(v: Village) -> Array:
	var w: Variant = _state(v).get("wait", null)
	return w if w is Array else []


static func is_waiting(v: Village, id: String) -> bool:
	for s: Dictionary in waiting(v):
		if String(s["id"]) == id:
			return true
	return false


## 놓이는 곳: 깨달은 뒤 제단이 섰으면 "altar", 아니면 "stone" (어귀의 납작한 돌)
static func place(v: Village) -> String:
	return "altar" if v.aware and v.altar_built else "stone"


## 연대기 줄. who_name = 이끈 주민 (없으면 "")
static func line(id: String, where: String, who_name: String) -> String:
	var pair: Array = LINE_ALTAR if where == "altar" else LINE_STONE
	var item := String(NAME.get(id, ""))
	var text := String(pair[1] if who_name.is_empty() else pair[0])
	text = text.replace("{itga}", item + Village.josa(item, "이", "가")).replace("{it}", item + Village.josa(item, "을", "를"))
	return text.replace("{n}", who_name).replace("{ga}", Village.josa(who_name, "이", "가"))


# ───────────────────────── 만들기 · 줍기 ─────────────────────────
## 고비 id를 넘었다 → 기념품 하나가 기다린다. rec = 그 고비의 기록 (Milestones passed[id]).
## quiet = 조용히 넘은 고비·옛 저장 (연대기 줄·사건 없음, 만든 사람 모름). 이미 만든 고비는 다시 만들지 않는다.
static func make(v: Village, id: String, rec: Dictionary, quiet: bool) -> void:
	if not NAME.has(id):
		return
	var s := _state(v)
	if s.is_empty():
		s = {"wait": [], "made": []}
		v.milestones["souvenirs"] = s
	if not (s.get("made", null) is Array):
		s["made"] = []
	if not (s.get("wait", null) is Array):
		s["wait"] = []
	var made: Array = s["made"]
	if made.has(id):
		return
	made.append(id)
	var who_name := "" if quiet else String(rec.get("name", ""))
	var item := {"id": id, "day": v.cal_day(float(rec.get("t", v.t))), "who": -1 if quiet else int(rec.get("who", -1)), "name": who_name, "t": v.t}
	(s["wait"] as Array).append(item)
	keep_spot(v)
	if quiet:
		return
	var where := place(v)
	v.log_line(line(id, where, who_name))
	v.emit(&"souvenir_made", {"who": int(item["who"]), "at": spot(v), "v": {"id": id, "place": where}})


## 별지기가 주웠다 → 기다리는 줄에서 뺀다 ({id, day, who, name, t} — 없으면 빈 사전). 연대기 줄 없음 · 경이와 손길 사건 없음
static func take(v: Village, id: String) -> Dictionary:
	var wait := waiting(v)
	for i in wait.size():
		var s: Dictionary = wait[i]
		if String(s["id"]) == id:
			var at := spot(v)
			wait.remove_at(i)
			v.emit(&"souvenir_taken", {"at": at, "v": {"id": id}})
			return s
	return {}


# ───────────────────────── 자리 ─────────────────────────
## 지금 놓여 있는 자리 (제단 또는 납작한 돌) — 사건의 at
static func spot(v: Village) -> Vector2:
	return v.altar_pos if place(v) == "altar" else stone_spot(v)


## 마을 이름 표지판 자리: 선 표지판이 있으면 그 자리 (그 자리에 건물·무덤이 들어섰으면 화면도 새 어귀로 옮긴다 — MilestoneView.wanted), 아니면 어귀
static func sign_spot(v: Village) -> Vector2:
	var rec: Dictionary = (v.milestones.get("passed", {}) as Dictionary).get("pop12", {})
	if rec.has("x"):
		var p := Vector2(float(rec["x"]), float(rec["y"]))
		if Milestones.spot_free(v, p):
			return p
	return Milestones.edge_spot(v)


## 적어 둔 돌 자리가 아직 쓸 만한가 (건물·무덤·물이 들어서지 않았고 표지판과 겹치지 않음)
static func stone_ok(v: Village, p: Vector2) -> bool:
	if not Milestones.spot_free(v, p):
		return false
	var rec: Dictionary = (v.milestones.get("passed", {}) as Dictionary).get("pop12", {})
	if rec.has("x") and Vector2(float(rec["x"]), float(rec["y"])).distance_to(p) < Balance.SOUVENIR_SIGN_MIN:
		return false
	return true


## 납작한 돌 자리. 적어 둔 자리가 쓸 만하면 그 자리, 아니면 새로 찾은 자리 — 읽기만 한다 (적는 것은 keep_spot)
static func stone_spot(v: Village) -> Vector2:
	var s := _state(v)
	if s.has("x"):
		var p := Vector2(float(s["x"]), float(s["y"]))
		if stone_ok(v, p):
			return p
	return find_spot(v)


## 표지판 자리 곁에서 정해진 어긋남을 앞에서부터 — 깨끗한 자리(spot_clear) → 꽃만 피한 자리(spot_open) → 설 수만 있는 자리(spot_free). 난수 없음
static func find_spot(v: Village) -> Vector2:
	var a := sign_spot(v)
	var open := Vector2.INF
	var bare := Vector2.INF
	for off: Vector2 in Balance.SOUVENIR_STONE_OFFSETS:
		var p := a + off
		if not Milestones.spot_free(v, p):
			continue
		if bare.x > 1.0e8:
			bare = p
		if not Milestones.spot_open(v, p):
			continue
		if open.x > 1.0e8:
			open = p
		if Milestones.spot_clear(v, p):
			return p
	if open.x < 1.0e8:
		return open
	return bare if bare.x < 1.0e8 else a + (Balance.SOUVENIR_STONE_OFFSETS[0] as Vector2)


## 돌 자리를 적어 둔다 — 처음 쓸 때, 그리고 적어 둔 자리에 건물·무덤·표지판이 들어섰을 때만 다시 찾는다.
## (Milestones.step이 병의 날이 바뀔 때 · 기념품을 만들 때 부른다. 기다리는 것이 없으면 아무것도 하지 않는다)
static func keep_spot(v: Village) -> void:
	var s := _state(v)
	if s.is_empty() or waiting(v).is_empty():
		return
	if s.has("x") and stone_ok(v, Vector2(float(s["x"]), float(s["y"]))):
		return
	var p := find_spot(v)
	s["x"] = p.x
	s["y"] = p.y
