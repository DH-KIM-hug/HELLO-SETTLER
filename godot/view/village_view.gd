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
var cut_shadows: CutoutShadows  # 종이 인형 주민의 발밑 그림자 (CutoutResident.enabled일 때만)
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
## (P1 4차) 가까이 건물 그림자 대역: 가까이 LOD에서 건물 본 모델(수천 삼각형)은 그림자를 드리우지 않고, 같은 자리의 멀리 모양
## (52~600 삼각형, 선·껍데기 없음)을 그림자 전용(SHADOWS_ONLY)으로 묶어 한 메시로 구워 드리운다 → 그림자 패스 삼각형 약 19만 → 약 1만,
## 그림자 그리기 건물마다 1번 → 1번 (양면 재질 하나). 보이는 모델은 그대로. 짝: 본 모델 노드에 SH_DST, 멀리 모양 노드에 SH_SRC 표시.
## 움직이는(떨어지는 중)·숨긴 건물은 묶음에서 빼고 제 본 모델이 그림자를 드리운다 (_far_moving 공유).
const SH_SRC := &"shadow_src"
const SH_DST := &"shadow_dst"
var bld_shadow_proxy := true    # false = 예전처럼 본 모델이 그림자 (비교 측정)
var _near_shadow: Node3D        # 그림자 전용 묶음 (가까이 LOD일 때만 보임)
var _shadow_items := {}         # 건물 id → [노드 변환, [[메시, 재질, 건물 기준 Transform3D]…]]
var _shadow_dirty := false
## (2D 그림 건물 — view/bld2d/bld2d.gd, RENDERING.md 확정 2026-11-08) 건물마다 그림 판 + 3D 모델은 그림자 대역
var _bld2d_on := false            # 지금 그림으로 그리는가 (Bld2D.enabled — 바뀌면 건물을 다시 만듦)
var _card_items := {}             # 건물 id → [[그림, 마을 기준 원점(올림 포함), k, flip]…] (멀리 묶음 · 접촉 그림자)
var _contact: MultiMeshInstance3D # 접촉 그림자 타원 (모든 건물 = 그리기 1번, 늘 보임)
var _contact_dirty := false
## (2D 그림책 꽃·소품 — view/flora2d, RENDERING.md 확정 2026-11-08) 건물 노드에 단 꽃·소품 그림 (짐 더미·짓는 터 더미·화분 집·찾은 물건):
## 건물 id → [[그림, 마을 기준 원점, k, flip]…] — 멀리 묶음(Flora2D.multi, 아틀라스마다 그리기 1번)·접촉 그림자에 함께
var _fcard_items := {}
var _fcontact: MultiMeshInstance3D
var no_pic2d := {}                # (2D) 그림이 없어 3D로 남은 바위·연잎 모양 (시험: 비어 있어야)
var _flora2d_on := false          # 지금 꽃·소품을 그림으로 그리는가 (Flora2D.enabled — 바뀌면 꽃숲·소품·건물을 다시)
const YARD_FLORA_2D := ["flowers", "flowers_b", "bush_flower"]   # 그림 건물: 마당 소품 중 꽃만 남김 (나머지는 그림에 들어 있음)
## (A27-c) 밀 숲 터 = 농장: 키 큰 밀 줄기 다섯 (art/src/build_buildings.py build_wheat_forest). 윗부분(_top, 모델 높이 6칸 위)은
## 엷어지는 재질(render/toon_fade.gdshader)로 — 그 아래 주민·길을 가리지 않게. 그림자는 그림자 전용 쌍둥이가 드리운다.
const WHEAT_MODELS := ["buildings/wheat_forest_sprout", "buildings/wheat_forest_green", "buildings/wheat_forest_ripe"]
const WHEAT_MIN_ALPHA := 0.45   # 윗부분이 가장 엷을 때 불투명도 (진짜 반투명 — 0.35는 풀밭 위 금빛 이삭이 너무 흐림, 2026-11-08)
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
var tremor_fx: TremorFx         # (A28b) 땅 흔들림 — 먼지·달그락·깨진 항아리 (view/tremor_fx.gd)
var fireflies: Fireflies        # (E3-17) 여름밤 반딧불이 (view/fireflies.gd)
var _props: Node3D
var _prop_key := ""
var _lily_node: Node3D          # 수련·연꽃 (따로 — 수면이 오르내리면 높이만 다시)
var _lilies: Array = []         # [모델, 칸, x, z, 돌림, 크기]
var _lily_y := PackedFloat32Array()   # 마지막으로 놓은 높이 (−1e9 = 숨김)
var _lily_t := 0.0
var _far: Node3D                # (6단계) 넓은 세상: 마을 둘레 밖, 안개가 걷힌 숲 무리 (ww.forests)
## (P1 성능) 꽃숲·소품·먼 숲 묶음 — 화면 자르기 + 멀리 덩이 (view/flora_batch.gd). 부모 노드 → FloraBatch
var _batches := {}
## (꽃 정보 카드 — docs/UI.md) 그린 꽃숲 덩이의 가벼운 기록, 층 노드 이름 ("_trees"·"_props"·"_far") → FloraPicks. 묶음을 다시 만들 때 새로
var flora_picks := {}
var _rec: FloraPicks              # 지금 채우는 기록 (_put이 누를 수 있는 모양만 적음) — 묶음 만들기 밖에서는 null
var _rec_sim := false
var flora_cull := true          # false = 화면 밖도 늘 그림 (캡처·시험)
var flora_force_near := false  # true = 늘 가까이 모양 (예전 그림과 비교하는 캡처용)
var _far_key := -1
var _far_season := ""
var _far_t := -1.0e9
var n_far_trees := 0
var far_ms := 0.0
var sync_prof := {}               # (성능 탐침) 마지막 sync의 단계별 ms — all · flora_lod · live, 점검한 화면이면 bld·trees·props·lilies·far(먼 숲을 다시 놓았으면)
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
var kitchen_view: KitchenView  # [부엌] 진딧물 목장·하늘의 큰 알·껍데기·씨앗 짜개 (view/kitchen_view.gd — E3-14)
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
var kids_view: KidsView         # [아이·아기] 놀이 몸짓·소품 · 요람 · 아장아장 (view/kids_view.gd — Q2-b)
var econ: BldEcon               # [보이는 살림 Q6] 짓는 터 자재·말뚝, 일터 앞 더미, 일하는 김, 막힘 풍선 (view/bld2d/bld_econ.gd — 2D 건물일 때만)
var staged := {}                # 주민 id → {"pos": Vector3, "rot": float, "anim": String, "vis": bool, "tilt": Vector2} (시뮬레이션 자리 대신)
var pose_over: Dictionary = {}       # (E1-0 사건 연출) 주민 id → {anim, face, up(고개 젖힘 라디안), side, arm: Vector2} — 자리는 시뮬레이션 그대로, 몸짓만 연출이
                                     #   (E1-1) hold: true = 두 팔로 안음 (종이 인형 안기 팔) · to: 주민 id = 그 사람 곁으로 다가가 안김 (화면 자리만, 1초에 걸쳐)
var stage_say: Dictionary = {}       # (E1-1) 화면 말풍선만 — 주민 id → [글, 기분, 남은 초]. 시뮬레이션(r.say)에 쓰지 않음 (staging.md R4)
var _stage_w: Dictionary = {}        # 'to' 다가감 정도 0~1
## (E1-1 조짐 — EVENTS_STAGING 1-1) 깨닫기 전, 경이(Village.wonder)가 찰수록 아이들이 자주 멈춰 서서 하늘 이야기를 한다 (화면만 — 경이를 읽기만)
const HINT_FROM := 0.3               # 경이가 WONDER_NEED의 이만큼부터
const HINT_EVERY := Vector2(40.0, 9.0)   # 조짐 사이 (현실 초): 경이가 막 찼을 때 → 가득
const HINT_SECS := 4.0               # 말풍선·멈춤 (현실 초)
const HINT_KIDS := [["저기 봐! 하늘이 반짝였어", "하늘이 이상해!"], ["방금 하늘이 움직였어!", "위에 뭐가 있나 봐…"], ["또 봤어! 저 위에!", "하늘이 우리를 봐!"]]
const HINT_ADULTS := ["애들이 자꾸 하늘을 봐", "요즘 하늘이 좀 이상하지?", "쉿, 바람이겠지"]
var hint_pose: Dictionary = {}       # 주민 id → {anim, left: 남은 초} (연출 몸짓이 없을 때만)
var hint_log: Array = []             # (시험) 띄운 조짐 [현실 시각, 주민 id, 글]
var _hint_t := 6.0
var _hint_n := 0
var _hint_clock := 0.0
var _hint_rng := RandomNumberGenerator.new()


func _init(village: Village, t: JarTerrain) -> void:
	v = village
	terrain = t


