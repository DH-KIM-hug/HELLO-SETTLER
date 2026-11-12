## 주민 = 2D 종이 인형 (컷아웃) — art-bible 5.2 (2026-11-08 사용자: 시안 A · 직업 옷 · 시드로 정한 겉모습 기록).
## 화면만 바꾼다 (ADR-0001: 연출은 결과를 바꾸지 않는다) — 시뮬레이션(Resident)은 읽기만, 아무것도 쓰지 않는다.
## ResidentModel을 이어받아 VillageView·말풍선·누르기·따라가기·연출(social_stage·뗏목·횃불)이 쓰는 자리·이름을 그대로 둔다:
##   position(발) · rotation.y(바라보는 쪽 = r.facing) · scale(나이 배율 — 말풍선·누르기 높이가 읽음) · tool(횃불이 붙는 빈 자리).
## 그림은 proto/cutout_a (cut_lib · cut_doll · cut_doll.gdshader) — 한 사람 = MeshInstance3D 하나 = 그리기 1번 (가까이·멀리 LOD 같음).
## 동작 대응 (컷아웃 클립 — cut_lib.CLIPS, CLIP_OF 표):
##   walk → walk (아이 = 같은 걸음을 더 빨리 = 뛰기, 노인 = 느린 걸음 — 빠르기는 실제 땅 빠르기에서) · 짐(또는 아기) 든 walk/carry → carry ·
##   짐(또는 아기) 든 idle → hold · work/torch → 연장이 괭이·낫이면 괭이질(hoe + 그 연장), 망치·도끼·곡괭이면 같은 내려찍기 + 나무망치,
##   약초·빈손 채집(GATHER_TOOLS)·사냥꾼 → gather (숙여 줍기), 그 밖 → idle ·
##   sit → sit · eat → eat (빵 — 먹을거리를 들었으면 그것) · sleep → sleep (누움, 앞 보기) · pray → kneel (제단 기도 · 깨달음 KNEEL) ·
##   그 밖(play·fly·wave·chat·사이 동작…) → idle. 앉기·먹기·줍기는 비스듬한 보기로만 (앞·뒤 보기에선 앉은 다리가 안 읽힘).
## 일 옷 (A23 ③, art-bible 5.2 직업 옷): 일터에서 일을 시작하는 순간(work 동작) 일 옷으로 갈아입고 — 일터 문 앞에서 작은 연기와 함께
##   잠깐 사라졌다 나타남 (SWAP_HIDE) — 그 일(같은 행동)을 하는 동안은 일감을 나르러 걸어도 일 옷, 행동이 바뀌거나 쉬기·먹기·자기·기도로
##   가면 평상복으로 (같은 연기). 지금 일 옷은 모든 일이 농부 옷 하나 (look_from jobs).
## 아기 (2026-11-08 "아이가 태어났다 했는데 아기가 없음" — 시뮬레이션은 아기를 집 자리에 재워 두어 VillageView가 '집 안'으로 숨겼다):
##   place_babies()가 화면에서만 — 젖먹이(1살 아래)는 걷거나 서 있는 부모가 품에 안고(부모 인형 = 안기 팔), 아니면 집 문 옆 요람에 누움,
##   걸음마 아기(1~2.4살)는 부모 곁에서 아장아장 따라 걷거나 앉아 놀고, 부모가 없으면 문 옆에서 논다.
## 아이·노인: 제 몸 (2026-11-08 시안 A 넷 — 아이 몸 f · 노인 몸 g + 지팡이, cut_lib.look_from body). 아기는 아이 몸을 0.45로 (강보는 아직 없음).
## 낮엔 모자(R6 머리쓰개 문화), 저녁엔 벗음. 발밑 접촉 그림자는 VillageView의 CutoutShadows (MultiMesh 하나).
class_name CutoutResident
extends ResidentModel

const Lib := preload("res://proto/cutout_a/cut_lib.gd")
const Doll := preload("res://proto/cutout_a/cut_doll.gd")
## 방식 C 시험판 (스파이크, docs/RESIDENTS_2D.md 7장): NAZAKJI_FRAMES=1 또는 FrameLib.spike = 1 일 때만 —
## 여자 평상복(a) 어른의 걷기·나르기·서기·안고 서기를 장면 그림 몸 + 머리 조각으로 (그 밖은 그대로 컷아웃). 기본값은 바뀌지 않음.
const FrameLib := preload("res://proto/cutout_c/frame_lib.gd")
const FrameDoll := preload("res://proto/cutout_c/frame_doll.gd")
const FRAME_CLIPS := {"walk": "walk", "carry": "carry", "idle": "idle", "hold": "hold", "travel": "walk",
	"sit": "sit", "eat": "eat", "lookup": "lookup", "kneel": "kneel", "hoe": "hoe", "gather": "gather", "sleep": "sleep",     # 2026-11-10 states4 · states5 (sleep)
	"reap": "reap"}     # 2026-11-11 Q16: 낫질 (한 손 낫 — 전에는 이 동작만 컷아웃 인형으로 바뀌어 튀었음)

const DOLL_H := 0.88             # 어른의 화면 키 (세계 단위, cut_doll screen_h) — 3D 어른(모자 포함)과 같게 (cutA_lineup)
## 걷기 한 주기에 가는 길 = 그 옷 묶음 다리의 보폭 (Lib.stride_rig, rig 단위 × 화면 키 / fig) — 2026-11-08 걷기 점검:
## 옛 고정값 0.78칸은 짧은 인형 다리가 실제로 딛는 길(0.2~0.3)의 2.5배라 발이 땅에서 미끄러졌다
const RATE_MIN := 0.35
const RATE_MAX := 6.0
const RATE_STEP := 0.05          # 빠르기를 이만큼씩만 바꿈 (GPU에 보내는 일을 줄이고 위상 이음을 덜 함)
## 아주 빠른 배속 (2026-11-08 "아주 빠르게 할 때 주민들이 꼭 뒤로 가"): 발이 땅에 맞는 걸음 빠르기가 RATE_TRAVEL을 넘거나 한 장면에
## TRAVEL_STEP 주기 넘게 넘어가면 걸음 대신 travel (멈춘 큰 보폭 + 들썩임). 어떤 동작이든 한 장면에 MAX_FRAME_STEP 주기를 넘지 않음
## (반 주기를 넘으면 거꾸로 도는 것처럼 보임). 장면 길이는 지금 FPS (낮게 잡아 24)
## 걸음 한 주기 = 두 걸음 (좌우가 거의 같은 모양) → 보이는 주기는 반 주기라, 한 장면에 0.25 주기를 넘으면 벌써 거꾸로 보이기 시작함
const RATE_TRAVEL := 7.0
const TRAVEL_STEP := 0.25
const MAX_FRAME_STEP := 0.45
const MIN_FPS := 24.0
const BABY_SCALE := 0.45
const CHILD_SCALE := Vector2(0.68, 0.8)    # 아이 몸 f의 키 배율 (어린 → 큰 아이)
const ELDER_SCALE := 0.9
## 짐 이름 → 소품 (Lib.PROPS 번호): 빵 0 · 나뭇가지 1 · 바구니 2 · 밀 10 · 물통 11. 표에 없으면 바구니
## "돌" = 소품 없음 (제단 돌은 AltarView가 손에 둥근 돌을 따로 그림 — 바구니로 보이지 않게)
const CARRY_PROP := {"빵": 0, "통나무": 1, "판자": 1, "밀": 10, "물": 11, "씨앗": 12, "돌": -1}
const PROP_BASKET := 2
## 일 연장 → 내려찍는 일 동작(hoe)의 소품: 괭이 6 · 낫 7 · 나무망치 9. 표에 없는 연장(빈손·삽·약초·낚싯대) = 서서 (idle)
const WORK_PROP := {"tool_hoe": 6, "tool_sickle": 7, "tool_hammer": 9, "tool_axe": 9, "tool_pick": 9}
## (Q8 밀 거두기) 익은 밭을 거두는 밭 일꾼: 괭이 대신 작은 낫 + 낫질 (Lib "reap") — reaping은 VillageView가 밭의 자람 단계를 읽어 켠다 (화면만)
const REAP_JOB := "농장"
const REAP_PROP := 7
## 숙여 줍는 일 (약초 · 빈손 일터) · 그렇게 일하는 일터 (사냥꾼: 웅크려 살핌)
const GATHER_TOOLS := ["tool_herbs"]
const GATHER_JOBS := ["사냥꾼"]
## 비스듬한 보기로만 보이는 동작 (앞 → 비스듬한 앞, 뒤 → 비스듬한 뒤) · 늘 앞 보기 (누움)
const SIDE_ONLY := ["sit", "eat", "gather"]
const FRONT_ONLY := ["sleep", "lookup"]      # lookup (수첩 쪽지 7) — 하늘(거인 쪽)을 올려다보는 얼굴·가리키는 팔이 보이게
## 일 옷을 벗는 동작 (쉬기·먹기·자기·기도·놀기)
const OFF_SHIFT := ["sit", "eat", "sleep", "pray", "play", "fly"]
const SWAP_HIDE := 0.18          # 옷을 갈아입는 동안 사라지는 시간 (현실 초)
const SWAP_PUFF := 0.5           # 연기가 퍼졌다 사라지는 시간
## 아기: 젖먹이 = 1살 아래 (나이 일 < 1/2.4), 그 밖의 아기(AGE_BABY 아래) = 걸음마
const INFANT_AGE := 1.0 / 2.4
const INFANT_H := 0.4            # 젖먹이의 화면 키 (누운 인형의 길이 쪽) — 부모 품·요람에
const HOLD_RIG := 400.0          # 부모 품 높이 (rig 단위 — 안기 소품 자리와 같은 쪽)
const CRADLE_OFF := Vector2(0.4, 0.85)   # 집 문 옆 요람: 집 가운데에서 (옆, 앞) + 집 크기 × 0.5 앞

