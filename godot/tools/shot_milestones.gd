## 자람의 보상 (Q9) 캡처 — sim/milestones.gd · view/milestone_view.gd · view/ui/milestone_stamps.gd · view/ui/chronicle_sheet.gd.
## 실행 (창 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_milestones.gd [-- [m3|m4] <크게 자른 확인용 그림을 둘 폴더>]
##   m3 = Q9 ⑦ 묶음 (고비 여섯 — 첫걸음마 · 마을에서 난 첫 어른)만 찍는다. 없으면 2차 묶음(m2_*).
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트. 세로 화면 540×960. 화덕이 없으면 모닥불 곁 빈자리에 하나 세우고,
## 첫 빵 + 식구 열둘 고비를 넘긴 뒤 찍는다 (같은 날 고비 둘 → 그날 저녁 잔치는 '식구 열둘').
## 결과 (godot_shots/milestones/ — 2차 묶음 m2_*):
##   m2_strip_recent_none.png (연대기 '최근' 탭 — 도장 띠, 넘은 고비 없음) · m2_strip_people_two.png ('사람들' 탭 — 도장 둘) ·
##   m2_strip_myth_two.png ('창세 신화' 탭 맨 아래 수첩 장 — 옛 도장 줄이 없어진 자리) ·
##   m2_signpost_near.png · m2_signpost_far.png (마을 이름 표지판과 둘레의 꽃 — 가까이 44 · 멀리 20) ·
##   m2_signpost_flower.png (표지판 바로 앞·옆에 큰 꽃이 자란 경우 — 꽃 그림이 낮아져 표지판을 가리지 않음) ·
##   m2_feast_skip.png (아침 → 저녁 잔치 한가운데로 건너뛴 바로 뒤 2번째 화면) · m2_feast_near.png · m2_feast_far.png (해 질 녘 잔치) ·
##   m2_sheet.png (모아 보기)
## 결과 (m3 — Q9 ⑦):
##   m3_strip_none.png · m3_strip_three.png · m3_strip_six.png (도장 띠 — 자리 여섯: 없음 · 셋 · 여섯) ·
##   m3_steps_near.png · m3_steps_cheer.png (첫걸음마 — 문 앞에 모인 이웃이 손뼉) · m3_pinwheel_near.png · m3_pinwheel_far.png (문 앞 바람개비) ·
##   m3_signpost_far.png (마을 이름 표지판 — 마을과 함께 보이게 멀리) · m3_post_near.png (모닥불 곁 키 재는 기둥) ·
##   m3_grown_feast.png (마을에서 난 첫 아이가 어른이 된 날 저녁의 작은 잔치) · m3_sheet.png
##   첫걸음마 장면은 도구가 차린다: 걸음마 나이의 아기를 한 집에 두고, 어머니와 이웃 넷을 문 가까이에서 쉬는 것으로 놓는다 —
##   부르고·걸어와 서고·손뼉 치고·고비를 넘는 것은 마을(sim/milestones.gd)이 스스로 한다. 어른이 됨·식구 스물·첫 겨울은 도구가 넘긴다.
## 결과 (m4 — Q9 ⑭⑮, 고비 일곱):
##   m4_strip_none.png · m4_strip_three.png · m4_strip_seven.png (도장 띠 — 자리 일곱: 없음 · 셋 · 일곱) ·
##   m4_steps_wait.png (이웃이 문 앞에 와서 기다림) · m4_steps_cheer.png (첫걸음마 — 모인 이웃이 손뼉) ·
##   m4_sheaf_near.png · m4_sheaf_far.png (창고 문 위 햇밀 다발 — 가까이 64 · 마을 20) · m4_green_feast.png (햇밀 잔치 — 작은 잔치) · m4_sheet.png
##   푸른 밀 고개는 도구가 '끝났다'고 적는다 (Village.stats lean_green_y · lean_green_end_y) — 알아차리고 다발을 걸고 잔치를 여는 것은 마을이 한다.
##   창고가 없으면 모닥불 곁 빈자리에 하나 세운다.
## 결과 (m5 — Q15 잔치 화면 다듬기, 모두 도구가 차린 장면):
##   m5_oldsave_post · m5_oldsave_far · m5_oldsave_pinwheel (조용히 넘은 병 — 도구가 조용한 기록을 적는다: 기둥은 모닥불 곁, 바람개비는 집 문 옆) ·
##   m5_clap_close · m5_clap_near · m5_clap_far · m5_clap_bubble (첫걸음마 손뼉 — '짝' 금 · 두 손 그림 말풍선) ·
##   m5_pinwheel_near · m5_pinwheel_far20 · m5_pinwheel_far16 · m5_pinwheel_far9 (바람개비 — 64 · 20 · 16 · 9) ·
##   m5_feast_near · m5_feast_close · m5_feast_far (여느 잔치 — 빵 먹기 · 잔칫상 · 등) ·
##   m5_evening_near · m5_evening_far20 · m5_evening_far16 · m5_evening_far9 (어두워진 뒤 — 등불 · 큰 불의 불티) ·
##   m5_post_day (키 재는 기둥 — 낮) · m5_grown_near · m5_grown_close · m5_grown_far (첫 어른 잔치 — 기둥 옆에서 키 재기) ·
##   m5_grown_vs_feast.png (여느 잔치 | 첫 어른 잔치 나란히) · m5_sheet.png (설명 글이 붙은 모아 보기)
## 결과 (m6 — Q18 잔치 남은 일. `-- m6 before`로 띄우면 같은 장면을 m6_before_* 이름으로 — 고치기 전 코드에서 찍어 둔 것과 나란히 본다):
##   m6_clap_far9 · m6_clap_far16 · m6_clap_near (⑪ 첫걸음마 손뼉의 그림 말풍선과 바람개비 — 9 · 16 · 44) ·
##   m6_feast_h0~h3 (⑩ 여느 잔치 — 카메라 방위 넷, 44) · m6_feast_z16 · m6_feast_z9 (기본 확대 · 가장 먼 축소) ·
##   m6_eat_rig · m6_eat_frame · m6_eat_frame_near (⑧ 먹는 손님 — 관절 인형 / 그린 인형(방식 C)을 켠 것: 빵은 하나만) ·
##   m6_evening (등불) · m6_post_day · m6_post_z16 (⑫ 키 재는 기둥 — 시뮬레이션이 적어 둔 자리) ·
##   m6_grown_h0~h3 · m6_grown_close · m6_grown_z16 (⑦ 첫 어른 잔치 — 잔치가 시작될 때 그 젊은이를 모닥불에서 멀리 둔 장면) · m6_sheet.png (전 | 후 나란히)
## 결과 (m7 — Q20 ㉚㉜㉝. `-- m7 [확인용 폴더]`):
##   m7_eat_rig · m7_eat_c_a · m7_eat_c_b · m7_eat_c_near · m7_eat_c_z32 (㉝ 잔치에서 빵 먹는 손님 — 관절 인형 / 그린 인형(방식 C): 64 두 때 · 44 · 가까운 확대 32) ·
##   m7_eat_c_big0~ (그린 인형으로 먹는 손님마다 한 장 — 손·빵 자리를 보려는 확인용 확대 128. 게임에서 가장 가까운 확대는 60) ·
##   m7_post_day · m7_post_z16 · m7_post_z32 (㉚ 새로 선 키 재는 기둥 — 낮: 44 · 기본 확대 16 · 가까운 확대 32) ·
##   m7_grown_z16 · m7_grown_z32 · m7_grown_near (㉚ 첫 어른 잔치 때의 기둥 — 손님·상·등에 가리지 않는지) ·
##   m7_say_z16 · m7_say_z32 · m7_say_near · m7_say_close (㉜ 글 말풍선 — 도구가 손님 셋을 상·등 바로 앞에 세우고 한마디씩 띄운 장면: 상·등·기둥을 덮지 않음) · m7_sheet.png
## 저장 (2026-11-11 확인): 이 도구는 진짜 저장(user://save)을 읽지도 쓰지도 않는다 — 장면을 직접 띄우므로 저장을 쓰지 않는 병이고
##   (test_village.use_save = false), 그래도 틀리지 않게 저장 관리자를 끄고 폴더를 제 것(SAVE_DIR)으로 돌린다. 처음 겪는 일 안내 창의 대기 줄도
##   거인 묶음(저장 관리자의 player.firsts) 대신 이 도구만의 Firsts를 쓴다. 연대기 그림 카드(연출이 찍는 화면 — StageDirector)는
##   진짜 user://chron_pics 대신 SAVE_DIR/chron_pics에 적는다 (창이 있는 도구는 그 폴더에 j1_*.png를 남길 수 있었다).
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")
const SAVE_DIR := "user://_tool/shot_milestones/save"     # 도구 지킴이 폴더 (save/user_paths.gd) 안 — user:// 바로 아래에 쓰지 않는다
const NEAR := 44.0
const FAR := 20.0
const DUSK := 20.3                                    # 해 질 녘 (Balance.DUSK_FROM 19.5 ~ NIGHT_FULL 21.5 사이, 잔치는 21:00까지)
const CLOSE := 64.0
const STAY := 2
const DONE := 1
const NEXT := 0
const NAMES := ["다래", "솔이", "가람", "누리", "보람", "한결", "이슬", "마루", "새봄", "하늘이", "도담", "나래"]

