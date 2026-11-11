## 유모차 산책 · 아이의 첫 심부름 · 아이의 첫 낚시 (ROADMAP E2-2 · E2-3) 캡처. 실행 (창이 필요): godot --path godot -s res://tools/shot_kids2.gd
## 넓은 세상(world.tscn) 마을에 가족(젖먹이·아이 넷·노인)을 꾸려 1080×1920(논리 360×640)으로 찍는다 → godot_shots/kids2/k2_*.png
##   K2_ONLY=pram·meet·dog·park·errand·fish·book 로 하나씩 (비우면 전부 + 한 장 모음 k2_sheet.png · 연대기는 k2_book_1~3)
## 마을 기본 확대(ppu 21)와 가까이(ppu 44). 저장은 도구 지킴이 폴더(user://_tool/…)로만 간다 (save/user_paths.gd).
extends SceneTree

const ADD := ["목조주택", "목조주택", "목조주택", "창고", "우물", "광장"]
const FAR := 21.0
const NEAR := 44.0

var scene: Node
var vp: SubViewport
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var infant: Resident
var kids: Array[Resident] = []
var mum_i: Resident
var mum_t: Resident
var elder: Resident
var nb: Resident                  # 이웃 어른
var sheet: PackedStringArray = []
var _area := Vector2.ZERO         # 트인 띠의 왼쪽 위 (가로 8.8 · 세로 4)
var _hb: Building                 # 아기네 집 (심부름을 받는 집)
var _hc: Building                 # 심부름 가는 아이네 집
var _hf: Building                 # 물가의 집 (첫 낚시)
var _c := Vector2.ZERO
var _follow: Resident
var _half := Vector2(80, 68)
var _half_wide := Vector2.ZERO
var _until_n := 0


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/kids2").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	CutoutResident.override = 1
	Village.default_created = {"year": 2026, "month": 6, "day": 15}
	Village.start_aware = true
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = 20261107
	vp.add_child(scene)
	var only := OS.get_environment("K2_ONLY")
	plan = [_build]
	if only == "" or only.contains("errand"):
		plan.append(_s_errand.bind(2, ""))
		_seq("k2_errand_carry", NEAR, 3, 50)
		plan.append(_until.bind(_err_ph.bind(2), 1500))
		_seq("k2_errand_give", NEAR, 4, 22)
		plan.append(_until.bind(_err_ph.bind(3), 400))
		_seq("k2_errand_pat", NEAR, 4, 18)
		plan.append(_until.bind(_err_ph.bind(4), 400))
		_seq("k2_errand_skip", NEAR, 5, 16)
		plan.append(_until.bind(_err_ph.bind(-1), 1500))
		plan.append(_s_errand.bind(3, ""))
		_seq("k2_errand_far_carry", FAR, 2, 60)
		plan.append(_until.bind(_err_ph.bind(2), 1500))
		_seq("k2_errand_far_give", FAR, 2, 40)
		plan.append(_until.bind(_err_ph.bind(3), 400))
		_seq("k2_errand_far_pat", FAR, 2, 30)
		plan.append(_until.bind(_err_ph.bind(4), 400))
		_seq("k2_errand_far_skip", FAR, 3, 22)
		plan.append(_until.bind(_err_ph.bind(-1), 1500))
		plan.append(_s_errand.bind(0, "sick"))
		_seq("k2_errand_bowl_carry", NEAR, 2, 60)
		plan.append(_until.bind(_err_ph.bind(2), 1500))
		_seq("k2_errand_bowl_give", NEAR, 3, 26)
		plan.append(_until.bind(_err_ph.bind(-1), 2400))
	if only == "" or only.contains("pram"):
		for h: Array in [["side", Vector2(1.0, 0.0)], ["left", Vector2(-1.0, 0.0)], ["frontside", Vector2(0.75, 0.66)], ["backside", Vector2(0.75, -0.66)],
				["front", Vector2(0.0, 1.0)], ["back", Vector2(0.0, -1.0)]]:
			plan.append(_s_pram.bind(h[1], false, false))
			_seq("k2_pram_%s" % h[0], NEAR, 3, 55)
			_seq("k2_pram_%s_far" % h[0], FAR, 1, 40)
	if only == "" or only.contains("meet"):
		plan.append(_s_pram.bind(Vector2(1.0, 0.0), true, false))
		plan.append(_until.bind(_meet_on, 900))
		_seq("k2_meet", NEAR, 6, 24)
		plan.append(_until.bind(_meet_off, 900))
		plan.append(_s_pram.bind(Vector2(-1.0, 0.0), true, false))
		plan.append(_until.bind(_meet_on, 900))
		_seq("k2_meet_far", FAR, 3, 40)
		plan.append(_until.bind(_meet_off, 900))
		plan.append(_s_pram.bind(Vector2(0.0, 1.0), true, false))
		plan.append(_until.bind(_meet_on, 900))
		_seq("k2_meet_front", NEAR, 3, 40)
		plan.append(_until.bind(_meet_off, 900))
	if only == "" or only.contains("dog"):
		plan.append(_s_pram.bind(Vector2(1.0, 0.0), false, true))
		_seq("k2_dog", NEAR, 4, 60)
		plan.append(_s_pram.bind(Vector2(-0.75, 0.66), false, true))
		_seq("k2_dog_far", FAR, 2, 80)
	if only == "" or only.contains("fish"):
		plan.append(_s_fish.bind(2))
		_seq("k2_fish_go", NEAR, 2, 60)
		plan.append(_until.bind(_fish_ph.bind(1), 2400))
		_seq("k2_fish_sit", NEAR, 3, 70)
		plan.append(_until.bind(_fish_ph.bind(2), 900))
		_seq("k2_fish_bite", NEAR, 2, 20)
		plan.append(_until.bind(_fish_ph.bind(3), 400))
		_seq("k2_fish_catch", NEAR, 6, 20)
		plan.append(_until.bind(_fish_ph.bind(4), 400))
		_seq("k2_fish_home", NEAR, 3, 40)
		plan.append(_until.bind(_fish_ph.bind(-1), 2400))
		plan.append(_s_fish.bind(3))
		_seq("k2_fish_far_go", FAR, 1, 80)
		plan.append(_until.bind(_fish_ph.bind(1), 2400))
		_seq("k2_fish_far_sit", FAR, 2, 120)
		plan.append(_until.bind(_fish_ph.bind(3), 900))
		_seq("k2_fish_far_catch", FAR, 4, 28)
		plan.append(_until.bind(_fish_ph.bind(-1), 2400))
	if only == "" or only.contains("park"):
		plan.append(_s_park.bind(false))
		_seq("k2_park", NEAR, 2, 50)
		_seq("k2_park_far", FAR, 1, 30)
		plan.append(_s_park.bind(true))
		_seq("k2_park_toddler", NEAR, 2, 80)
	if only == "" or only.contains("book"):
		plan.append(_book_open)
		var marks := ["첫 심부름이었다", "유모차", "낚싯대"]
		for i in marks.size():
			plan.append(_book_to.bind(marks[i]))
			plan.append(_book_shot.bind("k2_book_%d" % (i + 1), i == marks.size() - 1))
	if only == "":
		plan.append(_sheet)
	plan.append(_finish)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 10:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	if scene.first_popup != null:
		scene.first_popup.queue_free()
		scene.first_popup = null
	var w: Variant = plan[step].call()
	step += 1
	_wait = int(w) if w != null else 4
	return false


