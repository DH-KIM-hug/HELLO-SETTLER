class_name ChildOutings
extends RefCounted
## 유모차 산책 · 아이의 첫 심부름 · 아이의 첫 낚시 (ROADMAP E2-2 · E2-3 — 기획서 7.3).
##
## 셋 다 '얹은 그림'이다: 주민의 자리·할 일·든 것·행복·배고픔·창고·마을 난수 흐름을 하나도 바꾸지 않는다.
##   - 유모차 산책: 돌보는 부모의 낮 산책(ResidentAI._care — 예전 그대로) 가운데 몇 번에 '유모차' 표시를 붙일 뿐이다.
##   - 첫 심부름 · 첫 낚시: 아이(와 곁의 어른)의 '인형 자리'를 따로 적어 화면이 그 자리에 인형을 세운다. 시뮬의 아이는 제 할 일을 그대로 한다.
## 고르는 일은 파생 난수(ChildPlay._roll — 씨앗 + 내 순번)만 쓴다. 지켜보는지·화면은 읽지 않는다 (ADR-0001).
## 상태는 v.kids["out"] (저장됨 — 열쇠가 없는 옛 저장은 빈 상태로 시작). 숫자·문자열·배열만 담는다.
##   n 순번 · acc · next · pram 걷는 중인 산책 · pd 아기마다 [날, 횟수, 마지막 때] · park 집마다 유모차를 세워 둔 때 · p1 병의 첫 산책 줄
##   err 벌어진 심부름 · ed 다녀온 아이 · e1 · fish 벌어진 낚시 · fd 낚아 본 아이 · f1

const IV := 30.0
const RS := 288.0                         # 현실 1초 = 병 288초 (보통 빠르기)
const ARRIVE := 0.06
const BACK_R := 0.35                      # 돌아가는 인형이 제 자리에 닿았다고 보는 거리
const SEAT_GAP := 0.52                    # 물가에 나란히 앉은 두 사람 사이 (칸)
const FLOAT_D := 0.8                      # 아이 자리에서 찌까지 (칸 — 물이어야 함)
const FREE := {"rest": true, "idle": true, "social": true, "chores": true, "play": true, "eat": true, "": true}
const RECV := {"rest": true, "idle": true, "social": true, "chores": true, "care": true, "": true}
const STILL := {"idle": true, "sit": true}

## 연대기 — 숫자 없음. 병의 첫 번은 조금 길게.
const LINES := {
	"pram": "%s 나무 유모차에 %s 태우고 마을을 한 바퀴 돌았다. 바퀴가 길 위에서 달그락거리는 동안 아기는 하늘만 올려다보았다.",
	"errand_first": "%s 두 손에 보퉁이를 꼭 쥐고 %s네 문 앞까지 혼자 걸어갔다. 마을 아이의 첫 심부름이었다. %s 아이의 머리를 오래 쓰다듬어 주었다.",
	"errand_elder": ["%s 보퉁이를 안고 %s 어르신께 첫 심부름을 다녀왔다.", "%s 처음으로 혼자 %s 어르신 댁에 보퉁이를 가져다드렸다."],
	"errand_sick": ["%s 앓는 식구가 있는 %s네에 따뜻한 그릇을 들고 갔다. 첫 심부름이었다."],
	"errand_baby": ["%s 아기가 있는 %s네에 보퉁이를 가져다주었다. 첫 심부름이었다."],
	"errand": ["%s 이웃 %s네에 첫 심부름을 다녀왔다.", "%s 보퉁이를 들고 %s네에 다녀왔다. 첫 심부름이었다."],
	"fish_first": "%s %s 곁에 나란히 앉아 풀줄기 낚싯대를 물에 드리웠다. 한참 만에 손가락만 한 것이 올라오자 물가가 떠들썩했다. 아이의 첫 낚시였다.",
	"fish": ["%s %s 곁에서 풀줄기 낚싯대로 첫 낚시를 했다. 올라온 것은 손가락만 했다.", "%s %s 곁에 앉아 첫 낚시를 했다. 조그만 것 하나에 한참을 웃었다."],
}