var scene: Node
var out_dir := ""
var crop_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var mode := "m2"
var baby: Resident
var steps_at := 0.0
var _tries := 0
var _near: Array = []                                 # 첫걸음마 장면: 문 가까이에 둔 사람들 (어머니 먼저)
var _q: Array = []                                    # (m5) 찍을 것들: [자리, 확대, 이름, 설명]
var _q_phase := 0
var _q_tries := 0
var _labels := {}                                     # (m5) 그림 파일 → 모아 보기에 붙일 설명
var _sheet_vp: SubViewport                            # (m5) 모아 보기를 그리는 그림판
var _pre := "m6_"                                     # (m6) 그림 이름 머리 — "before"로 띄우면 m6_before_
var _old_personal := {}                               # (m6) 그린 인형을 켜는 동안 바꿔 둔 인형 차림 (주민 id → 원래 값)


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/milestones").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var args := OS.get_cmdline_user_args()
	for a: String in args:
		if a == "m3" or a == "m4" or a == "m5" or a == "m6" or a == "m7":
			mode = a
		elif a == "before":
			_pre = "m6_before_"
		else:
			crop_dir = a
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
	if mode == "m3" or mode == "m4" or mode == "m5" or mode == "m6" or mode == "m7":
		var r := _m3(v) if mode == "m3" else (_m4(v) if mode == "m4" else (_m5(v) if mode == "m5" else (_m6(v) if mode == "m6" else _m7(v))))
		if r == NEXT:
			step += 1
		return r == DONE
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


# ───────────────────────── m3 (Q9 ⑦ — 고비 여섯) ─────────────────────────
## 걸음마 나이의 아기를 집이 있는 부부에게 두고, 어머니와 이웃 넷을 문 가까이에서 쉬는 것으로 놓는다 (부르는 것부터는 마을이 한다)
func _baby_scene(v: Village) -> void:
	var mom: Resident = null
	for p in v.people:
		if p.is_adult() and p.sex == "f" and p.partner >= 0 and v.person(p.partner) != null and v.bld(p.home) != null:
			mom = p
			break
	var dad := v.person(mom.partner)
	var hm := v.bld(mom.home)
	baby = v.add_person("아람", "f", ChildPlay.TODDLE_AGE + 0.004, "", hm.x, hm.y, mom, dad)
	baby.parents = PackedInt32Array([mom.id, dad.id])
	baby.home = hm.id
	baby.born_t = v.t - baby.age * Balance.AGE_K * Balance.DAY
	v.stats["born"] = int(v.stats.get("born", 0)) + 1
	if v.in_opening():
		v.stats["thanks"] = 1                         # 첫 한 시간 대본 중에는 부르지 않는다 — 도구는 대본을 지난 것으로
	_near = [mom]
	for p in v.people:
		if _near.size() >= 5:
			break
		if p.is_adult() and p != mom and p != dad and not p.sleeping:
			_near.append(p)
	_idle_near(v)
	print("아기 %s (집 %s %d · 문 %s) · 어머니 %s · 곁에 둔 이웃 %d · 대본 %s · 연출 중 %s" % [baby.name, hm.type, hm.id, ChildPlay.door(v, baby), mom.name, _near.size() - 1, v.in_opening(), v.staged()])


## 문 가까이에 둔 사람들을 쉬는 것으로 (마을이 부를 때까지 살핌마다 다시 — 그 사이 일하러 흩어지지 않게)
func _idle_near(v: Village) -> void:
	var mom := v.person(baby.parents[0])
	var d := ChildPlay.door(v, baby)
	var i := 0
	for p: Resident in _near:
		p.steps.clear()
		p.action = "idle"
		p.anim = "idle"
		p.carry = ""
		var off := Vector2(1.0, 1.0) if p == mom else Vector2(2.6 + 0.4 * float(i), 2.4 - 0.8 * float(i))
		p.x = d.x + off.x
		p.y = d.y + off.y
		p.px = p.x
		p.py = p.y
		i += 1


## 마을에서 난 아이가 어른이 됨 — 갓난 아기를 보태 마을이 적어 두게 한 뒤 나이를 어른으로 (도구가 넘김)
func _grow(v: Village) -> void:
	var mom := v.person(baby.parents[0])
	var dad := v.person(baby.parents[1])
	var hm := v.bld(baby.home)
	var kid := v.add_person("보리", "m", 0.0, "", hm.x, hm.y, mom, dad)
	kid.parents = PackedInt32Array([mom.id, dad.id])
	kid.home = hm.id
	v.stats["born"] = int(v.stats.get("born", 0)) + 1
	scene.world.advance(2.0)
	kid.age = Balance.AGE_ADULT + 0.002
	scene.world.advance(2.0)
	print("고비 기록 (어른이 됨): ", (v.milestones.get("passed", {}) as Dictionary).get("grown", {}), " · ", Milestones.title_of(kid))
	for b: Dictionary in v.book.slice(maxi(0, v.book.size() - 2)):
		print("  연대기: ", b["text"])


