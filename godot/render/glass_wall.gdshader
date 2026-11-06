// 세상 끝 유리벽 — RENDERING.md v2 2.8 (지구 시점)
// 옅은 반투명 띠(벽) + 땅 끝 테두리·벽 꼭대기 흰 하이라이트 줄 (view/jar_glass.gd가 띠 모양 메시를 만든다).
// far_only: 카메라 반대편(먼 쪽) 절반만 — 가까운 쪽 벽이 마을을 가리지 않게.
// 화면 셰이더(outline_post) 뒤에 그려지므로 밤 색 조정은 night_amount로 따로 받는다.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never, blend_mix;

uniform vec3 color : source_color = vec3(1.0);
uniform float alpha = 1.0;
uniform bool far_only = false;
uniform float night_amount = 0.0;
uniform vec3 night_mul : source_color = vec3(0.3, 0.37, 0.6);
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (far_only && dot(world_pos.xz, CAMERA_POSITION_WORLD.xz) > 0.0) {
		discard;
	}
	ALBEDO = mix(color, color * night_mul, night_amount * 0.8);
	ALPHA = alpha;
}
