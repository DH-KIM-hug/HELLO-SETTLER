## 주민이 무엇을 할지 — 점수제 결정과 행동 (RESIDENT_AI.md 4·5장, 고친 규칙 9장)
## 점수 = 기본 × 긴급도 × 시간대 가중치 × (1 + 특징 보정) × 신앙 상태 보정, 방금 한 행동 ×0.8.
## 가장 높은 행동부터 해 보고, 할 수 없으면(일감 없음 등) 다음 행동.
## 행동 = 걸음(steps) 목록: {k:"walk", x, y} → 목표까지 걷기 / {k:"do", left, anim, done, cancel} → 정해진 시간 수행.
## done·cancel은 Callable이 아니라 **할 일 묶음(op)** {op: 이름, ...값} — 저장했다가 그대로 이어 갈 수 있게 (docs/SAVE.md 1).
##   실행은 run_op (곰팡이 "mold_*"는 Mold.run_op, 하늘의 것 "flora_*"는 Flora.run_op). 값으로 나무·바위·낟알 무더기(Dictionary)·
##   건물(Building)을 그대로 붙잡는다 — 저장할 때 SaveCodec이 목록 자리·번호로 바꾼다.
## 원본: prototype/app.html decide·workTask·haulTask·buildTask·haulMannaTask
class_name ResidentAI
extends RefCounted

const WORKISH := {"work": true, "haul": true, "build": true}


static func walk(x: float, y: float) -> Dictionary:
	return {"k": "walk", "x": x, "y": y}


static func act(left: float, anim: String, done: Variant = null, fast := false, cancel: Variant = null) -> Dictionary:
	return {"k": "do", "left": left, "anim": anim, "done": done, "fast": fast, "cancel": cancel}


## 할 일 묶음 하나 만들기 — ResidentAI.op("stock_add", {"k": "통나무", "amt": 1.0})
static func op(name: String, args := {}) -> Dictionary:
	var o := {"op": name}
	o.merge(args)
	return o


## 할 일 묶음 실행 (걸음이 끝났을 때 done · 그만둘 때 cancel). o가 null이면 아무것도 안 함
static func run_op(v: Village, r: Resident, o: Variant) -> void:
	if o == null:
		return
	var d: Dictionary = o
	var n: String = d["op"]
	if n.begins_with("flora_"):
		v.flora.run_op(v, r, d)
		return
	if n.begins_with("mold_"):
		v.mold.run_op(v, r, d)
		return
	if n.begins_with("crisis_"):         # [작은 위기] 모깃불·먼지 뭉치 뜯기 (sim/small_crises.gd)
		v.smalls.run_op(v, r, d)
		return
	if n.begins_with("cat_"):            # 애벌레 잡이·고치 (sim/caterpillars.gd — production-chain R7-5)
		Caterpillars.run_op(v, r, d)
		return
	if n.begins_with("wild_"):           # [들짐승] 낚시·사냥·울타리 (sim/wildlife.gd)
		Wildlife.run_op(v, r, d)
		return
	if n.begins_with("social_"):         # [마을의 삶] 이야기가 끝나면 하던 일 이름으로 (sim/social.gd)
		Social.run_op(v, r, d)
		return
	if n.begins_with("gplant_"):         # 씨앗비 씨앗 굴리기 · 목화 솜뭉치 (sim/giant_plants.gd)
		GiantPlants.run_op(v, r, d)
		return
	if n.begins_with("fruit_"):          # (E3-3) 거대한 열매 자르기·나르기 (sim/great_trees.gd)
		GreatTrees.run_op(v, r, d)
		return
	if n.begins_with("kit_"):            # 진딧물 목장 톡톡·큰 알 굴리기 (sim/kitchen.gd — E3-14)
		Kitchen.run_op(v, r, d)
		return
	if n.begins_with("sky_"):            # [상점] 하늘에서 내려온 것 깎아 나르기 (sim/sky_drops.gd)
		SkyDrops.run_op(v, r, d)
		return
	match n:
		"stock_add":                      # 창고에 더함 (나른 물건 내려놓기 · 그만두면 되돌리기)
			v.stock[d["k"]] = float(v.stock.get(d["k"], 0.0)) + float(d["amt"])
		"stroll_meet":                    # 유모차 산책: 곁의 이웃이 멈춰 들여다보고 웃는다 (행복 +)
			var seen := 0
			for q in v.people:
				if q == r or q.sleeping or q.is_baby() or seen >= 3:
					continue
				if Vector2(q.x - r.x, q.y - r.y).length() < Balance.STROLL_R:
					q.happiness = minf(1.0, q.happiness + Balance.STROLL_HAPPY)
					seen += 1
					if seen == 1:
						v.speak(q, "아이 귀여워!" if not q.is_child() else "아기다!", 5)
			v.stats["strolls"] = int(v.stats.get("strolls", 0)) + 1
		"stroll_end":
			if r.carry == "유모차":
				r.carry = ""
				r.carry_amt = 0.0
		"explore_clear":
			if v.explorer == r.id:
				v.explorer = -1
		"explore_look":
			r.doing = "집으로 돌아가는 중"
			v._reveal_at(Vector2(r.x, r.y), WorldCfg.REVEAL_LOOK, r, true)
		"meal":
			r.meal_done = int(d["mk"])
		"pray":
			r.belief = minf(1.0, r.belief + Balance.BELIEF_PRAYER)
		"pray_chapel":                    # 교회에서 (사제가 있으면 믿음 조금 더 — A6)
			var chb := VillageEra.first_built(v, "교회")
			r.belief = minf(1.0, r.belief + Balance.BELIEF_PRAYER + (Balance.CHAPEL_BELIEF if VillageEra.staffed(v, chb) else 0.0))
		"chop":                           # v5: 나무 한 그루 = 통나무 TREE_LOGS개 — 한 번에 들 만큼 (나머지는 다음에), 다 쓰면 그루터기
			var tr: Dictionary = d["tr"]
			var left := int(tr.get("logs", Balance.TREE_LOGS))
			var take := mini(left, r.carry_cap())
			left -= take
			tr["logs"] = left
			tr["res"] = 0
			if left <= 0:
				tr["s"] = "stump"                 # 그루터기는 다시 자라지 않고 2~3일 뒤 썩어 사라진다 (Village._update_trees)
				tr["g"] = v.rng.randf_range(Balance.STUMP_ROT[0], Balance.STUMP_ROT[1])
				tr.erase("logs")
			r.carry = "통나무"
			r.carry_amt = float(take)
		"unres":                          # 나무·바위 예약 풀기
			var q: Dictionary = d["q"]
			q["res"] = 0
		"plant":
			v.trees.append({"x": float(d["x"]), "y": float(d["y"]), "s": "sapling", "g": Balance.SAPLING_GROW, "res": 0})
		"dig":                            # v5: 한 번에 들 만큼 캔다 (걸음이 느려져서)
			var rk: Dictionary = d["rk"]
			var dn := mini(int(rk["amt"]), r.carry_cap())
			rk["amt"] = int(rk["amt"]) - dn
			rk["res"] = 0
			r.carry = String(rk.get("ore", "돌"))
			r.carry_amt = float(maxi(dn, 1))
		"pick":                           # 짐을 집어 듦
			r.carry = d["item"]
			r.carry_amt = float(d["amt"])
		"put":                            # 짐을 내려놓음 (drop 실행 뒤 빈손)
			run_op(v, r, d["drop"])
			r.carry = ""
			r.carry_amt = 0.0
		"store_put":                      # 손에 든 것을 창고에 (든 양 — 없으면 적힌 양)
			var amt := r.carry_amt if r.carry_amt > 0.0 else float(d["amt"])
			v.stock[d["k"]] = float(v.stock.get(d["k"], 0.0)) + amt
			r.carry = ""
			r.carry_amt = 0.0
		"carry_back":                     # 나르다 그만둠 — 든 것을 창고에 (v5)
			if r.carry_amt > 0.0:
				v.stock[d["k"]] = float(v.stock.get(d["k"], 0.0)) + r.carry_amt
		"site_put":
			var b: Building = d["b"]
			var k: String = d["k"]
			b.incoming[k] = int(b.incoming[k]) - int(d["amt"])
			b.delivered[k] = int(b.delivered[k]) + int(d["amt"])
		"site_undo":
			var b: Building = d["b"]
			var k: String = d["k"]
			b.incoming[k] = int(b.incoming[k]) - int(d["amt"])
			v.stock[k] = float(v.stock[k]) + int(d["amt"])
		"inbuf_put":
			var b: Building = d["b"]
			var k: String = d["k"]
			b.in_inc[k] = float(b.in_inc[k]) - float(d["amt"])
			b.in_buf[k] = float(b.in_buf.get(k, 0.0)) + float(d["amt"])
			if float(d.get("gift", 0.0)) > 0.0:       # v5: 거인이 준 재료 몫 → 가공품도 거인 몫
				b.gift_in[k] = float(b.gift_in.get(k, 0.0)) + float(d["gift"])
		"inbuf_undo":
			var b: Building = d["b"]
			var k: String = d["k"]
			b.in_inc[k] = float(b.in_inc[k]) - float(d["amt"])
			v.stock[k] = float(v.stock[k]) + float(d["amt"])
			Production.gift_add(v, k, float(d.get("gift", 0.0)))     # 나르다 그만둠 — 거인 몫도 창고로 되돌림
		"manna_pick":
			var m: Dictionary = d["m"]
			var take := minf(float(d["cap"]), m["amt"])
			m["amt"] = float(m["amt"]) - take
			m["res"] = int(m["res"]) - 1
			r.carry = "낟알"
			r.carry_amt = take
		"manna_unres":
			var m: Dictionary = d["m"]
			m["res"] = int(m["res"]) - 1
		"manna_put":
			if r.carry_amt > 0.0:
				v.manna_batches.append({"amt": r.carry_amt, "born": float(d["born"])})
			r.carry = ""
			r.carry_amt = 0.0
		"manna_undo":
			if r.carry_amt > 0.0:
				v.manna_batches.append({"amt": r.carry_amt, "born": float(d["born"])})
		"carry_set":                              # (E1-2) 제단에 쌓을 돌을 안음 / 내려놓음 (보이는 것만 — 창고와 상관없음)
			r.carry = String(d["item"])
			r.carry_amt = 0.0
		"build":
			var b: Building = d["b"]
			if bool(d.get("drop", false)):
				r.carry = ""
			if not b.is_site():
				return
			b.prog += float(d["chunk"]) * v.build_mult(b) * v.opening_build(b)    # 들어준 소원 ×1.5 (기획서 6.7) · 첫 한 시간의 터는 천천히
			if b.prog >= float(Balance.B[b.site_type()]["time"]) - 1e-3:
				v.on_built(b)
				v.speak(r, "%s 완성!" % b.label(), 5)
		_:
			push_error("ResidentAI.run_op: 모르는 할 일 %s" % n)


