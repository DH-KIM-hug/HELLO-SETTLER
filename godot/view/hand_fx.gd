## 거인의 손 연출 (ROADMAP B6 — sim/giant_hand.gd) — 물 뿌리기의 물보라 · 핀셋 집게가 내려왔다 올라감. 병 데이터 좌표의 3D (장면의 jar 아래).
## 시뮬레이션은 읽지 않는다 (장면이 결과를 보고 부른다). 김·먼지막·커튼·감싼 손·닦는 반짝임은 화면 막(view/jar_air_overlay.gd)이 그린다.
class_name HandFx
extends RefCounted

const SPRAY_H := 9.0                   # 물방울이 떨어지기 시작하는 높이 (칸)


## 물보라: 위에서 쏟아지는 물방울 (넘칠 때는 더 많이, 더 오래) + 땅의 젖은 둥근 자국 (잠깐)
static func spray(parent: Node3D, at: Vector3, rad: float, flood: bool) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	var pt := CPUParticles3D.new()
	pt.one_shot = true
	pt.amount = 260 if flood else 120
	pt.lifetime = 1.3
	pt.explosiveness = 0.35
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	pt.emission_sphere_radius = rad * 0.8
	pt.direction = Vector3(0, -1, 0)
	pt.spread = 8.0
	pt.initial_velocity_min = 6.0
	pt.initial_velocity_max = 9.0
	pt.gravity = Vector3(0, -14.0, 0)
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


## 핀셋: 은빛 집게 두 다리가 내려와 집고 올라감 (집은 것은 화면이 sim을 따라 감춘다)
static func tweezers(parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at + Vector3(0, 14.0, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.86, 0.88, 0.92)
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = Color(0.35, 0.37, 0.42)
	var legs: Array[MeshInstance3D] = []
	for s in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 9.0, 0.32)
		leg.mesh = bm
		leg.material_override = m
		leg.position = Vector3(s * 0.55, 4.5, 0)
		leg.rotation.z = s * 0.09
		root.add_child(leg)
		legs.append(leg)
	var tw := root.create_tween()
	tw.tween_property(root, "position:y", at.y + 0.2, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(legs[0], "rotation:z", -0.02, 0.45)
	tw.parallel().tween_property(legs[1], "rotation:z", 0.02, 0.45)
	tw.tween_interval(0.2)
	tw.tween_property(root, "position:y", at.y + 16.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	return root
