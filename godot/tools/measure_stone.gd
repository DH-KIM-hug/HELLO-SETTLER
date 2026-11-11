## 돌이 떨어지는 날 재기 (ROADMAP Q11-b 남은 것 ②, 2026-11-11) — 헤드리스 측정 도구. 게임 코드의 값은 바꾸지 않는다.
## tools/measure_food_trace.gd · measure_growth.gd의 watch와 똑같이 돌린다 (넓은 세상 + 기본 키트 · 4월 15일 · 깨닫기 전 · 도움 없음 ·
## 한 시간씩 30초 걸음) — 같은 씨앗이면 같은 마을이다. 씨앗마다:
##   E  일이 처음 일어난 때 (stone0 창고의 돌 0 · reach0 다 지은 채석장 둘레에 캘 바위 없음 · dry 그 둘이 함께 = 돌이 떨어진 날 ·
##      stall 그때 돌을 기다리는 터가 섰음 · out_all / rock0 병 안에 캘 바위가 하나도 없음 · 채석장 수가 바뀜 · 묘지 · 첫 죽음)
##   L  병 10일의 건물 자리 (종류 x y — 앞뒤 견주기: 무덤이 없는 마을의 밭 자리는 그대로여야 한다)
##   P  병 10 · 20 · 30 · 36 · 45 · 60 (· 75 · 90 · 105 · 120)일의 식구 · 집 정원 · 돌 · 건물 자리 해시
##   S  한 줄 요약
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_stone.gd -- <첫 씨앗> <끝 씨앗> [끝 날 = 60]
extends SceneTree

const H := 3600.0
const D := 86400.0
const MARKS := [10, 20, 30, 36, 45, 60, 75, 90, 105, 120]

var jw: JarWorld


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var s0 := int(args[0]) if args.size() > 0 else 15
	var s1 := int(args[1]) if args.size() > 1 else s0
	var days := float(args[2]) if args.size() > 2 else 60.0
	for s in range(s0, s1 + 1):
		_run(s, days)
	quit()


