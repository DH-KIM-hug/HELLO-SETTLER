## 시작 흐름 끝까지 (실제 장면 바꾸기) — 회사 로고 → 타이틀 → 들어가는 연출 → 짧은 창조(이름) → 병 안 → 뒤로 가기 → 타이틀 [이어하기] → 병 안.
## 실행 (창이 필요): NAZAKJI_SAVE_DIR=user://shot_flow_save godot --path godot -s res://tools/shot_start_flow.gd
## (저장 폴더를 꼭 따로 — 진짜 저장을 건드리지 않게. 시작할 때 그 폴더를 비운다)
## 결과 (godot_shots/): start_flow_village_new · start_flow_back_confirm · start_flow_title_after · start_flow_village_continue
extends SceneTree

var step := 0
var st := 0.0
var out_dir := ""


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	SafeArea.fake = Vector2(28, 16)
	StartFlow.force_tod = "morning"
	GameSettings.path = "user://shot_settings.cfg"


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved %s" % name)


func _is(path: String) -> bool:
	return current_scene != null and current_scene.scene_file_path == path


func _next() -> void:
	step += 1
	st = 0.0


func _process(dt: float) -> bool:
	st += dt
	match step:
		0:
			var sm := GameSave.get_instance()
			if sm == null or not sm.dir.begins_with("user://shot"):
				push_error("NAZAKJI_SAVE_DIR=user://shot_flow_save 로 실행하세요 (진짜 저장 보호)")
				return true
			var da := DirAccess.open(ProjectSettings.globalize_path(sm.dir))
			if da != null:
				for f in da.get_files():
					da.remove(f)
			root.size = Vector2i(390, 844)
			change_scene_to_file(StartFlow.BOOT_SCENE)
			_next()
		1:
			if _is(StartFlow.TITLE_SCENE) and st > 1.0:
				print("title button: ", current_scene.get("button").text)
				current_scene.call("enter")
				_next()
		2:
			if _is(StartFlow.CREATION_SCENE) and st > 0.3:
				current_scene.call("jump", "name")
				current_scene.call("confirm_name", "테스트별")
				_next()
		3:
			if _is(StartFlow.GAME_SCENE) and st > 3.0:
				current_scene.call("set_debug_mode", false)
				_save("start_flow_village_new")
				current_scene.call("on_back")
				_next()
		4:
			if st > 0.3:
				_save("start_flow_back_confirm")
				(current_scene.get("confirm_sheet") as ConfirmSheet).answer(true)
				_next()
		5:
			if _is(StartFlow.TITLE_SCENE) and st > 1.5:
				_save("start_flow_title_after")
				print("title button: ", current_scene.get("button").text, " / ", current_scene.get("save_line").text)
				current_scene.call("enter")
				_next()
		6:
			if _is(StartFlow.GAME_SCENE) and st > 3.0:
				current_scene.call("set_debug_mode", false)
				_save("start_flow_village_continue")
				print("continue: entry ", current_scene.get("entry"), " use_save ", current_scene.get("use_save"))
				return true
	if st > 30.0:
		push_error("멈춤: 단계 %d" % step)
		return true
	return false
