class_name OutingView
extends Node3D
## 유모차 산책 · 아이의 첫 심부름 · 아이의 첫 낚시 — 화면 (ROADMAP E2-2 · E2-3, 기획서 7.3).
## 시뮬(sim/child_outings.gd)이 적어 둔 기록만 읽어 그린다. 시뮬에는 아무것도 쓰지 않는다 (ADR-0001 — 지켜보든 말든 결과가 같다).
##   · 유모차: 미는 부모 인형 앞에 나무 바구니 수레 (그림 두 장 사이에 누운 아기 + 굴러가는 단추 바퀴), 만난 이웃이 멈춰 숙여 들여다봄,
##     걸음마를 뗀 뒤에는 문 옆에 세워 둠
##   · 첫 심부름 · 첫 낚시: 아이(와 곁의 어른) 인형을 기록의 '인형 자리'에 세우고 보퉁이 · 풀줄기 낚싯대 · 찌 · 작은 물고기를 그림
## KidsView가 만들고 부른다 (begin → 주민마다 pose → 아기를 놓은 뒤 after). 종이 인형일 때만 (옛 3D 주민은 제 유모차 소품 그대로).
## 그림: art/kids2d/kids_outing.png (tools/kids/make_outing.py — 요람과 같은 밀도·선·바구니 결)

const ATLAS := Vector2i(512, 512)
const PICS := {"p1_back": Rect2i(0, 0, 192, 144), "p1_front": Rect2i(192, 0, 192, 144), "p2_back": Rect2i(0, 144, 192, 144), "p2_front": Rect2i(192, 144, 192, 144),
	"p0_back": Rect2i(0, 288, 128, 144), "p0_front": Rect2i(128, 288, 128, 144), "p3_back": Rect2i(256, 288, 128, 144), "p3_front": Rect2i(384, 288, 128, 144),
	"wheel": Rect2i(384, 0, 52, 52), "hand": Rect2i(440, 0, 36, 36), "bundle": Rect2i(384, 56, 64, 64), "bowl": Rect2i(448, 56, 64, 56),
	"rod": Rect2i(384, 124, 128, 80), "string": Rect2i(384, 212, 16, 44), "float": Rect2i(384, 264, 16, 20), "fish": Rect2i(404, 208, 48, 60)}
const ATLAS_PATH := "res://art/kids2d/kids_outing.png"
const PX := 293.3                 # 그림 밀도 (px/칸 — 요람과 같음)
const GROUND_PX := 10.0           # 유모차 그림 밑에서 땅 금까지
const RIM_PX := 68.0              # 땅 금에서 바구니 테두리 가운데까지
const WHEEL_R_PX := 19.0
## 옆모습의 가까운 바퀴 둘 (그림 가운데에서 가로 px, 그림 밑에서 세로 px) — make_outing.py가 찍어 준 값
const WHEELS := {1: [Vector2(-42.5, 25.2), Vector2(37.2, 32.2)], 2: [Vector2(-45.1, 32.9), Vector2(34.6, 25.9)]}
const PRAM_K := 1.1               # 유모차 크기 (손잡이가 부모 손 높이에 오게)
const PRAM_DX := 0.43             # 옆모습: 부모 → 유모차 가운데 (화면 가로)
const PRAM_DY := 0.03             # 옆모습: 화면 세로로 조금 (앞옆 = 아래 · 뒤옆 = 위)
const PRAM_FRONT := 0.2           # 앞모습: 부모보다 카메라 쪽으로 (땅 위 칸)
const PRAM_BACK := 0.08           # 뒷모습: 부모보다 뒤로
const FACE_CAM := 0.22             # 마주 볼 때 바라보는 곳을 이만큼 카메라 쪽으로 (옆모습이 뒤통수로 넘어가지 않게)
const GIVE_GAP := 0.42             # 첫 심부름: 건넬 때 아이와 어른 사이 (화면 가로 칸)
const HAND_STEP := 0.6             # (Q21 ㊶) 건네는 자리: 시뮬의 문 앞에서 카메라 쪽으로 이만큼 (칸 — 집 그림에 가리면 더 앞으로)
const PARK_SIDE := 0.36            # 세워 둔 유모차: 집 그림 가운데에서 그림 폭의 이만큼 옆 (화면)
const PARK_OUT := 0.18             # 집 그림 밑변에서 (KidsView.FS_CLEAR에 더해) 이만큼 앞
const BABY_K := Vector2(0.92, 0.8)     # 유모차 속 아기 크기 (옆모습, 앞·뒷모습)
const MEET_R := 2.6               # 이웃이 이만큼 안에 있어야 다가와 들여다봄 (칸)
const MEET_WALK := 2.4            # 다가오는 데 이보다 오래 걸리면 그 자리에서 숙임 (현실 초)
const MEET_LOOK := 2.5            # 숙여 들여다보는 동안
const MEET_GAP := 0.47            # 유모차 가운데 → 이웃 (화면 가로)
const SIT_GAP := 0.5               # 첫 낚시: 곁의 어른이 앉는 자리 (아이에서 화면 가로 칸 — 서로 가리지 않게)
const CASTS := [1.3, 1.1, 0.95]    # 찌를 던지는 거리 후보 (칸 — 물이면 멀리, 아니면 ChildOutings.FLOAT_D)
const BUNDLE_W := 0.19            # 보퉁이 너비 (칸)
const BOWL_W := 0.2
const ROD_LEN := 122.6            # 풀줄기 낚싯대: 손 → 끝 (px)
const ROD_A0 := 0.4929            # 그 기울기 (라디안)
const ROD_HAND := Vector2(-54.0, -30.0)     # 그림 가운데에서 손잡이까지 (px, 위 +)
const FOLLOW := 14.0              # 시뮬 인형 자리를 따라가는 빠르기 (1/초 — 30Hz 걸음을 매끄럽게)

