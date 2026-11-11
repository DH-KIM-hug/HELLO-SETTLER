## Q22 ① 겉모습 점검 (2026-11-12) — 실행 (창이 필요): godot --path godot -s res://tools/shot_looks.gd
## 넓은 세상(world.tscn) 마을 (shot_cutgame과 같은 꾸림: 4일 + 건물) + 나이·성별·유전 형질을 골라 넣은 사람 18명:
##   l1_village_{cut,C}_ppu{20,44}.png — 낮 10시 마을이 살아 움직이는 중 (cut = 지금 기본 컷아웃 인형, C = 방식 C 켬)
##   l1_lineup_{cut,C}_ppu{20,44}.png — 같은 18명을 빈 터에 세 줄로 세워 모두 카메라 쪽 (앞 보기, 서기)
## 줄 세운 사람의 형질은 로그에 (줄·칸 · 나이 · 성별 · Genetics.describe · 머리 묶음 · 옷 묶음 · 모자).
## 게임 코드는 바꾸지 않음 — 형질 유전자만 이 사진용 사람에게 직접 넣음.
extends SceneTree

const FLib := preload("res://proto/cutout_c/frame_lib.gd")
const ADD := ["목조주택", "목조주택", "석조주택", "창고", "제재소", "방앗간", "빵집", "우물", "광장", "농장"]

## 사진용 사람: [성별, 나이(일생 날), 형질 표시] — 형질: 유전자 바이트 덮어쓰기 (Genetics 상수 번호 → 값)
## 줄 0 = 아이 6, 줄 1 = 어른 6, 줄 2 = 어른 2 + 노인 4
var CAST := [
	["f", 1.8, {}], ["m", 2.2, {"curl": 2}], ["f", 2.8, {"red": true, "freck": true}], ["m", 3.0, {"skin": 230}],
	["f", 3.5, {"rare": 2}], ["m", 3.6, {"blond": true, "eye": 2}],
	["f", 8.0, {"skin": 20, "blond": true, "eye": 2}], ["m", 9.0, {"skin": 235, "curl": 2}], ["f", 10.0, {"red": true, "freck": true, "skin": 15}],
	["m", 16.0, {"bald": true}], ["f", 12.0, {"rare": 1}], ["m", 11.0, {"piebald": true, "skin": 170}],
	["f", 6.0, {"height": 20, "build": 20}], ["m", 7.0, {"height": 240, "build": 240}],
	["f", 23.0, {}], ["m", 24.0, {"bald": true}], ["f", 26.0, {"skin": 200}], ["m", 22.0, {"curl": 2, "skin": 120}],
]

var scene: Node
var vp: SubViewport
var v: Village
var out_dir := ""
var frame := 0
var step := 0
var _wait := 0
var plan: Array[Callable] = []
var _center := Vector2.ZERO
var _cast: Array[Resident] = []
var _spot := Vector2.ZERO


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/looks").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	CutoutResident.override = 1
	FLib.spike = 0
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
	plan = [_build, _live.bind(10.0),
		_shot.bind("village_cut", 20.0), _shot.bind("village_cut", 44.0),
		_frames.bind(1), _shot.bind("village_C", 20.0), _shot.bind("village_C", 44.0),
		_lineup, _lshot.bind("lineup_C", 44.0), _lshot.bind("lineup_C", 20.0),
		_frames.bind(0), _lshot.bind("lineup_cut", 44.0), _lshot.bind("lineup_cut", 20.0), _finish]


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


func _gene(r: Resident, k: String, val: Variant) -> void:
	var g := r.genes
	match k:
		"skin": g[Genetics.SKIN] = int(val)
		"height": g[Genetics.HEIGHT] = int(val)
		"build": g[Genetics.BUILD] = int(val)
		"eye":
			g[Genetics.EYE] = int(val)
			g[Genetics.EYE + 1] = int(val)
		"blond":
			g[Genetics.DARK] = 2
			g[Genetics.DARK + 1] = 2
		"red":
			g[Genetics.RED] = 1
			g[Genetics.RED + 1] = 1
		"curl":
			g[Genetics.CURL] = 1
			g[Genetics.CURL + 1] = 1
		"freck":
			g[Genetics.FRECK] = 1
		"bald":
			g[Genetics.BALD] = 1
			g[Genetics.BALD + 1] = 1
		"rare": g[Genetics.RARE] = int(val)
		"piebald":
			g[Genetics.PIEBALD] = 1
			g[Genetics.PATTERN] = 77
	r.genes = g


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
	var fs: Variant = v.find_spot("농장")
	_spot = fs if fs != null else v.center + Vector2(4, 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in CAST.size():
		var c: Array = CAST[i]
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.5, 4.0)
		var r := v.add_person("겉%d" % i, c[0], c[1], "", v.center.x + cos(ang) * rad, v.center.y + sin(ang) * rad, null, null)
		for k: String in c[2]:
			_gene(r, k, c[2][k])
		_cast.append(r)
	scene.refresh()
	scene.set_debug_mode(false)
	return 10


