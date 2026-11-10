## 보이는 살림 캡처 (Q6 — view/bld2d/bld_econ.gd). 창이 필요:  godot --path godot -s res://tools/shot_site_piles.gd -- after
## -> godot_shots/site_piles/<tag>_site_<n>_ppu44.png · _ppu20.png   짓는 터 한 곳의 진행 (빈 터 → 자재 도착 → 뼈대 → 벽 → 지붕 → 다 지음)
##    <tag>_<일터>_<n>_ppu44.png · _ppu20.png                        일터 앞 더미 (빈 것 → 가득) · 일하는 중 / 쉬는 중
##    <tag>_stall_<n>_ppu44.png · _ppu20.png                         막힌 일터 (재료 없음 · 일꾼 없음 · 앞이 가득)
##    <tag>_wide_ppu20.png · <tag>_wide_ppu44.png                    마을 한 장 (여러 곳이 한꺼번에)
## 인자: -- before | after | off (파일 이름 머리말) [site | work | stall | wide | draws]  (하나만 · 'draws'는 그리기 횟수만 재고 끝)
##   off = 보이는 살림(BldEcon)을 끄고 (그리기 횟수 견줌)
## 시뮬레이션은 멈춘 채(paused) 건물 값만 바꿔 찍는다 — 화면이 값을 그대로 읽는지 보는 용도.
## '일하는 중'은 일터 시계(b.timer)를 화면마다 조금씩 밀어 흉내 낸다 (BldEcon은 시계가 움직이는 일터만 돌아가는 것으로 본다).
extends SceneTree

const PHYS := Vector2i(1080, 1920)
const LOGICAL := Vector2i(360, 640)
const WORK := ["맷돌간", "화덕", "나무꾼", "제재소", "채석장", "우물", "농장"]

var out_dir := ""
var tag := "after"
var draws_only := false
var only := ""
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var scene: Node
var vp: SubViewport
var v: Village
var site: Building
var site2: Building
var blds := {}            # 종류 → Building
var working := {}         # Building → true (일하는 중 흉내 — 화면마다 timer를 민다)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	only = args[1] if args.size() > 1 else ""
	draws_only = only == "draws"
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/site_piles").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Bld2D.override = 1
	Flora2D.override = 1
	CutoutResident.override = 1
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
	plan.append(_setup)
	plan.append(_build)
	if draws_only:
		for ppu: float in [16.0, 20.0, 32.0, 44.0]:
			plan.append_array([_aim.bind(Vector2.INF, ppu), _draws.bind(ppu)])
	else:
		_plan_shots()
	plan.append(func() -> int:
		quit()
		return 1)


func _plan_shots() -> void:
	# 짓는 터: [진행 몫, 판자, 돌]
	var st := [[0.0, 0, 0], [0.0, 2, 0], [0.0, 8, 4], [0.14, 8, 4], [0.30, 8, 4], [0.55, 8, 4], [0.80, 8, 4], [0.97, 8, 4], [1.0, 8, 4], [1.0, 8, 4]]
	for i in (st.size() if only in ["", "site"] else 0):
		plan.append(_set_site.bind(st[i]))
		for ppu: float in [44.0, 20.0]:
			plan.append_array([_aim_b.bind("site", ppu), _save.bind("site_%d_ppu%d" % [i, int(ppu)], ppu)])
	plan.append(_set_site.bind([0.45, 4, 1]))
	# 일터 더미: 빈 것 → 가득 (0, 1/3, 2/3, 1) · 마지막 두 장은 일하는 중
	for ty: String in (["맷돌간", "화덕", "나무꾼", "제재소", "채석장", "우물", "농장", "창고"] if only in ["", "work"] else []):
		for i in 4:
			plan.append(_set_work.bind(ty, float(i) / 3.0, i >= 1))
			for ppu: float in [44.0, 20.0]:
				plan.append_array([_aim_b.bind(ty, ppu), _save.bind("%s_%d_ppu%d" % [_ascii(ty), i, int(ppu)], ppu)])
	# 집: 땔감 더미 · 불 땐 집 연기
	for i in (3 if only in ["", "work"] else 0):
		plan.append(_set_house.bind(i))
		for ppu: float in [44.0, 20.0]:
			plan.append_array([_aim_b.bind("house", ppu), _save.bind("house_%d_ppu%d" % [i, int(ppu)], ppu)])
	# 막힘
	var stalls := [["맷돌간", &"no_input"], ["화덕", &"no_worker"], ["우물", &"full"], ["제재소", &"no_input"]]
	if only in ["", "stall"]:
		plan.append(_set_stalls.bind(stalls))
	for i in (stalls.size() if only in ["", "stall"] else 0):
		for ppu: float in [44.0, 20.0]:
			plan.append_array([_aim_b.bind(stalls[i][0], ppu), _save.bind("stall_%d_ppu%d" % [i, int(ppu)], ppu)])
	# 마을 한 장
	if only in ["", "wide"]:
		plan.append(_set_wide)
	for ppu: float in ([20.0, 44.0] if only in ["", "wide"] else []):
		plan.append_array([_aim.bind(Vector2.INF, ppu), _save.bind("wide_ppu%d" % int(ppu), 0.0)])
	for ppu: float in ([20.0, 32.0] if only in ["", "wide"] else []):      # 새로 놓은 일터·짓는 터 쪽
		plan.append_array([_aim_b.bind("site", ppu), _save.bind("wide2_ppu%d" % int(ppu), 0.0)])


