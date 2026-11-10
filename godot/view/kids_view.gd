## 아이·아기가 사는 모습 (ROADMAP Q2-b 귀여움 묶음 ② — E2-2 · E2-3, GAME_DESIGN 기둥 0). 화면만 — 시뮬레이션은 sim/child_play.gd.
## 여기서는 저장된 놀이 상태(Village.kids)와 사건(kid_tagged · kid_stack_fell · kid_play_started · baby_peeked · first_steps)을 읽어
##   · 놀이 속 아이의 화면 자리 (ChildPlay.spot — 놀이 시계의 순수 함수) + 인형 통째 몸짓 (폴짝 · 눌림 · 기울임) + 그림 말풍선
##   · 작은 소품 그림 (돌탑 · 나비 · 먼지 · 요람 — art/kids2d/kids_props.png, tools/kids/make_props.py가 그림)
##   · 아기: 문 옆 요람(2D 바구니) · 들여다보는 이웃 · 걸음마 아기의 아장아장·털썩
## 을 보여 준다. 시뮬레이션 값(자리·하는 일·난수)은 건드리지 않는다 (ADR-0001). 새 인형 동작(rig clip)은 없다.
## 값을 싸게: 아이마다 상태 하나를 한 번만 만들고, 매 화면에는 숫자 계산과 바뀐 instance uniform만.
class_name KidsView
extends Node3D

const ATLAS := Vector2i(512, 256)
const PICS := {"cradle_back": Rect2i(0, 0, 176, 112), "cradle_front": Rect2i(176, 0, 176, 112), "stone_a": Rect2i(0, 128, 72, 56),
	"stone_b": Rect2i(72, 128, 72, 56), "stone_c": Rect2i(144, 128, 72, 56), "butterfly": Rect2i(352, 0, 96, 80), "puff": Rect2i(216, 128, 72, 56)}
const ATLAS_PATH := "res://art/kids2d/kids_props.png"
const SHADER_PATH := "res://view/kids/kid_card.gdshader"
## 화면 말풍선 (시뮬레이션 말이 아님 — VillageView.stage_say). 주민의 말 규칙(CLAUDE.md 1장)을 따른다 — tests/kids_tests가 살핌
const SAY := {
	"tag_it": ["잡았다!", "잡았지!"],
	"tag_caught": ["꺄!", "앗!", "으앗!"],
	"tag_run": ["꺄아!", "못 잡지!", "이리 와 봐!"],
	"bfly": ["나비다!", "기다려!", "잡을 거야!"],
	"stack_wob": ["어어…", "살살!"],
	"stack_fell": ["와르르!", "아이쿠!"],
	"stack_again": ["다시!", "한 번 더!"],
	"peek": ["까꿍!", "아이, 예뻐라.", "잘 잤니?"],
	"baby": ["까르르", "꺄아", "아부부"],
	"plop": ["에헤헤", "아부"],
	"first": ["걸었다!", "어머, 걸었어!"],
}
const JOIN_SECS := 0.7            # 놀이 자리로 섞여 들어가는 시간 (현실 초)
const LEAVE_SECS := 0.45
const RUN_LEGS := 1.2             # 달리는 아이의 다리 빠르기 상한 (칸/초 — 넘으면 인형이 '멈춘 보폭'이 됨)
const HOP_SECS := 0.42
const HOP_H := 0.2
const STONE_W := 0.25
const STONE_PITCH := 0.088
const STONE_PICS := ["stone_a", "stone_b", "stone_c"]
const BFLY_W := 0.27
const CRADLE_W := 0.6
const CRADLE_RIM := 0.607         # 바구니 테두리 가운데 높이 (그림 높이의 비율 — make_props RIM)
const PUFF_W := 0.3
const PUFF_SECS := 0.55
const FALL_SECS := 2.3
const TODDLE_START := 0.46        # 부모와 이만큼 벌어지면 따라나섬 (칸) — 조금 늦게
const TODDLE_STOP := 0.12
const TODDLE_SPEED := Vector2(0.3, 1.0)
const PLOP_SECS := 1.35
const PLOP_EVERY := Vector2(4.5, 9.0)     # 걷다가 털썩 주저앉기까지 (현실 초)

