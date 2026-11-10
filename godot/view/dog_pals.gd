## [강아지와 사람] (ROADMAP Q2-d · 귀여움 묶음 ④) — 화면만 (ADR-0001).
## 시뮬의 강아지(sim/dogs.gd)는 주인·노는 아이 '곁 한 자리'에 있을 뿐이다. 여기서는 그 강아지가 **그려지는 자리와 몸짓**만 얹는다:
##   · 따라가기: 주인이 걸으면 한 박자 늦게 일어나 종종 따라가고, 주인이 서면 곁에 앉아 올려다보며 꼬리(몸 전체)를 흔든다.
##   · 아이들 놀이: 술래잡기는 아이 옆에서 같이 달리고, 나비는 맨 뒤에서 쫓으며 폴짝, 돌탑은 앞에 앉아 구경하다 무너지면 움찔 물러난다.
##   · 쓰다듬기 (드문 작은 장면): 가만히 선 아이 곁으로 강아지가 다가와 앉고, 아이가 몸을 숙이고, 강아지가 좋아서 납작해진다 (하트).
## 시뮬 값은 읽기만 하고 아무것도 쓰지 않는다 — 식량·일·관계는 물론 강아지의 시뮬 자리도 그대로. 난수는 이 노드의 것만 (시뮬 난수 흐름과 무관).
## 폴짝·움찔·멍!(그림 말풍선 + 이미 있는 강아지 소리)은 톡 반응의 길(view/tap_react.gd cue)을 빌린다: cues에 쌓아 두면 test_village가 가져감.
## 몸짓은 모두 인형 통째(자리·기울임·눌림) — 주민·강아지 그림이 바뀌어도 그대로 쓴다.
class_name DogPals
extends RefCounted

const LAG := 0.38                 # 그린 자리가 갈 곳을 이만큼(현실 초) 늦게 쫓음 — 걷는 주인 뒤로 한 뼘 처짐
const MIN_SPEED := 0.38           # 움직일 땐 적어도 이 빠르기 (칸/초) — 걷는 발 없이 미끄러지지 않게 (CutoutDogs.WALK_ON 위)
const START_GAP := 0.3            # 앉아 있다가 주인과 이만큼 벌어지면 일어나 따라감
const ARRIVE := 0.03
const JUMP := 6.0                 # 이보다 멀면 걸음이 아님 (집 안팎·순간이동)
const SIT_AFTER := 0.3            # 멈춘 뒤 이만큼 지나면 앉음 (현실 초)
const LOOK_R := 3.0               # 이 안의 주인을 올려다봄
const HEEL_R := 1.7               # 선 주인이 이 안이면 곁(옆 + 조금 앞)에 와 앉음 — 주인 뒤에 가려지지 않게
const HEEL_SIDE := 0.5
const HEEL_FRONT := 0.1
const GAME_R := 3.4               # 노는(play) 강아지: 놀이 가운데에서 이 안이면 놀이에 낌
const GAME_R_FOLLOW := 2.4        # 아이를 따라온 집 강아지
const GAME_DOGS := 2              # 놀이 하나에 끼는 강아지 수
const TAG_SIDE := [0.45, -0.4]    # 같이 달리는 자리: 아이의 바깥쪽 · 안쪽 (칸)
const STACK_SEAT := [Vector2(0.74, 0.5), Vector2(-0.76, 0.46)]     # 돌탑 앞 양옆 (탑을 가리지 않게 — 아이들은 뒤·옆에 앉음)
const STACK_BACK := 0.32          # 무너지면 이만큼 물러남
const FELL_SECS := 1.3
const BFLY_BEHIND := 0.9          # 마지막 아이 뒤로 (아이 사이 간격의 배)
const LEAP_EVERY := 2.3           # 나비를 쫓다 폴짝 (현실 초)
const LEAP_SECS := 0.36
const LEAP_H := 0.16
const WAG_HZ := 4.6
const WAG_ROLL := 0.1             # 꼬리 흔들기 = 몸 전체가 좌우로 까딱 (rad)
const WAG_SIT := 1.5              # 앉자마자 흔드는 시간
const WAG_EVERY := 6.5
const WOOF_GAP := 4.0             # 한 강아지가 다시 짖기까지 (현실 초)
const PET_CHECK := Vector2(6.0, 11.0)     # 쓰다듬기를 살피는 간격 (현실 초)
const PET_P := 0.4
const PET_R := 1.7                # 이 안의 강아지
const PET_SIDE := 0.44            # 아이 옆 이만큼에 앉음
const PET_COME := 2.2             # 다가오는 데 이보다 걸리면 그냥 시작
const PET_SECS := 2.3
const PET_REST := 45.0            # 한 번 쓰다듬은 뒤 다음까지 (현실 초)
const PET_LEFT := 1500.0          # 아이가 이만큼은 더 서 있어야 (병 초 — 보통 빠르기 5초쯤)
const PET_LEAN := 0.2
const PET_STATES := ["idle", "roam", "follow", "play", "walk"]
const CUE_KEEP := 8

