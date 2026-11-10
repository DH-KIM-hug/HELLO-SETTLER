## 첫날 먹을 것 재 보기 (ROADMAP Q7, 2026-11-11) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다.
## 넓은 세상 + 기본 키트(tools/measure_lifespan.gd와 같은 시작)를 병 N일 돌리며 병 한 시간마다 창고를 본다:
## 날마다 먹을 것이 모자란 시간 수 · 아침(6~12시)에 모자랐는가 · 가장 적었던 비축(날치) · 첫 수확·첫 밀가루·첫 빵 시각 ·
## 굶어 떠난 사람 · 맨손 채집(forage_*)이 열렸는가. 씨앗마다 SEED 줄 하나 — 모으기는 밖에서.
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_opening_food.gd -- run <거인> <씨앗 처음> <씨앗 끝> <일수> [trace]
##     (trace: 병 한 시간마다 HOUR 줄 — 창고의 먹을 것·밭·일꾼·짓는 터)
##   godot --headless --path godot -s res://tools/measure_opening_food.gd -- dust <씨앗 처음> <씨앗 끝>
##
## 거인:
##   watch    내내 지켜보기만 한다 (보통 속도로 병 N일 = 현실 N×5분). 낟알·소원 없음. 톡 세 번 · 떨어뜨리기 한 번(목격 — 물건은 아님)과 공물 받기는 한다
##   away     measure_lifespan의 'game+nohelp typical'과 같은 하루 (병 2일 지켜봄 → 병 약 2일 비움 되풀이), 낟알·소원 없음
##   typical  measure_lifespan의 'game typical' (지켜보는 동안 비축이 하루치 아래면 하늘 낟알 — 병 하루에 한 번까지, 소원 들어줌)
##
## 해 보기 전용: 환경 변수 Q7_DRY=<시작 건량> · Q7_WHEAT=<시작 밀> (게임 값은 안 바꾸고 이 판에서만 창고를 고쳐 놓는다)
##
## dust: 병 4일째 아침 9시에 먼지 뭉치를 굴리고(SmallCrises.force_dust) 덩어리마다 끝을 본다 — 뜯겨 사라짐 · 내려앉음 · 한 번도 안 뜯긴 채 물에 가라앉음.
extends SceneTree

const H := 3600.0
const D := 86400.0

var jw: JarWorld
var mode := "watch"
var seed_v := 0
var helps := 0
var last_help := -1.0e9
# 한 판 모음
var short_h: Array = []            # 달력 날(1부터)마다 모자란 시간 수
var morn_h: Array = []             # … 그 가운데 아침 6~12시
var food_min: Array = []           # … 가장 적었던 비축 (날치)
var first := {}                    # 사건 이름 → 병 시각(시간)
var cursor := 0
var hunger_max := 0.0
var health_min := 1.0
var idle_max := 0
var forage_first := -1.0
var dry_out := -1.0                # 건량이 바닥난 때 (시간)
var pop_day := {}
var trace := false


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var cmd := args[0] if args.size() > 0 else "run"
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	if cmd == "dust":
		var a := int(args[1]) if args.size() > 1 else 1
		var b := int(args[2]) if args.size() > 2 else a
		for s in range(a, b + 1):
			_dust(s)
		quit()
		return
	mode = args[1] if args.size() > 1 else "watch"
	if not mode in ["watch", "away", "typical"]:
		push_error("unknown watcher %s (watch | away | typical)" % mode)
		quit(1)
		return
	var s0 := int(args[2]) if args.size() > 2 else 1
	var s1 := int(args[3]) if args.size() > 3 else s0
	var days := int(args[4]) if args.size() > 4 else 10
	trace = args.size() > 5 and args[5] == "trace"
	print("CONST START_STOCK food: 건량 %.0f 빵 %.0f 밀 %.0f 버섯 %.0f | GROW_FIRST %.1fh | OPENING_CHIEF_AT %s | FORAGE_ENOUGH_DAYS %.1f | AUTO_MANNA %s" % [
		float(Balance.START_STOCK["건량"]), float(Balance.START_STOCK["빵"]), float(Balance.START_STOCK["밀"]), float(Balance.START_STOCK["버섯"]),
		Balance.GROW_FIRST / H, str(Balance.OPENING_CHIEF_AT), Balance.FORAGE_ENOUGH_DAYS, str(Balance.AUTO_MANNA)])
	for s in range(s0, s1 + 1):
		_run(s, days)
	quit()