var v: Village
var vw: VillageView               # residents · gy · stage_say
var _mat: ShaderMaterial
var _quad: QuadMesh
var _cursor := 0
var _clock := 0.0
var _frame := 0
var _said := 0
var _cu := 0.7
var _right := Vector3.RIGHT
var _was_fast := false
var _kid := {}                    # 주민 id → Kid
var _props := {}                  # 놀이 id → Props
var _baby := {}                   # 아기 id → Baby
var _peek := {}                   # 들여다보는 사람 id → Peek
var _puffs: Array[MeshInstance3D] = []
var _puff_t := PackedFloat32Array()
var _puff_i := 0


class Kid extends RefCounted:
	var g: Dictionary = {}
	var i := -1
	var seen := -1
	var w := 0.0
	var spot := Vector2.ZERO
	var pos := Vector2.ZERO
	var has := false
	var sp := 0.0
	var yaw := 0.0
	var ph := 0.0
	var hop_t := -1.0
	var said := -1


class Props extends RefCounted:
	var stones: Array[MeshInstance3D] = []
	var bfly: MeshInstance3D
	var h := 0
	var pop_t := 9.0
	var fall_t := -1.0
	var fall_h := 0
	var said := -1


class Baby extends RefCounted:
	var back: MeshInstance3D
	var front: MeshInstance3D
	var pos := Vector2.ZERO
	var has := false
	var moving := false
	var sp := 0.0
	var yaw := 0.0
	var walked := 0.0
	var next_plop := 6.0
	var plop_t := -1.0
	var wander := Vector2.ZERO
	var wander_t := 0.0
	var gig_t := -1.0
	var hop_t := -1.0
	var seen := -1


class Peek extends RefCounted:
	var baby := -1
	var said := false


func _init(village: Village = null, view: VillageView = null) -> void:
	v = village
	vw = view
	if v != null:
		_cursor = v.events.clear_to_end()


## 소품 그림판 (한 장 — 엔진이 한 번만 읽어 나눠 씀)
static func atlas() -> Texture2D:
	return load(ATLAS_PATH) as Texture2D


static func uv_of(pic: String) -> Vector4:
	var rc: Rect2i = PICS[pic]
	return Vector4(float(rc.position.x) / ATLAS.x, float(rc.position.y) / ATLAS.y, float(rc.size.x) / ATLAS.x, float(rc.size.y) / ATLAS.y)


static func pic_h(pic: String, w: float) -> float:
	var rc: Rect2i = PICS[pic]
	return w * float(rc.size.y) / float(rc.size.x)


func _card(pic: String) -> MeshInstance3D:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load(SHADER_PATH)
		_mat.set_shader_parameter("tex", atlas())
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var n := MeshInstance3D.new()
	n.mesh = _quad
	n.material_override = _mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.extra_cull_margin = 1.0
	n.visible = false
	add_child(n)
	n.set_instance_shader_parameter("rect", uv_of(pic))
	return n


## 그림 한 장 놓기: at = 밑(또는 가운데) 자리, w = 너비, rot = 기울임, depth = 카메라 쪽으로, lift = 화면 높이만큼 위로
func _put(n: MeshInstance3D, pic: String, at: Vector3, w: float, rot := 0.0, depth := 0.0, sx := 1.0, sy := 1.0, anchor := 0.0, lift := 0.0) -> void:
	n.visible = true
	n.position = at
	n.set_instance_shader_parameter("geo", Vector4(w, pic_h(pic, w), rot, depth))
	n.set_instance_shader_parameter("fx", Vector4(sx, sy, anchor, lift))


func _gy(x: float, z: float) -> float:
	return vw.gy(x, z) if vw != null else 0.0


static func _h01(a: int, b: int) -> float:
	var h := a * 0x9E3779B1 + b * 0x85EBCA77 + 0x27D4EB2F
	h = (h ^ (h >> 15)) * 0x2C1B3C6D
	h = h ^ (h >> 13)
	return float(h & 0xFFFF) / 65536.0


func _say(id: int, key: String, mood: String, secs: float) -> void:
	if vw == null or id < 0 or vw.stage_say.has(id):
		return
	var opts: Array = SAY[key]
	_said += 1
	vw.stage_say[id] = [String(opts[(_said * 7 + id) % opts.size()]), mood, secs]