var v: Village
var vw: VillageView
var cues: Array = []              # [{who: "d", id, kind}] — 톡 반응의 길로 보낼 몸짓 (test_village가 가져감 · 헤드리스에선 쌓였다 잘림)
var pets := 0                     # 지금까지 시작한 쓰다듬기 (시험·캡처)
var joined := 0                   # 지금 놀이에 낀 강아지 수 (시험)
var _st := {}                     # 강아지 id → S
var _rank := {}                   # 강아지 id → [놀이, 몇째]
var _fell := {}                   # 놀이 id → 무너진 때 (현실 시계)
var _stack_h := {}                # 놀이 id → 지난 화면의 돌 수
var _pet := {}                    # {kid, dog, ph(0 다가옴 · 1 쓰다듬음), t, at: 아이 자리, side}
var _pet_next := 9.0
var _pet_warp := -1               # 숙인 채인 아이 (끝나면 되돌림)
var _cursor := 0
var _clock := 0.0
var _frame := 0
var _on := false
var _right := Vector3.RIGHT
var _front := Vector3.BACK        # 땅 위에서 보는 이 쪽 (화면 아래)
var _rng := RandomNumberGenerator.new()


class S extends RefCounted:
	var pos := Vector2.ZERO
	var moving := false
	var still := 0.0
	var free := true              # 시뮬 자리 그대로 (얹은 것 없음)
	var mode := ""
	var wag := 0.0                # 남은 꼬리 흔들기 (초)
	var woof := -100.0
	var seen := 0


func _init(village: Village = null, view: VillageView = null) -> void:
	v = village
	vw = view
	_rng.seed = 20261110
	if v != null:
		_cursor = v.events.serial


# ───────────────────────── 매 화면 (강아지를 그리기 전에) ─────────────────────────
func step(dt: float, fast: bool) -> void:
	_frame += 1
	_clock += dt
	_on = not fast and v != null and v.dogs != null
	joined = 0
	if vw != null and vw.is_inside_tree():
		var cam := vw.get_viewport().get_camera_3d()
		if cam != null:
			var bs := cam.global_transform.basis
			var rx := Vector3(bs.x.x, 0.0, bs.x.z)
			if rx.length_squared() > 1.0e-6:
				_right = rx.normalized()
			var fz := Vector3(bs.z.x, 0.0, bs.z.z)
			if fz.length_squared() > 1.0e-6:
				_front = fz.normalized()
	if v == null:
		return
	var evs: Array = []
	if v.events.serial != _cursor:
		evs = v.events.since(_cursor)
		_cursor = v.events.serial
	if not _on:
		_rank.clear()
		_end_pet(false)
		return
	_ranks()
	for e: Dictionary in evs:
		var kind: StringName = e["kind"]
		if kind == &"kid_stack_fell":
			var gid := int((e["v"] as Dictionary)["game"])
			_fell[gid] = _clock
			for id: int in _rank:
				if int(_rank[id][0]["id"]) == gid:
					_cue(id, "dog_flinch")
		elif kind == &"kid_tagged":
			var gid := int((e["v"] as Dictionary)["game"])
			for id: int in _rank:
				if int(_rank[id][0]["id"]) == gid and int(_rank[id][1]) == 0:
					_woof(id)
	for gid: int in _fell.keys():
		if _clock - float(_fell[gid]) > FELL_SECS:
			_fell.erase(gid)
	_pet_tick(dt)
	if _frame % 240 == 0:                 # 떠난 강아지의 기억을 치움
		for id: int in _st.keys():
			if _frame - (_st[id] as S).seen > 240:
				_st.erase(id)


