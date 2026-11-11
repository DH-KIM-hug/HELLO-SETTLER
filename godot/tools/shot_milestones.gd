## 자람의 보상 (Q9) 캡처 — sim/milestones.gd · view/milestone_view.gd · view/ui/milestone_stamps.gd · view/ui/chronicle_sheet.gd.
## 실행 (창 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_milestones.gd [-- <크게 자른 확인용 그림을 둘 폴더>]
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트. 세로 화면 540×960. 화덕이 없으면 모닥불 곁 빈자리에 하나 세우고,
## 첫 빵 + 식구 열둘 고비를 넘긴 뒤 찍는다 (같은 날 고비 둘 → 그날 저녁 잔치는 '식구 열둘').
## 결과 (godot_shots/milestones/ — 2차 묶음 m2_*):
##   m2_strip_recent_none.png (연대기 '최근' 탭 — 도장 띠, 넘은 고비 없음) · m2_strip_people_two.png ('사람들' 탭 — 도장 둘) ·
##   m2_strip_myth_two.png ('창세 신화' 탭 맨 아래 수첩 장 — 옛 도장 줄이 없어진 자리) ·
##   m2_signpost_near.png · m2_signpost_far.png (마을 이름 표지판과 둘레의 꽃 — 가까이 44 · 멀리 20) ·
##   m2_signpost_flower.png (표지판 바로 앞·옆에 큰 꽃이 자란 경우 — 꽃 그림이 낮아져 표지판을 가리지 않음) ·
##   m2_feast_skip.png (아침 → 저녁 잔치 한가운데로 건너뛴 바로 뒤 2번째 화면) · m2_feast_near.png · m2_feast_far.png (해 질 녘 잔치) ·
##   m2_sheet.png (모아 보기)
## 저장 (2026-11-11 확인): 이 도구는 진짜 저장(user://save)을 읽지도 쓰지도 않는다 — 장면을 직접 띄우므로 저장을 쓰지 않는 병이고
##   (test_village.use_save = false), 그래도 틀리지 않게 저장 관리자를 끄고 폴더를 제 것(SAVE_DIR)으로 돌린다. 처음 겪는 일 안내 창의 대기 줄도
##   거인 묶음(저장 관리자의 player.firsts) 대신 이 도구만의 Firsts를 쓴다. 연대기 그림 카드(연출이 찍는 화면 — StageDirector)는
##   진짜 user://chron_pics 대신 SAVE_DIR/chron_pics에 적는다 (창이 있는 도구는 그 폴더에 j1_*.png를 남길 수 있었다).
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")
const SAVE_DIR := "user://shot_milestones_save"
const NEAR := 44.0
const FAR := 20.0
const DUSK := 20.3                                    # 해 질 녘 (Balance.DUSK_FROM 19.5 ~ NIGHT_FULL 21.5 사이, 잔치는 21:00까지)
const NAMES := ["다래", "솔이", "가람", "누리", "보람", "한결", "이슬", "마루", "새봄", "하늘이", "도담", "나래"]

var scene: Node
var out_dir := ""
var crop_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/milestones").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		crop_dir = String(args[0])
		DirAccess.make_dir_recursive_absolute(crop_dir)
	# 진짜 저장·설정을 건드리지 않게 (머리말 '저장')
	var sm := GameSave.get_instance()
	if sm != null:
		sm.enabled = false
		sm.dir = SAVE_DIR
	GameSettings.path = SAVE_DIR.path_join("settings.cfg")
	StoreStrip.cfg_path = SAVE_DIR.path_join("hud.cfg")
	Inquiry.id_path = SAVE_DIR.path_join("install_id.cfg")
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	scene.firsts = Firsts.new()                       # 거인 묶음의 대기 줄이 아니라 이 도구만의 것
	root.add_child(scene)
	if scene.director != null:
		scene.director.pic_dir = SAVE_DIR.path_join("chron_pics")


func _mv() -> MilestoneView:
	return MilestoneView.of(scene.view)


