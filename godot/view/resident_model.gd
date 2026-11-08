## 주민 3D 모델 — RENDERING.md 2.6, 기획서 7.1. 그림 기준: design/characters/*.png (A20 캐릭터 디자인 시트)
## v3 (A20 v3): 매끈하고 둥근 동화책 주민. 몸은 Blender 에셋 art/models/resident.glb (art/src/build_residents.py):
##   뼈대 하나(엉덩이·허리·가슴·머리·팔 3마디·다리 3마디) + 뼈에 붙은 부품 메시 (가까이 LOD 약 3천 · 멀리 LOD 약 600 삼각형) +
##   동작(Blender에서 만든 애니메이션: 숨쉬기·걷기·노인 걸음·아이 깡충·나르기·들기·도끼/괭이/망치/손일·기도·앉기·먹기·잠·손 흔들기·놀기·날기).
##   이 주민이 고른 부품을 LOD마다 메시 하나로 합친다 (같은 조합은 공유 — 주민 한 명 = 그리기 2번 + 외곽선).
##   얼굴 = 그림 묶음 art/models/resident_face.png (표정 칸, render/resident.gdshader). 소품(짐·연장·지팡이)은
##   art/models/resident_props.glb (Art.parts) — 뼈(가슴·손)에 붙임.
## 겉모습(체형·머리·피부·옷 색)은 주민 데이터(look_* · 겉모습 유전자 · 혈통 표시)에서만 정한다 — 능력치(재주·특징·숙련·건강)와 상관없다.
## 직업 옷(set_job)은 일터 종류에서, 표정(set_face)은 지금 상태(잠·앓음·기분·말)에서.
## 색: 부품의 열쇠 색을 render/resident.gdshader가 이 주민의 옷·피부·머리·수건·숄 색으로 바꿈. 주민 한 명 = 재질 하나.
## 외곽선: 뒤집은 껍데기(짙은 갈색) + 화면 깊이 외곽선.
## A23 (아트 바이블 5.2·8.13): 약 4등신, 모델 단위 = 게임 단위 (1 = 1칸 = 어른 키 · 아이 약 0.7 · 노인 0.95 + 지팡이).
##   낮엔 머리쓰개 문화 (넓은 챙 풀 모자 · 높은 고깔 · 늘어진 머릿수건 — daylight), 저녁엔 벗어 머리색이 드러남.
## v5 동작: 시뮬레이션 동작(r.anim) + 행동(r.action)으로 기본 클립을 고르고 (_clip), 사람마다 버릇(_style)·시작 자리·빠르기를 달리,
##   가끔 사이 동작(둘러보기·기지개·머리 긁기·짝다리·이야기·절)을 끼운다 (VARIETY). 손 흔들기는 인사(greet)·신호 때만.
## LOD: 마을 확대가 LOD_PPU(칸당 화면 점) 이상이면 가까이 LOD (village_view가 set_lod) — 초상화·따라가기는 늘 가까이.
class_name ResidentModel
extends Node3D

## 걸음 동작이 1배속일 때 디딘 발이 몸 뒤로 미는 빠르기 (칸/초, 모델 배율 1 기준 — tools/measure_stride.gd로 잰 값).
## 동작 빠르기 = 땅 위 실제 빠르기 ÷ (이 값 × 모델 배율) → 발이 미끄러지지 않는다 (GD 6.6 '걸음 다시' 2026-11-07)
const STRIDE := {"walk": 1.35, "carry": 1.18, "run": 2.28, "walk_elder": 0.67}   # A23 4등신 (칸/초, 모델 배율 1)
const GROUND_NORMAL := Balance.WALK_SCREEN   # 땅 빠르기를 모를 때(초상화·사진) 어른 걸음 = 보통 배속 1초에 0.7칸 (Balance.WALK × 288)
const GROUND_EASE := 6.0          # 잰 땅 빠르기를 부드럽게 따라가는 정도 (1/초)
const PARTS := "resident_props"   # 소품: art/models/resident_props.glb (Art.parts)
const BODY := "res://art/models/resident.glb"
const FACE_TEX := "res://art/models/resident_face.png"
## A20 v4: 손으로 그린 결 그림 묶음 (머리카락 · 옷감) — art/src/pack_detail_atlas.py (원본 design/characters/textures/src).
## 부품의 꼭짓점 색 알파 = 칸 번호, UV2 = 칸 안의 무늬 자리 → 셰이더가 물들인 색 × 결
const HAIR_TEX := "res://art/models/resident_hair.png"
const CLOTH_TEX := "res://art/models/resident_cloth.png"
const LOD_PPU := 24.0             # 이 확대(칸당 화면 점) 이상이면 가까이 LOD
const HEAD_TILT := -0.3           # 머리를 살짝 들어 위에서 보는 카메라(48°)에도 얼굴이 보이게
const NECK := Vector3(0, 0.735, 0) # 머리 부품 좌표 원점 (셰이더 대머리·주근깨 자리) — art/src/build_residents.py fz(NECK)
## CUSTOM1 = 옛 설계 단위 자리 (셰이더의 대머리·주근깨·점박이 숫자가 그대로 맞게): 머리 = (자리 - NECK) ÷ HEAD_K, 몸 = 자리 ÷ BODY_K
const HEAD_K := 0.42              # build_residents.py HS
const BODY_K := 0.52              # build_residents.py WB
const ARM_X := 0.148              # 어깨 관절 x (build_residents.py ARM_X × WB) — 체형 어깨 넓힘
const LEG_X := 0.055              # 다리 x (LEG_X × WB)
const BLEND := 0.18               # 동작 바꿀 때 섞는 시간 (초)

## 부품 고르기 표 (데이터) — look_clothes → 몸통·다리, look_head × 성별 → 머리 모양, look_hat → 모자
const CLOTHES := [{"torso": "torso_tunic", "leg": "leg_trousers"}, {"torso": "torso_dress", "leg": "leg_stocking"}]
const HAIR_BY_LOOK := [["hair_short", "hair_bun"], ["hair_long", "hair_braids"]]   # [look_head][여자면 1]
## 얼굴형 (겉모습 유전자 Genetics.face_shape): 0 둥근 · 1 갸름한 · 2 넓적한 · 3 하트 (머리 배율 — 초상화는 윤곽까지 다름)
const FACE_SHAPES := [Vector3(1.03, 0.98, 1.0), Vector3(0.94, 1.06, 0.96), Vector3(1.08, 0.95, 1.02), Vector3(0.98, 1.02, 0.97)]
## (A20 2차) 소인의 옷 — 시대(Village.era 0 개척기 · 1 마을 · 2 읍내 · 3 영지)마다 옷감 색과 꾸밈이 달라진다.
## 옷 색: 개척기 = 엮은 풀·마른 잎·나무껍질 빛 / 마을 = 물들인 천 + 꽃잎 빛 / 읍내 이후 = 꽃잎 빛이 많음
const ERA_CLOTH := [
	["7d8f4a", "a68a52", "6b7a3a", "8a6a45", "9c8c5c", "5f7046", "b09a62", "7a5a3c"],
	["46759e", "6e452f", "3e5c2c", "a0703e", "c96f6f", "8b6fa8", "d9a441", "60782e"],
	["c95f72", "e0a43a", "7e68b5", "4f86b8", "e48c5a", "5d8f4e", "9a4f7a", "3f6f8f"]]
const PETAL_COLORS := ["f2a7b8", "f4d27a", "c9b6ea", "f4b183", "f3efe6", "e98a8a", "9fc6e8"]   # 꽃잎 치마 (꽃잎 빛)
const LEAF_COLORS := ["6f9a3e", "8aa64a", "5d7f3a", "b88a3a", "a65a32"]                    # 잎 망토 (푸른 잎 · 마른 잎 · 단풍)
const SCARF_COLORS := ["b54023", "e2ded8", "d9a441", "4f86b8", "c96f6f", "7e68b5"]          # 목수건
const FLOWERS := ["acc_flower", "acc_flower_w", "acc_flower_y"]
## 시대마다 꾸밈이 나올 몫 (0~10, 차림 취향 씨앗으로 사람마다 정해짐) — [개척기, 마을, 읍내 이후]
const ERA_PETAL := [3, 5, 6]       # 여자·여자아이 꽃잎 치마
const ERA_BUTTONS := [0, 5, 8]     # 튜닉 씨앗 단추
const ERA_CAPE := [4, 2, 2]        # 잎 망토
const ERA_SCARF := [1, 2, 3]       # 목수건
const ERA_ACORN := [1, 2, 3]       # 도토리 깍정이 모자 (모자 없는 사람)
const ERA_FLOWER := [2, 4, 4]      # 머리에 꽃 (여자·아이, 모자 없거나 수건)
static var village_era := 0        # 지금 그리는 마을의 시대 (VillageView가 정함 — look_of가 읽음)
## A23 (아트 바이블 5.3 R6) 낮의 머리쓰개 문화: 낮에 등불 아래서 일할 땐 많은 주민이 머리를 덮는 쓰개를 쓰고 저녁엔 벗는다.
## 모양은 머리 윤곽을 크게 바꾸는 것만 — 넓은 챙 풀 모자 · 높은 고깔 · 늘어진 머릿수건 (크림·마른 재료색, 고정 색).
## 누가 무엇을 쓰는지는 차림 취향 씨앗(유전 아님) × 시대 — 능력과 무관. 직업 모자가 있으면 그것을 씀.
const DAY_HATS := ["hat_straw", "hat_cone", "hat_kerchief"]
const ERA_DAY_HAT := [9, 9, 8]     # 시대마다 낮 쓰개를 쓰는 몫 (0~10)
const DAY_HOURS := Vector2(6.0, 17.0)   # 이 시각 사이 = 낮 (저녁 모닥불부터 벗음)
static var daylight := true        # 지금 낮인가 (VillageView가 정함 — 모델마다 바뀔 때만 몸을 다시 합침)
const HATS := ["", "hat_straw", "hat_scarf"]
const CAP_HAT := "hat_cap"        # 모자 없는 남자 일부
## 체형 3종 (겉모습 유전자 '체격'에서 — 능력과 무관): 0 호리호리 · 1 다부진 · 2 둥근 → 몸통 배율 (가슴·치마 뼈)
const BODY_SCALE := [Vector3(0.88, 1.0, 0.88), Vector3(1.04, 1.0, 1.0), Vector3(1.14, 1.0, 1.28)]
## 노인 숄 색 (차분한 색 — 사람마다 하나. 셰이더 shawl)
const SHAWL_COLORS := ["7d8a68", "8b7560", "6c7d8a", "94785a", "7b6a7e", "6f8572"]
## 짐 이름 → 부품 (없으면 상자)
const ITEMS := {"통나무": "item_log", "판자": "item_plank", "돌": "item_stone", "낟알": "item_sack", "밀": "item_sack",
	"밀가루": "item_sack", "빵": "item_basket", "물": "item_water", "소금": "item_sack",
	"버섯": "item_basket", "빛버섯": "item_basket", "붉은 물감": "item_basket", "말린 버섯": "item_basket"}   # [하늘의 것] (옛 소품 — carry glb가 없을 때만)
