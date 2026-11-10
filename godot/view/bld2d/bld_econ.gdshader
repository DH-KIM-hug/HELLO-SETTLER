// 'Visible economy' sprites on the 2D buildings (ROADMAP Q6): material piles, site progress pegs, work puffs, thought bubbles,
// the little burst when a building is finished. Every sprite from ONE atlas (art/bld2d/econ_atlas.png) in ONE MultiMesh = one
// draw call at any zoom (view/bld2d/bld_econ.gd). Placement / light follow bld_card: right = camera right, up = world up
// stretched so the sprite shows 1:1, standing on its ground point (residents in front draw over it, those behind are hidden).
// Per instance: origin = ground point · INSTANCE_CUSTOM = (sprite index, size k — negative mirrors, motion kind, t0 or phase)
//               COLOR = (lift above the ground point, a, b, c) — motion parameters, not a colour.
// Motion runs here from the view clock `now` (no per-frame buffer upload):
//  0 still · 1 plop (a pile just changed: squash and settle from t0) · 2 bubble (pops in at t0, then bobs; a = bob phase)
//  3 puff loop (a = rise, b = drift, c = period; custom.w = phase) · 4 burst (flies from t0: a = side speed, b = up speed, c = life)
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque, shadows_disabled;

const int MAX_PICS = 64;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 geo[MAX_PICS];      // w, h (world units), -, -
uniform vec4 uvr[MAX_PICS];      // atlas rect (x, y, w, h) in 0..1
uniform float now = 0.0;         // view clock (seconds)
uniform float zoom_k = 1.0;      // sprites grow a little at village zoom so they still read on a phone
uniform float alpha_cut = 0.5;
uniform vec3 lit_tint : source_color = vec3(1.0);

varying vec4 v_uv;

void vertex() {
	int i = clamp(int(INSTANCE_CUSTOM.x + 0.5), 0, MAX_PICS - 1);
	v_uv = uvr[i];
	float k = abs(INSTANCE_CUSTOM.y) * zoom_k;
	float flip = INSTANCE_CUSTOM.y < 0.0 ? -1.0 : 1.0;
	int kind = int(INSTANCE_CUSTOM.z + 0.5);
	float t = INSTANCE_CUSTOM.w;
	vec4 p = COLOR;
	float lift = p.r;
	float side = 0.0;
	vec2 sc = vec2(1.0);
	if (kind == 1) {
		float a = max(now - t, 0.0);
		float s = 1.0 - exp(-a * 8.0) * cos(a * 18.0);
		sc = vec2(1.0 + (1.0 - s) * 0.45, s);
	} else if (kind == 2) {
		float a = max(now - t, 0.0);
		sc = vec2(1.0 - exp(-a * 7.0) * cos(a * 13.0));
		lift += 0.05 * sin(now * 2.2 + p.g);
	} else if (kind == 3) {
		float f = fract(now / max(p.a, 0.1) + t);
		lift += p.g * f;
		side = p.b * f + 0.04 * sin(f * 9.0 + t * 40.0);
		sc = vec2(smoothstep(0.0, 0.2, f) * (1.0 - smoothstep(0.65, 1.0, f)) * (0.6 + 0.6 * f));
	} else if (kind == 4) {
		float a = now - t;
		float life = max(p.a, 0.1);
		float f = clamp(a / life, 0.0, 1.0);
		side = p.g * a;
		lift += max(p.b * a - 2.4 * a * a, -lift);
		sc = vec2((a < 0.0 || a >= life) ? 0.0 : smoothstep(0.0, 0.1, f) * (1.0 - smoothstep(0.6, 1.0, f)));
	}
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	right = normalize(vec3(right.x, 0.0, right.z));
	float cu = max(INV_VIEW_MATRIX[1].y, 0.3);
	vec4 g = geo[i];
	vec3 w = MODEL_MATRIX[3].xyz + right * (VERTEX.x * flip * g.x * k * sc.x + side)
		+ vec3(0.0, ((VERTEX.y + 0.5) * g.y * k * sc.y + lift) / cu, 0.0);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(INV_VIEW_MATRIX[2].xyz, 0.0)).xyz);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec4 tx = texture(atlas, v_uv.xy + UV * v_uv.zw);
	if (tx.a < alpha_cut) {
		discard;
	}
	ALBEDO = tx.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += lit_tint;
}
