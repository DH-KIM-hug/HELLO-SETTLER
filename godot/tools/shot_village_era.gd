## 마을 시대 건물 (A6) · 등불 옮기기 (A11) 캡처 — 실행 (창이 필요 — 헤드리스 아님): godot --path godot -s res://tools/shot_village_era.gd
## 넓은 세상(world.tscn, 시드 20261106) 기본 키트를 이틀 돌리고 계시(마을 시대) → 마을 시대 건물을 사 준 것처럼 완성해 두고 390×844:
##   village_era_herbalist.png (약초꾼이 숲가에서 약초를 캠) · village_era_clinic.png (치료소 툇마루에 누운 사람들 + 약초사) ·
##   village_era_chapel.png (저녁 기도 — 교회 앞에 모인 사람들) · village_era_plaza.png (광장에 모여 어울림) ·
##   village_era_funeral.png (장례 행렬 + 묘지의 무덤 돌) · village_era_watch_before / _after.png (망루가 걷은 안개) ·
##   village_era_ferry.png (나루터 뗏목으로 강을 건넘) ·
##   lamp_compass.png (작은 나침반) · lamp_hint.png (노인의 귀띔) · lamp_preview.png (볕·그늘 색 + 골 화살표 + 말) ·
##   lamp_turning.png (그림자가 도는 중) · lamp_after.png (옮긴 뒤 — 구석의 작은 해) · lamp_sun.png (구석의 해 확대) ·
##   village_era_sheet.png · lamp_sheet.png (모아 보기)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")

var scene: Node
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var shots: PackedStringArray = []
var lamp_shots: PackedStringArray = []
var v: Village
var plan: Array[Callable] = []
var B := {}                           # 종류 → 건물


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Market.reset(2400.0)
	Village.start_aware = true
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261106
	root.add_child(scene)
	plan = [_setup, _settle_w, _herb_go, _settle_w, _herb_shot, _clinic_go, _settle_w, _clinic_shot, _chapel_go, _settle_w, _chapel_shot,
		_plaza_go, _settle_w, _plaza_shot, _funeral_go, _settle_w, _funeral_shot, _ferry_go, _settle_w, _ferry_shot,
		_watch_before, _settle_w, _watch_before_shot, _watch_after, _settle_w, _watch_after_shot,
		_lamp_compass, _lamp_compass_shot, _lamp_hint_shot, _lamp_preview, _lamp_preview_shot, _lamp_move, _lamp_turning_shot,
		_lamp_after, _settle_w, _lamp_after_shot, _finish]
	if OS.get_environment("SHOT_ONLY") == "ferry":
		plan = [_setup, _ferry_go, _settle_w, _ferry_shot, _finish]


func _save(name: String, lamp := false, crop := Rect2i()) -> void:
	var img := root.get_texture().get_image()
	if crop.size.x > 0:
		img = img.get_region(crop)
		img.resize(crop.size.x * 3, crop.size.y * 3, Image.INTERPOLATE_NEAREST)
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	(lamp_shots if lamp else shots).append(p)
	print("saved %s %s" % [name, img.get_size()])


func _settle() -> void:
	scene.clock.notice_t = 0.0
	v.warnings.clear()
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.view.sync(0.0, true)


func _look(p: Vector2, ppu: float) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _run(secs: float, step_s := 60.0) -> void:
	var left := secs
	while left > 0.0:
		var d := minf(step_s, left)
		scene.world.advance(d)
		left -= d


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(390, 844)
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	var w: Variant = plan[step].call()
	step += 1
	_wait = int(w) if w != null else 4
	return step >= plan.size() and _wait <= 0


# ───────────────────────── 마을 시대 ─────────────────────────
func _place(type: String) -> Building:
	var sp: Variant = v.find_spot(type)
	if sp == null:
		print("자리 없음: %s" % type)
		return null
	var b := v.add_building(type, (sp as Vector2).x, (sp as Vector2).y, true)
	b.bought = true
	v.on_built(b)
	B[type] = b
	return b


func _staff(b: Building) -> Resident:
	if b == null:
		return null
	for r in v.people:
		if r.is_adult() and r.job < 0:
			r.job = b.id
			b.worker = r.id
			return r
	for r in v.people:
		if r.is_adult() and v.bld(r.job) != null and v.bld(r.job).type != "농장":
			v.bld(r.job).worker = -1
			r.job = b.id
			b.worker = r.id
			return r
	return null