func _ascii(ty: String) -> String:
	return {"맷돌간": "quern", "화덕": "oven", "나무꾼": "lumber", "제재소": "sawmill", "채석장": "quarry", "우물": "well",
		"농장": "farm", "창고": "store"}.get(ty, "bld")


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 6:
		return false
	for b: Building in working:
		b.timer += 0.01
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	if scene != null and scene.get("first_popup") != null:
		(scene.get("first_popup") as Node).queue_free()
		scene.set("first_popup", null)
	var w: Variant = plan[step].call()
	step += 1
	_wait = int(w) if w != null else 4
	return false


func _setup() -> int:
	vp = SubViewport.new()
	vp.size = PHYS
	vp.size_2d_override = LOGICAL
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261107
	vp.add_child(scene)
	return 20


func _build() -> int:
	scene.paused = true
	v = scene.village
	var left := 4.0 * 86400.0 + 3.0 * 3600.0
	while left > 0.0:
		var d := minf(1800.0, left)
		v.advance(d)
		left -= d
	for b in v.buildings:
		if b.built and not blds.has(b.type):
			blds[b.type] = b
	for ty: String in WORK:      # 일터는 앞(카메라 쪽)이 트인 자리에 하나씩 새로 (마을 것은 큰 꽃·밀밭 그림에 가려 더미를 볼 수 없다)
		if ty == "농장":
			if blds.has(ty):
				continue
			var sp: Variant = v.find_spot(ty)
			if sp == null:
				print("no spot ", ty)
				continue
			blds[ty] = v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
			continue
		var p := _clear_spot(float(Balance.B[ty]["size"]) + 1.2)
		if p == Vector2.INF:
			print("no clear spot ", ty)
			continue
		var b := v.add_building(ty, p.x, p.y, true)
		b.built_t = v.t
		blds[ty] = b
	for b in v.buildings:
		if b.is_store and b.built:
			blds["창고"] = b
		if not b.built and b.type == "오두막" and site2 == null:
			site2 = b
	# 짓는 터는 앞(카메라 쪽)이 트인 빈 자리에 — 앞 건물·밀밭 그림에 가리면 더미·말뚝을 볼 수 없다
	var sp2 := _clear_spot(2.4)
	site = v.add_building("목조주택", sp2.x, sp2.y, false)
	blds["site"] = site
	var hp := _clear_spot(2.6)
	if hp != Vector2.INF:
		blds["house"] = v.add_building("오두막", hp.x, hp.y, true)
	scene.refresh()
	scene.set_debug_mode(false)
	if tag == "off" and scene.view.get("econ") != null:
		scene.view.econ.on = false
	for b in v.buildings:
		print("bld ", b.id, " ", b.type, " ", Vector2(b.x, b.y), " built=", b.built, " size=", b.size())
	return 10


## 앞(카메라 쪽)이 가장 트인 빈 자리 (마을 둘레를 나선으로 훑음)
func _clear_spot(size: float) -> Vector2:
	var f2 := Vector2(sin(deg_to_rad(JarCamera.BASE_YAW_DEG)), cos(deg_to_rad(JarCamera.BASE_YAW_DEG)))
	var best := 0.0
	var at := Vector2.INF
	for i in 500:
		var a := float(i) * 2.399963
		var p := v.center + Vector2(cos(a), sin(a)) * (5.0 + 0.03 * i)
		if not v.is_free(p.x, p.y, size):
			continue
		var clear := 99.0
		for b in v.buildings:
			var d := Vector2(b.x, b.y) - p
			clear = minf(clear, d.length() if d.dot(f2) > -1.5 else d.length() * 3.0)
		for t in v.trees:
			var d := Vector2(t.x, t.y) - p
			if d.dot(f2) > 0.0:
				clear = minf(clear, d.length() * 1.5)
		for t in v.rocks:
			var d := Vector2(t.x, t.y) - p
			clear = minf(clear, d.length() * 1.5)
		if clear > best:
			best = clear
			at = p
	print("clear spot ", at, " clear=", best)
	return at


func _set_site(s: Array) -> int:
	var tm := float(Balance.B[site.site_type()]["time"])
	site.delivered["판자"] = mini(int(s[1]), site.need("판자"))
	site.delivered["돌"] = mini(int(s[2]), site.need("돌"))
	var was_built := site.built
	if float(s[0]) >= 1.0:
		site.prog = tm
		site.built = true
		site.built_t = v.t
	else:
		site.built = false
		site.prog = tm * float(s[0])
	scene.refresh()
	if float(s[0]) >= 1.0:
		return 110 if was_built else 1          # 다 지은 순간: 바로 = '퐁' 도중 · 한 번 더 = 가라앉은 뒤
	return 20


