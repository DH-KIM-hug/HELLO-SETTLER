// 건물 그림(view/ui/building_thumb.gd) 마무리 — outline_post.gdshader의 깊이 외곽선만, 투명 바탕을 지킨다.
// 바탕(아무것도 없는 화소, 역방향 깊이 0)은 버려서 투명 그대로 · 물체 화소는 외곽선을 입혀 불투명하게.
// 유리 테두리·밤 색·모닥불 빛은 없음 (카드 그림은 늘 낮).
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float line_px = 2.0;          // 이 화면 화소 단위 그대로 (해상도 비례 없음 — building_thumb.gd가 정함)
uniform float gap = 0.22;
uniform vec3 line_mul : source_color = vec3(0.25, 0.4, 0.42);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float view_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return -v.z / v.w;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (texture(depth_tex, uv).r <= 0.0) {
		discard;
	}
	vec3 col = texture(screen_tex, uv).rgb;
	vec2 px = max(1.0, line_px) / VIEWPORT_SIZE;
	float d = view_depth(uv, INV_PROJECTION_MATRIX);
	float g = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 o = vec2(cos(a), sin(a)) * px;
		g = max(g, view_depth(uv + o, INV_PROJECTION_MATRIX) - d);
	}
	float e = smoothstep(gap, gap * 1.6, g);
	ALBEDO = mix(col, col * line_mul, e);
	ALPHA = 1.0;
}