## 처음 한 번 모델을 모두 읽어 둠 (첫 등장 때 끊기지 않게)
const PRELOAD := ["cottage_a", "cottage_b", "cottage_c", "cottage_d", "hut", "house_timber", "house_timber_b", "house_stone", "house_stone_b", "storehouse", "forester", "quarry", "sawmill",
	"well", "windmill", "bakery", "saltpan", "buildings/wheat_forest_sprout", "buildings/wheat_forest_green", "buildings/wheat_forest_green_top", "buildings/wheat_forest_ripe", "buildings/wheat_forest_ripe_top", "woodpile", "chopblock", "planter", "pier", "bridge", "bridge_stones", "raft_reed", "boat_leaf", "mushroom_hut",
	"bush", "bush_b", "bush_flower", "bush_berry",
	"rocks", "rocks_b", "rock_small", "mushrooms", "flora/clover_a", "tuft", "flowers", "flowers_b", "lily", "lotus", "reeds", "altar",
	"campfire", "campfire_extra", "campfire_seat", PF_JARS, PF_FENCE, PF_CORDWOOD, PF_BENCH, PF_CAIRN, PF_MOSS, PF_FERN,
	PF_LITTER_A, PF_LITTER_B, PF_EGGSHELL, PF_STUMP, PF_MUSHROOMS, PF_HORSETAIL, PF_REEDS, PF_ACORN_BASIN, PF_POT_HOUSE,
	PF_QUERN, PF_OVEN, PF_GRANARY, PF_RETTING, PF_WEAVE_JIG, PF_RACK_HASA, PF_RACK_NET]
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
## (2026-11-08 polyfork 2차 — ROADMAP E3-17) Insect World 재료·숲 가장자리·물가 (진짜 크기, art/src/build_polyfork.py)
const PF_LITTER_A := "props/pf_litter_a"    # 떨어진 잔가지 + 마른 참나무 잎
const PF_LITTER_B := "props/pf_litter_b"    # 장미 꽃잎 + 해바라기씨 둘 + 단풍 씨앗 날개
const PF_EGGSHELL := "props/pf_eggshell"    # 반쪽 알껍데기
const PF_STUMP := "props/pf_stump"          # 이끼 낀 꺾인 줄기 밑동 (약 1.6칸)
const PF_MUSHROOMS := "props/pf_mushrooms"  # 버섯 무리 (옛 build_nature "mushrooms" 대신)
const PF_HORSETAIL := "props/pf_horsetail"  # 거대한 쇠뜨기 (진짜 약 50cm — FloraLook으로 약 7칸, 숲 가장자리에만)
const PF_REEDS := "props/pf_reeds"          # 물가 갈대 덤불 + 부들 (옛 "reeds" 대신)
const PF_ACORN_BASIN := "props/pf_acorn_basin"  # 도토리 깍정이 물그릇 (우물 곁)
const PF_POT_HOUSE := "props/pf_pot_house"  # 엎어 놓은 흙 화분 집 (마을 가장자리 랜드마크 — 지금은 장식만)
## 빵 사슬·실 일 마당 소품 (주민이 손수 지은 것 — 사람 키 1.7m → 1칸)
const PF_QUERN := "props/pf_quern"          # 갈판 맷돌 (맷돌간·방앗간)
const PF_OVEN := "props/pf_oven"            # 흙 화덕 (빵집)
const PF_GRANARY := "props/pf_granary"      # 다락 곡식 창고 (창고 곁 — 창고 모델은 그대로)
const PF_RETTING := "props/pf_retting"      # 줄기 불림 통 (방직소)
const PF_WEAVE_JIG := "props/pf_weave_jig"  # 엮기 틀 (방직소)
const PF_RACK_HASA := "props/pf_rack_hasa"  # 볏단 건조대 (맷돌간)
const PF_RACK_NET := "props/pf_rack_net"    # 그물 건조대 (방직소)
## 떨어진 물건 (E3-16 — sim/found_objects.gd): 종류(쓰임) → 모델
const FOUND_MODELS := {"button": "props/pf_found_table", "marble": "props/pf_found_marble", "cap": "props/pf_found_cap",
	"sugar": "props/pf_found_sugar", "match": "props/pf_found_match"}
const FOUND_SINK := {"button": 0.29}    # 찾은 채 놓인 단추: 잔가지 다리는 아직 없음 → 다리 높이만큼 땅에 묻어 단추만 보이게
const POT_HOUSE_ID := -1          # 장식 노드 id (건물 id와 겹치지 않게 음수 — 건물처럼 멀리 묶음에 함께 구움)
const FOUND_ID0 := -100


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
	kitchen_view = KitchenView.new(v, self)  # [부엌]
	add_child(kitchen_view)
	social = SocialStage.new(v, self)   # [마을의 삶]
	add_child(social)
	kids_view = KidsView.new(v, self)   # [아이·아기]
	add_child(kids_view)
	econ = BldEcon.new(v, self)         # [보이는 살림 Q6]
	add_child(econ)
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
	var s0 := Time.get_ticks_usec()
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
		var t0 := Time.get_ticks_usec()
		var f0 := far_ms
		_sync_buildings()
		var t1 := Time.get_ticks_usec()
		_sync_graves()
		_sync_trees()
		var t2 := Time.get_ticks_usec()
		_sync_rocks()
		_sync_manna()
		_sync_props()
		var t3 := Time.get_ticks_usec()
		_lily_t += 0.25
		if force or _lily_t >= 1.0:
			_lily_t = 0.0
			_sync_lilies(false)
		var t4 := Time.get_ticks_usec()
		sync_prof = {"force": force, "bld": (t1 - t0) / 1000.0, "trees": (t2 - t1) / 1000.0, "props": (t3 - t2) / 1000.0,
			"lilies": (t4 - t3) / 1000.0, "far": far_ms if far_ms != f0 else 0.0, "bp": bld_prof}
	else:
		sync_prof = {}
	var s1 := Time.get_ticks_usec()
	_flora_lod()
	var s2 := Time.get_ticks_usec()
	_animate_fire()
	_animate_live(dt)
	if econ != null:
		econ.sync(dt, not sync_prof.is_empty())     # [보이는 살림 Q6] 건물을 살핀 화면이면 더미도 바로
	var s3 := Time.get_ticks_usec()
	if altar_view != null:
		altar_view.sync(dt)
		manna_fx.sync(dt)
	if tremor_fx != null:
		tremor_fx.sync(dt)
		if _yard != null:
			_yard.position = tremor_fx.wobble()
	if fireflies != null:
		fireflies.sync(dt)
	sync_prof["frame"] = Engine.get_process_frames()
	sync_prof["all"] = (Time.get_ticks_usec() - s0) / 1000.0
	sync_prof["flora_lod"] = (s2 - s1) / 1000.0
	sync_prof["live"] = (s3 - s2) / 1000.0


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
	if not _far_job.is_empty():
		_far_step(FAR_BUDGET_MS)
	if not _far_bake.is_empty():
		_far_bake_step(FAR_BUDGET_MS)
	var t0 := Time.get_ticks_usec()
	_bld_lod()
	var t1 := Time.get_ticks_usec()
	if bld_batch and (bld_far or bld_shadow_proxy):
		_check_far_moving()
	lod_prof = {"frame": Engine.get_process_frames(), "bld_lod": (t1 - t0) / 1000.0, "far_moving": (Time.get_ticks_usec() - t1) / 1000.0}


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
	elif not bld_far and _shadow_dirty:
		_sync_near_shadow()           # 안에서 _apply_bld_lod
	else:
		for id in _blds:
			_apply_bld_lod(_blds[id])
	if _far_batch != null:
		_far_batch.visible = bld_far
	if _near_shadow != null:
		_near_shadow.visible = not bld_far
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
	for c: Node in n.get_children():
		if c.has_meta(&"pic"):
			(c as Node3D).visible = not batched        # 묶음에 든 건물의 그림은 멀리 묶음(아틀라스 MultiMesh)이 그림
	_set_near_shadows(near, not bld_far and _shadow_batched(n))


## (P1 4차) 본 모델(SH_DST 표시) 그림자 끄기/되돌리기 — off = 그림자 대역 묶음이 대신 드리움. 처음 설정은 메타 "cs0"에 둠
func _set_near_shadows(near: Node3D, off: bool) -> void:
	for c: Node in near.get_children():
		if not c.has_meta(SH_DST):
			continue
		var list: Array = c.find_children("*", "GeometryInstance3D", true, false)
		if c is GeometryInstance3D:
			list.append(c)
		for g: GeometryInstance3D in list:
			if not g.has_meta(&"cs0"):
				g.set_meta(&"cs0", g.cast_shadow)
			# 그림자 전용 쌍둥이(밀 숲 윗부분 — SHADOWS_ONLY)는 그림자를 끄면 '보이는' 불투명 메시가 되어 버린다 (cast_shadow OFF =
			# 그림자만 끄고 그림) → 엷어지는 윗부분을 온전히 덮고 먹선까지 생겼다. 이런 것은 숨기기로 (2026-11-08)
			if int(g.get_meta(&"cs0")) == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
				g.visible = not off
				continue
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if off else g.get_meta(&"cs0")


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
	if kids_view != null:
		kids_view.begin(dt, fast)   # [아이·아기] 놀이 소품 · 누가 놀이 속인가 (주민을 놓기 전)
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
	if kitchen_view != null:
		kitchen_view.sync(dt)       # [부엌] (주민 몸짓 뒤 — 굴리는 팔·목장지기)


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
	var cut := CutoutResident.enabled()
	fish_pair = fish_pairs(v.people)
	for r in v.people:
		seen[r.id] = true
		var m: ResidentModel = residents.get(r.id)
		var key := ResidentModel.look_key(r)      # 나이·대머리·흰머리 단계가 바뀌면 다시 만든다 (7단계)
		# (2026-11-08) 종이 인형 주민 미리 보기 — 설정이 바뀌면 그 자리에서 다시 만든다 (화면만)
		var fresh: bool = m == null or _res_key.get(r.id, -1) != key or (m is CutoutResident) != cut
		if fresh:
			if m != null:
				m.queue_free()
			m = CutoutResident.new() if cut else ResidentModel.new()
			add_child(m)
			m.setup_from(r)
			residents[r.id] = m
			_res_key[r.id] = key
		# 집 안에서 자는 사람·집 안의 아기는 보이지 않는다
		var hm := v.bld(r.home)
		var inside := hm != null and r.anim == "sleep" and Vector2(r.x - hm.x, r.y - hm.y).length() < 0.6
		var cut_baby := cut and r.is_baby()      # (2026-11-08 "아기가 없음") 종이 인형 아기는 부모 품·문 옆 요람에 (CutoutResident.place_babies)
		m.visible = not inside or cut_baby
		if not m.visible:
			continue
		var x := r.x
		var z := r.y
		if alpha < 1.0 and absf(r.x - r.px) + absf(r.y - r.py) < lerp_max:     # 순간이동(집 안·새로 태어남)은 보간하지 않음
			x = lerpf(r.px, r.x, alpha)
			z = lerpf(r.py, r.y, alpha)
		if not cut_baby:
			m.move_to(Vector3(x, gy(x, z), z), dt)     # 땅 빠르기를 재어 걸음 동작을 맞춤 (발 미끄러짐 없음)
		elif fresh:
			m.position = Vector3(x, gy(x, z), z)
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
		if kids_view != null and not fast:
			kids_view.pose(r, m, dt)    # [아이·아기] 놀이 속 아이: 화면 자리·폴짝 · 요람을 들여다보는 이웃
		var po: Dictionary = pose_over.get(r.id, {}) if not pose_over.is_empty() else hint_pose.get(r.id, {})
		if not po.is_empty():           # (E1-0) 연출이 몸짓·표정을 잠깐 정함 · (E1-1) 조짐: 멈춰 서서 하늘을 봄
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
	if cut:
		_place_babies()
		if kids_view != null:
			kids_view.babies(dt, fast)  # [아이·아기] 요람 그림 · 아장아장 (place_babies가 정한 자리 뒤에)
	_stage_after(dt)
	_wonder_hints(dt)
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
	if cut and cut_shadows == null:
		cut_shadows = CutoutShadows.new()
		add_child(cut_shadows)
	if cut_shadows != null:
		cut_shadows.visible = cut
		if cut:
			cut_shadows.refresh(residents)
	for id in _rafts.keys():
		if not seen.has(int(id) / 2):
			(_rafts[id] as Node3D).queue_free()
			_rafts.erase(id)


