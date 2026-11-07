## 땅 화면 — 겉흙 12종·계절 (A13, view/ground_look.gd) · 유리벽 폭포 굵기 (A12, view/waterfalls.gd) · 넓은 세상 땅 조각·세상 지도 (A18).
## tests/run.gd가 부름 (`-- terrain` = 이것만, 몇 초). 화면 없이 계산만 — 실제 그림은 tools/shot_terrain.gd, 화면 시간은 tools/frame_terrain.gd.
extends RefCounted

var run: SceneTree
var quick := false
const SLOW: Array = []


func _init(r: SceneTree, q: bool) -> void:
	run = r
	quick = q


func check(ok: bool, what: String) -> void:
	run.check(ok, what)


func all() -> void:
	print("== 땅 겉흙 · 계절 · 폭포 (A12 · A13 · A18)")
	run.timed(self, ["test_ground_types", "test_seasons", "test_waterfall_flux", "test_paths_and_distance", "test_world_terrain"])


## 표본 칸 (보통 땅에서 하나씩만 바꿈) → 보이는 겉흙
func _type(o: Dictionary, sp: Dictionary) -> int:
	var w := GroundLook.cell_weights(float(o.get("depth", 0.0)), bool(o.get("lake", false)), bool(o.get("river", false)),
		float(o.get("near", 99.0)), float(o.get("wet", 0.35)), float(o.get("sun", 0.0)), float(o.get("slope", 0.05)),
		float(o.get("height", 0.3)), float(o.get("forest", 0.0)), float(o.get("plot", 0.0)), float(o.get("rocky", 0.0)), float(o.get("pool", 0.0)))
	return GroundLook.type_at(w[0], w[1], float(o.get("path", 0.0)), bool(o.get("stone", false)), bool(o.get("salt", false)),
		bool(o.get("lake", false)) or bool(o.get("river", false)), sp)