func _setup() -> int:
	v = scene.village
	v.water.offline = true
	_run(2.0 * 24.0 * 3600.0, 3600.0)              # 1일차 07:00 → 3일차 07:00
	v.era_pts = Balance.ERA_NEED[0]
	v.reveal()
	for k: String in ["판자", "돌", "통나무", "빵", "밀"]:
		v.stock[k] = maxf(float(v.stock.get(k, 0.0)), 120.0)
	v.stock["도구"] = 20.0
	for i in 8:                                     # 이웃이 늘었다 (광장·교회 모임이 보이게)
		var q := v.add_person(["안나", "요한", "마리", "루카", "소피", "다비드", "릴리", "노아"][i], "f" if i % 2 == 0 else "m", 5.0 + i, "",
			v.center.x + 1.0, v.center.y + 1.0, null, null)
		q.belief = 0.9
	v.faith = 85.0
	for ty: String in ["약초꾼", "치료소", "교회", "광장", "묘지"]:
		_place(ty)
	_staff(B.get("약초꾼"))
	_staff(B.get("치료소"))
	_staff(B.get("교회"))
	v.water.offline = false
	scene.paused = true
	scene.set_debug_mode(false)
	print("마을 시대 · 인구 %d · 건물 %s" % [v.people.size(), ", ".join(PackedStringArray(B.keys()))])
	return 20


func _settle_w() -> int:
	_settle()
	return 8


func _herb_go() -> int:
	var b: Building = B.get("약초꾼")
	var hb := v.person(b.worker) if b != null else null
	for i in 60:
		_run(60.0, 30.0)
		if hb != null and hb.doing == "약초를 캐는 중" and hb.anim == "work":
			break
	if hb != null:
		_look(Vector2(hb.x, hb.y).lerp(Vector2(b.x, b.y), 0.3) + Vector2(0.5, 0.5), 34.0)
		print("약초꾼 오두막 (%.1f, %.1f) · 캐는 자리 (%.1f, %.1f)" % [b.x, b.y, hb.x, hb.y])
		print("약초꾼 %s: %s (약초 %.0f)" % [hb.name, hb.doing, float(v.stock.get("약초", 0.0))])
	return 10


func _herb_shot() -> int:
	_save("village_era_herbalist")
	return 2


func _clinic_go() -> int:
	var b: Building = B.get("치료소")
	var n := 0
	for r in v.people:
		if n >= 3:
			break
		if r.job == b.id or r.age < 3.0 or r.is_baby():
			continue
		Health.fall_ill(v, r, true, "고뿔")
		r.sick_left = 2.0 * Balance.DAY
		ResidentAI.cancel(v, r)
		n += 1
	_run(30.0 * 60.0, 20.0)
	_look(VillageEra.local_to_world(b, 0.0, b.size() + 0.6), 40.0)
	var lying := v.people.filter(func(q: Resident) -> bool: return q.doing == "치료소에 누운 중").size()
	print("치료소 (%.1f, %.1f) 화면 %s · 누운 사람 %d명" % [b.x, b.y, str(scene.lamp_screen(Vector2(b.x, b.y))), lying])
	for q in v.people:
		if q.sick_left > 0.0:
			print("  %s (%.1f, %.1f) %s %s" % [q.name, q.x, q.y, q.doing, q.anim])
	return 10


func _clinic_shot() -> int:
	_save("village_era_clinic")
	for r in v.people:
		if r.sick_left > 0.0:
			Health.recover(v, r, v.t)
	return 2


func _chapel_go() -> int:
	var h := v.hour_now()
	var want := 20.6
	_run(fposmod(want - h, 24.0) * 3600.0, 120.0)
	v.evening_offering()
	_run(150.0, 10.0)
	var ch: Building = B.get("교회")
	_look(Vector2(ch.x, ch.y) + VillageEra.front(ch) * 2.4, 26.0)
	var n := v.people.filter(func(q: Resident) -> bool: return q.doing.contains("교회")).size()
	print("교회 앞 기도 %d명 · 종 %s" % [n, str(v.bell_t == v.t)])
	return 12


func _chapel_shot() -> int:
	_save("village_era_chapel")
	return 2