func _m3(v: Village) -> int:
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 960)
				return STAY
			scene.set_debug_mode(false)
			_advance_to(10.5)
			scene.paused = true
			_look(v.fire, 32.0)
			_settle()
			scene.chronicle.open(0)                   # 도장 띠 — 자리 여섯, 넘은 고비 없음
			_wait = 14
		1:
			_save("m3_strip_none")
			scene.chronicle.close()
			_reach(v)                                 # 첫 빵 + 식구 열둘
			_baby_scene(v)
			_wait = 2
		2:
			_idle_near(v)
			scene.world.advance(ChildPlay.CARE_IV)    # 마을이 이웃을 부를 때까지
			_tries += 1
			if not v.milestones.has("steps_call") and _tries < 60:
				return STAY
			var call: Dictionary = v.milestones.get("steps_call", {})
			steps_at = float(call.get("at", v.t))
			var called := 0
			for p in v.people:
				called += 1 if p.doing == Milestones.CLAP_DOING else 0
			print("불렀다 (%d번째 살핌): 걸음마는 병 %.0f초 뒤 · 부른 이웃 %d" % [_tries, steps_at - v.t, called])
			scene.world.advance(maxf(steps_at - v.t - 40.0, 1.0))
			_look(ChildPlay.door(v, baby) + Vector2(0.9, 0.9), CLOSE)
			_settle()
			scene.paused = false
			_tries = 0
			_wait = 2
		3:
			_tries += 1
			if not Milestones.is_passed(v, "steps") and _tries < 900:
				return STAY
			print("고비 기록 (첫걸음마): ", (v.milestones.get("passed", {}) as Dictionary).get("steps", {}), " · 화면 손뼉 ", _mv().clappers())
			for b: Dictionary in v.book.slice(maxi(0, v.book.size() - 2)):
				print("  연대기: ", b["text"])
			_wait = 45
		4:
			_save("m3_steps_near")
			print("  화면 손뼉 ", _mv().clappers())
			_wait = 70
		5:
			_save("m3_steps_cheer")
			print("  화면 손뼉 ", _mv().clappers())
			_wait = 260                               # 손뼉이 끝나고 흩어질 때까지
		6:
			scene.paused = true
			_look(_spot("steps") + Vector2(-0.3, -0.3), CLOSE)
			_wait = 10
		7:
			_settle()
			_wait = 14
		8:
			_save("m3_pinwheel_near")
			_look(_spot("steps"), FAR)
			_wait = 10
		9:
			_settle()
			_wait = 14
		10:
			_save("m3_pinwheel_far")
			scene.chronicle.open(0)                   # 도장 셋 (첫 빵 · 첫걸음마 · 식구 열둘)
			_wait = 14
		11:
			_save("m3_strip_three")
			scene.chronicle.close()
			_look((_spot("pop12") + v.fire) * 0.5, 17.0)
			_wait = 10
		12:
			_settle()
			_sign_report(v)
			_wait = 14
		13:
			_save("m3_signpost_far")
			_grow(v)
			_look(_spot("grown") + Vector2(-0.3, -0.3), CLOSE)
			_wait = 10
		14:
			_settle()
			_wait = 14
		15:
			_save("m3_post_near")
			scene.paused = false
			_look(v.fire + Vector2(0.0, 0.4), NEAR)
			_settle()
			_wait = 20
		16:
			_advance_to(19.2)                         # 작은 잔치 한가운데 (18:30 → 20:00)
			_wait = 1
		17:
			_wait = 40
		18:
			_settle()
			_wait = 14
		19:
			_save("m3_grown_feast")
			scene.paused = true
			var i := 0
			while v.people.size() < Milestones.POP_BIG:   # 식구 스물 + 첫 겨울 (도구가 넘김) — 도장 여섯
				v.add_person(NAMES[i % NAMES.size()] + "네", "f" if i % 2 == 0 else "m", 20.0 + float(i), "", v.fire.x - 2.0, v.fire.y - 1.5 + 0.3 * float(i), null, null)
				i += 1
			scene.world.advance(2.0)
			if not Milestones.is_passed(v, "winter"):
				Milestones._pass(v, "winter")
			scene.chronicle.open(0)
			_wait = 14
		20:
			_save("m3_strip_six")
			Sheet.make(shots, out_dir.path_join("m3_sheet.png"), 0.5)
			print("sheet ", out_dir.path_join("m3_sheet.png"))
			return DONE
	return NEXT


# ───────────────────────── m4 (Q9 ⑭⑮ — 고비 일곱 · 햇밀 다발 · 첫걸음마 이웃) ─────────────────────────
## 창고가 없으면 모닥불 곁 빈자리에 하나 (이미 있으면 그대로)
func _need_store(v: Village) -> Building:
	var st := Milestones.sheaf_house(v)
	if st != null and st.type == "창고":
		return st
	for ring in [6.0, 7.0, 8.5, 10.0, 12.0]:
		for i in 16:
			var a := TAU * float(i) / 16.0 + 1.1
			var p := v.fire + Vector2(cos(a), sin(a)) * float(ring)
			if Milestones.spot_free(v, p) and Milestones.spot_free(v, p + Vector2(1.6, 1.6)) and Milestones.spot_free(v, p + Vector2(-1.6, 1.6)) and Milestones.spot_free(v, p + Vector2(0.0, 2.4)):
				return v.add_building("창고", p.x, p.y, true)
	return v.add_building("창고", v.fire.x - 7.0, v.fire.y + 3.0, true)


## 푸른 밀 고개가 끝났다고 적는다 (LeanSeasons.hourly가 적는 것과 같은 통계) — 그다음은 마을이 스스로
func _green(v: Village) -> void:
	var st := _need_store(v)
	var y := int(Health.jar_date(v)["year"])
	v.stats["lean_green_y"] = y
	v.stats["lean_green_end_y"] = y
	scene.world.advance(2.0)
	var rec: Dictionary = (v.milestones.get("passed", {}) as Dictionary).get("green", {})
	var hang := MilestoneView.sheaf(v)
	print("고비 기록 (푸른 밀 고개): ", rec, " · 창고 %d (%.1f, %.1f) · 다발 %s · %.2f시" % [st.id, st.x, st.y, hang, v.hour_now()])
	for b: Dictionary in v.book.slice(maxi(0, v.book.size() - 2)):
		print("  연대기: ", b["text"])


func _m4(v: Village) -> int:
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 960)
				return STAY
			scene.set_debug_mode(false)
			_advance_to(8.0)
			scene.paused = true
			_look(v.fire, 32.0)
			_settle()
			scene.chronicle.open(0)                   # 도장 띠 — 자리 일곱, 넘은 고비 없음
			_wait = 14
		1:
			_save("m4_strip_none")
			scene.chronicle.close()
			_reach(v)                                 # 첫 빵 + 식구 열둘
			_baby_scene(v)
			_wait = 2
		2:
			_idle_near(v)
			scene.world.advance(ChildPlay.CARE_IV)    # 마을이 이웃을 부를 때까지
			_tries += 1
			if not v.milestones.has("steps_call") and _tries < 60:
				return STAY
			var call: Dictionary = v.milestones.get("steps_call", {})
			steps_at = float(call.get("at", v.t))
			var called := 0
			for p in v.people:
				called += 1 if p.doing == Milestones.CLAP_DOING else 0
			print("불렀다 (%d번째 살핌): 걸음마는 병 %.0f초 뒤 (마감 %.0f초 뒤) · 부른 이웃 %d" % [_tries, steps_at - v.t, float(call.get("last", steps_at)) - v.t, called])
			scene.world.advance(maxf(steps_at - v.t - 300.0, 1.0))
			_look(ChildPlay.door(v, baby) + Vector2(0.9, 0.9), CLOSE)
			_settle()
			_tries = 0
			_wait = 14
		3:
			_save("m4_steps_wait")                    # 이웃이 문 앞에 와서 기다린다 (아직 걸음마 전)
			print("  기다리는 이웃 ", Milestones.clappers(v, baby.id), " · 넘겼나 ", Milestones.is_passed(v, "steps"))
			scene.world.advance(maxf(steps_at - v.t - 40.0, 1.0))
			scene.paused = false
			_wait = 2
		4:
			_tries += 1
			if not Milestones.is_passed(v, "steps") and _tries < 900:
				return STAY
			print("고비 기록 (첫걸음마): ", (v.milestones.get("passed", {}) as Dictionary).get("steps", {}), " · 화면 손뼉 ", _mv().clappers())
			for b: Dictionary in v.book.slice(maxi(0, v.book.size() - 2)):
				print("  연대기: ", b["text"])
			_wait = 70
		5:
			_save("m4_steps_cheer")
			print("  화면 손뼉 ", _mv().clappers())
			_wait = 260                               # 손뼉이 끝나고 흩어질 때까지
		6:
			scene.paused = true
			scene.chronicle.open(0)                   # 도장 셋 (첫 빵 · 첫걸음마 · 식구 열둘)
			_wait = 14
		7:
			_save("m4_strip_three")
			scene.chronicle.close()
			_green(v)
			_look(_spot("green") + Vector2(-0.6, -0.6), CLOSE)
			_wait = 10
		8:
			_settle()
			_wait = 14
		9:
			_save("m4_sheaf_near")
			print("  다발 그림 ", _mv().sign_node("green") != null, " · 올림 ", _mv().sheaf_lift())
			_look((_spot("green") + v.fire) * 0.5, FAR)
			_wait = 10
		10:
			_settle()
			_wait = 14
		11:
			_save("m4_sheaf_far")
			scene.paused = false
			_look(v.fire + Vector2(0.0, 0.4), NEAR)
			_settle()
			_wait = 20
		12:
			_advance_to(19.2)                         # 작은 잔치 한가운데 (18:30 → 20:00)
			_wait = 1
		13:
			_wait = 40
		14:
			_settle()
			_wait = 14
		15:
			_save("m4_green_feast")
			scene.paused = true
			_grow(v)                                  # 마을에서 난 첫 어른 (도구가 넘김)
			var i := 0
			while v.people.size() < Milestones.POP_BIG:   # 식구 스물 + 첫 겨울 (도구가 넘김) — 도장 일곱
				v.add_person(NAMES[i % NAMES.size()] + "네", "f" if i % 2 == 0 else "m", 20.0 + float(i), "", v.fire.x - 2.0, v.fire.y - 1.5 + 0.3 * float(i), null, null)
				i += 1
			scene.world.advance(2.0)
			if not Milestones.is_passed(v, "winter"):
				Milestones._pass(v, "winter")
			print("넘은 고비: ", (v.milestones.get("passed", {}) as Dictionary).keys())
			scene.chronicle.open(0)
			_wait = 14
		16:
			_save("m4_strip_seven")
			Sheet.make(shots, out_dir.path_join("m4_sheet.png"), 0.5)
			print("sheet ", out_dir.path_join("m4_sheet.png"))
			return DONE
	return NEXT


