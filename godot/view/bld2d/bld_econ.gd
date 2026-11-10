## 보이는 살림 — 건물 쪽 (ROADMAP Q6 · E0-3). 화면만: 시뮬레이션을 읽기만 하고 아무것도 쓰지 않는다 (ADR-0001 — 난수도 시뮬 것을 쓰지 않음,
## 켜든 끄든 결과가 같다). 2D 그림 건물(Bld2D)일 때만 그린다 (3D 대역은 예전 더미 그대로).
##  ① 짓는 터: 도착한 판자·돌 더미(지으면서 줄어듦) + 터 앞 말뚝 다섯 (지은 만큼 잎 깃발이 꽂힘) + 다 지으면 '퐁' (그림이 통 튀고 잎·먼지·별)
##  ② 일터 앞 더미: 들어온 재료(왼쪽)·쌓인 산출물(오른쪽) 세 단계 · 창고 앞엔 창고에 든 것 · 집 옆엔 땔감
##  ③ 돌아가는 일터만 움직임: 화덕 김 · 맷돌 가루 · 톱밥 · 우물 물방울 · 소금 반짝 · 불 땐 집 연기 (멈추면 고요)
##  ④ 막힌 일터는 그림 생각 풍선: 모자란 재료 · 빈 밀짚모자(일손 없음) · 넘치는 바구니(나르는 손이 없음) — 글·숫자 없음, 한 화면에 몇 개만
## 그림은 전부 아틀라스 하나(art/bld2d/econ_atlas.png — tools/bld2d/econ_sprites.py) + MultiMesh 하나 = 어느 확대에서든 그리기 1번.
## 움직임은 셰이더(bld_econ.gdshader)가 화면 시계로 — 목록이 바뀔 때만 버퍼를 올린다.
## [Q6 남은 것 — 2026-11-10] 더미·일꾼이 가려지지 않게 (전부 화면만):
##  · '앞'은 지금 카메라 방위 걸음(step 0~3)으로 — 방위가 바뀔 때만 꽃·풀을 다시 잰다 (apron_ver · place_key)
##  · 민들레·큰 버섯(FloraView)도 더미 앞마당에서는 낮춤 (plant_cap). 밀밭은 낮은 밭(Q8 — 익어도 주민 가슴 높이)이라 줄이지 않는다:
##    가리는 것은 밀 줄 하나하나(_cover_scan)뿐이고, 그래도 가리는 더미는 아래 규칙대로 옆으로 옮긴다
##  · 다른 건물 그림이 앞을 가리면 더미를 제 건물 앞줄에서 옆으로 (_slot — 건물은 안 옮김)
##  · 채집 일꾼 인형은 나무·바위 그림의 깊이 면 앞·화면 옆에 세움 (stand_pos — 시뮬 자리·수확은 그대로) + 그 앞 꽃을 낮춤
##  · 둘레에 벨 나무·캘 바위가 없으면 그림 풍선 (bub_no_tree · bub_no_rock) · 조각은 그 일꾼이 정말 베고 캘 때만
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
	"wheat_green": {"out": Vector2(2.1, 0.12)},     # 볏단 더미 = 낮은 밭(Q8)의 앞 울타리 오른쪽 끝 옆 (울타리·밀 줄을 덮지 않게)
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
const APRON_CLEAR := 0.15        # 줄 뒤에 선 큰 그림의 가리는 면은 줄보다 이만큼 뒤까지 물림
const APRON_SIDE := 1.4          # 건물 그림 반 폭 + 이것 = 옆으로 살피는 폭 (그림 옆에 놓는 집 땔감까지)
const APRON_SIN := 0.743         # sin 48° (카메라 기울기 — 그림 판은 화면에 제 키 그대로 서므로 키 h는 뒤쪽 땅을 h / sin 만큼 가린다)
## 앞에 선 다른 건물 그림(밀밭 포함)이 더미를 가리면 더미를 제 건물 앞줄에서 옆으로 옮겨 놓는다 (화면만 · 건물은 안 옮김)
const COVER_FILL := 0.85         # 건물 그림에서 실제로 그려진 키 몫 어림 (그림 위쪽 빈 곳은 가리지 않음)
const COVER_W := 0.9             # 〃 폭 몫
const PILE_HALF := 0.3           # 더미 반 폭 어림
const NUDGE := [0.8, 1.6]        # 옆으로 옮겨 보는 걸음 — 반대편, 그다음 바깥쪽으로 이만큼씩 (양쪽)
const NUDGE_OUT := 1.2           # 건물 그림 반 폭 + 이것 안에서만 (제 건물 곁 — 앞마당 폭 APRON_SIDE 안)
const NUDGE_STEP := 0.25         # 반대편·바깥이 다 가리면 이 간격으로 훑음
const NUDGE_GAP := 0.7           # 그 건물의 다른 더미 자리와 이만큼은 띄움
## 밀밭(세워 놓는 큰 그림)이 뒤쪽 건물의 더미 줄을 가리면 밭 그림을 가리지 않는 크기까지 줄인다 (밭 자리·수확은 그대로)
## 채집 일꾼이 서는 자리 (화면만): 나무·바위 그림의 깊이 면 앞 · 화면 옆으로 비켜서 옆모습 도끼질·곡괭이질이 보이게
const GATHER_OPS := {"나무꾼": "chop", "채석장": "dig"}      # 그 일터 일꾼의 채집 걸음 (ResidentAI.work_task의 done)
const STAND_FRONT := 0.3         # 그림의 깊이 면보다 이만큼 카메라 쪽
const STAND_SIDE := 0.7          # 나무: 줄기에서 화면 옆으로
const STAND_TOE := 0.1           # 발은 그림 밑변보다 이만큼 카메라 쪽 (낮은 잎에 발이 묻히지 않게)
const STAND_OUT := 0.8           # 양옆이 다 건물 그림에 가리면 이만큼 더 바깥도 봄
const STAND_NEAR := 2.5          # 걸어오는 동안 이 거리부터 선 자리 쪽으로 비켜 듦
const STAND_EASE := 6.0          # 일을 마치고 제자리로 돌아오는 빠르기 (1/초)
const SPOT_SIDE := 0.5           # 일꾼 앞마당 옆 폭 (그 앞 키 큰 꽃·풀을 낮춤)
const TREE_AT := Vector2(0.4, 0.2)        # 시뮬에서 일꾼이 서는 자리 (나무 · 바위 — ResidentAI.work_task)
const ROCK_AT := Vector2(0.6, 0.4)
const ROCK_MATE := Vector2(1.1, 0.5)      # 바위 곁 작은 돌 (VillageView._sync_rocks) — 일꾼은 그 반대편에
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
var _aprons: Array = []          # 더미 앞마당 목록 (apron_list + 채집 일꾼 자리) — 한 화면에 한 번
var _apron_frame := -1
var step := 0                    # 카메라 방위 걸음 0~3 (JarCamera.quarter와 같은 뜻 — 카메라에서 읽음)
var apron_ver := 0               # 앞마당(건물·일꾼 자리·방위)이 바뀔 때마다 +1 — 꽃·풀·민들레는 이것이 바뀔 때만 다시 잰다
var tree_draw := {}              # 나무 자리 Vector2 → [꽃 모델, 그린 크기] (VillageView._sync_trees가 적음 — 일꾼이 설 자리)
var rock_draw := {}              # 바위 자리 Vector2 → 그린 크기 (VillageView._sync_rocks가 적음)
var stands := {}                 # 주민 id → [dx, dz, 몫 0~1, 바라보는 쪽] (채집 일꾼 인형을 비켜 세운 만큼)
var _spots := {}                 # 채집 일터 id → 앞마당 한 줄 [x, y, 0, 옆 폭, 나무·바위 x, y]
var _apron_sig := 0
var _covers: Array = []          # 세워 놓은 건물 그림 판 [밑변 가운데 x, z, 반 폭, 가리는 키, 건물 id]
var _cover_sig := 0
var _cov_by := {}                # 건물 id → 그 건물 더미 줄을 가릴 수 있는 판 [옆, 앞, 반 폭, 키] (건물 자리에서)
var _cov: Array = []             # 지금 놓는 건물의 것
var _slot_xs: Array = []         # 지금 놓는 건물의 기본 더미 자리 (화면 오른쪽)
var _used: Array = []            # 〃 이미 놓은 자리
var _slot_max := 0.0
var _sf := Vector2.ZERO          # 방위 걸음의 카메라 쪽 · 화면 오른쪽 (카메라가 도는 동안에도 걸음 단위로만 바뀜)
var _sr := Vector2.RIGHT
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
	if GATHER.has(b.type):           # 채집 일터: 일꾼은 있는데 둘레에 벨 나무·캘 바위가 없다 (사슬 막힘 판정에 없는 것 — 자리만 봄)
		if b.built and b.worker >= 0 and gather_empty(vil, b):
			return "bub_no_tree" if b.type == "나무꾼" else "bub_no_rock"
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