## (E1-1) 연출 몸짓 중 자리·팔을 건드리는 것 (아기 품기 뒤에 — place_babies가 안기 팔을 매번 다시 정하므로):
## hold = 두 팔로 안음 · to = 그 사람 곁으로 다가감 (화면 자리만 — 시뮬레이션 자리는 그대로). 화면 말풍선 시간도 여기서 줄임
func _stage_after(dt: float) -> void:
	for id: int in stage_say.keys():
		var s: Array = stage_say[id]
		s[2] = float(s[2]) - dt
		if float(s[2]) <= 0.0:
			stage_say.erase(id)
	if pose_over.is_empty():
		_stage_w.clear()
		return
	for id: int in pose_over:
		var po: Dictionary = pose_over[id]
		var m: ResidentModel = residents.get(id)
		if m == null or not m.visible:
			continue
		if po.has("to"):
			var tm: ResidentModel = residents.get(int(po["to"]))
			if tm != null and tm.visible:
				var w := minf(1.0, float(_stage_w.get(id, 0.0)) + (dt if dt > 0.0 else 1.0))
				_stage_w[id] = w
				var side := Vector3(cos(tm.rotation.y), 0.0, -sin(tm.rotation.y))      # 안는 사람의 옆 (앞에서 보면 오른쪽)
				var goal := tm.position + side * 0.3 * tm.scale.x
				goal.y = gy(goal.x, goal.z)
				m.position = m.position.lerp(goal, w * w * (3.0 - 2.0 * w))
				m.rotation.y = tm.rotation.y
		if bool(po.get("hold", false)) and m is CutoutResident:
			(m as CutoutResident).carry_baby = true
			(m as CutoutResident)._refresh_doll()


## (E1-1 조짐) 깨닫기 전 경이가 찰수록 아이들이 더 자주 하늘 이야기 (화면 말풍선 + 서 있던 아이는 잠깐 멈춤). 경이가 가득 차면 어른도 수군거림.
## 시뮬레이션은 읽기만 (v.wonder · aware) — 화면 난수(_hint_rng)만 씀
func _wonder_hints(dt: float) -> void:
	_hint_clock += dt
	for id: int in hint_pose.keys():
		var hp: Dictionary = hint_pose[id]
		hp["left"] = float(hp["left"]) - dt
		if float(hp["left"]) <= 0.0:
			hint_pose.erase(id)
	var k := v.wonder / Awakening.WONDER_NEED
	if v.aware or fast or k < HINT_FROM or not pose_over.is_empty():
		return
	_hint_t -= dt
	if _hint_t > 0.0:
		return
	_hint_t = hint_every(k) * _hint_rng.randf_range(0.75, 1.25)
	var kids: Array[Resident] = []
	var adults: Array[Resident] = []
	for r in Awakening.witnesses(v):
		if stage_say.has(r.id) or r.say_t > 0.0:
			continue
		if r.is_child():
			kids.append(r)
		elif r.is_adult():
			adults.append(r)
	_hint_n += 1
	var murmur := k >= 0.8 and not adults.is_empty() and (_hint_n % 3 == 0 or kids.is_empty())
	if kids.is_empty() and not murmur:
		return
	var who: Resident = adults[_hint_rng.randi() % adults.size()] if murmur else kids[_hint_rng.randi() % kids.size()]
	var text := ""
	if murmur:
		text = String(HINT_ADULTS[_hint_n % HINT_ADULTS.size()])
	else:
		var band: Array = HINT_KIDS[clampi(int((k - HINT_FROM) / ((1.0 - HINT_FROM) / 3.0)), 0, HINT_KIDS.size() - 1)]
		text = String(band[_hint_n % band.size()])
		hint_pose[who.id] = {"anim": "idle", "face": "surprised", "up": 0.6, "left": HINT_SECS}
	stage_say[who.id] = [text, "" if murmur else "cheer", HINT_SECS]
	hint_log.append([_hint_clock, who.id, text])


## 조짐 사이 (현실 초) — 경이 몫 k (HINT_FROM → 1)에 따라 HINT_EVERY.x → y
static func hint_every(k: float) -> float:
	var u := clampf((k - HINT_FROM) / (1.0 - HINT_FROM), 0.0, 1.0)
	return lerpf(HINT_EVERY.x, HINT_EVERY.y, u * u * (3.0 - 2.0 * u))


## 종이 인형 아기: 부모 품 · 문 옆 요람 · 부모 곁 걸음마 (화면만 — CutoutResident.place_babies). 요람·걸음마의 땅 높이는 여기서
func _place_babies() -> void:
	var placed := CutoutResident.place_babies(v, v.people, residents)
	for id: int in placed:
		var m: Node3D = residents.get(id)
		if m != null and String(placed[id]["mode"]) != "carried":
			m.position.y = gy(m.position.x, m.position.z) + (0.03 if String(placed[id]["mode"]) == "cradle" else 0.0)


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
	if _bld2d_on and Bld2D.has("grave"):        # (2D) 무덤 그림 — 아틀라스 MultiMesh 하나 (그리기 1번, 그림자 없음 그대로)
		var cards: Array = []
		for g: Dictionary in v.graves:
			var gx := float(g["x"])
			var gz := float(g["y"])
			cards.append(["grave", Vector3(gx, gy(gx, gz), gz), 0.9 + fposmod(float(g["id"]) * 0.37, 0.2), int(g["id"]) % 2 == 1])
		if not cards.is_empty():
			_graves.add_child(Bld2D.multi(cards))
		return
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
	var dp := int(b.delivered["판자"])
	var ds := int(b.delivered["돌"])
	if _bld2d_on:                    # (2D · Q6) 더미는 BldEcon이 따로 그린다 — 짐이 오갈 때마다 건물 노드(와 멀리 묶음)를 다시 만들지 않음
		dp = 0
		ds = 0
	else:
		for k in b.out:
			piles += "%s%d" % [k, mini(6, int(b.out[k]))]
	var stage := SITE_STAGES
	if b.is_site():
		stage = site_stage(b)
	var ripe := wheat_stage(b, v.t) if b.type == "농장" else 0
	# 자리·병 방향도 키에 (병을 돌리면 건물 자리가 돈다)
	var era := v.era if b.type == "나루터" else 0      # (E3-6) 나루터: 개척 시대는 갈대 뗏목, 그 뒤 잎 배
	return "%s|%s|%s|%d|%d,%d|%d|%s|%.2f,%.2f|%d|%d" % [b.type, b.built, b.upgrade_to, stage, dp, ds, ripe, piles, b.x, b.y, v.water.rot, era]


func _sync_buildings() -> void:
	var on := Bld2D.enabled()
	var fon := Flora2D.enabled()
	if fon != _flora2d_on:           # (2D 꽃·소품) 설정을 바꾸면 꽃숲·소품·바위·연잎·먼 숲·건물(짐 더미)을 다시
		_flora2d_on = fon
		_tree_key = ""
		_rock_key = ""
		_prop_key = ""
		_far_key = -1
		_far_t = -1.0e9
		_bld_key.clear()
		_fcard_items.clear()
		_yard_dirty = true
		_contact_dirty = true
	if on != _bld2d_on:              # 설정을 바꾸면 모든 건물·무덤을 다시
		_bld2d_on = on
		_bld_key.clear()
		_grave_key = ""
		_card_items.clear()
		_contact_dirty = true
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
		_n_rebuilt += 1
		if _yard_xf.erase(b.id):             # 다시 만들 때 _build_shape가 다시 넣는다
			_yard_dirty = true
		if _blds.has(b.id):
			(_blds[b.id] as Node3D).queue_free()
		if _card_items.erase(b.id):
			_contact_dirty = true
		if _fcard_items.erase(b.id):
			_contact_dirty = true
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
	# 장식 노드 (흙 화분 집 · 떨어진 물건) — 건물처럼 가까이/멀리 모양을 두고 멀리 묶음에 함께 구움 (기본 확대에서 그리기 횟수 +0)
	for it: Dictionary in _decor_items():
		var id: int = it["id"]
		seen[id] = true
		if _bld_key.get(id, "") == it["key"]:
			continue
		_bld_key[id] = it["key"]
		if _blds.has(id):
			(_blds[id] as Node3D).queue_free()
		var n := Node3D.new()
		add_child(n)
		_blds[id] = n
		n.position = it["pos"]
		n.rotation.y = it["yaw"]
		n.scale = Vector3.ONE * float(it["s"])
		var near := Node3D.new()
		near.name = "near"
		n.add_child(near)
		var far := Node3D.new()
		far.name = "far"
		n.add_child(far)
		var dm := Art.instance(near, it["model"])
		if Art.has_far(it["model"]):
			Art.instance(far, it["model"], Transform3D.IDENTITY, true).set_meta(SH_SRC, true)
			dm.set_meta(SH_DST, true)
		if _fcard_items.erase(id):
			_contact_dirty = true
		var dpic := Flora2D.pic_for(it["model"]) if _flora2d_on else ""
		if dpic != "" and Flora2D.has(dpic):     # (2D) 화분 집 · 찾은 물건 그림 + 3D 모델은 그림자 대역
			Flora2D.proxify(near)
			Flora2D.proxify(far)
			_add_fcard(n, id, n, dpic, Vector3.ZERO, 1.0)
		n.set_meta("bid", id)
		_record_far(id, n)
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
			if _shadow_items.erase(id):
				_shadow_dirty = true
			if _card_items.erase(id):
				_contact_dirty = true
			if _fcard_items.erase(id):
				_contact_dirty = true
			_far_rest.erase(id)
			_far_moving.erase(id)
	var b0 := Time.get_ticks_usec()
	if _yard_dirty:
		_sync_yard()
	var b1 := Time.get_ticks_usec()
	if _far_dirty and bld_far:
		_sync_far_batch()
	var b2 := Time.get_ticks_usec()
	if _shadow_dirty and not bld_far:
		_sync_near_shadow()
	if _contact_dirty:
		_sync_contact()
	bld_prof = {"rebuilt": _n_rebuilt, "yard": (b1 - b0) / 1000.0, "far_batch": (b2 - b1) / 1000.0, "shadow": (Time.get_ticks_usec() - b2) / 1000.0}
	_n_rebuilt = 0


var lod_prof := {}                # (성능 탐침) 마지막 _process: 건물 LOD 바꾸기 · 움직임 점검 ms
var bld_prof := {}                # (성능 탐침) 마지막 _sync_buildings: 다시 만든 건물 수 · 마당 · 멀리 묶음 · 그림자 대역 ms
var _n_rebuilt := 0