## -1 = 설정(GameSettings.cutout_residents)을 따름 · 0 = 늘 3D · 1 = 늘 컷아웃 (시험·캡처·성능 비교)
static var override := -1
static var _game_mat: ShaderMaterial

var doll: MeshInstance3D
var dlook: Dictionary = {}       # 겉모습 기록 (Lib.look_from + 유전 피부·머리색) — 같은 주민이면 늘 같음
var _hh_seed := -1
var _d_outfit := -2
var _d_hat := -2
var _d_prop := -2
var _d_clip := ""
var _d_rate := -1.0
var _d_phase := 0.0
var _doll_h := DOLL_H
var _infant := false
## 화면만의 아기 자리 (place_babies): "" 스스로 · carried 부모 품 · cradle 요람 · toddle 부모 곁 걸음마
var baby_mode := ""
var toddle_clip := "idle"
var reaping := false             # (Q8) 익은 밭을 거두는 중 — 일 동작이 낫질 (VillageView._sync_residents가 켬)
var carry_baby := false          # 이 사람이 아기를 안고 있음 (안기 팔, 소품 없음)
var baby_held := false           # 품에 정말 아기가 있음 (place_babies) — carry_baby만 켜진 것은 안아 주는 몸짓 (연출 hold)이라 아기 그림을 그리지 않음
var baby_dye := Vector2i(-1, -1)  # 안긴 아기의 피부 · 머리카락 물감 (place_babies가 넣음 — 방식 C 인형의 아기 그림에 입힘, 화면만)
var cradle: MeshInstance3D
var arms_out := false            # (E2-3) 두 손을 앞으로 내민 몸짓 (유모차 손잡이·보퉁이 — OutingView가 켜고 끔, 화면만)
var minder_id := -1              # (Q2-b) 이 아기를 지금 보는 사람 (place_babies가 적음 — 없으면 -1: 문 옆)
var _warp := Vector3(1, 1, 0)    # (Q2-b) 화면 몸짓: (키 배율, 폭 배율, 기울임) — set_body_warp
var _lift := 0.0                 # (Q2-b) 화면 몸짓: 인형만 들어 올림 (폴짝·요람 높이, 인형 좌표) — set_body_lift
## 일 옷 차림 (shift): 일을 시작한 행동 — 그 행동이 이어지는 동안 일 옷
var on_shift := false
var _shift_action := ""
var swaps := 0                   # 옷을 갈아입은 횟수 (시험)
## 방식 C 시험판: 이 사람만 켜기·끄기 (-1 = FrameLib.enabled() 따름) — 비교 사진용
var frames_force := -1
var fdoll: MeshInstance3D
var _f_on := false
## (Q22 ⑤ X, 2026-11-12) 방식 C 인형이 보이는 동안 컷아웃 인형의 GPU 일(sel · st · misc · 보기 고르기)은 건너뛰고 '밀림'만 적어 둠 →
## 컷아웃 인형으로 돌아오는 그 장면에 (보이기 전에) 한꺼번에 보냄. 시뮬·동작 고르기(_d_clip · 빠르기 · 위상)는 늘 그대로 따라감
var _d_stale := false
var doll_pushes := 0             # 컷아웃 인형에 보낸 GPU 값 수 (시험 — 방식 C가 보이는 동안 늘지 않아야 함)
## (X) 방식 C 길에서 장면마다 다시 찾던 값 (몸 · 동작이 같으면 그대로): 그 동작의 장면 그림이 있나 · 보폭 (rig ÷ fig)
var _fk_body := ""
var _fk_clip := ""
var _fk_ok := false
var _fk_stride := 0.0
## (X) 보기 고르기는 한 장면에 한 번 (move_to와 tick이 같은 장면에 두 번 _refresh_doll을 부름 — 둘째는 같은 값)
var _uv_frame := -1
var _uv_dir := Vector3.ZERO
var _uv_key := ""
var _uv_cam := Basis()
var _f_clip := ""
var _f_rate := -1.0
var _f_phase := 0.0
var _f_hat := -9
## [톡 반응] (view/tap_react.gd) 인형 전체에 얹는 화면만의 움직임 — 이 노드의 자리(= 시뮬 자리)는 그대로, 인형(doll)만 움직인다
var react_off := Vector3.ZERO    # 부모(VillageView) 틀 기준 옮김: y = 폴짝, xz = 반응하는 동안 제자리에 붙들기
var react_sq := Vector2.ONE      # (가로, 세로) 배율 — 찌그러짐·늘어남
var react_roll := 0.0            # 바라보는 쪽으로 숙이는 기울기 (rad, 발끝 중심)
var react_turn := 0.0            # 종이 인형이 세로 축으로 도는 바퀴 수 (0.5 = 반대쪽을 봄)
var react_hint := ""             # "" · still (걷던 발을 멈춤) · lookup (올려다봄 — 깨달은 뒤에만 옴) · (E2-1 2차, 하루의 흐름만) sit · eat · walk · carry · hold · stand
var react_speed := -1.0          # (E2-1 2차) walk·carry 힌트로 그린 인형만 걸을 때의 땅 빠르기 (칸/현실 초) — -1이면 잰 값 그대로


static func enabled() -> bool:
	if override >= 0:
		return override == 1
	return GameSettings.get_current().cutout_residents


## 게임용 재질: 시제품 재질 + 게임의 피부 8단계(Style.SKIN_RAMP → 물감 0~7) · 머리 8단계(Style.HAIR_RAMP → 12~19) · 반백(54)
static func game_material() -> ShaderMaterial:
	if _game_mat != null:
		return _game_mat
	_game_mat = Lib.material().duplicate() as ShaderMaterial
	var p := Lib.palette()
	for i in 12:
		p[i] = _v(Color(Style.SKIN_RAMP[mini(i, Style.SKIN_RAMP.size() - 1)]))
	for i in 8:
		p[12 + i] = _v(Color(Style.HAIR_RAMP[i]))
	p[54] = _v(Style.HAIR_GREY_MID)
	_game_mat.set_shader_parameter("palette", p)
	return _game_mat


static func _v(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)


## 집안 씨앗: 짝이 있으면 둘 중 작은 번호 (부부와 아직 혼인 안 한 아이가 같은 옷 물감), 아니면 부모, 아니면 제 번호
static func household_of(r: Resident) -> int:
	if r.partner >= 0:
		return mini(r.id, r.partner)
	if r.parents.size() > 0:
		var m := r.parents[0]
		for q in r.parents:
			m = mini(m, q)
		return m
	return r.id