func _puff(at: Vector3) -> void:
	if _puffs.size() < 4:
		_puffs.append(_card("puff"))
		_puff_t.append(-1.0)
		_puff_i = _puffs.size() - 1
	else:
		_puff_i = (_puff_i + 1) % _puffs.size()
	_puffs[_puff_i].position = at
	_puff_t[_puff_i] = 0.0


func _warp_reset(id: int) -> void:
	var cm := vw.residents.get(id) as CutoutResident
	if cm != null and is_instance_valid(cm):
		cm.set_body_warp()
		if cm.doll != null:
			cm.set_body_lift(0.0)


# ───────────────────────── 매 화면: 앞 (주민을 놓기 전) ─────────────────────────
func begin(dt: float, fast: bool) -> void:
	if v == null or vw == null:
		return
	_frame += 1
	_clock += dt
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var bs := cam.global_transform.basis
		_cu = maxf(bs.y.y, 0.3)
		var rx := Vector3(bs.x.x, 0.0, bs.x.z)
		if rx.length_squared() > 1.0e-6:
			_right = rx.normalized()
	if fast != _was_fast:
		_was_fast = fast
		if fast:                               # 빠른 흐름: 몸짓을 멈추고 시뮬 자리로 (소품만 그대로)
			for id: int in _kid.keys():
				_warp_reset(id)
			_kid.clear()
			for id: int in _peek.keys():
				_warp_reset(id)
			_peek.clear()
	_events(fast)
	var gs: Array = v.kids.get("g", [])
	for g: Dictionary in gs:
		var who: Array = g["who"]
		var on: Array = g["on"]
		if not fast:
			for i in who.size():
				if int(on[i]) == 0:
					continue
				var id := int(who[i])
				var k: Kid = _kid.get(id)
				if k == null:
					k = Kid.new()
					k.ph = _h01(id, 5) * TAU
					_kid[id] = k
				k.g = g
				k.i = i
				k.seen = _frame
		_props_tick(g, dt)
	if _props.size() > gs.size():
		for gid: int in _props.keys():
			var alive := false
			for g: Dictionary in gs:
				if int(g["id"]) == gid:
					alive = true
			if not alive:
				var pr: Props = _props[gid]
				for s: MeshInstance3D in pr.stones:
					s.queue_free()
				if pr.bfly != null:
					pr.bfly.queue_free()
				_props.erase(gid)
	for i in _puffs.size():
		var t := _puff_t[i]
		if t < 0.0:
			continue
		t += dt
		if t >= PUFF_SECS:
			_puff_t[i] = -1.0
			_puffs[i].visible = false
			continue
		_puff_t[i] = t
		var u := t / PUFF_SECS
		var s := (0.55 + 0.75 * u) * (1.0 if u < 0.7 else 1.0 - (u - 0.7) / 0.3)
		_put(_puffs[i], "puff", _puffs[i].position, PUFF_W, 0.0, 0.09, s, s, 1.0, 0.07 + 0.1 * u)
	if _frame % 240 == 0:                      # 사라진 사람의 상태 치우기 (가끔)
		for id: int in _kid.keys():
			if v.person(id) == null:
				_kid.erase(id)
		for id: int in _baby.keys():
			if (_baby[id] as Baby).seen < _frame - 240:
				_free_baby(id)


