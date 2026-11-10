// One building drawn as a 2D storybook picture (near zoom: its own picture, art/bld2d/<name>.png). See bld_card.gdshaderinc.
// Light = the paper-doll rule without N.L (the card always faces the camera): lit_tint per light; night grading and the ink
// outline come from the screen shader (outline_post) by depth, exactly as for residents. The card neither casts nor receives
// shadows — the invisible 3D model under it (SHADOWS_ONLY proxy) casts the real sun / lamp shadow.
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque, shadows_disabled;

#include "res://view/bld2d/bld_card.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 geo = vec4(2.5, 2.5, 1.1, 0.0);     // w, h, front, dx (world units)
uniform float mode = 0.0;                        // 0 card · 1 ground
uniform float sway = 0.0;                        // wind lean of the top edge (world units) — wheat rows
uniform float lean = 0.0;                        // depth-only lean of the foot toward the camera (world units) — wheat rows
uniform float alpha_cut = 0.5;
uniform vec3 lit_tint : source_color = vec3(1.0);
instance uniform float flip = 1.0;               // -1 mirrors (ferry landing toward the other bank)
instance uniform float k = 1.0;                  // size multiplier (building sites follow the building size)
instance uniform float lift = 0.0;               // raise (ground mode: over the highest corner of the footprint)

void vertex() {
	vec3 org = MODEL_MATRIX[3].xyz + vec3(0.0, lift, 0.0);
	vec2 corner = VERTEX.xy;
	vec3 w = bld_place(VERTEX.xy, org, geo, mode, flip, k, INV_VIEW_MATRIX);
	if (sway > 0.0) {
		w = bld_sway(w, VERTEX.xy, org, geo, sway, k, TIME, INV_VIEW_MATRIX);
	}
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	VERTEX.z += bld_lean(corner, lean, k);
	NORMAL = normalize((VIEW_MATRIX * vec4(INV_VIEW_MATRIX[2].xyz, 0.0)).xyz);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec4 t = texture(tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += lit_tint;
}
