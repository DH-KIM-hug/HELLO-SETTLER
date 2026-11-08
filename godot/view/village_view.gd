## 부락 화면 — sim/village.gd(Village)의 상태를 3D로 (주민·건물·건설 현장·나무·바위·하늘 낟알·모닥불) + 화면 장식.
## 4단계 (RENDERING v2): 모든 물체가 공용 툰 빛(render/toon_light.gdshaderinc) — 밝은 면 + 청록 그늘 한 단계, 그림자는 그림자 맵.
## 5단계: 건물·나무·소품·주민은 Blender 모델 에셋 (art/models/*.glb, art/art.gd가 읽음 — 뒤집은 껍데기 + 접힌 곳 선 외곽선).
## 여러 개인 것(나무·소품)은 MultiMesh. 장식(숲 가장자리 나무 무리·소품 무리·물가 갈대·연잎·선착장·다리)은 시뮬레이션에 없음 —
## 잡음·해시로 늘 같은 자리, 병을 돌리면 땅과 함께 돈다. 사이사이 빈 풀밭을 넓게 남긴다.
## 매 화면마다 sync(dt) — 주민 위치·동작은 매번, 건물·나무·소품은 모양이 바뀔 때만 다시 만든다. 색은 data/style.gd.
class_name VillageView
extends Node3D


const BUILDING_SCALE := 1.0     # 건물 화면 크기 배율 (시뮬레이션 자리·크기는 그대로)
const TREE_SCALE := 1.0

var v: Village
var terrain: JarTerrain
var residents := {}             # id → ResidentModel
var _res_key := {}              # id → 나이 단계 (바뀌면 모델을 다시 만듦)
var _blds := {}                 # id → Node3D
var _bld_key := {}
var _live := {}                 # 건물 id → {"stone": 맷돌 윗돌 · "glow": 화덕 불} (_animate_live)
var _yard: Node3D               # (P1 2차) 집 앞마당 꽃·꽃덤불 — 집마다 따로가 아니라 모양마다 MultiMesh 하나 (가까이 LOD에서만 보임)
var _yard_xf := {}              # 건물 id → [[모델, 건물 기준 Transform3D]…]
var _yard_dirty := false
## (P1 성능 후속 · buildings GDD 메인 판단 1) 건물 멀리 LOD: 확대가 BLD_FAR_IN 아래면 모델의 "__far" 노드(≤ 600, 선·껍데기 없음),
## BLD_FAR_OUT 위로 돌아오면 가까이 (가운데 24 — Mobile엔 visibility_range 페이드가 없어 확대로 직접 바꿈, 경계에서 깜빡이지 않게 틈).
## 멀리에서는 마당 꽃·덤불도 숨김. 건물 노드 아래 "near" · "far" 두 갈래 (_build_shape).
const BLD_FAR_IN := 22.0
const BLD_FAR_OUT := 26.0
var bld_far := false            # 지금 멀리 LOD인가
var bld_force_lod := -1         # -1 = 확대 따라 · 0 = 늘 가까이 · 1 = 늘 멀리 (캡처·시험)
## (P1 3차) 멀리 LOD 건물 묶음: 멀리에서는 건물마다 "far" 노드·짐 더미("piles") 대신, 가만히 선 건물 전부의 같은 (메시·재질·그림자)를
## 메시 하나로 구워 합침 (건물 약 30채 × 2~3번 → 재질 수만큼). 노드는 그대로 두고 (시험·떨어지는 연출이 노드를 씀) 숨기기만 한다.
## 움직이는 건물(하늘에서 떨어지는 중 — 노드 변환이 기록과 다름)은 묶음에서 빼고 제 노드로 그린다.
var bld_batch := true           # false = 예전처럼 건물마다 (비교 측정)
var _far_batch: Node3D
var _far_items := {}            # 건물 id → [[메시, 재질 또는 null, 그림자 설정, 마을 기준 Transform3D]…]
var _far_rest := {}             # 건물 id → 기록할 때의 노드 변환
var _far_moving := {}           # 건물 id → true (움직이는 중 — 제 노드로)
var _far_dirty := false
## (A27-c) 밀 숲 터 = 농장: 키 큰 밀 줄기 다섯 (art/src/build_buildings.py build_wheat_forest). 윗부분(_top, 모델 높이 6칸 위)은
## 엷어지는 재질(render/toon_fade.gdshader)로 — 그 아래 주민·길을 가리지 않게. 그림자는 그림자 전용 쌍둥이가 드리운다.
const WHEAT_MODELS := ["buildings/wheat_forest_sprout", "buildings/wheat_forest_green", "buildings/wheat_forest_ripe"]
const WHEAT_SPROUT := 0.33      # 첫 수확까지 시간의 이만큼 지나기 전엔 싹
static var _fade_mat: ShaderMaterial
static var _oven_mat: StandardMaterial3D
var _trees: Node3D
var _tree_key := ""
var season := ""                # 지금 철 (꽃숲 모양 — FloraLook.season_of)
var n_flora := 0                # 꽃숲으로 그린 시뮬레이션 나무 수 (시험용)
var _rocks: Node3D
var _rock_key := ""
var _manna: Node3D
var _manna_key := ""
var _fire: Campfire             # [모닥불] view/campfire.gd — 돌 고리·장작·의자 + 불꽃 셰이더·불티·연기·불빛
var altar_view: AltarView       # 모닥불 곁 돌 제단 (기획서 11.1 · 6.5 — view/altar_view.gd): 둥근 돌 단 · 짓는 모습 · 제물 더미 + 빛
var manna_fx: MannaFx           # 하늘 낟알이 쏟아지는 연출 (view/manna_fx.gd)
var _props: Node3D
var _prop_key := ""
var _lily_node: Node3D          # 수련·연꽃 (따로 — 수면이 오르내리면 높이만 다시)
var _lilies: Array = []         # [모델, 칸, x, z, 돌림, 크기]
var _lily_y := PackedFloat32Array()   # 마지막으로 놓은 높이 (−1e9 = 숨김)
var _lily_t := 0.0
var _far: Node3D                # (6단계) 넓은 세상: 마을 둘레 밖, 안개가 걷힌 숲 무리 (ww.forests)
## (P1 성능) 꽃숲·소품·먼 숲 묶음 — 화면 자르기 + 멀리 덩이 (view/flora_batch.gd). 부모 노드 → FloraBatch
var _batches := {}
var flora_cull := true          # false = 화면 밖도 늘 그림 (캡처·시험)
var flora_force_near := false  # true = 늘 가까이 모양 (예전 그림과 비교하는 캡처용)
var _far_key := -1
var _far_season := ""
var _far_t := -1.0e9
var n_far_trees := 0
var far_ms := 0.0
var _wf: Array[Dictionary] = [] # 마을 둘레에 걸친 세상 숲 무리 (장식 숲 짙기용)
var _check_t := 0.0
var decor_ms := 0.0             # 장식을 마지막으로 다시 놓는 데 든 시간 (표시·측정용)
var n_decor_trees := 0
var n_piers := 0
var n_bridges := 0
var _anim_t := 0.0
var mold_view: MoldView        # [곰팡이·뚜껑] 털뭉치 (view/mold_view.gd)
var crisis_view: CrisisView    # [작은 위기] 날벌레·떠돌이 물방울·먼지 뭉치 (view/crisis_view.gd)
var flora_view: FloraView      # [하늘의 것] 큰 버섯·큰 민들레·꽃씨 (view/flora_view.gd)
var drop_view: SkyDropView     # [상점] 하늘에서 내려온 것·앰플 탑·녹조 (view/sky_drop_view.gd)
var fauna_view: FaunaView      # [강아지·작은 생물] 집 강아지·마을 강아지·꿀떡이 + 무당벌레·나비… (view/fauna_view.gd — E3-12 · E3-13)
var animal_view: AnimalView    # [들짐승] 카메라 곁 무리의 대표·물고기·메고 오는 사슴·올무·울타리 (view/animal_view.gd)
var _torches := {}              # 주민 id → 횃불 노드 (곰팡이 쫓는 사람)
var _torch_glows := {}          # 주민 id → 발밑 횃불 빛
var _graves: Node3D             # (A6) 무덤 돌 — 묘지 안·마을 끝 (Village.graves)
var _grave_key := ""
var _rafts := {}                # (A6) 주민 id → 나루터 뗏목 (뗏목 길을 건너는 동안)
var _raft_era := -1             # (E3-6) 뗏목 모양을 정한 시대 (바뀌면 다시 만듦: 개척 = 갈대 뗏목 · 그 뒤 = 잎 배)
## (E3-6) 물 건너는 자리 — [{"kind": "bridge"|"stones", "c": Vector2 가운데, "u": Vector2 건너는 방향, "half": 반 길이, "y": 높이}]
var crossings: Array[Dictionary] = []
var n_stones := 0
## (E3-6) 둘이 메는 물고기: 주민 id → [역할 "앞"/"뒤", 짝 id] (매 화면 fish_pairs) · 뒤 사람이 장대 자리로 붙는 정도 (0~1)
var fish_pair := {}
var _pair_w := {}
var alpha := 1.0                # 걸음 사이 어디쯤인가 (0 = 직전 걸음, 1 = 지금) — JarClock이 병 시계 1초씩 걸으므로 그 사이를 보간
var lerp_max := 3.0             # 걸음 사이 이만큼(칸) 넘게 옮겼으면 순간이동 (보간 안 함) — 10초 걸음이면 화면이 키운다
var fast := false               # 빠른 흐름 (1초=5분~, JarClock.fast): 주민은 멀리 LOD로 FAST_EVERY초마다 제자리에 순간이동 (걷기·몸짓 멈춤),
                                # 곰팡이·위기·하늘의 것·상점·들짐승 화면도 그 간격으로만 (효과가 쏟아지지 않게)
var _fast_t := 0.0
var _fast_dt := 0.0
const FAST_EVERY := 0.1
## (OPENING 8 v3.9 스타터킷 풀기) 장면이 잠깐 감추거나 직접 움직이는 것 — 상자에서 기어 나오는 주민 · 아직 놓지 않은 키트 건물·모닥불
var hidden_blds := {}           # 건물 id → true (그리지 않음)
var hide_fire := false
var social: SocialStage         # [마을의 삶] 이야기·다툼·사랑·혼례 모임·저녁 노래 (view/social_stage.gd)
var staged := {}                # 주민 id → {"pos": Vector3, "rot": float, "anim": String, "vis": bool, "tilt": Vector2} (시뮬레이션 자리 대신)
var pose_over: Dictionary = {}       # (E1-0 사건 연출) 주민 id → {anim, face, up(고개 젖힘 라디안), side, arm: Vector2} — 자리는 시뮬레이션 그대로, 몸짓만 연출이


func _init(village: Village, t: JarTerrain) -> void:
	v = village
	terrain = t


## 처음 한 번 모델을 모두 읽어 둠 (첫 등장 때 끊기지 않게)
const PRELOAD := ["cottage_a", "cottage_b", "cottage_c", "cottage_d", "hut", "house_timber", "house_timber_b", "house_stone", "house_stone_b", "storehouse", "forester", "quarry", "sawmill",
	"well", "windmill", "bakery", "saltpan", "buildings/wheat_forest_sprout", "buildings/wheat_forest_green", "buildings/wheat_forest_green_top", "buildings/wheat_forest_ripe", "buildings/wheat_forest_ripe_top", "woodpile", "chopblock", "planter", "pier", "bridge", "bridge_stones", "raft_reed", "boat_leaf", "mushroom_hut",
	"bush", "bush_b", "bush_flower", "bush_berry",
	"rocks", "rocks_b", "rock_small", "mushrooms", "flora/clover_a", "tuft", "flowers", "flowers_b", "lily", "lotus", "reeds", "altar",
	"campfire", "campfire_extra", "campfire_seat", PF_JARS, PF_FENCE, PF_CORDWOOD, PF_BENCH, PF_CAIRN, PF_MOSS, PF_FERN]
## polyfork.dev 소품 (CC BY 4.0, 우리 팔레트·크기로 고침 — art/src/build_polyfork.py, 출처 art/CREDITS.md)
## (2026-11-08) 울타리·걸상·장작은 polyfork 대신 우리 잔가지 조각 (같은 이름·자리 — 사람 세상의 켠 통나무처럼 보여서)
const PF_JARS := "props/pf_yard_jars"       # 옹기 단지 둘 + 바구니 (집·창고 마당)
const PF_FENCE := "props/pf_fence"          # 잔가지 울타리 한 칸 (기둥 둘·가름대 둘을 풀끈으로 묶음, 길이 1칸, 높이 0.6)
const PF_CORDWOOD := "props/pf_cordwood"    # 쌓은 잔가지 토막 (나무꾼 마당)
const PF_BENCH := "props/pf_bench"          # 반으로 쪼갠 잔가지 걸상 (모닥불 둘레 — view/campfire.gd)
const PF_CAIRN := "props/pf_cairn"
const PF_MOSS := "props/pf_moss"
const PF_FERN := "props/pf_fern"
const FERN_CLEAR := 3.5           # 거대한 고사리 (폭 약 9칸) 둘레 비움 — 집·모닥불·제단·길 가운데에서 이만큼


