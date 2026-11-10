## 강아지와 사람 · 톡 반응 크기 · 말풍선 자리 · 짧은 이야기 (Q2-d 귀여움 묶음 ④) 캡처.
## 실행 (창이 필요): godot --path godot -s res://tools/shot_dogs.gd
##   DOGS_TAG=before|after (파일 이름 앞머리 — 기본 after) · DOGS_ONLY=follow,tag,stack,bfly,pet,tap,bubble,chat (그 장면만)
## 넓은 세상(world.tscn) 마을에 가족·아이 넷·집 강아지·마을 강아지를 꾸려 1080×1920(논리 360×640)으로 찍는다 → godot_shots/dogs/
##   <앞머리>_<장면>_<확대>_<n>.png (그 자리 둘레를 오려 냄) · <앞머리>_<장면>_sheet.png (한 장 모음) · 화면 전체는 *_full.png (절반 크기)
##   확대: 20 = 기본 확대 · 44 = 가까이 (· 88 = 아주 가까이 — 말풍선)
extends SceneTree

const ADD := ["목조주택", "목조주택", "목조주택", "창고", "우물", "광장"]
const SCENES := ["follow", "tag", "stack", "bfly", "pet", "tap", "bubble", "chat"]

var scene: Node
var vp: SubViewport
var v: Village
var out_dir := ""
var tag := "after"
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var kids: Array[Resident] = []
var owner: Resident               # 집 강아지의 주인 (어른)
var pal: Resident                 # 이야기 상대 (다른 어른)
var third: Resident               # 셋째 (말리는 이웃)
var elder: Resident
var dog_h: Dictionary = {}        # 집 강아지
var dog_v: Dictionary = {}        # 마을 강아지
var sheets := {}                  # 장면 → 사진 경로들
var _group := ""
var _chat_said := false


func _initialize() -> void:
	if OS.get_environment("DOGS_TAG") != "":
		tag = OS.get_environment("DOGS_TAG")
	var only := OS.get_environment("DOGS_ONLY")
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/dogs").simplify_path()
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
	plan = [_build, _scan]
	for s: String in SCENES:
		if only != "" and not (s in only.split(",")):
			continue
		call("_plan_" + s)
		plan.append(_sheet.bind(s))
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
	scene.clock.creation = false              # 창세의 날 빠르기가 아니라 보통 빠르기로 (이야기 장면은 보통 이하에서만 펼쳐짐)
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
	for i in 4:
		var m: Resident = mums[i % mums.size()]
		kids.append(_child_of(m, ["보리", "새별", "한솔", "다래"][i], "f" if i % 2 == 0 else "m", [1.6, 2.3, 3.0, 3.5][i]))
	owner = v.person(mums[0].partner)
	pal = mums[mums.size() - 1]
	for r in v.people:
		if r.is_adult() and not r.is_elder() and r != owner and r != pal and r != mums[0]:
			third = r
			break
	elder = v.add_person("할매", "f", 20.05, "", v.fire.x + 1.0, v.fire.y + 0.5, null, null)
	elder.home = pal.home
	# 강아지: 집 강아지 하나 (주인 = owner — 그 집 아이는 kids[0]·kids[2]) + 마을 강아지 하나
	var dogs: Dogs = v.dogs
	for dg: Dictionary in dogs.list.duplicate():          # 다른 강아지는 치움 (장면이 헷갈리지 않게)
		dogs.list.erase(dg)
	dog_h = dogs._new_dog(v, "콩이", "m", {"base": 1, "pat": 4, "ear": 2, "tail": 0, "size": 1.0}, v.fire + Vector2(2, 2))
	dog_h["owner"] = owner.id
	dog_h["born"] = v.t - 12.0 * Balance.DAY
	dog_v = dogs._new_dog(v, "점박이", "f", {"base": 0, "pat": 1, "ear": 0, "tail": 1, "size": 0.95}, v.fire + Vector2(-2, 2))
	dog_v["born"] = v.t - 12.0 * Balance.DAY
	print("사람 %d · 아이 %d · 강아지 %d (집 %s · 마을 %s) · 주인 %s · 이야기 상대 %s · 셋째 %s" % [v.people.size(), kids.size(), dogs.list.size(),
		dog_h["name"], dog_v["name"], owner.name, pal.name, third.name if third != null else "-"])
	_to_hour(10.0)
	scene.paused = true
	_find_spot()
	scene.refresh()
	scene.set_debug_mode(false)
	return 10