# ───────────────────────── 마을 꾸리기 ─────────────────────────
func _build() -> int:
	scene.paused = true
	v = scene.village
	var left := 4.0 * 86400.0 + 3.0 * 3600.0
	while left > 0.0:
		var d := minf(1800.0, left)
		v.advance(d)
		left -= d
	for ty: String in ADD:
		var sp: Variant = v.find_spot(ty)
		if sp == null:
			continue
		var b := v.add_building(ty, (sp as Vector2).x, (sp as Vector2).y, true)
		b.built_t = v.t
	v.stock["밀"] = 400.0
	v.stock["빵"] = 200.0
	var mums: Array[Resident] = []
	for r in v.people:
		if r.sex == "f" and r.is_adult() and not r.is_elder() and r.partner >= 0 and v.bld(r.home) != null:
			mums.append(r)
	var hs := v.houses()
	var free_f: Array[Resident] = []
	var free_m: Array[Resident] = []
	for r in v.people:
		if r.is_adult() and not r.is_elder() and r.partner < 0:
			(free_f if r.sex == "f" else free_m).append(r)
	while mums.size() < 2 and not free_f.is_empty() and not free_m.is_empty() and hs.size() > mums.size():
		var a: Resident = free_f.pop_back()
		var b: Resident = free_m.pop_back()
		a.partner = b.id
		b.partner = a.id
		a.home = hs[hs.size() - 1 - mums.size()].id
		b.home = a.home
		mums.append(a)
	mum_i = mums[0]
	mum_t = mums[mums.size() - 1]
	_find_area()
	mum_i.home = _hb.id
	v.person(mum_i.partner).home = _hb.id
	infant = _child_of(mum_i, "아람", "f", 0.12)
	for i in 4:
		kids.append(_child_of(mum_t, ["보리", "새별", "한솔", "다래"][i], "f" if i % 2 == 0 else "m", [1.6, 2.3, 3.0, 3.5][i]))
	elder = v.add_person("할매", "f", 21.0, "", v.fire.x + 1.0, v.fire.y + 0.5, null, null)
	elder.home = _hb.id
	for r in v.people:
		if r.is_adult() and not r.is_elder() and r != mum_i and r != mum_t and r.id != mum_i.partner and r.id != mum_t.partner:
			nb = r
			break
	print("부부 %d쌍 · 사람 %d · 이웃 %s · 맑은 날 %s (일할 때 %s · 장면 %s · 작은 위기 %d · 굶주림 %s)" % [mums.size(), v.people.size(), nb.name, ChildOutings.calm(v),
		v.is_work_time(), v.staged(), SmallCrises.active_count(v), v._starving()])
	scene.refresh()
	scene.set_debug_mode(false)
	return 10


