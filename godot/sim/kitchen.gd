## 우유·계란 없는 부엌 — 진딧물 목장(단물) · 하늘의 큰 알(메추리알 잔치) · 씨앗 우유·기름·씨앗 반죽 → 더 좋은 빵
## (ROADMAP E3-14 · GD 3.0 '우유·계란 없는 부엌' · docs/FOOD.md 5 · village-economy D4·R1~R3 · wallet-shop R6). 무리(Village)마다 하나 (Village.kitchen).
## ADR-0001: 정적 상태 없음 · 사건은 v.emit · 거인이 보고 있는지는 읽지 않는다 · 난수 흐름을 쓰지 않는다 (날마다의 굴림은 마을 씨앗·날의 해시).
##  · 진딧물 목장: 여름(APHID_FIND_MONTHS) 꽃 무리 곁 어른이 장미 줄기에서 찾거나 (해시 APHID_FIND_P), 별지기가 '진딧물 한 무리'를 내려 줌.
##    철(APHID_MONTHS)이면 아침(TEND_HOURS) 목장지기(한가한 어른 — 어제의 목장지기를 먼저)가 톡톡 → 단물 = 마리 × HONEYDEW_PER를 창고로.
##    돌본 날 진딧물 +APHID_GROW (APHID_MAX까지), 무당벌레(LADYBUG_P)가 오면 −LADYBUG_EAT. 다 잃으면 목장은 비고 다시 찾아야 함.
##  · 하늘의 큰 알: SkyDrops.drop(kind "egg") → land(). 한가한 어른 EGG_CREW명이 굴려 와 창고 곁에서 깸 →
##    '알' = 식량 EGG_DAYS일치(전부 거인 몫) + 잔치(festival_t — 사흘 축제 행복) + 껍데기(물가면 배, 아니면 큰 물통 — 모양만, 자원 아님).
##  · 씨앗 방앗간: 하루 한 번(PRESS_HOUR) 맷돌간·방앗간 일꾼이 해바라기씨 PRESS_SEEDS_DAY알을 빻음 → 씨앗 반죽 · 기름 · 우유 (모자란 것부터).
##  · 빵: 화덕·빵집이 한 판 구울 때(on_bake) 씨앗 반죽이 있으면 빵 +BINDER_BONUS, 단물·씨앗 우유·기름이 있으면 '좋은 빵' (행복 +HAPPY_FINE_BREAD).
## 이 파일 밖의 고리: Village.step의 정시 (hourly) · Village._update_building (on_bake) · Production.food_happy (happy) · Production.spoil (KITCHEN_SPOIL) ·
##   ResidentAI.run_op ("kit_*") · SkyDrops.drop (egg · aphids) · Shop.card (lock) · Village.to_dict/from_dict.
class_name Kitchen
extends RefCounted

const VER := 1
const FIND_LINE := "장미 줄기에서 진딧물 무리를 찾았다. %s 풀줄기로 작은 울타리를 두르고, 아침마다 단물을 받기로 했다."
const SKY_LINE := "사람들이 진딧물 둘레에 풀줄기로 작은 울타리를 두르고, 그곳을 진딧물 목장이라 불렀다."
const FIRST_DEW_LINE := "목장지기가 처음으로 진딧물을 톡톡 건드려 단물을 받았다. 아이들이 손가락을 빨며 졸졸 따라다녔다."
const LADYBUG_SAY := "무당벌레다! 진딧물을 지켜!"
const EMPTY_LINE := "무당벌레가 진딧물을 모두 먹어 버렸다. 목장의 울타리만 덩그러니 남았다."
const FEAST_LINE := "사람들이 하늘의 큰 알을 굴려 와 깨뜨렸다. 노른자 웅덩이 곁에서 온 마을이 사흘 동안 알부침 잔치를 벌였다."
const SHELL_LINES := {"basin": "깨진 알껍데기는 씻어서 큰 물통으로 썼다. 아이들이 그 안에서 물장구를 쳤다.",
	"boat": "깨진 알껍데기 반쪽을 물에 띄우니 배가 되었다. 아이들이 서로 먼저 타겠다고 다투었다."}
