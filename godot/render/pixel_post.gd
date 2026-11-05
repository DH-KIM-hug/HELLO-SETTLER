## 도트 마무리 화면 사각형 — 카메라 앞에 붙이면 외곽선·팔레트·디더링 (pixel_post.gdshader)
## 팔레트 크기는 data/palette.json의 count를 따른다 (지금 64색, 셰이더 최대 256).
class_name PixelPost
extends RefCounted

const PALETTE_PATH := "res://data/palette.json"
const MAX_COLORS := 256


static func load_palette() -> PackedColorArray:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PALETTE_PATH))
	var cols: Array = data["colors"]
	var n := mini(int(data.get("count", cols.size())), cols.size())
	var out := PackedColorArray()
	for i in mini(n, MAX_COLORS):
		out.append(Color(cols[i]["hex"]))
	return out


static func make_material() -> ShaderMaterial:
	var pal := load_palette()
	var img := Image.create(pal.size(), 1, false, Image.FORMAT_RGB8)
	for i in pal.size():
		img.set_pixel(i, 0, pal[i])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://render/pixel_post.gdshader")
	mat.set_shader_parameter("palette_tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("palette_size", pal.size())
	return mat


## 카메라 바로 앞에 화면 전체 사각형을 붙이고 그 재질을 돌려준다
static func attach(camera: Camera3D) -> ShaderMaterial:
	var mat := make_material()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	var post := MeshInstance3D.new()
	post.mesh = q
	post.material_override = mat
	post.extra_cull_margin = 16384.0
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(post)
	post.position = Vector3(0, 0, -2)
	return mat
