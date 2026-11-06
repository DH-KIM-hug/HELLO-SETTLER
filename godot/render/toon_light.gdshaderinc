// 공용 셀 채색 빛 — RENDERING.md v2 2.3
// 빛은 창가 한쪽(해 하나)에서만: 밝은 면 + 그늘 한 단계. 그림자 맵도 같은 그늘 색 한 단계로 (부드러운 그림자 없음).
// 그늘 색은 검정을 섞지 않고 원래 색 × shade_tint (청록 쪽). 값은 data/style.gd → render/toon.gd가 넣는다.
// 쓰는 셰이더: toon.gdshader (건물·나무·주민·소품), terrain.gdshader, water.gdshader.
// view_fill (5단계, 물체만): 기준 그림은 빛을 속여 카메라 쪽 앞벽·지붕 앞면을 밝게 그린다 → 밝은 면 판정에 쓰는 빛 방향을
// 카메라 쪽으로 조금 기울인다 (LIGHT + VIEW × view_fill). 해를 등지거나 비스듬한 면(N·L ≤ 0.3)은 자기 몸 그림자를 무시 —
// 그 면은 자기 그림자 속이거나 그림자 맵 얼룩(acne)이 생기기 때문. 땅·물은 0 (그대로).
uniform vec3 lit_tint : source_color = vec3(1.0);
uniform vec3 shade_tint : source_color = vec3(0.55, 0.76, 0.87);
uniform float lit_threshold = 0.08;
uniform float view_fill = 0.0;
// TOON_WARM (toon.gdshader만): 손그림 결이 있는 동물 털은 그늘을 따뜻한 회색 쪽으로 (주민 머리카락과 같은 규칙 — 흰 양이 파랗지 않게).
#ifdef TOON_WARM
uniform vec3 warm_shade_tint : source_color = vec3(0.74, 0.69, 0.68);
varying float warm_shade;
#endif

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ndl_f = view_fill > 0.0 ? dot(NORMAL, normalize(LIGHT + VIEW * view_fill)) : ndl;
	float shadow = (view_fill > 0.0 && ndl <= 0.3) ? 1.0 : step(0.5, ATTENUATION);
	float lit = step(lit_threshold, ndl_f) * shadow;
#ifdef TOON_WARM
	vec3 sh = mix(shade_tint, warm_shade_tint, warm_shade);
#else
	vec3 sh = shade_tint;
#endif
	DIFFUSE_LIGHT += mix(sh, lit_tint, lit);
}