const PRESS_LINE := "맷돌간에서 해바라기씨를 빻았다. 물에 개니 뽀얀 씨앗 우유가, 짜내니 고소한 기름이, 불리니 끈적한 씨앗 반죽이 되었다."
const FINE_LINES := {"단물": "%s 빵 반죽에 단물을 섞어 구웠다. 달콤한 냄새에 아이들이 화덕 앞에 줄을 섰다.",
	"씨앗 우유": "%s 빵 반죽에 씨앗 우유를 부어 구웠다. 빵이 한결 부드러워졌다.",
	"씨앗 기름": "%s 화덕 돌에 씨앗 기름을 바르고 빵을 구웠다. 겉이 바삭한 기름 빵이 되었다."}
const SAY_FIND := "장미 줄기에 진딧물이 잔뜩이야! 단물이 나와!"
const SAY_TEND := "톡톡, 단물 한 방울 줄래?"
const SAY_ROLL := "다 같이 밀어! 하나, 둘!"
const SAY_FEAST := "알부침이다! 다 모여!"

var ranch: Dictionary = {}            # {x, y, n, src, keeper, t} — 비면 목장 없음
var tend_day := -1                    # 단물을 받은 (또는 맡긴) 마지막 달력 날
var find_day := -1                    # 진딧물 찾기를 굴린 마지막 날
var bug_day := -1                     # 무당벌레를 굴린 마지막 날
var press_day := -1
var eggs: Array = []                  # {id, x, y, t, res(굴리러 간 사람 수), rolled(bool)}
var shells: Array = []                # {x, y, t, use: "basin"/"boat"} — 화면 (props/pf_eggshell)
var egg_last_t := -1.0e9              # 마지막 알이 떨어진 병 시각 (EGG_COOLDOWN)
var next_id := 1
var fine_t := -1.0e9                  # 마지막으로 좋은 빵을 구운 때
var stats := {"found": 0, "sky": 0, "tended": 0, "honeydew": 0.0, "ladybugs": 0, "eggs": 0, "feasts": 0, "pressed": 0.0,
	"milk": 0.0, "oil": 0.0, "binder": 0.0, "fine": 0, "bound": 0}


# ───────────────────────── 읽기 ─────────────────────────
func has_ranch() -> bool:
	return not ranch.is_empty() and int(ranch.get("n", 0)) > 0


func aphids() -> int:
	return int(ranch.get("n", 0)) if not ranch.is_empty() else 0


static func day_of(v: Village) -> int:
	return floori((v.start_clock + v.t) / Balance.DAY)


static func month_of(v: Village) -> int:
	return int(Health.jar_date(v)["month"])


## 상점 카드의 '못 사는 까닭' (비면 살 수 있음) — 메추리알 (3일에 하나 · 손에 하나)
func egg_lock(v: Village) -> String:
	if Shop.hand_count("메추리알") > 0 or not eggs.is_empty():
		return "손에 들고 있어요" if Shop.hand_count("메추리알") > 0 else "알을 아직 굴리는 중이에요"
	var left := Balance.EGG_COOLDOWN - (v.t - egg_last_t)
	if left > 0.0:
		return "병 %d일 뒤에 또" % maxi(1, ceili(left / Balance.DAY))
	return ""


## 진딧물 한 무리 — 목장이 가득하면 못 삼
func aphid_lock(_v: Village) -> String:
	if Shop.hand_count("진딧물 한 무리") > 0:
		return "손에 들고 있어요"
	if aphids() >= Balance.APHID_MAX:
		return "목장이 가득해요"
	return ""