func _new_world(s: int) -> Village:
	seed_v = s
	Market.reset()
	Market.first_paid = false
	Market.mig_seed = s * 7919 + 13
	Market.today_override = "R1"
	jw = JarWorld.create_with_kit(s, WorldCfg.SIZE, Kits.make([]))
	var v := jw.primary()
	# 해 보기 전용 (값을 고르기 전에 여러 안을 나란히 재려고): 환경 변수 Q7_DRY = 시작 건량, Q7_WHEAT = 시작 밀. 없으면 게임 값 그대로
	if OS.get_environment("Q7_DRY") != "":
		v.stock["건량"] = float(OS.get_environment("Q7_DRY"))
	if OS.get_environment("Q7_WHEAT") != "":
		v.stock["밀"] = float(OS.get_environment("Q7_WHEAT"))
	return v


# ───────────────────────── 한 판 ─────────────────────────
func _run(s: int, days: int) -> void:
	var t0 := Time.get_ticks_msec()
	var v := _new_world(s)
	helps = 0
	last_help = -1.0e9
	short_h = []
	morn_h = []
	food_min = []
	first = {}
	cursor = 0
	hunger_max = 0.0
	health_min = 1.0
	idle_max = 0
	forage_first = -1.0
	dry_out = -1.0
	pop_day = {}
	var lamp_s := float(Market.LAMP_HOURS[0]) * H
	var rate := float(Balance.AWAY_RATES[Balance.AWAY_DEFAULT_I])
	var watch_j := 10.0 * 60.0 * float(Balance.SPEEDS[Balance.SPEED_DEFAULT_I])      # typical: 한 번에 현실 10분
	var away_j := minf((86400.0 - 3.0 * 600.0) / 3.0, lamp_s) * rate
	var tapped := 0
	var dropped := false
	while v.t < 23.0 * H:                  # 창세의 날 (measure_lifespan과 같음)
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
	while v.t < days * D and not v.people.is_empty():
		var t_end := minf(v.t + (watch_j if mode != "watch" else days * D), days * D)
		while v.t < t_end - 1.0:           # 지켜봄: 한 시간씩
			jw.advance(minf(H, t_end - v.t))
			for q: Village in jw.settlements:
				q.crises.clear()
				if q.revelation_pending():
					q.reveal()
			var hr := int(_hour(v))
			if hr == 8 or hr == 20:
				_collect()
			_grant()
			_sample(v, true)
		_collect()
		if mode == "watch":
			break
		var left := minf(away_j, days * D - v.t)     # 비움: 병 한 시간씩 따라잡기
		while left > 1.0:
			var chunk := minf(H, left)
			var c := CatchUp.new(v, chunk / rate, lamp_s, jw, rate)
			c.run()
			c.finish()
			left -= chunk
			_sample(v, false)
		_collect()
		_grant()
	_line(v, days, (Time.get_ticks_msec() - t0) / 1000.0)


func _sample(v: Village, watching: bool) -> void:
	var cd := v.cal_day(v.t - 1.0)                    # 방금 지난 시간이 속한 달력 날 (1부터)
	while short_h.size() < cd:
		short_h.append(0)
		morn_h.append(0)
		food_min.append(1.0e9)
	var fd := v.food_total() / maxf(1.0, Production.day_need(v))
	food_min[cd - 1] = minf(float(food_min[cd - 1]), fd)
	if v.deficit > 0.0 or v.t - v.last_short_t < H:
		short_h[cd - 1] += 1
		var hr := fmod(v.start_clock + v.t - 1.0, D) / H
		if hr >= 6.0 and hr < 12.0:
			morn_h[cd - 1] += 1
	for e: Dictionary in v.events.since(cursor):
		cursor = int(e["n"])
		var k := String(e["kind"])
		if k in ["first_harvest", "first_flour", "first_bread"] and not first.has(k):
			first[k] = float(e["t"]) / H
	if not first.has("farm"):
		for b: Building in v.buildings:
			if b.built and b.type == "농장":
				first["farm"] = v.t / H
				break
	if dry_out < 0.0 and float(v.stock.get("건량", 0.0)) < 1.0:
		dry_out = v.t / H
	if forage_first < 0.0 and int(v.stats.get("forage_trips", 0)) > 0:
		forage_first = v.t / H
	var idle := 0
	for p: Resident in v.people:
		hunger_max = maxf(hunger_max, p.hunger)
		health_min = minf(health_min, p.health)
		if p.is_adult() and p.job < 0:
			idle += 1
	idle_max = maxi(idle_max, idle)
	if trace:
		_trace(v, fd, idle)
	var dn := int(v.t / D + 0.001)
	if dn >= 1 and not pop_day.has(dn) and absf(v.t - dn * D) < 1800.0:
		pop_day[dn] = v.people.size()
	if mode == "typical" and watching and fd < 1.0 and v.t - last_help >= D:      # 거인의 손 (measure_lifespan과 같음)
		v.manna_fall("giant")
		helps += 1
		last_help = v.t


