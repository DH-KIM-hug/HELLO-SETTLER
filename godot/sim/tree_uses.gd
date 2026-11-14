## 큰 나무 넷의 쓰임 — 탐험하면 좋은 까닭 (ROADMAP Q40 · 2026-11-14 사용자 결정 · design/gdd/flower-forest.md R5 · 186행).
## 탐험가가 '본' 큰 나무(Village.explore_seen — Q39)까지 한가한 어른 두셋이 나들이를 다녀오고, 마을이 그 나무에서 얻은 것을 쓴다.
##   벚나무 cherry: 꽃 철에 나무 아래 앉아 쉬다 옴 → 돌아오면 며칠 마을이 조금 행복 (겹치지 않음 · 철마다 횟수 상한). 벚꽃 철 이름 부르기(Q31)와는 따로.
##   소나무 pine: 따뜻한 철에 송진을 긁어 옴 → 횃불(곰팡이 털뭉치 쫓기 · 날벌레 모깃불)에 섞어 씀: 한 번 휘두를 때 더 세게 · 모깃불은 더 오래 · 통나무를 덜 씀.
##   은행나무 ginkgo: 가을에 떨어진 열매를 주워 옴 → 창고의 '은행알' (먹을 것 — FOODS 맨 끝: 다른 것이 떨어질 때 먹음 = 겨울 먹을 것).
##   단풍나무 maple: 이른 봄 줄기에서 단물을 받아 옴 → 졸여 '단풍 엿' → 잔치(축제 · 고비 잔치)가 열리면 하나 꺼내 그 잔치 동안 조금 더 행복.
## 규칙: 도착하고 TUSE_FROM_DAY날 뒤 (첫 고비 · 첫 20일은 그대로) · 본 나무만 · 철에만 · 하루 한 번 아침에 주사위 (먼 나무일수록 드물게) ·
##   한 무리에 한 나들이만 · 위기 · 잔치 · 혼례 · 추운 밤 · 추위가 오는 철 · 첫 며칠 먹을 것 막기 · 먹을 것이 모자랄 때는 떠나지 않음 ·
##   성하고(Village.explore_fit) 한가한 어른 2~4명 (일터 일을 하는 중인 사람 · 탐험가 · 짐 든 사람은 빼고) · 나무 곁에서 쉬는 장면 (밤이면 그 아래에서 자고 아침에).
## 난수: 마을 rng를 쓰지 않는다 — 날짜 · 나무로 정한 해시 (다른 흐름의 난수 순서를 바꾸지 않게). 상태는 Village.tree_use (저장 — 이름 그대로).
## 주민 쪽 글에는 숫자 · 거인 이야기 없음.
class_name TreeUses
extends RefCounted

const KINDS := ["cherry", "pine", "ginkgo", "maple"]
const RESIN := "송진"
const NUTS := "은행알"
const SWEETS := "단풍 엿"
const ACTION := "tree_trip"            # 나들이 중인 사람의 action (다른 일이 데려가지 않게 — 열매 줍기 · 잔치 목록에 없음)
const ITEM := {"cherry": "", "pine": RESIN, "ginkgo": NUTS, "maple": SWEETS}
const CARRY := {"cherry": "", "pine": "송진", "ginkgo": "은행알", "maple": "단풍 단물"}     # 지고 오는 짐 이름 (화면 소품)
## 주민 쪽 글 (숫자 없음 · 거인 없음)
const SAY_GO := {"cherry": "큰 벚나무에 꽃이 피었대. 다 같이 보러 가자!", "pine": "큰 소나무에 송진 긁으러 가자.",
	"ginkgo": "은행 주우러 가자… 냄새는 각오하고.", "maple": "단풍나무 단물 받으러 가자!"}
