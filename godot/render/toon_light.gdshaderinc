// 공용 셀 채색 빛 — RENDERING.md v2 2.3
// 빛은 창가 한쪽(해 하나)에서만: 밝은 면 + 그늘 한 단계. 그림자 맵도 같은 그늘 색 한 단계로 (부드러운 그림자 없음).
// 그늘 색은 검정을 섞지 않고 원래 색 × shade_tint (청록 쪽). 값은 data/style.gd → render/toon.gd가 넣는다.
// 쓰는 셰이더: toon.gdshader (건물·나무·주민·소품), terrain.gdshader, water.gdshader.
uniform vec3 lit_tint : source_color = vec3(1.0);
uniform vec3 shade_tint : source_color = vec3(0.55, 0.76, 0.87);
uniform float lit_threshold = 0.08;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = step(lit_threshold, ndl) * step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += mix(shade_tint, lit_tint, lit);
}