func _trace(v: Village, fd: float, idle: int) -> void:
	var farms := 0
	var farm_w := 0
	var sites := PackedStringArray()
	var built := PackedStringArray()
	var field := 0.0
	for b: Building in v.buildings:
		if b.is_site():
			sites.append(b.site_type())
		elif b.built:
			if b.type == "농장":
				farms += 1
				field += float(b.out.get("밀", 0.0))
				if b.worker >= 0:
					farm_w += 1
			elif not b.type in ["창고"]:
				built.append(b.type)
	var acts := {}
	for p: Resident in v.people:
		if p.is_adult():
			acts[p.action] = int(acts.get(p.action, 0)) + 1
	print("HOUR seed=%d t=%.0fh clock=%04.1f day=%d fd=%.2f short=%d dry=%.0f wheat=%.0f(+%.0f) flour=%.0f bread=%.0f shroom=%.0f manna=%.0f farms=%d/%d sites=%s built=%s plank=%.0f stone=%.0f log=%.0f tools=%.0f idle=%d pop=%d hungermax=%.2f acts=%s" % [
		seed_v, v.t / H, fmod(v.start_clock + v.t, D) / H, v.cal_day(v.t - 1.0), fd, 1 if (v.deficit > 0.0 or v.t - v.last_short_t < H) else 0,
		float(v.stock.get("건량", 0.0)), float(v.stock.get("밀", 0.0)), field, float(v.stock.get("밀가루", 0.0)), float(v.stock.get("빵", 0.0)), float(v.stock.get("버섯", 0.0)),
		v.manna.reduce(func(a: float, m: Dictionary) -> float: return a + float(m["amt"]), 0.0),
		farm_w, farms, ",".join(sites), ",".join(built), float(v.stock["판자"]), float(v.stock["돌"]), float(v.stock.get("통나무", 0.0)), float(v.stock.get("도구", 0.0)),
		idle, v.people.size(), hunger_max, JSON.stringify(acts)])


func _line(v: Village, days: int, secs: float) -> void:
	while short_h.size() < days + 1:
		short_h.append(0)
		morn_h.append(0)
		food_min.append(-1.0)
	var fm := PackedStringArray()
	for x: float in food_min:
		fm.append("%.2f" % x)
	var why := {}
	for p: Resident in v.dead:
		why[p.death_why] = int(why.get(p.death_why, 0)) + 1
	var bad := v.check_invariants().size() + v.violations.size()
	print("SEED mode=%s seed=%d days=%d pop=%d born=%d died=%d starved=%d spared=%d short=%s morn=%s foodmin=%s farm=%.1f harvest=%.1f flour=%.1f bread=%.1f dry=%.1f forage_first=%.1f forage_trips=%d forage_food=%.0f hunger_max=%.2f health_min=%.2f idle_max=%d tools=%.0f helps=%d aware=%d altar=%d pop5=%d pop10=%d causes=%s bad=%d secs=%.0f" % [
		mode, seed_v, days, v.people.size(), int(v.stats["born"]), int(v.stats["died"]), int(v.stats["starved"]), int(v.stats.get("spared", 0)),
		",".join(PackedStringArray(short_h.map(func(x: int) -> String: return str(x)))),
		",".join(PackedStringArray(morn_h.map(func(x: int) -> String: return str(x)))), ",".join(fm),
		float(first.get("farm", -1.0)), float(first.get("first_harvest", -1.0)), float(first.get("first_flour", -1.0)), float(first.get("first_bread", -1.0)),
		dry_out, forage_first, int(v.stats.get("forage_trips", 0)), float(v.stats.get("forage_food", 0.0)), hunger_max, health_min, idle_max,
		float(v.stock.get("도구", 0.0)), helps, 1 if v.aware else 0, 1 if v.altar_built else 0, int(pop_day.get(5, -1)), int(pop_day.get(10, -1)),
		JSON.stringify(why), bad, secs])