var v: Village
var vw: VillageView
var kv: KidsView
var _mat: ShaderMaterial
var _quad: QuadMesh
var _cards := {}                  # 이름 → [판, 그림 이름, 마지막으로 쓴 화면 번호]
var _cursor := 0
var _frame := 0
var _clock := 0.0
var _was_fast := false
var _dir := {}                    # 주민 id → 이번 화면의 지시 (pos · sp · anim · face · arms · hop · skip · sy · sx · lean · back)
var _pup := {}                    # 주민 id → Pup (화면 자리를 따로 가진 인형)
var _armed := {}                  # 두 손을 내민 인형 (arms_out을 켠 주민)
var _meet: Meet
var _once := {}                   # 한 번만 하는 것 (말·소리·빛) — 그 나들이가 끝나면 비움
var _p_has := false
var _p_off := Vector2.ZERO        # 부모 → 유모차 (땅 위, 매끄럽게)
var _p_at := Vector2.ZERO         # 유모차 자리
var _p_roll := 0.0
var _p_run := 0.0                 # 굴러간 길 (달그락 흔들림)
var _p_gig := -1.0                # 아기가 까르르 (−1 = 없음)
var _p_side := 1.0                # 아기가 손을 내미는 쪽 (화면 오른쪽 +)
var _e_goal := Vector2.INF        # 첫 심부름: 이웃집 문 앞 (시뮬) — 바뀌면 건네는 자리를 다시 셈
var _e_want := Vector2.ZERO       # 문 앞 → 건네는 자리 (카메라 쪽으로 한 걸음, 집 그림에 가리면 더)
var _e_dwant := Vector2.ZERO      # 시뮬의 문 앞 → 그 앞 한 걸음 (찾아가는 길에 문 앞을 지날 때)
var _e_r2 := Vector2.ZERO         # 그 셈을 한 때의 화면 오른쪽 (카메라가 돌면 다시 셈)
var _e_side := -1.0               # 아이가 받을 사람의 화면 어느 쪽에 서나 (제 집 쪽)
var _e_drop := Vector3.INF        # (㊷) 아기를 안은 어른 발치에 내려놓은 보퉁이 (땅 위 자리)
var _own_say := {}                # (Q21 ㊵) 나들이가 띄운 말: 주민 id → 글 (그 사람에게는 이 말만 보임)
var _park := {}                   # 세워 둔 유모차: 집 id → [자리, 좌우]
var seen: Array = []              # (시험) 이번 화면에 그린 것 이름


class Pup extends RefCounted:
	var pos := Vector2.ZERO
	var yaw := 0.0
	var sp := 0.0
	var seen := 0
	var back := 1.4


class Meet extends RefCounted:
	var nb := -1                  # 들여다보는 이웃
	var cr := -1                  # 유모차를 미는 사람
	var hold := Vector2.ZERO      # 부모가 멈춰 선 자리
	var spot := Vector2.ZERO      # 이웃이 설 자리
	var side := 1.0               # 이웃이 유모차의 어느 쪽 (화면 오른쪽 +)
	var t := 0.0
	var at := -1.0                # 이웃이 닿은 때 (−1 = 아직 걸어오는 중)
	var t0 := 0.0                 # 그 산책이 시작된 때 (다른 산책이면 버림)


func _init(village: Village = null, view: VillageView = null, kids: KidsView = null) -> void:
	v = village
	vw = view
	kv = kids
	if v != null:
		_cursor = v.events.clear_to_end()


static func atlas() -> Texture2D:
	return load(ATLAS_PATH) as Texture2D


static func pic_w(pic: String, k := 1.0) -> float:
	return float((PICS[pic] as Rect2i).size.x) / PX * k


# ───────────────────────── 그림 판 ─────────────────────────
func _c(nm: String, pic: String) -> MeshInstance3D:
	var c: Array = _cards.get(nm, [])
	if c.is_empty():
		if _mat == null:
			_mat = ShaderMaterial.new()
			_mat.shader = load(KidsView.SHADER_PATH)
			_mat.set_shader_parameter("tex", atlas())
			_quad = QuadMesh.new()
			_quad.size = Vector2.ONE
		var n := MeshInstance3D.new()
		n.mesh = _quad
		n.material_override = _mat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.extra_cull_margin = 1.0
		add_child(n)
		c = [n, "", 0]
		_cards[nm] = c
	if String(c[1]) != pic:
		c[1] = pic
		var rc: Rect2i = PICS[pic]
		(c[0] as MeshInstance3D).set_instance_shader_parameter("rect",
			Vector4(float(rc.position.x) / ATLAS.x, float(rc.position.y) / ATLAS.y, float(rc.size.x) / ATLAS.x, float(rc.size.y) / ATLAS.y))
	c[2] = _frame
	return c[0]


## 밑이 at에 놓이는 판 (유모차) — lift = 화면 높이만큼 위로
func _put(nm: String, pic: String, at: Vector3, w: float, rot := 0.0, depth := 0.0, sx := 1.0, sy := 1.0, anchor := 0.0, lift := 0.0) -> void:
	var n := _c(nm, pic)
	var rc: Rect2i = PICS[pic]
	n.visible = true
	n.position = at
	n.set_instance_shader_parameter("geo", Vector4(w, w * float(rc.size.y) / float(rc.size.x), rot, depth))
	n.set_instance_shader_parameter("fx", Vector4(sx, sy, anchor, lift))
	seen.append(nm)


## 가운데가 '기준 자리 o + 화면 (가로, 세로) s'에 놓이는 판 — depth = 카메라 쪽으로 (화면 자리는 그대로)
func _spr(nm: String, pic: String, o: Vector3, s: Vector2, w: float, rot := 0.0, depth := 0.0, sx := 1.0, sy := 1.0) -> void:
	_put(nm, pic, o + kv._right * s.x, w, rot, depth, sx, sy, 1.0, s.y)


## 화면 두 점 a → b를 잇는 가는 판 (낚싯줄)
func _seg(nm: String, pic: String, o: Vector3, a: Vector2, b: Vector2, w: float, depth: float) -> void:
	var dv := b - a
	var ln := dv.length()
	if ln < 0.004:
		return
	var rc: Rect2i = PICS[pic]
	var nat := w * float(rc.size.y) / float(rc.size.x)
	_spr(nm, pic, o, (a + b) * 0.5, w, atan2(dv.y, dv.x) - PI * 0.5, depth, 1.0, ln / nat)


func _hide_all() -> void:
	for nm: String in _cards:
		((_cards[nm] as Array)[0] as MeshInstance3D).visible = false


func _cut(id: int) -> CutoutResident:
	var m := vw.residents.get(id) as CutoutResident
	if m == null or not is_instance_valid(m) or not m.visible or m.doll == null:
		return null
	return m


func _m2(m: Node3D) -> Vector2:
	return Vector2(m.position.x, m.position.z)


func _g3(p: Vector2) -> Vector3:
	return Vector3(p.x, kv._gy(p.x, p.y), p.y)


