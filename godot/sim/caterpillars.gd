## 애벌레 → 고치 → 나비 · 애벌레 잡이 · 비단 실 · 꿀방울 — design/gdd/production-chain.md R7-4·5, F5·F6, AC19·AC20 (#31의 MVP판, GD 3.0).
## 무리(Village)마다 하나 (Village.caterpillars). 정적 상태 없음 (ADR-0001 d). 거인이 보고 있는지는 읽지 않는다.
##  · 꽃 무리 CAT_PATCHES곳 (마을 가운데 둘레 마른 땅 — 자리는 해시로, 난수 흐름을 쓰지 않음), 무리마다 상함 값 hp (1 = 성함).
##  · 알 (CAT_HATCH) → 애벌레 (잡히거나 CAT_PUPATE 뒤 고치) → 고치 (COCOON_DAYS 뒤 나비 + 빈 고치) → 빈 고치 (COCOON_ROT 뒤 사라짐).
##  · 나비는 BUTTERFLY_DAYS 동안 살고, 나온 지 BUTTERFLY_LAY 뒤 가까운 꽃 무리에 알 CAT_EGGS개 (봄·여름만, 무리마다 CAT_MAX까지).
##  · 봄 첫날 나비가 하나도 없으면 꽃 무리 CAT_SEED곳에 알 하나 (잎 뒤에 숨어 있던 알 — 멸종 막기).
##  · 꽃숲 피해: 애벌레 한 마리마다 하루 CAT_NIBBLE, 없으면 하루 CAT_RECOVER 되살아남. CAT_PATCH_OK 아래면 꿀방울 없음 (#6이 hp를 읽음).
##  · 잡기: 애벌레 잡이(사냥꾼 키 — 저장 호환) 일꾼이 조장, 한가한 어른 1~2명을 부름 (조 2~3명, 모자라면 잡지 않음). 한 마리 = 고기 CAT_MEAT를 나눠 멤.
##  · 고치: 빈 고치 = 비단 실 SILK_EMPTY, 산 고치 = SILK_LIVE (그 나비는 없음 — 비단 실이 넉넉하지 않을 때만 땀).
##  · 꿀방울: 여름(HONEY_MONTHS) 반나절마다, 그동안 성한 꽃 무리 둘레(HONEY_R)에 있었던 어른마다 (id 순) 마을 rng로 HONEY_P → 꿀 HONEY_FOOD.
## 이 파일 밖의 고리: Village.step (step) · ResidentAI.work_task (사냥꾼 → work_task) · ResidentAI.run_op ("cat_*") ·
##   Wildlife._place_bugs (live_cats — 강아지가 짖는 상대·화면) · Village.to_dict/from_dict.
class_name Caterpillars
extends RefCounted

const VER := 1

var patches: Array = []               # {id, x, y, hp}
var eggs: Array = []                  # {p, t} — t = 낳은 때
var cats: Array = []                  # {id, p, x, y, t, res} — t = 깬 때, res = 잡으러 오는 조 번호 (0 = 없음)
var cocoons: Array = []               # {id, p, x, y, t, live, res} — live면 t = 고치가 된 때, 아니면 빈 고치가 된 때
var flies: Array = []                 # {id, p, t, laid} — 나비
var hunts: Array = []                 # {id, cat, leader, n, left, caught} — 잡으러 간 조
var next_id := 1
var seed_year := -1                   # 봄 첫날 알을 확인한 해
var day_i := -1
var month := 0                        # 그날의 병 달 (하루에 한 번 셈)
var year := 0
var half_i := -1                      # 꿀방울 반나절 번호
var near: Dictionary = {}             # 이 반나절에 성한 꽃 무리 둘레에 있었던 어른 id → true
var stats := {"hatched": 0, "caught": 0, "pupated": 0, "flown": 0, "silk_live": 0, "silk_empty": 0, "honey": 0, "seeded": 0}


# ───────────────────────── 읽기 ─────────────────────────
func live_cats() -> Array:
	return cats