## 장식 노드 목록: [{id(음수), model, pos, yaw, s, key}] — 흙 화분 집 (마을 가장자리, 화면만) + 떨어진 물건 (FoundObjects.shown).
## 놓인 자리는 _decor_block에 적어 잔것(_prop_ok)이 그 위에 나지 않게.
var _decor_block: Array[Vector3] = []     # (x, z, 반지름)
var _decor_sig := ""                      # 잔것 다시 깔기 키에 (화분 집 자리 · 놓인 물건 수)
var _pot_key := ""
var _pot_at := Vector2(1.0e9, 1.0e9)
const POT_CLEAR := 1.7                    # 화분 집 (지름 약 2칸) 둘레


func _decor_items() -> Array:
	var out: Array = []
	_decor_block.clear()
	var pot := _pot_spot()
	if pot.x < 1.0e8 and Art.exists(PF_POT_HOUSE):
		var d := v.center - pot
		out.append({"id": POT_HOUSE_ID, "model": PF_POT_HOUSE, "pos": Vector3(pot.x, gy(pot.x, pot.y) - 0.05, pot.y),
			"yaw": atan2(d.x, d.y), "s": 1.0, "key": "pot|%.2f|%.2f" % [pot.x, pot.y]})
		_decor_block.append(Vector3(pot.x, pot.y, POT_CLEAR))
	for o: Dictionary in FoundObjects.shown(v):
		var kind: String = o["kind"]
		var model: String = FOUND_MODELS.get(kind, "")
		if model == "" or not Art.exists(model):
			continue
		var x: float = o["x"]
		var z: float = o["y"]
		var yaw: float = o["yaw"]
		var y := gy(x, z)
		if o["use"] == "":
			y -= float(FOUND_SINK.get(kind, 0.0))         # 찾은 채 놓인 것
		elif o["use"] == "bridge":                         # 성냥개비 다리: 두 기슭 높이에 걸침 (모델 긴 축 = x)
			var u := Vector2(cos(-yaw), sin(-yaw)) * 0.48
			y = maxf(gy(x + u.x, z + u.y), gy(x - u.x, z - u.y)) - 0.03
		out.append({"id": FOUND_ID0 - int(o["id"]), "model": model, "pos": Vector3(x, y, z), "yaw": yaw, "s": float(o["s"]),
			"key": "%s|%s|%.2f|%.2f|%.2f|%.2f" % [kind, o["use"], x, z, yaw, snappedf(float(o["s"]), 0.05)]})
		_decor_block.append(Vector3(x, z, 0.6))
	_decor_sig = "%.1f,%.1f|%d" % [pot.x, pot.y, out.size()]
	return out


## 흙 화분 집 자리: 마을 가장자리 (영역 반지름의 0.8, 7~16칸) 숲 밖 빈 땅 — 마을 씨앗(sid) 방향부터 돌며 처음 맞는 곳.
## 건물 수·병 방향이 바뀔 때만 다시 보고, 지금 자리가 아직 괜찮으면 그대로 (자리가 튀지 않게)
func _pot_spot() -> Vector2:
	var key := "%d|%d|%.1f,%.1f" % [v.buildings.size(), v.water.rot, v.center.x, v.center.y]
	if key == _pot_key:
		return _pot_at
	_pot_key = key
	if _pot_at.x < 1.0e8 and _prop_ok(_pot_at.x, _pot_at.y, POT_CLEAR):
		return _pot_at
	var r0 := clampf(v.territory_r() * 0.8, 7.0, 16.0)
	var a0 := _hash(float(v.sid), 3.0, 77.0) * TAU
	for ring in 4:
		for k in 16:
			var a := a0 + k * TAU / 16.0
			var q := v.center + Vector2(cos(a), sin(a)) * (r0 + ring * 1.5)
			if forest_at(q) < 0.15 and _prop_ok(q.x, q.y, POT_CLEAR) and _clear_of_trees(q, POT_CLEAR + 2.0):
				_pot_at = q
				return q
	_pot_at = Vector2(1.0e9, 1.0e9)
	return _pot_at


## 시뮬레이션 나무(꽃숲 포기)가 r 안에 없나 — 화분 집이 꽃 아래 묻히지 않게
func _clear_of_trees(q: Vector2, r: float) -> bool:
	for tr: Dictionary in v.trees:
		if Vector2(float(tr["x"]), float(tr["y"])).distance_squared_to(q) < r * r:
			return false
	return true


## (P1 3차) 이 건물의 멀리 모양("far" 노드)과 짐 더미("piles")를 묶음용으로 기록 — 멀리 모양이 없으면 묶지 않음
func _record_far(id: int, n: Node3D) -> void:
	_far_dirty = _far_items.erase(id) or _far_dirty
	_far_moving.erase(id)
	var far := n.get_node_or_null("far") as Node3D
	if not bld_batch or far == null or far.get_child_count() == 0:
		if _shadow_items.erase(id):
			_shadow_dirty = true
		return
	_record_shadow(id, n, far)
	var items: Array = []
	for root: Node3D in [far, n.get_node_or_null("piles") as Node3D]:
		if root == null:
			continue
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.visible or mi.has_meta(&"pic"):     # (2D) 그림 판은 굽지 않음 — 아래 Flora2D.multi
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


func _sync_far_batch(now := false) -> void:
	_far_dirty = false
	# (끊김 — 2026-11-08) 다시 굽기는 한 화면에 FAR_BUDGET_MS까지 나눠서 (_process가 이어 감) — 다 구울 때까지 옛 묶음이 그대로 보인다.
	# 예전엔 짐 더미 하나만 바뀌어도 한 화면에 전부 다시 구워 약 50ms (병 밖 → 병 안으로 들어오는 순간 멈칫). 처음 한 번 · now는 한 번에.
	_far_bake = {"ids": _far_items.keys(), "i": 0, "groups": {}}
	_far_bake_step(INF if _far_batch == null or now else FAR_BUDGET_MS)


var _far_bake := {}               # 굽는 중인 멀리 묶음 {ids, i, groups}


func _far_bake_step(budget_ms: float) -> void:
	if _far_bake.is_empty():
		return
	var t0 := Time.get_ticks_usec()
	var ids: Array = _far_bake["ids"]
	var i: int = _far_bake["i"]
	var groups: Dictionary = _far_bake["groups"]      # [재질, 그림자] → SurfaceTool
	# 같은 (재질 · 그림자)끼리 한 메시로 구워 합침 — 모델마다 메시가 달라 MultiMesh로는 모델 수만큼 그려짐 (멀리 모양 약 6k 삼각형이라 굽기 값쌈)
	while i < ids.size():
		var id: int = ids[i]
		i += 1
		if _far_moving.has(id) or not _blds.has(id) or not _far_items.has(id):
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
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			break
	_far_bake["i"] = i
	if i < ids.size():
		return
	_far_bake = {}
	if _far_batch != null:
		_far_batch.queue_free()
	_far_batch = _node(self)
	_far_batch.name = "far_batch"
	_far_batch.visible = bld_far
	for k: Array in groups:
		var mi := MeshInstance3D.new()
		mi.mesh = (groups[k] as SurfaceTool).commit()
		mi.material_override = k[0]
		mi.cast_shadow = k[1]
		_far_batch.add_child(mi)
	var cards: Array = []                 # (2D) 묶음에 든 건물의 그림 — 아틀라스 하나 · MultiMesh 하나 (그리기 1번)
	for id in _far_items:
		if _far_moving.has(id) or not _blds.has(id):
			continue
		cards.append_array(_card_items.get(id, []))
	if not cards.is_empty():
		_far_batch.add_child(Bld2D.multi(cards))
	var fcards: Array = []                # (2D) 묶음에 든 건물의 꽃·소품 그림 (짐 더미·화분 집·찾은 물건) — 아틀라스마다 그리기 1번
	for id in _far_items:
		if _far_moving.has(id) or not _blds.has(id):
			continue
		fcards.append_array(_fcard_items.get(id, []))
	if not fcards.is_empty():
		_far_batch.add_child(Flora2D.multi(fcards, false))
	for id in _blds:
		_apply_bld_lod(_blds[id])


## (P1 4차) 그림자 대역 기록: "far" 아래 SH_SRC 표시 노드의 메시 (그림자를 드리우는 것만). 모양·자리가 그대로면 다시 굽지 않음 —
## 짐 더미가 바뀌어 건물 노드를 다시 만들어도 (메시는 Art 캐시라 같은 것) 묶음은 그대로
func _record_shadow(id: int, n: Node3D, far: Node3D) -> void:
	var items: Array = []
	for c: Node in far.get_children():
		if not c.has_meta(SH_SRC):
			continue
		var list: Array = c.find_children("*", "MeshInstance3D", true, false)
		if c is MeshInstance3D:
			list.append(c)
		for mi: MeshInstance3D in list:
			if mi.mesh == null or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				continue
			var xf := mi.transform
			var p := mi.get_parent()
			while p != null and p != n:
				xf = (p as Node3D).transform * xf
				p = p.get_parent()
			items.append([mi.mesh, mi.material_override, xf])
	if items.is_empty():
		if _shadow_items.erase(id):
			_shadow_dirty = true
		return
	var rec := [n.transform, items]
	if _shadow_items.get(id, []) != rec:
		_shadow_items[id] = rec
		_shadow_dirty = true


## (P1 4차) 가까이 그림자 대역 묶음 굽기: 가만히 선 건물 전부의 멀리 모양을 한 메시로 (양면 재질), 그림자만 드리움
func _sync_near_shadow() -> void:
	_shadow_dirty = false
	if _near_shadow != null:
		_near_shadow.queue_free()
	_near_shadow = _node(self)
	_near_shadow.name = "near_shadow"
	_near_shadow.visible = not bld_far
	var groups := {}                # 0 → SurfaceTool (하나)
	if bld_shadow_proxy:
		for id in _shadow_items:
			if _far_moving.has(id) or not _blds.has(id):
				continue
			var rec: Array = _shadow_items[id]
			var bx: Transform3D = rec[0]
			for it: Array in rec[1]:
				var mesh: Mesh = it[0]
				for si in mesh.get_surface_count():
					if not groups.has(0):            # 재질은 상관없음 (그림자 대역 재질 하나) — 메시 하나로
						groups[0] = SurfaceTool.new()
					(groups[0] as SurfaceTool).append_from(mesh, si, bx * (it[2] as Transform3D))
	for k: int in groups:
		var mi := MeshInstance3D.new()
		mi.mesh = (groups[k] as SurfaceTool).commit()
		mi.material_override = shadow_proxy_mat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_near_shadow.add_child(mi)
	for id in _blds:
		_apply_bld_lod(_blds[id])