func _r2() -> Vector2:
	return Vector2(kv._right.x, kv._right.z)


func _b2() -> Vector2:
	return Vector2(kv._back.x, kv._back.z)


func _sn() -> float:
	return sqrt(maxf(1.0 - kv._cu * kv._cu, 0.01))


func _first(key: String) -> bool:
	if _once.has(key):
		return false
	_once[key] = true
	return true


# ───────────────────────── 매 화면: 앞 (주민을 놓기 전) ─────────────────────────
func begin(dt: float, fast: bool) -> void:
	if v == null or vw == null or kv == null:
		return
	_frame += 1
	_clock += dt
	_dir.clear()
	seen.clear()
	var evs: Array[Dictionary] = []
	if v.events.serial != _cursor:
		evs = v.events.since(_cursor)
		_cursor = v.events.serial
	var off := fast or not CutoutResident.enabled()
	if off:
		if not _was_fast:
			_was_fast = true
			_drop_all()
		return
	_was_fast = false
	for e: Dictionary in evs:
		if (e["kind"] as StringName) == &"stroller_met":
			_meet_start(int(e["who"]), int(e["v"]))
	_direct(dt)
	for id: int in _own_say.keys():            # 말풍선이 사라졌거나 나들이가 끝난 사람
		if not vw.stage_say.has(id) or not busy(id):
			_own_say.erase(id)
	for id: int in _armed.keys():              # 내민 팔: 지시가 끝나면 내림
		var d: Dictionary = _dir.get(id, {})
		if not bool(d.get("arms", false)):
			_arms(id, false)
	for id: int in _dir:
		if bool((_dir[id] as Dictionary).get("arms", false)) and not _armed.has(id):
			_arms(id, true)
	for id: int in _pup.keys():                # 보이지 않게 된 사람 (집 안·떠남)
		if (_pup[id] as Pup).seen < _frame - 3:
			_release(id)


func _arms(id: int, on: bool) -> void:
	var cm := vw.residents.get(id) as CutoutResident
	if cm != null and is_instance_valid(cm):
		cm.arms_out = on
	if on:
		_armed[id] = true
	else:
		_armed.erase(id)


func _release(id: int) -> void:
	var cm := vw.residents.get(id) as CutoutResident
	if cm != null and is_instance_valid(cm):
		cm.set_body_warp()
		if cm.doll != null:
			cm.set_body_lift(0.0)
	_pup.erase(id)


func _drop_all() -> void:
	for id: int in _pup.keys():
		_release(id)
	for id: int in _armed.keys():
		_arms(id, false)
	_meet = null
	_p_gig = -1.0
	_once.clear()
	_own_say.clear()
	_hide_all()


