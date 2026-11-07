## 그림체 색·빛 데이터 — RENDERING.md v2 (셀 채색 일러스트, 위에서 내려다본 지도).
## 기준 그림: design/concept/style-test/flat2_map_a.png · flat2_map_b.png (색은 그 그림에서 뽑아 맞춤).
## 화면 코드(view/·render/)는 색을 여기서만 읽는다 → 그림체를 고칠 때 이 파일만 바꾸면 된다.
## 색은 모두 sRGB 16진수 (셰이더에는 source_color로 넘어가 선형으로 바뀜).
class_name Style
extends RefCounted

# ───────────── 빛 (셀 채색: 밝은 면 + 그늘 한 단계) ─────────────
const LIT_TINT := Color("ffffff")          # 밝은 면 = 원래 색
const SHADE_TINT := Color("8cc2de")        # 그늘 = 원래 색 × 이 색 (검정 대신 청록 쪽으로 어둡게)
const LIT_THRESHOLD := 0.08                # N·L 이 값보다 크면 밝은 면 (경계 또렷)
const SUN_ELEVATION_DEG := 52.0            # 해 높이 (그림자 길이 ≈ 키 × 0.8)
## 화면용 해 방위: 기획서의 창가 방향(JarWater.LIGHT)에서 이만큼 돌림 → 기본 카메라(방위 45°)에서
## 그림자가 기준 그림처럼 오른쪽 아래로 진다 (시뮬레이션의 볕 드는 쪽 계산은 그대로).
const SUN_AZIMUTH_OFFSET_DEG := -38.0
const BACKGROUND := Color("23393b")        # 병 밖 (멀리 축소했을 때만 보임)

# ───────────── 외곽선 (깊이 차이 화면 셰이더) ─────────────
const OUTLINE_PX_1080P := 2.5              # 1080×1920 기준 두께 (해상도에 비례)
const OUTLINE_MUL := Color("3f6a6e")       # 선 색 = 물체 색 × 이 색 (그 물체 색의 짙은 청록 버전)
const OUTLINE_GAP := 0.22                  # 이웃 픽셀이 이만큼(세계 단위) 더 멀면 가장자리

