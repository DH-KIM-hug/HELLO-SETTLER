// 유리 하이라이트 줄 — RENDERING.md 2.8 ("유리 테두리 하이라이트 밝은 픽셀 줄 2개", "세상 끝 유리벽은 빛나는 픽셀 띠")
// 투명 물체는 도트 마무리(pixel_post)가 읽는 화면에 들어가지 않으므로 불투명한 밝은 줄로 그린다.
// far_only: 카메라 반대편(먼 쪽) 절반만 — 가까운 쪽 벽 꼭대기 줄이 마을을 가로지르지 않게.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.984, 0.918);
uniform bool far_only = false;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (far_only) {
		vec2 cam = CAMERA_POSITION_WORLD.xz;
		if (dot(world_pos.xz, cam) > 0.0) {
			discard;
		}
	}
	ALBEDO = color;
}