const SAY_REST := {"cherry": "꽃잎이 눈처럼 내려…", "pine": "솔 냄새 좋다. 좀 쉬었다 하자.", "ginkgo": "아이고, 이 냄새!", "maple": "똑, 똑… 달큰한 냄새가 나."}
const DOING_GO := {"cherry": "큰 벚나무로 꽃 보러 가는 중", "pine": "큰 소나무로 송진을 긁으러 가는 중", "ginkgo": "큰 은행나무로 열매를 주우러 가는 중", "maple": "큰 단풍나무로 단물을 받으러 가는 중"}
const DOING_REST := {"cherry": "큰 벚나무 아래 앉아 꽃을 보는 중", "pine": "큰 소나무 아래에서 쉬는 중", "ginkgo": "큰 은행나무 아래에서 쉬는 중", "maple": "큰 단풍나무 아래에서 쉬는 중"}
const DOING_WORK := {"cherry": "떨어진 꽃잎을 모으는 중", "pine": "줄기에서 송진을 긁는 중", "ginkgo": "떨어진 은행을 줍는 중", "maple": "줄기에 홈을 내어 단물을 받는 중"}
const DOING_BACK := {"cherry": "꽃 이야기를 하며 돌아오는 중", "pine": "송진을 지고 돌아오는 중", "ginkgo": "은행을 지고 돌아오는 중", "maple": "단물을 지고 돌아오는 중"}
const DOING_SLEEP := "큰 나무 아래에서 자는 중"
## 처음 한 번 (연대기 — 절제 · 숫자 없음). %s = "이름이"
const FIRST_LINE := {
	"cherry": "%s 이웃 몇과 먼 길을 걸어 큰 벚나무 아래에 앉았다. 꽃잎이 눈처럼 내리는 동안 아무도 서두르지 않았다. 돌아온 뒤로도 한동안 마을은 그 이야기로 환했다.",
	"pine": "%s 큰 소나무 줄기에 맺힌 송진을 긁어 왔다. 송진을 바른 횃불은 오래, 세게 탔다.",
	"ginkgo": "%s 큰 은행나무 아래에서 떨어진 열매를 주워 왔다. 냄새가 고약해 다들 코를 막았지만, 껍질을 벗긴 알은 겨울까지 두고 먹을 수 있었다.",
	"maple": "%s 이른 봄 큰 단풍나무 줄기에서 단물을 받아 왔다. 오래 졸이니 달큰한 엿이 되었다. 잔치 날에 꺼내기로 했다."}
const SWEET_LINE := "잔치 자리에 단풍 엿이 돌았다. 아이들 입가가 끈적했다."


static func _st(v: Village) -> Dictionary:
	return v.tree_use


## 철인가 (달 · 날) — Balance.TUSE_SEASON[kind] = [시작 (월, 일), 끝 (월, 일)]
static func in_season(kind: String, month: int, day: int) -> bool:
	var se: Array = Balance.TUSE_SEASON[kind]
	var md := month * 100 + day
	var a: Vector2i = se[0]
	var b: Vector2i = se[1]
	return md >= a.x * 100 + a.y and md <= b.x * 100 + b.y


## 철의 이름표 (해마다 한 번씩 세는 횟수 상한) — "<kind>:<해>"
static func season_key(kind: String, d: Dictionary) -> String:
	return "%s:%d" % [kind, int(d["year"])]


## 이 무리가 쓸 수 있는 나무 (본 나무 · 넓은 세상) {kind: {x, y, r, d}}
static func seen_trees(v: Village) -> Dictionary:
	var out := {}
	if not v.water is WorldWater or v.explore_seen.is_empty():
		return out
	for gt: Dictionary in (v.water as WorldWater).great_trees:
		var k := String(gt["kind"])
		if k in KINDS and v.explore_seen.has(k):
			var c := Vector2(float(gt["x"]), float(gt["y"]))
			out[k] = {"c": c, "r": float(gt["r"]), "d": c.distance_to(v.center)}
	return out


## 오늘 그 나무로 갈 몫 — 가까우면 TUSE_DAY_P, 멀수록 줄어듦 (TUSE_NEAR / 거리, TUSE_FAR_MIN까지)
static func day_p(kind: String, d: float) -> float:
	return float(Balance.TUSE_DAY_P[kind]) * clampf(Balance.TUSE_NEAR / maxf(1.0, d), Balance.TUSE_FAR_MIN, 1.0)