# ───────────────────────── 상태 ─────────────────────────
static func state(v: Village) -> Dictionary:
	var k := v.kids
	if not k.has("out"):
		k["out"] = {}
	var st: Dictionary = k["out"]
	if not st.has("pram"):
		for key: String in ["pram", "pd", "park", "err", "ed", "fish", "fd"]:
			if not st.has(key):
				st[key] = {}
		for key: String in ["n", "p1", "e1", "f1"]:
			if not st.has(key):
				st[key] = 0
		for key: String in ["acc", "next"]:
			if not st.has(key):
				st[key] = 0.0
	return st


## 읽기만 (화면·시험) — 상태를 만들지 않는다
static func peek(v: Village) -> Dictionary:
	var o: Variant = v.kids.get("out")
	return o if o is Dictionary else {}


static func pram(v: Village) -> Dictionary:
	var o: Variant = peek(v).get("pram")
	return o if o is Dictionary else {}


static func errand(v: Village) -> Dictionary:
	var o: Variant = peek(v).get("err")
	return o if o is Dictionary else {}


static func fishing(v: Village) -> Dictionary:
	var o: Variant = peek(v).get("fish")
	return o if o is Dictionary else {}


static func parked(v: Village) -> Dictionary:
	var o: Variant = peek(v).get("park")
	return o if o is Dictionary else {}


static func errand_done(v: Village, id: int) -> bool:
	var o: Variant = peek(v).get("ed")
	return o is Dictionary and (o as Dictionary).has(str(id))


static func fishing_done(v: Village, id: int) -> bool:
	var o: Variant = peek(v).get("fd")
	return o is Dictionary and (o as Dictionary).has(str(id))


## 이 사람이 지금 유모차를 미는 중인가 (시뮬의 산책 가운데 유모차로 뽑힌 것)
static func pushing(v: Village, id: int) -> bool:
	var p := pram(v)
	return not p.is_empty() and int(p.get("cr", -1)) == id


## 화면이 인형을 따로 세우는 사람인가 → [x, y] 또는 빈 배열 (심부름·낚시의 아이, 낚시의 곁 어른)
static func doll_at(v: Village, id: int) -> Array:
	var e := errand(v)
	if not e.is_empty() and int(e.get("k", -1)) == id:
		return [float(e["x"]), float(e["y"])]
	var f := fishing(v)
	if not f.is_empty():
		if int(f.get("k", -1)) == id:
			return [float(f["x"]), float(f["y"])]
		if int(f.get("m", 0)) == 1 and int(f.get("ad", -1)) == id:
			return [float(f["ax"]), float(f["ay"])]
	return []


static func _next(st: Dictionary) -> int:
	st["n"] = int(st.get("n", 0)) + 1
	return int(st["n"])


static func _nm(name: String, a: String, b: String) -> String:
	return name + Village.josa(name, a, b)


# ───────────────────────── 날씨·때 ─────────────────────────
## 춥지도 덥지도 않은 낮, 작은 위기(날벌레·물방울·먼지·곰팡이)도 굶주림도 장면도 없는 때 — 병 속의 '맑은 날'
static func calm(v: Village) -> bool:
	if not v.is_work_time() or v.is_night() or v.in_opening() or v.staged() or v.t < Balance.DAY:
		return false
	if SmallCrises.active_count(v) > 0 or v._starving():
		return false
	var temp := Health.temperature_at(v, v.fire.x, v.fire.y)
	return Health.cold_of(temp) <= 0.0 and Health.heat_of(temp) <= 0.0


## 지금부터 need(병 초) 동안 끼니도 저녁도 걸리지 않는가
static func free_span(v: Village, need: float) -> bool:
	var h := v.hour_now()
	var n := need / Balance.HOUR
	if h + n > Balance.WORK_TO:
		return false
	for m: Array in Balance.MEALS:
		if h + n > float(m[0]) and h < float(m[1]):
			return false
	return true


static func _door(hm: Building) -> Vector2:
	return Vector2(hm.x - 0.3, hm.y + hm.size() * 0.5 + 0.75)


static func _well(r: Resident) -> bool:
	return r != null and not r.dead and not r.sleeping and r.sick_left <= 0.0 and r.injured_left <= 0.0


