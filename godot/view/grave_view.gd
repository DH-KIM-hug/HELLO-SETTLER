## 무덤 곁의 꽃 · 작은 빛 · 손에 든 꽃 (EVENTS_STAGING 5 첫 죽음과 장례 — E1-5, 2026-11-10).
## 돌은 VillageView._sync_graves가 그린다 (Village.graves — 묘지 안 또는 마을 끝). 여기는 그 위에 얹는 것만:
##   - 꽃: 새 무덤 발치에 작은 꽃 FLOWER_MAX송이. FLOWER_FULL일 지나면 한 송이씩 시들어 FLOWER_DAYS일에 모두 사라진다 (돌은 남는다)
##   - 작은 빛: 묻힌 지 LIGHT_DAYS일 동안 돌 위에 머무는 따뜻한 빛 (숨 쉬듯 — 차츰 옅어짐)
##   - 손에 든 꽃: 장례 연출의 인형(give · take) + 시뮬레이션의 장례 행렬("○○의 장례에 가는 중"으로 걷는 사람)
##   - 연출이 정하는 동안(stage): 돌을 아직 세우지 않음 (VillageView.grave_hide) · 놓인 꽃 수 · 빛
## 화면만 (ADR-0001): Village.graves · 주민의 하는 일을 읽기만 한다. 난수 없음 (꽃 자리·빛깔은 무덤 id에서). 마을 데이터 좌표 노드(VillageView) 아래.
class_name GraveView
extends Node3D

const FLOWER_MAX := 5                 # 새 무덤의 꽃 (송이)
const FLOWER_FULL := 2.0              # 이만큼(병 날)은 모두 싱싱
const FLOWER_DAYS := 5.0              # 이만큼 지나면 꽃은 모두 사라짐 (돌은 남음)
const LIGHT_DAYS := 1.0               # 작은 빛이 머무는 날
const LIGHT_FADE := 0.3               # 그 하루의 끝 이만큼(몫) 동안 스러짐 — 그 앞까지는 또렷이 머묾
const LIGHT_A := 0.6                  # 둘레의 따뜻한 빛 (더하기 — 어스름·밤에 번짐)
const LIGHT_SIZE := 1.15              # 〃 지름 (칸)
const GLOW_A := 0.9                   # 돌 위에 앉은 작은 불빛 (섞기 — 한낮의 밝은 풀밭 위에서도 보임). 테두리 없는 부드러운 점 — 표시(UI)처럼 읽히지 않게
const GLOW_SIZE := 0.42               # 〃 지름 (칸 — 꽃 한 송이쯤)
const GLOW_H := 0.62                  # 〃 높이 (돌 머리 바로 위)
const GLOW_COL := Color(1.0, 0.95, 0.74)
const STONE_H := 0.63                 # 돌 그림 키 (칸 — Bld2D "grave")
const STONE_K := 1.15                 # 홀로 선 돌의 크기 (가까이서 볼 때 — 전보다 조금 크게)
const STONE_K_MAX := 1.6              # 멀리서 볼 때 키우는 상한 (어른 키쯤 — 그보다 크면 돌이 아니라 바위로 읽힘)
const STONE_PX := 15.0                # 돌이 화면에서 적어도 이만큼(세로 화면 점)은 보이게 — 마을 기본 확대(16)에서 어른 키쯤
const FLOWER_SIZE := 0.26             # 꽃 한 송이 (칸)
const HAND_SIZE := 0.24
const HAND_H := 0.4                   # 손 높이 (어른 키 0.88의 몫)
const CHECK := 0.4                    # 꽃·빛을 다시 세는 간격 (현실 초)
const PETALS := [Color("fff6ea"), Color("f7b6c6"), Color("ffe08a")]      # 흰 · 연분홍 · 연노랑 (따뜻하게 — 검은색·회색 없음)
const WILT := Color("c9b98a")         # 시든 빛
const NODE_NAME := "GraveView"
const MOURN_SY := 0.94                # 무덤가에 선 사람의 고개 숙임: 인형 키가 이만큼 (StageDolls.DROOP과 같은 정도 — 인형 통째, 새 그림 없음)
const MOURN_LEAN := 0.1               # … 돌 쪽으로 기우는 정도 (라디안 — CutoutResident.set_body_warp)
const MOURN_IN := 0.7                 # 고개를 숙이고 드는 시간 (현실 초)