## 겉모습 기록: 머리·모자·옷 묶음·옷 물감은 주민 번호·집안에서, 피부·머리색은 겉모습 유전자에서 (능력 값은 읽지 않는다)
static func doll_look(lk: Dictionary, seed: int, household: int) -> Dictionary:
	var tones := tones_of(lk)
	var skin := Style.SKIN_RAMP.find(tones["skin"].to_html(false))
	if skin < 0:
		skin = 0
	var dl := Lib.look_from(seed * 131 + 7, String(lk.get("sex", "m")), skin, 0, household * 977 + 11, body_of(lk))
	var hc: Color = tones["hair"]
	var hi := Style.HAIR_RAMP.find(hc.to_html(false))
	var d: Array = dl["dye"]
	if hi >= 0:
		d[1] = 12 + hi
	elif hc.is_equal_approx(Style.HAIR_GREY_MID):
		d[1] = 54
	else:                       # 반백으로 가는 중 (greyed) — 가장 가까운 단계
		var best := 12
		var bd := INF
		for k in 8:
			var c := Color(Style.HAIR_RAMP[k])
			var dd := Vector3(c.r - hc.r, c.g - hc.g, c.b - hc.b).length()
			if dd < bd:
				bd = dd
				best = 12 + k
		var g := Style.HAIR_GREY_MID
		if Vector3(g.r - hc.r, g.g - hc.g, g.b - hc.b).length() < bd:
			best = 54
		d[1] = best
	gene_look(lk, dl, seed)
	return dl


## ───────── (Q22 ④, 2026-11-12) 유전 → 겉모습 (BLOODLINES 7장 — 화면만, 능력 값은 읽지 않음) ─────────
## 머리 묶음 (lib의 sets 번호): 0 a 머릿수건 여자 · 1 b 맨머리 여자 · 2 c 곱슬·수염 남자 · 3 d 짧은 머리 (남자·남자아이) · 4 e 곱슬·수염 남자 ·
## 5 f 단발 여자아이 · 6 g 대머리 노인 (흰 머리 둘레). 머리결 변형 (doll_lib "head_var"): 0 그린 그대로 · 1 웨이브 · 2 곱슬 · 3 숱 적음 · 4 직모.
## 머리결 유전자 (Genetics.curl: 0 직모 · 1 웨이브 · 2 곱슬) → 그 머리 묶음의 변형 (g는 그린 그림이 곱슬 둘레라 직모 = 4, 곱슬 = 0)
const CURL_VAR := {0: [0, 1, 2], 1: [0, 1, 2], 3: [0, 1, 2], 5: [0, 1, 2], 6: [4, 1, 0]}
const HV_THIN := 3
## 수염 (어른 남자, 머리 묶음 d 위에 얹는 조각): 0 없음 · 1 짧은 · 2 덥수룩. 짙기는 눈썹 숱 유전 칸(Genetics.BROW, 부모 평균 ± — 닮음)에서,
## 면도는 차림 취향 씨앗(Genetics.STYLE — 유전 안 됨)에서 4명 중 1명. c · e 머리는 덥수룩한 수염이 그려져 있어 곱슬 + 덥수룩일 때만
const BEARD_SHORT_FROM := 0.28
const BEARD_FULL_FROM := 0.62
## 키 · 체격: 인형 전체를 ±6% 늘이고 줄임 (몸 그림은 그대로 — 2026-11-12 사용자 결정)
const STRETCH := 0.12
## 낮 모자 표 (몸마다) — 머리 묶음 a(머릿수건)는 모자 없음. 대머리 노인은 반쯤 모자 없이 (벗은 머리가 보이게)
const HAT_TABLE := {"adult": [-1, 1, 2, 3, 4, 6], "child": [-1, 5, 5, 2], "elder": [-1, 6, 6, 1]}


## 수염 0 없음 · 1 짧은 · 2 덥수룩 (어른 남자만 — 아이·여자는 0)
static func beard_of(g: PackedByteArray, sex: String, age: float) -> int:
	if sex != "m" or age < Balance.AGE_ADULT or g.size() < Genetics.MIN_BYTES:
		return 0
	if (Genetics.style(g) >> 5) & 3 == 0:
		return 0                                    # 깎음 (차림 취향)
	var b := float(Genetics.byte_of(g, Genetics.BROW)) / 255.0
	return 0 if b < BEARD_SHORT_FROM else (1 if b < BEARD_FULL_FROM else 2)


## 겉모습 기록(dl)에 유전 겉모습을 더함: head(머리 묶음) · hv(머리결 변형) · beard · hat · look2(셰이더 표시) · stretch(키·폭 배율).
## lk["head"] (시뮬의 look_head — 부모에게서 70% 물려받음)로 같은 성별 안의 얼굴 묶음을 고른다 → 형제끼리 닮고 부모를 닮음.
## 유전자가 없으면 (옛 저장·시험의 겉모습 사전) 고른 머리 그대로 · 변형 없음 · 표시 없음.
static func gene_look(lk: Dictionary, dl: Dictionary, seed: int) -> void:
	dl["hv"] = 0
	dl["beard"] = 0
	dl["look2"] = Vector4.ZERO
	dl["stretch"] = Vector2.ONE
	var g: PackedByteArray = lk.get("genes", PackedByteArray())
	if g.size() < Genetics.MIN_BYTES:
		return
	var sex := String(lk.get("sex", "m"))
	var age: float = lk.get("age", 10.0)
	var body := String(dl.get("body", "adult"))
	var lh := int(lk.get("head", 0))
	var curl := Genetics.curl(g)
	var bald := Genetics.bald_stage(g, sex, age)
	var beard := beard_of(g, sex, age)
	var head := 3
	var hv := 0
	if body == "child":
		head = 5 if sex == "f" else 3
	elif sex == "f":
		head = [0, 1][posmod(lh, 2)]
	elif bald == 2:
		head = 6                                    # 노년의 대머리 (둘레 머리 — 콧수염이 그려져 있어 수염 조각 없음)
		beard = 0
	elif bald == 0 and curl == 2 and beard == 2:
		head = [2, 4][posmod(lh, 2)]                # 곱슬 + 덥수룩한 수염이 그려진 얼굴
		beard = 0
	else:
		head = 3
	if CURL_VAR.has(head):
		hv = int(CURL_VAR[head][curl])
	if bald == 1 and (head == 3 or head == 1):
		hv = HV_THIN                                # 남자 성인 중반 · 여자(두 벌) 노년: 숱이 줄어듦 (머릿수건 a 밑은 안 보임)
	dl["head"] = head
	dl["hv"] = hv
	dl["beard"] = beard if head == 3 else 0
	# 낮 모자: 머릿수건 머리는 없음, 그 밖은 사람마다 (주민 번호 + 시뮬의 look_hat), 대머리 노인은 반쯤 모자 없이
	var tab: Array = HAT_TABLE.get(body, HAT_TABLE["adult"])
	var hh := hash([seed, int(lk.get("hat", 0)), 41])
	var hat := -1 if head == 0 else int(tab[posmod(hh, tab.size())])
	if head == 6 and posmod(hh >> 7, 2) == 0:
		hat = -1
	dl["hat"] = hat
	# 셰이더 표시: 주근깨 진하기 · 흰 앞머리 · 눈송이 무늬 (6종 × 자리 8 — 무늬 시드)
	var code := 1 if Genetics.forelock(g) else 0
	if Genetics.piebald(g):
		var pat := int(g[Genetics.PATTERN])
		code += 2 * (1 + pat % 6) + 16 * ((pat / 6) % 8)
	dl["look2"] = Vector4(hv, dl["beard"], Genetics.freckle_amount(g), code)
	dl["stretch"] = Vector2(1.0 + STRETCH * (Genetics.height(g) - 0.5), 1.0 + STRETCH * (Genetics.build_v(g) - 0.5))


## 몸 종류 (2026-11-08 시안 A 넷): 아이(아기 제외) = 아이 몸 f, 노인 = 노인 몸 g, 그 밖 = 어른 몸
static func body_of(lk: Dictionary) -> String:
	var age: float = lk.get("age", 10.0)
	if age < Balance.AGE_ADULT:
		return "child"
	if age >= Balance.AGE_ELDER:
		return "elder"
	return "adult"


func setup_from(r: Resident) -> void:
	seed_id = r.id
	_hh_seed = household_of(r)
	build_look(look_of(r))


