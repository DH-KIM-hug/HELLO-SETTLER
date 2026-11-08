// 툰 + 높이 따라 엷어짐 — 반투명 패스 (toon_fade.gdshader의 next_pass): 엷어지는 윗부분을 제 색 그대로 반투명하게 (이삭은 금빛, 짚은 짚 색).
// 반투명이라 화면 마무리 셰이더(outline_post) 뒤에 그려진다 → 엷은 부분엔 먹선이 없고, 밤 색 조정은 여기서 같은 식으로
// (night_amount — ToonFade.set_night가 넣음): col × (1 − n + n·night_mul) + n·night_add. 빛은 꼭짓점 색에 곱으로 걸리므로
// 곱하는 몫은 ALBEDO에, 더하는 몫은 EMISSION에. (모닥불 빛 웅덩이는 넣지 않음 — 키 큰 윗부분은 땅의 빛 웅덩이 밖.)
// depth_draw_always: 한 메시 안에서 앞 줄기가 먼저 그려지면 뒤 줄기를 덮는다 (겹친 곳이 두 겹으로 진해지는 일이 줄도록).
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back, blend_mix, depth_draw_always;

#include "res://render/toon_light.gdshaderinc"
#include "res://render/toon_fade.gdshaderinc"

uniform float night_amount = 0.0;
uniform vec3 night_mul : source_color = vec3(0.3, 0.37, 0.6);
uniform vec3 night_add : source_color = vec3(0.01, 0.02, 0.05);
// 불투명 패스가 끝나는 줄(fade_from · cut_from)의 맨 윗 화소는 깊이 외곽선이 먹선으로 칠한다 (위가 먼 바닥이라) →
// 이 패스가 그 아래 soft_overlap(모델 칸)만큼을 온전한 색(불투명도 1)으로 한 번 더 덮어 가로 먹줄을 지운다.
uniform float soft_overlap = 0.2;

void fragment() {
	float a = fade_alpha();
	if (a <= 0.004 || (a >= 0.999 && h < min(fade_from, cut_from) - soft_overlap)) {
		discard;
	}
	ALBEDO = albedo * srgb_to_linear(COLOR.rgb) * mix(vec3(1.0), night_mul, night_amount);
	EMISSION = night_add * night_amount;
	ALPHA = a;
	ROUGHNESS = 1.0;
}
