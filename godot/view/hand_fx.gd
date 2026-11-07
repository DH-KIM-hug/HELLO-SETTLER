## 거인의 도구 연출 (ROADMAP B6 — sim/giant_hand.gd) — 물 뿌리기의 물안개 · 핀셋 끝이 내려왔다 올라감. 병 데이터 좌표의 3D (장면의 jar 아래).
## (A24 2026-11-08 그림 원칙) 거인의 손은 화면에 나오지 않는다: 물은 화면 밖 위에서 원뿔로 내려오는 물안개, 핀셋은 끝만 화면 위 가장자리로 들어옴.
## 시뮬레이션은 읽지 않는다 (장면이 결과를 보고 부른다). 김·먼지막·닦는 줄은 화면 막(view/jar_air_overlay.gd)이 그린다.
class_name HandFx
extends RefCounted

const SPRAY_H := 34.0                  # 물안개가 나오는 높이 (칸) — 화면 위 밖
const TWEEZ_LEN := 70.0                # 핀셋 다리 길이 (칸) — 끝만 화면에 들어오고 나머지는 위 밖
const TWEEZ_START := 40.0              # 핀셋 끝이 내려오기 시작하는 높이 (화면 위 밖)


## 물 뿌리기: 화면 밖 위에서 원뿔로 퍼지며 내려오는 물안개 (옅은 원뿔 빛 + 물방울) + 땅에 닿아 피어오르는 안개 + 젖은 둥근 자국 (잠깐).
## 넘칠 때는 더 많이, 더 오래
static func spray(parent: Node3D, at: Vector3, rad: float, flood: bool) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	# 옅은 원뿔 (위에서 아래로 넓어짐 — 물줄기가 지나가는 길)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = rad * 0.95
	cm.height = SPRAY_H
	cm.radial_segments = 24
	cm.cap_top = false
	cm.cap_bottom = false
	cone.mesh = cm
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cmat.albedo_color = Color(0.82, 0.93, 1.0, 0.0)
	cone.material_override = cmat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.position.y = SPRAY_H * 0.5
	root.add_child(cone)
	# 물방울: 원뿔 꼭짓점(화면 밖)에서 퍼지며 떨어짐
	var pt := CPUParticles3D.new()
	pt.one_shot = true
	pt.amount = 300 if flood else 150
	pt.lifetime = 1.5
	pt.explosiveness = 0.25
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = 0.3
	pt.direction = Vector3(0, -1, 0)
	pt.spread = rad_to_deg(atan(rad * 0.95 / SPRAY_H))
	pt.initial_velocity_min = 24.0
	pt.initial_velocity_max = 30.0
	pt.gravity = Vector3(0, -8.0, 0)
	pt.scale_amount_min = 0.7
	pt.scale_amount_max = 1.3
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.34
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.72, 0.88, 1.0, 0.85)
	sm.material = m
	pt.mesh = sm
	pt.position = Vector3(0, SPRAY_H, 0)
	root.add_child(pt)
	pt.emitting = true
	# 땅에서 피어오르는 물안개 (부드러운 알갱이)
	var mist := CPUParticles3D.new()
	mist.one_shot = true
	mist.amount = 40 if flood else 24
	mist.lifetime = 1.6
	mist.explosiveness = 0.2
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	mist.emission_sphere_radius = rad * 0.8
	mist.direction = Vector3(0, 1, 0)
	mist.spread = 60.0
	mist.initial_velocity_min = 0.3
	mist.initial_velocity_max = 0.9
	mist.gravity = Vector3.ZERO
	mist.scale_amount_min = 0.8
	mist.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 0.96, 1.0, 0.0))
	ramp.set_color(1, Color(0.9, 0.96, 1.0, 0.0))
	ramp.add_point(0.3, Color(0.9, 0.96, 1.0, 0.45))
	mist.color_ramp = ramp
	var qm := QuadMesh.new()
	qm.size = Vector2(1.4, 1.4)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.vertex_color_use_as_albedo = true
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mm.albedo_texture = SkyDescent.soft_tex()
	qm.material = mm
	mist.mesh = qm
	mist.position.y = 0.6
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mist)
	var ctw := root.create_tween()
	ctw.tween_property(cmat, "albedo_color:a", 0.16, 0.25)
	ctw.tween_interval(0.9 if flood else 0.5)
	ctw.tween_property(cmat, "albedo_color:a", 0.0, 0.6)
	var mtw := root.create_tween()
	mtw.tween_interval(1.0)
	mtw.tween_callback(func() -> void: mist.emitting = true)
	# 젖은 자국
	var wet := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = rad
	cy.bottom_radius = rad
	cy.height = 0.03
	cy.radial_segments = 28
	wet.mesh = cy
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.albedo_color = Color(0.2, 0.3, 0.45, 0.0)
	wet.material_override = wm
	wet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wet.position.y = 0.05
	root.add_child(wet)
	var tw := root.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(wm, "albedo_color:a", 0.4 if flood else 0.28, 0.4)
	tw.tween_interval(1.4 if flood else 0.8)
	tw.tween_property(wm, "albedo_color:a", 0.0, 1.2)
	tw.tween_callback(root.queue_free)
	return root


## 핀셋: 은빛 집게의 끝만 화면 위 가장자리로 들어와 (다리는 길어 위는 화면 밖) 내려와 집고 올라감 (집은 것은 화면이 sim을 따라 감춘다)
static func tweezers(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at + Vector3(0, TWEEZ_START, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.88, 0.92)
	m.roughness = 0.35
	m.metallic = 0.4
	m.emission_enabled = true
	m.emission = Color(0.35, 0.37, 0.42)
	var legs: Array[Node3D] = []
	for s in [-1.0, 1.0]:
		var leg := Node3D.new()                    # 집게 다리 하나 (끝을 축으로 오므림)
		leg.position = Vector3(s * 0.45, 0, 0)
		leg.rotation.z = s * 0.05
		root.add_child(leg)
		var shaft := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.2, TWEEZ_LEN, 0.36)
		shaft.mesh = bm
		shaft.material_override = m
		shaft.position = Vector3(0, 1.2 + TWEEZ_LEN * 0.5, 0)
		leg.add_child(shaft)
		var tip := MeshInstance3D.new()            # 가늘어지는 끝 (안쪽으로 살짝 굽음)
		var cm := CylinderMesh.new()
		cm.top_radius = 0.15
		cm.bottom_radius = 0.035
		cm.height = 1.3
		cm.radial_segments = 6
		tip.mesh = cm
		tip.material_override = m
		tip.position = Vector3(-s * 0.06, 0.62, 0)
		tip.rotation.z = -s * 0.12
		leg.add_child(tip)
		legs.append(leg)
	var tw := root.create_tween()
	tw.tween_property(root, "position:y", at.y + 0.2, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(legs[0], "rotation:z", -0.04, 0.15)
	tw.parallel().tween_property(legs[1], "rotation:z", 0.04, 0.15)
	tw.tween_interval(0.15)
	tw.tween_property(root, "position:y", at.y + TWEEZ_START + 6.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	return root