func test_ground_types() -> void:
	var spring := GroundLook.season_params(4, 15, "온대", 12.0)
	var summer := GroundLook.season_params(7, 15, "온대", 12.0)
	var cases := [
		[{}, spring, GroundLook.GRASS, "보통 땅 = 풀밭"],
		[{"lake": true, "depth": 0.1}, spring, GroundLook.WATER, "호수 = 물 (땅 겉흙 없음)"],
		[{"near": 1.0}, spring, GroundLook.SHORE, "호숫가 1칸 = 모래·자갈"],
		[{"near": 1.0, "slope": 0.9}, spring, GroundLook.ROCK, "가파른 물가 = 바위 (모래 아님)"],
		[{"depth": 0.006}, spring, GroundLook.MUD, "얕게 고인 물(강이 스며드는 끝) = 진흙·습지"],
		[{"wet": 0.97, "slope": 0.02}, spring, GroundLook.MUD, "아주 젖은 낮은 땅 = 진흙"],
		[{"forest": 0.8}, spring, GroundLook.FOREST, "숲 = 숲 바닥"],
		[{"forest": 0.15}, spring, GroundLook.GRASS, "숲 가장자리 옅은 곳은 풀밭"],
		[{"sun": -0.8, "wet": 0.8}, spring, GroundLook.MOSS, "그늘 + 습함 = 이끼"],
		[{"sun": -0.8, "wet": 0.2}, spring, GroundLook.GRASS, "그늘이어도 마르면 이끼 아님"],
		[{"sun": 0.8, "wet": 0.05}, summer, GroundLook.DRY, "볕 드는 마른 쪽 여름 = 마른 풀"],
		[{"sun": 0.8, "wet": 0.05}, spring, GroundLook.GRASS, "같은 자리 봄 = 풀밭 (계절 문턱)"],
		[{"slope": 0.9}, spring, GroundLook.ROCK, "가파른 비탈 = 바위"],
		[{"height": 0.8}, spring, GroundLook.ROCK, "높은 등성이 = 바위"],
		[{"rocky": 1.0}, spring, GroundLook.ROCK, "바위 더미 곁 = 바위"],
		[{"plot": 1.0}, spring, GroundLook.SOIL, "밭·집터 = 맨흙"],
		[{"path": 0.8}, spring, GroundLook.PATH, "오솔길 = 흙길"],
		[{"path": 0.97, "stone": true}, spring, GroundLook.STONE_PATH, "돌길 마을의 큰길(아주 많이 밟음) = 돌길"],
		[{"path": 0.8, "stone": true}, spring, GroundLook.PATH, "돌길 마을이어도 덜 밟은 오솔길은 흙길"],
		[{"path": 0.8, "forest": 0.9}, spring, GroundLook.PATH, "숲 속 길도 길"],
		[{"salt": true}, spring, GroundLook.SALT, "마른 호수 바닥 소금 = 소금 들판"],
		[{"pool": 1.0}, spring, GroundLook.MOSS, "폭포 웅덩이 곁 = 이끼 (젖은 땅)"],
		[{}, GroundLook.season_params(1, 15, "냉대", 12.0), GroundLook.SNOW, "냉대 1월 = 눈"],
		[{}, GroundLook.season_params(1, 15, "온대", 12.0), GroundLook.GRASS, "온대 1월 = 눈 없음 (서리만)"],
		[{}, GroundLook.season_params(7, 15, "사막", 12.0), GroundLook.SAND, "사막 병 = 모래땅"],
	]
	var bad: Array = []
	for c: Array in cases:
		var got := _type(c[0], c[1])
		if got != int(c[2]):
			bad.append("%s: %s (기대 %s)" % [c[3], GroundLook.NAMES[got], GroundLook.NAMES[c[2]]])
	check(bad.is_empty(), "겉흙 표본 %d칸이 기대대로 %s" % [cases.size(), "" if bad.is_empty() else str(bad)])
	# 12종이 모두 나올 수 있다 (풀·마른 풀·이끼·숲 바닥·맨흙·흙길·돌길·모래·진흙·바위·소금·눈·모래땅)
	var seen := {}
	for c: Array in cases:
		seen[int(c[2])] = true
	check(seen.size() >= 13, "겉흙 종류 %d가지가 표본에 나옴 (물 포함, 기획서 12종 + 돌길)" % seen.size())
	# 덮개 모델: 종류마다 맞는 무리 (해시라 늘 같음)
	var ok := true
	var hits := 0
	for i in 400:
		var nm := GroundLook.cover_pick(GroundLook.SHORE, i, 7)
		if nm != "":
			hits += 1
			ok = ok and nm.begins_with("gc_shore")
		ok = ok and GroundLook.cover_pick(GroundLook.GRASS, i, 7) == ""
	check(ok and hits > 20 and hits < 120, "물가에만 모래·자갈 덮개 (400칸에 %d개 — 듬성듬성), 풀밭엔 없음" % hits)
	check(GroundLook.cover_pick(GroundLook.SHORE, 12, 34) == GroundLook.cover_pick(GroundLook.SHORE, 12, 34), "덮개 자리는 늘 같음 (해시)")