func _child_of(m: Resident, nm: String, sex: String, age: float) -> Resident:
	var hm := v.bld(m.home)
	var c := v.add_person(nm, sex, age, "", hm.x + 0.5, hm.y + 1.2, m, v.person(m.partner))
	c.parents = PackedInt32Array([m.id, m.partner])
	c.home = m.home
	return c


## 가로 8.8 · 세로 4칸의 트인 띠 + 그 뒤(화면 위)에 집 두 채 (왼쪽 = 아이네 · 오른쪽 = 아기네)
func _find_area() -> void:
	var probe := Building.new()
	probe.type = "목조주택"
	var hs := probe.size()
	var found := false
	for ring in range(4, 30):
		for k in 24:
			var q := Vector2(v.fire.x, v.fire.y) + Vector2(float(ring), 0.0).rotated(TAU * float(k) / 24.0)
			var ok := true
			for i in 12:
				for j in 6:
					if not ChildPlay._open(v, q + Vector2(float(i) * 0.8, float(j) * 0.8)):
						ok = false
						break
				if not ok:
					break
			var hy := q.y - hs * 0.5 - 0.85
			if ok and v.is_free(q.x + 6.9, hy, hs) and v.is_free(q.x + 1.3, hy, hs):
				_area = q
				found = true
				break
		if found:
			break
	if not found:
		print("트인 띠를 못 찾음 — 모닥불 오른쪽으로")
		_area = Vector2(v.fire.x + 4.0, v.fire.y + 3.0)
	var hy2 := _area.y - hs * 0.5 - 0.85
	_hc = v.add_building("목조주택", _area.x + 1.3, hy2, true)
	_hc.built_t = v.t
	_hb = v.add_building("목조주택", _area.x + 6.9, hy2, true)
	_hb.built_t = v.t
	print("트인 띠 (%.1f, %.1f) · 모닥불 (%.1f, %.1f) · 집 크기 %.1f" % [_area.x, _area.y, v.fire.x, v.fire.y, hs])


