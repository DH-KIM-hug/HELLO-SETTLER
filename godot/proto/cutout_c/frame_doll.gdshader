// 방식 C 주민 시험판 (docs/RESIDENTS_2D.md 7장, 2026-11-08 — 스파이크, 기본값은 그대로 컷아웃):
// 몸+옷 = 장면마다 그린 그림 한 장 (frames_atlas, 걸음·숨쉬기가 그림에 있음), 옷 색 = 물감 마스크 두 장 (frames_mask0/1 → Q22 ③-0 코드 텍스처, 아래 masks()),
// 머리·얼굴·모자 = 지금 컷아웃 라이브러리의 머리 조각 (doll_atlas)을 그 장면의 턱 자리(fdata)에 얹음 → 머리·모자 조합은 그대로.
// 한 사람 = 메시 하나 = 그리기 1번 (몸 사각형 + 손 겹 + 짐 그림 + 모든 머리·모자·소품 사각형, 고르지 않은 것은 점으로 접힘).
// v12 (2026-11-10): 나르는 짐은 몸 장면에 그려 넣지 않고 따로 그린 그림(group 5)을 그 장면의 짐 자리에 얹음 — 밀·밀가루·빵이 갈림.
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;          // 머리 조각 (컷아웃 라이브러리)
uniform sampler2D dye_mask : hint_default_black, filter_linear_mipmap, repeat_disable;   // 머리 조각 물감 마스크 (Q22 ④부터 4분의 1 크기 doll_mq.png — 아래 설명)
uniform sampler2D frames_atlas : filter_linear_mipmap, repeat_disable;   // 몸 장면들 + 짐 그림들 (v12)
// 물감 마스크 두 장 (m0 = 피부 · 옷 주색 · 둘째(크림) · 장식(띠), m1 = 다리(양말) · 신 · 짐을 받친 손 (앞쪽 보기의 나르기·안고 서기 — 짐 위에
// 다시 그릴 곳) · 먼 다리)을 Q22 ③-0 (2026-11-12)부터 작게 담음 (tools/cutout_c/pack_masks.py): 옛날엔 RGBA8 두 장을 밉맵째 = 47 MB.
//   fcode: 텍셀마다 한 바이트 (코드표의 줄) · flut: 코드 → (m0, m1) · fmq0/1: 두 마스크의 밉맵 2단 (4분의 1 크기) — 그 아래 단은 GPU가.
// 가까이(lod < 2)는 셰이더가 코드로 0단·1단을 직접 거르고 (0단 겹선형 · 1단 = 0단 2×2 평균의 겹선형, 둘을 lod로 섞음 — 삼선형과 같은 셈),
// 멀리(lod ≥ 2)는 fmq를 GPU가 거른다 → 옛 마스크와 같은 값 (코드표가 담지 못한 드문 텍셀만 조금 다름 — pack_masks.py 참고).
uniform sampler2D fcode : filter_nearest, repeat_disable;
uniform sampler2D flut : filter_nearest, repeat_disable;
uniform sampler2D fmq0 : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D fmq1 : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D fdata : filter_nearest, repeat_disable;               // 장면마다: [0] uv 사각형 (그리는 몫), [1] (턱 x, y, 시작 위상, 고개 기울기 rad) rig,
                                                                         // [2] 소품·짐 (기울기 rad, 손 x, y, 배율 — 0 = 없음), [3] (쥐는 자리: 소품 키의 몇 배, 짧은 연장의 기울기, 눕힘 rad, 눈 감음 1 — v13),
                                                                         // [4] 그리는 몫 (칸의 0~1 — Q22 ③-1, 2026-11-12)
// 동작 = frames.json의 clips 차례 (걷기·나르기·서기·안고 서기 + 2026-11-10 앉기·먹기·올려다보기·무릎·괭이질·줍기) — frame_lib.material이 채움
uniform int clip_off[16];        // 동작의 첫 장면 번호
uniform int clip_n[16];          // 동작의 장면 수 (보기마다)
uniform int load_clip[16];       // 그 동작의 팔에 얹는 그림: 0 없음 · 1 짐 (나르기·안고 서기) · 2 아기 (안고 걷기·안고 서기 — v13)
uniform float head_r = 143.0;    // 머리 자리 표시 원의 반지름 (rig) — 고개 기울기는 그 가운데(턱 위 head_r)를 중심으로
uniform vec4 body_rect = vec4(-400.0, -10.0, 400.0, 1020.0);   // 몸 장면 사각형 (rig, 발바닥 가운데 = 0)
uniform vec4 head_k = vec4(1.3);                  // 보기마다 머리 배율 (자리 표시 원 지름에 맞춤)
uniform vec4 body_layer = vec4(5.0, 7.0, 6.0, 4.0);   // 보기마다 몸의 겹 (컷아웃 라이브러리의 몸 겹 — 머리꼬리·매듭 앞뒤가 그대로)
uniform vec4 sack_layer = vec4(12.0, 12.0, -1.0, -1.0);   // 짐 그림의 겹: 머리 위 (그 위 +0.5에 짐을 받친 손을 다시 그림) · -1 = 몸·머리 뒤 (뒤쪽 보기)
uniform vec2 lie_at = vec2(400.0, 190.0);         // 누운 장면 (자기): 눕힌 뒤 옮김 (rig — 컷아웃 인형의 SLEEP_SHIFT · SLEEP_LIFT와 같음)
uniform float breath = 0.03;                      // 누운 장면의 숨쉬기 (몸통 두께가 이만큼 부풀었다 꺼짐)
uniform vec3 palette[64];
uniform vec3 base_col[64];       // 머리 조각 묶음의 그린 바탕색 (컷아웃과 같음)
uniform vec3 fbase[8];           // 몸 장면의 그린 바탕색 (물감 슬롯 0~7)
uniform vec3 bbase[2];           // 아기 그림의 그린 바탕색 (피부 · 머리카락 — v13)
uniform vec2 head_top[32];
uniform float fig = 920.0;
uniform float layer_eps = 0.004;
uniform vec3 lit_tint : source_color = vec3(1.0);
uniform vec3 shade_tint : source_color = vec3(0.55, 0.76, 0.87);
uniform float self_lit = 0.5;
uniform float alpha_cut = 0.5;
uniform float ground_pull = 1.3;   // 뿌리 아래(앞으로 디딘 발)를 땅 위로 당기는 배율 (1 = 딱 땅 높이, 그보다 크면 땅 위로 뜸)
uniform float foot_lock = 0.5;     // 발 붙이기 세기 (0 = 끔, 1 = 다 붙임): 한 장면이 떠 있는 동안 인형을 제자리에 세워 디딘 발이 땅에서 밀리지 않게 (아래 lockv).
                                   // 2026-11-10 눈으로 맞춤: 1이면 발은 딱 붙지만 몸이 장면마다 톡톡 나아감 (ppu 44에서 몸 흔들림 sd 1.7~1.9px), 0이면 몸은 미끄러지듯 가고 발이 밀림 —
                                   // 0.5가 둘을 반씩 (몸 sd 1.0px, 디딘 발 ±1px; ppu 20에서는 둘 다 1px 이하)
