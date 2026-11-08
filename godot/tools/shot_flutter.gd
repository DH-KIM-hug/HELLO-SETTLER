## 작은 생물 움직임 띠 (나비 날갯짓 · 꿀벌 · 메뚜기 · 달팽이 자국) — 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_flutter.gd
## 넓은 세상(world.tscn, 시드 20261106) 낮 10시 · 병 시간은 멈추고 화면 (fauna_view)만 흐름 (30화면/초) →
##   flutter_ppu32.png · flutter_ppu60.png · flutter_ppu110.png (나비 하나를 따라가며 0.1초 간격 6칸 — 날갯짓 두 번쯤) ·
##   flutter_ppu80_slow.png (카메라 고정 · 1초 간격 6칸 — 굽이 날기·내려앉기·둘레 생물)
## 칸은 메모리에서 이어 붙여 한 장만 저장 (디스크를 아낌).
extends SceneTree

const CROP := Vector2i(300, 360)
const GAP := 6

var scene: Node
var out_dir := ""
var frame := 0
var v: Village
var jobs: Array = []                   # [이름, ppu, 칸 사이 화면 수, 칸 수, 나비를 따라감]
var _job := -1
var _left := 0
var _gap_left := 0
var _cells: Array[Image] = []
var _target := Vector2.ZERO
var _bf: Dictionary = {}               # 따라가는 나비 (fauna_view 항목 — 읽기만)


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Market.reset(2400.0)
	Village.start_aware = true
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	scene.firsts.open_all()
	jobs = [["flutter_ppu32", 32.0, 3, 6, true], ["flutter_ppu60", 60.0, 3, 6, true], ["flutter_ppu110", 110.0, 3, 6, true], ["flutter_ppu80_slow", 80.0, 30, 6, false]]


func _fv() -> FaunaView:
	return (scene.view as VillageView).fauna_view


func _look(p: Vector2, ppu: float) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()


func _setup() -> void:
	v = scene.village
	v.water.offline = true
	scene.firsts.open_all()
	var left := fposmod(10.0 - v.hour_now(), 24.0) * 3600.0 + 24.0 * 3600.0
	while left > 0.0:
		var d := minf(600.0, left)
		scene.world.advance(d)
		left -= d
	v.water.offline = false
	scene.paused = true
	scene.set_debug_mode(false)
	scene.clock.notice_t = 0.0
	v.warnings.clear()
	for p in v.people:
		p.say_t = 0.0
	# 나비가 가장 많이 모인 곳 (다른 생물도 함께 보이게 3칸 안 생물 수로)
	var crit: Array = _fv()._crit
	var best := -1
	for e: Dictionary in crit:
		if e["kind"] != "butterfly":
			continue
		var n := 0
		for q: Dictionary in crit:
			if (q["p"] as Vector2).distance_to(e["p"]) < 3.0:
				n += 1 if q["kind"] != "butterfly" else 3
		if n > best:
			best = n
			_target = e["p"]
			_bf = e
	print("철 %s · %.1f시 · 생물 %d (고치 나비 %d) · 가운데 (%.1f, %.1f)" % [FloraLook.season_of(v), v.hour_now(), crit.size(),
		v.caterpillars.flies.size() if v.caterpillars != null else 0, _target.x, _target.y])


func _cell() -> Image:
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var sz := img.get_size()
	var o := (sz - CROP) / 2
	return img.get_region(Rect2i(o, CROP))


func _save_strip(name: String) -> void:
	var w := CROP.x * _cells.size() + GAP * (_cells.size() - 1)
	var strip := Image.create(w, CROP.y, false, Image.FORMAT_RGB8)
	strip.fill(Color("1e1f2a"))
	for i in _cells.size():
		strip.blit_rect(_cells[i], Rect2i(Vector2i.ZERO, CROP), Vector2i(i * (CROP.x + GAP), 0))
	var p := out_dir.path_join(name + ".png")
	strip.save_png(p)
	var fv := _fv()
	print("saved %s · 보는 반지름 %.1f · 생물 가까이 %d · 멀리 %d · 자국 %d" % [name, scene.cam.view_radius(), fv.shown_near, fv.shown_far, fv.shown_trail])


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(390, 844)
		Engine.max_fps = 30
		return false
	if frame == 10:
		_setup()
		return false
	if _job < 0 or _left <= 0:
		if _job >= 0:
			_save_strip(jobs[_job][0])
		_job += 1
		if _job >= jobs.size():
			return true
		_look(_bf["p"] if not _bf.is_empty() else _target, float(jobs[_job][1]))     # 고정 띠도 그 나비의 지금 자리에서 시작
		_cells.clear()
		_left = int(jobs[_job][3])
		_gap_left = 45                  # 확대를 바꾼 뒤 1.5초 — 땅·가까이 노드가 자리 잡게
		return false
	_gap_left -= 1
	if _gap_left == 1 and bool(jobs[_job][4]) and not _bf.is_empty():
		_look(_bf["p"], float(jobs[_job][1]))     # 다음 화면에 찍힘
	if _gap_left > 0:
		return false
	_cells.append(_cell())
	_left -= 1
	_gap_left = int(jobs[_job][2])
	return false
