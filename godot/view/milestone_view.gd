## 자람의 보상 — 영구 장식(빵 간판 · 마을 이름 표지판 · 문 앞 바람개비 · 키 재는 기둥 · 창고 문 위 햇밀 다발)과 잔치 춤 · 첫걸음마 손뼉 (docs/PROGRESSION.md 4.5 · ROADMAP Q9 · Q15).
## 화면만 (ADR-0001): 병의 고비 기록(sim/milestones.gd)과 주민의 하는 일을 읽기만 한다. 새 건물 종류 없음 · 시뮬레이션 효과 없음 · 난수 없음.
##   - 빵 간판: 첫 빵을 넘은 병 — 다 지은 화덕(빵집) 앞 오른쪽에 (기본 보기에서 카메라 쪽)
##   - 마을 이름 표지판: 식구 열둘을 넘은 병 — 마을 어귀 (고비를 넘을 때 적어 둔 자리 — 꽃·길·건물·무덤을 피한 곳, 나중에 건물이 서면 그 옆 빈자리).
##     그 둘레·앞의 키 큰 꽃 그림은 낮추고 발치의 잔것은 비운다 (VillageView.sign_spot — 무덤과 같은 방식)
##   - 문 앞 작은 바람개비 (Q9 ⑦): 첫걸음마를 넘은 병 — 그 아기네 집 문 옆 요람 곁 (집이 없어졌으면 그때 적어 둔 자리). 날개가 돈다 (여섯 장면).
##     조용히 넘은 옛 저장(어느 집인지 적혀 있지 않다)은 마을에서 난 사람 가운데 가장 먼저 난 이의 집 문 앞, 없으면 가장 먼저 지은 살림집 (Q15 — quiet_house).
##     작은 그림이라 멀리서는 다른 장식보다 더 키운다 (K_CAP — 마을 기본 확대에서도 SIGN_PX).
##   - 키 재는 기둥 (Q9 ⑦ · Q15): 마을에서 난 첫 아이가 어른이 된 병 — 모닥불 바로 곁 (기본 보기에서 불의 왼쪽, 걸상 바로 밖 — post_at).
##     시뮬레이션이 적어 둔 자리는 창고 장작더미 쪽으로 밀려나곤 해서 화면이 불 곁 빈자리를 다시 찾는다 (불 곁이 모두 막혔을 때만 적어 둔 자리).
##     조용히 넘은 옛 저장도 같은 자리에.
##   - 햇밀 다발 (Q9 ⑭): 첫 푸른 밀 고개를 넘긴 병 — 창고 문 위 (창고 그림의 문틀 높이에, 그림 바로 앞 — 카메라가 돌아도 늘 보이는 쪽).
##     창고가 없으면 첫 밭 울타리 앞에, 밭도 없으면 적어 둔 자리(모닥불 곁)에 세워 둔다. 조용히 넘은 옛 저장도 창고에 건다 (자리를 알 수 있으니).
##   - 첫걸음마 손뼉 (Q9 ⑦): 아기의 첫걸음마를 보러 문 앞에 온 이웃(걸음의 "ms" 표시 — Milestones._gather)이 아기 쪽을 보고,
##     손뼉 걸음("play") 동안 콩콩 뛰며 한마디. (Q15) 발이 닿는 박자마다 손 높이에 '짝' 금 그림 + 손뼉 그림 말풍선.
##     손뼉 소리는 따로 없다 (godot/audio에 맞는 소리가 없어서 — 처음의 small_cheer 한 번만)
##   - 잔치 춤: 잔치 중(Milestones.feast_on) 모닥불 둘레에서 "play" 몸짓인 사람이 폴짝이며 좌우로 흔들림 (인형 통째 — 새 그림 없음)
##   - 잔치 먹기 (Q15): "eat" 몸짓인 잔치 손님 — 손에 든 빵을 입으로 올렸다 내렸다 (한 입에 몸을 조금 숙임) + 빵 그림 말풍선 (멀리서도 읽힘)
##   - 잔칫상 · 등 (Q15): 잔치 동안만 — 모닥불 앞쪽(카메라 쪽) 잔치 둘레 바로 밖에 긴 상(빵·열매·물병), 양옆에 막대 등 둘 (밤에도 제 빛깔 + 둥근 빛,
##     땅의 불빛 웅덩이는 Campfire.lamps로). 자리는 feast_spots — 건물·물·제단을 피한 빈자리, 없으면 차리지 않는다
##   - 첫 어른 잔치 (Q15): 그 젊은이(기록의 who)가 불 가까이(STAR_R)에 들어서면 기둥 옆으로 폴짝폴짝 가서 키를 잰다 (화면 자리만 — 시뮬레이션 자리는 그대로) —
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
const POST_FIRE_RINGS := [2.9, 3.3]   # 키 재는 기둥: 모닥불에서 이만큼 (걸상 1.85 바로 밖 — 칸)
const POST_FIRE_TURN_DEG := 20.0      # 기본 보기의 불 왼쪽에서 양옆으로 벌리는 각 걸음 (카메라 쪽부터)
const POST_FIRE_TURNS := 9            # 한 둘레에서 보는 자리 수 (왼쪽 반 바퀴)
const TABLE_RINGS := [3.6, 4.1]       # 잔칫상: 모닥불에서 이만큼 (잔치 둘레 바로 밖 — 칸)
const TABLE_TURN_DEG := 25.0          # 기본 보기의 불 앞쪽(카메라 쪽)에서 양옆으로 벌리는 각 걸음
const TABLE_TURNS := 9
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
const STAR_OFF := Vector2(-0.34, 0.05)     # 키를 재는 젊은이: 기둥에서 (화면 옆, 앞) — 눈금이 보이게 기둥 왼쪽에
const STAR_R := 7.5                   # 그 젊은이는 모닥불에서 이 안에 들어서면 기둥으로 (걸음이 느려 DANCE_R까지 기다리면 잔치의 반이 지난다)
const STAR_SPEED := 3.0               # 기둥 옆으로 폴짝폴짝 가는 빠르기 (칸/현실 초)
const STAR_HOP_BEAT := 9.0
const STAR_SNAP := 12.0               # 이보다 멀면 (빠른 흐름 뒤) 바로 제자리
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
var _halo_mat: ShaderMaterial         # 둥근 빛 (등보다 먼저 그림)


