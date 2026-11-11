## 밀밭 캡처 (Q8 — GAME_DESIGN 104행: 싹 → 푸른 밀 → 금빛 밀 숲). 창이 필요:  godot --path godot -s res://tools/shot_wheat_field.gd -- w1
## -> godot_shots/wheat/<tag>_<sprout|green|ripe>_ppu44.png · _ppu20.png   밭 한 곳 (오두막·방앗간 곁, 밭 안에 일꾼 둘 + 밭 앞에 한 사람, 낮)
##    <tag>_ripe_yaw1_ppu44.png · _ppu20.png · _yaw2_...                    카메라를 한 걸음 · 두 걸음 돌려서 (줄이 화면을 따라 도는지)
##    <tag>_ripe_wide_ppu20.png                                             먼 확대 화면 전체 ('노란 밭'으로 읽히는지)
##    <tag>_ripe_sway_a.png · _b.png                                        바람 (조금 뒤 두 장 — 이삭이 움직였는지)
##    <tag>_ripe_<scarecrow|flowers>_ppu44.png · _ppu20.png                 밭 꾸밈 그림 두 가지 (VillageView.wheat_accent — 기본은 없음)
##    <tag>_ripe_bubble_ppu44.png                                           볏단이 넘칠 때 밭 위 생각 풍선 + 가득 찬 볏단 더미
##    (grave)   <tag>_grave_ppu44.png · _ppu16.png · <tag>_grave_near_ppu44.png · _ppu16.png   밭 뒤(1.2칸 · 바로 뒤)의 무덤 — 그 앞의 밀 줄만 낮춰 그림
##    (compare) <tag>_cmp_ppu44.png · _ppu20.png                                  익은 밭 + 앞 울타리 앞에 선 주민 셋 (키 견줌 — 밭 안에는 아무도 없음)
##    (harvest) <tag>_harvest_1.png · _2.png · _3.png   거두기: 아침 (첫 줄) · 한낮 (절반) · 저녁 (이삭 하나를 메고 감) + <tag>_harvest_night.png (밤사이 다시 자람)
##              ※ 옛 장면: 줄은 이제 시각이 아니라 밭 곁에 쌓인 벤 밀의 몫을 따른다 (BldEcon.wheat_rows — w3의 reap 장면)
##    (carry)   <tag>_carry_a.png · _b.png   이삭 하나를 멘 사람 셋 — 오른쪽·앞·왼쪽 / 뒤·비스듬히 둘 (짐 그림 점검)
##    (w3)      2026-11-11 밀밭 손질 — <tag>_reap_half_ppu44.png · _ppu20.png   벤 밀이 반 수레: 앞 두 줄이 그루터기 + 낫 든 일꾼 둘 + 이삭 멘 사람
##              <tag>_sickle_4views.png · <tag>_ear_4views.png                    낫질 · 이삭 메기를 네 보기로 (앞 · 비스듬한 앞 · 비스듬한 뒤 · 뒤), 가장 가까운 확대
##              <tag>_piles_ppu44.png · _ppu20.png                                 밀 숲 뒤에 선 방앗간·둘째 밭의 더미가 어디에 놓이는지
##              <tag>_grave_behind_ppu44.png · _ppu20.png                          옛 저장: 밭 한가운데 바로 뒤의 무덤 → 좁은 홈
##              <tag>_grave_new_ppu44.png · _ppu20.png                             새 자리 고르기: 옛 자리가 밭 바로 뒤일 때 무덤이 놓이는 곳
##              셋째 인자로 골라 찍기: reap,tools,piles,grave,site
##    (w4)      2026-11-11 밀밭 남은 손질 ⑥⑦ — <tag>_notch_mid_ppu44.png · _ppu20.png          밭 한가운데 바로 뒤의 무덤: 홈 옆선 (이삭 무리가 들쭉날쭉 낮아짐)
##              <tag>_notch_yaw1_side_ppu44.png · _ppu20.png · _yaw2_mid_… · _yaw3_side_…    카메라를 한·두·세 걸음 돌려서, 그 보기에서 밭 뒤(가운데 · 옆으로 비킨 자리)의 무덤
##              <tag>_regrow_strip_ppu44.png · _ppu20.png   볏단을 실어 간 뒤 다시 자람: 실어 가기 전 → 0.5 · 1.2 · 2.0 · 2.8초 → 다 자람 (여섯 장을 한 장에)
##              셋째 인자로 골라 찍기: notch,regrow
## 인자: -- <tag> [all|grave|compare|harvest|carry|w3|w4] [w3·w4 장면]
## 저장: 진짜 저장·설정·연대기 그림(user://chron_pics)을 건드리지 않게 이 도구만의 폴더(SAVE_DIR)로 돌린다 (shot_milestones와 같은 식).
## 시뮬레이션은 멈춘 채(paused) 밭 값(ready_at)만 바꿔 찍는다.
extends SceneTree

