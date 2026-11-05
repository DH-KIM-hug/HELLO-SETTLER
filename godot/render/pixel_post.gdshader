// 도트 마무리 — RENDERING.md 2.3 색 · 2.4 외곽선
// 화면 전체를 덮는 사각형에 붙인다. 3D가 다 그려진 뒤의 화면을 읽어서:
//   1) 깊이가 갑자기 멀어지는 곳(물체의 가장자리)에 1픽셀 선 — 색은 그 물체 색을 어둡게
//   2) 4×4 디더링 점무늬를 섞어 팔레트(48색)의 가장 가까운 색으로 맞춘다
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D palette_tex : filter_nearest;   // 팔레트 색 N×1 (sRGB)
uniform int palette_size = 48;
uniform bool use_palette = true;
uniform bool use_outline = true;
uniform float dither_strength : hint_range(0.0, 0.3) = 0.07;
uniform float outline_gap = 0.9;      // 이웃 픽셀이 이만큼(세계 단위) 더 멀면 가장자리
uniform float outline_dark : hint_range(0.0, 1.0) = 0.55;

void vertex() {
	// 카메라 바로 앞 화면 전체 (4.3+ 역방향 깊이: 1.0 = 가장 가까움)
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

vec3 to_srgb(vec3 c) {
	c = clamp(c, 0.0, 1.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float bayer4(ivec2 p) {
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[(p.y & 3) * 4 + (p.x & 3)]) + 0.5) / 16.0;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, uv).rgb;

	if (use_outline) {
		float d = view_depth(uv, INV_PROJECTION_MATRIX);
		float far_gap = 0.0;
		far_gap = max(far_gap, view_depth(uv + vec2(px.x, 0.0), INV_PROJECTION_MATRIX) - d);
		far_gap = max(far_gap, view_depth(uv - vec2(px.x, 0.0), INV_PROJECTION_MATRIX) - d);
		far_gap = max(far_gap, view_depth(uv + vec2(0.0, px.y), INV_PROJECTION_MATRIX) - d);
		far_gap = max(far_gap, view_depth(uv - vec2(0.0, px.y), INV_PROJECTION_MATRIX) - d);
		if (far_gap > outline_gap) {
			col *= outline_dark;   // 검정이 아니라 그 물체 색의 어두운 버전
		}
	}

	if (use_palette) {
		vec3 s = to_srgb(col);
		s += (bayer4(ivec2(FRAGCOORD.xy)) - 0.5) * dither_strength;
		float best = 1e9;
		vec3 pick = s;
		for (int i = 0; i < palette_size; i++) {
			vec3 p = texelFetch(palette_tex, ivec2(i, 0), 0).rgb;
			vec3 dd = (s - p) * vec3(0.30, 0.59, 0.11);   // 밝기에 민감한 눈에 맞춘 거리
			float e = dot(dd, dd) + 0.25 * dot(s - p, s - p);
			if (e < best) { best = e; pick = p; }
		}
		col = to_linear(pick);
	}
	ALBEDO = col;
}
