## 아이·아기가 사는 모습 (ROADMAP Q2-b 귀여움 묶음 ② — E2-2 · E2-3, GAME_DESIGN 기둥 0). 화면만 — 시뮬레이션은 sim/child_play.gd.
## 여기서는 저장된 놀이 상태(Village.kids)와 사건(kid_tagged · kid_stack_fell · kid_play_started · baby_peeked · first_steps)을 읽어
##   · 놀이 속 아이의 화면 자리 (ChildPlay.spot — 놀이 시계의 순수 함수) + 인형 통째 몸짓 (폴짝 · 눌림 · 기울임) + 그림 말풍선
##   · 작은 소품 그림 (돌탑 · 나비 · 먼지 · 요람 — art/kids2d/kids_props.png, tools/kids/make_props.py가 그림)
##   · 사방치기: 땅에 그은 칸 (납작한 판 — 놀이가 끝나면 한동안 남았다가 닳아 없어짐) · 깨금발 뜀 · 조약돌/별 그림 말풍선
##   · 물수제비: 날아가는 조약돌 · 물 위의 고리 (점점 촘촘히) — 아이는 물가 자리에서 움직이지 않는다
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
# 첫걸음마 (Q2-b 남은 것 — 짧은 순간: 카메라·병 시간을 붙잡지 않음, 현실 초). first_steps 사건 → 부모가 몇 걸음 물러나 쪼그려 앉아 두 팔을 벌림
# → 아기가 뒤뚱뒤뚱 몇 걸음 (가운데서 한 번 휘청) → 털썩 → 부모가 안아 올림 · 하트 → 내려놓음. 보는 사람이 없으면 아기 혼자 몇 걸음 · 털썩 · 반짝
const FS_SECS := 3.8
const FS_BACK := 0.6              # 부모가 물러나는 동안 (아기는 일어서서 흔들흔들)
const FS_WALK_END := 2.45
const FS_PLOP_END := 2.85
const FS_LIFT_END := 3.25
const FS_DOWN := 3.52             # 여기부터 아기를 내려놓음
const FS_RELEASE := 0.45          # 끝난 뒤 부모 인형이 시뮬 자리로 돌아가는 시간
const FS_GAP := 1.0               # 부모와 아기 사이 (칸 — 화면 가로)
const FS_SHORT := 0.27            # 부모 앞 이만큼에서 털썩
const FS_SOLO := 0.7              # 혼자일 때 걷는 거리
const FS_WAIT := 2.5              # 아기 인형이 걸음마 모습이 되길 기다리는 시간 (넘으면 그만둠)
const FS_CROUCH := Vector2(0.84, 1.06)     # 쪼그려 앉은 부모 (키 배율, 폭 배율)
const FS_HOLD := 0.27             # 안긴 아기의 높이 (부모 인형 키의 비율)
const FS_SPARK := 0.4             # 혼자 걸었을 때의 반짝임 크기 (아기 키에 맞춰 작게)
const FS_FX_PX := 72.0            # 하트·반짝임의 크기 기준 (짧은 판 MINI_PX보다 작게 — 마을의 작은 순간)
const NOD_SECS := 3.4             # 꾸벅 한 번 (천천히 숙였다가 화들짝)
const FS_CLEAR := 0.3             # 건물 그림 밑변에서 이만큼 앞이어야 보임
# 사방치기 · 물수제비 (Q2-b 놀이 3 — 화면만)
const GROUND_SHADER := "res://view/kids/kid_ground.gdshader"
const GRID_FILL := Color("f1e6c4")     # 칸 바탕 (발로 다진 밝은 흙)
const GRID_INK := Color("6e4a2c")      # 나뭇가지로 그은 금
const GRID_LIFT := 0.04           # 칸을 땅에서 띄우는 높이
const GRID_LINE := 0.06           # 금의 굵기 (칸)
const GRID_DRAW := 1.5            # 긋는 데 걸리는 시간 (현실 초)
const GRID_HOLD := 7.0            # 놀이가 끝난 뒤 그대로 남는 시간
const GRID_FADE := 5.0            # 그 뒤 닳아 없어지는 시간
const HOPSCOTCH_H := 0.21         # 깨금발 뜀 높이 (칸)
const CHEER_SECS := 0.95          # 기다리던 아이의 들썩들썩 (두 번)
const STAR_SECS := 1.7            # 깨끗이 다녀온 아이 머리 위의 별
const RING_COL := Color("f6fcff")
const RING_SECS := 1.3
const RING_R := 0.5              # 첫 물결 고리의 반지름 (칸)
const RING_LIFT := 0.03
const RING_MAX := 14
const PEBBLE_W := 0.16

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
var _steps := {}                  # 첫걸음마: 아기 id → Steps
var _steps_par := {}              # 첫걸음마: 부모 id → 아기 id
var _back := Vector3.BACK         # 카메라 쪽 (땅 위)
var bub: KidBubbles               # 그림 말풍선 (저녁 이야기 — 글 없음)
var _story := {}                  # 이야기하는 어르신 id → 놀이
var fx_log: Array = []            # (시험) 놓은 빛·하트 [종류, 자리]
var _grids := {}                  # 사방치기 칸: 놀이 id → Grid (놀이가 끝난 뒤에도 한동안 남음)
var _gmat: ShaderMaterial         # 칸 재질
var _rmat: ShaderMaterial         # 물결 고리 재질
var _ring_mesh: ArrayMesh
var _rings: Array[MeshInstance3D] = []
var _ring_t := PackedFloat32Array()
var _ring_r := PackedFloat32Array()
var _ring_i := 0
var ring_log: Array = []          # (시험) 놓은 물결 고리 [자리, 반지름] — 가장 새 것 몇 개만
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
	var cheer_t := -9.0           # 들썩들썩 (−9 = 없음 · 음수 = 조금 뒤에 시작)
	var star_t := -1.0            # 머리 위 별
	var land := -1                # 사방치기: 마지막으로 내려선 뜀


