// 뒤집은 껍데기 외곽선 — RENDERING.md v2 2.4 (5단계)
// 모델을 화면 평면에서 바깥으로 일정한 픽셀만큼 부풀린 뒷면만 그린다 (cull_front) → 물체 둘레 + 다른 물체 위에 겹친 가장자리
// (처마가 벽 위로 · 잎 덩어리가 다른 덩어리 위로 · 머리가 몸 위로)에 고른 두께의 선. 깊이 차이 화면 셰이더(outline_post)는 그대로 둔다.
// 부풀리는 방향 = CUSTOM0.xyz (같은 자리 꼭짓점들의 평균 노멀, art/art.gd가 넣음) — 각진 상자 모서리에서 선이 끊기지 않게.
// CUSTOM0이 없는 메시(w = 0)는 그냥 NORMAL. 정사영 카메라라 1픽셀 = 2 / (P[1][1] × 화면 높이) 세계 단위.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled, shadows_disabled, ambient_light_disabled, specular_disabled;

uniform vec3 albedo : source_color = vec3(1.0);
uniform vec3 line_mul : source_color = vec3(0.25, 0.42, 0.43);
uniform bool use_vertex_color = true;
uniform vec3 fixed_color : source_color = vec3(0.3, 0.22, 0.18);   // use_vertex_color = false일 때 (주민)
uniform float width_px_1080p = 1.6;
uniform float push_back = 0.06;      // 껍데기를 조금 뒤로 → 자기 면을 덮지 않음 (세계 단위)
// 7단계: 주민 대머리 — 지운 머리카락의 껍데기도 지운다 (render/resident.gdshader와 같은 규칙, 머리 부품만)
uniform int bald = 0;
instance uniform float part_head = 0.0;
varying vec3 lp;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	lp = VERTEX;
	vec3 n = CUSTOM0.w > 0.5 ? CUSTOM0.xyz : NORMAL;
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 nv = mat3(MODELVIEW_MATRIX) * n;
	float upp = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float w = max(0.75, width_px_1080p * VIEWPORT_SIZE.y / 1920.0) * upp;
	float l = length(nv.xy);
	if (l > 1e-5) {
		vp.xy += nv.xy / l * w * min(1.0, l * 4.0);
	}
	vp.z -= push_back;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	if (bald > 0 && part_head > 0.5 && COLOR.r < 0.03 && COLOR.g > 0.97) {
		if ((bald == 1 && length(lp - vec3(0.0, 0.64, -0.08)) < 0.19) || (bald == 2 && lp.y > 0.37 + 0.3 * clamp(-lp.z, 0.0, 0.3))) {
			discard;
		}
	}
	vec3 c = use_vertex_color ? albedo * srgb_to_linear(COLOR.rgb) : srgb_to_linear(fixed_color);
	ALBEDO = c * line_mul;
}
