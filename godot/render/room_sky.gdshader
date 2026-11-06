// 거인의 방 창밖 하늘 (GIANT_ROOM 1 — 현실 시각: 아침·노을·밤). 창 모델(window_sky) 위에 그린다. 빛을 받지 않음 (창밖).
// top/bottom 색 + 해·달 둥근 빛 + 구름 + 밤엔 별. 모델 좌표: x −13~13, y 0~30 (build_room.py build_window).
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
varying vec3 lp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float v = clamp(lp.y / 30.0, 0.0, 1.0);
	vec3 c = mix(bottom_col, top_col, smoothstep(0.0, 1.0, v));
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
	ALBEDO = c;
}