## 지금 떠날 수 없는 까닭 ("" = 떠날 수 있음 — 나무 · 철은 따로). 읽기만 (측정 · 시험).
## kind를 주면 그 나무의 추위 금(TUSE_COLD_MAX_KIND — 단풍 단물은 밤이 얼고 낮에 녹는 철에 오르므로 조금 추운 밤까지), "*"이면 추위는 보지 않음
static func blocked(v: Village, kind := "") -> String:
	if not v.explore_on or not v.water is WorldWater:
		return "small"
	if v.t < Balance.TUSE_FROM_DAY * Balance.DAY:
		return "early"
	var st := _st(v)
	if not (st.get("out", {}) as Dictionary).is_empty():
		return "out"
	if v.t - float(st.get("last", -1.0e9)) < Balance.TUSE_GAP:
		return "gap"
	if v.in_crisis():
		return "crisis"
	if Milestones.feast_on(v) or VillageEra.wedding_on(v) or v.t - v.festival_t < Balance.FESTIVAL_DAYS * Balance.DAY:
		return "feast"
	for f: Dictionary in v.milestones.get("feasts", []):
		if int(f.get("day", 0)) <= v.cal_day(v.t) + 1:
			return "feast"                 # 오늘 · 내일 잔치가 기다린다
	if v.explore_held():
		return "cold"
	if v.food_total() < Balance.TUSE_FOOD_DAYS * Production.day_need(v):
		return "food"
	if kind != "*" and too_cold(v, kind):
		return "cold"
	return ""


## 오늘 밤(새벽 두 시)이 그 나무로 가기에 추운가 · 추위가 오는 철인가 (단풍은 추위가 오는 철 금을 보지 않음 — 이른 봄 단물 철)
static func too_cold(v: Village, kind := "") -> bool:
	var lim := float(Balance.TUSE_COLD_MAX_KIND.get(kind, Balance.TUSE_COLD_MAX))
	if v.cold_season and not Balance.TUSE_COLD_MAX_KIND.has(kind):
		return true
	var hn := v.hour_now()
	return Health.cold_of(Health.base_temp(v, v.t + (26.0 - hn) * Balance.HOUR)) > lim


## 한 시간에 한 번 (Village.step — 과일나무 열매 줍기 다음): 나들이 떠남 · 단풍 엿 잔치 · 오래된 나들이 정리
static func hourly(v: Village) -> void:
	if not v.explore_on or v.t < Balance.TUSE_FROM_DAY * Balance.DAY or not v.water is WorldWater:
		return
	var st := _st(v)
	_sweets(v, st)
	_tidy(v, st)
	var h := v.hour_now()
	if h < Balance.TUSE_HOURS.x or h >= Balance.TUSE_HOURS.y:
		return
	var today := v.cal_day(v.t)
	if int(st.get("day", -1)) == today:
		return                              # 하루 한 번만 주사위
	var why := blocked(v, "*")
	if why == "out" or why == "gap":
		return                              # 나가 있거나 막 다녀왔다 — 오늘 주사위는 남겨 둠 (아무 날도 버리지 않음)
	st["day"] = today
	if why != "":
		_count(v, "tuse_block_" + why)
		return
	var trees := seen_trees(v)
	if trees.is_empty():
		return
	var d := Health.jar_date(v)
	var order: Array = []
	var cold := false
	for k: String in KINDS:
		if not trees.has(k) or not in_season(k, int(d["month"]), int(d["day"])) or not want(v, k):
			continue
		if too_cold(v, k):
			cold = true
			continue
		var per: Dictionary = st.get("season_n", {})
		if int(per.get(season_key(k, d), 0)) >= int(Balance.TUSE_SEASON_MAX[k]):
			continue
		order.append(k)
	if order.is_empty():
		if cold:
			_count(v, "tuse_block_cold")
		return
	for k: String in order:
		var roll := _roll(v, today, k)
		if roll < day_p(k, float(trees[k]["d"])):
			go(v, k)
			return