class Grid extends RefCounted:
	var node: MeshInstance3D
	var t := 0.0                  # 긋기 시작한 뒤 (현실 초)
	var gone := -1.0              # 놀이가 끝난 뒤 (−1 = 놀이 중)
	var seen := -1


class Props extends RefCounted:
	var stones: Array[MeshInstance3D] = []
	var bfly: MeshInstance3D
	var stone: MeshInstance3D     # 물수제비 돌
	var touch := 0                # 이번 돌이 물에 닿은 횟수 (고리를 놓은 만큼)
	var cheer_hs := -1.0          # 멀리 간 돌에 폴짝한 차례 (그 차례가 시작된 놀이 시계)
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


class Steps extends RefCounted:
	var par := -1                 # 팔 벌린 부모 (없으면 -1: 혼자)
	var t := -1.0                 # 지난 시간 (현실 초 — -1 = 아직 시작 전)
	var wait := 0.0
	var at := Vector2.ZERO        # 아기가 있던 자리 (건물 그림에 가려 있을 수 있음)
	var from := Vector2.ZERO      # 아기가 일어서는 자리 (트인 곳)
	var to := Vector2.ZERO        # 털썩 앉는 자리
	var p0 := Vector2.ZERO        # 부모가 있던 자리
	var p1 := Vector2.ZERO        # 부모가 물러나 앉는 자리
	var side := 1.0               # 부모가 아기의 어느 쪽 (화면 오른쪽 +1)
	var bpos := Vector2.ZERO      # 지금 아기의 화면 자리
	var done := 0                 # 한 번만 하는 것 (1 말 · 2 털썩 · 4 하트)


func _init(village: Village = null, view: VillageView = null) -> void:
	v = village
	vw = view
	bub = KidBubbles.new()
	add_child(bub)
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
		var bz := Vector3(bs.z.x, 0.0, bs.z.z)
		if bz.length_squared() > 1.0e-6:
			_back = bz.normalized()
	if fast != _was_fast:
		_was_fast = fast
		if fast:                               # 빠른 흐름: 몸짓을 멈추고 시뮬 자리로 (소품만 그대로)
			for id: int in _kid.keys():
				_warp_reset(id)
			_kid.clear()
			for id: int in _peek.keys():
				_warp_reset(id)
			_peek.clear()
			for id: int in _steps.keys():
				_steps_end(id)
	_events(fast)
	bub.clear()
	var tell := {}
	if not fast:
		for g: Dictionary in v.kids.get("g", []):
			if String(g["kind"]) == "story" and int(g.get("go", 0)) == 1:
				tell[int(g.get("el", -1))] = g
	for id: int in _story.keys():              # 이야기가 끝난 어르신: 제 모습으로
		if not tell.has(id):
			_warp_reset(id)
	_story = tell
	for id: int in _steps.keys():              # 첫걸음마의 시계
		var st: Steps = _steps[id]
		if st.t < 0.0:
			st.wait += dt
			if st.wait > FS_WAIT:
				_steps_end(id)
		else:
			st.t += dt
			if st.t >= FS_SECS + FS_RELEASE:
				_steps_end(id)
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
				if pr.stone != null:
					pr.stone.queue_free()
				_props.erase(gid)
	for gid: int in _grids.keys():             # 사방치기 칸: 긋는 중 → 그대로 → (놀이가 끝나고 한참 뒤) 닳아 없어짐
		var gr: Grid = _grids[gid]
		if gr.seen == _frame:
			gr.t += dt
			gr.gone = -1.0
		else:
			gr.gone = maxf(gr.gone, 0.0) + dt
			if gr.gone >= GRID_HOLD + GRID_FADE:
				gr.node.queue_free()
				_grids.erase(gid)
				continue
		gr.node.set_instance_shader_parameter("reveal", 1.0 if fast else clampf(gr.t / GRID_DRAW, 0.0, 1.0))
		gr.node.set_instance_shader_parameter("tint", Vector4(1.0, 1.0, 1.0, clampf((gr.gone - GRID_HOLD) / GRID_FADE, 0.0, 1.0)))
	for i in _rings.size():                    # 물결 고리: 퍼지며 흩어짐
		var t := _ring_t[i]
		if t >= RING_SECS:
			continue
		t += dt
		_ring_t[i] = t
		if t < 0.0 or t >= RING_SECS:
			_rings[i].visible = false
			continue
		var u := t / RING_SECS
		var sc := _ring_r[i] * (0.22 + 0.78 * (1.0 - (1.0 - u) * (1.0 - u)))
		_rings[i].visible = true
		_rings[i].scale = Vector3(sc, 1.0, sc)
		_rings[i].set_instance_shader_parameter("tint", Vector4(1.0, 1.0, 1.0, smoothstep(0.5, 1.0, u) * 0.96))
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
		elif kind == &"kid_hop_done":            # 사방치기 한 판: 깨끗이 다녀오면 별 · 기다리던 아이들이 들썩들썩, 금을 밟았으면 깔깔
			var d: Dictionary = e["v"]
			if bool(d["clean"]):
				var hk: Kid = _kid.get(int(e["who"]))
				if hk != null:
					hk.star_t = 0.0
				for id: int in _kid:
					var k: Kid = _kid[id]
					if id != int(e["who"]) and k.seen >= _frame - 1 and int(k.g.get("id", -1)) == int(d["game"]):
						k.cheer_t = -0.22 * _h01(id, 9)
				GameAudio.fx("small_cheer", "Village", -11.0, e["at"])
			else:
				GameAudio.fx("child_laugh", "Village", -13.0, e["at"])
		elif kind == &"baby_peeked":
			var d: Dictionary = e["v"]
			var p := Peek.new()
			p.baby = int(d["baby"])
			_peek[int(e["who"])] = p
		elif kind == &"first_steps":
			var d: Dictionary = e["v"]
			if _steps.size() < 2 and not _steps.has(int(e["who"])):     # 짧은 순간으로 보여 줌 (babies → _steps_start)
				var st := Steps.new()
				st.par = int(d["with"])
				_steps[int(e["who"])] = st


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
	# 사방치기 칸 (첫 아이가 닿으면 긋기 시작)
	if kind == "hop" and int(g.get("go", 0)) == 1:
		var gr: Grid = _grids.get(gid)
		if gr == null:
			gr = Grid.new()
			gr.node = _grid_node(g)
			_grids[gid] = gr
		gr.seen = _frame
	# 물수제비: 돌 · 물결 고리
	if kind == "skip":
		_skip_tick(g, pr, n_on)
	elif pr.stone != null:
		pr.stone.visible = false
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