func patch(id: int) -> Dictionary:
	for p: Dictionary in patches:
		if int(p["id"]) == id:
			return p
	return {}


func cats_in(pid: int) -> int:
	var n := 0
	for c: Dictionary in cats:
		if int(c["p"]) == pid:
			n += 1
	return n


func eggs_in(pid: int) -> int:
	var n := 0
	for e: Dictionary in eggs:
		if int(e["p"]) == pid:
			n += 1
	return n


## 꽃 무리 상함 값 (#6이 그림에 씀 — 1 = 성함)
func patch_hp(pid: int) -> float:
	var p := patch(pid)
	return float(p.get("hp", 1.0))


static func in_season(m: int) -> bool:
	return m in Balance.CAT_MONTHS


# ───────────────────────── 걸음 ─────────────────────────
static func step(v: Village, dt: float) -> void:
	var c := v.caterpillars
	if c == null:
		return
	if c.patches.is_empty():
		c.setup(v)
	c._tick(v, dt)


## 처음: 꽃 무리 자리 (마을 가운데 둘레 — 무리·번호로 정한 해시) + 철이면 꽃 무리마다 애벌레 하나 (나이를 조금씩 다르게)
func setup(v: Village) -> void:
	for i in Balance.CAT_PATCHES:
		var spot := v.center + Vector2(Balance.CAT_PATCH_R_LO + 1.0, 0.0).rotated(TAU * i / float(Balance.CAT_PATCHES))
		for tryn in 12:
			var h := Wildlife._hash3(v.sid, 7919, i * 17 + tryn)
			var p := v.center + Vector2(cos(h.x * TAU), sin(h.x * TAU)) * lerpf(Balance.CAT_PATCH_R_LO, Balance.CAT_PATCH_R_HI, h.y)
			if v.water.inside(p.x, p.y, 2.0) and not v.water_at(p.x, p.y) and not Wildlife._on_building(v, p):
				spot = p
				break
		patches.append({"id": i + 1, "x": spot.x, "y": spot.y, "hp": 1.0})
	_calendar(v)
	if in_season(month):
		seed_year = year
		for i in patches.size():
			_hatch(v, int(patches[i]["id"]), v.t - i * 0.4 * Balance.DAY)
	_bugs(v)


func _calendar(v: Village) -> void:
	var di := floori((v.start_clock + v.t) / Balance.DAY)
	if di == day_i:
		return
	day_i = di
	var d := Health.jar_date(v)
	month = int(d["month"])
	year = int(d["year"])