const PHYS := Vector2i(1080, 1920)
const LOGICAL := Vector2i(360, 640)
const STAGES := ["sprout", "green", "ripe"]
const SAVE_DIR := "user://shot_wheat_save"       # 이 도구만의 저장 폴더 (진짜 저장을 건드리지 않게)
const REGROW_AT := [0.5, 1.2, 2.0, 2.8, 4.4]     # (w4) 다시 자람을 찍는 때 (시작한 뒤 화면 초 — BldEcon의 다시 자람 시계)

var out_dir := ""
var tag := "w1"
var mode := "all"
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var scene: Node
var vp: SubViewport
var v: Village
var farm: Building
var folk: Array[Resident] = []
var aim_at := Vector2.INF        # 카메라가 볼 자리 (INF = 밭 가운데)
var mill: Building
var farm2: Building
var _frames: Array[Image] = []   # (w4) 한 장으로 이어 붙일 그림들
var _rg_t0 := -1.0               # (w4) 다시 자람이 시작된 때 (BldEcon._regrow_t)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	if args.size() > 1:
		mode = args[1]
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/wheat").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	# 진짜 저장·설정을 건드리지 않게 (머리말 '저장')
	var sm := GameSave.get_instance()
	if sm != null:
		sm.enabled = false
		sm.dir = SAVE_DIR
	GameSettings.path = SAVE_DIR.path_join("settings.cfg")
	StoreStrip.cfg_path = SAVE_DIR.path_join("hud.cfg")
	Inquiry.id_path = SAVE_DIR.path_join("install_id.cfg")
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	Bld2D.override = 1
	Flora2D.override = 1
	CutoutResident.override = 1
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
	plan.append(_setup)
	plan.append(_build)
	if mode == "grave":
		plan.append(_stage.bind(2))
		for near: bool in [false, true]:
			plan.append(_grave.bind(near))
			for ppu: float in [44.0, 16.0]:
				plan.append_array([_aim.bind(ppu), _save.bind("grave%s_ppu%d" % ["_near" if near else "", int(ppu)], ppu)])
	elif mode == "compare":
		plan.append_array([_stage.bind(2), _front_folk, _run.bind(60)])       # 옷 갈아입는 연기가 걷힌 뒤에
		for ppu: float in [44.0, 20.0]:
			plan.append_array([_aim.bind(ppu), _save.bind("cmp_ppu%d" % int(ppu), ppu)])
	elif mode == "harvest":
		plan.append(_stage.bind(2))
		var hours := [9.3, 15.0, 18.2, 23.5]
		for i in hours.size():
			plan.append_array([_harvest.bind(float(hours[i]), i == 2), _aim.bind(44.0), _run.bind(24),
				_save.bind("harvest_%s" % ("night" if i == 3 else str(i + 1)), 44.0)])
	elif mode == "carry":
		plan.append(_stage.bind(2))
		for i in 2:
			plan.append_array([_carriers.bind(i), _aim.bind(44.0), _run.bind(24), _save.bind("carry_%s" % "ab"[i], 44.0)])
	elif mode == "w3":
		var pick: PackedStringArray = (args[2] if args.size() > 2 else "reap,tools,piles,grave,site").split(",")
		plan.append(_stage.bind(2))
		if pick.has("reap"):
			plan.append_array([_reap_half, _run.bind(70)])
			for ppu: float in [44.0, 20.0]:
				plan.append_array([_aim.bind(ppu), _run.bind(10), _save.bind("reap_half_ppu%d" % int(ppu), ppu)])
		if pick.has("tools"):
			plan.append_array([_four.bind("work"), _run.bind(70), _aim.bind(60.0), _run.bind(16), _save.bind("sickle_4views", 60.0, 4.6)])
			plan.append_array([_four.bind("carry"), _run.bind(70), _aim.bind(60.0), _run.bind(16), _save.bind("ear_4views", 60.0, 4.6)])
			plan.append(_aim_reset)
		if pick.has("piles"):
			plan.append(_piles)
			for ppu: float in [44.0, 20.0]:
				plan.append_array([_aim.bind(ppu), _save.bind("piles_ppu%d" % int(ppu), ppu)])
			plan.append(_piles_undo)
		if pick.has("grave"):
			plan.append(_grave_mid)
			for ppu: float in [44.0, 20.0]:
				plan.append_array([_aim.bind(ppu), _save.bind("grave_behind_ppu%d" % int(ppu), ppu)])
		if pick.has("site"):
			plan.append(_grave_site)
			for ppu: float in [44.0, 20.0]:
				plan.append_array([_aim.bind(ppu), _hold.bind(ppu), _save.bind("grave_new_ppu%d" % int(ppu), ppu)])
	elif mode == "w4":
		var pick: PackedStringArray = (args[2] if args.size() > 2 else "notch,regrow").split(",")
		plan.append(_stage.bind(2))
		if pick.has("notch"):
			for sc: Array in [[0, 0.0, "mid"], [1, 0.9, "yaw1_side"], [2, 0.0, "yaw2_mid"], [3, -1.2, "yaw3_side"]]:
				plan.append(_grave_at.bind(int(sc[0]), float(sc[1])))
				for ppu: float in [44.0, 20.0]:
					plan.append_array([_aim.bind(ppu), _run.bind(8), _save.bind("notch_%s_ppu%d" % [sc[2], int(ppu)], ppu)])
			plan.append(_grave_gone)
		if pick.has("regrow"):
			for ppu: float in [44.0, 20.0]:
				plan.append_array([_regrow_ready, _aim.bind(ppu), _run.bind(30), _grab.bind(ppu), _regrow_go])
				for t: float in REGROW_AT:
					plan.append_array([_regrow_until.bind(t), _grab.bind(ppu)])
				plan.append(_strip.bind("regrow_strip_ppu%d" % int(ppu)))
	if mode != "all":
		plan.append(func() -> int:
			quit()
			return 1)
		return
	for i in 3:
		plan.append(_stage.bind(i))
		for ppu: float in [44.0, 20.0]:
			plan.append_array([_aim.bind(ppu), _save.bind("%s_ppu%d" % [STAGES[i], int(ppu)], ppu)])
	plan.append_array([_aim.bind(20.0), _save.bind("ripe_wide_ppu20", 0.0)])
	plan.append_array([_aim.bind(44.0), _run.bind(40), _save.bind("ripe_sway_a", 44.0), _run.bind(50), _save.bind("ripe_sway_b", 44.0)])
	for st: int in [1, 2]:
		plan.append(_yaw.bind(st))
		for ppu: float in [44.0, 20.0]:
			plan.append_array([_aim.bind(ppu), _save.bind("ripe_yaw%d_ppu%d" % [st, int(ppu)], ppu)])
	plan.append(_yaw.bind(0))
	for ac: String in ["scarecrow", "flowers"]:
		plan.append(_accent.bind(ac))
		for ppu: float in [44.0, 20.0]:
			plan.append_array([_aim.bind(ppu), _save.bind("ripe_%s_ppu%d" % [ac, int(ppu)], ppu)])
	plan.append(_accent.bind(""))
	plan.append_array([_bubble, _aim.bind(44.0), _bubble_tick, _save.bind("ripe_bubble_ppu44", 44.0)])
	plan.append(func() -> int:
		quit()
		return 1)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 6:
		return false
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
	scene.firsts = Firsts.new()                       # 거인 묶음의 대기 줄이 아니라 이 도구만의 것
	vp.add_child(scene)
	if scene.director != null:
		scene.director.pic_dir = SAVE_DIR.path_join("chron_pics")
	return 20