## 그림자 대역 재질: 양면 (멀리 모양은 카메라 쪽만 다듬은 낮은 모양이라 뒷면이 빠진 곳이 있을 수 있음 — 어느 면이든 빛을 막게).
## 그림자 패스 깊이만 쓰므로 빛 계산 없음. 재질이 하나라 묶음 = 그림자 그리기 1번
static var _shadow_mat: ShaderMaterial
static func shadow_proxy_mat() -> ShaderMaterial:
	if _shadow_mat == null:
		var sh := Shader.new()
		sh.code = "shader_type spatial;\nrender_mode unshaded, cull_disabled;\nvoid fragment() { ALBEDO = vec3(0.0); }\n"
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = sh
	return _shadow_mat


## 그림자 대역 묶음에 든 건물인가 (가까이 LOD에서 본 모델 그림자를 끔)
func _shadow_batched(n: Node3D) -> bool:
	var id: int = n.get_meta("bid", -1)
	return bld_shadow_proxy and _shadow_items.has(id) and not _far_moving.has(id) and _near_shadow != null and not _shadow_dirty


## 묶음에 든 건물인가 (멀리 모양 기록이 있고 지금 움직이지 않음)
func _batched(n: Node3D) -> bool:
	var id: int = n.get_meta("bid", -1)
	return bld_batch and _far_items.has(id) and not _far_moving.has(id) and _far_batch != null and not _far_dirty


## 매 화면 (멀리 · 또는 가까이 그림자 대역이 켜졌을 때): 노드 변환이 기록과 달라진 건물(떨어지는 중)·숨긴 건물은 묶음에서 빼고, 제자리로 돌아오면 다시 넣음
func _check_far_moving() -> void:
	var changed := false
	for id in _far_items:
		var n: Node3D = _blds.get(id)
		if n == null:
			continue
		var moving := not n.visible or not n.transform.is_equal_approx(_far_rest[id])    # 숨긴 건물도 묶음에서 뺌
		if moving != _far_moving.has(id):
			changed = true
			_contact_dirty = _contact_dirty or _card_items.has(id)
			if moving:
				_far_moving[id] = true
			else:
				_far_moving.erase(id)
	if bld_far:
		if changed or _far_dirty:
			_sync_far_batch(changed)      # 움직이는 건물은 옛 묶음에도 남아 둘로 보이므로 바로 굽기
		if changed:
			_shadow_dirty = true          # 가까이 그림자 묶음도 다음에 가까이로 갈 때 다시
	else:
		if changed or _shadow_dirty:
			_sync_near_shadow()
		if changed:
			_far_dirty = true             # 멀리 묶음도 다음에 멀리로 갈 때 다시


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
	if _flora2d_on:                  # (2D) 마당 꽃·꽃덤불(·소품) 그림 — 아틀라스마다 그리기 1번
		var items: Array = []
		for k: String in groups:
			var pic := Flora2D.pic_for(k)
			if pic == "":
				Art.multi(_yard, k, groups[k], false)
				continue
			for xf: Transform3D in groups[k]:
				items.append([pic, xf.origin, xf.basis.y.length(), int(xf.origin.x * 7.0 + xf.origin.z * 3.0) % 2 == 0])
		if not items.is_empty():
			_yard.add_child(Flora2D.multi(items))
		return
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
		if _bld2d_on:                 # (2D) 밀밭 그림 (자람 단계 셋) — 3D 줄기는 그림자만
			Bld2D.proxify(near)
			Bld2D.proxify(far)
			_add_card(n, b, Bld2D.wheat_pic(wheat_stage(b, v.t)))
		_set_yard(far, b, far.get_child_count() > 0)
		_apply_bld_lod(n)
		return
	var names: Array = BUILDING_MODELS.get(b.type, ["hut"])
	var nm: String = names[b.id % names.size()]
	if nm == "ferry" and v.era == 0 and Art.exists("ferry_raft"):
		nm = "ferry_raft"
	var main := Art.instance(near, nm)
	if Art.has_far(nm):
		Art.instance(far, nm, Transform3D.IDENTITY, true).set_meta(SH_SRC, true)     # (P1 4차) 가까이 그림자 대역
		main.set_meta(SH_DST, true)
	var pic := Bld2D.type_pic(b.type, b.id, v.era) if _bld2d_on else ""
	if pic != "":
		# (2D) 그림 판 + 3D 모델은 보이지 않는 그림자 대역. 맷돌 윗돌·마당 소품은 그림에 들어 있음. 화덕 불은 땅의 빛 웅덩이만
		Bld2D.proxify(near)
		Bld2D.proxify(far)
		var flip := false
		if b.type == "나루터" and b.has_link:     # 잔교 그림은 화면 오른쪽 위로 뻗음 → 건너편이 화면 왼쪽이면 뒤집기
			flip = Vector2(b.link_x - b.x, b.link_y - b.y).dot(_cam_right2()) < 0.0
		_add_card(n, b, pic, 1.0, flip)
		if nm == "oven" and Art.exists(OVEN_GLOW):
			var g := _oven_glow(n)
			for c: Node in g.get_children():
				if c is MeshInstance3D and not ((c as MeshInstance3D).mesh is PlaneMesh):
					(c as MeshInstance3D).visible = false
			_live[b.id] = {"glow": g}
		_set_yard(far, b, Art.has_far(nm))
		_apply_bld_lod(n)
		return
	if nm == "quern_house" and Art.exists(QUERN_STONE):
		_live[b.id] = {"stone": Art.instance(near, QUERN_STONE, Transform3D(Basis.IDENTITY, QUERN_STONE_AT))}
	elif nm == "oven" and Art.exists(OVEN_GLOW):
		_live[b.id] = {"glow": _oven_glow(n)}
	for y: Array in YARD.get(b.type, []):
		Art.instance(near, y[0], Transform3D(Basis(Vector3.UP, y[2]).scaled(Vector3.ONE * float(y[3]) if y.size() > 3 else Vector3.ONE), y[1]))
	_set_yard(far, b, Art.has_far(nm))
	_apply_bld_lod(n)


## 기본 카메라의 화면 오른쪽 (땅 위, 마을 기준 x·z) — 방위 BASE_YAW_DEG의 카메라 basis.x
static func _cam_right2() -> Vector2:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector2(cos(yaw), -sin(yaw))


## (2D) 건물 노드에 그림 판을 달고 기록 (멀리 묶음 · 접촉 그림자). 땅에 눕힌 그림은 발자리 네 귀퉁이 중 가장 높은 곳 위로
func _add_card(n: Node3D, b: Building, pic: String, k := 1.0, flip := false) -> void:
	if not Bld2D.has(pic):
		return
	var lift := 0.0
	if int(Bld2D.info(pic).get("mode", 0)) == 1:
		var s := b.size()
		var top := gy(b.x, b.y)
		for a in 4:
			top = maxf(top, gy(b.x + cos(a * PI / 2.0 + PI / 4.0) * s, b.y + sin(a * PI / 2.0 + PI / 4.0) * s))
		lift = top - n.position.y + Bld2D.GROUND_LIFT
	n.add_child(Bld2D.card(pic, k, flip, lift))
	if not _card_items.has(b.id):
		_card_items[b.id] = []
	(_card_items[b.id] as Array).append([pic, n.position + Vector3(0, lift, 0), k, flip])
	_contact_dirty = true


## (2D 꽃·소품) 건물 노드(n, id) 아래 parent에 그림 판을 달고 기록 (멀리 묶음 · 접촉 그림자). at = parent 기준 자리
func _add_fcard(n: Node3D, id: int, parent: Node3D, pic: String, at: Vector3, k := 1.0, flip := false) -> void:
	var c := Flora2D.card(pic, k, flip)
	c.position = at
	parent.add_child(c)
	var xf := n.transform
	var p := parent
	var local := Transform3D(Basis.IDENTITY, at)
	while p != null and p != n:
		local = p.transform * local
		p = p.get_parent() as Node3D
	if not _fcard_items.has(id):
		_fcard_items[id] = []
	(_fcard_items[id] as Array).append([pic, xf * local.origin, k * n.scale.y, flip])
	_contact_dirty = true


## (2D) 접촉 그림자 타원 다시 (모든 건물 = MultiMesh 하나). 들려 움직이는 건물은 뺌
func _sync_contact() -> void:
	_contact_dirty = false
	if _fcontact != null:
		_fcontact.queue_free()
		_fcontact = null
	var fitems: Array = []
	for id in _fcard_items:
		if _far_moving.has(id):
			continue
		for it: Array in _fcard_items[id]:
			if float(Flora2D.info(it[0]).get("contact", 0.0)) > 0.0:
				fitems.append(it)
	if not fitems.is_empty():
		_fcontact = Flora2D.contact_shadows(fitems)
		_fcontact.name = "fcontact2d"
		add_child(_fcontact)
	if _contact != null:
		_contact.queue_free()
		_contact = null
	var items: Array = []
	for id in _card_items:
		if _far_moving.has(id):
			continue
		items.append_array(_card_items[id])
	if items.is_empty():
		return
	_contact = Bld2D.contact_shadows(items)
	add_child(_contact)


## 마당 소품 (가까이: _sync_yard가 모양마다 MultiMesh · 멀리: PF_FAR_YARD의 멀리 모양을 건물 "far" 노드에 넣어 건물 멀리 묶음에 함께 구움 →
## 기본 확대(ppu 16)에서 그리기 횟수가 늘지 않는다). bake_far = 이 건물에 멀리 모양이 있을 때만 (없으면 far 노드가 비어 있어야 가까이가 남는다)
const PF_FAR_YARD := [PF_JARS, PF_FENCE, PF_CORDWOOD, PF_QUERN, PF_OVEN, PF_GRANARY, PF_RETTING, PF_WEAVE_JIG, PF_RACK_HASA,
	PF_RACK_NET, PF_ACORN_BASIN]


