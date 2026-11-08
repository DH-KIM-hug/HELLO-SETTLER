## BALANCE v5 / v5-0 측정 (헤드리스) — 넓은 세상 + 기본 키트, 병 N일, 가격 연구(v5 econ_sim)와 같은 하루:
##   현실 하루 = 병 10일 = [지켜봄 2일 · 비움(따라잡기 ×6) 1.33일] × 3번. 창세의 날은 톡 세 번 + 내려 주기로 깨달음.
##   지켜보는 동안 병 8시·20시에 제단의 제물을 거두고 (돈이 제단 값의 1.5배면 제단을 넓힘), 계시는 바로 받음.
## 거인의 손 (세 번째 인자):
##   none = 그냥 둠 (제물만 거둠 — 소원·먹을 것 도움 없음)
##   help = 소원을 모두 들어주고, 지켜보는 동안 먹을 것 비축이 1일치 아래면 하늘 낟알 하루치 (병 하루에 한 번까지)
## 결과 (v5-0): 먹을 것 비축 (일치, 병 한 시간마다 — 비운 동안 포함), 빠듯한 때(1일치 아래로 떨어진 횟수), 굶어 죽음, 인구, 지폐(현실 하루)
## 실행: godot --headless --path godot -s res://tools/balance_v5_report.gd -- [일수=60] [시드들=11,23,37] [none|help] [시작 달=4] [핵=1]
## 핵 (A28b — 0 서늘한 별 · 1 따뜻한 별(기준) · 2 뜨거운 별): 1이면 예전과 똑같은 세상. 0·2는 같은 시드의 세상에 핵만 바꿔 얹음 (광맥·화산도 그 핵대로).
## 핵 줄 (CORE): 밭 자람(철 × 핵 × 이슬·마른 철 — 첫 밭, 시간 평균) · 이슬/마른 철 배율 · 이끼 덮임 · 탁한 공기 · 버섯 돋음 · 달팽이 덤 ·
##   앓은 몫 · 추위 노출 시간 몫 · 땅 흔들림 · 깨진 항아리 · 온천 · 꽃숲(나무 수) · 수첩 한 줄 · 한 해 추운 날(철 기온 < 5°C)
extends SceneTree

const H := 3600.0
const D := 86400.0
const R := 10.0                    # 현실 하루 = 병 10일

var jw: JarWorld
var help := false
var sdays: Array = []              # 시간마다 비축 (일치)
var lean := 0
var lean_at: Array = []
var in_lean := false
var helps := 0
var last_help := -1.0e9
var pop_min := 999
var pop_max := 0
var bread := -1.0
var core := 1
var g_sum := 0.0                   # 첫 밭 자람 배율 합 (시간마다)
var w_sum := 0.0                   # 이슬·마른 철 배율 합
var m_sum := 0.0                   # 이끼 덮임 합
var st_sum := 0.0                  # 탁한 공기 합
var c_n := 0
var g_n := 0
var cold_secs := 0.0               # 추위 노출 중인 사람 × 표본 (시간)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 60
	var seeds := (args[1] if args.size() > 1 else "11,23,37").split(",")
	help = args.size() > 2 and args[2] == "help"
	var month := int(args[3]) if args.size() > 3 else 4
	core = clampi(int(args[4]), 0, 2) if args.size() > 4 else 1
	Village.default_created = {"year": 2026, "month": month, "day": 15}
	Village.start_aware = false
	for sd: String in seeds:
		_run(int(sd), days)
	quit()