func _fdir(st: int) -> Vector2:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG + 90.0 * st)
	return Vector2(sin(yaw), cos(yaw))


func _rdir(st: int) -> Vector2:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG + 90.0 * st)
	return Vector2(cos(yaw), -sin(yaw))


func _build() -> int:
	scene.paused = true
	v = scene.village
	var left := 4.0 * 86400.0 + 3.0 * 3600.0
	while left > 0.0:
		var d := minf(1800.0, left)
		v.advance(d)
		left -= d
	# 낮 (10시 반)
	var dh := fposmod(10.5 - v.hour_now(), 24.0) * 3600.0
	while dh > 0.0:
		var s := minf(600.0, dh)
		scene.world.advance(s)
		dh -= s
	var f := _fdir(0)
	var r := _rdir(0)
	var p := _clear_spot(7.0)
	farm = v.add_building("농장", p.x, p.y, true)
	farm.built_t = v.t - 86400.0
	var hp := p - r * 3.5 - f * 0.9
	var hut := v.add_building("오두막", hp.x, hp.y, true)
	hut.built_t = v.t - 86400.0
	var mp := p + r * 3.7 - f * 0.7
	mill = v.add_building("방앗간", mp.x, mp.y, true)
	mill.built_t = v.t - 86400.0
	var adults := v.people.filter(func(q: Resident) -> bool: return q.is_adult())
	# 밭 안 둘 (앞쪽 줄 · 뒤쪽 줄) + 밭 앞 한 사람 (키 견줌)
	var spots := [p + r * 0.45 + f * 0.25, p - r * 0.6 - f * 0.55, p - r * 1.3 + f * 2.2]
	for i in mini(3, adults.size()):
		var q: Resident = adults[i]
		q.steps.clear()
		q.steps.append(ResidentAI.act(1.0e6, "work" if i < 2 else "idle"))
		q.x = (spots[i] as Vector2).x
		q.y = (spots[i] as Vector2).y
		q.px = q.x
		q.py = q.y
		q.action = "work" if i < 2 else "idle"
		q.anim = q.action
		q.carry = ""
		if i < 2:
			q.job = farm.id
		folk.append(q)
	farm.worker = folk[0].id if not folk.is_empty() else -1
	scene.refresh()
	scene.set_debug_mode(false)
	print("farm ", farm.id, " at ", p, " size ", farm.size())
	return 10


