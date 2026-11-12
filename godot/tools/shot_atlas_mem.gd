## Q22 ③-0 방식 C 옷 한 벌의 그래픽 메모리 재기 + 전후 사진 (2026-11-12) — 실행 (창이 필요): godot --path godot -s res://tools/shot_atlas_mem.gd
## Q22M_MODE (없으면 tex):
##   tex    — 텍스처마다 불러오기 전후 RENDER_TEXTURE_MEM_USED 차이 · 형식 · 크기 · 밉맵 수 (Q22M_TEX = res:// 경로 쉼표 목록, 없으면 방식 C·머리 텍스처)
##   world  — 넓은 세상 마을 (shot_looks와 같은 꾸림 + 18명): 방식 C 끔 → 켬 의 RENDER_TEXTURE_MEM_USED (방식 C가 더하는 몫)
##   shots  — 빈 판 위에 방식 C 인형 4줄 × 8칸 (생김새 4 · 걷기·나르기·아기 안기·괭이질 등, 위상 고정 — 걸음 빠르기 0)을
##            ppu 20 · 44 · 60에서 → godot_shots/looks/l2_<Q22M_TAG>_ppu<N>.png (Q22M_TAG 없으면 now)
##            Q22M_PIC=etc2|astc|s3tc|bptc: 몸 그림(frames_atlas)을 그 형식으로 눌렀다 푼 그림으로 바꿔 찍음 (폰 형식의 모습을 데스크톱에서 봄),
##            raw = 누르지 않은 그림 (마스크를 바꾼 몫만 볼 때)
##            Q22M_HEAD=etc2|astc|…: 머리 그림(doll_atlas)도 같은 식으로
## 2026-11-12 결과 (Apple M4 Pro · Metal): 옷 한 벌 70.9 MB → 14.7 MB (몸 그림 BPTC 6.33 + 코드 4.72 + 코드표 0.002 + 4분의 1 마스크 1.81 × 2),
##   world: 방식 C 켬 +70.96 MB → +14.72 MB. 전후 사진·차이: godot_shots/looks/l2_*.png, l2_sheet.png
## 게임 코드는 바꾸지 않음.
extends SceneTree

const FLib := preload("res://proto/cutout_c/frame_lib.gd")
const FDoll := preload("res://proto/cutout_c/frame_doll.gd")
const Lib := preload("res://proto/cutout_a/cut_lib.gd")
const ADD := ["목조주택", "목조주택", "석조주택", "창고", "제재소", "방앗간", "빵집", "우물", "광장", "농장"]
const TEX := ["res://art/cutout/woman_c/frames_atlas.png", "res://art/cutout/woman_c/frames_mask0.png", "res://art/cutout/woman_c/frames_mask1.png",
	"res://art/cutout/woman_c/frames_mcode.png", "res://art/cutout/woman_c/frames_mlut.png", "res://art/cutout/woman_c/frames_mq0.png",
	"res://art/cutout/woman_c/frames_mq1.png", "res://art/cutout/woman_a/doll_atlas.png", "res://art/cutout/woman_a/doll_mask.png"]
## 사진 칸: [동작, 보기, 뒤집기, 위상, 소품, 짐]
const COLS := [["walk", 0, 1.0, 0.1, -1, ""], ["walk", 1, 1.0, 0.3, -1, ""], ["carry", 1, -1.0, 0.2, -1, "밀가루"], ["carry", 0, 1.0, 0.6, -1, "빵"],
	["rock", 0, 1.0, 0.0, -1, "#baby"], ["cradle", 1, 1.0, 0.4, -1, "#baby"], ["hoe", 1, 1.0, 0.3, 6, ""], ["walk", 2, 1.0, 0.55, -1, ""]]
const ROWS := [[11, 2, 3], [23, 6, 1], [37, 9, 5], [58, 4, 7]]     # 생김새: [씨앗, 피부 단계, 머리 색]
const PPUS := [20.0, 44.0, 60.0]

