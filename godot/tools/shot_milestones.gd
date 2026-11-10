## 자람의 보상 (Q9 첫 묶음) 캡처 — sim/milestones.gd · view/milestone_view.gd · view/ui/milestone_stamps.gd.
## 실행 (창 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_milestones.gd [-- <크게 자른 확인용 그림을 둘 폴더>]
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트. 세로 화면 540×960. 화덕이 없으면 모닥불 곁 빈자리에 하나 세우고,
## 첫 빵 + 식구 열둘 고비를 넘긴 뒤 찍는다 (같은 날 고비 둘 → 그날 저녁 잔치는 '식구 열둘').
## 결과 (godot_shots/milestones/): m1_bread_near.png · m1_bread_far.png (빵 간판 — 가까이 44 · 멀리 20) ·
##   m1_signpost_near.png · m1_signpost_far.png (마을 이름 표지판) · m1_feast_near.png · m1_feast_far.png (저녁 잔치) ·
##   m1_notebook.png (별지기의 수첩 — 도장 줄 + 다음 고비 한 줄) · m1_card.png (주민 카드 — 별명) · m1_sheet.png (모아 보기)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")
const NEAR := 44.0
const FAR := 20.0
const NAMES := ["다래", "솔이", "가람", "누리", "보람", "한결", "이슬", "마루", "새봄", "하늘이", "도담", "나래"]

var scene: Node
var out_dir := ""
var crop_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var baker: Resident


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/milestones").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		crop_dir = String(args[0])
		DirAccess.make_dir_recursive_absolute(crop_dir)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)


func _mv() -> MilestoneView:
	return MilestoneView.of(scene.view)


## 처음 겪는 일의 안내 창('이제 마을이 스스로 먹고살아요' 등)이 장면을 가리지 않게 — 기다리는 것을 비우고 닫는다
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
	print("saved %s %s · %.2f시 · ppu %.1f · 잔치 %s(%s) · 잔치 손님 %d (춤 몸짓 %d · 불 곁 %d) · 화면 춤 %d · fast %s" % [name, img.get_size(), v.hour_now(), scene.cam.ppu, Milestones.feast_on(v), Milestones.feast_id(v), fest, play, near, _mv().dancers(), scene.view.fast])


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
	_mv().refresh()


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
			_reach(v)
			scene.paused = true
			_look(_spot("bread") + Vector2(0.0, -0.4), NEAR)
			_wait = 20
		1:
			_settle()
			_wait = 10
		2:
			_save("m1_bread_near")
			_look(_spot("bread") + Vector2(0.0, -0.4), FAR)
			_wait = 10
		3:
			_settle()
			_wait = 10
		4:
			_save("m1_bread_far")
			_look(_spot("pop12"), NEAR)
			_wait = 10
		5:
			_settle()
			_wait = 10
		6:
			_save("m1_signpost_near")
			_look(_spot("pop12"), FAR)
			_wait = 10
		7:
			_settle()
			_wait = 10
		8:
			_save("m1_signpost_far")
			scene.paused = false
			_advance_to(19.3)                         # 잔치 한가운데 — 멈추지 않고 찍는다 (몸짓·춤이 움직이는 채로)
			_look(v.fire + Vector2(0.0, 0.4), NEAR)
			_wait = 45
		9:
			_settle()
			_wait = 14
		10:
			_save("m1_feast_near")
			_look(v.fire + Vector2(0.0, 0.4), FAR)
			_wait = 10
		11:
			_settle()
			_wait = 14
		12:
			_save("m1_feast_far")
			scene.paused = true
			_look(v.fire, 32.0)
			scene.chronicle.open(1)
			_wait = 8
		13:
			var page := scene.chronicle.body.find_child("JarNotes", true, false) as Control      # 수첩 장은 '창세 신화' 아래쪽 — 그 장까지 내린다
			if page != null:
				scene.chronicle.scroll.scroll_vertical = int(page.position.y) - 96
			_wait = 14
		14:
			_save("m1_notebook")
			scene.chronicle.close()
			scene.detail.open(baker)
			_wait = 20
		15:
			_save("m1_card")
			scene.detail.close()
			Sheet.make(shots, out_dir.path_join("m1_sheet.png"), 0.5)
			print("sheet ", out_dir.path_join("m1_sheet.png"))
			return true
	step += 1
	return false