# ───────────────────────── 걸음 ─────────────────────────
static func step(v: Village, dt: float) -> void:
	var st := state(v)
	var pd := dt * v.pace_walk()
	var er: Dictionary = st["err"]
	if not er.is_empty():
		_errand_step(v, st, er, pd)
	var fi: Dictionary = st["fish"]
	if not fi.is_empty():
		_fish_step(v, st, fi, pd)
	st["acc"] = float(st["acc"]) + dt
	if float(st["acc"]) < IV:
		return
	st["acc"] = 0.0
	_pram_tick(v, st)
	if (st["err"] as Dictionary).is_empty() and (st["fish"] as Dictionary).is_empty() and v.t >= float(st["next"]):
		st["next"] = v.t + Balance.OUTING_TRY
		_try_start(v, st)


## 인형 자리(kx, ky)를 (tx, ty) 쪽으로 — 닿았으면 true. speed = 칸/현실 초, pd = 놀이 시계 (병 초)
static func _toward(rec: Dictionary, kx: String, ky: String, tx: float, ty: float, speed: float, pd: float, stop := ARRIVE) -> bool:
	var p := Vector2(float(rec[kx]), float(rec[ky]))
	var to := Vector2(tx, ty)
	var d := p.distance_to(to)
	if d <= stop:
		return true
	var q := p.move_toward(to, speed / RS * pd)
	rec[kx] = q.x
	rec[ky] = q.y
	return q.distance_to(to) <= stop


# ───────────────────────── A. 유모차 산책 ─────────────────────────
## ResidentAI._care가 산책 걸음을 다 적은 바로 뒤에 부른다 (마을 난수는 뽑지 않는다). 걷는 길·시간·만나는 사람의 행복은 시뮬 그대로.
static func on_stroll(v: Village, r: Resident, baby: Resident) -> void:
	if baby == null:
		return
	var st := state(v)
	if pram_ok(v, st, r, baby) and ChildPlay._roll(v, 7100 + _next(st), baby.id) < Balance.PRAM_PICK_P:
		_pram_start(v, st, r, baby)
	elif baby.age < ChildPlay.TODDLE_AGE:
		r.doing = "%s 안고 마을을 한 바퀴 도는 중" % _nm(baby.name, "을", "를")
	else:
		r.doing = "%s 데리고 마을을 한 바퀴 도는 중" % _nm(baby.name, "을", "를")


static func pram_ok(v: Village, st: Dictionary, r: Resident, baby: Resident) -> bool:
	if baby.age >= ChildPlay.TODDLE_AGE or not (st["pram"] as Dictionary).is_empty():
		return false
	var h := v.hour_now()
	if h < Balance.PRAM_FROM or h >= Balance.PRAM_TO or not calm(v):
		return false
	if not _well(r) or baby.dead or baby.sick_left > 0.0 or v.bld(r.home) == null:
		return false
	var d: Array = (st["pd"] as Dictionary).get(str(baby.id), [-1, 0, -1.0e9])
	var today := int(v.t / Balance.DAY)
	if int(d[0]) == today and int(d[1]) >= Balance.PRAM_PER_DAY:
		return false
	return v.t - float(d[2]) >= Balance.PRAM_GAP


static func _pram_start(v: Village, st: Dictionary, r: Resident, baby: Resident) -> void:
	var today := int(v.t / Balance.DAY)
	var pd: Dictionary = st["pd"]
	var d: Array = pd.get(str(baby.id), [-1, 0, -1.0e9])
	pd[str(baby.id)] = [today, (int(d[1]) if int(d[0]) == today else 0) + 1, v.t]
	st["pram"] = {"cr": r.id, "b": baby.id, "h": r.home, "t0": v.t, "met": [], "mt": v.t}
	(st["park"] as Dictionary)[str(r.home)] = v.t
	v.emit(&"stroller_walk_started", {"who": r.id, "at": Vector2(r.x, r.y), "v": baby.id})
	if int(st.get("p1", 0)) == 0:
		st["p1"] = 1
		v.log_line(String(LINES["pram"]) % [_nm(r.name, "이", "가"), _nm(baby.name, "을", "를")])