var mode := ""
var vp: SubViewport
var frame := 0
var _wait := 0
var step := 0
var plan: Array[Callable] = []
var out_dir := ""
var scene: Node
var cam: Camera3D
var dolls: Array[Node3D] = []
var _ppu := 0.0
var _keep: Array = []


func _initialize() -> void:
	mode = OS.get_environment("Q22M_MODE")
	if mode == "":
		mode = "tex"
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots/looks").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	vp = SubViewport.new()
	vp.size = Vector2i(1080, 1920)
	vp.size_2d_override = Vector2i(360, 640)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	match mode:
		"tex":
			plan = [_tex_all, _finish]
		"world":
			CutoutResident.override = 1
			FLib.spike = 0
			Village.default_created = {"year": 2026, "month": 6, "day": 15}
			Village.start_aware = true
			scene = load("res://scenes/world.tscn").instantiate()
			scene.world_seed = 20261107
			vp.add_child(scene)
			plan = [_w_build, _w_mem.bind("method C off"), _w_on, _w_mem.bind("method C on"), _finish]
		_:
			plan = [_s_build]
			for p: float in PPUS:
				plan.append(_s_look.bind(p))
				plan.append(_s_save)
			plan.append(_finish)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 6:
		return false
	if scene != null and "first_popup" in scene and scene.first_popup != null:
		scene.first_popup.queue_free()
		scene.first_popup = null
	if _wait > 0:
		_wait -= 1
		return false
	if step >= plan.size():
		return true
	var w: Variant = plan[step].call()
	step += 1
	_wait = int(w) if w != null else 4
	return false


func _mem() -> float:
	return float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED))


# ───────────── tex ─────────────
## 한 장씩: 불러오기 → 몇 장면 기다림 → 메모리 차이 (그리는 서버가 장면마다 세는 값이라 기다려야 바뀜)
var _tex_q: Array = []
var _tex_m0 := 0.0
var _tex_cur: Texture2D
var _tex_total := 0.0


func _tex_all() -> int:
	if _tex_q.is_empty() and _tex_cur == null:
		var paths: Array = TEX
		if OS.get_environment("Q22M_TEX") != "":
			paths = Array(OS.get_environment("Q22M_TEX").split(","))
		_tex_q = paths.duplicate()
		print("Q22M tex · renderer %s · %s" % [RenderingServer.get_current_rendering_driver_name(), RenderingServer.get_video_adapter_name()])
	if _tex_cur != null:
		var d := _mem() - _tex_m0
		_tex_total += d
		var img := _tex_cur.get_image()
		var fmt := _fmt_name(img.get_format()) if img != null else "?"
		var mips := img.get_mipmap_count() if img != null else 0
		print("Q22M tex %s · %dx%d · %s · mips %d · VRAM %.2f MB (%d B)" % [_tex_cur.resource_path.get_file(), _tex_cur.get_width(), _tex_cur.get_height(),
			fmt, mips, d / 1048576.0, int(d)])
		_keep.append(_tex_cur)
		_tex_cur = null
	while not _tex_q.is_empty():
		var p: String = _tex_q.pop_front()
		if not ResourceLoader.exists(p):
			print("Q22M tex %s · (없음)" % p.get_file())
			continue
		_tex_m0 = _mem()
		_tex_cur = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_IGNORE)
		step -= 1
		return 6
	print("Q22M tex total %.2f MB" % (_tex_total / 1048576.0))
	return 2


static func _fmt_name(f: int) -> String:
	var names := {Image.FORMAT_L8: "L8", Image.FORMAT_R8: "R8", Image.FORMAT_RG8: "RG8", Image.FORMAT_RGB8: "RGB8", Image.FORMAT_RGBA8: "RGBA8",
		Image.FORMAT_DXT1: "DXT1", Image.FORMAT_DXT5: "DXT5", Image.FORMAT_BPTC_RGBA: "BPTC(BC7)", Image.FORMAT_ETC2_RGBA8: "ETC2_RGBA8",
		Image.FORMAT_ETC2_RGB8: "ETC2_RGB8", Image.FORMAT_ASTC_4x4: "ASTC_4x4", Image.FORMAT_LA8: "LA8"}
	return String(names.get(f, str(f)))