func _events(fast: bool) -> void:
	if v.events.serial == _cursor:
		return
	var evs := v.events.since(_cursor)
	_cursor = v.events.serial
	if fast:
		return
	for e: Dictionary in evs:
		var kind: StringName = e["kind"]
		if kind == &"kid_tagged":
			var d: Dictionary = e["v"]
			var k: Kid = _kid.get(int(e["who"]))
			if k != null:
				k.hop_t = 0.0
			_say(int(d["by"]), "tag_it", "cheer", 1.6)
			_say(int(e["who"]), "tag_caught", "", 1.2)
		elif kind == &"kid_stack_fell":
			var d: Dictionary = e["v"]
			var pr: Props = _props.get(int(d["game"]))
			if pr != null:
				pr.fall_t = 0.0
				pr.fall_h = int(d["h"])
				pr.h = 0
			var at: Vector2 = e["at"]
			_puff(Vector3(at.x, _gy(at.x, at.y), at.y))
			var first := true
			for id: int in _kid:
				var k: Kid = _kid[id]
				if k.seen >= _frame - 1 and int(k.g.get("id", -1)) == int(d["game"]):
					k.hop_t = 0.0
					if first or id == int(e["who"]):
						_say(id, "stack_fell", "cheer" if first else "sad", 1.8)
					first = false
		elif kind == &"kid_play_started":
			var d: Dictionary = e["v"]
			if String(d["kind"]) == "bfly":
				_say(int(e["who"]), "bfly", "cheer", 2.0)
		elif kind == &"baby_peeked":
			var d: Dictionary = e["v"]
			var p := Peek.new()
			p.baby = int(d["baby"])
			_peek[int(e["who"])] = p
		elif kind == &"first_steps":
			var d: Dictionary = e["v"]
			var b: Baby = _baby.get(int(e["who"]))
			if b != null:
				b.hop_t = 0.0
			_say(int(d["with"]), "first", "love", 2.6)
			_say(int(e["who"]), "baby", "cheer", 2.0)


# ───────────────────────── 소품: 돌탑 · 나비 ─────────────────────────
func _props_tick(g: Dictionary, dt: float) -> void:
	var gid := int(g["id"])
	var pr: Props = _props.get(gid)
	if pr == null:
		pr = Props.new()
		_props[gid] = pr
	var kind := String(g["kind"])
	var c := float(g["c"])
	var n_on := 0
	for o: Variant in g["on"]:
		n_on += int(o)
	# 나비
	if kind == "bfly" and n_on > 0:
		if pr.bfly == null:
			pr.bfly = _card("butterfly")
		var b := ChildPlay.bfly_at(g, c)
		var flap := 0.22 + 0.78 * absf(sin(_clock * 15.0))
		_put(pr.bfly, "butterfly", Vector3(b.x, _gy(b.x, b.y), b.y), BFLY_W, sin(_clock * 2.3) * 0.28, 0.1, flap, 1.0, 1.0,
			0.5 + 0.09 * sin(_clock * 3.1 + float(gid)))
	elif pr.bfly != null:
		pr.bfly.visible = false
	# 돌탑
	if kind != "stack":
		for s: MeshInstance3D in pr.stones:
			s.visible = false
		pr.h = 0
		pr.fall_t = -1.0
		return
	while pr.stones.size() < ChildPlay.STACK_MAX + 1:
		pr.stones.append(_card(STONE_PICS[pr.stones.size() % 3]))
	var base := Vector3(float(g["x"]), _gy(float(g["x"]), float(g["y"])), float(g["y"]))
	var h := int(g["h"])
	var ph := int(g["ph"])
	if h > pr.h:
		pr.pop_t = 0.0
	elif h < pr.h and pr.fall_t < 0.0:         # (사건을 놓쳤을 때도) 무너짐
		pr.fall_t = 0.0
		pr.fall_h = pr.h
	pr.h = h
	pr.pop_t += dt
	if pr.fall_t >= 0.0:
		pr.fall_t += dt
		if pr.fall_t >= FALL_SECS or h > 0:
			pr.fall_t = -1.0
	var sway := sin(_clock * 8.5) if ph == 1 else 0.0
	if ph == 1 and pr.said != int(g["falls"]):
		pr.said = int(g["falls"])
		_say(int(g["turn"]), "stack_wob", "", 1.3)
	for i in pr.stones.size():
		var s := pr.stones[i]
		var pic: String = STONE_PICS[i % 3]
		var jx := (_h01(gid * 13 + i, 3) - 0.5) * 0.05
		if pr.fall_t >= 0.0:
			if i >= pr.fall_h:
				s.visible = false
				continue
			# 와르르: 돌마다 옆으로 튀어 포물선 → 땅에 구르다 작아져 사라짐
			var vx := (_h01(gid * 17 + i, 7) - 0.5) * 2.0 + (0.35 if i % 2 == 0 else -0.35)
			var vy := 0.7 + _h01(gid * 19 + i, 9) * 0.7
			var y0 := float(i) * STONE_PITCH
			var t_land := (vy + sqrt(vy * vy + 2.0 * 5.0 * y0)) / 5.0
			var t := minf(pr.fall_t, t_land)
			var y := maxf(y0 + vy * t - 2.5 * t * t, 0.0)
			var x := jx + vx * t + (vx * 0.25 * minf(pr.fall_t - t_land, 0.5) if pr.fall_t > t_land else 0.0)
			var k := clampf((FALL_SECS - pr.fall_t) / 0.5, 0.0, 1.0)
			if k <= 0.0:
				s.visible = false
				continue
			_put(s, pic, base + _right * x, STONE_W, vx * 3.0 * t, 0.02 + 0.004 * i, k, k, 0.0, y)
		elif i < h:
			var pop := 1.0 + (0.35 * (1.0 - pr.pop_t / 0.22) if i == h - 1 and pr.pop_t < 0.22 else 0.0)
			_put(s, pic, base + _right * (jx + sway * 0.011 * float(i + 1)), STONE_W, sway * 0.07 * float(i) / 3.0, 0.02 + 0.004 * i,
				pop, 2.0 - pop if pop > 1.0 else 1.0, 0.0, float(i) * STONE_PITCH)
		elif i == h and ph == 0 and n_on > 0:
			# 차례인 아이가 들고 와 얹는 돌
			var tk: Kid = _kid.get(int(g["turn"]))
			var u := clampf((c - float(g["hs"])) / ChildPlay.STACK_PLACE, 0.0, 1.0)
			if tk == null or not tk.has or u < 0.2 or h >= ChildPlay.STACK_MAX:
				s.visible = false
				continue
			var from := Vector3(tk.pos.x, _gy(tk.pos.x, tk.pos.y), tk.pos.y)
			var e := smoothstep(0.5, 0.97, u)
			_put(s, pic, from.lerp(base + _right * jx, e), STONE_W, 0.0, 0.06, 1.0, 1.0, 0.0, lerpf(0.2, float(i) * STONE_PITCH, e) + 0.1 * sin(e * PI))
		else:
			s.visible = false