static func _pram_tick(v: Village, st: Dictionary) -> void:
	var park: Dictionary = st["park"]
	if not park.is_empty():
		# 세워 둔 유모차: 그 집에 젖먹이가 있는 동안은 늘 새로, 걸음마 뒤에는 PRAM_PARK_DAYS만
		for key: String in park.keys():
			var hid := int(key)
			var has := false
			for q: Resident in v.people:
				if q.home == hid and q.age < ChildPlay.TODDLE_AGE and not q.dead:
					has = true
					break
			if has and v.bld(hid) != null:
				park[key] = v.t
			elif v.bld(hid) == null or v.t - float(park[key]) > Balance.PRAM_PARK_DAYS * Balance.DAY:
				park.erase(key)
	var p: Dictionary = st["pram"]
	if p.is_empty():
		return
	var cr := v.person(int(p["cr"]))
	var baby := v.person(int(p["b"]))
	if cr == null or cr.dead or baby == null or baby.dead or cr.carry != "유모차" or not v.is_work_time():      # 날이 저물면 유모차는 들여놓음 (남은 길은 품에 안고)
		st["pram"] = {}
		v.emit(&"stroller_walk_ended", {"who": int(p["cr"]), "v": int(p["b"])})
		return
	var met: Array = p["met"]
	if met.size() >= Balance.PRAM_MEET_MAX or v.t - float(p["mt"]) < Balance.PRAM_MEET_GAP or cr.anim == "idle":
		return
	var best: Resident = null
	var bd := Balance.PRAM_MEET_R
	for q: Resident in v.people:
		if q == cr or q == baby or q.is_baby() or not _well(q) or q.carry != "" or not FREE.has(q.action):
			continue
		if q.anim != "idle" and q.anim != "walk" and q.anim != "sit":
			continue
		var d := Vector2(q.x - cr.x, q.y - cr.y).length()
		if d < bd and not met.has(q.id) and not met.has(float(q.id)):
			bd = d
			best = q
	if best != null:
		met.append(best.id)
		p["mt"] = v.t
		v.emit(&"stroller_met", {"who": best.id, "at": Vector2(cr.x, cr.y), "v": cr.id})


# ───────────────────────── 나설 아이 고르기 ─────────────────────────
static func _try_start(v: Village, st: Dictionary) -> void:
	if not calm(v):
		return
	var n := _next(st)
	if ChildPlay._roll(v, 7200 + n, 0) >= Balance.OUTING_TRY_P:
		return
	var kids: Array = []
	for r: Resident in v.people:
		if r.age >= Balance.ERRAND_AGE and r.is_child():
			kids.append(r)
	if kids.is_empty():
		return
	var from := int(ChildPlay._roll(v, 7300 + n, 1) * kids.size()) % kids.size()
	for i in kids.size():
		var r: Resident = kids[(from + i) % kids.size()]
		if try_errand(v, r) or try_fishing(v, r):
			return


static func _kid_free(v: Village, r: Resident, min_age: float) -> bool:
	if r == null or r.age < min_age or not r.is_child() or not _well(r) or r.carry != "" or not FREE.has(r.action):
		return false
	var hm := v.bld(r.home)
	if hm == null or not hm.built or not ChildPlay.game_of(v, r.id).is_empty():
		return false
	return Vector2(r.x, r.y).distance_to(_door(hm)) <= Balance.ERRAND_HOME_R