# ───────────── world ─────────────
func _w_build() -> int:
	scene.paused = true
	var v: Village = scene.village
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 18:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(0.5, 4.0)
		v.add_person("메%d" % i, "f" if i % 2 == 0 else "m", 8.0 + i, "", v.center.x + cos(ang) * rad, v.center.y + sin(ang) * rad, null, null)
	scene.refresh()
	scene.set_debug_mode(false)
	scene.look_at_ground(v.center)
	scene.cam.ppu = 44.0
	scene.cam.ppu_goal = 44.0
	scene.cam._apply()
	scene.paused = false
	return 90


func _w_mem(tag: String) -> int:
	RenderingServer.force_sync()
	var n_c := 0
	for m: Node in scene.view.residents.values():
		if m is CutoutResident and (m as CutoutResident)._f_on:
			n_c += 1
	print("Q22M world %s · texture mem %.2f MB · video mem %.2f MB · method-C dolls %d · people %d" % [tag, _mem() / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, n_c, scene.village.people.size()])
	return 4


func _w_on() -> int:
	FLib.spike = 1
	scene.view.sync(0.0, true)
	return 60


# ───────────── shots ─────────────
func _s_build() -> int:
	var w := Node3D.new()
	vp.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.8, 0.5)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	w.add_child(env)
	# 평평한 풀색 바닥판 (shot_cutC_compare의 띠와 같음)
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.62, 0.8, 0.5)
	pm.material = bm
	var plate := MeshInstance3D.new()
	plate.mesh = pm
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plate.position = Vector3(0, -0.01, 0)
	w.add_child(plate)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	# 그림자를 켜야 함 (2026-11-12: 그림자 없는 해 아래서는 버린(discard) 자리가 검은 네모로 남았다 — 게임의 해는 늘 그림자를 켬)
	sun.shadow_enabled = true
	w.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	w.add_child(cam)
	cam.rotation_degrees = Vector3(-JarCamera.PITCH_DEG, 0, 0)
	cam.position = Vector3(0, 0.6, 0) + cam.global_transform.basis.z * 40.0
	cam.near = 1.0
	cam.far = 100.0
	cam.current = true
	var pal: PackedVector3Array = CutoutResident.game_material().get_shader_parameter("palette")
	var mat: ShaderMaterial = FLib.material(pal)
	var pic := OS.get_environment("Q22M_PIC")
	if pic != "":
		mat = mat.duplicate() as ShaderMaterial
		mat.set_shader_parameter("frames_atlas", _squeezed("res://art/cutout/woman_c/frames_atlas.png", pic))
	var hpic := OS.get_environment("Q22M_HEAD")
	if hpic != "":
		if pic == "":
			mat = mat.duplicate() as ShaderMaterial
		mat.set_shader_parameter("atlas", _squeezed("res://art/cutout/woman_a/doll_atlas.png", hpic))
	for ri in ROWS.size():
		var r: Array = ROWS[ri]
		var look := Lib.look_from(int(r[0]), "f", int(r[1]), int(r[2]))
		look["head"] = ri % 2
		var hat := int(look["hat"]) if ri == 2 else -1
		for ci in COLS.size():
			var c: Array = COLS[ci]
			var n: MeshInstance3D = FDoll.new()
			n.setup(mat)
			w.add_child(n)
			n.set_look(look, hat)
			n.set_prop(int(c[4]), String(c[5]))
			if String(c[5]) == "#baby":
				n.set_baby(ri * 2 % 12, 12 + ri)
			n.view = int(c[1])
			n.mirror = float(c[2])
			n.set_clip(String(c[0]), 0.0, float(c[3]))
			n.position = Vector3((float(ci) - 3.5) * 0.72, 0.0, (float(ri) - 1.5) * 1.55)
			dolls.append(n)
	print("Q22M shots · %d dolls · picture %s · head %s" % [dolls.size(), pic if pic != "" else "imported", hpic if hpic != "" else "imported"])
	return 4