# ───────────── 땅 ─────────────
const GRASS := Color("b9d687")             # 밝은 연두 풀밭 (기준 b9d286)
const GRASS_COOL := Color("a6d08a")        # 그늘 쪽 · 습한 땅은 민트 쪽으로
const GRASS_WET := Color("8fc48a")
const GRASS_RIDGE := Color("94bf78")       # 높이 단계 경계의 작은 둔덕 테두리
const PATH := Color("d9bf8f")              # 흙길 — 밟아 다진 따뜻한 흙빛 (예전 e0cf9c는 모래빛)
const PATH_EDGE := Color("c2a374")
const SALT := Color("eef0e6")
const SALT_EDGE := Color("cfd6cf")
const RIVER := Color("7fcfd6")
const RIVER_EDGE := Color("5aaab4")
const MARSH := Color("8fc4a0")
const BANK := Color("93b27a")              # 호숫가 짙은 띠 (흙 + 이끼)
const SOIL := Color("8a6a4a")              # 땅 옆면
const SOIL_DARK := Color("5e4836")
# 겉흙 12종 (기획서 4.4b — view/ground_look.gd · render/terrain.gdshader). 풀밭 = 위 GRASS들, 흙길 = PATH, 소금 = SALT
const DRY_GRASS := Color("d2cf8c")         # 짧은 풀·마른 풀 (볕 드는 마른 쪽, 여름)
const MOSS_GROUND := Color("63a58c")       # 이끼 (짙은 청록) + 보송한 점
const MOSS_DOT := Color("8cc8a0")
const FOREST_FLOOR := Color("a2a26c")      # 숲 바닥 (낙엽·흙 — 수관 그늘 아래라 밝게)
const FOREST_DOT := Color("8c7c56")
const SOIL_GROUND := Color("b8925f")       # 맨흙 (밭·집터·공사장) + 밭이랑
const SOIL_FURROW := Color("9a7650")
const SHORE_SAND := Color("e6d9a9")        # 모래·자갈 물가
const PEBBLE := Color("aab1aa")
const MUD := Color("9c8f6e")               # 진흙·습지 + 물웅덩이
const PUDDLE := Color("78b9c2")
const ROCK_GROUND := Color("aab4ae")        # 바위 (언덕 위·광맥)
const ROCK_GROUND_DARK := Color("8d9894")
## 돌 색 — 어디서나 같다 (기획서 21장 '돌 색' · SHOP 2.4): 회색 = 돌 · 붉은 = 철 · 하양 = 소금 · 검정 = 석탄 · 반짝이 = 금.
## 창조의 암반 컵·광맥 알갱이, 상점의 광맥 돌, 병 안의 광맥 바위가 모두 이 표를 쓴다 (키 = 창고 물건 이름)
const ORE := {"돌": Color("a7a9a6"), "철광석": Color("b8543a"), "소금": Color("f2f0ea"), "석탄": Color("2e2c2e"), "금": Color("e8b84a")}
const ORE_GOLD_GLOW := 0.6                  # 금은 반짝인다 (빛을 조금 냄)
const STONE_PATH := Color("dccfb5")        # 돌길 (광장이 선 마을·읍내의 큰길) — 따뜻한 회색 자갈
const STONE_GAP := Color("a08867")         # 돌 사이 틈 (흙 메움)
const SNOW := Color("f6f8f8")              # 눈·서리
const SNOW_SHADE := Color("dbe7ee")
const DESERT_SAND := Color("e9c287")       # 사막 병 모래땅
const DANDELION := Color("f4d64c")         # 봄 들꽃 (민들레 노랑 + 흰 꽃)
const DAISY := Color("fbf8ea")
const LEAF_RED := Color("d9763f")          # 가을 낙엽
const LEAF_GOLD := Color("e8b04a")

# ───────────── 물 ─────────────
const WATER := Color("6cc6d0")             # 옅은 하늘색 (기준 68c3cc)
const WATER_DEEP := Color("5db8c6")
const WATER_SHORE := Color("4f9fae")       # 물가 한 단계 진한 띠
const WATER_FOAM := Color("e2f6f5")        # 큰 흰 물결 무늬 (기준 d2f2f3)
const WAVE_SCALE := 0.3                   # 물결 무늬 크기 (세계 단위당)
const WAVE_SPEED := 0.025                  # 물결이 흐르는 빠르기
const WAVE_AMOUNT := 0.14                  # 흰 무늬가 덮는 비율 (0~1)
const DROP := Color("7fc8de")             # 물방울 — 눈처럼 하얗지 않게 물빛 (사용자 피드백 2026-11-07)

# ───────────── 나무·소품 ─────────────
const LEAF_TOP := Color("66c98a")          # 수관 위쪽 (밝은 민트, 기준 60c686)
const LEAF_MID := Color("3ea383")          # 수관 (청록, 기준 399f86)
const LEAF_LOW := Color("2a8577")          # 수관 아래쪽 (짙은 청록, 기준 2d8679)
const LEAF_YOUNG := Color("8ccf86")        # 묘목
const TRUNK := Color("7a5e4a")             # 줄기 (기준 695948 · 796053)
const TRUNK_DARK := Color("5b4537")
const STUMP_TOP := Color("d9b98a")
const ROCK := Color("9aa9a6")              # 이끼 낀 돌 (청회색)
const ROCK_DARK := Color("7d8d8c")
const MOSS := Color("8fc46c")
const MUSHROOM_CAP := Color("e9a35e")      # 버섯 (따뜻한 색은 아껴서)
const MUSHROOM_DOT := Color("f8e6c4")
const MUSHROOM_STEM := Color("f1e2c2")
const FERN := Color("4fae74")
const CLOVER := Color("7cc173")
const TUFT := Color("7fb565")
const BUSH := Color("4fae7c")              # 집 둘레 덤불
const BUSH_TOP := Color("72c48a")
const LILY := Color("5aae6e")              # 연잎
const LOTUS := Color("f2a7c0")             # 연꽃 (따뜻한 색은 아껴서)