uniform float far_k = 0.68;       // 비스듬한 보기의 먼 다리 (frames_mask1.a)를 물감을 입힌 뒤 이만큼 어둡게 — 어떤 양말 색이든 두 다리가 갈림

instance uniform vec4 sel = vec4(-1.0, 0.0, -1.0, -1.0);   // 짐 그림 L(-1 없음), 머리 묶음 T, 모자 묶음 U(-1 없음), 소품 P(-1 없음 — 컷아웃 PROPS 번호)
instance uniform vec4 prop = vec4(0.0);                    // x = 소품의 키 (rig — 쥐는 자리 계산), y = 더 돌림 (rad: 머리가 위에 그려진 낫·망치 = PI), z = 1: 짧은 연장 (fdata[3].y 기울기)
instance uniform vec4 st = vec4(0.0, 1.0, 0.0, 0.0);       // 보기 0~3, 뒤집기 ±1, 동작(0 걷기 1 나르기 2 서기 3 안고 서기), 시작 위상
instance uniform vec4 dyes0 = vec4(0.0, 1.0, 2.0, 3.0);
instance uniform vec4 dyes1 = vec4(4.0, 5.0, 6.0, 7.0);
instance uniform vec4 misc = vec4(0.88, 1.0, 1.0, 0.0);    // 화면 키(세계), 폭 배율(음수 = 뒤집힘), 동작 빠르기(주기/초), 기울기(rad, 발끝 중심) — 컷아웃 인형과 같음
instance uniform vec4 baby = vec4(-1.0);                   // 품에 안긴 아기의 물감 (x 피부 · y 머리카락, -1 = 그린 색 그대로) — 아기 그림의 피부·머리카락만 물들임 (v13)
instance uniform vec4 look2 = vec4(0.0);                   // (Q22 ④) 머리결 변형 · 수염 · 주근깨 · 표시 코드 — 컷아웃 인형(cut_doll)과 같음
// (Q22 ④) 머리 자료 텍스처 (RGBAF 128 × 3, cut_lib.head_data): 줄 0 = 마스크 코드표 (코드 → 마스크 RGB), 줄 1 = 얼굴 자리 head_eye
// (머리 묶음 × 4 + 보기: 두 눈 x, y, x, y), 줄 2 = head_mark (눈 반지름, 머리선 x, y, 얼굴 반폭) — 머리 틀 rig, 턱 = 원점.
// (작은 표를 한 장에 — 방식 C 재질의 텍스처 · uniform을 늘리지 않게.)
uniform sampler2D head_data : filter_nearest, repeat_disable;

instance uniform vec4 lockv = vec4(0.0);                   // xy = 걸음 한 주기에 땅에서 가는 길 (세계 x, z — frame_doll.gd가 걷는 쪽 × 땅 빠르기 ÷ 걸음 빠르기)

varying flat vec4 v_dye;     // 머리 조각: 물감 슬롯 xyz, w = 묶음 · 몸: w = 50 (몸 · 감은 눈) / 60 (손 겹) / 70 (짐·아기 그림)
varying flat float v_show;
varying vec2 v_hp;           // (Q22 ④) 머리 조각의 머리 틀 rig 자리 (얼굴 표시용)
varying flat float v_hi;     // 머리 묶음 × 4 + 보기 (머리 그림 조각만, 그 밖 -1)
varying flat vec4 v_win;     // 감은 눈: 눈꺼풀 그림의 아틀라스 창 (u0, v0, u1, v1) — 이 밖은 그리지 않음. 그 밖의 조각은 (-1, -1, 2, 2)