func take_cues() -> Array:
	var c := cues
	cues = []
	return c


func _cue(id: int, kind: String) -> void:
	cues.append({"who": "d", "id": id, "kind": kind})
	if cues.size() > CUE_KEEP:
		cues = cues.slice(cues.size() - CUE_KEEP)


func _woof(id: int) -> void:
	var s: S = _st.get(id)
	if s == null or _clock - s.woof < WOOF_GAP:
		return
	s.woof = _clock
	_cue(id, "dog_woof")


## 놀이마다 곁의 강아지 (시뮬 자리로 고름 — 가까이 온 강아지만, 놀이 하나에 GAME_DOGS마리)
func _ranks() -> void:
	_rank.clear()
	var gs: Array = v.kids.get("g", [])
	if gs.is_empty():
		_stack_h.clear()
		return
	for g: Dictionary in gs:
		if not (g["on"] as Array).has(1):
			continue
		var c := Vector2(float(g["x"]), float(g["y"]))
		var k := 0
		for dg: Dictionary in v.dogs.list:
			var id := int(dg["id"])
			var state := String(dg.get("state", ""))
			if _rank.has(id) or (state != "play" and state != "follow") or int(_pet.get("dog", -1)) == id:
				continue
			if Vector2(float(dg["x"]), float(dg["y"])).distance_to(c) > (GAME_R if state == "play" else GAME_R_FOLLOW):
				continue
			_rank[id] = [g, k]
			k += 1
			if k >= GAME_DOGS:
				break


