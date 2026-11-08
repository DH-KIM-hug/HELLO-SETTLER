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
// 위쪽 끊기 (초거대 해바라기 마을 확대 — 줄기가 화면 위로 사라짐): cut_from~cut_to 사이에서 0까지 엷어짐. 기본값 = 끊지 않음
uniform float cut_from = 100000.0;
uniform float cut_to = 100001.0;
uniform float y_offset = 0.0;       // 부품 원점의 모델 높이 (꽃판처럼 원점이 발이 아닌 부품)
// 위로 늘이기 (초거대 해바라기 마을 시점): stretch_from 위의 꼭짓점을 stretch배로 위로 — 줄기가 늘 화면 위로 빠져나가게. 1 = 그대로
uniform float stretch_from = 0.0;
uniform float stretch = 1.0;
varying float h;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	h = VERTEX.y + y_offset;
	if (stretch > 1.0 && h > stretch_from) {
		VERTEX.y += (h - stretch_from) * (stretch - 1.0);
	}
}

void fragment() {
	float a = mix(1.0, min_alpha, smoothstep(fade_from, fade_to, h));
	a = min(a, 1.0 - smoothstep(cut_from, cut_to, h));
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