## 물가의 집: 문에서 물가 자리가 가깝고 (화면 아래·옆), 자리 둘이 뭍 · 찌가 물
func _find_shore_house() -> bool:
	if _hf != null:
		return true
	var probe := Building.new()
	probe.type = "목조주택"
	var hs := probe.size()
	var kv: KidsView = scene.view.kids_view
	var r2 := Vector2(kv._right.x, kv._right.z)
	var b2 := Vector2(kv._back.x, kv._back.z)
	# 물이 화면 옆쪽에 있는 물가 (아이가 옆모습으로 앉아 낚싯대·찌·물고기가 다 보이게), 앉을 자리가 집 그림 앞
	var best := {}
	var bs := -1.0e9
	for ring in range(3, 60):
		for k in 48:
			var c := Vector2(v.fire.x, v.fire.y) + Vector2(float(ring), 0.0).rotated(TAU * float(k) / 48.0)
			if not v.is_free(c.x, c.y, hs):
				continue
			var door := Vector2(c.x - 0.3, c.y + hs * 0.5 + 0.75)
			var sp: Variant = Wildlife.shore_point(v, door, 9.0, 3.0)
			if sp == null:
				continue
			var s := ChildOutings._seats(v, sp as Vector2)
			if s.is_empty():
				continue
			var seat: Vector2 = s["seat"]
			var dir: Vector2 = s["dir"]
			if (seat - c).dot(b2) < 1.2 or absf(dir.dot(r2)) < 0.45 or dir.dot(b2) > 0.5:
				continue
			var sc := absf(dir.dot(r2)) - absf(dir.dot(b2)) - float(ring) * 0.01
			for i in 5:                            # 카메라 쪽에 물가(갈대·부들)가 또 있으면 가림
				for j in range(-2, 3):
					var q := seat + b2 * (0.7 + 0.7 * float(i)) + r2 * (0.7 * float(j))
					if v.water_at(q.x, q.y):
						sc -= 0.3
			if sc > bs:
				bs = sc
				best = {"c": c, "s": s, "sp": sp, "door": door}
	if best.is_empty():
		print("물가의 집 자리를 못 찾음")
		return false
	var c0: Vector2 = best["c"]
	_hf = v.add_building("목조주택", c0.x, c0.y, true)
	_hf.built_t = v.t
	var s0: Dictionary = best["s"]
	var seat0: Vector2 = s0["seat"]
	if v.wild._nearest_live(v, "fish", best["sp"] as Vector2, Wildlife.FUN_FISH_R).is_empty():
		var at := seat0 + (s0["dir"] as Vector2) * 3.0
		v.wild.add_herd("fish", at.x, at.y, 8)
		print("  (그림 도구: 물가에 물고기 떼를 놓음)")
	print("물가의 집 (%.1f, %.1f) · 물가 자리 (%.1f, %.1f) · 문에서 %.1f칸 · 물 쪽 화면 (%.2f, %.2f) · 점수 %.2f" % [c0.x, c0.y, seat0.x, seat0.y, seat0.distance_to(best["door"] as Vector2),
		(s0["dir"] as Vector2).dot(r2), (s0["dir"] as Vector2).dot(b2), bs])
	return true


func _to_hour(hour: float) -> void:
	scene.paused = true
	var d := fposmod(hour - v.hour_now(), 24.0) * 3600.0
	while d > 0.0:
		var s := minf(600.0, d)
		scene.world.advance(s)
		d -= s
	scene.refresh()


func _hour_in(lo: float, hi: float) -> void:
	var h := v.hour_now()
	if h < lo or h > hi:
		_to_hour(lo)


func _look(p: Vector2, ppu: float) -> void:
	scene.look_at_ground(p)
	scene.cam.ppu = ppu
	scene.cam.ppu_goal = ppu
	scene.cam._apply()
	scene.wterrain.zoom_ppu(ppu)
	scene.far_outline_check()
	var c: Vector3 = scene.cam.target
	scene.wterrain.set_focus(Vector2(c.x, c.z), scene.cam.view_radius())
	scene.wterrain.update_now()


func _model(r: Resident) -> Node3D:
	return scene.view.residents.get(r.id)