## 처음 겪는 일의 안내 창('이제 마을이 스스로 먹고살아요' 등)이 장면을 가리지 않게 — 기다리는 것을 비우고 닫는다 (이 도구만의 Firsts)
func _quiet() -> void:
	scene.firsts.queue.clear()
	if scene.first_popup != null and scene.first_popup.showing():
		scene.first_popup.close()


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	if not crop_dir.is_empty():                       # 가운데만 2배 (확인용 — 저장소 밖)
		var c := img.get_region(Rect2i(120, 300, 300, 360))
		c.resize(600, 720, Image.INTERPOLATE_LANCZOS)
		c.save_png(crop_dir.path_join(name + "_crop.png"))
	var v: Village = scene.village
	var fest := 0
	var play := 0
	var near := 0
	var anims := {}
	for q in v.people:
		if q.action == "festival":
			fest += 1
			play += 1 if q.anim == "play" else 0
			near += 1 if Vector2(q.x, q.y).distance_to(v.fire) <= MilestoneView.DANCE_R else 0
			anims[q.anim] = int(anims.get(q.anim, 0)) + 1
	if fest > 0:
		print("  몸짓: ", anims)
	print("saved %s %s · %.2f시 · ppu %.1f · 잔치 %s(%s) · 잔치 손님 %d (춤 몸짓 %d · 불 곁 %d) · 화면 춤 %d · fast %s" % [name, img.get_size(), v.hour_now(),
		scene.cam.ppu, Milestones.feast_on(v), Milestones.feast_id(v), fest, play, near, _mv().dancers(), scene.view.fast])


func _look(p: Vector2, ppu: float) -> void:
	scene.cam.stop_fly()
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _advance_to(hour: float) -> void:
	var v: Village = scene.village
	var dh := fposmod(hour - v.hour_now(), 24.0)
	v.water.offline = true
	scene.world.advance(dh * 3600.0)
	v.water.offline = false


## 화덕이 없으면 모닥불 곁 빈자리에 하나 (이미 있으면 그대로)
func _need_oven(v: Village) -> Building:
	var b := Milestones.oven(v)
	if b != null:
		return b
	for ring in [4.0, 5.0, 6.0, 7.0, 8.5]:
		for i in 16:
			var a := TAU * float(i) / 16.0 + 0.4
			var p := v.fire + Vector2(cos(a), sin(a)) * float(ring)
			if Milestones.spot_free(v, p) and Milestones.spot_free(v, p + Vector2(1.2, 1.2)) and Milestones.spot_free(v, p + Vector2(0.0, 1.6)):
				return v.add_building("화덕", p.x, p.y, true)
	return v.add_building("화덕", v.fire.x + 5.0, v.fire.y + 2.0, true)


## 첫 빵 + 식구 열둘 — 시험(tests/milestone_tests.gd)과 같은 길: 사건·통계를 넣고 마을이 스스로 알아차리게
func _reach(v: Village) -> void:
	var oven := _need_oven(v)
	var baker: Resident = null
	for p in v.people:
		if p.is_adult():
			baker = p
			break
	v.stock["빵"] = float(v.stock.get("빵", 0.0)) + 400.0
	v.emit(&"first_bread", {"who": baker.id, "v": {"b": oven.id}})
	v.stats["first_bread"] = 1
	var i := 0
	while v.people.size() < Milestones.POP_SMALL:
		v.add_person(NAMES[i % NAMES.size()], "f" if i % 2 == 0 else "m", 22.0 + float(i), "", v.fire.x + 1.5, v.fire.y - 1.0 + 0.3 * float(i), null, null)
		i += 1
	scene.world.advance(2.0)
	print("고비 기록: ", v.milestones.get("passed", {}))
	for b: Dictionary in v.book.slice(maxi(0, v.book.size() - 3)):
		print("  연대기: ", b["text"])


func _spot(id: String) -> Vector2:
	return MilestoneView.wanted(scene.village).get(id, scene.village.fire)


## 표지판 자리 둘레 (확인용 한 줄): 가장 가까운 꽃숲 덩이·바위·건물·무덤까지, 발길 값
func _sign_report(v: Village) -> void:
	var p := _spot("pop12")
	var tree := 1.0e9
	for tr: Dictionary in v.trees:
		tree = minf(tree, Vector2(float(tr["x"]), float(tr["y"])).distance_to(p))
	var rock := 1.0e9
	for r: Dictionary in v.rocks:
		rock = minf(rock, Vector2(float(r["x"]), float(r["y"])).distance_to(p))
	var bld := 1.0e9
	for b in v.buildings:
		bld = minf(bld, Vector2(b.x, b.y).distance_to(p) - b.size())
	var grave := 1.0e9
	for g: Dictionary in v.graves:
		grave = minf(grave, Vector2(float(g["x"]), float(g["y"])).distance_to(p))
	print("표지판 자리 (%.1f, %.1f) · 모닥불에서 %.1f칸 · 꽃숲 덩이 %.1f · 바위 %.1f · 건물 가장자리 %.1f · 무덤 %.1f · 발길 %.1f · 깨끗 %s · 화면이 아는 자리 %s" % [
		p.x, p.y, p.distance_to(v.fire), tree, rock, bld, grave, v.path_at(p.x, p.y), Milestones.spot_clear(v, p), scene.view.sign_spot])


