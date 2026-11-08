## 떨어진 물건 — 큰 세상의 잡동사니 (GAME_DESIGN 3.0 표 · ROADMAP E3-16 · STORY 1).
## 병 흙에 처음부터 몇 개 묻혀 있다 (창조 때 섞여 옴): 단추·유리구슬·병뚜껑·각설탕·성냥개비.
## 주민은 그게 무엇인지 안다 (지구에서 온 사람들) — 놀라는 것은 정체가 아니라 **크기**. 큰 존재·하늘은 말하지 않는다.
##
## 묻기: 넓은 세상은 WorldGen.generate 끝에 bury(ww) — 좋은 키트 자리(ww.spots)마다 둘레 고리(FIND_RING)에 2~3개.
##        작은 시험 병(Village.new_prototype)은 bury_local(v) — 마을 둘레에.
##        결정론: 세상 씨앗에서 나온 따로 쓰는 난수 (마을 rng·다른 흐름을 건드리지 않음). static 상태 없음 (ADR-0001).
## 찾기: 매시간(hourly) 묻힌 물건 둘레 NEAR_R 안에서 일하던·돌아다니던 사람이 있으면 그 시간이 쌓이고,
##        NOTICE_HOURS가 차거나 누가 DIG_R 안에 있으면 그 사람이 찾는다 (사람 id 순 — 난수 없음).
##        사건 &"found_object" + 연대기 한 줄 + 말풍선 하나.
## 쓰임: MOVE_AFTER 뒤 마을 쪽으로 옮겨 장식이 된다 — 단추 = 모닥불 곁 마을 탁자 · 구슬 = 광장 표지 (제단이 서면 제단 곁으로) ·
##        병뚜껑 = 집 곁 목욕통 · 각설탕 = 창고 곁 잔치 (날마다 갉아 먹음, 아이 행복 조금, 물 뿌림·짙은 이슬에 녹음) ·
##        성냥개비 = 가까운 개울을 건너는 다리 (없으면 창고 곁 대들보).
## 상태는 목록의 사전에 (넓은 세상 = WorldWater.found, 작은 병 = Village.found) — SaveCodec이 그대로 저장.
class_name FoundObjects
extends RefCounted

const KINDS := ["button", "marble", "cap", "sugar", "match"]
const NAMES := {"button": "단추", "marble": "유리구슬", "cap": "병뚜껑", "sugar": "각설탕", "match": "성냥개비"}
## 상태
const BURIED := 0
const FOUND := 1        # 찾은 자리에 놓여 있음 (사람들이 둘러봄)
const USED := 2         # 마을 쪽으로 옮겨 쓰임
const GONE := 3         # 다 먹음·녹음 (각설탕)

## 말풍선 (GD 3.0 표 그대로)
const SAY := {
	"button": "탁자만 한 단추야. 누구 옷에서 떨어졌을까?",
	"marble": "구슬 속에 빛이 갇혀 있어.",
	"cap": "뚜껑 하나가 통만 하네.",
	"sugar": "설탕이다! 무릎까지 오는 설탕 덩어리야!",
	"match": "성냥이 대들보만 해.",
}
## 연대기 — 찾음 (%s = 찾은 사람 이름 + 조사). 큰 존재를 말하지 않고 물음으로 끝낸다
const FOUND_LINE := {
	"button": "%s 땅을 고르다 탁자만 한 단추를 캐냈다. 이렇게 큰 옷을 입는 이가 있을까, 사람들은 밤늦도록 이야기했다.",
	"marble": "%s 풀숲에서 무릎만 한 유리구슬을 굴려 냈다. 이렇게 큰 구슬로는 누가 놀았을까, 아이들은 그 앞을 떠나지 못했다.",
	"cap": "%s 흙 속에서 통만 한 병뚜껑을 파냈다. 이 뚜껑에 맞는 병은 얼마나 클까, 사람들은 고개를 갸웃했다.",
	"sugar": "%s 무릎까지 오는 각설탕을 찾아냈다. 이렇게 큰 설탕 덩어리가 어디서 왔을까, 그날 밤 아이들은 단맛 생각에 잠을 설쳤다.",
	"match": "%s 대들보만 한 성냥개비를 끌어냈다. 이런 성냥으로 붙인 불은 얼마나 컸을까, 아무도 답하지 못했다.",
}
## 연대기 — 쓰임 (옮긴 날)
const USE_LINE := {
	"button": "큰 단추에 잔가지 다리를 달아 모닥불 곁 마을 탁자로 삼았다.",
	"marble": "유리구슬을 마을 가운데 세워 표지로 삼았다. 밤이면 불빛을 모아 은은하게 빛났다.",
	"cap": "병뚜껑을 집 곁에 엎어 놓고 물을 채웠다. 마을의 첫 목욕통이 되었다.",
	"sugar": "각설탕을 창고 곁에 두고 잔치를 열었다. 아이들이 날마다 조금씩 갉아 먹었다.",
	"match_bridge": "성냥개비를 개울에 걸쳐 다리로 삼았다. 붉은 머리는 떼어 불씨로 아껴 두었다.",
	"match_beam": "성냥개비를 창고 곁에 눕혀 대들보로 아껴 두었다. 붉은 머리는 떼어 불씨로 썼다.",
}
const ALTAR_LINE := "유리구슬을 제단 곁으로 옮겨 모셨다. 밤이면 등불 빛을 모아 반짝였다."
const SUGAR_GONE_LINE := "각설탕이 다 없어졌다. 아이들은 한동안 그 자리를 맴돌았다."
const SUGAR_MELT_LINE := "물에 젖은 각설탕이 녹아내렸다. 아이들은 남은 단물을 손가락으로 찍어 먹었다."