# ───────────── 건물 ─────────────
const THATCH := Color("f0c886")            # 초가 (기준 f1c788)
const THATCH_DARK := Color("d5ac6c")
const STONE := Color("b9c0bd")             # 회색 돌담 (밝은 면)
const STONE_DARK := Color("8e9a98")
const WOOD := Color("9a7150")
const WOOD_DARK := Color("6a4c39")
const PLASTER := Color("efe8d8")
const ROOF_RED := Color("c98a5e")
const ROOF_GREY := Color("7f8c8c")
const FIELD_SOIL := Color("a78358")
const CROP := Color("9cc85c")
const CROP_RIPE := Color("efc35a")
const WINDOW := Color("4f5f63")
const FLAME := Color("f39a45")
const FLAME2 := Color("ffe08a")
const GRAIN := Color("fff6dc")
const ITEM_COLORS := {"통나무": Color("9a7150"), "판자": Color("e0bf8c"), "돌": Color("a3adab"), "밀": Color("efc35a"),
	"물": Color("6cc6d0"), "밀가루": Color("f2ede2"), "빵": Color("d49a5e"), "소금": Color("fff6dc"),
	"버섯": Color("efe9dc"), "말린 버섯": Color("8a5a36"), "빛버섯": Color("bfe8ef")}   # [하늘의 것]

# ───────────── 주민 ─────────────
## A23 (아트 바이블 5.2·8.13): 주민 모델은 게임 단위로 만든다 — 1 = 1칸 = 어른 키 (약 4등신). 기본 확대(ppu 16)에서 1080 폭 약 32px
const RESIDENT_SCALE := 1.0
## 옛 '주민 모델 단위' (어른 약 1.9) → 칸. 아직 그 단위로 만든 동물(animals/*)·몇몇 연출만 씀 — 다시 만들 때 1칸 단위로 옮기고 지움
const LEGACY_MODEL_UNIT := 0.52
const RESIDENT_LINE := Color("3a2a22")     # 주민 둘레선 — 화면에서 가장 짙은 외곽선 (아트 바이블 5.3 R7)
## 주민 색 (아트 바이블 4.1 · 5.3 · 5.7) — 크림 어깨띠 P4 · 팔다리 중간 명도 P3 쪽 · 피부 8단계 · 머리색 8단계 · 점 눈
const CREAM := Color("f3e6cc")             # P4 주민 크림 (어깨 깃 · 빵 모자 · 머릿수건) — 화면에서 가장 밝은 따뜻한 값
const DRIED := Color("c8ae82")             # P3 마른 재료 (고깔 풀 모자)
const SKIN_RAMP := ["e8c8a8", "ddb590", "cfa27a", "b98762", "a0704e", "87593c", "6e452e", "573524"]   # S1~S8 (번호로만, 능력과 무관)
const HAIR_RAMP := ["3a3230", "4e3a2e", "6e5038", "8a5434", "ad6440", "7e3f2c", "d2b278", "d9d1c3"]   # H1~H8 (H8 흰머리 = 따뜻한 회백)
const HAIR_GREY_MID := Color("a69c90")     # 반백
const EYE_DOT := Color("1e1612")           # 모든 주민의 점 눈 (게임에서 가장 짙은 값)
## 옷 물감 상한 (꽃물 공식 — 채도 ≤ 0.42 · 명도 ≤ 0.85, 짙은 색은 신발·허리띠에만 → 명도 하한)
const DYE_SAT_MAX := 0.42
const DYE_VAL := Vector2(0.5, 0.85)
const ANIM_SPEED := 1.0                    # 부드러운 동작의 빠르기 배율

