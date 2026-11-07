## UI 10 설정·문의 + 휴대폰 다듬기 캡처 — docs/UI.md 화면 10 · "10 문의하기 (v1)".
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_ui10.gd
## 넓은 세상(world.tscn, 시드 20261106, '힘센 가족' 키트). 노치·제스처 막대는 가짜 안전 영역(위 28 · 아래 16)으로 흉내.
## 결과 (godot_shots/): ui10_main.png (390×844 — 위 띠·아래 띠, 개발 모드 꺼짐) · ui10_settings.png (설정) · ui10_inquiry.png (문의하기) ·
##   ui10_toast.png (메일 앱이 없을 때 토스트) · ui10_debug.png (톱니 길게 누름 → 개발 모드) · ui10_tree.png (주민 상세 가계도 — 손가락으로 끌어 스크롤) ·
##   ui10_phone_9x20.png (540×1200 = 1080×2400과 같은 9:20 · UI 360×800, 뚜껑 열림 → 불기 보임) · ui10_sheet.png
## 손가락 확인 (마우스로 손가락 흉내 — Input.emulate_touch_from_mouse): 한 손가락 끌기 이동이 한 번만 걸리는지 · 시트 버튼 누르기가 화면(유리 톡)으로 새지 않는지 ·
##   가계도 칸 위에서 끌어도 스크롤되는지 (결과는 출력 줄 'touch check').
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var _t0 := Vector3.ZERO
var _taps0 := 0
var _scroll0 := 0
var _who_open := -1
var _presses := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_settings.cfg"       # 캡처가 진짜 설정 파일을 건드리지 않게
	Inquiry.id_path = "user://shot_install_id.cfg"
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.kit_variant = "힘센 가족"
	root.add_child(scene)


func _who(n: String) -> Resident:
	for r: Resident in scene.village.people:
		if r.name == n:
			return r
	return null


func _ghost(v: Village, n: String, sex: String, age: float, why: String) -> Resident:
	var r := Resident.new()
	r.id = v.next_id
	v.next_id += 1
	r.name = n
	r.sex = sex
	r.age = age
	r.dead = true
	r.death_t = v.t - 3.0 * Balance.DAY
	r.death_why = why
	r.genes = Genetics.random_genes(v.gene_rng, false)
	v.dead.append(r)
	return r


## 가계도가 시트보다 길게 (shot_ui03과 같은 꾸밈 — 이 캡처에서만)
func _family() -> void:
	var v: Village = scene.village
	var hans := _who("한스")
	var marta := _who("마르타")
	var lina := _who("리나")
	var karl := _who("카를")
	var bern := _who("베른")
	var gf := _ghost(v, "아달베르트", "m", 26.0, "노환")
	var gm := _ghost(v, "힐데", "f", 19.0, "병")
	var gm2 := _ghost(v, "로테", "f", 15.0, "굶주림")
	hans.parents = PackedInt32Array([gf.id, gm.id])
	marta.parents = PackedInt32Array([bern.id, gm2.id])
	lina.age = 9.5
	karl.age = 10.0
	if karl.partner >= 0 and v.person(karl.partner) != null:
		v.person(karl.partner).partner = -1
	v.marry(lina, karl)
	for nm: String in ["미아", "요나", "엘사"]:
		var baby := v.add_person(nm, "f" if nm != "요나" else "m", 0.6, "", lina.x + 0.6, lina.y, lina, karl)
		baby.parents = PackedInt32Array([lina.id, karl.id])
	scene.view.sync(0.0, true)


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
	scene.view.sync(0.0, true)


## 마우스 사건을 Input으로 (emulate_touch_from_mouse가 켜져 있으면 손가락 사건도 함께 생김) — 창 좌표
func _mouse(pos: Vector2, kind: int, rel := Vector2.ZERO) -> void:
	var k := root.get_final_transform()           # UI 좌표 → 창 좌표
	var wp: Vector2 = k * pos
	if kind == 2:
		var mm := InputEventMouseMotion.new()
		mm.position = wp
		mm.global_position = wp
		mm.relative = k.basis_xform(rel)
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mm)
		return
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = kind == 1
	m.position = wp
	m.global_position = wp
	m.button_mask = MOUSE_BUTTON_MASK_LEFT if kind == 1 else 0
	Input.parse_input_event(m)