func _process(_dt: float) -> bool:
	frame += 1
	if frame > 12:
		_quiet()
	if _wait > 0:
		_wait -= 1
		return false
	var v: Village = scene.village
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 960)
				return false
			scene.set_debug_mode(false)
			_advance_to(10.5)
			scene.paused = true
			_look(v.fire, 32.0)
			_settle()
			scene.chronicle.open(0)                   # 도장 띠 — 넘은 고비 없음, '최근' 탭
			_wait = 14
		1:
			_save("m2_strip_recent_none")
			_reach(v)
			scene.chronicle.open(2)                   # 도장 둘, '사람들' 탭
			_wait = 14
		2:
			_save("m2_strip_people_two")
			scene.chronicle.open(1)                   # '창세 신화' 탭 맨 아래 수첩 장 (옛 도장 줄이 있던 자리)
			_wait = 8
		3:
			var page := scene.chronicle.body.find_child("JarNotes", true, false) as Control
			if page != null:
				scene.chronicle.scroll.scroll_vertical = int(page.position.y) - 96
			_wait = 14
		4:
			_save("m2_strip_myth_two")
			scene.chronicle.close()
			_look(_spot("pop12"), NEAR)
			_wait = 10
		5:
			_settle()
			_sign_report(v)
			_wait = 10
		6:
			_save("m2_signpost_near")
			_look(_spot("pop12"), FAR)
			_wait = 10
		7:
			_settle()
			_wait = 10
		8:
			_save("m2_signpost_far")
			var sp := _spot("pop12")                  # 어려운 경우: 표지판 바로 앞(카메라 쪽)·옆에 큰 꽃이 자람 — 도구가 나무를 심어 본다
			var before: int = v.trees.size()
			v.trees.append({"x": sp.x + MilestoneView._front().x * 1.6, "y": sp.y + MilestoneView._front().y * 1.6, "s": "tree", "g": 0.0, "res": 0})
			v.trees.append({"x": sp.x + MilestoneView._right().x * 1.3, "y": sp.y + MilestoneView._right().y * 1.3, "s": "tree", "g": 0.0, "res": 0})
			v.trees.append({"x": sp.x - MilestoneView._right().x * 1.2 + MilestoneView._front().x * 3.2, "y": sp.y - MilestoneView._right().y * 1.2 + MilestoneView._front().y * 3.2, "s": "tree", "g": 0.0, "res": 0})
			print("꽃 셋을 표지판 곁에 심음 (나무 %d → %d)" % [before, v.trees.size()])
			_look(sp, NEAR)
			_wait = 10
		9:
			_settle()
			_wait = 10
		10:
			_save("m2_signpost_flower")
			v.trees.resize(v.trees.size() - 3)        # 심은 꽃 셋을 도로 뺌
			scene.paused = false
			_look(v.fire + Vector2(0.0, 0.4), NEAR)
			_settle()
			_wait = 20
		11:
			_advance_to(DUSK)                         # 아침 → 해 질 녘 잔치 한가운데로 한 번에 (큰 시간 건너뛰기)
			_wait = 1
		12:
			_save("m2_feast_skip")                    # 건너뛴 뒤 2번째 화면 — 손님이 제자리에서 먹고 춤추는 몸짓이어야 한다
			_wait = 40
		13:
			_settle()
			_wait = 14
		14:
			_save("m2_feast_near")
			_look(v.fire + Vector2(0.0, 0.4), FAR)
			_wait = 10
		15:
			_settle()
			_wait = 14
		16:
			_save("m2_feast_far")
			Sheet.make(shots, out_dir.path_join("m2_sheet.png"), 0.5)
			print("sheet ", out_dir.path_join("m2_sheet.png"))
			return true
	step += 1
	return false