func test_seasons() -> void:
	var apr := GroundLook.season_params(4, 15, "온대", 12.0)
	var jul := GroundLook.season_params(7, 15, "온대", 12.0)
	var octo := GroundLook.season_params(10, 15, "온대", 12.0)
	var jan8 := GroundLook.season_params(1, 15, "온대", 8.0)
	var jan13 := GroundLook.season_params(1, 15, "온대", 13.0)
	check(float(apr["flowers"]) > 0.5 and float(jul["flowers"]) < 0.3 and float(octo["flowers"]) == 0.0, "봄 민들레 (4월 %.2f · 7월 %.2f · 10월 %.2f)" % [apr["flowers"], jul["flowers"], octo["flowers"]])
	check(float(octo["leaves"]) > 0.7 and float(apr["leaves"]) == 0.0, "가을 붉은 낙엽 (10월 %.2f)" % octo["leaves"])
	check(float(jul["dry_thr"]) < float(apr["dry_thr"]) - 0.2, "여름엔 마른 풀이 넓다 (문턱 7월 %.2f < 4월 %.2f)" % [jul["dry_thr"], apr["dry_thr"]])
	check(float(jan8["frost"]) > 0.4 and float(jan13["frost"]) == 0.0, "온대 겨울 아침 서리 (8시 %.2f), 한낮엔 녹음 (13시 %.2f)" % [jan8["frost"], jan13["frost"]])
	check(float(jan8["snow"]) == 0.0 and float(GroundLook.season_params(1, 15, "냉대", 12.0)["snow"]) > 0.8 and float(GroundLook.season_params(7, 15, "냉대", 12.0)["snow"]) == 0.0,
		"눈은 냉대 겨울에만")
	check(float(GroundLook.season_params(1, 15, "열대", 8.0)["frost"]) == 0.0, "열대는 서리 없음")
	# 달 사이는 부드럽게 (4월 30일 ~ 5월 1일)
	var a := GroundLook.season_params(4, 30, "온대", 12.0)
	var b := GroundLook.season_params(5, 1, "온대", 12.0)
	check(absf(float(a["flowers"]) - float(b["flowers"])) < 0.05 and (a["grass"] as Color).is_equal_approx(b["grass"]) == false and
		absf((a["grass"] as Color).g - (b["grass"] as Color).g) < 0.01, "달이 바뀌어도 색이 튀지 않음")
	# 병 날짜 덮어쓰기 (캡처용)
	GroundLook.month_override = 10
	var o := GroundLook.season_now(null)
	GroundLook.month_override = 0
	check(String(o["season"]) == "가을", "날짜 덮어쓰기 = 10월 가을")
	# 재질에 넣기
	var m := Toon.terrain_mat()
	GroundLook.apply_season(m, jul)
	var tint: Vector3 = m.get_shader_parameter("season_tint")
	check(tint.y > 0.0 and absf(float(m.get_shader_parameter("dry_thr")) - float(jul["dry_thr"])) < 1e-4, "계절 값이 땅 재질에 들어감 (풀 색 비 %s)" % str(tint))


func test_waterfall_flux() -> void:
	var b := WorldWater.GROOVE_BASE
	var shade := Waterfalls.flux_norm(-1.0, 1.0, b)
	var sunny := Waterfalls.flux_norm(1.0, 1.0, b)
	var spot := Waterfalls.flux_norm(-0.3, WorldWater.GROOVE_SPOT, b)
	check(shade > sunny * 3.0, "그늘 골의 물 (%.2f) > 볕 드는 골 (%.2f)" % [shade, sunny])
	check(Waterfalls.width_for(shade) > Waterfalls.width_for(sunny) + 0.4, "그늘 골 폭포가 굵다 (%.2f칸 vs %.2f칸)" % [Waterfalls.width_for(shade), Waterfalls.width_for(sunny)])
	check(Waterfalls.width_for(spot) <= 3.2 and Waterfalls.width_for(spot) > Waterfalls.width_for(shade), "강의 근원(골 배율 12)은 가장 굵되 3.2칸 이하 (%.2f칸)" % Waterfalls.width_for(spot))
	var mono := true
	var prev := -1.0
	for i in 41:
		var w := Waterfalls.width_for(i * 0.4)
		mono = mono and w >= prev
		prev = w
	check(mono, "물이 많을수록 굵다 (단조)")
	check(Waterfalls.width_for(Waterfalls.flux_norm(1.0, 1.0, 0.0)) == 0.0 and Waterfalls.width_for(Waterfalls.flux_norm(-1.0, 1.0, 0.0)) > 0.9,
		"소형 병: 볕 드는 골은 폭포 없음, 그늘 골은 있음 (시뮬레이션의 물줄기와 같음)")
	check(Waterfalls.opacity_for(shade) > Waterfalls.opacity_for(sunny), "굵은 폭포가 더 진함")
	# 시뮬레이션이 골에 넣는 물과 같은 비율 (WorldWater._groove_rate)
	var ww := WorldWater.new()
	ww.setup(256)
	var k1 := ww.idx(-120.0, 0.0)
	var k2 := ww.idx(120.0, 0.0)
	var r_sim := ww._groove_rate(k1) / ww._groove_rate(k2)
	var r_view := Waterfalls.flux_norm(ww.sun_at(ww.cx(k1), ww.cy(k1)), 1.0, b) / Waterfalls.flux_norm(ww.sun_at(ww.cx(k2), ww.cy(k2)), 1.0, b)
	check(absf(r_sim - r_view) < 1e-3, "폭포 굵기 비 = 시뮬레이션 골 물 비 (%.3f = %.3f)" % [r_sim, r_view])
	# 등불을 옮기면(병 돌리기) 볕 드는 쪽이 바뀌어 굵기가 바뀐다
	var before := Waterfalls.flux_norm(ww.sun_at(ww.cx(k1), ww.cy(k1)), 1.0, b)
	ww.rotate_jar()
	ww.rotate_jar()
	var after := Waterfalls.flux_norm(ww.sun_at(ww.cx(k1), ww.cy(k1)), 1.0, b)
	check(absf(before - after) > 0.2, "등불을 반 바퀴 옮기면 같은 골의 물 양이 바뀜 (%.2f → %.2f)" % [before, after])
	# 멀리 축소: 화면 폭 하한
	var w := Waterfalls.width_for(sunny)
	check(Waterfalls.shown_width(w, 16.0) == w and Waterfalls.shown_width(w, 3.0) * 3.0 >= 2.6 - 1e-4 and Waterfalls.shown_width(w, 0.42) * 0.42 >= 2.0 - 1e-4,
		"가까이선 실제 폭, 반쯤 축소 2 px 이상, 세상 전체 1 px 이상")
	check(Waterfalls.shown_width(0.0, 0.42) == 0.0, "물 없는 골은 멀리서도 안 보임")


