## 마을의 삶 화면 (ROADMAP E2 · EVENTS_STAGING 6e) — sim/social.gd가 쌓은 장면을 현실 시간으로 펼친다.
## 장면 = 두세 사람이 마주 서서 말풍선을 번갈아 (LINE_REAL초씩) + 몸짓·표정 + 소품 (꽃잎 한 장 · 혼례 꽃잎 비).
## 화면만의 작은 장면도 (시뮬레이션은 그대로): 저녁 모닥불 노래와 손뼉 · 아이들 술래잡기 · 노인 둘의 옛이야기 · 거대한 꽃을 올려다봄.
## 한꺼번에 MAX_SCENES개까지, 빠른 흐름(vw.fast)·따라잡기·stage_on 꺼짐(보통보다 빠름)일 때는 아무것도 하지 않는다.
## 시뮬은 지켜봄·연출과 무관하게 늘 '멈춰 서서 이야기'를 넣는다 (ADR-0001 3절) — 여기는 보여 주기만. 멈춤(병 초)이 끝나 걸어가도 말풍선은 남는다 (village-life-min 열린 질문 1 권장안).
## VillageView가 만든다: sync(dt) 매 화면 → pose(r, m)로 모델의 방향·동작·표정·자리를 덮어씀 → after_tick(r, m) 고개 들기.
## 말풍선은 test_village._bubbles_of가 say_of(id)로 그린다 (기분 = 색·작은 그림).
class_name SocialStage
extends Node3D

const MAX_SCENES := 3
const VIGNETTE_EVERY := Vector2(5.0, 11.0)   # 화면 장면을 살피는 간격 (현실 초)
const BLEND := 0.35
# (Q2-d) 듣는 이의 끄덕임 — 인형 전체를 말하는 이 쪽으로 살짝 숙였다 폄 (새 그림 없이: 주민 그림이 바뀌어도 그대로)
const NOD_AT := [0.3, 0.62]                  # 한 줄(Social.LINE_REAL) 안에서 끄덕이는 때 (0~1)
const NOD_W := 0.13                          # 끄덕임 하나의 반 너비 (0~1)
const NOD_LEAN := 0.1                        # 숙이는 기울임 (rad)
const NOD_SQ := 0.07                         # 숙이며 눌리는 만큼
const NOD_HOP := 0.07                        # 반가운 말(환호·사랑)을 들으면 끄덕임 대신 작게 폴짝 (세계)
const HOP_MOODS := ["cheer", "love"]
const SAME_ALT := {"sulk": "sulk", "song": "vignette/song"}    # 같은 말이 잇달아 나올 때 바꿔 쓸 말 묶음 (장면 종류 → Social.pool 길)

var v: Village
var vw: Node3D
var scenes: Array = []                # {ev, t, dur, poses: {id: {...}}, nodes: []}
var _says := {}                       # id → [말, 기분]
var _poses := {}                      # id → {rot?, look_at?, anim?, face?, off?: Vector3, w: 0~1, tilt?}
var _next_v := 3.0
var _rng := RandomNumberGenerator.new()
var _sing_t := -100.0                 # 마지막 모닥불 노래 (현실 초)
var _clock := 0.0
var n_played := 0                     # 시험·캡처: 펼친 장면 수
var _nodded := {}                     # (Q2-d) 끄덕이느라 몸을 숙여 둔 인형 id → true (장면이 끝나면 되돌림)
var stage_on := true                  # 화면이 장면을 펼치나 (test_village가 빠르기에 따라 — 화면 상태, 시뮬은 읽지 않음)


func _init(village: Village, view: Node3D) -> void:
	v = village
	vw = view
	_rng.seed = 4242


func say_of(id: int) -> Array:
	return _says.get(id, [])


func busy(id: int) -> bool:
	return _poses.has(id)


## (E2-1 2차) 그 사람이 지금 펼쳐진 장면의 종류 ("" = 없음 — court · old_walk · vignette …) — 하루의 흐름이 같은 저녁에 산책을 두 번 그리지 않게
func scene_kind(id: int) -> String:
	for sc: Dictionary in scenes:
		if id in sc["ev"]["who"]:
			return String(sc["ev"]["kind"])
	return ""


## (E2-1 2차) 하루의 흐름(DailyView)이 쥐고 있는 사람인가 — 장면 중 + 제자리로 돌아가는 중. 그런 사람은 화면 장면에 고르지 않는다
func _daily_holds(id: int) -> bool:
	return vw != null and vw.has_meta(&"daily_view") and (vw.get_meta(&"daily_view") as DailyView).holding(id)