## 앞(카메라 쪽)이 가장 트인 빈 자리 (shot_site_piles와 같은 훑기)
func _clear_spot(size: float) -> Vector2:
	var f2 := _fdir(0)
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
			clear = minf(clear, d.length() * 1.5)
		for t in v.rocks:
			var d := Vector2(t.x, t.y) - p
			clear = minf(clear, d.length() * 1.5)
		if clear > best:
			best = clear
			at = p
	print("clear spot ", at, " clear=", best)
	return at


func _stage(i: int) -> int:
	farm.ready_at = [v.t + Balance.GROW_FIRST * 0.9, v.t + Balance.GROW_FIRST * 0.4, v.t - 1.0][i]
	farm.out["밀"] = roundf(BldEcon.out_full("밀") * 0.67) if i == 2 else 0.0
	scene.refresh()
	scene.view.sync(0.0, true)
	return 60


func _yaw(st: int) -> int:
	scene.cam.turn(st - int(scene.cam.quarter), true)
	scene.cam._apply()
	scene.view.sync(0.0, true)
	return 30


## 밭 뒤에 무덤 하나 (near: 맨 뒷줄 바로 뒤 · 아니면 1.2칸 뒤) — 밭 안의 일꾼은 밭 앞으로 비킴
func _grave(near: bool) -> int:
	var f := _fdir(0)
	var r := _rdir(0)
	var back := float(Bld2D.info(Bld2D.wheat_cards(2)[1])["front"])       # 맨 뒷줄
	var gp := Vector2(farm.x, farm.y) + f * (back - (0.35 if near else 1.2)) + r * 0.3
	if v.graves.is_empty():
		var dead: Resident = null
		for q: Resident in v.people:
			if q.is_adult() and not folk.has(q):
				dead = q
				break
		dead.x = gp.x
		dead.y = gp.y
		v.kill(dead, "노환")
	var g: Dictionary = v.graves[0]
	g["x"] = gp.x
	g["y"] = gp.y
	_front_folk()
	scene.view._grave_key = ""          # 무덤 돌 그림은 무덤 수가 바뀔 때만 다시 놓인다 — 자리를 옮겼으니 다시
	scene.view._bld_key.erase(farm.id)
	scene.refresh()
	scene.view.sync(0.0, true)
	print("grave ", gp, " cuts ", BldEcon.grave_cuts(v, farm, 0, 2))
	return 40


## 주민 셋을 앞 울타리 앞에 나란히 세움 (키 견줌 · 밭 안에는 아무도 없게)
func _front_folk(st := 0) -> int:
	var f := _fdir(st)
	var r := _rdir(st)
	var edge := float(Bld2D.info(Bld2D.Pics.WHEAT_FENCE)["front"]) + 0.3
	for i in folk.size():
		var q := folk[i]
		var at := Vector2(farm.x, farm.y) + f * edge + r * (-0.9 + 0.75 * i)
		q.steps.clear()
		q.steps.append(ResidentAI.act(1.0e6, "idle"))
		q.x = at.x
		q.y = at.y
		q.px = q.x
		q.py = q.y
		q.action = "idle"
		q.anim = "idle"
		q.job = -1
	farm.worker = -1
	scene.refresh()
	scene.view.sync(0.0, true)
	return 20