## 채집 일터 둘레(Balance.GATHER_RANGE — ResidentAI.work_task와 같은 범위)에 벨 나무 / 캘 바위가 하나도 없나. 읽기만
static func gather_empty(vil: Village, b: Building) -> bool:
	var rr := Balance.GATHER_RANGE * Balance.GATHER_RANGE
	if b.type == "나무꾼":
		for tr: Dictionary in vil.trees:
			if String(tr["s"]) == "tree" and Vector2(float(tr["x"]) - b.x, float(tr["y"]) - b.y).length_squared() <= rr:
				return false
		return true
	for rk: Dictionary in vil.rocks:
		if float(rk["amt"]) > 0.0 and SkyDrops.rock_minable(vil, rk) and Vector2(float(rk["x"]) - b.x, float(rk["y"]) - b.y).length_squared() <= rr:
			return false
	return true


## 방위 걸음 (0~3): 카메라 쪽 땅 방향 f2에서 (JarCamera — 방위 = BASE_YAW_DEG + 90° × 걸음)
static func step_of(f2: Vector2) -> int:
	return posmod(roundi((rad_to_deg(atan2(f2.x, f2.y)) - JarCamera.BASE_YAW_DEG) / 90.0), 4)


## 방위 걸음의 [카메라 쪽, 화면 오른쪽] (마을 기준 땅 위 x·z)
static func step_dirs(st: int) -> Array:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG + 90.0 * float(st))
	return [Vector2(sin(yaw), cos(yaw)), Vector2(cos(yaw), -sin(yaw))]


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
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var inv := global_transform.basis.inverse()
		var cr := inv * cam.global_transform.basis.x
		var cf := inv * cam.global_transform.basis.z
		var r2 := Vector2(cr.x, cr.z)
		var f2 := Vector2(cf.x, cf.z)
		if r2.length() > 0.05 and f2.length() > 0.05:
			_r2 = r2.normalized()
			_f2 = f2.normalized()
	var st := step_of(_f2)
	if st != step or _sf == Vector2.ZERO:
		step = st
		_apron_frame = -1
		var sd := step_dirs(st)
		_sf = sd[0]
		_sr = sd[1]


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
	var spots2 := {}
	var workers := {}                # 채집 일터의 일꾼 (인형을 비켜 세울 주민)
	_dirs()
	_aprons_now()
	_cover_scan()
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
		_cov = _cov_for(b.id, org)
		_used.clear()
		if b.is_site():
			_site(list, lv2, b, org, w, front)
		else:
			_work(list, lv2, b, org, pic, w, h, front)
			if GATHER.has(b.type):
				_gather_spot(b, spots2, workers)
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
	if spots2 != _spots:             # 일꾼 자리가 바뀜 → 앞마당 다시 (꽃·풀은 다음 살핌에 다시 놓임)
		_spots = spots2
		_apron_frame = -1
		_aprons_now()
	for rid: int in workers:
		if not stands.has(rid):
			stands[rid] = [0.0, 0.0, 0.0, 0.0]
	for rid: int in stands.keys():
		if not workers.has(rid) and float(stands[rid][2]) <= 0.0:
			stands.erase(rid)
	_seen_once = true
	_upload(list)