void vertex() {
	int group = int(CUSTOM0.w + 0.5);
	float set_i = CUSTOM1.x;
	int view = int(CUSTOM1.y + 0.5);
	int cur_view = int(st.x + 0.5);
	int clip = int(st.z + 0.5);
	int n = clip_n[clip];
	// 장면마다 시작 위상 (fdata[1].z) — 디딘 발이 그림에서 고르지 않게 움직이는 만큼 장면 길이를 다르게 (2026-11-09 라이브 점검)
	int f0 = clip_off[clip] + cur_view * n;
	float u = fract(TIME * misc.z + st.w);
	int fi = f0;
	for (int k = 1; k < n; k++) {
		if (texelFetch(fdata, ivec2(f0 + k, 1), 0).z <= u) {
			fi = f0 + k;
		}
	}
	vec4 fd = texelFetch(fdata, ivec2(fi, 1), 0);
	// 발 붙이기 (2026-11-10 "디딘 장화가 한 장면 안에서 2.8px 밀림"): 그림은 장면마다 뚝뚝 바뀌는데 몸은 매끄럽게 나아가서, 한 장면이
	// 떠 있는 동안 디딘 발이 몸과 함께 밀렸다 (8장면 톱니). 그리는 자리만 장면의 가운데 때 자리에 세워 둔다: 장면이 바뀌는 순간
	// 한 장면 몫만큼 나아가고 (그림의 디딘 발은 그만큼 뒤로 가 있으므로 땅에서는 제자리), 시뮬 자리(노드)는 그대로. 평균 자리는 같다.
	float t_b = fi + 1 < f0 + n ? texelFetch(fdata, ivec2(fi + 1, 1), 0).z : 1.0;
	float f_len = max(t_b - fd.z, 0.0001);
	vec2 hold = lockv.xy * (f_len * (clamp((u - fd.z) / f_len, 0.0, 1.0) - 0.5) * foot_lock);
	bool show;
	bool arms = load_clip[clip] > 0;                                       // 팔에 무언가를 얹는 동작
	bool loaded = sel.x >= 0.0 && arms;                                    // 나르기·안고 서기 + 짐 · 안고 걷기·안고 서기 + 아기
	vec4 fx = texelFetch(fdata, ivec2(fi, 3), 0);
	if (group == 0) {
		show = true;
	} else if (group == 4) {
		show = loaded && sack_layer[cur_view] >= 0.0;                        // 짐이 머리 위에 그려지는 보기만: 짐을 받친 손을 그 위에
	} else if (group == 5) {
		show = loaded && abs(set_i - sel.x) < 0.5 && (CUSTOM1.y < -0.5 || view == cur_view);    // 아기 그림은 보기마다 따로 (v13)
	} else if (group == 3 && arms) {
		show = false;                                                        // 나르기·안고 서기의 짐은 group 5
	} else if (group == 3) {
		// 소품 (컷아웃 인형과 같은 그림·같은 번호): 그 장면에 쥘 자리가 있을 때만. 빵·나뭇가지·바구니는 비스듬한 그림이 따로 (+3)
		float pid = sel.w;
		if ((cur_view == 1 || cur_view == 2) && pid >= 0.0 && pid < 2.5) {
			pid += 3.0;
		}
		show = pid >= 0.0 && abs(set_i - pid) < 0.5 && texelFetch(fdata, ivec2(fi, 2), 0).w != 0.0;
	} else if (group == 6) {
		// 감은 눈 (v13): 자는 장면(fdata[3].w)에서만, 그 머리 묶음의 앞 얼굴 위에 — 머리 조각과 같은 자리·배율·기울기.
		// 사각형은 머리 조각과 똑같은 네 귀퉁이 (frame_lib.mesh): 누운 머리 조각은 한쪽 끝이 뿌리 줄 아래로 조금 내려가 아래의
		// '땅 위로 당기기'로 깊이가 기울어진다 — 작은 사각형을 따로 얹으면 그 기울기가 없어 머리 뒤에 숨었다 (눈이 뜬 채로 보임).
		// 같은 귀퉁이면 깊이가 어디서나 머리 조각 + 반 겹. 눈꺼풀 그림 밖(v_win)은 버린다.
		show = abs(set_i - sel.y) < 0.5 && view == cur_view && fx.w > 0.5;
	} else if (group == 1) {
		// (Q22 ④) 머리 묶음의 조각: 머리 그림은 이 사람의 머리결 변형 하나만 (CUSTOM2.w), 머리꼬리·매듭(-1)은 늘
		show = abs(set_i - sel.y) < 0.5 && view == cur_view && (CUSTOM2.w < -0.5 || abs(CUSTOM2.w - look2.x) < 0.5);
	} else if (group == 7) {
		show = look2.y > 0.5 && abs(set_i - sel.y) < 0.5 && view == cur_view && abs(CUSTOM2.w - look2.y) < 0.5;     // (Q22 ④) 수염
	} else {
		show = sel.z >= 0.0 && abs(set_i - sel.z) < 0.5 && view == cur_view;
	}
	v_show = show ? 1.0 : 0.0;
	v_win = group == 6 ? vec4(CUSTOM0.xy, CUSTOM1.zw) : vec4(-1.0, -1.0, 2.0, 2.0);
	v_hp = VERTEX.xy;
	v_hi = (group == 1 && CUSTOM2.w > -0.5) ? float(int(set_i + 0.5) * 4 + view) : -1.0;
	v_dye = vec4(CUSTOM1.zw, CUSTOM2.x, (group == 0 || group == 6) ? 50.0 : (group == 4 ? 60.0 : (group == 5 ? 70.0 : (group == 3 ? 0.0 : set_i))));
	if (!show) {
		VERTEX = vec3(0.0);
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		vec2 p;
		float layer;
		if (group == 0 || group == 4) {
			// 귀퉁이 (0~1) → 그 장면이 쓰는 몫 (fdata[4] — Q22 ③-1: 아틀라스에는 칸의 쓰는 몫만 빈틈없이 담김, 그 몫이 아틀라스의 r)
			vec4 sb = texelFetch(fdata, ivec2(fi, 4), 0);
			vec2 c = clamp(UV, sb.xy, sb.zw);
			p = vec2(mix(body_rect.x, body_rect.z, c.x), mix(body_rect.w, body_rect.y, c.y));
			vec4 r = texelFetch(fdata, ivec2(fi, 0), 0);
			UV = mix(r.xy, r.zw, (c - sb.xy) / max(sb.zw - sb.xy, vec2(1e-6)));
			layer = group == 0 ? body_layer[cur_view] : sack_layer[cur_view] + 0.5;
		} else if (group == 5) {
			// 짐 그림: 밑변 가운데가 원점 → 기울임·배율 → 그 장면의 짐 자리 (어깨 위 손 옆). 앞쪽 보기 = 머리 위, 뒤쪽 보기 = 몸·머리 뒤
			vec4 pr = texelFetch(fdata, ivec2(fi, 2), 0);
			float tc = cos(pr.x), ts = sin(pr.x);
			p = vec2(tc * VERTEX.x - ts * VERTEX.y, ts * VERTEX.x + tc * VERTEX.y) * pr.w + pr.yz;
			layer = sack_layer[cur_view] >= 0.0 ? sack_layer[cur_view] : -0.5;
		} else if (group == 3) {
			// 소품: 원점 둘레 그림 → 돌림·배율 → 손 자리. 자루를 쥐는 연장(비스듬한 보기)은 손에서 날 쪽으로 (쥐는 자리 × 소품 키)만큼 밀어
			// 자루 위쪽이 손에 오게 (컷아웃 인형의 괭이와 같은 식). 겹: 앞쪽 보기 = 몸 바로 앞 (머리 뒤), 뒤쪽 보기 = 몸 뒤.
			// 짧은 연장 (낫·망치 — v12): 휘두름 꼭대기에서 괭이처럼 머리 뒤로 넘기면 머리에 가려 안 보였다 → 그 장면만 따로 정한 기울기 (위·앞쪽)
			vec4 pr = texelFetch(fdata, ivec2(fi, 2), 0);
			float ang = prop.z > 0.5 ? fx.y : pr.x;
			float th = ang + prop.y;
			float tc = cos(th), ts = sin(th);
			// 배율이 음수 (v14 낫질): 그림을 좌우로 뒤집어 (컷아웃 인형의 낫질과 같음 — 낫의 휜 날이 아래·몸 쪽으로) 돌린다
			float vx = pr.w < 0.0 ? -VERTEX.x : VERTEX.x;
			p = vec2(tc * vx - ts * VERTEX.y, ts * vx + tc * VERTEX.y) * abs(pr.w) + pr.yz;
			p += fx.x * prop.x * vec2(sin(ang), -cos(ang));
			layer = cur_view < 2 ? body_layer[cur_view] + 0.5 : -0.5;
		} else {
			p = VERTEX.xy;
			if (group == 2) {
				p += head_top[int(sel.y + 0.5) * 4 + cur_view];
			}
			p *= head_k[cur_view];
			if (fd.w != 0.0) {                         // 고개 기울기 (숙여 줍기·절·한 입): 머리 가운데를 중심으로 — 그린 자리 표시 원과 같은 자리
				float hc = cos(fd.w), hs = sin(fd.w);
				vec2 q = p - vec2(0.0, head_r);
				p = vec2(hc * q.x - hs * q.y, hs * q.x + hc * q.y) + vec2(0.0, head_r);
			}
			p += fd.xy;
			layer = VERTEX.z;
		}
		if (fx.z != 0.0) {                             // 누운 장면 (자기 — v12): 선 채로 그린 그림을 통째로 눕힘 (머리 = 왼쪽, 뒤집기로 오른쪽 — 컷아웃 인형과 같음) + 숨쉬기
			p.x *= 1.0 - breath * sin(u * 6.2831853);
			float lc = cos(fx.z), ls = sin(fx.z);
			p = vec2(lc * p.x - ls * p.y, ls * p.x + lc * p.y) + lie_at;
		}
		p.x *= st.y * misc.y;
		if (misc.w != 0.0) {                           // [톡 반응] 발끝을 중심으로 인형 전체를 기울임 (view/tap_react.gd — 화면만, 컷아웃 인형과 같은 식)
			float rc = cos(misc.w), rs = sin(misc.w);
			p = vec2(rc * p.x - rs * p.y, rs * p.x + rc * p.y);
		}
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		right = normalize(vec3(right.x, 0.0, right.z));
		vec3 back = INV_VIEW_MATRIX[2].xyz;
		float cu = max(INV_VIEW_MATRIX[1].y, 0.3);
		float k = misc.x / fig;
		vec3 org = MODEL_MATRIX[3].xyz - vec3(hold.x, 0.0, hold.y);
		vec3 w = org + right * (p.x * k) + vec3(0.0, p.y * k / cu, 0.0) + back * (layer * layer_eps);
		// 뿌리(땅 점)보다 아래에 그려진 발 (2026-11-10): 비스듬한 보기에서 앞으로 디딘 발은 화면에서 뿌리보다 아래 = 땅 위에서
		// 카메라 쪽에 있다. 세운 판에서는 그 부분이 땅속(y < 0)이라 땅에 가려 장화 밑이 반듯하게 잘렸다 → 보는 줄기를 따라
		// 땅 높이 조금 위까지 당긴다: 화면 자리는 그대로, 깊이만 땅 위. (몸 사각형은 뿌리 줄에서 둘로 나뉘어 있다 — frame_lib.mesh)
		if (p.y < 0.0) {
			vec3 ray = PROJECTION_MATRIX[3][3] > 0.5 ? back : normalize(INV_VIEW_MATRIX[3].xyz - w);
			w += ray * ((-p.y) * k / cu * ground_pull / max(ray.y, 0.2));
		}
		VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
		NORMAL = normalize((VIEW_MATRIX * vec4(back, 0.0)).xyz);
		POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	}
}