func test_paths_and_distance() -> void:
	check(absf(GroundLook.path_value(GroundLook.PATH_LO + GroundLook.PATH_SPAN * 0.5) - 0.5) < 1e-4 and GroundLook.path_value(0.0) == 0.0 and GroundLook.path_value(60.0) == 1.0,
		"오솔길 값 0~1 (발길 %.0f부터 길)" % (GroundLook.PATH_LO + GroundLook.PATH_SPAN * 0.5))
	var paths := PackedFloat32Array()
	paths.resize(16)
	paths[5] = 5.0
	paths[6] = 60.0
	var img := GroundLook.path_image(paths, 4, 1.0)
	var img4 := GroundLook.path_image(paths, 4, 4.0)
	check(img.get_size() == Vector2i(4, 4) and img.get_pixel(0, 0).r == 0.0 and absf(img.get_pixel(1, 1).r - 0.5) < 0.01 and img.get_pixel(2, 1).r == 1.0,
		"오솔길 지도 → 텍스처 값 (격자 (1,1) = %.2f)" % img.get_pixel(1, 1).r)
	check(img4.get_pixel(1, 1).r > 0.7 and img4.get_pixel(1, 1).r < GroundLook.STONE_V, "넓은 세상: 칸마다 발길 합 (×4) — 발길 20은 흙길 (%.2f)" % img4.get_pixel(1, 1).r)
	check(GroundLook.path_value(8.0) < 0.62 and GroundLook.path_value(20.0) < GroundLook.STONE_V and GroundLook.path_value(50.0) > GroundLook.STONE_V,
		"0.5 위는 로그 눈금 — 큰길(발길 50)만 돌길 문턱을 넘음")
	var sv := Village.new_prototype(5)
	sv.era = 1
	var no_plaza := GroundLook.stone_roads(sv)
	var pz := sv.add_building("광장", sv.center.x + 6.0, sv.center.y + 6.0, true)
	var with_plaza := GroundLook.stone_roads(sv)
	sv.buildings.erase(pz)
	sv.era = 0
	var pioneer := GroundLook.stone_roads(sv)
	sv.era = 2
	check(not no_plaza and with_plaza and not pioneer and GroundLook.stone_roads(sv),
		"돌길: 개척기·갓 마을은 흙길, 광장이 선 마을 · 읍내부터 돌길")
	var src := PackedByteArray()
	src.resize(25)
	src[12] = 1
	var d := JarTerrain.chamfer(src, 5, 5)
	check(d[12] == 0.0 and absf(d[13] - 1.0) < 1e-4 and absf(d[18] - 1.4142) < 1e-3 and absf(d[14] - 2.0) < 1e-4 and absf(d[0] - 2.8284) < 1e-3,
		"물에서의 거리 (모따기 거리)")


