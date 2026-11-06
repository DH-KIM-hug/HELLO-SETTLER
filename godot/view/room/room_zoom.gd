## 병 밖 시점 = 거인의 방 실시간 (ROADMAP B1 · GIANT_ROOM 4·5 · RENDERING 2.2 · AUDIO 1). 넓은 세상 장면(view/world_village.gd)에 붙는다.
## 같은 3D 장면 안에 거인의 방(GiantRoom)을 세상에 맞는 크기로 세워 두고 (병 안쪽 반지름 5.6cm = 세상 반지름), 카메라(JarCamera)가
## 한 줄의 로그 확대로 ① 마을 → ② 넓은 땅 → ③ 세상 전체(유리벽·폭포 띠, 유리 너머 흐릿한 방) → ④ 유리병 → ⑤ 거인의 방까지 끊김 없이 간다.
## 단계마다 (휴대폰 성능 — GD 18):
##   ①② 방을 그리지 않음 (visible 끔) · 화면 가장자리 유리 호 (outline_post use_glass)
##   ③   방을 그림 (병 안에서 유리 너머 — 유리 haze로 흐릿하게) · 방 그림자 끔
##   ④⑤ 마을 화면(주민·건물 VillageView)을 멈추고 감춤 — 시뮬레이션은 그대로. 병 안 세상은 한 덩어리 메시(WorldTerrain whole — 높이 + 색 지도)
##       · 세상 해 그림자 끔, 방 창빛 그림자 켬 · 유리 굴절(화면 셰이더 refract) · 방 음악이 앞 (GameAudio.room_view)
##   카메라가 유리를 지나는 순간: 반사광이 화면을 쓸고(sweep) 유리 소리, 마을 소리가 먹먹해짐 (outside 0 ↔ 1, 0.6초)
## 병 안 밤(시계) = 등불 꺼짐 · 병 안 화소만 밤 색 (화면 셰이더 room_mask가 병 원기둥 안/밖을 가름) · 창밖 = 현실 시각 (StartFlow.now_time_of_day)
class_name RoomZoom
extends Node

const SWEEP_TIME := 0.65
const MUFFLE_TIME := 0.6
const REFRACT := 0.07

var scene: Node                       # 넓은 세상 장면 (world_village)
var cam: JarCamera
var room: GiantRoom
var post: ShaderMaterial
var sun: DirectionalLight3D
var s := 1.0                          # 1cm = 세계 s칸
var y0 := 0.0                         # 선반 윗면 (세계 y)
var stage := 1
var was_inside := true
var sweep_t := -1.0
var outside := 0.0                    # 병 밖 소리 정도 (0 안 ~ 1 밖)
var views_live := true
var _sun_mask := 0
var _tod_t := 0.0
var _glass_off := false
## 방 창빛 그림자 (④⑤). 끔: 세상 크기(s≈91)로 키운 방에서는 그림자 맵이 벽 아래쪽을 통째로 그늘로 칠하는 문제가 있어서
## (타이틀 s = 1은 괜찮음 — tools/debug_room_scale.gd로 재현). 휴대폰 성능에도 이득 (그림자 맵 한 장 덜 그림)
var room_shadows := false
var stats := {"crossings": 0}


func setup(sc: Node, rr: float, ground_fn: Callable, light_dir: Vector2) -> void:
	scene = sc
	cam = sc.get("cam")
	post = sc.get("post_mat")
	sun = sc.get("sun")
	s = rr / GiantRoom.JAR_IN
	# 흙 원판 윗면 = 땅의 가장 낮은 곳 바로 아래 (땅이 흙 위에 얹힘)
	var lo := INF
	for j in 33:
		for i in 33:
			var x := (i / 32.0 * 2.0 - 1.0) * rr * 0.98
			var z := (j / 32.0 * 2.0 - 1.0) * rr * 0.98
			if x * x + z * z <= rr * rr * 0.96:
				lo = minf(lo, float(ground_fn.call(x, z)))
	if lo == INF:
		lo = 0.0
	y0 = lo - 0.4 - GiantRoom.SOIL_TOP * s
	room = GiantRoom.new()
	room.name = "GiantRoom"
	room.position = Vector3(0.0, y0, 0.0)
	sc.add_child(room)
	room.setup(s, StartFlow.now_time_of_day(), true)
	room.set_lamp(true, light_dir)
	room.visible = false
	_sun_mask = sun.light_cull_mask
	sun.light_cull_mask = _sun_mask & ~GiantRoom.LAYER_BIT          # 병 안 해(등불)는 방을 비추지 않는다
	# 세상 전체가 화면 폭에 들어오는 데까지가 ③ (그 너머는 beyond)
	cam.ppu_min = 360.0 / (2.0 * rr * 1.15)
	cam.set_room(s, y0)
	post.set_shader_parameter("room_gap", Style.OUTLINE_GAP * s)
	var v := room.jar_volume()
	post.set_shader_parameter("jar_center", v["center"])
	post.set_shader_parameter("jar_radius", v["radius"])
	post.set_shader_parameter("jar_bottom", v["bottom"])
	post.set_shader_parameter("jar_top", v["top"])
	update(0.0)


