## 땅 고리 층 확인 캡처 — 짓는 터 진행 고리 · 쪽지의 땅 고리(짓는 터 / 제단)가 주민 상세 시트 '아래'에 그려지는지.
## 실행 (창이 필요): godot --path godot -s res://tools/shot_ring_layer.gd
## 결과 (godot_shots/): ringlayer_site / ringlayer_site_sheet (통나무를 내린 뒤 짓는 터 + 진행 고리, 시트 열림) ·
##   ringlayer_altar / ringlayer_altar_sheet ('제단' 쪽지의 금빛 고리 + 말, 시트 열림)
extends SceneTree

const NB := preload("res://tests/notebook_tests.gd")

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
	Market.reset(0.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	steps = [_s_start, _s_to.bind("logs"), _s_logs, _s_after.bind(4.0), _s_shot.bind("ringlayer_site"),
		_s_detail, _s_shot.bind("ringlayer_site_sheet"), _s_close,
		_s_to.bind("altar"), _s_unstage, _s_look_altar, _s_unstage, _s_unstage, _s_unstage, _s_shot.bind("ringlayer_altar"),
		_s_detail, _s_unstage, _s_shot.bind("ringlayer_altar_sheet"), _s_end]


func v() -> Village:
	return scene.village


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved %s %s · 쪽지 \"%s\" · marks %d · detail %s" % [name, img.get_size(), Notebook.text(v()).replace("\n", " "),
		scene._site_marks.size(), scene.detail.visible])


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
	while String(Notebook.shown(v()).get("id", "")) != id and guard < 6000:
		var tk := Notebook.shown(v())
		if not tk.is_empty() and not bool(tk.get("watch", false)) and Notebook.real(v()) - float(v().notebook["shown"]) >= 3.0:
			NB.do_task(v(), String(tk["id"]))
		_tick(0.5)
		guard += 1
	print("to %s: shown=%s guard=%d" % [id, Notebook.shown(v()).get("id", ""), guard])
	_settle()
	return 8


func _s_shot(name: String) -> int:
	_save(name)
	return 2


func _s_logs() -> int:
	var b := Notebook._site(v(), v().center, 1.0e9)
	NB.drop_from_hand(v(), Notebook.LOGS, Vector2(b.x, b.y))
	scene.look_at_ground(Vector2(b.x, b.y))
	scene.cam.ppu = 40.0
	scene.cam.ppu_goal = 40.0
	scene.cam._apply()
	scene.after_drop(v())
	return 4


func _s_after(real_s: float) -> int:
	scene.paused = false
	_tick(real_s)
	scene.paused = true
	_settle()
	return 10


## 사건 연출·안내 창이 떠 있으면 쪽지가 비켜 있으므로 걷어 냄
func _s_unstage() -> int:
	if scene.director != null and scene.director.playing():
		scene.director.skip()
	if scene.first_popup != null and scene.first_popup.showing():
		scene.first_popup.close()
	print("unstage: playing=%s popup=%s" % [scene.director.playing(), scene.first_popup.showing()])
	return 20


func _s_look_altar() -> int:
	var p: Vector2 = v().altar_pos
	scene.look_at_ground(p + Vector2(0.0, -3.0))     # 고리가 화면 아래쪽(시트가 덮는 곳)에 오도록
	scene.cam.ppu = 30.0
	scene.cam.ppu_goal = 30.0
	scene.cam._apply()
	_settle()
	return 12


func _s_detail() -> int:
	scene.detail.setup(v())
	scene.detail.open(v().people[0])
	return 14


func _s_close() -> int:
	scene.detail.close()
	return 4


func _s_end() -> void:
	print("고리 층 캡처 끝: %s" % out_dir)
	quit()
