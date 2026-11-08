// 나는 작은 생물 (나비·꿀벌) 멀리 LOD — MultiMesh 한 덩이에서 날개만 꼭짓점 셰이더로 퍼덕임 (view/fauna_view.gd, E3-12).
// 색·빛은 toon.gdshader와 같음 (꼭짓점 색 sRGB × albedo, toon_light 한 단계 그늘). 다음 패스 = critter_flap_hull.gdshader.
// 날개 표시: UV.y = -1 (왼 날개) · +1 (오른 날개) · 0 (몸) — fauna_view.gd template()가 넣음 (UV.x는 0 — 동물 결 표시 아님).
// 날개 각 = INSTANCE_CUSTOM.x (라디안, + = 날개 끝이 위로) — 화면이 매 화면 마리마다 넣음. 경첩 = hinge (모델 자리 |x|, y), 몸 긴 축(+Z) 둘레로 돎.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

#include "res://render/toon_light.gdshaderinc"

uniform vec3 albedo : source_color = vec3(1.0);
uniform vec2 hinge = vec2(0.035, 0.015);

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	float s = UV.y;
	if (abs(s) > 0.5) {
		float th = sign(s) * INSTANCE_CUSTOM.x;
		float c = cos(th);
		float sn = sin(th);
		vec2 h = vec2(sign(s) * hinge.x, hinge.y);
		vec2 d = VERTEX.xy - h;
		VERTEX.xy = h + vec2(d.x * c - d.y * sn, d.x * sn + d.y * c);
		NORMAL.xy = vec2(NORMAL.x * c - NORMAL.y * sn, NORMAL.x * sn + NORMAL.y * c);
	}
}

void fragment() {
	ALBEDO = albedo * srgb_to_linear(COLOR.rgb);
	ROUGHNESS = 1.0;
}