// ── (Q22 ④, 2026-11-12) 머리 물감 마스크 (코드 + 코드표 + 4분의 1 마스크) · 얼굴 표시 (주근깨 · 흰 앞머리 · 눈송이 무늬) ──
// 머리 조각의 물감 마스크는 묶음 a의 doll_mask.png (RGBA 2048² + 밉맵 21 MB)를 코드 한 바이트 + 코드표 + 4분의 1 마스크로 (build_atlas.pack_mask):
// lod < 2 는 코드에서 직접 겹선형·1단 상자를 만들어 섞고 (방식 C 몸 마스크 masks()와 같은 식), lod >= 2 는 4분의 1 마스크의 밉맵 — 옛 마스크와 같은 값.
uniform sampler2D dye_code : filter_nearest, repeat_disable;
// 얼굴 자리는 head_data 줄 1 · 2 (위). 뒤쪽 보기는 눈 반지름 0 (얼굴 없음 — 머리선 자리 = 정수리 근처).
uniform vec3 freckle_mul = vec3(0.80, 0.66, 0.56);   // 주근깨 점: 피부를 이만큼 곱함 (따뜻한 갈색 점 — Genetics.FRECKLE 쪽)
uniform vec3 snow_skin : source_color = vec3(0.96, 0.90, 0.82);   // 눈송이 무늬: 따뜻한 우유빛 (피부와 65% 섞음 — 하얗게 비치지 않게)
uniform vec3 snow_hair : source_color = vec3(0.965, 0.953, 0.925);   // 흰 머리 한 줌 (Genetics.PIEBALD_HAIR f6f3ec)