func _ready() -> void:
	for nm: String in PRELOAD:
		Art.model(nm)
	Art.parts(ResidentModel.PARTS)
	ResidentModel.kit()
	_trees = _node(self)
	_rocks = _node(self)
	_manna = _node(self)
	_props = _node(self)
	_lily_node = _node(self)
	_far = _node(self)
	for n: Node3D in [_trees, _props, _far]:
		_batches[n] = FloraBatch.new(n)
	mold_view = MoldView.new(v)     # [곰팡이·뚜껑]
	add_child(mold_view)
	crisis_view = CrisisView.new(v)   # [작은 위기]
	add_child(crisis_view)
	flora_view = FloraView.new(v)   # [하늘의 것]
	add_child(flora_view)
	drop_view = SkyDropView.new(v, terrain)   # [상점]
	add_child(drop_view)
	animal_view = AnimalView.new(v, self)   # [들짐승]
	add_child(animal_view)
	fauna_view = FaunaView.new(v, self)     # [강아지·작은 생물]
	add_child(fauna_view)
	social = SocialStage.new(v, self)   # [마을의 삶]
	add_child(social)
	_build_fire()
	sync(0.0, true)


func _node(parent: Node3D) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	return n


func gy(x: float, z: float) -> float:
	return terrain.ground_y(x, z)


# ───────────────────────── 매 화면 ─────────────────────────
func sync(dt: float, force := false) -> void:
	_anim_t += dt
	if fast and not force:          # 빠른 흐름: 움직이는 것들은 FAST_EVERY초마다 한 번 (그동안 쌓인 dt로)
		_fast_t += dt
		_fast_dt += dt
		if _fast_t >= FAST_EVERY:
			_fast_t = 0.0
			_sync_moving(_fast_dt)
			_fast_dt = 0.0
	else:
		_fast_dt = 0.0
		_sync_moving(dt)
	_check_t += dt
	if force or _check_t >= 0.25:
		_check_t = 0.0
		if force:
			_far_t = -1.0e9           # 안개만 바뀐 먼 숲도 바로 다시
		_sync_buildings()
		_sync_graves()
		_sync_trees()
		_sync_rocks()
		_sync_manna()
		_sync_props()
		_lily_t += 0.25
		if force or _lily_t >= 1.0:
			_lily_t = 0.0
			_sync_lilies(false)
	_flora_lod()
	_animate_fire()
	_animate_live(dt)
	if altar_view != null:
		altar_view.sync(dt)
		manna_fx.sync(dt)


## (P1 성능) 꽃숲 묶음: 확대에 따라 멀리 덩이 · 화면 밖 자르기 (view/flora_batch.gd)
func _flora_lod() -> void:
	if _batches.is_empty() or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	var ppu := 16.0
	var vr := {"ok": false}
	if cam != null:
		if cam.projection == Camera3D.PROJECTION_ORTHOGONAL and cam.size > 0.0:
			ppu = float(get_viewport().get_visible_rect().size.y) / cam.size
		if flora_cull:
			vr = FloraBatch.view_rect(cam, self, -2.0, 6.0)
	for b: FloraBatch in _batches.values():
		b.cull = flora_cull
		b.update(1.0e9 if flora_force_near else ppu, vr)


## 건물 LOD는 sync와 따로 매 화면 (병 밖 보기처럼 sync가 멈춘 동안에도 축소를 따라가게)
func _process(_dt: float) -> void:
	_bld_lod()
	if bld_far and bld_batch:
		_check_far_moving()


## 건물 멀리 LOD 고르기 (매 화면 — 바뀔 때만 노드를 건드림)
func _bld_lod(force := false) -> void:
	var want := bld_far
	if bld_force_lod >= 0:
		want = bld_force_lod == 1
	else:
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam == null:
			return
		var ppu := 16.0
		var h := float(get_viewport().get_visible_rect().size.y)
		if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
			if cam.size <= 0.0:
				return
			ppu = h / cam.size
		else:                                    # 원근 카메라 (거인의 방 · 병 밖 보기): 마을 가운데까지 거리로 어림
			var d := cam.global_position.distance_to(to_global(Vector3(v.center.x, 0.0, v.center.y)))
			ppu = h / maxf(0.01, 2.0 * d * tan(deg_to_rad(cam.fov) * 0.5))
		want = ppu < (BLD_FAR_OUT if bld_far else BLD_FAR_IN)
	if want == bld_far and not force:
		return
	bld_far = want
	if bld_far and (_far_dirty or _far_batch == null):
		_sync_far_batch()             # 안에서 _apply_bld_lod
	else:
		for id in _blds:
			_apply_bld_lod(_blds[id])
	if _far_batch != null:
		_far_batch.visible = bld_far
	if _yard != null:
		_yard.visible = not bld_far


func _apply_bld_lod(n: Node3D) -> void:
	var near := n.get_node_or_null("near") as Node3D
	var far := n.get_node_or_null("far") as Node3D
	if near == null or far == null:
		return
	near.visible = not bld_far or far.get_child_count() == 0       # 멀리 모양이 없는 모델은 가까이 그대로
	var batched := bld_far and _batched(n)
	far.visible = bld_far and far.get_child_count() > 0 and not batched
	var piles := n.get_node_or_null("piles") as Node3D
	if piles != null:
		piles.visible = not batched


## 꽃숲 묶음 수 (시험·측정): {"total": 놓은 수, "drawn": 지금 그리는 수, "far": 멀리 덩이인가}
func flora_stats() -> Dictionary:
	var t := 0
	var d := 0
	var f := false
	for b: FloraBatch in _batches.values():
		t += b.n_total
		d += b.n_drawn
		f = f or b.far
	return {"total": t, "drawn": d, "far": f}


## 주민 · 곰팡이 · 작은 위기 · 하늘의 것 · 상점 · 들짐승 (보통은 매 화면)
func _sync_moving(dt: float) -> void:
	if social != null:
		social.sync(dt, fast)
	_sync_residents(dt)
	mold_view.alpha = alpha         # [곰팡이·뚜껑]
	mold_view.sync(dt)
	crisis_view.alpha = alpha       # [작은 위기]
	crisis_view.sync(dt)
	flora_view.alpha = alpha        # [하늘의 것]
	flora_view.sync(dt)
	if drop_view != null:
		drop_view.sync(dt)          # [상점]
	if animal_view != null:
		animal_view.sync(dt)        # [들짐승]
	if fauna_view != null:
		fauna_view.alpha = alpha    # [강아지·작은 생물]
		fauna_view.sync(dt, fast)


static func age_stage(r: Resident) -> int:
	if r.is_baby():
		return 0
	if r.is_child():
		return 1 + int(r.age)       # 아이는 자라면서 조금씩 커짐
	return 10 if r.is_adult() else 11


## (A20 v3) 주민 LOD: 카메라 확대(칸당 화면 점)가 ResidentModel.LOD_PPU 이상이면 가까이 LOD (정사영 — 거리 대신 확대로)
func _resident_lod_close() -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL or cam.size <= 0.0:
		return true
	return get_viewport().get_visible_rect().size.y / cam.size >= ResidentModel.LOD_PPU


func _sync_residents(dt: float) -> void:
	ResidentModel.village_era = v.era     # (A20 2차) 시대마다 옷이 달라짐 — look_of · look_key가 읽음
	ResidentModel.daylight = ResidentModel.is_hat_time(v.hour_now())   # (A23) 낮엔 머리쓰개, 저녁엔 벗음
	var seen := {}
	var chief := v.chief()
	var lod_close := _resident_lod_close()
	fish_pair = fish_pairs(v.people)
	for r in v.people:
		seen[r.id] = true
		var m: ResidentModel = residents.get(r.id)
		var key := ResidentModel.look_key(r)      # 나이·대머리·흰머리 단계가 바뀌면 다시 만든다 (7단계)
		var fresh: bool = m == null or _res_key.get(r.id, -1) != key
		if fresh:
			if m != null:
				m.queue_free()
			m = ResidentModel.new()
			add_child(m)
			m.setup_from(r)
			residents[r.id] = m
			_res_key[r.id] = key
		# 집 안에서 자는 사람·집 안의 아기는 보이지 않는다
		var hm := v.bld(r.home)
		var inside := hm != null and r.anim == "sleep" and Vector2(r.x - hm.x, r.y - hm.y).length() < 0.6
		m.visible = not inside
		if not m.visible:
			continue
		var x := r.x
		var z := r.y
		if alpha < 1.0 and absf(r.x - r.px) + absf(r.y - r.py) < lerp_max:     # 순간이동(집 안·새로 태어남)은 보간하지 않음
			x = lerpf(r.px, r.x, alpha)
			z = lerpf(r.py, r.y, alpha)
		m.move_to(Vector3(x, gy(x, z), z), dt)     # 땅 빠르기를 재어 걸음 동작을 맞춤 (발 미끄러짐 없음)
		m.rotation.y = r.facing
		if (r.anim == "walk" or r.anim == "carry") and not crossings.is_empty():     # (E3-6) 징검돌에서 폴짝 · 다리 위
			m.position.y = maxf(m.position.y, crossing_y(x, z))
		if staged.has(r.id):            # (스타터킷 풀기) 장면이 직접 — 상자 가장자리를 넘어 폴짝
			var st: Dictionary = staged[r.id]
			m.visible = bool(st.get("vis", true))
			m.position = st.get("pos", m.position)
			m.rotation.y = float(st.get("rot", r.facing))
			m.set_lod(true)
			m.set_face(String(st.get("face", "")))
			m.set_anim(String(st.get("anim", "idle")))
			m.tick(dt)
			var tl: Vector2 = st.get("tilt", Vector2.ZERO)
			if tl != Vector2.ZERO:
				m.tilt_head(tl.x, tl.y)
			continue
		var rafting := _raft(r, m)      # (A6) 나루터 뗏목 위 (E3-6: 갈대 뗏목 / 잎 배 + 장대)
		_ride(r, m)                     # [하늘의 것] 꽃씨에 매달린 아이 — 떠올라 날아감
		var jb0 := v.bld(r.job)                 # (A20) 직업 옷·연장 · 촌장 띠 · 표정 — 바뀔 때만 부품을 갈아 끼움
		m.set_job(jb0.type if jb0 != null else "", r == chief)
		m.set_face(ResidentModel.face_of(r))
		m.set_pale(r.latent != "")      # [B7] 밖에서 병을 지니고 온 사람: 잠복 동안 창백한 얼굴빛 (거인에게만 보이는 조짐)
		m.set_item(r.carry if not fish_pair.has(r.id) else "생선:" + String(fish_pair[r.id][0]))
		if r.anim == "work":
			var jb := v.bld(r.job)
			m.set_tool(jb.type if jb != null else "")
		m.set_anim("idle" if rafting else ("work" if r.anim == "torch" else r.anim), r.action)
		if r.action == "social" and r.anim != "walk" and not fast:
			_face_partner(r, m)
		if social != null and not fast:
			social.pose(r, m)           # [마을의 삶] 장면 속 사람: 마주 봄·몸짓·표정
		var po: Dictionary = pose_over.get(r.id, {})
		if not po.is_empty():           # (E1-0) 연출이 몸짓·표정을 잠깐 정함
			if po.has("face"):
				m.set_face(String(po["face"]))
			if po.has("anim") and r.anim != "walk":
				m.set_anim(String(po["anim"]), r.action)
		m.set_lod(lod_close and not fast)
		if not fast:                    # 빠른 흐름: 몸짓(걷기 보간·팔다리)은 멈춰 두고 자리만 옮긴다
			m.tick(dt)
			if social != null:
				social.after_tick(r, m)
		elif fresh:
			m.tick(0.0)
		if not po.is_empty():
			if float(po.get("up", 0.0)) != 0.0 or float(po.get("side", 0.0)) != 0.0:
				m.tilt_head(float(po.get("up", 0.0)), float(po.get("side", 0.0)))
			if po.has("arm"):
				var ar: Vector2 = po["arm"]
				m.aim_arm_r(ar.x, ar.y)
		_torch(r, m)
		if rafting:                     # 장대를 두 손으로 밀어 나감 (오른팔 — 장대와 같은 박자)
			m.aim_arm_r(-0.95 + 0.3 * sin(_anim_t * POLE_SPEED + r.id), 0.35)
	_pair_follow(dt)
	for id in _torches.keys():
		if not seen.has(id) or not is_instance_valid(_torches[id]):
			_torches.erase(id)
	for id in _torch_glows.keys():
		if not seen.has(id):
			(_torch_glows[id] as Node3D).queue_free()
			_torch_glows.erase(id)
	for id in residents.keys():
		if not seen.has(id):
			(residents[id] as Node3D).queue_free()
			residents.erase(id)
			_res_key.erase(id)
	for id in _rafts.keys():
		if not seen.has(int(id) / 2):
			(_rafts[id] as Node3D).queue_free()
			_rafts.erase(id)


