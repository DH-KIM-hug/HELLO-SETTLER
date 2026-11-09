// 방식 C 주민 시험판 (docs/RESIDENTS_2D.md 7장, 2026-11-08 — 스파이크, 기본값은 그대로 컷아웃):
// 몸+옷 = 장면마다 그린 그림 한 장 (frames_atlas, 걸음·숨쉬기가 그림에 있음), 옷 색 = 물감 마스크 두 장 (frames_mask0/1),
// 머리·얼굴·모자 = 지금 컷아웃 라이브러리의 머리 조각 (doll_atlas)을 그 장면의 턱 자리(fdata)에 얹음 → 머리·모자 조합은 그대로.
// 한 사람 = 메시 하나 = 그리기 1번 (몸 사각형 + 짐 겹 + 모든 머리·모자 사각형, 고르지 않은 것은 점으로 접힘).
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;          // 머리 조각 (컷아웃 라이브러리)
uniform sampler2D dye_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D frames_atlas : filter_linear_mipmap, repeat_disable;   // 몸 장면들
uniform sampler2D fmask0 : hint_default_black, filter_linear_mipmap, repeat_disable;   // 피부 · 옷 주색 · 둘째(크림) · 장식(띠)
uniform sampler2D fmask1 : hint_default_black, filter_linear_mipmap, repeat_disable;   // 다리(양말) · 신 · 짐(물감 없음)
uniform sampler2D fdata : filter_nearest, repeat_disable;               // 장면마다: [0] uv 사각형, [1] (턱 x, y, 시작 위상, -) rig
uniform ivec4 clip_off = ivec4(0, 32, 64, 80);   // 동작(걷기·나르기·서기·안고 서기)의 첫 장면 번호
uniform ivec4 clip_n = ivec4(8, 8, 4, 4);         // 동작의 장면 수 (보기마다)
uniform vec4 body_rect = vec4(-400.0, -10.0, 400.0, 1020.0);   // 몸 장면 사각형 (rig, 발바닥 가운데 = 0)
uniform vec4 head_k = vec4(1.3);                  // 보기마다 머리 배율 (자리 표시 원 지름에 맞춤)
uniform vec4 body_layer = vec4(5.0, 7.0, 6.0, 4.0);   // 보기마다 몸의 겹 (컷아웃 라이브러리의 몸 겹 — 머리꼬리·매듭 앞뒤가 그대로)
uniform vec4 sack_layer = vec4(12.0, 12.0, -1.0, -1.0);   // 짐을 머리 위에 다시 그리는 겹 (-1 = 안 그림: 짐이 머리 뒤)
uniform vec3 palette[64];
uniform vec3 base_col[64];       // 머리 조각 묶음의 그린 바탕색 (컷아웃과 같음)
uniform vec3 fbase[8];           // 몸 장면의 그린 바탕색 (물감 슬롯 0~7)
uniform vec2 head_top[32];
uniform float fig = 920.0;
uniform float layer_eps = 0.004;
uniform vec3 lit_tint : source_color = vec3(1.0);
uniform vec3 shade_tint : source_color = vec3(0.55, 0.76, 0.87);
uniform float self_lit = 0.5;
uniform float alpha_cut = 0.5;
uniform float far_k = 0.68;       // 비스듬한 보기의 먼 다리 (frames_mask1.a)를 물감을 입힌 뒤 이만큼 어둡게 — 어떤 양말 색이든 두 다리가 갈림

instance uniform vec4 sel = vec4(0.0, 0.0, -1.0, -1.0);    // -, 머리 묶음 T, 모자 묶음 U(-1 없음), -
instance uniform vec4 st = vec4(0.0, 1.0, 0.0, 0.0);       // 보기 0~3, 뒤집기 ±1, 동작(0 걷기 1 나르기 2 서기 3 안고 서기), 시작 위상
instance uniform vec4 dyes0 = vec4(0.0, 1.0, 2.0, 3.0);
instance uniform vec4 dyes1 = vec4(4.0, 5.0, 6.0, 7.0);
instance uniform vec4 misc = vec4(0.88, 1.0, 1.0, 0.0);    // 화면 키(세계), -, 동작 빠르기(주기/초), -