# ───────────────────────── 정시 (Village.step — LAKE_EVERY마다) ─────────────────────────
static func hourly(v: Village) -> void:
	var k := v.kitchen
	if k == null or v.people.is_empty():
		return
	var day := day_of(v)
	var hr := floori(v.hour_now())
	var m := month_of(v)
	k._eggs_tick(v)
	if hr == Balance.APHID_FIND_HOUR and k.find_day != day:
		k.find_day = day
		k._try_find(v, m, day)
	if k.has_ranch() and m in Balance.APHID_MONTHS:
		if k.bug_day != day and hr >= int(Balance.TEND_HOURS[1]):
			k.bug_day = day
			k._ladybug(v, day)
		if k.tend_day != day and hr >= int(Balance.TEND_HOURS[0]) and hr < int(Balance.TEND_HOURS[1]):
			k._send_keeper(v, day)
	if hr == Balance.PRESS_HOUR and k.press_day != day:
		k.press_day = day
		k._press(v)


# ───────────────────────── 진딧물 목장 ─────────────────────────
func _try_find(v: Village, m: int, day: int) -> void:
	if not ranch.is_empty() or not m in Balance.APHID_FIND_MONTHS or not Production.bread_made(v):
		return
	if v.t < Balance.APHID_FIND_AGE or v.caterpillars == null or v.caterpillars.patches.is_empty():
		return
	if Wildlife._hash3(_hseed(v), 30449, day).x >= Balance.APHID_FIND_P:
		return
	var best: Resident = null
	var bp := Vector2.ZERO
	var bd := Balance.APHID_FIND_R * Balance.APHID_FIND_R
	for p: Dictionary in v.caterpillars.patches:
		var pp := Vector2(float(p["x"]), float(p["y"]))
		for r in v.people:
			if r.dead or r.sleeping or not r.is_adult():
				continue
			var d := Vector2(r.x, r.y).distance_squared_to(pp)
			if d < bd or (d == bd and best != null and r.id < best.id):
				bd = d
				best = r
				bp = pp
	if best == null:
		return
	start_ranch(v, bp + Vector2(1.1, 0.4), Balance.APHID_START, &"rose", best)


## 목장을 세움 (또는 진딧물을 보탬). src = &"rose" (찾음) · &"sky" (내려 줌)
func start_ranch(v: Village, at: Vector2, n: int, src: StringName, who: Resident = null) -> void:
	var fresh := ranch.is_empty() or int(ranch.get("n", 0)) <= 0
	if fresh:
		ranch = {"x": at.x, "y": at.y, "n": 0, "src": String(src), "keeper": who.id if who != null else -1, "t": v.t}
	ranch["n"] = mini(Balance.APHID_MAX, int(ranch["n"]) + n)
	stats["found" if src == &"rose" else "sky"] = int(stats["found" if src == &"rose" else "sky"]) + 1
	v.emit(&"aphids_found", {"who": who.id if who != null else -1, "at": Vector2(float(ranch["x"]), float(ranch["y"])),
		"v": {"src": src, "n": int(ranch["n"])}})
	if src == &"rose" and who != null:
		v.speak(who, SAY_FIND, 6)
		v.log_line(FIND_LINE % (who.name + Village.josa(who.name, "이", "가")))
	elif fresh and src == &"sky":
		v.log_line(SKY_LINE)              # (연대기 첫 줄 — 내려온 것은 SkyDrops.BOOK, 목장이 선 것은 여기)


## 마을마다 다른 해시 씨앗 (무리 번호 + 마을 난수의 씨앗 — 상태는 건드리지 않음)
static func _hseed(v: Village) -> int:
	return v.sid * 7919 + int(v.rng.seed % 100003)