func _run(seed_v: int, days: int) -> void:
	var t0 := Time.get_ticks_msec()
	Market.reset()
	Market.first_paid = false
	sdays = []
	lean = 0
	lean_at = []
	in_lean = false
	helps = 0
	last_help = -1.0e9
	pop_min = 999
	pop_max = 0
	bread = -1.0
	_income = {}
	_items = {}
	g_sum = 0.0
	w_sum = 0.0
	m_sum = 0.0
	st_sum = 0.0
	c_n = 0
	g_n = 0
	cold_secs = 0.0
	if core == 1:
		jw = JarWorld.create_with_kit(seed_v, WorldCfg.SIZE, Kits.make([]))
	else:
		jw = JarWorld.create(seed_v, WorldCfg.SIZE)
		WorldGen._minerals(jw.water, core, seed_v, [])
		var rec := jw.recommended_kit_spots()
		var p: Vector2 = rec[0] if not rec.is_empty() else Vector2.ZERO
		jw.place_kit(p.x, p.y, Kits.make([]))
	var v := jw.primary()
	Market.today_override = "R1"
	var tapped := 0
	var dropped := false
	while v.t < 23.0 * H:                  # 창세의 날
		jw.advance(5.0 * 60.0)
		if tapped < 3 and v.t > (20.0 + 20.0 * tapped) * 60.0:
			Awakening.witness(v, "tap")
			tapped += 1
		if not dropped and v.t > 50.0 * 60.0:
			Awakening.witness(v, "drop")
			dropped = true
		if fmod(v.t, H) < 300.0:
			_sample(v, true)
		if _hour(v) >= 19.6 and v.cal_day(v.t) == 1:
			_collect()
		_grant()
	_collect()
	var income := {}
	var watch_d := 0.6 * R / 3.0
	var away_d := 0.4 * R / 3.0
	while v.cal_day(v.t) < days and not v.people.is_empty():
		var t_end := v.t + watch_d * D
		while v.t < t_end - 1.0:           # 지켜봄: 한 시간씩
			jw.advance(minf(H, t_end - v.t))
			for q: Village in jw.settlements:
				q.crises.clear()
				if q.revelation_pending():
					q.reveal()
			var hr := int(_hour(v))
			if hr == 8 or hr == 20:
				_collect()
			_today(v)
			_grant()
			_sample(v, true)
		_collect()
		_buy_altar()
		var left := away_d * D             # 비움: 병 한 시간씩 따라잡기 (×6)
		while left > 1.0:
			var c := CatchUp.new(v, minf(H, left) / 6.0, -1.0, jw, 6.0)
			c.run()
			c.finish()
			left -= H
			_sample(v, false)
		_today(v)
		_collect()
		_grant()
	income = _income
	var vals: Array = sdays.duplicate()
	vals.sort()
	var over10 := vals.filter(func(x: float) -> bool: return x > 10.0).size()
	var in14 := vals.filter(func(x: float) -> bool: return x >= 1.0 and x <= 4.0).size()
	var inc := PackedStringArray()
	for k: String in income:
		inc.append("%d" % roundi(float(income[k])))
	print("RESULT seed %d %s | pop %d (min %d max %d) | born %d died %d starved %d | stock days p10 %.1f median %.1f p90 %.1f · 1~4일 %.0f%% · >10일 %.0f%% | lean %d at %s | helps %d | notes/real day %s | bread jd %.1f | era %d | %.0f s" % [
		seed_v, "help" if help else "none", v.people.size(), pop_min, pop_max, int(v.stats["born"]), int(v.stats["died"]), int(v.stats["starved"]),
		_pct(vals, 0.1), _pct(vals, 0.5), _pct(vals, 0.9), 100.0 * in14 / maxf(1, vals.size()), 100.0 * over10 / maxf(1, vals.size()),
		lean, lean_at, helps, ",".join(inc), bread, v.era, (Time.get_ticks_msec() - t0) / 1000.0])
	print("  offered ", _items, " | stock ", _stock_line(v))
	var notes := PackedStringArray()
	for n: Dictionary in v.jar_notes:
		notes.append("%s@%.1f" % [n["id"], float(n["t"]) / D])
	var ps := maxf(1.0, float(v.stats.get("person_secs", 0.0)))
	print("CORE seed %d core %d | grow %.3f wet %.3f | moss %.2f stale %.3f | shrooms %d picked %.0f snails %.0f | sick %.1f%% cold %.1f%% | tremors %d lost %.0f spring %s | trees %d | cold days/yr %d | notes %s" % [
		seed_v, core, g_sum / maxf(1, g_n), w_sum / maxf(1, g_n), m_sum / maxf(1, c_n), st_sum / maxf(1, c_n),
		int(v.flora.stats.get("shrooms", 0)), float(v.flora.stats.get("picked", 0.0)), float(v.stats.get("snails", 0.0)),
		100.0 * float(v.stats.get("sick_secs", 0.0)) / ps, 100.0 * cold_secs / maxf(1.0, float(c_n) * maxf(1, v.people.size())),
		int(v.stats.get("tremors", 0)), float(v.stats.get("tremor_lost", 0.0)), str(Codex.knows(v, "hot_spring")),
		v.trees.filter(func(t: Dictionary) -> bool: return t["s"] == "tree").size(), _cold_days(v), ",".join(notes)])