var view: VillageView
var v: Village
var driven := false
var stage: Dictionary = {}            # 무덤 id → {"stone": bool, "flowers": int, "light": bool} (연출 동안만 — 없으면 묻힌 날로)
var _marks: Dictionary = {}           # 무덤 id → {"root": Node3D, "flowers": Array[MeshInstance3D], "light": MeshInstance3D, "lit": float, "pop": Array[float]}
var _hands: Dictionary = {}           # 주민 id → MeshInstance3D (손에 든 꽃)
var _held: Dictionary = {}            # 주민 id → true: 연출이 쥐여 준 꽃 (시뮬레이션 행렬이 건드리지 않음)
var _no_carry: Dictionary = {}        # "○○의 장례에 가는 중" → true: 긴 연출에서 이미 꽃을 놓은 장례 (끝난 뒤 그 행렬은 빈손으로)
var _mourn: Dictionary = {}           # 주민 id → 그 사람이 선 무덤 자리 (Vector2): 깨닫기 전 장례 행렬에서 무덤가에 서 있는 사람 (VillageEra.MOURN)
var _bowed: Dictionary = {}           # 주민 id → 고개 숙인 정도 0~1 (여기서 얹은 몸짓만 — 끝나면 되돌림)
var _bowed_side: Dictionary = {}      # 주민 id → 기운 쪽 (+1 화면 오른쪽) — 고개를 드는 동안에도 같은 쪽으로
var _tex: Array = []                  # 꽃 그림 (빛깔마다)
var _since := 1.0e9
var _key := ""
var _t := 0.0


## 그 마을 화면의 것 (없으면 만듦)
static func of(vw: VillageView, q: Village) -> GraveView:
	if vw == null or not is_instance_valid(vw):
		return null
	var g: GraveView = vw.get_node_or_null(NODE_NAME)
	if g == null:
		g = GraveView.new()
		g.name = NODE_NAME
		g.view = vw
		vw.add_child(g)
	g.v = q
	return g


static func grave_of(q: Village, id: int) -> Dictionary:
	for g: Dictionary in q.graves:
		if int(g["id"]) == id:
			return g
	return {}


# ───────────────────────── 꽃 수 · 빛 (묻힌 날에서) ─────────────────────────
## 묻힌 지 days일 된 무덤의 꽃 (송이)
static func flowers_at(days: float) -> int:
	if days < FLOWER_FULL:
		return FLOWER_MAX
	if days >= FLOWER_DAYS:
		return 0
	return int(ceil(float(FLOWER_MAX) * (1.0 - (days - FLOWER_FULL) / (FLOWER_DAYS - FLOWER_FULL))))


## 꽃이 시든 정도 0~1 (사라지기 전 하루 남짓 빛이 바램)
static func wilt_at(days: float) -> float:
	return clampf((days - FLOWER_FULL) / (FLOWER_DAYS - FLOWER_FULL), 0.0, 1.0)


## 작은 빛 0~1: 하루(LIGHT_DAYS) 동안 머묾 — 끝 무렵(LIGHT_FADE)에만 스러짐 (전에는 처음부터 고르게 옅어져 반나절이면 안 보였다)
static func light_at(days: float) -> float:
	if days < 0.0:
		return 1.0
	return clampf((1.0 - days / LIGHT_DAYS) / LIGHT_FADE, 0.0, 1.0)


## 홀로 선 돌의 크기 몫 (화면 확대 ppu = 한 칸이 화면 점 몇 개인가): 가까이서는 STONE_K, 멀어질수록 화면에서 STONE_PX는 되게 키움 (STONE_K_MAX까지).
## 0.05 걸음 — 확대를 바꾸는 동안 돌 그림을 매 화면 다시 만들지 않게
static func stone_k(ppu: float) -> float:
	return snappedf(clampf(STONE_PX / (STONE_H * maxf(ppu, 1.0)), STONE_K, STONE_K_MAX), 0.05)


## 그 무덤 돌(과 발치의 꽃·빛)의 크기 몫: 묘지 안의 돌은 촘촘히 서 있으므로 그대로 (묘지가 표지), 홀로 선 돌만 k
static func stone_k_of(g: Dictionary, k: float) -> float:
	return 1.0 if bool(g.get("yard", false)) else k