## (E3-6 GD 3.0) 물고기를 나르는 어른 둘이 같은 쪽으로 가까이 걸으면 장대에 메고 간다 → id → [역할 "앞"/"뒤", 짝 id].
## 화면만 — 시뮬레이션의 먹을거리 양은 그대로 (각자 제 몫을 창고에 내려놓음)
const PAIR_R := 3.2             # 이만큼 가까이 (칸)
const PAIR_ANGLE := 0.75        # 걷는 방향 차이 (라디안)


static func fish_pairs(people: Array) -> Dictionary:
	var cs: Array[Resident] = []
	for r: Resident in people:
		if r.carry == "생선" and (r.anim == "carry" or r.anim == "walk") and not r.is_child() and not r.sleeping:
			cs.append(r)
	var out := {}
	if cs.size() < 2:
		return out
	for i in cs.size():
		var a := cs[i]
		if out.has(a.id):
			continue
		var best: Resident = null
		var bd := PAIR_R
		for j in range(i + 1, cs.size()):
			var b := cs[j]
			if out.has(b.id) or absf(angle_difference(a.facing, b.facing)) > PAIR_ANGLE:
				continue
			var d := Vector2(a.x - b.x, a.y - b.y).length()
			if d < bd:
				bd = d
				best = b
		if best == null:
			continue
		var fwd := Vector2(sin(a.facing), cos(a.facing))
		var lead := a if Vector2(a.x - best.x, a.y - best.y).dot(fwd) >= 0.0 else best
		var back := best if lead == a else a
		out[lead.id] = ["앞", back.id]
		out[back.id] = ["뒤", lead.id]
	return out


## 뒤 사람을 앞 사람의 장대 끝으로 (짝이 생기면 0.3초쯤에 걸쳐 붙고, 풀리면 제 자리로)
func _pair_follow(dt: float) -> void:
	for id: int in _pair_w.keys():
		if not fish_pair.has(id) or fish_pair[id][0] != "뒤":
			_pair_w.erase(id)
	for id: int in fish_pair:
		if fish_pair[id][0] != "뒤":
			continue
		var m: ResidentModel = residents.get(id)
		var lm: ResidentModel = residents.get(int(fish_pair[id][1]))
		if m == null or lm == null or not m.visible or not lm.visible:
			continue
		var wgt := minf(1.0, float(_pair_w.get(id, 0.0)) + (dt * 3.5 if dt > 0.0 else 1.0))
		_pair_w[id] = wgt
		var f := Vector3(sin(lm.rotation.y), 0.0, cos(lm.rotation.y))
		var to := lm.position - f * ResidentModel.POLE_GAP * lm.scale.x      # 모델 단위 × 모델 크기 = 칸
		var p := m.position.lerp(to, wgt)
		p.y = maxf(gy(p.x, p.z), crossing_y(p.x, p.z))
		m.position = p
		m.rotation.y = lerp_angle(m.rotation.y, lm.rotation.y, wgt)


## 어울리는 사람: 가까이 있는 다른 어울리는 사람 쪽으로 몸을 돌림 (둘씩 마주 보고 이야기) — 화면만, 시뮬레이션은 그대로
func _face_partner(r: Resident, m: ResidentModel) -> void:
	var best: Resident = null
	var bd := 2.4 * 2.4
	for q in v.people:
		if q == r or q.action != "social" or q.anim == "walk":
			continue
		var d := Vector2(q.x - r.x, q.y - r.y).length_squared()
		if d < bd and d > 0.0001:
			bd = d
			best = q
	if best != null:
		m.rotation.y = lerp_angle(r.facing, atan2(best.x - r.x, best.y - r.y), 0.85)


## (A6) 무덤: 흙 둔덕 + 작은 비석 (묘지 안이면 줄지어, 묘지가 없을 땐 마을 끝에 홀로)
func _sync_graves() -> void:
	var key := "%d|%d" % [v.graves.size(), v.water.rot]
	if key == _grave_key:
		return
	_grave_key = key
	if _graves != null:
		_graves.queue_free()
	_graves = _node(self)
	# (P1 2차) 무덤마다 상자 셋을 따로 그리면 무덤 27개 = 그리기 54+ → 부품마다 MultiMesh 하나 (그리기 3).
	# 주민 키 절반보다 낮아 그림자 끔 (아트 바이블 8.8).
	var parts := [[Vector3(0.42, 0.1, 0.62), Vector3(0, 0.04, 0.08), Style.WOOD.darkened(0.15)],
		[Vector3(0.3, 0.38, 0.09), Vector3(0, 0.2, -0.22), Style.STONE],
		[Vector3(0.22, 0.06, 0.1), Vector3(0, 0.42, -0.22), Style.STONE.lightened(0.15)]]
	var xfs: Array[Transform3D] = []
	for g: Dictionary in v.graves:
		var x := float(g["x"])
		var z := float(g["y"])
		var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG) + fposmod(float(g["id"]) * 0.37, 0.3) - 0.15
		xfs.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(x, gy(x, z), z)))
	if xfs.is_empty():
		return
	for p: Array in parts:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = ResidentModel.box_of(p[0])
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i] * Transform3D(Basis.IDENTITY, p[1]))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Toon.mat(p[2])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_graves.add_child(mmi)


## (A6) 뗏목 길을 건너는 사람: 발밑에 뗏목 (물 위 높이) · 치료소에 누운 사람: 밑에 흰 깔개.
## (E3-6 GD 3.0 물가 표) 개척 시대 = 마른 갈대 다발 뗏목, 그 뒤 = 말려 굳힌 큰 잎 배. 탄 사람이 장대로 바닥을 밀어 건넌다. 뗏목 위면 true
const POLE_SPEED := 2.4


func _raft(r: Resident, m: ResidentModel) -> bool:
	if _raft_era != v.era:          # 시대가 바뀌면 뗏목 모양도 (갈대 뗏목 → 잎 배)
		_raft_era = v.era
		for k0: int in _rafts.keys():
			if k0 % 2 == 0:
				(_rafts[k0] as Node3D).queue_free()
				_rafts.erase(k0)
	var on := not r.steps.is_empty() and bool((r.steps[0] as Dictionary).get("raft", false)) and m.visible
	var mat := r.doing == "치료소에 누운 중" and r.anim == "sleep" and m.visible
	var key := r.id * 2 + (1 if mat else 0)
	for k2 in [r.id * 2, r.id * 2 + 1]:
		if k2 != key or not (on or mat):
			var old: Node3D = _rafts.get(k2)
			if old != null:
				old.visible = false
	if not on and not mat:
		return false
	var rf: Node3D = _rafts.get(key)
	if rf == null:
		rf = _node(self)
		if mat:
			_box(rf, Vector3(0.62, 0.05, 1.25), Vector3(0, -0.08, 0.0), Color("f3ecd8"))
			_box(rf, Vector3(0.5, 0.1, 0.28), Vector3(0, -0.03, -0.45), Color("d9e4ec"))
		else:
			var nm := raft_model(v.era)
			if Art.exists(nm):
				Art.instance(rf, nm, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO))    # 모델은 x로 길다 → 가는 쪽(+z)으로
			else:
				for i in 4:
					_box(rf, Vector3(0.22, 0.12, 1.2), Vector3(-0.36 + i * 0.24, 0.0, 0.0), Style.WOOD)
			var pole := _node(rf)          # 장대: 오른손 높이를 축으로, 물 바닥을 뒤로 밀며 흔들림
			pole.name = "pole"
			pole.position = Vector3(-0.3, 0.62, 0.05)
			_box(pole, Vector3(0.045, 1.9, 0.045), Vector3(0, -0.45, 0), Color("c4b47a"))
			_box(pole, Vector3(0.06, 0.05, 0.06), Vector3(0, 0.1, 0), Color("8f7a48"))
		_rafts[key] = rf
	rf.visible = true
	if mat:
		rf.position = m.position + Vector3(0, 0.1, 0)
		rf.rotation.y = r.facing
		return false
	var k := v.water.idx(m.position.x, m.position.z)
	var wy := (v.water.ground(k) + v.water.depth(k)) * JarTerrain.HS - JarTerrain.WATER_SINK
	var y := maxf(m.position.y, wy) + 0.05
	var bob := sin(_anim_t * 1.7 + r.id) * 0.025      # 물결에 살랑
	rf.position = Vector3(m.position.x, y + bob, m.position.z)
	rf.rotation.y = r.facing
	rf.rotation.z = sin(_anim_t * 1.3 + r.id * 0.7) * 0.04
	var pole: Node3D = rf.get_node_or_null("pole")
	if pole != null:
		pole.rotation.x = -0.45 + 0.3 * sin(_anim_t * POLE_SPEED + r.id)
	m.position.y = y + bob + 0.1
	return true


## 나루터 배 모양: 개척 시대 = 갈대 뗏목 · 그 뒤 = 잎 배 (GD 3.0 물가 표 — 씨앗 껍데기 배는 나중)
static func raft_model(era: int) -> String:
	return "raft_reed" if era <= 0 else "boat_leaf"


## [곰팡이·뚜껑] 곰팡이 쫓는 사람: 오른손에 횃불 (걸을 땐 높이 들고, 휘두를 땐 연장 대신). 불꽃은 깜빡임
func _torch(r: Resident, m: ResidentModel) -> void:
	var on := r.action == "mold_chase" and m.visible
	var tn: Node3D = _torches.get(r.id)
	if not on:
		if tn != null and is_instance_valid(tn):
			tn.visible = false
		var g0: Node3D = _torch_glows.get(r.id)
		if g0 != null and is_instance_valid(g0):
			g0.visible = false
		return
	if tn == null or not is_instance_valid(tn):
		tn = Node3D.new()
		m.tool.get_parent().add_child(tn)
		tn.position = m.tool.position
		_box(tn, Vector3(0.13, 0.95, 0.13), Vector3(0, 0.05, 0.0), Style.WOOD_DARK)
		_box(tn, Vector3(0.22, 0.16, 0.22), Vector3(0, 0.5, 0.0), Style.WOOD)
		_box(tn, Vector3(0.42, 0.5, 0.42), Vector3(0, 0.78, 0.0), Style.FLAME, 0.4).name = "f1"
		_box(tn, Vector3(0.22, 0.34, 0.22), Vector3(0, 0.95, 0.0), Style.FLAME2, 0.9).name = "f2"
		_torches[r.id] = tn
	# 횃불 빛: 발밑의 따뜻한 빛 웅덩이 (툰 빛을 흔들지 않게 빛 대신 반투명 원판)
	var glow: MeshInstance3D = _torch_glows.get(r.id)
	if glow == null or not is_instance_valid(glow):
		glow = MeshInstance3D.new()
		var disc := PlaneMesh.new()
		disc.size = Vector2(2.6, 2.6)
		glow.mesh = disc
		glow.material_override = _glow_mat()
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glow)
		_torch_glows[r.id] = glow
	glow.visible = true
	glow.position = m.position + Vector3(0, 0.03, 0)
	glow.scale = Vector3.ONE * (0.95 + 0.08 * sin(_anim_t * 13.0 + r.id))
	tn.visible = true
	m.tool.visible = false
	var ax := -1.6                        # 걸을 때: 횃불을 앞으로 높이
	if r.anim == "torch":                 # 휘두르기: 횃불을 앞으로 내밀었다 거뒀다 (불꽃은 늘 위로)
		ax = -1.25 + 0.4 * sin(_anim_t * 8.0 + r.id)
	m.aim_arm_r(ax, 0.2)                  # (A20 v3) 오른팔 뼈를 직접 겨눔 — tick 뒤
	tn.rotation.x = -ax
	var f := int(_anim_t * 10.0 + r.id) % 3
	var hs := [1.0, 1.3, 0.8]
	var f1 := tn.get_node("f1") as Node3D
	var f2 := tn.get_node("f2") as Node3D
	f1.scale.y = hs[f]
	f2.scale.y = hs[(f + 1) % 3]


## [하늘의 것] 꽃씨에 매달린 아이: 몸을 띄우고 머리 위에 큰 꽃씨 (sim/flora.gd ride_h)
func _ride(r: Resident, m: ResidentModel) -> void:
	var h: float = v.flora.ride_h.get(r.id, 0.0) if v.flora != null else 0.0
	var sd := flora_view.rider_seed(r.id, h > 0.01)
	if h <= 0.01:
		return
	m.position.y += h
	if sd != null:
		sd.position = m.position + Vector3(sin(_anim_t * 2.0) * 0.05, 1.05, 0)
		sd.rotation.z = sin(_anim_t * 1.6 + r.id) * 0.15


static var _glow: ShaderMaterial