vec3 head_mask(vec2 uv, float lod) {
	if (lod >= 2.0) {
		return textureLod(dye_mask, uv, lod - 2.0).rgb;
	}
	ivec2 n0 = textureSize(dye_code, 0);
	ivec2 n1 = n0 / 2;
	vec2 q0 = uv * vec2(n0) - 0.5;
	vec2 q1 = uv * vec2(n1) - 0.5;
	ivec2 i0 = ivec2(floor(q0));
	ivec2 j0 = ivec2(floor(q1));
	vec2 f = fract(q0);
	vec2 g = fract(q1);
	float t1 = clamp(lod, 0.0, 1.0);
	float t0 = 1.0 - t1;
	// (Q22 ⑤ Y, 2026-11-12) 코드를 먼저 모두 읽고, 무게가 있는 코드가 모두 같으면 (머리 · 얼굴 안쪽 — 대부분) 코드표를 한 번만 읽음 —
	// 값은 옛 셈과 똑같음 (무게 합 = 1). 테두리만 옛날처럼 코드마다 코드표를 읽음.
	// (가볍게 하려고 0단 겹선형만 쓰는 몸 마스크 식을 머리에 써 보았더니 머리선 · 눈가에 흰 점이 생겨 쓰지 않음 — 머리는 정확한 1단이 필요)
	int cs[16];
	float ws[16];
	int first = -1;
	bool same = true;
	for (int y = 0; y < 4; y++) {
		int py = clamp(j0.y + y / 2, 0, n1.y - 1);
		int cy = py * 2 + (y & 1);
		float wy1 = (y < 2 ? 1.0 - g.y : g.y) * 0.5;
		float wy0 = (cy == clamp(i0.y, 0, n0.y - 1) ? 1.0 - f.y : 0.0) + (cy == clamp(i0.y + 1, 0, n0.y - 1) ? f.y : 0.0);
		for (int x = 0; x < 4; x++) {
			int px = clamp(j0.x + x / 2, 0, n1.x - 1);
			int cx = px * 2 + (x & 1);
			float wx1 = (x < 2 ? 1.0 - g.x : g.x) * 0.5;
			float wx0 = (cx == clamp(i0.x, 0, n0.x - 1) ? 1.0 - f.x : 0.0) + (cx == clamp(i0.x + 1, 0, n0.x - 1) ? f.x : 0.0);
			float w = t1 * wx1 * wy1 + t0 * wx0 * wy0;
			int k = y * 4 + x;
			ws[k] = w;
			cs[k] = -1;
			if (w > 0.0) {
				int c = int(texelFetch(dye_code, ivec2(cx, cy), 0).r * 255.0 + 0.5);
				cs[k] = c;
				if (first < 0) {
					first = c;
				} else if (c != first) {
					same = false;
				}
			}
		}
	}
	if (same) {
		return first < 0 ? vec3(0.0) : texelFetch(head_data, ivec2(first, 0), 0).rgb;
	}
	vec3 m = vec3(0.0);
	for (int k = 0; k < 16; k++) {
		if (cs[k] >= 0) {
			m += ws[k] * texelFetch(head_data, ivec2(cs[k], 0), 0).rgb;
		}
	}
	return m;
}

float mk_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// 부드러운 덩이 (중심 c, 반지름 r — 가장자리가 조금 물결지고 넓게 번짐: 우유빛 무늬). px = 화면 한 화소의 크기 (rig)
float mk_blob(vec2 p, vec2 c, vec2 r, float seed, float px) {
	vec2 d = (p - c) / r;
	float a = atan(d.y, d.x);
	float wob = 1.0 + 0.1 * sin(a * 3.0 + seed * 6.28) + 0.05 * sin(a * 5.0 + seed * 11.0);
	float k = length(d) - wob;
	return 1.0 - smoothstep(-0.45 - px / r.x, 0.15 + px / r.x, k);
}