## 거두기 (화면만): 밭은 며칠 전에 익었고 일꾼이 있다 · 시각 hour (BldEcon.wheat_rows가 앞줄부터 그루터기로).
## 일꾼 둘은 밭 한가운데서 일함 (시뮬 자리 — 화면에서는 숲 앞 가장자리에 선다) · carry: 셋째 사람이 밀을 메고 방앗간 쪽으로 걸어감
func _harvest(hour: float, carry: bool) -> int:
	var f := _fdir(0)
	var r := _rdir(0)
	farm.ready_at = v.t - 3.0 * 86400.0
	v.start_clock = fposmod(v.start_clock + (hour - v.hour_now()) * Village.HOUR, Village.DAY)
	var p := Vector2(farm.x, farm.y)
	var spots := [p + r * 0.75 + f * 0.25, p - r * 0.7 - f * 0.3, p + r * 1.5 + f * 1.9]
	for i in folk.size():
		var q := folk[i]
		var act := "work" if i < 2 else ("carry" if carry else "idle")
		q.steps.clear()
		q.steps.append(ResidentAI.act(1.0e6, act))
		q.x = (spots[i] as Vector2).x
		q.y = (spots[i] as Vector2).y
		q.px = q.x
		q.py = q.y
		q.action = act
		q.anim = act
		q.carry = "밀" if act == "carry" else ""
		q.job = farm.id if i < 2 else -1
		if act == "carry":
			q.facing = atan2(r.x, r.y)
	farm.worker = folk[0].id
	scene.view._bld_key.erase(farm.id)
	scene.refresh()
	scene.view.sync(0.0, true)
	print("harvest ", hour, " rows ", BldEcon.wheat_rows(v, farm), " fields ", scene.view.econ.fields)
	return 30


## 이삭을 멘 사람 셋을 울타리 앞에 — 걷는 쪽이 서로 다름 (which 0: 오른쪽·카메라 쪽·왼쪽 / 1: 뒤·비스듬히 뒤·비스듬히 앞)
func _carriers(which: int) -> int:
	var f := _fdir(0)
	var r := _rdir(0)
	var edge := float(Bld2D.info(Bld2D.Pics.WHEAT_FENCE)["front"]) + 0.45
	var dirs: Array = [[r, f, -r], [-f, r - f, f - r]][which]
	for i in folk.size():
		var q := folk[i]
		var at := Vector2(farm.x, farm.y) + f * edge + r * (-1.1 + 1.1 * i)
		var d := (dirs[i] as Vector2).normalized()
		q.steps.clear()
		q.steps.append(ResidentAI.act(1.0e6, "carry"))
		q.x = at.x
		q.y = at.y
		q.px = q.x
		q.py = q.y
		q.action = "carry"
		q.anim = "carry"
		q.carry = "밀"
		q.job = -1
		q.facing = atan2(d.x, d.y)
	farm.worker = -1
	scene.view._bld_key.erase(farm.id)
	scene.refresh()
	scene.view.sync(0.0, true)
	return 30


## (w3) 벤 밀이 반 수레 쌓인 밭 — 시뮬 값(farm.out)만 정하고 줄은 BldEcon.wheat_rows가 고른다. 일꾼 둘은 밭 안(화면에선 숲 앞), 한 사람은 이삭을 메고 감
func _reap_half() -> int:
	var f := _fdir(0)
	var r := _rdir(0)
	farm.ready_at = v.t - 3.0 * 86400.0
	farm.out["밀"] = roundf(BldEcon.out_full("밀") * 0.5)
	var p := Vector2(farm.x, farm.y)
	var spots := [p + r * 0.75 + f * 0.25, p - r * 0.7 - f * 0.3, p + r * 1.5 + f * 1.9]
	for i in folk.size():
		var q := folk[i]
		var act := "work" if i < 2 else "carry"
		_put(q, spots[i], act, r if i == 2 else Vector2.ZERO)
		q.job = farm.id if i < 2 else -1
	farm.worker = folk[0].id
	_redraw()
	print("reap_half cut ", farm.out["밀"], " frac ", BldEcon.reaped_frac(float(farm.out["밀"])), " rows ", BldEcon.wheat_rows(v, farm))
	return 30


