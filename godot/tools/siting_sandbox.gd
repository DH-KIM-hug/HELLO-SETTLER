## 자리 잡기 모래판 (헤드리스, 몇 초) — 키트를 놓고 안개를 걷은 뒤 정해진 순서로 건물을 지어 본 배치 그림.
## 실행: godot --headless --path godot -s res://tools/siting_sandbox.gd -- [이름=sandbox] [시드=1,2,3] [집 수=20]
## 결과: godot_shots/<이름>_s<시드>.png (모닥불 둘레 34칸, ppu 10). 시간 흐름 없음 → 배치 규칙만 본다 (자원이 줄어든 뒤는 shot_siting)
extends SceneTree

const SitingMap = preload("res://tools/siting_map.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var name := args[0] if args.size() > 0 else "sandbox"
	var seeds: Array = []
	for s in (String(args[1]) if args.size() > 1 else "1,2,3").split(","):
		seeds.append(int(s))
	var nh := int(args[2]) if args.size() > 2 else 20
	var out_dir := ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	for sd: int in seeds:
		var jw := JarWorld.create(sd, WorldCfg.SIZE)
		var rec := jw.recommended_kit_spots()
		var v := jw.place_kit(rec[0].x, rec[0].y, Kits.make())
		v.water.offline = true
		v.water.reveal(v.sid, v.center.x, v.center.y, v.territory_r() + 4.0, true)
		v.era = 1
		v.t = Balance.DAY
		for k in ["판자", "돌"]:
			v.stock[k] = 999.0
		var seq: Array = ["나무꾼", "오두막", "농장", "맷돌간", "오두막", "채석장", "농장", "제재소", "오두막", "화덕", "오두막", "산림관", "농장", "우물"]
		var extra: Array = ["어부", "약초꾼", "치료소", "교회", "나무꾼", "농장", "방앗간"]
		var h := 4
		while h < nh:
			seq.append("오두막")
			h += 1
			if not extra.is_empty() and h % 3 == 0:
				seq.append(extra.pop_front())
		var t0 := Time.get_ticks_msec()
		var miss: Array = []
		for ty: String in seq:
			if not Balance.B.has(ty):
				continue
			var sp: Variant = v.find_spot(ty)
			if sp == null:
				miss.append(ty)
				continue
			var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
			v.on_built(b)
		var img := SitingMap.render(v, 34.0, 10)
		img.save_png(out_dir.path_join("%s_s%d.png" % [name, sd]))
		print("seed %d · %d채 · %dms · 자리 없음 %s" % [sd, v.buildings.size(), Time.get_ticks_msec() - t0, str(miss)])
	quit()
