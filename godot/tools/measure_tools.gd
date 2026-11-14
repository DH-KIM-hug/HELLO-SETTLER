## 연장 멈춤 재 보기 (ROADMAP Q25, 2026-11-12) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다.
## 시작은 tools/measure_growth.gd watch와 같다 (넓은 세상 + 기본 키트 · 4월 15일 · 깨닫기 전 · 창조 첫날의 톡 세 번과 떨어뜨리기 한 번 ·
## 제단 공물 걷기 · 계시 받기). 병 한 시간씩 지켜본다 (걸음 30초).
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_tools.gd -- run <거인> <씨앗 처음> <씨앗 끝> <일수> [걸음 초]
## 거인:
##   none   아무것도 주지 않는다 (공물만 걷음)
##   wish   '연장이 모자라요' 편지가 오면 그때만 연장 꾸러미를 사서 창고 곁에 떨어뜨린다 (지폐가 모자라면 모일 때까지 기다림)
##   stone  wish + 병 60일 뒤 창고의 돌이 4 아래면 자갈 한 알을 사서 창고 곁에 (사흘에 한 번까지 — Q26: 돌 천장을 걷으면)
##   stonewish  (Q30) wish + '돌이 모자라요' 편지가 오면 그때만 자갈 한 알 (300)
##   veinwish   (Q30) wish + '돌이 모자라요' 편지가 오면 회색 돌멩이 (1,200 · 한 병에 둘까지) — 못 사면 자갈 한 알
##   help   balance_v5_report의 help (건물 소원을 모두 들어줌 · 먹을 것이 1일치 아래면 병 하루 한 번 하늘 낟알) + wish
## 병 정오마다 본다: 식구 · 어른 · 일터 없는 어른(아기 돌봄 빼고) · 창고의 연장 · 일터(지어진 일 건물) · 빈 일터 · 먹을 것 날치 · 지폐.
## 씨앗마다 TOOLS 줄 하나(JSON) — 모으기는 밖에서. DIGEST 줄 = 경제가 같은지 보는 지문 (병 20일 · 끝).
extends SceneTree

const H := 3600.0
const D := 86400.0
const TOOL_ITEM := "연장 꾸러미"
const TOOL_WISH := "연장"
const GRAVEL_ITEM := "자갈 한 알"
const VEIN_ITEM := "회색 돌멩이"

var jw: JarWorld
var mode := "none"
var seed_v := 0
var step := 30.0
var daily := {}              # 날 → [식구, 어른, 일터 없는 어른, 연장, 일터, 빈 일터, 먹을 것 날치, 지폐, 병 전체 식구]
var bought: Array = []        # [병 날, 값]
var wish_at: Array = []       # '연장' 편지가 온 병 날
var stone_at: Array = []      # (Q30) '돌' 편지가 온 병 날 (모든 거인 모드에서 적음 — none은 사지 않음)
var last_help := -1.0e9
var helps := 0
var gravel: Array = []        # (Q26 stone) [병 날, 값] — 자갈 한 알
var last_gravel := -1.0e9
var digests := {}
var dump_mid := ""           # (Q36) 덤프 파일을 주면 병 150일에도 <덤프>.d150 에 (한 번)
var diag := {}               # (Q36) 날 → 일손이 남을 때 규칙이 무엇에 막혔나 · 자원 (읽기만)
var extra := {}              # (Q26) 날 → [판자, 돌, 짓는 터, 땅이 품는 인구, 영역 반지름, 일터 종류별 수]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	mode = args[1] if args.size() > 1 else "none"
	var s0 := int(args[2]) if args.size() > 2 else 1
	var s1 := int(args[3]) if args.size() > 3 else s0
	var days := int(args[4]) if args.size() > 4 else 200
	step = float(args[5]) if args.size() > 5 else 30.0
	var dump := args[6] if args.size() > 6 else ""       # (Q26) 끝난 세상을 이 파일에 (var_to_bytes) — tools/shot_spare_hands.gd가 읽음
	dump_mid = dump
	for s in range(s0, s1 + 1):
		_run(s, days)
		if dump != "":
			var f := FileAccess.open(dump, FileAccess.WRITE)
			f.store_buffer(var_to_bytes(jw.to_dict()))
			f.close()
			print("DUMP %s" % dump)
	quit()


