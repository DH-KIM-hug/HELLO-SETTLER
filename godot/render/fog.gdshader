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
	float n = fbm(p);
	float a = COLOR.a;
	// 뭉게 가장자리: 안개 정도 + 잡음 → 문턱
	float e = a + (n - 0.5) * 0.55;
	float aa = fwidth(e) + 1e-3;
	float core = smoothstep(0.55 - aa, 0.55 + aa, e);
	float halo = smoothstep(0.32 - aa, 0.32 + aa, e);
	// 구름 안쪽 그늘 (한 단계): 해 반대쪽으로 밀린 잡음
	float n2 = fbm(p * 1.6 + vec2(0.35, 0.2));
	float sh = smoothstep(0.56 - fwidth(n2), 0.56 + fwidth(n2), n2);
	vec3 c = mix(cloud_col, cloud_shade, sh * 0.85);
	c = mix(haze_col, c, core);
	ALBEDO = c;
	ALPHA = max(core * 0.97, halo * 0.45);
}
