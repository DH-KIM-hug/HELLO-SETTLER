## (Q39) 주민이 계속 탐험 — 캡처 (창이 필요 — 헤드리스 아님). 세상 덤프는 tools/measure_explore.gd의 다섯째 인자로 만든다:
##   godot --headless --path godot -s res://tools/measure_explore.gd -- 3 3 200 none <앞> → <앞>_s3_d60.bin · _d120.bin · _d200.bin
## 실행: godot --path godot -s res://tools/shot_explore_q39.gd -- <덤프.bin> <이름> [<덤프.bin> <이름> …]
## 결과 (godot_shots/explore_q39/): 덤프마다
##   <이름>_out_near · <이름>_out_wide — 안개 너머로 떠나는 탐험가 (가까이 · 멀리서 — 지나온 길의 안개가 걷힘)
##   <이름>_tree — 아직 못 본 큰 나무 곁에 탐험가가 닿은 순간: 발견 카드 + 걷힌 나무 (그 나무 자리로 카메라)
##   <이름>_chron — 연대기 (발견 줄)
##   <이름>_full — 끝까지 축소: 걷힌 땅 · 안개 · 유리벽
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


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/explore_q39").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i in range(0, args.size() - 1, 2):
		jobs.append([args[i], args[i + 1]])
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_q39_settings.cfg"
	StoreStrip.cfg_path = "user://shot_q39_hud.cfg"
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


func _save(nm: String) -> void:
	var img := root.get_texture().get_image()
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


## 떠나는 탐험가를 찾는다: 마을에서 15~70칸 떨어져 밖으로 걷는 중 (없으면 병 시간을 조금씩 흘려 본다)
func _find_out() -> Resident:
	for i in 96:
		for r: Resident in v.people:
			if r.id != v.explorer and not r.id in v.explore_party:
				continue
			var d := Vector2(r.x, r.y).distance_to(v.center)
			if d > 15.0 and d < 70.0 and r.doing != "집으로 돌아가는 중":
				return r
		scene.world.advance(600.0)
	return null


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
			ex = _find_out()
			print("%s: day %.1f · people %d · out %d · seen %s · hero %s · explorer %s" % [jobs[cur][1], v.t / Balance.DAY, v.people.size(), v.explorers_out(),
				str(v.explore_seen.keys()), str(v.explore_hero), ex.name + " " + ex.doing if ex != null else "-"])
			if ex == null:
				step = 4
				return false
			_zoom(14.0, Vector2(ex.x, ex.y))
			scene.go_see({"village": v, "who": ex.id, "pos": Vector2(ex.x, ex.y)})     # 그 사람의 상세 (하는 일) + 따라가기
			_wait = 40
		1:
			_settle()
			_wait = 6
		2:
			_save("out_near")
			scene.close_sheets()
			scene._stop_follow()
			_zoom(2.2, (Vector2(ex.x, ex.y) + v.center) * 0.5)
			_wait = 30
		3:
			_settle()
			_wait = 6
		4:
			if ex != null:
				_save("out_wide")
			for i in 30:                          # 낮에 (밤엔 나무가 어두워 안 보임) — 병 시간을 조금 흘려 아침으로
				var h := v.hour_now()
				if h >= 9.0 and h <= 15.0:
					break
				scene.world.advance(3600.0)
			# 아직 못 본 큰 나무 가운데 가장 가까운 것 곁에 탐험가를 세우고 안개를 걷는다 (발견 순간)
			var ww := v.water as WorldWater
			var bd := INF
			for gt: Dictionary in ww.great_trees:
				var dd := Vector2(gt["x"], gt["y"]).distance_to(v.center)
				if not v.explore_seen.has(String(gt["kind"])) and dd < bd:
					bd = dd
					tree = gt
			if tree.is_empty():
				print("모든 큰 나무를 이미 봄")
				step = 9
				return false
			var who: Resident = ex
			if who == null:
				for r: Resident in v.people:
					if r.is_adult():
						who = r
						break
			var c := Vector2(tree["x"], tree["y"])
			var dir := (v.center - c).normalized()
			var p := c + dir * (float(tree["r"]) + 9.0)
			ResidentAI.cancel(v, who)
			who.x = p.x
			who.y = p.y
			who.px = p.x
			who.py = p.y
			who.facing = atan2(-dir.x, -dir.y)
			v._reveal_at(p, WorldCfg.REVEAL_WALK, who, true)
			print("tree %s found by %s · line: %s" % [tree["name"], who.name, String(v.book.back()["text"]) if not v.book.is_empty() else ""])
			_zoom(5.0, c - dir * 6.0)
			_wait = 40
		5:
			var c := Vector2(tree["x"], tree["y"])
			var dir := (v.center - c).normalized()
			_zoom(5.0, c - dir * 6.0)          # 안개가 걷혀 카메라 한계가 넓어진 뒤 다시
			_wait = 20
		6:
			_settle()
			print("cam target %s · tree %s" % [str(scene.cam.target), str(Vector2(tree["x"], tree["y"]))])
			_wait = 8
		7:
			_save("tree")
			scene.open_chronicle()
			_wait = 30
		8:
			_save("chron")
			scene.close_sheets()
			_wait = 6
		9:
			_zoom(0.6, Vector2.ZERO)
			_wait = 40
		10:
			_settle()
			_wait = 8
		11:
			_save("full")
			cur += 1
			if cur < jobs.size():
				_open()
				return false
			for p: String in ["user://shot_q39_settings.cfg", "user://shot_q39_hud.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	step += 1
	return false
