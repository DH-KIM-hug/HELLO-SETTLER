// 모닥불 불꽃 (view/campfire.gd) — 겹친 불꽃 혀 카드 몇 장 (메시 하나 = 그리기 한 번).
// 카드마다 꼭짓점: VERTEX = 카드 밑동 자리(모델 공간), UV = 카드 모서리(0~1), UV2 = 카드 (폭, 높이), COLOR.r = 겹(0 뒤·큼 ~ 1 앞·작음), COLOR.g = 위상.
// 꼭짓점: 카메라를 보는 판(빌보드) — 밑동은 장작 사이에 고정, 위로 갈수록 흔들림 · 키가 잡음으로 일렁임.
// 화소: 물방울 모양(둥근 밑 · 뾰족한 끝)을 흐르는 값 잡음으로 일그러뜨리고 끝을 갉아 혀가 떨어져 나감.
//       색은 가장자리 → 가운데로 빨강 → 주황 → 노랑 (부드러운 띠 세 단계 — 그림책 느낌). 앞 겹일수록 노랗다.
// 반투명이라 화면 마무리 셰이더(밤 색 조정) 뒤에 그려진다 → 밤에도 밝게 빛난다.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float heat : hint_range(0.0, 1.5) = 1.0;    // 0 = 꺼짐 · 0.35 연기 불 · 1 보통 · 1.4 큰 불
uniform float smoky : hint_range(0.0, 1.0) = 0.0;   // 모깃불: 붉고 탁한 불
uniform float speed = 1.0;
uniform vec3 col_edge : source_color = vec3(0.86, 0.27, 0.16);
uniform vec3 col_mid : source_color = vec3(0.98, 0.56, 0.18);
uniform vec3 col_core : source_color = vec3(1.0, 0.86, 0.38);
uniform vec3 col_hot : source_color = vec3(1.0, 0.97, 0.78);

varying float v_layer;
varying float v_seed;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	v_layer = COLOR.r;
	v_seed = COLOR.g;
	float s = length(MODEL_MATRIX[0].xyz);
	float t = TIME * speed + v_seed * 17.0;
	float flick = 1.0 + 0.11 * sin(t * 9.3) + 0.07 * sin(t * 14.1 + 1.3) + 0.09 * (vnoise(vec2(t * 3.1, v_seed * 9.0)) - 0.5);
	float h = UV2.y * s * heat * flick;
	float w = UV2.x * s * mix(0.7, 1.0, clamp(heat, 0.0, 1.5)) * (1.0 + 0.05 * sin(t * 7.7));
	vec2 c = vec2(UV.x - 0.5, 1.0 - UV.y);
	float sway = (sin(t * 2.3) * 0.13 + sin(t * 3.9 + 0.7) * 0.07) * (1.0 - v_layer * 0.4);
	vec3 anchor = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	anchor.z += 0.3 * s;                  // 카메라 쪽으로 — 장작 원뿔 앞에 서서 장작이 불꽃을 가르지 않게 (밑동만 살짝 묻힘)
	vec3 off = vec3(c.x * w + sway * c.y * c.y * h * 0.55, (c.y - 0.06) * h, 0.0);
	POSITION = PROJECTION_MATRIX * vec4(anchor + off, 1.0);
}

void fragment() {
	vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
	float y = p.y;
	float t = TIME * speed * 2.1 + v_seed * 5.0;
	float n1 = vnoise(vec2(p.x * 3.2 + v_seed * 11.0, y * 2.6 - t));
	float n2 = vnoise(vec2(p.x * 7.0 - v_seed * 3.0, y * 5.0 - t * 1.6));
	p.x += (n1 - 0.5) * 0.3 * y;
	// 물방울: 밑은 반지름 R 원, 위는 끝으로 좁아짐
	float R = 0.3;
	float hw = y < R ? sqrt(max(0.0, R * R - (y - R) * (y - R))) * (0.45 / R) : 0.45 * pow(max(0.0, 1.0 - (y - R) / (1.0 - R)), 1.35);
	float edge = hw - abs(p.x);
	edge -= (n2 * 0.75 + n1 * 0.25) * 0.16 * y * y;       // 끝을 갉음 → 혀가 갈라지고 떨어져 나감
	float a = smoothstep(0.0, 0.025, edge);
	float core = clamp(edge / max(hw, 0.02), 0.0, 1.0) * (1.0 - y * 0.55);
	core = clamp(core + v_layer * 0.35, 0.0, 1.0);
	vec3 col = mix(col_edge, col_mid, smoothstep(0.08, 0.2, core));
	col = mix(col, col_core, smoothstep(0.32, 0.46, core));
	col = mix(col, col_hot, smoothstep(0.62, 0.75, core) * v_layer);
	col = mix(col, col * vec3(0.8, 0.55, 0.45), smoky);
	ALBEDO = col;
	ALPHA = a * clamp(heat * 2.0, 0.0, 1.0) * mix(1.0, 0.75, smoky);
}
