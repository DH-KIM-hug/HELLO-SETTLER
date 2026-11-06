## 이주민 뽑기 캡처 — ROADMAP B2 (기획서 11.2 · SHOP 2.6 · UI 06).
## 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_immigrant.gd
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트를 2일차 아침까지 돌린 뒤 (지폐 2,400) — 390×844:
##   immigrant_card.png (상점 '이주민' 탭 — 값 · 오늘 남은 횟수 · [확률 보기]) · immigrant_odds.png (공개 확률 창) ·
##   immigrant_drop.png (손에 든 뗏목 꾸러미 + 마을 어귀 그림자) · immigrant_arrival.png (내려앉은 가족과 마을 사람들의 맞이 말)
extends SceneTree

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var v: Village
var p := Vector2.ZERO


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Market.reset(2400.0)
	Market.mig_seed = 31                  # 캡처마다 같은 사람들 — 첫 꾸러미가 셋 이상 가족인 seed
	while Immigrants.roll(hash([Market.mig_seed, 1, Immigrants.SEED_SALT])).size() < 3:
		Market.mig_seed += 1
	Village.start_aware = true
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	img.save_png(path)
	print("saved %s %s" % [name, img.get_size()])


func _settle() -> void:
	scene.clock.notice_t = 0.0
	if v != null:
		v.warnings.clear()
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _look(q: Vector2, ppu: float) -> void:
	scene.look_at_ground(q)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _screen(q: Vector2) -> Vector2:
	var r := q.rotated(PI * 0.5 * scene._rot_shown)
	return scene.cam.camera.unproject_position(Vector3(r.x, scene.terrain.ground_y(q.x, q.y), r.y))


## 마을 어귀 (모닥불에서 조금 떨어진 빈 땅)
func _gate(q: Village) -> Vector2:
	for rr in range(6, 30):
		for i in 24:
			var s := q.center + Vector2(cos(TAU * i / 24.0 + 0.2), sin(TAU * i / 24.0 + 0.2)) * rr
			var pv := SkyDrops.preview(q, Immigrants.ITEM, s)
			if bool(pv["ok"]) and q.is_free(s.x, s.y, 1.5):
				return s
	return q.center + Vector2(7, 7)


func _process(_dt: float) -> bool:
	frame += 1
	if _wait > 0:
		_wait -= 1
		return false
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(390, 844)
				return false
			v = scene.village
			v.water.offline = true
			scene.world.advance(25.0 * 3600.0)           # 2일차 08:00
			v.water.offline = false
			scene.paused = true
			scene.set_debug_mode(false)
			Shop.update_unlocks(v)
			_look(v.center + Vector2(1.0, 2.0), 16.0)
			_wait = 20
		1:
			_settle()
			scene.open_shop()
			scene.shop_sheet.select_tab("이주민")
			_wait = 14
		2:
			_save("immigrant_card")
			scene.shop_sheet.show_odds()
			_wait = 8
		3:
			_save("immigrant_odds")
			scene.shop_sheet.hide_odds()
			scene.shop_sheet.press(Immigrants.ITEM)
			scene.shop_sheet.close()
			p = _gate(v)
			_look(p + Vector2(0.0, 2.0), 22.0)
			_wait = 6
		4:
			_settle()
			scene.start_drop(int(Market.hand[0]["id"]))
			scene.hand_ctl.aim_at(_screen(p), false)
			_wait = 10
		5:
			_save("immigrant_drop")
			scene.hand_ctl.confirm_drop()
			scene.paused = false
			_wait = 70                                     # 손이 올라가고 사람들이 둘러봄
		6:
			scene.paused = true
			for q in v.people:                             # 맞이 말이 보이게 (내려앉은 가족 둘레)
				if Vector2(q.x, q.y).distance_to(p) < 12.0 and q.say != "":
					q.say_t = maxf(q.say_t, 6.0)
			print("연대기: %s" % v.book[v.book.size() - 1]["text"])
			_look(p + Vector2(0.0, 1.0), 30.0)
			_wait = 6
		7:
			_settle()
			_wait = 8
		8:
			_save("immigrant_arrival")
			return true
	step += 1
	return false
