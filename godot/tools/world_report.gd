## 넓은 세상 수치 보기 (6단계): godot --headless --path godot -s res://tools/world_report.gd -- [시드] [지름] [일수]
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	var size := int(args[1]) if args.size() > 1 else 1024
	var days := float(args[2]) if args.size() > 2 else 2.0
	var t0 := Time.get_ticks_usec()
	var ww := WorldGen.generate(seed_v, size, {"settle_days": 0.0})
	print("만들기 (타임랩스 빼고) %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	print("물 %.2f · 소금 %.4f" % [ww.total_water(), ww.total_salt()])
	t0 = Time.get_ticks_usec()
	ww.offline = true
	for d in int(days):
		var t1 := Time.get_ticks_usec()
		ww.advance(JarWater.DAY)
		print("  %d일 (거친 칸만, 오프라인) %.0f ms · 물 %.2f (들어옴 %.2f 나감 %.2f) · 소금 %.4f" % [d + 1, (Time.get_ticks_usec() - t1) / 1000.0, ww.total_water(), ww.added, ww.removed, ww.total_salt()])
	ww.offline = false
	print("물방울 %d · 골 %d · 자리 %d · 발견할 것 %d" % [ww.drips.size(), ww.grooves.size(), ww.spots.size(), ww.features.size()])
	for i in ww.spots.size():
		var s := ww.spots[i]
		var lake := ww.lake_cells_in(s, 40.0)
		var river := 0
		for k in ww.cells_near(s, 30.0):
			if ww.is_river(k):
				river += 1
		print("  자리 %d (%.0f, %.0f): 호수 칸 %d · 강 칸 %d · 물방울 호수 %d칸" % [i, s.x, s.y, lake, river, ww.lake_cells_in(Vector2(ww.drips[i]["x"], ww.drips[i]["y"]), 12.0)])
	for b: Dictionary in ww.basins:
		print("  부은 호수 %s: %d → %d칸" % [b["name"], b["area0"], ww.basin_area(b)])
	if args.size() > 3:
		var marks: Array = []
		for sp in ww.spots:
			marks.append({"p": sp, "c": Color.RED})
		WorldMap.render(ww, 1, false, marks).save_png(args[3])
		print("지도 → %s" % args[3])
	quit(0)