# ───────────────────────── 소품: 사방치기 칸 · 물수제비 ─────────────────────────
## 사방치기 칸들 [가운데, 줄] — 한 칸 줄은 가운데, 두 칸 줄은 양옆 (ChildPlay.HOP_ROWS)
static func hop_cells(g: Dictionary) -> Array:
	var ax := Vector2(float(g["ax"]), float(g["ay"]))
	var perp := Vector2(-ax.y, ax.x)
	var c := Vector2(float(g["x"]), float(g["y"]))
	var n := ChildPlay.HOP_ROWS.size()
	var out: Array = []
	for i in n:
		var q := c + ax * ((float(i) + 0.5 - float(n) * 0.5) * ChildPlay.HOP_CELL)
		if int(ChildPlay.HOP_ROWS[i]) == 1:
			out.append([q, i])
		else:
			out.append([q + perp * ChildPlay.HOP_CELL * 0.5, i])
			out.append([q - perp * ChildPlay.HOP_CELL * 0.5, i])
	return out


func _ground_mat(fill: Color, line: Color) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = load(GROUND_SHADER)
	mt.set_shader_parameter("col_fill", fill)
	mt.set_shader_parameter("col_line", line)
	return mt


## 땅에 눕힌 네모 하나 (꼭짓점마다 땅 높이를 따라감). ink = 0 바탕 · 1 금, UV.x = 긋는 차례 (첫 칸 0 → 끝 칸 1)
func _flat_quad(vs: PackedVector3Array, cs: PackedColorArray, us: PackedVector2Array, ix: PackedInt32Array,
		o: Vector2, ex: Vector2, ey: Vector2, lift: float, ink: float, g: Dictionary) -> void:
	var c := Vector2(float(g["x"]), float(g["y"]))
	var ax := Vector2(float(g["ax"]), float(g["ay"]))
	var span := ChildPlay.HOP_CELL * float(ChildPlay.HOP_ROWS.size())
	var n := vs.size()
	for q: Vector2 in [o - ex - ey, o + ex - ey, o + ex + ey, o - ex + ey]:
		vs.append(Vector3(q.x, _gy(q.x, q.y) + lift, q.y))
		cs.append(Color(ink, 0.0, 0.0))
		us.append(Vector2(clampf(((q - c).dot(ax) + span * 0.5) / span, 0.0, 1.0) * 0.97, 0.0))
	ix.append_array(PackedInt32Array([n, n + 1, n + 2, n, n + 2, n + 3]))


## 사방치기 칸 그림 (판 하나 — 칸마다 바탕 네모 + 네 변의 금)
func _grid_node(g: Dictionary) -> MeshInstance3D:
	if _gmat == null:
		_gmat = _ground_mat(GRID_FILL, GRID_INK)
	var ax := Vector2(float(g["ax"]), float(g["ay"]))
	var perp := Vector2(-ax.y, ax.x)
	var h := ChildPlay.HOP_CELL * 0.5
	var lw := GRID_LINE * 0.5
	var vs := PackedVector3Array()
	var cs := PackedColorArray()
	var us := PackedVector2Array()
	var ix := PackedInt32Array()
	var cells := hop_cells(g)
	for cl: Array in cells:
		_flat_quad(vs, cs, us, ix, cl[0], ax * h, perp * h, GRID_LIFT, 0.0, g)
	for cl: Array in cells:
		var o: Vector2 = cl[0]
		for sg: float in [-1.0, 1.0]:
			_flat_quad(vs, cs, us, ix, o + perp * h * sg, ax * (h + lw), perp * lw, GRID_LIFT + 0.012, 1.0, g)
			_flat_quad(vs, cs, us, ix, o + ax * h * sg, ax * lw, perp * (h + lw), GRID_LIFT + 0.012, 1.0, g)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_TEX_UV] = us
	arr[Mesh.ARRAY_INDEX] = ix
	var nm := PackedVector3Array()
	nm.resize(vs.size())
	nm.fill(Vector3.UP)
	arr[Mesh.ARRAY_NORMAL] = nm
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = _gmat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	n.set_instance_shader_parameter("reveal", 0.0)
	return n


## 물 높이 (호수의 수면 — VillageView의 뗏목과 같은 셈)
func _wy(x: float, z: float) -> float:
	var k := v.water.idx(x, z)
	return (v.water.ground(k) + v.water.depth(k)) * JarTerrain.HS - JarTerrain.WATER_SINK