## 짓는 터: 자재 더미 (왼쪽 판자 · 오른쪽 돌 — 지으면서 줄어듦) + 말뚝 줄 (지은 만큼 깃발)
func _site(list: Array, lv2: Dictionary, b: Building, org: Vector3, w: float, front: float) -> void:
	var frac := clampf(b.prog / float(Balance.B[b.site_type()]["time"]), 0.0, 1.0)
	var px := w * 0.5 * SITE_PILE_X
	_slot_xs = [-px, px]
	_slot_max = px + NUDGE_OUT
	var lp := site_level(site_left(int(b.delivered["판자"]), frac), b.need("판자"))
	if lp > 0:
		_pile(list, lv2, "%d:p" % b.id, goods_pic("판자", lp), _slot(org, -px, front + FRONT_GAP, []))
	var ls := site_level(site_left(int(b.delivered["돌"]), frac), b.need("돌"))
	if ls > 0:
		_pile(list, lv2, "%d:s" % b.id, goods_pic("돌", ls), _slot(org, px, front + FRONT_GAP, []))
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
	_slot_max = w * 0.5 + NUDGE_OUT
	if not _cov.is_empty():          # 가리는 건물이 있을 때만: 이 건물의 기본 더미 자리들 (옮길 때 서로 겹치지 않게)
		if b.is_store:
			_slot_xs = STORE_SLOTS.map(func(sl: Vector2) -> float: return sl.x)
		elif b.is_house():
			_slot_xs = [-(w * 0.5 + HOUSE_WOOD.x)]
		elif GATHER.has(b.type):
			_slot_xs = [out_at.x]
		else:
			_slot_xs = [in_at.x, out_at.x]
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
		if wk != null:               # 조각: 그 일꾼이 정말 베고 캐는 동안만 — 인형이 선 자리(stand_of) 앞에
			var st := stand_of(gather_node(wk))
			var wx := st.x + _f2.x * GATHER_FRONT
			var wz := st.y + _f2.y * GATHER_FRONT
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
	# '일하는 몸짓'만으로는 모자람: 부엌 일·씨앗 굴리기·김매기 … 도 같은 몸짓 — 지금 걸음이 이 일터의 채집(chop · dig)일 때만
	if gather_op(r) != String(GATHER_OPS[b.type]):
		return null
	return r