# ───────────────────────── 거인의 하루 (measure_lifespan과 같음) ─────────────────────────
func _collect() -> void:
	for q: Village in jw.settlements:
		if q.altar_items().is_empty():
			continue
		q.take_all()
		if q.revelation_pending():
			q.reveal()


func _grant() -> void:
	if mode != "typical":
		return
	for q: Village in jw.settlements:
		for l: Dictionary in q.open_letters("wish"):
			q.grant_wish(int(l["id"]))


func _hour(v: Village) -> float:
	return fmod(v.start_clock + v.t, D) / H


# ───────────────────────── 먼지 뭉치 ─────────────────────────
## 병 4일째(위기가 열리는 날) 아침 9시에 굴리고, 덩어리가 다 사라질 때까지 병 1분씩 본다.
func _dust(s: int) -> void:
	var t0 := Time.get_ticks_msec()
	mode = "dust"
	var v := _new_world(s)
	var go := 3.0 * D + 2.0 * H                       # 도착(아침 7시)에서 병 3일 + 2시간 = 4일째 아침 9시
	var tapped := 0
	while v.t < go:
		jw.advance(minf(H, go - v.t))
		if tapped < 3 and v.t > (20.0 + 20.0 * tapped) * 60.0:
			Awakening.witness(v, "tap")
			tapped += 1
		for q: Village in jw.settlements:
			q.crises.clear()
	var sm := v.smalls
	sm.force_dust(v)
	var born := v.t
	var size0 := {}
	var pulled := {}                 # 덩어리 id → 처음 뜯긴 때 (병 시간, 굴린 뒤)
	var last := {}                   # 덩어리 id → [x, y, size]
	var ended := {}                  # 덩어리 id → "sunk" · "sunk_untouched" · "pulled" · "settled"
	for c: CrisisThing in sm.live("dust"):
		size0[c.id] = c.size
		last[c.id] = [c.x, c.y, c.size]
	var n := size0.size()
	var learned := -1.0
	var wet_secs := 0.0
	while ended.size() < n and v.t - born < Balance.DUST_LIFE + 2.0 * H:
		jw.advance(60.0)
		for q: Village in jw.settlements:
			q.crises.clear()
		if learned < 0.0 and sm.dust_known:
			learned = (v.t - born) / H
		var alive := {}
		for c: CrisisThing in sm.things:
			if c.kind != "dust":
				continue
			if c.state != "gone":
				alive[c.id] = true
				if v.water_at(c.x, c.y):
					wet_secs += 60.0
			if size0.has(c.id):
				if c.size < float(size0[c.id]) - 0.01 and not pulled.has(c.id):
					pulled[c.id] = (v.t - born) / H
				last[c.id] = [c.x, c.y, c.size]
		for id: int in size0:
			if ended.has(id) or alive.has(id):
				continue
			var l: Array = last[id]
			if float(l[2]) < Balance.DUST_MIN:
				ended[id] = "pulled"
			elif v.t - born >= Balance.DUST_LIFE - 120.0:
				ended[id] = "settled"
			else:
				ended[id] = "sunk" if pulled.has(id) else "sunk_untouched"
	var cnt := {"pulled": 0, "settled": 0, "sunk": 0, "sunk_untouched": 0, "left": n - ended.size()}
	for id: int in ended:
		cnt[ended[id]] += 1
	print("DUST seed=%d balls=%d pulled_away=%d settled=%d sunk_after_pull=%d sunk_untouched=%d left=%d learned_h=%.1f pulls=%d yarn=%.0f first_pull_h=%.1f wet_min=%.0f hours=%.1f secs=%.0f" % [
		s, n, cnt["pulled"], cnt["settled"], cnt["sunk"], cnt["sunk_untouched"], cnt["left"], learned, int(sm.stats["pulled"]), float(sm.stats["yarn"]),
		float(pulled.values().min()) if not pulled.is_empty() else -1.0, wet_secs / 60.0, (v.t - born) / H, (Time.get_ticks_msec() - t0) / 1000.0])