# ───────────────────────── m5 (Q15 — 잔치 화면 다듬기: 먹기 · 등·불티 · 첫 어른 잔치 · 바람개비 · 손뼉 · 조용히 넘은 병) ─────────────────────────
## 찍고 설명 한 줄을 적어 둔다 (모아 보기에 그 글이 붙는다)
func _cap(name: String, label: String) -> void:
	_save(name)
	_labels[out_dir.path_join(name + ".png")] = name + "\n" + label
	var mv := _mv()
	print("  m5: 먹는 몸짓 %d · 상 %s · 등 %d · 키 재기 %d (닿음 %s · 끈 %s) · 손뼉 %d · 그림 말풍선 %d · 불티 %s" % [mv.eaters(), mv.feast_table() != null, mv.lamps_lit(),
		mv.star(), mv.star_there(), mv.ribbon_on(), mv.clappers(), mv.bub.items.size(), scene.view._fire.sparks.visible])


## 찍을 것들([자리, 확대, 이름, 설명])을 차례로: 보기 맞춤 → 10화면 → 다시 맞춤 → 14화면 → 저장. 다 찍으면 true
func _run_q() -> bool:
	if _q.is_empty():
		return true
	var s: Array = _q[0]
	match _q_phase:
		0:
			if s.size() > 5:                          # (m6) 카메라 방위 (0~3)
				while scene.cam.quarter != int(s[5]):
					scene.cam.turn(1, true)
			_look(s[0], float(s[1]))
			_q_phase = 1
			_wait = 10
		1:
			_settle()
			_q_phase = 2
			_wait = 14
		2:
			if s.size() > 4 and String(s[4]) != "" and not _bub_showing(String(s[4])) and _q_tries < 500:     # 그 그림 말풍선이 또렷이 뜬 때를 기다림
				_q_tries += 1
				return false
			_q_tries = 0
			_cap(String(s[2]), String(s[3]))
			if mode == "m7":
				_say_report()
			_q.pop_front()
			_q_phase = 0
	return _q.is_empty()


## 그 그림의 말풍선이 지금 또렷이 떠 있나 (뜨고 지는 사이의 가운데)
func _bub_showing(pic: String) -> bool:
	for it: Array in _mv().bub.items:
		if String(it[1]) == pic and float(it[2]) > 0.25 and float(it[2]) < 0.6:
			return true
	return false


## 지금 '짝' 금 그림이 또렷이 보이는 이웃이 있나 (손뼉 캡처의 때를 맞춤)
func _clap_peak() -> bool:
	for id: int in _mv()._claps:
		var n := _mv()._claps[id] as MeshInstance3D
		if n != null and n.visible and (n.get_instance_shader_parameter("fx") as Vector4).y > 0.8:
			return true
	return false


## 카메라 쪽에 선 먹는 손님 (가까이 찍을 사람 — 없으면 모닥불)
func _eater_at(v: Village) -> Vector2:
	var best := v.fire
	var score := -1.0e9
	for p in v.people:
		if p.action != "festival" or p.anim != "eat" or Vector2(p.x, p.y).distance_to(v.fire) > MilestoneView.DANCE_R:
			continue
		var alone := 2.0                              # 곁 사람에게 가려지지 않은 손님을 고른다
		for o in v.people:
			if o != p and not o.dead:
				alone = minf(alone, Vector2(o.x - p.x, o.y - p.y).length())
		var s := alone + 0.2 * (Vector2(p.x, p.y) - v.fire).dot(MilestoneView._front())
		if s > score:
			score = s
			best = Vector2(p.x, p.y)
	return best


## 그림 여러 장을 설명 글과 함께 한 장으로 (cols 칸 · scale 배) — 따로 둔 그림판(SubViewport)에 놓는다. 몇 화면 뒤 _compose_save가 적는다
func _compose(paths: PackedStringArray, cols: int, scale: float) -> void:
	var cell := Vector2(540.0, 960.0) * scale
	var cap_h := 36.0
	var gap := 8.0
	var rows := ceili(float(paths.size()) / float(cols))
	var vp := SubViewport.new()
	vp.size = Vector2i(int(float(cols) * (cell.x + gap) + gap), int(float(rows) * (cell.y + cap_h + gap) + gap))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	var bg := ColorRect.new()
	bg.color = Color("1e1f2a")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	for i in paths.size():
		var img := Image.load_from_file(paths[i])
		img.generate_mipmaps()
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.position = Vector2(gap + float(i % cols) * (cell.x + gap), gap + floorf(float(i) / float(cols)) * (cell.y + cap_h + gap) + cap_h)
		tr.size = cell
		vp.add_child(tr)
		var lb := Label.new()
		lb.text = String(_labels.get(paths[i], paths[i].get_file().get_basename()))
		lb.position = tr.position - Vector2(0.0, cap_h)
		lb.size = Vector2(cell.x, cap_h)
		lb.clip_text = true
		lb.add_theme_font_size_override("font_size", 12)
		lb.add_theme_constant_override("line_spacing", 0)
		lb.add_theme_color_override("font_color", Color("fff3d6"))
		vp.add_child(lb)
	root.add_child(vp)
	_sheet_vp = vp


func _compose_save(path: String) -> void:
	_sheet_vp.get_texture().get_image().save_png(path)
	print("sheet ", path, " ", _sheet_vp.size)
	_sheet_vp.queue_free()
	_sheet_vp = null