## 주민이 지금 하는 걸음이 채집이면 "chop" / "dig" (아니면 "")
static func gather_op(r: Resident) -> String:
	if r.steps.is_empty():
		return ""
	var s: Dictionary = r.steps[0]
	var dn: Variant = s.get("done")
	if String(s.get("k", "")) != "do" or not (dn is Dictionary):
		return ""
	var o := String((dn as Dictionary).get("op", ""))
	return o if o == "chop" or o == "dig" else ""


## 주민이 지금 베는 나무 · 캐는 바위 (없으면 {}). ahead = 그리로 걸어가는 중이어도 (걸음 목록의 첫 '할 일'이 채집). 읽기만
static func gather_node(r: Resident, ahead := false) -> Dictionary:
	for s: Dictionary in r.steps:
		if String(s.get("k", "")) != "do":
			if ahead:
				continue
			return {}
		var dn: Variant = s.get("done")
		if not (dn is Dictionary):
			return {}
		var o := dn as Dictionary
		match String(o.get("op", "")):
			"chop":
				return o.get("tr", {})
			"dig":
				return o.get("rk", {})
		return {}
	return {}


## 채집 일꾼 인형이 서는 자리 (x, z)와 바라보는 쪽 — 화면만. 나무: 꽃 그림의 깊이 면 바로 앞 · 줄기 옆 / 바위: 바위 그림 옆 끝
## (곁의 작은 돌 반대편). 그 자리가 건물 그림에 가리면 반대편. 옆모습으로 나무·바위를 본다. 방위 걸음 기준 (도는 동안 안 흔들림)
func stand_of(node: Dictionary) -> Vector3:
	var rock := node.has("amt")
	var p := Vector2(float(node["x"]), float(node["y"]))
	var ahead := STAND_FRONT
	var lat := STAND_SIDE
	var side := 1.0
	if rock:
		# 그린 크기 (앞마당에서 줄여 놓은 바위면 그 크기 — VillageView._sync_rocks가 적음. 없으면 양에서 어림)
		var k := float(rock_draw.get(p, minf(0.8 + float(node["amt"]) / 25.0, 2.4)))
		var inf := Flora2D.info(Flora2D.pic_for("rocks"))
		ahead = stand_ahead(inf, k, 0.2)
		lat = float(inf.get("w", 2.0)) * k * 0.5 * 0.85 + 0.15
		side = -1.0 if ROCK_MATE.dot(_sr) >= 0.0 else 1.0
	else:
		var e: Array = tree_draw.get(p, [])
		if not e.is_empty():
			ahead = stand_ahead(Flora2D.info(Flora2D.pic_for(String(e[0]))), float(e[1]), STAND_FRONT)
		side = 1.0 if TREE_AT.dot(_sr) >= 0.0 else -1.0
	var at := p + _sf * ahead + _sr * (side * lat)
	if _card_covers(at):             # 건물 그림 뒤 → 반대편, 그다음 양쪽으로 한 걸음 더 바깥 (모두 가리면 제자리 — 밑동이 통째로 건물 뒤)
		for c: float in [-side * lat, side * (lat + STAND_OUT), -side * (lat + STAND_OUT)]:
			var other := p + _sf * ahead + _sr * c
			if not _card_covers(other):
				at = other
				side = signf(c)
				break
	var look := -_sr * side
	return Vector3(at.x, at.y, atan2(look.x, look.y))


