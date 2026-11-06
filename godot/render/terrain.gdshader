// 땅 — RENDERING.md v2 2.3 · 2.4 · 2.7 + 기획서 4.4b 겉흙 12종 (A13, view/ground_look.gd)
// 꼭짓점 COLOR.rgb = 풀밭 바탕색 (sRGB, 칸 색을 꼭짓점으로 평균 → 부드럽게 바뀜). COLOR.a = 그늘 (눈·서리가 오래 남음)
// UV = (맨흙, 소금) · UV2 = (강, 바위) · CUSTOM0 = (모래·자갈 물가, 진흙·습지, 숲 바닥, 이끼) · CUSTOM1 = (마른 풀 바탕값, 폭포 웅덩이, -, -)
// 꼭짓점 사이에서 보간된 값을 (잡음으로 조금 흔든) 문턱으로 끊어 또렷한 곡선 경계의 평면 색으로 쌓는다 (칸 계단이 보이지 않게).
// 쌓는 순서 (뒤가 위): 풀 → 마른 풀 → 이끼 → 숲 바닥 → 물가 → 맨흙 → 진흙 → 바위 → 오솔길/돌길 → 소금 → 눈 → 강.
// 오솔길은 무리마다 오솔길 지도 텍스처 (path_tex[i], 사각형 path_rect[i] = (x0, z0, 한 변, 돌길 0/1)) — 조각 LOD와 상관없이 또렷.
// 무늬(들꽃 점·이끼 점·낙엽·밭이랑·자갈·물웅덩이·바위 금·소금 금·돌길 돌)는 세계 좌표 해시·잡음, 한 픽셀보다 작아지면 사라진다.
// 계절 (season_*·flower_amt·leaf_amt·dry_thr·frost_amt·snow_amt)은 view/ground_look.gd가 병 날짜로 넣는다.
// 높이는 선 대신 색 단계 + 작은 둔덕 테두리 (band_h마다) + (멀리 축소) 언덕 명암.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

#include "res://render/toon_light.gdshaderinc"

uniform vec3 path_col : source_color;
uniform vec3 path_edge : source_color;
uniform vec3 salt_col : source_color;
uniform vec3 salt_edge : source_color;
uniform vec3 river_col : source_color;
uniform vec3 river_edge : source_color;
uniform vec3 bank_col : source_color;
uniform vec3 ridge_col : source_color;
uniform vec3 foam_col : source_color = vec3(0.9, 0.97, 0.97);
uniform float band_h = 0.9;          // 높이 단계 (세계 단위)
uniform float band_lift = 0.035;     // 단계마다 밝아지는 정도

// 겉흙 색 (Toon.terrain_mat이 Style에서 넣음)
uniform vec3 dry_col : source_color = vec3(0.83, 0.82, 0.54);
uniform vec3 moss_col : source_color = vec3(0.37, 0.62, 0.52);
uniform vec3 moss_dot : source_color = vec3(0.53, 0.76, 0.6);
uniform vec3 forest_col : source_color = vec3(0.58, 0.6, 0.4);
uniform vec3 forest_dot : source_color = vec3(0.48, 0.44, 0.3);
uniform vec3 soil_col : source_color = vec3(0.69, 0.54, 0.36);
uniform vec3 soil_dark : source_color = vec3(0.56, 0.43, 0.28);
uniform vec3 shore_col : source_color = vec3(0.89, 0.84, 0.66);
uniform vec3 pebble_col : source_color = vec3(0.68, 0.7, 0.67);
uniform vec3 mud_col : source_color = vec3(0.55, 0.45, 0.33);
uniform vec3 puddle_col : source_color = vec3(0.45, 0.68, 0.72);
uniform vec3 rock_col : source_color = vec3(0.66, 0.7, 0.68);
uniform vec3 rock_dark : source_color = vec3(0.54, 0.58, 0.57);
uniform vec3 stone_col : source_color = vec3(0.78, 0.78, 0.72);
uniform vec3 stone_gap : source_color = vec3(0.62, 0.62, 0.56);
uniform vec3 snow_col : source_color = vec3(0.96, 0.97, 0.97);
uniform vec3 snow_shade : source_color = vec3(0.86, 0.91, 0.93);
uniform vec3 sand_col : source_color = vec3(0.91, 0.76, 0.53);
uniform vec3 flower_col : source_color = vec3(0.95, 0.83, 0.29);
uniform vec3 flower_col2 : source_color = vec3(0.98, 0.97, 0.9);
uniform vec3 leaf_col : source_color = vec3(0.85, 0.46, 0.25);
uniform vec3 leaf_col2 : source_color = vec3(0.91, 0.69, 0.29);