static func near(v: Village, x: float, y: float, r := 1.2) -> Vector2:
	var a := v.rng.randf() * TAU
	return Vector2(x + cos(a) * r, y + sin(a) * r)


## 하던 일을 그만둔다 — 들고 있던 짐·예약은 되돌린다 (죽음 등)
static func cancel(v: Village, r: Resident) -> void:
	for s: Dictionary in r.steps:
		if s.get("cancel") != null:
			run_op(v, r, s["cancel"])
	r.steps.clear()
	r.carry = ""
	r.carry_amt = 0.0


# ───────────────────────── 한 걸음 ─────────────────────────
static func update(v: Village, r: Resident, dt: float) -> void:
	var left := dt
	var decisions := 0
	var max_dec := 3 * maxi(1, int(dt / Balance.AWAY_STEP))     # 걸음 30초에 3번 — 따라잡기 빠른 길(더 큰 걸음)도 같은 빈도로 마음을 정한다
	while left > 1e-6:
		if r.steps.is_empty():
			if decisions >= max_dec:
				break
			decide(v, r)
			decisions += 1
			if r.steps.is_empty():
				break
		var s: Dictionary = r.steps[0]
		var used := 0.0
		if s["k"] == "walk":
			if not s.has("rt"):
				VillageEra.route(v, r, s)          # 강 건너: 나루터로 돌아가는 게 빠르면 (A6) — 걸음이 늘면 첫 걸음부터 다시
				if r.steps[0] != s:
					continue
				VillagePlan.route(v, r, s)         # [길] 길을 따라 (sim/village_plan.gd) — 사이 걸음이 끼면 첫 걸음부터
				if r.steps[0] != s:
					continue
			var to := Vector2(s["x"], s["y"])
			var from := Vector2(r.x, r.y)
			var d := to - from
			var dd := d.length()
			var wm := VillageEra.wade_mult(v, r.x, r.y)          # 물을 걸어 건너면 느리다 · 나루터의 뗏목 길은 그대로
			var sp := r.walk_speed() * v.path_mult(r.x, r.y) * wm * v.pace_walk()     # 흙길 위는 빠르다 (기획서 6.7) · v5 첫날 배율
			var can := sp * left
			if dd > 1e-4:
				r.facing = atan2(d.x, d.y)
			if dd <= can:
				r.x = to.x
				r.y = to.y
				used = dd / sp
				r.steps.pop_front()
				v.mark_path_seg(from, to)
			else:
				r.x += d.x / dd * can
				r.y += d.y / dd * can
				used = left
				v.mark_path_seg(from, Vector2(r.x, r.y))
			if wm < 1.0:
				VillageEra.note_wade(v, used)
			r.anim = "carry" if r.carry != "" else "walk"
		else:
			var speed: float = r.job_speed(_job_kind(v, r)) if s["fast"] else 1.0
			if s["anim"] == "work" and not (s["done"] is Dictionary and String(s["done"].get("op", "")) == "build"):
				speed *= v.pace_act()             # v5: 첫날·첫 한 시간의 채집 동작은 느린 병 시계에 맞춰 짧게
			var need: float = s["left"] / speed
			r.anim = s["anim"]
			if need <= left:
				used = need
				r.steps.pop_front()
				if s["done"] != null:
					run_op(v, r, s["done"])
			else:
				s["left"] = float(s["left"]) - left * speed
				used = left
		left -= used
		if WORKISH.has(r.action):
			r.work_secs_today += used
	if r.steps.is_empty() and r.anim == "walk":
		r.anim = "idle"


## 지금 하는 일의 종류 (혈통 작업 빠르기용): 짓기 / 일터 종류
static func _job_kind(v: Village, r: Resident) -> String:
	if r.action == "build":
		return "짓기"
	if r.fx.is_empty():
		return ""
	var jb := v.bld(r.job)
	return jb.type if jb != null else ""