## 묻는 자리
const FIND_RING := Vector2(12.0, 28.0)     # 키트 자리에서 (칸)
const LOCAL_RING := Vector2(6.0, 16.0)     # 작은 시험 병: 마을 중심에서
const PER_SPOT := Vector2i(2, 3)           # 키트 자리마다 이만큼 (뽑음)
## 찾기
const NEAR_R := 9.0                        # 이 안에서 일하던·돌아다니던 사람의 시간이 쌓임
const DIG_R := 2.5                         # 이 안에 있으면 바로 찾음
const NOTICE_HOURS := 6                    # 둘레에서 이만큼 시간을 보내면 누군가 눈치챔
const SEEK_R := 60.0                       # 마을 중심에서 이보다 먼 물건은 보지 않음 (넓은 세상 — 다른 부락의 몫)


static func list(v: Village) -> Array[Dictionary]:
	if v.water is WorldWater:
		return (v.water as WorldWater).found
	return v.found


# ───────────────────────── 묻기 ─────────────────────────
## 넓은 세상 (WorldGen.generate 끝, GreatTrees.place 뒤): 키트 자리마다 둘레 고리에 2~3개
static func bury(ww: WorldWater) -> void:
	ww.found.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = ww.seed_v * 733 + 41
	var serial := 0
	for s: Vector2 in ww.spots:
		var kinds: Array = KINDS.duplicate()
		var n := rng.randi_range(PER_SPOT.x, PER_SPOT.y)
		for i in n:
			var kind: String = kinds.pop_at(rng.randi_range(0, kinds.size() - 1))
			var p := _spot(rng, s, FIND_RING, func(q: Vector2) -> bool: return _dry(ww, q, 2.0) and not GreatTrees.blocks(ww, q.x, q.y, 2.0))
			if p.x < 1.0e8:
				ww.found.append(_rec(serial, kind, p, rng.randf() * TAU))
				serial += 1


## 작은 시험 병: 마을 둘레에 2~3개 (마을 rng를 쓰지 않음 — 다른 시험 흐름 그대로)
static func bury_local(v: Village, seed_v: int) -> void:
	v.found.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 733 + 43
	var kinds: Array = KINDS.duplicate()
	var n := rng.randi_range(PER_SPOT.x, PER_SPOT.y)
	for i in n:
		var kind: String = kinds.pop_at(rng.randi_range(0, kinds.size() - 1))
		var p := _spot(rng, v.center, LOCAL_RING, func(q: Vector2) -> bool: return _dry(v.water, q, 2.0) and _clear_of_buildings(v, q, 1.5))
		if p.x < 1.0e8:
			v.found.append(_rec(i, kind, p, rng.randf() * TAU))


static func _rec(id: int, kind: String, p: Vector2, yaw: float) -> Dictionary:
	return {"id": id, "kind": kind, "x": p.x, "y": p.y, "yaw": yaw, "st": BURIED, "near_h": 0, "by": -1, "who": -1,
		"t": -1.0, "ux": p.x, "uy": p.y, "uyaw": yaw, "use": "", "left": 1.0, "soak_n": 0, "dew_day": -1}