// 계절 (view/ground_look.gd apply_season)
uniform vec3 season_tint = vec3(1.0);
uniform float season_mix = 0.0;
uniform float flower_amt = 0.0;
uniform float leaf_amt = 0.0;
uniform float dry_thr = 0.6;
uniform float frost_amt = 0.0;
uniform float snow_amt = 0.0;
uniform float desert = 0.0;

// 오솔길 지도 (무리 4곳까지)
uniform sampler2D path_tex0 : filter_linear, repeat_disable;
uniform sampler2D path_tex1 : filter_linear, repeat_disable;
uniform sampler2D path_tex2 : filter_linear, repeat_disable;
uniform sampler2D path_tex3 : filter_linear, repeat_disable;
uniform vec4 path_rect0 = vec4(0.0, 0.0, -1.0, 0.0);
uniform vec4 path_rect1 = vec4(0.0, 0.0, -1.0, 0.0);
uniform vec4 path_rect2 = vec4(0.0, 0.0, -1.0, 0.0);
uniform vec4 path_rect3 = vec4(0.0, 0.0, -1.0, 0.0);
uniform float path_far = 0.0;        // 0 가까이 ~ 1 반쯤 축소: 길 문턱을 낮추고 테두리를 진하게 (A18 — ×3에서도 읽히게)

// 멀리 축소 (세상 전체): 언덕 명암 + 숲 덩어리
uniform float far_shade = 0.0;
uniform vec2 light_dir = vec2(-0.72, -0.69);   // 창가 방향 (병 데이터 좌표 — 언덕 명암)
// 등불 옮기기 미리보기 (A11 — view/lamp_ctl.gd): 볕이 들 땅 = 노랑, 그늘이 될 땅 = 파랑 (지금 빛 lamp_l0 → 옮긴 뒤 lamp_l1)
uniform float lamp_mix = 0.0;
uniform vec2 lamp_l0 = vec2(-0.72, -0.69);
uniform vec2 lamp_l1 = vec2(-0.72, -0.69);
uniform float lamp_rr = 512.0;
// 세상 전체 지도 (view/world_terrain.gd _build_maps — 키트 자리 고르기·끝까지 축소): 높이 → 언덕 명암, 숲 지도 → 수관 덩어리,
// 거친 칸 수면 높이(R)·흐름(G) → 호수·강·습지. 거친 메시(16칸 간격)여도 픽셀마다 읽어 또렷하다.
uniform float map_on = 0.0;
uniform sampler2D map_h : filter_linear, repeat_disable;
uniform sampler2D map_f : filter_linear_mipmap, repeat_disable;
uniform sampler2D map_w : filter_linear, repeat_disable;
uniform vec4 map_rect = vec4(-512.0, -512.0, 1024.0, 512.0);   // (x0, z0, 한 변 칸, 높이 지도 해상도)
uniform float map_wn = 128.0;
uniform float map_hs = 6.0;
uniform vec3 canopy_col : source_color = vec3(0.24, 0.64, 0.51);
uniform vec3 canopy_lit : source_color = vec3(0.4, 0.79, 0.54);
uniform vec3 canopy_dark : source_color = vec3(0.16, 0.52, 0.47);
uniform vec3 lake_col : source_color = vec3(0.42, 0.78, 0.82);
uniform vec3 lake_edge : source_color = vec3(0.31, 0.62, 0.68);

varying vec3 wpos;
varying vec3 lpos;                   // 병 데이터 좌표 (조각 메시 좌표 — 병을 돌려도 땅과 함께)
varying float up;
varying vec4 c0;
varying vec4 c1;
varying vec3 lnorm;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 문턱 a에서 끊되 가장자리 띠(폭 w)는 edge 색
vec3 layer(vec3 base, float v, float a, float w, vec3 fill, vec3 edge) {
	float aa = fwidth(v) * 0.75 + 1e-4;
	float inside = smoothstep(a - aa, a + aa, v);
	float core = smoothstep(a + w - aa, a + w + aa, v);
	return mix(base, mix(edge, fill, core), inside);
}