# ───────────────────────── 점수제 결정 ─────────────────────────
static func decide(v: Village, r: Resident) -> void:
	var h := v.hour_now()
	r.sleeping = false
	if r.is_baby():
		_baby(v, r)
		return
	if r.sick_left > 0.0:             # 앓는 동안 일하지 않고 집(없으면 모닥불 곁)에서 쉼 (HEALTH.md 2)
		_sick_rest(v, r)
		return
	if Mold.decide(v, r):              # [곰팡이·뚜껑] 털뭉치를 피해 숨기 · 횃불로 쫓기 · 곰팡이약 만들기 (WORLD_EVENTS 2.1)
		return
	if SmallCrises.decide(v, r):       # [작은 위기] 물방울 아래에서 비키기 · 날벌레를 피해 숨기 · 모깃불 · 먼지 뭉치 뜯기 (WORLD_EVENTS 2.2)
		return
	if Flora.decide(v, r):             # [하늘의 것] 큰 민들레 꽃잎·솜털·잎 따기 (WORLD_EVENTS 2.7)
		return
	if Wildlife.decide(v, r):          # [들짐승] 쉬는 아이·노인이 물가에서 낚싯대 (WILDLIFE 2)
		return
	var night := v.is_night()
	var late := r.f("wake_late", 0.0)        # 혈통 '잠꾸러기': 아침에 1시간 늦게
	if late > 0.0 and h >= Balance.NIGHT_TO and h < Balance.NIGHT_TO + late:
		night = true
	var work_t := v.is_work_time()
	var cand := {}
	if night:
		cand["sleep"] = Balance.ACT_BASE["sleep"] * Balance.W_NIGHT_SLEEP
	if r.hunger >= Balance.HUNGRY_AT:
		cand["eat"] = Balance.ACT_BASE["eat"] * (1.0 + r.hunger)
	elif not night:
		var mk := _meal_key(v, h)
		if mk >= 0 and r.meal_done != mk:
			cand["eat"] = Balance.ACT_BASE["eat"] * Balance.W_MEAL
	var opening := v.in_opening()
	# 첫 한 시간: 어른은 도착하고 잠깐만 낟알을 줍고 일하러 간다 (나머지는 아이들이 줍는다 — OPENING 3.1)
	var manna_ok := r.is_child() or not opening or v.t < Balance.OPENING_MANNA_ADULT
	if manna_ok and not v.manna.is_empty() and h < 11.0 and not night and r.age >= 2.5:
		cand["manna"] = Balance.ACT_BASE["manna"] * (Balance.W_DAWN_MANNA if h < 8.0 else 1.0)
	var hurt := r.injured_left > 0.0       # 다치면 힘쓰는 일(벌목·채석·짓기·나르기) 대신 가벼운 일 (HEALTH.md 3)
	var baby := Production.caring_for(v, r)     # v5 (GD 7.3): 아기를 돌보는 부모는 일터·짐·짓기 대신 집에서 돌봄 (가끔 유모차 산책)
	if baby != null and not night:
		cand["care"] = Balance.ACT_BASE["work"] * Balance.W_DAY_WORK
	if r.is_adult() and baby == null:
		if r.job >= 0 and not (hurt and _heavy_job(v, r)) and work_task(v, r, true):
			cand["work"] = Balance.ACT_BASE["work"] * (Balance.W_DAY_WORK if work_t else Balance.W_NIGHT_WORK)
		if work_t and not hurt:
			var n := haul_requests(v)
			if n > 0:
				cand["haul"] = Balance.ACT_BASE["haul"] * minf(1.5, 1.0 + 0.1 * n) * Balance.W_DAY_WORK
			var site := _ready_site(v)
			if site != null:
				var g := v.build_mult(site)          # 들어준 소원의 터는 더 서둘러 짓는다
				cand["build"] = Balance.ACT_BASE["build"] * 1.2 * Balance.W_DAY_WORK * g
	# [상점] 하늘에서 내려온 바깥 크기의 물건: 몰려와 깎아 창고로 (WORLD_EVENTS 1.1) — 낮에, 어른 (아이는 먹을 것만 조금씩)
	if work_t and not hurt and r.age >= 2.5 and not v.drops.is_empty() and SkyDrops.carve_open(v):
		cand["carve"] = Balance.ACT_BASE["haul"] * 1.4 * Balance.W_DAY_WORK * (1.0 if r.is_adult() else 0.5)
	if not night and r.age >= 2.5 and not opening and v.altar_built:     # 제단이 생기기 전엔 기도가 없다 (A4b — 기획서 6.5). 첫 한 시간엔 따로 기도하지 않는다 — 첫 집이 서면 다 같이 감사 기도 (Village.thanksgiving)
		var worries := 1.0 + (1.0 if v.deficit > 0.0 else 0.0) + (0.5 if r.home < 0 else 0.0)
		# 저녁(일이 끝난 뒤) ×2, 저녁 일하는 시간엔 ×1, 낮엔 ×0.5. 믿음이 깊을수록 자주
		var pw := Balance.W_EVENING_PRAY if h >= Balance.WORK_TO else (1.0 if h >= Balance.EVENING_FROM else Balance.W_DAY_PRAY)
		cand["pray"] = Balance.ACT_BASE["pray"] * worries * pw * r.belief
	if not night and r.age >= Balance.AGE_ADULT and not (opening and r.is_adult()):     # 첫 한 시간의 어른은 노닥이지 않는다
		cand["social"] = Balance.ACT_BASE["social"] * (Balance.W_EVENING_SOCIAL if h >= Balance.WORK_TO else 1.0)
	if r.is_child() and work_t:
		cand["play"] = Balance.ACT_BASE["play"]
	if work_t and r.is_adult() and r.home >= 0 and not opening:      # v5: 일 없는 낮 — 텃밭·집 손보기·아이와 놀기·집 앞에서 쉬기
		cand["chores"] = Balance.ACT_BASE["chores"]
	if r.is_elder() and not night:
		cand["rest"] = Balance.ACT_BASE["rest"]
	# 탐험 (넓은 세상만 — 6단계): 무리마다 가끔 한 명이 안개 가장자리로
	if v.explore_on and work_t and r.is_adult() and v.can_explore(r):
		cand["explore"] = WorldCfg.EXPLORE_BASE * r.f("explore")
	# 방랑벽 (혈통): 가끔 일을 놓고 멀리 걸어감
	if work_t and r.is_adult() and r.f("wander", 0.0) > 0.0 and v.gene_rng.randf() < Bloodlines.WANDER_P:
		cand["wander"] = 100.0
	# 추위·더위 (HEALTH.md 1.4): 밖의 정도가 0.5를 넘으면 집·불가로 (일을 일찍 접음). 더위는 한낮(12~15시)에 쉼
	if not night and r.age >= 2.5:
		var od := Health.outdoor(v, r.x, r.y)
		var sh := 0.0
		if od.x > Balance.SHELTER_AT:
			sh = od.x
		if od.y > Balance.SHELTER_AT and h >= Balance.HEAT_REST_HOURS[0] and h < Balance.HEAT_REST_HOURS[1]:
			sh = maxf(sh, od.y)
		if sh > 0.0:
			cand["shelter"] = Balance.SHELTER_SCORE * sh
	# 두려움 0.6↑ (HEALTH.md 4): 일 점수 ×0.7, 가끔 집으로 숨음
	var afraid := r.fear >= Balance.FEAR_HIGH
	if afraid and not night and r.age >= 2.5 and v.health_rng.randf() < Balance.FEAR_HIDE_P:
		cand["hide"] = 100.0
	# 보정
	var fs: Dictionary = Balance.FAITH_STATE_MOD.get(v.faith_state(), {})
	var order: Array = []
	for k: String in cand:
		var s: float = cand[k] * (1.0 + float(r.trait_mod.get(k, 0.0))) * float(fs.get(k, 1.0))
		if afraid and k == "work":
			s *= Balance.FEAR_WORK
		if k == r.last_action:
			s *= Balance.REPEAT_MULT
		s += v.rng.randf() * 0.2
		order.append([s, k])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for o: Array in order:
		var k: String = o[1]
		if _do(v, r, k, h):
			r.action = k
			r.last_action = k
			return
	r.action = "idle"
	r.doing = "쉬는 중"
	var p := near(v, v.fire.x, v.fire.y, 2.5)
	r.steps.append(walk(p.x, p.y))
	r.steps.append(act(30.0 if v.in_opening() else Balance.IDLE_TIME, "idle"))     # 첫 한 시간엔 잠깐만 쉬고 다시 일감을 본다