func _finish() -> int:
	quit()
	return 1


func _seq(name: String, ppu: float, n: int, gap: int) -> void:
	for i in n:
		plan.append(_centre.bind(ppu, gap))
		plan.append(_shot.bind("%s_%d" % [name, i + 1] if n > 1 else name))


func _centre(ppu: float, gap: int) -> int:
	_half = Vector2(100, 84) if ppu < 30.0 else Vector2(80, 68)
	if _half_wide != Vector2.ZERO and ppu >= 30.0:
		_half = _half_wide
	var p := _c
	if _follow != null:
		var m := _model(_follow)
		if m != null and m.visible:
			p = Vector2(m.position.x, m.position.z)
	_look(p, ppu)
	return gap


func _shot(name: String) -> int:
	var img := vp.get_texture().get_image()
	var c3: Camera3D = scene.cam.camera
	var p := _c
	if _follow != null:
		var m := _model(_follow)
		if m != null and m.visible:
			p = Vector2(m.position.x, m.position.z)
	var sp := c3.unproject_position(scene.ground_point(p) + Vector3(0, 0.3, 0)) * 3.0
	var h := _half * 3.0
	var rect := Rect2i(Vector2i(sp - h), Vector2i(h * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var path := out_dir.path_join(name + ".png")
	img.get_region(rect).save_png(path)
	sheet.append(path)
	var note := ""
	var kv: KidsView = scene.view.kids_view
	var pr := ChildOutings.pram(v)
	if not pr.is_empty():
		var cm := _model(mum_i) as CutoutResident
		var bm := _model(infant) as CutoutResident
		note += " 유모차: 보기 %d 좌우 %+.0f 손 %s · 아기 %s 보임 %s · 만남 %s" % [int(cm.doll.view), float(cm.doll.mirror), cm.arms_out, bm.baby_mode, bm.visible,
			str(kv.out._meet != null)]
		if kv.out._meet != null:
			var mt: OutingView.Meet = kv.out._meet
			var nm := _model(nb) as CutoutResident
			note += " [이웃 모델 (%.2f, %.2f) 설 자리 (%.2f, %.2f) 유모차 (%.2f, %.2f) 부모 (%.2f, %.2f) 보기 %d 좌우 %+.0f 돌림 %.2f t %.2f at %.2f 시뮬 (%.2f, %.2f) %s]" % [nm.position.x, nm.position.z, mt.spot.x, mt.spot.y,
				kv.out._p_at.x, kv.out._p_at.y, cm.position.x, cm.position.z, int(nm.doll.view), float(nm.doll.mirror), nm.rotation.y, mt.t, mt.at, nb.x, nb.y, nb.anim]
	var e := ChildOutings.errand(v)
	if not e.is_empty():
		note += " 심부름: 단계 %d c %.1f" % [int(e["ph"]), float(e["c"]) / ChildOutings.RS]
		var rm := _model(v.person(int(e["rc"]))) as CutoutResident
		var km := _model(v.person(int(e["k"]))) as CutoutResident
		if rm != null and km != null:
			note += " 아이 보기 %d 좌우 %+.0f · 어른 보기 %d 좌우 %+.0f 아기 안음 %s" % [int(km.doll.view), float(km.doll.mirror), int(rm.doll.view), float(rm.doll.mirror), str(rm.carry_baby)]
	var f := ChildOutings.fishing(v)
	if not f.is_empty():
		note += " 낚시: 단계 %d c %.1f" % [int(f["ph"]), float(f["c"]) / ChildOutings.RS]
		var fk := _model(v.person(int(f["k"]))) as CutoutResident
		var fa := _model(v.person(int(f["ad"]))) as CutoutResident
		if fk != null and fa != null:
			note += " 아이 %s 보기 %d 좌우 %+.0f · 어른 %s 보기 %d 좌우 %+.0f" % [fk._d_clip, int(fk.doll.view), float(fk.doll.mirror), fa._d_clip, int(fa.doll.view), float(fa.doll.mirror)]
	print("  %s  %.1f초 %s%s · 그림 %s" % [name, Time.get_ticks_msec() / 1000.0, v.fmt_time(v.t), note, str(kv.out.seen)])
	return 1


func _until(cond: Callable, max_n: int) -> int:
	_until_n += 1
	if cond.call() or _until_n >= max_n:
		if _until_n >= max_n:
			print("  (기다리다 넘어감: %s)" % str(cond))
		_until_n = 0
		return 1
	step -= 1
	return 1


func _hold(r: Resident, action: String, x: float, y: float, doing: String) -> void:
	r.x = x
	r.y = y
	r.action = action
	r.anim = "work" if action == "work" else "idle"
	r.carry = ""
	r.doing = doing
	r.sleeping = false
	r.steps = [ResidentAI.act(1.0e6, r.anim)]


## 장면을 시작할 때마다: 찍는 사이 병의 며칠이 지나도 나이·몸 상태는 처음 그대로 (젖먹이는 젖먹이, 아이는 아이, 앓던 이웃은 나음)
func _fresh() -> void:
	infant.age = 0.12
	for i in kids.size():
		kids[i].age = [1.6, 2.3, 3.0, 3.5][i]
	elder.age = 21.0
	for r: Resident in [nb, elder, mum_i, mum_t]:
		r.sick_left = 0.0
		r.injured_left = 0.0


## 장면에 나오지 않는 사람은 멀리서 일함 (장면을 가리지 않게) — keep의 사람은 그대로
func _others_away(keep: Array) -> void:
	var st := ChildPlay._state(v)
	(st["g"] as Array).clear()
	var i := 0
	for r in v.people:
		if r in keep or r == infant:
			continue
		_hold(r, "work", _area.x - 9.0 - float(i % 5) * 1.1, _area.y - 9.0 - float(i / 5) * 1.1, "일하는 중")
		i += 1


## 화면 기준 (오른쪽, 앞) 칸 → 땅 위 벡터 (길이 그대로)
func _scr(d: Vector2) -> Vector2:
	var kv: KidsView = scene.view.kids_view
	return Vector2(kv._right.x, kv._right.z) * d.x + Vector2(kv._back.x, kv._back.z) * d.y


func _screen(d: Vector2) -> Vector2:
	var kv: KidsView = scene.view.kids_view
	var r2 := Vector2(kv._right.x, kv._right.z)
	var b2 := Vector2(kv._back.x, kv._back.z)
	return (r2 * d.x + b2 * d.y).normalized()


# ───────────────────────── A. 유모차 산책 ─────────────────────────
## dir = 화면 (오른쪽 +, 아래 +)으로 걷는 방향. meet = 길가에 이웃이 서 있음 · dog = 집 강아지가 따라옴
func _s_pram(dir: Vector2, meet: bool, dog: bool) -> int:
	_hour_in(8.6, 15.5)
	_fresh()
	scene.paused = true
	var w := _screen(dir)
	var mid := _area + Vector2(2.8, 2.2)       # 풀·꽃에 가리지 않는 자리
	var a := mid - w * 1.0
	var b := mid + w * 3.0
	_others_away([mum_i])
	mum_i.x = a.x
	mum_i.y = a.y
	mum_i.facing = atan2(w.x, w.y)
	mum_i.action = "care"
	mum_i.anim = "walk"
	mum_i.sleeping = false
	mum_i.carry = "유모차"
	mum_i.carry_amt = 1.0
	mum_i.doing = "%s 유모차를 끌고 산책하는 중" % infant.name
	mum_i.steps = [ResidentAI.walk(b.x, b.y), ResidentAI.act(1.0e6, "idle")]
	infant.x = a.x
	infant.y = a.y
	var st := ChildOutings.state(v)
	st["pram"] = {}
	ChildOutings._pram_start(v, st, mum_i, infant)
	var p: Dictionary = st["pram"]
	p["mt"] = v.t + 1.0e9
	if meet:
		var side := _screen(Vector2(dir.y, -dir.x) if absf(dir.x) < 0.5 else Vector2(0.0, 1.0))
		var at := a + w * 2.1 + side * 0.9
		_hold(nb, "rest", at.x, at.y, "쉬는 중")
		p["mt"] = -1.0e9
	if dog:
		if v.dogs.list.is_empty():
			v.dogs.settle(v)
		if not v.dogs.list.is_empty():
			var dg: Dictionary = v.dogs.list[0]
			dg["owner"] = mum_i.id
			dg["x"] = a.x - w.x * 0.7
			dg["y"] = a.y - w.y * 0.7
			dg["px"] = dg["x"]
			dg["py"] = dg["y"]
			print("  집 강아지 %s → 주인 %s" % [String(dg["name"]), mum_i.name])
	_c = mid
	_follow = mum_i
	_half_wide = Vector2.ZERO
	scene.refresh()
	scene.paused = false
	return 70 if not meet else 20


func _meet_off() -> bool:
	var kv: KidsView = scene.view.kids_view
	return kv.out._meet == null and not kv.out._pup.has(nb.id)


func _meet_on() -> bool:
	var kv: KidsView = scene.view.kids_view
	return kv.out._meet != null and kv.out._meet.at >= 0.0


## 산책이 끝나 문 옆에 세워 둔 유모차 — toddler: 아기가 걸음마를 뗀 뒤
func _s_park(toddler: bool) -> int:
	_hour_in(8.6, 16.5)
	_fresh()
	scene.paused = true
	_others_away([mum_i])
	var door := ChildOutings._door(_hb)
	var stand := Vector2(_hb.x, _hb.y) + _scr(Vector2(-0.2, 2.3))
	_hold(mum_i, "rest", stand.x, stand.y, "쉬는 중")
	var st := ChildOutings.state(v)
	if not (st["park"] as Dictionary).has(str(_hb.id)):
		(st["park"] as Dictionary)[str(_hb.id)] = v.t
	if toddler:
		infant.age = 0.47
		mum_i.steps = []
		for k in 6:
			var to := Vector2(_hb.x, _hb.y) + _scr(Vector2(-0.9 if k % 2 == 0 else 0.7, 2.3 if k % 2 == 0 else 2.6))
			mum_i.steps.append(ResidentAI.walk(to.x, to.y))
			mum_i.steps.append(ResidentAI.act(500.0, "idle"))
		mum_i.steps.append(ResidentAI.act(1.0e6, "idle"))
	_c = Vector2(_hb.x, _hb.y) + _scr(Vector2(0.75, 1.5))
	_follow = null
	_half_wide = Vector2(96, 84)
	scene.refresh()
	scene.paused = false
	var kv: KidsView = scene.view.kids_view
	print("세워 둔 유모차: 집 %d · 걸음마 뒤 %s · 집 (%.2f, %.2f) 크기 %.1f · 화면 오른쪽 %s 앞 %s · 자리 %s · 그림 판 %s" % [_hb.id, toddler, _hb.x, _hb.y, _hb.size(), str(kv._right), str(kv._back),
		str(kv.out._park_spot(_hb)), str(scene.view._card_items.get(_hb.id, []))])
	return 90


# ───────────────────────── B. 첫 심부름 ─────────────────────────
func _s_errand(ki: int, why: String) -> int:
	_hour_in(9.1, 10.3)
	_fresh()
	scene.paused = true
	var k := kids[ki]
	_others_away([k, elder])
	var dc := ChildOutings._door(_hc)
	var db := ChildOutings._door(_hb)
	k.home = _hc.id
	_hold(k, "rest", dc.x + 0.3, dc.y + 0.3, "쉬는 중")
	elder.home = _hb.id
	_hold(elder, "rest", db.x + 0.6, db.y + 0.35, "쉬는 중")
	infant.home = _hb.id if ki == 3 else mum_t.home      # 멀리서 본 장면만 아기를 안은 어른이 받는다
	if why == "sick":
		nb.home = _hb.id
		nb.sick_left = 6.0 * 3600.0
	var ok := ChildOutings.try_errand(v, k)
	var e := ChildOutings.errand(v)
	print("첫 심부름 %s (%.1f살): 벌어짐 %s · 까닭 '%s' · 맑은 날 %s · 시각 %.2f" % [k.name, k.age, ok, String(e.get("why", "?")), ChildOutings.calm(v), v.hour_now()])
	_c = (dc + db) * 0.5
	_follow = k
	_half_wide = Vector2(96, 70)
	scene.refresh()
	scene.paused = false
	return 50


## 심부름 단계 (−1 = 끝남)
func _err_ph(ph: int) -> bool:
	var e := ChildOutings.errand(v)
	return e.is_empty() if ph < 0 else (e.is_empty() or int(e["ph"]) >= ph)


# ───────────────────────── C. 첫 낚시 ─────────────────────────
func _s_fish(ki: int) -> int:
	_hour_in(13.05, 14.2)
	_fresh()
	scene.paused = true
	if not _find_shore_house():
		return 1
	var k := kids[ki]
	_others_away([k, elder])
	var d := ChildOutings._door(_hf)
	k.home = _hf.id
	_hold(k, "rest", d.x + 0.2, d.y + 0.3, "쉬는 중")
	elder.home = _hf.id
	_hold(elder, "rest", d.x + 0.95, d.y + 0.4, "쉬는 중")
	var ok := ChildOutings.try_fishing(v, k)
	var f := ChildOutings.fishing(v)
	print("첫 낚시 %s (%.1f살): 벌어짐 %s · 곁 어른 %s · 맑은 날 %s · 시각 %.2f" % [k.name, k.age, ok, str(f.get("ad", "?")), ChildOutings.calm(v), v.hour_now()])
	_c = d
	_follow = k
	_half_wide = Vector2(104, 84)
	scene.refresh()
	scene.paused = false
	return 50


func _fish_ph(ph: int) -> bool:
	var f := ChildOutings.fishing(v)
	return f.is_empty() if ph < 0 else (f.is_empty() or int(f["ph"]) >= ph)


# ───────────────────────── 연대기 ─────────────────────────
func _book_open() -> int:
	scene.paused = true
	for b: Dictionary in v.book.slice(maxi(0, v.book.size() - 8)):
		print("  연대기: ", b["text"])
	scene.open_chronicle(0)
	return 40


## 그 말이 든 줄이 화면 위쪽에 오게 두루마리를 내림 (새 줄은 여러 날에 흩어져 있다)
func _book_to(word: String) -> int:
	var ch: Control = scene.chronicle
	var hit := _label_with(ch.body, word)
	if hit == null:
		print("  (연대기에 '%s' 줄이 없음)" % word)
		return 2
	ch.scroll.scroll_vertical = maxi(0, int(hit.global_position.y - ch.body.global_position.y) - 150)
	return 12


func _label_with(n: Node, word: String) -> Label:
	if n is Label and (n as Label).text.contains(word):
		return n as Label
	for c in n.get_children():
		var hit := _label_with(c, word)
		if hit != null:
			return hit
	return null


func _book_shot(name: String, last: bool) -> int:
	var path := out_dir.path_join(name + ".png")
	vp.get_texture().get_image().save_png(path)
	if last:
		scene.chronicle.close()
	print("  ", name)
	return 4


## 한 줄로는 너무 길어 (100장) 열 줄 격자로 — 반으로 줄여 칸 가운데에
func _sheet() -> int:
	var cw := 300
	var ch := 252
	var gap := 8
	var cols := 10
	var rows := int(ceil(sheet.size() / float(cols)))
	var img := Image.create(cols * cw + (cols - 1) * gap, rows * ch + (rows - 1) * gap, false, Image.FORMAT_RGB8)
	img.fill(Color("1e1f2a"))
	for i in sheet.size():
		var one := Image.load_from_file(sheet[i])
		one.convert(Image.FORMAT_RGB8)
		one.resize(one.get_width() / 2, one.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		var at := Vector2i((i % cols) * (cw + gap) + (cw - one.get_width()) / 2, (i / cols) * (ch + gap) + (ch - one.get_height()) / 2)
		img.blit_rect(one, Rect2i(Vector2i.ZERO, one.get_size()), at)
	img.save_png(out_dir.path_join("k2_sheet.png"))
	print("모음: %s (%d장)" % [out_dir.path_join("k2_sheet.png"), sheet.size()])
	return 1