func _put(q: Resident, at: Vector2, act: String, dir: Vector2) -> void:
	q.steps.clear()
	q.steps.append(ResidentAI.act(1.0e6, act))
	q.x = at.x
	q.y = at.y
	q.px = q.x
	q.py = q.y
	q.action = act
	q.anim = act
	q.carry = "밀" if act == "carry" else ""
	if dir != Vector2.ZERO:
		q.facing = atan2(dir.x, dir.y)


func _redraw() -> void:
	scene.view._bld_key.erase(farm.id)
	scene.refresh()
	scene.view.sync(0.0, true)


## (w3) 네 사람을 울타리 앞에 나란히 — 왼쪽부터 앞(카메라 쪽) · 비스듬한 앞(오른쪽) · 비스듬한 뒤 · 뒤. act = "work" (낫질) · "carry" (이삭 메기)
func _four(act: String) -> int:
	var f := _fdir(0)
	var r := _rdir(0)
	if folk.size() < 4:
		for q: Resident in v.people:
			if q.is_adult() and not folk.has(q):
				folk.append(q)
				break
	var edge := float(Bld2D.info(Bld2D.Pics.WHEAT_FENCE)["front"]) + 0.75
	var dirs := [f, r, (r - f * 1.19).normalized(), -f]
	farm.out["밀"] = 0.0
	for i in folk.size():
		var q := folk[i]
		_put(q, Vector2(farm.x, farm.y) + f * edge + r * (-1.5 + 1.0 * i), act, dirs[i])
		q.job = farm.id if act == "work" else -1
	farm.worker = folk[0].id if act == "work" else -1
	aim_at = Vector2(farm.x, farm.y) + f * (edge + 0.35)
	_redraw()
	return 30


func _aim_reset() -> int:
	aim_at = Vector2.INF
	for q in folk:
		q.job = -1
	farm.worker = -1
	return 1


## (w3) 밀 숲 뒤의 더미: 방앗간을 밭 바로 뒤로 옮기고 (밀 · 밀가루 더미), 둘째 밭을 그 옆 뒤에 (제 볏단 더미)
func _piles() -> int:
	var f := _fdir(0)
	var r := _rdir(0)
	_front_folk()
	farm.out["밀"] = roundf(BldEcon.out_full("밀") * 0.67)
	var p := Vector2(farm.x, farm.y)
	mill.set_meta("was", Vector2(mill.x, mill.y))
	var mp := p - f * 3.3 + r * 1.3
	for q in folk:                   # 사람들은 화면 밖으로 (더미만 보게)
		_put(q, p + f * 9.0 + r * 9.0, "idle", Vector2.ZERO)
	aim_at = p - f * 1.6
	mill.x = mp.x
	mill.y = mp.y
	mill.in_buf["밀"] = 120.0
	mill.out["밀가루"] = 90.0
	if farm2 == null:
		var fp := p - f * 3.9 - r * 0.8
		farm2 = v.add_building("농장", fp.x, fp.y, true)
		farm2.built_t = v.t - 86400.0
	farm2.ready_at = v.t - 86400.0
	farm2.out["밀"] = roundf(BldEcon.out_full("밀") * 0.67)
	scene.view._bld_key.clear()
	_redraw()
	var spots := ""
	for key: String in scene.view.econ._lv:
		if key.begins_with("%d:" % farm2.id) or key.begins_with("%d:" % mill.id) or key.begins_with("%d:" % farm.id):
			spots += key + " "
	print("piles: mill ", mp, " farm2 ", Vector2(farm2.x, farm2.y), " piles ", spots)
	return 40


func _piles_undo() -> int:
	var was: Vector2 = mill.get_meta("was")
	mill.x = was.x
	mill.y = was.y
	mill.in_buf.erase("밀")
	mill.out.erase("밀가루")
	if farm2 != null:
		v.buildings.erase(farm2)
		farm2 = null
	aim_at = Vector2.INF
	scene.view._bld_key.clear()
	_redraw()
	return 20


## (w3) 옛 저장: 밭 한가운데 바로 뒤의 무덤 (옛 규칙이 고르던 식의 자리) — 화면이 그 앞에 좁은 홈만 낸다
func _grave_mid() -> int:
	var f := _fdir(0)
	var back := float(Bld2D.info(Bld2D.wheat_cards(2)[1])["front"])
	var gp := Vector2(farm.x, farm.y) + f * (back - 0.9)
	farm.out["밀"] = 0.0
	_one_grave(gp)
	_front_folk()
	scene.view._grave_key = ""
	_redraw()
	print("grave_mid ", gp, " cuts ", BldEcon.grave_cuts(v, farm, 0, 2))
	return 40