## 부를 수 있는 어른 (prefer 먼저 · 한가한 사람 먼저 · 가까운 순 · 같으면 id 순). 짐을 든 사람·아기 돌보는 부모는 부르지 않는다.
## 일·나르기·짓기 하던 사람도 잠깐 부른다 (아침 단물 받기·큰 알 굴리기 — 둘 다 짧은 일)
static func _free_adults(v: Village, p: Vector2, n: int, prefer := -1) -> Array:
	var cs: Array = []
	for r in v.people:
		if r.dead or r.sleeping or not r.is_adult() or r.sick_left > 0.0 or r.injured_left > 0.0 or r.hunger >= 1.0:
			continue
		if not r.action in ["", "idle", "rest", "social", "wander", "chores", "play", "work", "haul", "build"] or r.carry != "":
			continue
		if Production.caring_for(v, r) != null:
			continue
		cs.append(r)
	cs.sort_custom(func(a: Resident, b: Resident) -> bool:
		if a.id == prefer or b.id == prefer:
			return a.id == prefer
		var ba := a.action in ["work", "haul", "build"]
		var bb := b.action in ["work", "haul", "build"]
		if ba != bb:
			return bb
		var da := Vector2(a.x, a.y).distance_squared_to(p)
		var db := Vector2(b.x, b.y).distance_squared_to(p)
		return da < db or (da == db and a.id < b.id))
	return cs.slice(0, n)


func _send_keeper(v: Village, day: int) -> void:
	var s := v.store()
	if s == null:
		return
	var at := Vector2(float(ranch["x"]), float(ranch["y"]))
	var got := _free_adults(v, at, 1, int(ranch.get("keeper", -1)))
	if got.is_empty():
		return                            # 다음 정시에 다시 (TEND_HOURS 안)
	var r: Resident = got[0]
	tend_day = day
	ranch["keeper"] = r.id
	ResidentAI.cancel(v, r)
	r.action = "work"
	r.last_action = "work"
	r.doing = "진딧물 목장에 단물을 받으러 가는 중"
	r.steps.append(ResidentAI.walk(at.x + 0.6, at.y + 0.5))
	r.steps.append(ResidentAI.act(Balance.TEND_TIME, "work", ResidentAI.op("kit_tend", {}), false))
	ResidentAI._drop_at_store(v, r, s, "단물", 0.0)


## 톡톡 — 단물을 손에 들고 (창고로 가는 걸음은 이미 있음), 돌본 날 진딧물이 늚
func tend(v: Village, r: Resident) -> void:
	if not has_ranch():
		r.doing = "빈손으로 돌아오는 중"
		return
	var amt := float(ranch["n"]) * Balance.HONEYDEW_PER
	if month_of(v) in Balance.APHID_MONTHS:
		ranch["n"] = mini(Balance.APHID_MAX, int(ranch["n"]) + Balance.APHID_GROW)
	r.carry = "단물"
	r.carry_amt = amt
	r.doing = "단물을 들고 오는 중"
	stats["tended"] = int(stats["tended"]) + 1
	stats["honeydew"] = float(stats["honeydew"]) + amt
	v.speak(r, SAY_TEND, 4)
	v.emit(&"honeydew_collected", {"who": r.id, "at": Vector2(float(ranch["x"]), float(ranch["y"])), "v": {"amt": amt, "n": int(ranch["n"])}})
	if int(stats["tended"]) == 1:
		v.log_line(FIRST_DEW_LINE)


func _ladybug(v: Village, day: int) -> void:
	if Wildlife._hash3(_hseed(v), 52711, day).y >= Balance.LADYBUG_P:
		return
	var lost := mini(Balance.LADYBUG_EAT, int(ranch["n"]))
	ranch["n"] = int(ranch["n"]) - lost
	stats["ladybugs"] = int(stats["ladybugs"]) + 1
	v.emit(&"ladybug_raid", {"at": Vector2(float(ranch["x"]), float(ranch["y"])), "v": {"lost": lost, "n": int(ranch["n"])}})
	var kp := v.person(int(ranch.get("keeper", -1)))
	if kp != null and not kp.sleeping:
		v.speak(kp, LADYBUG_SAY, 5)
	if int(ranch["n"]) <= 0:
		v.log_line(EMPTY_LINE)
		ranch = {}


# ───────────────────────── 하늘의 큰 알 ─────────────────────────
## SkyDrops.drop이 부름 (지폐는 이미 냄). 굴릴 사람을 곧바로 부른다
func land(v: Village, p: Vector2) -> Dictionary:
	var e := {"id": next_id, "x": p.x, "y": p.y, "t": v.t, "res": 0, "rolled": false}
	next_id += 1
	eggs.append(e)
	egg_last_t = v.t
	stats["eggs"] = int(stats["eggs"]) + 1
	v.emit(&"quail_egg_landed", {"at": p, "v": {"id": int(e["id"])}})
	_send_rollers(v, e)
	return e