## 그림 말풍선 — 아이들 장면의 것(KidBubbles: 화면 화소로 일정한 크기)에 잔치 그림 셋을 더함
class PicBubbles extends KidBubbles:
	const LOAF := Color("e48a49")
	const LOAF_L := Color("f6bd6e")
	const SKIN := Color("f3c9a0")
	const RED := Color("e4704a")

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


## (Q15) 키 재는 기둥 자리: 모닥불 바로 곁 — 기본 보기에서 불의 왼쪽부터 (카메라 쪽 먼저) 양옆으로 벌려 가며 찾은 첫 빈자리 (난수 없음).
## keep = 이미 세워 둔 자리 (아직 쓸 수 있으면 그대로). 불 곁이 모두 막혔으면 고비를 넘을 때 적어 둔 자리, 그것도 막혔으면 시뮬레이션이 다시 찾은 자리.
## 읽기만 한다 — 적어 둔 자리(기록의 x·y)는 그대로 둔다
static func post_at(q: Village, keep := Vector2.INF) -> Vector2:
	var far := float(POST_FIRE_RINGS[POST_FIRE_RINGS.size() - 1]) + 0.05
	if keep != Vector2.INF and keep.distance_to(q.fire) <= far and Milestones.post_ok(q, keep):
		return keep
	var a0 := (-_right()).angle()
	for rr: float in POST_FIRE_RINGS:
		for i in POST_FIRE_TURNS:
			var side := -1.0 if i % 2 == 1 else 1.0
			var a := a0 + side * float((i + 1) >> 1) * deg_to_rad(POST_FIRE_TURN_DEG)
			var p := q.fire + Vector2(cos(a), sin(a)) * rr
			if Milestones.post_ok(q, p):
				return p
	var rec: Dictionary = (q.milestones.get("passed", {}) as Dictionary).get("grown", {})
	if rec.has("x"):
		var p := Vector2(float(rec["x"]), float(rec["y"]))
		if Milestones.post_ok(q, p):
			return p
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


## (Q15) 잔칫상과 등의 자리: {"table": 상 가운데 (없으면 INF), "lamps": [[자리, 옆(-1 왼쪽 · +1 오른쪽)] …]} (마을 데이터 좌표).
## 상 = 모닥불 앞쪽(기본 보기의 카메라 쪽) 잔치 둘레 바로 밖, 앞쪽부터 양옆으로 벌려 가며 찾은 첫 빈자리 (건물·물·무덤·제단·큰 줄기를 피하고 기둥과 떨어져).
## 등 = 상의 양 끝 (빈자리만). 상 자리가 없으면 모닥불 양옆에 등만. post = 키 재는 기둥 자리 (없으면 INF). 읽기만 한다
static func feast_spots(q: Village, post := Vector2.INF) -> Dictionary:
	var lamps: Array = []
	var out := {"table": Vector2.INF, "lamps": lamps}
	var right := _right()
	var a0 := _front().angle()
	for rr: float in TABLE_RINGS:
		for i in TABLE_TURNS:
			var side := 1.0 if i % 2 == 1 else -1.0
			var a := a0 + side * float((i + 1) >> 1) * deg_to_rad(TABLE_TURN_DEG)
			var p := q.fire + Vector2(cos(a), sin(a)) * rr
			if not Milestones.post_ok(q, p) or not Milestones.spot_free(q, p + right * TABLE_HALF) or not Milestones.spot_free(q, p - right * TABLE_HALF):
				continue
			if post != Vector2.INF and p.distance_to(post) < TABLE_POST_GAP:
				continue
			out["table"] = p
			for sg: float in [-1.0, 1.0]:
				var lp: Vector2 = p + right * sg * (TABLE_HALF + LAMP_GAP)
				if Milestones.spot_free(q, lp) and (post == Vector2.INF or lp.distance_to(post) > 0.6):
					lamps.append([lp, sg])
			return out
	for sg: float in [-1.0, 1.0]:
		var lp: Vector2 = q.fire + right * sg * LAMP_FIRE.x + _front() * LAMP_FIRE.y
		if Milestones.post_ok(q, lp) and (post == Vector2.INF or lp.distance_to(post) > 0.6):
			lamps.append([lp, sg])
	return out


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
	if on and _spots.is_empty():
		_spots = feast_spots(q, _post_keep)
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
			if p.id == id:                               # 그 젊은이는 불 가까이(STAR_R) 오면 바로 (제 자리까지 걸어가는 중이어도) 기둥으로 달려간다 — 잔치가 짧다
				if far <= STAR_R:
					who = id
			elif far <= DANCE_R and (p.anim == "eat" or p.anim == "play"):
				_guests.append(p.id)
		if who < 0:
			_guests.clear()
	if who >= 0 and _star >= 0 and _star != who:
		_release_star()
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
	if view.fast or (_eating.is_empty() and _clapping.is_empty() and _guests.is_empty()):
		return
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
	var step := STAR_SPEED * _step
	_step = 0.0
	var flat := Vector3(goal.x - _star_at.x, 0.0, goal.z - _star_at.z)
	var left := flat.length()
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