func _tick(v: Village, dt: float) -> void:
	var old_day := day_i
	_calendar(v)
	if day_i != old_day and in_season(month) and seed_year != year:
		seed_year = year
		if flies.is_empty() and cats.is_empty() and eggs.is_empty() and cocoons.filter(func(q: Dictionary) -> bool: return bool(q["live"])).is_empty():
			_seed(v)
	var changed := false
	var t := v.t
	# 알 → 애벌레
	var keep_eggs: Array = []
	for e: Dictionary in eggs:
		if t - float(e["t"]) >= Balance.CAT_HATCH:
			if cats_in(int(e["p"])) < Balance.CAT_MAX:
				_hatch(v, int(e["p"]), float(e["t"]) + Balance.CAT_HATCH)
				changed = true
		else:
			keep_eggs.append(e)
	eggs = keep_eggs
	# 애벌레 → 고치
	var keep_cats: Array = []
	for c: Dictionary in cats:
		if t - float(c["t"]) >= Balance.CAT_PUPATE:
			cocoons.append({"id": next_id, "p": int(c["p"]), "x": float(c["x"]), "y": float(c["y"]), "t": float(c["t"]) + Balance.CAT_PUPATE, "live": true, "res": 0})
			next_id += 1
			stats["pupated"] = int(stats["pupated"]) + 1
			changed = true
		else:
			keep_cats.append(c)
	cats = keep_cats
	# 고치 → 나비 + 빈 고치 · 빈 고치가 썩음
	var keep_coc: Array = []
	for q: Dictionary in cocoons:
		if bool(q["live"]):
			if t - float(q["t"]) >= Balance.COCOON_DAYS:
				var out_t := float(q["t"]) + Balance.COCOON_DAYS
				flies.append({"id": next_id, "p": int(q["p"]), "t": out_t, "laid": false})
				next_id += 1
				q["live"] = false
				q["t"] = out_t
				stats["flown"] = int(stats["flown"]) + 1
				v.emit(&"butterfly_out", {"at": Vector2(float(q["x"]), float(q["y"])), "v": {"patch": int(q["p"])}})
			keep_coc.append(q)
		elif t - float(q["t"]) < Balance.COCOON_ROT:
			keep_coc.append(q)
	cocoons = keep_coc
	# 나비: 알을 낳고 (봄·여름) 사라짐
	var keep_flies: Array = []
	for f: Dictionary in flies:
		if not bool(f["laid"]) and t - float(f["t"]) >= Balance.BUTTERFLY_LAY:
			f["laid"] = true
			if in_season(month):
				_lay(int(f["p"]), Balance.CAT_EGGS, float(f["t"]) + Balance.BUTTERFLY_LAY)
		if t - float(f["t"]) < Balance.BUTTERFLY_DAYS:
			keep_flies.append(f)
	flies = keep_flies
	# 꽃숲 피해·되살아남
	for p: Dictionary in patches:
		var n := cats_in(int(p["id"]))
		var hp := float(p["hp"])
		if n > 0:
			hp -= Balance.CAT_NIBBLE * n * dt / Balance.DAY
		else:
			hp += Balance.CAT_RECOVER * dt / Balance.DAY
		p["hp"] = clampf(hp, 0.0, 1.0)
	_honey(v)
	if changed:
		_bugs(v)


## 깬 애벌레 하나 (꽃 무리 곁 — 자리는 해시)
func _hatch(v: Village, pid: int, born: float) -> void:
	var p := patch(pid)
	if p.is_empty():
		return
	var h := Wildlife._hash3(v.sid, next_id, pid)
	var at := Vector2(float(p["x"]), float(p["y"])) + Vector2(cos(h.x * TAU), sin(h.x * TAU)) * (0.4 + 0.8 * h.y)
	cats.append({"id": next_id, "p": pid, "x": at.x, "y": at.y, "t": born, "res": 0})
	next_id += 1
	stats["hatched"] = int(stats["hatched"]) + 1


## 알 n개를 from 무리에서 가까운 꽃 무리부터 (무리마다 애벌레 + 알이 CAT_MAX까지)
func _lay(from_pid: int, n: int, t: float) -> void:
	var src := patch(from_pid)
	if src.is_empty():
		return
	var c := Vector2(float(src["x"]), float(src["y"]))
	var order := patches.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := c.distance_squared_to(Vector2(float(a["x"]), float(a["y"])))
		var db := c.distance_squared_to(Vector2(float(b["x"]), float(b["y"])))
		return da < db or (da == db and int(a["id"]) < int(b["id"])))
	for p: Dictionary in order:
		var pid := int(p["id"])
		while n > 0 and cats_in(pid) + eggs_in(pid) < Balance.CAT_MAX:
			eggs.append({"p": pid, "t": t})
			n -= 1
		if n <= 0:
			return


## 봄 첫날 나비가 없으면: 가장 성한 꽃 무리부터 CAT_SEED곳에 알 하나
func _seed(v: Village) -> void:
	var order := patches.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["hp"]) > float(b["hp"]) or (float(a["hp"]) == float(b["hp"]) and int(a["id"]) < int(b["id"])))
	for i in mini(Balance.CAT_SEED, order.size()):
		eggs.append({"p": int(order[i]["id"]), "t": v.t})
		stats["seeded"] = int(stats["seeded"]) + 1
	if not order.is_empty():
		v.log_line("올봄엔 나비가 드물었다. 그래도 잎 뒤에 작은 알 하나가 숨어 있었다.")