## (화면 · 시험) 지금 그 무덤에 보이는 것 {stone, flowers, light 0~1}
func shown(id: int) -> Dictionary:
	var g := grave_of(v, id) if v != null else {}
	if g.is_empty():
		return {"stone": false, "flowers": 0, "light": 0.0}
	if stage.has(id):
		var s: Dictionary = stage[id]
		return {"stone": bool(s.get("stone", true)), "flowers": int(s.get("flowers", 0)), "light": 1.0 if bool(s.get("light", false)) else 0.0}
	var days := (v.t - float(g["t"])) / Balance.DAY
	return {"stone": true, "flowers": flowers_at(days), "light": light_at(days)}


# ───────────────────────── 연출이 부르는 것 ─────────────────────────
## 연출 시작: 돌은 아직 (hide) · 꽃 없음 · 빛 없음
func stage_begin(id: int, hide_stone: bool) -> void:
	stage[id] = {"stone": not hide_stone, "flowers": 0, "light": false}
	_apply_hide()
	_since = 1.0e9


func stage_stone(id: int) -> void:
	if stage.has(id):
		stage[id]["stone"] = true
		_apply_hide()
		_since = 1.0e9


## 꽃 한 송이를 놓음 (FLOWER_MAX까지)
func stage_lay(id: int) -> void:
	if stage.has(id):
		stage[id]["flowers"] = mini(FLOWER_MAX, int(stage[id]["flowers"]) + 1)
		_since = 1.0e9


func stage_light(id: int) -> void:
	if stage.has(id):
		stage[id]["light"] = true
		_since = 1.0e9


## 연출 끝 (건너뛰기 포함): 묻힌 날의 모습으로 — 돌 · 꽃 · 빛 모두
func stage_end(id: int) -> void:
	stage.erase(id)
	_apply_hide()
	_since = 1.0e9


func _apply_hide() -> void:
	if view == null or not is_instance_valid(view):
		return
	var hide := {}
	for id: int in stage:
		if not bool(stage[id].get("stone", true)):
			hide[id] = true
	if hide != view.grave_hide:
		view.grave_hide = hide


## 손에 꽃을 쥐여 줌 (연출의 인형)
func give(rid: int) -> void:
	_held[rid] = true
	_hand(rid)


func take(rid: int) -> void:
	_held.erase(rid)
	_drop_hand(rid)


## 긴 연출에서 꽃을 다 놓은 장례 — 연출이 끝난 뒤 시뮬레이션 행렬이 꽃을 또 들지 않게
func staged_for(who: String) -> void:
	_no_carry["%s의 장례에 가는 중" % who] = true


func holding(rid: int) -> bool:
	return _hands.has(rid)


func clear_hands() -> void:
	for rid: int in _hands.keys():
		_drop_hand(rid)
	_held.clear()


func _hand(rid: int) -> void:
	if _hands.has(rid):
		return
	var f := _flower(HAND_SIZE, rid % PETALS.size())
	add_child(f)
	_hands[rid] = f
	_place_hand(rid)


func _drop_hand(rid: int) -> void:
	var f: Variant = _hands.get(rid)
	if f != null and is_instance_valid(f):
		(f as Node).queue_free()
	_hands.erase(rid)


# ───────────────────────── 한 화면 ─────────────────────────
func _process(dt: float) -> void:
	if not driven:
		step(dt)


func step(dt: float) -> void:
	if v == null or view == null or not is_instance_valid(view):
		return
	_t += dt
	_since += dt
	var sk := stone_k(_ppu())
	if not is_equal_approx(sk, view.grave_k):       # 확대가 바뀜 → 돌(VillageView._sync_graves)과 발치의 꽃·빛을 그 크기로
		view.grave_k = sk
		_since = 1.0e9
	var key := "%d|%d" % [v.graves.size(), v.water.rot]
	if key != _key or _since >= CHECK:
		_key = key
		_since = 0.0
		_refresh()
		_walkers()
	for id: int in _marks:
		var m: Dictionary = _marks[id]
		var lit: float = m["lit"]
		var lm: MeshInstance3D = m["light"]
		var gm: MeshInstance3D = m["glow"]
		lm.visible = lit > 0.01
		gm.visible = lm.visible
		if lm.visible:
			var br := 1.0 + 0.12 * sin(_t * 1.9 + float(id))      # 숨 쉬듯
			(lm.material_override as StandardMaterial3D).albedo_color.a = LIGHT_A * lit * br
			(gm.material_override as StandardMaterial3D).albedo_color.a = minf(1.0, GLOW_A * lit * (0.94 + 0.5 * (br - 1.0)))
			gm.position.y = GLOW_H + 0.025 * sin(_t * 1.1 + float(id) * 0.7)      # 아주 조금 떠오르내림
		var fl: Array = m["flowers"]
		var pop: Array = m["pop"]
		for i in fl.size():                        # 놓인 꽃이 톡 나타남
			if float(pop[i]) < 1.0:
				pop[i] = minf(1.0, float(pop[i]) + dt / 0.3)
				var u := float(pop[i])
				(fl[i] as MeshInstance3D).scale = Vector3.ONE * (u * (2.0 - u))
	for rid: int in _hands.keys():
		_place_hand(rid)
	_bow_step(dt)