## 물결 고리 하나 (at = 수면 위 자리, r = 다 퍼졌을 때 반지름, delay = 조금 늦게)
func _ring(at: Vector3, r: float, delay := 0.0) -> void:
	if _ring_mesh == null:
		_rmat = _ground_mat(RING_COL, RING_COL)
		_rmat.set_shader_parameter("grain", 44.0)
		var vs := PackedVector3Array()
		var cs := PackedColorArray()
		var us := PackedVector2Array()
		var nm := PackedVector3Array()
		var ix := PackedInt32Array()
		var seg := 28
		for i in seg:
			var a := TAU * float(i) / float(seg)
			for rr: float in [0.74, 1.0]:
				vs.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))
				cs.append(Color(0.0, 0.0, 0.0))
				us.append(Vector2.ZERO)
				nm.append(Vector3.UP)
			var j := (i + 1) % seg
			ix.append_array(PackedInt32Array([i * 2, i * 2 + 1, j * 2 + 1, i * 2, j * 2 + 1, j * 2]))
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = vs
		arr[Mesh.ARRAY_COLOR] = cs
		arr[Mesh.ARRAY_TEX_UV] = us
		arr[Mesh.ARRAY_NORMAL] = nm
		arr[Mesh.ARRAY_INDEX] = ix
		_ring_mesh = ArrayMesh.new()
		_ring_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if _rings.size() < RING_MAX:
		var n := MeshInstance3D.new()
		n.mesh = _ring_mesh
		n.material_override = _rmat
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.visible = false
		add_child(n)
		_rings.append(n)
		_ring_t.append(RING_SECS)
		_ring_r.append(r)
		_ring_i = _rings.size() - 1
	else:
		_ring_i = (_ring_i + 1) % _rings.size()
	_rings[_ring_i].position = at + Vector3(0.0, RING_LIFT, 0.0)
	_rings[_ring_i].visible = false
	_ring_t[_ring_i] = -delay
	_ring_r[_ring_i] = r
	ring_log.append([at, r])
	if ring_log.size() > 48:
		ring_log = ring_log.slice(24)


## 물수제비 (놀이 시계의 순수 함수 ChildPlay.skip_stone을 그대로 그림): 손의 돌 → 날아가는 돌 → 닿는 곳마다 고리 · 퐁 소리
func _skip_tick(g: Dictionary, pr: Props, n_on: int) -> void:
	if pr.stone == null:
		pr.stone = _card("stone_b")
	if n_on == 0 or int(g["turn"]) < 0:
		pr.stone.visible = false
		return
	var c := float(g["c"])
	var st: Array = ChildPlay.skip_stone(g, c)
	var state := int(st[0])
	var d := Vector2(float(g["ax"]), float(g["ay"]))
	var from := ChildPlay.skip_from(g)
	if state == 0:                             # 아직 손에: 뒤로 젖힐 때부터 보임
		pr.touch = 0
		var u := clampf((c - float(g["hs"])) / ChildPlay.SKIP_WIND, 0.0, 1.0)
		var tk: Kid = _kid.get(int(g["turn"]))
		if tk == null or not tk.has or u < 0.22 or _was_fast:
			pr.stone.visible = false
		else:
			var back := smoothstep(0.22, 0.78, u) - 2.0 * smoothstep(0.84, 1.0, u)
			var hp := tk.pos - d * 0.13 * back
			_put(pr.stone, "stone_b", Vector3(hp.x, _gy(tk.pos.x, tk.pos.y), hp.y), PEBBLE_W, 0.0, 0.08, 1.0, 0.7, 1.0, ChildPlay.SKIP_HAND)
		return
	var tc: Array = ChildPlay.skip_touches(g)
	var done := mini(int(st[3]), tc.size()) if state == 1 else tc.size()
	var wl := _wy(from.x + d.x * float(tc[0][0]), from.y + d.y * float(tc[0][0]))
	if _was_fast:
		pr.touch = done
	for j in range(pr.touch, done):
		var q := from + d * float(tc[j][0])
		var last := j == tc.size() - 1
		var rad := RING_R * pow(0.9, float(j)) * (1.12 if last else 1.0)
		_ring(Vector3(q.x, wl, q.y), rad)
		_ring(Vector3(q.x, wl, q.y), rad * 0.55, 0.17)     # 안쪽 고리 하나 더 (조금 늦게)
		GameAudio.fx("drip", "Village", -8.0 if not last else -11.0, q, 0.8 if last else 1.05 + 0.09 * float(j))
	pr.touch = done
	if state == 1 and not _was_fast:
		var q := from + d * float(st[1])
		var f := float(st[4])
		var y := (lerpf(_gy(from.x, from.y) + ChildPlay.SKIP_HAND, wl, f) if int(st[3]) == 0 else wl) + float(st[2])
		_put(pr.stone, "stone_b", Vector3(q.x, y, q.y), PEBBLE_W, _clock * 9.0, 0.05, 1.0, 0.62, 1.0, 0.03)
	else:
		pr.stone.visible = false
	if int(g["h"]) >= ChildPlay.SKIP_FAR and done >= ChildPlay.SKIP_FAR and pr.cheer_hs != float(g["hs"]) and not _was_fast:
		pr.cheer_hs = float(g["hs"])           # 멀리 갔다! 지켜보던 아이 하나가 폴짝 (혼자면 던진 아이가)
		var best: Kid = null
		for id: int in _kid:
			var k: Kid = _kid[id]
			if k.seen >= _frame - 1 and int(k.g.get("id", -1)) == int(g["id"]) and (best == null or id != int(g["turn"])):
				best = k
				if id != int(g["turn"]):
					break
		if best != null:
			best.hop_t = 0.0
		GameAudio.fx("small_cheer", "Village", -13.0, Vector2(float(g["x"]), float(g["y"])))


