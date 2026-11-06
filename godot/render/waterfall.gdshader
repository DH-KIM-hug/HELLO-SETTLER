// 유리벽 폭포 띠 — 기획서 4.2 (A12). 메시 = art/models/water/waterfall_strip.glb (폭 1.4 × 높이 6, 위는 유리에 붙고 아래 12%에서 웅덩이 쪽으로 꺾임).
// UV: u = 가로 0~1, v = 위→아래 (1 = 띠 폭) · COLOR.r = 물거품 가림막 (양 가장자리·아래 = 1).
// 흐르는 물결 무늬(아래로 스크롤되는 잡음을 문턱으로 끊은 흰 줄) + 가장자리 반짝임 + 물거품. view/waterfalls.gd가 놓는다.
// 굵기·투명도는 그 골의 물 양 (instance uniform — 재질 하나를 모든 폭포가 나눠 씀).
// far: 멀리 축소하면 무늬 없이 밝은 은빛 세로 띠 하나 (지평선 위의 수직 은빛 띠).
// 화면 셰이더(outline_post) 뒤에 그려지는 반투명이라 밤 색 조정은 night_amount로 따로 받는다.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never, blend_mix;

uniform vec3 water_col : source_color = vec3(0.42, 0.78, 0.82);
uniform vec3 foam_col : source_color = vec3(0.89, 0.96, 0.96);
uniform vec3 shine_col : source_color = vec3(1.0);
uniform vec3 far_col : source_color = vec3(0.86, 0.95, 0.98);
uniform float speed = 1.3;
uniform float night_amount = 0.0;
uniform vec3 night_mul : source_color = vec3(0.3, 0.37, 0.6);
uniform vec3 night_add : source_color = vec3(0.01, 0.02, 0.05);
instance uniform float opacity = 0.85;
instance uniform float far = 0.0;
instance uniform float aspect = 1.0;      // 세로 배율 ÷ 가로 배율 — 물결 무늬가 늘어나지 않게
instance uniform float phase = 0.0;
uniform float v_top = -3.46;              // 모델 UV.y 범위 (꼭대기 ~ 바닥 — view/waterfalls.gd가 메시에서 읽어 넣음)
uniform float v_bot = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying float foam_v;

void vertex() {
	foam_v = COLOR.r;
}

void fragment() {
	float u = UV.x;
	float v = UV.y * aspect;
	float t = TIME * speed + phase;
	// 아래로 흐르는 가는 줄 (세로로 길게 늘인 잡음 두 겹)
	float n = vnoise(vec2(u * 10.0, v * 0.45 - t)) * 0.6 + vnoise(vec2(u * 19.0 + 3.0, v * 0.9 - t * 1.6)) * 0.4;
	float aa = fwidth(n) + 1e-4;
	float streak = smoothstep(0.6 - aa, 0.6 + aa, n);
	// 가장자리 반짝임 (양쪽 얇은 흰 줄)
	float edge = min(u, 1.0 - u);
	float ew = fwidth(u) * 1.5 + 0.02;
	float rim = 1.0 - smoothstep(0.06, 0.06 + ew, edge);
	float foam = smoothstep(0.35, 0.8, foam_v);
	vec3 c = mix(water_col, foam_col, max(streak * 0.75, foam));
	c = mix(c, shine_col, rim * 0.8);
	float a = opacity * mix(0.55, 1.0, max(max(streak, foam), rim));
	// 꼭대기는 뚜껑 경사에서 흘러드는 곳 — 옅게 시작
	float vt = (UV.y - v_top) / (v_bot - v_top);      // 0 꼭대기 ~ 1 바닥
	a *= smoothstep(0.0, 0.07, vt);
	// 멀리: 밝은 은빛 띠 하나
	c = mix(c, far_col, far);
	a = mix(a, opacity * 0.95, far);
	c = mix(c, c * night_mul + night_add, night_amount);
	ALBEDO = c;
	ALPHA = clamp(a, 0.0, 1.0);
}
