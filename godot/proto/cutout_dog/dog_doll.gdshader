// 2D 종이 인형 강아지 (E3-13 · E3-13b, 2026-11-08) — 주민 인형(proto/cutout_a/cut_doll.gdshader)과 같은 방식·같은 빛 규칙.
// 강아지 한 마리 = 메시 하나 · 재질 하나 = 그리기 1번. 모든 강아지가 같은 메시(조각 라이브러리 전체의 사각형)와 재질을 나눠 씀.
// 마리마다 다른 것은 instance uniform 뿐: 귀·꼬리 종류, 옷(꿀떡이 니트), 보기(앞·옆·비스듬한 뒤·뒤 + 뒤집기), 동작, 털빛·무늬.
// 고르지 않은 사각형은 화면 밖 한 점으로 접힌다. 조각 움직임 = 정점 셰이더 (anim_tex 한 칸 = 회전, dx, dy, 세로 배율).
// 털빛 = 마스크(R 바탕 털 · G 밝은 털(주둥이·가슴·발))에 따라 그린 그림을 물감으로 (밝기 옮기기 — 그늘·선은 그대로).
// 무늬 = 조각의 그린 자리(rig 좌표)에서 그 자리에서 계산 (얼룩·눈가면·주근깨·양말발) — 텍스처 없이, 강아지마다 씨앗으로 다름.
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque;

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D dye_mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform sampler2D anim_tex : filter_nearest, repeat_disable;
uniform int frames = 16;
uniform float fig = 430.0;            // rig 단위로 그림 키 (서 있는 강아지, 귀 끝 ~ 발바닥)
uniform vec2 body_pivot[4];           // 보기마다 몸 조각의 돌림 중심 (머리·귀·꼬리·다리 붙는 자리가 몸을 따름)
uniform vec3 coat_base = vec3(0.9, 0.58, 0.33);     // 그린 바탕 털 (sRGB 값 그대로 — source_color 아님: 셰이더가 sRGB로 셈, build_dog가 잰 값)
uniform vec3 light_base = vec3(0.99, 0.87, 0.74);   // 그린 밝은 털 (sRGB 값 그대로)
uniform float layer_eps = 0.003;
uniform vec3 lit_tint : source_color = vec3(1.0);
uniform vec3 shade_tint : source_color = vec3(0.55, 0.76, 0.87);
uniform float self_lit = 0.5;
uniform float alpha_cut = 0.5;
uniform float far_shade = 0.84;
// 꿀떡이 (사용자의 강아지를 닮게, Q2-e) — pat_c.w가 켜진 강아지만 씀. 값은 dog_lib.gd가 조각 표에서 채움.
uniform vec4 kk_ear[4];               // 보기마다 접힌 귀 두 쪽의 뿌리 (a.xy, b.xy — rig)
uniform vec2 kk_tail[4];              // 보기마다 말린 꼬리의 뿌리 (rig)
uniform vec4 kk_nose[6];              // 보기 0·1 × 머리 셋 (보통·잠·짖음): 코 (x, y, 가로 반지름, 세로 반지름)
uniform vec3 kk_nose_col = vec3(0.56, 0.34, 0.27);     // 간색(밤빛) 코 (sRGB 값 그대로)
uniform vec3 kk_pink = vec3(0.97, 0.76, 0.74);         // 흰 귀 안쪽의 분홍 (sRGB 값 그대로)
uniform float kk_ear_scale = 1.28;    // 귀가 크고 넓게 벌어짐
uniform float kk_tail_scale = 1.16;   // 풍성한 꼬리

instance uniform vec4 sel = vec4(1.0, 0.0, 0.0, 0.0);      // 귀 종류 0~2, 꼬리 종류 0~1, 니트 0/1, -
instance uniform vec4 st = vec4(0.0, 1.0, 0.0, 0.0);       // 보기 0~3, 뒤집기 ±1, 동작 번호, 시작 위상
instance uniform vec4 misc = vec4(0.5, 1.0, 1.0, 0.0);     // 화면 키(세계), 폭 배율(음수 = 뒤집힘), 빠르기(주기/초), 기울기(rad, 발끝 중심)
instance uniform vec4 coat = vec4(0.79, 0.54, 0.31, 0.0);  // 바탕 털 rgb (sRGB), 무늬 종류 (0 없음 1 얼룩 2 눈가면 3 주근깨 4 양말발)
instance uniform vec4 light_c = vec4(0.95, 0.9, 0.8, 0.0); // 밝은 털 rgb, 무늬 씨앗
instance uniform vec4 pat_c = vec4(0.5, 0.3, 0.2, 0.0);    // 무늬 rgb, 꿀떡이 표시 (1 = 아래 '꿀떡이' 겉모습 — 유전자가 아니라 그 한 마리만)