# ───────────────────────── 매 화면 ─────────────────────────
func sync(dt: float, fast: bool) -> void:
	_clock += dt
	_says.clear()
	_poses.clear()
	if fast or not stage_on or not v.is_watching():
		Social.take_events(v)          # 빠른 흐름 중 쌓인 것은 버린다 (말은 관계 값으로 이미 남음)
		_clear_all()
		_unnod_all()
		return
	for ev: Dictionary in Social.take_events(v):
		if float(ev.get("t", v.t)) + float(ev.get("secs", 0.0)) + Balance.HOUR < v.t:
			continue                   # 오래전 (따라잡기·불러오기 전) 만남 — 펼치지 않음
		if scenes.size() >= MAX_SCENES + 1 and String(ev["kind"]) != "wedding":
			continue
		if String(ev["kind"]) != "wedding" and _any_in_scene(ev["who"]):
			continue                   # (Q2-d) 이미 이야기 중인 사람 — 한 사람 머리 위에 두 장면의 말이 겹쳐 뜨지 않게 (말은 관계 값으로 이미 남음)
		if String(ev["kind"]) != "wedding" and _any_in_story(ev["who"]):
			continue                   # (Q2-b) 저녁 이야기 자리의 어르신·아이들 — 그 자리의 말은 이야기 그림뿐 (말은 관계 값으로 이미 남음)
		start(ev)
	_next_v -= dt
	if _next_v <= 0.0:
		_next_v = _rng.randf_range(VIGNETTE_EVERY.x, VIGNETTE_EVERY.y)
		if scenes.size() < MAX_SCENES:
			_try_vignette()
	var keep: Array = []
	for sc: Dictionary in scenes:
		sc["t"] = float(sc["t"]) + dt
		if float(sc["t"]) > float(sc["dur"]) or not _alive(sc) or (String(sc["ev"]["kind"]) != "wedding" and _any_in_story(sc["ev"]["who"])):
			_end(sc)                   # (Q2-b) 말하던 사람이 저녁 이야기 자리에 끼면 그 장면은 접음
			continue
		_play(sc)
		keep.append(sc)
	scenes = keep


func _alive(sc: Dictionary) -> bool:
	for id: int in sc["ev"]["who"]:
		var r := v.person(id)
		if r == null or r.dead:
			return false
	return true


## (Q2-b) 그 사람들 가운데 누가 벌어진 저녁 이야기 자리에 있나 (어르신·둘러앉은 아이·오는 길인 아이)
func _any_in_story(who: Array) -> bool:
	for id: Variant in who:
		if ChildPlay.in_story(v, int(id)):
			return true
	return false


## 그 사람들 가운데 누가 지금 펼쳐지는 장면에 있나
func _any_in_scene(who: Array) -> bool:
	for sc: Dictionary in scenes:
		for id: Variant in sc["ev"]["who"]:
			if who.has(id):
				return true
	return false


func _clear_all() -> void:
	for sc: Dictionary in scenes:
		_end(sc)
	scenes.clear()


## 장면 하나 시작 (시험·캡처가 직접 부를 수 있다)
func start(ev: Dictionary) -> Dictionary:
	var alt: Array = Social.pool(String(SAME_ALT.get(String(ev.get("vig", ev["kind"])), "")))
	var fixed := distinct_lines(ev["lines"], alt)       # (Q2-d) 같은 말이 잇달아 뜨지 않게 — 화면에 띄울 줄만 (시뮬의 기록·관계 값은 그대로)
	if fixed != ev["lines"]:
		ev = ev.duplicate()
		ev["lines"] = fixed
	var n := (ev["lines"] as Array).size()
	var walk := 4.0 if bool(ev.get("walk", false)) else 0.0
	var sc := {"ev": ev, "t": 0.0, "dur": walk + n * Social.LINE_REAL + 1.2, "walk": walk, "nodes": [], "flower": null}
	if String(ev["kind"]) == "wedding":
		sc["dur"] = float(sc["dur"]) + 2.5
	if String(ev.get("flower", "")) != "" and String(ev["kind"]) in ["flower", "confess", "reject", "makeup"]:
		sc["flower"] = _flower_node()
		add_child(sc["flower"])
		sc["nodes"].append(sc["flower"])
	if bool(ev.get("petals", false)):
		var pt := _petals()
		add_child(pt)
		sc["nodes"].append(pt)
		sc["petals"] = pt
	scenes.append(sc)
	n_played += 1
	return sc


