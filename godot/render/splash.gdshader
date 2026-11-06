// 폭포 웅덩이의 물거품 고리 — 기획서 4.2 (A12). 메시 = art/models/water/splash_foam.glb (웅덩이 위 반원 고리 + 가운데 흰 원판).
// UV: u = 둘레 0~4, v = 안→밖 0~1 · COLOR.r = 거품 세기 (폭포 바로 밑 1). 바깥으로 퍼지는 동그란 물결 + 부서지는 흰 거품.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never, blend_mix;

uniform vec3 foam_col : source_color = vec3(0.92, 0.98, 0.98);
uniform vec3 ripple_col : source_color = vec3(0.8, 0.93, 0.95);
uniform float night_amount = 0.0;
uniform vec3 night_mul : source_color = vec3(0.3, 0.37, 0.6);
uniform vec3 night_add : source_color = vec3(0.01, 0.02, 0.05);
instance uniform float opacity = 0.9;
instance uniform float phase = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

varying float strength;

void vertex() {
	strength = COLOR.r;
}

void fragment() {
	float t = TIME + phase;
	// 바깥으로 퍼지는 물결 고리 두 개
	float r = fract(UV.y * 1.6 - t * 0.45);
	float rw = fwidth(UV.y) * 1.6 + 0.02;
	float ring = 1.0 - smoothstep(0.06, 0.06 + rw, abs(r - 0.5));
	// 부서지는 거품
	float n = vnoise(vec2(UV.x * 9.0, UV.y * 5.0 - t * 1.4)) * 0.65 + vnoise(vec2(UV.x * 21.0, UV.y * 9.0 - t * 2.1)) * 0.35;
	float fa = fwidth(n) + 1e-4;
	float froth = smoothstep(0.62 - strength * 0.35 - fa, 0.62 - strength * 0.35 + fa, n);
	float outer = 1.0 - smoothstep(0.7, 1.0, UV.y);
	float a = max(froth * (0.55 + 0.45 * strength), ring * 0.45 * outer) * outer;
	vec3 c = mix(ripple_col, foam_col, froth);
	c = mix(c, c * night_mul + night_add, night_amount);
	ALBEDO = c;
	ALPHA = clamp(a * opacity, 0.0, 1.0);
}
