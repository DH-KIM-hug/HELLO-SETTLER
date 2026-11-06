// 마무리 화면 셰이더 — RENDERING.md v2 2.3 색 · 2.4 외곽선 · 2.8 유리
// 화면 전체 사각형. 불투명 단계까지 그려진 화면을 읽어서:
//   1) 외곽선: 깊이가 갑자기 멀어지는 곳(물체 가장자리)에 고른 두께의 선 — 색은 그 물체 색 × line_mul (짙은 청록)
//      (1단계 pixel_post.gdshader의 깊이 차이 부분. 팔레트·디더링은 없앰 — Mobile 렌더러엔 화면 노멀이 없어 깊이만 씀)
//   2) 낮·밤 전체 색 조정: 밤 = 남색 (night_amount 0~1)
//   3) 화면 가장자리 유리: 왼쪽 위 구석을 지나는 옅은 곡선 테두리 + 흰 하이라이트 두 줄
// 반투명 물체(유리벽)는 render_priority가 더 높아 이 사각형 뒤에 그려진다.
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform bool use_outline = true;
uniform float line_px_1080p = 2.0;
uniform float gap = 0.22;
uniform vec3 line_mul : source_color = vec3(0.25, 0.4, 0.42);
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 night_mul : source_color = vec3(0.3, 0.37, 0.6);
uniform vec3 night_add : source_color = vec3(0.01, 0.02, 0.05);
uniform bool use_glass = true;
uniform vec2 arc_center = vec2(0.4, 0.7);
uniform float arc_radius = 0.755;
uniform float arc_tint = 0.3;

void vertex() {
	// 카메라 바로 앞 화면 전체 (역방향 깊이: 1.0 = 가장 가까움)
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col = texture(screen_tex, uv).rgb;

	if (use_outline) {
		float lp = max(1.0, line_px_1080p * VIEWPORT_SIZE.y / 1920.0);
		vec2 px = lp / VIEWPORT_SIZE;
		float d = view_depth(uv, INV_PROJECTION_MATRIX);
		float g = 0.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.785398;
			vec2 o = vec2(cos(a), sin(a)) * px;
			g = max(g, view_depth(uv + o, INV_PROJECTION_MATRIX) - d);
		}
		float e = smoothstep(gap, gap * 1.6, g);
		col = mix(col, col * line_mul, e);
	}

	col = mix(col, col * night_mul + night_add, night_amount);

	if (use_glass) {
		float asp = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
		vec2 p = vec2(uv.x * asp, uv.y);
		float r = length(p - arc_center);
		float pw = 1.0 / VIEWPORT_SIZE.y;
		float outside = smoothstep(arc_radius - pw, arc_radius + pw, r);
		col = mix(col, vec3(0.92, 0.98, 0.98), outside * arc_tint);
		float l1 = 1.0 - smoothstep(pw * 1.2, pw * 2.4, abs(r - arc_radius));
		float l2 = 1.0 - smoothstep(pw * 0.8, pw * 2.0, abs(r - arc_radius - 0.022));
		col = mix(col, vec3(1.0), max(l1 * 0.9, l2 * 0.75));
	}
	ALBEDO = col;
}
