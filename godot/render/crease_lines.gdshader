// 접힌 곳 선 — RENDERING.md v2 2.4 (5단계)
// 모델의 각진 모서리(지붕 끝·벽 모서리·문틀·돌 쌓은 선)를 화면 공간 고른 두께의 띠로. 메시는 art/art.gd가 만든다:
// 모서리마다 사각형 하나, 꼭짓점 = 모서리 한쪽 끝 A, CUSTOM0.xyz = 다른 쪽 끝 B, CUSTOM0.w = 옆 방향(±1).
// 화면에서 A→B 방향의 수직으로 펴고 끝을 반 폭 늘려 이음매를 덮는다. 카메라 쪽으로 조금 당겨(bias) 자기 면 위에 보이게,
// 앞을 가리는 물체 뒤에선 깊이 시험으로 숨는다. 색 = 모서리 양쪽 면 중 짙은 색 × line_mul.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled, shadows_disabled, ambient_light_disabled, specular_disabled;

uniform vec3 line_mul : source_color = vec3(0.25, 0.42, 0.43);
uniform float width_px_1080p = 1.8;
uniform float bias = 0.035;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	vec4 a = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 b = MODELVIEW_MATRIX * vec4(CUSTOM0.xyz, 1.0);
	vec2 d = b.xy - a.xy;
	float l = length(d);
	vec2 dir = l > 1e-6 ? d / l : vec2(1.0, 0.0);
	vec2 perp = vec2(-dir.y, dir.x);
	float upp = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float hw = 0.5 * max(1.0, width_px_1080p * VIEWPORT_SIZE.y / 1920.0) * upp;
	a.xy += perp * CUSTOM0.w * hw - dir * hw;
	a.z += bias;
	POSITION = PROJECTION_MATRIX * a;
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb) * line_mul;
}