func _set_yard(far: Node3D, b: Building, bake_far: bool) -> void:
	var items := _yard_items(b)
	if _bld2d_on and _card_items.has(b.id):      # (2D) 단지·화덕·맷돌·건조대·울타리는 그림에 들어 있음 — 집 앞 꽃만
		items = items.filter(func(e: Array) -> bool: return e[0] in YARD_FLORA_2D)
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
		if b.id % 4 == 1:     # (E3-17) 네 집에 하나: 옆벽에 엮기 틀 (울타리·벽 짜기 — 방직소가 열리기 전 집 일)
			out.append([PF_WEAVE_JIG, Transform3D(Basis(Vector3.UP, PI * 0.5 * m), Vector3(-1.45 * m * s, 0, 0.1 * s))])
	elif b.type == "창고":    # 창고 앞 양 귀퉁이에 단지·바구니 + 옆에 다락 곡식 창고 (E3-17 — 창고 모델은 그대로)
		out.append([PF_JARS, Transform3D(Basis(Vector3.UP, 0.3), Vector3(-1.45, 0, 1.25))])
		out.append([PF_JARS, Transform3D(Basis(Vector3.UP, 2.6), Vector3(1.35, 0, 1.2))])
		out.append([PF_GRANARY, Transform3D(Basis(Vector3.UP, 0.15), Vector3(2.05, 0, -0.55))])
	elif b.type == "우물":    # 우물 곁 도토리 깍정이 물그릇
		out.append([PF_ACORN_BASIN, Transform3D(Basis(Vector3.UP, b.id * 0.7), Vector3(0.95 * m, 0, 0.75))])
	elif b.type == "맷돌간" or b.type == "방앗간":   # 빵 사슬 (E3-17): 갈판 맷돌 + (맷돌간) 볏단 건조대
		out.append([PF_QUERN, Transform3D(Basis(Vector3.UP, 0.5 * m), Vector3(1.2 * m * s, 0, 0.95 * s))])
		if b.type == "맷돌간":
			out.append([PF_RACK_HASA, Transform3D(Basis(Vector3.UP, PI * 0.5 + 0.1 * m), Vector3(-1.45 * m * s, 0, 0.1))])
	elif b.type == "빵집":    # 마당에 흙 화덕 하나 더
		out.append([PF_OVEN, Transform3D(Basis(Vector3.UP, -0.4 * m), Vector3(1.55 * m * s, 0, 0.8 * s))])
	elif b.type == "어부":    # 그물 말리는 건조대
		out.append([PF_RACK_NET, Transform3D(Basis(Vector3.UP, 0.3 * m), Vector3(1.4 * m * s, 0, 0.6 * s))])
	elif b.type == "방직소":  # 실 일 (잠긴 건물 — 열리면): 줄기 불림 통 · 엮기 틀 · 그물 건조대
		out.append([PF_RETTING, Transform3D(Basis(Vector3.UP, 0.2), Vector3(-1.5, 0, 1.05))])
		out.append([PF_WEAVE_JIG, Transform3D(Basis(Vector3.UP, -0.15), Vector3(1.45, 0, 1.15))])
		out.append([PF_RACK_NET, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-1.9, 0, -0.6))])
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
	var main := Art.instance(near, nm)
	if Art.has_far(nm):
		Art.instance(far, nm, Transform3D.IDENTITY, true).set_meta(SH_SRC, true)     # (P1 4차) 가까이 그림자 대역
		main.set_meta(SH_DST, true)
	var top_far := Art.exists(nm + "_top") and Art.model_far(nm + "_top")["mesh"] != null
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
		if top_far:                                  # (P1 4차) 가까이 윗부분 그림자도 멀리 모양이 대신
			sh.set_meta(SH_SRC if is_far else SH_DST, true)
		parent.add_child(sh)


static func wheat_fade_mat() -> ShaderMaterial:
	if _fade_mat == null:
		_fade_mat = ToonFade.make()      # 불투명 밑 + 반투명 윗부분 (render/toon_fade.gd — 이삭 금빛이 먹선 없이 비쳐 보임)
		ToonFade.set_param(_fade_mat, &"min_alpha", WHEAT_MIN_ALPHA)
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
	var k0 := n.get_child_count()
	_build_site_shape(n, b)
	if _bld2d_on:      # (2D) 짓는 모습 그림 네 장 (말뚝·바닥 → 뼈대 → 벽 → 서까래) · 밭 고랑 · 개축 비계. 3D 상자는 그림자 대역
		for i in range(k0, n.get_child_count()):
			Bld2D.proxify(n.get_child(i))
		if b.site_type() == "농장":
			_add_card(n, b, "field_site", b.size() / 1.8)
		elif b.built:
			_add_card(n, b, "scaffold", b.size())
		else:
			_add_card(n, b, Bld2D.site_pic(site_stage(b), SITE_STAGES), b.size())
	if b.site_type() != "농장" and not _bld2d_on:      # (2D · Q6) 자재 더미는 BldEcon (화면 기준 자리 · 지으면서 줄어듦)
		_build_site_piles(n, b)


func _build_site_shape(n: Node3D, b: Building) -> void:
	var st := site_stage(b) if b.is_site() else SITE_STAGES - 1
	if b.built:
		st = mini(st, 3)                     # 개축: 옛 집 둘레 비계(기둥·들보)만
	var s := b.size() * 0.85
	var d := s * 0.8
	var wall := Style.WOOD.lightened(0.12)
	if not b.built:
		# (2D · Q6) 말뚝·줄은 그림에 그려져 있다 — 3D 것은 그림자 대역이 되어 그림과 어긋난 점선 네모 그림자만 남기므로 만들지 않음
		for p: Vector2 in ([] if _bld2d_on else [Vector2(-s, -d), Vector2(s, -d), Vector2(-s, d), Vector2(s, d)]):     # 말뚝
			_box(n, Vector3(0.08, 0.3, 0.08), Vector3(p.x, 0.15, p.y), Style.WOOD)
		for e: Array in ([] if _bld2d_on else [[Vector3(s * 2.0, 0.03, 0.03), Vector3(0, 0.26, -d)], [Vector3(s * 2.0, 0.03, 0.03), Vector3(0, 0.26, d)],
				[Vector3(0.03, 0.03, d * 2.0), Vector3(-s, 0.26, 0)], [Vector3(0.03, 0.03, d * 2.0), Vector3(s, 0.26, 0)]]):     # 줄
			_box(n, e[0], e[1], Color("e8dcc0"))
		if b.site_type() == "농장":                                                      # 밭: 고랑이 한 줄씩 늘고 마지막에 울타리
			if _bld2d_on:                 # (2D · Q6) 고랑·울타리는 그림에 — 납작한 상자의 빗금 그림자를 남기지 않음
				return
			var rows := st + 1
			for i in rows:
				var z := -d + (d * 2.0) * (float(i) + 0.5) / float(SITE_STAGES)
				_box(n, Vector3(s * 1.9, 0.07, d * 2.0 / float(SITE_STAGES) * 0.55), Vector3(0, 0.05, z), Color("4f3420"))
			if st >= SITE_STAGES - 2:
				for p: Vector2 in [Vector2(-s, -d), Vector2(s, -d), Vector2(-s, d), Vector2(s, d), Vector2(0, -d), Vector2(0, d)]:
					_box(n, Vector3(0.1, 0.55, 0.1), Vector3(p.x, 0.27, p.y), Style.WOOD)
			return
		if _bld2d_on and st < 4:       # (2D · Q6) 벽이 서기 전 바닥·기둥·들보는 그림자 대역이 되면 그림과 어긋난 빗금·토막 그림자뿐 — 만들지 않음
			return
		if _bld2d_on:                  # (2D · Q6) 벽·지붕 단계 그림자 대역 = 그림 폭에 맞춰 화면 쪽으로 돌린 상자 하나 (건물 방위로 돌아간 벽·서까래 상자는 그림과 어긋난 네모 그림자)
			var sh := 0.9 if st < 6 else 1.5
			_box(n, Vector3(s * 2.0, sh, d * 0.9), Vector3(0, sh * 0.5, 0), Style.WOOD, deg_to_rad(JarCamera.BASE_YAW_DEG) - n.rotation.y)
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


## 짓는 터에 도착한 판자·돌 더미 (2D 그림 건물에서도 3D 그대로 — 소품 단계에서 그림으로)
func _build_site_piles(n: Node3D, b: Building) -> void:
	var s := b.size() * 0.85
	var np := mini(6, int(b.delivered["판자"]))
	if _flora2d_on:                  # (2D) 도착한 판자·돌 더미 그림 (많을수록 크게)
		if np > 0:
			_add_fcard(n, b.id, n, "pile_planks", Vector3(s + 0.55, 0, 0.3), 0.7 + 0.1 * np)
		var ns := mini(6, int(b.delivered["돌"]))
		if ns > 0:
			_add_fcard(n, b.id, n, "pile_stone", Vector3(-s - 0.55, 0, 0.4), 0.7 + 0.1 * ns)
		return
	if np > 0:                       # (E3) 판자 = 쪼갠 갈대·나뭇가지 → 나뭇가지 더미 (많을수록 크게)
		Art.instance(n, "flora/twig_pile_b", Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * (0.16 + 0.025 * np)), Vector3(s + 0.55, 0, 0.3)))
	for i in mini(6, int(b.delivered["돌"])):
		_box(n, Vector3(0.26, 0.22, 0.26), Vector3(-s - 0.4 - (i % 2) * 0.3, 0.11 + (i / 2) * 0.22, 0.4), Style.STONE)


## 건물 앞에 쌓인 산출물
func _build_piles(n0: Node3D, b: Building) -> void:
	var n := Node3D.new()              # (P1 3차) 짐 더미는 "piles" 아래 — 멀리 묶음에 들면 숨김
	n.name = "piles"
	n0.add_child(n)
	if _bld2d_on:                    # (2D · Q6) 산출 더미는 BldEcon (그림 앞 화면 기준 자리 · 세 단계)
		return
	var i := 0
	if _flora2d_on:                  # (2D) 물건마다 더미 그림 하나 (많을수록 크게) — 멀리 묶음엔 Flora2D.multi로
		for k in b.out:
			var cnt := mini(6, int(b.out[k]))
			if cnt > 0:
				_add_fcard(n0, b.id, n, Flora2D.goods_pic(k), Vector3(b.size() + 0.55, 0, -0.6 + i * 0.6), 0.65 + 0.09 * cnt)
			i += 1
		return
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


## (꽃 군락) 꽃숲 자리 성질 = (젖음 0~1, 숲 짙기 0~1) — 지금 좌표 p. dense < 0이면 forest_at으로 읽음 (FloraLook.clump_at)
func flora_site(p: Vector2, dense := -1.0) -> Vector2:
	var w := v.water
	var wet := 0.0
	if w.inside(p.x, p.y, 0.0):
		var k := w.idx(p.x, p.y)
		wet = w.wet_k(k)
		if w.is_lake(k) or w.is_river(k):
			wet = 1.0
	return Vector2(wet, forest_at(p) if dense < 0.0 else dense)