# ───────────────────────── B. 첫 심부름 ─────────────────────────
## 조건이 모두 맞으면 심부름을 벌인다 (확률 없음 — 고르는 쪽이 굴림). 시험·그림 도구도 이것을 부른다.
static func try_errand(v: Village, r: Resident) -> bool:
	var st := state(v)
	if not (st["err"] as Dictionary).is_empty() or not (st["fish"] as Dictionary).is_empty() or (st["ed"] as Dictionary).has(str(r.id)):
		return false
	var h := v.hour_now()
	if h < Balance.ERRAND_FROM or h >= Balance.ERRAND_TO or not calm(v) or not free_span(v, Balance.ERRAND_FREE):
		return false
	if not _kid_free(v, r, Balance.ERRAND_AGE):
		return false
	var pick := _errand_target(v, r)
	if pick.is_empty():
		return false
	var hm: Building = pick[0]
	var to := _door(hm)
	st["err"] = {"k": r.id, "to": hm.id, "rc": (pick[1] as Resident).id, "why": String(pick[2]), "ph": 0, "c": 0.0,
		"x": r.x, "y": r.y, "tx": to.x, "ty": to.y, "rx": to.x, "ry": to.y, "done": 0}
	v.emit(&"errand_started", {"who": r.id, "at": Vector2(r.x, r.y), "v": hm.id})
	return true


## 받을 사람: 그 집 식구, 어른·노인, 깨어 있고 빈손, 서 있거나 앉아 있고, 문 가까이
static func _receiver_ok(q: Resident, hm: Building) -> bool:
	if q.home != hm.id or q.is_child() or not _well(q) or q.carry != "" or not RECV.has(q.action) or not STILL.has(q.anim):
		return false
	return Vector2(q.x, q.y).distance_to(_door(hm)) <= Balance.ERRAND_NEAR


static func _receiver(v: Village, hm: Building, want: int) -> Resident:
	var best: Resident = null
	var bs := 1.0e9
	var door := _door(hm)
	for q: Resident in v.people:
		if not _receiver_ok(q, hm):
			continue
		var s := Vector2(q.x, q.y).distance_to(door) - (100.0 if q.id == want else 0.0) - (10.0 if q.is_elder() else 0.0)
		if s < bs:
			bs = s
			best = q
	return best


## → [집, 받을 사람, 까닭("elder"·"sick"·"baby"·"")] 또는 빈 배열. 노인·앓는 이·아기가 있는 집 먼저, 그다음 가까운 집.
static func _errand_target(v: Village, r: Resident) -> Array:
	var own := v.bld(r.home)
	var best: Array = []
	var bs := 1.0e9
	for hm: Building in v.houses():
		if hm.id == r.home or not hm.built:
			continue
		var d := Vector2(hm.x - own.x, hm.y - own.y).length()
		if d < Balance.ERRAND_R.x or d > Balance.ERRAND_R.y:
			continue
		var q := _receiver(v, hm, -1)
		if q == null:
			continue
		var why := ""
		for p: Resident in v.people:
			if p.home != hm.id or p.dead:
				continue
			if p.sick_left > 0.0 or p.injured_left > 0.0:
				why = "sick"
				break
			if p.is_elder():
				why = "elder"
			elif p.is_baby() and why == "":
				why = "baby"
		var s := d + (0.0 if why != "" else 100.0)
		if s < bs:
			bs = s
			best = [hm, q, why]
	return best


