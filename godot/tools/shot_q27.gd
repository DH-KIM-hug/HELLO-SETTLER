## 4~7일차 고비 넷 (ROADMAP Q27) 캡처 — 일터 스물 · 첫 돌집 · 삼대가 한집에 · 큰 마을 (sim/milestones.gd · view/ui/milestone_stamps.gd · view/souvenir_view.gd).
## 실행 (창 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_q27.gd
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트. 세로 화면 540×960. 결과 godot_shots/milestones_q27/:
##   q27_strip_before (연대기 — 첫 28일 고비 여섯을 넘은 띠, 다음 고비 = 일터 스물) ·
##   q27_work20_book (일터 스물을 넘은 바로 뒤 연대기 '최근' — 연대기 줄 · 도장) · q27_work20_stone (어귀의 납작한 돌 위 '작은 나무 망치') ·
##   q27_stone_house (첫 돌집 — 식구가 든 집, 마을 확대) · q27_stone_book · q27_stone_feast (그날 저녁 집들이 잔치) ·
##   q27_gen3_book (삼대가 한집에) · q27_pop35_book (큰 마을) · q27_pop35_feast · q27_souvenirs (돌 위 기념품 셋 + '더' 바구니) ·
##   q27_strip_all (고비 열하나 가운데 열을 넘은 띠 — 다음 = 첫 겨울) · q27_sheet (모아 보기)
## 고비는 도구가 조건만 차린다 (일터를 짓고 · 돌집에 식구를 들이고 · 삼대를 한 집에 · 식구를 늘림) — 알아차리고 넘는 것은 마을이 한다 (시험과 같은 길).
## 저장: 진짜 저장·설정을 건드리지 않는다 (tools/shot_milestones.gd와 같은 방법 — 제 폴더 SAVE_DIR).
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")
const SAVE_DIR := "user://_tool/shot_q27/save"
const NAMES := ["다래", "솔이", "가람", "누리", "보람", "한결", "이슬", "마루", "새봄", "하늘이", "도담", "나래",
	"가온", "라온", "미르", "바다", "산들", "아라", "온새", "하랑", "윤슬", "다솜", "예솔", "초롱"]

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var _tri: Array = []
var _to_end := false                                  # 연대기를 연 뒤 맨 아래(방금 적힌 줄)까지 내린다


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/milestones_q27").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
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
	scene.firsts = Firsts.new()
	root.add_child(scene)
	if scene.director != null:
		scene.director.pic_dir = SAVE_DIR.path_join("chron_pics")


func _quiet() -> void:
	scene.firsts.queue.clear()
	if scene.first_popup != null and scene.first_popup.showing():
		scene.first_popup.close()


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	shots.append(p)
	var v: Village = scene.village
	print("saved %s · %.2f시 · 넘은 고비 %s · 다음: %s" % [name, v.hour_now(), str((v.milestones.get("passed", {}) as Dictionary).keys()), Milestones.next_line(v)])


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


func _advance(secs: float) -> void:
	var v: Village = scene.village
	v.water.offline = true
	scene.world.advance(secs)
	v.water.offline = false


func _advance_to(hour: float) -> void:
	_advance(fposmod(hour - scene.village.hour_now(), 24.0) * 3600.0)


## 모닥불에서 바깥으로 빈자리를 찾아 다 지은 건물 하나
func _place(v: Village, type: String, r0: float) -> Building:
	for ring in 30:
		for i in 18:
			var a := TAU * float(i) / 18.0 + 0.2 * float(ring)
			var p := v.fire + Vector2(cos(a), sin(a)) * (r0 + 1.3 * float(ring))
			if v.is_free(p.x, p.y, Balance.B[type]["size"]) and Milestones.spot_free(v, p):
				return v.add_building(type, p.x, p.y, true)
	return v.add_building(type, v.fire.x + r0, v.fire.y, true)


## 첫 28일의 고비 여섯을 조용히 넘은 것으로 (띠·다음 고비 줄만 보려고 — 장식·기념품은 조용히)
func _early(v: Village) -> void:
	for id: String in ["bread", "steps", "pop12", "grown", "green", "pop20"]:
		if not Milestones.is_passed(v, id):
			Milestones._mark_silent(v, id)
	v.stats["first_bread"] = 1


func _book_tab() -> void:
	scene.chronicle.open(0)
	_to_end = true


func _last_lines(v: Village, n: int) -> void:
	for b: Dictionary in v.book.slice(maxi(0, v.book.size() - n)):
		print("  연대기: ", b["text"])


