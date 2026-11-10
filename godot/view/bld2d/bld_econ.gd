## 보이는 살림 — 건물 쪽 (ROADMAP Q6 · E0-3). 화면만: 시뮬레이션을 읽기만 하고 아무것도 쓰지 않는다 (ADR-0001 — 난수도 시뮬 것을 쓰지 않음,
## 켜든 끄든 결과가 같다). 2D 그림 건물(Bld2D)일 때만 그린다 (3D 대역은 예전 더미 그대로).
##  ① 짓는 터: 도착한 판자·돌 더미(지으면서 줄어듦) + 터 앞 말뚝 다섯 (지은 만큼 잎 깃발이 꽂힘) + 다 지으면 '퐁' (그림이 통 튀고 잎·먼지·별)
##  ② 일터 앞 더미: 들어온 재료(왼쪽)·쌓인 산출물(오른쪽) 세 단계 · 창고 앞엔 창고에 든 것 · 집 옆엔 땔감
##  ③ 돌아가는 일터만 움직임: 화덕 김 · 맷돌 가루 · 톱밥 · 우물 물방울 · 소금 반짝 · 불 땐 집 연기 (멈추면 고요)
##  ④ 막힌 일터는 그림 생각 풍선: 모자란 재료 · 빈 밀짚모자(일손 없음) · 넘치는 바구니(나르는 손이 없음) — 글·숫자 없음, 한 화면에 몇 개만
## 그림은 전부 아틀라스 하나(art/bld2d/econ_atlas.png — tools/bld2d/econ_sprites.py) + MultiMesh 하나 = 어느 확대에서든 그리기 1번.
## 움직임은 셰이더(bld_econ.gdshader)가 화면 시계로 — 목록이 바뀔 때만 버퍼를 올린다.
class_name BldEcon
extends Node3D

const Pics := preload("res://view/bld2d/bld_econ_pics.gd")
const SHADER := preload("res://view/bld2d/bld_econ.gdshader")

const CAP := 768                 # MultiMesh 인스턴스 (넘으면 뒤쪽은 그리지 않음)
const TICK := 0.25               # 목록을 다시 보는 간격 (화면 초 — VillageView의 건물 살핌과 같은 박자)
## 물건 → 더미 그림 (세 단계 _1 · _2 · _3). 없는 물건은 덮개 바구니(goods)
const GOODS := {"통나무": "logs", "판자": "planks", "돌": "stone", "밀": "wheat", "밀가루": "flour", "빵": "bread", "물": "water",
	"소금": "salt", "버섯": "mushroom", "말린 버섯": "dried"}
