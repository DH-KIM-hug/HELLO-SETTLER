// 2D 컷아웃 주민 v2 (시안 A, 2026-11-08 시제품 — 게임 주민과 무관)
// 주민 한 명 = 메시 하나 · 재질 하나 = 그리기 1번. 모든 주민이 같은 메시(조각 라이브러리 전체의 사각형)와 같은 재질을 나눠 씀.
// 사람마다 다른 것은 instance uniform 뿐: 고른 조각 묶음(옷·머리·모자·소품), 보기(앞·비스듬한 앞·비스듬한 뒤·뒤 + 뒤집기),
// 동작(애니메이션 표 텍스처의 줄), 물감 번호 8개. 고르지 않은 사각형은 점으로 접혀 그려지지 않는다.
// 조각 움직임 = 정점 셰이더 (CPU 일 없음): anim_tex 한 칸 = (회전, dx, dy, 세로 배율), 조각 슬롯 × (동작·보기 종류·장면).
// 색 = 마스크(R·G·B = 조각의 물감 채널 0·1·2 무게)에 따라 그린 그림을 물감으로 (피부 = 채널 비율, 그 밖 = 밝기 옮기기). 기본 물감이면 그림 그대로.
// 빛 = 우리 툰 규칙: 해 그림자(건물 그늘)는 청록 그늘 한 단계, 주민은 스스로 조금 밝음(art-bible R5: 그늘에서도 85% 아래로 안 떨어짐).
// 밤·모닥불·외곽선은 화면 셰이더(outline_post)가 깊이로 처리 → 불투명(알파 자르기)이라 3D 주민과 똑같이 받는다.
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;     // sRGB 값 그대로 읽고 물감을 곱한 뒤 한 번만 선형으로
uniform sampler2D dye_mask : hint_default_black, filter_linear_mipmap, repeat_disable;   // (Q22 ④) 4분의 1 크기 마스크 — head_mask()
uniform sampler2D anim_tex : filter_nearest, repeat_disable;
uniform int frames = 16;
uniform vec3 palette[64];          // 물감 (sRGB)
uniform vec3 base_col[64];         // 그린 바탕색 [묶음 × 8 + 물감 슬롯] (sRGB) — 묶음 8개까지
uniform vec2 head_socket[32];      // 옷 묶음 S의 목 자리 [S × 4 + 보기] (rig 단위, 몸 종류 배율 반영)
uniform vec2 head_top[32];         // 머리 묶음 T의 정수리 - 목 [T × 4 + 보기] — 모자는 고른 머리의 정수리에
uniform float head_k[8];           // 몸 종류(옷 묶음 S)마다 머리 배율 — 시안 A 작은 화면처럼 큰 머리 (build_atlas BODY)
uniform int set_col = 11;          // 동작 표의 묶음 칸 시작: 옷 묶음 S마다 (소품 dx, dy, 몸 내림 dy, 지팡이 숨김) — 몸이 다르면 소품도 그 손에,
                                   // 앉기·무릎은 그 몸의 다리 길이만큼 내림 (cut_lib.bake_anim)
uniform float fig = 920.0;         // rig 단위로 그림 키
uniform vec2 body_pivot = vec2(0.0, 380.0);
uniform float layer_eps = 0.004;   // 겹 순서: 겹 하나마다 카메라 쪽으로 (세계 단위)
uniform vec3 lit_tint : source_color = vec3(1.0);
uniform vec3 shade_tint : source_color = vec3(0.55, 0.76, 0.87);
uniform float self_lit = 0.5;      // 그늘 속에서도 이만큼 원래 밝기 쪽으로 (R5)
uniform float alpha_cut = 0.5;
uniform float far_shade = 0.84;    // 비스듬한 보기의 먼 다리(leg_b)를 조금 어둡게 — 두 다리가 겹쳐도 둘로 읽힘 (2026-11-08)
uniform ivec4 prop_layer = ivec4(5, 7, 0, 0);    // 보기마다 소품의 겹 (앞: 몸과 팔 사이, 뒤: 몸 뒤)
// (Q8) 어깨에 멘 밀 이삭: 뒤쪽 보기(2·3)에서는 몸 앞에 든 자리 그대로면 머리·몸에 가려 안 보인다 → 그 소품만 제 자리·제 겹으로
uniform int back_prop = -1;                      // 그 소품 번호 (-1 없음)
uniform vec4 back_xf[2];                         // 보기 2·3: (회전 더함, dx 더함, dy 더함, 배율 곱 — 음수 = 좌우로 뒤집음)
uniform ivec2 back_layer = ivec2(0, 0);          // 그때의 겹

