// 툰 + 높이 따라 엷어짐 (가림 겹 1 — 아트 바이블 6.4 · buildings GDD Visual): 밀 숲 줄기의 윗부분(모델 높이 fade_from 위)을
// 화면 문 무늬(4×4 디더)로 비워, 그 아래 주민·길이 늘 보이게. 그림자는 view가 따로 그림자 전용 쌍둥이(Art.flat_mat)로 드리운다
// (그림자 패스에서 discard가 그림자에 구멍을 내지 않게 — 이 재질을 쓰는 메시는 cast_shadow OFF).
// 빛·색은 toon.gdshader와 같음 (꼭짓점 색 sRGB × albedo, toon_light.gdshaderinc). 동물 결 그림은 없음.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

#include "res://render/toon_light.gdshaderinc"

uniform vec3 albedo : source_color = vec3(1.0);
uniform float fade_from = 6.0;      // 모델 높이 (칸) — 여기서부터 엷어지기 시작
uniform float fade_to = 9.0;        // 여기부터 min_alpha
uniform float min_alpha = 0.35;     // 가장 엷을 때 남는 몫 (디더 칸의 비율)
varying float h;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	h = VERTEX.y;
}

void fragment() {
	float a = mix(1.0, min_alpha, smoothstep(fade_from, fade_to, h));
	if (a < 0.999) {
		const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		if ((BAYER[p.y * 4 + p.x] + 0.5) / 16.0 > a) {
			discard;
		}
	}
	ALBEDO = albedo * srgb_to_linear(COLOR.rgb);
	ROUGHNESS = 1.0;
}