# ───────────────────────── 매 화면: 놀이 속 아이 (주민마다, social.pose 뒤) ─────────────────────────
func pose(r: Resident, m: ResidentModel, dt: float) -> void:
	var k: Kid = _kid.get(r.id)
	if k == null:
		if not _peek.is_empty() and _peek.has(r.id):
			_peek_pose(r, m)
		return
	var here := k.seen == _frame
	k.w = move_toward(k.w, 1.0 if here else 0.0, dt / (JOIN_SECS if here else LEAVE_SECS))
	var cm := m as CutoutResident
	if not here and k.w <= 0.0:
		if cm != null:
			cm.set_body_warp()
			cm.set_body_lift(0.0)
		_kid.erase(r.id)
		return
	var g := k.g
	var c := float(g["c"])
	var kind := String(g["kind"])
	if here:
		k.spot = ChildPlay.spot(g, k.i, c)
	var e := k.w * k.w * (3.0 - 2.0 * k.w)
	var p := Vector2(m.position.x, m.position.z).lerp(k.spot, e)
	if not k.has:
		k.has = true
		k.pos = p
		k.yaw = m.rotation.y
	if dt > 0.0:
		var d := p - k.pos
		var sp := d.length() / dt
		k.sp = lerpf(k.sp, minf(sp, 3.0), clampf(dt * 10.0, 0.0, 1.0))
		if sp > 0.15:
			k.yaw = lerp_angle(k.yaw, atan2(d.x, d.y), clampf(dt * 14.0, 0.0, 1.0))
	k.pos = p
	var moving := k.sp > 0.22
	var anim := "walk" if moving else "idle"
	var hop := 0.0
	var look := Vector2.INF                    # 서 있을 때 바라볼 곳
	if here:
		match kind:
			"tag":
				var it := int(g["it"])
				var u := c - float(g["rs"])
				if moving:
					hop = absf(sin(_clock * 11.0 + k.ph)) * 0.04
				if it == r.id:
					if u < ChildPlay.TAG_PAUSE:    # 술래: 잠깐 서서 들썩이다 쫓음
						hop = absf(sin(_clock * 9.0)) * 0.035
						var rk: Kid = _kid.get(int(g["run"]))
						if rk != null and rk.has:
							look = rk.pos
				elif it >= 0:
					if not moving:
						var ik: Kid = _kid.get(it)
						if ik != null and ik.has:
							look = ik.pos
					if int(g["run"]) == r.id and k.said != int(g["tags"]) and u > ChildPlay.TAG_PAUSE + float(g["rt"]) * 0.5:
						k.said = int(g["tags"])
						if int(g["tags"]) % 2 == 0:
							_say(r.id, "tag_run", "", 1.2)
			"bfly":
				var b := ChildPlay.bfly_at(g, c)
				var near := (b - p).length()
				if near < 0.75:                    # 나비 가까이: 폴짝폴짝 손 뻗기
					hop = absf(sin(_clock * 8.0 + k.ph)) * 0.075
				elif moving:
					hop = absf(sin(_clock * 11.0 + k.ph)) * 0.03
				if not moving:
					look = b
				if k.said != int(c / 1700.0) and int(g["sl"][k.i]) == int(c / 1700.0) % 4:
					k.said = int(c / 1700.0)
					if k.said % 2 == 1:
						_say(r.id, "bfly", "", 1.4)
			"stack":
				look = Vector2(float(g["x"]), float(g["y"]))
				if not moving:
					var mine := int(g["turn"]) == r.id and int(g["ph"]) == 0
					var u := (c - float(g["hs"])) / ChildPlay.STACK_PLACE
					anim = "gather" if mine and u > 0.5 else "sit"
				if int(g["ph"]) == 2 and k.said != -2 - int(g["falls"]) and c - float(g["hs"]) > ChildPlay.STACK_DOWN * 0.6:
					k.said = -2 - int(g["falls"])
					if int(g["sl"][k.i]) == int(g["falls"]) % 4:
						_say(r.id, "stack_again", "cheer", 1.4)
	if look != Vector2.INF and not moving and dt > 0.0:
		k.yaw = lerp_angle(k.yaw, atan2(look.x - p.x, look.y - p.y), clampf(dt * 8.0, 0.0, 1.0))
	var sy := 1.0
	var sx := 1.0
	if k.hop_t >= 0.0:                         # 잡혔다! · 와르르! — 크게 폴짝, 내려앉으며 눌림
		k.hop_t += dt
		var t := k.hop_t / HOP_SECS
		if t < 1.0:
			hop += HOP_H * 4.0 * t * (1.0 - t)
			sy = 1.0 + 0.1 * sin(t * PI)
			sx = 1.0 - 0.07 * sin(t * PI)
		elif t < 1.45:
			var q := sin((t - 1.0) / 0.45 * PI)
			sy = 1.0 - 0.16 * q
			sx = 1.0 + 0.14 * q
		else:
			k.hop_t = -1.0
	var y := _gy(p.x, p.y)
	m.position = Vector3(p.x, y, p.y)
	m.rotation.y = k.yaw
	if moving:
		m._ground = snappedf(clampf(k.sp, 0.3, RUN_LEGS), 0.15)
	m.set_anim(anim, r.action)
	if cm != null:
		cm.set_body_lift(hop / maxf(cm.scale.y, 0.01))     # 폴짝은 인형만 (그림자는 땅에)
		cm.set_body_warp(sy, sx, 0.0)
	else:
		m.position.y = y + hop