varying flat vec4 v_info;     // x 조각 종류 (0 몸 1 머리 2 귀 3 꼬리 4 다리 5 옷), y 먼 쪽(1), z 귀 쪽 (0 a 1 b), w 보기
varying vec2 v_loc;           // 그린 자세의 rig 좌표 (무늬)
varying flat vec4 v_eyes;     // 머리: 두 눈 자리 (rig)
varying flat vec4 v_head;     // 머리: 가운데 x, 폭, 머리 종류 (0 보통 1 잠 2 짖음), -
varying flat vec2 v_piv;      // 조각의 돌림 중심 (귀 = 뿌리)
varying flat float v_show;

vec4 anim(int slot, int row0, float f) {
	int fa = int(floor(f)) % frames;
	int fb = (fa + 1) % frames;
	return mix(texelFetch(anim_tex, ivec2(slot, row0 + fa), 0), texelFetch(anim_tex, ivec2(slot, row0 + fb), 0), fract(f));
}

vec2 xf(vec2 p, vec2 piv, vec4 a) {
	vec2 q = p - piv;
	q.y *= a.w;
	float c = cos(a.x), s = sin(a.x);
	q = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	return q + piv + a.yz;
}

void vertex() {
	vec2 piv = CUSTOM0.xy;
	int slot = int(CUSTOM0.z + 0.5);
	int group = int(CUSTOM0.w + 0.5);       // 0 늘 · 1 머리 (동작이 고름) · 2 귀 (종류) · 3 꼬리 (종류) · 4 옷
	float kind = CUSTOM1.x;
	int view = int(CUSTOM1.y + 0.5);
	int cur_view = int(st.x + 0.5);
	int row0 = (int(st.z + 0.5) * 4 + cur_view) * frames;
	float f = fract(TIME * misc.z + st.w) * float(frames);
	bool show = view == cur_view;
	if (group == 1) {
		float hk = floor(anim(10, row0, f).x + 0.5);
		int clip = int(st.z + 0.5);
		if (pat_c.w > 0.5 && hk < 0.5 && (clip == 1 || clip == 4)) {
			hk = 2.0;                              // 꿀떡이: 걷거나 놀자고 할 때 입을 벌리고 웃음 (혀)
		}
		show = show && abs(kind - hk) < 0.5;
	} else if (group == 2) {
		show = show && abs(kind - sel.x) < 0.5;
	} else if (group == 3) {
		show = show && abs(kind - sel.y) < 0.5;
	} else if (group == 4) {
		show = show && sel.z > 0.5;
	}
	v_show = show ? 1.0 : 0.0;
	v_info = vec4(CUSTOM1.z, CUSTOM1.w, CUSTOM2.w, float(view));
	v_loc = VERTEX.xy;
	v_eyes = CUSTOM3;
	v_head = vec4(CUSTOM2.xy, kind, 0.0);
	v_piv = piv;
	if (!show) {
		VERTEX = vec3(0.0);
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	} else {
		vec2 p = VERTEX.xy;
		if (group == 2 && pat_c.w > 0.5) {             // 꿀떡이: 큰 귀 (뿌리에서 키움), 앞·뒤 보기에선 바깥으로 조금 벌림
			p = piv + (p - piv) * kk_ear_scale;
			if (cur_view == 0 || cur_view == 3) {
				p += vec2(sign(piv.x - CUSTOM2.x) * 7.0, -5.0);
			}
		} else if (group == 3 && pat_c.w > 0.5) {      // 꿀떡이: 등 위로 말린 풍성한 꼬리
			p = piv + (p - piv) * kk_tail_scale;
		}
		vec2 bp = body_pivot[cur_view];
		vec4 a_body = anim(1, row0, f);
		if (slot >= 6 && slot <= 9) {
			// 다리: 제 자리(어깨·엉덩이)에서 돌고 늘고, 붙은 자리는 몸을 따라 옮겨짐 (몸이 기울어도 다리는 곧게)
			p = xf(p, piv, anim(slot, row0, f));
			p += xf(piv, bp, a_body) - piv;
		} else {
			p = xf(p, piv, anim(slot, row0, f));
			if (slot == 3 || slot == 4) {
				p = xf(p, CUSTOM2.xy, anim(2, row0, f));    // 귀는 머리를 따라 (목 자리 = CUSTOM2.xy)
			}
			if (slot != 1) {
				p = xf(p, bp, a_body);                     // 머리·귀·꼬리는 몸을 따라
			}
		}
		p = xf(p, vec2(0.0), anim(0, row0, f));
		p.x *= st.y * misc.y;
		if (misc.w != 0.0) {                           // [톡 반응] 발끝을 중심으로 인형 전체를 기울임 (view/tap_react.gd — 화면만)
			float rc = cos(misc.w), rs = sin(misc.w);
			p = vec2(rc * p.x - rs * p.y, rs * p.x + rc * p.y);
		}
		vec3 right = INV_VIEW_MATRIX[0].xyz;
		right = normalize(vec3(right.x, 0.0, right.z));
		vec3 back = INV_VIEW_MATRIX[2].xyz;
		float cu = max(INV_VIEW_MATRIX[1].y, 0.3);
		float k = misc.x / fig;
		vec3 org = MODEL_MATRIX[3].xyz;
		vec3 w = org + right * (p.x * k) + vec3(0.0, p.y * k / cu, 0.0) + back * (VERTEX.z * layer_eps);
		VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
		NORMAL = normalize((VIEW_MATRIX * vec4(back, 0.0)).xyz);
		POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	}
}

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 u = fract(p);
	u = u * u * (3.0 - 2.0 * u);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 작은 점 (주근깨): 칸마다 점 하나 (있을 수도 없을 수도), 반지름 r