func _m5(v: Village) -> int:
	var fire := v.fire + Vector2(0.0, 0.4)
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 960)
				return STAY
			scene.set_debug_mode(false)
			_advance_to(10.5)
			scene.paused = true
			# ⑥ 조용히 넘은 병 (차린 장면): 옛 저장을 처음 볼 때 마을이 적는 것과 같은 기록(Milestones._mark_silent)을 도구가 적는다 — 자리·집은 적히지 않는다
			Milestones._mark_silent(v, "steps")
			Milestones._mark_silent(v, "grown")
			_look(fire, NEAR)
			_settle()
			var hm := MilestoneView.quiet_house(v)
			print("조용히 넘은 병: 기록 ", (v.milestones["passed"] as Dictionary), " · 바람개비 집 ", hm.id if hm != null else -1, " · 장식 ", MilestoneView.wanted(v))
			_q = [[fire, NEAR, "m5_oldsave_post", "⑥ 조용히 넘은 병 [차림]: 기둥이 모닥불 곁에 (44)"],
				[(_spot("steps") + _spot("grown")) * 0.5, FAR, "m5_oldsave_far", "⑥ 조용히 넘은 병 [차림]: 기둥 + 바람개비 (20)"],
				[_spot("steps") + Vector2(-0.3, -0.3), NEAR, "m5_oldsave_pinwheel", "⑥ 조용히 넘은 병 [차림]: 집 문 옆 바람개비 (44)"]]
		1:
			if not _run_q():
				return STAY
			(v.milestones["passed"] as Dictionary).erase("steps")     # 차린 기록을 도로 지우고 — 아래부터는 마을이 스스로 넘긴다
			(v.milestones["passed"] as Dictionary).erase("grown")
			_reach(v)                                 # 첫 빵 + 식구 열둘
			_baby_scene(v)
			_wait = 2
		2:
			_idle_near(v)
			scene.world.advance(ChildPlay.CARE_IV)    # 마을이 이웃을 부를 때까지
			_tries += 1
			if not v.milestones.has("steps_call") and _tries < 60:
				return STAY
			var call: Dictionary = v.milestones.get("steps_call", {})
			steps_at = float(call.get("at", v.t))
			print("불렀다 (%d번째 살핌): 걸음마는 병 %.0f초 뒤" % [_tries, steps_at - v.t])
			scene.world.advance(maxf(steps_at - v.t - 40.0, 1.0))
			_look(ChildPlay.door(v, baby) + Vector2(0.9, 0.9), CLOSE)
			_settle()
			scene.paused = false
			_tries = 0
			_wait = 2
		3:
			_tries += 1
			if not Milestones.is_passed(v, "steps") and _tries < 900:
				return STAY
			print("고비 기록 (첫걸음마): ", (v.milestones.get("passed", {}) as Dictionary).get("steps", {}), " · 화면 손뼉 ", _mv().clappers())
			_tries = 0
			_wait = 40
		4:
			_tries += 1
			if not _clap_peak() and _tries < 240:
				return STAY
			_cap("m5_clap_close", "⑤ 첫걸음마 손뼉: 손 높이의 '짝' 금 + 손뼉 그림 (64)")
			scene.paused = true                       # 손뼉 걸음을 멈춰 두고 (화면 몸짓은 계속) 다른 확대로
			_q = [[ChildPlay.door(v, baby) + Vector2(0.9, 0.9), NEAR, "m5_clap_near", "⑤ 첫걸음마 손뼉 (44)"],
				[ChildPlay.door(v, baby) + Vector2(0.9, 0.9), FAR, "m5_clap_far", "⑤ 첫걸음마 손뼉 — 멀리 (20)"]]
		5:
			if not _run_q():
				return STAY
			scene.paused = false
			_wait = 260                               # 손뼉이 끝나고 흩어질 때까지
		6:
			scene.paused = true
			var pin := _spot("steps")
			_q = [[ChildPlay.door(v, baby) + Vector2(0.9, 0.9), CLOSE, "m5_clap_bubble", "⑤ 첫걸음마 손뼉: 두 손 그림 말풍선 (64)", "hands"],
				[pin + Vector2(-0.3, -0.3), CLOSE, "m5_pinwheel_near", "④ 바람개비 — 가까이 (64 · 제 크기)"],
				[pin, FAR, "m5_pinwheel_far20", "④ 바람개비 — 멀리 (20)"],
				[pin, float(JarCamera.ZOOM_PPU[1]), "m5_pinwheel_far16", "④ 바람개비 — 마을 기본 확대 (16)"],
				[pin, float(JarCamera.ZOOM_PPU[0]), "m5_pinwheel_far9", "④ 바람개비 — 가장 먼 축소 (9)"]]
		7:
			if not _run_q():
				return STAY
			scene.paused = false
			_look(fire, NEAR)
			_settle()
			_wait = 20
		8:
			_advance_to(19.2)                         # 그날 저녁 '식구 열둘' 잔치 (18:30 → 21:00) — 아직 밝을 때
			_wait = 1
		9:
			_wait = 50
		10:
			scene.paused = true
			_q = [[fire, NEAR, "m5_feast_near", "① 여느 잔치: 빵 먹기 · 잔칫상 · 등 (44)"],
				[_eater_at(v), CLOSE, "m5_feast_close", "① 먹는 손님 — 가까이 (64)"],
				[fire, FAR, "m5_feast_far", "① 여느 잔치 — 멀리 (20)"]]
		11:
			if not _run_q():
				return STAY
			scene.paused = false
			_look(fire, NEAR)
			_settle()
			_wait = 10
		12:
			_advance_to(20.75)                        # 어두워진 뒤 (잔치는 21:00까지)
			_wait = 1
		13:
			_wait = 50
		14:
			scene.paused = true
			_q = [[fire, NEAR, "m5_evening_near", "② 저녁 잔치: 등불 · 큰 불의 불티 (44)"],
				[fire, FAR, "m5_evening_far20", "② 저녁 잔치 — 멀리 (20)"],
				[fire, float(JarCamera.ZOOM_PPU[1]), "m5_evening_far16", "② 저녁 잔치 — 마을 기본 확대 (16)"],
				[fire, float(JarCamera.ZOOM_PPU[0]), "m5_evening_far9", "② 저녁 잔치 — 가장 먼 축소 (9)"]]
		15:
			if not _run_q():
				return STAY
			_advance_to(10.0)                         # 이튿날 아침
			_grow(v)                                  # 마을에서 난 첫 어른 (도구가 넘김)
			var rec: Dictionary = (v.milestones["passed"] as Dictionary).get("grown", {})
			print("기둥: 적어 둔 자리 (%.1f, %.1f) 불에서 %.1f칸 → 화면 자리 %s 불에서 %.1f칸" % [float(rec.get("x", 0.0)), float(rec.get("y", 0.0)),
				Vector2(float(rec.get("x", 0.0)), float(rec.get("y", 0.0))).distance_to(v.fire), _spot("grown"), _spot("grown").distance_to(v.fire)])
			_q = [[fire, NEAR, "m5_post_day", "③ 키 재는 기둥 — 모닥불 곁 (낮 · 44)"]]
		16:
			if not _run_q():
				return STAY
			scene.paused = false
			_look(fire, NEAR)
			_settle()
			_wait = 20
		17:
			_advance_to(18.9)                         # 작은 잔치 (18:30 → 20:00)
			_tries = 0
			_wait = 1
		18:
			_tries += 1
			if _tries % 60 == 1:                      # 그 젊은이가 불 곁에 오기까지 (늦게 오면 키 재기도 늦다)
				var kid := v.person(int(((v.milestones["passed"] as Dictionary).get("grown", {}) as Dictionary).get("who", -1)))
				if kid != null:
					print("  젊은이 %.2f시: %s/%s · 불에서 %.1f칸 · 키 재기 %d" % [v.hour_now(), kid.action, kid.anim, Vector2(kid.x, kid.y).distance_to(v.fire), _mv().star()])
			if not (_mv().star_there() and _mv().ribbon_on()) and _tries < 900 and Milestones.feast_on(v):
				return STAY
			print("첫 어른 잔치: 키 재기 %d (닿음 %s · 끈 %s) · %.2f시 · 기다린 화면 %d" % [_mv().star(), _mv().star_there(), _mv().ribbon_on(), v.hour_now(), _tries])
			_wait = 70
		19:
			scene.paused = true
			_q = [[fire, NEAR, "m5_grown_near", "③ 첫 어른 잔치: 기둥 옆에서 키 재기 (44)"],
				[_spot("grown") + Vector2(0.4, 0.4), CLOSE, "m5_grown_close", "③ 키 재기 — 가까이 (64)"],
				[fire, FAR, "m5_grown_far", "③ 첫 어른 잔치 — 멀리 (20)"]]
		20:
			if not _run_q():
				return STAY
			_compose(PackedStringArray([out_dir.path_join("m5_feast_near.png"), out_dir.path_join("m5_grown_near.png")]), 2, 1.0)
			_wait = 4
		21:
			_compose_save(out_dir.path_join("m5_grown_vs_feast.png"))
			_compose(shots, 5, 0.5)
			_wait = 4
		22:
			_compose_save(out_dir.path_join("m5_sheet.png"))
			return DONE
	return NEXT