## 모자란 재료 → 생각 풍선 (없으면 덮개 바구니 풍선)
const WANT := {"통나무": "bub_want_logs", "밀": "bub_want_wheat", "밀가루": "bub_want_flour", "판자": "bub_want_planks", "돌": "bub_want_stone"}
## 그림마다 더미·움직임 자리: [화면 오른쪽, 카메라 쪽(그림 밑변에서)] 칸. fx_at = [화면 오른쪽, 그림 밑변에서 위로]
## (그림에 이미 그려 넣은 자루·통나무 묶음·문을 가리지 않는 자리 — 그림을 보고 잡음)
const LAYOUT := {
	"sawmill": {"in": Vector2(-1.5, 0.3), "out": Vector2(1.5, 0.35), "fx": &"chips", "fx_at": Vector2(0.15, 1.2)},
	"quern_house": {"in": Vector2(-1.3, 0.3), "out": Vector2(1.2, 0.35), "fx": &"flour", "fx_at": Vector2(-0.3, 1.25)},
	"windmill": {"in": Vector2(-1.3, 0.3), "out": Vector2(1.35, 0.35), "fx": &"flour", "fx_at": Vector2(0.0, 1.0)},
	"oven": {"in": Vector2(-1.2, 0.3), "out": Vector2(1.2, 0.35), "fx": &"smoke", "fx_at": Vector2(0.05, 1.55)},
	"bakery": {"fx": &"smoke", "fx_at": Vector2(0.4, 2.6)},
	"well": {"out": Vector2(0.95, 0.3), "fx": &"drops", "fx_at": Vector2(0.0, 1.1)},
	"saltpan": {"out": Vector2(1.5, 0.9), "fx": &"stars", "fx_at": Vector2(0.0, 0.55)},
	"mushroom_hut": {"out": Vector2(1.3, 0.3)},
	"wheat_green": {"out": Vector2(1.5, 0.35)},
	"lumber": {"out": Vector2(-1.35, 0.4), "fx_at": Vector2(0.1, 0.5)},      # 움직임 = 도끼 박힌 그루터기 위
	"quarry": {"out": Vector2(1.85, 0.45), "fx_at": Vector2(-0.35, 1.45)},    # 움직임 = 구덩이 속 바위 위
}
## 채집 일터 (건물에 쌓이는 것이 없다 — 일꾼이 나무·바위에서 일하고 바로 창고로): 종류 → [모으는 것, 일하는 자리의 움직임]
## 더미 = 마을 창고에 든 그 물건 (창고 앞 더미와 같은 기준) · 움직임 = 그 일터 일꾼이 나무·바위에서 일하는 동안,
## 일꾼이 선 자리(나무·바위 곁 — 숲에 가려 안 보일 때가 많다)와 일터 그림(LAYOUT fx_at — "지금 일하는 중" 표시) 두 곳에
const GATHER := {"나무꾼": ["통나무", &"chips"], "채석장": ["돌", &"pebbles"]}
const GATHER_AT_CAMP := true     # false = 일꾼이 선 자리에만 (일터 그림에는 움직임 없음)
const GATHER_LIFT := 0.55        # 일꾼 손 높이 (조각이 튀는 자리)
const GATHER_FRONT := 0.35       # 일꾼보다 카메라 쪽으로 (조각이 일꾼·꽃 그림 앞에 보이게)
const HOUSE_WOOD := Vector2(0.8, 0.1)     # 집 땔감: 그림 왼쪽 끝에서 바깥으로 · 그림 밑변에서 카메라 쪽 (문 옆 단지를 가리지 않게 벽 옆에)
## 더미 앞마당: 건물·짓는 터의 카메라 쪽에 선 키 큰 꽃·풀 그림은 더미를 가리지 않는 키까지만 (VillageView._put이 물음)
const APRON_MIN_H := 0.45        # 이 키까지는 그대로 (더미보다 낮은 풀) — 더미 바로 앞에 선 것은 여기까지 낮춤
const APRON_BACK := 0.3          # 더미 줄보다 이만큼 뒤에 선 것부터 살핌 (그림 밑변이 줄 앞으로 나오는 것)
const APRON_SIDE := 1.4          # 건물 그림 반 폭 + 이것 = 옆으로 살피는 폭 (그림 옆에 놓는 집 땔감까지)
const APRON_SIN := 0.743         # sin 48° (카메라 기울기 — 그림 판은 화면에 제 키 그대로 서므로 키 h는 뒤쪽 땅을 h / sin 만큼 가린다)
## 일할 때 움직임: 그림 · 개수 · 크기 · [오르는 높이, 옆으로 흐름, 한 바퀴(초)] · 퍼지는 폭
const FX := {
	&"smoke": {"pic": "puff", "n": 3, "k": 0.8, "rise": 1.0, "drift": 0.3, "period": 2.8, "spread": 0.0},
	&"flour": {"pic": "puff", "n": 2, "k": 0.5, "rise": 0.4, "drift": -0.25, "period": 1.7, "spread": 0.5},
	&"chips": {"pic": "chip", "n": 3, "k": 1.35, "rise": 0.45, "drift": 0.6, "period": 0.9, "spread": 0.5},
	&"pebbles": {"pic": "pebble", "n": 3, "k": 1.2, "rise": 0.4, "drift": 0.5, "period": 0.8, "spread": 0.4},
	&"drops": {"pic": "drop", "n": 2, "k": 1.3, "rise": -0.45, "drift": 0.0, "period": 1.2, "spread": 0.3},
	&"stars": {"pic": "star", "n": 3, "k": 1.1, "rise": 0.2, "drift": 0.0, "period": 1.5, "spread": 1.8},
}
## 창고 앞에 보이는 것 (칸마다 앞에서부터 있는 것 하나) — 자리 = [화면 오른쪽, 카메라 쪽]
const STORE_SHOW := [["통나무"], ["판자"], ["돌"], ["빵", "밀가루", "밀"]]
const STORE_SLOTS := [Vector2(-1.75, 0.25), Vector2(-1.0, 0.6), Vector2(1.75, 0.25), Vector2(1.0, 0.6)]
const STORE_FULL_DEFAULT := 400.0   # Balance.ENOUGH에 없는 물건(밀)의 '가득'
const UNIT_FULL := 4.0           # 낱개 물건(판자·소금 …)의 산출 더미 '가득' (한 번에 나르는 짐 Balance.CARRY와 같은 값)
const OVERFLOW := 2.0            # 산출 더미가 '가득'의 이만큼이면 넘침 풍선 (나르는 손이 없다)
const PEGS := 5                  # 짓는 터 앞 말뚝 수 (지은 만큼 깃발)
const PEG_GAP := 0.27
const PEG_K := 1.2               # 말뚝 크기
const PILE_K := 1.25             # 더미 크기 (조금 크게 — 폰에서 읽히게)
const BUSH_NEAR := 0.9           # 더미 자리에서 화면 옆으로 이 안에 마당 덤불이 있으면 덤불 앞으로 나온다
const SITE_PILE_X := 1.0         # 짓는 터 자재 더미: 터 그림 폭의 절반 × 이것 (왼쪽 판자 · 오른쪽 돌)
const FRONT_GAP := 0.3           # 더미·말뚝을 그림 밑변에서 카메라 쪽으로 이만큼 (그림 앞에 놓인 것으로 보이게)
const WORK_HOLD := 0.9           # 일터 시계가 마지막으로 움직인 뒤 이만큼은 '돌아가는 중' (깜박임 막기 — 화면 초)
const BUBBLE_DELAY := 1.2        # 막힘이 이만큼 이어져야 풍선 (화면 초)
const BUBBLE_MAX := 3            # 한 화면에 풍선 이만큼만
const POP_SECS := 1.6            # 다 지음 '퐁' 조각이 사는 시간
const BOUNCE_SECS := 0.7         # 다 지은 그림이 통 튀는 시간
const ZOOM_NEAR_PPU := 34.0      # 이보다 가까우면 그림 크기 그대로
const ZOOM_FAR_PPU := 16.0       # 여기까지 멀어지면 ZOOM_FAR_K배 (기본 마을 확대에서도 폰에서 읽히게)
const ZOOM_FAR_K := 1.5