## (A22 · E0 · OPENING 3.1c) 나르는 짐 — 밀 단 → 밀가루 자루 → 반죽 그릇 → 빵 바구니가 길 따라 옮겨 가는 모습이 핵심.
## 소품 = art/models/carry/<이름>.glb (art/src/build_carry.py, 부품 "<이름>" · 멀리 LOD 덩어리 "<이름>__far").
## 짐 이름 → [소품, 드는 자리]. 자리: front 두 손으로 안음 · shoulder 오른 어깨에 멤 · back 등에 짊어짐(오른손이 목을 잡음) ·
## head 머리에 임 · hand 오른손에 늘어뜨림. 표에 없는 짐 = 보따리 (CARRY_GENERIC)
const CARRY := {
	"밀": ["wheat_sheaf", "shoulder"], "밀가루": ["flour_sack", "back"], "반죽": ["dough_bowl", "front"],
	"빵": ["bread_basket", "front"], "죽": ["porridge_pot", "front"], "건량": ["grain_sack", "back"], "낟알": ["grain_sack", "back"],
	"통나무": ["twig_bundle", "shoulder"], "판자": ["twig_bundle", "shoulder"],   # (E3 소인의 세상) 통나무·판자 = 나뭇가지 다발·쪼갠 갈대 다발 (GD 3.0)
	"돌": ["stone_block", "front"], "철광석": ["stone_block", "front"], "석탄": ["stone_block", "front"], "철": ["stone_block", "front"],
	"소금": ["salt_sack", "back"], "물": ["water_bucket", "hand"],
	"생선": ["medaka", "front"],           # (E3-6 GD 3.0 · 2026-11-07 사용자) 잡는 물고기 = 송사리 (주민만 함) — 혼자면 두 팔로 안고, 같은 길을 가는 둘이면 큰 놈을 장대에 메고 (village_view 짝짓기)
	"생선:앞": ["fish_pole", "pole"], "생선:뒤": ["pole_half", "pole"],
	"과일": ["fruit_piece", "head"],        # (E3-3) 거대한 열매를 잘라 조각을 머리에 이고 (위에서 보는 카메라에 잘 보이게)
	"약초": ["herb_bundle", "hand"], "민들레 잎": ["herb_bundle", "hand"], "꽃잎": ["herb_bundle", "hand"],
	"버섯": ["mushroom_basket", "front"], "빛버섯": ["mushroom_basket", "front"], "말린 버섯": ["mushroom_basket", "front"],
	"유모차": ["pram", "push"],          # v5 (GD 7.3) 아기 산책: 땅 위를 굴러가는 나무 유모차를 두 손으로 민다 (art/src/build_pioneer.py)
}
const CARRY_GENERIC := ["bundle", "back"]
const CARRY_PROPS := ["wheat_sheaf", "flour_sack", "grain_sack", "salt_sack", "dough_bowl", "bread_basket", "loaf",
	"porridge_pot", "log", "plank_stack", "twig_bundle", "stone_block", "fish_string", "herb_bundle", "water_bucket", "mushroom_basket", "bundle", "pram",
	"medaka", "fish_pole", "pole_half", "fruit_piece"]
## 아이: 작은 것으로 바꿔 (빵 바구니 → 빵 한 덩이) 두 손으로 안는다 · 머리에 이는 건 바구니만 (어른 여자 반쯤)
const CARRY_CHILD := {"bread_basket": "loaf", "fish_pole": "medaka", "pole_half": "medaka"}
const CARRY_HEAD_OK := ["bread_basket", "mushroom_basket"]
const CARRY_SCALE := 1.12          # 기본 확대에서도 읽히게 조금 크게
const CARRY_CHILD_SCALE := 0.95
## 작은 소품은 더 크게 (손에 늘어뜨린 것은 기본 확대에서 안 읽힘)
const CARRY_PROP_SCALE := {"fish_string": 1.55, "medaka": 1.25, "fruit_piece": 1.5, "wheat_sheaf": 1.2, "flour_sack": 1.2, "salt_sack": 1.15, "grain_sack": 1.15, "bundle": 1.15, "herb_bundle": 1.5, "water_bucket": 1.15, "loaf": 1.15}
const CARRY_FAR_SCALE := 1.35
const CARRY_BOB := 0.018          # 걸음에 맞춰 짐이 통통 (칸)
## 자리 → 붙는 곳 (모델 좌표 = 칸, 쉴 자세 — 앞 = +Z, 오른쪽 = -X). A23 4등신 관절 (build_residents.py가 찍는 A23 joints)
const CARRY_SOCKET := {"front": Vector3(0, 0.57, 0.218), "shoulder": Vector3(-0.114, 0.714, -0.052), "back": Vector3(0, 0.614, -0.088),
	"head": Vector3(0, 1.01, 0.0), "hand": Vector3(-0.187, 0.39, 0.01), "push": Vector3(0, 0, 0.6),
	"pole": Vector3(-0.114, 0.76, -0.02)}
const BODY_FRONT := 0.125         # 가슴 앞면 (front 짐이 몸에 묻히지 않게)
## pole (둘이 메기): 오른 어깨 위 장대 — 앞 사람(fish_pole)은 뒤로, 뒤 사람(pole_half)은 앞으로 뻗어 POLE_GAP 사이 가운데에서 만남
const POLE_GAP := 1.352          # 둘 사이 (칸 — build_carry.py POLE_HALF × 2)
## push (유모차): 모델 원점(땅)에 붙음 — 소품 원점 = 바구니 아래 땅, 손잡이가 주민 쪽(-Z). 바퀴 부품 (굴러감)
const PRAM_SCALE := 1.3          # 유모차 크기 (손잡이가 손 높이에 오게)
const PRAM_WHEELS := {"pram_wheel_fl": 0.0676, "pram_wheel_fr": 0.0676, "pram_wheel_bl": 0.0884, "pram_wheel_br": 0.0884}   # 부품 → 반지름 (build_pioneer.py × PRAM_UNIT)
## 자리 → 팔 자세 (build_residents.py arms()와 같은 말: [윗팔 (x 앞으로 듦(-), y 옆으로 벌림, z), 팔뚝 굽힘(-)]). 빠진 팔은 살랑
const CARRY_ARMS := {
	"shoulder": {"R": [Vector3(-1.25, 0.75, 0.0), -2.1]},
	"back": {"R": [Vector3(-0.45, 0.4, 0.0), -2.55]},
	"head": {"R": [Vector3(-2.75, 0.5, 0.0), -0.45], "L": [Vector3(-2.75, -0.5, 0.0), -0.45]},
	"hand": {"R": [Vector3(0.0, 0.3, 0.0), -0.08]},
	"push": {"R": [Vector3(-0.7, 0.1, 0.0), -0.75], "L": [Vector3(-0.7, -0.1, 0.0), -0.75]},
	"pole": {"R": [Vector3(-1.25, 0.75, 0.0), -2.1]},
}
const A_OUT := 0.12                # 쉴 때 팔이 몸에서 벌어진 정도 (build_residents.py A_OUT)
## 직업(일터 종류) → 옷·연장 (A20, design/characters/jobs_a·jobs_b). hat = 모자(본디 모자 대신), over = 겉옷, robe = 긴 옷,
## tool = 일할 때 손에 드는 연장 ("-" = 빈손). 표에 없는 일터 = 망치 (짓기 · 일꾼). "" = 일자리 없음(짓는 사람).
const JOB_LOOK := {
	"농장": {"hat": "hat_straw", "tool": "tool_hoe"},
	"나무꾼": {"hat": "hat_cap", "tool": "tool_axe"},
	"산림관": {"hat": "hat_cap", "tool": "tool_axe"},
	"채석장": {"tool": "tool_pick"},
	"제재소": {"tool": "tool_hammer"},
	"소금밭": {"hat": "hat_straw", "tool": "tool_hoe"},
	"버섯꾼": {"over": "herb_bag", "tool": "tool_sickle"},
	"약초꾼": {"hat": "hat_scarf", "over": "herb_bag", "tool": "tool_herbs"},
	"어부": {"hat": "hat_fisher", "tool": "tool_rod"},          # 자리표시 (B3 — 물고기가 생기면)
	"나루터": {"hat": "hat_fisher", "tool": "-"},
	"빵집": {"hat": "hat_baker", "over": "apron_job", "tool": "tool_peel"},
	"방앗간": {"over": "apron_job", "tool": "-"},
	"치료소": {"hat": "hat_scarf", "over": "apron_job", "tool": "-"},
	"교회": {"robe": true, "tool": "-"},
	"우물": {"tool": "-"},
	"": {"tool": "tool_hammer"},
}
const DEFAULT_TOOL := "tool_hammer"
## 표정 → 얼굴 그림 칸 (art/src/paint_face_atlas.py). 앓음은 피부도 조금 핼쑥하게 (셰이더 sick)
const FACE_CELL := {"": 0, "happy": 1, "sad": 2, "sick": 3, "sleep": 4, "surprised": 5, "talking": 6}
## 동작 (resident.glb의 애니메이션 이름) — set_anim의 이름 + 나이·연장에 따라 고름 (_clip)
const ANIMS := ["idle", "walk", "walk_elder", "run", "carry", "hold", "work_axe", "work_hoe", "work_hammer", "work_hands",
	"pray", "sit", "eat", "sleep", "wave", "play", "fly",
	"look", "stretch", "scratch", "shift", "chat", "sit_talk", "fish", "crouch", "clap", "pray_stand", "bow"]
## 시뮬레이션 동작(r.anim) → 기본 클립 — 그 밖의 이름은 클립 이름 그대로 (ANIMS에 있으면)
const SIM_ANIMS := ["idle", "walk", "carry", "work", "torch", "pray", "sit", "eat", "sleep", "play", "fly", "wave", "lookup", "gather"]
## (v5) 사이사이 끼는 짧은 동작 — 기본 클립 → [[클립, 무게]]. 한 번 돌고 기본으로 돌아온다 (사람마다 다른 때에)
const VARIETY := {
	"idle": [["look", 3.0], ["shift", 3.0], ["scratch", 2.0], ["stretch", 1.0]],
	"chat": [["look", 1.0], ["shift", 1.0]],
	"sit": [["sit_talk", 1.0]],
	"sit_talk": [["sit", 1.0]],
	"play": [["clap", 1.0]],
	"clap": [["play", 1.0]],
	"hold": [["look", 1.0]],
	"pray_stand": [["bow", 1.0]],
}
const VARIETY_GAP := Vector2(3.0, 9.0)   # 기본 클립을 이만큼 (초) 튼 뒤 하나 끼움
const RATE_SPREAD := 0.08                # 사람마다 동작 빠르기 ±8%
## 연장 → 일하는 동작
const TOOL_ANIM := {"tool_axe": "work_axe", "tool_pick": "work_axe", "tool_hammer": "work_hammer", "tool_hoe": "work_hoe",
	"tool_sickle": "work_hoe", "tool_peel": "work_hands", "tool_herbs": "work_hands", "tool_rod": "fish", "-": "work_hands"}
