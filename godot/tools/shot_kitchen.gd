## E3-14 부엌 화면 캡처 (390×844 — world.tscn, 시드 20261106). 창이 필요 (헤드리스 아님).
## 실행: godot --path godot -s res://tools/shot_kitchen.gd
## 결과 godot_shots/: kitchen_ranch_60 · kitchen_ranch_32 (목장·목장지기·단물 방울·무당벌레) · kitchen_egg_60 · kitchen_egg_32 (굴리는 큰 알) ·
##   kitchen_feast_60 · kitchen_feast_32 (깬 알 잔치) · kitchen_shell_60 · kitchen_shell_32 (빗물 통·껍데기 배) · kitchen_press_60 (씨앗 짜개)
## 시뮬레이션은 멈추고 (scene.paused) 부엌 상태·주민의 자리·걸음만 정해 화면이 그리게 한다.
extends SceneTree

var scene: Node
var out_dir := ""
var frame := 0
var _wait := 0
var steps: Array[Callable] = []
var si := 0
var _keep: Array = []           # [Resident, x, y, facing, anim, doing, steps(Array)]


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 7, "day": 15}
	Market.reset(650.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	steps = [_s_start, _s_ranch, _s_look.bind("ranch", 60.0), _s_shot.bind("kitchen_ranch_60"), _s_look.bind("ranch", 32.0), _s_shot.bind("kitchen_ranch_32"),
		_s_egg, _s_look.bind("egg", 60.0), _s_shot.bind("kitchen_egg_60"), _s_look.bind("egg", 32.0), _s_shot.bind("kitchen_egg_32"),
		_s_feast, _s_look.bind("feast", 60.0), _s_shot.bind("kitchen_feast_60"), _s_look.bind("feast", 32.0), _s_shot.bind("kitchen_feast_32"),
		_s_shell, _s_look.bind("shell", 60.0), _s_shot.bind("kitchen_shell_60"), _s_look.bind("shell", 32.0), _s_shot.bind("kitchen_shell_32"),
		_s_boat, _s_look.bind("boat", 60.0), _s_shot.bind("kitchen_boat_60"),
		_s_press, _s_look.bind("press", 60.0), _s_shot.bind("kitchen_press_60"), _s_end]


func v() -> Village:
	return scene.village


func kv() -> KitchenView:
	return (scene.view as VillageView).kitchen_view


var _focus := {}


func _look(p: Vector2, ppu := 40.0) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(390, 844)
		return false
	_apply_keep()
	if _wait > 0:
		_wait -= 1
		return false
	if si >= steps.size():
		return true
	var w: Variant = steps[si].call()
	si += 1
	_wait = int(w) if w != null else 4
	return false


func _apply_keep() -> void:
	for e: Array in _keep:
		var r: Resident = e[0]
		r.x = e[1]
		r.y = e[2]
		r.px = r.x
		r.py = r.y
		r.facing = e[3]
		r.anim = e[4]
		r.doing = e[5]
		r.carry = ""
		r.sleeping = false
		r.steps = (e[6] as Array).duplicate(true)


func _clear() -> void:
	_keep.clear()
	for r in v().people:
		r.x = v().center.x + 400.0
		r.y = v().center.y + 400.0
		r.px = r.x
		r.py = r.y
		r.carry = ""
		r.steps = []


func _adults() -> Array:
	var out: Array = []
	for r in v().people:
		if r.is_adult():
			out.append(r)
	return out


func _put(r: Resident, p: Vector2, facing: float, anim: String, doing := "", st: Array = []) -> void:
	_keep.append([r, p.x, p.y, facing, anim, doing, st])


func _dry(p: Vector2) -> bool:
	var w := v().water
	return w.inside(p.x, p.y, 1.0) and w.depth(w.idx(p.x, p.y)) <= Balance.WADE_DEPTH and not v().water_at(p.x, p.y)


func _open(p: Vector2, r: float) -> bool:
	if not _dry(p):
		return false
	var vv: VillageView = scene.view
	# 마당 덤불·꽃 (village_view _decor_yards: 건물 반지름 × 1.45 둘레) 과 숲 가장자리 꽃숲 밖
	for b in v().buildings:
		if Vector2(b.x, b.y).distance_to(p) < r + 2.2 * b.size() * VillageView.BUILDING_SCALE + 0.6:
			return false
	if vv.forest_at(p) > 0.0 or not vv._prop_ok(p.x, p.y, r):
		return false
	if Vector2(p.x - v().fire.x, p.y - v().fire.y).length() < 3.5 + r:
		return false
	if v().flora != null:                           # 큰 민들레·큰 버섯 (하늘의 것 — 키가 커서 앞을 가림)
		for f: Dictionary in v().flora.dands + v().flora.shrooms:
			if Vector2(float(f["x"]), float(f["y"])).distance_to(p) < r + 4.5:
				return false
	return vv._clear_of_trees(p, r + 3.5)


## 마을 가운데 둘레에서 빈 마른 땅
func _spot(from: Vector2, r: float) -> Vector2:
	for i in 192:
		var a := TAU * i / 16.0 + 0.4
		var p := from + Vector2(cos(a), sin(a)) * (2.0 + 1.0 * floorf(i / 16.0))
		if _open(p, r):
			return p
	return from


func _s_start() -> int:
	scene.paused = true
	scene.set_debug_mode(false)
	scene.wterrain.set_fog_visible(false)
	GroundLook.month_override = 7
	var vv: VillageView = scene.view
	vv.flora_cull = false
	print("buildings: %s" % [v().buildings.map(func(b: Building) -> String: return b.type)])
	return 10


func _s_look(key: String, ppu: float) -> int:
	_look(_focus[key], ppu)
	return 24


func _s_ranch() -> int:
	_clear()
	var k := v().kitchen
	var at := _spot(v().center + Vector2(5.0, -2.0), 1.6)
	k.start_ranch(v(), at, 12, &"sky")
	var ad := _adults()
	var spot := at + KitchenView.KEEPER_SPOT
	_put(ad[0], spot, atan2(-KitchenView.KEEPER_SPOT.x, -KitchenView.KEEPER_SPOT.y), "work", "진딧물 목장에 단물을 받으러 가는 중")
	_put(ad[1], at + Vector2(1.8, 1.4), atan2(-1.8, -1.4), "idle")          # 구경하는 사람
	_focus["ranch"] = at + Vector2(0.3, 0.4)
	kv().sync(0.0)
	kv().visit_ladybug()
	kv()._lady["t"] = KitchenView.LADY_IN * 0.88
	kv()._dew(ad[0].id)
	kv()._dews[0]["t"] = KitchenView.DEW_SECS * 0.35
	return 6


## 굴리는 중: 셋이 알 뒤에서 창고 쪽으로 (첫 걸음 = 창고 곁, 그 뒤 kit_egg_crack)
func _s_egg() -> int:
	_clear()
	var k := v().kitchen
	var s := v().store()
	var home := Vector2(s.x, s.y) if s != null else v().center
	var at := _spot(home + Vector2(-6.0, 4.0), 1.0)
	for r in v().people:
		r.action = "idle"
	var e := k.land(v(), at)
	e["rolled"] = true
	e["t"] = v().t - 4.0 * KitchenView.FRESH       # 떨어지는 모습 없이 (내려온 지 오래된 알)
	e["res"] = 3
	var dir := (home - at).normalized()
	var side := Vector2(dir.y, -dir.x)
	var ad := _adults()
	var face := atan2(dir.x, dir.y)
	for i in 3:
		var p := at - dir * 0.75 + side * (i - 1) * 0.55
		var st := [ResidentAI.walk(home.x + 1.6 + 0.5 * i, home.y - 1.0),
			ResidentAI.act(30.0, "work", ResidentAI.op("kit_egg_crack", {"e": int(e["id"])}), false)]
		_put(ad[i], p, face, "walk", "하늘의 큰 알을 굴려 오는 중", st)
	_focus["egg"] = at + dir * 0.2
	for r in v().people:
		if not _keep.any(func(q: Array) -> bool: return q[0] == r):
			r.steps = []
	return 40


## 깬 자리 잔치: 노른자 웅덩이 둘레에 모여 먹음
func _s_feast() -> int:
	_clear()
	var k := v().kitchen
	k.eggs.clear()
	var s := v().store()
	var home := Vector2(s.x, s.y) if s != null else v().center
	var at := _spot(home + Vector2(1.6, -1.5), 0.8)
	k.shells.append({"x": at.x, "y": at.y, "t": v().t - 20.0, "use": "basin"})
	var ad := _adults()
	for i in mini(5, ad.size()):
		var a := TAU * i / 5.0 + 0.5
		var p := at + Vector2(cos(a), sin(a)) * 1.25
		_put(ad[i], p, atan2(at.x - p.x, at.y - p.y), "eat" if i % 2 == 0 else "idle")
	_focus["feast"] = at
	return 40


## 껍데기 장식: 잔치가 끝난 껍데기 → 가까운 집 옆 빗물 통
func _s_shell() -> int:
	_clear()
	var k := v().kitchen
	k.shells.clear()
	var house: Building = null
	for b in v().buildings:
		if b.built and b.is_house():
			house = b
			break
	var at := Vector2(house.x, house.y) + Vector2(2.0, 1.0) if house != null else v().center
	k.shells.append({"x": at.x, "y": at.y, "t": v().t - 2.0 * Balance.DAY, "use": "basin"})
	kv()._decor_t = 0.0
	kv().sync(0.0)
	var bx: Transform3D = kv()._basin_xf(at, {}, 0.0)
	_focus["shell"] = Vector2(bx.origin.x, bx.origin.z)
	var ad := _adults()
	_put(ad[0], _focus["shell"] + Vector2(-0.75, 0.55), atan2(0.75, -0.55), "idle")      # 카메라와 통 사이를 비켜 옆에
	return 20


## 껍데기 배: 물가 가까이 깬 껍데기 → 물 위
func _s_boat() -> int:
	_clear()
	var k := v().kitchen
	var w := v().water
	var best := Vector2.ZERO
	var bd := INF
	for kk in w.village_cells(v().center, 30.0):
		if not w.is_lake(kk):
			continue
		var p := Vector2(w.cx(kk), w.cy(kk))
		var d := p.distance_to(v().center)
		if d < bd:
			bd = d
			best = p
	var dry := _spot(best, 0.3)
	k.shells.append({"x": dry.x, "y": dry.y, "t": v().t - 2.0 * Balance.DAY, "use": "boat"})
	kv()._decor_t = 0.0
	kv().sync(0.0)
	var b: Dictionary = kv()._boats.values()[0] if not kv()._boats.is_empty() else {}
	_focus["boat"] = b.get("at", best)
	print("boat at %s (lake %s, dry %s)" % [_focus["boat"], best, dry])
	return 20


func _s_press() -> int:
	_clear()
	var mill: Building = null
	for b in v().buildings:
		if b.type == "맷돌간" or b.type == "방앗간":
			mill = b
	if mill == null:
		var p := _spot(v().center + Vector2(-4.0, -5.0), 2.5)
		mill = v().add_building("맷돌간", p.x, p.y, true)
	v().kitchen.stats["pressed"] = 1.0
	kv()._press_t[mill.id] = v().t
	(scene.view as VillageView).sync(0.0, true)
	var ad := _adults()
	var pn: Node3D = kv()._presses[mill.id]["node"] if kv()._presses.has(mill.id) else null
	var pp := Vector2(pn.position.x, pn.position.z) if pn != null else Vector2(mill.x, mill.y)
	_put(ad[0], pp + Vector2(0.9, 0.3), atan2(-0.9, -0.3), "work")
	_focus["press"] = pp
	return 20


func _s_shot(nm: String) -> int:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(nm + ".png"))
	print("saved ", nm)
	return 2


func _s_end() -> int:
	quit()
	return 1