func _bugs(v: Village) -> void:
	if v.wild != null:
		v.wild.refresh_bugs(v)


# ───────────────────────── 꿀방울 (R7-4 · F6) ─────────────────────────
func _honey(v: Village) -> void:
	var hi := floori((v.start_clock + v.t) / (0.5 * Balance.DAY))
	if half_i < 0:
		half_i = hi
	if hi != half_i:
		half_i = hi
		if month in Balance.HONEY_MONTHS and not near.is_empty():
			var ids: Array = near.keys()
			ids.sort()
			for id: Variant in ids:
				var r := v.person(int(id))
				if r == null or r.dead:
					continue
				if v.rng.randf() < Balance.HONEY_P:
					v.stock["꿀"] = float(v.stock.get("꿀", 0.0)) + Balance.HONEY_FOOD
					stats["honey"] = int(stats["honey"]) + 1
					v.emit(&"honey_found", {"who": r.id, "at": Vector2(r.x, r.y)})
		near.clear()
	if not month in Balance.HONEY_MONTHS:
		return
	var r2 := Balance.HONEY_R * Balance.HONEY_R
	for r in v.people:
		if r.dead or r.sleeping or not r.is_adult() or near.has(r.id):
			continue
		for p: Dictionary in patches:
			if float(p["hp"]) >= Balance.CAT_PATCH_OK and Vector2(r.x - float(p["x"]), r.y - float(p["y"])).length_squared() <= r2:
				near[r.id] = true
				break


# ───────────────────────── 애벌레 잡이 (사냥꾼 키 — R1-5 · R7-5) ─────────────────────────
## 일감이 있나 (ResidentAI.work_task의 dry)
static func has_work(v: Village, r: Resident, b: Building) -> bool:
	var c := v.caterpillars
	if c == null:
		return false
	if b.out_total() >= 4.0:
		return true
	if c._target_cat(v, b, r).size() > 0 and float(v.stock.get("고기", 0.0)) < v.enough("고기") and c._crew(v, r).size() >= Balance.CAT_CREW_MIN - 1:
		return true
	return not c._target_cocoon(v, b).is_empty()


## 조장 r이 조를 꾸려 애벌레를 잡으러 감 · 조를 못 꾸리면 고치를 따거나 주움. 일감이 없으면 false
static func work_task(v: Village, r: Resident, b: Building) -> bool:
	var c := v.caterpillars
	if c == null:
		return false
	var s := v.store()
	if float(v.stock.get("고기", 0.0)) < v.enough("고기"):
		var cat := c._target_cat(v, b, r)
		if not cat.is_empty():
			var crew := c._crew(v, r)
			if crew.size() + 1 >= Balance.CAT_CREW_MIN:
				var team: Array = [r]
				team.append_array(crew)
				var hid := c.next_id
				c.next_id += 1
				cat["res"] = hid
				c.hunts.append({"id": hid, "cat": int(cat["id"]), "leader": r.id, "n": team.size(), "left": team.size(), "caught": false})
				var cp := Vector2(float(cat["x"]), float(cat["y"]))
				for i in team.size():
					var q: Resident = team[i]
					if q != r:
						ResidentAI.cancel(v, q)
						q.action = "work"
						q.last_action = "work"
					q.doing = "애벌레를 잡으러 가는 중"
					var a := TAU * i / float(team.size()) + 0.5
					q.steps.append(ResidentAI.walk(cp.x + cos(a) * 0.9, cp.y + sin(a) * 0.9))
					q.steps.append(ResidentAI.act(Balance.CAT_HUNT, "work", ResidentAI.op("cat_hunt", {"h": hid}), false, ResidentAI.op("cat_quit", {"h": hid})))
					ResidentAI._drop_at_store(v, q, s, "고기", 0.0)
				return true
	var coc := c._target_cocoon(v, b)
	if coc.is_empty():
		return false
	coc["res"] = 1
	r.doing = "고치를 따러 가는 중" if bool(coc["live"]) else "빈 고치를 주우러 가는 중"
	r.steps.append(ResidentAI.walk(float(coc["x"]) + 0.5, float(coc["y"]) + 0.3))
	r.steps.append(ResidentAI.act(Balance.COCOON_PICK, "work", ResidentAI.op("cat_cocoon", {"c": int(coc["id"])}), false, ResidentAI.op("cat_cocoon_unres", {"c": int(coc["id"])})))
	ResidentAI._drop_at_store(v, r, s, "비단 실", 0.0)
	return true