## 강아지 하나의 그릴 자리·몸짓 (CutoutDogs.sync가 보이는 강아지마다 부름). sp = 시뮬 자리 (걸음 사이 보간된 것).
## 돌려주는 것: {} = 시뮬 그대로 · {pos: Vector2, hint: "" | sit | bow | idle, look: Vector2(없으면 INF), roll: 꼬리 흔들기(rad), hop: 폴짝(칸)}
func place(dg: Dictionary, sp: Vector2, dt: float) -> Dictionary:
	var id := int(dg["id"])
	var s: S = _st.get(id)
	if s == null:
		s = S.new()
		s.pos = sp
		_st[id] = s
	s.seen = _frame
	var state := String(dg.get("state", "idle"))
	if not _on or state == "sleep":
		s.pos = sp
		s.free = true
		s.moving = false
		s.mode = ""
		return {}
	var tgt := sp
	var mode := ""
	var hint := ""
	var look := Vector2.INF
	var wag := false
	var hop := 0.0
	var gap := 0.0
	if int(_pet.get("dog", -1)) == id:
		mode = "pet"
		var at: Vector2 = _pet["at"]
		tgt = at + Vector2(_right.x, _right.z) * PET_SIDE * float(_pet["side"]) + Vector2(0.0, 0.06)
		look = at
		hint = "sit"
		wag = true
	elif _rank.has(id):
		var g: Dictionary = _rank[id][0]
		var k := int(_rank[id][1])
		var c := Vector2(float(g["x"]), float(g["y"]))
		mode = String(g["kind"])
		joined += 1
		match mode:
			"tag":
				var i := _tag_kid(g, k)
				var kp := _kid_pos(g, i)
				var out := kp - c
				tgt = kp + (out.normalized() if out.length() > 0.05 else Vector2.RIGHT) * float(TAG_SIDE[k % TAG_SIDE.size()])
				look = kp
				hint = "bow"                  # 아이가 멈추면 놀자 절
				wag = true
			"bfly":
				var gc := float(g["c"])
				var n := 0
				for j in (g["who"] as Array).size():
					if int(g["on"][j]) == 1:
						n = maxi(n, int(g["sl"][j]) + 1)
				tgt = ChildPlay.bfly_at(g, gc - ChildPlay.BFLY_LAG.x - ChildPlay.BFLY_LAG.y * (float(n) - 1.0 + BFLY_BEHIND + 0.8 * float(k))) + Vector2(0.0, 0.16)
				look = ChildPlay.bfly_at(g, gc)
				wag = true
				var u := fposmod(_clock + float(id) * 0.77, LEAP_EVERY) / LEAP_SECS
				if u < 1.0 and s.moving:
					hop = LEAP_H * sin(u * PI)
			"stack":
				var seat: Vector2 = STACK_SEAT[k % STACK_SEAT.size()]
				var gid := int(g["id"])
				if _fell.has(gid):
					seat += seat.normalized() * STACK_BACK
				else:
					hint = "sit" if int(g["ph"]) == 0 else "idle"      # 흔들리면 벌떡 일어나 봄
				tgt = c + seat
				look = c
				var h := int(g["h"])
				if k == 0:
					if h > int(_stack_h.get(gid, h)):
						s.wag = 0.9               # 돌이 하나 올라갈 때마다 꼬리
					_stack_h[gid] = h
				elif h > 0 and int(g["ph"]) == 0 and fposmod(_clock + float(id), 3.1) < 0.9:
					wag = true
	elif state == "follow":
		mode = "follow"
		gap = START_GAP
		var o := v.person(int(dg.get("owner", -1)))
		if o != null and not o.dead:
			var op := Vector2(o.x, o.y)
			var om: Node3D = vw.residents.get(o.id) if vw != null else null
			if om != null and om.visible:
				op = Vector2(om.position.x, om.position.z)
			if op.distance_to(s.pos) < LOOK_R:
				look = op
				hint = "sit"
			if o.anim != "walk" and not o.sleeping and op.distance_to(sp) < HEEL_R:
				var r2 := Vector2(_right.x, _right.z)
				var side := 1.0 if (s.pos - op).dot(r2) >= 0.0 else -1.0
				tgt = op + r2 * HEEL_SIDE * side + Vector2(_front.x, _front.z) * HEEL_FRONT
	# ── 그린 자리: 갈 곳을 한 박자 늦게 쫓음 (움직일 땐 걷는 발이 나올 만큼 빠르게, 닿으면 딱 멈춤) ──
	if mode == "" and s.free:
		s.pos = sp
		s.moving = false
		s.mode = ""
		return {}
	if mode != s.mode:
		s.mode = mode
		s.still = 0.0
	s.free = false
	var d := tgt - s.pos
	var dist := d.length()
	if dist > JUMP:
		s.pos = tgt
		s.moving = false
	elif dt > 0.0 and (s.moving or dist > maxf(ARRIVE, gap if s.still > SIT_AFTER else 0.0)):
		var stp := maxf(MIN_SPEED, dist / (LAG if mode != "" else LAG * 0.6)) * dt
		if stp >= dist:
			s.pos = tgt
			s.moving = false
		else:
			s.pos += d / dist * stp
			s.moving = true
	if s.moving:
		s.still = 0.0
	else:
		if mode == "":                        # 시뮬 자리에 돌아옴 — 얹은 것 없음
			s.free = true
			s.pos = sp
			return {}
		if s.still <= SIT_AFTER and s.still + dt > SIT_AFTER and (mode == "follow" or mode == "pet"):
			s.wag = WAG_SIT                   # 앉자마자 꼬리
		s.still += dt
	if mode == "follow" and not s.moving and fposmod(_clock + float(id) * 1.7, WAG_EVERY) < 1.0:
		wag = true
	s.wag = maxf(0.0, s.wag - dt)
	var roll := 0.0
	if not s.moving and (wag or s.wag > 0.0) and s.still > SIT_AFTER * 0.5:
		roll = WAG_ROLL * sin(TAU * WAG_HZ * _clock + float(id))
	return {"pos": s.pos, "hint": hint if not s.moving and s.still > SIT_AFTER else "", "look": look, "roll": roll, "hop": hop}