func _live(hour: float) -> int:
	scene.paused = true
	var d := fposmod(hour - v.hour_now(), 24.0) * 3600.0
	while d > 0.0:
		var s := minf(600.0, d)
		scene.world.advance(s)
		d -= s
	scene.refresh()
	scene.paused = false
	return 150


func _frames(on: int) -> int:
	FLib.spike = on
	scene.view.sync(0.0, true)
	return 30


func _busy() -> Vector2:
	var best := v.center
	var bn := -1
	for a: Resident in v.people:
		var n := 0
		for b: Resident in v.people:
			if Vector2(a.x - b.x, a.y - b.y).length() < 3.0:
				n += 1
		if n > bn:
			bn = n
			best = Vector2(a.x, a.y)
	return best


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


var _pending := ""


func _shot(tag: String, ppu: float) -> int:
	if _pending == "":
		if ppu < 30.0:
			_center = _busy()
		_look(_center, ppu)
		_pending = "%s_ppu%d" % [tag, int(ppu)]
		step -= 1
		return 40
	_save(_pending)
	_pending = ""
	return 2


func _lshot(tag: String, ppu: float) -> int:
	if _pending == "":
		_look(_spot, ppu)
		scene.view.sync(0.0, true)
		_pending = "%s_ppu%d" % [tag, int(ppu)]
		step -= 1
		return 40
	_save(_pending)
	_pending = ""
	return 2


func _save(name: String) -> void:
	var img := vp.get_texture().get_image()
	img.save_png(out_dir.path_join("l1_" + name + ".png"))
	var n_c := 0
	var n := 0
	for m: Node in scene.view.residents.values():
		if m is CutoutResident and (m as CutoutResident).visible:
			n += 1
			if (m as CutoutResident)._f_on:
				n_c += 1
	print("saved l1_%s · %s · people %d · dolls %d · method-C dolls %d" % [name, v.fmt_time(v.t), v.people.size(), n, n_c])


## 18명을 빈 터에 세 줄 (아이 · 어른 · 어른+노인), 모두 카메라 쪽을 보고 섬
func _lineup() -> int:
	scene.paused = true
	_look(_spot, 44.0)
	var cam: Camera3D = scene.cam.camera
	var bs := cam.global_transform.basis
	var right := Vector2(bs.x.x, bs.x.z).normalized()
	var toward := Vector2(bs.z.x, bs.z.z).normalized()
	for i in _cast.size():
		var r := _cast[i]
		var row := i / 6
		var col := i % 6
		var p: Vector2 = _spot + right * (float(col) - 2.5) * 0.95 + toward * (float(row) - 1.0) * 1.25
		r.x = p.x
		r.y = p.y
		r.px = p.x
		r.py = p.y
		r.anim = "idle"
		r.action = "idle"
		r.carry = ""
		r.sleeping = false
		r.say_t = 0.0
		r.facing = atan2(toward.x, toward.y)
		var m: CutoutResident = scene.view.residents.get(r.id)
		var dl: Dictionary = m.dlook if m != null else {}
		print("cast row %d col %d · %s · age %.1f (%s) · %s · head %s outfit %s hat %s · dye %s" % [row, col, r.sex, r.age,
			"child" if r.is_child() else ("elder" if r.age >= Balance.AGE_ELDER else ("baby" if r.is_baby() else "adult")),
			Genetics.describe(r.genes, r.sex, r.age), dl.get("head", "?"), dl.get("personal", "?"), dl.get("hat", "?"), dl.get("dye", [])])
	scene.view.sync(0.0, true)
	return 40


func _finish() -> int:
	quit()
	return 1