# ───────────────────────── 매 화면: 놀이 속 아이 (주민마다, social.pose 뒤) ─────────────────────────
func pose(r: Resident, m: ResidentModel, dt: float) -> void:
	if not _steps_par.is_empty() and _steps_par.has(r.id):
		_steps_parent(r, m)
		return
	if not _story.is_empty() and _story.has(r.id):
		_story_tell(r, m, _story[r.id])
		return
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
	var sy := 1.0
	var sx := 1.0
	var lean := 0.0
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
			"story":                               # 저녁 이야기: 어르신 쪽으로 앉아 몸을 기울여 듣는다 — 한 아이는 꾸벅
				var ep := Vector2(float(g["x"]), float(g["y"]))
				look = ep
				if not moving:
					anim = "sit"
					var side := signf((ep - p).dot(Vector2(_right.x, _right.z)))
					var pic: Array = ChildPlay.story_pic(g, c)
					if ChildPlay.story_nod(g, c) == r.id:
						var q := fposmod(_clock + k.ph, NOD_SECS) / NOD_SECS
						var droop := smoothstep(0.0, 0.78, q) if q < 0.8 else 1.0 - smoothstep(0.8, 0.88, q)
						lean = side * (0.05 + 0.2 * droop)
						sy = 1.0 - 0.07 * droop
						if q >= 0.8 and q < 0.9:           # 화들짝
							hop = 0.035 * sin((q - 0.8) / 0.1 * PI)
						elif cm != null and not _says(r):
							bub.add(m, "zzz", 0.12 + 0.7 * q / 0.8, true, _clock)
					else:
						var f := float(pic[1])
						var lead := sin(f * PI) if String(pic[0]) != "" else 0.0
						lean = side * (0.07 + 0.06 * lead)     # 그림이 뜨면 더 바짝
						sy = 1.0 + 0.012 * sin(_clock * 2.3 + k.ph)
						if String(pic[0]) != "" and f < 0.12:  # 새 그림: 들썩
							hop = 0.03 * sin(f / 0.12 * PI)
			"hop":                                 # 사방치기: 제 차례엔 깨금발로 칸을 따라 갔다가 돌아오고, 나머지는 곁에서 지켜봄
				var ax := Vector2(float(g["ax"]), float(g["ay"]))
				if int(g["turn"]) == r.id:
					var a: Array = ChildPlay.hop_at(g, c)
					var j := int(a[1])
					var f := float(a[2])
					var out_yaw := atan2(ax.x, ax.y)
					var n_rows := ChildPlay.HOP_ROWS.size()
					match int(a[0]):
						0:                                 # 첫 칸 앞으로: 조약돌을 던져 놓고 움찔
							k.land = -1
							if not moving:
								look = p + ax
							var bk: Kid = _kid.get(int(g["by"]))      # 방금 깨끗이 다녀온 아이의 별이 떠 있으면 조약돌 그림은 쉼 (두 그림이 겹치지 않게)
							if f > 0.25 and cm != null and not _says(r) and (bk == null or bk.star_t < 0.0):
								bub.add(m, "pebble", clampf((f - 0.25) / 0.75, 0.0, 1.0), true, _clock)
							if f > 0.84:
								sy = 1.0 - 0.09 * sin((f - 0.84) / 0.16 * PI)
						1:                                 # 폴짝 — 한 칸 줄은 깨금발(기우뚱), 두 칸 줄은 두 발을 벌려 착
							moving = false
							anim = "idle"
							var row := ChildPlay.hop_row(j)
							var two := row >= 0 and int(ChildPlay.HOP_ROWS[row]) == 2
							var foot := 0.0 if two else (1.0 if j % 2 == 0 else -1.0)
							var q := f / ChildPlay.HOP_AIR
							if q < 1.0:
								hop = HOPSCOTCH_H * 4.0 * q * (1.0 - q)
								sy = 1.0 + 0.09 * sin(q * PI)
								sx = 1.0 - 0.06 * sin(q * PI)
								lean = 0.1 * foot
							else:
								var sq := sin((f - ChildPlay.HOP_AIR) / (1.0 - ChildPlay.HOP_AIR) * PI)
								sy = 1.0 - (0.15 if two else 0.1) * sq
								sx = 1.0 + (0.18 if two else 0.07) * sq
								lean = 0.1 * foot * (1.0 - 0.6 * sq)
								if k.land != j:                    # 착! (발소리 한 번)
									k.land = j
									GameAudio.fx("finger_place", "Village", -13.0, p, 1.25 if two else 1.45)
							k.yaw = out_yaw if j <= n_rows else out_yaw + PI
						2:                                 # 끝 칸: 폴짝 돌아섬
							moving = false
							anim = "idle"
							hop = 0.11 * sin(f * PI)
							sy = 1.0 + 0.05 * sin(f * PI)
							k.yaw = out_yaw + PI * smoothstep(0.1, 0.9, f)
						3:                                 # 금을 밟음: 휘청휘청
							moving = false
							anim = "idle"
							lean = 0.22 * sin(f * 5.0 * PI) * (1.0 - f)
							sy = 1.0 - 0.07 * sin(f * PI)
				elif not moving:
					var tk: Kid = _kid.get(int(g["turn"]))
					if tk != null and tk.has:
						look = tk.pos
						if tk.land >= 0 and absf(tk.pos.x - k.pos.x) + absf(tk.pos.y - k.pos.y) > 0.2:     # 박자 맞춰 살짝 들썩
							hop = 0.012 * absf(sin(_clock * 7.0 + k.ph))
					else:
						look = Vector2(float(g["x"]), float(g["y"]))
			"skip":                                # 물수제비: 물가 제 자리에서 — 차례인 아이는 젖혔다가 휙, 나머지는 물을 내다봄
				var d := Vector2(float(g["ax"]), float(g["ay"]))
				if not moving:
					look = p + d * 2.0
					var side := signf(d.dot(Vector2(_right.x, _right.z)))
					if int(g["turn"]) == r.id:
						var u := (c - float(g["hs"])) / ChildPlay.SKIP_WIND
						if u < 1.0:                        # 뒤로 젖혀 웅크렸다가 → 휙
							var wd := smoothstep(0.18, 0.78, u)
							var th := smoothstep(0.84, 1.0, u)
							lean = side * (-0.2 * wd * (1.0 - th) + 0.26 * th)
							sy = 1.0 - 0.1 * wd * (1.0 - th) + 0.04 * th
							sx = 1.0 + 0.06 * wd * (1.0 - th)
						else:                              # 던진 팔을 따라 숙였다가, 돌을 눈으로 좇음
							var q := smoothstep(0.0, 1.0, clampf((u - 1.0) * ChildPlay.SKIP_WIND / 300.0, 0.0, 1.0))
							lean = side * lerpf(0.26, 0.06, q)
							sy = 1.0 + 0.04 * (1.0 - q)
					else:
						lean = side * 0.05
						sy = 1.0 + 0.012 * sin(_clock * 2.6 + k.ph)
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
	if k.cheer_t > -9.0:                       # 와! — 두 번 들썩이며 손뼉 (몸이 좁아졌다 넓어졌다)
		k.cheer_t += dt
		if k.cheer_t >= CHEER_SECS:
			k.cheer_t = -9.0
		elif k.cheer_t >= 0.0:
			var t := k.cheer_t / CHEER_SECS
			hop += 0.1 * absf(sin(t * TAU))
			sx *= 1.0 + 0.06 * sin(t * TAU * 3.0)
			sy *= 1.0 + 0.04 * absf(sin(t * TAU))
	if k.star_t >= 0.0:                        # 깨끗이 다녀옴: 머리 위에 별
		k.star_t += dt
		if k.star_t >= STAR_SECS:
			k.star_t = -1.0
		elif here and cm != null and not _says(r):
			bub.add(m, "star", clampf(k.star_t / STAR_SECS, 0.0, 1.0), true, _clock)
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
		cm.set_body_warp(sy, sx, lean)
	else:
		m.position.y = y + hop


