## (Q31) 벚꽃 철 이름 부르기 캡처 (390×844 — 넓은 세상 world.tscn) — sim/names_call.gd · view/stagings.gd "names_call" · view/moment_cast.gd "names".
## 실행 (창이 필요 — 헤드리스 아님):
##   godot --path godot -s res://tools/shot_names_call.gd -- [n=4] [seed=20261106] [every=1.0] [days=1] [aware]
##   n = 그해 떠난 사람 수 (이름 말풍선 수 — 일곱이면 여섯 + "그리고… 여러 이웃") · days = 마을을 며칠 키운 뒤 · aware = 깨달은 마을
## 결과 (godot_shots/names_q31/): names_NN.png (연출 띠) · names_a_wide · names_b_walk · names_c_lamps · names_d_names · names_e_names2 · names_f_bow ·
##   names_g_card · names_after · names_strip (모아 보기) · names_chronicle (연대기 줄 + 도장 띠) · names_souvenir (어귀의 돌 위 말린 벚꽃)
extends SceneTree

const Sheet := preload("res://tools/contact_sheet.gd")
const H := 3600.0

var scene: Node
var out_dir := ""
var frame := 0
var _wait := 0
var steps: Array = []
var si := 0
var _until: Callable = Callable()
var _guard := 0
var n_dead := 4
var world_seed := 20261106
var every := 1.0
var grow_days := 1.0
var aware := false

var _tag := ""
var _next := 0.0
var _n := 0
var _strip: PackedStringArray = []
var _beats: Array = []


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("n="):
			n_dead = int(a.substr(2))
		elif a.begins_with("seed="):
			world_seed = int(a.substr(5))
		elif a.begins_with("every="):
			every = maxf(0.2, a.substr(6).to_float())
		elif a.begins_with("days="):
			grow_days = maxf(1.0, a.substr(5).to_float())
		elif a == "aware":
			aware = true
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/names_q31").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	Village.default_created = {"year": 2026, "month": 4, "day": 1}
	Village.start_aware = aware
	Market.reset(650.0)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = world_seed
	root.add_child(scene)
	scene.firsts.reset()
	steps = [_s_start, _s_deaths, _s_evening, _w_play, _s_strip, _w_end, _s_after, _s_chronicle, _s_chronicle_off, _s_souvenir, _s_end]


func v() -> Village:
	return scene.village


func d() -> StageDirector:
	return scene.director


func _save(name: String) -> String:
	var img := root.get_texture().get_image()
	var p := out_dir.path_join(name + ".png")
	img.save_png(p)
	var dd := d()
	print("saved %s %s (연출 %s %.1f초 · 어둠 %.2f · 인형 %d · 말풍선 %d · 빛 %d)" % [name, img.get_size(), dd.id, dd.t, dd.dark,
		dd._dolls.acts.size(), (scene.view as VillageView).stage_say.size(), dd._props.size()])
	return p


