## 지켜보기 쪽지 캡처 (2026-11-08 "주민들이 지켜볼 때 그에 맞춰 행동을 안 함") — 360×640, world.tscn, 시드 20261106, 종이 인형, ppu 32.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_watch_notes.gd
## 결과 (godot_shots/): watch_sky_1·2 쪽지 7 '아이들이 하늘을 올려다보네' (모닥불 곁 아이들이 올려다보며 가리킴 + 진행 줄) ·
##   watch_altar_1·2·3 쪽지 '사람들이 모닥불 곁에 돌을 모은다' (돌을 줍고·안고·쌓음, 제단이 단계마다 자람, "제단 돌 n/24" + 터 위 진행 고리)
extends SceneTree

const NB := preload("res://tests/notebook_tests.gd")
const PPU := 32.0

var scene: Node
var out_dir := ""
var frame := 0
var _wait := 0
var steps: Array[Callable] = []
var si := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	CutoutResident.override = 1
	Market.reset(0.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	steps = [_s_start, _s_to.bind("sky"), _s_press, _s_after.bind(14.0), _s_skip, _s_shot.bind("watch_sky_1"), _s_after.bind(1.6), _s_shot.bind("watch_sky_2"),
		_s_to.bind("altar"), _s_skip, _s_press, _s_after.bind(30.0), _s_skip, _s_frames.bind(50), _s_skip, _s_frames.bind(50), _s_skip, _s_press, _s_shot.bind("watch_altar_1"), _s_after.bind(1.2), _s_shot.bind("watch_altar_2"),
		_s_after.bind(60.0), _s_skip, _s_frames.bind(50), _s_skip, _s_frames.bind(50), _s_skip, _s_press, _s_shot.bind("watch_altar_3"), _s_end]


func v() -> Village:
	return scene.village


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	var kids := PackedStringArray()
	for r in v().people:
		if r.is_child() and not r.is_baby():
			kids.append("%s:%s/%s%s" % [r.name, r.action, r.anim, ("+" + r.carry) if r.carry != "" else ""])
	print("saved %s %s · 쪽지 \"%s\" · 진행 \"%s\" · 아이들 %s · 손의 돌 %d" % [name, img.get_size(), Notebook.text(v()).replace("\n", " "),
		String(Notebook.progress(v()).get("text", "")), " ".join(kids), scene.view.altar_view.carried_stones() if scene.view.altar_view != null else -1])


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.refresh()


func _tick(real_s: float) -> void:
	var vv := v()
	vv.water.offline = true
	var t := 0.0
	while t < real_s:
		scene.clock.tick(0.25)
		t += 0.25
	vv.water.offline = false
	scene._sync_views()


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(360, 640)
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if si >= steps.size():
		return true
	var w: Variant = steps[si].call()
	si += 1
	_wait = int(w) if w != null else 4
	return false


func _s_start() -> int:
	scene.set_debug_mode(false)
	scene.clock.start_creation_day()
	Notebook.begin(v())
	scene.paused = true
	return 6


func _s_to(id: String) -> int:
	var guard := 0
	while String(Notebook.shown(v()).get("id", "")) != id and guard < 4000:
		var tk := Notebook.shown(v())
		if not tk.is_empty() and not bool(tk.get("watch", false)) and Notebook.real(v()) - float(v().notebook["shown"]) >= 3.0:
			NB.do_task(v(), String(tk["id"]))
		_tick(0.5)
		guard += 1
	print("to %s: real %.0f" % [id, Notebook.real(v())])
	_settle()
	return 8


## 쪽지를 누름 → 그 자리로 카메라 (장면과 같은 길) + ppu 32
func _s_press() -> int:
	scene._on_note_pressed()
	scene.cam.ppu = PPU
	scene.cam.ppu_goal = PPU
	scene.cam._apply()
	_settle()
	return 8


func _s_after(real_s: float) -> int:
	scene.paused = false
	_tick(real_s)
	scene.paused = true
	_settle()
	return 12


func _s_shot(name: String) -> int:
	_save(name)
	return 2


## 사건 연출(깨달음·첫 기도)이 쪽지를 가리는 동안은 건너뜀 — 쪽지가 보이는 화면을 찍음
func _s_skip() -> int:
	var d: Variant = scene.get("director")
	if d != null and d.playing():
		d.skip()
		print("  (연출 건너뜀)")
	var fp: Variant = scene.get("first_popup")
	if fp != null and fp.showing():
		fp.close()
		print("  (안내 창 닫음)")
	return 2


func _s_frames(n: int) -> int:
	return n


func _s_end() -> void:
	print("지켜보기 쪽지 캡처 끝: %s" % out_dir)
	quit()
