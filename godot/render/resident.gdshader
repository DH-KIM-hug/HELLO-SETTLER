// 주민 셰이더 — 공용 툰 빛(toon_light.gdshaderinc) + 부품 색 바꾸기 (5단계, art/src/build_residents.py).
// 모델의 꼭짓점 색(sRGB)이 열쇠 색이면 이 주민의 색으로 바꾼다 (파랑 채널 = 밝기):
//   (0, 0, b) 옷   (1, 0, b) 피부   (0, 1, b) 머리카락   (0, 0.5, b) 머릿수건·모자
// 그 밖의 색(신발·허리띠·앞치마·밀짚·눈·짐)은 그대로. 주민 한 명 = 재질 하나 (색은 view/resident_model.gd가 Balance 색표에서).
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

#include "res://render/toon_light.gdshaderinc"

uniform vec3 cloth : source_color = vec3(0.27, 0.46, 0.62);
uniform vec3 skin : source_color = vec3(0.93, 0.69, 0.43);
uniform vec3 hair : source_color = vec3(0.33, 0.22, 0.15);
uniform vec3 accent : source_color = vec3(0.89, 0.87, 0.85);

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec3 k = COLOR.rgb;
	vec3 c = srgb_to_linear(k);
	if (k.r < 0.03 && k.g < 0.03) {
		c = cloth * srgb_to_linear(vec3(k.b));
	} else if (k.r > 0.97 && k.g < 0.03) {
		c = skin * srgb_to_linear(vec3(k.b));
	} else if (k.r < 0.03 && k.g > 0.97) {
		c = hair * srgb_to_linear(vec3(k.b));
	} else if (k.r < 0.03 && abs(k.g - 0.5) < 0.05) {
		c = accent * srgb_to_linear(vec3(k.b));
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