float dots(vec2 p, float cell, float r, float seed) {
	vec2 g = floor(p / cell);
	float best = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 c = g + vec2(float(dx), float(dy));
			float h = hash2(c + seed);
			if (h < 0.55) {
				continue;
			}
			vec2 o = (c + vec2(hash2(c + seed + 3.1), hash2(c + seed + 7.7)) * 0.8 + 0.1) * cell;
			best = max(best, 1.0 - smoothstep(r * 0.7, r, length(p - o)));
		}
	}
	return best;
}

// 이 화소의 바탕 털이 무늬 색이 되는 정도 (0~1)
float pattern(float pk, float part, vec2 p, float seed) {
	if (pk > 0.5 && pk < 1.5) {          // 얼룩: 몸·머리·꼬리에 큰 덩어리
		if (part > 4.5) { return 0.0; }
		float n = vnoise(p / 95.0 + seed) * 0.65 + vnoise(p / 40.0 + seed * 1.7) * 0.35;
		return smoothstep(0.56, 0.6, n);
	}
	if (pk > 1.5 && pk < 2.5) {          // 눈가면: 머리의 두 눈 둘레 + 귀 전부
		if (part > 1.5 && part < 2.5) { return 1.0; }
		if (part > 0.5 && part < 1.5) {
			float hw = max(v_head.y, 1.0);
			float r = 0.24 * hw;
			float m = 0.0;
			for (int i = 0; i < 2; i++) {
				vec2 e = i == 0 ? v_eyes.xy : v_eyes.zw;
				if (e.x > 9000.0) { continue; }
				vec2 d = (p - e) / vec2(r, r * 1.1);
				m = max(m, 1.0 - smoothstep(0.85, 1.0, length(d)));
			}
			return m;
		}
		return 0.0;
	}
	return 0.0;
}

// 두 점을 잇는 둥근 띠까지의 거리 (반지름이 ra → rb로 바뀜)
float band_sd(vec2 p, vec2 a, vec2 b, float ra, float rb) {
	vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
	return length(p - a - ab * t) - mix(ra, rb, t);
}

