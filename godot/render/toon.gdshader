// 공용 툰 셰이더 — 건물·나무·주민·소품·동물 (RENDERING.md v2 2.3).
// 색 = albedo × 꼭짓점 색(있으면, sRGB). 빛은 toon_light.gdshaderinc (밝은 면 + 그늘 한 단계).
// 동물 v2 (art/src/build_animals.py): 손으로 그린 털·깃털·비늘 결 = 회색 그림 묶음 animal_tex (art/models/animal_fur.png,
//   art/src/pack_animal_atlas.py, 4 × 2칸). 동물 꼭짓점만 UV.x ≥ 50 (100을 더해 둠 = 표시) — 그 밖의 모델은 그대로.
//   꼭짓점 색 알파 = 칸 번호 ((칸 + 0.5) / 32, 1 = 결 없음), UV - (100, 0) = 칸 안의 무늬 자리 (되풀이). 색 = 물들인 색 × 결.
//   화면에서 아주 작아지면(멀리) 결을 줄여 반짝이지 않게 · 결 있는 곳은 그늘을 조금 따뜻하게 (render/resident.gdshader와 같은 규칙).
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

#define TOON_WARM
#include "res://render/toon_light.gdshaderinc"

uniform vec3 albedo : source_color = vec3(1.0);
uniform sampler2D animal_tex : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float animal_detail = 1.0;
uniform float animal_warm = 0.6;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 c = albedo * srgb_to_linear(COLOR.rgb);
	warm_shade = 0.0;
	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	if (UV.x > 50.0 && COLOR.a < 0.985) {
		int cell = int(COLOR.a * 32.0) % 8;
		vec2 base = vec2(float(cell % 4), float(cell / 4));
		const vec2 ATL = vec2(512.0, 256.0);
		const vec2 S = vec2(120.0) / ATL;
		vec2 auv = (base * 128.0 + 4.0) / ATL + fract(UV) * S;
		float t = textureGrad(animal_tex, auv, dx * S, dy * S).r;
		float tpp = max(length(dx * S * ATL), length(dy * S * ATL));
		float fade = 1.0 - smoothstep(2.5, 7.0, tpp);
		c *= mix(1.0, t * 1.4, animal_detail * fade);
		warm_shade = animal_warm;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
