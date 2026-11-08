## 2D 컷아웃 주민 시험 장면 (비교 시제품, 2026-11-08): 풀밭 + 병 카메라(48°) + 원을 그리며 걷는 컷아웃 여자 + 서 있는 컷아웃 + 3D 주민.
## 실행: godot --path godot res://proto/cutout/cutout_test.tscn   (휠 = 확대, 스페이스 = 걷기/멈춤)
extends Node3D

const DollScript := preload("res://proto/cutout/cutout_doll.gd")

var cam: JarCamera
var walker: Node3D
var t := 0.0
var walking := true


func _ready() -> void:
	JarTerrain.make_world(self)
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	var g := MeshInstance3D.new()
	g.mesh = pm
	g.material_override = Toon.mat(Style.GRASS)
	add_child(g)
	walker = DollScript.new()
	add_child(walker)
	var idle: Node3D = DollScript.new()
	add_child(idle)
	idle.position = Vector3(0.0, 0, 0.0)
	idle.move_dir = Vector3(1, 0, 1)
	var m := ResidentModel.new()
	add_child(m)
	m.build(1, 1, 1, 2, 1, 1, 10.0, "f")
	m.position = Vector3(1.2, 0, -1.2)
	m.set_anim("idle")
	cam = JarCamera.new()
	add_child(cam)
	cam.ground_radius = 1000.0
	cam.ppu = 60.0
	cam.ppu_goal = 60.0


func _process(dt: float) -> void:
	if walking:
		t += dt
	var a := t * 0.35
	var r := 2.2
	walker.position = Vector3(cos(a) * r, 0, sin(a) * r)
	walker.move_dir = Vector3(-sin(a), 0, cos(a))
	walker.walking = walking
	walker.call("set_tex_height", int(clampf(cam.ppu * 2.2 * 1.5, 64.0, 512.0)))


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.zoom_by(1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.zoom_by(1.0 / 1.15)
	elif e is InputEventKey and e.pressed and (e as InputEventKey).keycode == KEY_SPACE:
		walking = not walking
