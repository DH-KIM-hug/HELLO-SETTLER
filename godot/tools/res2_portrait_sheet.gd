## A20 주민 2차 — 그림 초상 시트 (헤드리스로 됨: SVG를 바로 그림으로). 3D 줄 세우기(shot_res2.gd)와 같은 16명.
## godot --headless --path godot -s res://tools/res2_portrait_sheet.gd -- [접미사]
##   → godot_shots/res2_portraits<접미사>.png (4 × 4, 시대는 사람마다 i % 3) · res2_portrait_faces<접미사>.png (한 사람 표정 7가지 + 얼굴형 4 × 눈썹·코)
extends SceneTree

const People := preload("res://tools/res2_people.gd")
const CELL := 256
const PAD := 8


func _initialize() -> void:
	var suffix: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var out_dir := ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ps: Array = People.people()
	var sheet := _sheet(4, 4)
	for i in ps.size():
		var r: Resident = ps[i]
		ResidentModel.village_era = People.era_of(i)
		var ls := PortraitComposer.compose(ResidentModel.look_of(r), People.job_of(i, r), i == 3, People.FACES[i])
		print("%2d %s %4.1f era%d  %s" % [i, r.sex, r.age, People.era_of(i), " ".join(PortraitComposer.names_of(ls))])
		_put(sheet, ls, i % 4, i / 4)
	sheet.save_png(out_dir.path_join("res2_portraits%s.png" % suffix))
	# 표정 7 · 얼굴형 4 (같은 사람)
	var faces := _sheet(7, 2)
	var r0: Resident = ps[0]
	var k := 0
	for f: String in PortraitComposer.FACES:
		ResidentModel.village_era = 1
		_put(faces, PortraitComposer.compose(ResidentModel.look_of(r0), "", false, f), k, 0)
		k += 1
	for sh in 7:
		var r := Resident.new()
		r.id = 71000 + sh
		r.sex = "m" if sh % 2 else "f"
		r.age = 12.0 if sh < 6 else 3.0
		r.genes = r0.genes.duplicate()
		r.genes[Genetics.FACE] = sh * 64 % 256 + 10
		r.genes[Genetics.NOSE] = sh * 90 % 256
		r.genes[Genetics.BROW] = sh * 120 % 256
		r.genes[Genetics.STYLE] = sh * 37
		r.look_head = sh % 2
		r.look_clothes = 1 if r.sex == "f" else 0
		r.look_cloth = sh
		_put(faces, PortraitComposer.compose(ResidentModel.look_of(r), "", false, ""), sh, 1)
	faces.save_png(out_dir.path_join("res2_portrait_faces%s.png" % suffix))
	print("res2 portraits -> ", out_dir)
	quit()


func _sheet(cols: int, rows: int) -> Image:
	var img := Image.create(cols * (CELL + PAD) + PAD, rows * (CELL + PAD) + PAD, false, Image.FORMAT_RGBA8)
	img.fill(Color("f4ecd8"))
	return img


func _put(sheet: Image, ls: Array, cx: int, cy: int) -> void:
	var at := Vector2i(PAD + cx * (CELL + PAD), PAD + cy * (CELL + PAD))
	sheet.fill_rect(Rect2i(at, Vector2i(CELL, CELL)), UiTheme.PORTRAIT_BG)
	var img := Image.new()
	var err := img.load_svg_from_string(PortraitComposer.svg_of(ls), 1.0)
	if err != OK:
		push_error("svg failed")
		return
	img.convert(Image.FORMAT_RGBA8)
	sheet.blend_rect(img, Rect2i(0, 0, CELL, CELL), at)
