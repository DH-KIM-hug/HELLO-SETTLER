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
uniform sampler2D dye_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
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
instance uniform vec4 misc = vec4(0.88, 1.0, 1.0, 0.0);    // 화면 키(세계), 폭 배율(음수 = 뒤집힘), 동작 빠르기(주기/초), 기울기(rad, 발끝 중심 — 톡 반응 + 화면 몸짓을 더한 값: cutout_resident._push_misc)

varying flat vec4 v_dye;     // xyz = 이 조각의 물감 슬롯 0·1·2 (-1 없음), w = 묶음
varying flat float v_show;
varying flat float v_far;    // 1 = 비스듬한 보기의 먼 다리

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
		show = abs(set_i - sel.y) < 0.5 && view == cur_view;
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
		if (group == 1 || group == 2) {
			if (group == 2) {
				// 모자 = 머리와 한 덩어리: 고른 머리의 정수리에 놓은 뒤 머리와 똑같이 (턱 기준) 돌림 — 제 꼭대기 기준으로 돌면 머리에서 떨어짐
				p += head_top[int(sel.y + 0.5) * 4 + cur_view];
			}
			if (slot != 2 || group == 2) {
				p = xf(p, vec2(0.0), anim(2, row0, f));    // 매듭·머리꼬리·모자는 머리를 따라
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
	vec4 t = texture(atlas, UV);
	if (t.a < alpha_cut || v_show < 0.5) {
		discard;
	}
	vec3 c = t.rgb;
	if (v_dye.w < 3.5) {
		vec3 m = texture(dye_mask, UV).rgb;
		vec3 o = c * (1.0 - min(m.r + m.g + m.b, 1.0));
		o += m.r * dyed(c, v_dye.x, v_dye.w);
		o += m.g * dyed(c, v_dye.y, v_dye.w);
		o += m.b * dyed(c, v_dye.z, v_dye.w);
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