instance uniform vec4 sel = vec4(0.0, 0.0, -1.0, -1.0);    // 옷 묶음 S, 머리 묶음 T, 모자 묶음 U(-1 없음), 소품(-1 없음)
instance uniform vec4 st = vec4(0.0, 1.0, 0.0, 0.0);       // 보기 0~3, 뒤집기 ±1, 동작 번호, 시작 위상(0~1)
instance uniform vec4 dyes0 = vec4(0.0, 1.0, 2.0, 3.0);    // 물감 번호: 피부, 머리카락, 옷 주색, 둘째(크림)
instance uniform vec4 dyes1 = vec4(4.0, 5.0, 6.0, 7.0);    // 장식(띠·가죽), 모자, 다리(양말·바지), 신
instance uniform vec4 misc = vec4(0.88, 1.0, 1.0, 0.0);
// (Q22 ④, 2026-11-12) 유전 → 겉모습: x = 머리결 변형 (머리 조각 CUSTOM2.w — 0 원래 그림 · 1 웨이브 · 2 곱슬 · 3 숱 적음 · 4 직모),
// y = 수염 (0 없음 · 1 짧은 · 2 덥수룩 — group 7 조각), z = 주근깨 진하기 0~1, w = 표시 코드 (흰 앞머리 1 + 2 × 눈송이 무늬 0~6 + 16 × 자리 0~7)
// (Q22 ④) 머리 자료 텍스처 (RGBAF 128 × 3, cut_lib.head_data): 줄 0 = 마스크 코드표 (코드 → 마스크 RGB), 줄 1 = 얼굴 자리 head_eye
// (머리 묶음 × 4 + 보기: 두 눈 x, y, x, y), 줄 2 = head_mark (눈 반지름, 머리선 x, y, 얼굴 반폭) — 머리 틀 rig, 턱 = 원점.
// (작은 표를 한 장에 — 방식 C 재질의 텍스처 · uniform을 늘리지 않게.)
uniform sampler2D head_data : filter_nearest, repeat_disable;
instance uniform vec4 look2 = vec4(0.0);    // 화면 키(세계), 폭 배율(음수 = 뒤집힘), 동작 빠르기(주기/초), 기울기(rad, 발끝 중심 — 톡 반응 + 화면 몸짓을 더한 값: cutout_resident._push_misc)

varying flat vec4 v_dye;     // xyz = 이 조각의 물감 슬롯 0·1·2 (-1 없음), w = 묶음
varying flat float v_show;
varying flat float v_far;    // 1 = 비스듬한 보기의 먼 다리
varying vec2 v_hp;           // (Q22 ④) 머리 조각의 머리 틀 rig 자리 (얼굴 표시용)
varying flat float v_hi;     // 머리 묶음 × 4 + 보기 (머리 그림 조각만, 그 밖 -1)
varying flat vec4 v_eye;     // 그 머리의 얼굴 자리 (head_data 줄 1 · 2 — 정점에서 골라 넘김)
varying flat vec4 v_mark;

vec4 anim(int slot, int row0, float f) {
	int fa = int(floor(f)) % frames;
	int fb = (fa + 1) % frames;
	vec4 a = texelFetch(anim_tex, ivec2(slot, row0 + fa), 0);
	vec4 b = texelFetch(anim_tex, ivec2(slot, row0 + fb), 0);
	return mix(a, b, fract(f));
}

vec2 xf(vec2 p, vec2 piv, vec4 a) {     // 회전(a.x) + 세로 배율(a.w) 은 piv 기준, 그다음 옮김(a.yz)
	vec2 q = p - piv;
	q.y *= a.w;
	float c = cos(a.x), s = sin(a.x);
	q = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	return q + piv + a.yz;
}

