## 타이틀·선반 병 미리보기 캡처 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_title_preview.gd
## 결과 (godot_shots/):
##   title_empty.png — 저장도 만들던 병도 없을 때: 빈 유리병 (코르크만)
##   title_preview_a.png · title_preview_b.png — 서로 다른 두 세상을 저장한 뒤 [이어하기] 타이틀 (병 안 = 그 세상의 미리보기)
##   title_preview_a_map.png · title_preview_b_map.png — 같은 세상의 위에서 본 지도 (WorldMap — 비교용)
##   shelf_previews.png — 선반을 옆으로 밀어 병 셋 (미리보기 둘 + 사 둔 빈 병)
## 저장은 user://shot_title_preview_* (진짜 저장을 건드리지 않음)
extends SceneTree

const WORLDS := [[20261106, "초록방울", 2.0, 1], [11, "도토리 공화국", 2.0, 2], [5, "구름빵 나라", 1.5, 0]]
var step := 0
var t := 0.0
var out_dir := ""
var inst: GameSave
var maps: Array = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	SafeArea.fake = Vector2(28, 16)
	GameSettings.path = "user://shot_settings.cfg"
	StartFlow.force_tod = "morning"
	GiantRoom.force_season = "summer"
	StartFlow.navigate = false
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	root.size = Vector2i(390, 844)
	DisplayServer.window_set_size(Vector2i(390, 844))
	if GameSave.get_instance() != null:
		GameSave.get_instance().enabled = false
	inst = GameSave.new()                         # 타이틀이 읽는 저장 (GameSave.get_instance)
	inst.enabled = false
	root.add_child(inst)
	# 세상 셋을 만들어 저장 둘 (a = 지금 병 1 · b = 지금 병 2, 둘 다 선반에 병 셋 + 사 둔 빈 병)
	var made: Array = []
	for w: Array in WORLDS:
		var t0 := Time.get_ticks_msec()
		var jw := JarWorld.create(w[0], WorldCfg.SIZE)
		var sp: Array[Vector2] = jw.recommended_kit_spots()
		var v := jw.place_kit(sp[0].x, sp[0].y)
		v.water.offline = true
		jw.advance(float(w[2]) * Balance.DAY)
		v.water.offline = false
		v.era = maxi(v.era, int(w[3]))
		made.append(jw)
		print("세상 %s (%d ms)" % [w[1], Time.get_ticks_msec() - t0])
	for which: String in ["a", "b"]:
		var dir := "user://shot_title_preview_" + which
		_wipe(dir)
		var sm := GameSave.new()
		sm.dir = dir
		sm.start()
		for i in made.size():
			var jw: JarWorld = made[i]
			sm.register_jar(i + 1, jw.primary(), JarClock.new(jw.primary()), {"name": WORLDS[i][1]}, jw)
		sm.current = 1 if which == "a" else 2
		sm.giant["first_jar_done"] = true
		sm.giant["pending_jar"] = {"climate": "온대", "paid": 6000.0, "unix": 0.0}
		sm.save_all(true)
		sm.stop()
		sm.free()
	inst.start()                                  # 타이틀이 읽는 저장 = 자동 로드 (위의 sm.stop이 비워 둔 자리)
	for i in 2:
		var img := WorldMap.render((made[i] as JarWorld).water, 4, false, [{"p": (made[i] as JarWorld).primary().center, "c": Color.RED}])
		img.save_png(out_dir.path_join("title_preview_%s_map.png" % ["a", "b"][i]))
	_wipe("user://shot_title_preview_empty")
	_use("user://shot_title_preview_empty")


func _wipe(dir: String) -> void:
	var p := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(p)
	for f in DirAccess.get_files_at(p):
		DirAccess.remove_absolute(p.path_join(f))


func _use(dir: String) -> void:
	inst.unload()
	inst.dir = dir
	change_scene_to_file(StartFlow.TITLE_SCENE)
	t = 0.0


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved " + name)


func _process(dt: float) -> bool:
	t += dt
	if t < 1.6:
		return false
	match step:
		0:
			_save("title_empty")
			_use("user://shot_title_preview_a")
		1:
			_save("title_preview_a")
			_use("user://shot_title_preview_b")
		2:
			_save("title_preview_b")
			root.size = Vector2i(1600, 760)                # 선반을 넓게 (병 넷: 왼쪽 병 · 지금 병 · 오른쪽 병 · 사 둔 빈 병)
			DisplayServer.window_set_size(Vector2i(1600, 760))
			var cam: JarCamera = current_scene.get("cam")
			cam.shelf_range = Vector2(-GiantRoom.SHELF_GAP, 2.0 * GiantRoom.SHELF_GAP)
			cam.shelf_pan = GiantRoom.SHELF_GAP * 1.0
			cam.set_ext_zoom(cam.ext_min() + 0.0)
			cam._apply()
			current_scene.get("ui").visible = false
			t = 0.0
		3:
			_save("shelf_previews")
			return true
	step += 1
	return false
