// 거인의 방 바닥 그림자 (blob) — 소품 아래 부드러운 둥근 그림자 (곱하기). view/room/giant_room.gd _make_blobs.
// 창빛 실제 그림자 대신: 타이틀(s = 1)과 넓은 세상 장면(s ≈ 91 — 그림자 맵이 어긋남)에서 똑같이 보이게, 휴대폰에서 그림자 맵 없이.
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 shade_col : source_color = vec3(0.66, 0.55, 0.5);
uniform float strength = 0.75;

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r = length(d);
	float a = (1.0 - smoothstep(0.25, 1.0, r)) * strength;
	ALBEDO = mix(vec3(1.0), shade_col, a);
}
