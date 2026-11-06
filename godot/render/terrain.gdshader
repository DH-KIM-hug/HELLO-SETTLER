// 땅 — RENDERING.md v2 2.3 · 2.4 · 2.7
// 꼭짓점 COLOR = 풀밭 바탕색 (sRGB, 칸 색을 꼭짓점으로 평균 → 부드럽게 바뀜).
// UV = (오솔길, 소금), UV2 = (강, 호숫가) — 꼭짓점 사이에서 보간된 값을 문턱으로 끊어
// 흙길·소금 들판·강·물가 띠를 또렷한 곡선 경계의 평면 색으로 그린다 (칸 모양 계단이 보이지 않게).
// 높이는 선 대신 색 단계 + 작은 둔덕 테두리 (band_h마다).
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

#include "res://render/toon_light.gdshaderinc"

uniform vec3 path_col : source_color;
uniform vec3 path_edge : source_color;
uniform vec3 salt_col : source_color;
uniform vec3 salt_edge : source_color;
uniform vec3 river_col : source_color;
uniform vec3 river_edge : source_color;
uniform vec3 bank_col : source_color;
uniform vec3 ridge_col : source_color;
uniform vec3 foam_col : source_color = vec3(0.9, 0.97, 0.97);
uniform float band_h = 0.9;          // 높이 단계 (세계 단위)
uniform float band_lift = 0.035;     // 단계마다 밝아지는 정도

varying vec3 wpos;
varying float up;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 문턱 a에서 끊되 가장자리 띠(폭 w)는 edge 색
vec3 layer(vec3 base, float v, float a, float w, vec3 fill, vec3 edge) {
	float aa = fwidth(v) * 0.75 + 1e-4;
	float inside = smoothstep(a - aa, a + aa, v);
	float core = smoothstep(a + w - aa, a + w + aa, v);
	return mix(base, mix(edge, fill, core), inside);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = NORMAL.y;
}

void fragment() {
	vec3 c = srgb_to_linear(COLOR.rgb);
	if (up > 0.35) {
		// 높이 단계: 높을수록 조금 밝게 + 단계 경계에 둔덕 테두리
		float b = wpos.y / band_h;
		c *= 1.0 + band_lift * clamp(floor(b), -2.0, 4.0);
		float fw = fwidth(b);
		float ridge = 1.0 - smoothstep(fw * 0.6, fw * 1.6, fract(b));
		c = mix(c, ridge_col, ridge * smoothstep(0.002, 0.02, fw) * 0.8);
		c = layer(c, UV2.y, 0.5, 0.0, bank_col, bank_col);
		c = layer(c, UV.x, 0.5, 0.06, path_col, path_edge);
		c = layer(c, UV.y, 0.5, 0.08, salt_col, salt_edge);
		c = layer(c, UV2.x, 0.5, 0.08, river_col, river_edge);
		// 강의 흰 물살 (천천히 흐르는 잡음을 문턱으로)
		float rn = vnoise(wpos.xz * vec2(0.9, 0.9) + vec2(TIME * 0.35, TIME * 0.2)) * 0.6 + vnoise(wpos.xz * 2.1 - TIME * 0.4) * 0.4;
		float rf = smoothstep(0.62, 0.66, rn) * smoothstep(0.62, 0.75, UV2.x);
		c = mix(c, foam_col, rf);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