func _run(s: int, days: int) -> void:
	var t0 := Time.get_ticks_msec()
	seed_v = s
	Market.reset()
	Market.first_paid = false
	Market.mig_seed = s * 7919 + 13
	Market.today_override = "R1"
	jw = JarWorld.create_with_kit(s, WorldCfg.SIZE, Kits.make([]))
	var v := jw.primary()
	daily = {}
	bought = []
	wish_at = []
	stone_at = []
	last_help = -1.0e9
	helps = 0
	gravel = []
	last_gravel = -1.0e9
	digests = {}
	extra = {}
	diag = {}
	ResidentAI.plant_tries = 0
	ResidentAI.plant_fails = 0
	var tapped := 0
	var dropped := false
	while v.t < 23.0 * H:                  # 창세의 날 (measure_growth와 같음)
		jw.advance(5.0 * 60.0)
		if tapped < 3 and v.t > (20.0 + 20.0 * tapped) * 60.0:
			Awakening.witness(v, "tap")
			tapped += 1
		if not dropped and v.t > 50.0 * 60.0:
			Awakening.witness(v, "drop")
			dropped = true
		if _hour(v) >= 19.6 and v.cal_day(v.t) == 1:
			_collect()
	_collect()
	var sdt0 := v.step_dt
	_set_step(step)
	while v.t < days * D - 1.0 and not v.people.is_empty():
		jw.advance(minf(H, days * D - v.t))
		for q: Village in jw.settlements:
			q.crises.clear()
			if q.revelation_pending():
				q.reveal()
		var hr := int(_hour(v))
		if hr == 8 or hr == 20:
			_collect()
		_giant(v)
		if hr == 12:
			_sample(v)
		var dn := int(v.t / D + 0.001)
		if dump_mid != "" and dn == 150 and absf(v.t - dn * D) < 1800.0:
			var mf := FileAccess.open(dump_mid + ".d150", FileAccess.WRITE)
			mf.store_buffer(var_to_bytes(jw.to_dict()))
			mf.close()
			print("DUMP %s.d150" % dump_mid)
		if (dn == 20 or dn == 60 or dn == 120) and not digests.has(dn) and absf(v.t - dn * D) < 1800.0:
			digests[dn] = _digest()
	_set_step(sdt0)
	digests[days] = _digest()
	var out := {"mode": mode, "seed": s, "days": days, "daily": daily, "bought": bought, "gravel": gravel, "wish_at": wish_at, "stone_at": stone_at, "helps": helps,
		"end_pop": v.people.size(), "settlements": jw.settlements.size(), "era": v.era, "notes": int(Market.notes),
		"starved": int(v.stats["starved"]), "extra": extra, "diag": diag, "ms": _ms(v),
		"plant": [ResidentAI.plant_tries, ResidentAI.plant_fails], "secs": int((Time.get_ticks_msec() - t0) / 1000.0)}
	print("TOOLS " + JSON.stringify(out))
	for k: int in digests:
		print("DIGEST seed %d mode %s day %d %s" % [s, mode, k, digests[k]])


func _set_step(dt: float) -> void:
	for q: Village in jw.settlements:
		q.step_dt = dt


func _giant(v: Village) -> void:
	if mode == "none":
		for l: Dictionary in v.open_letters("wish"):      # (Q30) 편지가 온 날만 적는다 (사지 않음)
			var dd := snappedf(float(l["t"]) / D, 0.01)
			if StoneShort.is_stone_wish(l) and not stone_at.has(dd):
				stone_at.append(dd)
			elif String(l["type"]) == TOOL_WISH and not wish_at.has(dd):
				wish_at.append(dd)
		return
	for q: Village in jw.settlements:
		for l: Dictionary in q.open_letters("wish"):
			if String(l["type"]) == TOOL_WISH:
				if not wish_at.has(snappedf(float(l["t"]) / D, 0.01)):
					wish_at.append(snappedf(float(l["t"]) / D, 0.01))
				_buy_tools(q)
			elif StoneShort.is_stone_wish(l):    # (Q30) '돌이 모자라요' — stonewish: 자갈 한 알 · veinwish: 회색 돌멩이 (못 사면 자갈)
				if not stone_at.has(snappedf(float(l["t"]) / D, 0.01)):
					stone_at.append(snappedf(float(l["t"]) / D, 0.01))
				if mode == "veinwish":
					if not _buy_tools(q, VEIN_ITEM):
						_buy_tools(q, GRAVEL_ITEM)
				elif mode == "stonewish":
					_buy_tools(q, GRAVEL_ITEM)
			elif mode == "help":
				q.grant_wish(int(l["id"]))
	if mode == "stone":                    # (Q26) + 창고의 돌이 바닥나면 자갈 한 알 (병 60일 뒤, 사흘에 한 번까지 — 지폐가 있을 때)
		if v.t > 60.0 * D and float(v.stock.get("돌", 0.0)) - v._owed("돌") < 4.0 and v.t - last_gravel >= 3.0 * D:
			if _buy_tools(v, GRAVEL_ITEM):
				last_gravel = v.t
	if mode == "help":
		var d := v.food_total() / maxf(1.0, Production.day_need(v))
		if d < 1.0 and v.t - last_help >= D:
			v.manna_fall("giant")
			helps += 1
			last_help = v.t


