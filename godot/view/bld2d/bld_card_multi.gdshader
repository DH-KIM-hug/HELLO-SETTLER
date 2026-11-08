// Every building card at village zoom (bld_far) from ONE atlas (art/bld2d/far_atlas.png) — one MultiMesh = one draw call
// (art-bible budget 300 draw calls at ppu 16). Also the graves. Placement / light = bld_card.gdshader.
// Per instance: transform origin = building centre (lift already added), INSTANCE_CUSTOM = (picture index, flip, size k, -).
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque, shadows_disabled;

#include "res://view/bld2d/bld_card.gdshaderinc"

const int MAX_PICS = 96;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 geo[MAX_PICS];      // w, h, front, dx
uniform vec4 uvr[MAX_PICS];      // atlas rect (x, y, w, h) in 0..1
uniform float pmode[MAX_PICS];   // 0 card · 1 ground
uniform float alpha_cut = 0.5;
uniform vec3 lit_tint : source_color = vec3(1.0);

varying vec4 v_uv;

void vertex() {
	int i = clamp(int(INSTANCE_CUSTOM.x + 0.5), 0, MAX_PICS - 1);
	v_uv = uvr[i];
	vec3 w = bld_place(VERTEX.xy, MODEL_MATRIX[3].xyz, geo[i], pmode[i], INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.z, INV_VIEW_MATRIX);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(INV_VIEW_MATRIX[2].xyz, 0.0)).xyz);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec4 t = texture(atlas, v_uv.xy + UV * v_uv.zw);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += lit_tint;
}
