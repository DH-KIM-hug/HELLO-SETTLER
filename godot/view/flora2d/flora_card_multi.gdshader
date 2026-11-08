// Every flora / prop card of one atlas group (art/flora2d/atlas_<group>.png) in ONE MultiMesh draw (FloraBatch · Flora2D.multi).
// Per instance: transform origin = the model origin (ground), INSTANCE_CUSTOM = (picture index, flip, size k, sway phase),
// COLOR = tint (white = as drawn; ore rocks are tinted). Placement = flora_card.gdshaderinc. Light = the paper-doll rule (flat
// lit_tint, night grading and ink outline from the screen shader) like the building cards; casts / receives no shadow — tall
// things have an invisible SHADOWS_ONLY 3D twin.
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque, shadows_disabled;

#include "res://view/flora2d/flora_card.gdshaderinc"

const int MAX_PICS = 128;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 geo[MAX_PICS];      // w, h, front, dx
uniform vec4 uvr[MAX_PICS];      // atlas rect (x, y, w, h) in 0..1
uniform vec4 ex[MAX_PICS];       // mode, cy, sway, -
uniform float alpha_cut = 0.5;
uniform vec3 lit_tint : source_color = vec3(1.0);

varying vec4 v_uv;
varying vec3 v_tint;

void vertex() {
	int i = clamp(int(INSTANCE_CUSTOM.x + 0.5), 0, MAX_PICS - 1);
	v_uv = uvr[i];
	v_tint = COLOR.rgb;
	vec3 w = flora_place(VERTEX.xy, MODEL_MATRIX[3].xyz, geo[i], ex[i], INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.z, INSTANCE_CUSTOM.w, TIME, INV_VIEW_MATRIX);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(INV_VIEW_MATRIX[2].xyz, 0.0)).xyz);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec4 t = texture(atlas, v_uv.xy + UV * v_uv.zw);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb * v_tint;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += lit_tint;
}