## 일꾼이 서는 자리: 나무·바위 자리에서 카메라 쪽으로 얼마나. 그림의 가리는 면(flora_front)보다 gap 앞 · 발은 그림 밑변
## (front — 낮은 잎·바위 밑동은 여기까지 나와 그려진다)보다 조금 앞
static func stand_ahead(inf: Dictionary, k: float, gap: float) -> float:
	return maxf(flora_front(inf) * k + gap, float(inf.get("front", 0.0)) * k + STAND_TOE)


## 매 화면 (VillageView._sync_residents — stands에 든 주민만): 인형을 놓을 [x, z, 바라보는 쪽]. 시뮬 자리 (x, z)에서
## 채집하러 다가오면 선 자리 쪽으로 비켜 들고, 베고 캐는 동안은 선 자리에, 마치면 걸어가며 제자리로. 시뮬은 건드리지 않는다
func stand_pos(r: Resident, x: float, z: float, dt: float) -> Vector3:
	var e: Array = stands[r.id]
	var node := gather_node(r, true)
	var goal := 0.0
	var working := false
	if not node.is_empty() and not r.sleeping and not r.dead:
		var st := stand_of(node)
		var sim := Vector2(float(node["x"]), float(node["y"])) + (ROCK_AT if node.has("amt") else TREE_AT)
		e[0] = st.x - sim.x
		e[1] = st.y - sim.y
		e[3] = st.z
		working = gather_op(r) != ""
		goal = 1.0 if working else clampf(1.0 - Vector2(x - sim.x, z - sim.y).length() / STAND_NEAR, 0.0, 1.0)
	var w := float(e[2])
	w = goal if working and w > 0.98 else lerpf(w, goal, 1.0 - exp(-STAND_EASE * dt))
	if goal <= 0.0 and w < 0.01:
		w = 0.0
	e[2] = w
	return Vector3(x + float(e[0]) * w, z + float(e[1]) * w, float(e[3]) if working else r.facing)


## 채집 일터의 일꾼 · 그가 서는(설) 자리의 앞마당 한 줄. 자리는 다음 나무·바위가 정해질 때까지 그대로 (꽃을 자꾸 다시 놓지 않게)
func _gather_spot(b: Building, spots2: Dictionary, workers: Dictionary) -> void:
	var r: Resident = v.person(b.worker) if b.built and b.worker >= 0 else null
	if r != null and not r.dead and r.job == b.id:
		workers[r.id] = true
		var node := gather_node(r, true)
		if not node.is_empty():
			var st := stand_of(node)
			spots2[b.id] = [st.x, st.y, 0.0, SPOT_SIDE, float(node["x"]), float(node["y"])]
			return
	if _spots.has(b.id):
		spots2[b.id] = _spots[b.id]


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


## 꽃·풀 그림(Flora2D.info)이 실제로 다른 것을 가리기 시작하는 면: 원점에서 카메라 쪽으로 이만큼 (크기 1). flora_card.gdshaderinc는
## 그림 판을 밑변(front)에서 깊이 면(df) 쪽으로 (front − df) × cos(기울기)만큼 시선 따라 밀어 넣는다 → 땅 위로는 cos² 만큼만 물러난다
static func flora_front(inf: Dictionary) -> float:
	var fr := float(inf.get("front", 0.0))
	var df := float(inf.get("df", fr))
	return fr - (fr - df) * (1.0 - APRON_SIN * APRON_SIN)


