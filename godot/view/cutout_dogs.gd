## 강아지 = 2D 종이 인형 (E3-13 · E3-13b, 2026-11-08 사용자: "강아지들도 완전 이상하고" · "걷질 않아") — 주민 종이 인형과 같은 그림책.
## 화면만 바꾼다 (ADR-0001): sim/dogs.gd의 강아지 사전은 읽기만 한다.
## FaunaView.sync가 부른다 (훅 세 줄) — 켜져 있으면 FaunaView의 3D 강아지 노드·멀리 MultiMesh 대신 이 노드가 그린다.
## 스위치 = 주민 인형과 같음 (CutoutResident.enabled → GameSettings.cutout_residents · 시험의 override).
## 한 마리 = MeshInstance3D 하나 = 그리기 1번 (메시·재질은 모두 같이 씀, proto/cutout_dog) + 발밑 그림자는 모두 MultiMesh 하나.
## 걷기/서기는 sim의 moving만이 아니라 '그린 자리가 이번 화면에 실제로 간 거리'로 정한다 (멈춘 채 걷거나 걷지 않고 미끄러지지 않게),
## 걷기 빠르기 = 실제 땅 빠르기 ÷ 한 주기 보폭 → 발이 미끄러지지 않음.
class_name CutoutDogs
extends Node3D

const Lib := preload("res://proto/cutout_dog/dog_lib.gd")

const DOG_H := 0.46              # 다 자란 강아지(보통 몸집)의 화면 키 (귀 끝~발, 세계) — 등이 주민(0.88)의 무릎과 허리 사이 (E3-13)
const PUP_SCALE := 0.6           # FaunaView.PUP_SCALE과 같음
const HIDE_R := 110.0            # FaunaView.HIDE_R과 같음
const WALK_ON := 0.12            # 그린 자리 빠르기 (세계/초) — 이 위로 오르면 걷기
const WALK_OFF := 0.05           # 이 아래로 내려가면 멈춤 (둘 사이는 지금 것 유지 — 깜빡임 없음)
const SPEED_K := 8.0             # 빠르기 고르기 (1/초)
const RATE_MIN := 0.4
const RATE_MAX := 6.0            # 달리기(Dogs.RUN)에선 이보다 빨라야 하지만 너무 잦은 걸음은 떨림 — 조금 미끄러짐을 받아들임
const RATE_STEP := 0.05
const SHADOW := Vector2(0.4, 0.22)    # DOG_H 강아지의 발밑 타원 (세계)

static var override := -1       # -1 = 주민 인형 스위치를 따름 · 0 = 늘 3D · 1 = 늘 종이 인형

var dogs := {}                   # 강아지 id → 상태 사전 (아래 _entry)
var react := {}                  # [톡 반응] 강아지 id → {off, sq, roll, turn, hint} (view/tap_react.gd — 화면만, 반응이 끝나면 지워짐)
var shown := 0
var _shadows: MultiMeshInstance3D


static func enabled() -> bool:
	if override >= 0:
		return override == 1
	return CutoutResident.enabled()


## FaunaView 훅: 이 노드를 (없으면) 만들고, FaunaView의 3D 강아지를 놓은 뒤 그린다
static func sync_into(fv: FaunaView, dt: float, c: Vector2, vr: float, fast: bool) -> void:
	var n := fv.get_node_or_null("CutoutDogs") as CutoutDogs
	if n == null:
		n = CutoutDogs.new()
		n.name = "CutoutDogs"
		fv.add_child(n)
	for id: int in fv._dogs.keys():
		(fv._dogs[id]["node"] as Node3D).queue_free()
	fv._dogs.clear()
	fv._far_dogs.clear()
	n.sync(fv, dt, c, vr, fast)
	fv.shown_dogs = n.shown
	fv.shown_dogs_far = 0


## 스위치가 꺼지면 (3D로 돌아감) 인형을 치움
static func release(fv: FaunaView) -> void:
	var n := fv.get_node_or_null("CutoutDogs")
	if n != null:
		fv.remove_child(n)
		n.queue_free()


func _init() -> void:
	var q := QuadMesh.new()
	q.size = SHADOW
	q.orientation = PlaneMesh.FACE_Y
	q.material = CutoutShadows.material()
	_shadows = MultiMeshInstance3D.new()
	_shadows.multimesh = MultiMesh.new()
	_shadows.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_shadows.multimesh.mesh = q
	_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadows.extra_cull_margin = 16384.0
	add_child(_shadows)