func _child_of(m: Resident, nm: String, sex: String, age: float) -> Resident:
	var hm := v.bld(m.home)
	var c := v.add_person(nm, sex, age, "", hm.x + 0.5, hm.y + 1.2, m, v.person(m.partner))
	c.parents = PackedInt32Array([m.id, m.partner])
	c.home = m.home
	return c


func _to_hour(hour: float) -> void:
	scene.paused = true
	var d := fposmod(hour - v.hour_now(), 24.0) * 3600.0
	while d > 0.0:
		var s := minf(600.0, d)
		scene.world.advance(s)
		d -= s
	scene.refresh()
	scene.paused = false


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


# ───────────────────────── 찍기 ─────────────────────────
var _c := Vector2.ZERO            # 지금 장면의 가운데 (땅)
var _follow: Resident             # 있으면 그 사람의 화면 자리를 가운데로
var _half := Vector2(100, 84)
var _game: Dictionary = {}
var _to_spot := Vector2.ZERO


func _centre_of() -> Vector2:
	if _follow != null:
		var m := _model(_follow)
		if m != null and m.visible:
			return Vector2(m.position.x, m.position.z)
	return _c


## 이름_1..n: 가운데를 맞추고 secs(현실 초)마다 한 장. from = 첫 장 번호
func _seq(name: String, ppu: float, n: int, secs: float, from := 1) -> void:
	for i in n:
		plan.append(_centre.bind(ppu, 1))
		plan.append(_sleep.bind(secs))
		plan.append(_centre.bind(ppu, 1))
		plan.append(_shot.bind("%s_%d_%d" % [name, int(ppu), from + i]))


func _centre(ppu: float, gap: int) -> int:
	_look(_centre_of(), ppu)
	return gap