## 한 해 가운데 철 기온(낮밤·자리 뺌) < 5°C인 날 수 — 겨울의 길이 (핵이 기온을 옮김)
static func _cold_days(v: Village) -> int:
	var row := Health.climate_row(v)
	var n := 0
	for d in 365:
		if float(row[0]) + CoreWarmth.temp(v) - float(row[1]) * cos(TAU * (d - Balance.COLDEST_DOY) / 365.0) < Balance.COLD_FROM:
			n += 1
	return n


static func _stock_line(v: Village) -> String:
	var st := PackedStringArray()
	for k: String in v.stock:
		if float(v.stock[k]) >= 1.0:
			st.append("%s=%d" % [k, int(v.stock[k])])
	return ",".join(st)


static func _pct(a: Array, p: float) -> float:
	return float(a[clampi(int(a.size() * p), 0, a.size() - 1)]) if not a.is_empty() else 0.0


func _sample(v: Village, watching: bool) -> void:
	if v.people.is_empty():
		return
	var d := v.food_total() / maxf(1.0, Production.day_need(v))
	for b in v.buildings:                 # 핵 줄: 첫 밭의 자람 배율 (철 × 핵 × 이슬·마른 철)
		if b.built and b.type == "농장":
			g_sum += Health.season_grow(v) * CoreWarmth.farm_mult(v, b)
			w_sum += CoreWarmth.field_wet_mult(v, b)
			g_n += 1
			break
	m_sum += CoreWarmth.moss_cover(v)
	st_sum += v.air.stale
	c_n += 1
	for r in v.people:
		if r.cold >= Balance.DISEASE_EXPOSED:
			cold_secs += 1.0
	sdays.append(d)
	if d < 1.0 and not in_lean and v.t > D:      # 첫날(건량 하루치로 시작)은 빼고
		in_lean = true
		lean += 1
		lean_at.append(snappedf(v.t / D, 0.1))
	elif d >= 1.5:
		in_lean = false
	if help and watching and d < 1.0 and v.t - last_help >= D:
		v.manna_fall("giant")
		helps += 1
		last_help = v.t
	if v.t > D:
		pop_min = mini(pop_min, v.people.size())
	pop_max = maxi(pop_max, v.people.size())
	if bread < 0.0 and float(v.stock.get("빵", 0.0)) >= 1.0:
		bread = v.t / D


var _income := {}
var _items := {}


func _collect() -> void:
	for q: Village in jw.settlements:
		if q.altar_items().is_empty():
			continue
		for it: String in q.altar_items():
			_items[it] = int(_items.get(it, 0)) + int(q.altar_items()[it])
		var n0 := Market.notes
		q.take_all()
		_income[Market.today_override] = float(_income.get(Market.today_override, 0.0)) + Market.notes - n0
		if q.revelation_pending():
			q.reveal()


func _buy_altar() -> void:
	for q: Village in jw.settlements:
		var nx: Dictionary = Altar.next(q)
		if not nx.is_empty() and String(nx["lock"]) == "" and Market.notes >= float(nx["cost"]) * 1.5:
			Altar.expand(q)


func _grant() -> void:
	if not help:
		return
	for q: Village in jw.settlements:
		for l: Dictionary in q.open_letters("wish"):
			q.grant_wish(int(l["id"]))


func _today(v: Village) -> void:
	Market.today_override = "R%d" % (1 + int(floor(float(v.cal_day(v.t) - 2) / R)))


func _hour(v: Village) -> float:
	return fmod(v.start_clock + v.t, D) / H