## 횃불 빛 웅덩이: 가운데가 밝고 가장자리로 사라지는 따뜻한 원 (더하기 섞기, 도트처럼 몇 단계로 끊음)
static func _glow_mat() -> ShaderMaterial:
	if _glow == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = floor(clamp(1.0 - d, 0.0, 1.0) * 4.0) / 4.0;
	ALBEDO = vec3(1.0, 0.6, 0.22);
	ALPHA = a * 0.38;
}"""
		_glow = ShaderMaterial.new()
		_glow.shader = sh
	return _glow


# ───────────────────────── 건물 ─────────────────────────
func _bld_state(b: Building) -> String:
	var piles := ""
	for k in b.out:
		piles += "%s%d" % [k, mini(6, int(b.out[k]))]
	var stage := SITE_STAGES
	if b.is_site():
		stage = site_stage(b)
	var ripe := wheat_stage(b, v.t) if b.type == "농장" else 0
	# 자리·병 방향도 키에 (병을 돌리면 건물 자리가 돈다)
	var era := v.era if b.type == "나루터" else 0      # (E3-6) 나루터: 개척 시대는 갈대 뗏목, 그 뒤 잎 배
	return "%s|%s|%s|%d|%d,%d|%d|%s|%.2f,%.2f|%d|%d" % [b.type, b.built, b.upgrade_to, stage, int(b.delivered["판자"]), int(b.delivered["돌"]), ripe, piles, b.x, b.y, v.water.rot, era]


func _sync_buildings() -> void:
	var seen := {}
	for b in v.buildings:
		if b.site_type() == Awakening.ALTAR:      # 제단은 AltarView가 그린다 (짓는 모습까지)
			continue
		if hidden_blds.has(b.id):
			continue
		seen[b.id] = true
		var key := _bld_state(b)
		if _bld_key.get(b.id, "") == key:
			continue
		_bld_key[b.id] = key
		if _yard_xf.erase(b.id):             # 다시 만들 때 _build_shape가 다시 넣는다
			_yard_dirty = true
		if _blds.has(b.id):
			(_blds[b.id] as Node3D).queue_free()
		var n := Node3D.new()
		add_child(n)
		_blds[b.id] = n
		var size := b.size()
		var y := gy(b.x, b.y)
		for a in 4:      # 비탈에서 뜨지 않게 가장 낮은 곳에
			y = minf(y, gy(b.x + cos(a * PI / 2.0) * size, b.y + sin(a * PI / 2.0) * size))
		if not b.built:                      # 짓는 터는 가운데 땅 높이에 (낮은 귀퉁이에 맞추면 말뚝·고랑이 땅에 묻힘)
			y = gy(b.x, b.y) - 0.02
		n.position = Vector3(b.x, y, b.y)
		n.scale = Vector3.ONE * BUILDING_SCALE
		# 앞(문)이 기본 카메라 쪽(방위 45°)을 보게 + 조금씩 다르게 (시뮬레이션에는 방향이 없음)
		n.rotation.y = VillagePlan.facing(v, b)       # [배치] 앞(문, 모델 +z)이 길·광장 쪽 (sim/village_plan.gd)
		if b.type == "나루터" and b.has_link:          # 나루터 모델은 +x가 물 쪽 → 건너편을 보게 (A6)
			var ld := Vector2(b.link_x - b.x, b.link_y - b.y)
			n.rotation.y = atan2(ld.x, ld.y)        # 잔교는 모델의 +z 쪽으로 뻗는다
		if b.built and b.upgrade_to == "":
			_build_shape(n, b)
		else:
			if b.built:
				_build_shape(n, b)          # 개축 중: 옛 집 + 비계
			_build_site(n, b)
		_build_piles(n, b)
		n.set_meta("bid", b.id)
		_record_far(b.id, n)
		_apply_bld_lod(n)
	for id in _blds.keys():
		if not seen.has(id):
			(_blds[id] as Node3D).queue_free()
			_blds.erase(id)
			_bld_key.erase(id)
			if _yard_xf.erase(id):
				_yard_dirty = true
			if _far_items.erase(id):
				_far_dirty = true
			_far_rest.erase(id)
			_far_moving.erase(id)
	if _yard_dirty:
		_sync_yard()
	if _far_dirty and bld_far:
		_sync_far_batch()


## (P1 3차) 이 건물의 멀리 모양("far" 노드)과 짐 더미("piles")를 묶음용으로 기록 — 멀리 모양이 없으면 묶지 않음
func _record_far(id: int, n: Node3D) -> void:
	_far_dirty = _far_items.erase(id) or _far_dirty
	_far_moving.erase(id)
	var far := n.get_node_or_null("far") as Node3D
	if not bld_batch or far == null or far.get_child_count() == 0:
		return
	var items: Array = []
	for root: Node3D in [far, n.get_node_or_null("piles") as Node3D]:
		if root == null:
			continue
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.visible:
				continue
			var xf := mi.transform
			var p := mi.get_parent()
			while p != null and p != n:
				xf = (p as Node3D).transform * xf
				p = p.get_parent()
			items.append([mi.mesh, mi.material_override, mi.cast_shadow, xf])
	_far_items[id] = items
	_far_rest[id] = n.transform
	_far_dirty = true


func _sync_far_batch() -> void:
	_far_dirty = false
	if _far_batch != null:
		_far_batch.queue_free()
	_far_batch = _node(self)
	_far_batch.name = "far_batch"
	_far_batch.visible = bld_far
	# 같은 (재질 · 그림자)끼리 한 메시로 구워 합침 — 모델마다 메시가 달라 MultiMesh로는 모델 수만큼 그려짐 (멀리 모양 약 6k 삼각형이라 굽기 값쌈)
	var groups := {}                # [재질, 그림자] → SurfaceTool
	for id in _far_items:
		if _far_moving.has(id) or not _blds.has(id):
			continue
		var bx: Transform3D = _far_rest[id]
		for it: Array in _far_items[id]:
			var mesh: Mesh = it[0]
			for si in mesh.get_surface_count():
				var mat: Material = it[1] if it[1] != null else mesh.surface_get_material(si)
				var k := [mat, it[2]]
				if not groups.has(k):
					groups[k] = SurfaceTool.new()
				(groups[k] as SurfaceTool).append_from(mesh, si, bx * (it[3] as Transform3D))
	for k: Array in groups:
		var mi := MeshInstance3D.new()
		mi.mesh = (groups[k] as SurfaceTool).commit()
		mi.material_override = k[0]
		mi.cast_shadow = k[1]
		_far_batch.add_child(mi)
	for id in _blds:
		_apply_bld_lod(_blds[id])


## 묶음에 든 건물인가 (멀리 모양 기록이 있고 지금 움직이지 않음)
func _batched(n: Node3D) -> bool:
	var id: int = n.get_meta("bid", -1)
	return bld_batch and _far_items.has(id) and not _far_moving.has(id) and _far_batch != null and not _far_dirty


## 매 화면 (멀리일 때만): 노드 변환이 기록과 달라진 건물(떨어지는 중)은 묶음에서 빼고, 제자리로 돌아오면 다시 넣음
func _check_far_moving() -> void:
	var changed := false
	for id in _far_items:
		var n: Node3D = _blds.get(id)
		if n == null:
			continue
		var moving := not n.transform.is_equal_approx(_far_rest[id])
		if moving != _far_moving.has(id):
			changed = true
			if moving:
				_far_moving[id] = true
			else:
				_far_moving.erase(id)
	if changed or _far_dirty:
		_sync_far_batch()


## (P1 2차) 앞마당 소품을 모양마다 MultiMesh로 (집 15채 × 2 = 노드 30개 × 몸·껍데기·그림자 → 모양 3개). 낮은 것이라 그림자 끔.
func _sync_yard() -> void:
	_yard_dirty = false
	if _yard != null:
		_yard.queue_free()
	_yard = _node(self)
	_yard.name = "yard"
	_yard.visible = not bld_far
	var groups := {}
	for id in _yard_xf:
		var n: Node3D = _blds.get(id)
		if n == null:
			continue
		for e: Array in _yard_xf[id]:
			if not groups.has(e[0]):
				groups[e[0]] = [] as Array[Transform3D]
			(groups[e[0]] as Array[Transform3D]).append(n.transform * (e[1] as Transform3D))
	for k: String in groups:
		Art.multi(_yard, k, groups[k], false)


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ResidentModel.box_of(size)
	mi.material_override = Toon.mat(c)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


## 건물 모양 → art/models의 모델 (art/src/build_buildings.py · build_village.py). 종류마다 하나, 오두막은 네 가지를 번갈아.
## 일터는 모델 + 마당 소품 (벌목장 = 통나무집 + 장작 헛간 + 도끼 박힌 그루터기). 묘목원은 묘목 줄이 모델 안에 있다.
## v3 (2026-11): 종류마다 실루엣·지붕 재료가 다르게 — 둥근 초가 · 너와 · 슬레이트 · 붉은 기와 · 잔디 지붕. 집은 색 변형을 번갈아.
const BUILDING_MODELS := {"오두막": ["cottage_a", "cottage_b", "cottage_c", "cottage_d"], "목조주택": ["house_timber", "house_timber_b"], "석조주택": ["house_stone", "house_stone_b"],
	"창고": ["storehouse"], "나무꾼": ["hut"], "산림관": ["forester"], "채석장": ["quarry"], "제재소": ["sawmill"],
	"우물": ["well"], "방앗간": ["windmill"], "빵집": ["bakery"], "소금밭": ["saltpan"], "농장": ["buildings/wheat_forest_green"],      # 농장은 _build_wheat (자람 단계)
	"맷돌간": ["quern_house"], "화덕": ["oven"],     # v5 빵 사슬 (art/src/build_pioneer.py): 맷돌 윗돌·화덕 불은 따로 (QUERN_STONE · OVEN_GLOW)
	"버섯꾼": ["mushroom_hut"],
	# 마을 시대 (A6, art/src/build_village.py) — 시뮬레이션 종류 이름이 정해지면 여기 이름을 맞춘다. 모델 바닥 크기(칸):
	# 어부 1.6×1.2 · 사냥꾼 1.6×1.2 · 약초꾼 1.7×1.2 · 치료소 2.5×1.5(+오른쪽 툇마루 1칸) · 방직소 2.3×1.5(+왼쪽 처마 0.8)
	# 대장간 1.5×1.5(+오른쪽 대장간 헛간 1.4) · 교회 2.0×3.0 · 광장 지름 3.8 · 묘지 2.6×2.2 · 목장 4.0×3.4 · 망루 1.4×1.4(높이 4.3)
	# 나루터 = pier처럼 원점이 물가, +x(모델 기준)로 2.6칸 물 위 (옆에 뗏목)
	"어부": ["fisher"], "사냥꾼": ["hunter"], "약초꾼": ["herbalist"], "치료소": ["healer"], "방직소": ["weaver"],
	"대장간": ["smithy"], "교회": ["chapel"], "광장": ["plaza"], "묘지": ["graveyard"], "목장": ["pasture"],
	"망루": ["watchtower"], "나루터": ["ferry"]}
## 맷돌간의 윗돌 (art/models/quern_stone.glb — 원점 = 도는 축, 아랫돌 윗면): 빻는 동안 돈다
const QUERN_STONE := "quern_stone"
const QUERN_STONE_AT := Vector3(0.0, 0.46, -0.05)
const QUERN_SPIN := 2.4             # 라디안/초 (화면 시간)
## 공용 화덕 아궁이 불 (art/models/oven_glow.glb — 원점 = 화덕 원점): 굽는 동안만 켜짐 (빛나는 재질 + 발밑 빛 웅덩이)
const OVEN_GLOW := "oven_glow"
const OVEN_GLOW_COLOR := Color(1.0, 0.62, 0.28)
## 마당 소품: [모델, 건물 기준 자리(x, z — 건물 앞 = +z), 방위(라디안)]
## (E3 소인의 세상) 장작더미 대신 나뭇가지 더미 [모델, 자리, 방위, 크기]
const YARD := {"나무꾼": [["flora/twig_pile_a", Vector3(-1.75, 0, -0.1), 0.0, 0.36], ["flora/twig_pile_b", Vector3(-1.2, 0, 1.2), 0.6, 0.26]]}
const TWIG_PILE_GOODS := ["통나무", "판자"]   # 쌓인 짐이 이것이면 상자 대신 나뭇가지 더미


func _build_shape(n: Node3D, b: Building) -> void:
	var near := Node3D.new()
	near.name = "near"
	n.add_child(near)
	var far := Node3D.new()
	far.name = "far"
	n.add_child(far)
	if b.type == "농장":
		_build_wheat(near, far, b)
		_set_yard(far, b, far.get_child_count() > 0)
		_apply_bld_lod(n)
		return
	var names: Array = BUILDING_MODELS.get(b.type, ["hut"])
	var nm: String = names[b.id % names.size()]
	if nm == "ferry" and v.era == 0 and Art.exists("ferry_raft"):
		nm = "ferry_raft"
	Art.instance(near, nm)
	if Art.has_far(nm):
		Art.instance(far, nm, Transform3D.IDENTITY, true)
	if nm == "quern_house" and Art.exists(QUERN_STONE):
		_live[b.id] = {"stone": Art.instance(near, QUERN_STONE, Transform3D(Basis.IDENTITY, QUERN_STONE_AT))}
	elif nm == "oven" and Art.exists(OVEN_GLOW):
		_live[b.id] = {"glow": _oven_glow(n)}
	for y: Array in YARD.get(b.type, []):
		Art.instance(near, y[0], Transform3D(Basis(Vector3.UP, y[2]).scaled(Vector3.ONE * float(y[3]) if y.size() > 3 else Vector3.ONE), y[1]))
	_set_yard(far, b, Art.has_far(nm))
	_apply_bld_lod(n)


## 마당 소품 (가까이: _sync_yard가 모양마다 MultiMesh · 멀리: PF_FAR_YARD의 멀리 모양을 건물 "far" 노드에 넣어 건물 멀리 묶음에 함께 구움 →
## 기본 확대(ppu 16)에서 그리기 횟수가 늘지 않는다). bake_far = 이 건물에 멀리 모양이 있을 때만 (없으면 far 노드가 비어 있어야 가까이가 남는다)
const PF_FAR_YARD := [PF_JARS, PF_FENCE, PF_CORDWOOD]


func _set_yard(far: Node3D, b: Building, bake_far: bool) -> void:
	var items := _yard_items(b)
	if items.is_empty():
		if _yard_xf.erase(b.id):
			_yard_dirty = true
		return
	_yard_xf[b.id] = items
	_yard_dirty = true
	if bake_far:
		for e: Array in items:
			if e[0] in PF_FAR_YARD and Art.has_far(e[0]):
				Art.instance(far, e[0], e[1], true)


## [모델, 건물 기준 Transform3D] — 건물 앞 = +z
func _yard_items(b: Building) -> Array:
	var out: Array = []
	var s := b.size()
	var m := 1.0 if b.id % 2 == 0 else -1.0
	if b.is_house():          # [배치] 길 쪽 앞마당 — 문 앞 골목 양옆에 꽃·꽃덤불 (sim/village_plan.gd GARDEN) + 옆벽에 단지·바구니
		out.append(["flowers" if b.id % 3 != 0 else "flowers_b", Transform3D(Basis(Vector3.UP, b.id * 0.9), Vector3(0.7 * m * s, 0, 1.45 * s))])
		out.append(["bush_flower", Transform3D(Basis(Vector3.UP, b.id * 1.3), Vector3(-0.85 * m * s, 0, 1.35 * s))])
		out.append([PF_JARS, Transform3D(Basis(Vector3.UP, 0.4 * m + b.id * 0.7), Vector3(1.25 * m * s, 0, 0.75 * s))])
	elif b.type == "창고":    # 창고 앞 양 귀퉁이에 단지·바구니
		out.append([PF_JARS, Transform3D(Basis(Vector3.UP, 0.3), Vector3(-1.45, 0, 1.25))])
		out.append([PF_JARS, Transform3D(Basis(Vector3.UP, 2.6), Vector3(1.35, 0, 1.2))])
	elif b.type == "나무꾼":  # 나뭇가지 줍는 터: 옆벽에 쌓은 장작
		out.append([PF_CORDWOOD, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(1.6, 0, 0.1))])
	elif b.type == "농장":    # 밀 숲 앞쪽에 울타리 (가운데는 드나드는 틈) + 앞 귀퉁이 옆으로 한 칸씩
		for x in [-1.55, -0.6, 0.6, 1.55]:
			out.append([PF_FENCE, Transform3D(Basis(Vector3.UP, (_hash(b.x + x, b.y, 91.0) - 0.5) * 0.12), Vector3(x, 0, 2.15))])
		for x in [-2.1, 2.1]:
			out.append([PF_FENCE, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0, 1.55))])
	return out


## 밀 숲 자람 단계 (보기만 — 시뮬 숫자는 그대로): 0 싹 · 1 자란 푸른 줄기 · 2 익은 금빛 이삭.
## 수확 시각(ready_at)이 없으면 1 (예전 field_green), 그 시각부터 2 (예전 field_ripe — 첫 수확 뒤에도 익은 채).
static func wheat_stage(b: Building, t: float) -> int:
	if b.ready_at < 0.0:
		return 1
	if t >= b.ready_at:
		return 2
	var grown := 1.0 - (b.ready_at - t) / Balance.GROW_FIRST
	return 0 if grown < WHEAT_SPROUT else 1


## 밀 숲: 밑동(선·그림자 그대로) + 윗부분(엷어지는 재질, 그림자는 쌍둥이가) — 가까이·멀리 같은 짜임
func _build_wheat(near: Node3D, far: Node3D, b: Building) -> void:
	var nm: String = WHEAT_MODELS[wheat_stage(b, v.t)]
	Art.instance(near, nm)
	if Art.has_far(nm):
		Art.instance(far, nm, Transform3D.IDENTITY, true)
	var top := nm + "_top"
	if not Art.exists(top):
		return
	for pair: Array in [[near, false], [far, true]]:
		var parent: Node3D = pair[0]
		var is_far: bool = pair[1]
		var m: Dictionary = Art.model_far(top) if is_far else Art.model(top)
		var mesh: Mesh = m["mesh"]
		if mesh == null:
			continue
		var vis := MeshInstance3D.new()             # 보이는 몸: 6칸 위로 엷어짐, 그림자 없음
		vis.mesh = mesh
		vis.material_override = wheat_fade_mat()
		vis.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(vis)
		var sh := MeshInstance3D.new()              # 그림자만: 줄기·이삭의 긴 그림자 (사용자 결정 — 해바라기처럼 그림자가 보임)
		sh.mesh = mesh
		sh.material_override = Art.flat_mat()
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		parent.add_child(sh)


static func wheat_fade_mat() -> ShaderMaterial:
	if _fade_mat == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://render/toon_fade.gdshader")
		Toon._light(m)
		m.set_shader_parameter("view_fill", Style.VIEW_FILL)
		_fade_mat = m
	return _fade_mat


## 화덕 불: 빛나는(그늘 없는) 재질 + 아궁이 앞 땅의 따뜻한 빛 웅덩이. 처음엔 꺼 둠 (_animate_live가 켬)
func _oven_glow(n: Node3D) -> Node3D:
	var g := Art.instance(n, OVEN_GLOW)
	if _oven_mat == null:
		_oven_mat = StandardMaterial3D.new()
		_oven_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_oven_mat.vertex_color_use_as_albedo = true
		_oven_mat.vertex_color_is_srgb = true
		_oven_mat.emission_enabled = true
		_oven_mat.emission = OVEN_GLOW_COLOR
		_oven_mat.emission_energy_multiplier = 0.6
	for c in g.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = _oven_mat
			(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pool := MeshInstance3D.new()
	var disc := PlaneMesh.new()
	disc.size = Vector2(1.4, 1.1)
	pool.mesh = disc
	pool.material_override = _glow_mat()
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pool.position = Vector3(0, 0.04, 0.75)
	g.add_child(pool)
	g.visible = false
	return g


## 일터가 지금 돌아가나 (일꾼이 있고 재료가 들어와 있다) — 맷돌이 돌고 화덕에 불이 켜지는 기준
static func working(b: Building) -> bool:
	if not b.built or b.worker < 0 or b.upgrade_to != "":
		return false
	for k: String in b.def().get("in", {}):
		if float(b.in_buf.get(k, 0.0)) < float(b.def()["in"][k]):
			return false
	return true


## 맷돌 윗돌 돌리기 · 화덕 불 켜고 끄기 (매 화면 — 값만 바꿈)
func _animate_live(dt: float) -> void:
	for id: int in _live.keys():
		var e: Dictionary = _live[id]
		var b := v.bld(id)
		var any_ok := false
		for key: String in e:
			var nd: Node3D = e[key]
			if nd == null or not is_instance_valid(nd):
				continue
			any_ok = true
			var on := b != null and working(b)
			if key == "stone":
				if on:
					nd.rotation.y = fposmod(nd.rotation.y + dt * QUERN_SPIN, TAU)
			else:
				nd.visible = on
				if on:
					nd.scale = Vector3.ONE * (0.94 + 0.06 * sin(_anim_t * 7.0 + id))
		if not any_ok:
			_live.erase(id)


## 건설 현장 — 몇 초마다 눈에 띄게 바뀌는 여덟 단계 (OPENING 3.1b v3.3 '늘 무언가 바뀌는 게 보이게'):
## 말뚝·줄 → 바닥 → 기둥 반 → 기둥·들보 (뼈대) → 벽 반 → 벽 → 서까래 → 지붕 (다 지으면 모델) + 도착한 판자·돌 더미
const SITE_STAGES := 8


static func site_stage(b: Building) -> int:
	var tm: float = Balance.B[b.site_type()]["time"]
	return int(clampf(b.prog / tm, 0.0, 0.999) * SITE_STAGES)


func _build_site(n: Node3D, b: Building) -> void:
	var st := site_stage(b) if b.is_site() else SITE_STAGES - 1
	if b.built:
		st = mini(st, 3)                     # 개축: 옛 집 둘레 비계(기둥·들보)만
	var s := b.size() * 0.85
	var d := s * 0.8
	var wall := Style.WOOD.lightened(0.12)
	if not b.built:
		for p: Vector2 in [Vector2(-s, -d), Vector2(s, -d), Vector2(-s, d), Vector2(s, d)]:     # 말뚝
			_box(n, Vector3(0.08, 0.3, 0.08), Vector3(p.x, 0.15, p.y), Style.WOOD)
		for e: Array in [[Vector3(s * 2.0, 0.03, 0.03), Vector3(0, 0.26, -d)], [Vector3(s * 2.0, 0.03, 0.03), Vector3(0, 0.26, d)],
				[Vector3(0.03, 0.03, d * 2.0), Vector3(-s, 0.26, 0)], [Vector3(0.03, 0.03, d * 2.0), Vector3(s, 0.26, 0)]]:     # 줄
			_box(n, e[0], e[1], Color("e8dcc0"))
		if b.site_type() == "농장":                                                      # 밭: 고랑이 한 줄씩 늘고 마지막에 울타리
			var rows := st + 1
			for i in rows:
				var z := -d + (d * 2.0) * (float(i) + 0.5) / float(SITE_STAGES)
				_box(n, Vector3(s * 1.9, 0.07, d * 2.0 / float(SITE_STAGES) * 0.55), Vector3(0, 0.05, z), Color("4f3420"))
			if st >= SITE_STAGES - 2:
				for p: Vector2 in [Vector2(-s, -d), Vector2(s, -d), Vector2(-s, d), Vector2(s, d), Vector2(0, -d), Vector2(0, d)]:
					_box(n, Vector3(0.1, 0.55, 0.1), Vector3(p.x, 0.27, p.y), Style.WOOD)
			return
		if st >= 1:
			_box(n, Vector3(s * 2.0, 0.1, d * 2.0), Vector3(0, 0.05, 0), Style.WOOD.lightened(0.25))
	var h := 1.5
	if st >= 2:
		var ph := h * (0.5 if st == 2 else 1.0)
		for p: Vector2 in [Vector2(-s, -d), Vector2(s, -d), Vector2(-s, d), Vector2(s, d)]:
			_box(n, Vector3(0.14, ph, 0.14), Vector3(p.x, ph * 0.5, p.y), Style.WOOD)
	if st >= 3:
		_box(n, Vector3(s * 2.0, 0.1, 0.12), Vector3(0, h, -d), Style.WOOD)
		_box(n, Vector3(s * 2.0, 0.1, 0.12), Vector3(0, h, d), Style.WOOD)
		_box(n, Vector3(0.12, 0.1, d * 2.0), Vector3(-s, h, 0), Style.WOOD)
		_box(n, Vector3(0.12, 0.1, d * 2.0), Vector3(s, h, 0), Style.WOOD)
	if st >= 4:
		var wh := h * (0.5 if st == 4 else 1.0)
		_box(n, Vector3(s * 2.0, wh, 0.1), Vector3(0, wh * 0.5, -d), wall)               # 뒷벽
		_box(n, Vector3(0.1, wh, d * 2.0), Vector3(-s, wh * 0.5, 0), wall)
		_box(n, Vector3(0.1, wh, d * 2.0), Vector3(s, wh * 0.5, 0), wall)
		_box(n, Vector3(s * 0.7, wh, 0.1), Vector3(-s * 0.65, wh * 0.5, d), wall)        # 앞벽 (문 자리 비움)
		_box(n, Vector3(s * 0.7, wh, 0.1), Vector3(s * 0.65, wh * 0.5, d), wall)
	if st >= 6:
		for side in [-1.0, 1.0]:                                                          # 서까래 / 지붕
			var mi := MeshInstance3D.new()
			var rw := sqrt(s * s + 0.8 * 0.8) + 0.25
			mi.mesh = ResidentModel.box_of(Vector3(rw, 0.1 if st == 6 else 0.22, d * 2.0 + 0.4))
			mi.material_override = Toon.mat(Style.WOOD if st == 6 else Style.THATCH)
			mi.position = Vector3(side * s * 0.5, h + 0.42, 0)
			mi.rotation.z = -side * atan2(0.8, s)
			n.add_child(mi)
	var np := mini(6, int(b.delivered["판자"]))
	if np > 0:                       # (E3) 판자 = 쪼갠 갈대·나뭇가지 → 나뭇가지 더미 (많을수록 크게)
		Art.instance(n, "flora/twig_pile_b", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.16 + 0.025 * np)), Vector3(s + 0.55, 0, 0.3)))
	for i in mini(6, int(b.delivered["돌"])):
		_box(n, Vector3(0.26, 0.22, 0.26), Vector3(-s - 0.4 - (i % 2) * 0.3, 0.11 + (i / 2) * 0.22, 0.4), Style.STONE)


## 건물 앞에 쌓인 산출물
func _build_piles(n0: Node3D, b: Building) -> void:
	var n := Node3D.new()              # (P1 3차) 짐 더미는 "piles" 아래 — 멀리 묶음에 들면 숨김
	n.name = "piles"
	n0.add_child(n)
	var i := 0
	for k in b.out:
		var cnt := mini(6, int(b.out[k]))
		var c: Color = Style.ITEM_COLORS.get(k, Style.WOOD)
		if k in TWIG_PILE_GOODS:
			if cnt > 0:
				Art.instance(n, "flora/twig_pile_a", Transform3D(Basis(Vector3.UP, i * 1.3).scaled(Vector3.ONE * (0.15 + 0.025 * cnt)), Vector3(b.size() + 0.55, 0, -0.6 + i * 0.4)))
			i += 1
			continue
		for j in cnt:
			_box(n, Vector3(0.28, 0.2, 0.28), Vector3(b.size() + 0.3 + (j % 2) * 0.3, 0.1 + (j / 2) * 0.2, -0.6 + i * 0.4), c)
		i += 1


# ───────────────────────── 나무·바위·소품 (art/models → MultiMesh) ─────────────────────────
## 시뮬레이션의 나무·그루터기·묘목·바위 + 화면 장식: 숲 가장자리(장식 나무 무리), 소품 무리, 물가 갈대·돌, 연잎, 선착장, 다리.
## 장식은 시뮬레이션에 없다 (베어지지 않음). 자리는 '병 처음 방향' 좌표에서 잡음(FastNoiseLite, 시드 고정)·해시로 정하고
## 지금 병 방향으로 돌린다 → 같은 병이면 늘 같은 자리, 병을 돌리면 땅과 함께 돈다. 물·강·소금·오솔길·건물·모닥불 근처는 비움.
const TREE_KINDS := ["tree_a", "tree_b", "tree_c", "tree_d"]
const FOREST_STEP := 2.2          # 장식 숲 격자 (칸) — 수관 지름 약 3.4칸이라 겹쳐서 숲 덩어리가 된다
const PROP_STEP := 2.6            # 소품 무리 격자
const VILLAGE_CLEAR := 5.0        # 마을(모닥불·건물)에서 이만큼은 장식 나무 없음, 그 바깥 FOREST_RAMP칸에 걸쳐 숲이 짙어짐
const FOREST_RAMP := 10.0
const PIER_MAX := 2
const PIER_REACH := 18.0          # 마을에서 이 거리 안의 호숫가에만 선착장

static var _noise: FastNoiseLite


static func _hash(x: float, z: float, k := 0.0) -> float:
	return fposmod(sin(x * 12.9898 + z * 78.233 + k * 37.719) * 43758.5453, 1.0)


## 데이터가 돈 횟수 — 소형 병(JarWater)은 병을 돌리면 데이터가 돌고, 넓은 세상(WorldWater)은 데이터 대신 병 노드가 돈다 (6단계)
func _data_rot() -> int:
	return 0 if v.water is WorldWater else posmod(v.water.rot, 4)


## 병 처음 방향 → 지금 방향 ((x, y) → (−y, x)를 rot번), 그 반대
func _to_now(p: Vector2) -> Vector2:
	var q := p
	for i in _data_rot():
		q = Vector2(-q.y, q.x)
	return q


func _to_orig(p: Vector2) -> Vector2:
	var q := p
	for i in _data_rot():
		q = Vector2(q.y, -q.x)
	return q


## 숲 짙기 0(빈 풀밭) ~ 1(깊은 숲) — 지금 좌표 p. 잡음은 처음 방향 좌표로 읽음.
static func _forest_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 20261106
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 0.075
		_noise.fractal_octaves = 2
	return _noise


func forest_at(p: Vector2) -> float:
	_forest_noise()
	var o := _to_orig(p)
	var n := _noise.get_noise_2d(o.x, o.y) * 0.5 + 0.5
	var dv := p.distance_to(v.fire)
	for b in v.buildings:
		dv = minf(dv, p.distance_to(Vector2(b.x, b.y)) - b.size())
	if v.water is WorldWater:
		# (6단계) 넓은 세상: 숲 = 세상 숲 무리(ww.forests — 지도·시뮬레이션 나무와 같은 자리) + 잡음 숲 (화면 장식).
		# 마을에서 멀수록 짙어지는 소형 병 규칙을 쓰면 마을 둘레(view_r)에 둥근 숲 띠가 생긴다 → 잡음만, 마을 곁만 비움.
		return _world_forest(p, n, _wf) * smoothstep(VILLAGE_CLEAR, VILLAGE_CLEAR + 6.0, dv)
	var edge := smoothstep(VILLAGE_CLEAR, VILLAGE_CLEAR + FOREST_RAMP, dv)
	return clampf((n + edge * 0.65 - 0.66) * 3.0, 0.0, 1.0)


## 넓은 세상의 숲 짙기 = 잡음 숲 + 세상 숲 무리 (가장자리는 잡음으로 들쭉날쭉)
const WORLD_NOISE_FOREST := 0.6   # 잡음이 이보다 높으면 숲 (소형 병보다 듬성듬성 — 빈 풀밭이 넓게)


func _world_forest(p: Vector2, n: float, list: Array[Dictionary]) -> float:
	var g := clampf((n - WORLD_NOISE_FOREST) * 3.0, 0.0, 1.0)
	for f: Dictionary in list:
		var r: float = f["r"] * (1.0 + 0.6 * n)
		var d := p.distance_to(Vector2(f["x"], f["y"]))
		g = maxf(g, clampf((r - d) / 2.5, 0.0, 1.0) * (0.6 + 0.5 * float(f["dens"])))
	return g


## 장식 격자 (처음 방향 좌표) — 마을 중심 v.center 둘레 v.view_r (6단계: 소형 병은 (0, 0) 둘레 32칸 그대로)
func _grid_range(step: float) -> Rect2i:
	var n := int(v.view_r / step) + 1
	var c := _to_orig(v.center) / step
	var g0 := Vector2i(roundi(c.x), roundi(c.y))
	return Rect2i(g0.x - n, g0.y - n, 2 * n + 1, 2 * n + 1)


## 땅 위 장식을 놓아도 되는 곳인가 (지금 좌표)
func _prop_ok(x: float, z: float, clear_r: float) -> bool:
	var w := v.water
	if not w.inside(x, z, JarTerrain.R - JarTerrain.R_EDGE + 1.2):     # (6단계: 소형 병·넓은 세상 같은 함수)
		return false
	if Vector2(x - v.center.x, z - v.center.y).length() > v.view_r + 2.0:
		return false
	if w.has_fog() and not w.revealed(x, z):        # 안개 속에는 장식을 놓지 않는다 (안개 위로 나무가 삐죽 나오지 않게)
		return false
	var k := w.idx(x, z)
	if w.is_lake(k) or w.is_river(k) or w.depth(k) > 0.002 or w.salt_k(k) > 0.0015:
		return false
	if terrain._path_at(k) > 5.0:
		return false
	if GreatTrees.blocks(w, x, z, clear_r):          # 큰 나무 다섯의 줄기 둘레
		return false
	if Vector2(x - v.fire.x, z - v.fire.y).length() < 2.5 + clear_r:
		return false
	if Vector2(x - v.altar_pos.x, z - v.altar_pos.y).length() < Village.ALTAR_CLEAR + clear_r:     # 제단 돌 단 (아직 없어도 그 자리는 비움)
		return false
	for b in v.buildings:
		var rr: float = b.size() * BUILDING_SCALE * (2.4 if b.type == "농장" else 1.9) + clear_r
		if Vector2(x - b.x, z - b.y).length() < rr:
			return false
	return true


func _add(groups: Dictionary, key: String, xf: Transform3D) -> void:
	if not groups.has(key):
		groups[key] = [] as Array[Transform3D]
	(groups[key] as Array[Transform3D]).append(xf)


func _put(groups: Dictionary, key: String, x: float, z: float, s: float, yaw: float, dy := 0.0) -> void:
	_add(groups, key, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(x, gy(x, z) + dy, z)))


func _flush(parent: Node3D, groups: Dictionary, no_shadow: Array = []) -> void:
	if _batches.has(parent):
		(_batches[parent] as FloraBatch).set_groups(groups, no_shadow)
		_flora_lod()
		return
	for c in parent.get_children():
		c.queue_free()
	for k: String in groups:
		Art.multi(parent, k, groups[k], not (k in no_shadow))


func _sync_trees() -> void:
	var n_tree := 0
	var n_stump := 0
	for tr: Dictionary in v.trees:
		if tr["s"] == "tree":
			n_tree += 1
		elif tr["s"] == "stump":
			n_stump += 1
	season = FloraLook.season_of(v)
	var key := "%d|%d|%d|%d|%s" % [v.trees.size(), n_tree, n_stump, v.water.rot, season]
	if key == _tree_key:
		return
	_tree_key = key
	# (E3-3 소인의 세상) 나무 = 꽃숲 덩이 · 벤 자리 = 나뭇가지 더미 · 묘목 = 클로버·풀 싹 (view/flora_look.gd)
	var groups := {}
	n_flora = 0
	for tr: Dictionary in v.trees:
		var x: float = tr["x"]
		var z: float = tr["y"]
		var h := _hash(x, z)
		var yaw := _hash(z, x, 1.0) * TAU
		var c: Array
		match String(tr["s"]):
			"tree":
				var o := _to_orig(Vector2(x, z))
				c = FloraLook.clump(season, _hash(o.x, o.y, 11.0), _hash(o.y, o.x, 12.0))
				n_flora += 1
			"stump":
				c = FloraLook.twig(h)
			_:
				c = FloraLook.sprout(h)
		_put(groups, c[0], x, z, float(c[1]) * TREE_SCALE, yaw)
	_flush(_trees, groups, FloraLook.NO_SHADOW)


func _sync_rocks() -> void:
	var key := ""
	for r: Dictionary in v.rocks:
		key += "%d,%.1f,%.1f;" % [int(r["amt"]), float(r["x"]), float(r["y"])]     # 자리도 (핀셋으로 옮긴 바위 — B6)
	key += str(v.water.rot)
	if key == _rock_key:
		return
	_rock_key = key
	var groups := {}
	var ores := {}                       # 광맥 돌의 바위 (SHOP 2.4) — 돌 색으로 (Style.ORE: 회색 돌 · 하양 소금 · 붉은 철 · 검정 석탄)
	for r: Dictionary in v.rocks:
		var amt: int = r["amt"]
		if amt <= 0:
			continue
		var x: float = r["x"]
		var z: float = r["y"]
		var k := minf(0.8 + amt / 25.0, 2.4)
		var ore := String(r.get("ore", ""))
		var g: Dictionary = groups
		if ore != "":
			if not ores.has(ore):
				ores[ore] = {}
			g = ores[ore]
		_put(g, "rocks", x, z, k, _hash(x, z) * TAU, -0.08)
		_put(g, "rock_small", x + 1.1 * k, z + 0.5 * k, k * 0.8, _hash(z, x) * TAU, -0.04)
	_flush(_rocks, groups)
	for ore: String in ores:
		var node := _node(_rocks)
		var og: Dictionary = ores[ore]
		for gk: String in og:
			Art.multi(node, gk, og[gk])
		var mat := Toon.mat(Style.ORE.get(ore, Style.ORE["돌"]))
		for c in node.get_children():         # 몸만 돌 색 (선은 그대로) — Art.multi는 몸 · 선 순서로 더한다
			var mmi := c as MultiMeshInstance3D
			if mmi != null and mmi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				mmi.material_override = mat


## 화면 장식 전부 (장식 숲 · 소품 무리 · 물가 · 집 둘레 덤불 · 선착장 · 다리). 건물이 늘거나 병을 돌리거나 6시간마다 다시.
## (6단계) 넓은 세상: 마을 둘레(view_r 40칸)는 키트를 놓을 때 이미 안개가 걷혀 있어(REVEAL_KIT 44칸) 안개와 상관없다.
## 그 바깥 숲(_sync_far)은 안개가 걷힐 때 다시 — 다만 FAR_REDECOR초에 한 번까지 (탐험가가 걸을 때마다 다시 놓지 않게).
const FAR_REDECOR := 6.0
const FAR_MAX := 200.0            # 이 반지름 밖의 숲은 지도에만 (멀리 축소하면 어차피 점)


func _sync_props() -> void:
	if v.water is WorldWater:
		_sync_far()
	var key := "%d|%d|%d|%s" % [v.buildings.size(), v.water.rot, int(v.t / 21600.0), season]
	if key == _prop_key:
		return
	_prop_key = key
	var t0 := Time.get_ticks_usec()
	if v.water is WorldWater:
		_wf.clear()
		for f: Dictionary in (v.water as WorldWater).forests:
			if Vector2(f["x"], f["y"]).distance_to(v.center) < v.view_r + float(f["r"]) * 1.4 + 3.0:
				_wf.append(f)
	var groups := {}
	var sim_pts: Array[Vector2] = []
	for tr: Dictionary in v.trees:
		sim_pts.append(Vector2(tr["x"], tr["y"]))
	for r: Dictionary in v.rocks:
		sim_pts.append(Vector2(r["x"], r["y"]))
	_decor_forest(groups, sim_pts)
	_decor_clusters(groups)
	_lilies.clear()
	_decor_water(groups)
	_decor_yards(groups)
	_decor_crossings(groups)
	_flush(_props, groups, ["tuft", "lily", "lotus", "reeds", "flowers", "flowers_b", "flora/fallen_leaf_dry"] + FloraLook.NO_SHADOW)
	_sync_lilies(true)
	decor_ms = (Time.get_ticks_usec() - t0) / 1000.0


## 숲 가장자리: 잡음이 높은 곳에 나무 무리 (마을 가까이는 빈 풀밭)
func _decor_forest(groups: Dictionary, sim_pts: Array[Vector2]) -> void:
	var g := _grid_range(FOREST_STEP)
	# 시뮬레이션 나무·바위 곁은 비움 — 격자 칸(4칸)으로 나눠 두고 둘레만 본다 (넓은 세상은 나무가 수백 그루)
	var near_map := {}
	for q in sim_pts:
		var c := Vector2i(floori(q.x / 2.0), floori(q.y / 2.0))
		if not near_map.has(c):
			near_map[c] = [] as Array[Vector2]
		(near_map[c] as Array[Vector2]).append(q)
	n_decor_trees = 0
	for gj in range(g.position.y, g.end.y):
		for gi in range(g.position.x, g.end.x):
			var p0 := Vector2(gi + _hash(gi, gj, 1.0) * 0.8 - 0.4, gj + _hash(gi, gj, 2.0) * 0.8 - 0.4) * FOREST_STEP
			var p := _to_now(p0)
			var f := forest_at(p)
			if f <= 0.0 or _hash(gi, gj, 3.0) > 0.25 + 0.75 * f:
				continue
			if not _prop_ok(p.x, p.y, 1.4):
				continue
			var near := false
			var pc := Vector2i(floori(p.x / 2.0), floori(p.y / 2.0))
			for dj in range(-1, 2):
				for di in range(-1, 2):
					for q: Vector2 in near_map.get(pc + Vector2i(di, dj), []):
						if q.distance_squared_to(p) < 4.0:
							near = true
			if near:
				continue
			var c := FloraLook.clump(season, _hash(gi, gj, 4.0), _hash(gi, gj, 5.0))
			_put(groups, c[0], p.x, p.y, float(c[1]) * TREE_SCALE, _hash(gi, gj, 6.0) * TAU)
			n_decor_trees += 1


## 소품 무리: 숲 가장자리엔 덤불·거대한 고사리·버섯·이끼 둔덕·돌·나뭇가지 더미·떨어진 큰 잎, 빈 풀밭엔 드문드문 클로버·풀 포기·꽃 덤불
## (2026-11-08) 숲 가장자리에 polyfork 돌무더기·이끼 둔덕·고사리
## (2026-11-08 "이끼, 고사리 크기가 어때야 하는지 알지?") 진짜 크기 (주민 5cm = 1칸, GAME_DESIGN 3.0):
##   풀·꽃·고사리·이끼·클로버는 진짜 크기 모델 × FloraLook.base_scale (K·√키 — 5칸 넘는 것만 줄임) — 큰 나무 자리 꽃숲과 같은 규칙.
##   거대한 고사리(진짜 30~60cm → 화면 약 6~8칸)는 숲 가장자리에만, 한 포기씩, 건물에서 떨어져 (빈 풀밭·마당엔 두지 않음).
##   옛 사람 크기 소품 모델(build_nature)은 CLUTTER_SCALE로 진짜 크기에 맞춤.
const FRINGE := ["bush", "bush_b", PF_MOSS, PF_FERN, "mushrooms", "rocks", "flora/twig_pile_a", "flora/fallen_leaf_dry", "bush_flower", PF_MOSS, PF_CAIRN, "bush_berry"]
const OPEN := ["flora/clover_a", "flora/clover_a", "tuft", "tuft", "flowers", "rock_small", "bush_flower", "mushrooms", "flowers_b", "rock_small", "bush_b", "tuft"]
## 한 자리에 하나만 (나머지는 1~3포기 무리)
const CLUTTER_ONE := ["flora/twig_pile_a", "flora/fallen_leaf_dry", "rocks", "rocks_b", PF_CAIRN, PF_MOSS, PF_FERN, "flora/clover_a"]
## 옛 사람 크기 모델 → 진짜 크기 배율 (모델 키 × 배율 = 화면 칸, 무리마다 ×0.75~1.25):
##   덤불(작은 잎 풀 포기, 진짜 5~10cm) 0.64~0.86 → 1.1~1.5 · 버섯(3~10cm) 0.61 → 1.1 · 풀 포기(마을의 밟힌 풀 5~8cm) 0.4 → 1.2
##   작은 들꽃 포기(5~15cm) 0.55 → 1.7. 돌(1.07 = 5cm 돌, 주민에겐 바위)·조약돌(0.59)은 그대로.
## 진짜 크기 모델에 곱하는 몫: 마을 빈터의 클로버는 밟히고 깎인 낮은 포기 (진짜 10~20cm → 화면 약 2칸, 폭 2.6)
const CLUTTER_SCALE := {"bush": 1.7, "bush_b": 1.7, "bush_flower": 1.7, "bush_berry": 1.7, "mushrooms": 1.8, "tuft": 3.0,
	"flowers": 3.0, "flowers_b": 3.0, "flora/clover_a": 0.5}


## 땅 위 잔것 하나의 기본 배율 (무리마다 흔들기 전)
static func clutter_scale(kind: String) -> float:
	var s := float(CLUTTER_SCALE.get(kind, 1.0))
	if kind.begins_with("flora/") or kind in [PF_FERN, PF_MOSS]:
		s *= FloraLook.base_scale(kind)
	return s


func _decor_clusters(groups: Dictionary) -> void:
	var g := _grid_range(PROP_STEP)
	for gj in range(g.position.y, g.end.y):
		for gi in range(g.position.x, g.end.x):
			var p0 := Vector2(gi + 0.2 + 0.6 * _hash(gi, gj, 4.0), gj + 0.2 + 0.6 * _hash(gi, gj, 5.0)) * PROP_STEP
			var c := _to_now(p0)
			var f := forest_at(c)
			var h0 := _hash(gi, gj, 3.0)
			var fringe := f > 0.05 and f < 0.9
			if f >= 0.9:
				if h0 > 0.15:
					continue
			elif h0 > (0.6 if fringe else 0.22):
				continue
			var table: Array = FRINGE if fringe or f >= 0.9 else OPEN
			var kind: String = table[int(_hash(gi, gj, 6.0) * table.size()) % table.size()]
			if kind == PF_FERN and not _prop_ok(c.x, c.y, FERN_CLEAR):
				continue                    # 거대한 고사리 잎이 집·길·모닥불 위로 덮이지 않게
			var cnt := 1 if kind in CLUTTER_ONE else 1 + int(_hash(gi, gj, 7.0) * 3.0)
			for i in cnt:
				var a := _hash(gi, gj, 10.0 + i) * TAU
				var d := (0.35 + 0.8 * _hash(gi, gj, 20.0 + i)) if i > 0 else 0.0
				var x := c.x + cos(a) * d
				var z := c.y + sin(a) * d
				if not _prop_ok(x, z, 0.3):
					continue
				var jig := (0.85 + 0.3 * _hash(gi, gj, 30.0 + i)) if kind == PF_FERN else (0.75 + 0.5 * _hash(gi, gj, 30.0 + i))
				var s := jig * clutter_scale(kind)
				var k2 := kind
				if i > 0 and kind == "bush" and _hash(gi, gj, 40.0 + i) < 0.4:
					k2 = "tuft"
					s *= clutter_scale("tuft") / clutter_scale("bush")
				_put(groups, k2, x, z, s, a * 3.0)
			# 흩어진 풀 포기 (빈 풀밭에 아주 드문드문)
			if _hash(gi, gj, 50.0) < 0.3:
				var x := c.x + (_hash(gi, gj, 51.0) - 0.5) * PROP_STEP
				var z := c.y + (_hash(gi, gj, 52.0) - 0.5) * PROP_STEP
				if _prop_ok(x, z, 0.0):
					_put(groups, "tuft", x, z, clutter_scale("tuft") * (0.8 + 0.4 * _hash(gi, gj, 53.0)), _hash(x, z) * TAU)


## 물가: 호숫가 칸을 따라 이끼 돌·갈대, 수면에 연잎·연꽃 (기준 그림)
func _decor_water(groups: Dictionary) -> void:
	var w := v.water
	var fog := w.has_fog()
	for k in w.village_cells(v.center, v.view_r * 1.3):     # (6단계) 소형 병은 모든 칸
		if not w.is_lake(k):
			continue
		var x := w.cx(k)
		var z := w.cy(k)
		if fog and not w.revealed(x, z):
			continue
		var out := Vector2.ZERO
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not w.is_lake(w.idx(x + d.x, z + d.y)):
				out += Vector2(d)
		var o := _to_orig(Vector2(x, z))
		var hh := _hash(o.x, o.y, 70.0)
		if out != Vector2.ZERO:
			var p := Vector2(x, z) + out.normalized() * 0.6
			if hh < 0.16:
				_put(groups, "rocks" if hh < 0.05 else "rock_small", p.x, p.y, 0.45 + hh * 2.0, hh * 40.0, -0.08)
			elif hh < 0.3:
				_put(groups, "reeds", p.x, p.y, 0.9 + hh, hh * 50.0)
		elif w.depth(k) > 0.03 and hh > 0.9:
			_lilies.append(["lotus" if hh > 0.975 else "lily", k, x, z, hh * 50.0, LILY_SCALE * (0.85 + 1.5 * (hh - 0.9))])


## 수련·연꽃을 지금 수면에 띄운다 (장식은 6시간마다 다시 놓지만 ×60에선 그 사이 수면이 오르내려 잎이 물에 잠겨
## 테두리만 점선처럼 보였다 — 1초마다 높이를 보고 달라졌으면 이것만 다시). 물이 빠진 칸은 숨김.
const LILY_SCALE := 0.8
const LILY_LIFT := 0.035


func _sync_lilies(force: bool) -> void:
	var w := v.water
	var ys := PackedFloat32Array()
	ys.resize(_lilies.size())
	var changed := force or _lily_y.size() != _lilies.size()
	for i in _lilies.size():
		var k: int = _lilies[i][1]
		var d := w.depth(k)
		var y := (w.ground(k) + d) * JarTerrain.HS - JarTerrain.WATER_SINK + LILY_LIFT if d > JarWater.LAKE_DEPTH else -1.0e9
		ys[i] = y
		if not changed and absf(y - _lily_y[i]) > 0.004:
			changed = true
	if not changed:
		return
	_lily_y = ys
	var groups := {}
	for i in _lilies.size():
		if ys[i] < -1.0e8:
			continue
		var it: Array = _lilies[i]
		_add(groups, it[0], Transform3D(Basis(Vector3.UP, it[4]).scaled(Vector3.ONE * float(it[5])), Vector3(it[2], ys[i], it[3])))
	_flush(_lily_node, groups, ["lily", "lotus"])


## 집 둘레 덤불 (앞쪽 양옆)
func _decor_yards(groups: Dictionary) -> void:
	for b in v.buildings:
		if not b.built or b.type in ["농장", "소금밭", "우물", "채석장"]:
			continue
		var base := deg_to_rad(JarCamera.BASE_YAW_DEG)
		for i in 3:
			var hb := _hash(b.x + i, b.y, 80.0)
			if hb < 0.3:
				continue
			var a := base + PI * 0.5 + (i - 1) * 1.15 + hb * 0.4
			var r := b.size() * BUILDING_SCALE * 1.45
			var x := b.x + sin(a) * r
			var z := b.y + cos(a) * r
			_put(groups, "bush_flower" if hb > 0.8 else ("bush_b" if hb < 0.5 else "bush"), x, z, 0.65 + 0.4 * hb, hb * 9.0)


## 선착장 (마을 가까운 호숫가, 물 쪽으로) · 다리 (오솔길이 강을 건너는 곳)
func _decor_crossings(groups: Dictionary) -> void:
	var w := v.water
	var cells := w.village_cells(v.center, v.view_r * 1.3)     # (6단계) 소형 병은 모든 칸
	var cands: Array = []
	for k in cells:
		if w.is_lake(k):
			continue
		var x := w.cx(k)
		var z := w.cy(k)
		var dist := Vector2(x, z).distance_to(v.fire)
		if dist > PIER_REACH or w.salt_k(k) > 0.0015:
			continue
		# 물 쪽 방향: 1~3칸 안의 호수 칸
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ok := true
			for s in range(1, 4):
				if not w.is_lake(w.idx(x + d.x * s, z + d.y * s)):
					ok = false
					break
			if ok and w.depth(w.idx(x + d.x * 3, z + d.y * 3)) > 0.02:
				cands.append([dist, x, z, d])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var placed: Array[Vector2] = []
	for c: Array in cands:
		if placed.size() >= PIER_MAX:
			break
		var p := Vector2(c[1], c[2])
		var far := true
		for q in placed:
			if q.distance_to(p) < 10.0:
				far = false
		var near_bld := false
		for b in v.buildings:
			if p.distance_to(Vector2(b.x, b.y)) < b.size() * 1.6 + 0.8:
				near_bld = true
		if not far or near_bld:
			continue
		var d: Vector2i = c[3]
		var kw := w.idx(p.x + d.x, p.y + d.y)
		var lvl := (w.ground(kw) + w.depth(kw)) * JarTerrain.HS - JarTerrain.WATER_SINK
		var y := maxf(lvl + 0.04, gy(p.x, p.y) - 0.2)
		var dir := Vector3(d.x, 0, d.y)
		var origin := Vector3(p.x, y, p.y) - dir * 0.35
		_add(groups, "pier", Transform3D(Basis(Vector3.UP, atan2(-dir.z, dir.x)), origin))
		placed.append(p)
	n_piers = placed.size()
	# (E3-6 GD 3.0 물가 표) 건너는 자리: 오솔길이 짙은 강 칸 — 좁은 개울은 징검돌, 넓은 물은 갈대 다리 (하나)
	var rc: Array = []
	for k in cells:
		if w.is_river(k) and terrain._path_at(k) > CROSS_PATH:
			rc.append([terrain._path_at(k), k])
	rc.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	crossings.clear()
	n_bridges = 0
	n_stones = 0
	for e: Array in rc:
		if crossings.size() >= CROSS_MAX:
			break
		var k: int = e[1]
		var x := w.cx(k)
		var z := w.cy(k)
		var far := true
		for c: Dictionary in crossings:
			if (c["c"] as Vector2).distance_to(Vector2(x, z)) < CROSS_APART:
				far = false
		if not far:
			continue
		var along_x := w.is_river(w.idx(x + 1, z)) or w.is_river(w.idx(x - 1, z))
		var u := Vector2(0, 1) if along_x else Vector2(1, 0)       # 건너는 방향 (강을 가로질러)
		var width := river_width(w, Vector2(x, z), u)
		var stones := width <= STONES_MAX_W
		if not stones and n_bridges > 0:
			continue
		var rot := Basis(Vector3.UP, PI / 2.0 if along_x else 0.0)   # 모델은 x 방향으로 걸침 → 강이 x로 흐르면 90° 돌림
		if stones:
			var lvl := (w.ground(k) + w.depth(k)) * JarTerrain.HS - JarTerrain.WATER_SINK
			var sx := clampf((width + 1.4) / 3.6, 0.8, 1.35)
			var y := lvl - 0.1
			_add(groups, "bridge_stones", Transform3D(rot * Basis.from_scale(Vector3(sx, STONE_TALL, STONE_WIDE)), Vector3(x, y, z)))
			crossings.append({"kind": "stones", "c": Vector2(x, z), "u": u, "half": 1.8 * sx, "y": y + STONE_TOP, "step": 0.6 * sx})
			n_stones += 1
		else:
			var y := maxf(gy(x + u.x * 1.9, z + u.y * 1.9), gy(x - u.x * 1.9, z - u.y * 1.9)) - 0.15
			_add(groups, "bridge", Transform3D(rot, Vector3(x, y, z)))
			crossings.append({"kind": "bridge", "c": Vector2(x, z), "u": u, "half": 1.95, "y": y})
			n_bridges += 1


const CROSS_PATH := 4.0         # 이만큼 짙은 오솔길이 강을 건너는 칸
const CROSS_MAX := 3            # 건너는 자리 (다리 하나 + 징검돌)
const CROSS_APART := 8.0
const STONES_MAX_W := 3         # 물 칸 폭이 이 이하면 징검돌 (작은 개울)
const STONE_TOP := 0.33         # 징검돌 윗면 (모델 원점 위, 높이 배율 STONE_TALL 뒤)
const STONE_TALL := 1.4          # 징검돌을 소인에게 맞게 키움 (높이 · 건너는 방향에 직각인 너비)
const STONE_WIDE := 1.6
const HOP_H := 0.22             # 돌에서 돌로 폴짝 (화면만)


## 강 폭 (칸): 가운데 칸에서 건너는 방향 양쪽으로 물 칸을 셈
static func river_width(w: JarWater, c: Vector2, u: Vector2) -> int:
	var n := 1
	for sg: float in [1.0, -1.0]:
		for i in range(1, 8):
			var q := c + u * sg * float(i)
			if not w.inside(q.x, q.y) or w.depth(w.idx(q.x, q.y)) <= Balance.WADE_DEPTH:
				break
			n += 1
	return n


## (E3-6) 건너는 자리 위의 높이 (징검돌 = 돌에서 돌로 폴짝 · 다리 = 갈대 다발 위). 자리 밖이면 −INF
func crossing_y(x: float, z: float) -> float:
	for c: Dictionary in crossings:
		var d := Vector2(x, z) - (c["c"] as Vector2)
		var u: Vector2 = c["u"]
		var t := d.dot(u)
		var half := float(c["half"])
		if absf(t) > half or absf(d.dot(Vector2(-u.y, u.x))) > 0.7:
			continue
		if c["kind"] == "stones":
			var ph := (t + half) / float(c["step"])
			return float(c["y"]) + absf(sin(ph * PI)) * HOP_H
		return float(c["y"]) + 0.36 + 0.16 * cos(PI * t / (2.0 * half)) + 0.15
	return -INF


## (6단계) 마을 둘레(view_r) 밖의 세상 숲 무리 — 안개가 걷힌 곳만, 나무만 (소품·물가 장식 없음).
## 시뮬레이션 나무가 아니다 (마을 46칸 안의 숲 무리는 시뮬레이션 나무 + 장식, 그 밖은 장식 나무만).
func _sync_far() -> void:
	var ww := v.water as WorldWater
	var now := Time.get_ticks_msec() / 1000.0
	if (ww.fog_version == _far_key and season == _far_season) or now - _far_t < FAR_REDECOR:
		return
	_far_key = ww.fog_version
	_far_season = season
	_far_t = now
	var t0 := Time.get_ticks_usec()
	var nz := _forest_noise()
	var lim := v.view_r + 2.0
	var c := v.center
	var fl: Array[Dictionary] = []
	for f: Dictionary in ww.forests:
		if Vector2(f["x"], f["y"]).distance_to(c) < FAR_MAX + float(f["r"]) * 1.6:
			fl.append(f)
	var groups := {}
	n_far_trees = 0
	# 안개 칸(4칸)마다: 걷혔으면 그 안에 기준점이 있는 장식 숲 격자점들을 본다 (마을 둘레 장식과 같은 격자·해시)
	var fs := float(WorldWater.FOG)
	var q0 := Vector2i(clampi(floori((c.x - FAR_MAX + ww.rr) / fs), 0, ww.fn - 1), clampi(floori((c.y - FAR_MAX + ww.rr) / fs), 0, ww.fn - 1))
	var q1 := Vector2i(clampi(floori((c.x + FAR_MAX + ww.rr) / fs), 0, ww.fn - 1), clampi(floori((c.y + FAR_MAX + ww.rr) / fs), 0, ww.fn - 1))
	for qy in range(q0.y, q1.y + 1):
		for qx in range(q0.x, q1.x + 1):
			if ww.fog[qy * ww.fn + qx] == 0:
				continue
			var x0 := -ww.rr + qx * fs
			var y0 := -ww.rr + qy * fs
			if Vector2(x0 + fs * 0.5, y0 + fs * 0.5).distance_to(c) < lim - 4.0:
				continue
			for gj in range(ceili(y0 / FOREST_STEP), ceili((y0 + fs) / FOREST_STEP)):
				for gi in range(ceili(x0 / FOREST_STEP), ceili((x0 + fs) / FOREST_STEP)):
					var p := Vector2(gi + _hash(gi, gj, 1.0) * 0.8 - 0.4, gj + _hash(gi, gj, 2.0) * 0.8 - 0.4) * FOREST_STEP
					if p.distance_to(c) < lim or p.distance_to(c) > FAR_MAX or not ww.revealed(p.x, p.y):
						continue
					if _other_closer(p, c):
						continue
					var fd := _world_forest(p, nz.get_noise_2d(p.x, p.y) * 0.5 + 0.5, fl)
					if fd <= 0.0 or _hash(gi, gj, 3.0) > 0.25 + 0.75 * fd:
						continue
					if not ww.inside(p.x, p.y, 1.5):
						continue
					var k := ww.idx(p.x, p.y)
					if ww.depth(k) > 0.002 or ww.is_river(k) or ww.salt_k(k) > 0.0015 or GreatTrees.blocks(ww, p.x, p.y, 1.0):
						continue
					var fc := FloraLook.clump(season, _hash(gi, gj, 4.0), _hash(gi, gj, 5.0), true)
					_put(groups, fc[0], p.x, p.y, float(fc[1]) * TREE_SCALE, _hash(gi, gj, 6.0) * TAU)
					n_far_trees += 1
	_flush(_far, groups, FloraLook.NO_SHADOW)
	far_ms = (Time.get_ticks_usec() - t0) / 1000.0


## (넓은 세상 · 무리가 여럿) 먼 숲은 가장 가까운 무리의 화면이 맡는다 — 다른 무리 마을 둘레(장식 숲·건물)와 겹치지 않게
func _other_closer(p: Vector2, c: Vector2) -> bool:
	var d := p.distance_squared_to(c)
	for q: Village in v.peers:
		if q != v:
			var dq := p.distance_squared_to(q.center)
			if dq < d or dq < (q.view_r + 2.0) * (q.view_r + 2.0):
				return true
	return false


func _sync_manna() -> void:
	var key := ""
	for m: Dictionary in v.manna:
		key += "%d," % ceili(float(m["amt"]) / 10.0)
	if key == _manna_key:
		return
	_manna_key = key
	for c in _manna.get_children():
		c.queue_free()
	# 금빛 낟알 더미 (기본 확대에서 보이게 — 둥근 무더기: 바닥 고리 + 가운데 봉우리, 남은 양만큼)
	for m: Dictionary in v.manna:
		var x: float = m["x"]
		var z: float = m["y"]
		var cnt := mini(16, ceili(float(m["amt"]) / 8.0))
		var y0 := gy(x, z)
		for i in cnt:
			var layer := 0 if i < 8 else (1 if i < 13 else 2)
			var ring_i := i if layer == 0 else (i - 8 if layer == 1 else i - 13)
			var ring_n := 8 if layer == 0 else (5 if layer == 1 else 3)
			var rr := [0.62, 0.34, 0.1][layer] as float
			var a := TAU * ring_i / ring_n + layer * 0.5
			var px := x + cos(a) * rr
			var pz := z + sin(a) * rr
			_box(_manna, Vector3(0.42, 0.2, 0.42), Vector3(px, y0 + 0.1 + layer * 0.17, pz), MannaFx.GOLD if (i + layer) % 3 else MannaFx.GOLD_HI, a)


func _build_fire() -> void:
	_fire = Campfire.new()           # [모닥불] view/campfire.gd
	_fire.terrain = terrain
	add_child(_fire)
	_fire.position = Vector3(v.fire.x, gy(v.fire.x, v.fire.y), v.fire.y)
	# 제단 (깨달음 뒤 주민이 짓는다 — 그 전엔 비어 있음) · 하늘 낟알 연출
	altar_view = AltarView.new(v, terrain)
	add_child(altar_view)
	manna_fx = MannaFx.new(v, terrain)
	add_child(manna_fx)


func _animate_fire() -> void:
	if _fire == null:
		return
	_fire.visible = not hide_fire
	_fire.position = Vector3(v.fire.x, gy(v.fire.x, v.fire.y), v.fire.y)
	_fire.tick(get_process_delta_time() if is_inside_tree() else 0.0, v)   # [모닥불] 상태·일렁임·LOD (view/campfire.gd)