## (Q2-d) 바로 앞 줄과 글이 같은 줄은 다른 말로: alt(같은 묶음의 말들)에서 앞·뒤 줄과 다른 첫째, 없으면 말없음표. 순수 함수 (시험)
static func distinct_lines(ls: Array, alt: Array) -> Array:
	var out: Array = []
	var changed := false
	for i in ls.size():
		var l: Array = ls[i]
		var prev := String(out[i - 1][1]) if i > 0 else ""
		if i == 0 or String(l[1]) != prev:
			out.append(l)
			continue
		var next := String(ls[i + 1][1]) if i + 1 < ls.size() else ""
		var pick := ""
		for a: Variant in alt:
			if String(a) != prev and String(a) != next:
				pick = String(a)
				break
		if pick == "":
			pick = "……" if prev != "……" else "…"
		var nl := l.duplicate()
		nl[1] = pick
		out.append(nl)
		changed = true
	return out if changed else ls


## (Q2-d) 한 줄 안의 때 u(0~1)에서 끄덕임 세기 0~1 — NOD_AT마다 한 번씩 부드럽게. 순수 함수 (시험)
static func nod_at(u: float) -> float:
	var k := 0.0
	for c: float in NOD_AT:
		var x := absf(u - c) / NOD_W
		if x < 1.0:
			k = maxf(k, 0.5 + 0.5 * cos(x * PI))
	return k


func _unnod(id: int) -> void:
	_nodded.erase(id)
	var rs: Variant = vw.get("residents") if vw != null else null
	if rs is Dictionary:
		var cm := (rs as Dictionary).get(id) as CutoutResident
		if cm != null and is_instance_valid(cm):
			cm.set_body_warp()
			cm.set_body_lift(0.0)


func _unnod_all() -> void:
	for id: int in _nodded.keys():
		_unnod(id)


## 듣는 이의 몸짓을 자세에 얹음: 말하는 이(sp) 쪽으로 끄덕, 반가운 말이면 폴짝
func _listen(p: Dictionary, sp: Resident, lt: float, mood: String) -> Dictionary:
	p["nod"] = lt / Social.LINE_REAL
	p["nod_to"] = Vector2(sp.x, sp.y)
	p["nod_hop"] = mood in HOP_MOODS
	return p


func _end(sc: Dictionary) -> void:
	for nd: Node in sc["nodes"]:
		if is_instance_valid(nd):
			nd.queue_free()
	sc["nodes"] = []


# ───────────────────────── 장면 펼치기 ─────────────────────────
## 장면 안 어디쯤: 몇째 줄 (−1 = 걸어가는 중 · 끝난 뒤 = n)
func _line_at(sc: Dictionary) -> int:
	var t := float(sc["t"]) - float(sc["walk"])
	if t < 0.0:
		return -1
	return int(t / Social.LINE_REAL)