func _process(_dt: float) -> bool:
	frame += 1
	if frame > 12:
		_quiet()
		if scene.director != null and scene.director.playing():
			scene.director.skip()                     # 연출(고비 · 처음 겪는 일)은 건너뛰고 마을 모습만 찍는다
	if _wait > 0:
		if _to_end and _wait == 4:
			scene.chronicle.scroll.scroll_vertical = 1000000
			_to_end = false
		_wait -= 1
		return false
	var v: Village = scene.village
	match step:
		0:
			if frame < 10:
				root.size = Vector2i(540, 960)
				return false
			scene.set_debug_mode(false)
			_advance(2.0)
			_early(v)
			v.stock["빵"] = float(v.stock.get("빵", 0.0)) + 3000.0     # 도구가 늘리는 식구가 굶지 않게 (장면용)
			_advance_to(9.0)
			scene.paused = true
			_look(v.fire, 32.0)
			_settle()
			_book_tab()
			_wait = 14
		1:
			_save("q27_strip_before")
			scene.chronicle.close()
			var i := 0
			while Milestones.workplaces(v) < Milestones.WORK_MANY and i < 40:
				_place(v, "나무꾼" if i % 2 == 0 else "어부", 9.0)
				i += 1
			_advance(Balance.MILESTONE_LOOK_SECS * 1.2)
			print("일터 %d곳 · 일터 스물 %s" % [Milestones.workplaces(v), Milestones.is_passed(v, "work20")])
			_last_lines(v, 3)
			_book_tab()
			_wait = 14
		2:
			_save("q27_work20_book")
			scene.chronicle.close()
			Souvenirs.keep_spot(v)
			_look(Souvenirs.spot(v), 32.0)
			_settle()
			_wait = 20
		3:
			_save("q27_work20_stone")
			var h := _place(v, "석조주택", 12.0)
			var fam: Resident = null
			for p in v.people:
				if p.is_adult() and p.partner >= 0:
					fam = p
					break
			for q in v.household_of(fam):
				q.home = h.id
			_advance(Balance.MILESTONE_LOOK_SECS * 1.2)
			print("첫 돌집 %s · 집 %d" % [Milestones.is_passed(v, "stone"), h.id])
			if scene.director != null and scene.director.playing():
				scene.director.skip()
			_last_lines(v, 3)
			_look(Vector2(h.x, h.y), 32.0)
			_settle()
			_wait = 20
		4:
			_save("q27_stone_house")
			_book_tab()
			_wait = 14
		5:
			_save("q27_stone_book")
			scene.chronicle.close()
			_advance_to(19.3)
			if scene.director != null and scene.director.playing():
				scene.director.skip()
			scene.paused = false
			_look(v.fire + Vector2(0.0, 0.4), 40.0)
			_settle()
			_wait = 90
		6:
			_save("q27_stone_feast")
			scene.paused = true
			_advance_to(9.0)
			var top: Resident = null
			for p in v.people:
				if p.is_adult() and (top == null or p.age > top.age):
					top = p
			var h := v.bld(top.home) if top.home >= 0 else _place(v, "목조주택", 7.0)
			var mid := v.add_person("소담", "f", Balance.AGE_ADULT + 1.0, "", h.x, h.y, top, top)
			mid.parents = PackedInt32Array([top.id, top.partner if top.partner >= 0 else top.id])
			var kid := v.add_person("아롱", "m", 0.6, "", h.x, h.y, mid, mid)
			kid.parents = PackedInt32Array([mid.id, mid.id])
			top.home = h.id
			mid.home = h.id
			kid.home = h.id
			_advance(Balance.MILESTONE_LOOK_SECS * 1.2)
			print("삼대 %s" % Milestones.is_passed(v, "gen3"))
			_last_lines(v, 3)
			_book_tab()
			_wait = 14
		7:
			_save("q27_gen3_book")
			scene.chronicle.close()
			_advance_to(9.0)
			var i := 0
			while v.people.size() < Milestones.POP_TOWN:
				var nm := String(NAMES[i % NAMES.size()])
				v.add_person(nm, "f" if i % 2 == 0 else "m", 6.0 + float(i % 5), "", v.fire.x + 1.5, v.fire.y - 1.0 + 0.2 * float(i % 9), null, null)
				i += 1
			v.stock["빵"] = float(v.stock.get("빵", 0.0)) + 3000.0     # 갑자기 늘린 식구가 굶지 않게 (장면용)
			_advance(2.0)
			print("큰 마을 %s (%d명)" % [Milestones.is_passed(v, "pop35"), v.people.size()])
			_last_lines(v, 3)
			_book_tab()
			_wait = 14
		8:
			_save("q27_pop35_book")
			scene.chronicle.close()
			_advance_to(19.3)
			if scene.director != null and scene.director.playing():
				scene.director.skip()
			scene.paused = false
			_look(v.fire + Vector2(0.0, 0.4), 32.0)
			_settle()
			_wait = 90
		9:
			_save("q27_pop35_feast")
			scene.paused = true
			_advance_to(10.0)
			for id: String in ["bread", "steps", "pop12", "grown", "green", "pop20"]:     # 앞의 것은 주워 두고 새 기념품 넷이 돌 위에 (셋 + '더' 바구니)
				Souvenirs.take(v, id)
			Souvenirs.keep_spot(v)
			_look(Souvenirs.spot(v), 64.0)
			_settle()
			_wait = 20
		10:
			_save("q27_souvenirs")
			print("기다리는 기념품: ", Souvenirs.waiting(v).map(func(s: Dictionary) -> String: return String(s["id"])))
			_book_tab()
			_wait = 14
		11:
			_save("q27_strip_all")
			Sheet.make(shots, out_dir.path_join("q27_sheet.png"), 0.5)
			print("sheet ", out_dir.path_join("q27_sheet.png"))
			return true
	step += 1
	return false