func _run(s: int, days: float) -> void:
	var t0 := Time.get_ticks_msec()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	Market.reset()
	Market.first_paid = false
	Market.mig_seed = s * 7919 + 13
	Market.today_override = "R1"
	jw = JarWorld.create_with_kit(s, WorldCfg.SIZE, Kits.make([]))
	var v := jw.primary()
	var rock0 := 0.0
	for rk: Dictionary in v.rocks:
		rock0 += float(rk["amt"])
	print("R %d rocks %d amt %.0f stock %.0f" % [s, v.rocks.size(), rock0, float(v.stock["돌"])])
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
	for q: Village in jw.settlements:
		q.step_dt = 30.0
	var first := {}                        # 일 이름 → 처음 일어난 날
	var out_h := 0                         # 돌 0 + 닿는 바위 없음인 시간
	var full_h := 0                        # 빈 침대가 없는 시간
	var dry_h := 0                         # 채석장은 있는데 캘 바위가 닿지 않고 돌이 0인 시간
	var stall_h := 0                       # … 그 가운데 돌을 기다리는 터가 서 있던 시간
	var mark_i := 0
	var marks := {}
	var quarries := 0
	var dead_seen := 0
	while v.t < days * D - 1.0 and not v.people.is_empty():
		jw.advance(minf(H, days * D - v.t))
		for q: Village in jw.settlements:
			q.crises.clear()
			if q.revelation_pending():
				q.reveal()
		var hr := int(_hour(v))
		if hr == 8 or hr == 20:
			_collect()
		var day := v.t / D
		var st := _stone(v)
		if float(v.stock["돌"]) < 1.0:
			_first(first, s, "stone0", day, st)
		if int(st["quarry"]) > 0 and int(st["reach_n"]) == 0:
			_first(first, s, "reach0", day, st)
		if float(v.stock["돌"]) < 1.0 and int(st["reach_n"]) == 0:
			out_h += 1
			_first(first, s, "out", day, st)          # 돌이 없고 지금 채석장으로는 더 캘 수 없다
			if int(st["all_n"]) == 0:
				_first(first, s, "out_all", day, st)  # 병 안에 캘 바위가 하나도 없다 (끝)
		if int(st["all_n"]) == 0:
			_first(first, s, "rock0", day, st)
		# dry = 다 지은 채석장이 있는데 그 둘레에 캘 바위가 없고 창고의 돌도 0 (석수가 캘 것이 없다 — '돌이 떨어진 날')
		if int(st["quarry"]) > 0 and int(st["reach_n"]) == 0 and float(v.stock["돌"]) < 1.0:
			dry_h += 1
			_first(first, s, "dry", day, st)
			var waits := false
			for b: Building in v.buildings:
				if b.is_site() and int(b.delivered["돌"]) < b.need("돌"):
					waits = true
			if waits:                                   # 돌을 기다리는 터가 서 있다 (멈춘 터)
				stall_h += 1
				_first(first, s, "stall", day, st)
		if int(st["quarry"]) + int(st["quarry_site"]) != quarries:
			quarries = int(st["quarry"]) + int(st["quarry_site"])
			print("E %d quarries %d (site %d) day %.2f | %s" % [s, quarries, int(st["quarry_site"]), day, _stone_txt(v, st)])
		if v.count_type("묘지") > 0:
			_first(first, s, "yard", day, st)
		while dead_seen < v.dead.size():
			var p: Resident = v.dead[dead_seen]
			if dead_seen == 0:
				_first(first, s, "death", p.death_t / D, st)
			dead_seen += 1
		var hc := _houses(v)
		if int(hc["free"]) == 0:
			full_h += 1
		while mark_i < MARKS.size() and day >= float(MARKS[mark_i]) - 1e-6:
			var m := int(MARKS[mark_i])
			marks[m] = {"pop": v.people.size(), "cap": int(hc["cap"]), "n": int(hc["n"])}
			print("P %d day %d pop %d cap %d houses %d (%s) free %d homeless %d | %s | layout %d" % [s, m, v.people.size(), int(hc["cap"]), int(hc["n"]),
				String(hc["kinds"]), int(hc["free"]), int(hc["homeless"]), _stone_txt(v, st), _layout_hash(v)])
			if m == 10:
				for b: Building in v.buildings:
					print("L %d %s %.3f %.3f %s" % [s, b.type if b.built else b.site_type(), b.x, b.y, "built" if b.built else "site"])
				for g: Dictionary in v.graves:
					print("L %d grave %.3f %.3f" % [s, float(g["x"]), float(g["y"])])
			mark_i += 1
	var st2 := _stone(v)
	var hc2 := _houses(v)
	print("S %d end %.1f pop36 %d pop60 %d cap36 %d cap60 %d houses %d (%s) | stone0 %s reach0 %s dry %s stall %s out_all %s rock0 %s | dry_h %d stall_h %d out_h %d full_h %d | quarries %d graves %d yard %d fields %d | died %d starved %d | %s | hid %s | sites %s| %.0f s" % [
		s, v.t / D, int(marks.get(36, {}).get("pop", -1)), int(marks.get(60, {}).get("pop", v.people.size())),
		int(marks.get(36, {}).get("cap", -1)), int(marks.get(60, {}).get("cap", int(hc2["cap"]))), int(hc2["n"]), String(hc2["kinds"]),
		_d(first, "stone0"), _d(first, "reach0"), _d(first, "dry"), _d(first, "stall"), _d(first, "out_all"), _d(first, "rock0"), dry_h, stall_h, out_h, full_h,
		int(st2["quarry"]) + int(st2["quarry_site"]), v.graves.size(), v.count_type("묘지"), v.count_type("농장"),
		int(v.stats.get("died", 0)), int(v.stats.get("starved", 0)), _stone_txt(v, st2), _hidden(v), _sites(v), (Time.get_ticks_msec() - t0) / 1000.0])


func _first(first: Dictionary, s: int, what: String, day: float, st: Dictionary) -> void:
	if first.has(what):
		return
	first[what] = day
	print("E %d %s day %.2f | %s" % [s, what, day, _stone_txt(jw.primary(), st)])


func _d(first: Dictionary, what: String) -> String:
	return ("%.1f" % float(first[what])) if first.has(what) else "-"


