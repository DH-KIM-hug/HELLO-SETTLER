// 수면 — RENDERING.md v2 2.7: 옅은 하늘색 + 큰 흰 물결 무늬(평면 모양, 천천히 흐름) + 물가 한 단계 진한 띠.
// 꼭짓점 UV.x = 그 자리 물 깊이 (수면 − 땅, 세계 단위 — view/jar_terrain.gd가 넣음). 물결은 세계 좌표 잡음을 문턱으로 끊는다.
// 빛은 공용 셀 채색 (그림자가 물에도 진다).
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

#include "res://render/toon_light.gdshaderinc"

uniform vec3 water_col : source_color;
uniform vec3 deep_col : source_color;
uniform vec3 shore_col : source_color;
uniform vec3 foam_col : source_color;
uniform float wave_scale = 0.11;
uniform float wave_speed = 0.025;
uniform float wave_amount = 0.22;
uniform float shore_depth = 0.045;

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
	return vnoise(p) * 0.6 + vnoise(p * 2.13 + 7.1) * 0.28 + vnoise(p * 4.37 - 3.3) * 0.12;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = UV.x;
	vec3 c = mix(water_col, deep_col, smoothstep(0.6, 1.4, depth));
	// 큰 흰 물결: 한쪽으로 늘인 잡음을 천천히 흘려서 문턱으로 끊는다
	// 화면 가로(기본 카메라 방위 45°)로 길게 늘인 무늬
	vec2 q = vec2(wpos.x - wpos.z, wpos.x + wpos.z) * 0.7071;
	vec2 p = q * wave_scale * vec2(0.45, 2.0);
	float t = TIME * wave_speed;
	float n = fbm(p + vec2(t, t * 0.4)) * 0.65 + fbm(p * 1.7 - vec2(t * 0.7, -t * 0.3) + 11.0) * 0.35;
	float thr = 0.66 - wave_amount * 0.4;
	float aa = fwidth(n) + 1e-4;
	float foam = smoothstep(thr - aa, thr + aa, n);
	float inner = smoothstep(thr + 0.035 - aa, thr + 0.035 + aa, n);   // 무늬 안쪽은 더 흰 한 단계
	c = mix(c, mix(mix(c, foam_col, 0.55), foam_col, inner), foam * smoothstep(0.08, 0.3, depth));
	// 물가 띠
	float sa = fwidth(depth) + 1e-4;
	c = mix(shore_col, c, smoothstep(shore_depth - sa, shore_depth + sa, depth));
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