## (꽃 군락) 얼룩 자리 씨앗 — 넓은 세상은 세상 씨앗, 소형 병은 고정 (병마다 같은 자리)
func flora_seed() -> int:
	return (v.water as WorldWater).seed_v if v.water is WorldWater else 20261105


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
	for d: Vector3 in _decor_block:                 # 흙 화분 집 · 떨어진 물건 (_decor_items)
		if Vector2(x - d.x, z - d.y).length() < d.z + clear_r:
			return false
	return true


func _add(groups: Dictionary, key: String, xf: Transform3D) -> void:
	if not groups.has(key):
		groups[key] = [] as Array[Transform3D]
	(groups[key] as Array[Transform3D]).append(xf)


## (2D 그림 — 마을 한가운데가 읽히게, 2026-11-09 메인 검토) 정사영 카메라는 마을을 앞쪽 큰 꽃 너머로 본다: 불투명한 그림 판이라
## (사용자: 반투명 싫음) 마을 둘레(CORE_R) 안과 그 앞(카메라 쪽 CORE_FRONT) 띠에서는 키 큰 그림을 CORE_H 높이로 줄여 놓는다.
## 화면만 — 시뮬레이션 나무 자리·수는 그대로 (ADR-0001). 거리는 기본 방위(BASE_YAW) 기준.
const CORE_H := 3.0               # 줄여 놓는 화면 높이 상한 (칸, 주민 세 명 키)
const CORE_FRONT := 13.0          # 카메라 쪽 띠 길이 (꽃 키 14 × cot 48° — 그 뒤 땅을 가리는 몫)
var _core_r := -1.0               # 이번에 놓는 동안의 마을 둘레 (−1 = 줄이지 않음)


func _core_begin() -> void:
	_core_r = clampf(v.territory_r() * 0.75, 6.0, 18.0) if _flora2d_on else -1.0


func _core_scale(key: String, x: float, z: float, s: float) -> float:
	if _core_r < 0.0:
		return s
	var p := Vector2(x, z) - v.center
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	var tw := Vector2(sin(yaw), cos(yaw))
	var along := p.dot(tw)
	var lat := absf(p.dot(Vector2(tw.y, -tw.x)))
	if p.length() > _core_r and not (along > 0.0 and along < _core_r + CORE_FRONT and lat < _core_r):
		return s
	var pic := Flora2D.pic_for(key)
	if pic == "":
		return s
	var h := float(Flora2D.info(pic).get("h", 0.0)) * s
	return s * CORE_H / h if h > CORE_H else s


func _put(groups: Dictionary, key: String, x: float, z: float, s: float, yaw: float, dy := 0.0) -> void:
	s = _core_scale(key, x, z, s)
	if _flora2d_on and econ != null:      # [보이는 살림 Q6] 건물 앞 더미를 가리는 키 큰 그림은 낮춤 (화면만 — BldEcon.apron_scale)
		s = econ.apron_scale(key, x, z, s)
	var y := gy(x, z) + dy
	_add(groups, key, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(x, y, z)))
	if _rec != null and FloraPicks.pickable(key):
		_rec.add(key, Vector3(x, y, z), s, _rec_sim)


func _flush(parent: Node3D, groups: Dictionary, no_shadow: Array = []) -> void:
	if _batches.has(parent):
		(_batches[parent] as FloraBatch).set_groups(groups, no_shadow)
		_flora_lod()
		return
	for c in parent.get_children():
		c.queue_free()
	if _flora2d_on:                  # (2D) 바위·연잎: 그림 (아틀라스마다 그리기 1번) + 그림자를 드리우던 것은 3D 대역 (SHADOWS_ONLY)
		var items: Array = []
		for k: String in groups:
			var pic := Flora2D.pic_for(k)
			if pic == "" or not Flora2D.has(pic):
				no_pic2d[k] = true
				Art.multi(parent, k, groups[k], not (k in no_shadow))
				continue
			for xf: Transform3D in groups[k]:
				items.append([pic, xf.origin, xf.basis.y.length(), fposmod(xf.origin.x * 3.1 + xf.origin.z * 1.7, 2.0) < 1.0])
			if not (k in no_shadow):
				var sh := _node(parent)
				Art.multi(sh, k, groups[k], true)
				Flora2D.proxify(sh)
		if not items.is_empty():
			parent.add_child(Flora2D.multi(items))
		return
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
	var se := FloraLook.season_of(v)
	if se != season and _flora2d_on:
		Flora2D.keep_season(se)      # (2D) 다른 철 꽃 아틀라스를 놓아 줌
	season = se
	var key := "%d|%d|%d|%d|%s|%s|%.0f|%d" % [v.trees.size(), n_tree, n_stump, v.water.rot, season, _flora2d_on, v.territory_r() if _flora2d_on else 0.0, v.buildings.size() if _flora2d_on else 0]
	if key == _tree_key:
		return
	_tree_key = key
	# (E3-3 소인의 세상) 나무 = 꽃숲 덩이 · 벤 자리 = 나뭇가지 더미 · 묘목 = 클로버·풀 싹 (view/flora_look.gd)
	var groups := {}
	n_flora = 0
	_core_begin()
	_rec = FloraPicks.new()
	for tr: Dictionary in v.trees:
		var x: float = tr["x"]
		var z: float = tr["y"]
		var h := _hash(x, z)
		var yaw := _hash(z, x, 1.0) * TAU
		var c: Array
		_rec_sim = tr["s"] == "tree"
		match String(tr["s"]):
			"tree":
				var o := _to_orig(Vector2(x, z))
				c = FloraLook.clump_at(season, o, _hash(o.x, o.y, 11.0), _hash(o.y, o.x, 12.0), flora_site(Vector2(x, z)), flora_seed())
				n_flora += 1
			"stump":
				c = FloraLook.twig(h)
			_:
				c = FloraLook.sprout(h)
		_put(groups, c[0], x, z, float(c[1]) * TREE_SCALE, yaw)
	flora_picks["_trees"] = _rec
	_rec = null
	_rec_sim = false
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
		if _flora2d_on:              # (2D) 광맥 바위: 회색 그림에 돌 색을 곱함 (그리기 1번)
			var oc: Color = Style.ORE.get(ore, Style.ORE["돌"])
			var base: Color = Style.ORE["돌"]
			var tint := Color(minf(oc.r / base.r, 1.6), minf(oc.g / base.g, 1.6), minf(oc.b / base.b, 1.6))
			var items: Array = []
			for gk: String in og:
				var pic := Flora2D.pic_for(gk)
				for xf: Transform3D in og[gk]:
					items.append([pic, xf.origin, xf.basis.y.length(), false, tint])
			node.add_child(Flora2D.multi(items))
			var shadow_root := _node(node)
			for gk: String in og:
				Art.multi(shadow_root, gk, og[gk])
			Flora2D.proxify(shadow_root)
			continue
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
	var key := "%d|%d|%d|%s|%s" % [v.buildings.size(), v.water.rot, int(v.t / 21600.0), season, _decor_sig]
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
	_rec = FloraPicks.new()
	_core_begin()
	_decor_forest(groups, sim_pts)
	_decor_clusters(groups)
	_lilies.clear()
	_decor_water(groups)
	_decor_yards(groups)
	_decor_crossings(groups)
	flora_picks["_props"] = _rec
	_rec = null
	_flush(_props, groups, ["tuft", "lily", "lotus", "reeds", PF_REEDS, PF_MUSHROOMS, "flowers", "flowers_b", "flora/fallen_leaf_dry"] + FLAT_LITTER + FloraLook.NO_SHADOW)
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
			var c := FloraLook.clump_at(season, p0, _hash(gi, gj, 4.0), _hash(gi, gj, 5.0), flora_site(p, f), flora_seed())
			_put(groups, c[0], p.x, p.y, float(c[1]) * TREE_SCALE, _hash(gi, gj, 6.0) * TAU)
			n_decor_trees += 1


## 소품 무리: 숲 가장자리엔 덤불·거대한 고사리·버섯·이끼 둔덕·돌·나뭇가지 더미·떨어진 큰 잎, 빈 풀밭엔 드문드문 클로버·풀 포기·꽃 덤불
## (2026-11-08) 숲 가장자리에 polyfork 돌무더기·이끼 둔덕·고사리
## (2026-11-08 "이끼, 고사리 크기가 어때야 하는지 알지?") 진짜 크기 (주민 5cm = 1칸, GAME_DESIGN 3.0):
##   풀·꽃·고사리·이끼·클로버는 진짜 크기 모델 × FloraLook.base_scale (K·√키 — 5칸 넘는 것만 줄임) — 큰 나무 자리 꽃숲과 같은 규칙.
##   거대한 고사리(진짜 30~60cm → 화면 약 6~8칸)는 숲 가장자리에만, 한 포기씩, 건물에서 떨어져 (빈 풀밭·마당엔 두지 않음).
##   옛 사람 크기 소품 모델(build_nature)은 CLUTTER_SCALE로 진짜 크기에 맞춤.
## (2026-11-08 polyfork 2차 — E3-17) 숲 가장자리에 떨어진 잔가지·참나무 잎 / 꽃잎·씨앗 / 알껍데기 · 이끼 밑동 · 거대한 쇠뜨기,
##   버섯은 polyfork 버섯 무리로 (옛 "mushrooms" 대신 — 그리기 횟수 그대로). 빈 풀밭엔 가끔 꽃잎·씨앗.
const FRINGE := ["bush", "bush_b", PF_MOSS, PF_FERN, PF_MUSHROOMS, "rocks", "flora/twig_pile_a", "flora/fallen_leaf_dry", "bush_flower", PF_MOSS, PF_CAIRN, "bush_berry",
	PF_LITTER_A, PF_STUMP, PF_LITTER_B, PF_HORSETAIL, PF_EGGSHELL, PF_LITTER_A]
const OPEN := ["flora/clover_a", "flora/clover_a", "tuft", "tuft", "flowers", "rock_small", "bush_flower", PF_MUSHROOMS, "flowers_b", "rock_small", "bush_b", "tuft", PF_LITTER_B]
## 한 자리에 하나만 (나머지는 1~3포기 무리)
const CLUTTER_ONE := ["flora/twig_pile_a", "flora/fallen_leaf_dry", "rocks", "rocks_b", PF_CAIRN, PF_MOSS, PF_FERN, "flora/clover_a",
	PF_LITTER_A, PF_LITTER_B, PF_EGGSHELL, PF_STUMP, PF_HORSETAIL]