static func _meal_key(v: Village, h: float) -> int:
	for i in Balance.MEALS.size():
		var m: Array = Balance.MEALS[i]
		if h >= m[0] and h < m[1]:
			return int((v.start_clock + v.t) / Balance.DAY) * 3 + i
	return -1


static func _do(v: Village, r: Resident, k: String, h: float) -> bool:
	match k:
		"sleep":
			return _sleep(v, r)
		"eat":
			return _eat(v, r, h)
		"manna":
			return haul_manna_task(v, r)
		"work":
			return work_task(v, r, false)
		"haul":
			return haul_task(v, r)
		"carve":
			return SkyDrops.carve_task(v, r)
		"build":
			return build_task(v, r)
		"pray":
			return _pray(v, r)
		"social":
			var p := near(v, v.fire.x, v.fire.y, 2.5)
			r.doing = "어울리는 중"
			var ss: Variant = VillageEra.social_spot(v, v.rng.randf() * TAU) if VillageEra.has_social_place(v) else null     # (A6) 혼례 잔치는 교회 앞 · 광장이 있으면 광장
			if ss != null:
				p = ss
				r.doing = "혼례 잔치에 어울리는 중" if VillageEra.wedding_on(v) else ("장터에서 어울리는 중" if VillageEra.is_market_day(v) else "광장에서 어울리는 중")
			r.steps.append(walk(p.x, p.y))
			r.steps.append(act(Balance.SOCIAL_TIME[0] + v.rng.randf() * Balance.SOCIAL_TIME[1], "sit"))
			return true
		"play":
			var c := Vector2(v.fire.x, v.fire.y)
			var hm := v.bld(r.home)
			if hm != null:
				c = Vector2(hm.x, hm.y)
			var pa := _working_parent(v, r)          # 일하는 엄마·아빠 곁에서 논다
			if pa != null:
				c = Vector2(pa.x, pa.y)
			var p := near(v, c.x, c.y, 2.5 + v.rng.randf() * 2.0)
			r.doing = "노는 중"
			r.steps.append(walk(p.x, p.y))
			r.steps.append(act(Balance.PLAY_TIME[0] + v.rng.randf() * Balance.PLAY_TIME[1], "play"))
			return true
		"shelter":
			return _shelter(v, r)
		"hide":
			return _hide(v, r)
		"explore":
			return _explore(v, r)
		"wander":
			return _wander(v, r)
		"rest":
			var p := near(v, v.fire.x, v.fire.y, 2.0)
			r.doing = "모닥불 곁에서 쉬는 중"
			r.steps.append(walk(p.x, p.y))
			r.steps.append(act(Balance.REST_TIME[0] + v.rng.randf() * Balance.REST_TIME[1], "sit"))
			return true
		"care":
			return _care(v, r)
		"chores":
			return _chores(v, r)
	return false


## v5 (GD 7.3) 아기 돌봄: 집에서 흔들고 먹이고 안아 줌. 낮에 가끔 나무 유모차(바구니 수레)를 끌고 마을을 한 바퀴 —
## 지나가던 이웃이 멈춰 들여다보고 웃는다 (본 사람 행복 조금↑). 걷는 길은 집 → 모닥불 곁 → 광장(있으면) → 집
static func _care(v: Village, r: Resident) -> bool:
	var hm := v.bld(r.home)
	if hm == null:
		return false
	var baby := Production.caring_for(v, r)
	var bn := baby.name if baby != null else "아기"
	if v.is_work_time() and v.rng.randf() < Balance.STROLL_P and not v.in_opening():
		r.doing = "%s 유모차를 끌고 산책하는 중" % bn
		r.carry = "유모차"
		r.carry_amt = 1.0
		var a := near(v, v.fire.x, v.fire.y, 3.0)
		r.steps.append(walk(a.x, a.y))
		r.steps.append(act(120.0, "carry", op("stroll_meet", {"name": bn})))
		var pz := VillageEra.first_built(v, "광장")
		if pz != null:
			var q := near(v, pz.x, pz.y, 2.0)
			r.steps.append(walk(q.x, q.y))
			r.steps.append(act(120.0, "carry", op("stroll_meet", {"name": bn})))
		r.steps.append(walk(hm.x, hm.y + 0.4))
		r.steps.append(act(3.0, "idle", op("stroll_end"), false, op("stroll_end")))
		return true
	var obj := bn + Village.josa(bn, "을", "를")
	var acts := [["%s 흔들어 재우는 중" % obj, "sit"], ["%s에게 젖을 먹이는 중" % bn, "sit"], ["%s 안고 어르는 중" % obj, "idle"]]
	var pick: Array = acts[v.rng.randi() % acts.size()]
	r.doing = String(pick[0])
	r.steps.append(walk(hm.x + 0.3, hm.y + 0.4))
	r.steps.append(act(Balance.CHORE_TIME[0], String(pick[1])))
	return true


## v5: 일 없는 낮 — 집 앞 텃밭·집 손보기·아이와 놀기·집 앞에 앉아 쉬기 (기도만 하지 않게)
static func _chores(v: Village, r: Resident) -> bool:
	var hm := v.bld(r.home)
	if hm == null or not hm.built:
		return false
	var kids := false
	for q in v.people:
		if q.home == r.home and q.is_child() and not q.is_baby() and q.id != r.id:
			kids = true
			break
	var opts := [["집 앞 텃밭을 돌보는 중", "work"], ["집을 손보는 중", "work"], ["집 앞에 앉아 쉬는 중", "sit"]]
	if kids:
		opts.append(["아이들과 노는 중", "play"])
	var pick: Array = opts[v.rng.randi() % opts.size()]
	r.doing = String(pick[0])
	var p := near(v, hm.x, hm.y, 1.2 + hm.size() * 0.5)
	r.steps.append(walk(p.x, p.y))
	r.steps.append(act(Balance.CHORE_TIME[0] + v.rng.randf() * Balance.CHORE_TIME[1], String(pick[1])))
	return true


## 탐험: 안개 가장자리까지 걸어가 둘러보고 돌아온다 (걷는 길과 둘러본 둘레의 안개가 걷힌다)
static func _explore(v: Village, r: Resident) -> bool:
	var tg: Variant = v.explore_target()
	v.last_explore_t = v.t
	if tg == null:
		return false
	var p: Vector2 = tg
	v.explorer = r.id
	v.stats["explore"] = int(v.stats.get("explore", 0)) + 1
	r.doing = "안개 너머를 살피러 가는 중"
	var clear := op("explore_clear")
	var look := op("explore_look")
	r.steps.append(walk(p.x, p.y))
	r.steps.append(act(WorldCfg.EXPLORE_LOOK_TIME, "idle", look, false, clear))
	var hp := near(v, v.fire.x, v.fire.y, 2.5)
	r.steps.append(walk(hp.x, hp.y))
	r.steps.append(act(1.0, "idle", clear, false, clear))
	return true


