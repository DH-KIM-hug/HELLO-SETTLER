## 시대 점수 속도 보고 (헤드리스) — 새 넓은 세상 + 기본 키트, 거인이 내내 지켜봄. 한 시간마다 점수 출처 (인구·건물 / 발견).
## 실행: godot --headless --path godot -s res://tools/era_pace_report.gd -- [일수=3] [시드=7] [size=1024]
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := float(args[0]) if args.size() > 0 else 3.0
	var seed_v := int(args[1]) if args.size() > 1 else 7
	var size := int(args[2]) if args.size() > 2 else WorldCfg.SIZE
	var jw := JarWorld.create(seed_v, size)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y, Kits.make())
	v.auto_reveal = true
	var rate_sum := 0.0
	var disc_sum := 0.0
	var seen := {}
	var hours := int(days * 24.0)
	for h in hours:
		var e0 := v.era
		var p0 := v.era_pts
		v.advance(Village.HOUR)
		var d_pts := (v.era_pts - p0) if v.era == e0 else 0.0
		var disc_h := 0.0
		var names := []
		for id: String in v.discoveries:
			if not seen.has(id):
				seen[id] = true
				var pts := float(Codex.entry(id).get("pts", 0.0))
				disc_h += pts
				names.append("%s(+%.0f)" % [id, pts])
		disc_sum += disc_h
		rate_sum += maxf(0.0, d_pts - disc_h)
		var built_n := v.buildings.filter(func(b: Building) -> bool: return b.built).size()
		print("%s | era %d pts %5.1f | pop %2d bld %2d | rate~%5.1f disc %5.1f %s" % [
			v.fmt_time(v.t), v.era, v.era_pts, v.people.size(), built_n, rate_sum, disc_sum, " ".join(names)])
		if v.era != e0:
			print("  >>> 시대 %d at %s (t=%.2f일)" % [v.era, v.fmt_time(v.t), v.t / Village.DAY])
	quit()