static func _errand_step(v: Village, st: Dictionary, e: Dictionary, pd: float) -> void:
	var r := v.person(int(e["k"]))
	if r == null or r.dead or r.sleeping:
		st["err"] = {}
		st["next"] = v.t + Balance.OUTING_TRY
		v.emit(&"errand_ended", {"who": int(e["k"]), "v": int(e["done"])})
		return
	e["c"] = float(e["c"]) + pd
	var ph := int(e["ph"])
	var hm := v.bld(int(e["to"]))
	if ph <= 1 and (hm == null or not v.is_work_time() or v.staged()):
		e["no"] = "late"                       # (재 보기용) 못 건넨 까닭
		_errand_phase(e, 4)                    # 시뮬의 아이가 그사이 놀이에 끼어도 심부름은 마저 다녀온다 (끝나면 놀이 자리로 깡충깡충)
		return
	match ph:
		0:      # 이웃집 문 앞으로
			if _toward(e, "x", "y", float(e["tx"]), float(e["ty"]), Balance.ERRAND_WALK, pd):
				_errand_phase(e, 1)
		1:      # 받을 사람에게 다가감 (없으면 문 앞에서 기다림)
			var q := v.person(int(e["rc"]))
			if q == null or not _receiver_ok(q, hm):
				q = _receiver(v, hm, int(e["rc"]))
			if q != null:
				e["rc"] = q.id
				var side := Vector2(float(e["x"]) - q.x, float(e["y"]) - q.y)
				side = side.normalized() if side.length() > 0.01 else Vector2(-1.0, 0.0)
				var at := Vector2(q.x, q.y) + side * 0.42
				if _toward(e, "x", "y", at.x, at.y, Balance.ERRAND_WALK, pd):
					e["rx"] = q.x
					e["ry"] = q.y
					_errand_phase(e, 2)
					_errand_given(v, st, e, r, q, hm)
			elif float(e["c"]) > Balance.ERRAND_WAIT * RS:
				e["no"] = "wait"
				_errand_phase(e, 4)
		2:      # 건넴
			if float(e["c"]) >= Balance.ERRAND_GIVE * RS:
				_errand_phase(e, 3)
		3:      # 머리 쓰다듬기
			if float(e["c"]) >= Balance.ERRAND_PAT * RS:
				_errand_phase(e, 4)
		_:      # 깡충깡충 제 자리(시뮬의 아이가 있는 곳)로
			if _toward(e, "x", "y", r.x, r.y, Balance.ERRAND_SKIP, pd, BACK_R) or float(e["c"]) > Balance.OUTING_BACK_MAX * RS:
				st["err"] = {}
				st["next"] = v.t + (Balance.OUTING_REST if int(e["done"]) == 1 else Balance.OUTING_TRY * 4.0)
				v.emit(&"errand_ended", {"who": r.id, "v": int(e["done"])})


static func _errand_phase(e: Dictionary, ph: int) -> void:
	e["ph"] = ph
	e["c"] = 0.0


static func _errand_given(v: Village, st: Dictionary, e: Dictionary, r: Resident, q: Resident, hm: Building) -> void:
	e["done"] = 1
	(st["ed"] as Dictionary)[str(r.id)] = v.t
	v.emit(&"errand_given", {"who": r.id, "at": Vector2(q.x, q.y), "v": q.id})
	var kid := _nm(r.name, "은", "는")
	if int(st.get("e1", 0)) == 0:
		st["e1"] = 1
		v.log_line(String(LINES["errand_first"]) % [kid, q.name, _nm(q.name, "은", "는")])
		return
	var key := "errand" if String(e["why"]) == "" else "errand_" + String(e["why"])
	var rows: Array = LINES[key]
	var who := q.name
	if key == "errand_elder":      # 그 집의 어르신 이름으로
		for p: Resident in v.people:
			if p.home == hm.id and p.is_elder() and not p.dead:
				who = p.name
				break
	v.log_line(String(rows[int(ChildPlay._roll(v, 7400 + _next(st), r.id) * rows.size()) % rows.size()]) % [kid, who])


# ───────────────────────── C. 첫 낚시 ─────────────────────────
static func try_fishing(v: Village, r: Resident) -> bool:
	var st := state(v)
	if not (st["err"] as Dictionary).is_empty() or not (st["fish"] as Dictionary).is_empty() or (st["fd"] as Dictionary).has(str(r.id)):
		return false
	if v.wild == null or v.wild.herds.is_empty():
		return false
	var h := v.hour_now()
	if h < Balance.ERRAND_FROM or h >= Balance.ERRAND_TO or not calm(v) or not free_span(v, 0.0):
		return false
	if not _kid_free(v, r, Balance.FISH1_AGE):
		return false
	var sp := fish_spot(v, r)
	if sp.is_empty():
		return false
	var seat: Vector2 = sp["seat"]
	if h + fish_need(Vector2(r.x, r.y).distance_to(seat)) / Balance.HOUR > Balance.FISH1_BACK:
		return false                           # 저녁 끼니까지 못 돌아올 길
	var dir: Vector2 = sp["dir"]
	var ad: Resident = sp["ad"]
	var a2: Vector2 = sp["seat2"]
	st["fish"] = {"k": r.id, "ad": ad.id, "m": int(sp["m"]), "ph": 0, "c": 0.0, "x": r.x, "y": r.y, "ax": ad.x, "ay": ad.y,
		"sx": seat.x, "sy": seat.y, "s2x": a2.x, "s2y": a2.y, "wx": dir.x, "wy": dir.y, "done": 0}
	v.emit(&"first_fishing_started", {"who": r.id, "at": seat, "v": ad.id})
	return true