## 연장과 상관없이 일터가 정하는 일 동작 (사냥꾼: 웅크려 살핌)
const JOB_ANIM := {"사냥꾼": "crouch"}
## 머리 부품 (셰이더: 대머리·주근깨·얼굴 그림은 이 부품에만)
const HEAD_PREFIX := ["head", "hair_", "hat_", "beard", "baby_basket"]
## 몸 부품 이름 — 팔·다리는 _L/_R 두 짝
const PAIRED := ["arm", "arm_robe", "leg_trousers", "leg_stocking"]

static var _boxes: Dictionary = {}
static var _hull: ShaderMaterial
static var _hull_bald: Dictionary = {}
static var _shader: Shader
static var _kit: Dictionary = {}          # resident.glb에서 읽은 것 (뼈 · 부품 배열 · 스킨 · 동작)
static var _merged: Dictionary = {}       # 부품 조합 → 합친 메시 (LOD마다)

var pose: Node3D                # 몸 전체 (체형 배율 · 아기 바구니 흔들림)
var skel: Skeleton3D
var arm_l: Node3D               # 왼손 자리 (뼈에 붙음 — 지팡이)
var arm_r: Node3D               # 오른손 자리 (연장 · 횃불)
var head: Node3D                # 머리 뼈에 붙은 자리
var chest: Node3D               # 가슴 뼈에 붙은 자리 (혈통 소품)
var item: Node3D                # 들고 있는 짐
var tool: Node3D                # 오른손 연장 (일할 때)
var anim := "idle"
var mat: ShaderMaterial
var look: Dictionary = {}       # parts_for 결과 (이 모델이 고른 부품)
var job_key := "?"              # 지금 입은 직업 옷 (set_job)
var face := "?"                 # 지금 표정 (set_face)
var shown_parts: Array[String] = []   # 지금 합쳐 그리는 몸 부품
var lod_close := true
var _t := 0.0
var _item_kind := ""
var _carry_style := ""          # 지금 짐 드는 자리 (CARRY_SOCKET 키, "" = 옛 소품)
var _carry_prop := ""
var _carry_close: MeshInstance3D
var _carry_far: MeshInstance3D
var _wheels: Array = []         # 유모차 바퀴 [MeshInstance3D, 반지름]
var _wheel_last := Vector3.INF  # 지난 화면의 세계 자리 (바퀴는 실제로 간 거리만큼 굴러감)
var _item_base := Vector3.ZERO
var _female := false
var _arm_bi := PackedInt32Array([-1, -1, -1, -1])   # upper_arm.R · forearm.R · upper_arm.L · forearm.L
var _tool_kind := "?"
var _job_tool := ""             # 직업 연장 (set_job이 정함, "" = set_tool의 일터 표를 따름)
var _base_scale := 1.0
var _lean := 0.0                # 혈통 표시: '겁 많음' 움츠림 / '담대' 곧은 자세 · 노인 조금 굽음
var _gait := 1.0                # 혈통 표시: '굼뜬' 느릿한 걸음걸이
var _baby := false
var _child := false
var _job := {"hat": "", "over": [], "robe": false}
var _cues := PackedStringArray()
var _close_mi: MeshInstance3D
var _far_mi: MeshInstance3D
var _player: AnimationPlayer
var _clip_now := ""
var _action := ""               # 시뮬레이션 행동 (r.action: social · rest · play …) — 같은 동작이라도 클립을 달리 고름
var _job_name := ""
var _rng := RandomNumberGenerator.new()
var _rate := 1.0                # 사람마다 조금 다른 동작 빠르기 (걸음 동작은 땅 빠르기를 따르므로 제외)
var _ground := -1.0             # 땅 위에서 움직이는 빠르기 (칸/현실 초, village_view가 move_to로 잼) — -1 = 모름
var _gpos := Vector3.INF
var _base := ""                 # 지금 기본 클립 (사이 동작이 끝나면 돌아올 것)
var _var_clip := ""             # 지금 끼어 튼 사이 동작 ("" = 없음)
var _var_left := 0.0            # 사이 동작 남은 시간 (초)
var _var_next := 0.0            # 다음 사이 동작까지 (초)
var _style := 0                 # 사람마다 정해진 버릇 (어울릴 때 말하는 쪽/듣는 쪽 · 무릎 꿇기/서서 기도 · 깡충/손뼉)
var seed_id := -1               # 주민 번호 (setup_from) — 동작 엇갈림 씨앗
var _cane: Node3D
var _post := {}                 # 동작 뒤에 덧입히는 뼈 자세 (체형 배율 · 머리 크기 · 숙임)
var _arm_aim := Vector2.INF     # 오른팔 직접 겨눔 (횃불) — 이번 화면만
var _skip := false
var _skip_dt := 0.0
var _accent := Color.WHITE      # 본디 수건·모자 색 (직업 모자가 바꿨다가 되돌림)
var _cloth_i := 0
var _day_shown := true          # 지금 합친 몸이 낮 쓰개를 반영한 것인가


## 상자 메시 (건설 현장·더미 등 village_view가 씀)
static func box_of(size: Vector3) -> BoxMesh:
	var key := "%.3f,%.3f,%.3f" % [size.x, size.y, size.z]
	if not _boxes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_boxes[key] = b
	return _boxes[key]


static func _lc(key: String) -> Color:
	return Color(Balance.LOOK_FIXED[key])


static func hull(bald := 0) -> ShaderMaterial:
	if _hull == null:
		_hull = Art.hull_mat(false, Style.RESIDENT_LINE)
		_hull.set_shader_parameter("resident", true)
	if bald == 0:
		return _hull
	if not _hull_bald.has(bald):            # 대머리 단계마다 하나 (지운 머리카락의 껍데기도 지움)
		var h := Art.hull_mat(false, Style.RESIDENT_LINE)
		h.set_shader_parameter("resident", true)
		h.set_shader_parameter("bald", bald)
		_hull_bald[bald] = h
	return _hull_bald[bald]