// 머리 한 줌 (흰 앞머리 · 눈송이의 흰 머리): a(가르마 · 이마 머리선)에서 c를 거쳐 b(관자놀이 쪽)로 흐르는 곡선 다발,
// 너비 w0 → w1로 가늘어짐. 머리 물감 칸에만 입히고 (선 · 피부는 그대로) 그림의 머리 결 명암을 그대로 두므로 머리카락 선을 따라 흰 다발로 읽힘.
float mk_strand(vec2 p, vec2 a, vec2 c, vec2 b, float w0, float w1, float px) {
	float best = 1e9;
	float bt = 0.0;
	vec2 prev = a;
	for (int i = 1; i <= 10; i++) {
		float t = float(i) / 10.0;
		vec2 q = mix(mix(a, c, t), mix(c, b, t), t);
		vec2 ab = q - prev;
		float h = clamp(dot(p - prev, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
		float d = length(p - prev - ab * h);
		if (d < best) {
			best = d;
			bt = (float(i) - 1.0 + h) / 10.0;
		}
		prev = q;
	}
	float hw = mix(w0, w1, bt) * (1.0 - 0.6 * smoothstep(0.85, 1.0, bt));
	return 1.0 - smoothstep(hw - px - 0.12 * w0, hw + px, best);
}

// 얼굴 표시의 무게: x = 주근깨 (피부를 freckle_mul 쪽으로), y = 눈송이 우유빛 피부, z = 흰 머리 (흰 앞머리 · 눈송이의 흰 머리 한 줌).
// hp = 머리 틀 rig 자리, e · hm = 그 머리의 얼굴 자리 (head_data), px = 화면 한 화소의 rig 크기 (버리기 전에 잰 값),
// k = (머리결 변형, 수염, 주근깨 진하기, 표시 코드: 흰 앞머리 1 + 2 × 무늬(0~6) + 16 × 자리(0~7))
vec3 mk_marks(vec2 hp, vec4 e, vec4 hm, vec4 k, float px) {
	int code = int(k.w + 0.5);
	bool fore = (code & 1) == 1;
	int sp = (code >> 1) & 7;
	int pos = (code >> 4) & 7;
	bool face = hm.x > 0.5;
	float er = max(hm.x, 9.0);
	vec2 mid = 0.5 * (e.xy + e.zw);
	vec3 w = vec3(0.0);
	if (k.z > 0.0 && face) {
		// 볼 둘 + 콧등에 흩뿌린 점 (격자마다 흔들린 점 하나, 있을 확률 60%). 점이 화소보다 작아지면 평균 덮임으로 (깜빡이지 않게)
		float zone = 0.0;
		for (int i = 0; i < 2; i++) {
			vec2 ec = i == 0 ? e.xy : e.zw;
			zone = max(zone, 1.0 - smoothstep(0.6, 1.0, length((hp - (ec + vec2(0.0, -2.3 * er))) / vec2(2.3 * er, 1.35 * er))));
		}
		zone = max(zone, 1.0 - smoothstep(0.5, 1.0, length((hp - (mid + vec2(0.0, -1.9 * er))) / vec2(1.6 * er, 0.8 * er))));
		float cell = 1.05 * er;
		vec2 g = hp / cell;
		vec2 gi = floor(g);
		float best = 9.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec2 c = gi + vec2(float(x), float(y));
				float h = mk_hash(c);
				if (h < 0.6) {
					vec2 jit = vec2(mk_hash(c + 7.1), mk_hash(c + 3.3));
					best = min(best, length(g - c - jit));
				}
			}
		}
		float r = 0.24;
		float fw = px / cell;
		float sharp = 1.0 - smoothstep(r - fw, r + fw, best);
		float dotc = mix(sharp, 0.6 * 3.14159 * r * r, clamp(fw / r - 0.5, 0.0, 1.0));
		w.x = zone * (0.25 + 0.75 * dotc) * k.z;
	}
	float side = (pos & 1) == 1 ? 1.0 : -1.0;       // 무늬가 앉는 쪽 (화면 왼쪽 눈 · 오른쪽 눈)
	if (sp > 0 && face) {
		// 눈송이 (2026-11-12 리뷰: "피부병처럼 보임" → 적게 · 작게 · 무른 가장자리 · 눈가 / 관자놀이에만, 눈 · 입은 피함, 따뜻한 우유빛 65%)
		float sh = 0.3 * float((pos >> 1) & 3) - 0.45;   // 자리 흔들기 (같은 무늬도 사람마다 조금 다른 자리)
		vec2 ec = side < 0.0 ? e.xy : e.zw;
		vec2 o = vec2(side, 1.0);
		float seed = float(code) * 0.137;
		float s = 0.0;
		if (sp == 1) {          // 관자놀이에 하나
			s = mk_blob(hp, ec + o * vec2(2.3, 0.5 + sh) * er, vec2(1.1, 1.4) * er, seed, px);
		} else if (sp == 2) {   // 눈꼬리 아래 바깥 볼에 하나
			s = mk_blob(hp, ec + o * vec2(1.7, -2.1 + sh * 0.5) * er, vec2(1.2, 0.95) * er, seed, px);
		} else if (sp == 3) {   // 눈썹 위 이마에 가로로 하나
			s = mk_blob(hp, ec + o * vec2(0.7 + sh, 2.4) * er, vec2(1.3, 0.75) * er, seed, px);
		} else if (sp == 4) {   // 관자놀이 + 눈썹 끝 작은 점
			s = max(mk_blob(hp, ec + o * vec2(2.2, 0.1 + sh) * er, vec2(0.9, 1.2) * er, seed, px),
				mk_blob(hp, ec + o * vec2(1.3, 2.4) * er, vec2(0.5) * er, seed + 1.0, px));
		} else if (sp == 5) {   // 눈가 바깥 작은 둘
			s = max(mk_blob(hp, ec + o * vec2(2.0, -1.5 + sh * 0.5) * er, vec2(0.7) * er, seed, px),
				mk_blob(hp, ec + o * vec2(2.5, 0.9) * er, vec2(0.6) * er, seed + 1.0, px));
		} else {                // 눈가를 두르는 아주 작은 점 셋
			s = max(max(mk_blob(hp, ec + o * vec2(2.1, 1.3) * er, vec2(0.5) * er, seed, px),
				mk_blob(hp, ec + o * vec2(2.45, -0.2 + sh * 0.4) * er, vec2(0.55) * er, seed + 1.0, px)),
				mk_blob(hp, ec + o * vec2(1.8, -1.7) * er, vec2(0.5) * er, seed + 2.0, px));
		}
		// 눈 · 입은 비킴
		float eye_d = min(length(hp - e.xy), length(hp - e.zw));
		s *= smoothstep(1.5 * er, 2.1 * er, eye_d);
		s *= smoothstep(0.8, 1.15, length((hp - (mid + vec2(0.0, -4.0 * er))) / vec2(2.8 * er, 1.5 * er)));
		w.y = s;
	}
	if (face && (fore || sp > 0)) {
		// 흰 머리 한 줌: 이마 머리선 (가르마) 바로 위에서 무늬 쪽 (흰 앞머리는 화면 왼쪽) 관자놀이로 흘러내리는 다발
		float sd = sp > 0 ? side : -1.0;
		vec2 a = vec2(hm.y + sd * 0.1 * hm.w, hm.z + 0.35 * er);
		vec2 c = vec2(hm.y + sd * 0.6 * hm.w, hm.z + 0.55 * er);
		vec2 b = vec2(hm.y + sd * 0.98 * hm.w, hm.z - 2.4 * er);
		w.z = mk_strand(hp, a, c, b, 0.8 * er, 0.45 * er, px);
	}
	return w;
}

