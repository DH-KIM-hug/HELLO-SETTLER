## 거인의 수첩 캡처 (OPENING 3.1b — 360×640 휴대폰 기준, 넓은 세상 world.tscn, 시드 20261106).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_notebook.gd
## 결과 (godot_shots/): notebook_1 첫 쪽지 '통나무 내려 주기' (손 칸 + 화살표) · notebook_2 통나무를 내린 뒤 — 짓는 단계·진행 고리·일꾼 ·
##   notebook_3 첫 터(넓은 세상 키트는 오두막을 지고 와 첫 터가 밭) 완공 · notebook_4 첫 밭에 물 → 싹 · notebook_5 하늘 낟알 → 주워 먹음 · notebook_6 첫 아기 이름
extends SceneTree

const NB := preload("res://tests/notebook_tests.gd")

var scene: Node
var out_dir := ""
var frame := 0
var _wait := 0
var steps: Array[Callable] = []
var si := 0
var site_id := -1


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Market.reset(0.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	steps = [_s_start, _s_to.bind("logs"), _s_open_hand, _s_shot.bind("notebook_1"),
		_s_logs, _s_after.bind(5.0), _s_shot.bind("notebook_2"), _s_hut_done, _s_shot.bind("notebook_3"),
		_s_to.bind("water"), _s_water, _s_after.bind(2.5), _s_shot.bind("notebook_4"),
		_s_to.bind("grain"), _s_grain, _s_after.bind(1.2), _s_shot.bind("notebook_5"), _s_rest, _s_to.bind("baby"), _s_after.bind(0.5),
		_s_shot.bind("notebook_6"), _s_end]


func v() -> Village:
	return scene.village


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved %s %s · 쪽지 \"%s\"" % [name, img.get_size(), Notebook.text(v()).replace("\n", " ")])


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.refresh()


## 현실 시간을 흘림 (시계를 직접 — 화면은 다음 프레임에 맞춤)
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


## 그 쪽지가 뜰 때까지 (앞 쪽지는 대본처럼 해 둠)
func _s_to(id: String) -> int:
	var guard := 0
	while String(Notebook.shown(v()).get("id", "")) != id and guard < 4000:
		var tk := Notebook.shown(v())
		if not tk.is_empty() and not bool(tk.get("watch", false)) and Notebook.real(v()) - float(v().notebook["shown"]) >= 3.0:
			NB.do_task(v(), String(tk["id"]))
		_tick(0.5)
		guard += 1
	_settle()
	return 8


func _s_shot(name: String) -> int:
	_save(name)
	return 2


func _s_tap() -> int:
	scene.tap_glass(false, null)
	return 4


func _s_open_hand() -> int:
	var b := Notebook._site(v(), v().center, 1.0e9)
	scene.look_at_ground(Vector2(b.x, b.y) + Vector2(0.0, 3.5))
	scene.toggle_hand()
	_settle()
	return 10


func _s_logs() -> int:
	scene.hand_ctl.close()
	var b := Notebook._site(v(), v().center, 1.0e9)
	site_id = b.id
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


func _s_hut_done() -> int:
	scene.paused = false
	var guard := 0
	while guard < 200 and not (v().bld(site_id) != null and v().bld(site_id).built):
		_tick(0.25)
		guard += 1
	_tick(1.0)
	scene.paused = true
	_settle()
	return 10


func _s_water() -> int:
	var f := Notebook._farm(v(), v().center, 1.0e9)
	scene.look_at_ground(Vector2(f.x, f.y))
	scene.cam.ppu = 26.0
	scene.cam.ppu_goal = 26.0
	scene.cam._apply()
	_settle()
	scene.spray()
	return 4


func _s_grain() -> int:
	var c: Vector2 = NB.centroid(v())
	scene.look_at_ground(c)
	_settle()
	NB.drop_from_hand(v(), Notebook.GRAIN, c)
	scene.after_drop(v())
	return 2


func _s_rest() -> int:
	return 2


func _s_end() -> void:
	print("수첩 캡처 끝: %s" % out_dir)
	quit()