## 이 나무에서 지금 얻을 것이 필요한가 (넉넉하면 가지 않음 — 쓸데없는 먼 길 없게)
static func want(v: Village, kind: String) -> bool:
	match kind:
		"pine":
			return float(v.stock.get(RESIN, 0.0)) < Balance.RESIN_WANT
		"maple":
			return float(v.stock.get(SWEETS, 0.0)) < Balance.SWEETS_WANT
		"ginkgo":
			return float(v.stock.get(NUTS, 0.0)) < Balance.NUTS_WANT_DAYS * Production.day_need(v)
	return true


## 날 · 나무로 정한 0~1 (마을 rng를 쓰지 않음)
static func _roll(v: Village, day: int, kind: String) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = int(v.rng.seed) * 7349 + day * 131 + KINDS.find(kind) * 17 + int(v.sid) * 3 + 11
	return r.randf()


## 함께 갈 어른: 성하고(Village.explore_fit) 한가한 사람 (쉼 · 어울림 · 집안일 · 아무 일 없음 · 일터 없는 사람의 맨손 채집 · 나르기) — 일터 일 · 짓기 · 탐험 · 짐 든 사람은 빼고
static func team(v: Village, p: Vector2) -> Array:
	var cs: Array = []
	for r in v.people:
		if r.dead or r.sleeping or not r.is_adult() or r.hunger >= Balance.HUNGRY_AT or r.carry != "":
			continue
		var idle: bool = r.action in Balance.TUSE_IDLE or (r.job < 0 and r.action in Balance.TUSE_IDLE_JOBLESS)
		if r.id == v.explorer or r.id in v.explore_party or not idle or not v.explore_fit(r):
			continue
		cs.append(r)
	if cs.size() < Balance.TUSE_TEAM_MIN:
		return []
	cs.sort_custom(func(a: Resident, b: Resident) -> bool:
		var ja := 0 if a.job < 0 else 1
		var jb := 0 if b.job < 0 else 1
		if ja != jb:
			return ja < jb                  # 일터 없는 사람부터
		return Vector2(a.x, a.y).distance_squared_to(p) < Vector2(b.x, b.y).distance_squared_to(p))
	var n := clampi(cs.size() / 2, Balance.TUSE_TEAM_MIN, Balance.TUSE_TEAM_MAX)     # 한가한 사람의 절반쯤 (남는 사람이 있게)
	return cs.slice(0, n)


## 나들이를 떠난다 → 간 사람 수 (0 = 못 감)
static func go(v: Village, kind: String) -> int:
	var trees := seen_trees(v)
	if not trees.has(kind):
		return 0
	var c: Vector2 = trees[kind]["c"]
	var rad: float = trees[kind]["r"]
	var tm := team(v, c)
	if tm.is_empty():
		_count(v, "tuse_block_team")
		return 0
	var st := _st(v)
	var s := v.store()
	var home := Vector2(s.x, s.y) if s != null else v.center
	var dir := (v.center - c).normalized() if v.center.distance_to(c) > 1.0 else Vector2(0, 1)
	var a0 := Vector2(0, 1).angle()        # 나무의 앞쪽(화면 쪽 +y)에 앉음 — 잎 그늘 가장자리 밖이라 보는 쪽에서 가리지 않게
	var ids: Array = []
	var ww := v.water as WorldWater
	for i in tm.size():
		var r: Resident = tm[i]
		ResidentAI.cancel(v, r)
		r.action = ACTION
		r.last_action = ACTION
		r.doing = String(DOING_GO[kind])
		var a := a0 + (float(i) - (tm.size() - 1) * 0.5) * Balance.TUSE_SPREAD
		var q := c + Vector2(cos(a), sin(a)) * (rad * Balance.TUSE_SIT_K + Balance.TUSE_SIT_R)
		for k in 8:                         # 물 위면 마을 쪽으로 조금씩
			if ww.inside(q.x, q.y, 2.0) and ww.depth(ww.idx(q.x, q.y)) < 0.01:
				break
			q += dir * 2.0
		r.steps.append(ResidentAI.walk(q.x, q.y))
		r.steps.append(ResidentAI.act(1.0, "idle", ResidentAI.op("tuse_arrive", {"kind": kind})))
		r.steps.append(ResidentAI.act(float(Balance.TUSE_REST[kind]), "sit"))
		r.steps.append(ResidentAI.act(Balance.TUSE_WORK, "work" if kind != "cherry" else "sit", ResidentAI.op("tuse_take", {"kind": kind})))
		var o := Vector2(cos(a), sin(a)) * 0.7
		r.steps.append(ResidentAI.walk(home.x + 0.8 + o.x, home.y + 0.6 + o.y))
		r.steps.append(ResidentAI.act(3.0, "idle", ResidentAI.op("tuse_put", {"kind": kind}), false, ResidentAI.op("tuse_quit", {"kind": kind})))
		ids.append(r.id)
	st["out"] = {"kind": kind, "ids": ids, "t": v.t, "said": false}
	st["last"] = v.t
	var d := Health.jar_date(v)
	var per: Dictionary = st.get("season_n", {})
	per[season_key(kind, d)] = int(per.get(season_key(kind, d), 0)) + 1
	st["season_n"] = per
	v.speak(tm[0], String(SAY_GO[kind]), 7)
	_count(v, "tuse_trips_" + kind)
	_count(v, "tuse_people_" + kind, tm.size())
	var lg: Array = st.get("log", [])
	lg.append([snappedf(v.t / Balance.DAY, 0.1), kind, tm.size(), int(trees[kind]["d"])])
	if lg.size() > Balance.TUSE_LOG_MAX:
		lg = lg.slice(lg.size() - Balance.TUSE_LOG_MAX)
	st["log"] = lg
	return tm.size()