## 방랑: 마을에서 먼 곳까지 걸어갔다가 돌아온다 (넓은 세상이면 지나는 길의 안개가 조금 걷힌다)
static func _wander(v: Village, r: Resident) -> bool:
	for i in 6:
		var a := v.gene_rng.randf() * TAU
		var d := v.gene_rng.randf_range(Bloodlines.WANDER_DIST[0], Bloodlines.WANDER_DIST[1])
		var p := Vector2(r.x, r.y) + Vector2(cos(a), sin(a)) * d
		if v.water.inside(p.x, p.y, 3.0) and not v.water_at(p.x, p.y):
			r.doing = "괜히 먼 데까지 걸어가는 중"
			r.steps.append(walk(p.x, p.y))
			r.steps.append(act(60.0 + v.gene_rng.randf() * 120.0, "idle"))
			var hp := near(v, v.fire.x, v.fire.y, 2.5)
			r.steps.append(walk(hp.x, hp.y))
			return true
	return false


## 밖에서 일하고 있는 부모 (없으면 null)
static func _working_parent(v: Village, r: Resident) -> Resident:
	for id in r.parents:
		var pa := v.person(id)
		if pa != null and WORKISH.has(pa.action) and not pa.steps.is_empty():
			return pa
	return null


static func _heavy_job(v: Village, r: Resident) -> bool:
	var jb := v.bld(r.job)
	return jb != null and (jb.type == "나무꾼" or jb.type == "채석장")


## 앓는 사람: 집에 누움 (집이 없으면 모닥불 곁)
static func _sick_rest(v: Village, r: Resident) -> void:
	var hm := v.bld(r.home)
	var p := Vector2(hm.x, hm.y + 0.3) if (hm != null and hm.built) else near(v, v.fire.x, v.fire.y, 1.4)
	r.action = "sick"
	r.doing = "앓아누운 중" if (hm != null and hm.built) else "모닥불 곁에 앓아누운 중"
	var bed: Variant = VillageEra.clinic_bed(v, r)       # (A6) 약초사가 있는 치료소에 빈 자리가 있으면 툇마루에 누움
	if bed != null:
		p = bed
		r.doing = "치료소에 누운 중"
	r.sleeping = v.is_night()
	r.steps.append(walk(p.x, p.y))
	r.steps.append(act(minf(600.0, maxf(60.0, r.sick_left)), "sleep"))


## 추위·더위를 피해 집으로 (집이 없거나 불 땔 땔감이 없으면 추울 땐 모닥불 곁)
static func _shelter(v: Village, r: Resident) -> bool:
	var hm := v.bld(r.home)
	var od := Health.outdoor(v, r.x, r.y)
	var cold := od.x >= od.y
	var p: Vector2
	if hm != null and hm.built and (not cold or hm.fuel_on or float(hm.in_buf.get("통나무", 0.0)) >= 1.0):
		p = Vector2(hm.x, hm.y + 0.3)
		r.doing = "집에서 몸을 녹이는 중" if cold else "집 안에서 더위를 피하는 중"
	elif cold:
		p = near(v, v.fire.x, v.fire.y, 1.6)
		r.doing = "모닥불 곁에서 몸을 녹이는 중"
	else:
		return false
	r.steps.append(walk(p.x, p.y))
	r.steps.append(act(1200.0, "sit"))
	return true


## 두려움: 집으로 숨는다
static func _hide(v: Village, r: Resident) -> bool:
	var hm := v.bld(r.home)
	if hm == null or not hm.built:
		return false
	r.doing = "집에 숨어 있는 중"
	v.speak(r, Balance.LINE_FEAR, 5)
	r.steps.append(walk(hm.x, hm.y + 0.3))
	r.steps.append(act(900.0, "sit"))
	return true


static func _baby(v: Village, r: Resident) -> void:
	# 아기는 집 안 (기획서 7.3). 집이 없으면 모닥불 곁
	var hm := v.bld(r.home)
	var p := Vector2(hm.x, hm.y) if hm != null else near(v, v.fire.x, v.fire.y, 1.0)
	r.x = p.x
	r.y = p.y
	r.action = "baby"
	r.doing = "집 안의 아기" if hm != null else "모닥불 곁의 아기"
	r.sleeping = v.is_night()
	r.steps.append(act(600.0, "sleep" if hm != null else "sit"))


static func _sleep(v: Village, r: Resident) -> bool:
	var hm := v.bld(r.home)
	var p := Vector2(hm.x, hm.y + 0.3) if hm != null else near(v, v.fire.x, v.fire.y, 1.4)
	var until_morning := fmod((Balance.NIGHT_TO + r.f("wake_late", 0.0)) * Balance.HOUR - v.clock() + Balance.DAY, Balance.DAY)
	r.doing = "집에서 자는 중" if hm != null else "모닥불 곁에서 자는 중"
	r.sleeping = true
	r.steps.append(walk(p.x, p.y))
	r.steps.append(act(clampf(until_morning, 60.0, 2.0 * Balance.HOUR), "sleep"))
	return true


static func _eat(v: Village, r: Resident, h: float) -> bool:
	if r.hunger >= Balance.HUNGRY_AT:
		var s := v.store()
		var p := near(v, s.x, s.y, 2.0)
		r.doing = "먹을 것을 찾는 중"
		v.speak(r, "배고파요…", 5)
		r.steps.append(walk(p.x, p.y))
		r.steps.append(act(120.0, "idle"))
		return true
	# 식사 시간 — 모닥불에 모여 앉아 죽을 먹음 (식량은 마을 전체에서 집계로 줄어든다)
	var mk := _meal_key(v, h)
	var p := near(v, v.fire.x, v.fire.y, 1.8)
	r.doing = "밥 먹는 중"
	r.steps.append(walk(p.x, p.y))
	r.steps.append(act(Balance.MEAL_TIME * 0.5, "eat", op("meal", {"mk": mk})))
	return true


static func _pray(v: Village, r: Resident) -> bool:
	r.doing = "기도하는 중"
	var a := v.rng.randf() * TAU                  # 제단 둘레 고리에서 제단을 바라보며 (near와 같은 난수 하나)
	var tw: Variant = SkyDrops.tower_pray(v, r)   # [상점] 하늘의 탑이 있으면 몇은 탑 아래에서 (성소 — WORLD_EVENTS 4.4)
	if tw != null:
		var tp: Vector2 = tw
		var q := tp + Vector2(cos(a), sin(a)) * SkyDrops.TOWER_RING
		r.doing = "하늘의 탑 아래에서 기도하는 중"
		r.steps.append(walk(q.x, q.y))
		var f := q + (tp - q).normalized() * 0.03
		r.steps.append(walk(f.x, f.y))
		r.steps.append(act(Balance.PRAY_TIME, "pray", op("pray")))
		return true
	var ch := VillageEra.pray_spot(v, a)           # (A6) 교회가 있으면 교회 앞에서
	if not ch.is_empty():
		var cp: Vector2 = ch["p"]
		r.doing = "예배당 앞에서 기도하는 중"
		r.steps.append(walk(cp.x, cp.y))
		var cf: Vector2 = ch["face"]
		var ff := cp + (cf - cp).normalized() * 0.03
		r.steps.append(walk(ff.x, ff.y))
		r.steps.append(act(Balance.PRAY_TIME, "pray", op("pray_chapel")))
		if v.rng.randf() < 0.35:
			v.speak(r, Balance.LINES_PRAY[v.rng.randi() % Balance.LINES_PRAY.size()], 6)
		return true
	var p := v.altar_pos + Vector2(cos(a), sin(a)) * Awakening.RING_R
	r.steps.append(walk(p.x, p.y))
	r.steps.append(Awakening.face_altar_step(v, p))
	r.steps.append(act(Balance.PRAY_TIME, "pray", op("pray")))
	if v.rng.randf() < 0.35:
		v.speak(r, Balance.LINES_PRAY[v.rng.randi() % Balance.LINES_PRAY.size()], 6)
	return true