## 첫 낚시를 다녀오는 데 드는 때 (병 초): 가는 길 + 드리우고 기다림 + 오는 길 + 여유 (현실 3초)
static func fish_need(d: float) -> float:
	return (2.0 * d / Balance.FISH1_WALK + Balance.FISH1_SIT + Balance.FISH1_BITE + Balance.FISH1_CATCH + 3.0) * RS


## 물 쪽 방향 (자리 둘레를 둘러봐 물인 쪽의 평균) — 물이 없으면 ZERO
static func _water_dir(v: Village, p: Vector2) -> Vector2:
	var sum := Vector2.ZERO
	for rad: float in [1.0, 1.6, 2.4]:
		for i in 16:
			var a := TAU * i / 16.0
			var d := Vector2(cos(a), sin(a))
			if v.water_at(p.x + d.x * rad, p.y + d.y * rad):
				sum += d
		if sum.length() > 0.5:
			break
	return sum.normalized() if sum.length() > 0.01 else Vector2.ZERO


## 물가의 두 자리 (물을 보고 나란히) — 둘 다 뭍이고, 아이 자리 앞 FLOAT_D가 물이어야 (찌가 물에 닿게 물 쪽으로 조금씩 다가서 본다)
static func _seats(v: Village, p: Vector2) -> Dictionary:
	var dir := _water_dir(v, p)
	if dir == Vector2.ZERO:
		return {}
	var side := Vector2(-dir.y, dir.x)
	# 물 쪽으로 조금씩, 그래도 없으면 (물가가 계단꼴로 꺾인 곳) 뭍 쪽으로 조금씩 물러서 본다
	var wet := false
	for i: int in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, -1, -2, -3, -4, -5, -6]:
		var q := p + dir * 0.2 * float(i)
		if v.water_at(q.x, q.y):
			wet = wet or i >= 0
			continue
		if wet and i > 0:
			continue                           # 물을 건너가지 않음
		for s: float in [1.0, -1.0]:
			var a := q + side * s * SEAT_GAP
			var fl := a + dir * FLOAT_D
			var toe := a + dir * 0.25
			if not v.water_at(a.x, a.y) and not v.water_at(toe.x, toe.y) and v.water_at(fl.x, fl.y):
				return {"seat": a, "seat2": q, "dir": dir}
	return {}


## 어른이 낚시하는 물(물고기가 사는 호수)이 제 집 가까이 있고, 곁에 앉아 줄 쉬는 어른이 있는가
## → {seat 아이 자리, seat2 어른 자리, dir 물 쪽, m 1 (쉬는 어른과 함께), ad 어른} 또는 빈 사전.
## (일하는 어부 곁에 앉는 것은 넣지 않았다 — 어부는 보통 빠르기에서 물가에 현실 2초도 머물지 않아 끝까지 나란히 앉을 수 없음)
static func fish_spot(v: Village, r: Resident) -> Dictionary:
	var w := v.wild
	if w == null or w.herds.is_empty():
		return {}
	var hm := v.bld(r.home)
	var from := _door(hm)
	var sp: Variant = Wildlife.shore_point(v, from, Balance.FISH1_R)
	if sp == null or w._nearest_live(v, "fish", sp as Vector2, Wildlife.FUN_FISH_R).is_empty():
		return {}
	var s2 := _seats(v, sp as Vector2)
	if s2.is_empty():
		return {}
	var ad := _companion(v, r)
	if ad == null:
		return {}
	s2["m"] = 1
	s2["ad"] = ad
	return s2


static func _companion_ok(v: Village, q: Resident) -> bool:
	return q != null and not q.is_child() and _well(q) and q.carry == "" and FREE.has(q.action) and q.action != "play"


