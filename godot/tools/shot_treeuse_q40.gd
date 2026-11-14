## (Q40) 큰 나무 넷의 쓰임 — 캡처 (창이 필요 — 헤드리스 아님). 세상 덤프는 tools/measure_explore.gd의 다섯째 인자로 만든다:
##   godot --headless --path godot -s res://tools/measure_explore.gd -- 3 3 60 help <앞> → <앞>_s3_d60.bin
## 실행: godot --path godot -s res://tools/shot_treeuse_q40.gd -- <덤프.bin>
## 덤프의 마을에 큰 나무 넷을 '본 것'으로 하고 (안개를 걷고), 철과 상관없이 나들이를 하나씩 보낸다 (TreeUses.go) — 사람을 나무 곁으로 옮겨 장면만 본다.
## 결과 (godot_shots/treeuse_q40/):
##   cherry_sit — 꽃 철 (병 날짜를 4월로 돌림) 큰 벚나무 아래 앉은 나들이 무리 (가까이)
##   cherry_wide — 같은 장면 조금 멀리 (나무 전체)
##   pine_carry · ginkgo_carry · maple_carry — 송진 · 은행 · 단물을 지고 돌아오는 사람 (가까이)
##   chron — 연대기 (처음 쓴 줄 넷 + 엿이 돈 잔치)
extends SceneTree

var scene: Node
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var dump := ""
var kinds := ["pine", "ginkgo", "maple"]
var ki := 0
var team: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	dump = args[0]
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/treeuse_q40").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_q40_settings.cfg"
	StoreStrip.cfg_path = "user://shot_q40_hud.cfg"
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	var f := FileAccess.open(dump, FileAccess.READ)
	var d: Dictionary = bytes_to_var(f.get_buffer(f.get_length()))
	f.close()
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world = JarWorld.from_dict(d)
	scene.world_seed = scene.world.seed_v
	root.add_child(scene)


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join("%s.png" % nm)
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


func _tree(kind: String) -> Dictionary:
	return GreatTrees.of_kind(v.water as WorldWater, kind)


## 나들이를 보내고 (철과 상관없이) 무리를 나무 곁 앉는 자리로 옮긴다 — 닿음까지
func _send(kind: String) -> Array:
	for p: Resident in v.people:
		if p.is_adult() and p.action != TreeUses.ACTION:
			ResidentAI.cancel(v, p)
			p.action = "idle"
			p.hunger = 0.0
	v.tree_use["out"] = {}
	TreeUses.go(v, kind)
	var out: Array = []
	for id: int in (v.tree_use["out"]["ids"] as Array):
		var r := v.person(id)
		var w: Dictionary = r.steps.pop_front()
		r.x = float(w["x"])
		r.y = float(w["y"])
		r.px = r.x
		r.py = r.y
		var arrive: Dictionary = r.steps.pop_front()
		ResidentAI.run_op(v, r, arrive["done"])
		var c := Vector2(_tree(kind)["x"], _tree(kind)["y"])
		r.facing = atan2(c.x - r.x, c.y - r.y) + PI      # 나무를 등지고 (화면 쪽)
		ResidentAI.update(v, r, 5.0)         # 앉는 동작으로 (화면이 r.anim을 봄)
		out.append(r)
	return out


## 지고 돌아오는 장면: 긁기 · 줍기가 끝난 뒤 집으로 몇 걸음
func _carry(kind: String) -> Array:
	var tm := _send(kind)
	for r: Resident in tm:
		while not r.steps.is_empty() and String(r.steps[0]["k"]) == "do":
			var s: Dictionary = r.steps.pop_front()
			if s["done"] != null:
				ResidentAI.run_op(v, r, s["done"])
	for i in 100:                           # 병 50분쯤 — 잎 그늘 밖으로 — 잎 그늘 밖으로
		for r: Resident in tm:
			ResidentAI.update(v, r, 30.0)
	return tm


func _center(tm: Array) -> Vector2:
	var c := Vector2.ZERO
	for r: Resident in tm:
		c += Vector2(r.x, r.y)
	return c / maxf(1.0, tm.size())


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
			for i in 30:                          # 낮으로
				var h := v.hour_now()
				if h >= 10.0 and h <= 14.0:
					break
				scene.world.advance(3600.0)
			# 병 날짜를 벚꽃 철로 (덤프는 6월) — 화면의 철 모습도 봄
			var days := int((v.start_clock + v.t) / Balance.DAY)
			var base := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 4, "day": 5, "hour": 12, "minute": 0, "second": 0})
			var cd := Time.get_datetime_dict_from_unix_time(base - days * 86400)
			for q: Village in scene.world.settlements:
				q.created_date = {"year": int(cd["year"]), "month": int(cd["month"]), "day": int(cd["day"])}
			print("jar date now %s" % str(Health.jar_date(v)))
			for gt: Dictionary in (v.water as WorldWater).great_trees:
				v.explore_seen[String(gt["kind"])] = v.t
				v._reveal_at(Vector2(gt["x"], gt["y"]), float(gt["r"]) + 30.0, null, true)
			v.stock["빵"] = float(v.stock.get("빵", 0.0)) + 30.0 * Production.day_need(v)
			team = _send("cherry")
			print("anims %s" % [team.map(func(r: Resident) -> String: return r.anim)])
			print("cherry team %d: %s" % [team.size(), team.map(func(r: Resident) -> String: return r.name + " " + r.doing + " " + r.say)])
			var c := Vector2(_tree("cherry")["x"], _tree("cherry")["y"])
			_zoom(30.0, _center(team).lerp(Vector2(_tree("cherry")["x"], _tree("cherry")["y"]), 0.3))
			_wait = 40
		1:
			var c := Vector2(_tree("cherry")["x"], _tree("cherry")["y"])
			_zoom(30.0, _center(team).lerp(Vector2(_tree("cherry")["x"], _tree("cherry")["y"]), 0.3))          # 안개가 걷혀 카메라 한계가 넓어진 뒤 다시
			_wait = 10
		2:
			_save("cherry_sit")
			var c := Vector2(_tree("cherry")["x"], _tree("cherry")["y"])
			_zoom(6.0, _center(team).lerp(c, 0.6))
			_wait = 30
		3:
			_settle()
			_wait = 6
		4:
			_save("cherry_wide")
			for r: Resident in team:            # 돌아와 마을이 환함 (연대기 줄)
				r.steps.clear()
				ResidentAI.run_op(v, r, ResidentAI.op("tuse_put", {"kind": "cherry"}))
			ki = 0
		5:
			var kind: String = kinds[ki]
			team = _carry(kind)
			print("%s team %d: %s" % [kind, team.size(), team.map(func(r: Resident) -> String: return "%s %s %s %.1f" % [r.name, r.doing, r.carry, r.carry_amt])])
			_zoom(55.0, Vector2(team[0].x, team[0].y))
			_wait = 40
		6:
			_zoom(55.0, Vector2(team[0].x, team[0].y))
			_wait = 8
		7:
			_save("%s_carry" % kinds[ki])
			for r: Resident in team:
				r.steps.clear()
				ResidentAI.run_op(v, r, ResidentAI.op("tuse_put", {"kind": kinds[ki]}))
			ki += 1
			if ki < kinds.size():
				step = 5
				return false
			v.festival_t = v.t                  # 잔치 — 단풍 엿이 돈다 (연대기 줄)
			TreeUses.hourly(v)
		8:
			scene.open_chronicle()
			_wait = 30
		9:
			_save("chron")
			scene.close_sheets()
			for p: String in ["user://shot_q40_settings.cfg", "user://shot_q40_hud.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	step += 1
	return false
