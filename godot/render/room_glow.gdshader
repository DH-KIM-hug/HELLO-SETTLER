// 거인의 방 빛 (더하기): 등불 불꽃 둘레의 둥근 빛 · 창에서 들어오는 빛줄기. 빛을 받지 않음.
// shape 0 = 둥근 빛 (늘 카메라를 봄) · 1 = 빛줄기 (UV.y 0 창 쪽 → 1 끝, 가장자리로 갈수록 옅게)
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 glow_col : source_color = vec3(1.0, 0.8, 0.45);
uniform float strength = 0.5;
uniform int shape = 0;

void vertex() {
	if (shape == 0) {
		float sc = length(MODEL_MATRIX[0].xyz);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sc, INV_VIEW_MATRIX[1] * sc, INV_VIEW_MATRIX[2] * sc, MODEL_MATRIX[3]);
	}
}

void fragment() {
	float a;
	if (shape == 0) {
		float d = length(UV - 0.5) * 2.0;
		a = pow(max(0.0, 1.0 - d), 2.2);
	} else {
		float edge = 1.0 - pow(abs(UV.x - 0.5) * 2.0, 2.0);
		a = max(0.0, edge) * (1.0 - UV.y) * smoothstep(0.0, 0.1, UV.y);
	}
	ALBEDO = glow_col * a * strength;
}
