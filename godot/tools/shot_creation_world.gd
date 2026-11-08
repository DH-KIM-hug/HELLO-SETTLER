## 창조 오프닝 8·9 캡처 (넓은 세상 장면) — 창이 필요: godot --path godot -s res://tools/shot_creation_world.gd
## 창조(연출 없이)로 세상을 만든 뒤 키트 자리 고르기 → 손이 상자를 내려놓음 → 주민 소개 → 이름 → 지구 카드.
## 결과 godot_shots/: create_8_pick · create_8_drop · create_8_meet · create_9_name · create_9_card
extends SceneTree

const SAVE_DIR := "user://shot_creation_save"
var c: Node
var s: Node
var out_dir := ""
var step := 0
var t := 0.0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	SafeArea.fake = Vector2(28, 16)
	StartFlow.navigate = false
	GameSettings.path = "user://shot_settings.cfg"
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	OS.set_environment("NAZAKJI_SAVE_DIR", SAVE_DIR)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _at(sec: float, dt: float) -> bool:
	return t >= sec and t - dt < sec


func _process(dt: float) -> bool:
	t += dt
	match step:
		0:
			root.size = Vector2i(390, 844)
			CreationPlan.clear(SAVE_DIR)
			StartFlow.plan = CreationPlan.make(20261107, 512)
			c = load(StartFlow.CREATION_SCENE).instantiate()
			c.set("instant", true)
			root.add_child(c)
			c.call("jump", "life")
			c.call("next")                  # 작은 생명이 깨어난 뒤 → 키트 자리
			root.remove_child(c)
			c.free()
			StartFlow.take()
			StartFlow.mode = "new"
			s = load(StartFlow.GAME_SCENE).instantiate()
			s.set("kit_anim", false)        # 스타터킷 풀기 연출·건물 놓기는 tools/shot_kit_unpack.gd (여기선 자동 배치로 바로 소개)
			root.add_child(s)
			t = 0.0
			step = 1
		1:
			if _at(1.0, dt):
				_save("create_8_pick")
				var ch: Array = s.world.spot_choices(5)
				s.choose_spot(ch[0]["p"])
			if _at(1.55, dt):
				_save("create_8_drop")
			if _at(5.5, dt):
				s.set_debug_mode(false)
			if _at(7.5, dt):
				_save("create_8_meet")
			if _at(8.0, dt):
				var arr: FirstArrival = s.arrival
				if arr != null:
					for i in 4:
						arr.meet_next()
			if _at(11.5, dt):
				_save("create_9_name")
				var arr: FirstArrival = s.arrival
				if arr != null:
					arr.confirm_name("초록방울")
			if _at(12.5, dt):
				_save("create_9_card")
				quit(0)
	return false