# ───────────────────────── 겉모습 (털 유전자 → 셰이더 값) ─────────────────────────
## 강아지 사전 → instance uniform 값 {sel, coat, light_c, pat_c, size}. 같은 강아지·같은 계절이면 늘 같다. 능력 값은 읽지 않음.
static func doll_params(dg: Dictionary, winter := false) -> Dictionary:
	var lk := Lib.look_of(dg)
	var cc: Dictionary = Lib.COATS[int(lk["base"])]
	var pat := int(lk["pat"])
	var pc := Color(String(cc["patch"]))
	if pat == 2:
		pc = Color(String(cc["mask"]))
	elif pat == 3:
		pc = Color(String(cc["freck"]))
	var co := Color(String(cc["coat"]))
	var li := Color(String(cc["light"]))
	var kk := bool(lk["kk"])
	return {
		"sel": Vector4(int(lk["ear"]), int(lk["tail"]), 1.0 if kk and winter else 0.0, 0.0),
		"coat": Vector4(co.r, co.g, co.b, pat),
		"light_c": Vector4(li.r, li.g, li.b, float(lk["seed"])),
		"pat_c": Vector4(pc.r, pc.g, pc.b, 1.0 if kk else 0.0),
		"size": float(lk["size"]),
		"look": lk,
	}


## sim 상태 + 실제로 움직이는지 → 클립. idle/sit은 멈춘 시간으로 번갈아 (FaunaView 3D와 같은 박자), 놀이 중 멈추면 놀자 절
static func clip_for(state: String, walking: bool, still_t: float, id: int) -> String:
	if walking:
		return "walk"
	match state:
		"sleep":
			return "lie"
		"bark":
			return "bark"
		"play":
			return "bow" if fmod(still_t + id * 3.0, 6.0) < 3.0 else "idle"
	return "sit" if fmod(still_t + id * 7.0, 24.0) > 14.0 else "idle"


## 걷기 주기/초 = 땅 빠르기 ÷ (한 주기 보폭 × 화면 키 / fig)
static func walk_rate(speed: float, h: float) -> float:
	var stride := Lib.stride_rig() * h / float(Lib.lib()["fig"])
	return snappedf(clampf(speed / maxf(stride, 0.001), RATE_MIN, RATE_MAX), RATE_STEP)


## 카메라 기준 보기: 0 앞(다가옴) 1 비스듬히 앞 2 비스듬히 뒤 3 뒤, 뒤집기 = 왼쪽으로 갈 때 −1 (주민 인형과 같은 규칙)
static func view_of(cam_basis: Basis, dir: Vector3, prev_mirror := 1.0) -> Vector2:
	var right := Vector3(cam_basis.x.x, 0, cam_basis.x.z).normalized()
	var toward := Vector3(cam_basis.z.x, 0, cam_basis.z.z).normalized()
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() < 0.001:
		return Vector2(-1, prev_mirror)
	d = d.normalized()
	var deg := rad_to_deg(atan2(d.dot(right), d.dot(toward)))
	var a := absf(deg)
	var v := 0 if a < 30.0 else (1 if a < 110.0 else (2 if a < 150.0 else 3))
	var m := 1.0 if deg >= 0.0 else -1.0
	if v == 0 or v == 3:
		m = prev_mirror
	return Vector2(v, m)


# ───────────────────────── 매 화면 ─────────────────────────
func sync(fv: FaunaView, dt: float, c: Vector2, vr: float, _fast: bool) -> void:
	var d := fv.v.dogs
	var seen := {}
	shown = 0
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var winter := FloraLook.season_of(fv.v) == "겨울"
	var hide := d == null or vr <= 0.0 or vr > HIDE_R
	var shadow_xf: Array = []
	var pals: DogPals = fv.vv.dog_pals if fv.vv != null else null      # [강아지와 사람] 그릴 자리·몸짓만 얹음 (view/dog_pals.gd — 화면만)
	if not hide:
		for dg: Dictionary in d.list:
			var id := int(dg["id"])
			var x := float(dg["x"])
			var z := float(dg["y"])
			var px := float(dg.get("px", x))
			var pz := float(dg.get("py", z))
			if fv.alpha < 1.0 and absf(x - px) + absf(z - pz) < 6.0:
				x = lerpf(px, x, fv.alpha)
				z = lerpf(pz, z, fv.alpha)
			if Vector2(x, z).distance_to(c) > vr + 4.0:
				continue
			seen[id] = true
			var e: Dictionary = dogs.get(id, {})
			var pal: Dictionary = pals.place(dg, Vector2(x, z), dt) if pals != null else {}
			if not pal.is_empty():
				x = (pal["pos"] as Vector2).x
				z = (pal["pos"] as Vector2).y
			var pos := Vector3(x, fv._gy(x, z), z)
			if e.is_empty():
				e = _entry(id, pos)
				dogs[id] = e
			e["pal"] = pal
			var grow := clampf(d.age_days(fv.v, dg) / Dogs.PUP_DAYS, 0.0, 1.0)
			_update(e, dg, pos, dt, grow, winter, cam)
			shown += 1
			var s := float(e["h"]) / DOG_H
			var ro: Vector3 = (react[id] as Dictionary)["off"] if react.has(id) else Vector3.ZERO
			s *= CutoutShadows.hop_shrink(ro.y + float(pal.get("hop", 0.0)))       # [톡 반응] 폴짝 뛰면 그림자가 작아짐
			shadow_xf.append(Transform3D(Basis().scaled(Vector3.ONE * s), pos + Vector3(ro.x, CutoutShadows.LIFT, ro.z)))
	for id: int in dogs.keys():
		if not seen.has(id):
			(dogs[id]["doll"] as Node).queue_free()
			dogs.erase(id)
			react.erase(id)
	_sync_shadows(shadow_xf, cam)