## 같이 달릴 아이: 첫째 강아지는 달아나는 아이, 둘째는 술래 (자리에 있는 아이 가운데)
func _tag_kid(g: Dictionary, k: int) -> int:
	var who: Array = g["who"]
	var it := int(g["it"])
	var first := -1
	var it_i := -1
	var run_i := -1
	for i in who.size():
		if int(g["on"][i]) == 0:
			continue
		if first < 0:
			first = i
		if int(who[i]) == it:
			it_i = i
		elif run_i < 0:
			run_i = i
	if k == 0:
		return run_i if run_i >= 0 else first
	return it_i if it_i >= 0 else first


## 놀이 속 아이가 그려진 자리 (KidsView가 놓은 화면 자리 — 없으면 놀이 시계로 셈한 자리)
func _kid_pos(g: Dictionary, i: int) -> Vector2:
	if i < 0:
		return Vector2(float(g["x"]), float(g["y"]))
	var kv: KidsView = vw.kids_view if vw != null else null
	if kv != null:
		var kid: KidsView.Kid = kv._kid.get(int(g["who"][i]))
		if kid != null and kid.has:
			return kid.pos
	return ChildPlay.spot(g, i, float(g["c"]))


# ───────────────────────── 쓰다듬기 (드문 작은 장면) ─────────────────────────
func petting() -> bool:
	return not _pet.is_empty() and int(_pet["ph"]) == 1


## 그 아이가 그 강아지를 쓰다듬게 (캡처·시험) — 조건(가만히 선 아이·곁의 강아지)은 보지 않는다
func force_pet(kid_id: int, dog_id: int) -> bool:
	var r := v.person(kid_id) if v != null else null
	if r == null or v.dogs == null:
		return false
	for dg: Dictionary in v.dogs.list:
		if int(dg["id"]) == dog_id:
			_end_pet(false)
			_start_pet(r, dg)
			return true
	return false


func _pet_tick(dt: float) -> void:
	if _pet.is_empty():
		if _clock < _pet_next:
			return
		_pet_next = _clock + _rng.randf_range(PET_CHECK.x, PET_CHECK.y)
		var c := pet_candidate()
		if not c.is_empty() and _rng.randf() < PET_P:
			_start_pet(c["kid"], c["dog"])
		return
	var r := v.person(int(_pet["kid"]))
	var s: S = _st.get(int(_pet["dog"]))
	var dg := _dog(int(_pet["dog"]))
	if r == null or r.dead or r.sleeping or r.anim == "walk" or Vector2(r.x, r.y).distance_to(_pet["at"]) > 0.3 \
			or dg.is_empty() or String(dg.get("state", "")) == "sleep" or s == null or _frame - s.seen > 2:
		_end_pet(true)                        # 아이가 가 버림·강아지가 안 보임 — 조용히 접음
		return
	_pet["t"] = float(_pet["t"]) + dt
	if int(_pet["ph"]) == 0:
		if (s.mode == "pet" and not s.moving and s.still > 0.15) or float(_pet["t"]) > PET_COME:
			_pet["ph"] = 1
			_pet["t"] = 0.0
			pets += 1
			_cue(int(_pet["dog"]), "dog_happy")
	elif float(_pet["t"]) > PET_SECS:
		_end_pet(true)


