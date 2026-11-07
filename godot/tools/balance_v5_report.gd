## BALANCE v5 / v5-0 측정 (헤드리스) — 넓은 세상 + 기본 키트, 병 N일, 가격 연구(v5 econ_sim)와 같은 하루:
##   현실 하루 = 병 10일 = [지켜봄 2일 · 비움(따라잡기 ×6) 1.33일] × 3번. 창세의 날은 톡 세 번 + 내려 주기로 깨달음.
##   지켜보는 동안 병 8시·20시에 제단의 제물을 거두고 (돈이 제단 값의 1.5배면 제단을 넓힘), 계시는 바로 받음.
## 거인의 손 (세 번째 인자):
##   none = 그냥 둠 (제물만 거둠 — 소원·먹을 것 도움 없음)
##   help = 소원을 모두 들어주고, 지켜보는 동안 먹을 것 비축이 1일치 아래면 하늘 낟알 하루치 (병 하루에 한 번까지)
## 결과 (v5-0): 먹을 것 비축 (일치, 병 한 시간마다 — 비운 동안 포함), 빠듯한 때(1일치 아래로 떨어진 횟수), 굶어 죽음, 인구, 지폐(현실 하루)
## 실행: godot --headless --path godot -s res://tools/balance_v5_report.gd -- [일수=60] [시드들=11,23,37] [none|help] [시작 달=4]
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


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 60
	var seeds := (args[1] if args.size() > 1 else "11,23,37").split(",")
	help = args.size() > 2 and args[2] == "help"
	var month := int(args[3]) if args.size() > 3 else 4
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
	jw = JarWorld.create_with_kit(seed_v, WorldCfg.SIZE, Kits.make([]))
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