## 일터 하나의 앞 더미를 f(0~1)만큼 채움. on = 일꾼이 있고 재료가 들어와 일하는 중
func _set_work(ty: String, f: float, on: bool) -> int:
	var b: Building = blds.get(ty)
	if b == null:
		return 1
	v._stall.erase(b.id)
	var d := b.def()
	if b.is_store:
		for k: String in ["통나무", "판자", "돌", "밀", "밀가루", "빵"]:
			v.stock[k] = roundf(f * float({"통나무": 24, "판자": 16, "돌": 12, "밀": 400, "밀가루": 300, "빵": 300}[k]))
		scene.refresh()
		return 20
	for k: String in d.get("in", {}):
		b.in_buf[k] = roundf(f * Production.in_cap(k))
	for k: String in d.get("out", {}):
		b.out[k] = roundf(f * BldEcon.out_full(k))
	if on:
		var adults := v.people.filter(func(r: Resident) -> bool: return r.is_adult())
		b.worker = (adults[b.id % adults.size()] as Resident).id
		working[b] = true
	else:
		b.worker = -1
		working.erase(b)
	scene.refresh()
	return 90 if on else 20       # 일하는 중: 연기·움직임이 한 바퀴 돈 뒤


## 집 한 채: 0 = 땔감 없음 · 1 = 땔감 조금 + 불 · 2 = 땔감 가득 + 불
func _set_house(i: int) -> int:
	var b: Building = blds.get("house")
	if b == null:
		return 1
	b.in_buf["통나무"] = [0.0, 2.0, Balance.FUEL_TARGET][i]
	b.fuel_on = i > 0
	scene.refresh()
	return 90


func _set_stalls(list: Array) -> int:
	for e: Array in list:
		var b: Building = blds.get(e[0])
		if b == null:
			continue
		var d := b.def()
		var adults := v.people.filter(func(r: Resident) -> bool: return r.is_adult())
		b.worker = (adults[b.id % adults.size()] as Resident).id
		for k: String in d.get("in", {}):
			b.in_buf[k] = Production.in_cap(k)
		for k: String in d.get("out", {}):
			b.out[k] = 0.0
		var why: StringName = e[1]
		working.erase(b)
		if why == &"no_input":
			for k: String in d.get("in", {}):
				b.in_buf[k] = 0.0
			v._stall[b.id] = {"why": &"no_input", "since": v.t - 7200.0, "stalled": true, "at": v.t - 3600.0, "ok": -1.0}
		elif why == &"no_worker":
			b.worker = -1
			v._stall[b.id] = {"why": &"no_worker", "since": v.t - 7200.0, "stalled": true, "at": v.t - 3600.0, "ok": -1.0}
		else:
			for k: String in d.get("out", {}):
				b.out[k] = BldEcon.out_full(k) * BldEcon.OVERFLOW
	scene.refresh()
	return 150         # 말풍선은 조금 뒤에 뜬다


func _set_wide() -> int:
	v._stall.clear()
	var i := 0
	for ty: String in WORK:
		_set_work(ty, [1.0, 0.34, 0.67, 1.0, 0.34, 0.67, 1.0][i % 7], i % 3 != 2)
		i += 1
	_set_work("창고", 0.67, false)
	_set_stalls([["화덕", &"no_input"]])
	site.built = false
	_set_site([0.45, 4, 1])
	if site2 != null:
		site2.delivered["판자"] = 1
	scene.refresh()
	return 150


func _aim_b(ty: String, ppu: float) -> int:
	var b: Building = blds.get(ty)
	if b == null:
		return 1
	return _aim(Vector2(b.x, b.y), ppu)


func _aim(c: Vector2, ppu: float) -> int:
	scene.paused = true
	if c == Vector2.INF:
		c = v.center
	scene.look_at_ground(c)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(ppu)
	scene.far_outline_check()
	var cc: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(cc.x, cc.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)
	return 14


## 가운데를 잘라 저장 (ppu > 0: 건물 둘레 약 7칸 · 0: 화면 전체를 반으로 줄여)
func _save(name: String, ppu: float) -> int:
	var img := vp.get_texture().get_image()
	if ppu > 0.0:
		var px := int(7.0 * ppu * 3.0) if ppu > 30.0 else int(8.0 * ppu * 3.0)
		px = mini(px, img.get_width())
		var r := Rect2i((img.get_width() - px) / 2, (img.get_height() - px) / 2 - int(px * 0.08), px, px)
		img = img.get_region(r)
		if ppu > 30.0:
			img.resize(img.get_width() * 2 / 3, img.get_height() * 2 / 3, Image.INTERPOLATE_LANCZOS)
	else:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	var path := out_dir.path_join("%s_%s.png" % [tag, name])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
	return 1


func _draws(ppu: float) -> int:
	print("DRAWS ppu=%d draw_calls=%d prims=%d objects=%d" % [int(ppu),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))])
	return 1