## 요람을 들여다보는 이웃: 요람 쪽으로 몸을 기울이고 말풍선 하나, 아기는 까르르
func _peek_pose(r: Resident, m: ResidentModel) -> void:
	var pk: Peek = _peek[r.id]
	var s0: Dictionary = r.steps[0] if not r.steps.is_empty() else {}
	var mine := int(s0.get("pk", -1)) == pk.baby or (r.steps.size() > 1 and int((r.steps[1] as Dictionary).get("pk", -1)) == pk.baby)
	var cm := m as CutoutResident
	if not mine:
		if cm != null:
			cm.set_body_warp()
		_peek.erase(r.id)
		return
	if String(s0.get("k", "")) != "do":
		return                                 # 아직 걸어가는 중
	var bm: Node3D = vw.residents.get(pk.baby)
	if bm == null:
		return
	var d := bm.position - m.position
	m.rotation.y = atan2(d.x, d.z)
	if cm != null:
		cm.set_body_warp(0.97, 1.0, 0.17 * signf(d.dot(_right)) * (0.85 + 0.15 * sin(_clock * 2.4)))
	if not pk.said:
		pk.said = true
		_say(r.id, "peek", "love", 2.4)
		var b: Baby = _baby.get(pk.baby)
		if b != null:
			b.gig_t = 0.0


