// 거인의 방 창밖 하늘 (GIANT_ROOM 1 — 현실 시각: 아침·노을·밤 + 현실 계절: 봄 꽃잎·여름 짙은 잎·가을 낙엽·겨울 눈).
// 창 모델(window_sky) 위에 그린다. 빛을 받지 않음 (창밖). 모델 좌표: x −13~13, y 0~30 (build_room.py build_window).
// top/bottom 색 + 해·달 둥근 빛 + 구름 + 밤엔 별 · 창 왼쪽 위로 들어온 나뭇가지 (계절 잎·꽃) · 떨어지는 것 (꽃잎·잎·눈).
// 계절 값은 view/room/giant_room.gd set_season이 넣는다 (먼 나무 줄의 색은 창틀 메시 꼭짓점 색을 바꿔서).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 top_col : source_color = vec3(0.72, 0.86, 0.94);
uniform vec3 bottom_col : source_color = vec3(0.95, 0.94, 0.84);
uniform vec3 orb_col : source_color = vec3(1.0, 0.98, 0.86);
uniform vec2 orb_pos = vec2(-6.0, 22.0);
uniform float orb_r = 2.6;
uniform float stars = 0.0;
uniform float clouds = 1.0;
uniform vec3 cloud_col : source_color = vec3(1.0, 1.0, 1.0);
// 계절
uniform float light_k = 1.0;                 // 밤이면 어둡게 (가지·떨어지는 것)
uniform float fall_amt = 0.0;                // 떨어지는 것의 짙기 (0 없음)
uniform float fall_speed = 1.0;
uniform float fall_size = 0.18;              // 칸 비율
uniform float fall_stretch = 1.0;            // 1 = 둥근 눈, 크면 납작한 꽃잎·잎
uniform vec3 fall_col : source_color = vec3(1.0);
uniform vec3 fall_col2 : source_color = vec3(1.0);
uniform float branch_on = 0.0;
uniform vec3 branch_col : source_color = vec3(0.45, 0.32, 0.24);
uniform vec3 leaf_col : source_color = vec3(0.95, 0.75, 0.8);
uniform vec3 leaf_col2 : source_color = vec3(1.0, 0.9, 0.93);
uniform float leaf_amt = 1.0;                // 가지의 잎·꽃 덩이 (겨울 0 — 눈이 얹힌 맨 가지)
uniform float snow_cap = 0.0;
uniform float season_haze = 0.0;            // 겨울: 하늘이 희뿌옇게
varying vec3 lp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 선분 a-b까지 거리
float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// 가지 모양 (거리 < 0 = 가지 안)
float branch_d(vec2 p, float sway) {
	vec2 a = vec2(-14.5, 10.0);
	vec2 m = vec2(-9.0, 7.4 + sway);
	vec2 b = vec2(-4.2, 8.6 + sway * 1.6);
	vec2 t1 = vec2(-6.2, 11.6 + sway);
	vec2 t2 = vec2(-11.5, 4.6 + sway * 0.8);
	return min(min(seg(p, a, m) - 0.42, seg(p, m, b) - 0.26), min(seg(p, m + vec2(1.2, 0.3), t1) - 0.18, seg(p, a + vec2(3.0, -1.2), t2) - 0.2));
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float v = clamp(lp.y / 30.0, 0.0, 1.0);
	vec3 c = mix(bottom_col, top_col, smoothstep(0.0, 1.0, v));
	c = mix(c, mix(c, vec3(0.93, 0.95, 0.97) * (0.4 + 0.6 * light_k), 0.5), season_haze);
	float d = length(lp.xy - orb_pos);
	c += orb_col * 0.22 * (1.0 - smoothstep(orb_r, orb_r * 3.4, d));
	c = mix(c, orb_col, 1.0 - smoothstep(orb_r - 0.08, orb_r + 0.08, d));
	// 구름 두어 덩이 (아침·노을)
	float band = sin(lp.x * 0.35 + 1.3) * 0.5 + 0.5 + sin(lp.x * 0.9 + lp.y * 0.3) * 0.2;
	float cl = smoothstep(0.55, 0.6, band - abs(lp.y - 15.0) * 0.12);
	c = mix(c, cloud_col, cl * clouds * 0.9);
	if (stars > 0.0) {
		vec2 g = floor(lp.xy * 1.4);
		float h = hash(g);
		vec2 f = fract(lp.xy * 1.4) - 0.5;
		float s = step(0.955, h) * (1.0 - smoothstep(0.06, 0.18, length(f)));
		c = mix(c, vec3(1.0, 0.96, 0.82), s * stars * v);
	}
	// 창 왼쪽에서 들어온 나뭇가지 (바람에 아주 조금 흔들림)
	if (branch_on > 0.0) {
		float sway = sin(TIME * 0.8) * 0.12;
		vec2 p = lp.xy;
		vec2 a = vec2(-14.5, 10.0);
		vec2 m = vec2(-9.0, 7.4 + sway);
		vec2 b = vec2(-4.2, 8.6 + sway * 1.6);
		float br = branch_d(p, sway);
		float aa = fwidth(br) + 1e-3;
		c = mix(c, branch_col * light_k, 1.0 - smoothstep(-aa, aa, br));
		// 가지 위에 얹힌 눈 (겨울): 바로 아래가 가지인 곳
		float under = branch_d(p - vec2(0.0, 0.32), sway);
		float cap = snow_cap * (1.0 - smoothstep(-aa, aa, under)) * smoothstep(-aa, aa, br + 0.02);
		c = mix(c, vec3(0.97, 0.98, 1.0) * (0.45 + 0.55 * light_k), cap);
		// 잎·꽃 덩이: 가지 둘레의 동그라미들
		if (leaf_amt > 0.0) {
			float best = 1e3;
			float pick = 0.0;
			for (int i = 0; i < 11; i++) {
				float fi = float(i);
				float u = fi / 10.0;
				vec2 q = mix(mix(a, m, clamp(u * 2.0, 0.0, 1.0)), b, clamp(u * 2.0 - 1.0, 0.0, 1.0));
				q += vec2(hash(vec2(fi, 1.3)) - 0.5, hash(vec2(fi, 4.1)) - 0.5) * vec2(2.0, 2.2);
				float r = 0.8 + hash(vec2(fi, 7.7)) * 0.7;
				float dd = length(p - q) - r;
				if (dd < best) {
					best = dd;
					pick = hash(vec2(fi, 9.2));
				}
			}
			float la = fwidth(best) + 1e-3;
			float on = (1.0 - smoothstep(-la, la, best)) * step(pick, leaf_amt);
			vec3 lc = mix(leaf_col, leaf_col2, step(0.5, fract(pick * 7.0))) * (0.45 + 0.55 * light_k);
			c = mix(c, lc, on);
		}
	}
	// 떨어지는 것: 세 겹 (가까울수록 크고 빠름)
	if (fall_amt > 0.0) {
		for (int k = 0; k < 3; k++) {
			float fk = float(k);
			float sc = 0.42 + fk * 0.22;
			vec2 sp = lp.xy * sc;
			sp.y += TIME * fall_speed * (0.55 + 0.3 * fk) * sc;
			sp.x += sin(TIME * 0.9 + sp.y * 1.7 + fk) * 0.18 + TIME * 0.06 * fall_stretch;
			vec2 cell = floor(sp);
			vec2 f = fract(sp) - 0.5;
			float h = hash(cell + fk * 17.3);
			float fa = fwidth(sp.y) * 1.2 + 1e-4;              // 칸 경계에서 튀지 않는 폭 (거리 값의 fwidth는 경계에서 커짐)
			if (h < fall_amt) {
				vec2 o = (vec2(hash(cell + 3.1), hash(cell + 8.7)) - 0.5) * 0.36;
				vec2 dv = f - o;
				float ang = hash(cell + 5.5) * 6.28 + TIME * (hash(cell + 2.2) - 0.5) * 2.0 * step(1.2, fall_stretch);
				dv = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * dv;
				dv.y *= fall_stretch;
				float dd = length(dv) - fall_size * (0.75 + 0.4 * hash(cell + 1.9));
				vec3 fc = mix(fall_col, fall_col2, step(0.5, hash(cell + 6.6))) * mix(0.55, 1.0, light_k);
				c = mix(c, fc, 1.0 - smoothstep(-fa, fa, dd));
			}
		}
	}
	ALBEDO = c;
}
