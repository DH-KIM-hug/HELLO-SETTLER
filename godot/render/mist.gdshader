// 폭포 물안개 입자 — 기획서 4.2 (A12). 텍스처 = art/models/water/mist_puffs.png (256², 2×2 아틀라스, 흰색 + 알파 물안개 4개).
// GPUParticles3D가 아래에서 천천히 띄워 올리며 투명하게 (COLOR.a = 입자 색 띠의 알파). 늘 카메라를 보는 판 (빌보드).
// 또 무지개 (rainbow = 1): 같은 판에 일곱 빛 반원 띠 — 볕 드는 쪽 폭포 웅덩이 위, 낮에만 (view/waterfalls.gd).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled, depth_draw_never, blend_mix;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool rainbow = false;
uniform float night_amount = 0.0;
uniform vec3 night_mul : source_color = vec3(0.3, 0.37, 0.6);
uniform vec3 night_add : source_color = vec3(0.01, 0.02, 0.05);
instance uniform float opacity = 0.8;

varying float frame;

void vertex() {
	// 카메라를 보는 판 (크기는 그대로)
	mat4 bb = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	frame = mod(float(INSTANCE_ID), 4.0);
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

void fragment() {
	if (rainbow) {
		// 아래 가운데를 중심으로 한 반원 띠 (바깥 빨강 → 안쪽 보라), 양 끝은 옅게
		vec2 q = vec2(UV.x - 0.5, 1.0 - UV.y) * vec2(2.0, 1.0);
		float r = length(q);
		float band = (r - 0.62) / 0.3;              // 0 안쪽 ~ 1 바깥
		float w = fwidth(band) + 1e-3;
		float inside = smoothstep(-w, w, band) * (1.0 - smoothstep(1.0 - w, 1.0 + w, band));
		float ends = smoothstep(0.0, 0.35, q.y / max(r, 1e-3));
		vec3 c = hue(clamp(0.78 - band * 0.78, 0.0, 0.78));
		c = mix(c, vec3(1.0), 0.18);
		c = mix(c, c * night_mul + night_add, night_amount);
		ALBEDO = c;
		ALPHA = inside * ends * opacity * 0.55;
	} else {
		vec2 uv = UV * 0.5 + vec2(mod(frame, 2.0), floor(frame / 2.0)) * 0.5;
		vec4 t = texture(tex, uv);
		vec3 c = mix(t.rgb, t.rgb * night_mul + night_add, night_amount);
		ALBEDO = c * COLOR.rgb;
		ALPHA = t.a * COLOR.a * opacity;
	}
}
