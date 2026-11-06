// 주민 셰이더 — 공용 툰 빛(toon_light.gdshaderinc) + 부품 색 바꾸기 (5단계, art/src/build_residents.py).
// 모델의 꼭짓점 색(sRGB)이 열쇠 색이면 이 주민의 색으로 바꾼다 (파랑 채널 = 밝기):
//   (0, 0, b) 옷   (1, 0, b) 피부   (0, 1, b) 머리카락   (0, 0.5, b) 머릿수건·모자
// 그 밖의 색(신발·허리띠·앞치마·밀짚·눈·짐)은 그대로. 주민 한 명 = 재질 하나 (색은 view/resident_model.gd가 정함).
// 7단계 — 겉모습 유전자 (docs/BLOODLINES.md 7장, data/genetics.gd):
//   점 눈(고정색 LOOK_EYE) → 눈 색 (왼쪽·오른쪽 따로 = 짝짝이 눈) · 볼(고정색) → cheek (혈통 '강인한' 붉은 뺨 / '병약' 창백)
//   주근깨 = 얼굴 피부의 작은 점 무늬 · 대머리 = 머리카락을 정수리부터 지움(아래 두피가 보임) · 흰 앞머리 한 줌 ·
//   점박이 = 피부·머리에 하얀 얼룩 무늬 (무늬 시드) · 맨발 (혈통 '물가 사람') = 신발 색 → 피부.
// 머리 부품(얼굴·머리카락·모자·수염)은 instance uniform part_head = 1 (부품 좌표: 목 관절 원점, +Y 위, +Z 앞).
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

#include "res://render/toon_light.gdshaderinc"

uniform vec3 cloth : source_color = vec3(0.27, 0.46, 0.62);
uniform vec3 skin : source_color = vec3(0.93, 0.69, 0.43);
uniform vec3 hair : source_color = vec3(0.33, 0.22, 0.15);
uniform vec3 accent : source_color = vec3(0.89, 0.87, 0.85);
uniform vec3 eye_l : source_color = vec3(0.145, 0.129, 0.133);
uniform vec3 eye_r : source_color = vec3(0.145, 0.129, 0.133);
uniform vec3 cheek : source_color = vec3(0.94, 0.62, 0.55);
uniform vec3 freckle_col : source_color = vec3(0.65, 0.39, 0.25);
uniform float freckles = 0.0;          // 0 없음 ~ 1 진함
uniform int bald = 0;                  // 0 온전 · 1 정수리 · 2 대머리
uniform float forelock = 0.0;          // 흰 앞머리
uniform float barefoot = 0.0;
uniform float piebald = 0.0;
uniform vec4 pb_pattern = vec4(0.0, 0.0, 0.0, 3.0);   // xyz 무늬 자리, w 무늬 크기(빈도)
uniform float pb_cut = 0.62;           // 이 값보다 큰 곳이 하얀 무늬
uniform vec3 pb_skin : source_color = vec3(0.97, 0.94, 0.91);
uniform vec3 pb_hair : source_color = vec3(0.96, 0.95, 0.92);
instance uniform float part_head = 0.0;

varying vec3 lp;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1, 0, 0));
	float n010 = hash3(i + vec3(0, 1, 0));
	float n110 = hash3(i + vec3(1, 1, 0));
	float n001 = hash3(i + vec3(0, 0, 1));
	float n101 = hash3(i + vec3(1, 0, 1));
	float n011 = hash3(i + vec3(0, 1, 1));
	float n111 = hash3(i + vec3(1, 1, 1));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y), mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

bool near_col(vec3 k, vec3 ref) {
	return all(lessThan(abs(k - ref), vec3(0.025)));
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	vec3 k = COLOR.rgb;
	vec3 c = srgb_to_linear(k);
	bool head = part_head > 0.5;
	// 점박이 무늬 (부품 좌표 + 사람마다 다른 자리·크기)
	float pb = 0.0;
	if (piebald > 0.5) {
		vec3 q = (lp + vec3(part_head * 3.1, 0.0, 0.0)) * pb_pattern.w + pb_pattern.xyz;
		pb = step(pb_cut, vnoise(q) * 0.7 + vnoise(q * 2.3 + 7.0) * 0.3);
	}
	if (k.r < 0.03 && k.g < 0.03) {
		c = cloth * srgb_to_linear(vec3(k.b));
	} else if (k.r > 0.97 && k.g < 0.03) {
		vec3 s = skin;
		if (head && freckles > 0.0 && lp.z > 0.17 && lp.y > 0.15 && lp.y < 0.3 && abs(lp.x) > 0.045 && abs(lp.x) < 0.25) {
			vec3 g = lp * 26.0;
			vec3 cell = floor(g);
			float h = hash3(cell + 0.5);
			float d = length(fract(g) - 0.5);
			float dot_on = step(h, 0.5) * step(d, 0.36);
			s = mix(s, freckle_col, dot_on * freckles);
		}
		s = mix(s, pb_skin, pb);
		c = s * srgb_to_linear(vec3(k.b));
	} else if (k.r < 0.03 && k.g > 0.97) {
		if (head && bald > 0) {
			// 정수리부터 빠짐: 1 = 정수리 동그라미, 2 = 귀 위 전부 (뒤통수는 조금 더 남음)
			if (bald == 1 && length(lp - vec3(0.0, 0.64, -0.08)) < 0.19) {
				discard;
			}
			if (bald == 2 && lp.y > 0.37 + 0.3 * clamp(-lp.z, 0.0, 0.3)) {
				discard;
			}
		}
		vec3 hc = hair;
		if (head && forelock > 0.5 && lp.z > 0.1 && lp.y > 0.42 && lp.x > -0.17 && lp.x < 0.01) {
			hc = pb_hair;
		}
		hc = mix(hc, pb_hair, pb);
		c = hc * srgb_to_linear(vec3(k.b));
	} else if (k.r < 0.03 && abs(k.g - 0.5) < 0.05) {
		c = accent * srgb_to_linear(vec3(k.b));
	} else if (near_col(k, vec3(0.145, 0.129, 0.133))) {        // 점 눈 (Balance.LOOK_FIXED.eye)
		c = lp.x < 0.0 ? eye_l : eye_r;
	} else if (near_col(k, vec3(0.94, 0.62, 0.55))) {           // 볼
		c = cheek;
	} else if (barefoot > 0.5 && near_col(k, vec3(0.204, 0.141, 0.098))) {   // 신발 → 맨발
		c = skin * 0.92;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