# ───────────────────────── m6 (Q18 — 잔치 남은 일: 빵 하나 · 겹침 · 바람개비와 말풍선 · 기둥 자리 · 멀리 있던 젊은이) ─────────────────────────
## 모든 인형의 그린 인형(방식 C) 스위치 (-1 따름 · 0 끔 · 1 켬)
func _force_frames(on: int) -> void:
	for id: int in scene.view.residents:
		var cm := scene.view.residents[id] as CutoutResident
		if cm != null and is_instance_valid(cm):
			cm.frames_force = on
			# 그린 인형은 '제 옷'(personal 0)인 어른만 — 이 병의 식구는 모두 다른 옷이라, 찍는 동안만 인형의 차림을 바꿔 둔다 (화면 인형만 · 끝나면 되돌림)
			if on == 1 and not _old_personal.has(id):
				_old_personal[id] = cm.dlook.get("personal", -1)
				cm.dlook["personal"] = 0
			elif on != 1 and _old_personal.has(id):
				cm.dlook["personal"] = _old_personal[id]
				_old_personal.erase(id)
			cm._refresh_doll()                            # 멈춘 화면에서도 바로 바꿔 그리게


## 가까이 찍을 먹는 손님 (framed = 그린 인형으로 그려지는 사람만). 없으면 INF
func _eater_pick(v: Village, framed: bool) -> Vector2:
	var best := Vector2.INF
	var score := -1.0e9
	var n := 0
	for p in v.people:
		if p.action != "festival" or p.anim != "eat" or Vector2(p.x, p.y).distance_to(v.fire) > MilestoneView.DANCE_R:
			continue
		var cm := scene.view.residents.get(p.id) as CutoutResident
		if cm == null or cm._f_on != framed:
			continue
		n += 1
		var alone := 2.0
		for o in v.people:
			if o != p and not o.dead:
				alone = minf(alone, Vector2(o.x - p.x, o.y - p.y).length())
		var s := alone + 0.2 * (Vector2(p.x, p.y) - v.fire).dot(MilestoneView._front())
		if s > score:
			score = s
			best = Vector2(p.x, p.y)
	print("  먹는 손님 (그린 인형 %s): %d명 → %s" % [framed, n, best])
	return best


func _spots_report(v: Village) -> void:
	var mv := _mv()
	var rec: Dictionary = (v.milestones.get("passed", {}) as Dictionary).get("grown", {})
	var n := 0
	var edge := 0.0
	for p in v.people:
		if p.action == "festival":
			n += 1
			edge = maxf(edge, Vector2(p.x, p.y).distance_to(v.fire))
	print("  자리: 불 %s · 상·등 %s · 기둥(화면) %s · 기둥(적어 둔 것) %s · 잔치 손님 %d (가장 먼 사람 %.2f칸)" % [v.fire, mv._spots, mv._post_keep,
		Vector2(float(rec.get("x", 0.0)), float(rec.get("y", 0.0))) if rec.has("x") else Vector2.INF, n, edge])
	if mv._spots.has("table") and mv._spots["table"] != Vector2.INF:
		var tp: Vector2 = mv._spots["table"]
		print("    상: 불에서 %.2f칸 · 방위 %.0f° (기본 보기 앞 = %.0f°)" % [tp.distance_to(v.fire), rad_to_deg((tp - v.fire).angle()), rad_to_deg(MilestoneView._front().angle())])
	if mv._spots.has("table"):
		var oth := MilestoneView.feast_others(v, mv._post_keep, mv._seat_spots(v))
		for rr: float in MilestoneView.TABLE_RINGS:
			var row := ""
			for i in 24:
				var a2 := deg_to_rad(float(i) * 15.0 - 180.0)
				var cp := v.fire + Vector2(cos(a2), sin(a2)) * rr
				var ok := MilestoneView.table_ok(v, cp, MilestoneView._right())
				row += " %d:%s" % [i * 15 - 180, ("%.2f" % MilestoneView.table_score(v, cp, mv._post_keep, oth)) if ok else "x"]
			print("    상 후보 %.1f칸 —%s" % [rr, row])
	if mv._post_keep != Vector2.INF:
		print("    기둥: 불에서 %.2f칸 · 방위 %.0f°" % [mv._post_keep.distance_to(v.fire), rad_to_deg((mv._post_keep - v.fire).angle())])
	for b in v.buildings:
		if Vector2(b.x, b.y).distance_to(v.fire) < 9.0:
			print("    건물 %s: 불에서 %.1f칸 · 방위 %.0f° · 크기 %.1f" % [b.type, Vector2(b.x, b.y).distance_to(v.fire), rad_to_deg((Vector2(b.x, b.y) - v.fire).angle()), b.size()])