func _entry(id: int, pos: Vector3) -> Dictionary:
	var m := MeshInstance3D.new()
	m.mesh = Lib.mesh()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.extra_cull_margin = 0.5
	add_child(m)
	m.position = pos
	return {"id": id, "doll": m, "last": pos, "speed": 0.0, "walking": false, "still_t": 0.0, "clip": "", "rate": -1.0,
		"phase": float(posmod(hash([id, "ph"]), 997)) / 997.0, "view": 1, "mirror": 1.0, "dir": Vector3(0, 0, 1),
		"key": "", "h": DOG_H}


func _update(e: Dictionary, dg: Dictionary, pos: Vector3, dt: float, grow: float, winter: bool, cam: Camera3D) -> void:
	var m: MeshInstance3D = e["doll"]
	# 겉모습 (계절·자람이 바뀔 때만 다시 보냄)
	var key := "%s|%s|%d|%d" % [winter, dg.get("special", ""), hash(dg.get("genes", {})), int(grow * 20.0)]
	if key != e["key"]:
		e["key"] = key
		var p := doll_params(dg, winter)
		for k: String in ["sel", "coat", "light_c", "pat_c"]:
			m.set_instance_shader_parameter(k, p[k])
		e["h"] = DOG_H * float(p["size"]) * lerpf(PUP_SCALE, 1.0, grow)
		e["rate"] = -1.0
	# 실제로 간 거리 (그린 자리) → 빠르기 · 걷기 여부 · 가는 쪽
	var mv: Vector3 = pos - (e["last"] as Vector3)
	mv.y = 0.0
	if dt > 0.0:
		var inst := mv.length() / dt if mv.length() < 2.0 else 0.0      # 순간이동(집 안팎)은 걸음이 아님
		e["speed"] = lerpf(float(e["speed"]), inst, 1.0 - exp(-dt * SPEED_K))
		var sp := float(e["speed"])
		if bool(e["walking"]):
			e["walking"] = sp > WALK_OFF
		else:
			e["walking"] = sp > WALK_ON
		if mv.length() > 0.002:
			e["dir"] = mv.normalized()
		e["still_t"] = 0.0 if bool(e["walking"]) else float(e["still_t"]) + dt
	var pal: Dictionary = e.get("pal", {})
	if not bool(e["walking"]):
		var f := float(dg.get("face", 0.0))
		e["dir"] = Vector3(sin(f), 0, cos(f))
		var lk: Vector2 = pal.get("look", Vector2.INF)        # [강아지와 사람] 멈추면 주인·아이·돌탑 쪽을 봄
		if lk != Vector2.INF and Vector2(lk.x - pos.x, lk.y - pos.z).length() > 0.08:
			e["dir"] = Vector3(lk.x - pos.x, 0, lk.y - pos.z).normalized()
	e["last"] = pos
	var rx: Dictionary = react.get(int(e["id"]), {})
	m.position = pos + Vector3(0, float(pal.get("hop", 0.0)), 0) + ((rx["off"] as Vector3) if not rx.is_empty() else Vector3.ZERO)
	var clip := react_clip(pal_clip(clip_for(String(dg.get("state", "idle")), bool(e["walking"]), float(e["still_t"]), int(e["id"])), String(pal.get("hint", ""))),
		String(rx.get("hint", "")))
	var h := float(e["h"])
	var rate: float = Lib.CLIP_RATE[clip]
	if clip == "walk":
		rate = walk_rate(float(e["speed"]), h)
	var push := false
	if clip != e["clip"] or not is_equal_approx(rate, float(e["rate"])):
		var now := _shader_time()
		if clip == e["clip"] and float(e["rate"]) > 0.0:
			e["phase"] = fposmod(float(e["phase"]) + now * (float(e["rate"]) - rate), 1.0)    # 빠르기만 바뀜: 이어서
		elif clip != e["clip"]:
			e["phase"] = fposmod(float(posmod(hash([e["id"], clip]), 997)) / 997.0 - now * rate, 1.0)
		e["clip"] = clip
		e["rate"] = rate
		_push_misc(e)
		push = true
	if cam != null:
		var vm := view_of(cam.global_transform.basis, e["dir"], float(e["mirror"]))
		if vm.x >= 0.0 and (int(vm.x) != int(e["view"]) or vm.y != float(e["mirror"])):
			e["view"] = int(vm.x)
			e["mirror"] = vm.y
			push = true
	var wag := float(pal.get("roll", 0.0))
	if push:
		m.set_instance_shader_parameter("st", Vector4(int(e["view"]), float(e["mirror"]), Lib.CLIPS.find(clip), float(e["phase"])))
	if (push and not rx.is_empty()) or not is_equal_approx(wag, float(e.get("wag", 0.0))):
		e["wag"] = wag
		_push_misc(e)