func _shot(name: String) -> int:
	var img := vp.get_texture().get_image()
	var c3: Camera3D = scene.cam.camera
	var sp := c3.unproject_position(scene.ground_point(_centre_of()) + Vector3(0, 0.3, 0)) * 3.0
	var h := _half * 3.0
	var rect := Rect2i(Vector2i(sp - h), Vector2i(h * 2.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var path := out_dir.path_join("%s_%s.png" % [tag, name])
	img.get_region(rect).save_png(path)
	if not sheets.has(_group):
		sheets[_group] = []
	(sheets[_group] as Array).append(path)
	print("  %s  %.1f초 %s" % [name, Time.get_ticks_msec() / 1000.0, _note()])
	return 1


## 화면 전체 (절반 크기)
func _full(name: String) -> int:
	var img := vp.get_texture().get_image()
	img.resize(540, 960, Image.INTERPOLATE_LANCZOS)
	img.save_png(out_dir.path_join("%s_%s_full.png" % [tag, name]))
	print("  %s (화면 전체) %s" % [name, _note()])
	return 1


func _note() -> String:
	var s := ""
	for dg: Dictionary in [dog_h, dog_v]:
		if dg.is_empty():
			continue
		var cd := scene.view.fauna_view.get_node_or_null("CutoutDogs") as CutoutDogs
		var e: Dictionary = cd.dogs.get(int(dg["id"]), {}) if cd != null else {}
		var at := "화면 밖"
		if not e.is_empty():
			var p: Vector3 = (e["doll"] as Node3D).position
			at = "화면 (%.1f, %.1f) %s" % [p.x, p.z, e["clip"]]
		s += " · %s[%s (%.1f, %.1f) → %s]" % [dg["name"], dg["state"], dg["x"], dg["y"], at]
	if not _game.is_empty():
		s += " · 놀이 c=%.0f 술래 %d 잡음 %d 탑 %d(단계 %d)" % [float(_game["c"]), int(_game["it"]), int(_game["tags"]), int(_game["h"]), int(_game["ph"])]
	return s


func _sheet(name: String) -> int:
	var l := PackedStringArray(sheets.get(name, []))
	if l.is_empty():
		return 1
	var out := out_dir.path_join("%s_%s_sheet.png" % [tag, name])
	_grid(l, out, 4 if l.size() <= 12 else 5, 0.5)
	print("모음: %s (%d장)" % [out, l.size()])
	return 1


## 여러 장을 줄 맞춰 한 장으로 (cols장씩)
func _grid(paths: PackedStringArray, out: String, cols: int, scale: float) -> void:
	var imgs: Array[Image] = []
	var cw := 0
	var ch := 0
	for p in paths:
		var img := Image.load_from_file(p)
		img.convert(Image.FORMAT_RGB8)
		img.resize(int(img.get_width() * scale), int(img.get_height() * scale), Image.INTERPOLATE_LANCZOS)
		imgs.append(img)
		cw = maxi(cw, img.get_width())
		ch = maxi(ch, img.get_height())
	var rows := int(ceil(float(imgs.size()) / float(cols)))
	var sheet := Image.create(cols * cw + (cols - 1) * 6, rows * ch + (rows - 1) * 6, false, Image.FORMAT_RGB8)
	sheet.fill(Color("1e1f2a"))
	for i in imgs.size():
		sheet.blit_rect(imgs[i], Rect2i(Vector2i.ZERO, imgs[i].get_size()), Vector2i((i % cols) * (cw + 6), (i / cols) * (ch + 6)))
	sheet.save_png(out)


func _begin(name: String) -> int:
	_group = name
	return 1


## cond가 참이 될 때까지 기다림 (가장 길게 max 장면)
var _until_n := 0


func _until(cond: Callable, max_n: int) -> int:
	_until_n += 1
	if cond.call() or _until_n >= max_n:
		if _until_n >= max_n:
			print("  (기다리다 넘어감: %s)" % str(cond))
		_until_n = 0
		return 1
	step -= 1
	return 1


## 현실 초만큼 기다림 (화면 빠르기와 무관)
var _sleep_t0 := -1


func _sleep(secs: float) -> int:
	if _sleep_t0 < 0:
		_sleep_t0 = Time.get_ticks_msec()
	if float(Time.get_ticks_msec() - _sleep_t0) >= secs * 1000.0:
		_sleep_t0 = -1
		return 0
	step -= 1
	return 0


func _hold(r: Resident, action: String, x: float, y: float, doing: String, anim := "") -> void:
	r.x = x
	r.y = y
	r.action = action
	r.anim = anim if anim != "" else ("work" if action == "work" else "idle")
	r.carry = ""
	r.doing = doing
	r.sleeping = false
	r.say = ""
	r.say_t = 0.0
	r.steps = [ResidentAI.act(1.0e6, r.anim)]


func _clear_games() -> void:
	var st := ChildPlay._state(v)
	(st["g"] as Array).clear()
	for k in kids:
		k.steps.clear()
	_game = {}


## 장면에 나오지 않는 사람은 멀찍이 (가리지 않게)
func _park(but: Array) -> void:
	var i := 0
	for r in v.people:
		if r in but or r.is_baby():
			continue
		_hold(r, "work", _to_spot.x - 9.0 - float(i % 6) * 1.1, _to_spot.y - 6.0 - float(i / 6) * 1.1, "일하는 중")
		i += 1
	(v.social.get("busy", {}) as Dictionary).clear()
	v.social_events.clear()
	scene.view.stage_say.clear()


func _put_dog(dg: Dictionary, p: Vector2) -> void:
	dg["x"] = p.x
	dg["y"] = p.y
	dg["px"] = p.x
	dg["py"] = p.y
	dg["rx"] = p.x
	dg["ry"] = p.y
	dg["roam_t"] = v.t + 1.0e7        # 어슬렁거릴 자리를 새로 고르지 않음 (그 자리에)


func _find_spot() -> void:
	var env := OS.get_environment("DOGS_SPOT")              # "x,y" — 자리를 손으로
	if env != "":
		_to_spot = Vector2(float(env.split(",")[0]), float(env.split(",")[1]))
		return
	for k in 900:                                           # 놀이를 펼 수 있는 트인 자리 후보 (모닥불에서 5~15칸, 2칸 간격)
		var q := Vector2(v.fire.x - 15.0 + float(k % 30), v.fire.y - 15.0 + float(k / 30))
		if (k % 30) % 2 == 1 or (k / 30) % 2 == 1 or q.distance_to(v.fire) < 5.0 or q.distance_to(v.fire) > 15.0:
			continue
		if ChildPlay._open(v, q) and ChildPlay._open(v, q + Vector2(0.0, 1.2)) and ChildPlay._open(v, q + Vector2(2.0, 0.6)) and ChildPlay._open(v, q - Vector2(2.0, -0.6)) and v.is_free(q.x, q.y, 2.2):
			_cands.append(q)
	_to_spot = _cands[0] if not _cands.is_empty() else v.fire + Vector2(4, 4)


## 후보 자리를 하나씩 비춰 보고, 화면에 맨땅(밝은 풀빛)이 가장 많이 보이는 곳을 고름 — 풀·꽃에 가리지 않게 (큰 꽃숲은 시뮬 목록만으론 알 수 없음)
var _cands: Array[Vector2] = []
var _cand_i := -1
var _cand_best := -1.0


func _scan() -> int:
	if _cands.is_empty():
		print("자리 (%.1f, %.1f) · 모닥불 (%.1f, %.1f)" % [_to_spot.x, _to_spot.y, v.fire.x, v.fire.y])
		return 2
	if _cand_i >= 0:
		var img := vp.get_texture().get_image()
		var c3: Camera3D = scene.cam.camera
		var q := _cands[_cand_i]
		var sp := c3.unproject_position(scene.ground_point(q + Vector2(0.0, 0.5))) * 3.0
		var rect := Rect2i(Vector2i(sp - Vector2(130, 100) * 3.0), Vector2i(Vector2(260, 200) * 3.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var cut := img.get_region(rect)
		cut.resize(52, 40, Image.INTERPOLATE_BILINEAR)
		var open := 0
		for y in 40:
			for x in 52:
				var c := cut.get_pixel(x, y)
				if c.g > 0.74 and c.r > 0.52 and c.r < 0.78 and c.b > 0.4 and c.b < 0.68 and c.g - c.r > 0.1:
					open += 2 if absi(x - 26) < 14 and absi(y - 20) < 11 else 1     # 가운데가 더 중요
		if float(open) > _cand_best:
			_cand_best = float(open)
			_to_spot = q
	_cand_i += 1
	if _cand_i >= _cands.size():
		print("자리 (%.1f, %.1f) — 후보 %d곳 가운데 맨땅 점수 %.0f · 모닥불 (%.1f, %.1f)" % [_to_spot.x, _to_spot.y, _cands.size(), _cand_best, v.fire.x, v.fire.y])
		_cands.clear()
		return 2
	_look(_cands[_cand_i] + Vector2(0.0, 0.5), 44.0)
	step -= 1
	return 3


# ───────────────────────── 1. 강아지와 사람 ─────────────────────────
## 주인이 오가다 멈춤 → 집 강아지가 따라가다 앉음
func _plan_follow() -> void:
	plan.append(_begin.bind("follow"))
	plan.append(_s_follow)                       # 걷는 동안 4장 → 주인이 멈춘 뒤 4장 (앉아서 올려다보나)
	_seq("follow", 44.0, 4, 0.5)
	plan.append(_until.bind(_owner_still, 3000))
	_seq("follow", 44.0, 4, 0.4, 5)
	plan.append(_s_follow)
	_seq("follow", 20.0, 2, 0.8)
	plan.append(_until.bind(_owner_still, 3000))
	_seq("follow", 20.0, 2, 0.7, 3)


func _owner_still() -> bool:
	return owner.anim != "walk" and not owner.steps.is_empty() and String((owner.steps[0] as Dictionary).get("k", "")) == "do"


func _s_follow() -> int:
	scene.paused = true
	_clear_games()
	_park([owner])
	var a := _to_spot + Vector2(-2.0, 0.5)
	var b := _to_spot + Vector2(2.0, 0.9)
	_hold(owner, "rest", a.x, a.y, "쉬는 중")
	owner.steps = []
	for k in 8:
		var to := b if k % 2 == 0 else a
		owner.steps.append(ResidentAI.walk(to.x, to.y))
		owner.steps.append(ResidentAI.act(1800.0, "idle"))
	owner.steps.append(ResidentAI.act(1.0e6, "idle"))
	_put_dog(dog_h, a + Vector2(-0.8, 0.2))
	_put_dog(dog_v, _to_spot + Vector2(-14.0, -9.0))
	_c = _to_spot
	_follow = owner
	_half = Vector2(100, 84)
	scene.refresh()
	scene.paused = false
	return 20


## 아이들 놀이 (술래잡기·돌탑·나비) 곁의 강아지 — 집 강아지는 그 집 아이 곁, 마을 강아지는 가까운 아이 곁
func _plan_tag() -> void:
	plan.append(_begin.bind("tag"))
	plan.append(_s_game.bind("tag", 3))
	_seq("tag", 44.0, 10, 0.45)
	_seq("tag", 20.0, 4, 0.6)


func _plan_bfly() -> void:
	plan.append(_begin.bind("bfly"))
	plan.append(_s_game.bind("bfly", 3))
	_seq("bfly", 44.0, 6, 0.5)
	_seq("bfly", 20.0, 3, 0.6)


func _plan_stack() -> void:
	plan.append(_begin.bind("stack"))
	plan.append(_s_game.bind("stack", 3))
	_seq("stack", 44.0, 3, 1.2)
	plan.append(_until.bind(_stack_ph.bind(1), 6000))
	_seq("stack_wobble", 44.0, 1, 0.15)
	plan.append(_until.bind(_stack_ph.bind(2), 3000))
	_seq("stack_fall", 44.0, 6, 0.16)
	plan.append(_until.bind(_stack_ph.bind(1), 9000))
	plan.append(_until.bind(_stack_ph.bind(2), 3000))
	_seq("stack_fall", 20.0, 4, 0.16)


func _stack_ph(ph: int) -> bool:
	return int(_game.get("ph", 0)) == ph


func _s_game(kind: String, n: int) -> int:
	scene.paused = true
	_clear_games()
	_park(kids + [owner])
	_hold(owner, "rest", _to_spot.x + 5.5, _to_spot.y - 1.0, "쉬는 중")
	var g := ChildPlay.open_game(v, kids[0], _to_spot, kind, 3 + step)
	g["c1"] = 1.0e9
	for i in n:
		var k := kids[i]
		var gi := ChildPlay._add(g, k.id)
		var s := ChildPlay.seat(g, int(g["sl"][gi]))
		k.x = s.x
		k.y = s.y
		k.action = "play"
		k.anim = "play"
		k.sleeping = false
		k.steps.clear()
		ChildPlay._attach(k, g, gi, 1.0e6)
	_hold(kids[3], "work", _to_spot.x - 12.0, _to_spot.y - 8.0, "일하는 중")
	_put_dog(dog_h, _to_spot + Vector2(1.6, 0.9))
	_put_dog(dog_v, _to_spot + Vector2(-1.8, 1.0))
	_game = g
	_c = _to_spot
	_follow = null
	_half = Vector2(110, 90)
	scene.refresh()
	scene.paused = false
	print("놀이 %s — 가운데 (%.1f, %.1f) · 아이 %d" % [kind, _to_spot.x, _to_spot.y, n])
	return 150 if kind != "stack" else 60


## 아이가 강아지를 쓰다듬음 (드문 작은 장면 — 화면만). 놀이 없는 아이 곁에 마을 강아지
func _plan_pet() -> void:
	plan.append(_begin.bind("pet"))
	plan.append(_s_pet)
	plan.append(_until.bind(_pet_on, 3000))
	_seq("pet", 44.0, 6, 0.3)
	plan.append(_sleep.bind(2.6))
	plan.append(_s_pet)
	plan.append(_until.bind(_pet_on, 3000))
	_seq("pet", 20.0, 3, 0.35)


func _s_pet() -> int:
	scene.paused = true
	_clear_games()
	_park([kids[1]])
	_hold(kids[1], "rest", _to_spot.x, _to_spot.y + 0.4, "쉬는 중")
	_put_dog(dog_v, _to_spot + Vector2(0.75, 0.55))
	_put_dog(dog_h, _to_spot + Vector2(-14.0, -9.0))
	var dp: Variant = scene.view.get("dog_pals")
	if dp != null and dp.has_method("force_pet"):
		dp.call("force_pet", kids[1].id, int(dog_v["id"]))
	_c = _to_spot + Vector2(0.3, 0.4)
	_follow = null
	_half = Vector2(80, 68)
	scene.refresh()
	scene.paused = false
	return 20


func _pet_on() -> bool:
	var dp: Variant = scene.view.get("dog_pals")
	return dp == null or not dp.has_method("petting") or bool(dp.call("petting"))


# ───────────────────────── 2. 톡 반응 크기 ─────────────────────────
const TAPS := [["adult", "bow", 0.42], ["adult", "wobble", 0.14], ["adult", "wave", 0.17], ["elder", "nod", 0.2], ["child", "startle", 0.34], ["dog", "dog_wag", 0.28]]


func _plan_tap() -> void:
	plan.append(_begin.bind("tap"))
	plan.append(_s_tap)
	for ppu: float in [20.0, 44.0]:
		for tc: Array in TAPS:
			plan.append(_tap_aim.bind(String(tc[0]), ppu))
			plan.append(_shot.bind("tap_%s_%d_0rest" % [tc[1], int(ppu)]))
			plan.append(_tap.bind(String(tc[0]), String(tc[1])))
			plan.append(_sleep.bind(float(tc[2]) * TapReact.duration(String(tc[1]))))
			plan.append(_shot.bind("tap_%s_%d_1peak" % [tc[1], int(ppu)]))
			plan.append(_sleep.bind(1.6))
	plan.append(_tap_aim.bind("adult", 20.0))
	plan.append(_tap.bind("adult", "bow"))
	plan.append(_sleep.bind(0.42 * TapReact.duration("bow")))
	plan.append(_full.bind("tap_bow_20"))
	plan.append(_sleep.bind(2.2))


func _s_tap() -> int:
	scene.paused = true
	_clear_games()
	if elder == null or elder.dead:           # 그새 돌아가셨으면 살아 있는 어르신으로 (없으면 새로)
		elder = null
		for r in v.people:
			if r.is_elder() and not r.dead and r != owner and r != pal:
				elder = r
				break
		if elder == null:
			elder = v.add_person("할매", "f", 20.05, "", _to_spot.x, _to_spot.y + 0.7, null, null)
			elder.home = pal.home
	_park([owner, elder, kids[1]])
	_hold(owner, "rest", _to_spot.x - 1.2, _to_spot.y + 0.5, "쉬는 중")
	_hold(elder, "rest", _to_spot.x, _to_spot.y + 0.7, "쉬는 중")
	_hold(kids[1], "rest", _to_spot.x + 1.2, _to_spot.y + 0.5, "쉬는 중")
	_put_dog(dog_v, _to_spot + Vector2(2.3, 0.6))
	_put_dog(dog_h, _to_spot + Vector2(-14.0, -9.0))
	_c = _to_spot + Vector2(0.4, 0.5)
	_follow = null
	scene.refresh()
	scene.paused = false
	return 40


func _tap_who(who: String) -> Resident:
	return {"adult": owner, "elder": elder, "child": kids[1]}.get(who)


func _tap_aim(who: String, ppu: float) -> int:
	var r := _tap_who(who)
	_c = Vector2(r.x, r.y) if r != null else Vector2(dog_v["x"], dog_v["y"])
	_half = Vector2(46, 46) if ppu > 30.0 else Vector2(30, 30)
	_look(_c, ppu)
	return 6


func _tap(who: String, kind: String) -> int:
	var tr: TapReact = scene.tap_react
	var got := ""
	if who == "dog":
		got = tr.react_dog(scene.view, int(dog_v["id"]), kind)
	else:
		got = tr.react_resident(scene.view, _tap_who(who), kind)
	if got != kind:
		var r := _tap_who(who)
		print("  (톡 반응이 다름: %s → '%s' · %s 죽음 %s 인형 %s)" % [kind, got, r.name if r != null else "-", str(r.dead) if r != null else "-", str(_model(r)) if r != null else "-"])
	return 0


# ───────────────────────── 3. 말풍선 자리 ─────────────────────────
func _plan_bubble() -> void:
	plan.append(_begin.bind("bubble"))
	plan.append(_s_bubble)
	for ppu: float in [20.0, 44.0, 88.0]:
		plan.append(_bubble_say)
		plan.append(_bubble_aim.bind(ppu, -1.0))
		plan.append(_shot.bind("bubble_%d" % int(ppu)))
	for ppu: float in [44.0, 88.0]:          # 화면 위 띠 바로 아래에 선 사람 — 말풍선이 화면 안에 남나
		plan.append(_bubble_say)
		plan.append(_bubble_aim.bind(ppu, 9.0))
		plan.append(_bubble_note.bind(ppu))
		plan.append(_full.bind("bubble_top_%d" % int(ppu)))


func _s_bubble() -> int:
	scene.paused = true
	_clear_games()
	_park([owner, elder, kids[1]])
	_hold(owner, "rest", _to_spot.x - 1.3, _to_spot.y + 0.5, "쉬는 중")
	_hold(kids[1], "rest", _to_spot.x, _to_spot.y + 0.6, "쉬는 중")
	_hold(elder, "rest", _to_spot.x + 1.3, _to_spot.y + 0.5, "쉬는 중", "sit")
	_put_dog(dog_v, _to_spot + Vector2(-14.0, -8.0))
	_put_dog(dog_h, _to_spot + Vector2(-14.0, -9.0))
	_c = _to_spot + Vector2(0.0, 0.5)
	_follow = null
	scene.refresh()
	scene.paused = false
	return 40


func _bubble_say() -> int:
	var ss: Dictionary = scene.view.stage_say
	ss[owner.id] = ["볕이 좋네.", "", 30.0]
	ss[kids[1].id] = ["나도 갈래!", "cheer", 30.0]
	ss[elder.id] = ["그래그래.", "", 30.0]
	return 1


## top_y ≥ 0이면 사람들의 발이 화면 그 높이(논리 px)에 오게 카메라를 내림
func _bubble_aim(ppu: float, top_y: float) -> int:
	_half = Vector2(110, 84) if ppu < 80.0 else Vector2(170, 120)
	_look(_c, ppu)
	if top_y >= 0.0:                                   # 어른(owner)의 머리가 위 띠 아래 top_y px에 오게 — 두 번 맞춤
		var c3: Camera3D = scene.cam.camera
		var aim := _c
		for k in 3:
			var m := _model(owner)
			var feet: Vector3 = m.global_position
			var head := c3.unproject_position(feet) + TapReact.up_px(c3, feet) * float(m.call("react_top"))
			var want := float(scene.top_h) + top_y
			var s0 := c3.unproject_position(scene.ground_point(aim))
			var s1 := c3.unproject_position(scene.ground_point(aim + Vector2(0, 1)))
			var dy := s1.y - s0.y
			if absf(dy) < 0.01:
				break
			aim += Vector2(0, (head.y - want) / dy)
			_look(aim, ppu)
		var m2 := _model(owner)
		print("  위 끝 맞춤 (ppu %d): 머리 y %.0f · 위 띠 %.0f" % [int(ppu), (c3.unproject_position(m2.global_position) + TapReact.up_px(c3, m2.global_position) * float(m2.call("react_top"))).y, float(scene.top_h)])
	return 12


func _bubble_note(ppu: float) -> int:
	var rect: Rect2 = scene.bubble_rect(Vector2(360, 640))
	var out := 0
	var n := 0
	for c: Node in scene.bubbles.get_children():
		if c is Label:
			n += 1
			if not rect.grow(0.5).encloses(Rect2((c as Label).position, (c as Label).size)):
				out += 1
	print("  말풍선 (ppu %d, 위 끝): %d개 가운데 네모 밖 %d · 네모 %s" % [int(ppu), n, out, str(rect)])
	return 1


# ───────────────────────── 4. 짧은 이야기 ─────────────────────────
const CHAT := [[0, "오늘 볕이 참 좋네."], [1, "그러게, 빨래가 잘 마르겠어."], [0, "저녁에 모닥불에서 봐."], [1, "좋지!", "cheer"]]
const CHAT3 := [[0, "그건 내가 먼저 봤어!", "angry"], [1, "아니, 내가 먼저야!", "angry"], [2, "자자, 그만들 해."], [0, "…흥.", "sad"]]


func _plan_chat() -> void:
	plan.append(_begin.bind("chat"))
	for ppu: float in [44.0, 20.0]:
		plan.append(_s_chat.bind(false))
		plan.append(_centre.bind(ppu, 30))
		for i in CHAT.size():
			plan.append(_until.bind(_chat_line.bind(i), 900))
			plan.append(_sleep.bind(0.66))            # 듣는 이가 끄덕이는 때 (SocialStage.NOD_AT 첫 번째)
			plan.append(_shot.bind("chat_%d_%da" % [int(ppu), i + 1]))
			plan.append(_sleep.bind(0.42))            # 끄덕임 사이 (가만히)
			plan.append(_shot.bind("chat_%d_%db" % [int(ppu), i + 1]))
	plan.append(_s_chat.bind(true))
	plan.append(_centre.bind(44.0, 30))
	for i in CHAT3.size():
		plan.append(_until.bind(_chat_line.bind(i), 900))
		plan.append(_sleep.bind(0.8))
		plan.append(_shot.bind("chat3_44_%d" % (i + 1)))


func _s_chat(three: bool) -> int:
	scene.paused = true
	_clear_games()
	var who: Array = [owner, pal, third] if three else [owner, pal]
	_park(who)
	_hold(owner, "rest", _to_spot.x - 0.45, _to_spot.y + 0.5, "쉬는 중")
	_hold(pal, "rest", _to_spot.x + 0.45, _to_spot.y + 0.5, "쉬는 중")
	if three:
		_hold(third, "rest", _to_spot.x + 0.1, _to_spot.y + 1.5, "쉬는 중")
	_put_dog(dog_v, _to_spot + Vector2(-14.0, -8.0))
	_put_dog(dog_h, _to_spot + Vector2(-14.0, -9.0))
	var soc: SocialStage = scene.view.social
	soc._clear_all()
	var ls: Array = []
	for l: Array in (CHAT3 if three else CHAT):
		ls.append([int(l[0]), String(l[1]), String(l[2]) if l.size() > 2 else ""])
	var ev := Social._ev(v, "quarrel" if three else "talk", who, ls, "")
	ev["at"] = _to_spot + Vector2(0.0, 0.5)
	soc.start(ev)
	print("이야기 %s: 장면 %d · 펼침 %s · 지켜봄 %s · 빠름 %s" % [ev["kind"], soc.scenes.size(), str(soc.stage_on), str(v.is_watching()), str(scene.view.fast)] + " · 빠르기 %.0f" % scene.clock.speed())
	_c = _to_spot + Vector2(0.0, 0.6)
	_follow = null
	_half = Vector2(100, 80)
	scene.refresh()
	scene.paused = false
	return 2


func _chat_line(i: int) -> bool:
	var soc: SocialStage = scene.view.social
	if not soc.stage_on and not _chat_said:
		_chat_said = true
		var ck: JarClock = scene.clock
		print("  (이야기 장면 꺼짐: 빠르기 %.0f · 번호 %d · 건너뜀 %s · 빠른 흐름 %s · 창세 %s · 연출 빠르기 %.1f · 장면 몫 %.2f · 시각 %.1f시)" % [ck.speed(), ck.speed_i, str(ck.skipping), str(ck.fast), str(ck.creation), ck.stage_rate, ck.stage_scale(), v.hour_now()])
	for sc: Dictionary in soc.scenes:
		if soc._line_at(sc) >= i:
			return true
	return false