## 거대한 풀 (고사리·쇠뜨기) — 집·길·모닥불에서 FERN_CLEAR만큼 비키고, 흔들기 폭이 작다
const GIANT_GREEN := [PF_FERN, PF_HORSETAIL]
const LITTER_CLEAR := 2.6
## 땅에 납작한 잔것 (그림자 끔)
const FLAT_LITTER := [PF_LITTER_A, PF_LITTER_B, PF_EGGSHELL]
## 옛 사람 크기 모델 → 진짜 크기 배율 (모델 키 × 배율 = 화면 칸, 무리마다 ×0.75~1.25):
##   덤불(작은 잎 풀 포기, 진짜 5~10cm) 0.64~0.86 → 1.1~1.5 · 버섯(3~10cm) 0.61 → 1.1 · 풀 포기(마을의 밟힌 풀 5~8cm) 0.4 → 1.2
##   작은 들꽃 포기(5~15cm) 0.55 → 1.7. 돌(1.07 = 5cm 돌, 주민에겐 바위)·조약돌(0.59)은 그대로.
## 진짜 크기 모델에 곱하는 몫: 마을 빈터의 클로버는 밟히고 깎인 낮은 포기 (진짜 10~20cm → 화면 약 2칸, 폭 2.6)
const CLUTTER_SCALE := {"bush": 1.7, "bush_b": 1.7, "bush_flower": 1.7, "bush_berry": 1.7, "mushrooms": 1.8, "tuft": 3.0,
	"flowers": 3.0, "flowers_b": 3.0, "flora/clover_a": 0.5}


## 땅 위 잔것 하나의 기본 배율 (무리마다 흔들기 전)
static func clutter_scale(kind: String) -> float:
	var s := float(CLUTTER_SCALE.get(kind, 1.0))
	if kind.begins_with("flora/") or kind in [PF_FERN, PF_MOSS, PF_HORSETAIL, PF_REEDS, PF_MUSHROOMS]:
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
			if kind == PF_LITTER_A and not _prop_ok(c.x, c.y, LITTER_CLEAR):
				continue                    # 떨어진 잔가지 (길이 약 5칸)가 물·마당·길로 뻗지 않게
			if kind in GIANT_GREEN and not _prop_ok(c.x, c.y, FERN_CLEAR):
				continue                    # 거대한 고사리 잎이 집·길·모닥불 위로 덮이지 않게
			var cnt := 1 if kind in CLUTTER_ONE else 1 + int(_hash(gi, gj, 7.0) * 3.0)
			for i in cnt:
				var a := _hash(gi, gj, 10.0 + i) * TAU
				var d := (0.35 + 0.8 * _hash(gi, gj, 20.0 + i)) if i > 0 else 0.0
				var x := c.x + cos(a) * d
				var z := c.y + sin(a) * d
				if not _prop_ok(x, z, 0.3):
					continue
				var jig := (0.85 + 0.3 * _hash(gi, gj, 30.0 + i)) if kind in GIANT_GREEN else (0.75 + 0.5 * _hash(gi, gj, 30.0 + i))
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
			elif hh < 0.3:            # (E3-17) polyfork 갈대 덤불 + 부들 (진짜 크기 × FloraLook — 옛 "reeds" 대신)
				_put(groups, PF_REEDS, p.x, p.y, clutter_scale(PF_REEDS) * (0.8 + hh), hh * 50.0)
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
		for e: Array in yard_bush_spots(b):
			var hb: float = e[2]
			_put(groups, "bush_flower" if hb > 0.8 else ("bush_b" if hb < 0.5 else "bush"), e[0], e[1], 0.65 + 0.4 * hb, hb * 9.0)


## 집 둘레 덤불 자리 [[x, z, 해시]…] — BldEcon도 읽는다 (일터 앞 더미가 덤불 뒤에 숨지 않게)
static func yard_bush_spots(b: Building) -> Array:
	var out: Array = []
	if not b.built or b.type in ["농장", "소금밭", "우물", "채석장"]:
		return out
	var base := deg_to_rad(JarCamera.BASE_YAW_DEG)
	for i in 3:
		var hb := _hash(b.x + i, b.y, 80.0)
		if hb < 0.3:
			continue
		var a := base + PI * 0.5 + (i - 1) * 1.15 + hb * 0.4
		var r := b.size() * BUILDING_SCALE * 1.45
		out.append([b.x + sin(a) * r, b.y + cos(a) * r, hb])
	return out


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
	# (끊김 — 2026-11-08) 안개 칸마다 놓을 덩이를 기억해 두고(_far_cells) 새로 걷힌 칸만 셈 + 한 화면에 FAR_BUDGET_MS까지만 (_process가 이어 감).
	# 예전엔 걷힐 때마다 반지름 200칸을 한 화면에 다시 셈 (clump_at 수천 번 — 병 밖에서 들어올 때 약 200ms 멈춤).
	# 6시간마다 새로 (물·강이 바뀌면 그 자리 덩이가 빠지게 — 예전처럼 다시 셈, 다만 나눠서)
	var key := "%s|%d|%.1f,%.1f|%d|%d|%d" % [season, flora_seed(), v.center.x, v.center.y, v.peers.size(), v.water.rot, int(v.t / 21600.0)]
	if key != _far_cells_key:
		_far_cells.clear()
		_far_cells_key = key
	var c := v.center
	var fs := float(WorldWater.FOG)
	var fl: Array[Dictionary] = []
	for f: Dictionary in ww.forests:
		if Vector2(f["x"], f["y"]).distance_to(c) < FAR_MAX + float(f["r"]) * 1.6:
			fl.append(f)
	_far_job = {"q0": Vector2i(clampi(floori((c.x - FAR_MAX + ww.rr) / fs), 0, ww.fn - 1), clampi(floori((c.y - FAR_MAX + ww.rr) / fs), 0, ww.fn - 1)),
		"q1": Vector2i(clampi(floori((c.x + FAR_MAX + ww.rr) / fs), 0, ww.fn - 1), clampi(floori((c.y + FAR_MAX + ww.rr) / fs), 0, ww.fn - 1)),
		"i": 0, "fl": fl, "nz": _forest_noise(), "ms": 0.0}
	_far_step(INF if not _far_built else FAR_BUDGET_MS)


const FAR_BUDGET_MS := 3.0        # 먼 숲 다시 놓기: 한 화면에 이만큼까지 (그 뒤는 다음 화면 — 그동안은 옛 먼 숲이 보임)
var _far_cells := {}              # 안개 칸 Vector2i → [[모양, Transform3D], …] (걷혔는지와 상관없는 후보 — 놓을 때 revealed로 거름)
var _far_cells_key := ""
var _far_job := {}
var _far_built := false           # 처음 한 번은 한 번에 (장면을 열 때 — 시험·캡처도 바로 보이게)


func _far_step(budget_ms: float) -> void:
	if _far_job.is_empty():
		return
	var ww := v.water as WorldWater
	var t0 := Time.get_ticks_usec()
	var q0: Vector2i = _far_job["q0"]
	var q1: Vector2i = _far_job["q1"]
	var w := q1.x - q0.x + 1
	var n := w * (q1.y - q0.y + 1)
	var i: int = _far_job["i"]
	var c := v.center
	var lim := v.view_r + 2.0
	var fs := float(WorldWater.FOG)
	while i < n:
		var qx := q0.x + i % w
		var qy := q0.y + i / w
		i += 1
		if ww.fog[qy * ww.fn + qx] == 0:
			continue
		var q := Vector2i(qx, qy)
		if _far_cells.has(q):
			continue
		var x0 := -ww.rr + qx * fs
		var y0 := -ww.rr + qy * fs
		var out: Array = []
		if Vector2(x0 + fs * 0.5, y0 + fs * 0.5).distance_to(c) >= lim - 4.0:
			_far_cell(out, x0, y0, fs, c, lim, _far_job["nz"], _far_job["fl"])
		_far_cells[q] = out
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			break
	_far_job["i"] = i
	_far_job["ms"] = float(_far_job["ms"]) + (Time.get_ticks_usec() - t0) / 1000.0
	if i < n:
		return
	# 다 셈 → 걷힌 곳만 모아 한 번에 놓음
	var t1 := Time.get_ticks_usec()
	var groups := {}
	n_far_trees = 0
	var rec := FloraPicks.new()
	for q: Vector2i in _far_cells:
		if ww.fog[q.y * ww.fn + q.x] == 0:
			continue
		for e: Array in _far_cells[q]:
			var xf: Transform3D = e[1]
			if not ww.revealed(xf.origin.x, xf.origin.z):
				continue
			_add(groups, e[0], xf)
			if FloraPicks.pickable(e[0]):
				rec.add(e[0], xf.origin, xf.basis.get_scale().x, false)
			n_far_trees += 1
	flora_picks["_far"] = rec
	_flush(_far, groups, FloraLook.NO_SHADOW)
	far_ms = float(_far_job["ms"]) + (Time.get_ticks_usec() - t1) / 1000.0
	_far_job = {}
	_far_built = true


## 안개 칸 하나(x0, y0, 폭 fs)의 먼 숲 후보 → out ([모양, Transform3D]) — 마을 둘레 장식과 같은 격자·해시
func _far_cell(out: Array, x0: float, y0: float, fs: float, c: Vector2, lim: float, nz: FastNoiseLite, fl: Array[Dictionary]) -> void:
	var ww := v.water as WorldWater
	for gj in range(ceili(y0 / FOREST_STEP), ceili((y0 + fs) / FOREST_STEP)):
		for gi in range(ceili(x0 / FOREST_STEP), ceili((x0 + fs) / FOREST_STEP)):
			var p := Vector2(gi + _hash(gi, gj, 1.0) * 0.8 - 0.4, gj + _hash(gi, gj, 2.0) * 0.8 - 0.4) * FOREST_STEP
			if p.distance_to(c) < lim or p.distance_to(c) > FAR_MAX:
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
			var fc := FloraLook.clump_at(season, p, _hash(gi, gj, 4.0), _hash(gi, gj, 5.0), Vector2(ww.wet_k(k), fd), flora_seed(), true)
			var sc := float(fc[1]) * TREE_SCALE
			out.append([fc[0], Transform3D(Basis(Vector3.UP, _hash(gi, gj, 6.0) * TAU).scaled(Vector3.ONE * sc), Vector3(p.x, gy(p.x, p.y), p.y))])


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
	tremor_fx = TremorFx.new(v, self)
	add_child(tremor_fx)
	fireflies = Fireflies.new(v, self)
	add_child(fireflies)


func _animate_fire() -> void:
	if _fire == null:
		return
	_fire.visible = not hide_fire
	_fire.position = Vector3(v.fire.x, gy(v.fire.x, v.fire.y), v.fire.y)
	_fire.tick(get_process_delta_time() if is_inside_tree() else 0.0, v)   # [모닥불] 상태·일렁임·LOD (view/campfire.gd)
