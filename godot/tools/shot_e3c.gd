## E3-6 물가 세트 연결 · E3-3 열매 줍기 · 하늘 낟알 손봄 캡처 (390×844 — world.tscn, 시드 20261106). 창이 필요 (헤드리스 아님).
## 실행: godot --path godot -s res://tools/shot_e3c.gd
## 결과 godot_shots/: e3c_stones (징검돌 건너기) · e3c_fish (둘이 메는 물고기 + 혼자 끄는 물고기) · e3c_raft (개척 시대 갈대 뗏목 + 장대) ·
##   e3c_boat (다음 시대 잎 배) · e3c_fruit (잘린 열매 곁, 조각을 지고 가는 무리) · e3c_manna (하늘 낟알 — 빛기둥 없이 반짝이는 낟알)
## 시뮬레이션은 멈추고 (scene.paused) 주민의 자리·짐·동작만 정해 화면이 그리게 한다.
extends SceneTree

var scene: Node
var out_dir := ""
var frame := 0
var _wait := 0
var steps: Array[Callable] = []
var si := 0
var _keep: Array = []           # 매 화면 다시 정할 주민 [Resident, x, y, facing, carry, anim, raft]
var _extra: Array[Node] = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 7, "day": 15}
	Market.reset(650.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	steps = [_s_start, _s_stones, _s_shot.bind("e3c_stones"), _s_fish, _s_shot.bind("e3c_fish"), _s_raft.bind(0), _s_shot.bind("e3c_raft"),
		_s_raft.bind(1), _s_shot.bind("e3c_boat"), _s_fruit, _s_shot.bind("e3c_fruit"), _s_manna, _s_shot.bind("e3c_manna"), _s_end]


func v() -> Village:
	return scene.village


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
		r.carry = e[4]
		r.anim = "carry" if e[5] == "walk" and e[4] != "" else e[5]
		r.sleeping = false
		r.steps = [{"k": "walk", "x": r.x, "y": r.y, "raft": true}] if bool(e[6]) else []


## 마을 사람들을 모두 멀리 (집 안처럼 숨김) — 장면마다 쓸 사람만 다시 놓는다
func _clear() -> void:
	_keep.clear()
	for n in _extra:
		n.queue_free()
	_extra.clear()
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


func _put(r: Resident, p: Vector2, facing: float, carry: String, anim := "walk", raft := false) -> void:
	_keep.append([r, p.x, p.y, facing, carry, anim, raft])


func _s_start() -> int:
	scene.paused = true
	scene.set_debug_mode(false)
	scene.wterrain.set_fog_visible(false)
	GroundLook.month_override = 7
	return 10


func _dry(p: Vector2) -> bool:
	var w := v().water
	return w.inside(p.x, p.y, 1.0) and w.depth(w.idx(p.x, p.y)) <= Balance.WADE_DEPTH


## 징검돌: 화면이 놓은 징검돌이 있으면 거기, 없으면 마을 가까이 좁은 개울 칸에 하나 놓아 둔다 (캡처용)
func _s_stones() -> int:
	_clear()
	var vw: VillageView = scene.view
	var cr: Dictionary = {}
	for c: Dictionary in vw.crossings:
		if c["kind"] == "stones":
			cr = c
	print("crossings: %s" % [vw.crossings])
	if cr.is_empty():
		var w := v().water
		var best := -1
		var bd := INF
		for k in w.village_cells(v().center, 50.0):
			if not w.is_river(k):
				continue
			var p := Vector2(w.cx(k), w.cy(k))
			var along_x := w.is_river(w.idx(p.x + 1, p.y)) or w.is_river(w.idx(p.x - 1, p.y))
			var u := Vector2(0, 1) if along_x else Vector2(1, 0)
			if VillageView.river_width(w, p, u) > VillageView.STONES_MAX_W:
				continue
			var d := p.distance_to(v().center)
			if d < bd:
				bd = d
				best = k
		if best < 0:
			print("no narrow river near the village")
			return 2
		var p := Vector2(w.cx(best), w.cy(best))
		var along_x := w.is_river(w.idx(p.x + 1, p.y)) or w.is_river(w.idx(p.x - 1, p.y))
		var u := Vector2(0, 1) if along_x else Vector2(1, 0)
		var width := VillageView.river_width(w, p, u)
		var lvl := (w.ground(best) + w.depth(best)) * JarTerrain.HS - JarTerrain.WATER_SINK
		var sx := clampf((width + 1.4) / 3.6, 0.8, 1.35)
		var y := lvl - 0.1
		var n := Art.instance(scene.view, "bridge_stones", Transform3D(Basis(Vector3.UP, PI / 2.0 if along_x else 0.0) * Basis.from_scale(Vector3(sx, VillageView.STONE_TALL, VillageView.STONE_WIDE)), Vector3(p.x, y, p.y)))
		_extra.append(n)
		cr = {"kind": "stones", "c": p, "u": u, "half": 1.8 * sx, "y": y + VillageView.STONE_TOP, "step": 0.6 * sx}
		vw.crossings.append(cr)
		print("staged stones at %s width %d (center %s)" % [p, width, v().center])
	var c0: Vector2 = cr["c"]
	var u0: Vector2 = cr["u"]
	var ad := _adults()
	var face := atan2(u0.x, u0.y)
	var half := float(cr["half"])
	_put(ad[0], c0 - u0 * half * 0.15, face, "")
	_put(ad[1], c0 + u0 * half * 0.55, face, "물")
	_put(ad[2], c0 - u0 * (half + 0.9), face, "약초")
	_look(c0, 90.0)
	return 30


## 둘이 메는 물고기 (앞·뒤 짝) + 혼자 끄는 물고기 — 마을 가까운 마른 땅
func _s_fish() -> int:
	_clear()
	var c := v().center + Vector2(2.5, 4.0)
	for k in 30:
		if _dry(c) and _dry(c + Vector2(0, 3)):
			break
		c += Vector2(1.0, 0.0)
	var ad := _adults()
	var face := deg_to_rad(JarCamera.BASE_YAW_DEG) + 1.2
	var fwd := Vector2(sin(face), cos(face))
	_put(ad[0], c, face, "생선")
	_put(ad[1], c - fwd * 1.3, face, "생선")
	_put(ad[2], c + Vector2(fwd.y, -fwd.x) * 2.2 - fwd * 0.6, face, "생선")
	_look(c - fwd * 0.6, 110.0)
	return 30


## 나루터 뗏목: 물 위의 사람이 장대로 밀어 건넘 (시대 0 = 갈대 뗏목, 1 = 잎 배) + 곁의 나루터 모델
func _s_raft(era: int) -> int:
	_clear()
	v().era = era
	var w := v().water
	var best := -1
	var bd := INF
	for k in w.village_cells(v().center, 60.0):
		if w.depth(k) <= 0.02:
			continue
		var p := Vector2(w.cx(k), w.cy(k))
		var shore := false
		for d: Vector2 in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
			if _dry(p + d):
				shore = true
		var dd := p.distance_to(v().center)
		if shore and dd < bd:
			bd = dd
			best = k
	if best < 0:
		print("no water near the village")
		return 2
	var p := Vector2(w.cx(best), w.cy(best))
	var land := p
	for d: Vector2 in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		if _dry(p + d):
			land = p + d
			break
	var dir := (p - land).normalized()
	var fn := "ferry_raft" if era == 0 else "ferry"
	var gy: float = scene.view.gy(land.x, land.y)
	var n := Art.instance(scene.view, fn, Transform3D(Basis(Vector3.UP, atan2(-dir.y, dir.x)), Vector3(land.x, gy, land.y) + Vector3(dir.x, 0, dir.y) * 0.4))
	_extra.append(n)
	var ad := _adults()
	var side := Vector2(-dir.y, dir.x)
	var rp := p + dir * 2.4 + side * 2.6
	if not v().water_at(rp.x, rp.y):
		rp = p + dir * 2.4 - side * 2.6
	_put(ad[3], rp, atan2(side.x, side.y), "", "walk", true)
	_look(rp - side * 1.2, 75.0)
	return 30


## 거대한 열매: 잘린 열매 곁에서 하나는 자르고, 넷은 조각을 지고 줄지어 마을로
func _s_fruit() -> int:
	_clear()
	v().era = 0
	var ww := v().water as WorldWater
	var c := v().center + Vector2(-4.0, 3.0)
	for k in 30:
		if _dry(c) and _dry(c + Vector2(-4, 0)):
			break
		c += Vector2(-1.0, 1.0)
	ww.giant_fruits.clear()
	ww.giant_fruits.append({"x": c.x - 3.2, "y": c.y - 1.0, "t": v().t, "yaw": 0.6, "food": Balance.FRUIT_FOOD, "left": Balance.FRUIT_FOOD * 0.25, "cut": true, "id": 1})
	scene.great_view.sync(0.0, true)
	var ad := _adults()
	var face := atan2(1.0, 0.4)
	var fwd := Vector2(sin(face), cos(face))
	for i in 4:
		_put(ad[i], c + fwd * (1.1 * i) + Vector2(fwd.y, -fwd.x) * (0.35 * (i % 2)), face, "과일")
	_put(ad[4], Vector2(c.x - 3.2, c.y - 1.0) + Vector2(1.9, 0.9), atan2(-1.9, -0.9), "", "work")
	_look(c + Vector2(-1.2, 0.6), 62.0)
	return 30


## 하늘 낟알 한 줌: 무더기 셋 + 쏟아지는 연출 한가운데 (빛기둥이 없어야)
func _s_manna() -> int:
	_clear()
	var vv := v()
	var p := vv.center + Vector2(1.0, 2.0)
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		var q := p + Vector2(cos(a), sin(a)) * 0.7
		vv.manna.append({"x": q.x, "y": q.y, "amt": 20.0, "born": vv.t, "res": 0})
	var ad := _adults()
	_put(ad[0], p + Vector2(1.6, 0.9), atan2(-1.6, -0.9), "", "idle")
	_put(ad[1], p + Vector2(-1.4, 1.2), atan2(1.4, -1.2), "", "idle")
	vv.just_manna = true
	_look(p, 30.0)
	return 26


func _s_shot(name: String) -> int:
	for e: Array in _keep:
		var m: ResidentModel = scene.view.residents.get((e[0] as Resident).id)
		if m != null and m._carry_close != null:
			var ab := m._carry_close.global_transform * m._carry_close.mesh.get_aabb()
			print("  %d %s pos %s rot %.2f fwd %s prop %s centre %s" % [(e[0] as Resident).id, m._carry_prop, m.global_position, m.rotation.y, m.global_transform.basis.z.normalized(), m._carry_style, ab.get_center()])
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved %s %s · 징검돌 %d · 다리 %d · 짝 %s" % [name, img.get_size(), scene.view.n_stones, scene.view.n_bridges, scene.view.fish_pair])
	return 2


func _s_end() -> int:
	quit()
	return 1