// 표시 입히기: o = 물감을 입힌 색, c = 그린 색, m = 물감 마스크 (x 피부 · y 머리), bs · bh = 그린 피부 · 머리 바탕색
vec3 mk_apply(vec3 o, vec3 c, vec3 m, vec3 w, vec3 bs, vec3 bh) {
	o *= mix(vec3(1.0), freckle_mul, clamp(w.x, 0.0, 1.0) * m.r);
	vec3 ws = snow_skin * clamp(c / max(bs, vec3(0.04)), vec3(0.0), vec3(1.1));     // 그늘·볼은 남김 (피부 물감과 같은 식)
	o = mix(o, ws, clamp(w.y, 0.0, 1.0) * 0.65 * m.r);
	float lh = dot(c, vec3(0.299, 0.587, 0.114)) / max(dot(bh, vec3(0.299, 0.587, 0.114)), 0.04);
	o = mix(o, snow_hair * clamp(lh, 0.0, 1.05), clamp(w.z, 0.0, 1.0) * 0.92 * m.g);
	return o;
}


vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float dye_index(int s) {
	if (s < 4) {
		return dyes0[s];
	}
	return dyes1[s - 4];
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// 컷아웃과 같은 물감 규칙: 피부 = 채널별 비율, 그 밖 = 밝기 옮기기
vec3 dye_with(vec3 c, int s, vec3 b) {
	if (dye_index(s) < -0.5) {
		return c;
	}
	vec3 d = palette[int(dye_index(s) + 0.5)];
	if (s == 0) {
		return c * clamp(d / max(b, vec3(0.04)), vec3(0.0), vec3(5.0));
	}
	return d * (luma(c) / max(luma(b), 0.04));
}

vec3 dyed(vec3 c, float slot, float set_i) {
	if (slot < -0.5) {
		return c;
	}
	int s = int(slot + 0.5);
	return dye_with(c, s, base_col[int(set_i + 0.5) * 8 + s]);
}

// 물감 마스크 두 장 (옛 fmask0 · fmask1을 밉맵째 삼선형으로 거른 값)을 uv · lod에서
// (Q22 ⑤ Y, 2026-11-12) 가까이 경로를 가볍게: 옛날엔 lod < 2에서 0단 4×4 코드 + 코드표 2줄 = 48번 읽어 0단·1단을 정확히 만들었는데
// (기본 확대 20부터 70 언저리까지 늘 이 길 — 화면 가득 320명이면 GPU +1 ms), 이제는 0단 겹선형 하나 (코드 4 + 코드표 — 넷이 같은
// 코드면 2, 아니면 8)만 만들고 lod 1~2에서 4분의 1 마스크(2단, GPU 거름)와 섞는다. 1단 상자 대신 0단이라 테두리가 조금 더 또렷할 뿐,
// 흐린 마스크가 옆 칸 물감을 끌어오지는 않음 (4분의 1 마스크는 lod 1 위에서만 섞여 들어옴 — 옛날과 같은 단).
void masks(vec2 uv, float lod, out vec4 m0, out vec4 m1) {
	if (lod >= 2.0) {
		m0 = textureLod(fmq0, uv, lod - 2.0);
		m1 = textureLod(fmq1, uv, lod - 2.0);
		return;
	}
	ivec2 n0 = textureSize(fcode, 0);
	vec2 q0 = uv * vec2(n0) - 0.5;          // 0단 텍셀 자리
	ivec2 i0 = ivec2(floor(q0));
	vec2 f = fract(q0);
	ivec2 a = clamp(i0, ivec2(0), n0 - 1);
	ivec2 b = clamp(i0 + 1, ivec2(0), n0 - 1);
	int c00 = int(texelFetch(fcode, ivec2(a.x, a.y), 0).r * 255.0 + 0.5);
	int c10 = int(texelFetch(fcode, ivec2(b.x, a.y), 0).r * 255.0 + 0.5);
	int c01 = int(texelFetch(fcode, ivec2(a.x, b.y), 0).r * 255.0 + 0.5);
	int c11 = int(texelFetch(fcode, ivec2(b.x, b.y), 0).r * 255.0 + 0.5);
	m0 = texelFetch(flut, ivec2(c00, 0), 0);
	m1 = texelFetch(flut, ivec2(c00, 1), 0);
	if (c10 != c00 || c01 != c00 || c11 != c00) {     // 테두리만 넷을 겹선형으로 (안쪽은 한 코드 = 코드표 두 번)
		vec4 w = vec4((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y);
		m0 = w.x * m0 + w.y * texelFetch(flut, ivec2(c10, 0), 0) + w.z * texelFetch(flut, ivec2(c01, 0), 0) + w.w * texelFetch(flut, ivec2(c11, 0), 0);
		m1 = w.x * m1 + w.y * texelFetch(flut, ivec2(c10, 1), 0) + w.z * texelFetch(flut, ivec2(c01, 1), 0) + w.w * texelFetch(flut, ivec2(c11, 1), 0);
	}
	if (lod > 1.0) {                        // 0단 겹선형 ↔ 2단 (fmq의 0단)
		float t2 = lod - 1.0;
		m0 = mix(m0, textureLod(fmq0, uv, 0.0), t2);
		m1 = mix(m1, textureLod(fmq1, uv, 0.0), t2);
	}
}

void fragment() {
	// 마스크의 lod (텍스처 미분은 버리기 전에 — 몸 그림과 같은 크기의 코드 텍스처 기준, GPU가 고르는 밉맵 단과 같은 식)
	vec2 tdx = dFdx(UV) * vec2(textureSize(fcode, 0));
	vec2 tdy = dFdy(UV) * vec2(textureSize(fcode, 0));
	float mlod = 0.5 * log2(max(max(dot(tdx, tdx), dot(tdy, tdy)), 1e-8));
	vec2 hdx = dFdx(UV) * vec2(textureSize(dye_code, 0));       // (Q22 ④) 머리 마스크 코드 기준 lod · 머리 틀 화소 크기
	vec2 hdy = dFdy(UV) * vec2(textureSize(dye_code, 0));
	float hlod = 0.5 * log2(max(max(dot(hdx, hdx), dot(hdy, hdy)), 1e-8));
	float hpx = max(fwidth(v_hp.x), fwidth(v_hp.y));
	if (v_show < 0.5) {
		discard;
	}
	vec3 c;
	if (v_dye.w > 45.0) {
		vec4 t = texture(frames_atlas, UV);
		if (UV.x < v_win.x || UV.y < v_win.y || UV.x > v_win.z || UV.y > v_win.w) {
			discard;
		}
		// 알파 자르기는 엔진의 ALPHA_SCISSOR로 (2026-11-12, Metal: 직접 discard하면 셰이더가 조금 커지거나 해에 그림자가 없을 때
		// 버린 자리가 검은 네모로 남았다 — 줄여 가며 찾음. ALPHA_SCISSOR면 엔진이 깊이 패스까지 같은 문턱으로 자름 → 사라짐)
		ALPHA = t.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
		vec4 m0;
		vec4 m1;
		masks(UV, mlod, m0, m1);
		if (v_dye.w > 55.0 && v_dye.w < 65.0 && m1.b < 0.5) {
			discard;
		}
		c = t.rgb;
		if (v_dye.w > 65.0) {
			// 짐 그림은 그린 색 그대로. 아기 그림(v13)만 피부(m0.r)·머리카락(m0.g)을 그 아기의 물감으로 — 주민과 같은 규칙 (피부 = 채널별 비율, 머리 = 밝기 옮기기)
			vec3 o = c * (1.0 - min(m0.r + m0.g, 1.0));
			o += m0.r * (baby.x < -0.5 ? c : c * clamp(palette[int(baby.x + 0.5)] / max(bbase[0], vec3(0.04)), vec3(0.0), vec3(5.0)));
			o += m0.g * (baby.y < -0.5 ? c : palette[int(baby.y + 0.5)] * (luma(c) / max(luma(bbase[1]), 0.04)));
			c = o;
		} else {
			float wsum = min(m0.r + m0.g + m0.b + m0.a + m1.r + m1.g, 1.0);
			vec3 o = c * (1.0 - wsum);
			o += m0.r * dye_with(c, 0, fbase[0]);
			o += m0.g * dye_with(c, 2, fbase[2]);
			o += m0.b * dye_with(c, 3, fbase[3]);
			o += m0.a * dye_with(c, 4, fbase[4]);
			o += m1.r * dye_with(c, 6, fbase[6]);
			o += m1.g * dye_with(c, 7, fbase[7]);
			c = o * mix(1.0, far_k, m1.a);
		}
	} else {
		vec4 t = texture(atlas, UV);
		// 알파 자르기는 엔진의 ALPHA_SCISSOR로 (2026-11-12, Metal: 직접 discard하면 셰이더가 조금 커지거나 해에 그림자가 없을 때
		// 버린 자리가 검은 네모로 남았다 — 줄여 가며 찾음. ALPHA_SCISSOR면 엔진이 깊이 패스까지 같은 문턱으로 자름 → 사라짐)
		ALPHA = t.a;
		ALPHA_SCISSOR_THRESHOLD = alpha_cut;
		c = t.rgb;
		vec3 m = head_mask(UV, hlod);
		vec3 o = c * (1.0 - min(m.r + m.g + m.b, 1.0));
		o += m.r * dyed(c, v_dye.x, v_dye.w);
		o += m.g * dyed(c, v_dye.y, v_dye.w);
		o += m.b * dyed(c, v_dye.z, v_dye.w);
		if (v_hi > -0.5 && (look2.z > 0.0 || look2.w > 0.5)) {
			int hix = int(v_hi + 0.5);
			int si = int(v_dye.w + 0.5) * 8;
			o = mk_apply(o, c, m, mk_marks(v_hp, texelFetch(head_data, ivec2(hix, 1), 0), texelFetch(head_data, ivec2(hix, 2), 0), look2, hpx), base_col[si], base_col[si + 1]);
		}
		c = o;
	}
	ALBEDO = srgb_to_linear(clamp(c, 0.0, 1.0));
	ROUGHNESS = 1.0;
}

void light() {
	float lit = step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += mix(mix(shade_tint, lit_tint, lit), vec3(1.0), self_lit * (1.0 - lit));
}
