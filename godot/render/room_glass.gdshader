// 거인의 방 유리병 · 등불 유리 (GIANT_ROOM 5 — 유리 셰이더). view/room/giant_room.gd가 붙인다.
// 반투명 (화면 셰이더 outline_post 뒤에 그려짐 → 방 색은 tint_mul로 따로 받음). 양면을 그린다 — 병 안(③)에서 보면 먼 쪽 벽 안쪽 면.
//   · 가장자리 빛 (rim): 유리를 비스듬히 볼수록 하얗게
//   · 하이라이트 줄: 모델의 흰 꼭짓점 색 (build_room.py — 앞 왼쪽 긴 줄 두 개)
//   · haze: 병 안에서 유리 너머를 볼 때 (③) 방이 흐릿하게 비치게 — 0 = 맑음
//   · mist: 김 서림 (아래쪽부터, 0~1)
// 굴절은 화면 셰이더가 한다 (outline_post refract — 병 안 화소만 가운데 쪽으로 조금 당김).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 glass_col : source_color = vec3(0.86, 0.95, 0.95);
uniform vec3 tint_mul : source_color = vec3(1.0);
uniform float base_alpha = 0.03;
uniform float rim_alpha = 0.34;
uniform float hi_alpha = 0.55;
uniform float haze = 0.0;
uniform vec3 haze_col : source_color = vec3(0.84, 0.92, 0.93);
uniform float mist = 0.0;
uniform float y_lo = 0.0;          // 김 서림 높이 범위 (모델 단위)
uniform float y_hi = 13.0;
varying float ly;

void vertex() {
	ly = VERTEX.y;
}

void fragment() {
	float hi = smoothstep(0.92, 0.99, COLOR.r * COLOR.g * COLOR.b);
	float ndv = abs(dot(NORMAL, VIEW));
	float rim = pow(1.0 - ndv, 3.0);
	float m = mist * (1.0 - smoothstep(y_lo, y_hi, ly)) * 0.5;
	vec3 c = mix(glass_col, vec3(1.0), hi);
	c = mix(c, haze_col, clamp(haze, 0.0, 1.0) * 0.7);
	ALBEDO = c * tint_mul;
	ALPHA = clamp(base_alpha + rim * rim_alpha + hi * hi_alpha * (1.0 - haze * 0.6) + haze * 0.5 + m, 0.0, 0.92);
}