func _buy_tools(q: Village, item := TOOL_ITEM) -> bool:
	if not Shop.ITEMS.has(item):
		return false
	var c := Shop.can_buy(q, item)
	if not bool(c["ok"]):
		return false
	var price := Shop.price(q, item)
	var r := Shop.buy(q, item)
	if not bool(r["ok"]):
		return false
	if not q.air.lid_open:
		q.open_lid()
	var s := q.store()
	var at := Vector2(s.x, s.y)
	var res := {}
	for i in 24:                           # 창고 곁 빈자리 (나선)
		var a := float(i) * 2.399
		var p := at + Vector2(cos(a), sin(a)) * (3.0 + 0.4 * i)
		var h := Shop.hand_item(int(r["hand_id"]))
		res = SkyDrops.drop(q, item, p, h)
		if bool(res.get("ok", false)):
			Shop.hand_remove(int(r["hand_id"]))
			break
	if not bool(res.get("ok", false)):
		Shop.undo_buy(q, int(r["hand_id"]))
		return false
	if item == TOOL_ITEM:
		bought.append([snappedf(q.t / D, 0.01), int(price)])
	else:
		gravel.append([snappedf(q.t / D, 0.01), int(price)])
	return true


func _sample(v: Village) -> void:
	var adults := 0
	var idle := 0
	for p: Resident in v.people:
		if p.is_adult():
			adults += 1
			if p.job < 0 and Production.caring_for(v, p) == null:
				idle += 1
	var jobs := 0
	var empty := 0
	for b: Building in v.buildings:
		if b.built and b.def().get("job", false):
			jobs += 1
			if b.worker < 0:
				empty += 1
	var total := 0
	for q: Village in jw.settlements:
		total += q.people.size()
	var fd := v.food_total() / maxf(1.0, Production.day_need(v))
	var types := {}
	var sites := 0
	for b: Building in v.buildings:
		if b.is_site():
			sites += 1
		if b.built:
			types[b.type] = int(types.get(b.type, 0)) + 1
	extra[int(v.t / D)] = [snappedf(float(v.stock.get("판자", 0.0)), 0.1), snappedf(float(v.stock.get("돌", 0.0)), 0.1), sites,
		snappedf(v.land_capacity(), 0.1), snappedf(v.territory_r(), 0.1), types]
	diag[int(v.t / D)] = _diag(v)
	daily[int(v.t / D)] = [v.people.size(), adults, idle, snappedf(float(v.stock.get("도구", 0.0)), 0.1), jobs, empty, snappedf(fd, 0.01), int(Market.notes), total]


## (Q36) 일손이 남을 때 규칙(Village.spare_want)이 오늘 무엇에 막혔나 + 자원 — 읽기만 (난수 · 상태 변경 없음)
func _diag(v: Village) -> Dictionary:
	var hands := 0
	for p in v.people:
		if ToolShort.idle_hand(v, p):
			hands += 1
	var empty := 0
	for b in v.buildings:
		if not b.def().get("job", false) or (b.built and b.worker >= 0):
			continue
		if b.type == "채석장" and v.quarry_no_rock(b):
			continue
		empty += 1
	var tools := floori(float(v.stock.get("도구", 0.0)))
	var gate := ""
	if v.t < Balance.SPARE_FROM_DAY * D:
		gate = "early"
	elif hands < Balance.SPARE_IDLE:
		gate = "hands"
	elif empty >= maxi(1, tools):
		gate = "empty>=tools"
	var why := {}
	for ty: String in Balance.SPARE_ORDER:
		var r := "ok"
		if not VillageEra.can_build(v, ty):
			r = "era"
		elif not v._affordable(ty):
			r = "afford"
		elif v.has_method("spare_cap") and v.count_type(ty) >= int(v.call("spare_cap", ty)):
			r = "cap"
		elif not v.has_method("spare_cap") and Balance.SPARE_CAP.has(ty) and v.count_type(ty) >= int(Balance.SPARE_CAP[ty]):
			r = "cap"
		elif not v._spare_useful(ty):
			r = "useless"
		why[ty] = r
	var fish := 0
	if v.wild != null:
		for h: Dictionary in v.wild.herds:
			if h["kind"] == "fish" and not h["gone"]:
				fish += int(h["n"])
	var fd := v.food_total() / maxf(1.0, Production.day_need(v))
	var sap := 0
	for tr: Dictionary in v.trees:
		if tr["s"] == "sapling":
			sap += 1
	return {"sap": sap, "hands": hands, "empty": empty, "tools": tools, "gate": gate, "why": why, "want": v.spare_want(),
		"log": snappedf(float(v.stock.get("통나무", 0.0)), 0.1), "plank": snappedf(float(v.stock.get("판자", 0.0)), 0.1),
		"stone": snappedf(float(v.stock.get("돌", 0.0)), 0.1), "fish": fish, "trees": v._standing_trees(), "fd": snappedf(fd, 0.01),
		"wild": snappedf(v.wild_food, 1.0), "pop": v.people.size(), "forest": _forest(v)}


