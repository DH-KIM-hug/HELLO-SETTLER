## 2D 종이 인형(컷아웃) 주민 비교 시제품 — 뼈대(Node2D 계층) + AnimationPlayer (2026-11-08, 2D vs 3D 비교용; 게임 주민 시스템과 무관)
## rig.json (godot/tools/cutout/export_rig.py가 만듦): 보기 4개(front · q_front · q_back · back) × 부품 10개.
## 원점 = 발 가운데, 단위 = 원본 그림 px (위가 -y). 보기 하나만 보이고, 옆모습은 3/4 보기를 좌우로 뒤집어 씀.
## 동작: idle (숨쉬기·수건 흔들림), walk (다리·팔 흔들기, 몸 오르내림, 수건 자락 늦게 따라옴).
extends Node2D

const VIEWS := ["front", "q_front", "q_back", "back"]
const WALK_T := 0.8           # 한 걸음 주기 (두 발) — 초
const IDLE_T := 3.2
const KEYS := 16

var rig_path := "res://art/cutout/woman_b/rig.json"
var views := {}               # view → Node2D
var bones := {}               # view → {name: Node2D}
var player: AnimationPlayer
var view := "front"
var state := "idle"
var mirrored := false
var _shown := false


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rig_path))
	for v: String in VIEWS:
		_build_view(v, data[v])
	player = AnimationPlayer.new()
	add_child(player)
	var lib := AnimationLibrary.new()
	for v: String in VIEWS:
		lib.add_animation(v + "_idle", _make_anim(v, false))
		lib.add_animation(v + "_walk", _make_anim(v, true))
	player.add_animation_library("", lib)
	set_view("front", false)
	play_state("idle")


func _build_view(v: String, d: Dictionary) -> void:
	var root := Node2D.new()
	root.name = v
	add_child(root)
	views[v] = root
	var b := {}
	var body := Node2D.new()          # 몸 전체 (오르내림) — 엉덩이 높이에 둠
	body.name = "body"
	root.add_child(body)
	b["body"] = body
	var parts: Dictionary = d["parts"]
	var abs_pos := {"body": Vector2.ZERO}
	# 부모가 먼저 만들어지도록: body → torso → head → 나머지
	var order := ["torso", "head", "skirt", "leg_l", "leg_r", "arm_l", "arm_r", "sash", "drape", "braid"]
	for n: String in order:
		var p: Dictionary = parts[n]
		var bone := Node2D.new()
		bone.name = n
		var pos := Vector2(p["pos"][0], p["pos"][1])
		abs_pos[n] = pos
		var par: String = p["parent"]
		bone.position = pos - abs_pos[par]
		(b[par] as Node2D).add_child(bone)
		var spr := Sprite2D.new()
		spr.texture = load(p["tex"])
		spr.centered = false
		spr.offset = -Vector2(p["pivot"][0], p["pivot"][1])
		spr.scale = Vector2(float(p["sx"]), float(p["sy"]))
		spr.z_as_relative = false
		spr.z_index = int(p["z"])
		bone.add_child(spr)
		bone.set_meta("rest", bone.position)
		b[n] = bone
	bones[v] = b


## 곡선 하나 = 주기 안의 함수 → 키 KEYS개 (반복, 3차 보간)
func _track(a: Animation, path: String, prop: String, f: Callable) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(path + ":" + prop))
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	a.value_track_set_update_mode(t, Animation.UPDATE_CONTINUOUS)
	for i in KEYS + 1:
		var u := float(i) / KEYS
		a.track_insert_key(t, u * a.length, f.call(u * TAU))


