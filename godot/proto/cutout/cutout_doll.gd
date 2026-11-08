## 2D 컷아웃 주민을 3D 마을에 세우는 판 (비교 시제품, 2026-11-08) — 게임 주민 시스템과 무관.
## SubViewport(투명 배경)에서 cutout_rig를 그리고 → Sprite3D(카메라를 보는 판)로 3D 세상에 세움. 발 = 이 노드의 원점.
## 보기 고르기: 걷는 방향을 카메라 기준으로 — 다가옴(front) · 비스듬히 다가옴(q_front) · 비스듬히 멀어짐(q_back) · 멀어짐(back), 왼쪽이면 좌우 뒤집기.
## 발밑엔 납작한 그림자 타원 (art-bible R3).
extends Node3D

const RigScript := preload("res://proto/cutout/cutout_rig.gd")
const SHADOW_COL := Color(0.16, 0.2, 0.1)

## 화면에 보이는 키 (세계 단위, 카메라를 보는 판의 높이). 3D 주민(키 1)은 48° 아래로 볼 때 화면에서 약 0.7~0.75로 줄어 보이므로 맞춰 줌.
var screen_height := 0.8
## 판 그림의 세로 해상도 (px) — 화면에 그려지는 크기의 1~1.5배가 알맞음 (너무 크면 줄일 때 거칠어짐)
var tex_height := 160
var shaded := false            # true = 표준 빛 받기 — 시험해 보니 마을의 툰 빛(주변광 검정)과 안 맞아 새까매짐 → 쓰려면 toon_light 맞춤 셰이더가 필요
var vp: SubViewport
var rig: Node2D
var sprite: Sprite3D
var shadow: MeshInstance3D
var sun_card: Sprite3D
var _sun: DirectionalLight3D
var move_dir := Vector3.ZERO      # 세계 xz 방향 (0이면 서 있음 → 마지막 보기 유지)
var walking := false
var _last_dir := Vector3(0, 0, 1)
var _doll_h := 985.0              # rig 원본 키 (px)


func _ready() -> void:
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(vp)
	rig = RigScript.new()
	vp.add_child(rig)
	sprite = Sprite3D.new()
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = shaded
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.texture = vp.get_texture()
	add_child(sprite)
	# 해 그림자 전용 판: 카메라 대신 해를 향해 선 같은 그림 (보이지 않고 그림자만 드리움) — 3D 주민처럼 해 그림자가 생김
	sun_card = Sprite3D.new()
	sun_card.shaded = false
	sun_card.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sun_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	sun_card.texture = vp.get_texture()
	add_child(sun_card)
	shadow = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.42, 0.26)
	shadow.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 1, 1, 1))
	gr.set_color(1, Color(1, 1, 1, 0))
	gr.add_point(0.6, Color(1, 1, 1, 0.85))
	g.gradient = gr
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	m.albedo_texture = g
	m.albedo_color = Color(SHADOW_COL, 0.45)
	m.render_priority = -1
	shadow.material_override = m
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position.y = 0.02
	add_child(shadow)
	_resize()


## 그림 해상도·화면 키를 바꾼 뒤 부름
func _resize() -> void:
	var margin := 0.08
	var h := tex_height
	var w := int(ceil(h * 0.55))
	vp.size = Vector2i(w, h)
	var s := (h * (1.0 - margin)) / _doll_h
	rig.scale = Vector2(s, s)
	rig.position = Vector2(w * 0.5, h * (1.0 - margin * 0.25))
	sprite.pixel_size = screen_height / (h * (1.0 - margin))
	sprite.centered = true
	sprite.offset = Vector2(0, h * 0.5 - h * margin * 0.25)   # 발(그림 아래쪽)이 원점에
	sun_card.pixel_size = sprite.pixel_size / 0.74            # 그림자는 실제 키(1)로 — 화면 키는 내려다보는 각만큼 줄인 값
	sun_card.offset = sprite.offset


func set_tex_height(h: int) -> void:
	tex_height = h
	if vp != null:
		_resize()


func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := move_dir
	d.y = 0.0
	if d.length() > 0.001:
		_last_dir = d.normalized()
	var want := "walk" if walking else "idle"
	if rig.state != want:
		rig.play_state(want)
	pick_view(cam)
	if _sun == null:
		_sun = _find_sun(get_tree().root)
	if _sun != null:
		var ld := _sun.global_transform.basis.z         # 해 쪽
		sun_card.global_rotation = Vector3(0, atan2(ld.x, ld.z), 0)


func _find_sun(n: Node) -> DirectionalLight3D:
	if n is DirectionalLight3D and (n as DirectionalLight3D).visible:
		return n
	for c in n.get_children():
		var f := _find_sun(c)
		if f != null:
			return f
	return null


## 카메라 기준 방향 → 보기 4개 + 뒤집기
func pick_view(cam: Camera3D) -> void:
	var r := cam.global_transform.basis.x
	r.y = 0.0
	r = r.normalized()
	var f := -cam.global_transform.basis.z      # 카메라가 보는 쪽 (화면 안쪽 = 멀어짐)
	f.y = 0.0
	f = f.normalized()
	var sx := _last_dir.dot(r)                  # +면 화면 오른쪽으로
	var sf := _last_dir.dot(f)                  # +면 멀어짐
	var th := absf(atan2(sx, -sf))              # 0 = 정면으로 다가옴, PI = 멀어짐
	var v := "front"
	if th < deg_to_rad(25.0):
		v = "front"
	elif th < deg_to_rad(95.0):
		v = "q_front"
	elif th < deg_to_rad(155.0):
		v = "q_back"
	else:
		v = "back"
	# q_front 그림은 화면 오른쪽을 봄, q_back 그림은 왼쪽(위)을 봄
	var mirror := false
	if v == "q_front":
		mirror = sx < 0.0
	elif v == "q_back":
		mirror = sx > 0.0
	rig.set_view(v, mirror)
