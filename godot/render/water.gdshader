// 수면 — RENDERING.md v2 2.7: 옅은 하늘색 + 흰 물결 무늬(평면 모양, 천천히 흐름) + 부드러운 물가.
// 꼭짓점 UV.x = 그 자리 물 깊이 · UV.y = 강 몫 (0~1) (수면 − 땅, 세계 단위 — view/jar_terrain.gd·world_terrain.gd가 넣음). 물결은 세계 좌표 잡음을 문턱으로 끊는다.
// (물 다듬기 2026-11) 물가 = 진한 띠 대신 얕은 물 밝은 색 → 물가 거품 한 줄 (잡음으로 흔들려 계단 대신 둥글게).
// 흰 물결은 깊이로 끊지 않고 (얕은 물 삼각형마다 잘린 흰 조각 방지) 얕은 곳에서 부드럽게 사라짐 · 물가 가까이 반짝임 조금.
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
	float riv = UV.y;                       // 강 몫 (얕은 물길이라도 물빛으로 — world_terrain.gd가 넣음)
	float cd = depth + riv * 0.22;
	float t = TIME * wave_speed;
	// 얕은 물은 밝게 (밑이 비치는 듯) → 보통 → 깊은 물
	vec3 shallow = mix(water_col, foam_col, 0.28);
	vec3 c = mix(shallow, water_col, smoothstep(0.0, 0.2, cd));
	c = mix(c, deep_col, smoothstep(0.6, 1.4, cd));
	// 흰 물결: 화면 가로(기본 카메라 방위 45°)로 길게 늘인 잡음을 천천히 흘려서 문턱으로 끊는다 — 가늘고 옅게
	vec2 q = vec2(wpos.x - wpos.z, wpos.x + wpos.z) * 0.7071;
	vec2 p = q * wave_scale * vec2(0.45, 2.4);
	float n = fbm(p + vec2(t, t * 0.4)) * 0.65 + fbm(p * 1.7 - vec2(t * 0.7, -t * 0.3) + 11.0) * 0.35;
	float thr = 0.68 - wave_amount * 0.4;
	float aa = fwidth(n) + 1e-4;
	float band = smoothstep(thr - aa, thr + aa, n) * (1.0 - smoothstep(thr + 0.05 - aa, thr + 0.05 + aa, n) * 0.55);
	c = mix(c, foam_col, band * 0.5 * smoothstep(0.05, 0.35, cd));
	// 물가: 잡음으로 흔든 얕은 깊이에서 거품 한 줄 (물 가장자리가 계단처럼 읽히지 않게) + 가장자리 바로 앞은 한 단계 짙은 가는 선
	float wob = vnoise(wpos.xz * 1.3 + vec2(t * 6.0, -t * 4.0)) - 0.5;
	float fd = depth + wob * 0.012;
	float sa = fwidth(depth) + 1e-4;
	float foam_line = 1.0 - smoothstep(0.011 - sa, 0.011 + sa, fd);
	float under = (1.0 - smoothstep(0.024 - sa, 0.024 + sa, fd)) * (1.0 - foam_line);
	c = mix(c, mix(shallow, shore_col, 0.35), under * 0.5);
	c = mix(c, foam_col, foam_line * 0.8);
	// 물가 가까이 반짝임 (드문 점이 천천히 깜빡)
	vec2 sg = floor(wpos.xz * 2.2);
	float sp = hash(sg);
	float tw = sin(TIME * 1.7 + sp * 40.0) * 0.5 + 0.5;
	float near = 1.0 - smoothstep(0.05, 0.25, depth);
	float dotm = 1.0 - smoothstep(0.08, 0.16, length(fract(wpos.xz * 2.2) - 0.5));
	c = mix(c, vec3(1.0), step(0.93, sp) * tw * dotm * near * 0.7);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