func _settle() -> void:
	scene.wterrain.zoom_ppu(scene.cam.ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()
	scene.refresh()


func _look(p: Vector2, ppu := 16.0) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()


func _run(secs: float) -> void:
	var vv := v()
	vv.water.offline = true
	var left := secs
	while left > 0.0:
		var s := minf(1800.0, left)
		scene.world.advance(s)
		left -= s
	vv.water.offline = false
	scene._sync_views()


## 병 날짜를 그해 month/day의 hour시로 (지금 v.t 기준 — 병 시계는 그대로)
func _set_date(month: int, day: int, hour: float) -> void:
	var vv := v()
	vv.created_date = {"year": 2027, "month": month, "day": day}
	vv.start_clock = hour * H - vv.t


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		root.size = Vector2i(390, 844)
		return false
	if scene.first_popup != null and scene.first_popup.showing():
		scene.first_popup.visible = false
	if _tag != "" and d().playing() and d().t >= _next:
		_strip.append(_save("%s_%02d" % [_tag, _n]))
		_n += 1
		_next += every
	if not _beats.is_empty() and d().playing() and d().t >= float(_beats[0][0]):
		_save(String(_beats[0][1]))
		_beats.pop_front()
	if _until.is_valid():
		_guard += 1
		if not bool(_until.call()) and _guard < 6000:
			return false
		_until = Callable()
		_wait = 1
	if _wait > 0:
		_wait -= 1
		return false
	if si >= steps.size():
		return true
	var w: Variant = (steps[si] as Callable).call()
	si += 1
	_wait = int(w) if w != null else 4
	return false


func _s_start() -> int:
	scene.paused = true
	scene.set_debug_mode(false)
	_run(grow_days * Balance.DAY)
	_set_date(4, 9, 10.0)
	_look(v().fire + Vector2(0.0, 2.0))
	_settle()
	var vv := v()
	var sp := NamesCall.spot(vv)
	var tr := GreatTrees.of_kind(vv.water as WorldWater, "cherry") if vv.water is WorldWater else {}
	var td := Vector2(float(tr.get("x", 0.0)), float(tr.get("y", 0.0))).distance_to(vv.center) - float(tr.get("r", 0.0)) if not tr.is_empty() else -1.0
	print("마을: 주민 %d · 영역 %.1f · 벚나무 줄기까지 %.1f칸 (닿는 거리 %.1f) · 모임 자리 %s %s" % [vv.people.size(), vv.territory_r(), td,
		vv.territory_r() + Balance.NAMES_TREE_REACH, sp["place"], str(sp["at"])])
	return 20


func _s_deaths() -> int:
	var vv := v()
	var keep := NamesCall.caller(vv)
	var gone: Array = []
	for i in n_dead:
		var r: Resident = null
		for p in vv.people:
			if p != keep and p.age >= Balance.AGE_ADULT and (r == null or p.age > r.age):
				r = p
		if r == null:
			for p in vv.people:
				if p != keep and not p.is_baby():
					r = p
					break
		if r == null:
			break
		gone.append(r.name)
		vv.kill(r, "노환" if r.is_elder() else "병")
		_run(0.5 * H)
	_run(8.0 * H)                                      # 장례 행렬이 끝나고 (장례 연출은 오래전 일이라 틀지 않음)
	print("떠난 사람: %s · 무덤 %d" % [", ".join(PackedStringArray(gone)), vv.graves.size()])
	return 20


func _s_evening() -> int:
	_set_date(4, 10, 17.8)
	var vv := v()
	vv.deficit = 0.0
	_run(0.25 * H)                                     # 18:00을 넘김 → 모임
	print("모임: %s · 까닭 '%s' · 연대기: %s" % [str(NamesCall.last(vv)), NamesCall.blocked(vv), String(vv.book[vv.book.size() - 1]["text"]) if not vv.book.is_empty() else ""])
	return 2


func _w_play() -> int:
	_guard = 0
	_until = func() -> bool: return d().playing() and d().id == Stagings.NAMES_ID
	return 0


func _s_strip() -> int:
	_tag = "names"
	_next = 0.0
	_n = 0
	_strip = []
	var sp: Dictionary = d().spec
	var cap := 0.0
	for b: Dictionary in sp["beats"]:
		if b.has("caption"):
			cap = float(b["t"])
	var k := d().k
	_beats = [[1.4 * k, "names_a_wide"], [2.6 * k, "names_b_walk"], [5.6 * k, "names_c_lamps"], [7.4 * k, "names_d_names"],
		[9.0 * k, "names_e_names2"], [(cap - 0.6) * k, "names_f_bow"], [(cap + 1.0) * k, "names_g_card"]]
	return 0


func _w_end() -> int:
	_guard = 0
	_until = func() -> bool: return not d().playing()
	return 0


func _s_after() -> int:
	_tag = ""
	_guard = 0
	var t1 := Time.get_ticks_msec() + 900
	_until = func() -> bool:
		if Time.get_ticks_msec() < t1:
			return false
		_strip.append(_save("names_after"))
		Sheet.make(_strip, out_dir.path_join("names_strip.png"), 0.5)
		return true
	return 0


func _s_chronicle() -> int:
	for id: String in Milestones.ORDER:                # (캡처만 · 연출 뒤) 앞 고비는 넘은 것으로 — 도장 띠의 창이 '이름 부르기'까지 오게
		if id != "names" and not Milestones.is_passed(v(), id):
			Milestones.mark_silent(v(), id)
	scene.chronicle.open(0)
	_guard = 0
	var t1 := Time.get_ticks_msec() + 600
	_until = func() -> bool:
		scene.chronicle.scroll.scroll_vertical = 1000000      # 맨 아래 (가장 새 줄)
		return Time.get_ticks_msec() >= t1
	return 0


func _s_chronicle_off() -> int:
	_save("names_chronicle")
	scene.chronicle.close()
	return 20


func _s_souvenir() -> int:
	_look(Souvenirs.spot(v()), 32.0)
	_settle()
	_guard = 0
	var t1 := Time.get_ticks_msec() + 700
	_until = func() -> bool:
		if Time.get_ticks_msec() < t1:
			return false
		_save("names_souvenir")
		return true
	return 0


func _s_end() -> bool:
	quit()
	return true