func build_look(lk: Dictionary) -> void:
	for c in get_children():
		c.queue_free()
	look = parts_for(lk)
	job_key = "?"
	face = "?"
	_job = {"hat": "", "over": [], "robe": false}
	_job_tool = ""
	_job_name = ""
	_tool_kind = "?"
	_item_kind = ""
	_clip_now = ""
	var sid := seed_id if seed_id >= 0 else int(get_instance_id() % 100000)
	_rng.seed = hash([sid, lk.get("hair_i", 0), lk.get("cloth", 0)])
	_style = _rng.randi() % 6
	var age: float = lk.get("age", 10.0)
	_baby = look["baby"]
	_child = age < Balance.AGE_ADULT and not _baby
	_female = String(lk.get("sex", "m")) == "f"
	_infant = _baby and age < INFANT_AGE
	if _baby:
		_base_scale = BABY_SCALE
	elif _child:
		# 아이 몸(f)은 제 비율(큰 머리)로 그려져 있음 — 키만 나이에 따라 (시안 A 작은 화면: 아이 ≈ 어른의 0.8, 뾰족 모자 포함)
		_base_scale = CHILD_SCALE.x + (CHILD_SCALE.y - CHILD_SCALE.x) * clampf((age - 1.0) / 3.0, 0.0, 1.0)
	elif look["elder"]:
		_base_scale = ELDER_SCALE      # 노인 몸(g)은 굽은 등으로 그려져 있음
	else:
		_base_scale = 1.0
	_gait = 0.85 if look["elder"] else 1.0
	dlook = doll_look(lk, sid, _hh_seed if _hh_seed >= 0 else sid)
	# 바깥 코드가 붙이는 빈 자리 (뼈 대신 — 횃불은 오른손 높이 옆에)
	var hand := Node3D.new()
	hand.position = Vector3(0.18, 0.42, 0.05)
	add_child(hand)
	arm_r = hand
	arm_l = hand
	tool = Node3D.new()
	hand.add_child(tool)
	tool.visible = false
	chest = Node3D.new()
	chest.position = Vector3(0, 0.55, 0)
	add_child(chest)
	head = Node3D.new()
	head.position = Vector3(0, 0.95, 0)
	add_child(head)
	item = Node3D.new()
	chest.add_child(item)
	item.visible = false
	fdoll = null
	_f_on = false
	_d_stale = false
	_fk_body = ""
	_uv_frame = -1
	_f_clip = ""
	doll = Doll.new()
	doll.material_override = game_material()
	add_child(doll)
	doll.set_look(dlook)
	doll.set_instance_shader_parameter("look2", dlook.get("look2", Vector4.ZERO))
	_doll_h = INFANT_H if _infant else DOLL_H * _base_scale
	doll.screen_h = _doll_h
	if _infant:                 # 젖먹이: 크림 강보 (옷 물감을 크림으로)
		var dd: Array = dlook["dye"]
		dd[2] = Lib.OFF["cream"]
		dd[3] = Lib.OFF["cream"] + 1
		doll.set_look(dlook)
	_d_outfit = -2
	_d_hat = -2
	_d_prop = -2
	_d_clip = ""
	_d_rate = -1.0
	_d_phase = float(_rng.randi() % 997) / 997.0
	scale = Vector3.ONE * _base_scale * Style.RESIDENT_SCALE
	_refresh_doll()


# ───────────────────────── 3D 모델 함수 대신 (뼈·얼굴 없음) ─────────────────────────
func set_lod(close: bool) -> void:
	lod_close = close           # 인형은 가까이·멀리 같음


func set_job(job: String, chief := false) -> void:
	var key := "%s|%s" % [job, chief]
	if key == job_key:
		return
	job_key = key
	_job_name = job
	_job_tool = String(job_look(job, chief)["tool"])
	_tool_kind = "?"


func set_tool(workplace: String) -> void:
	_tool_kind = _job_tool if _job_tool != "" else str(job_look(workplace)["tool"])


func set_face(f: String) -> void:
	face = f                    # 얼굴 칸은 아직 없음 (점 눈 하나)


func set_pale(_on: bool) -> void:
	pass


func set_item(kind: String) -> void:
	_item_kind = kind


func tilt_head(_up: float, _side: float) -> void:
	pass


func aim_arm_r(_rx: float, _rz := 0.0) -> void:
	pass


func apply_pose(a: String, _t: float) -> void:
	anim = a
	_refresh_doll()


## [톡 반응] 인형 전체 움직임 입히기 (TapReact가 반응하는 동안 매 화면, 끝나면 기본값으로). 어떤 주민 인형이든 이 함수 하나만 있으면 된다.
func set_react(off: Vector3, squash: Vector2, roll: float, turn: float, hint: String) -> void:
	react_off = off
	react_sq = squash
	react_roll = roll
	react_turn = turn
	if hint != react_hint:
		react_hint = hint
		_refresh_doll()
	_push_misc()


## 인형 자리 + 키·폭·빠르기·기울기를 GPU에 (셰이더는 인형 노드의 원점만 읽는다 — 배율·회전은 여기 값으로)
func _push_misc() -> void:
	if doll == null:
		return
	doll.position = transform.basis.inverse() * react_off + Vector3(0.0, _lift, 0.0)     # 톡 반응 자리 + (Q2-b) 몸짓 높이
	var c := cos(react_turn * TAU)
	if absf(c) < 0.16:                              # 종이 인형이 돌 때 선으로 사라지지 않게 (옆모습 두께)
		c = 0.16 if c >= 0.0 else -0.16
	var gk: Vector2 = dlook.get("stretch", Vector2.ONE)              # (Q22 ④) 키 · 체격 (±6%, 화면만)
	var w := react_sq.x * c * _warp.y * gk.y                        # (Q2-b) 화면 몸짓(set_body_warp)과 곱해서
	var sy := maxf(react_sq.y, 0.05) * _warp.x * gk.x
	var shown_mirror: float = fdoll.mirror if _f_on else doll.mirror     # 지금 보이는 인형의 좌우 (방식 C가 보이면 컷아웃 보기는 멈춰 있음)
	var face := shown_mirror * (-1.0 if w < 0.0 else 1.0)            # 화면에서 바라보는 쪽 (오른쪽 +1)
	var roll := react_roll + _warp.z * face                         # 몸짓 기울임은 화면 오른쪽이 + → 바라보는 쪽 기준으로 바꿔 더함
	if _f_on:
		_d_stale = true                                             # (X) 숨은 컷아웃 인형엔 보내지 않음 — 돌아올 때 다시
	else:
		doll.set_instance_shader_parameter("misc", Vector4(_doll_h * sy, w / sy, maxf(_d_rate, 0.0), -roll * face))
		doll_pushes += 1
	if fdoll != null:
		fdoll.set_react(doll.position, w, sy, roll)              # 방식 C 인형도 같은 반응 (frame_doll.set_react)


## [톡 반응] 지금 그려진 인형의 머리 높이 (세계, 찌그러짐 전) — 말풍선 자리. 누웠으면 낮게, 앉았으면 조금 낮게
func react_top() -> float:
	if _infant or _d_clip == "sleep":
		return _doll_h * 0.42
	if _d_clip == "sit" or _d_clip == "eat" or _d_clip == "kneel":
		return _doll_h * 0.78
	return _doll_h


## (E2-1 2차) 하루의 흐름(view/daily_view.gd)이 그린 인형에만 입히는 동작: 힌트 → 동작. 소품은 eat만 빵, 나머지는 빈손 (화면만 — 시뮬의 짐·식량은 그대로)
const REACT_CLIPS := {"sit": "sit", "eat": "eat", "walk": "walk", "carry": "carry", "hold": "hold", "stand": "idle"}


## 반응하는 동안의 동작: 걷던 발은 멈추고(짐은 든 채), 올려다보기는 서 있을 때만 — 일·앉기·잠은 그대로
func _react_clip(clip: String) -> String:
	if react_hint == "" or _baby:
		return clip
	if react_hint == "lookup" and (clip == "idle" or clip == "walk"):
		return "lookup"
	if REACT_CLIPS.has(react_hint):                 # (E2-1 2차) 하루의 흐름이 정한 동작 — 잠·기도는 그대로
		return clip if clip == "sleep" or clip == "kneel" else String(REACT_CLIPS[react_hint])
	if clip == "walk":
		return "idle"
	if clip == "carry":
		return "hold"
	return clip