## 깨닫기 전 장례 행렬: 무덤가에 선 사람은 무릎 꿇지 않고 고개를 숙인다 — 인형 통째로 조금 낮추고 돌 쪽으로 기울임 (화면만).
## 깨달은 뒤의 행렬은 시뮬레이션의 기도 몸짓("pray" → 무릎) 그대로라 여기서 건드리지 않는다.
func _bow_step(dt: float) -> void:
	if _mourn.is_empty() and _bowed.is_empty():
		return
	for rid: int in _mourn:
		if not _bowed.has(rid):
			_bowed[rid] = 0.0
	var ax := _cam_axes()
	for rid: int in _bowed.keys():
		var on := _mourn.has(rid) and (not view.staged.has(rid) or _stays(rid)) and not view.fast
		var w := move_toward(float(_bowed[rid]), 1.0 if on else 0.0, dt / MOURN_IN if dt > 0.0 else 1.0)
		var cm := view.residents.get(rid) as CutoutResident
		if cm == null or not is_instance_valid(cm) or (w <= 0.0 and not on):
			if cm != null and is_instance_valid(cm):
				cm.set_body_warp()
			_bowed.erase(rid)
			continue
		_bowed[rid] = w
		var side := 1.0
		if _mourn.has(rid):
			var gp: Vector2 = _mourn[rid]
			var d := Vector3(gp.x - cm.position.x, 0.0, gp.y - cm.position.z)
			side = -1.0 if d.dot(ax[1]) < 0.0 else 1.0
			_bowed_side[rid] = side
		else:
			side = float(_bowed_side.get(rid, 1.0))
		var e := w * w * (3.0 - 2.0 * w)
		cm.set_body_warp(lerpf(1.0, MOURN_SY, e) * (1.0 + 0.006 * sin(_t * 1.3 + float(rid))), 1.0, MOURN_LEAN * side * e)
	for rid: int in _bowed_side.keys():
		if not _bowed.has(rid):
			_bowed_side.erase(rid)


## 긴 장례 연출이 끝난 뒤 무덤가에 머물러 선 사람인가 (StageDolls.hold가 VillageView.staged에 적어 둠)
func _stays(rid: int) -> bool:
	var st: Variant = view.staged.get(rid)
	return st is Dictionary and bool((st as Dictionary).get("hold", false))


## (화면 · 시험) 그 사람이 지금 무덤가에서 고개를 숙이고 있는 정도 0~1
func bowed(rid: int) -> float:
	return float(_bowed.get(rid, 0.0))


## 지금 화면 확대 (한 칸이 화면 점 몇 개인가 — VillageView._flora_lod와 같은 셈). 카메라가 없으면 (시험) 마을 기본 확대
func _ppu() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL or cam.size <= 0.0:
		return float(JarCamera.ZOOM_PPU[1])
	return float(get_viewport().get_visible_rect().size.y) / cam.size


## 화면 기준 두 축 (마을 화면 좌표): [카메라 쪽, 화면 오른쪽] — 카메라가 없으면 기본값
func _cam_axes() -> Array:
	var front := Vector3(0, 0, 1)
	var side := Vector3(1, 0, 0)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var inv := global_transform.basis.inverse()
		var bz := inv * Vector3(cam.global_transform.basis.z.x, 0, cam.global_transform.basis.z.z)
		var bx := inv * Vector3(cam.global_transform.basis.x.x, 0, cam.global_transform.basis.x.z)
		if bz.length() > 0.01 and bx.length() > 0.01:
			front = bz.normalized()
			side = bx.normalized()
	return [front, side]


