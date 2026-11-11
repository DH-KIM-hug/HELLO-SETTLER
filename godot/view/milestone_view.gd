## 자람의 보상 — 영구 장식(빵 간판 · 마을 이름 표지판 · 문 앞 바람개비 · 키 재는 기둥 · 창고 문 위 햇밀 다발)과 잔치 춤 · 첫걸음마 손뼉 (docs/PROGRESSION.md 4.5 · ROADMAP Q9 · Q15).
## 화면만 (ADR-0001): 병의 고비 기록(sim/milestones.gd)과 주민의 하는 일을 읽기만 한다. 새 건물 종류 없음 · 시뮬레이션 효과 없음 · 난수 없음.
##   - 빵 간판: 첫 빵을 넘은 병 — 다 지은 화덕(빵집) 앞 오른쪽에 (기본 보기에서 카메라 쪽)
##   - 마을 이름 표지판: 식구 열둘을 넘은 병 — 마을 어귀 (고비를 넘을 때 적어 둔 자리 — 꽃·길·건물·무덤을 피한 곳, 나중에 건물이 서면 그 옆 빈자리).
##     그 둘레·앞의 키 큰 꽃 그림은 낮추고 발치의 잔것은 비운다 (VillageView.sign_spot — 무덤과 같은 방식)
##   - 문 앞 작은 바람개비 (Q9 ⑦): 첫걸음마를 넘은 병 — 그 아기네 집 문 옆 요람 곁 (집이 없어졌으면 그때 적어 둔 자리). 날개가 돈다 (여섯 장면).
##     조용히 넘은 옛 저장(어느 집인지 적혀 있지 않다)은 마을에서 난 사람 가운데 가장 먼저 난 이의 집 문 앞, 없으면 가장 먼저 지은 살림집 (Q15 — quiet_house).
##     작은 그림이라 멀리서는 다른 장식보다 더 키운다 (K_CAP — 마을 기본 확대에서도 SIGN_PX).
##   - 키 재는 기둥 (Q9 ⑦ · Q15 · Q18 ⑫): 마을에서 난 첫 아이가 어른이 된 병 — 시뮬레이션이 고비를 넘을 때 적어 둔 바로 그 자리 (기록의 x·y — post_at).
##     화면이 자리를 따로 찾지 않는다. 그 자리가 막혔을 때(건물·꽃·하늘의 것)와 자리가 적히지 않은 옛 저장만 시뮬레이션의 같은 규칙(Milestones.post_spot)으로.
##   - 햇밀 다발 (Q9 ⑭): 첫 푸른 밀 고개를 넘긴 병 — 창고 문 위 (창고 그림의 문틀 높이에, 그림 바로 앞 — 카메라가 돌아도 늘 보이는 쪽).
##     창고가 없으면 첫 밭 울타리 앞에, 밭도 없으면 적어 둔 자리(모닥불 곁)에 세워 둔다. 조용히 넘은 옛 저장도 창고에 건다 (자리를 알 수 있으니).
##   - 첫걸음마 손뼉 (Q9 ⑦): 아기의 첫걸음마를 보러 문 앞에 온 이웃(걸음의 "ms" 표시 — Milestones._gather)이 아기 쪽을 보고,
##     손뼉 걸음("play") 동안 콩콩 뛰며 한마디. (Q15) 발이 닿는 박자마다 손 높이에 '짝' 금 그림 + 손뼉 그림 말풍선.
##     (Q18 ⑨) '짝' 금이 터질 때 작은 손뼉 소리(feast_clap) — 여럿이 쳐도 한 번, CLAP_SND_GAP에 한 번만 (처음엔 small_cheer도 한 번).
##     (Q18 ⑪) 손뼉 그림 말풍선은 바람개비를 덮지 않게 옆으로 비킨다 (PicBubbles.keep_out — 가장 먼 축소에서도 둘 다 보임)
##   - 잔치 춤: 잔치 중(Milestones.feast_on) 모닥불 둘레에서 "play" 몸짓인 사람이 폴짝이며 좌우로 흔들림 (인형 통째 — 새 그림 없음)
##   - 잔치 먹기 (Q15): "eat" 몸짓인 잔치 손님 — 손에 든 빵을 입으로 올렸다 내렸다 (한 입에 몸을 조금 숙임) + 빵 그림 말풍선 (멀리서도 읽힘)
##     (Q18 ⑧) 그린 인형(방식 C)의 먹는 그림에는 이미 빵이 들려 있으니 소품 빵을 얹지 않는다 — 한 사람에 빵 하나
##   - 잔칫상 · 등 (Q15 · Q18 ⑩): 잔치 동안만 — 잔치 둘레 바로 밖에 긴 상(빵·열매·물병), 양옆에 막대 등 둘 (밤에도 제 빛깔 + 둥근 빛,
##     땅의 불빛 웅덩이는 Campfire.lamps로). 자리는 feast_spots — 건물·물·제단을 피한 빈자리 가운데 네 보기 모두에서 손님·걸상·기둥·불꽃·건물과
##     화면에서 가장 덜 겹치는 곳 (table_score — 난수 없음), 없으면 차리지 않는다. 등은 상의 화면 양 끝을 따라간다 (카메라가 돌면 같이).
##     잔치 동안 나비·꿀벌은 상·등·기둥 앞에서 비켜 난다 (FaunaView.shoo — 화면만)
##   - 첫 어른 잔치 (Q15 · Q18 ⑦): 그 젊은이(기록의 who)가 잔치에 불려 오는 대로 (아무리 멀리 있었어도) 기둥 옆으로 폴짝폴짝 달려가 키를 잰다
##     (화면 자리만 — 시뮬레이션 자리·하는 일은 그대로. 멀수록 빨리 — STAR_RUN_SECS 안에 닿는다) —
##     발돋움, 머리 높이에 새 끈, 다른 손님은 그쪽을 보고 한마디 · 자람 그림 말풍선. 다른 잔치와 한눈에 다르게
## 그림은 자기 것(art/milestones/*.png — tools/milestone_signs.py), 카드는 Flora2D의 그림 판 셰이더를 그대로 쓴다 (늘 카메라를 보고, 아래 끝이 땅에).
## 잔치 소품은 그림판 한 장(feast_props.png)을 아이 소품 셰이더(view/kids/kid_card.gdshader)로 — 재질 하나 · 사각형 하나를 나눠 쓴다.
## 멀리서도 읽히게: 화면에서 SIGN_PX보다 작아지면 그만큼 키운다 (K_MAX까지 — GraveView.stone_k와 같은 생각).
class_name MilestoneView
extends Node3D

const TEX := {"bread": "res://art/milestones/bread_sign.png", "pop12": "res://art/milestones/village_sign.png",
	"steps": "res://art/milestones/pinwheel.png", "grown": "res://art/milestones/height_post.png", "green": "res://art/milestones/wheat_sheaf.png"}
const SIZE := {"bread": Vector2(0.88, 1.2), "pop12": Vector2(1.3, 1.24), "steps": Vector2(0.5, 0.79), "grown": Vector2(0.68, 1.32), "green": Vector2(0.56, 0.62)}     # 그림 크기 (칸 — 어른 키 0.88)
const FRAMES := {"steps": 6}          # 옆으로 이어 붙인 장면 수 (tools/milestone_signs.py PINWHEEL_FRAMES) — 차례로 넘겨 날개가 돈다
const FRAME_FPS := 7.0
const PIN_OFF := Vector2(1.55, 0.3)   # 바람개비: 집 앞 가장자리 가운데에서 (옆, 앞) — 문 옆 요람(CRADLE_OFF)의 화면 오른쪽 곁
const PIN_FIRE := Vector2(2.4, 0.6)   # (Q15) 조용히 넘었는데 살림집이 하나도 없을 때: 모닥불에서 (화면 옆, 앞)
const SHEAF_PIC := "storehouse"       # 햇밀 다발을 거는 건물 그림 (view/bld2d — 창고)
const SHEAF_AT := 1.93                # 그 그림의 밑변에서 문틀 위까지 (칸 — 그림 높이 3.91 가운데)
const SHEAF_FRONT := 0.06             # 건물 그림 판보다 이만큼 카메라 쪽에 (그림 위에 그려지게)
const SHEAF_3D := Vector2(0.8, 1.0)   # 그림 건물을 끈 화면(3D 창고): (건물 크기의 몇 배 앞, 땅에서 높이)
const SHEAF_FENCE := 0.3              # 밭 울타리 그림에서 이만큼 앞에 세운다
const CLAP_HOP := 0.07                # 손뼉 치며 콩콩 (칸)
const CLAP_BEAT := 10.5
const CLAP_SAY := ["짝짝짝!", "걸었다, 걸었어!", "잘한다!", "아이고, 장해라."]
const CLAP_SAY_SECS := 2.4
const SIGN_PX := 34.0                 # 장식이 화면에서 적어도 이만큼(세로 점)은 보이게
const K_MAX := 1.7                    # 멀리서 키우는 상한
const K_CAP := {"steps": 2.7}         # (Q15) 작은 장식은 상한을 따로 — 바람개비(0.79칸)는 1.7배로는 마을 기본 확대(16)에서 21점, 2.7배라야 SIGN_PX
const CHECK := 0.5                    # 자리를 다시 세는 간격 (현실 초)
const NODE_NAME := "MilestoneView"
const DANCE_R := 4.5                  # 모닥불에서 이 안에 선 사람만 춤춘다 (걸어오는 중엔 아님)
const HOP := 0.11                     # 폴짝 높이 (칸)
const SWAY := 0.11                    # 좌우 흔들림 (라디안)
const BEAT := 5.2                     # 춤 빠르기
# ── Q15 잔치 화면 ──
const FX_TEX := "res://art/milestones/feast_props.png"     # 잔치 소품 그림판 (tools/milestone_signs.py feast_props)
const FX_ATLAS := Vector2(512.0, 160.0)
const FX_PICS := {"spread": Rect2(2, 2, 258, 108), "lantern": Rect2(264, 2, 60, 156), "loaf": Rect2(328, 2, 48, 40),
	"clap": Rect2(380, 2, 54, 54), "ribbon": Rect2(438, 2, 54, 46)}     # 칸 (점) — milestone_signs.py FEAST_CELLS와 같게