var v: Village
var vw: Node3D                   # VillageView (건물 노드 · 땅 높이)
var on := true                   # 끄면 아무것도 그리지 않음 (시험: 켜든 끄든 시뮬 결과가 같다)
var items: Array = []            # 지금 그리는 것 [[그림, 원점, k, 움직임, t, Color]…] (시험·캡처)
var bubbles := {}                # 건물 id → {pic, seen, t0 (-1 = 아직 안 보임)}
var n_pops := 0                  # 지금까지 터진 '퐁' (시험·캡처)
var _mmi: MultiMeshInstance3D
var _mat: ShaderMaterial
var _t := 0.0                    # 화면 시계
var _tick := 0.0
var _sig := 0
var _lv := {}                    # "건물:칸" → [그림, 바뀐 때] (더미가 바뀌면 통 — plop)
var _prod := {}                  # 건물 id → [지난 timer, 마지막으로 움직인 때]
var _sites := {}                 # 짓는 중이던 건물 id (다 지어지면 퐁)
var _pops: Array = []            # [{t, org, w, h, id}]
var _bounces := {}               # 건물 id → 튀기 시작한 때
var _aprons: Array = []          # 더미 앞마당 목록 (apron_list) — 한 화면에 한 번
var _apron_frame := -1
var _seen_once := false          # 처음 살필 때는 통·퐁 없음 (불러온 마을이 한꺼번에 튀지 않게)
var _r2 := Vector2.RIGHT         # 화면 오른쪽 (마을 기준 땅 위 x·z)
var _f2 := Vector2.DOWN          # 카메라 쪽


func _init(village: Village, view: Node3D) -> void:
	v = village
	vw = view
	name = "econ2d"


func _ready() -> void:
	var n := Pics.PICS.size()
	var geo := PackedVector4Array()
	var uvr := PackedVector4Array()
	geo.resize(n)
	uvr.resize(n)
	for nm: String in Pics.PICS:
		var d: Dictionary = Pics.PICS[nm]
		var r: Rect2 = d["uv"]
		geo[int(d["i"])] = Vector4(d["w"], d["h"], 0.0, 0.0)
		uvr[int(d["i"])] = Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("atlas", load(Pics.ATLAS))
	_mat.set_shader_parameter("geo", geo)
	_mat.set_shader_parameter("uvr", uvr)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = Bld2D.quad()
	mm.instance_count = CAP
	mm.visible_instance_count = 0
	_mmi = MultiMeshInstance3D.new()
	_mmi.name = "econ_cards"
	_mmi.multimesh = mm
	_mmi.material_override = _mat
	_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mmi.custom_aabb = AABB(Vector3(-4096, -64, -4096), Vector3(8192, 256, 8192))     # 늘 그림 (인스턴스가 마을 곳곳에)
	_mmi.visible = false
	add_child(_mmi)


## 매 화면. look = 이번 화면에 건물 노드를 살폈다 (VillageView.sync의 0.25초 박자 · force)
func sync(dt: float, look := false) -> void:
	_t += dt
	if not on or not Bld2D.enabled():
		if not items.is_empty() or _mmi.visible:
			items = []
			bubbles.clear()
			_sig = 0
			_mmi.multimesh.visible_instance_count = 0
			_mmi.visible = false
		return
	_mat.set_shader_parameter("now", _t)
	_mat.set_shader_parameter("zoom_k", zoom_k(_ppu()))
	_tick += dt
	if look or _tick >= TICK:
		_tick = 0.0
		_rebuild()
	if not _bounces.is_empty():
		_bounce_cards()


# ───────────────────────── 규칙 (순수 — 시험) ─────────────────────────
static func has(pic: String) -> bool:
	return Pics.PICS.has(pic)


