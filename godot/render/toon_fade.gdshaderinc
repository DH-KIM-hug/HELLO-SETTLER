// 툰 + 높이 따라 엷어짐 — 두 패스가 함께 쓰는 부분 (toon_fade.gdshader = 불투명 아랫부분 · toon_fade_soft.gdshader = 반투명 윗부분).
// 모델 높이 fade_from 위는 엷어져서 그 아래 주민·길이 늘 보이게. render/toon_fade.gd(ToonFade)가 두 재질을 한 쌍(next_pass)으로 만든다.
uniform vec3 albedo : source_color = vec3(1.0);
uniform float fade_from = 6.0;      // 모델 높이 (칸) — 여기서부터 엷어지기 시작
uniform float fade_to = 9.0;        // 여기부터 min_alpha
uniform float min_alpha = 0.35;     // 가장 엷을 때 남는 불투명도
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

// 이 높이에서 남는 불투명도 (1 = 온전히, 0 = 사라짐)
float fade_alpha() {
	float a = mix(1.0, min_alpha, smoothstep(fade_from, fade_to, h));
	return min(a, 1.0 - smoothstep(cut_from, cut_to, h));
}