# ───────────────────────── 일 ─────────────────────────
static func _full(v: Village, k: String) -> bool:
	var have := float(v.stock.get(k, 0.0))
	if Balance.BULK.has(k):             # (걸음 다시 2026-11-07) 수레 물건은 건물 앞에 쌓여 나르기를 기다리는 몫도 센다 — 밭 앞 밀이 넉넉함을 넘어 쌓이지 않게
		for b in v.buildings:
			have += float(b.out.get(k, 0.0))
	return have >= v.enough(k)     # 추운 철엔 통나무를 더 (땔감 — HEALTH.md 1.3) · 밀도 넉넉하면 (BALANCE v4-4)


## 직장 일 — dry=true면 일감이 있는지만 본다
static func work_task(v: Village, r: Resident, dry: bool) -> bool:
	var b := v.bld(r.job)
	if b == null or not b.built:
		r.job = -1
		return false
	var d := b.def()
	if b.type == "나무꾼" and _full(v, "통나무"):
		return false
	if b.type == "채석장" and _full(v, "돌"):
		return false
	if b.type == "산림관" and v._standing_trees() >= Balance.FORESTER_STOP:
		return false
	if b.type == "버섯꾼" and _full(v, "버섯") and _full(v, "말린 버섯"):      # [하늘의 것]
		return false
	if b.type == "약초꾼" and _full(v, Balance.HERB):        # (A6) 약초가 넉넉하면 쉼 (곰팡이약은 Mold.decide가 먼저)
		return false
	if b.type == Balance.CLINIC_TYPE:                     # (A6) 약초사: 앓는 사람이 있을 때만
		return VillageEra.healer_task(v, r, b, dry)
	if b.type == "농장" and v.flora != null and int(v.flora.weeds.get(b.id, 0)) > 0:   # [하늘의 것] 잡초는 넉넉해도 뽑는다
		return dry or v.flora.weed_task(v, r, b)
	if b.type == "농장" and Wildlife.fence_needed(v, r, b):     # [들짐승] 토끼가 밭을 갉으면 울타리 (WILDLIFE 3)
		return dry or Wildlife.fence_task(v, r, b)
	if b.type == "어부" and not Wildlife.has_work(v, r, b):     # [들짐승] 물고기가 없거나 넉넉하면 쉼
		return false
	if b.type == "사냥꾼" and not Caterpillars.has_work(v, r, b):     # 애벌레 잡이 (사냥꾼 키 — 사슴 없음, production-chain R1-5)
		return false
	if d.has("out"):
		var all_full := true
		for k in d["out"]:
			if not _full(v, k):
				all_full = false
		if all_full:
			return false
	if dry:
		return true
	var s := v.store()
	# 건물 앞에 4개 넘게 쌓인 산출물은 일꾼이 직접 창고로 (9장)
	if b.out_total() >= minf(4.0, _bulk_of(b)):
		for k: String in b.out:
			if float(b.out[k]) >= 1.0:
				if _haul_direct(v, r, b, k, float(b.out[k])):     # 바로 보냄 (production-chain R3)
					return true
				var take := minf(maxf(4.0, float(Balance.BULK.get(k, 4.0))), floorf(b.out[k]))     # v5: 낟알·가루·빵은 수레 하나
				b.out[k] = float(b.out[k]) - take
				r.doing = "%s 나르는 중" % k
				var put := op("stock_add", {"k": k, "amt": take})
				_carry_steps(v, r, Vector2(b.x + 0.7, b.y + 0.5), Vector2(s.x + 0.8, s.y + 0.6), k, take, put, put)
				return true
	r.doing = "%s에서 일하는 중" % b.label()
	if b.type == "나무꾼":
		var tr := _nearest(v.trees, Vector2(b.x, b.y), func(q: Dictionary) -> bool: return q["s"] == "tree" and q["res"] == 0)
		if tr.is_empty() or Vector2(tr["x"] - b.x, tr["y"] - b.y).length() > Balance.GATHER_RANGE:
			r.doing = "벨 나무가 없어요"
			r.steps.append(act(120.0, "idle"))
			return true
		tr["res"] = 1
		var chop := op("chop", {"tr": tr})
		var unres := op("unres", {"q": tr})
		r.steps.append(walk(tr["x"] + 0.4, tr["y"] + 0.2))
		r.steps.append(act(d["chop"], "work", chop, true, unres))
		_drop_at_store(v, r, s, "통나무", 0.0)
		return true
	if b.type == "버섯꾼":                # [하늘의 것] 큰 버섯을 베어 나름 (WORLD_EVENTS 2.6)
		return v.flora.pick_task(v, r, b)
	if b.type == "약초꾼":                # (A6) 습한 땅·숲 가에서 약초
		return VillageEra.herb_task(v, r, b)
	if b.type == "사냥꾼":                # 애벌레 잡이: 조를 꾸려 잡거나 고치를 따고 주움 (production-chain R7-5)
		if Caterpillars.work_task(v, r, b):
			return true
		r.steps.append(act(120.0, "idle"))
		return true
	if b.type == "어부":                  # [들짐승] 물가에서 낚시 (WILDLIFE 2)
		if Wildlife.work_task(v, r, b):
			return true
		r.steps.append(act(120.0, "idle"))
		return true
	if b.type == "산림관":
		var sp := near(v, b.x, b.y, 2.0 + v.rng.randf() * 5.0)
		if not v.water.inside(sp.x, sp.y, 2.0) or v.water_at(sp.x, sp.y) or not VillagePlan.plantable(v, sp):     # [배치] 길·광장·집 앞은 비움
			r.steps.append(act(45.0, "idle"))
			return true
		r.steps.append(walk(sp.x, sp.y))
		var plant := op("plant", {"x": sp.x, "y": sp.y})
		r.steps.append(act(float(d["plant"]) / Discovery.plant_mult(v), "work", plant, true))     # 발견 F3 씨앗을 심다 — 두 배 빨리 심음
		return true
	if b.type == "채석장":
		var rk := _nearest(v.rocks, Vector2(b.x, b.y), func(q: Dictionary) -> bool: return q["amt"] > 0 and q["res"] == 0 and SkyDrops.rock_minable(v, q))
		if rk.is_empty() or Vector2(rk["x"] - b.x, rk["y"] - b.y).length() > Balance.GATHER_RANGE:
			r.doing = "캘 바위가 없어요"
			r.steps.append(act(120.0, "idle"))
			return true
		rk["res"] = 1
		var dig := op("dig", {"rk": rk})
		var unres := op("unres", {"q": rk})
		r.steps.append(walk(rk["x"] + 0.6, rk["y"] + 0.4))
		r.steps.append(act(d["dig"], "work", dig, true, unres))
		_drop_at_store(v, r, s, String(rk.get("ore", "돌")), 0.0)      # 하얀 광맥 바위는 소금
		return true
	# 생산·가공 건물: 실제 생산은 건물에서 돌아가고(Village._update_building), 일꾼은 곁에서 일한다
	var spot := near(v, b.x, b.y, 0.9)
	if b.type == "농장" and v.t < b.ready_at:
		r.doing = "밭을 돌보는 중 (아직 자라는 중)"
	r.steps.append(walk(spot.x, spot.y))
	r.steps.append(act(90.0, "work"))
	return true


## 건물 앞 산출물을 한 번에 나르는 양 중 가장 작은 것 (낟알·가루·빵은 수레 — Balance.BULK)
static func _bulk_of(b: Building) -> float:
	var m := INF
	for k: String in b.out:
		m = minf(m, float(Balance.BULK.get(k, 4.0)))
	return 4.0 if m == INF else m


