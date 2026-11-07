## E1-0~2 사건 연출 · 6b 안내 창 · 6c 손 도구 캡처 (390×844 — 넓은 세상 world.tscn, 시드 20261106).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_e1.gd
## 결과 (godot_shots/): e1_awaken_up (아이가 하늘을 가리키고 모두 올려다봄) · e1_awaken_kneel (빛 한 줄기·무릎) · e1_awaken_card (자막) ·
##   e1_altar_1 · e1_altar_3 · e1_altar_5 (제단 짓기 단계 ①③⑤) · e1_prayer (첫 기도) · e1_prayer_card · e1_popup_altar (제단 알림 창 2c) ·
##   e1_popup_awakening (안내 창 6b) · e1_hand_locked (처음 [손]) · e1_popup_tool (도구가 열림) · e1_hand_unlocked · e1_chronicle_card · e1_sheet (모아 보기)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var _wait := 0
var shots: PackedStringArray = []
var steps: Array = []
var si := 0
var _until: Callable = Callable()
var _guard := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Market.reset(650.0)
	Firsts.reset()
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	steps = [_s_start, _s_awaken, _w_dir.bind(3.9), _s_shot.bind("e1_awaken_up"), _w_dir.bind(7.4), _s_shot.bind("e1_awaken_kneel"),
		_w_dir.bind(9.3), _s_shot.bind("e1_awaken_card"), _w_end, _w_popup.bind("awakening"), _s_shot.bind("e1_popup_awakening"), _s_close_popup,
		_s_build.bind(0.17), _w_dir.bind(2.4), _s_shot.bind("e1_altar_1"), _s_build.bind(0.57), _s_shot.bind("e1_altar_3"),
		_s_build.bind(0.95), _s_shot.bind("e1_altar_5"), _s_built, _w_pray, _s_shot.bind("e1_prayer_close"), _w_dir.bind(7.2),
		_s_shot.bind("e1_prayer"), _w_dir.bind(8.9), _s_shot.bind("e1_prayer_card"), _w_end, _w_popup.bind("altar"), _s_shot.bind("e1_popup_altar"),
		_s_close_popup, _s_hand, _s_shot.bind("e1_hand_locked"),
		_s_unlock, _w_popup.bind("tool_lamp"), _s_shot.bind("e1_popup_tool"), _s_close_all, _s_hand, _s_shot.bind("e1_hand_unlocked"),
		_s_chron, _s_shot.bind("e1_chronicle_card"), _s_end]


func v() -> Village:
	return scene.village


func d() -> StageDirector:
	return scene.director


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	print("saved %s %s (연출 %s %.1f초)" % [name, img.get_size(), d().id, d().t])


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.refresh()


func _look(p: Vector2, ppu := 16.0) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


## 병 시간을 흘림
func _run(secs: float) -> void:
	var vv := v()
	vv.water.offline = true
	scene.world.advance(secs)
	vv.water.offline = false
	scene._sync_views()


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(390, 844)
		return false
	if _until.is_valid():
		_guard += 1
		if not bool(_until.call()) and _guard < 2400:
			return false
		_until = Callable()
		_wait = 2
	if _wait > 0:
		_wait -= 1
		return false
	if si >= steps.size():
		return true
	var w: Variant = (steps[si] as Callable).call()
	si += 1
	_wait = int(w) if w != null else 4
	return false


func _s_start() -> int:
	scene.paused = true                 # 병 시계는 멈추고 (같은 결과) — 연출·화면은 그대로 흐름
	scene.set_debug_mode(false)
	_run(1.6 * Balance.HOUR)
	_look(v().fire + Vector2(0.0, 2.0))
	_settle()
	return 20


func _s_awaken() -> int:
	Awakening.awaken(v())
	scene._sync_views()
	return 1


## 연출이 t초가 될 때까지
func _w_dir(secs: float) -> int:
	_guard = 0
	_until = func() -> bool: return d().playing() and d().t >= secs * d().k
	return 0


func _w_end() -> int:
	_guard = 0
	_until = func() -> bool: return not d().playing() or d().id == "altar_build"
	return 0


func _w_pray() -> int:
	_guard = 0
	_until = func() -> bool: return d().playing() and d().id == "first_prayer" and d().t >= 0.9 * d().k
	return 0


func _w_popup(id: String) -> int:
	_guard = 0
	_until = func() -> bool:
		var pop: FirstPopup = scene.first_popup
		return pop.showing() and pop.id == id and pop.modulate.a >= 0.99
	return 0


func _s_shot(name: String) -> int:
	_save(name)
	return 2


## 제단 짓기: 그 진행까지 (짓는 사람들이 돌을 안고 오가는 모습 — 병 시간을 조금 흘림)
func _s_build(f: float) -> int:
	var b := Awakening.altar_site(v())
	if b == null:
		print("제단 터 없음")
		return 2
	_run(40.0)
	b.prog = float(Balance.B[Awakening.ALTAR]["time"]) * f
	var n := 0
	for r in v().people:
		if r.carry == "돌":
			n += 1
	print("altar f=%.2f stage %d · 돌을 든 사람 %d · 연출 %s" % [f, scene.view.altar_view.stage(), n, d().id])
	scene._sync_views()
	return 30


func _s_built() -> int:
	var b := Awakening.altar_site(v())
	b.prog = float(Balance.B[Awakening.ALTAR]["time"])
	v().on_built(b)
	scene.paused = false                # 첫 기도: 병 시계를 흘려 (연출의 느린 빠르기) 사람들이 제단 둘레로 걸어오게
	scene._sync_views()
	return 1


func _s_close_popup() -> int:
	(scene.first_popup as FirstPopup).close()
	return 4


func _s_close_all() -> int:
	(scene.first_popup as FirstPopup).close()
	scene.close_sheets()
	return 6


func _s_hand() -> int:
	scene.close_sheets()
	scene.toggle_hand()
	return 12


## 첫 추위 → [감싸기]가 열림 (+ 첫 밭이 마름 → [물 뿌리기])
func _s_unlock() -> int:
	scene.close_sheets()
	Firsts.unlock("spray")
	Firsts.take("tool_spray")
	v().people[1].cold = 0.6
	Firsts.check(v())
	return 2


func _s_chron() -> int:
	scene.close_sheets()
	scene.open_chronicle(0)
	return 20


func _s_end() -> bool:
	Sheet.make(shots, out_dir.path_join("e1_sheet.png"), 0.5)
	print("saved e1_sheet")
	quit()
	return true