## 이번 화면에 누구를 어디에 어떤 몸짓으로 세울지 (시뮬 기록 → 지시)
func _direct(dt: float) -> void:
	var r2 := _r2()
	# ── 유모차를 미는 부모 (자리는 시뮬 그대로, 두 손만 앞으로) · 들여다보는 이웃
	var p := ChildOutings.pram(v)
	if p.is_empty():
		_meet = null
	else:
		var cr := int(p["cr"])
		var d := {"arms": true}
		if _meet != null and (_meet.cr != cr or _meet.t0 != float(p.get("t0", 0.0))):
			_meet = null
		if _meet != null:
			var mt := _meet
			mt.t += dt
			var nm := _cut(mt.nb)
			if nm == null or (mt.at < 0.0 and mt.t > MEET_WALK + 1.0) or (mt.at >= 0.0 and mt.t - mt.at > MEET_LOOK):
				_meet = null
			else:
				d["pos"] = mt.hold
				d["sp"] = 3.0
				d["anim"] = "idle"
				d["back"] = 1.15
				var nd := {"pos": mt.spot, "sp": 1.5, "face": _p_at + _b2() * FACE_CAM, "back": 1.4}
				if mt.at < 0.0 and (_m2(nm).distance_to(mt.spot) <= 0.08 or mt.t > MEET_WALK):
					mt.at = mt.t
					kv._say(mt.nb, "peek", "love", 2.0)
					_p_gig = 0.0
					_p_side = mt.side
				if mt.at >= 0.0:
					var u := mt.t - mt.at
					var k := smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(MEET_LOOK - 0.35, MEET_LOOK, u))
					nd["sy"] = 1.0 - 0.05 * k
					nd["lean"] = -mt.side * 0.2 * k * (0.85 + 0.15 * sin(_clock * 2.4))
				_dir[mt.nb] = nd
		_dir[cr] = d
	# ── 첫 심부름 (Q21 ㊶: 건네는 자리는 문 앞에서 카메라 쪽으로 한 걸음 — 집 그림에 가리면 더 앞으로. 아이도 받을 사람도 그 자리에서 다 보임)
	var e := ChildOutings.errand(v)
	if e.is_empty():
		_clear_once("e")
		_e_goal = Vector2.INF
		_e_want = Vector2.ZERO
	else:
		var kid := int(e["k"])
		var ph := int(e["ph"])
		var u := float(e["c"]) / ChildOutings.RS
		var picked := int(e.get("pk", 1 if ph >= 2 else 0)) == 1
		var door := Vector2(float(e["rx"]), float(e["ry"])) if picked else Vector2(float(e["tx"]), float(e["ty"]))     # 건네는 곳: 문 앞 (찾아간 사람이면 그 사람 자리)
		if door.distance_to(_e_goal) > 0.05 or _r2().distance_to(_e_r2) > 0.05:
			_e_goal = door
			_e_r2 = _r2()
			_e_want = hand_spot(door) - door
			var td := Vector2(float(e["tx"]), float(e["ty"]))
			_e_dwant = hand_spot(td) - td if td.distance_to(door) > 0.05 else _e_want
			var kh := v.person(kid)
			var hd := ChildOutings._door(v.bld(kh.home)) if kh != null and v.bld(kh.home) != null else door - r2
			if picked and int(e.get("sk", 0)) == 1:
				hd = Vector2(float(e["x"]), float(e["y"]))       # 찾아가는 길: 아이가 오는 쪽
			_e_side = signf((hd - door).dot(r2))      # 아이는 제 집 쪽에서 와서 그쪽으로 돌아감 → 받을 사람의 그쪽 옆에 섬
			if _e_side == 0.0:
				_e_side = -1.0
		var hand := door + _e_want
		var kp := Vector2(float(e["x"]), float(e["y"]))
		var near_k := 1.0 - smoothstep(0.5, 2.6, kp.distance_to(door))
		var td := Vector2(float(e["tx"]), float(e["ty"]))
		var near_d := (1.0 - smoothstep(0.5, 2.6, kp.distance_to(td))) * (1.0 - near_k)      # 찾아가는 길: 시뮬의 문 앞(집 그림 밑)도 한 걸음 앞으로
		kp += (_e_want + r2 * _e_side * GIVE_GAP) * near_k + _e_dwant * near_d      # 문 가까이에서는 건네는 자리 옆 쪽으로 (받을 사람과 겹치지 않게 — 오갈 때 모두)
		var rc := int(e["rc"])
		var hb := int(e.get("hb", 0)) == 1 or _holding(rc)
		if ph == 1:
			var stand := hand + r2 * _e_side * GIVE_GAP * (1.0 if picked else 1.6) + _b2() * 0.04
			kp = kp.lerp(stand, near_k)        # 찾아가는 길이면 시뮬의 걸음 그대로, 닿을수록 그 사람 옆으로
		elif ph == 2 or ph == 3:
			kp = hand + r2 * _e_side * GIVE_GAP + _b2() * 0.04       # 건넬 때: 어른의 화면 옆 (몸에 가리지 않게)
		var d := {"pos": kp, "sp": 2.4, "back": 1.4}
		match ph:
			0:
				d["arms"] = true
			1:
				d["arms"] = true
				d["face"] = hand + _b2() * FACE_CAM if picked else door - _b2() * 0.6
			2:
				d["face"] = hand + _b2() * FACE_CAM
				d["arms"] = u < Balance.ERRAND_GIVE * 0.7
				if _first("e_here"):
					_say_own(kid, "errand_here", "cheer", 1.5)
			3:
				d["face"] = hand + _b2() * FACE_CAM
				var q := absf(sin(u * 5.2))               # 쓰다듬는 손길에 고개가 꾹꾹 (아기를 안은 어른이면 고개만 끄덕 — 아이는 그대로 기뻐함)
				d["sy"] = 1.0 - 0.07 * q
				d["sx"] = 1.0 + 0.05 * q
				if _first("e_pat"):
					_say_own(rc, "errand_thanks", "love", 1.6)
					kv._fx("hearts", kp, 0.55, 1.4, 0.8)
					GameAudio.fx("child_laugh", "Village", -14.0, kp)
			_:
				if int(e["done"]) == 1:
					d["skip"] = true
				else:
					d["arms"] = true
		_dir[kid] = d
		if picked and ph >= 1 and (ph <= 3 or int(e["done"]) == 1) and not _dir.has(rc):
			var rd := {"pos": hand, "sp": Balance.ERRAND_COME, "face": kp + _b2() * FACE_CAM, "back": 1.2, "anim": "idle"}
			var side := signf((kp - hand).dot(r2))
			if ph == 2:
				var w := smoothstep(0.2, 0.8, u / Balance.ERRAND_GIVE)
				if hb:
					rd["lean"] = side * 0.12 * w                       # (㊷) 아기를 안았으니 팔 대신 몸만 기울임
					rd["sy"] = 1.0 - 0.03 * w
				else:
					rd["arms"] = u > Balance.ERRAND_GIVE * 0.45
					rd["lean"] = side * 0.08 * w
			elif ph == 3:
				var k := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(Balance.ERRAND_PAT - 0.3, Balance.ERRAND_PAT, u))
				var nod := absf(sin(u * 4.0)) if hb else 0.0           # (㊷) 쓰다듬는 대신 고개를 끄덕끄덕
				rd["lean"] = side * (0.08 + 0.14 * k) * (0.9 + 0.1 * sin(u * 5.2)) if not hb else side * 0.1 * k
				rd["sy"] = 1.0 - 0.05 * k - 0.05 * nod * k
			elif ph == 4:
				rd["face"] = kp + _b2() * FACE_CAM                     # 깡충깡충 돌아가는 아이를 바라봄 (끝나면 제 자리로)
			_dir[rc] = rd
	# ── 첫 낚시
	var f := ChildOutings.fishing(v)
	if f.is_empty():
		_clear_once("f")
	else:
		var kid := int(f["k"])
		var ph := int(f["ph"])
		var u := float(f["c"]) / ChildOutings.RS
		var seat := Vector2(float(f["sx"]), float(f["sy"]))
		var wdir := Vector2(float(f["wx"]), float(f["wy"]))
		var d := {"pos": Vector2(float(f["x"]), float(f["y"])), "sp": 0.0, "back": 1.4}
		match ph:
			1, 2:
				d["anim"] = "sit"
				d["face"] = seat + wdir * 3.0 + _b2() * 0.7
				if ph == 2:
					d["lean"] = 0.05 * sin(u * 22.0)       # 입질: 파르르
			3:
				d["face"] = seat + wdir * 3.0 + _b2() * 0.7
				if u > 0.25 and u < 1.9:
					d["hop"] = 0.13 * absf(sin((u - 0.25) * 5.7))
				if _first("f_got"):
					_say_own(kid, "fish_got", "cheer", 2.2)
					GameAudio.fx("small_cheer", "Village", -11.0, seat)
					kv._fx("sparkle", seat + wdir * 0.25, 0.6, 1.2, 0.8)
			4:
				if int(f["done"]) == 1:
					d["skip"] = true
		if not _dir.has(kid):
			_dir[kid] = d
		if int(f["m"]) == 1:
			var ad := int(f["ad"])
			var ap := Vector2(float(f["ax"]), float(f["ay"]))
			var s2 := Vector2(float(f["s2x"]), float(f["s2y"]))
			var beside := _beside(seat, s2, wdir)
			ap += (beside - s2) * (1.0 - smoothstep(0.4, 2.4, ap.distance_to(s2)))
			var a := {"pos": ap, "sp": 0.0, "back": 1.1}
			if ph >= 1 and ph <= 3:
				a["anim"] = "sit"
				a["face"] = beside + wdir * 3.0 + _b2() * 0.7
				if ph == 3:
					a["face"] = seat + _b2() * FACE_CAM
					a["lean"] = signf((seat - ap).dot(r2)) * 0.12 * smoothstep(0.0, 0.4, u)
			if not _dir.has(ad):
				_dir[ad] = a


