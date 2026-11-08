## 건물 정보 카드의 장부 (docs/UI.md '건물 정보 카드') — 화면 쪽에서 보기만 한다 (ADR-0001: 시뮬레이션 결과를 바꾸지 않음, static 상태 없음).
##   - 오늘 만든 양: 일터 앞 더미(Building.out)가 늘어난 만큼을 병 하루(Village.day_no)마다 센다 (나르기로 줄어든 것은 세지 않음).
##     매 화면 한 번 읽으므로 한 화면 안에서 만들고 바로 나른 몫은 빠질 수 있다 — 거인에게 보이는 '대략 오늘 몇 개'.
##   - 지은 사람: 짓기 걸음(ResidentAI op "build")을 하던 주민을 그 터에 적어 둔다 (본 동안만 — 저장하지 않음).
## 쓰는 법: var led := BuildingLedger.new() → 매 화면 led.sample(village) → led.made_today(v, b) · led.builders(v, b)
class_name BuildingLedger
extends RefCounted

const MAX_BUILDERS := 6

var _last: Dictionary = {}       # Village → {건물 id → {물건: 지난번 더미 양}}
var _made: Dictionary = {}       # Village → {건물 id → {물건: 오늘 만든 양}}
var _day: Dictionary = {}        # Village → 센 날 (day_no)
var _builders: Dictionary = {}   # Village → {건물 id → Array[int] 주민 id (처음 본 순서)}


func sample(v: Village) -> void:
	if v == null:
		return
	var day := v.day_no()
	if int(_day.get(v, -1)) != day:
		_day[v] = day
		_made[v] = {}
	var last: Dictionary = _last.get(v, {})
	_last[v] = last
	var made: Dictionary = _made[v]
	for b in v.buildings:
		if not b.built or not b.def().has("out"):
			continue
		var seen := last.has(b.id)             # 처음 보는 건물은 지금 더미를 기준으로 (그 전에 만든 것은 모름)
		var lb: Dictionary = last.get(b.id, {})
		last[b.id] = lb
		for k: String in b.out:
			var now := float(b.out[k])
			var was := float(lb.get(k, 0.0 if seen else now))
			if now > was + 1e-6:
				var mb: Dictionary = made.get(b.id, {})
				made[b.id] = mb
				mb[k] = float(mb.get(k, 0.0)) + (now - was)
			lb[k] = now
	var bl: Dictionary = _builders.get(v, {})
	_builders[v] = bl
	for r in v.people:
		if r.action != "build" or r.steps.is_empty():
			continue
		for s: Variant in r.steps:
			if not (s is Dictionary) or String((s as Dictionary).get("k", "")) != "do":
				continue
			var d: Variant = (s as Dictionary).get("done")
			if d is Dictionary and String((d as Dictionary).get("op", "")) == "build" and (d as Dictionary).get("b") is Building:
				var bid := ((d as Dictionary)["b"] as Building).id
				var arr: Array = bl.get(bid, [])
				bl[bid] = arr
				if not arr.has(r.id) and arr.size() < MAX_BUILDERS:
					arr.append(r.id)
			break


## 오늘(병 하루) 이 건물이 만든 양 {물건: 양}
func made_today(v: Village, b: Building) -> Dictionary:
	if int(_day.get(v, -1)) != v.day_no():
		return {}
	return ((_made.get(v, {}) as Dictionary).get(b.id, {}) as Dictionary)


## 이 건물을 짓는 것을 본 주민 id (처음 본 순서)
func builders(v: Village, b: Building) -> Array:
	return ((_builders.get(v, {}) as Dictionary).get(b.id, []) as Array)


## 시험·캡처용: 지은 사람을 적어 둠
func note_builder(v: Village, b: Building, id: int) -> void:
	var bl: Dictionary = _builders.get(v, {})
	_builders[v] = bl
	var arr: Array = bl.get(b.id, [])
	bl[b.id] = arr
	if not arr.has(id):
		arr.append(id)