## 지금 쓰다듬을 만한 아이와 강아지 {kid: Resident, dog: 사전} — 없으면 빈 사전. 시뮬 값은 읽기만
func pet_candidate() -> Dictionary:
	if v == null or v.dogs == null or vw == null:
		return {}
	for r in v.people:
		if not r.is_child() or r.is_baby() or r.sleeping or r.dead or r.anim == "walk" or r.steps.is_empty():
			continue
		var s0: Dictionary = r.steps[0]
		if String(s0.get("k", "")) != "do" or float(s0.get("left", 0.0)) < PET_LEFT:
			continue
		if not ChildPlay.game_of(v, r.id).is_empty() or vw.stage_say.has(r.id) or vw.pose_over.has(r.id) or (vw.social != null and vw.social.busy(r.id)):
			continue
		var m: Node3D = vw.residents.get(r.id)
		if m == null or not m.visible:
			continue
		for dg: Dictionary in v.dogs.list:
			var id := int(dg["id"])
			var s: S = _st.get(id)
			if s == null or _frame - s.seen > 2 or s.moving or _rank.has(id) or not PET_STATES.has(String(dg.get("state", ""))):
				continue
			if s.pos.distance_to(Vector2(r.x, r.y)) <= PET_R:
				return {"kid": r, "dog": dg}
	return {}


func _start_pet(r: Resident, dg: Dictionary) -> void:
	var at := Vector2(r.x, r.y)
	var s: S = _st.get(int(dg["id"]))
	var from := s.pos if s != null else Vector2(float(dg["x"]), float(dg["y"]))
	var side := 1.0 if (from - at).dot(Vector2(_right.x, _right.z)) >= 0.0 else -1.0
	_pet = {"kid": r.id, "dog": int(dg["id"]), "ph": 0, "t": 0.0, "at": at, "side": side}
	_rank.erase(int(dg["id"]))


func _end_pet(rest: bool) -> void:
	if _pet.is_empty():
		return
	_pet = {}
	if rest:
		_pet_next = _clock + PET_REST


func _dog(id: int) -> Dictionary:
	for dg: Dictionary in v.dogs.list:
		if int(dg["id"]) == id:
			return dg
	return {}


## 쓰다듬는 아이의 몸짓 (VillageView._sync_residents가 tick 전에 부름): 강아지 쪽을 보고, 쓰다듬는 동안 그쪽으로 몸을 숙임 (인형 통째)
func pose(r: Resident, m: ResidentModel) -> void:
	var mine := not _pet.is_empty() and int(_pet["kid"]) == r.id
	if not mine:
		if _pet_warp == r.id:
			_pet_warp = -1
			var c0 := m as CutoutResident
			if c0 != null:
				c0.set_body_warp()
		return
	var s: S = _st.get(int(_pet["dog"]))
	if s == null:
		return
	var d := Vector3(s.pos.x - m.position.x, 0.0, s.pos.y - m.position.z)
	if d.length() > 0.05:
		m.rotation.y = lerp_angle(m.rotation.y, atan2(d.x, d.z), 0.25)
	var cm := m as CutoutResident
	if cm == null:
		return
	if int(_pet["ph"]) == 1:
		var t := float(_pet["t"])
		var w := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(PET_SECS - 0.35, PET_SECS, t))
		var side := signf(d.dot(_right)) if absf(d.dot(_right)) > 0.01 else float(_pet["side"])
		cm.set_body_warp(lerpf(1.0, 0.93, w), 1.0, PET_LEAN * side * w * (0.86 + 0.14 * sin(_clock * 9.0)))      # 숙인 채 손을 쓱쓱
		_pet_warp = r.id
	elif _pet_warp == r.id:
		_pet_warp = -1
		cm.set_body_warp()