static func _count(v: Village, key: String, n := 1) -> void:
	v.stats[key] = int(v.stats.get(key, 0)) + n


static func _addf(v: Village, key: String, x: float) -> void:
	v.stats[key] = float(v.stats.get(key, 0.0)) + x


## 나들이가 너무 오래면 (걸음이 끊겼거나 사람이 떠남) 정리 — 남은 사람만 셈
static func _tidy(v: Village, st: Dictionary) -> void:
	var o: Dictionary = st.get("out", {})
	if o.is_empty():
		return
	var ids: Array = o["ids"]
	for id: Variant in ids.duplicate():
		var r := v.person(int(id))
		if r == null or r.action != ACTION:
			ids.erase(id)
	if ids.is_empty() or v.t - float(o["t"]) > Balance.TUSE_STALE:
		st["out"] = {}


static func _done(v: Village, r: Resident) -> void:
	var st := _st(v)
	var o: Dictionary = st.get("out", {})
	if o.is_empty():
		return
	(o["ids"] as Array).erase(r.id)
	if (o["ids"] as Array).is_empty():
		st["out"] = {}


## 단풍 엿: 잔치(축제 · 고비 잔치 · 혼례)가 열려 있고 엿이 있으면 그 잔치에 하나 — 잔치마다 한 번
static func _sweets(v: Village, st: Dictionary) -> void:
	if float(v.stock.get(SWEETS, 0.0)) < Balance.SWEETS_FEAST_USE:
		return
	var key := ""
	if Milestones.feast_on(v):
		key = "m%d" % int(float((v.milestones.get("feast", {}) as Dictionary).get("t0", 0.0)))
	elif v.t - v.festival_t < Balance.FESTIVAL_DAYS * Balance.DAY:
		key = "f%d" % int(v.festival_t)
	elif VillageEra.wedding_on(v):
		key = "w%d" % int(v.wedding_t)
	if key == "" or String(st.get("sweet_key", "")) == key:
		return
	st["sweet_key"] = key
	st["sweet_until"] = v.t + Balance.SWEETS_HAPPY_DAYS * Balance.DAY
	v.stock[SWEETS] = float(v.stock[SWEETS]) - Balance.SWEETS_FEAST_USE
	_count(v, "tuse_sweet_feasts")
	if not bool(st.get("sweet_said", false)):
		st["sweet_said"] = true
		v.log_line(SWEET_LINE)