func _plaza_go() -> int:
	_run(fposmod(18.6 - v.hour_now(), 24.0) * 3600.0, 300.0)
	var pz: Building = B.get("광장")
	var n := 0
	for r in v.people:
		if n >= 9:
			break
		if r.sleeping or r.is_baby() or r.sick_left > 0.0 or r.age < 2.5:
			continue
		ResidentAI.cancel(v, r)
		ResidentAI._do(v, r, "social", 18.6)
		r.action = "social"
		n += 1
	_run(120.0, 10.0)
	_look(Vector2(pz.x, pz.y) + Vector2(0.6, 0.6), 28.0)
	return 12


func _plaza_shot() -> int:
	_save("village_era_plaza")
	return 2


func _funeral_go() -> int:
	_run(fposmod(10.0 - v.hour_now(), 24.0) * 3600.0, 300.0)
	var gy: Building = B.get("묘지")
	# 먼저 떠난 이들 (무덤 셋)
	for nm: String in ["옛 할아버지", "옛 할머니"]:
		var q := v.add_person(nm, "m", 22.0, "", gy.x, gy.y, null, null)
		v.kill(q, "노환")
	var old: Resident = null
	for r in v.people:
		if r.is_elder() or (old == null and r.is_adult() and r.age > 12.0):
			old = r
	v.kill(old, "노환")
	_run(70.0, 5.0)
	_look(Vector2(gy.x, gy.y) + Vector2(1.6, 1.6), 26.0)
	print("무덤 %d · 장례 %d명" % [v.graves.size(), v.people.filter(func(q: Resident) -> bool: return q.doing.contains("장례")).size()])
	return 12


func _funeral_shot() -> int:
	_save("village_era_funeral")
	return 2


func _ferry_go() -> int:
	var fb: Building = null
	for q in v.buildings:                           # 촌장이 이미 지은 나루터가 있으면 그것 (강을 자주 걸어 건넜다)
		if q.type == "나루터" and q.built and q.has_link:
			fb = q
			print("촌장이 지은 나루터")
	if fb == null:
		fb = _place("나루터")
	if fb == null or not fb.has_link:
		print("나루터 자리 없음 (강이 영역 안에 없음)")
		return 2
	var a := Vector2(fb.x, fb.y)
	var c := Vector2(fb.link_x, fb.link_y)
	var side := (c - a).normalized()
	var n := 0
	for r in v.people:
		if n >= 3:
			break
		if not r.is_adult() or r.sick_left > 0.0:
			continue
		ResidentAI.cancel(v, r)
		r.x = a.x - side.x * (1.0 + n)
		r.y = a.y - side.y * (1.0 + n)
		var to := c + side * 4.0
		r.steps.append(ResidentAI.walk(to.x, to.y))
		r.steps.append(ResidentAI.act(600.0, "idle"))
		r.action = "walk"
		if n == 0:
			print("나루터 (%.1f, %.1f) → (%.1f, %.1f) · 곧장 가면 물 %.1f칸 · 물 깊이 가운데 %.4f" % [a.x, a.y, c.x, c.y,
				VillageEra._wet_len(v, Vector2(r.x, r.y), to), v.water.depth(v.water.idx(a.lerp(c, 0.5).x, a.lerp(c, 0.5).y))])
		n += 1
	var first: Resident = null
	for r in v.people:
		if r.action == "walk":
			first = r
			break
	if first != null:
		var fw := Vector2(first.x, first.y)
		var tw := Vector2(float(first.steps[0]["x"]), float(first.steps[0]["y"]))
		var wet := VillageEra._wet_len(v, fw, tw)
		print("  곧장 %.1f (물 %.1f) · 돌아서 %.1f · 나루터 %d채" % [fw.distance_to(tw) - wet + wet / Balance.WADE_SPEED, wet,
			fw.distance_to(a) + a.distance_to(c) + c.distance_to(tw), v.buildings.filter(func(q: Building) -> bool: return q.type == "나루터" and q.built and q.has_link).size()])
	for i in 120:
		_run(0.5, 0.5)
		if i < 12 and first != null:
			print("  %.1f초 %s (%.1f, %.1f) 걸음 %s" % [i * 0.5, first.name, first.x, first.y, str(first.steps.map(func(q: Dictionary) -> String: return "%s%s" % [q["k"], "(뗏목)" if q.get("raft", false) else ""]))])
		var on := v.people.filter(func(q: Resident) -> bool: return not q.steps.is_empty() and bool(q.steps[0].get("raft", false)))
		if not on.is_empty() and Vector2(on[0].x, on[0].y).distance_to(a) > a.distance_to(c) * 0.45:
			print("뗏목: %s (%.1f칸 / %.1f칸)" % [on[0].name, Vector2(on[0].x, on[0].y).distance_to(a), a.distance_to(c)])
			break
	_look(a.lerp(c, 0.4) + Vector2(0.5, 0.5), 36.0)
	return 12