## 곁에 앉아 줄 쉬는 어른: 한집의 노인 → 일 없는 노인 → 한집의 어른 → 다른 어른 (가까운 순). 일하는 사람은 부르지 않는다.
static func _companion(v: Village, r: Resident) -> Resident:
	var best: Resident = null
	var bs := 1.0e9
	for q: Resident in v.people:
		if not _companion_ok(v, q) or not STILL.has(q.anim):
			continue
		var d := Vector2(q.x - r.x, q.y - r.y).length()
		if d > Balance.ERRAND_HOME_R:
			continue
		var rank := 3.0
		if q.is_elder() and q.home == r.home:
			rank = 0.0
		elif q.is_elder() and q.job < 0:
			rank = 1.0
		elif q.home == r.home:
			rank = 2.0
		if rank * 100.0 + d < bs:
			bs = rank * 100.0 + d
			best = q
	return best


static func _fish_step(v: Village, st: Dictionary, f: Dictionary, pd: float) -> void:
	var r := v.person(int(f["k"]))
	var ad := v.person(int(f["ad"]))
	if r == null or r.dead or r.sleeping:
		_fish_end(v, st, f)
		return
	f["c"] = float(f["c"]) + pd
	var ph := int(f["ph"])
	# 앉아 드리우기 전에 어른이 일하러 가거나 날이 저물면 돌아간다 (다른 날 다시). 시뮬의 아이가 놀이에 끼어도 낚시는 마저 한다.
	if ph <= 1 and (not _companion_ok(v, ad) or not v.is_work_time() or v.staged()):
		_fish_phase(f, 4)
		return
	match ph:
		0:      # 물가로 (어른도 아이 걸음에 맞춰 나란히)
			var here := _toward(f, "x", "y", float(f["sx"]), float(f["sy"]), Balance.FISH1_WALK, pd)
			if _toward(f, "ax", "ay", float(f["s2x"]), float(f["s2y"]), Balance.FISH1_WALK, pd) and here:
				_fish_phase(f, 1)
		1:      # 풀줄기 낚싯대를 드리우고 기다림
			if float(f["c"]) >= Balance.FISH1_SIT * RS:
				_fish_phase(f, 2)
		2:      # 입질
			if float(f["c"]) >= Balance.FISH1_BITE * RS:
				_fish_phase(f, 3)
				_fish_caught(v, st, f, r, ad)
		3:      # 건져 올림
			if float(f["c"]) >= Balance.FISH1_CATCH * RS:
				_fish_phase(f, 4)
		_:      # 돌아감: 아이도 어른도 시뮬의 제 자리로
			var a := _toward(f, "x", "y", r.x, r.y, Balance.ERRAND_SKIP, pd, BACK_R)
			var b := true
			if ad != null and not ad.dead:
				b = _toward(f, "ax", "ay", ad.x, ad.y, Balance.FISH1_WALK, pd, BACK_R)
			if (a and b) or float(f["c"]) > Balance.OUTING_BACK_MAX * RS:
				_fish_end(v, st, f)


static func _fish_phase(f: Dictionary, ph: int) -> void:
	f["ph"] = ph
	f["c"] = 0.0


static func _fish_end(v: Village, st: Dictionary, f: Dictionary) -> void:
	st["fish"] = {}
	st["next"] = v.t + (Balance.OUTING_REST if int(f["done"]) == 1 else Balance.OUTING_TRY * 4.0)
	v.emit(&"first_fishing_ended", {"who": int(f["k"]), "v": int(f["done"])})


static func _fish_caught(v: Village, st: Dictionary, f: Dictionary, r: Resident, ad: Resident) -> void:
	f["done"] = 1
	(st["fd"] as Dictionary)[str(r.id)] = v.t
	v.emit(&"first_fishing_caught", {"who": r.id, "at": Vector2(float(f["sx"]), float(f["sy"])), "v": int(f["ad"])})
	var kid := _nm(r.name, "은", "는")
	var who := ad.name if ad != null else "어른"
	if int(st.get("f1", 0)) == 0:
		st["f1"] = 1
		v.log_line(String(LINES["fish_first"]) % [kid, who])
		return
	var rows: Array = LINES["fish"]
	v.log_line(String(rows[int(ChildPlay._roll(v, 7500 + _next(st), r.id) * rows.size()) % rows.size()]) % [kid, who])
