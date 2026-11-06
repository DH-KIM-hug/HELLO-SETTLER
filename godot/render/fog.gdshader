// 안개 (본 적 없는 땅) — 6단계, 기획서 3.1 '나머지는 안개 속 미개척지'. 셀 채색(flat2) 그림체에 맞춘 흰 구름층.
// 꼭짓점 COLOR.a = 그 자리가 안개인 정도 (0 걷힘 ~ 1 안개) — view/world_terrain.gd가 안개 칸에서 넣음.
// 가장자리는 잡음으로 흔든 문턱으로 또렷하게 끊어 뭉게구름 모양 + 바깥쪽 옅은 띠 한 단계, 안쪽은 흰색 두 단계(밝은 면·그늘 면).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

uniform vec3 cloud_col : source_color = vec3(0.976, 0.973, 0.953);
uniform vec3 cloud_shade : source_color = vec3(0.855, 0.886, 0.902);
uniform vec3 haze_col : source_color = vec3(0.93, 0.95, 0.95);
uniform float puff_scale = 0.075;
uniform float drift = 0.012;
uniform float far = 0.0;
// (B1 다듬기) 0 가까이 ~ 1 넓은 땅·세상 전체·병 밖: 안개를 '땅 위의 엷은 구름·물안개'로 — 흰 원판 대신 밑의 땅 색·높이가 비치고,
// 구름 사이로 틈이 나고, 그늘 면은 부드럽게. 구름 무늬가 천천히 흐른다 (drift). view/world_terrain.gd zoom_ppu가 넣음.
uniform float thin = 0.0;
// 등불 옮기기 미리보기 (A11 — view/lamp_ctl.gd): 안개 위에도 볕이 들 땅 노랑 · 그늘이 될 땅 파랑 (wpos = 병 데이터 좌표)
uniform float lamp_mix = 0.0;
uniform vec2 lamp_l0 = vec2(-0.72, -0.69);
uniform vec2 lamp_l1 = vec2(-0.72, -0.69);
uniform float lamp_rr = 512.0;          // 0 가까이 ~ 1 병 전체가 보일 만큼 축소 — 잔무늬를 큰 뭉게구름으로 바꾸고 그늘을 옅게 (깨알 무늬 방지)

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.07 + 5.3) * 0.3 + vnoise(p * 4.3 - 2.1) * 0.15;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz * puff_scale + vec2(TIME * drift, TIME * drift * 0.6);
	// 가까이·멀리 한쪽이면 잡음을 하나만 (화면을 덮는 층이라 휴대폰에서 픽셀마다 비용이 큼 — far는 화면 전체에 같은 값)
	vec2 pf = wpos.xz * puff_scale * 0.18 + 11.0;
	vec2 qf = wpos.xz * puff_scale * 0.3 + 3.0;
	float n;
	float n2;
	if (far <= 0.001) {
		n = fbm(p);
		n2 = fbm(p * 1.6 + vec2(0.35, 0.2));
	} else if (far >= 0.999) {
		n = fbm(pf);
		n2 = fbm(qf);
	} else {
		n = mix(fbm(p), fbm(pf), far);
		n2 = mix(fbm(p * 1.6 + vec2(0.35, 0.2)), fbm(qf), far);
	}
	float a = COLOR.a;
	// 뭉게 가장자리: 안개 정도 + 잡음 → 문턱
	float e = a + (n - 0.5) * 0.55;
	float aa = fwidth(e) + 1e-3;
	float core = smoothstep(0.55 - aa, 0.55 + aa, e);
	float halo = smoothstep(0.32 - aa, 0.32 + aa, e);
	// 구름 안쪽 그늘 (한 단계): 해 반대쪽으로 밀린 잡음
	float sh = smoothstep(0.56 - fwidth(n2), 0.56 + fwidth(n2), n2);
	vec3 c = mix(cloud_col, cloud_shade, sh * 0.85 * (1.0 - 0.45 * far));
	c = mix(haze_col, c, core);
	if (lamp_mix > 0.0) {
		float g = (dot(wpos.xz, lamp_l1) - dot(wpos.xz, lamp_l0)) / lamp_rr;
		float k = smoothstep(0.04, 0.45, abs(g));
		vec3 tint = g > 0.0 ? vec3(1.0, 0.84, 0.36) : vec3(0.45, 0.62, 0.98);
		c = mix(c, tint * (0.75 + 0.25 * c.r), k * 0.6 * lamp_mix);
	}
	float alpha = max(core * 0.97, halo * 0.45);
	if (thin > 0.001) {
		// 엷은 구름: 큰 덩이 잡음(흐름)으로 틈을 내고, 덩이 안쪽은 반투명 · 그늘 면은 푸른 회색으로 부드럽게
		vec2 q = wpos.xz * puff_scale * 0.11 + vec2(TIME * drift * 0.35, -TIME * drift * 0.2) + 7.0;
		float big = fbm(q);
		float gap = smoothstep(0.44, 0.56, big);                 // 0 틈 ~ 1 구름 덩이
		// 덩이 가장자리: 창가 반대쪽(그늘 면)을 푸른 회색으로 — 잡음을 조금 밀어 읽은 값과의 차이
		float bs = fbm(q + vec2(0.05, 0.04));
		float shade = smoothstep(0.0, 0.05, bs - big) * gap;
		float soft = smoothstep(0.3, 0.75, n2) * 0.5 + shade * 0.6;
		vec3 tc = mix(cloud_col, cloud_shade, clamp(soft, 0.0, 1.0));
		c = mix(c, mix(haze_col, tc, gap), thin);
		float body = mix(0.1, 0.62, gap) * core + 0.08 * halo;  // 틈은 옅은 물안개만 (땅이 또렷), 덩이는 반쯤 가림
		alpha = mix(alpha, min(body, 0.66), thin);
	}
	ALBEDO = c;
	ALPHA = alpha;
}