func tick(dt: float) -> void:
	_t += dt * Style.ANIM_SPEED
	_tick_frame = Engine.get_process_frames()
	_refresh_doll()


var _tick_frame := -10           # tick이 마지막으로 불린 장면 (move_to가 같은 일을 두 번 하지 않게)


# ───────────────────────── 인형에 입히기 ─────────────────────────
## 지금 틀 인형 동작 + 소품 + 일 옷 차림인지 (데이터만 — 바뀔 때만 GPU에 보내는 건 _refresh_doll)
func doll_state() -> Dictionary:
	var a := anim
	var carrying := _item_kind != "" and _item_kind != "해바라기씨" and _item_kind != "유모차"     # (F-2) 굴리는 씨앗은 땅 위에 따로 · (E2-3) 유모차는 따로 그린 그림 (OutingView), 산책하는 부모는 바구니를 들지 않는다
	var arms := carrying or carry_baby or arms_out
	var clip := "idle"
	var prop := -1
	var work := false
	match a:
		"walk", "run", "carry":
			clip = "carry" if arms else "walk"
		"work", "torch":
			work = true
			if _tool_kind == "?":
				set_tool("")
			if a == "work" and WORK_PROP.has(_tool_kind) and not _baby:
				clip = "hoe"
				prop = WORK_PROP[_tool_kind]
				if reaping and _job_name == REAP_JOB:
					clip = "reap"
					prop = REAP_PROP
			elif a == "work" and (GATHER_TOOLS.has(_tool_kind) or GATHER_JOBS.has(_job_name)):
				clip = "gather"
		"idle":
			clip = "hold" if arms else "idle"
		"sit":
			clip = "sit"
		"eat":
			clip = "eat"
			prop = int(CARRY_PROP.get(_item_kind.split(":")[0], 0)) if carrying and _item_kind.split(":")[0] == "빵" else 0
		"sleep":
			clip = "sleep"
		"pray":
			clip = "kneel"
		"gather":                              # (EVENTS_STAGING 2b) 제단 돌을 숙여 줍고 내려놓음
			clip = "gather"
		"lookup":                              # (수첩 쪽지 7) 하늘을 올려다보며 가리킴
			clip = "lookup"
		_:
			clip = "idle"
	if _baby:
		carrying = false
		work = false
		prop = -1
		if _infant or baby_mode == "carried" or baby_mode == "cradle":
			clip = "sleep"
		elif baby_mode == "toddle":
			clip = toddle_clip
		elif clip != "sleep":
			clip = "sit" if clip == "sit" else "idle"
	if carrying and (clip == "carry" or clip == "hold"):
		prop = int(CARRY_PROP.get(_item_kind.split(":")[0], PROP_BASKET))
	return {"clip": clip, "prop": prop, "work": work}


## 일 옷 차림: 일(work 동작)을 시작하면 입고, 행동이 바뀌거나 쉬기·먹기·자기·기도로 가면 벗음 (아기는 없음)
func _update_shift(work_now: bool) -> void:
	if _baby:
		on_shift = false
		return
	if not on_shift:
		if work_now:
			on_shift = true
			_shift_action = _action
	elif _action != _shift_action or OFF_SHIFT.has(anim):
		on_shift = work_now and not OFF_SHIFT.has(anim)
		_shift_action = _action


func _refresh_doll() -> void:
	if doll == null:
		return
	var s := doll_state()
	if REACT_CLIPS.has(react_hint) and not _baby and s["clip"] != "sleep" and s["clip"] != "kneel":
		s["prop"] = 0 if react_hint == "eat" else -1     # (E2-1 2차) 그림만: 한 입 먹는 빵 · 그 밖엔 연장을 내려놓은 빈손
	_update_shift(bool(s["work"]))
	var outfit := int(dlook["jobs"]["farmer"]) if on_shift else int(dlook["personal"])
	var hat := int(dlook["hat"]) if daylight and not _baby else -1          # R6: 낮엔 머리쓰개, 저녁엔 벗음
	var sel_dirty := false
	if outfit != _d_outfit or hat != _d_hat:
		if _d_outfit >= 0 and outfit != _d_outfit and not _f_on:      # 방식 C 인형은 일 옷이 아직 없음 (평상복 그대로) → 연기도 없음
			_swap_puff()
		_d_outfit = outfit
		_d_hat = hat
		doll.look = dlook
		doll.outfit = outfit
		sel_dirty = true
	if int(s["prop"]) != _d_prop:
		_d_prop = int(s["prop"])
		sel_dirty = true
	var clip: String = _react_clip(s["clip"])
	var rate: float = Lib.CLIP_RATE[clip]
	if clip == "walk" or clip == "carry":
		# 발이 미끄러지지 않게: 주기/초 = 땅 빠르기 ÷ (한 주기 걸음 × 키 배율). 모르면 보통 걸음
		var g := _gspeed()
		if g < 0.0:
			g = GROUND_NORMAL * _gait * (Balance.WALK_CHILD if _child else 1.0)
		var stride := Lib.stride_rig(Lib.SETS[clampi(outfit, 0, Lib.SETS.size() - 1)], clip) * _doll_h / float(Lib.lib()["fig"])
		var wr := _walk_rate_f(g / maxf(stride, 0.01), frame_dt())     # (= walk_rate, -1 = travel)
		if wr < 0.0:
			clip = "travel" if clip == "walk" else "hold"
		rate = wr if wr >= 0.0 else Lib.CLIP_RATE[clip]
	rate = minf(rate, MAX_FRAME_STEP / frame_dt())
	var st_dirty := false
	if clip != _d_clip or not is_equal_approx(rate, _d_rate):
		var now := _shader_time()
		if clip == _d_clip and _d_rate > 0.0:
			_d_phase = fposmod(_d_phase + now * (_d_rate - rate), 1.0)     # 빠르기만 바뀜: 지금 자세에서 이어서
		elif clip != _d_clip:
			_d_phase = fposmod(_rng.randf() - now * rate, 1.0)            # 새 동작: 사람마다 다른 자리에서
		_d_clip = clip
		_d_rate = rate
		doll.clip = clip
		st_dirty = true
	# (Q22 ⑤ X) 어느 인형을 보일지 먼저 정하고, 보이는 인형에만 GPU 일을 함 — 숨은 컷아웃 인형은 '밀림'만 적어 두었다가
	# 돌아오는 장면에 보이기 전에 한꺼번에 (sel · misc · st, 보기는 _update_view가 고른 뒤 다시) → 한 장면 튐 · 옛 값 없음
	var use_f := _frames_ok()          # (몸 · 동작 확인은 _fk_*에 남아 _refresh_frames가 다시 찾지 않음)
	if not use_f and _f_on:
		_f_on = false
		fdoll.visible = false
		doll.visible = true
	if use_f:
		_d_stale = _d_stale or sel_dirty or st_dirty or not _f_on
	else:
		if _d_stale or sel_dirty:
			doll.set_instance_shader_parameter("sel", Vector4(_d_outfit, int(dlook["head"]), _d_hat, _d_prop))
			doll_pushes += 1
		if _d_stale or st_dirty:
			_push_misc()
			doll.set_instance_shader_parameter("st", Vector4(doll.view, doll.mirror, Lib.CLIPS.find(_d_clip), _d_phase))
			doll_pushes += 1
		_d_stale = false
	if use_f:
		_refresh_frames()
	_update_view()


## (Q2-b) 인형 통째 몸짓 — 화면만: 키 배율 sy · 폭 배율 sx (눌림·늘어남) · 기울임 lean (라디안, 발 둘레 — 화면 오른쪽이 +).
## (1, 1, 0)이면 원래대로. 바뀔 때만 GPU에 보낸다 — 톡 반응(set_react)과 곱·합으로 함께 간다 (_push_misc)
func set_body_warp(sy := 1.0, sx := 1.0, lean := 0.0) -> void:
	var w := Vector3(maxf(sy, 0.05), sx, lean)
	if doll == null or w.is_equal_approx(_warp):
		return
	_warp = w
	_push_misc()


## (Q2-b) 인형만 위로 (그림자·자리는 그대로 — 폴짝, 요람 속 높이). 인형 자리는 _push_misc 한 곳에서만 쓴다 (톡 반응과 겹쳐도 됨)
func set_body_lift(y := 0.0) -> void:
	if doll == null or is_equal_approx(y, _lift):
		return
	_lift = y
	_push_misc()