## 등불 자리 (등불 옮기기 — 병 안 해가 오는 쪽)
func set_light_dir(l: Vector2) -> void:
	if room != null:
		room.set_lamp(room.lamp_lit, l)


func update(dt: float) -> void:
	if room == null:
		return
	stage = cam.stage()
	var inside := cam.inside_glass()
	# 방: ③부터 (①②는 그리지 않음)
	room.visible = stage >= 3
	room.light.visible = stage >= 3
	room.light.shadow_enabled = stage >= 4 and room_shadows
	room.set_haze(1.0 if inside else 0.0)
	# 마을 화면: ④⑤는 멈춤 (시뮬레이션은 계속)
	var live := stage <= 3
	if live != views_live:
		views_live = live
		scene.call("set_views_live", live)
	sun.shadow_enabled = stage <= 3
	# 등불 = 병 안 낮 (밤이면 꺼짐)
	var night := float(scene.get("night"))
	var lit := night < 0.5
	if lit != room.lamp_lit:
		room.set_lamp(lit, Vector2.ZERO)
	# 창밖 시각은 가끔만 다시 봄
	_tod_t += dt
	if _tod_t > 30.0:
		_tod_t = 0.0
		var tod := StartFlow.now_time_of_day()
		if tod != room.tod:
			room.set_tod(tod)
	# 화면 셰이더
	post.set_shader_parameter("room_mask", stage >= 3)
	post.set_shader_parameter("room_mul", room.room_mul())
	post.set_shader_parameter("room_outline", stage >= 4)
	if (stage >= 3) != _glass_off:                 # 화면 가장자리 유리 호는 병 안(①②)에서만
		_glass_off = stage >= 3
		post.set_shader_parameter("use_glass", not _glass_off)
	var refr := 0.0
	if not inside:
		refr = REFRACT * smoothstep(cam.b_glass, cam.b_glass + 0.12, cam.beyond)
		var c := room.cm(Vector3(0, 7.0, 0))
		var e := room.cm(Vector3(GiantRoom.JAR_OUT, 7.0, 0))
		var vs := scene.get_viewport().get_visible_rect().size
		var cp := cam.camera.unproject_position(c)
		var hw := absf(cam.camera.unproject_position(e).x - cp.x)
		post.set_shader_parameter("jar_screen", Vector2(cp.x / vs.x, maxf(hw, 1.0) / vs.x))
	post.set_shader_parameter("refract", refr)
	# 유리를 지나는 순간: 반사광 + 유리 소리 + 소리 바뀜
	if inside != was_inside:
		was_inside = inside
		sweep_t = 0.0
		stats["crossings"] = int(stats["crossings"]) + 1
		GameAudio.fx("glass_tap_light", "Room", -12.0)
	if sweep_t >= 0.0:
		sweep_t += dt
		var u := sweep_t / SWEEP_TIME
		post.set_shader_parameter("sweep", u if inside else 1.0 - u)     # 들어갈 땐 왼쪽→오른쪽, 나올 땐 반대로
		if u >= 1.0:
			sweep_t = -1.0
			post.set_shader_parameter("sweep", -1.0)
	outside = move_toward(outside, 0.0 if inside else 1.0, dt / MUFFLE_TIME)
	var a := GameAudio.get_instance()
	if a != null:
		a.room_view = stage >= 4


## 마을 소리 먹먹함 (AUDIO 1): 병 안에서는 멀리 축소할수록 조금 (거리), 유리를 지나면 완전히
func outside_amount() -> float:
	return maxf(outside, GameAudio.outside_from_ppu(cam.ppu) * 0.5)