## 무덤마다 꽃·빛을 지금 모습에 맞춤 (꽃이 남은 새 무덤만 노드를 가짐)
func _refresh() -> void:
	var live := {}
	for g: Dictionary in v.graves:
		var id := int(g["id"])
		var s := shown(id)
		if int(s["flowers"]) <= 0 and float(s["light"]) <= 0.0:
			continue
		live[id] = true
		var m: Dictionary = _marks.get(id, {})
		if m.is_empty():
			m = _make(id)
			_marks[id] = m
		var x := float(g["x"])
		var z := float(g["y"])
		(m["root"] as Node3D).position = Vector3(x, view.gy(x, z), z)
		(m["root"] as Node3D).scale = Vector3.ONE * stone_k_of(g, view.grave_k)      # 꽃·빛도 돌과 같은 몫으로
		m["lit"] = float(s["light"])
		var fl: Array = m["flowers"]
		var pop: Array = m["pop"]
		var days := (v.t - float(g["t"])) / Balance.DAY
		var wl := 0.0 if stage.has(id) else wilt_at(days)
		for i in fl.size():
			var f: MeshInstance3D = fl[i]
			var on := i < int(s["flowers"])
			if on and not f.visible:
				pop[i] = 0.0 if stage.has(id) else 1.0      # 연출 중에 놓는 꽃만 톡 — 평소엔 그냥 있음
				f.scale = Vector3.ONE * (0.01 if stage.has(id) else 1.0)
			f.visible = on
			(f.material_override as StandardMaterial3D).albedo_color = Color.WHITE.lerp(WILT, wl * 0.8)
	for id: int in _marks.keys():
		if not live.has(id):
			(_marks[id]["root"] as Node3D).queue_free()
			_marks.erase(id)


func _make(id: int) -> Dictionary:
	var root := Node3D.new()
	root.name = "Grave_%d" % id
	add_child(root)
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var rt := Vector3(cos(yaw), 0, -sin(yaw))          # 기본 보기에서 화면 오른쪽 · 카메라 쪽 (돌 앞에 꽃이 놓이게)
	var fw := Vector3(sin(yaw), 0, cos(yaw))
	var fl: Array = []
	var pop: Array = []
	for i in FLOWER_MAX:
		var f := _flower(FLOWER_SIZE * (0.9 + 0.2 * fposmod(float(id) * 0.31 + float(i) * 0.47, 1.0)), (id + i) % PETALS.size())
		var across := (float(i) - float(FLOWER_MAX - 1) * 0.5) * 0.17
		var front := 0.2 + 0.07 * float((i + id) % 2) + 0.02 * float(i % 3)
		f.position = rt * across + fw * front
		f.visible = false
		root.add_child(f)
		fl.append(f)
		pop.append(1.0)
	var lm := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(LIGHT_SIZE, LIGHT_SIZE)
	lm.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true                   # 돌과 같은 몫으로 커짐 (root.scale)
	mat.albedo_texture = SkyDescent.soft_tex()
	mat.albedo_color = Color(1.0, 0.86, 0.56, 0.0)
	lm.material_override = mat
	lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lm.position = Vector3(0, 0.5, 0)
	lm.visible = false
	root.add_child(lm)
	var gm := MeshInstance3D.new()                    # 돌 위에 앉은 작은 불빛 (섞기 — 낮에도 보임)
	var gq := QuadMesh.new()
	gq.size = Vector2(GLOW_SIZE, GLOW_SIZE)
	gm.mesh = gq
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gmat.billboard_keep_scale = true
	gmat.albedo_texture = SkyDescent.soft_tex()
	gmat.albedo_color = Color(GLOW_COL.r, GLOW_COL.g, GLOW_COL.b, 0.0)
	gmat.render_priority = 1
	gm.material_override = gmat
	gm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gm.position = Vector3(0, GLOW_H, 0)
	gm.visible = false
	root.add_child(gm)
	return {"root": root, "flowers": fl, "light": lm, "glow": gm, "lit": 0.0, "pop": pop}