## 더미 앞마당에 선 그림의 키 상한: (x, z)에 키 h인 그림이 서면 뒤쪽 건물 앞 더미(줄 위에 놓인 것)를 가리지 않는 키
## (가리지 않으면 h 그대로). aprons = apron_list · half_w = 그림 반 폭 어림 (VillageView._core_scale과 같은 어림).
## st = 카메라 방위 걸음 (step_of — '앞'이 어느 쪽인가) · back = 줄보다 이만큼 뒤에 선 것까지 살핌 (큰 꽃 그림은 밑변이 원점보다
## 카메라 쪽 front × 크기에 그려진다 → 줄 뒤에 서 있어도 낮은 잎이 더미를 덮는다 → 그 거리를 넘김). 줄 원소가 6개면 [4], [5] = 그 줄의 주인 (일꾼이
## 베는 나무·캐는 바위) 자리 — 그 그림은 낮추지 않는다
static func apron_h(aprons: Array, x: float, z: float, h: float, half_w := 0.0, st := 0, back := APRON_BACK) -> float:
	if h <= APRON_MIN_H:
		return h
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG + 90.0 * float(st))
	var tw := Vector2(sin(yaw), cos(yaw))
	var rt := Vector2(cos(yaw), -sin(yaw))
	var lim := h
	for e: Array in aprons:
		var d := Vector2(x - float(e[0]), z - float(e[1]))
		var along := d.dot(tw) - float(e[2])
		if along <= -back or along * APRON_SIN >= lim or absf(d.dot(rt)) > float(e[3]) + half_w:
			continue
		if e.size() > 5 and absf(x - float(e[4])) < 0.01 and absf(z - float(e[5])) < 0.01:
			continue
		if along < 0.0 and back > APRON_BACK:
			# 줄 뒤에 선 큰 그림: 가리는 면이 줄 뒤로 물러날 만큼만 줄인다 (더미가 그 그림 앞에 그려진다 — 키 큰 꽃은 꽃으로 남음)
			lim = minf(lim, maxf(APRON_MIN_H, h * (-along - APRON_CLEAR) / back))
		else:
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
	var back := maxf(APRON_BACK, float(inf.get("front", 0.0)) * s)     # 그림 밑변(front)이 줄 앞으로 나오면 낮은 잎이 더미를 덮는다
	return s * apron_h(_aprons_now(), x, z, h, float(inf.get("w", 0.0)) * s * 0.25, step, back) / h


## 지금의 앞마당 목록 (건물 + 채집 일꾼 자리) — 한 화면(프레임)·건물 수에 한 번만 만든다. 내용·방위가 바뀌었으면 apron_ver += 1
func _aprons_now() -> Array:
	var fr := Engine.get_process_frames() * 4096 + v.buildings.size()      # 같은 화면이라도 건물 수가 바뀌면 다시
	if fr == _apron_frame:
		return _aprons
	_apron_frame = fr
	var list := apron_list(v)
	for id: int in _spots:
		list.append(_spots[id])
	var sig := hash([list, step])
	if sig != _apron_sig:
		_apron_sig = sig
		apron_ver += 1
	_aprons = list
	return _aprons


## 꽃·풀·나무·바위를 다시 놓아야 하는지의 열쇠 (VillageView._sync_trees · _sync_rocks · _sync_props가 제 열쇠에 붙임):
## 카메라 방위 걸음 · 건물 앞마당 · 채집 일꾼 자리가 바뀔 때만 달라진다 (카메라가 가만히 있으면 값쌈 — 건물 수만큼)
func place_key() -> String:
	_dirs()
	_aprons_now()
	return str(apron_ver)


## 민들레·큰 버섯처럼 제 노드로 서 있는 것 (FloraView): (x, z)에 키 h · 반 폭 half_w · 밑변이 원점에서 df 앞에 그려지는 그림의 크기 몫 (0~1)
func plant_cap(x: float, z: float, h: float, half_w: float, df: float) -> float:
	if not on or h <= APRON_MIN_H:
		return 1.0
	return apron_h(_aprons_now(), x, z, h, half_w, step, maxf(APRON_BACK, df)) / h