## 더미 단계: 없음 0 · '가득'의 ⅓까지 1 · ⅔까지 2 · 그 위 3
static func level(amount: float, full: float) -> int:
	if amount < 0.5 or full <= 0.0:
		return 0
	return clampi(ceili(amount / full * 3.0 - 1e-6), 1, 3)


## 짓는 터 자재 더미 단계: 없음 0 · 남은 것이 드는 양의 ⅓까지 1 · ⅔까지 2 · 그 위 3 (작은 집도 큰 집도 '다 왔다 = 가득')
static func site_level(n: int, need: int) -> int:
	if n <= 0:
		return 0
	return clampi(ceili(float(n) / float(maxi(need, 1)) * 3.0 - 1e-6), 1, 3)


## 짓는 터에 아직 남은 자재 (도착한 것 − 지은 몫 · 다 지을 때까지 하나는 남는다)
static func site_left(delivered: int, frac: float) -> int:
	if delivered <= 0:
		return 0
	return maxi(1, ceili(float(delivered) * (1.0 - clampf(frac, 0.0, 1.0)) - 1e-6))


static func goods_pic(k: String, lv: int) -> String:
	return "%s_%d" % [GOODS.get(k, "goods"), clampi(lv, 1, 3)]


## 산출 더미의 '가득': 수레 물건은 한 수레, 낱개는 한 짐
static func out_full(k: String) -> float:
	return float(Balance.BULK.get(k, UNIT_FULL))


static func store_full(k: String) -> float:
	return float(Balance.ENOUGH.get(k, STORE_FULL_DEFAULT))


## 말뚝 i(0부터)에 깃발이 꽂혔나 — 지은 몫 frac
static func peg_on(i: int, frac: float) -> bool:
	return frac >= (float(i) + 0.5) / float(PEGS)


static func zoom_k(ppu: float) -> float:
	return clampf(remap(ppu, ZOOM_NEAR_PPU, ZOOM_FAR_PPU, 1.0, ZOOM_FAR_K), 1.0, ZOOM_FAR_K)


## 건물이 막혔으면 풍선 그림 이름, 아니면 "" (Production.stall_tick의 판정을 읽음 + 넘치는 더미 + 자재가 떨어진 짓는 터)
static func stall_pic(vil: Village, b: Building) -> String:
	if b.is_site():
		if b.site_type() == Awakening.ALTAR or b.materials_ready():
			return ""
		for k: String in ["판자", "돌"]:
			if b.need(k) > int(b.delivered[k]) + int(b.incoming[k]) and float(vil.stock.get(k, 0.0)) < 1.0:
				return String(WANT[k])
		return ""
	var s: Dictionary = vil._stall.get(b.id, {})
	if bool(s.get("stalled", false)):
		var why: StringName = s.get("why", &"")
		if why == &"no_worker":
			return "bub_noworker"
		if why == &"no_input":
			var ins: Dictionary = b.def().get("in", {})
			for k: String in ins:
				if float(b.in_buf.get(k, 0.0)) < float(ins[k]):
					return String(WANT.get(k, "bub_want_goods"))
			return "bub_want_goods"
	for k: String in b.out:
		if float(b.out[k]) >= out_full(k) * OVERFLOW:
			return "bub_full"
	return ""


static func _h(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)


# ───────────────────────── 목록 ─────────────────────────
func _ppu() -> float:
	if not is_inside_tree():
		return ZOOM_NEAR_PPU
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL or cam.size <= 0.0:
		return ZOOM_NEAR_PPU
	return float(get_viewport().get_visible_rect().size.y) / cam.size