func _m6(v: Village) -> int:
	var fire := v.fire + Vector2(0.0, 0.4)
	var z1 := float(JarCamera.ZOOM_PPU[1])
	var z0 := float(JarCamera.ZOOM_PPU[0])
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 960)
				return STAY
			scene.set_debug_mode(false)
			_advance_to(10.5)
			scene.paused = true
			_look(fire, NEAR)
			_settle()
			_reach(v)                                 # 첫 빵 + 식구 열둘
			_baby_scene(v)
			_wait = 2
		1:
			_idle_near(v)
			scene.world.advance(ChildPlay.CARE_IV)    # 마을이 이웃을 부를 때까지
			_tries += 1
			if not v.milestones.has("steps_call") and _tries < 60:
				return STAY
			var call: Dictionary = v.milestones.get("steps_call", {})
			steps_at = float(call.get("at", v.t))
			scene.world.advance(maxf(steps_at - v.t - 40.0, 1.0))
			_look(ChildPlay.door(v, baby) + Vector2(0.9, 0.9), CLOSE)
			_settle()
			scene.paused = false
			_tries = 0
			_wait = 2
		2:
			_tries += 1
			if not Milestones.is_passed(v, "steps") and _tries < 900:
				return STAY
			_tries = 0
			_wait = 40
		3:
			_tries += 1
			if not _clap_peak() and _tries < 240:
				return STAY
			scene.paused = true                       # 손뼉 걸음을 멈춰 두고 (화면 몸짓은 계속)
			var pin := _spot("steps")
			_q = [[pin, z0, _pre + "clap_far9", "⑪ 손뼉 그림 말풍선 + 바람개비 — 가장 먼 축소 (9)", "hands"],
				[pin, z1, _pre + "clap_far16", "⑪ 손뼉 그림 말풍선 + 바람개비 — 기본 확대 (16)", "hands"],
				[pin + Vector2(-0.3, -0.3), NEAR, _pre + "clap_near", "⑪ 손뼉 그림 말풍선 + 바람개비 (44)", "hands"]]
		4:
			if not _run_q():
				return STAY
			scene.paused = false
			_wait = 220                               # 손뼉이 끝나고 흩어질 때까지
		5:
			_look(fire, NEAR)
			_settle()
			_advance_to(19.2)                         # 그날 저녁 '식구 열둘' 잔치 — 아직 밝을 때
			_wait = 50
		6:
			scene.paused = true
			_spots_report(v)
			_q = []
			for h in 4:
				_q.append([fire, NEAR, "%sfeast_h%d" % [_pre, h], "⑩ 여느 잔치 — 카메라 방위 %d (44)" % h, "", h])
			_q.append([fire, z1, _pre + "feast_z16", "⑩ 여느 잔치 — 기본 확대 (16)", "", 0])
			_q.append([fire, z0, _pre + "feast_z9", "⑩ 여느 잔치 — 가장 먼 축소 (9)", "", 0])
			var ep := _eater_pick(v, false)
			if ep != Vector2.INF:
				_q.append([ep, CLOSE, _pre + "eat_rig", "⑧ 먹는 손님 — 관절 인형 (64)", "", 0])
		7:
			if not _run_q():
				return STAY
			_force_frames(1)                          # ⑧ 그린 인형(방식 C)을 켜고 같은 장면
			_wait = 30
		8:
			for p in v.people:
				if p.action == "festival" and p.anim == "eat":
					var cm := scene.view.residents.get(p.id) as CutoutResident
					if cm != null:
						print("    먹는 인형 %d: 동작 %s · 몸 %s · 옷 %s · 아기 %s · 그린 인형 %s (%s) · 켬 %d · 될 수 있음 %s" % [p.id, cm._d_clip, cm.dlook.get("body", "?"), cm.dlook.get("personal", "?"), cm._baby, cm._f_on, cm._f_clip, cm.frames_force, cm._frames_ok()])
			var fp := _eater_pick(v, true)
			_q = []
			if fp != Vector2.INF:
				_q = [[fp, CLOSE, _pre + "eat_frame", "⑧ 먹는 손님 — 그린 인형 (64)", "", 0],
					[fp, NEAR, _pre + "eat_frame_near", "⑧ 먹는 손님 — 그린 인형 (44)", "", 0]]
		9:
			if not _run_q():
				return STAY
			_force_frames(-1)
			scene.paused = false
			_look(fire, NEAR)
			_settle()
			_advance_to(20.75)                        # 어두워진 뒤
			_wait = 50
		10:
			scene.paused = true
			_q = [[fire, NEAR, _pre + "evening", "⑩ 저녁 잔치 — 등불 (44)", "", 0]]
		11:
			if not _run_q():
				return STAY
			_advance_to(10.0)                         # 이튿날 아침
			_grow(v)                                  # 마을에서 난 첫 어른 (도구가 넘김)
			scene.view.sync(0.0, true)
			_spots_report(v)
			_q = [[_spot("grown"), NEAR, _pre + "post_day", "⑫ 키 재는 기둥 (낮 · 44)", "", 0],
				[fire, z1, _pre + "post_z16", "⑫ 키 재는 기둥 — 기본 확대 (16)", "", 0]]
		12:
			if not _run_q():
				return STAY
			scene.paused = false
			_advance_to(18.42)                        # 작은 잔치(18:30)가 시작되기 바로 전
			var kid := v.person(int(((v.milestones["passed"] as Dictionary).get("grown", {}) as Dictionary).get("who", -1)))
			var far := Vector2.INF                    # ⑦ 그 젊은이를 모닥불에서 멀리 (잔치에 올 수 있는 거리 안)
			for i in 16:
				var a := MilestoneView._right().angle() + TAU * float(i) / 16.0
				var c := v.fire + Vector2(cos(a), sin(a)) * 14.0
				if Milestones.spot_free(v, c) and not v.water_at(c.x, c.y):
					far = c
					break
			if kid != null and far != Vector2.INF:
				ResidentAI.cancel(v, kid)
				kid.sleeping = false
				kid.action = "idle"
				kid.anim = "idle"
				kid.x = far.x
				kid.y = far.y
				kid.px = far.x
				kid.py = far.y
			print("젊은이를 멀리 둠: %s (불에서 %.1f칸) · %.2f시" % [far, far.distance_to(v.fire), v.hour_now()])
			_look(fire, NEAR)
			_settle()
			_tries = 0
		13:
			_tries += 1
			if _tries % 30 == 1:
				var kid := v.person(int(((v.milestones["passed"] as Dictionary).get("grown", {}) as Dictionary).get("who", -1)))
				if kid != null:
					print("  젊은이 %.2f시 (화면 %d): %s/%s · 불에서 %.1f칸 · 키 재기 %d · 닿음 %s" % [v.hour_now(), _tries, kid.action, kid.anim,
						Vector2(kid.x, kid.y).distance_to(v.fire), _mv().star(), _mv().star_there()])
			if not (_mv().star_there() and _mv().ribbon_on()) and _tries < 1500 and (Milestones.feast_on(v) or v.hour_now() < 18.6):
				return STAY
			print("첫 어른 잔치: 키 재기 %d (닿음 %s · 끈 %s) · %.2f시 · 기다린 화면 %d · 잔치 중 %s" % [_mv().star(), _mv().star_there(), _mv().ribbon_on(), v.hour_now(), _tries,
				Milestones.feast_on(v)])
			_wait = 70
		14:
			scene.paused = true
			_spots_report(v)
			_q = []
			for h in 4:
				_q.append([fire, NEAR, "%sgrown_h%d" % [_pre, h], "⑦⑩ 첫 어른 잔치 (멀리 있던 젊은이) — 방위 %d (44)" % h, "", h])
			_q.append([_spot("grown") + Vector2(0.4, 0.4), CLOSE, _pre + "grown_close", "⑦ 키 재기 — 가까이 (64)", "", 0])
			_q.append([fire, z1, _pre + "grown_z16", "⑦ 첫 어른 잔치 — 기본 확대 (16)", "", 0])
		15:
			if not _run_q():
				return STAY
			var all := PackedStringArray()            # 전 | 후 나란히 (고치기 전 것이 있으면)
			for sp: String in shots:
				var bp := sp.replace("/m6_", "/m6_before_")
				if _pre == "m6_" and FileAccess.file_exists(bp):
					_labels[bp] = "[전] " + String(_labels.get(sp, ""))
					all.append(bp)
				all.append(sp)
			_compose(all, 6, 0.4)
			_wait = 4
		16:
			_compose_save(out_dir.path_join(_pre + "sheet.png"))
			return DONE
	return NEXT



# ───────────────────────── m7 (Q20 — 기둥의 새 방위 · 잔치의 글 말풍선 · 그린 인형이 빵 먹는 모습) ─────────────────────────
## 마을에서 난 아이가 어른이 됨 (첫걸음마 장면 없이 — 집이 있는 부부의 아이로 보태고 나이를 어른으로. 도구가 넘김)
func _grow_plain(v: Village) -> void:
	var mom: Resident = null
	for p in v.people:
		if p.is_adult() and p.sex == "f" and p.partner >= 0 and v.person(p.partner) != null and v.bld(p.home) != null:
			mom = p
			break
	var dad := v.person(mom.partner)
	var hm := v.bld(mom.home)
	var kid := v.add_person("보리", "m", 0.0, "", hm.x, hm.y, mom, dad)
	kid.parents = PackedInt32Array([mom.id, dad.id])
	kid.home = hm.id
	v.stats["born"] = int(v.stats.get("born", 0)) + 1
	scene.world.advance(2.0)
	kid.age = Balance.AGE_ADULT + 0.002
	scene.world.advance(2.0)
	var rec: Dictionary = (v.milestones.get("passed", {}) as Dictionary).get("grown", {})
	var at := Vector2(float(rec.get("x", 0.0)), float(rec.get("y", 0.0)))
	print("고비 기록 (어른이 됨): ", rec, " · 기둥: 불에서 %.2f칸 · 방위 %.0f° (시작 %.0f°) · 기본 보기 오른쪽 %.2f · 앞 %.2f" % [at.distance_to(v.fire),
		fposmod(rad_to_deg((at - v.fire).angle()), 360.0), Balance.POST_START_DEG, (at - v.fire).dot(MilestoneView._right()), (at - v.fire).dot(MilestoneView._front())])


## (㉜) 지금 뜬 글 말풍선과 비켜 갈 네모 (확인용 한 줄)
func _say_report() -> void:
	var keep := _mv().say_keep_out()
	var n := 0
	var hit := 0
	var texts: Array = []
	for c in (scene.get("bubbles") as Control).get_children():
		if c is Label and not c.is_queued_for_deletion():
			n += 1
			texts.append((c as Label).text)
			var rc := Rect2((c as Label).position, (c as Label).get_minimum_size())
			for k: Rect2 in keep:
				if rc.intersects(k):
					hit += 1
					break
	print("  m7: 글 말풍선 %d개 %s · 비켜 갈 네모 %d개 · 덮은 말풍선 %d" % [n, texts, keep.size(), hit])