# ───────────── 유리 (RENDERING.md 2.8) ─────────────
const GLASS_RIM := Color("e9f6f4")         # 땅 끝 테두리
const GLASS_WALL := Color("d8f0f0")        # 유리벽 (반투명)
const GLASS_WALL_ALPHA := 0.16
const GLASS_LINE := Color("ffffff")        # 하이라이트 줄
## 화면 가장자리 유리 곡선 (화면 셰이더): 중심(화면 비율 좌표, 세로 = 1)과 반지름 → 왼쪽 위 구석을 지나는 큰 호
const GLASS_ARC_CENTER := Vector2(0.40, 0.70)
const GLASS_ARC_RADIUS := 0.70
const GLASS_ARC_TINT := 0.30               # 호 바깥(유리 두께)을 하얗게 덮는 정도

# ───────────── 낮·밤 (전체 색 조정) ─────────────
const NIGHT_MUL := Color("4a5f9c")         # 밤 = 남색 (화면 색 × 이 색)
const NIGHT_ADD := Color("0b1430")         # 밤에 더하는 남색 (검게 죽지 않게)
const DUSK_FROM := 19.5                    # 이 시각부터 어두워져
const NIGHT_FULL := 21.5                   # 이 시각에 완전히 밤
const DAWN_FROM := 4.5                     # 이 시각부터 밝아져
const DAY_FULL := 6.0                      # 아침 6시 = 완전히 낮 (밤 건너뛰기 끝과 같음)


# ───────────── 5단계: 모델 에셋 (art/) · 모델 외곽선 ─────────────
## 모델 외곽선 두 가지 (깊이 차이 화면 셰이더와 함께): 뒤집은 껍데기(물체 둘레·겹친 가장자리) + 접힌 곳 선(지붕 끝·벽 모서리)
## 빛 속이기 (물체만): 밝은 면 판정 빛을 카메라 쪽으로 이만큼 기울임 → 카메라를 향한 앞벽·지붕 앞면이 밝게 (기준 그림처럼).
## 그림자 방향은 그대로. 0 = 4단계와 같음. (toon_light.gdshaderinc)
const VIEW_FILL := 1.6
const OUTLINE_HULL_PX_1080P := 1.7         # 껍데기 두께 (1080×1920 기준, 해상도에 비례)
const OUTLINE_CREASE_PX_1080P := 1.9       # 접힌 곳 선 두께
const OUTLINE_CREASE_MUL := Color("6a7476") # 접힌 곳 선 색 = 그 면 색 × 이 색 (둘레선보다 조금 옅게)
const WINDOW_LIT := Color("f2cf72")        # 창 (기준 그림은 낮에도 따뜻한 노란 창)
const DOOR := Color("8a5a3a")
const PLANK := Color("c79a66")             # 선착장·다리 널빤지
const REED := Color("8fb36a")
const REED_HEAD := Color("8a5a3a")
const BREAD := Color("d49a5e")

## 시각(0~24) → 밤 정도 0~1
static func night_amount(hour: float) -> float:
	if hour >= NIGHT_FULL or hour < DAWN_FROM:
		return 1.0
	if hour >= DUSK_FROM:
		return smoothstep(DUSK_FROM, NIGHT_FULL, hour)
	if hour < DAY_FULL:
		return 1.0 - smoothstep(DAWN_FROM, DAY_FULL, hour)
	return 0.0


## 화면용 해 방향 (해에서 땅으로 — DirectionalLight의 -Z)
static func sun_direction() -> Vector3:
	return sun_direction_for(JarWater.LIGHT)


## 창가(등불) 방향 l (병 데이터 좌표)에서 오는 해 — 등불을 옮기면 (A11) 넓은 세상은 빛이 돈다
static func sun_direction_for(l: Vector2) -> Vector3:
	var a := l.normalized().rotated(deg_to_rad(SUN_AZIMUTH_OFFSET_DEG))
	var el := deg_to_rad(SUN_ELEVATION_DEG)
	# 해는 창가 쪽(a 방향)에 떠 있다 → 빛은 그 반대로 비춘다
	return -Vector3(a.x * cos(el), sin(el), a.y * cos(el)).normalized()