func _play(sc: Dictionary) -> void:
	var ev: Dictionary = sc["ev"]
	var kind := String(ev["kind"])
	var who: Array = ev["who"]
	var ls: Array = ev["lines"]
	var li := _line_at(sc)
	var ppl: Array[Resident] = []
	for id: int in who:
		ppl.append(v.person(id))
	var w := clampf(float(sc["t"]) / BLEND, 0.0, 1.0) * clampf((float(sc["dur"]) - float(sc["t"])) / BLEND, 0.0, 1.0)
	if ev.has("vig"):                   # 화면만의 작은 장면
		var vl := _line_at(sc)
		if vl >= 0 and vl < ls.size() and fposmod(float(sc["t"]), Social.LINE_REAL) < Social.LINE_REAL * 0.92:
			var sp0 := int(ls[vl][0])
			if sp0 < ppl.size():
				_says[ppl[sp0].id] = [String(ls[vl][1]), String(ls[vl][2])]
		_vignette_pose(sc, ppl, vl, w)
		return
	var a := ppl[0]
	var b := ppl[1]
	var standing := a.anim != "walk" and b.anim != "walk"
	if li < 0:
		return                          # 아직 걸어가는 중 — 시뮬레이션 걸음 그대로
	if not standing:                    # 멈춤이 끝나 다시 걸음: 몸짓은 시뮬 걸음 그대로, 말풍선만 머리 위에 남김
		var cw: Array = ls[li] if li < ls.size() else []
		if not cw.is_empty() and fposmod(float(sc["t"]) - float(sc["walk"]), Social.LINE_REAL) < Social.LINE_REAL * 0.92 and int(cw[0]) < ppl.size():
			_says[ppl[int(cw[0])].id] = [String(cw[1]), String(cw[2])]
		return
	var cur: Array = ls[li] if li < ls.size() else []
	var lt := fposmod(float(sc["t"]) - float(sc["walk"]), Social.LINE_REAL)
	if not cur.is_empty() and lt < Social.LINE_REAL * 0.92:
		var sp := int(cur[0])
		if sp < ppl.size():
			_says[ppl[sp].id] = [String(cur[1]), String(cur[2])]
	var center: Vector2 = ev.get("at", Vector2((a.x + b.x) * 0.5, (a.y + b.y) * 0.5))
	match kind:
		"wedding":
			_pose(a, {"look": Vector2(b.x, b.y), "face": "happy", "anim": "idle", "w": w})
			_pose(b, {"look": Vector2(a.x, a.y), "face": "happy", "anim": "idle", "w": w})
			if li >= 2:                 # 서약 뒤엔 둘이 마을 쪽으로 (손뼉 받는 쪽)
				_pose(a, {"look": center + Vector2(0, 3), "face": "happy", "anim": "wave" if li == 2 else "idle", "w": w})
				_pose(b, {"look": center + Vector2(0, 3), "face": "happy", "anim": "idle", "w": w})
			for i in range(2, ppl.size()):
				var g := ppl[i]
				var speaking: bool = not cur.is_empty() and int(cur[0]) == i
				_pose(g, {"look": center, "face": "happy" if li >= 1 else "", "anim": "clap" if li >= 2 and (i + li) % 3 != 0 else "idle", "w": w})
				if speaking:
					_poses[g.id]["face"] = "talking"
			if sc.has("petals"):
				var pt: Node3D = sc["petals"]
				pt.position = _ground(center) + Vector3(0, 1.6 * Style.LEGACY_MODEL_UNIT * 2.0, 0)
				(pt.get_child(0) as CPUParticles3D).emitting = li >= 1
		"quarrel":
			var angry := li < ls.size() - 1
			for i in ppl.size():
				var p := ppl[i]
				var other := b if p == a else a
				if i >= 2:                   # 말리는 이웃: 둘 사이를 봄
					_pose(p, {"look": center, "anim": "chat" if li >= ls.size() - 2 else "idle", "w": w})
					continue
				if angry:
					var talking: bool = not cur.is_empty() and int(cur[0]) == i
					_pose(p, {"look": Vector2(other.x, other.y), "face": "talking" if talking else "surprised", "anim": "chat" if talking else "shift",
						"stomp": talking, "w": w})
				else:                      # 서먹: 고개를 돌림
					_pose(p, {"look": Vector2(p.x, p.y) * 2.0 - Vector2(other.x, other.y), "face": "sad", "anim": "idle", "w": w})
		"sulk":
			_pose(a, {"look": Vector2(a.x, a.y) * 2.0 - Vector2(b.x, b.y), "face": "sad", "anim": "idle", "w": w})
			_pose(b, {"look": Vector2(b.x, b.y) * 2.0 - Vector2(a.x, a.y), "face": "sad", "anim": "idle", "w": w})
		_:
			for i in 2:
				var p := ppl[i]
				var other := b if i == 0 else a
				var talking: bool = not cur.is_empty() and int(cur[0]) == i
				var face := "talking" if talking else ""
				var anim := "chat" if talking else "idle"
				if p.anim == "sit":
					anim = "sit_talk" if talking else "sit"
				if kind in ["confess", "flower", "date", "court", "shy", "makeup", "old_walk"]:
					face = "happy" if not talking else "talking"
				if kind == "reject" and li >= 1:
					face = "sad" if i == 0 else ""
				if kind == "comfort" and i == 0:
					face = "sad"
				if kind == "shy" and i == 0:    # 설렘: 눈을 피함
					_pose(p, {"look": Vector2(p.x, p.y) * 2.0 - Vector2(other.x, other.y) + Vector2(other.y - p.y, p.x - other.x), "face": "happy", "anim": "scratch", "w": w})
					continue
				var dp := {"look": Vector2(other.x, other.y), "face": face, "anim": anim, "w": w}
				if not cur.is_empty() and int(cur[0]) == 1 - i and _says.has(other.id):      # (Q2-d) 듣는 쪽: 말하는 이를 보며 끄덕 (상대가 지금 이 줄을 말할 때만)
					_listen(dp, other, lt, String(cur[2]) if cur.size() > 2 else "")
				_pose(p, dp)
			if sc["flower"] != null:
				_move_flower(sc, a, b, li)