## 일터에서 닿는 가장 가까운 애벌레 (아직 아무 조도 잡으러 가지 않은 것)
func _target_cat(v: Village, b: Building, _r: Resident) -> Dictionary:
	var best: Dictionary = {}
	var bd := Balance.CAT_RANGE * Balance.CAT_RANGE
	for c: Dictionary in cats:
		if int(c["res"]) != 0:
			continue
		var d := Vector2(float(c["x"]) - b.x, float(c["y"]) - b.y).length_squared()
		if d <= bd:
			bd = d
			best = c
	return best


## 닿는 고치: 빈 고치는 늘, 산 고치는 비단 실이 넉넉하지 않을 때만 (빈 고치를 먼저)
func _target_cocoon(v: Village, b: Building) -> Dictionary:
	if float(v.stock.get("비단 실", 0.0)) >= v.enough("비단 실"):
		return {}
	var best: Dictionary = {}
	var bd := INF
	for q: Dictionary in cocoons:
		if int(q["res"]) != 0:
			continue
		var d := Vector2(float(q["x"]) - b.x, float(q["y"]) - b.y).length_squared()
		if d > Balance.CAT_RANGE * Balance.CAT_RANGE:
			continue
		if bool(q["live"]):
			d += 1.0e6                    # 빈 고치를 먼저 (나비를 날려 보낸 것)
		if d < bd:
			bd = d
			best = q
	return best


## 부를 수 있는 한가한 어른 (조장 빼고, 가까운 순, CAT_CREW_MAX − 1명까지). 아기 돌봄 부모는 부르지 않는다
func _crew(v: Village, r: Resident) -> Array:
	var cs: Array = []
	for q in v.people:
		if q == r or q.dead or q.sleeping or not q.is_adult() or q.sick_left > 0.0 or q.injured_left > 0.0 or q.hunger >= 1.0:
			continue
		if not q.action in ["", "idle", "rest", "wander", "play", "social"] or q.carry != "":
			continue
		if Production.caring_for(v, q) != null:
			continue
		cs.append(q)
	var p := Vector2(r.x, r.y)
	cs.sort_custom(func(a: Resident, b2: Resident) -> bool:
		var da := Vector2(a.x, a.y).distance_squared_to(p)
		var db := Vector2(b2.x, b2.y).distance_squared_to(p)
		return da < db or (da == db and a.id < b2.id))
	return cs.slice(0, Balance.CAT_CREW_MAX - 1)


func _hunt(id: int) -> Dictionary:
	for h: Dictionary in hunts:
		if int(h["id"]) == id:
			return h
	return {}


func _cat(id: int) -> Dictionary:
	for c: Dictionary in cats:
		if int(c["id"]) == id:
			return c
	return {}


func _cocoon(id: int) -> Dictionary:
	for q: Dictionary in cocoons:
		if int(q["id"]) == id:
			return q
	return {}


func _hunt_done(h: Dictionary) -> void:
	h["left"] = int(h["left"]) - 1
	if int(h["left"]) <= 0:
		if not bool(h["caught"]):
			var c := _cat(int(h["cat"]))
			if not c.is_empty():
				c["res"] = 0
		hunts.erase(h)