# ───────────────────────── 매 화면: 아기 (CutoutResident.place_babies 뒤) ─────────────────────────
func babies(dt: float, fast: bool) -> void:
	if v == null or vw == null:
		return
	for r in v.people:
		if not r.is_baby() or r.dead:
			continue
		var bm := vw.residents.get(r.id) as CutoutResident
		if bm == null:
			continue
		if bm._infant != (r.age < CutoutResident.INFANT_AGE):
			vw._res_key.erase(r.id)            # 첫돌: 누운 강보 인형 → 선 아기 인형으로 다시 만듦 (다음 화면)
			continue
		var b: Baby = _baby.get(r.id)
		if b == null:
			b = Baby.new()
			b.next_plop = lerpf(PLOP_EVERY.x, PLOP_EVERY.y, _h01(r.id, 1))
			_baby[r.id] = b
		b.seen = _frame
		if bm.baby_mode == "cradle":
			_cradle(r, bm, b, dt)
			continue
		if b.back != null:
			b.back.visible = false
			b.front.visible = false
		if bm.baby_mode == "toddle" and not fast:
			_toddle(r, bm, b, dt)
		else:
			b.has = false
			bm.set_body_warp()
			bm.set_body_lift(0.0)


func _free_baby(id: int) -> void:
	var b: Baby = _baby[id]
	if b.back != null:
		b.back.queue_free()
		b.front.queue_free()
	_baby.erase(id)


## 문 옆 요람: 짚 바구니 그림 두 장 (뒤 · 앞) 사이에 누운 아기. 살살 흔들리고, 누가 들여다보면 까르르
func _cradle(r: Resident, bm: CutoutResident, b: Baby, dt: float) -> void:
	if bm.cradle != null:
		bm.cradle.visible = false              # 옛 3D 원통 요람 대신
	if b.back == null:
		b.back = _card("cradle_back")
		b.front = _card("cradle_front")
	b.has = false
	var base := Vector3(bm.position.x, _gy(bm.position.x, bm.position.z), bm.position.z)
	var amp := 0.035
	var rate := 1.7
	var wig := 0.0
	if b.gig_t >= 0.0:
		b.gig_t += dt
		if b.gig_t > 0.6 and b.gig_t - dt <= 0.6:
			_say(r.id, "baby", "cheer", 1.8)
		if b.gig_t > 0.5 and b.gig_t < 2.6:
			amp = 0.075
			rate = 7.0
			wig = absf(sin(_clock * 9.0)) * 0.025
		if b.gig_t > 3.2:
			b.gig_t = -1.0
	var rock := sin(_clock * rate + float(r.id)) * amp
	_put(b.back, "cradle_back", base, CRADLE_W, rock, -0.012)
	_put(b.front, "cradle_front", base, CRADLE_W, rock, 0.075)
	var h := pic_h("cradle_back", CRADLE_W)
	var lying := _sleep_lift() * bm._doll_h
	bm.position.y = base.y
	bm.set_body_lift((h * CRADLE_RIM + 0.012 - lying + wig) / _cu / maxf(bm.scale.y, 0.01))
	bm.set_body_warp(1.0, 1.0, 0.0)


## 누운 인형의 가운데 높이 (인형 키 1에 대해) — CutoutResident.set_baby_mode와 같은 값
static func _sleep_lift() -> float:
	return CutoutResident.Lib.SLEEP_LIFT / float(CutoutResident.Lib.lib()["fig"])


