// 주민 셰이더 — 공용 툰 빛(toon_light.gdshaderinc) + 부품 색 바꾸기 (5단계, art/src/build_residents.py).
// 모델의 꼭짓점 색(sRGB)이 열쇠 색이면 이 주민의 색으로 바꾼다 (파랑 채널 = 밝기):
//   (0, 0, b) 옷   (1, 0, b) 피부   (0, 1, b) 머리카락   (0, 0.5, b) 머릿수건·모자
// 그 밖의 색(신발·허리띠·앞치마·밀짚·눈·짐)은 그대로. 주민 한 명 = 재질 하나 (색은 view/resident_model.gd가 정함).
// 7단계 — 겉모습 유전자 (docs/BLOODLINES.md 7장, data/genetics.gd):
//   점 눈(고정색 LOOK_EYE) → 눈 색 (왼쪽·오른쪽 따로 = 짝짝이 눈) · 볼(고정색) → cheek (혈통 '강인한' 붉은 뺨 / '병약' 창백)
//   주근깨 = 얼굴 피부의 작은 점 무늬 · 대머리 = 머리카락을 정수리부터 지움(아래 두피가 보임) · 흰 앞머리 한 줌 ·
//   점박이 = 피부·머리에 하얀 얼룩 무늬 (무늬 시드) · 맨발 (혈통 '물가 사람') = 신발 색 → 피부.
// A20 v3: 머리 피부는 노멀을 카메라 쪽으로 기울임 (얼굴에 그늘 경계가 지나가지 않게 — 시트의 평평하게 밝은 얼굴).
// A20: 표정 앓음 = sick (피부를 연둣빛 잿빛으로 조금). 감은 눈·눈썹·입은 고정색(LOOK_FIXED lash · mouth)이라 그대로.
// A20 v3: 주민 몸은 뼈대로 움직이는 매끈한 메시 하나 (view/resident_model.gd가 부품을 합침). CUSTOM1 = 쉴 때 자리
//   (xyz, 머리 부품은 목 관절 원점) + w = 머리 부품(1). 얼굴 = 그림 묶음(art/models/resident_face.png, art/src/paint_face_atlas.py)을
//   앞에서 비춘 UV로 — 채널: R 먹선 · G 눈동자(유전자 눈 색, 늘 짙게) · B 흰 반짝임 · A 볼 홍조(+먹 = 벌린 입 안).
//   표정 = 칸 번호 face_cell (0 보통 1 기쁨 2 슬픔 3 앓음 4 잠 5 놀람 6 말함, 7 = 눈 깜빡임 — 시간으로 가끔).
//   (0, 0.25, b) = 노인 숄 색. messy = 혈통 '부스스한 머리' (머리카락을 바깥으로 조금 부풀림).
//   소품(짐·연장·지팡이)은 CUSTOM1이 없음 → 0 = 머리 부품 아님.
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
uniform float sick = 0.0;              // A20 표정 '앓음': 피부를 조금 핼쑥하게 (ResidentModel.set_face)
uniform vec3 shawl : source_color = vec3(0.49, 0.54, 0.41);
uniform sampler2D face_tex : filter_linear_mipmap, repeat_disable;
uniform int face_cell = 0;
uniform float blink_seed = 0.0;        // 사람마다 깜빡이는 때가 다르게
uniform float messy = 0.0;
uniform vec4 pb_pattern = vec4(0.0, 0.0, 0.0, 3.0);   // xyz 무늬 자리, w 무늬 크기(빈도)
uniform float pb_cut = 0.62;           // 이 값보다 큰 곳이 하얀 무늬
uniform vec3 pb_skin : source_color = vec3(0.97, 0.94, 0.91);
uniform vec3 pb_hair : source_color = vec3(0.96, 0.95, 0.92);
varying vec3 lp;
varying float part_head;

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
	lp = CUSTOM1.xyz;
	part_head = CUSTOM1.w;
	if (messy > 0.0 && part_head > 0.5 && COLOR.r < 0.03 && COLOR.g > 0.97) {
		VERTEX += NORMAL * messy * (0.02 + 0.04 * vnoise(lp * 14.0));
	}
}

// 얼굴 그림: 피부 위에 홍조 → 흰자·반짝임 → 눈동자 → 먹선
vec3 face(vec3 s, vec2 uv, float t, vec3 eye) {
	int cell = face_cell;
	if ((cell == 0 || cell == 2 || cell == 6) && fract(t * 0.23 + blink_seed) < 0.035) {
		cell = 7;
	}
	vec2 auv = (vec2(float(cell % 2), float(cell / 2)) + clamp(uv, vec2(0.004), vec2(0.996))) * vec2(0.5, 0.25);
	vec4 f = texture(face_tex, auv);
	vec3 ink = vec3(0.075, 0.045, 0.035);
	s = mix(s, cheek * 0.95, f.a * 0.85);
	s = mix(s, vec3(0.97, 0.95, 0.92), f.b * (1.0 - f.g));
	s = mix(s, eye, f.g);
	s = mix(s, vec3(1.0), f.b * f.g);
	s = mix(s, ink, f.r);
	return s;
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
		if (head && freckles > 0.0 && lp.z > 0.17 && lp.y > 0.17 && lp.y < 0.3 && abs(lp.x) > 0.045 && abs(lp.x) < 0.25) {
			vec3 g = lp * 26.0;
			vec3 cell = floor(g);
			float h = hash3(cell + 0.5);
			float d = length(fract(g) - 0.5);
			float dot_on = step(h, 0.5) * step(d, 0.36);
			s = mix(s, freckle_col, dot_on * freckles);
		}
		s = mix(s, pb_skin, pb);
		s = mix(s, vec3(0.62, 0.68, 0.5), sick * 0.3);
		s *= srgb_to_linear(vec3(k.b));
		if (head && UV.x >= 0.0 && UV.x <= 1.0 && UV.y >= 0.0 && UV.y <= 1.0) {
			s = face(s, UV, TIME, lp.x < 0.0 ? eye_l : eye_r);
		}
		if (head) {
			// 시트처럼 얼굴은 늘 밝게: 머리 피부의 노멀을 카메라 쪽으로 기울여 그늘 경계가 얼굴을 가로지르지 않게
			NORMAL = normalize(mix(NORMAL, VIEW, 0.7));
		}
		c = s;
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
	} else if (k.r < 0.03 && abs(k.g - 0.25) < 0.05) {
		c = shawl * srgb_to_linear(vec3(k.b));
	} else if (k.r < 0.03 && abs(k.g - 0.5) < 0.05) {
		c = accent * srgb_to_linear(vec3(k.b));
	} else if (near_col(k, vec3(0.145, 0.129, 0.133))) {        // 점 눈 (Balance.LOOK_FIXED.eye)
		c = lp.x < 0.0 ? eye_l : eye_r;
	} else if (near_col(k, vec3(0.94, 0.62, 0.55))) {           // 볼
		c = cheek;
	} else if (barefoot > 0.5 && near_col(k, vec3(0.290, 0.204, 0.149))) {   // 신발 (LOOK_FIXED.boot) → 맨발
		c = skin * 0.92;
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