func _on_screen(p: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return true
	var gp := to_global(p)
	if cam.is_position_behind(gp):
		return false
	var s := cam.unproject_position(gp)
	var r := get_viewport().get_visible_rect().size
	return s.x > -24.0 and s.y > -24.0 and s.x < r.x + 24.0 and s.y < r.y + 24.0


## 그림 밑변 가운데(org)에서 [화면 오른쪽 sx, 카메라 쪽 sy]만큼 간 땅 위 자리
func _at(org: Vector3, sx: float, sy: float) -> Vector3:
	var x := org.x + _r2.x * sx + _f2.x * sy
	var z := org.z + _r2.y * sx + _f2.y * sy
	return Vector3(x, maxf(org.y, float(vw.gy(x, z))) + 0.02, z)


## 화면 오른쪽·카메라 쪽 (마을 기준). 카메라가 없으면 기본 방위 (JarCamera.BASE_YAW_DEG)
func _dirs() -> void:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	_r2 = Vector2(cos(yaw), -sin(yaw))
	_f2 = Vector2(sin(yaw), cos(yaw))
	if not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var inv := global_transform.basis.inverse()
	var r := inv * cam.global_transform.basis.x
	var f := inv * cam.global_transform.basis.z
	var r2 := Vector2(r.x, r.z)
	var f2 := Vector2(f.x, f.z)
	if r2.length() > 0.05 and f2.length() > 0.05:
		_r2 = r2.normalized()
		_f2 = f2.normalized()


## 더미 하나 (바뀌면 통 — 처음 본 것은 가만히)
func _pile(list: Array, lv2: Dictionary, key: String, pic: String, pos: Vector3, k := PILE_K) -> void:
	var t0 := -100.0
	var old: Array = _lv.get(key, [])
	if not old.is_empty() and String(old[0]) == pic:
		t0 = float(old[1])
	elif _seen_once:
		t0 = _t
	lv2[key] = [pic, t0]
	list.append([pic, pos, k, 1, t0, Color(0, 0, 0, 0)])


func _rebuild() -> void:
	var list: Array = []
	var lv2 := {}
	var sites2 := {}
	var cand: Array = []             # 풍선 후보 [건물 id, 그림, 자리, 높이]
	var blds: Dictionary = vw._blds
	var hidden: Dictionary = vw.hidden_blds
	_dirs()
	for b: Building in v.buildings:
		if b.site_type() == Awakening.ALTAR or hidden.has(b.id) or not blds.has(b.id):
			continue
		var n: Node3D = blds[b.id]
		if not is_instance_valid(n) or not n.visible:
			continue
		var org := n.position
		if absf(org.y - float(vw.gy(org.x, org.z))) > 1.0:      # 하늘에서 내려오는 중
			continue
		var pk := pic_k(v, b)
		var pic := String(pk[0])
		var k := float(pk[1])
		if b.is_site():
			sites2[b.id] = true
		elif _sites.has(b.id) and _seen_once:
			_pop(b, org, pic)
		var d := Bld2D.info(pic)
		if d.is_empty():
			continue
		var w := float(d["w"]) * k
		var h := float(d["h"]) * k
		var ground := int(d.get("mode", 0)) == 1
		var front := h * 0.5 if ground else float(d["front"]) * k
		if b.is_site():
			_site(list, lv2, b, org, w, front)
		else:
			_work(list, lv2, b, org, pic, w, h, front)
		var sp := stall_pic(v, b)
		if sp != "":
			cand.append([b.id, sp, _at(org, 0.0, (0.0 if ground else front) + 0.06), (0.9 if ground else h * 0.78)])
	_bubbles(list, cand)
	var alive: Array = []
	for p: Dictionary in _pops:
		if _t - float(p["t"]) < POP_SECS:
			alive.append(p)
			_pop_items(list, p)
	_pops = alive
	_lv = lv2
	_sites = sites2
	for id: int in _prod.keys():
		if not blds.has(id):
			_prod.erase(id)
	_seen_once = true
	_upload(list)


## 짓는 터: 자재 더미 (왼쪽 판자 · 오른쪽 돌 — 지으면서 줄어듦) + 말뚝 줄 (지은 만큼 깃발)
func _site(list: Array, lv2: Dictionary, b: Building, org: Vector3, w: float, front: float) -> void:
	var frac := clampf(b.prog / float(Balance.B[b.site_type()]["time"]), 0.0, 1.0)
	var px := w * 0.5 * SITE_PILE_X
	var lp := site_level(site_left(int(b.delivered["판자"]), frac), b.need("판자"))
	if lp > 0:
		_pile(list, lv2, "%d:p" % b.id, goods_pic("판자", lp), _at(org, -px, front + FRONT_GAP))
	var ls := site_level(site_left(int(b.delivered["돌"]), frac), b.need("돌"))
	if ls > 0:
		_pile(list, lv2, "%d:s" % b.id, goods_pic("돌", ls), _at(org, px, front + FRONT_GAP))
	for i in PEGS:
		var pic := "peg_on" if peg_on(i, frac) else "peg_off"
		_pile(list, lv2, "%d:g%d" % [b.id, i], pic, _at(org, (float(i) - float(PEGS - 1) * 0.5) * PEG_GAP, front + FRONT_GAP + 0.12), PEG_K)


## 다 지은 건물: 재료·산출 더미 · 창고에 든 것 · 집 땔감 · 돌아가는 동안만 움직임
func _work(list: Array, lv2: Dictionary, b: Building, org: Vector3, pic: String, w: float, h: float, front: float) -> void:
	var lay: Dictionary = LAYOUT.get(pic, {})
	var in_at: Vector2 = lay.get("in", Vector2(-(w * 0.5 - 0.3), FRONT_GAP))
	var out_at: Vector2 = lay.get("out", Vector2(w * 0.5 - 0.3, FRONT_GAP + 0.05))
	var ground := int(Bld2D.info(pic).get("mode", 0)) == 1
	var base := 0.0 if ground else front
	var bushes: Array = []           # 마당 덤불 [화면 오른쪽, 카메라 쪽] (건물 자리에서)
	for e: Array in vw.yard_bush_spots(b):
		var dv := Vector2(float(e[0]) - org.x, float(e[1]) - org.z)
		bushes.append(Vector2(dv.dot(_r2), dv.dot(_f2)))
	if b.is_store:
		for i in STORE_SHOW.size():
			for k: String in STORE_SHOW[i]:
				var lv := level(float(v.stock.get(k, 0.0)), store_full(k))
				if lv > 0:
					var at: Vector2 = STORE_SLOTS[i]
					_pile(list, lv2, "%d:w%d" % [b.id, i], goods_pic(k, lv), _slot(org, at.x, base + at.y, bushes))
					break
		return
	var d := b.def()
	if b.is_house():
		var fl := level(float(b.in_buf.get("통나무", 0.0)), Balance.FUEL_TARGET)
		if fl > 0:
			_pile(list, lv2, "%d:f" % b.id, goods_pic("통나무", fl), _slot(org, -(w * 0.5 + HOUSE_WOOD.x), base + HOUSE_WOOD.y, bushes))
		if b.fuel_on:
			_fx(list, b.id, &"smoke", _at(org, 0.0, base + 0.05), h * 0.8)
		return
	if GATHER.has(b.type):
		var g: Array = GATHER[b.type]
		var gl := level(float(v.stock.get(g[0], 0.0)), store_full(g[0]))
		if gl > 0:
			_pile(list, lv2, "%d:o0" % b.id, goods_pic(g[0], gl), _slot(org, out_at.x, base + out_at.y, bushes))
		var wk := gather_worker(v, b)
		if wk != null:
			var wx := wk.x + _f2.x * GATHER_FRONT
			var wz := wk.y + _f2.y * GATHER_FRONT
			_fx(list, b.id, g[1], Vector3(wx, float(vw.gy(wx, wz)) + 0.02, wz), GATHER_LIFT)
			if GATHER_AT_CAMP and lay.has("fx_at"):
				var ga: Vector2 = lay["fx_at"]
				_fx(list, b.id, g[1], _at(org, ga.x, base + 0.05), ga.y)
		return
	var j := 0
	for k: String in d.get("in", {}):
		var lv := level(float(b.in_buf.get(k, 0.0)), Production.in_cap(k))
		if lv > 0:
			_pile(list, lv2, "%d:i%d" % [b.id, j], goods_pic(k, lv), _slot(org, in_at.x - 0.6 * j, base + in_at.y + 0.2 * j, bushes))
		j += 1
	j = 0
	for k: String in b.out:
		var lv := level(float(b.out[k]), out_full(k))
		if lv > 0:
			_pile(list, lv2, "%d:o%d" % [b.id, j], goods_pic(k, lv), _slot(org, out_at.x + 0.6 * j, base + out_at.y + 0.2 * j, bushes))
		j += 1
	if lay.has("fx") and _producing(b):
		var fa: Vector2 = lay["fx_at"]
		_fx(list, b.id, lay["fx"], _at(org, fa.x, base + 0.05), fa.y)


## 채집 일터의 일꾼이 지금 나무·바위에서 일하는 중이면 그 주민 (아니면 null) — 읽기만
static func gather_worker(vil: Village, b: Building) -> Resident:
	if not b.built or b.worker < 0 or not GATHER.has(b.type):
		return null
	var r := vil.person(b.worker)
	if r == null or r.dead or r.sleeping or r.job != b.id or r.anim != "work" or r.action != "work" or r.carry != "":
		return null
	return r


## 건물의 그림과 배율 [그림 이름, k] — 짓는 터는 터 그림
static func pic_k(vil: Village, b: Building) -> Array:
	if b.is_site():
		var farm := b.site_type() == "농장"
		return ["field_site" if farm else ("scaffold" if b.built else "site_0"), b.size() / 1.8 if farm else b.size()]
	return ["wheat_green" if b.type == "농장" else Bld2D.type_pic(b.type, b.id, vil.era), 1.0]


## 더미 앞마당 목록 [[건물 x, y, 더미 줄(건물 자리에서 카메라 쪽으로), 옆 폭]] — 제단·그림 없는 건물은 뺌
static func apron_list(vil: Village) -> Array:
	var out: Array = []
	for b: Building in vil.buildings:
		if b.site_type() == Awakening.ALTAR:
			continue
		var pk := pic_k(vil, b)
		var d := Bld2D.info(pk[0])
		if d.is_empty():
			continue
		var k := float(pk[1])
		var front := float(d["h"]) * k * 0.5 if int(d.get("mode", 0)) == 1 else float(d["front"]) * k
		out.append([b.x, b.y, front + FRONT_GAP, float(d["w"]) * k * 0.5 + APRON_SIDE])
	return out


## 더미 앞마당에 선 그림의 키 상한: (x, z)에 키 h인 그림이 서면 뒤쪽 건물 앞 더미(줄 위에 놓인 것)를 가리지 않는 키
## (가리지 않으면 h 그대로). aprons = apron_list · half_w = 그림 반 폭 어림. 기본 방위(JarCamera.BASE_YAW_DEG) 기준 —
## VillageView._core_scale과 같은 어림
static func apron_h(aprons: Array, x: float, z: float, h: float, half_w := 0.0) -> float:
	if h <= APRON_MIN_H:
		return h
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var tw := Vector2(sin(yaw), cos(yaw))
	var rt := Vector2(cos(yaw), -sin(yaw))
	var lim := h
	for e: Array in aprons:
		var d := Vector2(x - float(e[0]), z - float(e[1]))
		var along := d.dot(tw) - float(e[2])
		if along <= -APRON_BACK or along * APRON_SIN >= lim or absf(d.dot(rt)) > float(e[3]) + half_w:
			continue
		lim = maxf(APRON_MIN_H, along * APRON_SIN)
	return lim


## 꽃·풀 모델(key)을 (x, z)에 크기 s로 놓을 때 더미 앞마당이면 줄인 크기 (세워 놓는 그림만 — 땅에 눕힌 것은 그대로).
## 앞마당 목록은 한 화면(프레임)·건물 수에 한 번만 만든다 (장식·나무를 다시 놓는 화면에서만 불림)
func apron_scale(key: String, x: float, z: float, s: float) -> float:
	var pic := Flora2D.pic_for(key)
	if pic == "":
		return s
	var inf := Flora2D.info(pic)
	var h := float(inf.get("h", 0.0)) * s
	if int(inf.get("mode", 0)) != 0 or h <= APRON_MIN_H:
		return s
	var fr := Engine.get_process_frames() * 4096 + v.buildings.size()      # 같은 화면이라도 건물 수가 바뀌면 다시
	if fr != _apron_frame:
		_apron_frame = fr
		_aprons = apron_list(v)
	return s * apron_h(_aprons, x, z, h, float(inf.get("w", 0.0)) * s * 0.25) / h


## 더미 자리: 화면 옆으로 가까운 마당 덤불이 앞을 가리면 그 덤불 앞으로 (덤불 뒤에 숨지 않게)
func _slot(org: Vector3, sx: float, sy: float, bushes: Array) -> Vector3:
	var y := sy
	for bp: Vector2 in bushes:
		if absf(bp.x - sx) < BUSH_NEAR and bp.y > sy - 0.6:
			y = maxf(y, bp.y + 0.3)
	return _at(org, sx, y)


## 일터가 지금 돌아가나 — 일터 시계(b.timer)가 요즘 움직였다 (읽기만: 일꾼 없음·재료 없음·넉넉해서 쉼·멈춘 시간이면 고요)
func _producing(b: Building) -> bool:
	var pr: Array = _prod.get(b.id, [])
	if pr.is_empty():
		_prod[b.id] = [b.timer, -100.0]
		return false
	if float(pr[0]) != b.timer:
		pr[0] = b.timer
		pr[1] = _t
	return b.worker >= 0 and _t - float(pr[1]) < WORK_HOLD


func _fx(list: Array, id: int, kind: StringName, pos: Vector3, lift: float) -> void:
	var f: Dictionary = FX[kind]
	var n := int(f["n"])
	for i in n:
		var ph := (float(i) + _h(id, i) * 0.3) / float(n)
		var sx := (_h(id + 0.5, i) - 0.5) * float(f["spread"])
		var dr := float(f["drift"]) * (1.0 if float(f["spread"]) == 0.0 or i % 2 == 0 else -1.0)
		list.append([String(f["pic"]), pos + Vector3(_r2.x * sx, 0.0, _r2.y * sx), float(f["k"]), 3, ph,
			Color(lift + _h(id, i + 7.0) * 0.1, float(f["rise"]), dr, float(f["period"]))])


## 생각 풍선: 막힘이 BUBBLE_DELAY 이어진 것 중 화면 안에서 오래된 순으로 BUBBLE_MAX개 (이미 떠 있는 것 먼저)
func _bubbles(list: Array, cand: Array) -> void:
	var now := {}
	for c: Array in cand:
		var id: int = c[0]
		var e: Dictionary = bubbles.get(id, {})
		if e.is_empty() or String(e["pic"]) != String(c[1]):
			e = {"pic": c[1], "seen": _t, "t0": -1.0}
		e["pos"] = c[2]
		e["lift"] = c[3]
		now[id] = e
	bubbles = now
	var shown: Array = []
	var wait: Array = []
	for id: int in bubbles:
		var e: Dictionary = bubbles[id]
		if _t - float(e["seen"]) < BUBBLE_DELAY or not _on_screen(e["pos"]):
			e["t0"] = -1.0
			continue
		if float(e["t0"]) >= 0.0:
			shown.append(id)
		else:
			wait.append(id)
	shown.sort()
	wait.sort_custom(func(a: int, b: int) -> bool:
		var sa := float(bubbles[a]["seen"])
		var sb := float(bubbles[b]["seen"])
		return sa < sb or (sa == sb and a < b))
	while shown.size() > BUBBLE_MAX:
		bubbles[shown.pop_back()]["t0"] = -1.0
	for id: int in wait:
		if shown.size() >= BUBBLE_MAX:
			break
		bubbles[id]["t0"] = _t
		shown.append(id)
	for id: int in shown:
		var e: Dictionary = bubbles[id]
		list.append([e["pic"], e["pos"], 1.0, 2, float(e["t0"]), Color(float(e["lift"]), _h(id, 3.0) * TAU, 0, 0)])


## 다 지음: 잎·먼지·별 조각 + 그림이 통 튐
func _pop(b: Building, org: Vector3, pic: String) -> void:
	var d := Bld2D.info(pic)
	if d.is_empty():
		return
	n_pops += 1
	var ground := int(d.get("mode", 0)) == 1
	_pops.append({"t": _t, "id": b.id, "w": float(d["w"]), "h": 1.0 if ground else float(d["h"]),
		"org": _at(org, 0.0, (0.0 if ground else float(d["front"])) + 0.08)})
	_bounces[b.id] = _t


func _pop_items(list: Array, p: Dictionary) -> void:
	var id := float(p["id"])
	var t0 := float(p["t"])
	var w := float(p["w"])
	var h := float(p["h"])
	var org: Vector3 = p["org"]
	for i in 8:           # 잎: 지붕께에서 위·옆으로
		var sx := (_h(id, i) - 0.5) * 2.0
		list.append(["leaf", org, 1.2, 4, t0 + _h(id, i + 20.0) * 0.08, Color(h * (0.45 + 0.3 * _h(id, i + 40.0)), sx * (0.6 + w * 0.35), 2.2 + 1.2 * _h(id, i + 60.0), 1.0 + 0.3 * _h(id, i + 80.0))])
	for i in 5:           # 먼지: 발치에서 옆으로
		var side := (float(i) - 2.0) / 2.0
		list.append(["puff", org, 0.8, 4, t0, Color(0.05, side * w * 0.55, 0.5 + 0.3 * _h(id, i + 100.0), 0.75)])
	for i in 4:           # 별: 지붕 위로
		var sx := (float(i) - 1.5) / 1.5
		list.append(["star", org, 1.4, 4, t0 + 0.05 * i, Color(h * 0.8, sx * 0.8, 2.6 + 0.5 * _h(id, i + 120.0), 0.9)])


func _upload(list: Array) -> void:
	if list.size() > CAP:
		list.resize(CAP)
	items = list
	var sig := hash(list)
	var mm := _mmi.multimesh
	if sig == _sig and mm.visible_instance_count == list.size():
		return
	_sig = sig
	for j in list.size():
		var it: Array = list[j]
		mm.set_instance_transform(j, Transform3D(Basis.IDENTITY, it[1]))
		mm.set_instance_custom_data(j, Color(float(Pics.PICS[it[0]]["i"]), float(it[2]), float(it[3]), float(it[4])))
		mm.set_instance_color(j, it[5])
	mm.visible_instance_count = list.size()
	_mmi.visible = not list.is_empty()


## 다 지은 건물의 그림 판을 통 — 가까이(그림 판 노드)와 멀리(아틀라스 묶음) 모두. 끝나면 제 크기로
func _bounce_cards() -> void:
	for id: int in _bounces.keys():
		var a := _t - float(_bounces[id])
		var done := a >= BOUNCE_SECS
		var s := 1.0 if done else 1.0 - 0.2 * exp(-a * 7.0) * cos(a * 16.0)
		var n: Node3D = vw._blds.get(id)
		if n != null and is_instance_valid(n):
			for c: Node in n.get_children():
				if c is MeshInstance3D and c.has_meta(&"pic"):
					(c as MeshInstance3D).set_instance_shader_parameter("k", float(c.get_meta(&"k", 1.0)) * s)
		var fb: Node3D = vw._far_batch
		if fb != null and is_instance_valid(fb):
			for it: Array in vw._card_items.get(id, []):
				for c: Node in fb.get_children():
					if not (c is MultiMeshInstance3D) or (c as MultiMeshInstance3D).material_override != Bld2D.multi_material():
						continue
					var mm := (c as MultiMeshInstance3D).multimesh
					for j in mm.instance_count:
						if mm.get_instance_transform(j).origin.distance_squared_to(it[1]) < 1e-4:
							var cd := mm.get_instance_custom_data(j)
							mm.set_instance_custom_data(j, Color(cd.r, cd.g, float(it[2]) * s, cd.a))
		if done:
			_bounces.erase(id)