func _make_anim(v: String, walk: bool) -> Animation:
	var a := Animation.new()
	a.length = WALK_T if walk else IDLE_T
	a.loop_mode = Animation.LOOP_LINEAR
	var b: Dictionary = bones[v]
	var side := v.begins_with("q_")
	# 3/4 보기에서 '뒤쪽' 방향 (수건 자락이 끌려가는 쪽): q_front 그림은 오른쪽을 봄 → 뒤 = 왼쪽(+회전), q_back은 왼쪽을 봄
	var back_sign := 1.0 if v == "q_front" else (-1.0 if v == "q_back" else 0.0)
	var P := func(n: String) -> String: return v + "/" + _path(b, n)
	var rest := func(n: String) -> Vector2: return (b[n] as Node2D).get_meta("rest")
	if walk:
		_track(a, P.call("body"), "position", func(x: float) -> Vector2: return Vector2(0, -9.0 * absf(sin(x))))
		_track(a, P.call("body"), "rotation", func(x: float) -> float: return deg_to_rad(1.2) * sin(x))
		_track(a, P.call("torso"), "rotation", func(x: float) -> float: return deg_to_rad(1.5) * sin(x) + deg_to_rad(2.0) * -back_sign)
		_track(a, P.call("head"), "rotation", func(x: float) -> float: return deg_to_rad(1.5) * sin(x + 0.6))
		if side:
			_track(a, P.call("leg_l"), "rotation", func(x: float) -> float: return deg_to_rad(20.0) * sin(x))
			_track(a, P.call("leg_r"), "rotation", func(x: float) -> float: return deg_to_rad(-20.0) * sin(x))
			_track(a, P.call("arm_l"), "rotation", func(x: float) -> float: return deg_to_rad(-22.0) * sin(x))
			_track(a, P.call("arm_r"), "rotation", func(x: float) -> float: return deg_to_rad(18.0) * sin(x))
		else:
			var rl: Vector2 = rest.call("leg_l")
			var rr: Vector2 = rest.call("leg_r")
			_track(a, P.call("leg_l"), "position", func(x: float) -> Vector2: return rl + Vector2(0, -16.0 * maxf(0.0, sin(x))))
			_track(a, P.call("leg_r"), "position", func(x: float) -> Vector2: return rr + Vector2(0, -16.0 * maxf(0.0, -sin(x))))
			_track(a, P.call("arm_l"), "rotation", func(x: float) -> float: return deg_to_rad(7.0) * sin(x) + deg_to_rad(3.0))
			_track(a, P.call("arm_r"), "rotation", func(x: float) -> float: return deg_to_rad(7.0) * sin(x) - deg_to_rad(3.0))
		_track(a, P.call("skirt"), "rotation", func(x: float) -> float: return deg_to_rad(2.5) * sin(x) + deg_to_rad(1.5) * back_sign)
		_track(a, P.call("skirt"), "scale", func(x: float) -> Vector2: return Vector2(1.0 + 0.025 * absf(sin(x)), 1.0 - 0.015 * absf(sin(x))))
		# 늦게 따라오는 천: 몸보다 위상이 늦고, 뒤로 끌림
		_track(a, P.call("drape"), "rotation", func(x: float) -> float: return deg_to_rad(5.0) * back_sign + deg_to_rad(3.0) * sin(x - 1.2) + deg_to_rad(1.5) * sin(2.0 * x - 1.6))
		_track(a, P.call("braid"), "rotation", func(x: float) -> float: return deg_to_rad(3.0) * back_sign + deg_to_rad(5.0) * sin(x - 1.0))
		_track(a, P.call("sash"), "rotation", func(x: float) -> float: return deg_to_rad(4.0) * back_sign + deg_to_rad(6.0) * sin(x - 1.3))
	else:
		_track(a, P.call("body"), "position", func(x: float) -> Vector2: return Vector2(0, -2.0 * (0.5 + 0.5 * sin(x))))
		_track(a, P.call("torso"), "scale", func(x: float) -> Vector2: return Vector2(1.0 + 0.008 * sin(x), 1.0 + 0.018 * sin(x)))
		_track(a, P.call("head"), "rotation", func(x: float) -> float: return deg_to_rad(1.8) * sin(x * 0.5 + 0.4) * (1.0 if not side else 0.6))
		_track(a, P.call("arm_l"), "rotation", func(x: float) -> float: return deg_to_rad(1.5) * sin(x - 0.4))
		_track(a, P.call("arm_r"), "rotation", func(x: float) -> float: return deg_to_rad(-1.5) * sin(x - 0.4))
		_track(a, P.call("drape"), "rotation", func(x: float) -> float: return deg_to_rad(1.6) * sin(x - 1.1) + deg_to_rad(0.6) * sin(2.0 * x))
		_track(a, P.call("braid"), "rotation", func(x: float) -> float: return deg_to_rad(1.8) * sin(x - 0.9))
		_track(a, P.call("sash"), "rotation", func(x: float) -> float: return deg_to_rad(1.4) * sin(x - 1.3))
	return a


func _path(b: Dictionary, n: String) -> String:
	var node: Node = b[n]
	var parts: Array[String] = []
	while node != null and not VIEWS.has(String(node.name)):
		parts.push_front(String(node.name))
		node = node.get_parent()
	return "/".join(parts)


func set_view(v: String, mirror: bool) -> void:
	if v == view and mirror == mirrored and _shown:
		return
	_shown = true
	for k: String in VIEWS:
		(views[k] as Node2D).visible = k == v
	(views[v] as Node2D).scale.x = -1.0 if mirror else 1.0
	var pos := player.current_animation_position if player.is_playing() else 0.0
	view = v
	mirrored = mirror
	player.play(view + "_" + state)
	player.seek(pos, true)        # 보기를 바꿔도 걸음 박자는 이어짐


func play_state(s: String) -> void:
	state = s
	player.play(view + "_" + state, 0.15)


## 시험·캡처용: 박자를 직접 정함 (0~1)
func pose_at(u: float) -> void:
	var a := player.get_animation(view + "_" + state)
	player.play(view + "_" + state)
	player.seek(u * a.length, true)
	player.pause()