func _ferry_shot() -> int:
	for q in v.people:
		if not q.steps.is_empty() and bool(q.steps[0].get("raft", false)):
			var m: Node3D = scene.view.residents.get(q.id)
			print("뗏목 위 %s (%.1f, %.1f) 모델 %s 보임 %s 화면 %s" % [q.name, q.x, q.y, str(m.global_position) if m != null else "-",
				str(m.visible) if m != null else "-", str(scene.cam.camera.unproject_position(m.global_position)) if m != null else "-"])
	_save("village_era_ferry")
	return 2


var _watch_p := Vector2.ZERO
var _fog_n := 0


func _fog_count() -> int:
	var n := 0
	for f in v.water.fog:
		if f != 0:
			n += 1
	return n


func _watch_before() -> int:
	var sp: Variant = v.find_spot("망루")
	_watch_p = sp if sp != null else v.center
	_fog_n = _fog_count()
	_look(_watch_p.lerp(v.center, 0.3), 5.0)
	return 12


func _watch_before_shot() -> int:
	_save("village_era_watch_before")
	return 2


func _watch_after() -> int:
	var b := _place("망루")
	print("망루 %s (계획 %s) · 본 땅 %d → %d칸" % [str(Vector2(b.x, b.y)) if b != null else "없음", str(_watch_p), _fog_n, _fog_count()])
	return 20


func _watch_after_shot() -> int:
	_save("village_era_watch_after")
	return 2


# ───────────────────────── 등불 옮기기 ─────────────────────────
func _lamp_compass() -> int:
	_run(fposmod(11.0 - v.hour_now(), 24.0) * 3600.0, 600.0)
	_look(v.center + Vector2(1.0, 2.0), 16.0)
	_settle()
	scene.toggle_hand()
	scene.move_lamp()
	return 12


func _lamp_compass_shot() -> int:
	_save("lamp_compass", true)
	var lc: LampCtl = scene.lamp_ctl
	lc.choose(posmod(Lamp.spot(v.water) + 2, 4))
	return 10


func _lamp_hint_shot() -> int:
	_save("lamp_hint", true)
	return 2


func _lamp_preview() -> int:
	var lc: LampCtl = scene.lamp_ctl
	lc._show_preview(lc.picked)
	scene.paused = false
	return 150                                      # 날아 올라가는 동안


func _lamp_preview_shot() -> int:
	_settle()
	_save("lamp_preview", true)
	print("미리보기: %s" % (scene.lamp_ctl as LampCtl).prev_text.text.replace("\n", " / "))
	return 2


func _lamp_move() -> int:
	(scene.lamp_ctl as LampCtl).confirm()
	return 80                                       # 날아 돌아오는 동안 (그림자는 3초 동안 돎) — 그 가운데쯤


func _lamp_turning_shot() -> int:
	_settle()
	_save("lamp_turning", true)
	return 200


func _lamp_after() -> int:
	scene.paused = true
	_look(v.center + Vector2(1.0, 2.0), 16.0)
	return 20


func _lamp_after_shot() -> int:
	_save("lamp_after", true)
	var lc: LampCtl = scene.lamp_ctl
	var r := Rect2i(Vector2i(lc.badge.global_position) - Vector2i(4, 4), Vector2i(lc.badge.size) + Vector2i(8, 8))
	var k := float(root.size.x) / scene.get_viewport().get_visible_rect().size.x
	_save("lamp_sun", true, Rect2i(Vector2i(Vector2(r.position) * k), Vector2i(Vector2(r.size) * k)))
	print("연대기: %s" % String(v.book[v.book.size() - 1]["text"]))
	return 2


func _finish() -> int:
	Sheet.make(shots, out_dir.path_join("village_era_sheet.png"), 0.5)
	Sheet.make(lamp_shots, out_dir.path_join("lamp_sheet.png"), 0.5)
	print("saved sheets")
	quit()
	return 0