## 마을 행복에 보태는 몫 (Village._update_happiness가 사람마다 더함 — 마을 하나에 같음). 벚꽃 나들이 뒤 · 단풍 엿 잔치 동안. 겹쳐도 각각 한 번
static func happy(v: Village) -> float:
	var st := v.tree_use
	if st.is_empty():
		return 0.0
	var h := 0.0
	if v.t < float(st.get("cherry_until", -1.0)):
		h += Balance.CHERRY_HAPPY
	if v.t < float(st.get("sweet_until", -1.0)):
		h += Balance.SWEETS_HAPPY
	return h


## 횃불 · 모깃불에 송진을 섞는가 — 있으면 RESIN_PER_FIRE만큼 쓰고 true (Mold._strike · SmallCrises "crisis_smoke")
static func use_resin(v: Village) -> bool:
	if float(v.stock.get(RESIN, 0.0)) < Balance.RESIN_PER_FIRE - 1e-6:
		return false
	v.stock[RESIN] = float(v.stock[RESIN]) - Balance.RESIN_PER_FIRE
	_addf(v, "tuse_resin_used", Balance.RESIN_PER_FIRE)
	_count(v, "tuse_resin_fires")
	return true


static func run_op(v: Village, r: Resident, d: Dictionary) -> void:
	var kind := String(d.get("kind", ""))
	match String(d["op"]):
		"tuse_arrive":                     # 나무 곁에 닿음: 쉬는 장면 (밤이면 그 아래에서 자고 아침에)
			r.doing = String(DOING_REST.get(kind, DOING_SLEEP))
			var st := _st(v)
			var o: Dictionary = st.get("out", {})
			if not o.is_empty() and not bool(o.get("said", false)):
				o["said"] = true
				v.speak(r, String(SAY_REST.get(kind, "")), 7)
			if v.is_night():
				var h := v.hour_now()
				var left := fmod(Balance.NIGHT_TO - h + 24.0, 24.0) * Balance.HOUR + 60.0
				r.doing = DOING_SLEEP
				r.steps.push_front(ResidentAI.act(left, "sleep"))
			_count(v, "tuse_arrive_" + kind)
		"tuse_take":
			r.doing = String(DOING_BACK.get(kind, ""))
			match kind:
				"pine":
					r.carry = CARRY["pine"]
					r.carry_amt = Balance.RESIN_LOAD
				"ginkgo":
					r.carry = CARRY["ginkgo"]
					r.carry_amt = Balance.NUTS_LOAD
				"maple":
					r.carry = CARRY["maple"]
					r.carry_amt = Balance.SAP_LOAD
		"tuse_put":
			var item := String(ITEM.get(kind, ""))
			var gain := 0.0
			if item != "" and r.carry == String(CARRY.get(kind, "")) and r.carry_amt > 0.0:
				gain = r.carry_amt * (Balance.SAP_TO_SWEETS if kind == "maple" else 1.0)
				v.stock[item] = float(v.stock.get(item, 0.0)) + gain
				_addf(v, "tuse_gain_" + kind, gain)
			if kind == "cherry":
				var st := _st(v)
				st["cherry_until"] = maxf(float(st.get("cherry_until", -1.0)), v.t + Balance.CHERRY_HAPPY_DAYS * Balance.DAY)
				_count(v, "tuse_cherry_home")
			if r.carry == String(CARRY.get(kind, "_")):
				r.carry = ""
				r.carry_amt = 0.0
			_first(v, r, kind, gain > 0.0 or kind == "cherry")
			_done(v, r)
		"tuse_quit":
			_done(v, r)
		_:
			push_error("TreeUses.run_op: 모르는 할 일 %s" % d["op"])


static func _first(v: Village, r: Resident, kind: String, ok: bool) -> void:
	if not ok:
		return
	var st := _st(v)
	var fs: Dictionary = st.get("first", {})
	if fs.has(kind):
		return
	fs[kind] = v.t
	st["first"] = fs
	v.log_line(String(FIRST_LINE[kind]) % ("%s%s" % [r.name, Village.josa(r.name, "이", "가")]))
