## (Q42) 탐험가의 밤 · 지나온 길 · 돌아와 들려주는 이야기 — 캡처 (창이 필요 — 헤드리스 아님). 세상 덤프는 tools/measure_explore.gd의 다섯째 인자로 만든다:
##   godot --headless --path godot -s res://tools/measure_explore.gd -- 3 3 200 none <앞> → <앞>_s3_d60.bin · _d120.bin · _d200.bin
## 실행: godot --path godot -s res://tools/shot_explore_q42.gd -- <덤프.bin> <이름> [<덤프.bin> <이름> …]
## 결과 (godot_shots/explore_q42/): 덤프마다
##   <이름>_camp_wide · <이름>_camp_near — 밤, 집에서 먼 탐험가의 작은 모닥불 불빛 (안개 속 · 멀리서 / 가까이)
##   <이름>_band_map — 안개 지도: 왼쪽 = 예전 (나무 둘레만 섬처럼) · 가운데 = 보기 전 · 오른쪽 = 이제 (탐험가 자리에서 나무까지 띠)
##   <이름>_band_3d — 띠로 걷힌 길과 큰 나무 (넓은 땅 확대)
##   <이름>_tale_a · <이름>_tale_b — 낮, 멀리 다녀온 탐험가가 모닥불 곁에서 이야기 · 이웃이 모여 듣는다 (말풍선)
extends SceneTree

var scene: Node
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var jobs: Array = []
var cur := 0
var ex: Resident = null
var tree: Dictionary = {}
var band_at := Vector2.ZERO


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/explore_q42").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in range(0, args.size() - 1, 2):
		jobs.append([args[i], args[i + 1]])
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_q42_settings.cfg"
	StoreStrip.cfg_path = "user://shot_q42_hud.cfg"
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	_open()


func _open() -> void:
	var f := FileAccess.open(String(jobs[cur][0]), FileAccess.READ)
	var d: Dictionary = bytes_to_var(f.get_buffer(f.get_length()))
	f.close()
	if scene != null:
		scene.queue_free()
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world = JarWorld.from_dict(d)
	scene.world_seed = scene.world.seed_v
	root.add_child(scene)
	frame = 0
	step = 0
	ex = null
	tree = {}


func _save(nm: String, img: Image = null) -> void:
	if img == null:
		img = root.get_texture().get_image()
	var p := out_dir.path_join("%s_%s.png" % [String(jobs[cur][1]), nm])
	img.save_png(p)
	print("saved %s %s" % [p.get_file(), img.get_size()])


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _zoom(ppu: float, at: Vector2) -> void:
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.look_at_ground(at)
	_settle()


## 밤에 야영하는 탐험가 (병 시간을 흘려 찾는다 — 없으면 나가 있는 탐험가를 밤으로 데려가 야영시킨다)
func _find_camp() -> Resident:
	for i in 24 * 12:
		for id: int in [v.explorer] + v.explore_party:
			var r := v.person(id)
			if r != null and ResidentAI.camping(r) and Vector2(r.x, r.y).distance_to(v.center) > Balance.EXPLORE_CAMP_FAR:
				return r
		scene.world.advance(300.0)
	return null