## 그 자리(와 양옆 한 걸음)가 건물 그림에 가려지면 화면 앞쪽으로 얼마나 내어야 보이는지 (안 가려지면 0)
## 첫 낚시: 곁의 어른이 앉을 자리 — 아이의 화면 옆 (시뮬 자리 s2에 가까운 쪽부터, 물도 집 그림 뒤도 아닌 곳). 없으면 시뮬 자리 그대로
func _beside(seat: Vector2, s2: Vector2, wdir: Vector2) -> Vector2:
	var r2 := _r2()
	var first := 1.0 if (s2 - seat).dot(r2) >= 0.0 else -1.0
	if absf(wdir.dot(r2)) > 0.35:              # 물이 화면 옆이면 뭍 쪽에 (낚싯대와 찌를 가리지 않게)
		first = -signf(wdir.dot(r2))
	for sg: float in [first, -first]:
		var q := seat + r2 * sg * SIT_GAP + _b2() * 0.05
		if not v.water_at(q.x, q.y) and kv._stand_ok(q):
			return q
	return s2


## 찌가 떨어지는 자리 (물 위 — 되도록 멀리)
func _cast(seat: Vector2, wdir: Vector2) -> Vector2:
	for c: float in CASTS:
		var q := seat + wdir * c
		var q2 := seat + wdir * (c + 0.25)
		if v.water_at(q.x, q.y) and v.water_at(q2.x, q2.y):
			return q
	return seat + wdir * ChildOutings.FLOAT_D


## (Q21 ㊶) 첫 심부름을 건네는 자리: 문 앞에서 카메라 쪽(트인 땅)으로 한 걸음 — 그 자리와 양옆이 집 그림에 가리면 더 앞으로
func hand_spot(door: Vector2) -> Vector2:
	var q := door + _b2() * HAND_STEP
	return q + _out_front(q)


## 이 사람이 (지난 화면에) 젖먹이를 품에 안고 그려졌나
func _holding(id: int) -> bool:
	var cm := _cut(id)
	return cm != null and cm.carry_baby


## (Q21 ㊵) 나들이 중인 사람 (심부름·낚시의 아이, 낚시의 곁 어른, 심부름을 받는 어른) — 그 사람에게는 나들이의 말만 보인다
func busy(id: int) -> bool:
	return _dir.has(id) or _pup.has(id)


## 이 말풍선을 띄워도 되나: 나들이 중인 사람이면 나들이가 띄운 말만 (시뮬의 혼잣말·놀이·끼니·이야기 장면의 말은 가림 — 화면만, 말 자체는 그대로)
func bubble_ok(id: int, text: String) -> bool:
	if not busy(id):
		return true
	return _own_say.has(id) and String(_own_say[id]) == text


## 나들이의 말 — 그 사람에게 다른 연출 말풍선이 떠 있으면 비우고 띄움
func _say_own(id: int, key: String, mood: String, secs: float) -> void:
	if vw.stage_say.has(id) and not (_own_say.has(id) and String(_own_say[id]) == String((vw.stage_say[id] as Array)[0])):
		vw.stage_say.erase(id)
	kv._say(id, key, mood, secs)
	if vw.stage_say.has(id):
		_own_say[id] = String((vw.stage_say[id] as Array)[0])


func _out_front(p: Vector2) -> Vector2:
	var r2 := _r2()
	var b2 := _b2()
	for i in 16:
		var q := p + b2 * (0.2 * float(i))
		if kv._stand_ok(q) and kv._stand_ok(q + r2 * 0.45) and kv._stand_ok(q - r2 * 0.45):
			return b2 * (0.2 * float(i))
	return Vector2.ZERO


func _clear_once(prefix: String) -> void:
	if _once.is_empty():
		return
	for key: String in _once.keys():
		if key.begins_with(prefix):
			_once.erase(key)


## 유모차와 마주친 이웃 (stroller_met): 화면에 둘 다 있고 한가하면 부모가 멈추고 이웃이 유모차 옆으로 와서 숙여 본다
func _meet_start(nb: int, cr: int) -> void:
	if _meet != null or not ChildOutings.pushing(v, cr) or not _p_has:
		return
	var cm := _cut(cr)
	var nm := _cut(nb)
	var q := v.person(nb)
	var c := v.person(cr)
	if cm == null or nm == null or q == null or c == null:
		return
	if kv._kid.has(nb) or kv._peek.has(nb) or vw.stage_say.has(nb) or _dir.has(nb) or _pup.has(nb):
		return
	var hm := v.bld(c.home)
	if hm != null and Vector2(c.x - hm.x, c.y - hm.y).length() < 2.5:
		return                                 # 집에 다 왔다 — 산책이 곧 끝남
	var at := _m2(cm)
	if _m2(nm).distance_to(at) > MEET_R:
		return
	var r2 := _r2()
	var view := int(cm.doll.view)
	var side := signf(float(cm.doll.mirror)) if view == 1 or view == 2 else signf((_m2(nm) - _p_at).dot(r2))
	if side == 0.0:
		side = 1.0
	var spot := _p_at + r2 * side * MEET_GAP - _b2() * 0.05
	if not kv._stand_ok(spot):
		return
	var mt := Meet.new()
	mt.nb = nb
	mt.cr = cr
	mt.hold = at
	mt.spot = spot
	mt.side = side
	mt.t0 = float(ChildOutings.pram(v).get("t0", 0.0))
	_meet = mt


