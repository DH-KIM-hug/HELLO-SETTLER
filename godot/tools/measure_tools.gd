## 연장 멈춤 재 보기 (ROADMAP Q25, 2026-11-12) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다.
## 시작은 tools/measure_growth.gd watch와 같다 (넓은 세상 + 기본 키트 · 4월 15일 · 깨닫기 전 · 창조 첫날의 톡 세 번과 떨어뜨리기 한 번 ·
## 제단 공물 걷기 · 계시 받기). 병 한 시간씩 지켜본다 (걸음 30초).
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_tools.gd -- run <거인> <씨앗 처음> <씨앗 끝> <일수> [걸음 초]
## 거인:
##   none   아무것도 주지 않는다 (공물만 걷음)
##   wish   '연장이 모자라요' 편지가 오면 그때만 연장 꾸러미를 사서 창고 곁에 떨어뜨린다 (지폐가 모자라면 모일 때까지 기다림)
##   help   balance_v5_report의 help (건물 소원을 모두 들어줌 · 먹을 것이 1일치 아래면 병 하루 한 번 하늘 낟알) + wish
## 병 정오마다 본다: 식구 · 어른 · 일터 없는 어른(아기 돌봄 빼고) · 창고의 연장 · 일터(지어진 일 건물) · 빈 일터 · 먹을 것 날치 · 지폐.
## 씨앗마다 TOOLS 줄 하나(JSON) — 모으기는 밖에서. DIGEST 줄 = 경제가 같은지 보는 지문 (병 20일 · 끝).
extends SceneTree

const H := 3600.0
const D := 86400.0
const TOOL_ITEM := "연장 꾸러미"
const TOOL_WISH := "연장"

var jw: JarWorld
var mode := "none"
var seed_v := 0
var step := 30.0
var daily := {}              # 날 → [식구, 어른, 일터 없는 어른, 연장, 일터, 빈 일터, 먹을 것 날치, 지폐, 병 전체 식구]
var bought: Array = []        # [병 날, 값]
var wish_at: Array = []       # '연장' 편지가 온 병 날
var last_help := -1.0e9
var helps := 0
var digests := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	mode = args[1] if args.size() > 1 else "none"
	var s0 := int(args[2]) if args.size() > 2 else 1
	var s1 := int(args[3]) if args.size() > 3 else s0
	var days := int(args[4]) if args.size() > 4 else 200
	step = float(args[5]) if args.size() > 5 else 30.0
	for s in range(s0, s1 + 1):
		_run(s, days)
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
	last_help = -1.0e9
	helps = 0
	digests = {}
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
		if (dn == 20 or dn == 60 or dn == 120) and not digests.has(dn) and absf(v.t - dn * D) < 1800.0:
			digests[dn] = _digest()
	_set_step(sdt0)
	digests[days] = _digest()
	var out := {"mode": mode, "seed": s, "days": days, "daily": daily, "bought": bought, "wish_at": wish_at, "helps": helps,
		"end_pop": v.people.size(), "settlements": jw.settlements.size(), "era": v.era, "notes": int(Market.notes),
		"starved": int(v.stats["starved"]), "secs": int((Time.get_ticks_msec() - t0) / 1000.0)}
	print("TOOLS " + JSON.stringify(out))
	for k: int in digests:
		print("DIGEST seed %d mode %s day %d %s" % [s, mode, k, digests[k]])


func _set_step(dt: float) -> void:
	for q: Village in jw.settlements:
		q.step_dt = dt


func _giant(v: Village) -> void:
	if mode == "none":
		return
	for q: Village in jw.settlements:
		for l: Dictionary in q.open_letters("wish"):
			if String(l["type"]) == TOOL_WISH:
				if not wish_at.has(snappedf(float(l["t"]) / D, 0.01)):
					wish_at.append(snappedf(float(l["t"]) / D, 0.01))
				_buy_tools(q)
			elif mode == "help":
				q.grant_wish(int(l["id"]))
	if mode == "help":
		var d := v.food_total() / maxf(1.0, Production.day_need(v))
		if d < 1.0 and v.t - last_help >= D:
			v.manna_fall("giant")
			helps += 1
			last_help = v.t


func _buy_tools(q: Village) -> void:
	if not Shop.ITEMS.has(TOOL_ITEM):
		return
	var c := Shop.can_buy(q, TOOL_ITEM)
	if not bool(c["ok"]):
		return
	var price := Shop.price(q, TOOL_ITEM)
	var r := Shop.buy(q, TOOL_ITEM)
	if not bool(r["ok"]):
		return
	if not q.air.lid_open:
		q.open_lid()
	var s := q.store()
	var at := Vector2(s.x, s.y)
	var res := {}
	for i in 24:                           # 창고 곁 빈자리 (나선)
		var a := float(i) * 2.399
		var p := at + Vector2(cos(a), sin(a)) * (3.0 + 0.4 * i)
		var h := Shop.hand_item(int(r["hand_id"]))
		res = SkyDrops.drop(q, TOOL_ITEM, p, h)
		if bool(res.get("ok", false)):
			Shop.hand_remove(int(r["hand_id"]))
			break
	if not bool(res.get("ok", false)):
		Shop.undo_buy(q, int(r["hand_id"]))
		return
	bought.append([snappedf(q.t / D, 0.01), int(price)])


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
	daily[int(v.t / D)] = [v.people.size(), adults, idle, snappedf(float(v.stock.get("도구", 0.0)), 0.1), jobs, empty, snappedf(fd, 0.01), int(Market.notes), total]


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
