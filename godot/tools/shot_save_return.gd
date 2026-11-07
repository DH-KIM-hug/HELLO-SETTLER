## 돌아왔을 때 캡처 — docs/SAVE.md 3 · 4. 마을을 하루 지켜본 뒤 거인이 이틀 반 자리를 비웠다가 돌아온 장면.
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_save_return.gd
## (2일 6시간 비움 → 등불 12시간만 흐르고 나머지는 잠듦 — "등불이 12시간 타고 꺼져 있었어요", SAVE.md 3 v1.1)
## 결과 (godot_shots/):
##   save_catchup.png — 돌아오자마자 펼친 편지 (따라잡는 도중 — "병 안의 시간이 흐르는 중…" + 가는 막대)
##   save_catchup_mid.png — 따라잡기가 반쯤 흘렀을 때 (큰 일이 한 줄씩 쓰인 편지)
##   save_return.png  — 촌장의 '자리를 비운 동안' 편지 (등불 줄 · 큰 일 · 인구 변화 · 새 얼굴/떠난 얼굴 ·
##                      기다리는 것: 비운 동안 쌓인 제물 + 장터 값 + [모두 받기] · 단추 둘)
##   save_festival.png — 편지를 닫은 뒤 귀환 축제: 광장(모닥불)에 모여 하늘을 보는 주민들
extends SceneTree

const AWAY := 2.25 * 86400.0

var scene: Node
var frame := 0
var step := 0
var out_dir := ""
var _mid := false


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	scene = load("res://scenes/test_village.tscn").instantiate()
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	print("saved %s %s" % [p, img.get_size()])


func _process(_d: float) -> bool:
	frame += 1
	match step:
		0:
			if frame == 5:
				scene.set_debug_mode(false)
				var v: Village = scene.village
				v.water.offline = true
				v.advance(1.2 * Balance.DAY)          # 하루 남짓 지켜봄 (집·밭이 서고 아이가 태어남)
				v.water.offline = false
				for r in v.people:
					r.say_t = 0.0
				scene.refresh()
				scene.begin_return([CatchUp.new(v, AWAY)], AWAY)
				step = 1
				frame = 0
		1:
			if frame == 3:
				_save("save_catchup")
			if not _mid and scene.catchup_screen != null and (scene.catchup_screen.jobs[0] as CatchUp).progress() >= 0.6:
				_mid = true
				_save("save_catchup_mid")
			if not scene.catching and scene.return_letter != null and scene.return_letter.visible:
				step = 2
				frame = 0
		2:
			if frame == 60:                        # 등불 줄이 다 떠오른 뒤 (0.8초)
				_save("save_return")
				scene.return_letter.close()
				step = 3
				frame = 0
		3:
			if frame == 1:
				var v: Village = scene.village
				scene.cam.set_zoom(2)
				scene.look_at_ground(v.fire)
				for i in 600:                      # 광장으로 모여드는 걸음 (병 시간 약 1분 반)
					scene.clock.tick(1.0 / 60.0 * 8.0)
			if frame == 40:
				_save("save_festival")
				quit(0)
	return false