## 그림을 그 VRAM 형식으로 눌렀다가 다시 풀어 RGBA8 텍스처로 — 가져오기와 같이 밉맵을 만든 뒤 단마다 따로 누름
## (단 크기를 4의 배수로 채워 누르고 잘라 냄: 엔진의 ASTC 풀기가 밉맵째로는 4의 배수가 아닌 단에서 깨짐 — 2026-11-12)
func _squeezed(path: String, kind: String) -> ImageTexture:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	img.fix_alpha_edges()
	img.generate_mipmaps()
	var cm := {"etc2": Image.COMPRESS_ETC2, "astc": Image.COMPRESS_ASTC, "s3tc": Image.COMPRESS_S3TC, "bptc": Image.COMPRESS_BPTC}
	if kind == "raw":                 # 누르지 않음 (가져오기 전 손실 없는 그림 — 마스크만 바꾼 차이를 볼 때)
		return ImageTexture.create_from_image(img)
	var t0 := Time.get_ticks_msec()
	var out := PackedByteArray()
	var bytes := 0
	for L in img.get_mipmap_count() + 1:
		var w := maxi(img.get_width() >> L, 1)
		var h := maxi(img.get_height() >> L, 1)
		var ofs := img.get_mipmap_offset(L)
		var lv := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, img.get_data().slice(ofs, ofs + w * h * 4))
		var pad := Image.create((w + 3) / 4 * 4, (h + 3) / 4 * 4, false, Image.FORMAT_RGBA8)
		pad.blit_rect(lv, Rect2i(0, 0, w, h), Vector2i.ZERO)
		pad.compress(cm[kind], Image.COMPRESS_SOURCE_SRGB, Image.ASTC_FORMAT_4x4)
		bytes += pad.get_data_size()
		pad.decompress()
		pad.convert(Image.FORMAT_RGBA8)
		out.append_array(pad.get_region(Rect2i(0, 0, w, h)).get_data())
	var res := Image.create_from_data(img.get_width(), img.get_height(), true, Image.FORMAT_RGBA8, out)
	print("Q22M squeeze %s → %s per level (%.2f MB compressed, %d ms), mips %d" % [path.get_file(), kind, bytes / 1048576.0, Time.get_ticks_msec() - t0, res.get_mipmap_count()])
	return ImageTexture.create_from_image(res)


func _s_look(ppu: float) -> int:
	_ppu = ppu
	cam.size = 640.0 / ppu
	return 8


func _s_save() -> int:
	var img := vp.get_texture().get_image()
	# 인형들 둘레만 잘라 냄
	var r := Rect2()
	var first := true
	for n: Node3D in dolls:
		for h: float in [0.0, 1.05]:
			for dx: float in [-0.42, 0.42]:
				var sp: Vector2 = cam.unproject_position(n.global_position + Vector3(dx, h, 0)) * 3.0
				if first:
					r = Rect2(sp, Vector2.ZERO)
					first = false
				else:
					r = r.expand(sp)
	var ri := Rect2i(r.grow(8.0)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var tag := OS.get_environment("Q22M_TAG")
	if tag == "":
		tag = "now"
	var fn := out_dir.path_join("l2_%s_ppu%d.png" % [tag, int(_ppu)])
	img.get_region(ri).save_png(fn)
	print("Q22M saved %s · %s · texture mem %.2f MB" % [fn.get_file(), ri, _mem() / 1048576.0])
	return 2


func _finish() -> int:
	quit()
	return 1
