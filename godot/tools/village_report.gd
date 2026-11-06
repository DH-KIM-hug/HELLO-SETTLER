## 부락 시뮬레이션 일별 보고 (헤드리스) — 수치 맞출 때 쓰는 도구
## 실행: godot --headless --path godot -s res://tools/village_report.gd -- [일수=10] [시드=1] [watch=all|2h] [step=10]
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := int(args[0]) if args.size() > 0 else 10
	var seed_v := int(args[1]) if args.size() > 1 else 1
	var watch := args[2] if args.size() > 2 else "2h"
	var step := float(args[3]) if args.size() > 3 else 10.0
	var v := Village.new_prototype(seed_v)
	v.step_dt = step
	v.water.offline = true
	v.auto_reveal = true
	if watch == "2h":
		v.watch_hours = [20, 21]
	var t0 := Time.get_ticks_msec()
	for d in days:
		var td := Time.get_ticks_msec()
		v.advance(Village.DAY)
		var houses := v.houses()
		var cap := 0
		for h in houses:
			cap += h.cap()
		var jobs := 0
		for p in v.people:
			if p.job >= 0:
				jobs += 1
		print("day %2d | pop %2d (born %2d died %d starved %d) | houses %d cap %d | bld %d | jobs %d | food %.0f 밀 %.0f | 판자 %.0f 돌 %.0f 통나무 %.0f 도구 %.0f | era %d %.0f | faith %.0f | %d ms" % [
			d + 1, v.people.size(), v.stats["born"], v.stats["died"], v.stats["starved"], houses.size(), cap,
			v.buildings.filter(func(b: Building) -> bool: return b.built).size(), jobs, v.food_total(), float(v.stock["밀"]),
			float(v.stock["판자"]), float(v.stock["돌"]), float(v.stock["통나무"]), float(v.stock["도구"]),
			v.era, v.era_pts, v.faith, Time.get_ticks_msec() - td])
		var bad := v.check_invariants()
		if not bad.is_empty():
			print("  !! ", bad)
	print("total %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var types := {}
	for b in v.buildings:
		types[b.type] = int(types.get(b.type, 0)) + 1
	print(types)
	for e: Dictionary in v.book.slice(0, 40):
		print("  [%s] %s" % [v.fmt_time(e["t"]), e["text"]])
	quit()