## 채석장(다 지은 것 · 터) 수 · 어느 채석장이든 닿는 캘 바위 · 병 안의 캘 바위 · 남은 바위에서 가장 가까운 채석장까지
func _stone(v: Village) -> Dictionary:
	var qs: Array[Vector2] = []
	var site := 0
	for b: Building in v.buildings:
		if b.built and b.type == "채석장":
			qs.append(Vector2(b.x, b.y))
		elif b.is_site() and b.site_type() == "채석장":
			site += 1
	var reach_n := 0
	var reach_amt := 0.0
	var all_n := 0
	var all_amt := 0.0
	var far_d := 0.0                   # 닿지 않는 바위 가운데 가장 가까운 채석장까지의 거리가 가장 짧은 것
	var far_n := 0
	for rk: Dictionary in v.rocks:
		if float(rk["amt"]) <= 0.0 or not SkyDrops.rock_minable(v, rk):
			continue
		all_n += 1
		all_amt += float(rk["amt"])
		var near := INF
		for q: Vector2 in qs:
			near = minf(near, Vector2(float(rk["x"]), float(rk["y"])).distance_to(q))
		if near <= Balance.GATHER_RANGE:
			reach_n += 1
			reach_amt += float(rk["amt"])
		else:
			far_n += 1
			far_d = near if far_d == 0.0 else minf(far_d, near)
	return {"quarry": qs.size(), "quarry_site": site, "reach_n": reach_n, "reach_amt": reach_amt, "all_n": all_n, "all_amt": all_amt, "far_n": far_n, "far_d": far_d}


func _stone_txt(v: Village, st: Dictionary) -> String:
	return "돌 %.0f owed %d 판자 %.0f | quarry %d+%d reach %d(%.0f) jar %d(%.0f) far %d@%.1f tr %.1f" % [float(v.stock["돌"]), v._owed("돌"), float(v.stock["판자"]),
		int(st["quarry"]), int(st["quarry_site"]), int(st["reach_n"]), float(st["reach_amt"]), int(st["all_n"]), float(st["all_amt"]),
		int(st["far_n"]), float(st["far_d"]) if is_finite(float(st["far_d"])) else -1.0, v.territory_r()]


func _houses(v: Village) -> Dictionary:
	var occ := v.occupancy()
	var cap := 0
	var free := 0
	var n := 0
	var kinds := {}
	for b: Building in v.houses():
		cap += b.cap()
		free += maxi(0, b.cap() - int(occ.get(b.id, 0)))
		n += 1
		kinds[b.type] = int(kinds.get(b.type, 0)) + 1
	var homeless := 0
	for p: Resident in v.people:
		if p.home < 0:
			homeless += 1
	var txt := ""
	for k: String in kinds:
		txt += "%s%d " % [k.substr(0, 2), int(kinds[k])]
	return {"cap": cap, "free": free, "n": n, "kinds": txt.strip_edges(), "homeless": homeless}


func _sites(v: Village) -> String:
	var out := ""
	for b: Building in v.buildings:
		if b.is_site():
			out += "%s(p%d/%d s%d/%d) " % [b.site_type(), int(b.delivered["판자"]), b.need("판자"), int(b.delivered["돌"]), b.need("돌")]
	return out


## 밀밭에 가린 무덤 (홀로 선 돌 n/모두 · 묘지 n/모두) — 규칙의 값(보는 축 45° · 3.6 · 2.8)을 여기 적어 둠: 고치기 전 코드에서도 같은 셈으로 재려고
func _hidden(v: Village) -> String:
	var farms: Array[Vector2] = []
	for b: Building in v.buildings:
		if b.type == "농장":
			farms.append(Vector2(b.x, b.y))
	var lone := 0
	var lone_hid := 0
	for g: Dictionary in v.graves:
		if bool(g.get("yard", false)):
			continue
		lone += 1
		if _covered(farms, Vector2(float(g["x"]), float(g["y"])), 0.0):
			lone_hid += 1
	var yards := 0
	var yard_hid := 0
	for b: Building in v.buildings:
		if b.type == "묘지":
			yards += 1
			if _covered(farms, Vector2(b.x, b.y), b.size()):
				yard_hid += 1
	return "grave %d/%d yard %d/%d" % [lone_hid, lone, yard_hid, yards]


func _covered(farms: Array[Vector2], q: Vector2, pad: float) -> bool:
	var ax := Vector2(sin(PI / 4.0), cos(PI / 4.0))
	for f: Vector2 in farms:
		var d := q - f
		var u := absf(d.dot(ax))
		var w := absf(d.dot(Vector2(ax.y, -ax.x)))
		if minf(u, w) < 2.8 + pad and maxf(u, w) < 3.6 + pad:
			return true
	return false


func _layout_hash(v: Village) -> int:
	var h := 17
	for b: Building in v.buildings:
		h = (h * 31 + hash(b.type if b.built else b.site_type()) + int(round(b.x * 100.0)) * 7 + int(round(b.y * 100.0)) * 13) & 0x3FFFFFFF
	return h


func _collect() -> void:
	for q: Village in jw.settlements:
		if q.altar_items().is_empty():
			continue
		q.take_all()
		if q.revelation_pending():
			q.reveal()


func _hour(v: Village) -> float:
	return fmod(v.start_clock + v.t, D) / H