// 문턱 덮개 (0~1)
float cover(float v, float a) {
	float aa = fwidth(v) * 0.75 + 1e-4;
	return smoothstep(a - aa, a + aa, v);
}

// 점 무늬: 격자 s칸마다 점 하나 (확률 p, 반지름 r — 칸 비율). 점이 한 픽셀보다 작으면 옅어짐. 돌려줌 = 덮개, 해시
vec2 dots(vec2 p, float s, float prob, float r) {
	vec2 g = p / s;
	vec2 i = floor(g);
	float h = hash(i + 0.37);
	vec2 c = vec2(hash(i + 1.7), hash(i + 5.3)) * (1.0 - 2.0 * r) + r;
	float d = length(fract(g) - c);
	float px = fwidth(g.x) + 1e-5;
	float vis = 1.0 - smoothstep(r * 0.6, r * 1.6, px);
	float on = step(h, prob) * (1.0 - smoothstep(r - px, r + px, d)) * vis;
	return vec2(on, hash(i + 9.1));
}

// 오솔길 값 — 반쯤 축소(path_far)에서는 둘레 네 점의 최댓값으로 길을 넓힘 (칸 하나 폭의 길이 ×3에서도 몇 픽셀)
float path_at(sampler2D t, vec4 r, vec2 p) {
	if (r.z <= 0.0) {
		return 0.0;
	}
	vec2 uv = (p - r.xy) / r.z;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	float v = texture(t, uv).r;
	if (path_far > 0.01) {
		float o = path_far * 0.9 / r.z;
		v = max(v, max(max(texture(t, uv + vec2(o, o)).r, texture(t, uv + vec2(-o, o)).r),
			max(texture(t, uv + vec2(o, -o)).r, texture(t, uv + vec2(-o, -o)).r)));
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lpos = VERTEX;
	lnorm = NORMAL;
	up = NORMAL.y;
	c0 = CUSTOM0;
	c1 = CUSTOM1;
}

void fragment() {
	vec3 c = srgb_to_linear(COLOR.rgb);
	if (up > 0.35) {
		vec2 p = lpos.xz;
		float px = fwidth(p.x) + 1e-5;                 // 한 픽셀 = 몇 칸
		float near = 1.0 - smoothstep(0.12, 0.35, px); // 무늬를 그릴 만큼 가까운가
		// 문턱을 흔드는 잡음 (경계가 곡선 붓자국처럼)
		float wob = (vnoise(p * 0.55) - 0.5) * 0.28 + (vnoise(p * 1.9 + 3.1) - 0.5) * 0.12 * near;
		// 바탕 풀 + 계절 + (사막 병) 모래땅
		c = mix(c, c * season_tint, season_mix);
		c = mix(c, sand_col * (0.94 + 0.12 * vnoise(p * 0.3)), desert);
		// 높이 단계: 높을수록 조금 밝게 + 단계 경계에 둔덕 테두리
		float b = wpos.y / band_h;
		c *= 1.0 + band_lift * clamp(floor(b), -2.0, 4.0);
		float fw = fwidth(b);
		float ridge = 1.0 - smoothstep(fw * 0.6, fw * 1.6, fract(b));
		c = mix(c, ridge_col, ridge * smoothstep(0.002, 0.02, fw) * 0.8);
		// 들꽃 점 (봄 민들레 노랑 + 흰 꽃) — 풀밭에만
		float grass_here = 1.0;
		// 마른 풀 (계절 문턱)
		float dry = cover(c1.x + wob * 0.6, dry_thr) * (1.0 - desert);
		c = mix(c, dry_col * (0.96 + 0.08 * vnoise(p * 2.3)), dry);
		grass_here *= 1.0 - dry * 0.6;
		// 겉흙마다 무게가 조금이라도 있는 곳에서만 무늬를 계산 (휴대폰 GPU — 대부분의 픽셀은 풀밭).
		// 가르는 값(0.05)은 보이는 문턱(0.5 − 흔들림 0.2)보다 한참 아래라 갈림 경계에선 덮개가 0 → 미분 값이 틀려도 안 보임
		if (c0.w > 0.05) {
			// 이끼: 짙은 청록 + 보송한 점
			float mo = cover(c0.w + wob, 0.5);
			vec2 md = dots(p, 0.45, 0.55, 0.22);
			c = mix(c, mix(moss_col, moss_dot, md.x), mo);
			grass_here *= 1.0 - mo;
		}
		if (c0.z > 0.05) {
			// 숲 바닥: 낙엽·흙 (가을엔 붉은 잎)
			float fo = cover(c0.z + wob, 0.5);
			vec3 fc = forest_col * (0.93 + 0.14 * vnoise(p * 1.3));
			vec2 fd = dots(p, 0.38, 0.35 + 0.45 * leaf_amt, 0.2);
			vec3 lc = mix(forest_dot, mix(leaf_col, leaf_col2, fd.y), step(fd.y, leaf_amt * 0.85));
			fc = mix(fc, lc, fd.x);
			c = mix(c, fc, fo);
			grass_here *= 1.0 - fo;
		}
		if (leaf_amt > 0.001) {
			// 가을 낙엽: 숲 가장자리 풀밭에 짙게, 바람에 날려 온 잎은 풀밭 어디에나 드문드문
			float lp = leaf_amt * (0.08 + 0.6 * smoothstep(0.02, 0.4, c0.z));
			vec2 ld = dots(p + 7.7, 0.5, lp, 0.17);
			c = mix(c, mix(leaf_col, leaf_col2, ld.y), ld.x * grass_here);
		}
		if (flower_amt > 0.001) {
			// 들꽃은 무리 지어 핀다 (넓은 잡음 덩어리 안에서만) — 풀밭 전체에 고르게 흩뿌리면 색종이처럼 보임
			float patch = smoothstep(0.45, 0.66, vnoise(p * 0.11 + 17.0));
			vec2 fl = dots(p + 3.3, 0.6, flower_amt * (0.04 + 0.42 * patch), 0.15);
			c = mix(c, mix(flower_col, flower_col2, step(0.72, fl.y)), fl.x * grass_here * (1.0 - desert));
		}
		if (c0.x > 0.05) {
			// 모래·자갈 물가
			float sh = cover(c0.x + wob * 0.7, 0.5);
			float pebbly = smoothstep(0.45, 0.62, vnoise(p * 0.21 + 4.0));      // 물가마다 모래 / 자갈
			vec2 pd = dots(p, 0.32, 0.25 + 0.55 * pebbly, 0.24);
			c = mix(c, mix(shore_col, pebble_col * (0.9 + 0.2 * pd.y), pd.x), sh);
		}
		if (UV.x > 0.05) {
			// 맨흙 (밭·집터·공사장): 밭이랑 줄
			float so = cover(UV.x + wob * 0.5, 0.5);
			float fur = 0.5 + 0.5 * sin(p.x * 4.2 + vnoise(p * 0.4) * 1.5);
			float furw = fwidth(fur) + 1e-4;
			vec3 sc = mix(soil_col, soil_dark, smoothstep(0.72 - furw, 0.72 + furw, fur) * near * smoothstep(0.7, 0.9, UV.x));
			c = mix(c, sc, so);
		}
		if (c0.y > 0.05) {
			// 진흙·습지: 짙은 갈색 + 물웅덩이
			float mu = cover(c0.y + wob * 0.7, 0.5);
			vec3 muc = mud_col * (0.92 + 0.12 * vnoise(p * 1.7));
			float pud = vnoise(p * 1.3 + 1.3) * 0.7 + vnoise(p * 3.1) * 0.3;
			float pw = fwidth(pud) + 1e-4;
			muc = mix(muc, mix(muc, puddle_col, 0.75), smoothstep(0.74 - pw, 0.74 + pw, pud) * smoothstep(0.55, 0.85, c0.y));
			c = mix(c, muc, mu);
		}
		// 폭포 웅덩이 곁: 물에 젖어 짙어진 땅
		c *= 1.0 - 0.18 * smoothstep(0.2, 0.8, c1.y);
		if (UV2.y > 0.05) {
			// 바위: 회색 덩어리 + 금
			float ro = cover(UV2.y + wob * 0.8, 0.5);
			float rn = vnoise(p * 0.8) * 0.65 + vnoise(p * 2.4) * 0.35;
			float rw = fwidth(rn) + 1e-4;
			vec3 rc = mix(rock_col, rock_dark, smoothstep(0.58 - rw, 0.58 + rw, rn));
			float crack = 1.0 - smoothstep(0.0, 0.035 + rw, abs(vnoise(p * 1.1 + 8.0) - 0.5));
			rc = mix(rc, rock_dark * 0.85, crack * near);
			c = mix(c, rc, ro);
		}
		// 오솔길 → 돌길 (무리마다 지도 텍스처)
		vec2 pv = vec2(0.0);
		float pth = path_at(path_tex0, path_rect0, p);
		pv = pth > pv.x ? vec2(pth, path_rect0.w) : pv;
		pth = path_at(path_tex1, path_rect1, p);
		pv = pth > pv.x ? vec2(pth, path_rect1.w) : pv;
		pth = path_at(path_tex2, path_rect2, p);
		pv = pth > pv.x ? vec2(pth, path_rect2.w) : pv;
		pth = path_at(path_tex3, path_rect3, p);
		pv = pth > pv.x ? vec2(pth, path_rect3.w) : pv;
		float pthr = mix(0.5, 0.3, path_far);
		vec3 pcol = path_col;
		vec3 pedge = mix(path_edge, path_edge * 0.82, path_far);
		if (pv.y > 0.5) {
			// 돌길: 둥근 돌 + 사이 틈 (칸의 0.5 격자 비틀린 벽돌)
			vec2 sp = p * 2.2;
			sp.x += floor(sp.y) * 0.5;
			vec2 sf = fract(sp) - 0.5;
			float sd = max(abs(sf.x), abs(sf.y));
			float sw = fwidth(sd) + 1e-4;
			float gap = smoothstep(0.36 - sw, 0.36 + sw, sd) * near;
			pcol = mix(stone_col * (0.95 + 0.1 * hash(floor(sp))), stone_gap, gap);
			pedge = stone_gap;
		}
		// 덜 다닌 곳은 풀이 닳아 옅은 흙빛 (길 둘레의 닳은 풀 — 길이 어디로 이어지는지 읽힘)
		c = mix(c, mix(c, path_col, 0.4), smoothstep(pthr * 0.35, pthr * 0.85, pv.x) * (1.0 - step(pthr, pv.x)));
		c = layer(c, pv.x + wob * 0.15, pthr, 0.06 + 0.05 * path_far, pcol, pedge);
		if (UV.y > 0.05) {
			// 소금 들판: 흰 땅 + 금
			float sa = cover(UV.y, 0.5);
			c = layer(c, UV.y, 0.5, 0.08, salt_col, salt_edge);
			float scr = 1.0 - smoothstep(0.0, 0.03 + fwidth(p.x) * 0.3, abs(vnoise(p * 0.7 + 2.0) - 0.5));
			c = mix(c, salt_edge, scr * sa * near * smoothstep(0.58, 0.75, UV.y));
		}
		if (frost_amt > 0.001) {
			// 서리 (온대 겨울 아침, 그늘에 오래): 그늘진 곳부터 하얗게 덮인 얼룩 + 반짝이는 서리 점 + 온 땅이 조금 희뿌옇게
			float fr = frost_amt * (0.55 + 0.45 * COLOR.a);
			float frp = cover(COLOR.a * 0.55 + vnoise(p * 0.32 + 9.0) * 0.55 + wob * 0.4, 1.35 - fr * 0.55);
			vec2 frd = dots(p + 1.1, 0.3, fr * 0.8, 0.26);
			c = mix(c, mix(snow_col, snow_shade, 0.5), frp * 0.75);
			c = mix(c, snow_col, frd.x * 0.85 + fr * 0.22);
		}
		if (snow_amt > 0.001) {
			// 눈 (냉대·툰드라 겨울): 그늘부터 덮임
			float sn = cover(COLOR.a + snow_amt + wob * 0.5, 1.0);
			vec3 snc = mix(snow_col, snow_shade, smoothstep(0.55, 0.62, vnoise(p * 0.5 + 6.0)));
			c = mix(c, snc, sn);
		}
		if (UV2.x > 0.05) {
			// 강 + 흰 물살 (천천히 흐르는 잡음을 문턱으로)
			c = layer(c, UV2.x, 0.5, 0.08, river_col, river_edge);
			float rvn = vnoise(wpos.xz * vec2(0.9, 0.9) + vec2(TIME * 0.35, TIME * 0.2)) * 0.6 + vnoise(wpos.xz * 2.1 - TIME * 0.4) * 0.4;
			float rf = smoothstep(0.62, 0.66, rvn) * smoothstep(0.62, 0.75, UV2.x);
			c = mix(c, foam_col, rf);
		}
	}
	if (map_on > 0.5) {
		// 세상 전체 지도: 픽셀마다 높이·숲·물
		vec2 uvm = (lpos.xz - map_rect.xy) / map_rect.z;
		float tx = 1.0 / map_rect.w;
		float hc = texture(map_h, uvm).r;
		float hx = texture(map_h, uvm + vec2(tx, 0.0)).r - texture(map_h, uvm - vec2(tx, 0.0)).r;
		float hz = texture(map_h, uvm + vec2(0.0, tx)).r - texture(map_h, uvm - vec2(0.0, tx)).r;
		vec2 grad = vec2(hx, hz) * map_hs / (2.0 * map_rect.z * tx);     // 세계 높이 / 칸
		float sh = -dot(grad, normalize(light_dir)) * 25.0;
		float st = floor(clamp(sh, -2.5, 2.5) + 0.5);
		c *= 1.0 + 0.06 * st;
		// 숲: 수관 덩어리 (창가 쪽 가장자리 밝게, 반대쪽 어둡게) — 조금 흐린 밉맵에서 읽어 잔 점은 지우고 덩어리만
		float f = textureLod(map_f, uvm, 2.0).r;
		float fa = fwidth(f) * 0.75 + 1e-3;
		float fo = smoothstep(0.34 - fa, 0.34 + fa, f);
		vec2 lo = normalize(light_dir) * tx * 2.5;
		float fl = textureLod(map_f, uvm + lo, 2.0).r;
		float fd = textureLod(map_f, uvm - lo, 2.0).r;
		vec3 cc = canopy_col;
		cc = mix(cc, canopy_lit, smoothstep(0.08, 0.2, f - fl) * 0.9);
		cc = mix(cc, canopy_dark, smoothstep(0.08, 0.2, f - fd) * 0.8);
		c = mix(c, cc, fo);
		// 물: 거친 칸 수면 높이와 픽셀 높이
		vec2 wv = texture(map_w, uvm).rg;
		float d = wv.r - hc;
		float dw = fwidth(d) * 0.75 + 1e-4;
		float lake = smoothstep(0.015 - dw, 0.015 + dw, d);
		float wet = smoothstep(0.0015 - dw, 0.0015 + dw, d);
		c = mix(c, mud_col, wet * (1.0 - lake) * (1.0 - step(0.5, wv.g)) * 0.7);
		c = mix(c, river_col, wet * step(0.5, wv.g) * (1.0 - lake));
		vec3 lc = mix(lake_edge, lake_col, smoothstep(0.03, 0.06, d));
		c = mix(c, lc, lake);
	} else if (far_shade > 0.0) {
		// 멀리 축소: 언덕 명암 (창가 쪽 비탈 밝게, 반대쪽 어둡게 — 세 단계로 끊어 셀 채색처럼)
		vec2 g = lnorm.xz / max(lnorm.y, 0.2);
		float s = dot(g, normalize(light_dir)) * 3.0;
		float st = floor(clamp(s, -1.5, 1.5) + 0.5);
		c *= 1.0 + far_shade * 0.09 * st;
	}
	if (lamp_mix > 0.0) {
		float g = (dot(lpos.xz, lamp_l1) - dot(lpos.xz, lamp_l0)) / lamp_rr;    // + 볕이 듦 · − 그늘이 됨
		float k = smoothstep(0.04, 0.45, abs(g));
		vec3 tint = g > 0.0 ? srgb_to_linear(vec3(1.0, 0.8, 0.22)) : srgb_to_linear(vec3(0.24, 0.44, 0.95));
		float lum = dot(c, vec3(0.3, 0.55, 0.15));
		c = mix(c, tint * (0.55 + 0.9 * lum), k * 0.55 * lamp_mix);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
