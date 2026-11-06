## A4b 깨달음 · A5 계시 · A10 연대기 · 하늘 낟알 · 새 제단 캡처 (390×844 — 넓은 세상 world.tscn, 시드 20261106, 기본 확대).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_era.gd
## 결과 (godot_shots/): manna_fall · awakening_1_tap · awakening_2_blow · awakening_3_beam · altar_build_1 · altar_build_2 · altar_after ·
##   era_offered · era_offered_sheet · era_sequence · era_after · chronicle_recent · chronicle_myth · chronicle_people · chronicle_codex · era_sheet (모아 보기)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var _wait := 0
var shots: PackedStringArray = []
var steps: Array[Callable] = []
var si := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	Market.reset(650.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	steps = [_s_start, _s_manna, _s_shot.bind("manna_fall"), _s_guide_tap, _s_shot.bind("awakening_1_tap"), _s_after_tap,
		_s_shot.bind("awakening_2_blow"), _s_blow_and_wait, _s_beam, _s_shot.bind("awakening_3_beam"), _s_finish_show, _s_build_mid,
		_s_shot.bind("altar_build_1"), _s_close, _s_shot.bind("altar_build_close"), _s_build_done, _s_shot.bind("altar_build_2"), _s_evening, _s_shot.bind("altar_after"),
		_s_era_full, _s_shot.bind("era_offered"), _s_era_sheet, _s_shot.bind("era_offered_sheet"), _s_era_go,
		_s_shot.bind("era_sequence"), _s_era_after, _s_shot.bind("era_after"), _s_chron.bind(0), _s_shot.bind("chronicle_recent"),
		_s_chron.bind(1), _s_shot.bind("chronicle_myth"), _s_people, _s_shot.bind("chronicle_people"), _s_chron.bind(3),
		_s_shot.bind("chronicle_codex"), _s_end]


func v() -> Village:
	return scene.village


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	print("saved %s %s" % [name, img.get_size()])


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


## 병 시간을 흘림 (화면은 멈춘 채 — 캡처마다 같은 결과)
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
	scene.paused = true
	scene.set_debug_mode(false)
	print("aware %s altar %s" % [v().aware, v().altar_built])
	v().guide = {"on": true}
	_look(v().center + Vector2(0.5, 3.0), 13.0)
	_settle()
	return 10


## 도착 직후 하늘 낟알 (Balance.MANNA_DELAY 3초) — 쏟아지는 중간에
func _s_manna() -> int:
	_run(4.0)
	scene.refresh()
	return 70


func _s_shot(name: String) -> int:
	_save(name)
	if name == "manna_fall":
		scene.view.manna_fx.stop()
	if name in ["awakening_3_beam", "era_sequence"]:      # 캡처는 몇 화면만에 넘어가므로 빛기둥(현실 초)을 여기서 거둔다
		for n in scene.jar.get_children():
			if n is SkyBeam:
				n.queue_free()
	return 2


## 2분쯤 (병 24분): 안내 자막 ① 유리 톡
func _s_guide_tap() -> int:
	_run(GuideCaption.TAP_AT - v().t + 30.0)
	_look(v().fire + Vector2(0.0, 2.0))
	_settle()
	return 30


func _s_after_tap() -> int:
	scene.tap_glass(false)
	_run(40.0)
	_settle()
	return 30


func _s_blow_and_wait() -> int:
	scene.toggle_lid()
	scene.blow()
	_run(30.0)
	scene.toggle_lid()
	var guard := 0
	while not v().aware and guard < 400:
		_run(10.0)
		guard += 1
	print("awakened t=%.0f (%s)" % [v().t, v().fmt_time(v().t)])
	_settle()
	return 4


func _s_beam() -> int:
	_look(v().altar_pos + Vector2(0.6, 2.2))
	_settle()
	return 110


func _s_finish_show() -> int:
	scene.rev_show.finish()
	return 2


func _s_build_mid() -> int:
	var b := Awakening.altar_site(v())
	var guard := 0
	while b != null and b.prog < float(Balance.B["제단"]["time"]) * 0.55 and guard < 500:
		_run(10.0)
		guard += 1
	var av: AltarView = scene.view.altar_view
	print("altar prog %.0f · altar %s fire %s · view %s · body %d · vis %s" % [b.prog if b != null else -1.0, v().altar_pos, v().fire, av.global_position, av._body.get_child_count(), av.is_visible_in_tree()])
	_settle()
	return 20


func _s_close() -> int:
	_look(v().altar_pos + Vector2(0.3, 1.0), 44.0)
	_settle()
	return 20


func _s_build_done() -> int:
	var guard := 0
	while not v().altar_built and guard < 800:
		_run(10.0)
		guard += 1
	_run(60.0)
	print("altar built %s items %s" % [v().altar_built, v().altar_items()])
	_settle()
	return 20


## 첫 저녁 기도 뒤 (제물이 쌓인 제단 + 빛) — 기본 확대
func _s_evening() -> int:
	var to := 20.5 * 3600.0
	var c := fmod(v().start_clock + v().t, Balance.DAY)
	_run(fposmod(to - c, Balance.DAY))
	_look(v().altar_pos + Vector2(0.6, 2.4))
	_settle()
	return 20


## 시대 점수를 채워 [계시]를 띄움 (캡처용)
func _s_era_full() -> int:
	var tm := fmod(v().start_clock + v().t, Balance.DAY)
	_run(fposmod(10.0 * 3600.0 - tm, Balance.DAY))     # 다음 날 아침
	v().era_pts = Balance.ERA_NEED[v().era]
	_run(2.0)
	print("revelation %s" % str(v().revelation))
	_look(v().fire + Vector2(0.0, 2.0))
	_settle()
	return 30


func _s_era_sheet() -> int:
	scene.open_altar()
	return 20


func _s_era_go() -> int:
	scene.altar_sheet._on_reveal()
	return 120


func _s_era_after() -> int:
	scene.rev_show.finish()
	print("era %d · %s" % [v().era, v().book.slice(-3).map(func(e: Dictionary) -> String: return e["text"])])
	_run(7.0 * 3600.0)
	var n := 0
	for b in v().buildings:
		if b.type == "목조주택" or b.upgrade_to == "목조주택":
			n += 1
	print("목조주택 %d" % n)
	_look(v().center + Vector2(0.0, 3.0), 12.0)
	_settle()
	return 20


func _s_chron(tab: int) -> int:
	scene.open_chronicle(tab)
	return 12


## 사람들 탭: 잠든 사람 · 분가로 떠난 사람이 보이게 (캡처용 — 노인 한 명 노환, 분가 한 번)
func _s_people() -> int:
	var vv := v()
	var old: Resident = null
	for r in vv.people:
		if old == null or r.age > old.age:
			old = r
	if old != null:
		vv.kill(old, "노환")
	var sp: Variant = scene.world.split_spot(vv)
	if sp != null:
		var nv: Village = scene.world.split_out(vv, (sp as Vector2).x, (sp as Vector2).y)
		print("split %s" % (str(nv.people.size()) if nv != null else "none"))
	vv.note_discovery("salt", vv.people[0])
	vv.salt_known = true
	scene._sync_views()
	scene.open_chronicle(2)
	return 12


func _s_end() -> bool:
	Sheet.make(shots, out_dir.path_join("era_sheet.png"), 0.5)
	print("saved era_sheet")
	quit()
	return true