func _egg(id: int) -> Dictionary:
	for e: Dictionary in eggs:
		if int(e["id"]) == id:
			return e
	return {}


func _send_rollers(v: Village, e: Dictionary) -> void:
	if int(e["res"]) > 0 or bool(e["rolled"]):
		return
	var s := v.store()
	var at := Vector2(float(e["x"]), float(e["y"]))
	var crew := _free_adults(v, at, Balance.EGG_CREW)
	if crew.is_empty():
		return
	var home := Vector2(s.x, s.y) if s != null else v.center
	e["res"] = crew.size()
	for i in crew.size():
		var r: Resident = crew[i]
		ResidentAI.cancel(v, r)
		r.action = "haul"
		r.last_action = "haul"
		r.doing = "하늘의 큰 알을 굴리러 가는 중"
		var a := TAU * i / float(crew.size()) + 0.3
		r.steps.append(ResidentAI.walk(at.x + cos(a) * 1.3, at.y + sin(a) * 1.3))
		r.steps.append(ResidentAI.act(Balance.EGG_ROLL_TIME, "work", ResidentAI.op("kit_egg_roll", {"e": int(e["id"])}), false, ResidentAI.op("kit_egg_quit", {"e": int(e["id"])})))
		r.steps.append(ResidentAI.walk(home.x + 1.6 + 0.5 * i, home.y - 1.0))
		r.steps.append(ResidentAI.act(30.0, "work", ResidentAI.op("kit_egg_crack", {"e": int(e["id"])}), false, ResidentAI.op("kit_egg_quit", {"e": int(e["id"])})))
	v.speak(crew[0], SAY_ROLL, 5)


## 정시: 아무도 굴리지 않은 알은 다시 사람을 부르고, EGG_WAIT가 지나면 그 자리에서 깸
func _eggs_tick(v: Village) -> void:
	for e: Dictionary in eggs.duplicate():
		if int(e["res"]) > 0:
			continue
		if v.t - float(e["t"]) >= Balance.EGG_WAIT:
			crack(v, e, null)
		else:
			_send_rollers(v, e)


## 깸 → 알(식량 EGG_DAYS일치, 전부 거인 몫) · 잔치 · 껍데기
func crack(v: Village, e: Dictionary, who: Resident) -> void:
	if not eggs.has(e):
		return
	eggs.erase(e)
	var at := Vector2(who.x, who.y) if who != null else Vector2(float(e["x"]), float(e["y"]))
	var food := roundf(maxf(1.0, float(v.people.size())) * Balance.DAY / Balance.FOOD_IV * Balance.EGG_DAYS)
	v.stock["알"] = float(v.stock.get("알", 0.0)) + food
	Production.gift_add(v, "알", food)
	v.festival_t = v.t
	var use := "boat" if _near_water(v, at) else "basin"
	shells.append({"x": at.x, "y": at.y, "t": v.t, "use": use})
	stats["feasts"] = int(stats["feasts"]) + 1
	v.emit(&"egg_feast", {"who": who.id if who != null else -1, "at": at, "v": {"food": food, "shell": StringName(use)}})
	if who != null:
		v.speak(who, SAY_FEAST, 6)
	v.log_line(FEAST_LINE)
	v.log_line(String(SHELL_LINES[use]))


static func _near_water(v: Village, p: Vector2) -> bool:
	var rr := Balance.SHELL_WATER_R
	for i in 8:
		var a := TAU * i / 8.0
		for f: float in [0.5, 1.0]:
			if v.water_at(p.x + cos(a) * rr * f, p.y + sin(a) * rr * f):
				return true
	return false