// 꿀떡이 머리의 생강빛: 눈마다 눈 둘레에서 귀 뿌리까지 올라가는 얼룩, 그 사이 이마~주둥이는 하얀 줄
float kk_head(vec2 p, int vw) {
	float hw = max(v_head.y, 1.0);
	vec4 eb = kk_ear[vw];
	float m = 0.0;
	if (vw == 0) {
		for (int i = 0; i < 2; i++) {
			vec2 e = i == 0 ? v_eyes.xy : v_eyes.zw;
			if (e.x > 9000.0) { continue; }
			float os = sign(e.x - v_head.x);
			vec2 root = os < 0.0 ? eb.xy : eb.zw;
			// 눈 둘레에서 귀 뿌리로 (바깥 띠) + 이마 쪽으로 (안쪽 띠) — 둘이 합쳐 얼굴 위쪽 반을 덮는 한 덩어리
			float sd = band_sd(p, e + vec2(os * 0.035, 0.05) * hw, root + vec2(-os * 0.035, -0.04) * hw, 0.13 * hw, 0.15 * hw);
			sd = min(sd, band_sd(p, e + vec2(0.0, 0.07) * hw, vec2(v_head.x + os * 0.17 * hw, e.y + 0.4 * hw), 0.11 * hw, 0.11 * hw));
			m = max(m, 1.0 - smoothstep(-2.5, 2.5, sd));
		}
		float dy = (p.y - v_eyes.y) / hw;
		float bw = mix(0.042, 0.1, smoothstep(0.04, 0.42, dy)) * hw + smoothstep(0.0, -0.1, dy) * 0.1 * hw;   // 눈 사이는 좁고 정수리로 갈수록 넓은 흰 줄
		m *= smoothstep(bw, bw + 5.0, abs(p.x - v_head.x));
	} else if (vw == 1) {
		vec2 e = v_eyes.xy;
		if (e.x < 9000.0) {
			float sd = band_sd(p, e + vec2(-0.03, 0.045) * hw, eb.xy + vec2(0.08, -0.05) * hw, 0.13 * hw, 0.17 * hw);
			sd = min(sd, band_sd(p, e + vec2(-0.03, 0.06) * hw, e + vec2(-0.1, 0.27) * hw, 0.115 * hw, 0.115 * hw));
			m = 1.0 - smoothstep(-2.5, 2.5, sd);
			float front = e.x + 0.085 * hw - (p.y - e.y) * 0.15;       // 눈 앞쪽 (이마~코)은 하얀 줄
			m *= 1.0 - smoothstep(front - 3.0, front + 3.0, p.x);
		}
	} else {
		// 뒤에서: 귀 뿌리 아래에 얼룩의 끝자락만 조금
		for (int i = 0; i < 2; i++) {
			vec2 root = i == 0 ? eb.xy : eb.zw;
			vec2 d = (p - (root + vec2(0.0, -0.05 * hw))) / vec2(0.1 * hw, 0.075 * hw);
			m = max(m, 1.0 - smoothstep(0.8, 1.0, length(d)));
		}
	}
	return m;
}