## 잡음: 조에서 처음 끝낸 사람이 잡고 (조장 이름으로 사건), 저마다 고기를 나눠 멤 (막대에 꿴 애벌레)
func catch_now(v: Village, r: Resident, hid: int) -> void:
	var h := _hunt(hid)
	if h.is_empty():
		return
	if not bool(h["caught"]):
		var c := _cat(int(h["cat"]))
		if c.is_empty():                  # 그사이 고치가 됨
			r.doing = "빈손으로 돌아오는 중"
			h["cat"] = -1
			_hunt_done(h)
			return
		cats.erase(c)
		h["caught"] = true
		stats["caught"] = int(stats["caught"]) + 1
		v.emit(&"caterpillar_caught", {"who": int(h["leader"]), "at": Vector2(float(c["x"]), float(c["y"])), "v": {"crew": int(h["n"])}})
		v.speak(r, "잡았다!", 5)
		_bugs(v)
	r.carry = "고기"
	r.carry_amt = Balance.CAT_MEAT / float(h["n"])
	r.doing = "애벌레를 메고 오는 중"
	_hunt_done(h)


## 고치를 따거나 주움 → 비단 실 (산 고치 2, 빈 고치 1)
func take_cocoon(v: Village, r: Resident, cid: int) -> void:
	var q := _cocoon(cid)
	if q.is_empty():
		r.doing = "빈손으로 돌아오는 중"
		return
	var live := bool(q["live"])
	cocoons.erase(q)
	var amt := Balance.SILK_LIVE if live else Balance.SILK_EMPTY
	stats["silk_live" if live else "silk_empty"] = int(stats["silk_live" if live else "silk_empty"]) + 1
	r.carry = "비단 실"
	r.carry_amt = amt
	r.doing = "고치를 안고 오는 중"
	v.emit(&"cocoon_taken", {"who": r.id, "at": Vector2(float(q["x"]), float(q["y"])), "v": {"live": live}})


static func run_op(v: Village, r: Resident, d: Dictionary) -> void:
	var c := v.caterpillars
	if c == null:
		return
	match String(d["op"]):
		"cat_hunt":
			c.catch_now(v, r, int(d["h"]))
		"cat_quit":                       # 도중에 그만둠 — 조에서 빠짐 (모두 빠지면 애벌레를 놓아줌)
			var h := c._hunt(int(d["h"]))
			if not h.is_empty():
				c._hunt_done(h)
		"cat_cocoon":
			c.take_cocoon(v, r, int(d["c"]))
		"cat_cocoon_unres":
			var q := c._cocoon(int(d["c"]))
			if not q.is_empty():
				q["res"] = 0


# ───────────────────────── 저장 (판 VER) ─────────────────────────
func to_dict() -> Dictionary:
	return {"ver": VER, "patches": patches.duplicate(true), "eggs": eggs.duplicate(true), "cats": cats.duplicate(true),
		"cocoons": cocoons.duplicate(true), "flies": flies.duplicate(true), "hunts": hunts.duplicate(true),
		"next_id": next_id, "seed_year": seed_year, "half_i": half_i, "near": near.keys(), "stats": stats.duplicate()}


static func from_dict(d: Dictionary) -> Caterpillars:
	var c := Caterpillars.new()
	c.patches = _ints(d.get("patches", []), ["id"])
	c.eggs = _ints(d.get("eggs", []), ["p"])
	c.cats = _ints(d.get("cats", []), ["id", "p", "res"])
	c.cocoons = _ints(d.get("cocoons", []), ["id", "p", "res"])
	c.flies = _ints(d.get("flies", []), ["id", "p"])
	c.hunts = _ints(d.get("hunts", []), ["id", "cat", "leader", "n", "left"])
	c.next_id = int(d.get("next_id", 1))
	c.seed_year = int(d.get("seed_year", -1))
	c.half_i = int(d.get("half_i", -1))
	for id: Variant in d.get("near", []):
		c.near[int(id)] = true
	var st: Dictionary = d.get("stats", {})
	for k: String in c.stats:
		c.stats[k] = int(st.get(k, 0))
	return c


static func _ints(list: Array, keys: Array) -> Array:
	var out: Array = []
	for e: Variant in list:
		var q: Dictionary = (e as Dictionary).duplicate(true)
		for k: String in keys:
			if q.has(k):
				q[k] = int(q[k])
		out.append(q)
	return out
