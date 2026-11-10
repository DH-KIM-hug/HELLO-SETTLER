// Every building card at village zoom (bld_far) from ONE atlas (art/bld2d/far_atlas.png) — one MultiMesh = one draw call
// (art-bible budget 300 draw calls at ppu 16). Also the graves. Placement / light = bld_card.gdshader.
// Per instance: transform origin = building centre (lift already added), INSTANCE_CUSTOM = (picture index, flip, size k, pull),
// instance colour = cut window (x0, x1, cap, -) in world units (bld_cut_sink) — cap < 0 = none.
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque, shadows_disabled;

#include "res://view/bld2d/bld_card.gdshaderinc"

const int MAX_PICS = 96;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 geo[MAX_PICS];      // w, h, front, dx
uniform vec4 uvr[MAX_PICS];      // atlas rect (x, y, w, h) in 0..1
uniform float pmode[MAX_PICS];   // 0 card · 1 ground
uniform float psway[MAX_PICS];   // wind lean of the top edge (world units) — wheat rows
uniform float plean[MAX_PICS];   // depth-only lean of the foot toward the camera (world units) — wheat rows
uniform float alpha_cut = 0.5;
uniform vec3 lit_tint : source_color = vec3(1.0);

varying vec4 v_uv;
varying vec2 v_loc;              // card-local position in world units (x right, y up from the foot)
varying vec4 v_cut;              // x0, x1, cap, full height

void vertex() {
	int i = clamp(int(INSTANCE_CUSTOM.x + 0.5), 0, MAX_PICS - 1);
	v_uv = uvr[i];
	vec2 corner = VERTEX.xy;
	v_loc = vec2(corner.x * INSTANCE_CUSTOM.y * geo[i].x, (corner.y + 0.5) * geo[i].y) * INSTANCE_CUSTOM.z;
	v_cut = vec4(COLOR.rgb, geo[i].y * INSTANCE_CUSTOM.z);
	vec3 w = bld_place(VERTEX.xy, MODEL_MATRIX[3].xyz, geo[i], pmode[i], INSTANCE_CUSTOM.y, INSTANCE_CUSTOM.z, INV_VIEW_MATRIX);
	if (psway[i] > 0.0) {
		w = bld_sway(w, VERTEX.xy, MODEL_MATRIX[3].xyz, geo[i], psway[i], INSTANCE_CUSTOM.z, TIME, INV_VIEW_MATRIX);
	}
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	VERTEX.z += bld_lean(corner, plean[i], geo[i].y, INSTANCE_CUSTOM.z) + INSTANCE_CUSTOM.w;
	NORMAL = normalize((VIEW_MATRIX * vec4(INV_VIEW_MATRIX[2].xyz, 0.0)).xyz);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec2 uv = UV;
	if (v_cut.z >= 0.0) {
		uv.y -= bld_cut_sink(v_loc.x, v_cut.xyz, v_cut.w) / v_cut.w;
		if (uv.y < 0.0) {
			discard;
		}
	}
	vec4 t = texture(atlas, v_uv.xy + uv * v_uv.zw);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += lit_tint;
}