## 이야기하는 어르신 (화면만 — 자리·앉은 모습은 시뮬 그대로): 아이들 쪽을 보고 느릿느릿 몸을 흔들며, 머리 위에 그림 (글 없음)
func _story_tell(r: Resident, m: ResidentModel, g: Dictionary) -> void:
	if not m.visible or vw.stage_say.has(r.id) or vw.pose_over.has(r.id):
		_warp_reset(r.id)                      # 연출·조짐이 먼저
		return
	var e := Vector2(float(g["x"]), float(g["y"]))
	var mid := (ChildPlay.seat(g, 0) + ChildPlay.seat(g, 1)) * 0.5
	m.rotation.y = atan2(mid.x - e.x, mid.y - e.y)
	m.set_anim("sit", r.action)            # 돌린 쪽으로 인형 보기(앞·비스듬)를 다시 고름
	var pic: Array = ChildPlay.story_pic(g, float(g["c"]))
	var on := String(pic[0]) != ""
	var cm := m as CutoutResident
	if cm != null:
		var side := signf((mid - e).dot(Vector2(_right.x, _right.z)))
		var lead := sin(float(pic[1]) * PI) if on else 0.0
		cm.set_body_warp(1.0 + 0.018 * sin(_clock * 3.1) * (1.0 if on else 0.3), 1.0, side * (0.03 + 0.05 * lead) + 0.02 * sin(_clock * 1.7))
	if on and not _says(r):
		bub.add(m, String(pic[0]), clampf(float(pic[1]), 0.08, 0.88), false, _clock)     # 말풍선은 이야기 내내 떠 있음 (그림이 바뀔 때만 살짝 톡)


## 글 말풍선이 떠 있는가 (그림 말풍선을 그 위에 겹치지 않음)
func _says(r: Resident) -> bool:
	return (r.say_t > 0.0 and r.say != "" and not ChildPlay.story_seated(v, r.id)) or vw.stage_say.has(r.id) or (vw.social != null and not vw.social.say_of(r.id).is_empty())     # 이야기 자리의 혼잣말은 화면에 안 뜸 (test_village._bubbles_of)


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
			var st: Steps = _steps.get(r.id) if not _steps.is_empty() else null
			if st != null and (st.t >= 0.0 or _steps_start(r, bm, b, st)) and st.t < FS_SECS:
				_steps_baby(r, bm, b, st)
			else:
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


# ───────────────────────── 첫걸음마 (짧은 순간 — first_steps 사건) ─────────────────────────
## 설 수 있는 자리인가 (화면만): 물 · 건물 속·뒤가 아님
func _stand_ok(p: Vector2) -> bool:
	if v.water_at(p.x, p.y):
		return false
	var r2 := Vector2(_right.x, _right.z)
	var b2 := Vector2(_back.x, _back.z)
	var carded := {}
	for id: int in vw._card_items:             # 2D 건물 그림: 카메라를 보고 선 판 — 밑변(front)보다 뒤는 가려짐
		for it: Array in vw._card_items[id]:
			var d := Bld2D.info(String(it[0]))
			if d.is_empty() or int(d.get("mode", 0)) != 0:
				continue
			carded[id] = true
			var k := float(it[2])
			var c: Vector3 = it[1]
			var rel := p - Vector2(c.x, c.z)
			var dc := rel.dot(b2)
			if absf(rel.dot(r2)) < float(d.get("w", 2.5)) * k * 0.5 + 0.1 and dc < float(d.get("front", 1.1)) * k + FS_CLEAR and dc > -(float(d.get("h", 2.5)) * k * 1.6 + 0.6):
				return false
	for b in v.buildings:                      # 그림 판이 없는 건물 (3D · 시험): 발자리
		if carded.has(b.id):
			continue
		var hs := b.size() * 0.5
		var rel := p - Vector2(b.x, b.y)
		var dc := rel.dot(b2)
		if absf(rel.dot(r2)) < hs + 0.25 and dc < hs + 0.15 and dc > -(hs + 1.8):
			return false
	return true