# ───────────────────────── 매 화면: 주민 하나 (VillageView가 자리를 놓은 뒤) ─────────────────────────
## 이 주민의 인형을 나들이 자리에 세웠으면 true (KidsView의 다른 몸짓은 건너뜀)
func pose(r: Resident, m: ResidentModel, dt: float) -> bool:
	if _pup.is_empty() and _dir.is_empty():
		return false
	var d: Dictionary = _dir.get(r.id, {})
	var pu: Pup = _pup.get(r.id)
	var has_pos := d.has("pos")
	if pu == null:
		if not has_pos:
			return false
		pu = Pup.new()
		pu.pos = _m2(m)
		pu.yaw = m.rotation.y
		_pup[r.id] = pu
	pu.seen = _frame
	var cm := m as CutoutResident
	var sim := _m2(m)
	var prev := pu.pos
	if has_pos:
		var to: Vector2 = d["pos"]
		var sp := float(d.get("sp", 0.0))
		if prev.distance_to(to) > 8.0:
			pu.pos = to
		elif sp <= 0.0:
			pu.pos = prev.lerp(to, 1.0 - exp(-dt * FOLLOW))
		else:
			pu.pos = prev.move_toward(to, sp * dt)
		pu.back = float(d.get("back", 1.4))
	else:                                      # 끝남: 시뮬의 제 자리로 걸어 돌아감
		pu.pos = prev.move_toward(sim, pu.back * dt) if prev.distance_to(sim) < 8.0 else sim
		if pu.pos.distance_to(sim) < 0.03:
			_release(r.id)
			return false
	var step := pu.pos - prev
	pu.sp = lerpf(pu.sp, minf(step.length() / maxf(dt, 1.0e-4), 3.0), minf(1.0, dt * 10.0))
	var moving := pu.sp > 0.18
	if moving and step.length() > 1.0e-5:
		pu.yaw = lerp_angle(pu.yaw, atan2(step.x, step.y), minf(1.0, dt * 12.0))
	elif d.has("face"):
		var fd: Vector2 = (d["face"] as Vector2) - pu.pos
		if fd.length() > 0.01:
			pu.yaw = lerp_angle(pu.yaw, atan2(fd.x, fd.y), minf(1.0, dt * 10.0))
	var hop := float(d.get("hop", 0.0))
	var sy := float(d.get("sy", 1.0))
	var sx := float(d.get("sx", 1.0))
	if bool(d.get("skip", false)) and moving:      # 깡충깡충
		var q := absf(sin(_clock * 8.6 + float(r.id)))
		hop += 0.085 * q
		sy *= 1.0 + 0.05 * q
	m.position = Vector3(pu.pos.x, kv._gy(pu.pos.x, pu.pos.y), pu.pos.y)
	m.rotation.y = pu.yaw
	if moving:
		m._ground = snappedf(clampf(pu.sp, 0.3, KidsView.RUN_LEGS), 0.15)
	m.set_anim("walk" if moving else String(d.get("anim", "idle")), r.action)
	if cm != null:
		cm.set_body_lift(hop / maxf(cm.scale.y, 0.01))
		cm.set_body_warp(sy, sx, float(d.get("lean", 0.0)))
	else:
		m.position.y += hop
	return true


## 이 주민이 지금 나들이 인형으로 서 있는가 (시험)
func staged(id: int) -> bool:
	return _pup.has(id)


# ───────────────────────── 매 화면: 뒤 (아기를 놓은 뒤) — 소품 그림 ─────────────────────────
func after(dt: float, fast: bool) -> void:
	if v == null or vw == null or kv == null or not CutoutResident.enabled():
		return
	_pram_draw(dt, fast)
	_park_draw()
	if not fast:
		_errand_draw()
		_fish_draw(dt)
	for nm: String in _cards.keys():
		var c: Array = _cards[nm]
		if int(c[2]) != _frame:
			(c[0] as MeshInstance3D).visible = false
			if int(c[2]) < _frame - 3600:
				(c[0] as MeshInstance3D).queue_free()
				_cards.erase(nm)


## 유모차 한 대 (그림 두 장 + 옆모습이면 굴러가는 단추 바퀴 둘). view = 인형의 보기 (0 앞 · 1 앞옆 · 2 뒤옆 · 3 뒤), mir = 화면 오른쪽으로 가면 +1
func _pram_cards(key: String, at: Vector3, view: int, mir: float, bob: float, roll: float) -> void:
	var s := PRAM_K / PX
	var side := view == 1 or view == 2
	var sx := -mir if side else 1.0
	var back := "p%d_back" % view
	var w := pic_w(back, PRAM_K)
	_put(key + "b", back, at, w, 0.0, -0.012, sx, 1.0, 0.0, -GROUND_PX * s + bob)
	_put(key + "f", "p%d_front" % view, at, w, 0.0, 0.075, sx, 1.0, 0.0, -GROUND_PX * s + bob)
	if side:
		var ws: Array = WHEELS[view]
		for i in ws.size():
			var wp: Vector2 = ws[i]
			_put("%sw%d" % [key, i], "wheel", at + kv._right * (wp.x * s * sx), pic_w("wheel", PRAM_K), roll, 0.085, 1.0, 1.0, 1.0, (wp.y - GROUND_PX) * s + bob * 0.4)


func _pram_draw(dt: float, fast: bool) -> void:
	var p := ChildOutings.pram(v)
	var cm: CutoutResident = _cut(int(p["cr"])) if not p.is_empty() else null
	if cm == null:
		_p_has = false
		_p_gig = -1.0
		return
	var r2 := _r2()
	var b2 := _b2()
	var sn := _sn()
	var view := int(cm.doll.view)
	var mir := 1.0 if float(cm.doll.mirror) >= 0.0 else -1.0
	var want := b2 * PRAM_FRONT
	match view:
		1:
			want = r2 * mir * PRAM_DX + b2 * (PRAM_DY / sn)
		2:
			want = r2 * mir * PRAM_DX - b2 * (PRAM_DY / sn)
		3:
			want = -b2 * PRAM_BACK
	var was := _p_at
	if not _p_has or fast:
		_p_off = want
	else:
		_p_off = _p_off.lerp(want, 1.0 - exp(-dt * 9.0))
	_p_at = _m2(cm) + _p_off
	var moved := (_p_at - was) if _p_has else Vector2.ZERO
	_p_has = true
	var s := PRAM_K / PX
	if moved.length() < 1.0:
		_p_roll -= moved.dot(r2) / (WHEEL_R_PX * s)
		_p_run += moved.length()
	var bob := 0.007 * sin(_p_run * 34.0) if not fast else 0.0
	var at := _g3(_p_at)
	_pram_cards("pram_", at, view, mir, bob, _p_roll)
	# 아기: 바구니 안에 누움 (요람과 같은 식). 이웃이 들여다보면 꼼지락 · 손을 내밀고 · 작은 하트
	var wig := 0.0
	if _p_gig >= 0.0:
		_p_gig += dt
		if _p_gig > 0.45 and _p_gig < 2.4:
			wig = absf(sin(_clock * 9.0)) * 0.02
			var hu := smoothstep(0.45, 0.8, _p_gig) * (1.0 - smoothstep(2.0, 2.4, _p_gig))
			_spr("pram_hand", "hand", at, Vector2(_p_side * (0.07 + 0.07 * hu) * PRAM_K, (RIM_PX + 16.0 + 22.0 * hu) * s + 0.012 * sin(_clock * 11.0)),
				pic_w("hand", PRAM_K * 0.8), _p_side * -0.3, 0.05)
		if _p_gig > 0.7 and _p_gig - dt <= 0.7:
			kv._fx("hearts", _p_at, 0.42, 1.3, 0.75)
			GameAudio.fx("baby_giggle_%d" % (int(p["b"]) % 2), "Village", -6.0, _p_at)
		if _p_gig > 3.0:
			_p_gig = -1.0
	var bm := _cut(int(p["b"]))
	if bm != null and bm.baby_mode == "pram":
		var ks: float = BABY_K.x if view == 1 or view == 2 else BABY_K.y
		var lying := KidsView._sleep_lift() * bm._doll_h * ks
		bm.position = at
		bm.set_body_lift((RIM_PX * s + 0.012 - lying + bob + wig) / kv._cu / maxf(bm.scale.y, 0.01))
		bm.set_body_warp(ks, ks, 0.0)