func _one_grave(gp: Vector2) -> void:
	if v.graves.is_empty():          # 무덤 기록만 놓는다 (주민을 죽이면 장례 연출이 카메라를 가져감)
		v.graves.append({"id": 99901, "name": "시험", "x": gp.x, "y": gp.y, "t": v.t, "yard": false, "yard_id": -1})
	while v.graves.size() > 1:
		v.graves.pop_back()
	var g: Dictionary = v.graves[0]
	g["x"] = gp.x
	g["y"] = gp.y


## (w3) 새 자리 고르기: 밭을 옛 무덤 자리(마을 끝) 바로 앞에 옮겨 놓고 마을이 무덤 자리를 고르게 한다 → 밭 뒤가 아닌 곳
func _grave_site() -> int:
	var f := _fdir(0)
	var fp := Vector2(farm.x, farm.y)
	scene.paused = true
	v.graves.clear()
	var old := fp - f * (farm.size() + 0.7)          # 옛 규칙이 고르던 식의 자리 = 밭 바로 뒤 (마을 끝 기준 자리가 여기인 마을)
	var was := v.center
	v.center = old - Vector2(-0.6, 0.8).normalized() * 8.0
	var now := VillageEra._lone_grave(v, null)
	var by := VillageEra.grave_by_field(v, old)
	v.center = was
	_one_grave(now)
	_front_folk()
	aim_at = fp - f * 1.4
	scene.view._grave_key = ""
	_redraw()
	var cuts := 0
	for st in 4:
		for c: Array in BldEcon.grave_cuts(v, farm, st, 2):
			cuts += 0 if c.is_empty() else 1
	print("grave_site: old ", old, " farm ", fp, " new ", now, " (", (now - fp).dot(f), " toward, ", (now - fp).dot(_rdir(0)),
		" right) by_field(old) ", by, " by_field(new) ", VillageEra.grave_by_field(v, now), " cut cards over 4 steps ", cuts)
	return 40


## 밭 꾸밈 그림을 바꿔 다시 그림 (화면만)
func _accent(name: String) -> int:
	scene.view.wheat_accent = name
	scene.view._bld_key.erase(farm.id)
	scene.refresh()
	scene.view.sync(0.0, true)
	return 30


## 볏단이 넘치게 (나르는 손이 없음) → 밭 위에 생각 풍선
func _bubble() -> int:
	farm.out["밀"] = roundf(BldEcon.out_full("밀") * BldEcon.OVERFLOW * 1.1)
	scene.refresh()
	scene.view.sync(0.0, true)
	return 10


func _bubble_tick() -> int:
	for i in 6:
		scene.view.sync(0.5, true)
	print("bubbles ", scene.view.econ.bubbles)
	return 30


## 그림만 n 프레임 더 흐르게 (바람) — 시뮬레이션은 멈춘 채
func _run(n: int) -> int:
	return n


func _aim(ppu: float) -> int:
	scene.paused = true
	var c := Vector2(farm.x, farm.y) if aim_at == Vector2.INF else aim_at
	if scene.cam.flying:             # 사건 연출이 카메라를 날려 보내는 중이면 멈춤 (찍는 자리가 어긋나지 않게)
		print("aim: camera was flying — stopped")
		scene.cam.flying = false
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


## _aim을 한 번 더 (그 사이 시작된 카메라 날아가기를 멈추고 제자리로) — 바로 다음에 저장
func _hold(ppu: float) -> int:
	_aim(ppu)
	return 3


## 가운데를 잘라 저장 (ppu > 0: 밭 둘레 약 8칸 너비 · 0: 화면 전체를 반으로 줄여)
func _save(name: String, ppu: float, cells := 8.0) -> int:
	var img := vp.get_texture().get_image()
	if ppu > 0.0:
		var px := mini(int(cells * ppu * 3.0), img.get_width())
		var r := Rect2i((img.get_width() - px) / 2, (img.get_height() - px) / 2 - int(px * 0.10), px, px)
		if cells < 6.0:
			r = Rect2i((img.get_width() - px) / 2, (img.get_height() - px * 2 / 5) / 2 - int(px * 0.12), px, px * 2 / 5)
		img = img.get_region(r)
		if ppu > 30.0 and cells >= 6.0:
			img.resize(img.get_width() * 2 / 3, img.get_height() * 2 / 3, Image.INTERPOLATE_LANCZOS)
	else:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	var path := out_dir.path_join("%s_%s.png" % [tag, name])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
	return 1