static func _spot(rng: RandomNumberGenerator, c: Vector2, ring: Vector2, ok: Callable) -> Vector2:
	for tries in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(ring.x, ring.y)
		var q := c + Vector2(cos(a), sin(a)) * r
		if ok.call(q):
			return q
	return Vector2(1.0e9, 1.0e9)


static func _dry(w: JarWater, q: Vector2, margin: float) -> bool:
	if not w.inside(q.x, q.y, margin + 2.0):
		return false
	var k := w.idx(q.x, q.y)
	return not w.is_lake(k) and not w.is_river(k) and w.depth(k) < 0.002


static func _clear_of_buildings(v: Village, q: Vector2, r: float) -> bool:
	for b in v.buildings:
		if q.distance_to(Vector2(b.x, b.y)) < _bld_r(b) + r:
			return false
	if q.distance_to(v.fire) < 2.5 + r:
		return false
	return true


# ───────────────────────── 찾기·쓰임 (매시간 — Village의 호수 타이머 곁) ─────────────────────────
static func hourly(v: Village) -> void:
	var objs := list(v)
	if objs.is_empty():
		return
	var day := v.day_no()
	for o: Dictionary in objs:
		match int(o["st"]):
			BURIED:
				_seek(v, o)
			FOUND:
				if int(o["by"]) == v.sid and v.t - float(o["t"]) >= Balance.FOUND_MOVE_AFTER:
					_put_to_use(v, o)
			USED:
				if int(o["by"]) != v.sid:
					continue
				if o["kind"] == "marble" and o["use"] != "altar" and v.altar_built and v.altar_pos != Vector2.ZERO:
					var p := _free_near(v, v.altar_pos, 1.7, 1.0, float(o["id"]))
					o["ux"] = p.x
					o["uy"] = p.y
					o["use"] = "altar"
					v.log_line(ALTAR_LINE)
				elif o["kind"] == "sugar":
					_sugar_hour(v, o, day)


static func _seek(v: Village, o: Dictionary) -> void:
	var at := Vector2(float(o["x"]), float(o["y"]))
	if at.distance_to(v.center) > SEEK_R or v.is_night():
		return
	var near: Resident = null
	var dig: Resident = null
	for p in v.people:                       # id 순 (people은 들어온 순 = id 순)
		if p.action == "idle" or p.is_child() and p.age < 4.0:
			continue
		var d := Vector2(p.x, p.y).distance_to(at)
		if d < DIG_R:
			dig = p
			break
		if d < NEAR_R and near == null:
			near = p
	if dig == null and near != null:
		o["near_h"] = int(o["near_h"]) + 1
		if int(o["near_h"]) >= NOTICE_HOURS:
			dig = near
	if dig != null:
		discover(v, o, dig)


## 찾음 (시험이 바로 부를 수 있게 public)
static func discover(v: Village, o: Dictionary, who: Resident) -> void:
	o["st"] = FOUND
	o["by"] = v.sid
	o["who"] = who.id
	o["t"] = v.t
	var kind: String = o["kind"]
	v.emit(&"found_object", {"who": who.id, "at": Vector2(float(o["x"]), float(o["y"])), "v": {"kind": StringName(kind), "id": int(o["id"])}})
	v.log_line(FOUND_LINE[kind] % (who.name + Village.josa(who.name, "이", "가")))
	v.speak(who, SAY[kind], 8.0)