## 시뮬레이션의 장례 행렬 (VillageEra.on_death — "○○의 장례에 가는 중"으로 걷는 사람)이 꽃을 들고 걷는다. 닿으면(걸음을 멈추면) 내려놓음.
## 깨닫기 전의 행렬(VillageEra.MOURN)은 닿은 뒤 서서 고개를 숙인다 (_bow_step) — 깨달은 뒤에는 무릎 (시뮬레이션의 기도 몸짓).
func _walkers() -> void:
	var want := {}
	_mourn.clear()
	if not view.fast and stage.is_empty():
		var names := {}
		var all := {}
		for g: Dictionary in v.graves:
			if (v.t - float(g["t"])) / Balance.DAY < LIGHT_DAYS:
				var nm := VillageEra.FUNERAL_DOING % String(g["name"])
				all[nm] = Vector2(float(g["x"]), float(g["y"]))
				if not _no_carry.has(nm):
					names[nm] = true
		if not all.is_empty():
			for r in v.people:
				if not VillageEra.in_funeral(r) or not all.has(r.doing):
					continue
				if _stays(r.id):                             # 긴 연출 뒤 무덤가에 머무는 사람 (StageDolls.hold — 시뮬레이션은 아직 걸어오는 중)
					if r.action == VillageEra.MOURN:
						_mourn[r.id] = all[r.doing]
				elif r.anim == "walk":
					if names.has(r.doing) and not _held.has(r.id):
						want[r.id] = true
				elif r.action == VillageEra.MOURN:
					_mourn[r.id] = all[r.doing]
	for rid: int in _hands.keys():
		if not want.has(rid) and not _held.has(rid):
			_drop_hand(rid)
	for rid: int in want:
		_hand(rid)


func _place_hand(rid: int) -> void:
	var f: MeshInstance3D = _hands.get(rid)
	if f == null or not is_instance_valid(f):
		_hands.erase(rid)
		return
	var m: Node3D = view.residents.get(rid)
	if m == null or not is_instance_valid(m) or not m.visible:
		f.visible = false
		return
	f.visible = true
	var ax := _cam_axes()                          # 인형(카메라를 보는 종이) 앞쪽으로 살짝 — 인형에 묻히지 않게 (BabyBundle과 같은 길)
	var front: Vector3 = ax[0]
	var side: Vector3 = ax[1]
	var hs := m.scale.y
	f.position = m.position + front * 0.14 + side * (0.13 if rid % 2 == 0 else -0.13) + Vector3(0, HAND_H * hs, 0)


# ───────────────────────── 꽃 그림 ─────────────────────────
func _flower(sz: float, col: int) -> MeshInstance3D:
	while _tex.size() < PETALS.size():
		_tex.append(flower_tex(PETALS[_tex.size()]))
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(sz, sz * 1.5)
	q.center_offset = Vector3(0, sz * 0.75, 0)         # 줄기 끝이 땅(손)에
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = _tex[col]
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 작은 꽃 한 송이: 둥근 꽃잎 다섯 + 노란 꽃술 + 짧은 줄기와 잎 (가로 32 · 세로 48 — 작게 그려도 꽃으로 읽히게 꽃송이를 크게)
static func flower_tex(petal: Color) -> ImageTexture:
	var w := 32
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var stem := Color("6f9a4c")
	var heart := Color("f0b33c")
	var edge := petal.darkened(0.16)
	var c := Vector2(16.0, 14.0)
	for y in h:
		for x in w:
			var acc := Color(0, 0, 0, 0)
			var hit := 0.0
			for sy in 2:
				for sx in 2:
					var p := Vector2(float(x) + 0.25 + 0.5 * sx, float(y) + 0.25 + 0.5 * sy)
					var col := Color(0, 0, 0, 0)
					if absf(p.x - 16.0 - 1.5 * sin((p.y - 20.0) * 0.12)) <= 1.5 and p.y >= 20.0 and p.y <= 47.0:
						col = stem
					if Vector2((p.x - 21.0) / 5.5, (p.y - 35.0) / 2.6).length() <= 1.0:      # 잎
						col = stem.lightened(0.12)
					for i in 5:
						var a := TAU * float(i) / 5.0 - PI * 0.5
						var d := p.distance_to(c + Vector2(cos(a), sin(a)) * 7.2)
						if d <= 6.3:
							col = petal if d <= 5.0 else edge
					if p.distance_to(c) <= 4.0:
						col = heart
					if col.a > 0.0:
						acc += col
						hit += 1.0
			if hit > 0.0:
				img.set_pixel(x, y, Color(acc.r / hit, acc.g / hit, acc.b / hit, hit / 4.0))
	return ImageTexture.create_from_image(img)