func _pose(r: Resident, p: Dictionary) -> void:
	_poses[r.id] = p


## 모델에 덮어씀 (VillageView._sync_residents가 tick 전에 부름)
func pose(r: Resident, m: ResidentModel) -> void:
	var p: Dictionary = _poses.get(r.id, {})
	if p.is_empty():
		if _nodded.has(r.id):
			_unnod(r.id)
		return
	var w := float(p.get("w", 1.0))
	if p.has("look"):
		var lk: Vector2 = p["look"]
		var to := atan2(lk.x - r.x, lk.y - r.y)
		m.rotation.y = lerp_angle(m.rotation.y, to, w)
	if p.has("off"):
		m.position += (p["off"] as Vector3) * w
	if bool(p.get("stomp", false)):          # 화가 나 발을 구름 (작게 들썩 — 때리지 않음)
		m.position.y += absf(sin(_clock * 11.0)) * 0.05 * w
	if p.has("face") and String(p["face"]) != "":
		m.set_face(String(p["face"]))
	if p.has("anim"):
		m.set_anim(String(p["anim"]), "social_scene")
	var cm := m as CutoutResident
	if cm == null:
		return
	if p.has("nod"):                         # (Q2-d) 듣는 이: 말하는 이 쪽으로 끄덕 (인형 전체 — 멀리서는 크게: TapReact.zoom_gain)
		var k := nod_at(float(p["nod"])) * w
		var to: Vector2 = p["nod_to"]
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		var gain := 1.0
		var side := 1.0
		if cam != null:
			gain = TapReact.zoom_gain(TapReact.px_per_unit(cam, m.global_position))
			side = signf(Vector3(to.x - r.x, 0.0, to.y - r.y).dot(cam.global_transform.basis.x))
			if side == 0.0:
				side = 1.0
		if bool(p["nod_hop"]):
			cm.set_body_warp(1.0 + NOD_SQ * k, 1.0 - NOD_SQ * 0.6 * k, 0.0)
			cm.set_body_lift(NOD_HOP * gain * k / maxf(cm.scale.y, 0.01))
		else:
			cm.set_body_warp(1.0 - NOD_SQ * k * lerpf(1.0, gain, 0.5), 1.0 + NOD_SQ * 0.5 * k, NOD_LEAN * gain * side * k)
			cm.set_body_lift(0.0)
		_nodded[r.id] = true
	elif _nodded.has(r.id):
		_unnod(r.id)


## tick 뒤: 고개 들기 (꽃 올려다보기)
func after_tick(r: Resident, m: ResidentModel) -> void:
	var p: Dictionary = _poses.get(r.id, {})
	if p.has("tilt"):
		var tl: Vector2 = p["tilt"]
		m.tilt_head(tl.x * float(p.get("w", 1.0)), tl.y)


func _ground(p: Vector2) -> Vector3:
	var y := 0.0
	if vw.has_method("gy"):
		y = vw.gy(p.x, p.y)
	return Vector3(p.x, y, p.y)


# ───────────────────────── 꽃잎 한 장 · 꽃잎 비 ─────────────────────────
func _flower_node() -> Node3D:
	var root := Node3D.new()
	var mat := Toon.mat(Color("f39ab4"))     # 공용 툰 재질 (화면 외곽선·빛이 다른 물체와 같게)
	var mid := Toon.mat(Color("f6d24a"))
	var stem := Toon.mat(Color("5c9a3c"))
	var s := Style.LEGACY_MODEL_UNIT
	for i in 5:
		var pm := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09 * s
		sm.height = 0.05 * s
		sm.radial_segments = 8
		sm.rings = 4
		pm.mesh = sm
		pm.material_override = mat
		var a := TAU * float(i) / 5.0
		pm.position = Vector3(cos(a) * 0.1 * s, 0.0, sin(a) * 0.1 * s)
		root.add_child(pm)
	var c := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.06 * s
	cm.height = 0.08 * s
	c.mesh = cm
	c.material_override = mid
	root.add_child(c)
	var st := MeshInstance3D.new()
	var stm := CylinderMesh.new()
	stm.top_radius = 0.03 * s
	stm.bottom_radius = 0.03 * s
	stm.height = 0.45 * s
	st.mesh = stm
	st.material_override = stem
	st.position = Vector3(0, -0.22 * s, 0)
	root.add_child(st)
	root.rotation.x = 0.9             # 꽃 얼굴이 위(카메라) 쪽으로
	root.scale = Vector3.ONE * 3.6
	return root