func _center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	var vs: Vector2 = root.get_visible_rect().size
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(390, 844)
				return false
			scene.village.water.offline = true
			scene.world.advance(3.0 * 3600.0)
			scene.village.water.offline = false
			scene.paused = true
			scene.set_process_unhandled_input(false)       # 캡처 중 창 위의 진짜 마우스가 장면을 건드리지 않게
			scene.set_debug_mode(false)
			scene.cam.ppu = 26.0
			scene.cam.ppu_goal = 26.0
			scene.layout_bars()
			_family()
			_wait = 20
		1:
			_settle()
			_wait = 6
		2:
			_save("ui10_main")
			print("bars: top %.0f px · bottom %.0f px · view %s" % [scene.top_h, scene.bottom_h, str(vs)])
			scene.settings_sheet.open()
			_wait = 8
		3:
			_save("ui10_settings")
			scene.settings_sheet.show_page("inquiry")
			_wait = 6
		4:
			_save("ui10_inquiry")
			print("mailto: %s" % Inquiry.mailto(scene.settings_sheet.kind, scene.settings_sheet.current_info()).left(160))
			scene.settings_sheet.pick_kind("제안")
			scene.settings_sheet.show_toast(Inquiry.FAIL_TOAST)      # (shell_open은 부르지 않음 — 캡처가 메일 앱을 열지 않게)
			_wait = 6
		5:
			_save("ui10_toast")
			scene.settings_sheet.close()
			# ── 손가락 확인 1: 시트 버튼 누르기가 화면으로 새지 않음 (제단 시트 [닫기] 말고 [모두 받기] 자리에 톡)
			Input.emulate_touch_from_mouse = true
			scene.set_process_unhandled_input(true)
			_taps0 = int(scene.village._taps[1])
			scene.settings_sheet.open()
			_wait = 10
		6:
			var tb: Button = scene.settings_sheet.toggles["music"]
			tb.pressed.connect(func() -> void: _presses += 1)
			_mouse(_center(tb), 1)
			_wait = 2
		7:
			_mouse(_center(scene.settings_sheet.toggles["music"]), 0)
			_wait = 3
		8:
			var leaked := int(scene.village._taps[1]) - _taps0
			print("touch check: 시트 버튼 톡 → 버튼 눌림 %d번 (1이어야 함) · 음악 %s · 화면으로 샌 톡 %d (0이어야 함) · 상세 열림 %s" % [
				_presses, "꺼짐" if not GameSettings.get_current().music else "켜짐", leaked, str(scene.detail.visible)])
			scene.settings_sheet.close()
			# ── 손가락 확인 2: 한 손가락 끌기 = 한 번만 이동
			_t0 = scene.cam.target
			_mouse(vs * 0.5, 1)
			_wait = 1
		9, 10, 11, 12, 13:
			_mouse(vs * 0.5 + Vector2(0, -12) * (step - 8), 2, Vector2(0, -12))
			_wait = 1
		14:
			_mouse(vs * 0.5 + Vector2(0, -60), 0)
			_wait = 2
		15:
			var got: Vector3 = scene.cam.target
			scene.cam.target = _t0
			scene.cam.pan_pixels(Vector2(0, -60))
			var want: Vector3 = scene.cam.target
			var taps := int(scene.village._taps[1]) - _taps0
			print("touch check: 끌기 60px → 움직인 거리 %.2f · 한 번 걸었을 때 %.2f (같아야 함 — 두 번이면 2배) · 끌기 뒤 유리 톡 %d (0이어야 함)" % [
				Vector2(got.x - _t0.x, got.z - _t0.z).length(), Vector2(want.x - _t0.x, want.z - _t0.z).length(), taps])
			scene.cam.target = _t0
			scene.cam._apply()
			# ── 빈 곳 톡 = 유리 톡 한 번
			_taps0 = int(scene.village._taps[1])
			_mouse(Vector2(vs.x * 0.15, vs.y * 0.3), 1)
			_wait = 1
		16:
			_mouse(Vector2(vs.x * 0.15, vs.y * 0.3), 0)
			_wait = 2
		17:
			print("touch check: 빈 곳 톡 → 유리 톡 %d (1이어야 함, 주민이 있으면 상세 %s)" % [int(scene.village._taps[1]) - _taps0, str(scene.detail.visible)])
			scene.detail.close()
			# ── 가계도: 리나 상세 → 가계도 칸 위에서 끌어 스크롤
			scene.detail.open(_who("리나"))
			_who_open = _who("리나").id
			_wait = 10
		18:
			var d: ResidentDetail = scene.detail
			d.scroll.scroll_vertical = int(d.tree_section.position.y) - 20
			_wait = 4
		19:
			var d: ResidentDetail = scene.detail
			_scroll0 = d.scroll.scroll_vertical
			var node: Control = d.tree_box.get_child(1).get_child(0)     # 조부모 줄의 첫 칸
			_t0 = Vector3(_center(node).x, _center(node).y, 0)
			_mouse(_center(node), 1)
			_wait = 1
		20, 21, 22, 23, 24, 25:
			_mouse(Vector2(_t0.x, _t0.y) + Vector2(0, -20) * (step - 19), 2, Vector2(0, -20))
			_wait = 1
		26:
			_mouse(Vector2(_t0.x, _t0.y) + Vector2(0, -120), 0)
			_wait = 6
		27:
			var d: ResidentDetail = scene.detail
			print("touch check: 가계도 칸 위 끌기 → 스크롤 %d → %d (최대 %d) · 보는 사람 그대로 %s (끌기가 칸 누르기로 새지 않음)" % [
				_scroll0, d.scroll.scroll_vertical, int(d.scroll.get_v_scroll_bar().max_value - d.scroll.size.y), str(d.r != null and d.r.id == _who_open)])
			Input.emulate_touch_from_mouse = false
			scene.set_process_unhandled_input(false)
			_save("ui10_tree")
			scene.detail.close()
			scene.set_debug_mode(true)               # (톱니 길게 누르기와 같음)
			_wait = 4
		28:
			_save("ui10_debug")
			scene.set_debug_mode(false)
			scene.toggle_lid()
			root.size = Vector2i(540, 1200)          # 1080×2400과 같은 9:20 (창이 화면보다 클 수 없어 절반 — UI 좌표는 똑같이 360×800)
			_wait = 20
		29:
			scene.layout_bars()
			_settle()
			_wait = 6
		30:
			_save("ui10_phone_9x20")
			print("9:20 (1080×2400 비율) → UI %s · 아래 띠 버튼: %s" % [str(vs), ", ".join(PackedStringArray([scene.hand_btn.text, scene.speed_btn.text]))])
			var small: PackedStringArray = shots.slice(0, shots.size() - 1)
			Sheet.make(small, out_dir.path_join("ui10_sheet.png"), 1.0)
			print("saved ui10_sheet")
			for p: String in ["user://shot_settings.cfg", "user://shot_install_id.cfg"]:
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
			return true
	step += 1
	return false