# ───────────────────────── 톡 반응 (view/tap_react.gd) ─────────────────────────
## 인형 전체에 얹는 화면만의 움직임 (주민 인형의 set_react와 같은 뜻): off = 옮김(y 폴짝·xz 제자리 붙들기), squash = (가로, 세로) 배율,
## roll = 바라보는 쪽으로 숙이기(rad), turn = 세로 축으로 도는 바퀴 수, hint = "" · still · bark. 반응이 끝나면 clear_react.
func set_react(id: int, off: Vector3, squash: Vector2, roll: float, turn: float, hint: String) -> void:
	if not dogs.has(id):
		return
	react[id] = {"off": off, "sq": squash, "roll": roll, "turn": turn, "hint": hint}
	var e: Dictionary = dogs[id]
	(e["doll"] as MeshInstance3D).position = (e["last"] as Vector3) + off + Vector3(0, float((e.get("pal", {}) as Dictionary).get("hop", 0.0)), 0)
	_push_misc(e)


func clear_react(id: int) -> void:
	if not react.has(id):
		return
	react.erase(id)
	if dogs.has(id):
		var e: Dictionary = dogs[id]
		(e["doll"] as MeshInstance3D).position = e["last"]
		_push_misc(e)


## [강아지와 사람] 멈춰 있을 때의 동작 부탁 (sit · bow · idle) — 걷는 중·자는 중엔 그대로
static func pal_clip(clip: String, hint: String) -> String:
	if hint == "" or clip == "walk" or clip == "lie" or clip == "bark":
		return clip
	return hint


## 반응하는 동안의 동작: 자는 강아지는 그대로 눕고, 걷던 발은 멈춤 · bark = 짖는 동작
static func react_clip(clip: String, hint: String) -> String:
	if hint == "" or clip == "lie":
		return clip
	if hint == "bark":
		return "bark"
	return "idle" if clip == "walk" else clip


func _push_misc(e: Dictionary) -> void:
	var rx: Dictionary = react.get(int(e["id"]), {})
	var sq: Vector2 = rx.get("sq", Vector2.ONE)
	var c := cos(float(rx.get("turn", 0.0)) * TAU)
	if absf(c) < 0.16:                              # 돌 때 선으로 사라지지 않게 (주민 인형과 같게)
		c = 0.16 if c >= 0.0 else -0.16
	var w := sq.x * c
	var sy := maxf(sq.y, 0.05)
	var face := float(e["mirror"]) * (-1.0 if w < 0.0 else 1.0)       # 화면에서 바라보는 쪽 (오른쪽 +1)
	(e["doll"] as MeshInstance3D).set_instance_shader_parameter("misc",
		Vector4(float(e["h"]) * sy, w / sy, maxf(float(e["rate"]), 0.0), -float(rx.get("roll", 0.0)) * face + float(e.get("wag", 0.0))))


func _sync_shadows(list: Array, cam: Camera3D) -> void:
	var mm := _shadows.multimesh
	if mm.instance_count != list.size():
		mm.instance_count = list.size()
	var b := Basis()
	if cam != null:
		var r := global_transform.basis.inverse() * cam.global_transform.basis.x       # 긴 축 = 화면 가로
		b = Basis(Vector3.UP, atan2(-r.z, r.x))
	for i in list.size():
		var t: Transform3D = list[i]
		mm.set_instance_transform(i, Transform3D(b * t.basis, t.origin))


## 셰이더 TIME과 같은 시계 (CutoutResident._shader_time과 같음)
static func _shader_time() -> float:
	var ro := float(ProjectSettings.get_setting("rendering/limits/time/time_rollover_secs", 3600.0))
	return fposmod(Time.get_ticks_usec() / 1.0e6, ro)