## 건물 앞에 이만큼 쌓여야 나르러 간다 (수레 물건은 4분의 1 수레)
static func haul_min(k: String) -> float:
	return maxf(1.0, float(Balance.BULK.get(k, 1.0)) * 0.25)


## 가공 건물 입구의 가득 (수레 물건은 한 수레, 나머지 3) — 채우는 문턱은 Production.refill_low (REFILL_AT)
static func _inbuf_low(k: String) -> float:
	return Production.in_cap(k)


## 한 번에 나르는 양 (v5 — 수레로 나르는 물건은 BULK, 나머지는 사람의 짐)
static func load_of(r: Resident, k: String) -> float:
	return float(Balance.BULK.get(k, r.carry_cap()))


static func _nearest(list: Array, c: Vector2, ok: Callable) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for q: Dictionary in list:
		if not ok.call(q):
			continue
		var d := Vector2(q["x"], q["y"]).distance_squared_to(c)
		if d < bd:
			bd = d
			best = q
	return best


## 짐 나르기 걸음: from에서 집어 to에 내려놓음. drop = 내려놓을 때, undo = 도중에 그만두면 (짐을 되돌림)
static func _carry_steps(v: Village, r: Resident, from: Vector2, to: Vector2, item: String, amt: float, drop: Dictionary, undo: Dictionary) -> void:
	var pick := op("pick", {"item": item, "amt": amt})
	var put := op("put", {"drop": drop})
	r.steps.append(walk(from.x, from.y))
	r.steps.append(act(3.0, "idle", pick))
	r.steps.append(walk(to.x, to.y))
	r.steps.append(act(3.0, "idle", put, false, undo))


## 채집한 것(손에 든 것)을 창고에 내려놓는 걸음
static func _drop_at_store(v: Village, r: Resident, s: Building, item: String, amt: float) -> void:
	var put := op("store_put", {"k": item, "amt": amt})
	var undo := op("stock_add", {"k": item, "amt": amt}) if amt > 0.0 else op("carry_back", {"k": item})
	r.steps.append(walk(s.x + 0.8, s.y + 0.6))
	r.steps.append(act(4.0, "idle", put, false, undo))


# ───────────────────────── 운반 (5.3) ─────────────────────────
static func haul_requests(v: Village) -> int:
	var n := 0
	var cold := v.cold_season and float(v.stock.get("통나무", 0.0)) >= 1.0
	var plank_ok := float(v.stock["판자"]) >= 1.0
	var stone_ok := float(v.stock["돌"]) >= 1.0
	for b in v.buildings:
		if b.built:
			if not b.is_store:
				for k in b.out:
					if float(b.out[k]) >= haul_min(k):     # v5: 수레 물건은 4분의 1 수레가 쌓여야
						n += 1
			var d := b.def()
			if d.has("in") and b.upgrade_to == "":
				for k in d["in"]:
					if Production.in_have(b, k) < Production.refill_low(v, k) and float(v.stock.get(k, 0.0)) >= 1.0:
						n += 1
		if b.is_site():
			if plank_ok and b.need("판자") - int(b.delivered["판자"]) - int(b.incoming["판자"]) > 0:
				n += 1
			if stone_ok and b.need("돌") - int(b.delivered["돌"]) - int(b.incoming["돌"]) > 0:
				n += 1
		if cold and Health.fuel_lack(v, b) >= 1.0:
			n += 1
	return n


static func haul_task(v: Village, r: Resident) -> bool:
	var s := v.store()
	var cap := r.carry_cap()
	# v5: 걸음이 느려 밭의 밀 나르기가 끝이 없다 — 짐꾼 절반은 짓는 터 자재부터, 절반은 산출물부터 (터가 자재를 영영 못 받는 일이 없게)
	if r.id % 2 == 0:
		if _haul_sites(v, r, s, cap) or _haul_inputs(v, r, s, cap) or _haul_out(v, r, s, cap):
			return true
	elif _haul_out(v, r, s, cap) or _haul_inputs(v, r, s, cap) or _haul_sites(v, r, s, cap):
		return true
	return _haul_fuel(v, r, s, cap)


static func _haul_out(v: Village, r: Resident, s: Building, cap: int) -> bool:
	# ① 건물 앞 산출물 → 바로 다음 건물 (입구가 REFILL_AT 아래인 가장 가까운 곳 — production-chain R3) · 없으면 창고
	for b in v.buildings:
		if not b.built or b.is_store:
			continue
		for k: String in b.out:
			var n := float(b.out[k])
			if n >= haul_min(k):
				if _haul_direct(v, r, b, k, n):
					return true
				var take := minf(load_of(r, k), floorf(n))
				b.out[k] = n - take
				r.doing = "%s 나르는 중" % k
				var put := op("stock_add", {"k": k, "amt": take})
				_carry_steps(v, r, Vector2(b.x + 0.7, b.y + 0.5), Vector2(s.x + 0.8, s.y + 0.6), k, take, put, put)
				return true
	return false


## 건물 b 앞의 k를 바로 다음 건물 입구로 (production-chain R3) — 보낼 곳이 없으면 false (창고로)
## 받는 건물의 가득까지만 싣는다 (R3-3 '한 수레 가득'). 섞인 거인 몫은 받는 건물의 gift_in으로 (R3-6)
static func _haul_direct(v: Village, r: Resident, b: Building, k: String, n: float) -> bool:
	var to := Production.dest_for(v, b, k)
	if to == null:
		return false
	var amt := minf(minf(load_of(r, k), floorf(n)), ceilf(Production.in_cap(k) - Production.in_have(to, k)))
	if amt < 1.0:
		return false
	b.out[k] = n - amt
	var g := Production.gift_use(v, k, amt)
	to.in_inc[k] = float(to.in_inc.get(k, 0.0)) + amt
	r.doing = "%s에서 %s로 %s 나르는 중" % [b.label(), to.label(), k]
	var put := op("inbuf_put", {"b": to, "k": k, "amt": amt, "gift": g})
	var undo := op("inbuf_undo", {"b": to, "k": k, "amt": amt, "gift": g})
	_carry_steps(v, r, Vector2(b.x + 0.7, b.y + 0.5), Vector2(to.x + 0.6, to.y + 0.6), k, amt, put, undo)
	return true


static func _haul_sites(v: Village, r: Resident, s: Building, cap: int) -> bool:
	# ② 건설 현장 ← 창고 자재 (들어준 소원의 터 먼저)
	var sites: Array[Building] = []
	for b in v.buildings:
		if b.is_site():
			sites.append(b)
	sites.sort_custom(func(a: Building, c: Building) -> bool: return (a.wished and not c.wished) or (a.wished == c.wished and a.id < c.id))
	for b in sites:
		for k: String in ["판자", "돌"]:
			var lack := b.need(k) - int(b.delivered[k]) - int(b.incoming[k])
			if lack > 0 and float(v.stock[k]) >= 1.0:
				var take := mini(mini(cap, lack), int(floorf(v.stock[k])))
				v.stock[k] = float(v.stock[k]) - take
				Production.gift_use(v, k, take)
				b.incoming[k] = int(b.incoming[k]) + take
				r.doing = "%s 터로 %s 나르는 중" % [Balance.label(b.site_type()), k]
				var put := op("site_put", {"b": b, "k": k, "amt": take})
				var undo := op("site_undo", {"b": b, "k": k, "amt": take})
				_carry_steps(v, r, Vector2(s.x + 0.8, s.y + 0.6), Vector2(b.x + 0.6, b.y + 0.6), k, take, put, undo)
				return true
	return false


