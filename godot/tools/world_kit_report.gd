## 넓은 세상 + 키트 수치 보기 (6단계): godot --headless --path godot -s res://tools/world_kit_report.gd -- [시드] [지름] [일수] [지도.png] [키트 수]
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_v := int(args[0]) if args.size() > 0 else 1
	var size := int(args[1]) if args.size() > 1 else 1024
	var days := int(args[2]) if args.size() > 2 else 3
	var kits := int(args[4]) if args.size() > 4 else 1
	var t0 := Time.get_ticks_usec()
	var jw := JarWorld.create(seed_v, size)
	print("세상 만들기 (타임랩스 포함) %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var rec := jw.recommended_kit_spots()
	print("추천 자리 %d곳" % rec.size())
	t0 = Time.get_ticks_usec()
	for i in mini(kits, rec.size()):
		jw.place_kit(rec[i].x, rec[i].y)
	var v := jw.primary()
	print("키트 놓기 %.0f ms · 고운 조각 %d (칸 %d) · 나무 %d · 바위 %d" % [(Time.get_ticks_usec() - t0) / 1000.0, jw.water.fine_chunks.size(), jw.water.fcells.size(), v.trees.size(), v.rocks.size()])
	var w0 := jw.water.total_water()
	var s0 := jw.water.total_salt()
	jw.water.added = 0.0
	jw.water.removed = 0.0
	v.water.offline = true
	v.step_dt = 30.0
	for o in v.others:
		o.step_dt = 30.0
	for d in days:
		var t1 := Time.get_ticks_usec()
		jw.advance(Balance.DAY)
		var ms := (Time.get_ticks_usec() - t1) / 1000.0
		var ww := jw.water
		print("  %d일: %.0f ms · 인구 %d · 건물 %d · 물 %.2f (기대 %.2f) · 소금 %.5f (처음 %.5f) · 고운 조각 %d" % [d + 1, ms, v.people.size(), v.buildings.size(), ww.total_water(), w0 + ww.added - ww.removed, ww.total_salt(), s0, ww.fine_chunks.size()])
	var lake := 0
	var river := 0
	for k in jw.water.cells_near(v.center, 36.0):
		if jw.water.is_lake(k):
			lake += 1
		elif jw.water.is_river(k):
			river += 1
	print("마을 둘레 36칸: 호수 칸 %d · 강 칸 %d" % [lake, river])
	var rev := 0
	for q in jw.water.fog.size():
		if jw.water.fog[q] != 0:
			rev += 1
	print("본 땅 %.2f%% · 탐험 %s번" % [100.0 * rev / (PI * pow(jw.water.fn * 0.5, 2)), str(v.stats.get("explore", 0))])
	for s in jw.settlements:
		print("-- 무리 %d 연대기" % s.sid)
		for e: Dictionary in s.book:
			print("   %s %s" % [s.fmt_time(e["t"]), e["text"]])
	if args.size() > 3 and args[3] != "-":
		var marks: Array = []
		for sp in jw.water.spots:
			marks.append({"p": sp, "c": Color.RED})
		for s in jw.settlements:
			for p in s.people:
				marks.append({"p": Vector2(p.x, p.y), "c": Color.ORANGE})
		WorldMap.render(jw.water, 1, true, marks).save_png(args[3])
	quit(0)
