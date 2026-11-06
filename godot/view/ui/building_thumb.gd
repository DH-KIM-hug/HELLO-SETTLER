## 건물 카드 그림 — 상점 '건물' 탭 (UI 06). 건물 아이콘이 따로 없어 마을과 같은 3D 모델(art/models)을 작은 화면 하나에 한 번 찍는다.
## 쓰는 법: BuildingThumb.rect("우물", 56) → Control (투명 바탕, 비스듬히 내려다본 건물). 모델이 없으면 집 아이콘.
class_name BuildingThumb
extends RefCounted


static func rect(type: String, px: float) -> Control:
	var names: Array = VillageView.BUILDING_MODELS.get(type, [])
	if names.is_empty() or not Art.exists(String(names[0])):
		return GameIcons.rect("마을로 가기", px)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(px, px)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.size = Vector2i(int(px * 2.0), int(px * 2.0))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_specular = 0.0
	root.add_child(sun)
	var d := Style.sun_direction()
	sun.look_at_from_position(-d * 50.0, Vector3.ZERO, Vector3.UP)
	var n := Art.instance(root, String(names[0]))
	n.rotation.y = deg_to_rad(JarCamera.BASE_YAW_DEG)
	var size := float(Balance.B.get(type, {"size": 1.0})["size"])
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(2.4, size * 2.9)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var eye := Vector3(sin(yaw), 0.9, cos(yaw)).normalized() * 30.0
	cam.look_at_from_position(eye + Vector3(0, size * 0.45, 0), Vector3(0, size * 0.45, 0), Vector3.UP)
	cam.far = 80.0
	root.add_child(cam)
	return box