# ───────────────────────── 씨앗 방앗간 ─────────────────────────
func _press(v: Village) -> void:
	var mill: Building = null
	for b in v.buildings:
		if b.built and (b.type == "맷돌간" or b.type == "방앗간") and b.worker >= 0:
			mill = b
			break
	if mill == null:
		return
	var w := v.person(mill.worker)
	if w == null or w.sick_left > 0.0:
		return
	var seed_food := Balance.SEED_FOOD
	var have := float(v.stock.get("해바라기씨", 0.0))
	var n := minf(Balance.PRESS_SEEDS_DAY, floorf(have / seed_food))
	if n < 1.0 or v.food_total() < Production.day_need(v) * Balance.PRESS_FOOD_DAYS:
		return
	var amt := n * seed_food
	var gshare := minf(1.0, float(v.gift.get("해바라기씨", 0.0)) / have) if have > 0.0 else 0.0
	v.stock["해바라기씨"] = have - amt
	Production.gift_use(v, "해바라기씨", amt * gshare)
	var out := {"씨앗 반죽": 0.0, "씨앗 기름": 0.0, "씨앗 우유": 0.0}
	for i in int(n):
		var k := "씨앗 우유"
		if float(v.stock.get("씨앗 반죽", 0.0)) + float(out["씨앗 반죽"]) < Balance.BINDER_KEEP:
			k = "씨앗 반죽"
		elif float(v.stock.get("씨앗 기름", 0.0)) + float(out["씨앗 기름"]) < Balance.OIL_KEEP:
			k = "씨앗 기름"
		var q: float = {"씨앗 반죽": Balance.BINDER_PER_SEED, "씨앗 기름": Balance.OIL_PER_SEED, "씨앗 우유": seed_food * Balance.MILK_YIELD}[k]
		out[k] = float(out[k]) + q
	for k: String in out:
		if float(out[k]) > 0.0:
			v.stock[k] = float(v.stock.get(k, 0.0)) + float(out[k])
			if k == "씨앗 우유":
				Production.gift_add(v, k, float(out[k]) * gshare)     # 거인 몫은 같은 비율로 따라감 (village-economy R3-2)
	stats["pressed"] = float(stats["pressed"]) + n
	stats["milk"] = float(stats["milk"]) + float(out["씨앗 우유"])
	stats["oil"] = float(stats["oil"]) + float(out["씨앗 기름"])
	stats["binder"] = float(stats["binder"]) + float(out["씨앗 반죽"])
	v.emit(&"seed_pressed", {"who": w.id, "at": Vector2(mill.x, mill.y),
		"v": {"seeds": n, "milk": float(out["씨앗 우유"]), "oil": float(out["씨앗 기름"]), "binder": float(out["씨앗 반죽"])}})
	if float(stats["pressed"]) <= n:
		v.log_line(PRESS_LINE)


# ───────────────────────── 빵 (Village._update_building — 한 판마다) ─────────────────────────
static func on_bake(v: Village, b: Building, w: Resident) -> void:
	var k := v.kitchen
	if k == null:
		return
	if float(v.stock.get("씨앗 반죽", 0.0)) >= Balance.BINDER_PER_BAKE:
		v.stock["씨앗 반죽"] = float(v.stock["씨앗 반죽"]) - Balance.BINDER_PER_BAKE
		b.out["빵"] = float(b.out.get("빵", 0.0)) + Balance.BREAD_YIELD * Balance.BINDER_BONUS
		k.stats["bound"] = int(k.stats["bound"]) + 1
	var used := ""
	for s: String in ["단물", "씨앗 우유", "씨앗 기름"]:
		var need := Balance.OIL_PER_BAKE if s == "씨앗 기름" else Balance.SWEET_PER_BAKE
		var have := float(v.stock.get(s, 0.0))
		if have < need:
			continue
		v.stock[s] = have - need
		if s != "씨앗 기름":             # 단물·우유는 반죽에 들어가 그만큼 빵이 됨 (거인 몫도 따라감)
			b.out["빵"] = float(b.out.get("빵", 0.0)) + need
			var gu := Production.gift_use(v, s, need)
			if gu > 0.0:
				Production.gift_add(v, "빵", gu)
		used = s
		break
	if used == "":
		return
	k.fine_t = v.t
	k.stats["fine"] = int(k.stats["fine"]) + 1
	var key := "fine_" + used
	if not k.stats.has(key):
		k.stats[key] = v.t
		var nm := w.name + Village.josa(w.name, "이", "가") if w != null else "빵 굽는 이가"
		v.log_line(String(FINE_LINES[used]) % nm)
		v.emit(&"fine_bread", {"who": w.id if w != null else -1, "at": Vector2(b.x, b.y), "v": {"k": StringName(used)}})