void vertex() {
	vec2 piv = CUSTOM0.xy;
	int slot = int(CUSTOM0.z + 0.5);
	int group = int(CUSTOM0.w + 0.5);
	float set_i = CUSTOM1.x;
	int view = int(CUSTOM1.y + 0.5);
	int cur_view = int(st.x + 0.5);
	int kind = (cur_view == 1 || cur_view == 2) ? 1 : 0;     // 비스듬한 보기 (소품 그림 고르기)
	bool show;
	if (group == 0) {
		show = abs(set_i - sel.x) < 0.5 && view == cur_view;
	} else if (group == 1) {
		// 머리 묶음의 조각: 머리 그림은 이 사람의 머리결 변형 하나만 (CUSTOM2.w), 머리꼬리·매듭·목(-1)은 늘
		show = abs(set_i - sel.y) < 0.5 && view == cur_view && (CUSTOM2.w < -0.5 || abs(CUSTOM2.w - look2.x) < 0.5);
	} else if (group == 7) {
		// (Q22 ④) 수염: 그 머리 묶음 위에 (수염 그림이 있는 묶음만 — 지금 d)
		show = look2.y > 0.5 && abs(set_i - sel.y) < 0.5 && view == cur_view && abs(CUSTOM2.w - look2.y) < 0.5;
	} else if (group == 2) {
		show = sel.z >= 0.0 && abs(set_i - sel.z) < 0.5 && view == cur_view;
	} else {
		float pid = sel.w;
		if (kind == 1 && pid >= 0.0 && pid < 2.5) {
			pid += 3.0;     // 빵·나뭇가지·바구니는 비스듬한 그림이 따로
		}
		show = pid >= 0.0 && abs(set_i - pid) < 0.5;
	}
	v_show = show ? 1.0 : 0.0;
	v_far = (group == 0 && slot == 8 && kind == 1) ? 1.0 : 0.0;
	v_hp = VERTEX.xy;
	v_hi = (group == 1 && CUSTOM2.w > -0.5) ? float(int(set_i + 0.5) * 4 + view) : -1.0;
	int hix = clamp(int(set_i + 0.5) * 4 + view, 0, 31);
	v_eye = texelFetch(head_data, ivec2(hix, 1), 0);
	v_mark = texelFetch(head_data, ivec2(hix, 2), 0);
	v_dye = vec4(CUSTOM1.zw, CUSTOM2.x, group == 3 ? 99.0 : set_i);
	int row0 = (int(st.z + 0.5) * 4 + cur_view) * frames;
	float f = fract(TIME * misc.z + st.w) * float(frames);
	vec4 ps = vec4(0.0);
	if (show) {
		ps = anim(set_col + int(sel.x + 0.5), row0, f);
		if (CUSTOM3.z > 0.5 && ps.w > 0.5) {
			show = false;      // 앉기·눕기·무릎·숙이기: 지팡이는 내려놓음
			v_show = 0.0;
		}
	}
	if (!show) {
		VERTEX = vec3(0.0);
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);    // 화면 밖 한 점으로 접기
	} else {
		vec2 p = VERTEX.xy;
		vec4 a_own = anim(slot, row0, f);
		bool bk = group == 3 && cur_view >= 2 && back_prop >= 0 && abs(sel.w - float(back_prop)) < 0.5;
		int so = int(sel.x + 0.5) * 4 + cur_view;
		if (group == 3) {
			// 소품: 원점 둘레 그림 → 회전·배율 → (dx, dy) 자리 (몸 틀) + 이 몸의 손 자리 차이
			vec4 pa = a_own;
			if (bk) {
				vec4 bx = back_xf[cur_view - 2];
				pa = vec4(pa.x + bx.x, pa.y + bx.y, pa.z + bx.z, pa.w * bx.w);
			}
			if (pa.w < 0.0) {
				p.x = -p.x;                              // 음수 배율 = 좌우로 뒤집은 그림 (낫질의 낫 · 뒤에서 본 이삭)
			}
			p = xf(p, vec2(0.0), vec4(pa.x, 0.0, 0.0, 1.0)) * abs(pa.w) + pa.yz;
			p += ps.xy;
		} else if (CUSTOM3.z > 0.5) {
			// 지팡이: 손(CUSTOM3.xy)이 움직인 만큼만 옮김 — 돌지 않고 곧게 섬
			vec2 g = xf(CUSTOM3.xy, piv, a_own);
			g = xf(g, CUSTOM2.yz, anim(slot - 2, row0, f));
			p += g - CUSTOM3.xy;
		} else if (group != 2) {
			p = xf(p, piv, a_own);
		}
		if ((slot == 5 || slot == 6) && CUSTOM3.z < 0.5) {
			p = xf(p, CUSTOM2.yz, anim(slot - 2, row0, f));   // 아래팔은 소매(어깨)를 따라
		}
		if (group == 1 || group == 2 || group == 7) {
			if (group == 2) {
				// 모자 = 머리와 한 덩어리: 고른 머리의 정수리에 놓은 뒤 머리와 똑같이 (턱 기준) 돌림 — 제 꼭대기 기준으로 돌면 머리에서 떨어짐
				p += head_top[int(sel.y + 0.5) * 4 + cur_view];
			}
			if (slot != 2 || group == 2) {
				p = xf(p, vec2(0.0), anim(2, row0, f));    // 매듭·머리꼬리·모자는 머리를 따라 (수염은 슬롯 2 — 머리 조각처럼 위의 a_own으로)
			}
			p = p * head_k[int(sel.x + 0.5)] + head_socket[so];     // 몸 종류의 머리 배율 (턱 = 목 자리 기준)
		}
		if (group != 0 || (slot >= 1 && slot <= 6)) {
			p = xf(p, body_pivot, anim(1, row0, f));       // 몸이 흔들리면 윗몸 전체가 따라
		}
		p = xf(p, vec2(0.0), anim(0, row0, f));
		p.y += ps.z;                                   // 엉덩이 내림 (걸음 들썩임·앉기·무릎 — 이 몸의 다리 길이만큼)
		p.x *= st.y * misc.y;
		if (misc.w != 0.0) {                           // [톡 반응 · 아이·아기 몸짓] 발끝을 중심으로 인형 전체를 기울임 (view/tap_react.gd · view/kids_view.gd — 화면만)
			float rc = cos(misc.w), rs = sin(misc.w);
			p = vec2(rc * p.x - rs * p.y, rs * p.x + rc * p.y);
		}
		// 카메라를 보는 세로 판: 오른쪽 = 카메라 오른쪽(수평), 위 = 세계 위. 정사영에서 세로 길이는 cam_up.y 만큼 줄어 보이므로 늘려 줌
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		right = normalize(vec3(right.x, 0.0, right.z));
		vec3 back = INV_VIEW_MATRIX[2].xyz;
		float cu = max(INV_VIEW_MATRIX[1].y, 0.3);
		float k = misc.x / fig;
		vec3 org = MODEL_MATRIX[3].xyz;
		float layer = group == 3 ? float(bk ? back_layer[cur_view - 2] : prop_layer[cur_view]) - 0.5 : VERTEX.z;
		vec3 w = org + right * (p.x * k) + vec3(0.0, p.y * k / cu, 0.0) + back * (layer * layer_eps);
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

// 물감 하나 입히기: 피부는 채널별 비율 (볼 홍조·그늘의 색 차이가 남음 — 피부 톤은 색상이 비슷해 비율이 작음),
// 그 밖(머리카락·옷·모자)은 밝기 옮기기 = 물감 × (그 화소 밝기 / 그린 바탕 밝기) — 짙은 바탕을 밝은 물감으로 바꿔도 색이 틀어지지 않음
vec3 dyed(vec3 c, float slot, float set_i) {
	if (slot < -0.5) {
		return c;
	}
	int s = int(slot + 0.5);
	if (dye_index(s) < -0.5) {
		return c;      // 물감 -1 = 그린 색 그대로 (시안 그대로의 주민)
	}
	vec3 b = base_col[int(set_i + 0.5) * 8 + s];
	vec3 d = palette[int(dye_index(s) + 0.5)];
	if (s == 0) {
		return c * clamp(d / max(b, vec3(0.04)), vec3(0.0), vec3(5.0));
	}
	return d * (luma(c) / max(luma(b), 0.04));
}

void fragment() {
	// 마스크의 lod · 화소 크기 (텍스처 미분은 버리기 전에 — 코드 텍스처 기준, GPU가 고르는 밉맵 단과 같은 식)
	vec2 tdx = dFdx(UV) * vec2(textureSize(dye_code, 0));
	vec2 tdy = dFdy(UV) * vec2(textureSize(dye_code, 0));
	float mlod = 0.5 * log2(max(max(dot(tdx, tdx), dot(tdy, tdy)), 1e-8));
	float hpx = max(fwidth(v_hp.x), fwidth(v_hp.y));
	vec4 t = texture(atlas, UV);
	if (v_show < 0.5) {
		discard;
	}
	// 알파 자르기는 엔진의 ALPHA_SCISSOR로 (방식 C 셰이더와 같게 — 직접 discard하면 그림자 없는 해 아래서 버린 자리가 검게 남는 일이 있었다)
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 c = t.rgb;
	if (v_dye.w < 7.5) {
		vec3 m = head_mask(UV, mlod);
		vec3 o = c * (1.0 - min(m.r + m.g + m.b, 1.0));
		o += m.r * dyed(c, v_dye.x, v_dye.w);
		o += m.g * dyed(c, v_dye.y, v_dye.w);
		o += m.b * dyed(c, v_dye.z, v_dye.w);
		if (v_hi > -0.5 && (look2.z > 0.0 || look2.w > 0.5)) {
			int si = int(v_dye.w + 0.5) * 8;
			o = mk_apply(o, c, m, mk_marks(v_hp, v_eye, v_mark, look2, hpx), base_col[si], base_col[si + 1]);
		}
		c = o;
	}
	c *= mix(1.0, far_shade, v_far);
	ALBEDO = srgb_to_linear(clamp(c, 0.0, 1.0));
	ROUGHNESS = 1.0;
}

void light() {
	// 판은 늘 카메라를 보므로 N·L 대신 해 그림자(건물·나무 그늘)만: 그늘 = 청록 한 단계, 주민은 조금 스스로 밝음
	float lit = step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += mix(mix(shade_tint, lit_tint, lit), vec3(1.0), self_lit * (1.0 - lit));
}
