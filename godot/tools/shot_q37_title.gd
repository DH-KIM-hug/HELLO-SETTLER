## (Q37) 타이틀 · 선반의 병에도 그 병의 꾸미기 (받침 · 유리 빛깔 · 코르크 무늬 — 병 저장 요약의 "deco").
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_q37_title.gd
## 결과: godot_shots/deco_q37/q37_title.png (지금 병 = 받침 + 호박빛 + 밀랍) · q37_title_shelf.png (선반을 넓게: 왼쪽 병 · 지금 병 · 오른쪽 병)
## 저장은 user://shot_q37_title (진짜 저장을 건드리지 않음)
extends SceneTree

## [시드, 이름, 날, 시대, 받침, 빛깔, 코르크]
const WORLDS := [[20261106, "초록방울", 2.0, 1, true, "호박빛 유리", "밀랍 코르크"],
	[11, "도토리 공화국", 2.0, 2, false, "물빛 유리", "삼끈 코르크"],
	[5, "구름빵 나라", 1.5, 0, true, "이끼빛 유리", "불도장 코르크"]]
const DIR := "user://shot_q37_title"
var step := 0
var t := 0.0
var out_dir := ""
var inst: GameSave


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/deco_q37").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_q37t_settings.cfg"
	StartFlow.force_tod = "morning"
	GiantRoom.force_season = "summer"
	StartFlow.navigate = false
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	root.size = Vector2i(540, 1170)
	DisplayServer.window_set_size(Vector2i(540, 1170))
	if GameSave.get_instance() != null:
		GameSave.get_instance().enabled = false
	inst = GameSave.new()
	inst.enabled = false
	root.add_child(inst)
	var made: Array = []
	for w: Array in WORLDS:
		var jw := JarWorld.create(w[0], WorldCfg.SIZE)
		var sp: Array[Vector2] = jw.recommended_kit_spots()
		var v := jw.place_kit(sp[0].x, sp[0].y)
		v.water.offline = true
		jw.advance(float(w[2]) * Balance.DAY)
		v.water.offline = false
		v.era = maxi(v.era, int(w[3]))
		if bool(w[4]):
			JarDeco.attach(v, JarDeco.STAND)
		JarDeco.attach(v, String(w[5]))
		JarDeco.attach(v, String(w[6]))
		print("세상 %s · 꾸미기 %s" % [w[1], str(JarDeco.home(v).deco)])
		made.append(jw)
	_wipe(DIR)
	var sm := GameSave.new()
	sm.dir = DIR
	sm.start()
	for i in made.size():
		var jw: JarWorld = made[i]
		sm.register_jar(i + 1, jw.primary(), JarClock.new(jw.primary()), {"name": WORLDS[i][1]}, jw)
	sm.current = 2                                 # 지금 병 = 가운데 (왼쪽 1 · 오른쪽 3)
	sm.giant["first_jar_done"] = true
	sm.save_all(true)
	sm.stop()
	sm.free()
	inst.start()
	inst.unload()
	inst.dir = DIR
	change_scene_to_file(StartFlow.TITLE_SCENE)


func _wipe(dir: String) -> void:
	var p := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(p)
	for f in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved " + name)


func _process(dt: float) -> bool:
	t += dt
	if t < 1.8:
		return false
	match step:
		0:
			print("title info deco: %s" % str(current_scene.get("info").get("deco")))
			_save("q37_title")
			root.size = Vector2i(1600, 760)
			DisplayServer.window_set_size(Vector2i(1600, 760))
			var cam: JarCamera = current_scene.get("cam")
			cam.shelf_range = Vector2(-GiantRoom.SHELF_GAP, GiantRoom.SHELF_GAP)
			cam.shelf_pan = 0.0
			cam.set_ext_zoom(cam.ext_min())
			cam._apply()
			current_scene.get("ui").visible = false
			t = 0.0
		1:
			_save("q37_title_shelf")
			_wipe(DIR)
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_q37t_settings.cfg"))
			return true
	step += 1
	return false
