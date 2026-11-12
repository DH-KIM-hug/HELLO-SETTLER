## 유모차 산책·첫 심부름·첫 낚시가 살림을 건드리지 않는지 재 보기 (ROADMAP E2-2 · E2-3) — 헤드리스 측정 도구. 게임 값은 바꾸지 않는다.
## 넓은 세상 + 기본 키트 (tools/measure_growth.gd와 같은 시작), 거인은 아무것도 하지 않는다. 내내 지켜봄 (병 한 시간씩 JarWorld.advance).
## 정한 날(기본 10 · 20일)마다 씨앗마다 OUT 줄 하나: 식구 · 태어남 · 죽음 · 집 · 건물 · 창고 합(물건마다) · 행복 합 · 난수 흐름 상태.
## 연대기는 파일로 (<폴더>/book_<씨앗>.txt) — 바꾸기 전·뒤의 것을 견주어 새 줄만 늘었는지 본다 (이 도구는 새 코드를 부르지 않는다 → 옛 커밋에서도 돈다).
##
## 실행:
##   godot --headless --path godot -s res://tools/measure_outings.gd -- run <씨앗 처음> <씨앗 끝> <일수> <연대기 폴더> [걸음 초]
##   (Q21) 심부름을 다녀온 몫은 EVT 줄 뒤 ERR 줄 (나섬 · 건넴 · 못 건넴 · 못 건넨 몫). 'trace'로 부르면 (run 대신) 병 10분씩 걸으며
##   못 건넨 심부름마다 TRACE 줄 (받을 사람이 그때 무엇을 하고 문에서 얼마나 떨어졌나) — 걸음 크기가 달라 OUT 값은 run과 견주지 않는다.
extends SceneTree

const H := 3600.0
const D := 86400.0
const MARKS := [10, 20, 30, 40]

var _trace := false
var _last_err := {}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Village.start_aware = false
	var s0 := int(args[1]) if args.size() > 1 else 1
	var s1 := int(args[2]) if args.size() > 2 else s0
	var days := int(args[3]) if args.size() > 3 else 20
	var dir := String(args[4]) if args.size() > 4 else ""
	var step := float(args[5]) if args.size() > 5 else 30.0
	_trace = args.size() > 0 and String(args[0]) == "trace"
	for s in range(s0, s1 + 1):
		_run(s, days, dir, step)
	quit()


func _run(s: int, days: int, dir: String, step: float) -> void:
	var t0 := Time.get_ticks_msec()
	Market.reset()
	Market.first_paid = false
	Market.mig_seed = s * 7919 + 13
	Market.today_override = "R1"
	var jw := JarWorld.create_with_kit(s, WorldCfg.SIZE, Kits.make([]))
	var v := jw.primary()
	while v.t < 23.0 * H:                  # 창세의 날은 게임 걸음 그대로
		jw.advance(5.0 * 60.0)
	for q: Village in jw.settlements:
		q.step_dt = step
	var mark := 0
	var cur := 0
	var evt := {}
	while v.t < days * D - 1.0 and not v.people.is_empty():
		jw.advance(minf(600.0 if _trace else H, days * D - v.t))
		if _trace:
			var er := ChildOutings.errand(v)
			if not er.is_empty():
				_last_err = er.duplicate()
				var q := v.person(int(er["rc"]))
				var hm := v.bld(int(er["to"]))
				if q != null and hm != null:
					_last_err["q"] = "%s %s/%s 문에서 %.1f 노인 %s 아기안음 %s" % [q.name, q.action, q.anim, Vector2(q.x, q.y).distance_to(ChildOutings._door(hm)), q.is_elder(), q.carry]
		for e: Dictionary in v.events.since(cur):      # 나들이 사건 세기 (읽기만 — 시뮬은 그대로)
			cur = int(e["n"])
			var kd := String(e["kind"])
			if kd.begins_with("stroller_") or kd.begins_with("errand_") or kd.begins_with("first_fishing_"):
				evt[kd] = int(evt.get(kd, 0)) + 1
				if kd == "errand_ended" or kd == "first_fishing_ended":
					var kk := kd + ("_ok" if int(e["v"]) == 1 else "_no")
					evt[kk] = int(evt.get(kk, 0)) + 1
					if _trace and kd == "errand_ended" and int(e["v"]) != 1:
						print("TRACE seed %d day %.2f  %s" % [s, v.t / D, str(_last_err)])
		for q: Village in jw.settlements:
			q.crises.clear()
			if q.revelation_pending():
				q.reveal()
		while mark < MARKS.size() and v.t >= float(MARKS[mark]) * D - 1.0:
			_line(jw, s, int(MARKS[mark]))
			mark += 1
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
		var f := FileAccess.open("%s/book_%d.txt" % [dir, s], FileAccess.WRITE)
		for q: Village in jw.settlements:
			for e: Dictionary in q.book:
				f.store_line("%d|%.0f|%s" % [q.sid, float(e["t"]), String(e["text"])])
		f.close()
	var kids := 0
	for r: Resident in v.people:
		kids += int(r.is_child() and r.age >= Balance.ERRAND_AGE)
	print("EVT seed %d  %s  (심부름 나이 아이 %d · 다녀온 아이 %d · 낚아 본 아이 %d · 물고기 떼 %d)" % [s, JSON.stringify(evt), kids,
		(ChildOutings.peek(v).get("ed", {}) as Dictionary).size(), (ChildOutings.peek(v).get("fd", {}) as Dictionary).size(), v.wild.herds.size() if v.wild != null else 0])
	var e_go := int(evt.get("errand_started", 0))
	var e_no := int(evt.get("errand_ended_no", 0))
	print("ERR seed %d  started %d  given %d  not_given %d  not_given_ratio %.3f" % [s, e_go, int(evt.get("errand_given", 0)), e_no, float(e_no) / maxf(1.0, float(e_go))])
	print("DONE seed %d  %.0fs" % [s, (Time.get_ticks_msec() - t0) / 1000.0])


func _line(jw: JarWorld, s: int, day: int) -> void:
	var pop := 0
	var born := 0
	var died := 0
	var houses := 0
	var blds := 0
	var happy := 0.0
	var hunger := 0.0
	var stock := {}
	var total := 0.0
	var rngs: Array = []
	var lines := 0
	var pos := 0.0
	for q: Village in jw.settlements:
		pop += q.people.size()
		born += int(q.stats["born"])
		died += int(q.stats["died"])
		blds += q.buildings.size()
		lines += q.book.size()
		for b: Building in q.buildings:
			if b.is_house():
				houses += 1
		for r: Resident in q.people:
			happy += r.happiness
			hunger += r.hunger
			pos += r.x * 3.0 + r.y * 7.0
		for k: String in q.stock:
			stock[k] = snappedf(float(stock.get(k, 0.0)) + float(q.stock[k]), 0.001)
			total += float(q.stock[k])
		rngs.append([q.rng.state, q.social_rng.state, q.pop_rng.state, q.health_rng.state, q.econ_rng.state])
	var keys := stock.keys()
	keys.sort()
	var st := {}
	for k: String in keys:
		st[k] = stock[k]
	print("OUT " + JSON.stringify({"seed": s, "day": day, "setts": jw.settlements.size(), "pop": pop, "born": born, "died": died, "houses": houses, "blds": blds,
		"stock_total": snappedf(total, 0.001), "stock": st, "happy": snappedf(happy, 0.0001), "hunger": snappedf(hunger, 0.0001), "pos": snappedf(pos, 0.001),
		"lines": lines, "rng": str(rngs)}))
