// 툰 + 높이 따라 엷어짐 (가림 겹 — 아트 바이블 6.4 · buildings GDD Visual) — 불투명 패스: 엷어지지 않는 아랫부분만 그린다.
// 엷어지는 윗부분은 next_pass의 반투명 쌍둥이(toon_fade_soft.gdshader)가 진짜 반투명으로 그린다.
// (예전엔 여기서 화면 4×4 디더로 구멍을 냈는데, 깊이 외곽선(outline_post)이 구멍 곁에 남은 화소를 모두 먹선으로 칠해
//  밀 이삭의 금빛이 검은 점으로만 보였다 — 2026-11-08.) 공통 부분: toon_fade.gdshaderinc. 짝 만들기: render/toon_fade.gd.
// 그림자는 view가 따로 그림자 전용 쌍둥이(Art.flat_mat)로 드리운다 (이 재질을 쓰는 메시는 cast_shadow OFF).
// 빛·색은 toon.gdshader와 같음 (꼭짓점 색 sRGB × albedo, toon_light.gdshaderinc).
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

#include "res://render/toon_light.gdshaderinc"
#include "res://render/toon_fade.gdshaderinc"

void fragment() {
	if (fade_alpha() < 0.999) {
		discard;
	}
	ALBEDO = albedo * srgb_to_linear(COLOR.rgb);
	ROUGHNESS = 1.0;
}