## 짧은 순간의 빛·하트 (view/moment_fx.gd — 짧은 판과 같은 규칙: 멀리서 보면 그만큼 크게, 높이는 덜)
func _fx(kind: String, at: Vector2, up: float, secs: float, k := 1.0) -> void:
	var p3 := Vector3(at.x, _gy(at.x, at.y), at.y)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var ppu := TapReact.px_per_unit(cam, to_global(p3)) if cam != null else 0.0
	var big := clampf(FS_FX_PX / ppu, 1.0, StageDirector.MINI_BIG) if ppu > 0.0 else 1.0
	p3.y += up * pow(big, StageDirector.MINI_LIFT_POW)
	MomentFx.spawn(self, kind, p3, secs, big * k)
	fx_log.append([kind, at])


## 시작: 아기가 걸음마 인형으로 서 있을 때. 부모(사건의 with, 없으면 지금 보는 사람)가 화면에 있고 다른 장면에 묶여 있지 않으면 함께, 아니면 혼자
func _steps_start(r: Resident, bm: CutoutResident, b: Baby, st: Steps) -> bool:
	var at := b.pos if b.has else Vector2(bm.position.x, bm.position.z)
	var r2 := Vector2(_right.x, _right.z)
	var b2 := Vector2(_back.x, _back.z)
	var par := st.par if st.par >= 0 else bm.minder_id
	var pr := v.person(par) if par >= 0 else null
	var pm := vw.residents.get(par) as CutoutResident if par >= 0 else null
	if pr == null or pm == null or not pm.visible or pr.dead or pr.sleeping or pr.anim == "sleep" or vw.staged.has(par) or vw.pose_over.has(par) \
			or (vw.social != null and vw.social.busy(par)) or _peek.has(par) or _steps_par.has(par):
		par = -1
	st.par = par
	st.at = at
	st.bpos = at
	# 걷는 줄 (화면 가로)이 건물 그림에 가리지 않는 가장 가까운 자리: 카메라 쪽으로 조금씩 나오며 양쪽을 봄
	var span := FS_GAP if par >= 0 else FS_SOLO + 0.2
	var s := 1.0
	if par >= 0:
		st.p0 = Vector2(pm.position.x, pm.position.z)
		s = 1.0 if (st.p0 - at).dot(r2) >= 0.0 else -1.0
	var from := at
	var found := false
	for k in 9:
		var f := at + b2 * 0.2 * float(k)
		for sd: float in [s, -s]:
			if _stand_ok(f) and _stand_ok(f + r2 * sd * span * 0.5) and _stand_ok(f + r2 * sd * span):
				from = f
				s = sd
				found = true
				break
		if found:
			break
	st.from = from
	st.side = s
	if par >= 0:
		st.p1 = from + r2 * s * (FS_GAP if found else 0.6)
		st.to = st.p1 - r2 * s * FS_SHORT + b2 * 0.03
		_steps_par[par] = r.id
	else:
		st.to = from + r2 * s * FS_SOLO + b2 * 0.12
	st.t = 0.0
	b.has = true
	b.plop_t = -1.0
	b.moving = false
	return true


func _steps_end(id: int) -> void:
	var st: Steps = _steps[id]
	if st.par >= 0:
		_warp_reset(st.par)
		_steps_par.erase(st.par)
	_steps.erase(id)