# ───────────────────────── 몸 에셋 (한 번만 읽음) ─────────────────────────
## {"bones": [[이름, 부모, 쉴 자세]], "parts": {부품: {arrays, tris}}, "skin": Skin, "lib": AnimationLibrary}
static func kit() -> Dictionary:
	if not _kit.is_empty():
		return _kit
	var ps := load(BODY) as PackedScene
	if ps == null:
		push_warning("ResidentModel: 몸 에셋 없음 " + BODY)
		return _kit
	var root := ps.instantiate()
	var sk := root.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var bones: Array = []
	for i in sk.get_bone_count():
		bones.append([sk.get_bone_name(i), sk.get_bone_parent(i), sk.get_bone_rest(i)])
	var bind := {}
	var parts := {}
	for mi: MeshInstance3D in sk.find_children("*", "MeshInstance3D", true, false):
		var a := mi.mesh.surface_get_arrays(0)
		var bn: PackedInt32Array = a[Mesh.ARRAY_BONES]
		var nv := (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per := bn.size() / maxi(nv, 1)
		var remap := PackedInt32Array()
		for b in mi.skin.get_bind_count():
			var bi := sk.find_bone(mi.skin.get_bind_name(b))
			remap.append(bi)
			bind[bi] = mi.skin.get_bind_pose(b)
		var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
		var bn4 := PackedInt32Array()
		var w4 := PackedFloat32Array()
		bn4.resize(nv * 4)
		w4.resize(nv * 4)
		for v in nv:
			for k in 4:
				bn4[v * 4 + k] = remap[bn[v * per + k]] if k < per else 0
				w4[v * 4 + k] = w[v * per + k] if k < per else 0.0
		var pn := String(mi.name)
		var head_part := false
		for p: String in HEAD_PREFIX:
			if pn.begins_with(p):
				head_part = true
		var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var cu := PackedFloat32Array()
		cu.resize(nv * 4)
		for v in nv:
			var q := (pos[v] - NECK) / HEAD_K if head_part else pos[v] / BODY_K
			cu[v * 4] = q.x
			cu[v * 4 + 1] = q.y
			cu[v * 4 + 2] = q.z
			cu[v * 4 + 3] = 1.0 if head_part else 0.0
		var uv2 = a[Mesh.ARRAY_TEX_UV2]
		if uv2 == null:
			uv2 = PackedVector2Array()
			uv2.resize(nv)
		parts[pn] = {"v": pos, "n": a[Mesh.ARRAY_NORMAL], "c": a[Mesh.ARRAY_COLOR], "uv": a[Mesh.ARRAY_TEX_UV], "uv2": uv2,
			"b": bn4, "w": w4, "cu": cu, "i": a[Mesh.ARRAY_INDEX], "tris": (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3}
	var skin := Skin.new()
	for i in bones.size():
		skin.add_named_bind(bones[i][0], bind.get(i, sk.get_bone_global_rest(i).affine_inverse()))
	# 동작: 길 = "Skeleton3D:뼈" (이 모델의 노드 구조), 크기 트랙은 버림 (체형 배율은 코드가 정함)
	var ap := root.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var lib := AnimationLibrary.new()
	for nm: StringName in ap.get_animation_list():
		var src := ap.get_animation(nm)
		var an := src.duplicate(true) as Animation
		for t in range(an.get_track_count() - 1, -1, -1):
			var path := an.track_get_path(t)
			var bone := path.get_concatenated_subnames()
			if an.track_get_type(t) == Animation.TYPE_SCALE_3D or (an.track_get_type(t) == Animation.TYPE_POSITION_3D and bone != "hips"):
				an.remove_track(t)
				continue
			an.track_set_path(t, NodePath("Skeleton3D:" + bone))
		an.loop_mode = Animation.LOOP_NONE if String(nm) == "RESET" else Animation.LOOP_LINEAR
		lib.add_animation(nm, an)
	root.free()
	_kit = {"bones": bones, "parts": parts, "skin": skin, "lib": lib}
	return _kit


## 몸 부품 이름 목록 (시험·표가 씀)
static func body_parts() -> Array:
	return kit().get("parts", {}).keys()


## 부품 조합 → 메시 하나 (뼈 무게 · 색 · 얼굴 UV · CUSTOM1). 같은 조합은 공유
static func merged(names: Array, far: bool) -> ArrayMesh:
	var key := ("F|" if far else "C|") + "|".join(names)
	if _merged.has(key):
		return _merged[key]
	var parts: Dictionary = kit().get("parts", {})
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var b := PackedInt32Array()
	var w := PackedFloat32Array()
	var cu := PackedFloat32Array()
	var ix := PackedInt32Array()
	for nm: String in names:
		var p: Dictionary = parts.get(nm + ("__far" if far else ""), parts.get(nm, {}))
		if p.is_empty():
			continue
		var base := v.size()
		v.append_array(p["v"])
		n.append_array(p["n"])
		c.append_array(p["c"])
		uv.append_array(p["uv"])
		uv2.append_array(p["uv2"])
		b.append_array(p["b"])
		w.append_array(p["w"])
		cu.append_array(p["cu"])
		var pi: PackedInt32Array = p["i"]
		var off := ix.size()
		ix.append_array(pi)
		for k in range(off, ix.size()):
			ix[k] += base
	var am := ArrayMesh.new()
	if not v.is_empty():
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_BONES] = b
		arr[Mesh.ARRAY_WEIGHTS] = w
		arr[Mesh.ARRAY_CUSTOM1] = cu
		arr[Mesh.ARRAY_INDEX] = ix
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	_merged[key] = am
	return am


## 부품 조합의 삼각형 수 (시험 · 예산)
static func tris_of(names: Array, far: bool) -> int:
	var parts: Dictionary = kit().get("parts", {})
	var t := 0
	for nm: String in names:
		t += int(parts.get(nm + ("__far" if far else ""), parts.get(nm, {})).get("tris", 0))
	return t


# ───────────────────────── 겉모습 고르기 (데이터) ─────────────────────────
## 주민 데이터에서 — 7단계: 머리색·피부·눈·머리결·주근깨·대머리·점박이는 겉모습 유전자(Genetics), 체형·소품은 혈통 표시(Bloodlines)
func setup_from(r: Resident) -> void:
	seed_id = r.id
	build_look(look_of(r))


## 겉모습 사전 — 겉모습 칸만 (능력치·특징·숙련·건강은 넣지 않는다: 생김새가 능력을 드러내지 않게)
static func look_of(r: Resident) -> Dictionary:
	return {"head": r.look_head, "clothes": r.look_clothes, "hat": r.look_hat, "hair_i": r.look_hair, "skin_i": r.look_skin,
		"cloth": r.look_cloth, "age": r.age, "sex": r.sex, "genes": r.genes, "blood": r.blood, "era": village_era}


## 모델을 다시 만들어야 하는 겉모습 단계 (나이 단계 · 대머리 단계 · 흰머리 단계)
static func look_key(r: Resident) -> int:
	var st := (0 if r.is_baby() else (1 + int(r.age) if r.is_child() else (10 if r.is_adult() else 11))) + mini(village_era, 2) * 1000
	if r.genes.size() < Genetics.MIN_BYTES:
		return st
	var early := "silver_early" in Bloodlines.looks(r.blood)
	return st * 100 + Genetics.bald_stage(r.genes, r.sex, r.age) * 10 + int(Genetics.grey(r.age, early) * 4.0)


## 지금 표정 — 잠 · 앓음(다침) · 말함(말풍선) · 놀람(큰 두려움) · 슬픔(기분 낮음·두려움) · 기쁨(기분 높음·놀이) · 보통 ""
static func face_of(r: Resident) -> String:
	if r.anim == "sleep" or r.sleeping:
		return "sleep"
	if r.is_sick() or r.is_injured():
		return "sick"
	if r.say != "" and r.say_t > 0.0:
		return "talking"
	if r.fear > 0.85:
		return "surprised"
	if r.happiness < 0.3 or r.fear > 0.6:
		return "sad"
	if r.happiness > 0.8 or r.anim == "play":
		return "happy"
	return ""


## 예전 방식 (유전자 없이 색 번호로) — 도구·시험 장면용: head 0~1, clothes 0~1, hat 0~2 (0 = 없음), 색 번호는 Balance 색표.
func build(head_i: int, clothes_i: int, hat_i: int, hair_i: int, skin_i: int, cloth_i: int, age := 10.0, sex := "m") -> void:
	build_look({"head": head_i, "clothes": clothes_i, "hat": hat_i, "hair_i": hair_i, "skin_i": skin_i, "cloth": cloth_i, "age": age, "sex": sex})


## 머리 모양 부품: 길이(look_head) × 성별 × 머리결(직모·웨이브·곱슬) × 차림 취향 씨앗(sty, 유전 아님)
## (A20 2차) 짧은 머리 · 바싹 깎은 머리 · 단발 · 하나로 묶은 머리 · 양쪽 올림머리 더함. sty < 0 = 예전 표 그대로
static func hair_part(head_i: int, sex: String, curl: int, sty := -1, child := false) -> String:
	var long := head_i % HAIR_BY_LOOK.size() == 1
	var k := (sty >> 1) % 6 if sty >= 0 else -1
	if curl >= 2:
		return "hair_curly_long" if long else "hair_curly"
	if curl == 1:
		if long:
			return "hair_pony" if sex == "f" and k == 0 else "hair_wave_long"
		if sex == "m":
			return "hair_crop" if k == 1 or k == 4 else "hair_wave"
		return "hair_bob" if k == 2 or k == 5 else "hair_bun"
	if k < 0:
		return HAIR_BY_LOOK[head_i % HAIR_BY_LOOK.size()][1 if sex == "f" else 0]
	if sex == "m":
		if long:
			return ["hair_long", "hair_pony", "hair_long", "hair_bob", "hair_long", "hair_pony"][k] if not child else "hair_bob"
		return ["hair_short", "hair_crop", "hair_short", "hair_crop", "hair_short", "hair_bob"][k]
	if long:
		return ["hair_long", "hair_braids", "hair_pony", "hair_braids", "hair_long", "hair_pony"][k]
	if child:
		return ["hair_twinbuns", "hair_bob", "hair_twinbuns", "hair_bun", "hair_bob", "hair_twinbuns"][k]
	return ["hair_bun", "hair_bob", "hair_twinbuns", "hair_bun", "hair_bob", "hair_bun"][k]


## 체형 3종 — 겉모습 유전자 '체격' (없으면 색 번호로). 혈통 '깡마름·호리호리' = 호리호리, '배불뚝이' = 둥근
static func body_type(lk: Dictionary) -> int:
	var cues: PackedStringArray = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	if "belly" in cues:
		return 2
	if "skinny" in cues or "slender" in cues:
		return 0
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	var b := 0.5
	if g.size() >= Genetics.MIN_BYTES:
		b = Genetics.build_v(g)
	else:
		b = float((int(lk.get("cloth", 0)) * 3 + int(lk.get("hair_i", 0))) % 5) / 4.0
	return 0 if b < 0.3 else (2 if b > 0.72 else 1)


## 겉모습 사전 → 고른 부품 (데이터만, 메시 없음 — 시험이 씀). 같은 사전이면 늘 같은 결과 (난수 없음)
static func parts_for(lk: Dictionary) -> Dictionary:
	var head_i: int = lk.get("head", 0)
	var clothes_i: int = lk.get("clothes", 0)
	var hat_i: int = lk.get("hat", 0)
	var hair_i: int = lk.get("hair_i", 0)
	var skin_i: int = lk.get("skin_i", 0)
	var cloth_i: int = lk.get("cloth", 0)
	var age: float = lk.get("age", 10.0)
	var sex: String = lk.get("sex", "m")
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	var cues: PackedStringArray = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	var has_g := g.size() >= Genetics.MIN_BYTES
	var curl := Genetics.curl(g) if has_g else 0
	var sty := Genetics.style(g) if has_g else -1
	var era := mini(int(lk.get("era", 0)), 2)
	var child := age < Balance.AGE_ADULT
	var cl: Dictionary = CLOTHES[clothes_i % CLOTHES.size()]
	var hat: String = HATS[hat_i % HATS.size()]
	if "straw_hat" in cues or "brim_hat" in cues:
		hat = "hat_straw"
	var cap: bool = hat == "" and sex == "m" and age >= Balance.AGE_ADULT and (hair_i + cloth_i) % 3 == 0 and not lk.get("no_cap", false)
	if cap:
		hat = CAP_HAT
	var hair := hair_part(head_i, sex, curl, sty, child)
	if hat == "hat_scarf" and hair in SCARF_HIDES:
		hair = ""                                   # 수건 밑에 다 들어감
	var elder := age >= Balance.AGE_ELDER
	# A20 v4: 남자 어른 일부는 튜닉 두건을 목에 접어 둠 (base_c) — 겉모습 유전자 무늬 칸에서 (없으면 색 번호)
	var hood_v: int = g[Genetics.PATTERN] if g.size() >= Genetics.MIN_BYTES else hair_i + skin_i * 2 + 1
	var hood: bool = sex == "m" and age >= Balance.AGE_ADULT and not elder and clothes_i % CLOTHES.size() == 0 and hood_v % 3 == 0
	# (A20 2차) 소인의 옷 · 꾸밈 — 시대 × 차림 취향 씨앗 (유전자가 없으면 색 번호에서)
	var sv: int = sty if sty >= 0 else (hair_i * 37 + cloth_i * 11 + skin_i * 5) % 256
	var roll := func(slot: int, table: Array) -> bool: return posmod(hash([sv, slot, 77]), 10) < int(table[era])
	var torso: String = cl["torso"]
	if torso == "torso_dress" and roll.call(0, ERA_PETAL):
		torso = "torso_petal"
	var acc: Array[String] = []
	var cape: bool = not elder and not hood and roll.call(4, ERA_CAPE)
	if cape:
		acc.append("cape_leaf")
	elif not elder and roll.call(2, ERA_SCARF):
		acc.append("acc_scarf")
	if torso == "torso_tunic" and not child and roll.call(1, ERA_BUTTONS):
		acc.append("buttons_seed")
	if hat == "" and not cap and roll.call(3, ERA_ACORN):
		hat = "hat_acorn"
	var day_hat := ""
	if (hat == "" or hat == "hat_acorn") and not cap and roll.call(6, ERA_DAY_HAT):
		day_hat = DAY_HATS[posmod(hash([sv, 11]), DAY_HATS.size())]
	var flower_ok: bool = (sex == "f" or child) and (hat == "" or hat == "hat_scarf") and roll.call(5, ERA_FLOWER)
	if flower_ok:
		acc.append(FLOWERS[posmod(hash([sv, 9]), FLOWERS.size())])
	var fsh := 0
	if "round_face" in cues:
		fsh = 0
	elif has_g:
		fsh = Genetics.face_shape(g)
	else:
		fsh = (skin_i + cloth_i) % FACE_SHAPES.size()
	return {"hood": hood, "baby": age < Balance.AGE_BABY, "torso": torso, "leg": cl["leg"], "arm": "arm", "hair": hair, "hat": hat,
		"cap": cap, "beard": sex == "m" and age >= 8.0 and (hair_i + skin_i) % 3 == 0,
		"face_shape": fsh, "body": body_type(lk), "acc": acc, "era": era, "sv": sv, "day_hat": day_hat,
		"elder": elder, "shawl": (hair_i + cloth_i + skin_i) % SHAWL_COLORS.size() if elder else -1}


## 이 사람의 옷 색 · 덧옷(잎 망토·목수건·노인 숄) 색 — 시대 · 꽃잎 치마 · 색 번호 (3D와 초상화가 같이 씀)
static func outfit_colors(lk: Dictionary, p: Dictionary) -> Dictionary:
	var cloth_i: int = lk.get("cloth", 0)
	var sv: int = p.get("sv", 0)
	var era: int = p.get("era", 0)
	var pal: Array = ERA_CLOTH[era]
	var cloth := Color(pal[cloth_i % pal.size()])
	if p.get("torso", "") == "torso_petal":
		cloth = Color(PETAL_COLORS[(cloth_i + sv) % PETAL_COLORS.size()])
	var over := Color(SHAWL_COLORS[maxi(int(p.get("shawl", -1)), 0)])
	var acc: Array = p.get("acc", [])
	if "cape_leaf" in acc:
		over = Color(LEAF_COLORS[(sv >> 3) % LEAF_COLORS.size()])
	elif "acc_scarf" in acc:
		over = Color(SCARF_COLORS[(sv + cloth_i) % SCARF_COLORS.size()])
	return {"cloth": dye(cloth), "over": dye(over)}


## 직업 옷 (일터 종류 · 촌장) → {hat, over[], robe, tool}
static func job_look(job: String, chief := false) -> Dictionary:
	var j: Dictionary = JOB_LOOK.get(job, {})
	var over: Array = []
	if j.has("over"):
		over.append(j["over"])
	if chief:
		over.append("sash")
	return {"hat": j.get("hat", ""), "over": over, "robe": j.get("robe", false), "tool": j.get("tool", DEFAULT_TOOL)}


## 머리 위를 덮는 모자(납작모자·털모자·빵 모자·수건)를 쓰면 곱슬머리는 정수리 곱슬을 뺀 부품(_under)으로, 올림머리는 짧은 머리로
const CROWN_HATS := ["hat_cap", "hat_fisher", "hat_baker", "hat_scarf", "hat_acorn", "hat_cone", "hat_kerchief"]
const KERCHIEFS := ["hat_scarf", "hat_kerchief"]
## 수건을 쓰면 다 들어가는 머리 · 정수리 모자 밑에선 짧은 머리로 바꾸는 머리 (올림머리)
const SCARF_HIDES := ["hair_bun", "hair_short", "hair_crop", "hair_twinbuns"]
const CROWN_SHORT := ["hair_bun", "hair_twinbuns"]


## 지금 그릴 몸 부품 (겉모습 + 직업 옷) — 데이터만
static func body_list(lk_parts: Dictionary, job: Dictionary, cues := PackedStringArray(), day := false) -> Array[String]:
	var out: Array[String] = []
	if lk_parts.get("baby", false):
		out.append("baby_basket")
		return out
	var robe: bool = job.get("robe", false)
	for side in ["_L", "_R"]:
		out.append(str(lk_parts["leg"]) + side)
		out.append(("arm_robe" if robe else "arm") + side)
	out.append("torso_robe" if robe else str(lk_parts["torso"]))
	if lk_parts.get("hood", false) and not robe:
		out.append("hood")
	out.append("head")
	var hat: String = job.get("hat", "")
	if hat == "":
		hat = lk_parts.get("hat", "")
		if day and lk_parts.get("day_hat", "") != "" and (hat == "" or hat == "hat_acorn"):
			hat = lk_parts["day_hat"]
	var hair: String = lk_parts.get("hair", "")
	if hat in KERCHIEFS and hair in SCARF_HIDES:
		hair = ""
	if hat in CROWN_HATS:
		if hair.begins_with("hair_curly"):
			hair += "_under"
		elif hair in CROWN_SHORT:
			hair = "hair_short"
	if hair != "":
		out.append(hair)
	if lk_parts.get("beard", false):
		out.append("beard")
	if hat != "":
		out.append(hat)
	if "apron" in cues and str(lk_parts["torso"]) == "torso_tunic" and not robe:
		out.append("apron_job")
	# (A20 2차) 꾸밈: 잎 망토 · 목수건 · 씨앗 단추 · 꽃 (긴 옷엔 망토·단추 없음, 모자를 쓰면 꽃 없음)
	for a: String in lk_parts.get("acc", []):
		if robe and a in ["cape_leaf", "buttons_seed"]:
			continue
		if a.begins_with("acc_flower") and hat != "" and not hat in KERCHIEFS:
			continue
		if a == "buttons_seed" and "apron_job" in job.get("over", []):
			continue
		out.append(a)
	for o: String in job.get("over", []):
		if not o in out:
			out.append(o)
	if lk_parts.get("elder", false):
		out.append("shawl")
	return out


const PB_FREQ := [2.2, 2.8, 3.4, 4.0, 4.6, 5.2]     # 점박이 무늬 6종 (크기)
const PB_CUT := [0.6, 0.63, 0.58, 0.64, 0.6, 0.62]


# ───────────────────────── 만들기 ─────────────────────────
func _space(bone: String) -> Node3D:
	## 뼈에 붙은 자리 — 자식 좌표 = 모델 좌표 (쉴 자세 기준)
	var at := BoneAttachment3D.new()
	at.bone_name = bone
	skel.add_child(at)
	var sp := Node3D.new()
	var bi := skel.find_bone(bone)
	if bi >= 0:
		sp.transform = skel.get_bone_global_rest(bi).affine_inverse()
	at.add_child(sp)
	return sp


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


static func origin(part: String) -> Vector3:
	return Art.parts(PARTS).get(part, {}).get("origin", Vector3.ZERO)


## 소품 메시 (짐·연장·지팡이 — 주민 재질, 고정 색)
func _mesh(parent: Node3D, part: String) -> MeshInstance3D:
	var p: Dictionary = Art.parts(PARTS).get(part, {})
	if p.is_empty() or p["mesh"] == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = p["mesh"]
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## 혈통 표시용 작은 소품 (한 가지 색 툰 재질)
func _prop(parent: Node3D, m: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = Toon.mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _cyl(r: float, h: float) -> CylinderMesh:
	var key := "cyl%.3f,%.3f" % [r, h]
	if not _boxes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = h
		c.radial_segments = 8
		c.rings = 1
		_boxes[key] = c
	return _boxes[key]


## 겉모습 사전으로 만들기 — 키: head clothes hat hair_i skin_i cloth age sex (+ genes blood)
func build_look(lk: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	look = parts_for(lk)
	job_key = "?"
	face = "?"
	_job = {"hat": "", "over": [], "robe": false}
	_job_tool = ""
	_clip_now = ""
	_base = ""
	_var_clip = ""
	_rng.seed = hash([seed_id if seed_id >= 0 else get_instance_id(), lk.get("hair_i", 0), lk.get("cloth", 0)])
	_rate = 1.0 + _rng.randf_range(-RATE_SPREAD, RATE_SPREAD)
	_style = _rng.randi() % 6
	_var_next = _rng.randf_range(0.5, VARIETY_GAP.y)
	_post = {}
	var hair_i: int = lk.get("hair_i", 0)
	var skin_i: int = lk.get("skin_i", 0)
	var cloth_i: int = lk.get("cloth", 0)
	var age: float = lk.get("age", 10.0)
	var sex: String = lk.get("sex", "m")
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	_cues = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	var has_g := g.size() >= Genetics.MIN_BYTES
	var cue := func(n: String) -> bool: return n in _cues
	# 색 (유전자가 있으면 유전자에서, 없으면 예전 색표)
	var tones := tones_of(lk)
	var skin: Color = tones["skin"]
	var hair: Color = tones["hair"]
	var eye_a := Style.EYE_DOT                # A23: 모든 주민의 점 눈은 같은 짙은 값 (아트 바이블 5.7)
	var eye_b := eye_a
	var bald := 0
	if has_g:
		bald = Genetics.bald_stage(g, sex, age)
	var cheek := Color(Genetics.CHEEK)
	if cue.call("pale"):
		skin = skin.lerp(Color(Genetics.PALE), 0.35)
		cheek = skin.lerp(cheek, 0.35)
	if cue.call("red_cheeks"):
		cheek = Color(Genetics.CHEEK_RED)
	var oc := outfit_colors(lk, look)
	var cloth: Color = oc["cloth"]
	var accent := _lc("scarf_a") if (cloth_i + hair_i) % 2 == 0 else _lc("scarf_b")
	if look["cap"]:
		accent = Color(Balance.CLOTH_COLORS[(cloth_i + 3) % Balance.CLOTH_COLORS.size()]).darkened(0.15)
	accent = dye(accent)
	_accent = accent
	_cloth_i = cloth_i
	if _shader == null:
		_shader = load("res://render/resident.gdshader")
	mat = ShaderMaterial.new()
	mat.shader = _shader
	Toon._light(mat)
	mat.set_shader_parameter("view_fill", Style.VIEW_FILL)
	mat.set_shader_parameter("cloth", cloth)
	mat.set_shader_parameter("skin", skin)
	mat.set_shader_parameter("hair", hair)
	mat.set_shader_parameter("accent", accent)
	mat.set_shader_parameter("eye_l", eye_a)
	mat.set_shader_parameter("eye_r", eye_b)
	mat.set_shader_parameter("cheek", cheek)
	mat.set_shader_parameter("bald", bald)
	mat.set_shader_parameter("barefoot", 1.0 if cue.call("barefoot") else 0.0)
	mat.set_shader_parameter("face_tex", load(FACE_TEX))
	mat.set_shader_parameter("hair_tex", load(HAIR_TEX))
	mat.set_shader_parameter("cloth_tex", load(CLOTH_TEX))
	mat.set_shader_parameter("blink_seed", fposmod(float(hair_i * 7 + skin_i * 13 + cloth_i * 3) * 0.137 + age * 0.31, 1.0))
	mat.set_shader_parameter("messy", 1.0 if cue.call("messy_hair") else 0.0)
	mat.set_shader_parameter("shawl", oc["over"])          # 노인 숄 · 잎 망토 · 목수건 (한 사람에 하나)
	if has_g:
		mat.set_shader_parameter("freckles", Genetics.freckle_amount(g))
		mat.set_shader_parameter("freckle_col", skin.lerp(Color(Genetics.FRECKLE), 0.75))
		mat.set_shader_parameter("forelock", 1.0 if Genetics.forelock(g) else 0.0)
		if Genetics.piebald(g):
			var sd: int = g[Genetics.PATTERN]
			mat.set_shader_parameter("piebald", 1.0)
			mat.set_shader_parameter("pb_pattern", Vector4((sd * 37 % 101) / 10.0, (sd * 53 % 97) / 10.0, (sd * 71 % 89) / 10.0, PB_FREQ[sd % 6]))
			mat.set_shader_parameter("pb_cut", PB_CUT[sd % 6])
			mat.set_shader_parameter("pb_skin", Color(Genetics.PIEBALD_SKIN))
			mat.set_shader_parameter("pb_hair", Color(Genetics.PIEBALD_HAIR))
	mat.next_pass = hull(bald)
	# 체형: 키·체격 (연속값) → 몸 전체 배율 · 체형 3종 + 혈통 어깨 → 가슴·치마 뼈 배율
	var bw := 1.0
	var hh := 1.0
	if has_g and age >= Balance.AGE_BABY:
		bw = 0.95 + 0.1 * Genetics.build_v(g)
		hh = 0.94 + 0.12 * Genetics.height(g)
	var shoulder := 1.0
	if cue.call("broad_shoulders"):
		shoulder = 1.18
	elif cue.call("narrow_shoulders"):
		shoulder = 0.88
	var bs: Vector3 = BODY_SCALE[look["body"]]
	_lean = 0.2 if cue.call("hunched") else (-0.05 if cue.call("upright") else (0.2 if look["elder"] else 0.0))
	_gait = 0.7 if cue.call("slow_gait") else (0.85 if look["elder"] else 1.0)
	_baby = look["baby"]
	_child = age < Balance.AGE_ADULT and not _baby
	pose = _pivot(self, Vector3.ZERO)
	pose.scale = Vector3(bw, hh, bw)
	# 뼈대
	var k := kit()
	skel = Skeleton3D.new()
	skel.name = "Skeleton3D"
	pose.add_child(skel)
	for b: Array in k.get("bones", []):
		var i := skel.add_bone(b[0])
		if int(b[1]) >= 0:
			skel.set_bone_parent(i, b[1])
		skel.set_bone_rest(i, b[2])
	skel.reset_bone_poses()
	_close_mi = MeshInstance3D.new()
	_far_mi = MeshInstance3D.new()
	for mi: MeshInstance3D in [_close_mi, _far_mi]:
		mi.skin = k.get("skin")
		mi.material_override = mat
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
	_player = AnimationPlayer.new()
	pose.add_child(_player)
	_player.root_node = NodePath("..")
	if k.has("lib"):
		_player.add_animation_library("", k["lib"])
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# 뼈에 붙은 자리
	arm_r = _space("hand.R")
	arm_l = _space("hand.L")
	head = _space("skull")
	chest = _space("chest")
	item = _pivot(chest, origin("item_log"))
	item.visible = false
	_carry_style = ""
	_carry_prop = ""
	_carry_close = null
	_carry_far = null
	_female = sex == "f"
	for j in 4:
		_arm_bi[j] = skel.find_bone(["upper_arm.R", "forearm.R", "upper_arm.L", "forearm.L"][j])
	tool = _pivot(arm_r, origin("tool_axe"))
	tool.visible = false
	_item_kind = ""
	_tool_kind = "?"
	_cane = null
	set_lod(lod_close)
	if _baby:
		# 아기: 강보에 싸여 바구니 안 (design/characters/base_c)
		_base_scale = 1.1
		mat.set_shader_parameter("face_cell", FACE_CELL["sleep"])
		_refresh_body()
		scale = Vector3.ONE * _base_scale * Style.RESIDENT_SCALE
		return
	if look["elder"]:                       # 노인: 숄(몸 부품) + 지팡이 (base_c)
		_cane = _pivot(arm_l, origin("cane"))
		_mesh(_cane, "cane")
	# 혈통 소품 (모델 좌표: +Z 앞, y 위 — 가슴 뼈를 따라 움직임)
	var front := 0.14
	if cue.call("amulet"):
		_prop(chest, box_of(Vector3(0.042, 0.052, 0.016)), Style.WOOD, Vector3(0, 0.6, front + 0.005))
		_prop(chest, box_of(Vector3(0.008, 0.083, 0.008)), Style.WOOD_DARK, Vector3(0, 0.65, front - 0.016), Vector3(0.3, 0, 0))
	if cue.call("neck_scarf"):
		_prop(chest, _cyl(0.085, 0.042), _lc("scarf_b"), Vector3(0, 0.7, 0.0))
	if cue.call("cloak"):
		_prop(chest, box_of(Vector3(0.34, 0.46, 0.026)), Color("7a6650"), Vector3(0, 0.46, -0.155), Vector3(0.12, 0, 0))
	if cue.call("pipe"):
		_prop(chest, _cyl(0.013, 0.166), Style.WOOD_DARK, Vector3(0.168 * shoulder, 0.39, 0.084), Vector3(0.4, 0, 0.3))
	if cue.call("staff") and not look["elder"]:
		var sp := _prop(arm_l, _cyl(0.018, 0.91), Style.WOOD, origin("cane") + Vector3(0, 0.13, 0.02))
		_prop(sp, box_of(Vector3(0.052, 0.052, 0.052)), Style.WOOD_DARK, Vector3(0, 0.458, 0))
	if cue.call("bandage"):
		_prop(arm_r, box_of(Vector3(0.068, 0.042, 0.068)), Color("f2efe6"), origin("tool_axe") + Vector3(0, 0.104, 0))
	# 뼈 자세 덧입히기 (동작 뒤 매번): 체형 · 어깨 · 팔다리 굵기 · 머리 크기
	var hs := 1.0
	if _child:                              # 아이: 키 약 0.7 · 약 3등신 (머리는 어른의 약 85~90%) — 아트 바이블 5.2
		_base_scale = 0.62 + 0.08 * clampf((age - 1.0) / 3.0, 0.0, 1.0)
		hs = 1.27
	elif look["elder"]:                     # 노인: 0.95 + 지팡이 + 숙임
		_base_scale = 0.95
	else:
		_base_scale = 1.0
	var fs: Vector3 = FACE_SHAPES[look["face_shape"]]
	if cue.call("round_face"):
		fs = Vector3(1.08, 0.97, 1.02)
	_post = {
		"chest": Vector3(bs.x * shoulder, 1.0, bs.z), "skirt": Vector3(bs.x, 1.0, bs.z),
		"skull": Vector3(hs * fs.x / bw, hs * fs.y / hh, hs * fs.z / bw),
		"arm_dx": ARM_X * (maxf(bs.x * shoulder, 1.0) - 1.0) * 0.9, "leg_dx": LEG_X * (maxf(bs.x, 1.0) - 1.0),
		"thick_arms": cue.call("thick_arms"), "slim_legs": cue.call("slim_legs")}
	set_face("")
	_refresh_body()
	scale = Vector3.ONE * _base_scale * Style.RESIDENT_SCALE


## A23 피부·머리 색 — 아트 바이블 5.7의 8단계 (S1~S8 · H1~H8). 유전자에서 (없으면 옛 색 번호를 가까운 단계로).
## 3D와 초상화(PortraitComposer.colors · FaceIcon)가 같이 씀. 흰머리 = 반백 → 따뜻한 회백 H8 (은백 없음)
const OLD_SKIN_STEP := [2, 1, 3, 5]                    # Balance.SKIN_COLORS 4가지 → S 단계
const OLD_HAIR_STEP := [1, 0, 6, 4, 6, -1, 2, 0]       # Balance.HAIR_COLORS 8가지 → H 단계 (-1 = 반백)


static func skin_step(g: PackedByteArray, tanned := false) -> int:
	var n := Style.SKIN_RAMP.size()
	var st := clampi(int(Genetics.skin(g) * n), 0, n - 1)
	return mini(st + 1, n - 1) if tanned else st


static func hair_base(g: PackedByteArray) -> Color:
	var d := Genetics.darkness(g)
	var red := Genetics.red(g)
	var i := 0
	match d:
		0:
			i = 5 if red else 0
		1:
			i = 3 if red else (1 if maxi(g[Genetics.DARK], g[Genetics.DARK + 1]) <= 1 else 2)
		_:
			i = 4 if red else 6
	return Color(Style.HAIR_RAMP[i])


## 나이 든 머리: 반백을 거쳐 따뜻한 회백 (grey 0~0.85)
static func greyed(c: Color, gr: float) -> Color:
	if gr <= 0.0:
		return c
	var t := clampf(gr / 0.85, 0.0, 1.0)
	if t < 0.5:
		return c.lerp(Style.HAIR_GREY_MID, t * 2.0)
	return Style.HAIR_GREY_MID.lerp(Color(Style.HAIR_RAMP[7]), (t - 0.5) * 2.0)


static func tones_of(lk: Dictionary) -> Dictionary:
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	var cues: PackedStringArray = Bloodlines.looks(lk.get("blood", PackedStringArray()))
	var age: float = lk.get("age", 10.0)
	var skin: Color
	var hair: Color
	if g.size() >= Genetics.MIN_BYTES:
		skin = Color(Style.SKIN_RAMP[skin_step(g, "tanned" in cues)])
		hair = greyed(hair_base(g), Genetics.grey(age, "silver_early" in cues))
	else:
		skin = Color(Style.SKIN_RAMP[OLD_SKIN_STEP[int(lk.get("skin_i", 0)) % OLD_SKIN_STEP.size()]])
		var hi: int = OLD_HAIR_STEP[int(lk.get("hair_i", 0)) % OLD_HAIR_STEP.size()]
		hair = Style.HAIR_GREY_MID if hi < 0 else Color(Style.HAIR_RAMP[hi])
		if age >= Balance.AGE_ELDER:
			hair = Color(Style.HAIR_RAMP[7])
	return {"skin": skin, "hair": hair}


## 옷 물감 (꽃물 공식의 상한): 채도 ≤ DYE_SAT_MAX, 명도 DYE_VAL 안 — 크림 어깨띠가 늘 먼저 읽히고 짙은 색은 신발·허리띠에만
static func dye(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(c.s * 0.85, Style.DYE_SAT_MAX), clampf(c.v * 1.08, Style.DYE_VAL.x, Style.DYE_VAL.y))


## 낮인가 (머리쓰개 문화) — 병 안의 시각(시)
static func is_hat_time(hour: float) -> bool:
	return hour >= DAY_HOURS.x and hour < DAY_HOURS.y


## 짙은 눈 색: 유전자 색의 빛깔은 남기고 밝기는 낮게 (멀리서도 또렷한 점 눈)
static func _eye_col(c: Color) -> Color:
	var v := clampf(c.v, 0.0, 1.0)
	return Color.from_hsv(c.h, minf(c.s * 0.9 + 0.1, 1.0), minf(0.12 + v * 0.3, 0.38))


## 지금 부품 목록으로 메시를 다시 합침 (같은 조합은 공유)
func _refresh_body() -> void:
	_day_shown = daylight
	shown_parts = body_list(look, _job, _cues, daylight)
	if _close_mi != null:
		_close_mi.mesh = merged(shown_parts, false)
		_far_mi.mesh = merged(shown_parts, true)


## 가까이 LOD(초상화·확대) / 멀리 LOD(마을 기본 확대)
func set_lod(close: bool) -> void:
	lod_close = close
	if _close_mi != null:
		_close_mi.visible = close
		_far_mi.visible = not close
	if _carry_close != null:
		_carry_close.visible = close
		_carry_far.visible = not close


## 직업 옷 (일터 종류 · 촌장 띠) — 바뀔 때만 몸 메시를 다시 고른다. 아기는 그대로.
func set_job(job: String, chief := false) -> void:
	var key := "%s|%s" % [job, chief]
	if key == job_key or pose == null:
		return
	job_key = key
	if _baby:
		return
	var jl := job_look(job, chief)
	_job = jl
	# 직업 모자 색: 납작모자 = 옷 색 짙게 (나무꾼 갈색 모자) · 털모자 = 물빛 회청 · 그 밖 = 본디 수건 색
	var hat: String = jl["hat"]
	var ac := _accent
	if hat == "hat_cap":
		ac = dye(Color(Balance.CLOTH_COLORS[(_cloth_i + 1) % Balance.CLOTH_COLORS.size()]).darkened(0.2))
	elif hat == "hat_fisher":
		ac = dye(Color("5f7d92"))
	if mat != null:
		mat.set_shader_parameter("accent", ac)
	_job_tool = jl["tool"]
	_job_name = job
	_tool_kind = "?"
	_refresh_body()


## 표정: "" 보통 · happy · sad · sick · sleep · surprised · talking (얼굴 그림 칸, 앓으면 피부를 조금 핼쑥하게)
## [B7] 잠복 중인 병 — 창백한 얼굴빛 (피부색을 창백 쪽으로). 바뀔 때만
var _pale := false
var _skin_base := Color.WHITE


func set_pale(on: bool) -> void:
	if on == _pale or mat == null:
		return
	_pale = on
	if on:
		_skin_base = mat.get_shader_parameter("skin")
		mat.set_shader_parameter("skin", _skin_base.lerp(Color(Genetics.PALE), 0.6).lerp(Color("d3dccb"), 0.45))     # 핏기 없는 잿빛 연두
	else:
		mat.set_shader_parameter("skin", _skin_base)


func set_face(f: String) -> void:
	if f == face or mat == null or _baby:
		return
	if not FACE_CELL.has(f):
		f = ""
	face = f
	mat.set_shader_parameter("face_cell", FACE_CELL[f])
	mat.set_shader_parameter("sick", 1.0 if f == "sick" else 0.0)


## (A22) 짐 이름 → [소품, 드는 자리, 크기]. child = 아이 (작은 것을 두 손으로), head = 머리에 일 수 있는 사람 (바구니만)
static func carry_spec(kind: String, child := false, head_ok := false) -> Array:
	var e: Array = CARRY.get(kind, CARRY_GENERIC)
	var prop: String = e[0]
	var style: String = e[1]
	if child:
		prop = CARRY_CHILD.get(prop, prop)
		return [prop, "front", CARRY_CHILD_SCALE * float(CARRY_PROP_SCALE.get(prop, 1.0))]
	if head_ok and prop in CARRY_HEAD_OK:
		style = "head"
	return [prop, style, CARRY_SCALE * float(CARRY_PROP_SCALE.get(prop, 1.0))]


## 소품 메시 사전 (없으면 빈 사전) — {"mesh", "far"}
static func carry_parts(prop: String) -> Dictionary:
	if not Art.exists("carry/" + prop):
		return {}
	var ps := Art.parts("carry/" + prop)
	if not ps.has(prop):
		return {}
	return {"mesh": ps[prop].get("mesh"), "far": ps.get(prop + "__far", {}).get("mesh")}


## 자리 → 소품 돌림 (긴 것은 어깨 위에서 앞뒤로 눕힘, 자루는 오른 어깨 쪽으로 기울여 등에)
static func carry_basis(prop: String, style: String) -> Basis:
	match style:
		"shoulder":
			# 앞뒤로 눕히면 위에서 보는 카메라에 얼굴을 가림 → 오른쪽 뒤로 비스듬히 (끝(+X, 밀 이삭)이 오른쪽 뒤로)
			return Basis(Vector3.UP, 2.3) * Basis(Vector3.BACK, 0.35 if prop == "wheat_sheaf" else 0.18)
		"back":
			return Basis(Vector3.RIGHT, -0.2) * Basis(Vector3.BACK, 0.32)
		"hand":
			return Basis(Vector3.UP, 0.5)
		"head":
			return Basis(Vector3.UP, 0.4)
	return Basis.IDENTITY


## 들고 있는 짐 (A22): 소품을 자리(뼈)에 붙이고 크기·돌림을 맞춤. 바뀔 때만 (매 화면 할당 없음)
func set_item(kind: String) -> void:
	if kind == _item_kind or item == null:
		return
	_item_kind = kind
	for c in item.get_children():
		item.remove_child(c)
		c.queue_free()
	_carry_close = null
	_carry_far = null
	_carry_style = ""
	_carry_prop = ""
	_wheels.clear()
	_wheel_last = Vector3.INF
	item.visible = kind != "" and kind != "해바라기씨"     # (F-2) 굴리는 씨앗은 땅 위에 따로 (SunflowerView)
	if kind == "" or kind == "해바라기씨":
		return
	var sp := carry_spec(kind, _child, _female and _style % 2 == 0)
	var parts := carry_parts(sp[0])
	if parts.is_empty() or parts["mesh"] == null:      # carry 소품이 없으면 옛 소품 (가슴 앞)
		_reparent_item(chest)
		item.transform = Transform3D(Basis.IDENTITY, origin("item_log"))
		_mesh(item, ITEMS.get(kind, "item_crate"))
		_item_base = item.position
		return
	_carry_prop = sp[0]
	_carry_style = sp[1]
	if _carry_style == "push":
		_set_push(parts)
		return
	if _carry_style == "pole":
		_set_ground_prop(parts)
		return
	_reparent_item(head if _carry_style == "head" else (arm_r if _carry_style == "hand" else chest))
	_carry_close = _carry_mi(parts["mesh"])
	_carry_far = _carry_mi(parts["far"] if parts["far"] != null else parts["mesh"])
	_carry_close.visible = lod_close
	_carry_far.visible = not lod_close
	_carry_far.scale = Vector3.ONE * CARRY_FAR_SCALE        # 멀리 LOD: 덩어리를 조금 더 크게 (기본 확대에서 색 점으로 읽히게)
	var b := carry_basis(_carry_prop, _carry_style).scaled(Vector3.ONE * float(sp[2]))
	var bb := Transform3D(b) * (parts["mesh"] as Mesh).get_aabb()
	var h := bb.size * 0.5
	var c := bb.get_center()
	var at: Vector3 = CARRY_SOCKET[_carry_style]
	var pos := at
	match _carry_style:
		"front":
			pos = Vector3(at.x, at.y - h.y * 0.15, maxf(at.z, BODY_FRONT + h.z))
		"shoulder":
			pos = at + Vector3(-h.x * 0.3, h.y * 0.75, -h.z * 0.3)
		"back":
			pos = at + Vector3(-0.028, h.y * 0.45, -h.z * 0.85)
		"head":
			pos = at + Vector3(0, h.y * 0.8, 0)
		"hand":
			pos = at + Vector3(0, -h.y * 0.9, 0)
	item.transform = Transform3D(b, pos - c)
	_item_base = item.position


## 유모차: 모델 원점(땅)에 붙여 앞(+Z)에 두고, 바퀴 부품을 따로 (굴러감). 크기는 모델 그대로 (주민 단위)
func _set_push(parts: Dictionary) -> void:
	_reparent_item(self)
	_carry_close = _carry_mi(parts["mesh"])
	_carry_far = _carry_mi(parts["far"] if parts["far"] != null else parts["mesh"])
	var ps := Art.parts("carry/" + _carry_prop)
	for wn: String in PRAM_WHEELS:
		if not ps.has(wn) or ps[wn].get("mesh") == null:
			continue
		var w := _carry_mi(ps[wn]["mesh"])
		w.position = ps[wn]["origin"]
		w.reparent(_carry_close, false)        # 가까이 LOD에서만 (멀리는 덩어리 하나)
		_wheels.append([w, float(PRAM_WHEELS[wn])])
	_carry_close.visible = lod_close
	_carry_far.visible = not lod_close
	item.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * PRAM_SCALE), CARRY_SOCKET["push"])
	_item_base = item.position


## (E3-6) 둘이 메는 장대: 모델 원점에 붙임 (어깨 위 장대 — 어깨 점을 장대 끝에 맞춤)
func _set_ground_prop(parts: Dictionary) -> void:
	_reparent_item(self)
	_carry_close = _carry_mi(parts["mesh"])
	_carry_far = _carry_mi(parts["far"] if parts["far"] != null else parts["mesh"])
	_carry_close.visible = lod_close
	_carry_far.visible = not lod_close
	var ab := (parts["mesh"] as Mesh).get_aabb()
	var at: Vector3 = CARRY_SOCKET[_carry_style]
	# 앞 사람 = 뒤로 (X → -Z) · 뒤 사람 = 앞으로 (X → +Z). 크기는 그대로 (둘 사이가 맞게)
	var b := Basis(Vector3.UP, PI / 2.0 if _carry_prop == "fish_pole" else -PI / 2.0)
	var anchor := Vector3(ab.position.x + 0.078, ab.end.y - 0.023, ab.get_center().z)
	item.transform = Transform3D(b, at - b * anchor)
	_item_base = item.position


func _reparent_item(host: Node3D) -> void:
	if item.get_parent() != host:
		item.reparent(host, false)


func _carry_mi(m: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	item.add_child(mi)
	return mi


## 일할 때 드는 연장 — 직업 옷(set_job)이 정한 연장, 없으면 일터 표 (없는 일터 = 망치: 짓기). "-" = 빈손
func set_tool(workplace: String) -> void:
	var kind: String = _job_tool if _job_tool != "" else str(job_look(workplace)["tool"])
	if kind == _tool_kind or tool == null:
		return
	_tool_kind = kind
	for c in tool.get_children():
		c.queue_free()
	if kind != "-":
		_mesh(tool, kind)


## a = 시뮬레이션 동작 (r.anim), action = 시뮬레이션 행동 (r.action: social · rest …)
func set_anim(a: String, action := "") -> void:
	if a == anim and action == _action:
		return
	var was := anim
	anim = a
	_action = action
	# 인사: 어울리러 와서 멈춰 서면 (반쯤) 손을 한 번 흔든다 — 손 흔들기는 이런 때만
	if was == "walk" and action == "social" and (a == "idle" or a == "sit") and _rng.randf() < 0.5:
		greet()


## 손 한 번 흔들기 (인사 · 거인에게 보내는 신호) — 사이 동작으로 한 번 돌고 하던 동작으로
func greet() -> void:
	_start_variety("wave", 2.0)


## 고개를 들고 갸웃 (이번 화면만 — tick 뒤에 부름): up = 위로 젖힘(라디안) · side = 옆으로 기울임 — 하늘을 올려다보는 아이 (OPENING 8)
func tilt_head(up: float, side: float) -> void:
	if skel == null:
		return
	var i := skel.find_bone("skull")
	_rot_world(i, Vector3.RIGHT, -up)
	_rot_world(i, Vector3.FORWARD, side)


## 횃불처럼 오른팔을 직접 겨눔 (이번 화면만 — tick 뒤에 부름). rx = 앞으로 듦(-), rz = 옆으로 벌림
func aim_arm_r(rx: float, rz := 0.0) -> void:
	_arm_aim = Vector2(rx, rz)
	_apply_aim()


## 동작 이름 → 기본 애니메이션 (나이·연장·짐·행동에 따라 — 사이 동작 없이, 정해진 값)
func _clip(a: String) -> String:
	match a:
		"walk":
			if look.get("elder", false):
				return "walk_elder"
			return "run" if _child else "walk"
		"carry":
			return "carry"
		"work", "torch":
			if _tool_kind == "?":
				set_tool("")
			if a == "work" and JOB_ANIM.has(_job_name):
				return JOB_ANIM[_job_name]
			return TOOL_ANIM.get(_tool_kind, "work_hammer")
		"idle":
			if _item_kind != "":
				return "hold"
			return "chat" if _action == "social" else "idle"
		"sit":
			# 어울림 = 앉아 이야기 (사람마다 반은 듣는 쪽) · 쉼 = 그냥 앉아 불 쬐기
			if _action == "social" or _action == "festival":
				return "sit_talk" if _style % 3 != 0 else "sit"
			return "sit"
		"play":
			return "clap" if _style % 3 == 1 else "play"
		"pray":
			# 제단 앞: 반은 무릎 꿇고, 반은 서서 손 모으고 (가끔 깊이 절함)
			return "pray_stand" if _style % 2 == 1 else "pray"
		"lookup":                # (수첩 쪽지 7) 하늘을 올려다봄 — 3D는 두리번(look)
			return "look"
		"gather":                # (EVENTS_STAGING 2b) 제단 돌을 숙여 줍고 내려놓음 — 3D는 쪼그려 앉음(crouch)
			return "crouch"
		"sleep", "eat", "fly", "wave", "run", "hold":
			return a
	return a if a in ANIMS else "idle"


## 사이 동작 시작 (loops = 몇 번 돌지)
func _start_variety(c: String, loops := 1.0) -> void:
	if _player == null or not _player.has_animation(c):
		return
	_var_clip = c
	_var_left = _player.get_animation(c).length * loops / maxf(0.1, _speed(c))
	_var_next = _rng.randf_range(VARIETY_GAP.x, VARIETY_GAP.y)


## 지금 틀 클립: 기본 클립 + 가끔 끼는 사이 동작 (기본 클립 VARIETY 표)
func _pick(dt: float) -> String:
	var b := _clip(anim)
	if b != _base:
		var first := _base == ""
		_base = b
		if not first and _var_clip != "wave":       # 하던 일이 바뀌면 사이 동작은 그만 (인사는 마저)
			_var_clip = ""
		_var_next = minf(_var_next, _rng.randf_range(VARIETY_GAP.x, VARIETY_GAP.y))
	if _item_kind != "" and (b == "carry" or b == "hold"):     # 짐을 든 동안엔 사이 동작 없이 (팔이 짐을 놓지 않게)
		_var_clip = ""
		return b
	if _var_clip != "":
		_var_left -= dt
		if _var_left > 0.0:
			return _var_clip
		_var_clip = ""
	var pool: Array = VARIETY.get(b, [])
	if pool.is_empty():
		return b
	_var_next -= dt
	if _var_next <= 0.0:
		var tot := 0.0
		for e: Array in pool:
			tot += float(e[1])
		var x := _rng.randf() * tot
		for e: Array in pool:
			x -= float(e[1])
			if x <= 0.0:
				_start_variety(e[0], 1.0 if _rng.randf() < 0.7 else 2.0)
				return _var_clip if _var_clip != "" else b
	return b


## 화면 시간으로 돌린다 (매 화면, 부드럽게 — 바뀌면 BLEND초 섞음)
## (v5) 기본 클립을 새로 틀 땐 사람마다 다른 자리에서 시작 + 조금 다른 빠르기 → 모두가 같은 박자로 움직이지 않음
func tick(dt: float) -> void:
	_t += dt * Style.ANIM_SPEED
	if pose == null:
		return
	if _baby:
		apply_pose(anim, _t)
		return
	if _day_shown != daylight:              # 낮 ↔ 저녁: 머리쓰개를 쓰고 벗음 (바뀔 때만 다시 합침)
		_refresh_body()
	var c := _pick(dt * Style.ANIM_SPEED)
	if _player == null or not _player.has_animation(c):
		return
	if c != _clip_now:
		_player.play(c, BLEND if _clip_now != "" else 0.0)
		if c != _var_clip:                 # 기본 클립: 엇갈린 자리에서 (사이 동작은 처음부터 — 몸짓 하나)
			_player.seek(_rng.randf() * _player.get_animation(c).length, false)
		_clip_now = c
	_player.speed_scale = _speed(c) * (1.0 if STRIDE.has(c) else _rate)
	_skip_dt += dt
	if not lod_close and not _skip:         # 멀리 LOD: 동작은 두 화면에 한 번 (작게 보여 티 안 남, CPU 절반)
		_skip = true
		return
	_skip = false
	_player.advance(_skip_dt * Style.ANIM_SPEED)
	_skip_dt = 0.0
	_after()


func _speed(c: String) -> float:
	if STRIDE.has(c):
		var g := _ground
		if g < 0.0:                     # 모름: 보통 배속의 제 걸음 (아이·노인 비율 · '굼뜬' 걸음걸이)
			g = GROUND_NORMAL * _gait * (Balance.WALK_CHILD if _child else (Balance.WALK_ELDER / 0.85 if look.get("elder", false) else 1.0))
		return clampf(g / (float(STRIDE[c]) * absf(scale.x) * pose.scale.y), 0.0, 8.0)
	return 1.0


## 자리 옮기기 + 땅 위 빠르기 재기 (화면 dt초 동안 옮긴 거리 — 걸음 동작 빠르기를 여기에 맞춤). 순간이동은 재지 않는다
func move_to(p: Vector3, dt: float) -> void:
	if dt > 0.0 and _gpos != Vector3.INF:
		var d := Vector2(p.x - _gpos.x, p.z - _gpos.z).length()
		if d < 3.0:
			var sp := d / dt
			_ground = sp if _ground < 0.0 else lerpf(_ground, sp, clampf(dt * GROUND_EASE, 0.0, 1.0))
	position = p
	_gpos = p


## 동작 자세 — 그 동작의 t초 자세 (섞지 않음: 사진 도구 · 시험)
func apply_pose(a: String, t: float) -> void:
	if pose == null:
		return
	anim = a
	if _baby:                           # 아기 바구니: 살짝 흔들릴 뿐
		item.visible = false
		tool.visible = false
		pose.rotation = Vector3(0, 0, sin(t * 1.4) * 0.03)
		return
	var c := _clip(a)
	if _player == null or not _player.has_animation(c):
		return
	_player.speed_scale = 1.0
	_player.play(c, 0.0)
	_clip_now = c
	var ln := _player.get_animation(c).length
	_player.seek(fposmod(t * _speed(c), ln), true)
	_after()


## 동작 뒤: 소품 보이기 · 체형 배율 · 숙임 · 머리 들기
func _after() -> void:
	var a := anim
	item.visible = _item_kind != "" and (a == "carry" or a == "idle")
	if item.visible and _carry_style != "":
		_carry_pose(a == "carry")
	tool.visible = a == "work" or a == "torch"
	if _cane != null:
		_cane.visible = not a in ["sit", "eat", "sleep", "pray", "work", "fly", "play", "carry"]
	_arm_aim = Vector2.INF
	if skel == null or _post.is_empty():
		return
	for bn: String in ["chest", "skirt", "skull"]:
		var i := skel.find_bone(bn)
		if i >= 0:
			skel.set_bone_pose_scale(i, _post[bn])
	var dx: float = _post["arm_dx"]
	var lx: float = _post["leg_dx"]
	for pr: Array in [["upper_arm.L", dx], ["upper_arm.R", -dx], ["thigh.L", lx], ["thigh.R", -lx]]:
		var i := skel.find_bone(pr[0])
		if i >= 0 and pr[1] != 0.0:
			skel.set_bone_pose_position(i, skel.get_bone_rest(i).origin + Vector3(pr[1], 0, 0))
	if _post["thick_arms"]:
		for bn: String in ["upper_arm.L", "upper_arm.R"]:
			skel.set_bone_pose_scale(skel.find_bone(bn), Vector3(1.3, 1.0, 1.3))
	if _post["slim_legs"]:
		for bn: String in ["thigh.L", "thigh.R"]:
			skel.set_bone_pose_scale(skel.find_bone(bn), Vector3(0.75, 1.0, 0.75))
	if a != "sleep":
		if _lean != 0.0:
			_rot_world(skel.find_bone("spine"), Vector3.RIGHT, _lean)
		_rot_world(skel.find_bone("skull"), Vector3.RIGHT, HEAD_TILT - _lean * 0.6)


## (A22) 짐 든 자세: 걸음에 맞춰 짐이 통통 + 자리마다 팔 자세 (front는 carry/hold 클립 그대로). 값만 씀 — 할당 없음
func _carry_pose(walking: bool) -> void:
	var ph := 0.0
	if _player != null and _player.current_animation != "":
		var ln := _player.current_animation_length
		ph = _player.current_animation_position / ln if ln > 0.0 else 0.0
	var bob := absf(cos(ph * TAU)) * CARRY_BOB if walking and not _carry_style in ["push", "pole"] else 0.0
	item.position = _item_base + Vector3(0, bob, 0)
	if not _wheels.is_empty():
		_roll_wheels()
	if _carry_style == "front":
		return
	var arms: Dictionary = CARRY_ARMS.get(_carry_style, {})
	var swing := sin(ph * TAU) * (0.4 if walking else 0.0)
	for side in 2:
		var key := "R" if side == 0 else "L"
		var ua := _arm_bi[side * 2]
		var fa := _arm_bi[side * 2 + 1]
		if ua < 0 or fa < 0:
			continue
		var sg := 1.0 if side == 0 else -1.0
		if arms.has(key):
			var e: Array = arms[key]
			var u: Vector3 = e[0]
			if _carry_style == "hand":
				u.x += swing * 0.25 * sg
			_set_bone_euler(ua, Vector3(u.x, u.y * sg, u.z))
			_set_bone_euler(fa, Vector3(float(e[1]), 0, 0))
		else:                           # 빈 팔: 걸음에 맞춰 살랑
			_set_bone_euler(ua, Vector3(swing * sg * -1.0, A_OUT * sg, 0))
			_set_bone_euler(fa, Vector3(-0.25 - maxf(0.0, swing * sg) * 0.3, 0, 0))


## 유모차 바퀴: 지난 화면부터 실제로 간 거리만큼 굴림 (앞으로 가면 앞으로 구름)
func _roll_wheels() -> void:
	if not is_inside_tree():
		return
	var p := global_position
	if _wheel_last != Vector3.INF:
		var d := p - _wheel_last
		var fwd := global_transform.basis.z.normalized()
		var dist := Vector2(d.x, d.z).dot(Vector2(fwd.x, fwd.z)) / maxf(0.001, global_transform.basis.get_scale().x * PRAM_SCALE)
		if absf(dist) < 2.0:                        # 순간 이동(자리 다시 잡기)은 굴리지 않음
			for e: Array in _wheels:
				var w: MeshInstance3D = e[0]
				w.rotation.x = fposmod(w.rotation.x + dist / float(e[1]), TAU)
	_wheel_last = p


## 뼈를 쉴 자세 기준 '모델 축 오일러'로 (build_residents.py key()와 같은 셈: Euler YXZ, Blender 축 → Godot 축)
func _set_bone_euler(i: int, e: Vector3) -> void:
	var rw := Basis(Vector3.UP, e.z) * Basis(Vector3.RIGHT, e.x) * Basis(Vector3.FORWARD, e.y)
	var bg := skel.get_bone_global_rest(i).basis
	skel.set_bone_pose_rotation(i, skel.get_bone_rest(i).basis.get_rotation_quaternion() * (bg.inverse() * rw * bg).get_rotation_quaternion())


## 뼈를 (쉴 자세 기준) 세계 축 둘레로 더 돌림
func _rot_world(i: int, axis: Vector3, ang: float) -> void:
	if i < 0 or ang == 0.0:
		return
	var local := (skel.get_bone_global_rest(i).basis.inverse() * axis).normalized()
	skel.set_bone_pose_rotation(i, skel.get_bone_pose_rotation(i) * Quaternion(local, ang))


func _apply_aim() -> void:
	if skel == null or _arm_aim == Vector2.INF:
		return
	var i := skel.find_bone("upper_arm.R")
	if i < 0:
		return
	var B := skel.get_bone_global_rest(i).basis
	var wr := Basis(Vector3.RIGHT, _arm_aim.x) * Basis(Vector3.BACK, _arm_aim.y)
	skel.set_bone_pose_rotation(i, skel.get_bone_rest(i).basis.get_rotation_quaternion() * (B.inverse() * wr * B).get_rotation_quaternion())