varying flat vec4 v_dye;     // 머리 조각: 물감 슬롯 xyz, w = 묶음 · 몸: w = 50 (몸) / 60 (짐 겹)
varying flat float v_show;

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
	bool show;
	if (group == 0) {
		show = true;
	} else if (group == 4) {
		show = sack_layer[cur_view] >= 0.0 && clip != 0 && clip != 2;
	} else if (group == 1) {
		show = abs(set_i - sel.y) < 0.5 && view == cur_view;
	} else {
		show = sel.z >= 0.0 && abs(set_i - sel.z) < 0.5 && view == cur_view;
	}
	v_show = show ? 1.0 : 0.0;
	v_dye = vec4(CUSTOM1.zw, CUSTOM2.x, group == 0 ? 50.0 : (group == 4 ? 60.0 : set_i));
	if (!show) {
		VERTEX = vec3(0.0);
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		vec2 p;
		float layer;
		if (group == 0 || group == 4) {
			vec2 c = UV;                                       // 귀퉁이 (0~1)
			p = vec2(mix(body_rect.x, body_rect.z, c.x), mix(body_rect.w, body_rect.y, c.y));
			vec4 r = texelFetch(fdata, ivec2(fi, 0), 0);
			UV = mix(r.xy, r.zw, c);
			layer = group == 0 ? body_layer[cur_view] : sack_layer[cur_view];
		} else {
			p = VERTEX.xy;
			if (group == 2) {
				p += head_top[int(sel.y + 0.5) * 4 + cur_view];
			}
			p = p * head_k[cur_view] + fd.xy;
			layer = VERTEX.z;
		}
		p.x *= st.y;
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		right = normalize(vec3(right.x, 0.0, right.z));
		vec3 back = INV_VIEW_MATRIX[2].xyz;
		float cu = max(INV_VIEW_MATRIX[1].y, 0.3);
		float k = misc.x / fig;
		vec3 org = MODEL_MATRIX[3].xyz;
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

void fragment() {
	if (v_show < 0.5) {
		discard;
	}
	vec3 c;
	if (v_dye.w > 45.0) {
		vec4 t = texture(frames_atlas, UV);
		vec4 m0 = texture(fmask0, UV);
		vec4 m1 = texture(fmask1, UV);
		if (t.a < alpha_cut || (v_dye.w > 55.0 && m1.b < 0.5)) {
			discard;
		}
		c = t.rgb;
		float wsum = min(m0.r + m0.g + m0.b + m0.a + m1.r + m1.g, 1.0);
		vec3 o = c * (1.0 - wsum);
		o += m0.r * dye_with(c, 0, fbase[0]);
		o += m0.g * dye_with(c, 2, fbase[2]);
		o += m0.b * dye_with(c, 3, fbase[3]);
		o += m0.a * dye_with(c, 4, fbase[4]);
		o += m1.r * dye_with(c, 6, fbase[6]);
		o += m1.g * dye_with(c, 7, fbase[7]);
		c = o * mix(1.0, far_k, m1.a);
	} else {
		vec4 t = texture(atlas, UV);
		if (t.a < alpha_cut) {
			discard;
		}
		c = t.rgb;
		vec3 m = texture(dye_mask, UV).rgb;
		vec3 o = c * (1.0 - min(m.r + m.g + m.b, 1.0));
		o += m.r * dyed(c, v_dye.x, v_dye.w);
		o += m.g * dyed(c, v_dye.y, v_dye.w);
		o += m.b * dyed(c, v_dye.z, v_dye.w);
		c = o;
	}
	ALBEDO = srgb_to_linear(clamp(c, 0.0, 1.0));
	ROUGHNESS = 1.0;
}

void light() {
	float lit = step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += mix(mix(shade_tint, lit_tint, lit), vec3(1.0), self_lit * (1.0 - lit));
}