static func _haul_inputs(v: Village, r: Resident, s: Building, cap: int) -> bool:
	# ③ 가공 건물 ← 창고 재료
	for b in v.buildings:
		if not b.built or not b.def().has("in") or b.upgrade_to != "":
			continue
		for k: String in b.def()["in"]:
			var have := Production.in_have(b, k)
			var low := _inbuf_low(k)              # 가득 — 채우러 가는 문턱은 refill_low, 갈 때는 한 수레를 가득 (R3-3)
			var keep := 0.0                   # v5: 판자가 넉넉하면 제재소가 통나무를 다 켜지 않게 (땔감·횃불 몫) — 판자가 모자라면 다 켠다
			if k == "통나무" and float(v.stock.get("판자", 0.0)) >= v._owed("판자") + Balance.PLANK_RESERVE + 8:
				keep = v.enough(k) * 0.4
			if have < Production.refill_low(v, k) and float(v.stock.get(k, 0.0)) - keep >= 1.0:
				var take := minf(minf(load_of(r, k), low - have), floorf(v.stock[k]))
				v.stock[k] = float(v.stock[k]) - take
				var g := Production.gift_use(v, k, take)      # v5: 거인이 준 재료 몫은 가공품으로 옮겨 감
				b.in_inc[k] = float(b.in_inc.get(k, 0.0)) + take
				r.doing = "%s에 %s 나르는 중" % [b.label(), k]
				var put := op("inbuf_put", {"b": b, "k": k, "amt": take, "gift": g})
				var undo := op("inbuf_undo", {"b": b, "k": k, "amt": take, "gift": g})
				_carry_steps(v, r, Vector2(s.x + 0.8, s.y + 0.6), Vector2(b.x + 0.6, b.y + 0.6), k, take, put, undo)
				return true
	return false


static func _haul_fuel(v: Village, r: Resident, s: Building, cap: int) -> bool:
	# ④ 집 ← 창고 통나무 (땔감 — HEALTH.md 1.3, 추운 철에만). 가장 모자란 집부터
	if v.cold_season and float(v.stock.get("통나무", 0.0)) >= 1.0:
		var best: Building = null
		var bl := 0.0
		for b in v.buildings:
			var lack := Health.fuel_lack(v, b)
			if lack >= 1.0 and lack > bl:
				bl = lack
				best = b
		if best != null:
			var b := best
			var k := "통나무"
			var take := minf(minf(cap, floorf(bl)), floorf(v.stock[k]))
			v.stock[k] = float(v.stock[k]) - take
			Production.gift_use(v, k, take)
			b.in_inc[k] = float(b.in_inc.get(k, 0.0)) + take
			r.doing = "땔감 나르는 중"
			var put := op("inbuf_put", {"b": b, "k": k, "amt": take})
			var undo := op("inbuf_undo", {"b": b, "k": k, "amt": take})
			_carry_steps(v, r, Vector2(s.x + 0.8, s.y + 0.6), Vector2(b.x + 0.6, b.y + 0.6), k, take, put, undo)
			return true
	return false


static func haul_manna_task(v: Village, r: Resident) -> bool:
	var s := v.store()
	var m := _nearest(v.manna, Vector2(r.x, r.y), func(q: Dictionary) -> bool: return q["amt"] > 0.0 and q["res"] < 3)
	if m.is_empty():
		return false
	m["res"] = int(m["res"]) + 1
	r.doing = "하늘 낟알을 줍는 중"
	var cap := 8.0 if r.is_child() else 20.0
	var born: float = m["born"]
	var pick := op("manna_pick", {"m": m, "cap": cap})
	var unres := op("manna_unres", {"m": m})
	var put := op("manna_put", {"born": born})
	var undo := op("manna_undo", {"born": born})
	r.steps.append(walk(m["x"], m["y"]))
	r.steps.append(act(40.0, "work", pick, false, unres))
	r.steps.append(walk(s.x + 0.6, s.y + 0.7))
	r.steps.append(act(4.0, "idle", put, false, undo))
	if v.rng.randf() < 0.15:
		v.speak(r, "{w}의 낟알이다!" if v.aware else "하늘이 또 주었네", 5)     # 거인을 모르면 '하늘이 주는 것' (A4b)
	return true


# ───────────────────────── 짓기 (5.4) ─────────────────────────
static func _ready_site(v: Village) -> Building:
	var best: Building = null
	for b in v.buildings:
		if b.is_site() and b.materials_ready():
			if best == null or (b.wished and not best.wished) or (b.wished == best.wished and b.id < best.id):
				best = b
	return best


static func build_task(v: Village, r: Resident) -> bool:
	var b := _ready_site(v)
	if b == null:
		return false
	var total: float = Balance.B[b.site_type()]["time"]
	var ch0 := 30.0 if (v.in_opening() or v.staged()) else Balance.BUILD_CHUNK     # 첫 한 시간·제단 장면은 예전처럼 잘게 (짓는 모습이 자주 바뀜)
	var chunk := minf(ch0, (total - b.prog) / (v.build_mult(b) * v.opening_build(b)))    # 남은 만큼만 (일하는 초 — v5 한 번에 병 30분)
	if chunk <= 1.0:
		chunk = 1.0
	r.doing = "%s 짓는 중" % Balance.label(b.site_type())
	var sp := near(v, b.x, b.y, 0.8 + b.size() * 0.5)
	if b.site_type() == Awakening.ALTAR:
		return _altar_task(v, r, b, chunk, sp)
	var work := op("build", {"b": b, "chunk": chunk})
	r.steps.append(walk(sp.x, sp.y))
	r.steps.append(act(chunk, "work", work, true))
	return true


## (E1-2 · EVENTS_STAGING 2b) 제단: 둘레에서 둥근 돌을 하나 주워 안고 와서 쌓는다 — 돌을 안은 모습이 보이게 (r.carry "돌").
## 주우러 가는 길도 짓는 일로 친다 (제단이 서는 때는 그대로 — 첫 병 ~7:30). 난수를 쓰지 않는다 (다른 흐름을 흔들지 않게)
const ALTAR_PICK_R := [2.8, 4.2]     # 돌을 줍는 곳 (제단에서 칸)
const ALTAR_PICK := 4.0              # 줍는 동작 (병 초)


static func _altar_task(v: Village, r: Resident, b: Building, chunk: float, sp: Vector2) -> bool:
	var c := Vector2(b.x, b.y)
	var pick := c
	for k in 6:                                  # 사람마다 다른 쪽 (물이면 다음 쪽)
		var a := float((r.id * 7 + int(b.prog / 30.0) * 3 + k * 5) % 12) * TAU / 12.0
		var rr: float = lerpf(ALTAR_PICK_R[0], ALTAR_PICK_R[1], fposmod(r.id * 0.37 + k * 0.21, 1.0))
		var q := c + Vector2(cos(a), sin(a)) * rr
		if not v.water_at(q.x, q.y):
			pick = q
			break
	var walk_s := (Vector2(r.x, r.y).distance_to(pick) + pick.distance_to(sp)) / maxf(0.05, Balance.WALK * v.pace_walk())
	var credit := chunk + 0.3 * minf(walk_s + ALTAR_PICK, chunk)     # 오가는 길의 몫 (제단이 서는 때 — 첫 병 ~7:30에 맞춤)
	r.doing = "제단에 쌓을 돌을 줍는 중" if v.aware else "둥근 돌을 줍는 중"
	r.steps.append(walk(pick.x, pick.y))
	r.steps.append(act(ALTAR_PICK, "work", op("carry_set", {"item": "돌"}), true, op("carry_set", {"item": ""})))
	r.steps.append(walk(sp.x, sp.y))
	r.steps.append(act(chunk, "work", op("build", {"b": b, "chunk": credit, "drop": true}), true, op("carry_set", {"item": ""})))
	return true
