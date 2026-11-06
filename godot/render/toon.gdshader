// 공용 툰 셰이더 — 건물·나무·주민·소품 (RENDERING.md v2 2.3).
// 색 = albedo × 꼭짓점 색(있으면, sRGB). 빛은 toon_light.gdshaderinc (밝은 면 + 그늘 한 단계).
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

#include "res://render/toon_light.gdshaderinc"

uniform vec3 albedo : source_color = vec3(1.0);

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	ALBEDO = albedo * srgb_to_linear(COLOR.rgb);
	ROUGHNESS = 1.0;
}