## 건물의 더미 줄 [줄(건물 자리에서 카메라 쪽 — 더미 가운데 가장 앞에 놓이는 것), 화면 왼쪽 끝, 오른쪽 끝] — 더미가 놓일 수 있는
## 자리의 띠 (없으면 []). 가장 앞 더미가 앞에 선 그림에 가장 먼저 가린다 → 그 줄을 안 가리면 뒤 더미도 안 가린다
static func pile_band(vil: Village, b: Building) -> Array:
	var pk := pic_k(vil, b)
	var pic := String(pk[0])
	var d := Bld2D.info(pic)
	if d.is_empty():
		return []
	var k := float(pk[1])
	var w := float(d["w"]) * k
	var ground := int(d.get("mode", 0)) == 1
	var front := float(d["h"]) * k * 0.5 if ground else float(d["front"]) * k
	var m := PILE_HALF + 0.2
	if b.is_site():
		return [front + FRONT_GAP, -w * 0.5 * SITE_PILE_X - m, w * 0.5 * SITE_PILE_X + m]
	var base := 0.0 if ground else front
	if b.is_store:
		var sy := 0.0
		var sx := 0.0
		for sl: Vector2 in STORE_SLOTS:
			sy = maxf(sy, sl.y)
			sx = maxf(sx, absf(sl.x))
		return [base + sy, -sx - m, sx + m]
	if b.is_house():
		var hx := -(w * 0.5 + HOUSE_WOOD.x)
		return [base + HOUSE_WOOD.y, hx - m, hx + m]
	var lay: Dictionary = LAYOUT.get(pic, {})
	var out_at: Vector2 = lay.get("out", Vector2(w * 0.5 - 0.3, FRONT_GAP + 0.05))
	if GATHER.has(b.type) or (b.def().get("in", {}) as Dictionary).is_empty():
		return [base + out_at.y, out_at.x - m, out_at.x + m]
	var in_at: Vector2 = lay.get("in", Vector2(-(w * 0.5 - 0.3), FRONT_GAP))
	return [base + maxf(in_at.y, out_at.y), minf(in_at.x, out_at.x) - m, maxf(in_at.x, out_at.x) + m]


## 세워 놓은 건물 그림 판 목록 (다른 건물 앞 더미를 가리는지 볼 것) — 바뀌었을 때만 건물별 목록(_cov_by)을 버린다
## 밀밭(Q8)은 한 장이 아니라 낮은 밀 줄 여러 겹 (Bld2D.wheat_cards) — 줄마다 제 자리·제 키로 (눕힌 흙은 아무것도 가리지 않는다)
func _cover_scan() -> void:
	var cards: Array = []
	var hidden: Dictionary = vw.hidden_blds
	for b: Building in v.buildings:
		if b.site_type() == Awakening.ALTAR or hidden.has(b.id):
			continue
		var pk := pic_k(v, b)
		var d := Bld2D.info(String(pk[0]))
		if d.is_empty() or int(d.get("mode", 0)) == 1:
			continue
		var k := float(pk[1])
		if b.type == "농장" and not b.is_site():
			for nm: String in Bld2D.wheat_cards(VillageView.wheat_stage(b, v.t), vw.wheat_accent):
				var rd := Bld2D.info(nm)
				if rd.is_empty() or int(rd.get("mode", 0)) == 1:
					continue
				var rb := Vector2(b.x, b.y) + _f2 * float(rd["front"]) + _r2 * float(rd.get("dx", 0.0))
				cards.append([rb.x, rb.y, float(rd["w"]) * 0.5, float(rd["h"]), b.id])
			continue
		var base := Vector2(b.x, b.y) + _f2 * (float(d["front"]) * k) + _r2 * (float(d.get("dx", 0.0)) * k)
		cards.append([base.x, base.y, float(d["w"]) * k * 0.5 * COVER_W, float(d["h"]) * k * COVER_FILL, b.id])
	var sig := hash(cards)
	if sig != _cover_sig:
		_cover_sig = sig
		_covers = cards
		_cov_by.clear()


## 건물 id(자리 org)의 더미 줄을 가릴 수 있는 판 — 건물 자리에서 [화면 옆, 카메라 쪽, 반 폭, 키]
func _cov_for(id: int, org: Vector3) -> Array:
	if _cov_by.has(id):
		return _cov_by[id]
	var out: Array = []
	var o := Vector2(org.x, org.z)
	for c: Array in _covers:
		if int(c[4]) == id:
			continue
		var dv := Vector2(float(c[0]), float(c[1])) - o
		var along := dv.dot(_f2)
		var lat := dv.dot(_r2)
		if along <= 0.0 or (along - 6.0) * APRON_SIN >= float(c[3]) or absf(lat) > float(c[2]) + 8.0:
			continue
		out.append([lat, along, float(c[2]), float(c[3])])
	_cov_by[id] = out
	return out