## (Q38) 산림관 곁 (2~7칸, 600곳) 중 심을 수 있는 곳 (옛 규칙: 땅 위 · VillagePlan.plantable) · 마을 한가운데 반지름 · 산림관 셈 (누적) — 읽기만 (난수 없음)
func _forest(v: Village) -> Dictionary:
	var core := 9.0
	for b in v.buildings:
		if b.type in VillagePlan.STREET_TYPES:
			core = maxf(core, Vector2(b.x, b.y).distance_to(v.fire) + 3.0)
	var huts: Array = []
	for b in v.buildings:
		if b.built and b.type == "산림관":
			var ok := 0
			for i in 600:
				var a := float(i) * 2.399
				var rr := 2.0 + 5.0 * fmod(float(i) * 0.618034, 1.0)
				var sp := Vector2(b.x + cos(a) * rr, b.y + sin(a) * rr)
				if v.water.inside(sp.x, sp.y, 2.0) and not v.water_at(sp.x, sp.y) and VillagePlan.plantable(v, sp):
					ok += 1
			huts.append([snappedf(Vector2(b.x, b.y).distance_to(v.fire), 0.1), ok, b.worker >= 0])
	return {"core": snappedf(core, 0.1), "huts": huts, "tries": ResidentAI.plant_tries, "fails": ResidentAI.plant_fails}


## (Q38) 고비 id → 넘은 병 날 (못 넘었으면 -1) — tools/measure_milestones.gd와 같은 셈
func _ms(v: Village) -> Dictionary:
	var out := {}
	var passed: Dictionary = v.milestones.get("passed", {})
	for id: String in Milestones.ORDER:
		out[id] = snappedf(float((passed[id] as Dictionary)["t"]) / D, 0.01) if passed.has(id) else -1.0
	return out


## 경제 지문 — 창고 · 사람(자리 · 일 · 집 · 나이 · 배고픔) · 건물 · 난수 흐름 · 지폐 · 통계(새 신호 값 빼고). 편지 · 연대기 · 말은 넣지 않는다
func _digest() -> String:
	var parts := PackedStringArray()
	parts.append("notes=%.3f" % Market.notes)
	for q: Village in jw.settlements:
		var ks: Array = q.stock.keys()
		ks.sort()
		for k: String in ks:
			parts.append("%s=%.4f" % [k, float(q.stock[k])])
		for p: Resident in q.people:
			parts.append("p%d:%.4f,%.4f,%d,%d,%.5f,%.4f" % [p.id, p.x, p.y, p.job, p.home, p.age, p.hunger])
		for b: Building in q.buildings:
			parts.append("b%d:%s,%.3f,%.3f,%s,%d" % [b.id, b.type, b.x, b.y, str(b.built), b.worker])
		for r: RandomNumberGenerator in [q.rng, q.gene_rng, q.health_rng, q.disc_rng, q.econ_rng, q.social_rng, q.pop_rng]:
			parts.append(str(r.state))
		var sk: Array = q.stats.keys()
		sk.sort()
		for k: String in sk:
			if k.begins_with("tool_"):
				continue
			parts.append("%s=%s" % [k, str(q.stats[k])])
	return "%d %s" % [parts.size(), "|".join(parts).sha256_text().substr(0, 16)]


func _collect() -> void:
	for q: Village in jw.settlements:
		if q.altar_items().is_empty():
			continue
		q.take_all()
		if q.revelation_pending():
			q.reveal()


func _hour(v: Village) -> float:
	return fmod(v.start_clock + v.t, D) / H