const FX_PX := 150.0                  # 그림 150점 = 1칸
const FX_W := {"loaf": 0.22, "clap": 0.4, "ribbon": 0.24}     # 그린 크기와 다르게 쓰는 것의 너비 (칸)
const FX_PRIORITY := 12               # 빛나는 판: 그림자·꽃(반투명)보다 나중에 (view/moment_fx.gd와 같게). 둥근 빛은 그 바로 앞(11)
const TABLE_RINGS := [3.2, 3.6, 4.0, 4.4]  # 잔칫상: 모닥불에서 이만큼 (잔치 둘레 바로 밖 — 칸)
const TABLE_BLD_GAP := 0.4            # (Q18 ⑩) 상·등은 건물 가장자리에서 이만큼만 떨어지면 된다 (팻말보다 좁게 — 집이 둘러선 마당에서도 카메라 쪽 자리를 얻게. 화면만)
const TABLE_TURN_DEG := 15.0          # 기본 보기의 불 앞쪽(카메라 쪽)에서 양옆으로 한 바퀴 — 각 걸음
const TABLE_FAR_W := 0.12             # (Q18 ⑩) 자리 점수: 불에서 한 칸 멀어질 때마다 이만큼 나쁘게
const TABLE_FRONT_W := 1.5            # 기본 보기의 앞쪽에서 반 바퀴 돌아간 자리는 이만큼 나쁘게
const TABLE_VIEW_W := 2.0             # 기본 보기에서의 겹침은 다른 세 보기의 이만큼으로 센다
const TABLE_SIDE_PEN := 0.5           # 돌려 본 보기에서 상의 한쪽 끝이 빈자리가 아닐 때
const LAMP_MISS_PEN := 0.35           # 한 보기에서 등 하나를 세울 수 없을 때
const LAMP_TURN_DOT := 0.9994         # 카메라가 이만큼(약 2°) 돌면 등 자리를 다시 (상의 화면 양 끝)
const SEEN_DOLL := Vector2(0.45, 0.88)     # 자리 점수에서 손님 한 사람의 너비 · 키 (칸)
const SEEN_SEAT := Vector2(0.9, 0.5)       # 걸상
const SEEN_FLAME := Vector2(1.1, 2.2)      # 잔치 불꽃 (크게 탄다)
const SEEN_BLD := Vector2(1.4, 1.8)        # 건물 그림: 건물 크기의 몇 배 (너비 · 높이)
const SEEN_NEAR := 12.0               # 모닥불에서 이 안의 건물만 센다
const SEEN_GUESTS := Vector2i(6, 24)  # 손님 수를 모를 때의 하한 · 상한
const SHOO_FRONT := 0.5               # (Q18 ⑩) 날것이 비켜 나는 자리: 소품에서 카메라 쪽으로 이만큼 (화면에서 소품 앞)
const SHOO_TABLE_R := 1.6             # 상 둘레 (칸)
const SHOO_POLE_R := 0.9              # 등 · 기둥 둘레
const PIN_KEEP := 2.0                 # (Q18 ⑪) 그림 말풍선이 바람개비에서 띄우는 틈 (화소)
const SAY_KEEP := 2.0                 # (Q20 ㉜) 글 말풍선이 잔칫상·등·키 재는 기둥에서 띄우는 틈 (화소)
const TABLE_HALF := 0.86              # 상 너비의 반 (칸)
const TABLE_POST_GAP := 1.5           # 기둥과 이만큼은 떨어져
const LAMP_GAP := 0.34                # 상 끝에서 등 막대까지 (칸)
const LAMP_FIRE := Vector2(2.9, 0.9)  # 상을 차릴 자리가 없을 때 등만: 모닥불에서 (화면 옆, 앞)
const LAMP_AT := Vector2(0.067, 0.72) # 등불의 자리: 막대 그림 밑 가운데에서 (옆, 위) — 둥근 빛·불빛 웅덩이의 가운데
const LAMP_HALO := 1.5                # 둥근 빛의 지름 (칸)
const LAMP_HALO_A := Vector2(0.22, 0.45)     # 둥근 빛의 짙기: 낮 + 밤 정도 × 이만큼
const LAMP_GLOW_R := 2.0              # 땅에 번지는 불빛 반지름 (화면 마무리 셰이더 — Campfire.lamps)
const LAMP_GLOW_K := 0.7
const FEAST_POP_SECS := 0.45          # 상·등이 톡 차려지는 시간 (현실 초)
const EAT_BEAT := 5.6                 # 한 입 박자
const EAT_HAND := Vector2(0.3, 0.42)  # 빵을 내린 자리: 바라보는 쪽으로 · 위로 (머리 높이의 몫)
const EAT_MOUTH := Vector2(0.21, 0.57) # 입가 (얼굴을 가리지 않게 입 바로 앞·아래)
const EAT_LEAN := 0.07                # 한 입에 숙이는 기울임 (라디안)
const BUB_SECS := 3.0                 # 그림 말풍선 하나가 떠 있는 시간 (현실 초) — 차례로 돌아가며
const BUB_EAT := 2                    # 한 번에 뜨는 빵 그림 말풍선 수 (많아야)
const BUB_GROW := 2                   # 첫 어른 잔치: 자람 그림 말풍선 수
const BUB_CLAP := 2                   # 손뼉 그림 말풍선 수
const BUB_APART := 1.3                # 그림 말풍선끼리 이만큼은 떨어진 사람에게 (칸 — 겹쳐 뜨지 않게)
const CLAP_AT := Vector2(0.3, 0.43)   # 손뼉 금: 바라보는 쪽으로 · 위로 (머리 높이의 몫 — 가슴 앞 두 손 자리)
const CLAP_OPEN := 0.62               # 폴짝의 이 높이 아래에서만 '짝' (발이 닿을 때 손이 마주친다)
const CLAP_SND := "feast_clap"        # (Q18 ⑨) 작은 손 몇이 짝짝 (audio/sfx — tools/gen_sfx.py)
const CLAP_SND_DB := -13.0
const CLAP_SND_GAP := 1.5             # 손뼉 소리 사이 (현실 초) — 여럿이 쳐도 이 사이에 한 번만
const CLAP_SND_POP := 0.6             # '짝' 금이 이만큼 터졌을 때 소리
const STAR_OFF := Vector2(-0.34, 0.05)     # 키를 재는 젊은이: 기둥에서 (화면 옆, 앞) — 눈금이 보이게 기둥 왼쪽에
const STAR_SPEED := 3.0               # 기둥 옆으로 폴짝폴짝 가는 빠르기 (칸/현실 초) — 적어도 이만큼
const STAR_RUN_SECS := 3.2            # (Q18 ⑦) 멀리 있었어도 이 시간(현실 초) 안에 기둥에 닿게 — 멀수록 빨리 달린다
const STAR_HOP_BEAT := 9.0
const STAR_SNAP := 40.0               # 이보다 멀면 (빠른 흐름 뒤) 바로 제자리 — 잔치에 불리는 거리(Milestones.FEAST_REACH)보다 넉넉히
const STAR_POP_SECS := 0.35           # 새 끈이 톡 달리는 시간
const STAR_STRETCH := 0.06            # 발돋움 (키 배율)
const STAR_BEAT := 2.4
const STAR_SAY := "이만큼 컸어요!"
const GROWN_SAY := ["다 컸네, 다 컸어!", "어느새 이만큼!", "장하다, 장해!", "키 좀 봐!"]
const GROWN_SAY_EVERY := 3.4          # 한마디 사이 (현실 초)
const GROWN_SAY_SECS := 2.6
const POLE_DX := -0.027               # 기둥 그림에서 나무 기둥의 가운데 (그림 가운데에서 — 칸)
## 빛나는 판 (등 · 둥근 빛 · 손뼉 금): 밤 색 조정 뒤(반투명 패스)에 제 빛깔로. 판 놓는 법은 view/kids/kid_card.gdshader와 같다
const GLOW_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;
uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 glow : source_color = vec3(1.0, 0.82, 0.47);
instance uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);    // atlas cell (u, v, w, h)
instance uniform vec4 geo = vec4(0.3, 0.3, 0.0, 0.0);     // width (negative = mirrored), height, soft (1 = round glow, no picture), pull toward the camera
instance uniform vec4 fx = vec4(1.0, 1.0, 0.0, 0.0);      // scale, alpha, anchor (0 = bottom at the node, 1 = centre), lift (screen-vertical, world units)
varying vec2 v_uv;
varying vec2 v_q;
void vertex() {
	vec2 q = VERTEX.xy * geo.xy * fx.x;
	q.y += geo.y * fx.x * 0.5 * (1.0 - fx.z) + fx.w;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	right = normalize(vec3(right.x, 0.0, right.z));
	float cu = max(INV_VIEW_MATRIX[1].y, 0.3);
	vec3 w = MODEL_MATRIX[3].xyz + right * q.x + vec3(0.0, q.y / cu, 0.0) + INV_VIEW_MATRIX[2].xyz * geo.w;
	v_uv = rect.xy + UV * rect.zw;
	v_q = UV * 2.0 - 1.0;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}