## 문 옆에 세워 둔 유모차 (그 집 아기가 유모차로 나가 있는 동안은 없음)
func _park_draw() -> void:
	var park := ChildOutings.parked(v)
	if park.is_empty():
		_park.clear()
		return
	var out_h := int(ChildOutings.pram(v).get("h", -1)) if _p_has else -1
	for key: String in park:
		var hid := int(key)
		if hid == out_h:
			continue
		var hm := v.bld(hid)
		if hm == null:
			continue
		var sp: Array = _park.get(hid, [])
		if sp.is_empty() or _frame % 600 == 0:
			sp = _park_spot(hm)
			_park[hid] = sp
		var at: Vector2 = sp[0]
		_pram_cards("park%d_" % hid, _g3(at), 1, float(sp[1]), 0.0, 0.6 + float(hid))


## 집 그림의 밑변 바로 앞, 문 오른쪽 가 (요람은 왼쪽 · 바람개비는 가운데 오른쪽), 막혔으면 왼쪽 가 → [자리, 좌우 (손잡이가 문 쪽)]
## 건물 그림은 카메라를 보고 선 판이라 화면 기준(오른쪽 · 앞)으로 센다
func _park_spot(hm: Building) -> Array:
	var r2 := _r2()
	var b2 := _b2()
	var c := Vector2(hm.x, hm.y)
	var w := hm.size() + 1.2
	var front := hm.size() * 0.5 + 0.3
	for it: Array in vw._card_items.get(hm.id, []):
		var d := Bld2D.info(String(it[0]))
		if d.is_empty() or int(d.get("mode", 0)) != 0:
			continue
		var c3: Vector3 = it[1]
		c = Vector2(c3.x, c3.z)
		w = float(d.get("w", 2.5)) * float(it[2])
		front = float(d.get("front", 1.1)) * float(it[2])
		break
	var out := front + KidsView.FS_CLEAR + PARK_OUT
	for cand: Array in [[PARK_SIDE, 1.0], [-PARK_SIDE - 0.06, -1.0], [PARK_SIDE + 0.1, 1.0]]:
		var q := c + r2 * w * float(cand[0]) + b2 * out
		if kv._stand_ok(q):
			return [q, float(cand[1])]
	return [c + r2 * w * PARK_SIDE + b2 * (out + 0.1), 1.0]


## 인형의 손 높이쯤 (화면 세로 — 폴짝 포함)
func _hand_y(cm: CutoutResident, k: float) -> float:
	return cm._doll_h * k + cm._lift * cm.scale.y * kv._cu


## 첫 심부름의 보퉁이 (앓는 집에는 김 나는 그릇): 아이 가슴 앞 → 건네는 동안 어른 손으로 → 어른 옆구리
func _errand_draw() -> void:
	var e := ChildOutings.errand(v)
	if e.is_empty():
		_e_drop = Vector3.INF
		return
	var km := _cut(int(e["k"]))
	if km == null:
		return
	var ph := int(e["ph"])
	var u := float(e["c"]) / ChildOutings.RS
	var pic := "bowl" if String(e["why"]) == "sick" else "bundle"
	var w := BOWL_W if pic == "bowl" else BUNDLE_W
	var o := km.position
	var kpt := _hold_pt(km, 0.36, 0.08)
	if ph <= 1 or (ph == 4 and int(e["done"]) != 1):
		_spr("e_item", pic, o, Vector2(kpt.x, kpt.y), w, 0.0, kpt.z)
		return
	var rm := _cut(int(e["rc"]))
	var hb := int(e.get("hb", 0)) == 1 or (rm != null and rm.carry_baby)
	if rm == null or (ph == 4 and not hb):
		return
	var rel := rm.position - km.position
	var roff := Vector2(rel.dot(kv._right), 0.0)       # 어른이 아이보다 화면 가로로 얼마나
	var dz := rel.dot(Vector3(kv._back.x, 0.0, kv._back.z))
	roff.y = -dz * _sn() + (rm.position.y - km.position.y) * kv._cu
	if hb:          # (Q21 ㊷) 젖먹이를 안은 어른: 손을 내밀지 않음 — 아이가 그 사람 발치(둘 사이)에 내려놓음, 아이가 돌아가는 동안에도 그 자리에
		if ph == 4:      # 아이는 떠났다 — 놓아 둔 자리 그대로
			if _e_drop != Vector3.INF:
				_spr("e_item", pic, _e_drop, Vector2(0.0, w * 0.42), w, 0.0, 0.05)
			return
		var foot := Vector2(roff.x * 0.55, roff.y * 0.55 + w * 0.42)
		var kk := smoothstep(0.3, 0.8, u / Balance.ERRAND_GIVE) if ph == 2 else 1.0
		_e_drop = km.position.lerp(rm.position, 0.55)
		_spr("e_item", pic, o, Vector2(kpt.x, kpt.y).lerp(foot, kk), w, 0.0, lerpf(kpt.z, 0.05, kk))
		return
	var seated := rm._d_clip == "sit"
	var rpt := _hold_pt(rm, 0.3 if seated else 0.4, 0.1)
	var to := roff + Vector2(rpt.x, rpt.y)
	var k := smoothstep(0.3, 0.75, u / Balance.ERRAND_GIVE) if ph == 2 else 1.0
	var at := Vector2(kpt.x, kpt.y).lerp(to, k)
	at.y += 0.05 * sin(k * PI)
	var depth := lerpf(kpt.z, dz * kv._cu + 0.07, k)
	var sc := 1.0
	if ph == 3:
		sc = 1.0 - 0.25 * smoothstep(0.0, 0.5, u)
		at.y -= 0.04 * smoothstep(0.0, 0.5, u)
	_spr("e_item", pic, o, at, w * sc, 0.0, depth)