## 행복: 지난 하루 빵을 먹었고, 그 하루 안에 좋은 빵을 구웠다 (Production.food_happy가 더함)
static func happy(v: Village) -> float:
	var k := v.kitchen
	if k == null:
		return 0.0
	if v.t - k.fine_t < Balance.DAY and v.t - v.ate_bread_t < Balance.DAY:
		return Balance.HAPPY_FINE_BREAD
	return 0.0


# ───────────────────────── 주민 걸음의 할 일 묶음 ("kit_*") ─────────────────────────
static func run_op(v: Village, r: Resident, d: Dictionary) -> void:
	var k := v.kitchen
	if k == null:
		return
	match String(d["op"]):
		"kit_tend":
			k.tend(v, r)
		"kit_egg_roll":
			var e := k._egg(int(d["e"]))
			if e.is_empty():
				r.doing = "빈손으로 돌아오는 중"
				return
			e["rolled"] = true
			r.doing = "하늘의 큰 알을 굴려 오는 중"
		"kit_egg_crack":
			var e2 := k._egg(int(d["e"]))
			if not e2.is_empty():
				k.crack(v, e2, r)
			r.doing = "잔치에 가는 중"
		"kit_egg_quit":                    # 도중에 그만둠 — 모두 빠지면 다음 정시에 다시 부름
			var e3 := k._egg(int(d["e"]))
			if not e3.is_empty():
				e3["res"] = maxi(0, int(e3["res"]) - 1)
				if int(e3["res"]) == 0:
					e3["rolled"] = false


# ───────────────────────── 저장 (판 VER) ─────────────────────────
func to_dict() -> Dictionary:
	return {"ver": VER, "ranch": ranch.duplicate(true), "tend_day": tend_day, "find_day": find_day, "bug_day": bug_day,
		"press_day": press_day, "eggs": eggs.duplicate(true), "shells": shells.duplicate(true), "egg_last_t": egg_last_t,
		"next_id": next_id, "fine_t": fine_t, "stats": stats.duplicate()}


static func from_dict(d: Dictionary) -> Kitchen:
	var k := Kitchen.new()
	k.ranch = (d.get("ranch", {}) as Dictionary).duplicate(true)
	for key: String in ["n", "keeper"]:
		if k.ranch.has(key):
			k.ranch[key] = int(k.ranch[key])
	k.tend_day = int(d.get("tend_day", -1))
	k.find_day = int(d.get("find_day", -1))
	k.bug_day = int(d.get("bug_day", -1))
	k.press_day = int(d.get("press_day", -1))
	for e: Variant in d.get("eggs", []):
		var q: Dictionary = (e as Dictionary).duplicate(true)
		q["id"] = int(q["id"])
		q["res"] = int(q["res"])
		k.eggs.append(q)
	k.shells = (d.get("shells", []) as Array).duplicate(true)
	k.egg_last_t = float(d.get("egg_last_t", -1.0e9))
	k.next_id = int(d.get("next_id", 1))
	k.fine_t = float(d.get("fine_t", -1.0e9))
	var st: Dictionary = d.get("stats", {})
	for key: String in st:
		k.stats[key] = st[key]
	for key: String in ["found", "sky", "tended", "ladybugs", "eggs", "feasts", "fine", "bound"]:
		k.stats[key] = int(k.stats.get(key, 0))
	return k