## (㉜) 손님 셋을 상·등 바로 앞(카메라 쪽)에 세우고 한마디씩 — 비키지 않으면 말풍선이 상·등을 덮는 장면 (도구가 차림)
func _say_guests(v: Village) -> void:
	var mv := _mv()
	if not mv._spots.has("table") or mv._spots["table"] == Vector2.INF:
		print("  m7: 상이 없다 — 손님을 세우지 않음")
		return
	var tp: Vector2 = mv._spots["table"]
	var f2 := MilestoneView._front()
	var r2 := MilestoneView._right()
	var spots: Array = [tp + f2 * 0.45, tp + f2 * 0.45 + r2 * 0.7]
	for l: Array in mv._spots.get("lamps", []):
		spots.append((l[0] as Vector2) + f2 * 0.3)
	var kid_id := int(((v.milestones["passed"] as Dictionary).get("grown", {}) as Dictionary).get("who", -1))
	var n := 0
	for p in v.people:
		if n >= spots.size():
			break
		if p.dead or p.id == kid_id or p.action != "festival" or not p.is_adult():
			continue
		var sp: Vector2 = spots[n]
		p.x = sp.x
		p.y = sp.y
		p.px = sp.x
		p.py = sp.y
		p.steps.clear()
		scene.view.stage_say[p.id] = [String(MilestoneView.GROWN_SAY[n % MilestoneView.GROWN_SAY.size()]), "cheer", 240.0]
		n += 1
	if kid_id >= 0:
		scene.view.stage_say[kid_id] = [MilestoneView.STAR_SAY, "cheer", 240.0]
	scene.view.sync(0.0, true)
	print("  m7: 말할 손님 %d명을 상·등 앞에 세움" % n)


func _m7(v: Village) -> int:
	var fire := v.fire + Vector2(0.0, 0.4)
	var z1 := float(JarCamera.ZOOM_PPU[1])
	var z2 := float(JarCamera.ZOOM_PPU[2])
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 960)
				return STAY
			scene.set_debug_mode(false)
			_advance_to(10.5)
			scene.paused = true
			_look(fire, NEAR)
			_settle()
			_reach(v)                                 # 첫 빵 + 식구 열둘 → 그날 저녁 잔치
			_wait = 2
		1:
			scene.paused = false
			_look(fire, NEAR)
			_settle()
			_advance_to(19.2)                         # 잔치 — 아직 밝을 때
			_wait = 50
		2:
			scene.paused = true
			_q = []
			var ep := _eater_pick(v, false)
			if ep != Vector2.INF:
				_q.append([ep, CLOSE, "m7_eat_rig", "㉝ 먹는 손님 — 관절 인형 (64)", "", 0])
		3:
			if not _run_q():
				return STAY
			_force_frames(1)                          # 그린 인형(방식 C)을 켜고 같은 장면
			_wait = 30
		4:
			for p in v.people:
				if p.action == "festival" and p.anim == "eat":
					var cm := scene.view.residents.get(p.id) as CutoutResident
					if cm != null:
						print("    먹는 인형 %d: 동작 %s · 그린 인형 %s (%s) · 켬 %d · 될 수 있음 %s" % [p.id, cm._d_clip, cm._f_on, cm._f_clip, cm.frames_force, cm._frames_ok()])
			var fp := _eater_pick(v, true)
			_q = []
			if fp != Vector2.INF:
				_q = [[fp, CLOSE, "m7_eat_c_a", "㉝ 먹는 손님 — 그린 인형 방식 C (64)", "", 0],
					[fp + Vector2(0.01, 0.0), CLOSE, "m7_eat_c_b", "㉝ 먹는 손님 — 그린 인형, 조금 뒤 (64)", "", 0],
					[fp, NEAR, "m7_eat_c_near", "㉝ 먹는 손님 — 그린 인형 (44)", "", 0],
					[fp, z2, "m7_eat_c_z32", "㉝ 먹는 손님 — 그린 인형, 가까운 확대 (32)", "", 0]]
				var k := 0
				for p in v.people:                    # 그린 인형으로 먹는 손님마다 크게 한 장 (손·빵 자리 확인용)
					var cm2 := scene.view.residents.get(p.id) as CutoutResident
					if p.action == "festival" and p.anim == "eat" and cm2 != null and cm2._f_on:
						_q.append([Vector2(p.x, p.y) - MilestoneView._front() * 0.9, 128.0, "m7_eat_c_big%d" % k, "㉝ 그린 인형 — 확인용 확대 (128) · 주민 %d" % p.id, "", 0])
						k += 1
		5:
			if not _run_q():
				return STAY
			_force_frames(-1)
			scene.paused = false
			_look(fire, NEAR)
			_settle()
			_advance_to(10.0)                         # 이튿날 아침
			_grow_plain(v)                            # 마을에서 난 첫 어른 (도구가 넘김) → 기둥이 새 방위에 선다
			scene.paused = true
			scene.view.sync(0.0, true)
			_spots_report(v)
			_q = [[_spot("grown"), NEAR, "m7_post_day", "㉚ 새로 선 키 재는 기둥 (낮 · 44)", "", 0],
				[fire, z1, "m7_post_z16", "㉚ 키 재는 기둥 — 기본 확대 (16)", "", 0],
				[fire, z2, "m7_post_z32", "㉚ 키 재는 기둥 — 가까운 확대 (32)", "", 0]]
		6:
			if not _run_q():
				return STAY
			scene.paused = false
			_advance_to(18.42)                        # 작은 잔치(18:30)가 시작되기 바로 전
			_look(fire, NEAR)
			_settle()
			_tries = 0
		7:
			_tries += 1
			if not (_mv().star_there() and _mv().ribbon_on()) and _tries < 1500 and (Milestones.feast_on(v) or v.hour_now() < 18.6):
				return STAY
			print("첫 어른 잔치: 키 재기 %d (닿음 %s · 끈 %s) · %.2f시 · 기다린 화면 %d · 잔치 중 %s" % [_mv().star(), _mv().star_there(), _mv().ribbon_on(), v.hour_now(), _tries,
				Milestones.feast_on(v)])
			_wait = 70
		8:
			scene.paused = true
			_spots_report(v)
			_q = [[fire, z1, "m7_grown_z16", "㉚ 첫 어른 잔치 — 기본 확대 (16): 기둥은 불의 왼쪽 앞", "", 0],
				[fire, z2, "m7_grown_z32", "㉚ 첫 어른 잔치 — 가까운 확대 (32)", "", 0],
				[fire, NEAR, "m7_grown_near", "㉚ 첫 어른 잔치 (44)", "", 0]]
		9:
			if not _run_q():
				return STAY
			_say_guests(v)
			var mid := fire
			if _mv()._spots.has("table") and _mv()._spots["table"] != Vector2.INF:
				mid = ((_mv()._spots["table"] as Vector2) + _spot("grown")) * 0.5
			var back := MilestoneView._front() * -1.0     # 화면 위쪽 (상·말풍선이 위쪽 창 밑으로 들어가지 않게 조금 뒤를 본다)
			_q = [[fire, z1, "m7_say_z16", "㉜ 글 말풍선 — 상·등 앞 손님 + 젊은이 (16)", "", 0],
				[fire, z2, "m7_say_z32", "㉜ 글 말풍선 (32)", "", 0],
				[mid + back * 1.5, NEAR, "m7_say_near", "㉜ 글 말풍선 — 상·등·기둥 (44)", "", 0],
				[mid + back * 1.8, CLOSE, "m7_say_close", "㉜ 글 말풍선 — 가까이 (64)", "", 0]]
		10:
			if not _run_q():
				return STAY
			_compose(shots, 6, 0.4)
			_wait = 4
		11:
			_compose_save(out_dir.path_join("m7_sheet.png"))
			return DONE
	return NEXT