## 걸음마 아기: 부모를 조금 늦게 아장아장 따라가고 (좌우로 뒤뚱), 가끔 털썩 주저앉았다 다시 서둘러 따라감.
## 보는 사람이 없으면 문 앞에서 앉아 놀다 몇 걸음 아장거림. place_babies가 정한 자리(bm.position)가 목표
func _toddle(r: Resident, bm: CutoutResident, b: Baby, dt: float) -> void:
	var tgt := Vector2(bm.position.x, bm.position.z)
	var minded := bm.minder_id >= 0
	if not minded:                             # 문 앞: 가끔 자리를 옮겨 앉음
		b.wander_t -= dt
		if b.wander_t <= 0.0:
			var n := int(_clock * 0.37) + r.id * 7
			b.wander = Vector2((_h01(n, 11) - 0.5) * 0.9, _h01(n, 12) * 0.45)
			b.wander_t = 3.5 + _h01(n, 13) * 4.0
		tgt += b.wander
	if not b.has or (tgt - b.pos).length() > 4.0:
		b.has = true
		b.pos = tgt
		b.yaw = bm.rotation.y
		b.moving = false
	var d := tgt - b.pos
	var dist := d.length()
	var sit := bm.toddle_clip == "sit"
	var sy := 1.0
	var sx := 1.0
	var lean := 0.0
	var hop := 0.0
	if b.plop_t >= 0.0:                        # 털썩: 눌렸다 펴지며 앉아 있음
		b.plop_t += dt
		sit = true
		b.sp = 0.0
		var q := clampf(b.plop_t / 0.28, 0.0, 1.0)
		sy = 1.0 - 0.2 * sin(q * PI)
		sx = 1.0 + 0.2 * sin(q * PI)
		if b.plop_t >= PLOP_SECS:
			b.plop_t = -1.0
			b.walked = 0.0
			b.next_plop = lerpf(PLOP_EVERY.x, PLOP_EVERY.y, _h01(r.id + int(_clock), 2))
	else:
		if not b.moving and dist > (TODDLE_START if minded else 0.1):
			b.moving = true
		if b.moving:
			var sp := clampf(dist * 1.5, TODDLE_SPEED.x, TODDLE_SPEED.y) if minded else TODDLE_SPEED.x
			var stp := minf(sp * dt, dist)
			if dist > 1.0e-4:
				b.pos += d / dist * stp
				b.yaw = lerp_angle(b.yaw, atan2(d.x, d.y), clampf(dt * 10.0, 0.0, 1.0))
			b.sp = sp
			b.walked += dt
			var wob := sin(_clock * 9.5 + float(r.id))
			lean = wob * 0.17                      # 뒤뚱뒤뚱
			hop = absf(wob) * 0.022
			sit = false
			if dist - stp < (TODDLE_STOP if minded else 0.03):
				b.moving = false
				if not minded:
					b.plop_t = 0.0             # 문 앞: 몇 걸음 가서 털썩 앉음
					_puff(Vector3(b.pos.x, _gy(b.pos.x, b.pos.y), b.pos.y))
			elif b.walked >= b.next_plop and dist < 2.2:
				b.plop_t = 0.0
				b.moving = false
				_puff(Vector3(b.pos.x, _gy(b.pos.x, b.pos.y), b.pos.y))
				if r.id % 2 == int(_clock) % 2:
					_say(r.id, "plop", "", 1.2)
		else:
			b.sp = 0.0
			if not minded:
				sit = true
	if b.hop_t >= 0.0:                         # 첫걸음마: 기뻐서 폴짝
		b.hop_t += dt
		var t := b.hop_t / HOP_SECS
		if t < 1.0:
			hop += 0.12 * 4.0 * t * (1.0 - t)
		else:
			b.hop_t = -1.0
	bm.toddle_clip = "sit" if sit else ("walk" if b.moving else "idle")
	bm.position = Vector3(b.pos.x, _gy(b.pos.x, b.pos.y), b.pos.y)
	bm.rotation.y = b.yaw
	if b.moving:
		bm._ground = snappedf(b.sp, 0.1)
	bm.set_body_lift(hop / maxf(bm.scale.y, 0.01))
	bm.set_body_warp(sy, sx, lean)
	bm._refresh_doll()