## 아기: 일어섬 → 뒤뚱뒤뚱 (가운데서 휘청) → 털썩 → (부모가 있으면) 안겨 올라갔다 내려옴
func _steps_baby(r: Resident, bm: CutoutResident, b: Baby, st: Steps) -> void:
	var t := st.t
	var r2 := Vector2(_right.x, _right.z)
	var b2 := Vector2(_back.x, _back.z)
	var p := st.from
	var clip := "idle"
	var sy := 1.0
	var sx := 1.0
	var lean := 0.0
	var hop := 0.0
	var lift := 0.0
	var pm := vw.residents.get(st.par) as CutoutResident if st.par >= 0 else null
	if t < FS_BACK:
		if (st.from - st.at).length() > 0.08:                 # 가려진 곳에 있었으면 먼저 트인 곳으로 아장아장
			p = st.at.lerp(st.from, smoothstep(0.0, 1.0, t / FS_BACK))
			clip = "walk"
			lean = sin(_clock * 10.0) * 0.15
		else:
			clip = "sit" if t < 0.22 else "idle"
			lean = sin(_clock * 7.0) * 0.07
			hop = 0.05 * sin(clampf((t - 0.22) / 0.2, 0.0, 1.0) * PI)     # 영차, 일어섬
	elif t < FS_WALK_END:
		var u := (t - FS_BACK) / (FS_WALK_END - FS_BACK)
		var stall := u > 0.4 and u < 0.58                     # 두어 걸음 → 휘청 → 남은 걸음은 와다다
		p = st.from.lerp(st.to, 0.46 * smoothstep(0.0, 0.4, u) + 0.54 * smoothstep(0.58, 1.0, u))
		var wob := sin(_clock * 10.0)
		lean = wob * (0.27 if stall else 0.17)
		hop = 0.0 if stall else absf(wob) * 0.028
		clip = "idle" if stall else "walk"
		if st.done & 1 == 0 and u > 0.12:
			st.done |= 1
			if st.par >= 0:
				_say(st.par, "first", "love", 2.6)
	elif t < FS_PLOP_END or pm == null:
		p = st.to
		clip = "sit"
		var q := clampf((t - FS_WALK_END) / 0.28, 0.0, 1.0)
		sy = 1.0 - 0.22 * sin(q * PI)
		sx = 1.0 + 0.2 * sin(q * PI)
		if q >= 1.0 and pm == null:
			hop = absf(sin(_clock * 9.0)) * 0.022                 # 까르르 (혼자)
		if st.done & 2 == 0:
			st.done |= 2
			_puff(Vector3(p.x, _gy(p.x, p.y), p.y))
			GameAudio.fx("baby_giggle_%d" % (r.id % 2), "Village", -6.0)
			if pm == null:
				_say(r.id, "baby", "cheer", 1.8)
				_fx("sparkle", p, 0.4, 1.2, FS_SPARK)
	else:
		var hold := st.p1 + b2 * 0.07 - r2 * st.side * 0.04
		var down := st.p1 - r2 * st.side * 0.3 + b2 * 0.04
		clip = "sit"
		if t < FS_LIFT_END:
			var k := smoothstep(0.0, 1.0, (t - FS_PLOP_END) / (FS_LIFT_END - FS_PLOP_END))
			p = st.to.lerp(hold, k)
			lift = k
		elif t < FS_DOWN:
			p = hold
			lift = 1.0
		else:
			var k := smoothstep(0.0, 1.0, (t - FS_DOWN) / (FS_SECS - FS_DOWN))
			p = hold.lerp(down, k)
			lift = 1.0 - k
		lift *= FS_HOLD * pm._doll_h / _cu
		if t < FS_DOWN:
			hop = pm._lift * pm.scale.y                         # 들썩이는 부모 품에서 함께
		if st.done & 4 == 0 and t > FS_PLOP_END + 0.2:
			st.done |= 4
			_fx("hearts", st.p1, 0.8, 1.3)
			GameAudio.fx("chime", "Room", -12.0)
	if pm != null and t >= FS_BACK and t < FS_SECS:
		pm.carry_baby = true                               # 두 팔을 앞으로 (안기 팔 — place_babies가 매번 지우므로 매 화면)
		pm._refresh_doll()
	var d := st.to - st.from
	st.bpos = p
	b.pos = p
	b.yaw = atan2(d.x, d.y)
	b.sp = 0.4 if clip == "walk" else 0.0
	bm.toddle_clip = clip
	bm.position = Vector3(p.x, _gy(p.x, p.y), p.y)
	bm.rotation.y = b.yaw
	if clip == "walk":
		bm._ground = 0.4
	bm.set_body_lift((hop + lift) / maxf(bm.scale.y, 0.01))
	bm.set_body_warp(sy, sx, lean)
	bm._refresh_doll()


## 부모: 몇 걸음 물러남 → 돌아서 쪼그려 앉아 두 팔을 벌림 → 안아 올리며 일어섬 → 들썩 → 끝나면 시뮬 자리로 (화면 자리만 — 시뮬은 그대로)
func _steps_parent(r: Resident, m: ResidentModel) -> void:
	var st: Steps = _steps.get(int(_steps_par[r.id]))
	if st == null or st.t < 0.0:
		_steps_par.erase(r.id)
		return
	var t := st.t
	var cm := m as CutoutResident
	var simp := Vector2(m.position.x, m.position.z)
	var p := st.p1
	var anim := "idle"
	var sy := 1.0
	var sx := 1.0
	var lean := 0.0
	var hop := 0.0
	var look := st.bpos
	var toward := -st.side                         # 아기 쪽 (화면 가로)
	if t < FS_BACK:
		var d := st.p1 - st.p0
		p = st.p0.lerp(st.p1, smoothstep(0.0, 1.0, t / FS_BACK))
		if d.length() > 0.12:
			anim = "walk"
			look = p + d
			m._ground = snappedf(clampf(d.length() / FS_BACK, 0.3, RUN_LEGS), 0.15)
	elif t < FS_PLOP_END:
		var k := smoothstep(0.0, 1.0, (t - FS_BACK) / 0.25)
		sy = lerpf(1.0, FS_CROUCH.x + 0.02 * sin(_clock * 6.0), k)     # 까딱까딱 부름
		sx = lerpf(1.0, FS_CROUCH.y, k)
		lean = 0.12 * k * toward
	elif t < FS_LIFT_END:
		var k := (t - FS_PLOP_END) / (FS_LIFT_END - FS_PLOP_END)
		var up := smoothstep(0.3, 1.0, k)
		sy = lerpf(FS_CROUCH.x, 1.0, up) - 0.05 * sin(clampf(k / 0.3, 0.0, 1.0) * PI)
		sx = lerpf(FS_CROUCH.y, 1.0, up)
		lean = 0.16 * toward * (1.0 - up)
	elif t < FS_SECS:
		if t < FS_DOWN:
			hop = absf(sin((t - FS_LIFT_END) * 11.5)) * 0.04      # 좋아서 들썩
		else:
			var k := sin((t - FS_DOWN) / (FS_SECS - FS_DOWN) * PI)
			sy = 1.0 - 0.1 * k
			lean = 0.1 * toward * k
	else:
		var k := smoothstep(0.0, 1.0, (t - FS_SECS) / FS_RELEASE)
		p = st.p1.lerp(simp, k)
		if (simp - st.p1).length() > 0.12:
			anim = "walk"
			look = simp
			m._ground = snappedf(clampf((simp - st.p1).length() / FS_RELEASE, 0.3, RUN_LEGS), 0.15)
	m.position = Vector3(p.x, _gy(p.x, p.y), p.y)
	if (look - p).length() > 0.02:
		m.rotation.y = atan2(look.x - p.x, look.y - p.y)
	m.set_anim(anim, r.action)
	if cm != null:
		cm.set_body_lift(hop / maxf(cm.scale.y, 0.01))
		cm.set_body_warp(sy, sx, lean)