## 넓은 세상 땅 화면을 실제로 만들어 본다 (작은 세상, 화면 트리 없이 _ready를 직접)
func test_world_terrain() -> void:
	var jw := JarWorld.create(7, WorldCfg.SMALL_SIZE)
	var rec := jw.recommended_kit_spots()
	var v := jw.place_kit(rec[0].x, rec[0].y, Kits.make([]))
	var wt := WorldTerrain.new(jw.water)
	wt.villages = jw.settlements
	wt.focus = v.center
	wt.view_r = 40.0
	var t0 := Time.get_ticks_usec()
	wt._ready()
	var ready_ms := (Time.get_ticks_usec() - t0) / 1000.0
	check(wt.waterfalls.items.size() == jw.water.grooves.size() and jw.water.grooves.size() > 0, "골마다 폭포 (%d곳)" % wt.waterfalls.items.size())
	var widest := 0.0
	var thin := INF
	for it: Dictionary in wt.waterfalls.items:
		widest = maxf(widest, float(it["w"]))
		thin = minf(thin, float(it["w"]))
	check(widest > thin and thin > 0.0, "넓은 세상 골은 모두 흐르고 굵기가 다름 (%.2f ~ %.2f칸)" % [thin, widest])
	check(wt._chunks.size() > 0 and int(wt.stats["built"]) > 0, "마을 둘레 조각을 만듦 (%d개, 평균 %.2f ms, 가장 긴 조각 %.2f ms · 처음 %.0f ms)" % [
		wt._chunks.size(), float(wt.stats["ms"]) / maxf(1, int(wt.stats["built"])), float(wt.stats["max_ms"]), ready_ms])
	check(wt.cover.count > 0, "가까운 조각에 땅 덮개 (%d개)" % wt.cover.count)
	# 조각 메시에 겉흙 무게가 들어 있다
	var types := {}
	for ch: int in wt._chunks:
		var mi: MeshInstance3D = wt._chunks[ch]["t"]
		if mi.mesh == null:
			continue
		var arr := (mi.mesh as ArrayMesh).surface_get_arrays(0)
		var c0: PackedFloat32Array = arr[Mesh.ARRAY_CUSTOM0]
		for i in range(0, c0.size(), 4):
			for j in 4:
				if c0[i + j] > 0.5:
					types[j] = true
	check(types.size() >= 2, "조각 꼭짓점에 겉흙 무게 (물가·진흙·숲 바닥·이끼 중 %d가지)" % types.size())
	_water_checks(wt)
	# 한 조각을 화면 예산으로 나눠 만들기 — 어떤 한 번도 예산을 크게 넘지 않음
	var job := wt._region_job(0, 0, WorldTerrain.RC, 1, MeshInstance3D.new(), MeshInstance3D.new(), true)
	var steps := 0
	var worst := 0.0
	var each: Array = []
	var ci := floori((v.center.x + jw.water.rr) / WorldTerrain.RC)
	var cj := floori((v.center.y + jw.water.rr) / WorldTerrain.RC)
	job = wt._region_job(ci * WorldTerrain.RC, cj * WorldTerrain.RC, WorldTerrain.RC, 1, MeshInstance3D.new(), MeshInstance3D.new(), true)
	while true:
		var s0 := Time.get_ticks_usec()
		var done := wt._run_job(job, s0 + 1000)
		each.append((Time.get_ticks_usec() - s0) / 1000.0)
		worst = maxf(worst, float(each[-1]))
		steps += 1
		if done:
			break
	# 벽시계 시간이라 다른 일이 기기를 쓰면 한 번쯤 튄다 (흔들리는 시험) — 한 번의 최대 대신 90번째 백분위를 본다 (최대는 출력만)
	check(steps > 3 and run.pctl(each, 0.9) < 6.0, "조각 하나를 %d번에 나눠 만듦 (1 ms 예산, 90%% %.2f ms · 최대 %.2f ms, 합 %.1f ms)" % [steps, run.pctl(each, 0.9), worst, float(job["ms"])])
	# 세상 전체 지도 (키트 자리 고르기)
	wt.view_r = 600.0
	t0 = Time.get_ticks_usec()
	wt.update_now()
	check(wt.whole_mode and wt._map_h != null and wt._map_w != null and wt._fmap_tex != null, "세상 전체: 높이·물·숲 지도 텍스처 (%.0f ms)" % ((Time.get_ticks_usec() - t0) / 1000.0))
	var fw := jw.water.n / WorldTerrain.FM
	var forest_px := 0
	for i in wt._fmap.size():
		if wt._fmap[i] > 110:
			forest_px += 1
	var share := float(forest_px) / (fw * fw)
	check(share > 0.03 and share < 0.6, "숲 지도에 숲이 있다 (%.0f%%)" % (share * 100.0))
	var f := jw.water.forests[0]
	var px := clampi(floori((float(f["x"]) + jw.water.rr) / WorldTerrain.FM), 0, fw - 1)
	var py := clampi(floori((float(f["y"]) + jw.water.rr) / WorldTerrain.FM), 0, fw - 1)
	check(wt._fmap[py * fw + px] > 150, "세상 숲 무리 한가운데는 짙은 숲 (%d/255)" % wt._fmap[py * fw + px])
	wt.free()