## 방식 C 시험판: 쓸 수 있으면 장면 그림 인형을 보이고 컷아웃 인형을 숨김 (걸음 빠르기 = 땅 빠르기 ÷ 그림에서 잰 보폭)
func _frames_ok() -> bool:
	if not (frames_force == 1 or (frames_force < 0 and FrameLib.enabled())) or _baby or not FRAME_CLIPS.has(_d_clip):
		return false                  # (X) 끈 채로는 몸 고르기도 하지 않음 (기본 게임 — 장면마다 두 번)
	var body := frame_body()
	if body == "":
		return false
	var fc := _frame_clip()
	if body != _fk_body or fc != _fk_clip:
		_fk_body = body
		_fk_clip = fc
		_fk_ok = fc != "" and FrameLib.clip_index(fc, body) >= 0
		_fk_stride = FrameLib.stride_rig(fc, body) / float(FrameLib.lib(body)["fig"]) if _fk_ok else 0.0
	return _fk_ok


## 방식 C 몸 (Q22, 2026-11-12 "어른 남자 먼저"): 어른 여자 평상복 a → 여자 장면 그림 (woman_c) · 어른 여자 평상복 b → 여자 둘째 벌
## (woman2_c — 치마·끈 조끼·앞치마, Q22 ⑤, 만들어 둔 때만) · 어른 남자 평상복 (c·e) → 남자 장면 그림 (man_c — 튜닉·바지, 만들어 둔 때만) ·
## 그 밖 "" (컷아웃 인형 그대로). 평상복 묶음은 Lib.look_from이 어른 여자에게 a·b 반반으로 고른 것 그대로
func frame_body() -> String:
	var p := int(dlook.get("personal", -1))
	if is_same(dlook, _fb_d) and p == _fb_p:
		return _fb                    # (X) 같은 겉모습 기록 · 같은 평상복이면 고른 몸 그대로 (장면마다 부름)
	_fb_d = dlook
	_fb_p = p
	_fb = _pick_frame_body(p)
	return _fb


var _fb_d: Dictionary
var _fb_p := -9
var _fb := ""


func _pick_frame_body(p: int) -> String:
	if String(dlook.get("body", "")) != "adult":
		return ""
	if p == 0:
		return FrameLib.DIR
	if p == 1 and String(dlook.get("sex", "")) == "f" and FrameLib.has_body(FrameLib.WOMAN2_DIR):
		return FrameLib.WOMAN2_DIR
	if String(dlook.get("sex", "")) == "m" and MAN_VEST.has(p) and FrameLib.has_body(FrameLib.MAN_DIR):
		return FrameLib.MAN_DIR
	return ""


## 남자 평상복 묶음 → 조끼 (Q22): 남자 장면 그림의 조끼 자리(둘째 물감)를 생김새의 크림 물감으로 칠하면 조끼, 튜닉 물감으로 칠하면 조끼 없음
const MAN_VEST := {2: true, 4: false}


## 여자 둘째 벌의 앞치마 (Q22 ⑤): 집안마다 (세 집 중 두 집이 앞치마) — 그 안에서 다섯 명 중 한 명은 반대.
## 앞치마 자리(둘째 물감)를 크림 물감으로 칠하면 앞치마, 치마 물감으로 칠하면 앞치마 없음 (남자 조끼와 같은 식)
const APRON_HOUSES := 3
const APRON_FLIP := 5


func woman2_apron() -> bool:
	var hh := _hh_seed if _hh_seed >= 0 else seed_id
	var on := posmod(hash([hh, 59]), APRON_HOUSES) != 0
	if posmod(hash([seed_id, 61]), APRON_FLIP) == 0:
		on = not on
	return on


## 방식 C 인형에 넘기는 생김새: 조끼 없는 남자 · 앞치마 없는 여자 둘째 벌은 둘째 물감(조끼·앞치마 자리)을 주 물감(튜닉·치마)으로
func _frame_look() -> Dictionary:
	var fb := frame_body()
	if fb == FrameLib.WOMAN2_DIR:
		if woman2_apron():
			return dlook
	elif fb != FrameLib.MAN_DIR or bool(MAN_VEST.get(int(dlook.get("personal", -1)), false)):
		return dlook
	var l := dlook.duplicate(true)
	var d: Array = l["dye"]
	d[3] = d[2]
	return l


## 지금 동작의 장면 그림 이름. 아기를 안으면 (v13) 나르기 → 안고 걷기(cradle), 안고 서기 → 안고 서기(rock) — 그 밖의 동작은 아기 장면이 없어 컷아웃 인형
func _frame_clip() -> String:
	var fc: String = FRAME_CLIPS[_d_clip]
	if arms_out and not carry_baby:
		return ""                     # (E2-3) 빈손으로 내민 팔: 그 장면 그림이 없어 컷아웃 인형 그대로
	if carry_baby:
		if not baby_held:
			return ""                 # 안아 주는 몸짓 (연출): 아기 없는 안기 팔 → 컷아웃 인형 그대로
		return "cradle" if fc == "carry" else ("rock" if fc == "hold" else "")
	return fc


## 방식 C 인형에 입히기 — _refresh_doll이 _frames_ok()일 때만 부름 (끄기는 _refresh_doll이)
func _refresh_frames() -> void:
	var body := _fk_body              # _frames_ok()가 방금 고른 몸 · 동작
	var fc := _fk_clip
	if fdoll == null:
		fdoll = FrameDoll.new()
		fdoll.setup(FrameLib.material(game_material().get_shader_parameter("palette"), body), body)
		add_child(fdoll)
	elif fdoll.body != body:          # (Q22) 생김새가 바뀌어 다른 몸 — 메시·재질을 그 몸 것으로
		fdoll.setup(FrameLib.material(game_material().get_shader_parameter("palette"), body), body)
		_f_clip = ""
		_f_hat = -9
	if not _f_on:
		_f_on = true
		fdoll.visible = true
		_f_clip = ""
		_f_hat = -9
	doll.visible = false
	fdoll.screen_h = _doll_h
	if _d_hat != _f_hat:
		_f_hat = _d_hat
		fdoll.set_look(_frame_look(), _d_hat)
	var walking := fc == "walk" or fc == "carry" or fc == "cradle"
	if carry_baby:
		fdoll.set_baby(baby_dye.x, baby_dye.y)
		fdoll.set_prop(_d_prop, FrameLib.BABY_LOAD)      # v13: 품의 아기도 따로 그린 그림 (짐과 같은 식)
	else:
		fdoll.set_prop(_d_prop, _item_kind if (fc == "carry" or fc == "hold") and _item_kind != "유모차" else "")      # v12: 나르는 짐은 따로 그린 그림 (밀·밀가루·빵이 갈림)
	var rate: float = 0.0 if walking else Lib.CLIP_RATE["hold" if fc == "rock" else fc]
	var g := 0.0
	if walking:
		g = _gspeed()
		if g < 0.0:
			g = GROUND_NORMAL * _gait
		# 그림의 보폭은 화면 가로 (비스듬한 보기에서 잰 값) → 화면 움직임을 그 보기의 걸음 축에 투영한 몫만큼 (발이 땅에 붙게,
		# 사선으로 내려올 때 너무 느리게 미끄러지지 않게 — 2026-11-09), 앞·뒤 보기는 0.8
		var stride := _fk_stride * _doll_h
		var hk: float = fdoll.step_k        # 화면 움직임을 그림의 걸음 축에 투영 (frame_doll.update_view)
		var wr := _walk_rate_f(g * hk / maxf(stride, 0.01), frame_dt())
		rate = 0.0 if wr < 0.0 or _d_clip == "travel" else wr
	fdoll.cycle_len = g / rate if rate > 0.0 and walking else 0.0          # = g_cycle(fc, rate) (발 붙이기: 한 주기에 땅에서 가는 길)
	if fc != _f_clip or not is_equal_approx(rate, _f_rate):
		var now := _shader_time()
		if fc == _f_clip and _f_rate >= 0.0:
			_f_phase = fposmod(_f_phase + now * (_f_rate - rate), 1.0)
		else:
			_f_phase = fposmod(_rng.randf() - now * rate, 1.0)
		_f_clip = fc
		_f_rate = rate
		fdoll.set_clip(fc, rate, _f_phase)


