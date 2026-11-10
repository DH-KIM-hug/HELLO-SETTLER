// 아이들 놀이의 납작한 그림 (view/kids_view.gd — 땅에 그은 사방치기 칸 · 물 위의 물수제비 고리).
// 땅·물 위에 눕힌 작은 판. 섞지 않고(불투명) 잘라 내기만 한다 — 인형·물과 그리는 차례가 엇갈리지 않는다.
//   · reveal: 긋는 중 (UV.x가 이 값을 넘는 곳은 아직 없음)
//   · tint.a: 닳아 없어지는 정도 (0 = 온전 · 1 = 사라짐 — 낟알처럼 흩어지며 지워짐)
//   · 색: 꼭짓점 COLOR.r로 두 색을 고름 (0 = 바탕 · 1 = 금)
// 빛 = 소품 그림(kid_card)과 같음.
shader_type spatial;
render_mode cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque, shadows_disabled;

uniform vec3 col_fill : source_color = vec3(0.93, 0.87, 0.72);
uniform vec3 col_line : source_color = vec3(0.42, 0.29, 0.18);
uniform vec3 lit_tint : source_color = vec3(1.0);
uniform vec3 shade_tint : source_color = vec3(0.55, 0.76, 0.87);
uniform float self_lit = 0.5;
uniform float grain = 30.0;            // 닳는 낟알 크기 (칸마다 몇 낟알)

instance uniform vec4 tint = vec4(1.0, 1.0, 1.0, 0.0);
instance uniform float reveal = 1.0;

varying vec2 v_w;

void vertex() {
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	if (UV.x > reveal) {
		discard;
	}
	if (tint.a > 0.0) {
		float n = fract(sin(dot(floor(v_w * grain), vec2(12.9898, 78.233))) * 43758.5453);
		if (n < tint.a) {
			discard;
		}
	}
	ALBEDO = mix(col_fill, col_line, COLOR.r) * tint.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float lit = step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += mix(mix(shade_tint, lit_tint, lit), vec3(1.0), self_lit * (1.0 - lit));
}
