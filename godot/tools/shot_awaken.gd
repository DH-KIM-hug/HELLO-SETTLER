## E1-1 깨달음 (EVENTS_STAGING 1 — 2026-11-08 극적인 판) 캡처 (390×844 — 넓은 세상 world.tscn, 시드 20261106).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_awaken.gd   (움직임 줄이기 판: ... -- reduce)
## 결과 (godot_shots/): aw_0_hint (조짐 — 경이가 찬 아이의 하늘 이야기) · aw_1_hush (세상이 멈춤) · aw_2_dark (어두워지고 큰 그림자) ·
##   aw_3_shadow (그림자가 마을 위를 지나감) · aw_4_pillar (빛기둥 · 선물이 내려옴) · aw_5_gift (선물이 닿음) · aw_6_kneel (한 사람씩 무릎 · 우는 사람 ·
##   안는 사람 · 서 있는 사람 · 노인의 부르는 말) · aw_7_page (화면 가득 연대기 한 쪽) · aw_8_after (끝난 뒤) · aw_sheet (모아 보기) ·
##   aw_strip (2초마다 한 장 — 장면 띠)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var _wait := 0
var shots: PackedStringArray = []
var strip: PackedStringArray = []
var steps: Array = []
var si := 0
var _until: Callable = Callable()
var _guard := 0
var _next_strip := 0.0
var reduce := false


func _initialize() -> void:
	reduce = "reduce" in OS.get_cmdline_user_args()
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Market.reset(650.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	scene.firsts.reset()
	if reduce:                          # 설정 '움직임 줄이기'(A26)가 생기면 그 값 — 지금은 JarCamera.reduce_motion()이 읽는 이름으로 덧붙여 둠
		GameSettings.get_current().set_meta("reduce_motion", true)
	var p := "aw_rm_" if reduce else "aw_"
	steps = [_s_start, _s_hint, _s_shot.bind(p + "0_hint"), _s_awaken, _w_dir.bind(1.3), _s_shot.bind(p + "1_hush"),
		_w_dir.bind(5.2), _s_shot.bind(p + "2_dark"), _w_dir.bind(7.8), _s_shot.bind(p + "3_shadow"),
		_w_dir.bind(12.6), _s_shot.bind(p + "4_pillar"), _w_dir.bind(15.9), _s_shot.bind(p + "5_gift"),
		_w_dir.bind(19.2), _s_shot.bind(p + "6_kneel"), _w_dir.bind(22.4), _s_shot.bind(p + "7_page"),
		_w_end, _s_shot.bind(p + "8_after"), _s_end]


func v() -> Village:
	return scene.village


func d() -> StageDirector:
	return scene.director


func _save(name: String, list := true) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	if list:
		shots.append(p)
	else:
		strip.append(p)
	print("saved %s %s (연출 %s %.1f초 · 어둠 %.2f · 그림자 %s · 카메라 %s · post %s)" % [name, img.get_size(), d().id, d().t, d().dark, str(d().shadow_param()),
		str(scene.cam.target), str(scene.post_mat.get_shader_parameter("stage_shadow"))])


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
	# 장면 띠: 연출 동안 2초마다 한 장
	if d() != null and d().playing() and d().id == "awakening" and d().t >= _next_strip:
		_save("%sstrip_%02d" % ["aw_rm_" if reduce else "aw_", int(roundf(_next_strip))], false)
		_next_strip += 2.0
	if _until.is_valid():
		_guard += 1
		if not bool(_until.call()) and _guard < 4000:
			return false
		_until = Callable()
		_wait = 1
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


## 조짐: 경이가 거의 찬 병 — 아이 하나가 하늘 이야기 (화면만). 그 아이 곁으로
func _s_hint() -> int:
	v().wonder = Awakening.WONDER_NEED * 0.95
	var vw: VillageView = scene.view
	vw._hint_t = 0.0
	vw._wonder_hints(0.01)
	if not vw.hint_log.is_empty():
		var r := v().person(int(vw.hint_log[vw.hint_log.size() - 1][1]))
		if r != null:
			_look(Vector2(r.x, r.y) + Vector2(0.0, 1.5), 22.0)
			_settle()
		print("조짐: %s" % str(vw.hint_log))
	return 24


func _s_awaken() -> int:
	_look(v().fire + Vector2(0.0, 2.0))
	_settle()
	Awakening.awaken(v())
	scene._sync_views()
	return 1


func _w_dir(secs: float) -> int:
	_guard = 0
	_until = func() -> bool: return d().playing() and d().t >= secs * d().k
	return 0


func _w_end() -> int:
	_guard = 0
	_until = func() -> bool: return not d().playing() or d().id != "awakening"
	return 0


func _s_shot(name: String) -> int:
	_save(name)
	return 1


func _s_end() -> bool:
	var p := "aw_rm_" if reduce else "aw_"
	Sheet.make(shots, out_dir.path_join(p + "sheet.png"), 0.5)
	Sheet.make(strip, out_dir.path_join(p + "strip.png"), 0.4)
	print("saved %ssheet · %sstrip (%d장)" % [p, p, strip.size()])
	quit()
	return true