## 꽃잎을 든 손: 첫 줄은 주는 사람 손에, 다음 줄부터 받는 사람 손에
func _move_flower(sc: Dictionary, a: Resident, b: Resident, li: int) -> void:
	var fl: Node3D = sc["flower"]
	var ma: Node3D = vw.residents.get(a.id)
	var mb: Node3D = vw.residents.get(b.id)
	if ma == null or mb == null:
		return
	var lt := clampf((float(sc["t"]) - float(sc["walk"]) - Social.LINE_REAL * 0.6) / 0.8, 0.0, 1.0)
	var hand := func(m: Node3D) -> Vector3:
		return m.global_transform * Vector3(0.0, 1.25, 0.7)
	var pa: Vector3 = hand.call(ma)
	var pb: Vector3 = hand.call(mb)
	fl.global_position = pa.lerp(pb, lt if li >= 0 else 0.0) + Vector3(0, sin(lt * PI) * 0.12, 0)


func _petals() -> Node3D:
	var root := Node3D.new()
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 2.6
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.1
	p.direction = Vector3(0, -1, 0)
	p.spread = 30.0
	p.gravity = Vector3(0, -0.35, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var qm := QuadMesh.new()
	qm.size = Vector2(0.16, 0.12)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = Color("f7b6c8")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	qm.material = mat
	p.mesh = qm
	var g := Gradient.new()
	g.set_color(0, Color("ffd1dc"))
	g.set_color(1, Color("f490ae"))
	p.color_initial_ramp = g
	root.add_child(p)
	return root


# ───────────────────────── 화면만의 작은 장면 ─────────────────────────
func _try_vignette() -> void:
	var h := v.hour_now()
	var opts: Array = []
	var free: Array[Resident] = []
	for r in v.people:
		if r.sleeping or r.is_baby() or r.anim == "walk" or _in_scene(r.id) or _daily_holds(r.id) or not Social.FREE_ACTS.has(r.action) or ChildPlay.in_story(v, r.id):
			continue                   # (Q2-b) 저녁 이야기 자리의 어르신·아이들은 화면 장면에 뽑지 않는다
		free.append(r)
	# 저녁 모닥불: 앉은 사람 중 하나가 노래, 곁의 둘셋이 손뼉
	if h >= Balance.EVENING_FROM and h < Balance.NIGHT_FROM and _clock - _sing_t > 20.0:
		var sit := free.filter(func(q: Resident) -> bool: return q.anim == "sit" and Vector2(q.x - v.fire.x, q.y - v.fire.y).length() < 4.5)
		if sit.size() >= 2:
			opts.append(["song", sit])
	var kids := free.filter(func(q: Resident) -> bool: return q.is_child() and q.action == "play" and ChildPlay.game_of(v, q.id).is_empty())     # (Q2-b) 놀이(ChildPlay)에 낀 아이는 그 놀이대로
	if kids.size() >= 2:
		var k0: Resident = kids[_rng.randi() % kids.size()]
		var near := kids.filter(func(q: Resident) -> bool: return q != k0 and Vector2(q.x - k0.x, q.y - k0.y).length() < 5.0)
		if not near.is_empty():
			opts.append(["tag", [k0, near[0]]])
	var olds := free.filter(func(q: Resident) -> bool: return q.is_elder() and q.anim == "sit")
	if olds.size() >= 2:
		opts.append(["bench", [olds[0], olds[1]]])
	if not v.trees.is_empty() and not free.is_empty():
		var p0: Resident = free[_rng.randi() % free.size()]
		if p0.anim != "sit":
			for tr: Dictionary in v.trees:
				if String(tr.get("s", "")) == "tree" and Vector2(float(tr["x"]) - p0.x, float(tr["y"]) - p0.y).length() < 3.0:
					opts.append(["admire", [p0], Vector2(float(tr["x"]), float(tr["y"]))])
					break
	if opts.is_empty():
		return
	var o: Array = opts[_rng.randi() % opts.size()]
	vignette(String(o[0]), o[1], o[2] if o.size() > 2 else Vector2.ZERO)


func _in_scene(id: int) -> bool:
	for sc: Dictionary in scenes:
		if id in sc["ev"]["who"]:
			return true
	return false


## 화면 장면 시작 (시험·캡처가 직접 부를 수 있다): song · tag · bench · admire
func vignette(kind: String, ppl: Array, at := Vector2.ZERO) -> Dictionary:
	var ids: Array = []
	for q: Resident in ppl:
		ids.append(q.id)
	var ls: Array = []
	var fl := _season_flower()
	match kind:
		"song":
			_sing_t = _clock
			ids = ids.slice(0, 4)
			ls.append([0, _one("vignette/song"), "song"])
			ls.append([0, _one("vignette/song"), "song"])
			ls.append([1, _one("vignette/song_reply"), "cheer"])
		"tag":
			ls.append([0, "거기 서!", ""])
			ls.append([1, _one("vignette/tag"), ""])
			ls.append([0, "잡았다!", "cheer"])
		"bench":
			var ex: Array = Social.pool("vignette/bench")
			var e: Array = ex[_rng.randi() % ex.size()]
			for i in e.size():
				ls.append([i % 2, String(e[i]), ""])
		"admire":
			ls.append([0, Social.fill(_one("vignette/admire"), {"flower": fl}), ""])
	var ev := {"kind": "vignette", "vig": kind, "who": ids, "lines": ls, "at": at, "flower": "", "walk": false, "t": v.t}
	return start(ev)


func _one(path: String) -> String:
	var p := Social.pool(path)
	return String(p[_rng.randi() % p.size()]) if not p.is_empty() else "…"


func _season_flower() -> String:
	var p := Social.pool("flowers/" + Health.season_of(int(Health.jar_date(v)["month"])))
	return String(p[_rng.randi() % p.size()]) if not p.is_empty() else "꽃"


func _vignette_pose(sc: Dictionary, ppl: Array[Resident], li: int, w: float) -> void:
	var ev: Dictionary = sc["ev"]
	var t := float(sc["t"])
	match String(ev["vig"]):
		"song":
			for i in ppl.size():
				var p := ppl[i]
				if i == 0:
					_pose(p, {"look": v.fire, "face": "happy", "anim": "sit_talk", "w": w})
				else:
					_pose(p, {"look": Vector2(ppl[0].x, ppl[0].y), "face": "happy", "anim": "clap" if li >= 1 else "sit", "w": w})
		"tag":                              # 둘이 작은 원을 그리며 쫓고 쫓김 (자리는 화면만 — 끝나면 제자리)
			var mid := Vector2((ppl[0].x + ppl[1].x) * 0.5, (ppl[0].y + ppl[1].y) * 0.5)
			for i in 2:
				var p := ppl[i]
				var ang := t * 2.2 - float(i) * 0.9
				var target := mid + Vector2(cos(ang), sin(ang)) * 0.9
				var off := Vector3(target.x - p.x, 0.0, target.y - p.y)
				var tang := Vector2(-sin(ang), cos(ang))
				_pose(p, {"off": off, "look": target + tang, "face": "happy", "anim": "run", "w": w})
		"bench":
			_pose(ppl[0], {"look": Vector2(ppl[1].x, ppl[1].y), "face": "happy", "anim": "sit_talk" if li % 2 == 0 else "sit", "w": w})
			_pose(ppl[1], {"look": Vector2(ppl[0].x, ppl[0].y), "face": "happy", "anim": "sit_talk" if li % 2 == 1 else "sit", "w": w})
			var ls: Array = ev["lines"]
			if li >= 0 and li < ls.size():                   # (Q2-d) 듣는 쪽이 끄덕
				var sp := li % 2
				if _says.has(ppl[sp].id):
					_listen(_poses[ppl[1 - sp].id], ppl[sp], fposmod(t, Social.LINE_REAL), String(ls[li][2]) if (ls[li] as Array).size() > 2 else "")
		"admire":
			var at: Vector2 = ev["at"]
			_pose(ppl[0], {"look": at, "face": "happy", "anim": "look" if li < 0 else "idle", "tilt": Vector2(0.55, 0.12), "w": w})