## (물 다듬기) 수면 — 한 자리에 물이 한 겹 · 조각 경계에서 수면이 이어짐 · 물가가 칸 사이 같은 자리가 아니라 땅 높이선을 따라 · 화면 안 조각은 LOD 1
func _water_checks(wt: WorldTerrain) -> void:
	var painted := 0
	var lod_bad := 0
	var edge := {}                       # (x, z) → 수면 y (조각 경계 꼭짓점, 삼각형이 쓰는 것만)
	var seam_n := 0
	var seam_bad := 0.0
	var ts: Array = []
	var n_water := 0
	for ch: int in wt._chunks:
		var cur: Dictionary = wt._chunks[ch]
		if wt._chunk_gap(ch) <= wt.view_r and int(cur["lod"]) != 1:
			lod_bad += 1
		var tm: MeshInstance3D = cur["t"]
		var wm: MeshInstance3D = cur["w"]
		if tm.mesh != null:
			var uv2: PackedVector2Array = (tm.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
			for u in uv2:
				if u.x > 0.05:
					painted += 1
		if wm.mesh == null or int(cur["lod"]) != 1:
			continue
		n_water += 1
		var arr := (wm.mesh as ArrayMesh).surface_get_arrays(0)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var used := {}
		for i in idx:
			used[i] = true
		var x0 := -wt.ww.rr + (ch % wt.nrc) * WorldTerrain.RC
		var z0 := -wt.ww.rr + (ch / wt.nrc) * WorldTerrain.RC
		for i: int in used:
			var p := vs[i]
			if absf(p.x - x0) < 0.01 or absf(p.x - x0 - WorldTerrain.RC) < 0.01 or absf(p.z - z0) < 0.01 or absf(p.z - z0 - WorldTerrain.RC) < 0.01:
				var key := Vector2i(roundi(p.x * 4.0), roundi(p.z * 4.0))
				if edge.has(key):
					seam_n += 1
					seam_bad = maxf(seam_bad, absf(float(edge[key]) - p.y))
				else:
					edge[key] = p.y
		# 물가가 지나는 삼각형 변: 수면−땅이 양수·음수로 갈리는 자리 t (0~1)
		for t in range(0, idx.size(), 3):
			for e in 3:
				var a := uv[idx[t + e]].x
				var b := uv[idx[t + (e + 1) % 3]].x
				if (a > 0.0) != (b > 0.0):
					ts.append(a / (a - b))
	check(painted == 0, "강은 땅에 칠하지 않고 수면 메시로만 (땅 칠 꼭짓점 %d개 — 한 자리에 물 한 겹)" % painted)
	check(lod_bad == 0, "화면 반지름 안에 걸친 조각은 모두 LOD 1 (거친 조각 %d개)" % lod_bad)
	check(n_water > 0 and seam_n > 0 and seam_bad < 0.001, "이웃 조각 경계에서 수면 높이가 같음 (꼭짓점 %d개 · 가장 큰 차 %.4f)" % [seam_n, seam_bad])
	var lo := 0
	var mid := 0
	for t: float in ts:
		if t < 0.25:
			lo += 1
		elif t < 0.75:
			mid += 1
	var hi := ts.size() - lo - mid
	check(ts.size() > 20 and lo > ts.size() / 10 and mid > ts.size() / 10 and hi > ts.size() / 10,
		"물가가 칸 안 여러 자리를 지남 (땅 높이선 — 물가 변 %d개: 앞 %d · 가운데 %d · 뒤 %d)" % [ts.size(), lo, mid, hi])