void fragment() {
	vec4 t = texture(atlas, UV);
	if (t.a < alpha_cut || v_show < 0.5) {
		discard;
	}
	vec3 c = t.rgb;
	float part = v_info.x;
	if (part < 4.5) {
		vec3 m = texture(dye_mask, UV).rgb;
		float pk = coat.w;
		float seed = light_c.w;
		float lc = luma(c);
		vec3 cb = coat.rgb * (lc / max(luma(coat_base), 0.04));
		float pm = pat_c.w > 0.5 ? 0.0 : pattern(pk, part, v_loc, seed);
		vec3 pb = pat_c.rgb * (lc / max(luma(coat_base), 0.04));
		cb = mix(cb, pb, pm);
		vec3 lb = light_c.rgb * (lc / max(luma(light_base), 0.04));
		// 양말발: 다리 아래 (발목 위까지) 밝은 털
		if (pk > 3.5 && part > 3.5) {
			cb = mix(cb, lb, 1.0 - smoothstep(34.0, 40.0, v_loc.y));      // 배 아래로 보이는 다리 (rig y < ~50)의 아래쪽
		}
		// 주근깨: 밝은 털(주둥이·가슴·발) 위의 작은 점 / 꿀떡이는 먼 쪽 귀에도
		float fr = 0.0;
		if (pk > 2.5 && pk < 3.5 && (part < 1.5 || part > 3.5)) {
			fr = dots(v_loc, 16.0, 4.5, seed);
		}
		vec3 frc = pat_c.rgb * (lc / max(luma(light_base), 0.04));
		vec3 lbf = mix(lb, frc, fr);
		if (pat_c.w > 0.5) {
			// 꿀떡이 (그 한 마리만 — 강아지가 물려받는 건 보통 유전자뿐): 눈마다 생강빛 얼룩 + 이마 하얀 줄, 제 왼쪽 귀는 생강빛 ·
			// 오른쪽 귀는 희고 안쪽이 분홍 · 끝에 생강빛 주근깨, 꼬리 뿌리의 작은 얼룩, 다리의 옅은 주근깨, 간색 코.
			int vw = int(v_info.w + 0.5);
			float g = 0.0;
			float pink = 0.0;
			float dim = 1.0;
			if (part < 0.5) {
				if (vw > 0) {
					vec2 off = vw == 1 ? vec2(12.0, 15.0) : (vw == 2 ? vec2(20.0, 12.0) : vec2(0.0, 6.0));
					float rr = vw == 3 ? 27.0 : 19.0;
					g = 1.0 - smoothstep(rr - 3.0, rr + 2.0, length((v_loc - kk_tail[vw] - off) * vec2(1.0, 1.25)));
				}
			} else if (part < 1.5) {
				g = kk_head(v_loc, vw);
			} else if (part < 2.5) {
				bool left = (v_info.z > 0.5) != (vw >= 2);          // 앞·비스듬히 앞: b쪽이 제 왼쪽 / 비스듬히 뒤·뒤: a쪽
				if (st.y * misc.y < 0.0) { left = !left; }          // 뒤집힌 그림에선 반대
				float tip = clamp(length(v_loc - v_piv) / 70.0, 0.0, 1.0);
				if (left) {
					g = 1.0;
					dim = mix(1.0, 0.86, smoothstep(0.45, 1.0, tip));
				} else {
					g = max(dots(v_loc, 9.0, 3.4, 5.0) * smoothstep(0.3, 0.65, tip), smoothstep(0.82, 1.02, tip) * 0.75);
					pink = (1.0 - smoothstep(0.2, 0.62, tip)) * 0.55;
				}
			} else if (part > 3.5) {
				g = dots(v_loc, 15.0, 2.8, 9.0) * 0.38;
			}
			float kc = lc / max(luma(coat_base), 0.04);
			float kl = lc / max(luma(light_base), 0.04);
			cb = mix(cb, kk_pink * kc, pink);
			cb = mix(cb, pat_c.rgb * kc * dim, g);
			lbf = mix(lbf, pat_c.rgb * kl * dim, g);
		}
		float ink = 1.0 - min(m.r + m.g, 1.0);
		vec3 o = c * ink;                              // 물감 아닌 것 (선·코·볼 붉은기·눈)은 그린 그대로
		o += m.r * cb + m.g * lbf;
		if (pat_c.w > 0.5 && part > 0.5 && part < 1.5 && v_info.w < 1.5) {
			vec4 n = kk_nose[int(v_info.w + 0.5) * 3 + int(v_head.z + 0.5)];
			float nm = (1.0 - smoothstep(0.85, 1.0, length((v_loc - n.xy) / n.zw))) * ink * (1.0 - smoothstep(0.3, 0.5, lc));
			o = mix(o, kk_nose_col * (0.72 + lc * 1.3), nm);
		}
		c = o;
	}
	float far = v_info.y;
	if (pat_c.w > 0.5 && part > 1.5 && part < 2.5) {
		far *= 0.45;                                   // 꿀떡이의 흰 귀가 먼 쪽에서 잿빛으로 보이지 않게
	}
	c *= mix(1.0, far_shade, far);
	ALBEDO = srgb_to_linear(clamp(c, 0.0, 1.0));
	ROUGHNESS = 1.0;
}

void light() {
	float lit = step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += mix(mix(shade_tint, lit_tint, lit), vec3(1.0), self_lit * (1.0 - lit));
}