## 지도 조각 (탐험가 자리와 나무가 다 들어가게) — 크게 키움
func _map_crop(ww: WorldWater, c: Vector2, half: float, marks: Array) -> Image:
	var st := 1
	var img := WorldMap.render(ww, st, true, marks)
	var k := ww.idx(c.x, c.y)
	var ci := (k % ww.n) / st
	var cj := (k / ww.n) / st
	var h := int(half / st)
	var x0 := clampi(ci - h, 0, img.get_width() - 2 * h)
	var y0 := clampi(cj - h, 0, img.get_height() - 2 * h)
	var part := img.get_region(Rect2i(x0, y0, 2 * h, 2 * h))
	part.resize(360, 360, Image.INTERPOLATE_NEAREST)
	return part


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 1170)
				return false
			v = scene.village
			scene.paused = true
			scene.set_process_unhandled_input(false)
			scene.set_debug_mode(false)
			scene.layout_bars()
			scene.firsts.open_all()
			ex = _find_camp()
			print("%s: day %.1f · hour %.1f · people %d · out %d · camp %s" % [jobs[cur][1], v.t / Balance.DAY, v.hour_now(), v.people.size(), v.explorers_out(),
				(ex.name + " " + ex.doing + " %.0f칸" % Vector2(ex.x, ex.y).distance_to(v.center)) if ex != null else "-"])
			if ex == null:
				step = 4
				return false
			for i in 12:                          # 깊은 밤으로 (23시 — 밤 남색이 짙게)
				if v.hour_now() >= 23.0 or v.hour_now() < 5.0:
					break
				scene.world.advance(600.0)
			_zoom(2.2, (Vector2(ex.x, ex.y) * 0.65 + v.center * 0.35))
			_wait = 40
		1:
			_settle()
			_wait = 8
		2:
			_save("camp_wide")
			_zoom(9.0, Vector2(ex.x, ex.y))
			_wait = 30
		3:
			_settle()
			_wait = 8
		4:
			if ex != null:
				_save("camp_near")
			for i in 30:                          # 낮으로
				var h := v.hour_now()
				if h >= 10.0 and h <= 14.0:
					break
				scene.world.advance(3600.0)
			var ww := v.water as WorldWater
			var bd := INF
			for gt: Dictionary in ww.great_trees:
				var dd := Vector2(gt["x"], gt["y"]).distance_to(v.center)
				if not v.explore_seen.has(String(gt["kind"])) and dd < bd:
					bd = dd
					tree = gt
			if tree.is_empty():
				print("모든 큰 나무를 이미 봄 — 띠 캡처 건너뜀")
				step = 8
				return false
			var who: Resident = null
			for r: Resident in v.people:
				if r.is_adult() and not r.id in v.explore_party and r.id != v.explorer:
					who = r
					break
			var c := Vector2(tree["x"], tree["y"])
			var dir := (v.center - c).normalized()
			var side := Vector2(-dir.y, dir.x)
			var p := c + (dir * 0.8 + side * 0.6).normalized() * (float(tree["r"]) + Balance.EXPLORE_TREE_SEE - 1.0)
			band_at = p
			var marks := [[c, Color(1, 0.8, 0.2)], [p, Color(0.9, 0.2, 0.2)]]
			var before := _map_crop(ww, c, 70.0, [])
			# 예전 (Q39): 나무 둘레만 — 같은 세상 사본에서 첫 20일처럼
			var d0: Dictionary = scene.world.to_dict()
			var w2 := JarWorld.from_dict(d0)
			var v2 := w2.primary()
			var ww2 := v2.water as WorldWater
			var t_keep := v2.t
			v2.t = 10.0 * Balance.DAY
			var who2 := v2.person(who.id)
			ResidentAI.cancel(v2, who2)
			who2.x = p.x
			who2.y = p.y
			v2._reveal_at(p, WorldCfg.REVEAL_WALK, who2, true)
			v2.t = t_keep
			var old := _map_crop(ww2, c, 70.0, [])
			# 이제 (Q42): 탐험가로 나가 있는 중에 봄
			ResidentAI.cancel(v, who)
			who.x = p.x
			who.y = p.y
			who.px = p.x
			who.py = p.y
			who.facing = atan2(c.x - p.x, c.y - p.y)
			v.explore_goals[str(who.id)] = "edge"
			v.explore_log.append({"t": v.t - 2.0 * Balance.DAY, "goal": "edge", "d": int(v.center.distance_to(p)), "who": who.id})
			v._reveal_at(p, WorldCfg.REVEAL_WALK, who, true)
			var now := _map_crop(ww, c, 70.0, [])
			var sheet := Image.create(360 * 3 + 20, 360, false, Image.FORMAT_RGB8)
			sheet.fill(Color(0.1, 0.1, 0.12))
			sheet.blit_rect(old, Rect2i(0, 0, 360, 360), Vector2i(0, 0))
			sheet.blit_rect(before, Rect2i(0, 0, 360, 360), Vector2i(370, 0))
			sheet.blit_rect(now, Rect2i(0, 0, 360, 360), Vector2i(740, 0))
			_save("band_map", sheet)
			print("band: tree %s · explorer %s at %.0f칸 from trunk · saw=%s" % [tree["name"], who.name, p.distance_to(c),
				String(ResidentAI._trip_of(v, who).get("saw", ""))])
			v.explore_goals.erase(str(who.id))
			ex = who
			_zoom(3.0, (p + c) * 0.5)
			_wait = 40
		5:
			_zoom(3.0, (band_at + Vector2(tree["x"], tree["y"])) * 0.5)
			_wait = 20
		6:
			_settle()
			_wait = 8
		7:
			_save("band_3d")
		8:
			# 이야기: 멀리 다녀온 탐험가를 모닥불 곁에 세우고 explore_home
			for i in 30:
				var h := v.hour_now()
				if h >= 10.0 and h <= 15.0:
					break
				scene.world.advance(3600.0)
			if ex == null:
				for r: Resident in v.people:
					if r.is_adult():
						ex = r
						break
			ResidentAI.cancel(v, ex)
			v.explore_done(ex)
			var hp := v.fire + Vector2(1.6, 1.4)
			ex.x = hp.x
			ex.y = hp.y
			ex.px = hp.x
			ex.py = hp.y
			v.explore_goals[str(ex.id)] = "tree:ginkgo"
			v.explore_log.append({"t": v.t - 3.0 * Balance.DAY, "goal": "edge", "d": 240, "who": ex.id, "saw": String(tree.get("kind", "ginkgo")), "camp": true})
			v.explorer = ex.id
			var n := 0
			for q: Resident in v.people:      # 곁의 이웃 몇은 한가하게 (이야기를 들으러 올 수 있게)
				if q != ex and not q.is_baby() and n < 4 and Vector2(q.x, q.y).distance_to(v.fire) < 30.0:
					ResidentAI.cancel(v, q)
					q.action = "idle"
					q.sleeping = false
					n += 1
			if v.in_crisis():
				print("위기 중 — 캡처를 위해 모자람을 잠시 끔")
				v.deficit = 0.0
			v.explore_done(ex)
			var ok: bool = ResidentAI._explore_tale(v, ex)
			print("tale ok=%s crisis=%s · events %d · %s" % [ok, v.in_crisis(), v.social_events.size(),
				str((v.social_events.back() as Dictionary).get("lines", [])) if not v.social_events.is_empty() else ""])
			_zoom(36.0, v.fire + Vector2(1.0, 1.0))
			_wait = 20
		9:
			for k in 8:                          # 이웃이 다가올 만큼 (병 몇 분)
				scene.world.advance(30.0)
			_zoom(36.0, Vector2(ex.x, ex.y))
			_wait = 120                          # 말풍선 둘째 줄쯤
		10:
			_zoom(36.0, Vector2(ex.x, ex.y))
			print("cam ppu %.1f · ex %s %s" % [scene.cam.ppu, ex.doing, str(Vector2(ex.x, ex.y))])
			_save("tale_a")
			_wait = 170
		11:
			_zoom(36.0, Vector2(ex.x, ex.y))
			_save("tale_b")
			cur += 1
			if cur < jobs.size():
				_open()
				return false
			for p: String in ["user://shot_q42_settings.cfg", "user://shot_q42_hud.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	step += 1
	return false