## 방식 C 인형이 지금 어깨에 그리고 있는 짐 그림 ("" = 컷아웃 인형이거나 빈손) — 짐을 따로 그리는 곳(제단 돌)이 겹쳐 그리지 않게
func frame_load() -> String:
	return FrameLib.load_name(_item_kind) if _f_on and (_f_clip == "carry" or _f_clip == "hold") and _item_kind != "유모차" else ""


## 방식 C 발 붙이기 (frame_doll.gdshader lockv): 걸음 한 주기에 땅에서 가는 길 (세계) — 걷지 않거나 멈춘 보폭이면 0
func g_cycle(fc: String, rate: float) -> float:
	if rate <= 0.0 or not (fc == "walk" or fc == "carry" or fc == "cradle"):
		return 0.0
	var g := _gspeed()
	return (g if g >= 0.0 else GROUND_NORMAL * _gait) / rate


## 걸음 동작을 맞출 땅 빠르기: 하루의 흐름이 그린 인형만 걷게 할 때는 그 빠르기 (E2-1 2차), 아니면 잰 값
func _gspeed() -> float:
	return react_speed if react_speed >= 0.0 and (react_hint == "walk" or react_hint == "carry") else _ground


## 땅에 맞는 걸음 빠르기 want(주기/초) · 장면 길이 fdt(초) → {travel: 걸음 대신 멈춘 보폭인가, rate: 걸음 빠르기 (상·하한·계단)}
static func walk_rate(want: float, fdt: float) -> Dictionary:
	if want > RATE_TRAVEL or want * fdt > TRAVEL_STEP:
		return {"travel": true, "rate": Lib.CLIP_RATE["travel"]}
	var r := snappedf(clampf(want, RATE_MIN, RATE_MAX), RATE_STEP)
	return {"travel": false, "rate": minf(r, MAX_FRAME_STEP / fdt)}


## walk_rate와 같은 고르기 — 사전을 만들지 않음 (장면마다 부름): 걸음 빠르기, travel이면 -1
static func _walk_rate_f(want: float, fdt: float) -> float:
	if want > RATE_TRAVEL or want * fdt > TRAVEL_STEP:
		return -1.0
	return minf(snappedf(clampf(want, RATE_MIN, RATE_MAX), RATE_STEP), MAX_FRAME_STEP / fdt)


## 지금 한 장면의 길이 (초) — FPS를 모르거나 너무 높으면 낮게 잡음 (느린 폰에서도 넘어가지 않게)
static func frame_dt() -> float:
	return 1.0 / clampf(Engine.get_frames_per_second(), MIN_FPS, 60.0)


## 빠른 흐름(VillageView.fast)에선 tick이 불리지 않고 자리만 순간이동 → 땅 빠르기를 잰 김에 인형도 맞춤 (아주 빠르면 travel)
func move_to(p: Vector3, dt: float) -> void:
	super(p, dt)
	# (Q22 ⑤ X) 보통 흐름에선 VillageView가 이 뒤에 tick을 불러 어차피 다시 입힘 → 직전 장면에 tick이 있었으면 여기선 건너뜀
	# (빠른 흐름처럼 tick이 끊긴 때만 여기서 — 흐름이 바뀌는 첫 장면만 한 장면 늦음)
	if doll != null and dt > 0.0 and Engine.get_process_frames() - _tick_frame > 1:
		_refresh_doll()


## 옷 갈아입기: 인형을 잠깐 숨기고 크림 연기 몇 덩이가 퍼졌다 사라짐 (화면만, 제 시계로 — 빠른 흐름에서도 끝남)
static var _puff_mesh: SphereMesh
static var _puff_mat: StandardMaterial3D


func _swap_puff() -> void:
	swaps += 1
	if _puff_mesh == null:
		_puff_mesh = SphereMesh.new()
		_puff_mesh.radius = 0.06
		_puff_mesh.height = 0.12
		_puff_mesh.radial_segments = 8
		_puff_mesh.rings = 4
		_puff_mat = StandardMaterial3D.new()
		_puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_puff_mat.albedo_color = Style.CREAM
		_puff_mesh.material = _puff_mat
	var puff := SwapPuff.new()
	puff.doll = doll
	puff.mesh_ref = _puff_mesh
	puff.height = _doll_h
	doll.visible = false
	add_child(puff)


## 바라보는 쪽(rotation.y — 걸을 땐 걷는 쪽, 서면 마지막 쪽 · 일할 땐 일감 쪽)과 카메라로 앞·비스듬·뒤 고르기
func _update_view() -> void:
	if not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var f := global_transform.basis.z
	var lock := "front" if FRONT_ONLY.has(_d_clip) else ("side" if SIDE_ONLY.has(_d_clip) else "")
	var fr := Engine.get_process_frames()
	var key := ("C" if _f_on else "A") + lock
	var cb := cam.global_transform.basis
	if fr == _uv_frame and f == _uv_dir and key == _uv_key and cb == _uv_cam:
		return                      # (X) 이 장면에 같은 쪽 · 같은 인형 · 같은 카메라로 이미 고름 (move_to 다음 tick)
	_uv_frame = fr
	_uv_dir = f
	_uv_key = key
	_uv_cam = cb
	doll.move_dir = Vector3(f.x, 0.0, f.z)
	doll.view_lock = lock
	if _f_on:                   # (X) 방식 C 인형만 보기를 고름 — 컷아웃 인형의 보기 · 좌우는 그 값을 따라 둠 (GPU에는 돌아올 때 보냄)
		fdoll.move_dir = doll.move_dir
		fdoll.view_lock = doll.view_lock
		fdoll.update_view(cam)
		doll.view = fdoll.view
		doll.mirror = fdoll.mirror
		return
	var v0: int = doll.view
	var m0: float = doll.mirror
	doll.update_view(cam)
	if doll.view != v0 or doll.mirror != m0:
		doll.set_instance_shader_parameter("st", Vector4(doll.view, doll.mirror, Lib.CLIPS.find(_d_clip), _d_phase))
		doll_pushes += 1


## 셰이더 TIME과 같은 시계 (초, rollover마다 되돌아감)
static func _shader_time() -> float:
	if _rollover <= 0.0:
		_rollover = float(ProjectSettings.get_setting("rendering/limits/time/time_rollover_secs", 3600.0))
	return fposmod(Time.get_ticks_usec() / 1.0e6, _rollover)


static var _rollover := 0.0