## (w4) 카메라를 st 걸음 돌리고, 그 보기에서 밭 바로 뒤 (가운데에서 화면 오른쪽으로 side칸)에 무덤 하나 — 주민은 그 보기의 울타리 앞에
func _grave_at(st: int, side: float) -> int:
	_yaw(st)
	var back := float(Bld2D.info(Bld2D.wheat_cards(2)[1])["front"])
	var gp := Vector2(farm.x, farm.y) + _fdir(st) * (back - 0.9) + _rdir(st) * side
	farm.ready_at = v.t - 1.0
	farm.out["밀"] = 0.0
	_one_grave(gp)
	_front_folk(st)
	scene.view._grave_key = ""
	_redraw()
	print("grave_at st=", st, " view step=", scene.view.econ.step, " side=", side, " cuts ", BldEcon.grave_cuts(v, farm, scene.view.econ.step, 2))
	return 40


## (w4) 무덤을 치우고 처음 보기로
func _grave_gone() -> int:
	v.graves.clear()
	scene.view._grave_key = ""
	_yaw(0)
	_redraw()
	return 20


## (w4) 다시 자람 준비: 벤 밀이 한 수레 (앞 네 줄이 그루터기) + 낫 든 일꾼 둘 + 이삭 멘 사람
func _regrow_ready() -> int:
	_reap_half()
	farm.out["밀"] = BldEcon.out_full("밀")
	_redraw()
	_rg_t0 = -1.0
	_frames.clear()
	print("regrow ready: rows ", BldEcon.wheat_rows(v, farm))
	return 30


## (w4) 볏단을 실어 갔다 — 시뮬 값만 바꾼다. 힘주어 살피지 않는다 (화면이 제 박자로 알아채고 자라게 그린다)
func _regrow_go() -> int:
	farm.out["밀"] = 0.0
	return 0


## (w4) 다시 자람이 시작되고 t초 (BldEcon의 다시 자람 시계) 지날 때까지 기다린다
func _regrow_until(t: float) -> int:
	var e: BldEcon = scene.view.econ
	if _rg_t0 < 0.0 and e._regrow.has(farm.id):
		_rg_t0 = INF
		for idx: int in e._regrow[farm.id]:
			_rg_t0 = minf(_rg_t0, float(e._regrow[farm.id][idx]))
		print("regrow started at ", _rg_t0, " rows ", e._regrow[farm.id], " wheat_rows ", BldEcon.wheat_rows(v, farm))
	if _rg_t0 < 0.0 or e._regrow_t - _rg_t0 < t:
		step -= 1                     # 이 걸음을 다시
		return 0
	print("regrow t=", snappedf(e._regrow_t - _rg_t0, 0.01), " left ", e._regrow.get(farm.id, {}), " far=", scene.view.bld_far)
	return 0


## (w4) 밭 둘레를 잘라 모아 둔다 (_strip이 이어 붙임)
func _grab(ppu: float) -> int:
	var img := vp.get_texture().get_image()
	var w := mini(int(5.6 * ppu * 3.0), img.get_width())
	var h := mini(int(4.4 * ppu * 3.0), img.get_height())
	img = img.get_region(Rect2i((img.get_width() - w) / 2, (img.get_height() - h) / 2 - int(h * 0.12), w, h))
	if ppu < 30.0:
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	else:
		img.resize(img.get_width() * 3 / 4, img.get_height() * 3 / 4, Image.INTERPOLATE_LANCZOS)
	_frames.append(img)
	return 0


## (w4) 모아 둔 그림을 세 장씩 줄지어 한 장으로
func _strip(name: String) -> int:
	if _frames.is_empty():
		return 0
	var fw := _frames[0].get_width()
	var fh := _frames[0].get_height()
	var cols := 3
	var rows_n := int(ceil(_frames.size() / float(cols)))
	var gap := 6
	var out := Image.create(cols * fw + (cols - 1) * gap, rows_n * fh + (rows_n - 1) * gap, false, Image.FORMAT_RGBA8)
	out.fill(Color.WHITE)
	for i in _frames.size():
		var f := _frames[i]
		f.convert(Image.FORMAT_RGBA8)
		out.blit_rect(f, Rect2i(0, 0, fw, fh), Vector2i((i % cols) * (fw + gap), (i / cols) * (fh + gap)))
	var path := out_dir.path_join("%s_%s.png" % [tag, name])
	out.save_png(path)
	print("saved ", path, " ", out.get_size())
	_frames.clear()
	return 1