## 마을 쪽으로 옮겨 쓰임 (자리는 이때 한 번 정함 — 구슬만 제단이 서면 다시)
static func _put_to_use(v: Village, o: Dictionary) -> void:
	var kind: String = o["kind"]
	var salt := float(o["id"])
	var p := v.fire
	var yaw := float(o["yaw"])
	var line_key := kind
	match kind:
		"button":
			p = _free_near(v, v.fire, 2.9, 0.8, salt)
		"marble":
			var pz := VillageEra.first_built(v, "광장")
			p = _free_near(v, Vector2(pz.x, pz.y) if pz != null else v.fire, (_bld_r(pz) + 1.0) if pz != null else 4.2, 0.7, salt)
		"cap":
			var hs := v.houses()
			var h: Building = hs[0] if not hs.is_empty() else v.store()
			p = _free_near(v, Vector2(h.x, h.y) if h != null else v.center, (_bld_r(h) if h != null else 1.0) + 1.0, 0.8, salt)
		"sugar":
			var st := v.store()
			p = _free_near(v, Vector2(st.x, st.y) if st != null else v.center, (_bld_r(st) if st != null else 1.0) + 0.8, 0.6, salt)
		"match":
			var br := _bridge_spot(v)
			if br.size() > 0:
				p = br[0]
				yaw = br[1]
				line_key = "match_bridge"
				o["use"] = "bridge"
			else:
				var st := v.store()
				p = _free_near(v, Vector2(st.x, st.y) if st != null else v.center, (_bld_r(st) if st != null else 1.0) + 1.1, 1.0, salt)
				line_key = "match_beam"
				o["use"] = "beam"
	o["ux"] = p.x
	o["uy"] = p.y
	o["uyaw"] = yaw
	o["st"] = USED
	if o["use"] == "":
		o["use"] = kind
	if kind == "marble" and v.altar_built and v.altar_pos != Vector2.ZERO:
		var q := _free_near(v, v.altar_pos, 1.7, 1.0, salt)
		o["ux"] = q.x
		o["uy"] = q.y
		o["use"] = "altar"
	if kind == "sugar":
		var hs := v.hand
		o["soak_n"] = int(hs.stats.get("sprays", 0)) if hs != null else 0
	v.log_line(USE_LINE[line_key])


## c 둘레 r에서 빈 자리 (건물·모닥불·제단·물을 피함) — 12방향을 소금(salt)부터 차례로
static func _free_near(v: Village, c: Vector2, r: float, clear: float, salt: float) -> Vector2:
	var a0 := fmod(salt * 2.399 + 0.7, TAU)
	for ring in 3:
		for k in 12:
			var a := a0 + k * TAU / 12.0
			var q := c + Vector2(cos(a), sin(a)) * (r + ring * 0.8)
			if not _dry(v.water, q, 0.5):
				continue
			if not _clear_of_buildings_except(v, q, clear, c):
				continue
			if q.distance_to(v.altar_pos) < Village.ALTAR_CLEAR + clear and c != v.altar_pos:
				continue
			if not _clear_of_others(v, q, clear + 0.4):
				continue
			return q
	return c + Vector2(cos(a0), sin(a0)) * r


## 건물 둘레 (지붕 처마까지 — 화면 VillageView._prop_ok와 같은 몫: 크기 × 1.9, 밀 숲 × 2.4)
static func _bld_r(b: Building) -> float:
	return b.size() * (2.4 if b.type == "농장" else 1.9)


static func _clear_of_buildings_except(v: Village, q: Vector2, r: float, c: Vector2) -> bool:
	for b in v.buildings:
		if q.distance_to(Vector2(b.x, b.y)) < _bld_r(b) + r:
			return false
	if c != v.fire and q.distance_to(v.fire) < 2.4 + r:
		return false
	if c == v.fire and q.distance_to(v.fire) < 2.4:
		return false
	return true


static func _clear_of_others(v: Village, q: Vector2, r: float) -> bool:
	for o: Dictionary in list(v):
		if int(o["st"]) == USED and Vector2(float(o["ux"]), float(o["uy"])).distance_to(q) < r:
			return false
	return true


## 성냥개비 다리: 모닥불에서 BRIDGE_REACH 안 가장 가까운 개울 칸 — 길이(1칸) 양 끝이 마른 땅인 방향이 있으면 [자리, 방위]
static func _bridge_spot(v: Village) -> Array:
	var w := v.water
	var best := []
	var best_d := INF
	var R := Balance.FOUND_BRIDGE_REACH
	var step := 0.5
	var n := int(R / step)
	for j in range(-n, n + 1):
		for i in range(-n, n + 1):
			var q := v.fire + Vector2(i, j) * step
			var d := q.distance_to(v.fire)
			if d > R or d >= best_d:
				continue
			var k := w.idx(q.x, q.y)
			if not w.is_river(k):
				continue
			for a8 in 8:
				var a := a8 * PI / 8.0
				var dv := Vector2(cos(a), sin(a))
				var u := dv * 0.48
				# 양 끝은 마른 기슭, 가운데 세 점은 모두 개울 (모서리에 비스듬히 걸친 것은 다리가 아님)
				var spans := _dry(w, q + u, 0.0) and _dry(w, q - u, 0.0)
				for f: float in [-0.22, 0.0, 0.22]:
					var m := q + dv * f
					spans = spans and w.is_river(w.idx(m.x, m.y))
				if spans:
					best = [q, -a]
					best_d = d
					break
	return best