# ───────────────────────── 아기 자리 (화면만) ─────────────────────────
## VillageView가 매 장면 부름 (종이 인형일 때). 시뮬레이션은 아기를 집 자리에 재워 두므로 (resident_ai._baby — GD 7.3) 화면에서만:
##   · 젖먹이(1살 아래): 깨어서 걷거나 서 있는(짐 없는) 부모가 품에 안음 → 부모 인형 = 안기 팔(carry_baby), 아기 = 가슴 앞에 누운 작은 인형.
##     안을 부모가 없으면(일·잠·짐) 집 문 옆 요람에 누움 — 부모가 앉아 있으면 그 곁의 요람
##   · 걸음마 아기: 부모 곁(뒤 옆)에서 따라 걷거나(부모가 걸으면) 앉아 놂, 부모가 없으면 문 옆에 앉아 놂
## 돌려줌: 아기 id → 정한 자리 (시험) {mode, pos, carrier}
static func place_babies(v: Village, people: Array, models: Dictionary) -> Dictionary:
	var out := {}
	var taken := {}
	for m: Variant in models.values():
		if m is CutoutResident:
			(m as CutoutResident).carry_baby = false
			(m as CutoutResident).baby_held = false
	var cam: Camera3D = null
	var pr := ChildOutings.pram(v)             # (E2-3) 유모차 산책 중인 아기는 유모차에 (그림은 OutingView)
	for r: Resident in people:
		if not r.is_baby() or r.dead:
			continue
		var bm := models.get(r.id) as CutoutResident
		if bm == null:
			continue
		var infant := r.age < INFANT_AGE
		if infant and not pr.is_empty() and int(pr.get("b", -1)) == r.id:
			var pc := models.get(int(pr.get("cr", -1))) as CutoutResident
			if pc != null and pc.visible:
				taken[int(pr["cr"])] = true
				bm.minder_id = int(pr["cr"])
				bm.set_baby_mode("pram", pc.position, pc.rotation.y, cam)
				if bm.doll != null and not bm.doll.visible:
					bm.doll.visible = true
				out[r.id] = {"mode": "pram", "pos": pc.position, "carrier": int(pr["cr"])}
				continue
		# (Q2-b) 누가 아기를 보는가는 시뮬 규칙 (ChildPlay.minder): 깨어서 집 가까이 돌보거나 쉬는 부모 (엄마 먼저) · 한집 노인.
		# 일하러·멀리 나간 부모는 아기를 데려가지 않는다 → 문 옆 요람 (정보 창의 '하는 일'과 화면이 같음)
		var best: Resident = ChildPlay.minder(v, r, people)
		if best != null:
			var pm0 := models.get(best.id) as CutoutResident
			if pm0 == null or not pm0.visible:
				best = null
		var mode := "cradle"
		var pos := Vector3.INF
		var yaw := bm.rotation.y
		var carrier := -1
		if best != null:
			var pm: CutoutResident = models[best.id]
			if cam == null and pm.is_inside_tree():
				cam = pm.get_viewport().get_camera_3d()
			var light := (best.carry == "" or best.carry == "유모차") and (best.anim == "walk" or best.anim == "idle" or best.anim == "carry")     # (E2-3) 유모차 없이 나선 산책: 젖먹이는 품에
			var f := Vector3(sin(pm.rotation.y), 0, cos(pm.rotation.y))
			var side := Vector3(f.z, 0, -f.x)
			if infant and light and not taken.has(best.id):
				mode = "carried"
				carrier = best.id
				taken[best.id] = true
				pm.carry_baby = true
				pm.baby_held = true
				var bd: Array = bm.dlook.get("dye", [])
				pm.baby_dye = Vector2i(int(bd[0]), int(bd[1])) if bd.size() >= 2 else Vector2i(-1, -1)
				pm._refresh_doll()
				pos = pm.position + pm.react_off       # [톡 반응] 폴짝 뛰는 부모 품에서 함께
				yaw = pm.rotation.y
			elif not infant:
				mode = "toddle"
				carrier = best.id
				pos = pm.position - f * 0.22 + side * 0.24      # 부모 곁: 바라보는 쪽 기준 옆 뒤 (걸으면 따라오는 모양)
				yaw = pm.rotation.y
				var walking := best.anim == "walk" or best.anim == "carry"
				bm.toddle_clip = "walk" if walking else ("sit" if best.anim == "sit" or best.anim == "eat" else "idle")
				bm._ground = pm._ground
			elif best.anim == "sit" or best.anim == "eat":
				carrier = best.id
				pos = pm.position + side * 0.32 + f * 0.06        # 앉은 부모 곁의 요람
				yaw = pm.rotation.y
		if pos == Vector3.INF:
			pos = _door(v, r, bm)
			if not infant:
				mode = "toddle"
				bm.toddle_clip = "sit"
		bm.minder_id = carrier
		bm.set_baby_mode(mode, pos, yaw, cam)
		# 방식 C 부모(v13)는 품의 아기를 제 그림으로 그린다 → 아기의 컷아웃 인형은 숨김 (화면만 — 아기 노드·자리·고르기는 그대로)
		var in_frames := mode == "carried" and (models[carrier] as CutoutResident)._f_on
		if bm.doll != null and bm.doll.visible == in_frames:
			bm.doll.visible = not in_frames
		out[r.id] = {"mode": mode, "pos": pos, "carrier": carrier}
	return out


static func _find(people: Array, id: int) -> Resident:
	for q: Resident in people:
		if q.id == id:
			return q
	return null


## 집 문 옆 (집 가운데에서 앞(+y)으로 집 크기의 반 + 조금, 옆으로 조금) — 집이 없으면 모닥불 곁. 땅 높이는 지금 자리 그대로
static func _door(v: Village, r: Resident, bm: CutoutResident) -> Vector3:
	var hm := v.bld(r.home)
	var c := Vector2(hm.x, hm.y) if hm != null else Vector2(v.fire.x, v.fire.y)
	var front := (hm.size() * 0.5 if hm != null else 0.6) + CRADLE_OFF.y
	return Vector3(c.x + CRADLE_OFF.x + float(r.id % 3) * 0.12, bm.position.y, c.y + front)


## 아기 자리 입히기: 품 = 부모 가슴 앞(카메라 쪽 조금, 품 높이), 요람 = 요람 위에 누움, 걸음마 = 그 자리에 서서·걸어서
func set_baby_mode(mode: String, pos: Vector3, yaw: float, cam: Camera3D = null) -> void:
	baby_mode = mode
	visible = true
	rotation.y = yaw
	if mode == "carried":
		var cu := 0.7
		var back := Vector3(0, 0, 1)
		if cam != null:
			cu = maxf(cam.global_transform.basis.y.y, 0.3)
			var bz := cam.global_transform.basis.z
			back = Vector3(bz.x, 0, bz.z).normalized()
		# 부모 인형의 품 높이 (rig HOLD_RIG) → 세계: 인형은 세로를 1/cu 늘려 그리므로 같게 맞춤. 누운 인형은 SLEEP_LIFT만큼 떠 있음
		var fig := float(Lib.lib()["fig"])
		var lift := (HOLD_RIG * DOLL_H / fig - Lib.SLEEP_LIFT * _doll_h / fig) / cu
		position = pos + Vector3(0, lift, 0) + back * 0.06
	elif mode == "cradle":
		position = pos + Vector3(0, 0.03, 0)
	elif mode == "pram":
		position = pos                         # 유모차 속 자리·높이는 OutingView가 (이 뒤에)
	else:
		move_to(pos, get_process_delta_time())
	if mode == "cradle":
		if cradle == null:
			cradle = _make_cradle()
			add_child(cradle)
		cradle.visible = true
	elif cradle != null:
		cradle.visible = false
	_refresh_doll()


## 요람: 마른 나무색 낮은 타원 바구니 (3D, 그리기 1번 — 아기 하나에 하나)
static var _cradle_mesh: CylinderMesh


static func _make_cradle() -> MeshInstance3D:
	if _cradle_mesh == null:
		_cradle_mesh = CylinderMesh.new()
		_cradle_mesh.top_radius = 0.22
		_cradle_mesh.bottom_radius = 0.16
		_cradle_mesh.height = 0.1
		_cradle_mesh.radial_segments = 12
		_cradle_mesh.rings = 1
		var mt := StandardMaterial3D.new()
		mt.albedo_color = Style.DRIED
		mt.roughness = 1.0
		_cradle_mesh.material = mt
	var c := MeshInstance3D.new()
	c.mesh = _cradle_mesh
	c.position = Vector3(0, 0.0, 0)
	c.scale = Vector3(1.0, 1.0, 0.62)
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return c


## 옷 갈아입기 연기: 처음 SWAP_HIDE초 인형을 숨기고, 크림 덩이 다섯이 퍼지며 옅어짐 → 스스로 사라짐
class SwapPuff extends Node3D:
	var doll: MeshInstance3D
	var mesh_ref: Mesh
	var height := 0.88
	var t := 0.0
	var balls: Array[MeshInstance3D] = []

	func _ready() -> void:
		for i in 5:
			var b := MeshInstance3D.new()
			b.mesh = mesh_ref
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a := TAU * float(i) / 5.0
			b.set_meta("dir", Vector3(cos(a), 0.35 + 0.25 * float(i % 2), sin(a)))
			b.position = Vector3(0, height * 0.35, 0)
			add_child(b)
			balls.append(b)

	func _process(dt: float) -> void:
		t += dt
		var u := clampf(t / SWAP_PUFF, 0.0, 1.0)
		for b: MeshInstance3D in balls:
			var d: Vector3 = b.get_meta("dir")
			b.position = Vector3(0, height * 0.35, 0) + d * (0.06 + 0.22 * u) * height
			b.scale = Vector3.ONE * (0.7 + 1.1 * u) * height
			b.transparency = u
		if doll != null and t >= SWAP_HIDE:
			doll.visible = not bool(get_parent().get("_f_on"))      # 방식 C 인형이 나와 있으면 컷아웃 인형은 숨긴 채 (두 인형이 겹쳐 보였음)
		if t >= SWAP_PUFF:
			queue_free()