## 지금 놓는 건물의 자리 (sx, sy)에 놓인 더미가 앞 건물 그림에 가리나
func _covered(sx: float, sy: float) -> bool:
	return _cover_depth(sx, sy) > 0.0


## 그 자리가 앞 건물 그림 안으로 옆으로 얼마나 들어가 있나 (0 = 안 가림 — 가장 깊이 들어간 판 기준)
func _cover_depth(sx: float, sy: float) -> float:
	var deep := 0.0
	for c: Array in _cov:
		var a := float(c[1]) - sy
		if a > 0.05 and a * APRON_SIN < float(c[3]):
			deep = maxf(deep, float(c[2]) + PILE_HALF - absf(sx - float(c[0])))
	return deep


## 땅 위 자리 p가 세워 놓은 건물 그림에 가리나 (채집 일꾼이 설 자리)
func _card_covers(p: Vector2) -> bool:
	for c: Array in _covers:
		var dv := Vector2(float(c[0]), float(c[1])) - p
		var a := dv.dot(_f2)
		if a > 0.05 and a * APRON_SIN < float(c[3]) and absf(dv.dot(_r2)) < float(c[2]) + PILE_HALF:
			return true
	return false


## 더미 자리: 화면 옆으로 가까운 마당 덤불이 앞을 가리면 그 덤불 앞으로 (덤불 뒤에 숨지 않게)
## · 앞에 선 다른 건물 그림에 가리면 같은 줄에서 옆으로: 반대편 → 바깥쪽으로 NUDGE씩 (양쪽). 그 건물의 다른 더미 자리와
## 겹치지 않고 건물 곁(_slot_max)을 벗어나지 않는 첫 자리 — 없으면 제자리. 건물은 옮기지 않는다 (화면만 · 늘 같은 답)
func _slot(org: Vector3, sx: float, sy: float, bushes: Array) -> Vector3:
	var y := _bush_y(sx, sy, bushes)
	if not _cov.is_empty() and _covered(sx, y):
		var sg := 1.0 if sx >= 0.0 else -1.0
		var tries: Array = [-sx]
		for st: float in NUDGE:
			tries.append(sx + sg * st)
			tries.append(-(sx + sg * st))
		for c: float in tries:
			if absf(c) > _slot_max or absf(c - sx) < 0.3:
				continue
			var taken := false
			for ox: float in _slot_xs:
				if absf(ox - sx) > 1e-3 and absf(ox - c) < NUDGE_GAP:
					taken = true
			for ox: float in _used:
				if absf(ox - c) < NUDGE_GAP:
					taken = true
			var cy := _bush_y(c, sy, bushes)
			if taken or _covered(c, cy):
				continue
			sx = c
			y = cy
			break
		if _covered(sx, y):          # 반대편·바깥도 가림 (앞 건물 둘 사이 틈 같은 곳) → 건물 곁을 NUDGE_STEP씩 훑어 안 가리는 가장 가까운 자리,
			var best := sx           # 그것도 없으면 가장 덜 가리는 자리
			var best_d := _cover_depth(sx, y)
			var best_far := 0.0
			var n := int(floor(_slot_max / NUDGE_STEP))
			for i in range(-n, n + 1):
				var c := float(i) * NUDGE_STEP
				var taken := false
				for ox: float in _slot_xs:
					if absf(ox - sx) > 1e-3 and absf(ox - c) < NUDGE_GAP:
						taken = true
				for ox: float in _used:
					if absf(ox - c) < NUDGE_GAP:
						taken = true
				if taken:
					continue
				var d := _cover_depth(c, _bush_y(c, sy, bushes))
				var far := absf(c - sx)
				if d < best_d - 0.01 or (absf(d - best_d) <= 0.01 and far < best_far - 0.01):
					best = c
					best_d = d
					best_far = far
			if best != sx:
				sx = best
				y = _bush_y(sx, sy, bushes)
	_used.append(sx)
	return _at(org, sx, y)


func _bush_y(sx: float, sy: float, bushes: Array) -> float:
	var y := sy
	for bp: Vector2 in bushes:
		if absf(bp.x - sx) < BUSH_NEAR and bp.y > sy - 0.6:
			y = maxf(y, bp.y + 0.3)
	return y


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