# ───────────────────────── 각설탕 ─────────────────────────
static func _sugar_hour(v: Village, o: Dictionary, day: int) -> void:
	var hr := v.hour_now()
	if hr >= 12.0 and hr < 13.0 and int(o.get("eat_day", -1)) != day:        # 낮참에 아이들이 갉아 먹음
		o["eat_day"] = day
		_sugar_less(v, o, Balance.FOUND_SUGAR_EAT, "")
	if hr >= 5.0 and hr < 8.0 and int(o["dew_day"]) != day and v.water.dew >= JarWater.DEW_FULL * Balance.FOUND_DEW_HEAVY:
		o["dew_day"] = day                                                   # 짙은 이슬 아침
		_sugar_less(v, o, Balance.FOUND_SUGAR_MELT, SUGAR_MELT_LINE)


## 매 걸음 (값쌈 — 쓰는 각설탕이 있을 때만): 거인의 물 뿌리기가 곁(MELT_R)을 적시면 녹음
static func step(v: Village, _dt: float) -> void:
	if v.hand == null:
		return
	var n := int(v.hand.stats.get("sprays", 0))
	for o: Dictionary in list(v):
		if o["kind"] != "sugar" or int(o["st"]) != USED or int(o["by"]) != v.sid:
			continue
		var seen := int(o["soak_n"])
		if n <= seen:
			continue
		o["soak_n"] = n
		var soaks: Array = v.hand.soaks
		var at := Vector2(float(o["ux"]), float(o["uy"]))
		for i in range(maxi(0, soaks.size() - (n - seen)), soaks.size()):
			var s: Array = soaks[i]
			if Vector2(float(s[0]), float(s[1])).distance_to(at) < Balance.FOUND_SUGAR_MELT_R:
				_sugar_less(v, o, Balance.FOUND_SUGAR_MELT, SUGAR_MELT_LINE)
				break


static func _sugar_less(v: Village, o: Dictionary, amt: float, line: String) -> void:
	o["left"] = maxf(0.0, float(o["left"]) - amt)
	if not line.is_empty() and float(o["left"]) > 0.0:
		v.log_line(line)
	if float(o["left"]) <= 0.001:
		o["st"] = GONE
		v.log_line(SUGAR_GONE_LINE)


## 아이 행복 (Village._update_happiness): 잔치 각설탕이 있는 동안 아이들 조금 ↑
static func happy(v: Village, p: Resident) -> float:
	if not p.is_child():
		return 0.0
	for o: Dictionary in list(v):
		if o["kind"] == "sugar" and int(o["st"]) == USED and int(o["by"]) == v.sid and float(o["left"]) > 0.0:
			return Balance.FOUND_SUGAR_HAPPY
	return 0.0


# ───────────────────────── 화면용 ─────────────────────────
## 이 마을 화면이 그릴 것: [{id, kind, model 키, x, y, yaw, s(크기 배율)}] — 찾은 채 놓인 것·쓰이는 것 (묻힌 것·없어진 것은 빼고)
static func shown(v: Village) -> Array:
	var out: Array = []
	for o: Dictionary in list(v):
		var st := int(o["st"])
		if st == BURIED or st == GONE:
			continue
		if st == USED and int(o["by"]) != v.sid:
			continue
		var used := st == USED
		var x := float(o["ux"]) if used else float(o["x"])
		var y := float(o["uy"]) if used else float(o["y"])
		if Vector2(x, y).distance_to(v.center) > v.view_r + 4.0:
			continue
		var s := 1.0
		if o["kind"] == "sugar":
			s = 0.45 + 0.55 * pow(float(o["left"]), 1.0 / 3.0)     # 갉아 먹을수록 작아짐
		out.append({"id": int(o["id"]), "kind": o["kind"], "use": o["use"] if used else "", "x": x, "y": y,
			"yaw": float(o["uyaw"]) if used else float(o["yaw"]), "s": s})
	return out