void fragment() {
	if (geo.z > 0.5) {
		float r = clamp(1.0 - length(v_q), 0.0, 1.0);
		ALBEDO = glow;
		ALPHA = r * r * fx.y;
	} else {
		vec4 t = texture(tex, v_uv);
		if (t.a < 0.5) {
			discard;
		}
		ALBEDO = t.rgb;
		ALPHA = fx.y;
	}
}
"""

var view: VillageView
var _signs: Dictionary = {}           # 고비 id → MeshInstance3D
var _mats: Dictionary = {}            # 고비 id → ShaderMaterial
var _dancing: Dictionary = {}         # 주민 id → true (여기서 얹은 몸짓 — 끝나면 되돌림)
var _clapping: Dictionary = {}        # 주민 id → true (첫걸음마 손뼉 — 끝나면 되돌림)
var _hang := {}                       # 햇밀 다발을 거는 높이 {"h": 그림 높이(칸 — 카메라 기울기로 나눔), "lift": 땅에서 높이(칸)} (refresh가 적음)
var _hang_lift := -1.0                # 지금 넣어 둔 높이
var _since := 1.0e9
var _k := 1.0
var _t := 0.0
# ── Q15 ──
var bub: PicBubbles                   # 그림 말풍선 (빵 · 손뼉 · 자람 — 글·숫자 없음)
var _eating: Dictionary = {}          # 주민 id → true (잔치에서 먹는 몸짓 — 끝나면 되돌림)
var _loaves: Dictionary = {}          # 주민 id → 손에 든 빵 그림
var _claps: Dictionary = {}           # 주민 id → 손뼉 금 그림
var _post_keep := Vector2.INF         # 기둥을 세운 자리 (쓸 수 있는 동안은 그대로 — 꽃·하늘의 것이 오갈 때 왔다 갔다 하지 않게)
var _quiet_b := -1                    # 조용히 넘은 첫걸음마의 바람개비를 단 집 (그 집이 서 있는 동안은 그대로)
var _spots := {}                      # 이번 잔치의 상·등 자리 (feast_spots — 잔치가 시작될 때 한 번)
var _table: MeshInstance3D            # 잔칫상 (잔치 동안만)
var _lamps: Array = []                # 등: [막대 그림, 둥근 빛]
var _feast_w := 0.0                   # 상·등이 차려진 정도 (0~1)
var _star := -1                       # 첫 어른 잔치: 기둥 옆에 서는 젊은이 (없으면 -1)
var _star_on := false                 # 지금 키를 재는 중인가 (꺼지면 제자리로 돌아간 뒤 놓아 준다)
var _star_at := Vector3.INF           # 그 젊은이의 화면 자리
var _star_there := false              # 기둥 옆에 닿았나
var _star_w := 0.0                    # 새 끈이 달린 정도 (0~1)
var _star_top := 0.88                 # 그 젊은이의 머리 높이 (새 끈 자리)
var _step := 0.0                      # 지난 pose 뒤로 흐른 현실 초 (젊은이가 옮겨 가는 몫)
var _guests: Array = []               # 첫 어른 잔치: 불 곁에 닿은 다른 손님 (주민 id)
var _ribbon: MeshInstance3D           # 기둥의 새 끈 (키를 재는 동안만)
var _say_t := 0.0                     # 다음 한마디까지 (현실 초)
var _say_i := 0
var _fx_quad: QuadMesh
var _fx_mat: ShaderMaterial           # 그늘지는 소품 (상 · 빵 · 끈) — 아이 소품과 같은 셰이더
var _glow_mat: ShaderMaterial         # 빛나는 판 (등 · 손뼉 금)
# ── Q18 ──
var _lamp_right := Vector2.INF        # 등 자리를 정한 때의 카메라 오른쪽 (돌면 다시 정한다)
var _shoo_on := false                 # 날것을 비키게 해 두었나 (잔치가 끝나면 되돌림)
var _star_speed := -1.0               # 그 젊은이가 옮겨 가는 빠르기 (-1 = 다음 pose에서 남은 거리로 다시 정함)
var _clap_snd_t := -1.0e9             # 마지막 손뼉 소리 (현실 초 — _t)
var _clap_snd_qt := -1.0e18           # 그때 병의 시각 (멈춘 화면에서는 되풀이하지 않는다)
var clap_sounds := 0                  # (시험) 지금까지 낸 손뼉 소리 수
var _halo_mat: ShaderMaterial         # 둥근 빛 (등보다 먼저 그림)


## 그림 말풍선 — 아이들 장면의 것(KidBubbles: 화면 화소로 일정한 크기)에 잔치 그림 셋을 더함
class PicBubbles extends KidBubbles:
	const LOAF := Color("e48a49")
	const LOAF_L := Color("f6bd6e")
	const SKIN := Color("f3c9a0")
	const RED := Color("e4704a")
	var keep_out: Array = []              # (Q18 ⑪) 덮으면 안 되는 화면 네모 (화소 — 바람개비): 몸통을 옆으로 비킨다, 꼬리는 머리에 그대로

	## 아이들 것과 같되 keep_out과 먼저 그린 풍선을 비켜 옆으로 (가장 먼 축소에서는 풍선이 사람보다 훨씬 커서 서로·장식을 덮는다)
	func _draw() -> void:
		if items.is_empty() or not is_inside_tree():
			return
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var vs := get_viewport_rect().size
		var avoid: Array = keep_out.duplicate()
		boxes.clear()
		for it: Array in items:
			var m: Node3D = it[0]
			if not is_instance_valid(m) or not m.is_visible_in_tree():
				continue
			var p := head_px(cam, m)
			if p == Vector2.INF or p.x < 0.0 or p.x > vs.x or p.y < 0.0 or p.y > vs.y:
				continue
			var b := box_of(p, float(it[2]), bool(it[3]), float(it[4]), vs)
			if b.is_empty():
				continue
			var rc := placed(b[0], avoid, vs)
			avoid.append(rc)
			boxes.append([rc, bool(it[3])])
			paint(p, rc, String(it[1]), float(b[1]), float(b[2]), float(it[4]))

	## 풍선 몸통 rc를 avoid(화면 네모들)에 닿지 않게 옆으로 비킨 것 — 화면 밖으로 밀리면 반대쪽으로
	static func placed(rc: Rect2, avoid: Array, vs: Vector2) -> Rect2:
		var dx := dodge(rc, avoid)
		if dx != 0.0 and (rc.position.x + dx < 2.0 or rc.end.x + dx > vs.x - 2.0):
			var lo := rc.position.x
			var hi := rc.end.x
			for a: Rect2 in avoid:
				lo = minf(lo, a.position.x - DODGE_GAP - rc.size.x)
				hi = maxf(hi, a.end.x + DODGE_GAP + rc.size.x)
			dx = (lo - rc.position.x) if dx > 0.0 else (hi - rc.end.x)
		return Rect2(rc.position + Vector2(dx, 0.0), rc.size)

	func draw_pic(c: Vector2, pic: String, a: float, k: float, t: float) -> void:
		var ink := Color(INK, a)
		match pic:
			"bread":                               # 둥근 빵 (한 입 베어 문 자국) — 먹는 중
				var o := c + Vector2(0.0, 0.6 + 0.5 * sin(t * 4.0)) * k
				var pts := PackedVector2Array()
				for i in 22:
					var ang := TAU * float(i) / 22.0
					pts.append(o + Vector2(cos(ang) * 9.4, sin(ang) * 6.6 * (0.8 if sin(ang) > 0.0 else 1.0)) * k)
				draw_colored_polygon(pts, Color(LOAF, a))
				var top := PackedVector2Array()
				for i in 12:
					var ang := PI + PI * float(i) / 11.0
					top.append(o + Vector2(cos(ang) * 7.6, sin(ang) * 4.9 - 0.4) * k)
				draw_colored_polygon(top, Color(LOAF_L, a))
				pts.append(pts[0])
				draw_polyline(pts, ink, 1.0, true)
				for dx: float in [-3.2, 0.6]:
					draw_line(o + Vector2(dx - 1.0, -3.6) * k, o + Vector2(dx + 1.2, -0.6) * k, Color(LOAF.darkened(0.3), a), 1.2, true)
				var bite := o + Vector2(7.6, -4.6) * k
				draw_circle(bite, 3.6 * k, Color(CREAM, a))
				draw_arc(bite, 3.6 * k, PI * 0.42, PI * 1.12, 8, ink, 1.0, true)
			"hands":                               # 마주친 두 손 + 튀는 금 — 손뼉
				var beat := absf(sin(t * 7.0))
				var gap := (0.6 + 1.8 * beat) * k
				for sgn: float in [-1.0, 1.0]:
					var h := c + Vector2(sgn * (gap + 3.2 * k), 2.4 * k)
					var tilt := -sgn * 0.42                # 손끝이 서로 기대게 (벙어리장갑 두 짝)
					var cuff := PackedVector2Array()       # 소매 끝
					for q: Vector2 in [Vector2(-2.6, 4.2), Vector2(2.6, 4.2), Vector2(3.0, 7.4), Vector2(-3.0, 7.4)]:
						cuff.append(h + q.rotated(tilt) * k)
					draw_colored_polygon(cuff, Color(RED, a))
					cuff.append(cuff[0])
					draw_polyline(cuff, ink, 1.0, true)
					var thumb := PackedVector2Array()      # 엄지 (바깥 아래)
					for i in 10:
						var ang := TAU * float(i) / 10.0
						thumb.append(h + (Vector2(sgn * 3.0, 1.4) + Vector2(cos(ang) * 1.7, sin(ang) * 2.4).rotated(sgn * 0.7)).rotated(tilt) * k)
					draw_colored_polygon(thumb, Color(SKIN, a))
					thumb.append(thumb[0])
					draw_polyline(thumb, ink, 1.0, true)
					var palm := PackedVector2Array()       # 손바닥 + 네 손가락 (위가 조금 넓음)
					for i in 16:
						var ang := TAU * float(i) / 16.0
						palm.append(h + Vector2(cos(ang) * (3.4 if sin(ang) < 0.0 else 3.0), sin(ang) * 5.6 - 0.6).rotated(tilt) * k)
					draw_colored_polygon(palm, Color(SKIN, a))
					palm.append(palm[0])
					draw_polyline(palm, ink, 1.0, true)
				for i in 3:
					var ang := -PI * 0.5 + (float(i) - 1.0) * 0.62
					var r0 := (6.2 - 1.2 * beat) * k
					var dir := Vector2(cos(ang), sin(ang))
					draw_line(c + dir * r0 + Vector2(0.0, 1.0) * k, c + dir * (r0 + 3.6 * k) + Vector2(0.0, 1.0) * k, Color(YELLOW.darkened(0.08), a), 1.6, true)
			"grow":                                # 잎 달린 줄기가 쑥 + 위로 화살 — 많이 컸다 (숫자·막대 없음)
				var base := c + Vector2(0.0, 8.6) * k
				var up := 1.0 + 0.08 * sin(t * 3.0)
				var tip := base + Vector2(0.0, -15.5 * up) * k
				draw_line(base, tip + Vector2(0.0, 3.0) * k, ink, 3.0 * k, true)
				draw_line(base + Vector2(0.0, -0.6) * k, tip + Vector2(0.0, 3.0) * k, Color(GREEN, a), 1.6 * k, true)
				for sgn: float in [-1.0, 1.0]:
					var leaf := PackedVector2Array([base + Vector2(0.0, -4.0) * k, base + Vector2(sgn * 6.4, -8.6) * k, base + Vector2(sgn * 5.2, -3.0) * k])
					draw_colored_polygon(leaf, Color(GREEN.lightened(0.12), a))
					leaf.append(leaf[0])
					draw_polyline(leaf, ink, 1.0, true)
				var head := PackedVector2Array([tip + Vector2(0.0, -1.8) * k, tip + Vector2(-4.6, 4.2) * k, tip + Vector2(4.6, 4.2) * k])
				draw_colored_polygon(head, Color(RED, a))
				head.append(head[0])
				draw_polyline(head, ink, 1.0, true)
				draw_line(base + Vector2(-8.5, 0.0) * k, base + Vector2(8.5, 0.0) * k, ink, 1.0, true)
			_:
				super(c, pic, a, k, t)


func _init() -> void:
	bub = PicBubbles.new()
	bub.name = "PicBubbles"
	add_child(bub)


func _exit_tree() -> void:
	var fire: Campfire = view._fire if view != null and is_instance_valid(view) else null
	if fire != null and is_instance_valid(fire):
		fire.lamps = []


## 그 마을 화면의 것 (없으면 만듦)
static func of(vw: VillageView) -> MilestoneView:
	if vw == null or not is_instance_valid(vw):
		return null
	var m: MilestoneView = vw.get_node_or_null(NODE_NAME)
	if m == null:
		m = MilestoneView.new()
		m.name = NODE_NAME
		m.view = vw
		vw.add_child(m)
	return m


## 기본 보기에서 화면 오른쪽 · 카메라 쪽 (마을 데이터 좌표)
static func _right() -> Vector2:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector2(cos(yaw), -sin(yaw))


static func _front() -> Vector2:
	var yaw := deg_to_rad(JarCamera.BASE_YAW_DEG)
	return Vector2(sin(yaw), cos(yaw))


## 지금 서 있어야 할 장식: 고비 id → 자리 (마을 데이터 좌표). 고비를 넘지 않았으면 없음. 시뮬레이션을 바꾸지 않는다.
## keep (화면이 기억해 둔 것 — 없어도 된다): {"post": 기둥을 세워 둔 자리, "house": 조용한 바람개비를 단 집}
static func wanted(q: Village, keep: Dictionary = {}) -> Dictionary:
	var out := {}
	if q == null or not q.owns_water:
		return out
	if Milestones.is_passed(q, "bread"):
		var b := Milestones.oven(q)
		if b != null:
			out["bread"] = Vector2(b.x, b.y) + _right() * (b.size() * 1.25 + 0.45) + _front() * (b.size() * 1.2 + 0.15)
	if Milestones.is_passed(q, "pop12"):
		var rec: Dictionary = (q.milestones["passed"] as Dictionary)["pop12"]
		var p := Vector2(float(rec.get("x", 0.0)), float(rec.get("y", 0.0)))
		if not rec.has("x") or not Milestones.spot_free(q, p):
			p = Milestones.edge_spot(q)                 # 옛 저장(자리 없음) · 그 자리에 건물이 선 뒤
		out["pop12"] = p
	if Milestones.is_passed(q, "steps"):
		var rec: Dictionary = (q.milestones["passed"] as Dictionary)["steps"]
		if rec.has("x"):
			var hm := q.bld(int(rec.get("b", -1)))
			var base := Vector2(hm.x, hm.y + hm.size() * 0.5) if hm != null else Vector2(float(rec["x"]), float(rec["y"]))
			out["steps"] = base + PIN_OFF
		else:                                           # (Q15) 조용히 넘은 옛 저장: 마을에서 난 첫 사람의 집 문 앞 (quiet_house)
			var hm := quiet_house(q, int(keep.get("house", -1)))
			out["steps"] = Vector2(hm.x, hm.y + hm.size() * 0.5) + PIN_OFF if hm != null else q.fire + _right() * PIN_FIRE.x + _front() * PIN_FIRE.y
	if Milestones.is_passed(q, "grown"):
		out["grown"] = post_at(q, keep.get("post", Vector2.INF))
	if Milestones.is_passed(q, "green"):
		out["green"] = sheaf(q)["pos"]
	return out


## (Q18 ⑫) 키 재는 기둥 자리 = 시뮬레이션이 고비를 넘을 때 적어 둔 자리 (기록의 x·y — Milestones.post_spot이 그때 찾은 곳). 화면은 따로 찾지 않는다.
## 그 자리가 지금 막혔으면 (건물·꽃·하늘의 것) keep = 화면이 세워 둔 자리 (아직 쓸 수 있으면 — 왔다 갔다 하지 않게), 그것도 아니면 · 자리가 적히지 않은
## 옛 저장이면 시뮬레이션의 같은 규칙(Milestones.post_spot)으로 지금 다시 찾은 자리. 읽기만 한다 — 적어 둔 자리는 그대로 둔다
static func post_at(q: Village, keep := Vector2.INF) -> Vector2:
	var rec: Dictionary = (q.milestones.get("passed", {}) as Dictionary).get("grown", {})
	if rec.has("x"):
		var p := Vector2(float(rec["x"]), float(rec["y"]))
		if Milestones.post_ok(q, p):
			return p
	if keep != Vector2.INF and Milestones.post_ok(q, keep):
		return keep
	return Milestones.post_spot(q)


## (Q15) 조용히 넘은 첫걸음마의 바람개비를 달 집: 마을에서 난 사람(Milestones.born_here) 가운데 번호가 가장 작은 이의 다 지은 집,
## 그런 사람이 없으면 사람이 사는 다 지은 집 가운데 번호가 가장 작은 것, 그것도 없으면 null. keep = 이미 단 집 (서 있는 동안은 그대로). 읽기만 한다
static func quiet_house(q: Village, keep := -1) -> Building:
	var kb := q.bld(keep) if keep >= 0 else null
	if kb != null and kb.built:
		return kb
	var best: Building = null
	var best_id := -1
	var first: Building = null
	for p in q.people:
		if p.dead:
			continue
		var hm := q.bld(p.home) if p.home >= 0 else null
		if hm == null or not hm.built:
			continue
		if first == null or hm.id < first.id:
			first = hm
		if (best_id < 0 or p.id < best_id) and Milestones.born_here(q, p, q.t):
			best_id = p.id
			best = hm
	return best if best != null else first


## (Q15 · Q18 ⑩) 잔칫상과 등의 자리: {"table": 상 가운데 (없으면 INF), "lamps": [[자리, 옆(-1 왼쪽 · +1 오른쪽)] …]} (마을 데이터 좌표).
## 상 = 잔치 둘레 바로 밖(TABLE_RINGS)의 빈자리(건물·물·무덤·제단·큰 줄기를 피하고 기둥과 떨어져) 가운데 table_score가 가장 낮은 곳 —
## 네 보기 모두에서 손님·걸상·기둥·불꽃·건물과 화면에서 가장 덜 겹치는 자리. 점수가 같으면 기본 보기의 앞쪽(카메라 쪽)부터 (난수 없음).
## 등 = 상의 화면 양 끝 (right = 지금 카메라의 오른쪽 — 없으면 기본 보기. 빈자리만). 상 자리가 없으면 모닥불 양옆에 등만.
## post = 키 재는 기둥 자리 (없으면 INF), seats = 모닥불 걸상 자리. 읽기만 한다
static func feast_spots(q: Village, post := Vector2.INF, seats: Array = [], right := Vector2.INF) -> Dictionary:
	var out := {"table": Vector2.INF, "lamps": []}
	var others := feast_others(q, post, seats)
	var best := 1.0e9
	var a0 := _front().angle()
	var r0 := float(TABLE_RINGS[0])
	var ax := _right()
	for rr: float in TABLE_RINGS:
		for i in int(round(360.0 / TABLE_TURN_DEG)):
			var side := 1.0 if i % 2 == 1 else -1.0
			var da := side * float((i + 1) >> 1) * deg_to_rad(TABLE_TURN_DEG)
			var p := q.fire + Vector2(cos(a0 + da), sin(a0 + da)) * rr
			if not table_ok(q, p, ax):
				continue
			if post != Vector2.INF and p.distance_to(post) < TABLE_POST_GAP:
				continue
			var sc := table_score(q, p, post, others) + TABLE_FAR_W * (rr - r0) + TABLE_FRONT_W * 0.5 * (1.0 - cos(da))
			if sc < best - 0.0001:
				best = sc
				out["table"] = p
	out["lamps"] = feast_lamps(q, out["table"], post, right)
	return out


## (Q18 ⑩) 상·등을 둘 수 있는 자리인가 — 시뮬레이션의 팻말 규칙(Milestones.spot_free)과 같되 건물에서는 TABLE_BLD_GAP만 떨어지면 된다. 읽기만
static func prop_free(q: Village, p: Vector2) -> bool:
	if q.water == null or not q.water.inside(p.x, p.y, 1.5) or q.water_at(p.x, p.y):
		return false
	for b: Building in q.buildings:
		if Vector2(b.x, b.y).distance_to(p) < b.size() + TABLE_BLD_GAP:
			return false
	for g: Dictionary in q.graves:
		if Vector2(float(g["x"]), float(g["y"])).distance_to(p) < Balance.SIGN_CLEAR_GRAVE:
			return false
	return true


## 잔칫상이 설 수 있나: 가운데와 양 끝(ax = 화면 오른쪽)이 빈자리이고, 제단·하늘의 것·큰 줄기가 아님 (기둥의 규칙 Milestones.post_ok에서 건물 거리만 좁힌 것)
static func table_ok(q: Village, p: Vector2, ax: Vector2) -> bool:
	if not prop_free(q, p) or not prop_free(q, p + ax * TABLE_HALF) or not prop_free(q, p - ax * TABLE_HALF):
		return false
	if p.distance_to(q.altar_pos) < Village.ALTAR_CLEAR + 0.5:
		return false
	if SkyDrops.blocks(q, p.x, p.y, 0.5) or (q.flora != null and q.flora.blocks(p.x, p.y, 0.5)):
		return false
	return not (GreatTrees.blocks(q.water, p.x, p.y, 0.5) or GiantPlants.blocks(q.water, p.x, p.y, 0.5))


## 등 둘의 자리 [[자리, 옆] …]: 상(table)의 화면 양 끝 — right = 그 보기의 화면 오른쪽 (없으면 기본 보기). 상이 없으면(INF) 모닥불 양옆. 빈자리만
static func feast_lamps(q: Village, table: Vector2, post := Vector2.INF, right := Vector2.INF) -> Array:
	if right == Vector2.INF:
		right = _right()
	var lamps: Array = []
	for sg: float in [-1.0, 1.0]:
		var lp: Vector2 = q.fire + right * sg * LAMP_FIRE.x + Vector2(-right.y, right.x) * LAMP_FIRE.y
		var ok := false
		if table != Vector2.INF:
			lp = table + right * sg * (TABLE_HALF + LAMP_GAP)
			ok = prop_free(q, lp)
		else:
			ok = Milestones.post_ok(q, lp)
		if ok and (post == Vector2.INF or lp.distance_to(post) > 0.6):
			lamps.append([lp, sg])
	return lamps


## (Q18 ⑩) 잔치 때 불 둘레에 서는 것들 — 상·등 자리 점수에 쓴다: [자리, 너비, 높이 (칸), 그것이 상·등을 가릴 때의 몫, 상·등이 그것을 가릴 때의 몫].
## 손님 자리는 시뮬레이션의 잔치 둘레 식(Milestones._feast — Balance.FEAST_RING_*)을 그대로 읽는다 (부를 수 있는 거리 안에 사는 사람 수만큼)
static func feast_others(q: Village, post := Vector2.INF, seats: Array = []) -> Array:
	var out: Array = []
	var n := 0
	for p in q.people:
		if not p.dead and Vector2(p.x, p.y).distance_to(q.fire) <= Milestones.FEAST_REACH:
			n += 1
	for i in clampi(n, SEEN_GUESTS.x, SEEN_GUESTS.y):
		var a := float(i) * Balance.FEAST_RING_TURN
		out.append([q.fire + Vector2(cos(a), sin(a)) * (Balance.FEAST_RING_R + Balance.FEAST_RING_GROW * sqrt(float(i))), SEEN_DOLL.x, SEEN_DOLL.y, 1.0, 0.35])
	for sp: Vector2 in seats:
		out.append([sp, SEEN_SEAT.x, SEEN_SEAT.y, 0.3, 0.8])
	out.append([q.fire, SEEN_FLAME.x, SEEN_FLAME.y, 1.5, 0.0])
	if post != Vector2.INF:
		var psz: Vector2 = SIZE["grown"]
		out.append([post, psz.x, psz.y, 0.6, 1.5])
	for b: Building in q.buildings:
		if Vector2(b.x, b.y).distance_to(q.fire) < SEEN_NEAR:
			out.append([Vector2(b.x, b.y), b.size() * SEEN_BLD.x, b.size() * SEEN_BLD.y, 3.0, 0.0])
	return out


## (Q18 ⑩) 상을 p에 차렸을 때 상·등이 네 보기에서 others(feast_others)와 화면에서 겹치는 넓이의 합 (칸² × 몫 — 작을수록 좋다).
## 기본 보기는 TABLE_VIEW_W배로 센다. 등을 세울 수 없는 보기 · 상 끝이 막힌 보기는 벌점
static func table_score(q: Village, p: Vector2, post: Vector2, others: Array) -> float:
	var sc := 0.0
	var right := _right()
	var front := _front()
	var tsz := fx_size("spread")
	var lsz := fx_size("lantern")
	for h in 4:
		var wh := TABLE_VIEW_W if h == 0 else 1.0
		if h % 2 == 1 and (not prop_free(q, p + right * TABLE_HALF) or not prop_free(q, p - right * TABLE_HALF)):
			sc += wh * TABLE_SIDE_PEN
		var things: Array = [[p, tsz.x, tsz.y]]
		for sg: float in [-1.0, 1.0]:
			var lp: Vector2 = p + right * sg * (TABLE_HALF + LAMP_GAP)
			if prop_free(q, lp) and (post == Vector2.INF or lp.distance_to(post) > 0.6):
				things.append([lp, lsz.x, lsz.y])
			else:
				sc += wh * LAMP_MISS_PEN
		for th: Array in things:
			for o: Array in others:
				sc += wh * float(o[3]) * seen_cover(o[0], float(o[1]), float(o[2]), th[0], float(th[1]), float(th[2]), right, front)
				sc += wh * float(o[4]) * seen_cover(th[0], float(th[1]), float(th[2]), o[0], float(o[1]), float(o[2]), right, front)
		var nr := front                                     # 다음 보기 (1/4 바퀴)
		front = -right
		right = nr
	return sc


## 그 보기(right · front = 화면 오른쪽 · 카메라 쪽)에서 앞의 것 a가 뒤의 것 b를 화면에서 가리는 넓이 (칸²). 둘 다 땅에 선 그림 판 (자리 · 너비 · 높이).
## a가 카메라 쪽에 있지 않으면 0. 땅에서 d칸 앞 = 화면에서 d × sin(카메라 기울기)만큼 아래
static func seen_cover(a: Vector2, aw: float, ah: float, b: Vector2, bw: float, bh: float, right: Vector2, front: Vector2) -> float:
	var d := a - b
	var dz := d.dot(front)
	if dz <= 0.0:
		return 0.0
	var oh := minf(ah - dz * sin(deg_to_rad(JarCamera.PITCH_DEG)), bh)
	var ow := minf(minf(aw, bw), (aw + bw) * 0.5 - absf(d.dot(right)))
	return maxf(oh, 0.0) * maxf(ow, 0.0)


## 햇밀 다발 자리: {"pos": 자리 (마을 데이터 좌표), "front": 카메라 쪽으로 당기는 거리, "h": 그림 위 높이 (칸 — 건물 그림처럼 카메라 기울기로
## 나누어 올림), "lift": 땅에서 높이 (칸)}. 적어 둔 건물이 아직 있으면 거기 (없어졌거나 옛 저장이면 지금의 창고 → 첫 밭), 아무것도 없으면 적어 둔 자리
## (모닥불 곁) 땅 위에. 시뮬레이션을 바꾸지 않는다.
static func sheaf(q: Village) -> Dictionary:
	var rec: Dictionary = (q.milestones.get("passed", {}) as Dictionary).get("green", {})
	var st := q.bld(int(rec.get("b", -1)))
	if st == null or not st.built or (st.type != "창고" and st.type != "농장"):
		st = Milestones.sheaf_house(q)
	if st == null:
		var at := Vector2(float(rec["x"]), float(rec["y"])) if rec.has("x") else q.fire + Vector2(0.9, 0.9)
		return {"pos": at, "front": 0.0, "h": 0.0, "lift": 0.0}
	var pos := Vector2(st.x, st.y)
	var pics := Bld2D.enabled()
	if st.type == "농장":
		var fence := float(Bld2D.info(Bld2D.Pics.WHEAT_FENCE).get("front", st.size())) if pics else st.size()
		return {"pos": pos, "front": fence + SHEAF_FENCE, "h": 0.0, "lift": 0.0}
	if pics and Bld2D.has(SHEAF_PIC):
		var front := float(Bld2D.info(SHEAF_PIC).get("front", st.size())) * VillageView.BUILDING_SCALE + SHEAF_FRONT
		return {"pos": pos, "front": front, "h": SHEAF_AT * VillageView.BUILDING_SCALE + SHEAF_FRONT * sin(deg_to_rad(JarCamera.PITCH_DEG)), "lift": 0.0}
	return {"pos": pos, "front": st.size() * VillageView.BUILDING_SCALE * SHEAF_3D.x, "h": 0.0, "lift": SHEAF_3D.y * VillageView.BUILDING_SCALE}


## 멀리서 키우는 몫 (ppu = 한 칸이 화면 점 몇 개인가, cap = 상한 — 작은 장식은 K_CAP). 0.05 걸음
static func sign_k(ppu: float, h: float, cap := K_MAX) -> float:
	return snappedf(clampf(SIGN_PX / (h * maxf(ppu, 1.0)), 1.0, cap), 0.05)


## 잔치 소품 그림판의 칸 (0~1) · 그 그림의 크기 (칸)
static func fx_uv(pic: String) -> Vector4:
	var rc: Rect2 = FX_PICS[pic]
	return Vector4(rc.position.x / FX_ATLAS.x, rc.position.y / FX_ATLAS.y, rc.size.x / FX_ATLAS.x, rc.size.y / FX_ATLAS.y)


static func fx_size(pic: String) -> Vector2:
	var rc: Rect2 = FX_PICS[pic]
	var w := float(FX_W.get(pic, rc.size.x / FX_PX))
	return Vector2(w, w * rc.size.y / rc.size.x)


func _process(dt: float) -> void:
	if view == null or not is_instance_valid(view) or view.v == null:
		return
	_t += dt
	_step += dt
	_since += dt
	var q: Village = view.v
	if _since >= CHECK:
		_since = 0.0
		_place(q)
	_lift_sheaf()
	_feast_props(q, dt, false)
	_grown(q, dt)
	_dance(q)
	_eat(q)
	_clap(q)
	_bubbles()


## 장식과 잔치 몸짓을 지금 기록에 맞춤 (시험·캡처가 바로 부를 수 있다).
## VillageView.sync(…, force)가 부른다 — 큰 시간 건너뛰기(비운 뒤 돌아옴·빠른 흐름) 바로 뒤 첫 화면부터 맞게.
func refresh() -> void:
	var q: Village = view.v
	if q == null:
		return
	_place(q)
	_lift_sheaf()
	_feast_props(q, 0.0, true)
	_grown(q, 0.0)
	_dance(q)
	_eat(q)


## 장식을 지금 기록에 맞춰 세움
func _place(q: Village) -> void:
	var keep := {"post": _post_keep}
	var rec_s: Dictionary = (q.milestones.get("passed", {}) as Dictionary).get("steps", {})
	if not rec_s.is_empty() and not rec_s.has("x"):     # 조용히 넘은 첫걸음마: 한 번 고른 집을 기억 (그 집이 서 있는 동안)
		var hm := quiet_house(q, _quiet_b)
		_quiet_b = hm.id if hm != null else -1
		keep["house"] = _quiet_b
	var want := wanted(q, keep)
	_post_keep = want.get("grown", Vector2.INF)
	view.sign_spot = want.get("pop12", Vector2.INF)     # 화면이 그 둘레의 키 큰 꽃 그림을 낮추고 잔것을 비운다 (VillageView._grave_scale · _decor_items)
	for id: String in _signs.keys():
		if not want.has(id):
			(_signs[id] as Node).queue_free()
			_signs.erase(id)
	var ppu := _ppu()
	for id: String in want:
		var mi: MeshInstance3D = _signs.get(id)
		if mi == null:
			mi = _make(id)
			_signs[id] = mi
		var p: Vector2 = want[id]
		mi.position = Vector3(p.x, view.gy(p.x, p.y), p.y)
		var sz: Vector2 = SIZE[id]
		var k := _k_of(id, ppu)
		mi.set_instance_shader_parameter("k", k)
		var r := maxf(sz.x, sz.y) * 1.6 * maxf(k, 1.0)
		mi.custom_aabb = AABB(Vector3(-r, -r, -r), Vector3(r * 2.0, r * 2.0, r * 2.0))
		if id == "green":                               # 햇밀 다발: 건물 그림 바로 앞 · 문틀 높이 (높이는 _lift_sheaf가 카메라 기울기에 맞춰 넣는다)
			_hang = sheaf(q)
			var front := float(_hang["front"])
			(mi.material_override as ShaderMaterial).set_shader_parameter("geo", Vector4(sz.x, sz.y, front, 0.0))
			(mi.material_override as ShaderMaterial).set_shader_parameter("ex", Vector4(0.0, 0.0, 0.0, front))
			var e := r + front
			mi.custom_aabb = AABB(Vector3(-e, -r, -e), Vector3(e * 2.0, r * 2.0 + float(_hang["lift"]) + float(_hang["h"]) / 0.3, e * 2.0))
			_hang_lift = -1.0


## 그 장식을 지금 키우는 몫 — 키를 재는 동안의 기둥은 제 크기로 (젊은이의 키와 맞게)
func _k_of(id: String, ppu: float) -> float:
	var k := sign_k(ppu, (SIZE[id] as Vector2).y, float(K_CAP.get(id, K_MAX)))
	if id == "grown" and _star_w > 0.0:
		k = lerpf(k, 1.0, _star_w)
	return k


## 햇밀 다발의 높이: 건물 그림은 카메라 기울기만큼 위로 늘여 그리므로(화면에서 1:1) 그림 위의 한 점도 같은 몫으로 올린다 — 카메라가 기울어도 문틀 위에
func _lift_sheaf() -> void:
	var mi: MeshInstance3D = _signs.get("green")
	if mi == null or _hang.is_empty():
		return
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cu := maxf(cam.global_transform.basis.y.y, 0.3) if cam != null else cos(deg_to_rad(JarCamera.PITCH_DEG))
	var lift := float(_hang["lift"]) + float(_hang["h"]) / cu
	if not is_equal_approx(lift, _hang_lift):
		_hang_lift = lift
		mi.set_instance_shader_parameter("lift", lift)


## (화면 · 시험) 햇밀 다발을 지금 올려 둔 높이 (칸 — 땅에서)
func sheaf_lift() -> float:
	return _hang_lift


func _make(id: String) -> MeshInstance3D:
	var mat: ShaderMaterial = _mats.get(id)
	if mat == null:
		var sz: Vector2 = SIZE[id]
		mat = ShaderMaterial.new()
		mat.shader = Flora2D.CARD_SHADER
		mat.set_shader_parameter("tex", load(String(TEX[id])))
		mat.set_shader_parameter("uv_rect", Vector4(0.0, 0.0, 1.0, 1.0))
		mat.set_shader_parameter("geo", Vector4(sz.x, sz.y, 0.0, 0.0))
		mat.set_shader_parameter("ex", Vector4(0.0, 0.0, 0.0, 0.0))
		var n := int(FRAMES.get(id, 1))
		if n > 1:                                       # 옆으로 이어 붙인 장면을 차례로 (바람개비 날개)
			var fr: Array = []
			for i in 8:
				fr.append(Vector4(float(i % n) / float(n), 0.0, 1.0 / float(n), 1.0))
			mat.set_shader_parameter("frames", n)
			mat.set_shader_parameter("fps", FRAME_FPS)
			mat.set_shader_parameter("frame_uv", fr)
		_mats[id] = mat
	var mi := MeshInstance3D.new()
	mi.name = "Sign_" + id
	mi.mesh = Flora2D.quad()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_instance_shader_parameter("k", 1.0)
	mi.set_instance_shader_parameter("flip", 1.0)
	mi.set_instance_shader_parameter("lift", 0.0)
	mi.set_instance_shader_parameter("phase", 0.0)
	mi.set_instance_shader_parameter("tint", Color(1, 1, 1))
	add_child(mi)
	return mi


## (화면 · 시험) 지금 서 있는 장식의 노드 (없으면 null)
func sign_node(id: String) -> MeshInstance3D:
	return _signs.get(id)


## 지금 화면 확대 (GraveView._ppu와 같은 셈). 카메라가 없으면 (시험) 마을 기본 확대
func _ppu() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or cam.projection != Camera3D.PROJECTION_ORTHOGONAL or cam.size <= 0.0:
		return float(JarCamera.ZOOM_PPU[1])
	return float(get_viewport().get_visible_rect().size.y) / cam.size


## 지금 카메라의 오른쪽 · 카메라 쪽 (땅 위 방향 — 화면 좌표). 카메라가 없으면 (시험) 기본 보기
func _cam_right() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var b := cam.global_transform.basis.x
		var f := Vector3(b.x, 0.0, b.z)
		if f.length() > 0.01:
			return f.normalized()
	var r := _right()
	return Vector3(r.x, 0.0, r.y)


func _cam_front() -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var b := cam.global_transform.basis.z
		var f := Vector3(b.x, 0.0, b.z)
		if f.length() > 0.01:
			return f.normalized()
	var r := _front()
	return Vector3(r.x, 0.0, r.y)


## 그 인형이 화면에서 보는 쪽 (+1 오른쪽 · -1 왼쪽). 앞·뒤를 보고 섰으면 손이 몸 가운데라 몫을 줄인다
static func _face(cm: CutoutResident) -> float:
	if cm.doll == null:
		return 1.0
	var side := 1.0 if float(cm.doll.mirror) >= 0.0 else -1.0
	var vw := int(cm.doll.view)
	return side * (0.35 if vw == 0 or vw == 3 else 1.0)


## 잔치 소품 그림 한 장 (kind 0 = 그늘지는 소품 · 1 = 빛나는 판 · 2 = 둥근 빛). 재질 셋 · 사각형 하나를 나눠 쓴다
func _fx_card(pic: String, kind := 0) -> MeshInstance3D:
	if _fx_quad == null:
		_fx_quad = QuadMesh.new()
		_fx_quad.size = Vector2.ONE
		var tex := load(FX_TEX) as Texture2D
		_fx_mat = ShaderMaterial.new()
		_fx_mat.shader = load(KidsView.SHADER_PATH)
		_fx_mat.set_shader_parameter("tex", tex)
		var sh := Shader.new()
		sh.code = GLOW_CODE
		_glow_mat = ShaderMaterial.new()
		_glow_mat.shader = sh
		_glow_mat.set_shader_parameter("tex", tex)
		_glow_mat.render_priority = FX_PRIORITY
		_halo_mat = _glow_mat.duplicate()
		_halo_mat.render_priority = FX_PRIORITY - 1
	var n := MeshInstance3D.new()
	n.name = "Fx_" + pic
	n.mesh = _fx_quad
	n.material_override = _fx_mat if kind == 0 else (_glow_mat if kind == 1 else _halo_mat)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.extra_cull_margin = 2.0
	n.visible = false
	add_child(n)
	n.set_instance_shader_parameter("rect", fx_uv(pic))
	return n


## 잔칫상과 등: 잔치 동안만 (톡 차려지고, 끝나면 톡 거둔다). snap = 바로 (시간 건너뛰기 뒤 · 시험)
func _feast_props(q: Village, dt: float, snap: bool) -> void:
	var on := Milestones.feast_on(q)
	if not on and _feast_w <= 0.0 and _spots.is_empty():
		return
	var cr := _cam_right()
	var r2 := Vector2(cr.x, cr.z)
	if on and _spots.is_empty():
		_spots = feast_spots(q, _post_keep, _seat_spots(q), r2)
		_lamp_right = r2
	elif on and r2.dot(_lamp_right) < LAMP_TURN_DOT:    # (Q18 ⑩) 카메라가 돌았다: 등이 상의 화면 양 끝을 따라간다 (상은 늘 카메라를 보고 서니)
		_lamp_right = r2
		_spots["lamps"] = feast_lamps(q, _spots["table"], _post_keep, r2)
	var goal := 1.0 if on else 0.0
	_feast_w = goal if snap or view.fast else move_toward(_feast_w, goal, dt / FEAST_POP_SECS)
	var fire: Campfire = view._fire
	if _feast_w <= 0.0:
		if _table != null:
			_table.visible = false
		for l: Array in _lamps:
			(l[0] as Node3D).visible = false
			(l[1] as Node3D).visible = false
		_spots = {}
		_shoo(false)
		if fire != null and not fire.lamps.is_empty():
			fire.lamps = []
		return
	var e := _feast_w * _feast_w * (3.0 - 2.0 * _feast_w)
	var pop := e * (1.0 + 0.12 * sin(e * PI))
	var tp: Vector2 = _spots["table"]
	if tp != Vector2.INF:
		if _table == null:
			_table = _fx_card("spread")
		var sz := fx_size("spread")
		_table.visible = true
		_table.position = Vector3(tp.x, view.gy(tp.x, tp.y), tp.y)
		_table.set_instance_shader_parameter("geo", Vector4(sz.x, sz.y, 0.0, 0.0))
		_table.set_instance_shader_parameter("fx", Vector4(pop, pop, 0.0, 0.0))
	elif _table != null:
		_table.visible = false
	var spots: Array = _spots["lamps"]
	while _lamps.size() < spots.size():
		_lamps.append([_fx_card("lantern", 1), _fx_card("lantern", 2)])
	var glow: Array = []
	var right := _cam_right()
	var lsz := fx_size("lantern")
	for i in _lamps.size():
		var pole: MeshInstance3D = _lamps[i][0]
		var halo: MeshInstance3D = _lamps[i][1]
		if i >= spots.size():
			pole.visible = false
			halo.visible = false
			continue
		var lp: Vector2 = spots[i][0]
		var sg := float(spots[i][1])
		var base := Vector3(lp.x, view.gy(lp.x, lp.y), lp.y)
		var lx := -sg * LAMP_AT.x                        # 등은 상 쪽(안쪽)으로 걸린다 — 오른쪽 등은 그림을 뒤집음
		var flick := 1.0 + 0.06 * sin(_t * 9.0 + float(i) * 2.1)
		pole.visible = true
		pole.position = base
		pole.set_instance_shader_parameter("geo", Vector4(-sg * lsz.x, lsz.y, 0.0, 0.0))
		pole.set_instance_shader_parameter("fx", Vector4(pop, 1.0, 0.0, 0.0))
		halo.visible = true
		halo.position = base + right * (lx * pop)
		halo.set_instance_shader_parameter("geo", Vector4(LAMP_HALO, LAMP_HALO, 1.0, -0.06))
		halo.set_instance_shader_parameter("fx", Vector4(pop * flick, (LAMP_HALO_A.x + LAMP_HALO_A.y * Campfire.night) * e, 1.0, LAMP_AT.y * pop))
		glow.append([view.to_global(base + right * lx + Vector3(0.0, LAMP_AT.y, 0.0)) if view.is_inside_tree() else base, LAMP_GLOW_R, LAMP_GLOW_K * e])
	if fire != null:
		fire.lamps = glow
	_shoo(true)


## (Q18 ⑩) 모닥불 걸상의 자리 (마을 데이터 좌표 — Campfire가 놓은 것을 읽기만)
func _seat_spots(q: Village) -> Array:
	var out: Array = []
	var fire: Campfire = view._fire
	if fire == null or not is_instance_valid(fire) or fire.seats == null:
		return out
	for c in fire.seats.get_children():
		var n := c as Node3D
		if n != null:
			out.append(q.fire + Vector2(n.position.x, n.position.z))
	return out


## (Q18 ⑩) 잔치 동안 나비·꿀벌이 상·등·기둥의 화면 앞을 가리지 않게 그 둘레를 비켜 날게 한다 (FaunaView.shoo — 화면만, 잔치가 끝나면 되돌림)
func _shoo(on: bool) -> void:
	var fv: FaunaView = view.fauna_view
	if fv == null or not is_instance_valid(fv):
		return
	if not on:
		if _shoo_on:
			_shoo_on = false
			fv.set_shoo([])
		return
	_shoo_on = true
	var f := _cam_front()
	var f2 := Vector2(f.x, f.z) * SHOO_FRONT
	var list: Array = []
	var tp: Vector2 = _spots.get("table", Vector2.INF)
	if tp != Vector2.INF:
		list.append([tp + f2, SHOO_TABLE_R])
	for l: Array in _spots.get("lamps", []):
		list.append([(l[0] as Vector2) + f2, SHOO_POLE_R])
	if _post_keep != Vector2.INF:
		list.append([_post_keep + f2, SHOO_POLE_R])
	fv.set_shoo(list)


## (화면 · 시험) 지금 차려진 잔칫상 (없으면 null) · 켜진 등 수
func feast_table() -> MeshInstance3D:
	return _table if _table != null and _table.visible else null


func lamps_lit() -> int:
	var n := 0
	for l: Array in _lamps:
		if (l[0] as Node3D).visible:
			n += 1
	return n


## 첫 어른 잔치: 그 젊은이가 불 곁에 닿았는지 보고 (닿았으면 pose가 기둥 옆으로 옮긴다), 새 끈 · 기둥 크기 · 한마디를 맞춘다
func _grown(q: Village, dt: float) -> void:
	var who := -1
	_guests.clear()
	if not view.fast and _signs.has("grown") and Milestones.feast_id(q) == "grown":
		var rec: Dictionary = (q.milestones["passed"] as Dictionary).get("grown", {})
		var id := int(rec.get("who", -1))
		for p in q.people:
			if p.dead or p.action != "festival":
				continue
			var far := Vector2(p.x, p.y).distance_to(q.fire)
			if p.id == id:                               # (Q18 ⑦) 그 젊은이는 잔치에 불려 오는 대로 (얼마나 멀리 있었든) 바로 기둥으로 달려간다 — 잔치가 짧다
				who = id
			elif far <= DANCE_R and (p.anim == "eat" or p.anim == "play"):
				_guests.append(p.id)
		if who < 0:
			_guests.clear()
	if who >= 0 and _star >= 0 and _star != who:
		_release_star()
	if _star_on != (who >= 0):
		_star_speed = -1.0                           # 가는 길 · 돌아오는 길의 빠르기를 남은 거리로 다시
	_star_on = who >= 0
	if _star_on and _star < 0:
		_star = who
		_star_at = Vector3.INF
		_star_there = false
		_say_t = 0.5
		_say_i = 0
	if _star >= 0 and not _star_on:                  # 잔치가 끝남: pose가 제자리로 돌려보낸다 — 화면이 멈췄거나(빠른 흐름) 인형이 없으면 바로 놓음
		var sm := view.residents.get(_star) as Node3D
		if view.fast or sm == null or not is_instance_valid(sm):
			_release_star()
	if _star < 0 and _star_w <= 0.0 and _ribbon == null:
		return
	var goal := 1.0 if _star_on and _star_there else 0.0
	var w0 := _star_w
	_star_w = goal if dt <= 0.0 and goal == 0.0 else move_toward(_star_w, goal, dt / STAR_POP_SECS)
	var pm: MeshInstance3D = _signs.get("grown")
	if pm != null and not is_equal_approx(w0, _star_w):
		pm.set_instance_shader_parameter("k", _k_of("grown", _ppu()))
	if _star_w > 0.0 and pm != null:
		if _ribbon == null:
			_ribbon = _fx_card("ribbon")
		var sz := fx_size("ribbon")
		var e := _star_w * (1.0 + 0.25 * sin(_star_w * PI))
		_ribbon.visible = true
		_ribbon.position = pm.position + _cam_right() * POLE_DX
		_ribbon.set_instance_shader_parameter("geo", Vector4(sz.x, sz.y, 0.0, 0.05))
		_ribbon.set_instance_shader_parameter("fx", Vector4(e, e, 1.0, _star_top * (1.0 + STAR_STRETCH * 0.5)))
	elif _ribbon != null:
		_ribbon.visible = false
	if _star_on and _star_w >= 1.0:                  # 한마디: 젊은이와 손님이 번갈아 (숫자 없음)
		_say_t -= dt
		if _say_t <= 0.0:
			_say_t = GROWN_SAY_EVERY
			var id := _star
			var text := STAR_SAY
			if _say_i % 3 != 0 and not _guests.is_empty():
				id = int(_guests[(_say_i * 5 + 1) % _guests.size()])
				text = String(GROWN_SAY[_say_i % GROWN_SAY.size()])
			_say_i += 1
			if not view.stage_say.has(id):
				view.stage_say[id] = [text, "cheer", GROWN_SAY_SECS]


## 키를 재던 젊은이를 놓아 줌 (몸짓을 되돌림)
func _release_star() -> void:
	var cm := view.residents.get(_star) as CutoutResident
	if cm != null and is_instance_valid(cm) and not _dancing.has(_star) and not _eating.has(_star):
		cm.set_body_lift()
		cm.set_body_warp()
	_star = -1
	_star_on = false
	_star_speed = -1.0
	_star_at = Vector3.INF
	_star_there = false


## (화면 · 시험) 지금 기둥 옆에서 키를 재는 젊은이 (없으면 -1) · 그 화면 자리 · 새 끈이 달렸나
func star() -> int:
	return _star if _star_on else -1


func star_there() -> bool:
	return _star_on and _star_there


func ribbon_on() -> bool:
	return _ribbon != null and _ribbon.visible


## 잔치 춤: 모닥불 둘레에서 "play" 몸짓인 잔치 손님 — 폴짝 + 좌우 흔들림. 잔치가 끝나거나 자리를 뜨면 되돌림
func _dance(q: Village) -> void:
	var on := Milestones.feast_on(q) and not view.fast
	if not on and _dancing.is_empty():
		return
	var live := {}
	if on:
		for p in q.people:
			if p.action != "festival" or p.anim != "play" or p.id == _star or Vector2(p.x, p.y).distance_to(q.fire) > DANCE_R:
				continue
			var cm := view.residents.get(p.id) as CutoutResident
			if cm == null or not is_instance_valid(cm):
				continue
			live[p.id] = true
			var ph := _t * BEAT + float(p.id) * 1.7
			var hop := absf(sin(ph))
			cm.set_body_lift(HOP * hop)
			cm.set_body_warp(1.0 + 0.05 * hop, 1.0 - 0.03 * hop, SWAY * sin(ph * 0.5))
	for rid: int in _dancing.keys():
		if live.has(rid):
			continue
		var cm := view.residents.get(rid) as CutoutResident
		if cm != null and is_instance_valid(cm) and rid != _star:
			cm.set_body_lift()
			cm.set_body_warp()
		_dancing.erase(rid)
	for rid: int in live:
		_dancing[rid] = true


## (Q15) 잔치 먹기: 모닥불 둘레에서 "eat" 몸짓인 잔치 손님 — 손에 든 빵을 입으로 올렸다 내렸다, 한 입에 몸을 조금 숙인다. 끝나면 되돌림
func _eat(q: Village) -> void:
	var on := Milestones.feast_on(q) and not view.fast
	if not on and _eating.is_empty():
		return
	var live := {}
	if on:
		var right := _cam_right()
		var sz := fx_size("loaf")
		for p in q.people:
			if p.action != "festival" or p.anim != "eat" or p.id == _star or Vector2(p.x, p.y).distance_to(q.fire) > DANCE_R:
				continue
			var cm := view.residents.get(p.id) as CutoutResident
			if cm == null or not is_instance_valid(cm):
				continue
			live[p.id] = true
			if cm._f_on and cm._f_clip == "eat":         # (Q18 ⑧) 그린 인형(방식 C): 먹는 그림에 이미 빵이 들려 있다 — 소품 빵·숙임을 얹지 않는다 (빵 하나만)
				cm.set_body_lift()
				cm.set_body_warp()
				var old: MeshInstance3D = _loaves.get(p.id)
				if old != null:
					old.queue_free()
					_loaves.erase(p.id)
				continue
			var s := 0.5 + 0.5 * sin(_t * EAT_BEAT + float(p.id) * 1.9)
			var bite := smoothstep(0.55, 1.0, s)
			var face := _face(cm)
			var side := signf(face)
			cm.set_body_lift()
			cm.set_body_warp(1.0 - 0.03 * bite, 1.0 + 0.02 * bite, EAT_LEAN * bite * side)
			var n: MeshInstance3D = _loaves.get(p.id)
			if n == null:
				n = _fx_card("loaf")
				_loaves[p.id] = n
			var h := cm.react_top()
			var at := EAT_HAND.lerp(EAT_MOUTH, smoothstep(0.0, 1.0, s)) * h
			n.visible = cm.visible
			n.position = cm.position + right * (face * at.x)
			n.set_instance_shader_parameter("geo", Vector4(sz.x, sz.y, -0.25 * side * bite, 0.06))
			var kd := clampf(h / (CutoutResident.DOLL_H * 0.78), 0.62, 1.0)     # 아이의 빵은 아이 몸집만큼 (얼굴을 덮지 않게)
			n.set_instance_shader_parameter("fx", Vector4(-side * kd, kd, 1.0, at.y))     # 베어 문 쪽이 입을 보게
	for rid: int in _eating.keys():
		if live.has(rid):
			continue
		var cm := view.residents.get(rid) as CutoutResident
		if cm != null and is_instance_valid(cm) and not _dancing.has(rid) and rid != _star:
			cm.set_body_warp()
		_eating.erase(rid)
		var n: MeshInstance3D = _loaves.get(rid)
		if n != null:
			n.queue_free()
			_loaves.erase(rid)
	for rid: int in live:
		_eating[rid] = true


## (Q15) 그림 말풍선: 먹는 사람의 빵 · 손뼉 치는 이웃의 두 손 · 첫 어른 잔치 손님의 자람 그림 — 몇 사람만, 차례로 돌아가며 (글 말풍선이 뜬 사람은 건너뜀)
func _bubbles() -> void:
	bub.clear()
	bub.keep_out = []
	if view.fast or (_eating.is_empty() and _clapping.is_empty() and _guests.is_empty()):
		return
	if not _clapping.is_empty():                        # (Q18 ⑪) 손뼉 그림 말풍선이 문 앞 바람개비를 덮지 않게
		var pr := pin_rect()
		if pr.size.x > 0.0:
			bub.keep_out = [pr.grow(PIN_KEEP)]
	var slot := int(_t / BUB_SECS)
	var u := fposmod(_t, BUB_SECS) / BUB_SECS
	if _star_w > 0.5:
		_bub_some(_guests, "grow", BUB_GROW, slot, u)
	else:
		_bub_some(_eating.keys(), "bread", BUB_EAT, slot, u)
	_bub_some(_clapping.keys(), "hands", BUB_CLAP, slot, u)


func _bub_some(ids: Array, pic: String, many: int, slot: int, u: float) -> void:
	var free: Array = []                                # 글 말풍선이 없는 사람만 (그 사람들끼리 돌아가며)
	for id: int in ids:
		var m := view.residents.get(id) as Node3D
		if m != null and is_instance_valid(m) and not view.stage_say.has(id):
			free.append(id)
	var n := free.size()
	if n == 0:
		return
	free.sort()
	var shown: Array = []                               # 이미 띄운 사람의 자리 — 바로 곁 사람에겐 겹쳐 띄우지 않는다
	for j in n:
		if shown.size() >= many:
			break
		var id := int(free[(slot * many + j) % n])
		var m := view.residents.get(id) as Node3D
		var near := false
		for at: Vector3 in shown:
			if Vector2(at.x - m.position.x, at.z - m.position.z).length() < BUB_APART:
				near = true
				break
		if near:
			continue
		shown.append(m.position)
		bub.add(m, pic, u, false, _t + float(id))


## VillageView.sync가 사람마다 부른다 (자리·몸짓을 정한 바로 뒤) — 화면만:
##   - 첫 어른 잔치의 젊은이: 기둥 옆으로 폴짝폴짝 가서 카메라를 보고 선다 (발돋움). 잔치가 끝나면 제자리로 돌아간 뒤 놓아 준다
##   - 그 잔치의 다른 손님: 젊은이 쪽을 본다
##   - 첫걸음마를 보러 온 이웃: 문 앞에 서면 아기 쪽을 본다. 걸어오는 중·아기를 보는 사람은 그대로
func pose(r: Resident, m: ResidentModel) -> void:
	if _star >= 0:
		if r.id == _star:
			_pose_star(r, m)
			return
		if _star_on and _star_at != Vector3.INF and r.action == "festival" and (r.anim == "eat" or r.anim == "play") \
				and Vector2(r.x, r.y).distance_to(view.v.fire) <= DANCE_R:
			var ds := _star_at - m.position
			if ds.x * ds.x + ds.z * ds.z > 0.01:
				m.rotation.y = atan2(ds.x, ds.z)
			return
	if r.steps.is_empty():
		return
	var s0: Dictionary = r.steps[0]
	if not s0.has("ms") or String(s0.get("k", "")) != "do" or bool(s0.get("par", false)):
		return
	var bm: Node3D = view.residents.get(int(s0["ms"]))
	if bm == null or not is_instance_valid(bm):
		return
	var d := bm.position - m.position
	if d.x * d.x + d.z * d.z > 0.01:
		m.rotation.y = atan2(d.x, d.z)


func _pose_star(r: Resident, m: ResidentModel) -> void:
	var goal := m.position                              # 시뮬레이션 자리 (방금 놓인 곳)
	var pm: MeshInstance3D = _signs.get("grown")
	if _star_on and pm != null:
		goal = pm.position + _cam_right() * STAR_OFF.x + _cam_front() * STAR_OFF.y
		goal.y = view.gy(goal.x, goal.z)
	if _star_at == Vector3.INF:
		_star_at = m.position
	var flat := Vector3(goal.x - _star_at.x, 0.0, goal.z - _star_at.z)
	var left := flat.length()
	if _star_speed < 0.0:                               # (Q18 ⑦) 멀수록 빨리 — STAR_RUN_SECS 안에 닿게
		_star_speed = maxf(STAR_SPEED, left / STAR_RUN_SECS)
	var step := _star_speed * _step
	_step = 0.0
	var moving := left > step + 0.001 and left <= STAR_SNAP
	if moving:
		_star_at += flat / left * step
		_star_at.y = view.gy(_star_at.x, _star_at.z)
	else:
		_star_at = goal
	_star_there = _star_on and not moving
	if not _star_on and not moving:                     # 제자리에 돌아옴
		_release_star()
		return
	var cm := m as CutoutResident
	m.position = _star_at
	if _star_on:
		m.set_anim("idle", r.action)
	if moving:
		if left > 0.05:
			m.rotation.y = atan2(flat.x, flat.z)
		if cm != null:
			var hop := absf(sin(_t * STAR_HOP_BEAT)) if _star_on or r.anim != "walk" else 0.0
			cm.set_body_lift(HOP * hop)
			cm.set_body_warp(1.0 + 0.05 * hop, 1.0 - 0.03 * hop, 0.0)
	else:
		var f := _cam_front()
		m.rotation.y = atan2(f.x, f.z)
		if cm != null:
			var up := 0.5 + 0.5 * sin(_t * STAR_BEAT)
			cm.set_body_lift()
			cm.set_body_warp(1.0 + STAR_STRETCH * up, 1.0 - 0.02 * up, 0.0)
			_star_top = cm.react_top()


## 첫걸음마 손뼉: "ms" 표시가 붙은 손뼉 걸음("play") 중인 이웃 — 콩콩 뛰며 한마디, 발이 닿을 때마다 손 높이에 '짝' 금. 걸음이 끝나면 되돌림
func _clap(q: Village) -> void:
	var live := {}
	if not view.fast and (q.milestones.has("steps_call") or not _clapping.is_empty() or _clap_recent(q)):
		var right := _cam_right()
		var sz := fx_size("clap")
		for p in q.people:
			if p.steps.is_empty() or p.anim != "play":
				continue
			var s0: Dictionary = p.steps[0]
			if not s0.has("ms") or String(s0.get("k", "")) != "do":
				continue
			var cm := view.residents.get(p.id) as CutoutResident
			if cm == null or not is_instance_valid(cm):
				continue
			live[p.id] = true
			var hop := absf(sin(_t * CLAP_BEAT + float(p.id) * 1.3))
			cm.set_body_lift(CLAP_HOP * hop)
			cm.set_body_warp(1.0 + 0.04 * hop, 1.0 - 0.025 * hop, 0.0)
			var pop := 1.0 - smoothstep(0.0, CLAP_OPEN, hop)
			if pop >= CLAP_SND_POP:
				_clap_sound(q, Vector2(p.x, p.y))
			var n: MeshInstance3D = _claps.get(p.id)
			if n == null:
				n = _fx_card("clap", 1)
				_claps[p.id] = n
			var h := cm.react_top()
			n.visible = cm.visible and pop > 0.02
			n.position = cm.position + right * (_face(cm) * CLAP_AT.x * h)
			n.set_instance_shader_parameter("geo", Vector4(sz.x, sz.y, 0.0, 0.08))
			n.set_instance_shader_parameter("fx", Vector4(0.55 + 0.45 * pop, pop, 1.0, CLAP_AT.y * h + CLAP_HOP * hop))
			if not _clapping.has(p.id):
				if _clapping.is_empty() and live.size() == 1:
					GameAudio.fx("small_cheer", "Village", -11.0, Vector2(p.x, p.y))
				if not view.stage_say.has(p.id):
					view.stage_say[p.id] = [String(CLAP_SAY[p.id % CLAP_SAY.size()]), "cheer", CLAP_SAY_SECS]
	for rid: int in _clapping.keys():
		if live.has(rid):
			continue
		var cm := view.residents.get(rid) as CutoutResident
		if cm != null and is_instance_valid(cm):
			cm.set_body_lift()
			cm.set_body_warp()
		_clapping.erase(rid)
		var n: MeshInstance3D = _claps.get(rid)
		if n != null:
			n.queue_free()
			_claps.erase(rid)
	for rid: int in live:
		_clapping[rid] = true


## (Q18 ⑨) 작은 손뼉 소리: '짝' 금이 터질 때 — 여럿이 쳐도 한 번, 앞 소리에서 CLAP_SND_GAP(현실 초)이 지나고 병의 시간도 흐른 뒤에만
## (멈춘 화면에서 되풀이하지 않게). 소리 설정(끄기 · 크기)과 거리는 GameAudio가 본다. 냈으면 true
func _clap_sound(q: Village, at: Vector2) -> bool:
	if _t - _clap_snd_t < CLAP_SND_GAP or q.t <= _clap_snd_qt:
		return false
	_clap_snd_t = _t
	_clap_snd_qt = q.t
	clap_sounds += 1
	GameAudio.fx(CLAP_SND, "Village", CLAP_SND_DB, at)
	return true


## (Q18 ⑪ · 화면 · 시험) 바람개비가 화면에서 차지하는 네모 (화소 — 바람개비나 카메라가 없으면 빈 네모)
func pin_rect() -> Rect2:
	var mi: MeshInstance3D = _signs.get("steps")
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if mi == null or cam == null or cam.is_position_behind(mi.global_position):
		return Rect2()
	var ppu := _ppu()
	var sz: Vector2 = (SIZE["steps"] as Vector2) * _k_of("steps", ppu) * ppu
	var base := cam.unproject_position(mi.global_position)
	return Rect2(base.x - sz.x * 0.5, base.y - sz.y, sz.x, sz.y)


## (Q20 ㉜ · 화면 · 시험) 잔치 동안 글 말풍선이 덮으면 안 되는 화면 네모들 (화소 — 틈 SAY_KEEP 포함): 잔칫상 · 등(막대와 등불 그림 — 둥근 빛은 빼고) ·
## 키 재는 기둥. 잔치 소품이 차려져 있지 않으면 빈 배열 (평소의 말풍선은 그대로). 화면이 읽기만 한다 — view/test_village.gd bubble_free
func say_keep_out() -> Array:
	var out: Array = []
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or _feast_w <= 0.0:
		return out
	var ppu := _ppu()
	if _table != null and _table.visible:
		out.append(_seen_rect(cam, _table, fx_size("spread") * ppu))
	for l: Array in _lamps:
		if (l[0] as Node3D).visible:
			out.append(_seen_rect(cam, l[0], fx_size("lantern") * ppu))
	var pm: MeshInstance3D = _signs.get("grown")
	if pm != null and pm.visible:
		out.append(_seen_rect(cam, pm, (SIZE["grown"] as Vector2) * _k_of("grown", ppu) * ppu))
	var kept: Array = []
	for rc: Rect2 in out:
		if rc.size.x > 0.0:
			kept.append(rc.grow(SAY_KEEP))
	return kept


## 밑 가운데가 n의 자리에 선 그림(크기 sz — 화소)이 화면에서 차지하는 네모. 카메라 뒤면 빈 네모
func _seen_rect(cam: Camera3D, n: Node3D, sz: Vector2) -> Rect2:
	if cam.is_position_behind(n.global_position):
		return Rect2()
	var base := cam.unproject_position(n.global_position)
	return Rect2(base.x - sz.x * 0.5, base.y - sz.y, sz.x, sz.y)


## (Q18 ⑧ · 화면 · 시험) 그 손님에게 지금 보이는 빵 수: 그린 인형의 먹는 그림 속 빵 + 화면이 얹은 소품 빵 (먹는 중이면 늘 하나)
func breads_of(id: int) -> int:
	var n := 0
	var cm := view.residents.get(id) as CutoutResident
	if cm != null and is_instance_valid(cm) and cm._f_on and cm._f_clip == "eat":
		n += 1
	var l: MeshInstance3D = _loaves.get(id)
	if l != null and l.visible:
		n += 1
	return n


## 첫걸음마 고비를 방금 넘었나 (손뼉 걸음이 아직 남아 있을 동안만 사람들을 살핀다)
func _clap_recent(q: Village) -> bool:
	var rec: Dictionary = (q.milestones.get("passed", {}) as Dictionary).get("steps", {})
	return not rec.is_empty() and not bool(rec.get("silent", false)) and q.t - float(rec.get("t", -1.0e12)) < Balance.STEPS_CLAP_SECS * 2.0


## (화면 · 시험) 지금 손뼉 치는 이웃 수
func clappers() -> int:
	return _clapping.size()


## (화면 · 시험) 지금 춤추는 사람 수
func dancers() -> int:
	return _dancing.size()


## (화면 · 시험) 지금 빵을 먹는 잔치 손님 수
func eaters() -> int:
	return _eating.size()
