// 나는 작은 생물 멀리 LOD의 껍데기 외곽선 — hull.gdshader와 같은 부풀리기 (RENDERING.md v2 2.4) + critter_flap.gdshader와 같은 날개 돌림.
// (날개를 먼저 돌린 뒤 부풀림 → 선이 날개를 따라감.) 주민·대머리 갈래는 없음.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled, shadows_disabled, ambient_light_disabled, specular_disabled;

uniform vec3 line_mul : source_color = vec3(0.25, 0.42, 0.43);
uniform float width_px_1080p = 1.6;
uniform float push_back = 0.06;
uniform vec2 hinge = vec2(0.035, 0.015);

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec2 rot(vec2 p, float th) {
	float c = cos(th);
	float s = sin(th);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

void vertex() {
	vec3 pos = VERTEX;
	vec3 n = CUSTOM0.w > 0.5 ? CUSTOM0.xyz : NORMAL;
	float sd = UV.y;
	if (abs(sd) > 0.5) {
		float th = sign(sd) * INSTANCE_CUSTOM.x;
		vec2 h = vec2(sign(sd) * hinge.x, hinge.y);
		pos.xy = h + rot(pos.xy - h, th);
		n.xy = rot(n.xy, th);
	}
	vec4 vp = MODELVIEW_MATRIX * vec4(pos, 1.0);
	vec3 nv = mat3(MODELVIEW_MATRIX) * n;
	float upp = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	float w = max(0.75, width_px_1080p * VIEWPORT_SIZE.y / 1920.0) * upp;
	float l = length(nv.xy);
	if (l > 1e-5) {
		vp.xy += nv.xy / l * w * min(1.0, l * 4.0);
	}
	vp.z -= push_back;
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	ALBEDO = srgb_to_linear(COLOR.rgb) * line_mul;
}