## 인형이 두 손으로 든 것의 자리 → (화면 가로, 화면 세로, 카메라 쪽) — 옆모습이면 바라보는 쪽 앞, 뒷모습이면 몸 뒤에 가림
func _hold_pt(cm: CutoutResident, hk: float, fwd: float) -> Vector3:
	var view := int(cm.doll.view)
	var mir := 1.0 if float(cm.doll.mirror) >= 0.0 else -1.0
	var x := 0.0
	var depth := 0.06
	match view:
		1:
			x = mir * fwd
		2:
			x = mir * fwd
			depth = -0.02
		3:
			depth = -0.03
	return Vector3(x, _hand_y(cm, hk), depth)


## 첫 낚시: 풀줄기 낚싯대 · 줄 · 찌 · 올라온 작은 물고기
func _fish_draw(dt: float) -> void:
	var f := ChildOutings.fishing(v)
	if f.is_empty():
		return
	var km := _cut(int(f["k"]))
	if km == null:
		return
	var ph := int(f["ph"])
	var u := float(f["c"]) / ChildOutings.RS
	var o := km.position
	var kh := km._doll_h
	var mir := 1.0 if float(km.doll.mirror) >= 0.0 else -1.0
	var lift := km._lift * km.scale.y * kv._cu
	if ph == 0 or ph == 4:                     # 오가는 길: 낚싯대를 어깨에 (돌아올 때는 끝에 물고기가 달랑)
		var h := Vector2(mir * 0.05, kh * 0.47 + lift)
		var tip := h + Vector2(-mir * 0.25, 0.45)
		_rod(o, h, tip, -0.03)
		if ph == 4 and int(f["done"]) == 1:
			var sw := 0.035 * sin(_clock * 7.0)
			var fp := tip + Vector2(sw, -0.13)
			_seg("f_line", "string", o, tip, fp + Vector2(0.0, 0.06), 0.03, -0.035)
			_spr("f_fish", "fish", o, fp, pic_w("fish", 0.95), sw * 3.0, -0.035)
		return
	var seat := Vector2(float(f["sx"]), float(f["sy"]))
	var wdir := Vector2(float(f["wx"]), float(f["wy"]))
	var fl := _cast(seat, wdir)
	var wy := kv._wy(fl.x, fl.y)
	var rel := fl - _m2(km)
	var dz := rel.dot(_b2())
	var fs := Vector2(rel.dot(_r2()), -dz * _sn() + (wy - o.y) * kv._cu)      # 찌의 화면 자리 (아이 발에서)
	var fdepth := dz * kv._cu + (wy - o.y) * _sn() + 0.05
	var side := signf(fs.x) if absf(fs.x) > 0.08 else mir
	if ph == 1 or ph == 2:
		var jig := 0.0
		var bobk := 0.012 * sin(_clock * 2.3)
		if ph == 2:                            # 입질: 찌가 쏙쏙, 물결 고리, 낚싯대 끝이 파르르
			jig = 0.02 * sin(_clock * 31.0)
			bobk = -0.03 * absf(sin(u * 11.0))
			if _first("f_bite"):
				GameAudio.fx("skip_plip", "Village", -8.0, fl)
			var n := int(u / 0.36)
			if _first("f_ring%d" % n):
				kv._ring(Vector3(fl.x, wy + KidsView.RING_LIFT, fl.y), 0.26 + 0.05 * float(n))
		var h := Vector2(side * 0.1, kh * 0.34 + lift)
		var tip := Vector2(h.x + side * maxf(0.27, 0.6 * absf(fs.x - h.x)), maxf(h.y + 0.2, fs.y + 0.32) + jig)
		_rod(o, h, tip, 0.06)
		_seg("f_line", "string", o, tip, fs + Vector2(0.0, 0.05 + bobk), 0.03, maxf(fdepth, 0.07))
		_spr("f_float", "float", o, fs + Vector2(0.0, 0.02 + bobk), pic_w("float", 1.5), 0.0, fdepth)
		return
	# 건져 올림: 낚싯대를 번쩍, 작은 물고기가 물에서 솟아 끝에 매달려 파닥파닥
	var h := Vector2(side * 0.07, kh * 0.5 + lift)
	var tip := h + Vector2(side * 0.24, 0.42)
	_rod(o, h, tip, 0.06)
	var up := smoothstep(0.0, 0.32, u)
	var hang := tip + Vector2(0.03 * sin(_clock * 6.0) * up, -0.2)
	var fp := (fs + Vector2(0.0, 0.03)).lerp(hang, up)
	fp.y += 0.1 * sin(up * PI)
	_seg("f_line", "string", o, tip, fp + Vector2(0.0, 0.07), 0.03, 0.07)
	_spr("f_fish", "fish", o, fp, pic_w("fish", 1.1), 0.25 * sin(_clock * 13.0) * up, lerpf(fdepth, 0.075, up))
	if u < 0.12 and _first("f_splash"):
		kv._ring(Vector3(fl.x, wy + KidsView.RING_LIFT, fl.y), 0.42)
	var am := _cut(int(f["ad"]))               # 곁의 어른 머리 위에 물고기 그림 (글 없음)
	var ar := v.person(int(f["ad"]))
	if am != null and ar != null and u > 0.5 and u < 2.5 and not kv._says(ar):
		kv.bub.add(am, "fish", (u - 0.5) / 2.0, true, kv._clock)


## 풀줄기 낚싯대: 손 h → 끝 tip (화면, 아이 발에서)
func _rod(o: Vector3, h: Vector2, tip: Vector2, depth: float) -> void:
	var dv := tip - h
	var k := clampf(dv.length() / (ROD_LEN / PX), 0.75, 1.7)
	var flip := 1.0 if dv.x >= 0.0 else -1.0
	var rot := atan2(dv.y, dv.x) - (ROD_A0 if flip > 0.0 else PI - ROD_A0)
	var hv := (Vector2(ROD_HAND.x * flip, ROD_HAND.y) * (k / PX)).rotated(rot)
	_spr("f_rod", "rod", o, h - hv, pic_w("rod", k), rot, depth, flip, 1.0)
