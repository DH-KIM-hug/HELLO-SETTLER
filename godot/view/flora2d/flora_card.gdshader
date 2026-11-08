// One flora / prop drawn as a 2D storybook picture: its own texture (great trees, giant sunflower) or a rect of an atlas
// (giant mushrooms, dandelion heads, kitchen props, piles, campfire …). Placement = flora_card.gdshaderinc.
// The node's own scale multiplies the size (grow / wither animations keep working), its rotation is ignored (the card always
// faces the camera). Flipbook: frames > 1 cycles frame_uv[] at fps (campfire flame). Column: tile_h > 0 draws the picture
// taller than drawn by repeating the band tile.x..tile.y of the texture (v from the top) above its bottom part (sunflower stalk).
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque, shadows_disabled;

#include "res://view/flora2d/flora_card.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 geo = vec4(1.0, 1.0, 0.0, 0.0);     // w, h, front, dx (world units at scale 1)
uniform vec4 ex = vec4(0.0);                     // mode, cy, sway, -
uniform float alpha_cut = 0.5;
uniform vec3 lit_tint : source_color = vec3(1.0);
uniform int frames = 1;
uniform float fps = 8.0;
uniform vec4 frame_uv[8];
uniform float tile_h = 0.0;                      // world height of a column card (0 = as drawn)
uniform vec2 tile = vec2(0.2, 0.6);              // repeated band (v from the top of the picture)
instance uniform float flip = 1.0;
instance uniform float k = 1.0;
instance uniform float lift = 0.0;
instance uniform float phase = 0.0;
instance uniform vec3 tint : source_color = vec3(1.0);

varying vec4 v_uv;
varying float v_y;       // column: world height above the base

void vertex() {
	float ks = k * length(MODEL_MATRIX[1].xyz);
	vec3 org = MODEL_MATRIX[3].xyz + vec3(0.0, lift, 0.0);
	vec4 g = geo;
	if (tile_h > 0.0) {
		g.y = tile_h;
	}
	v_uv = uv_rect;
	if (frames > 1) {
		v_uv = frame_uv[int(mod(floor(TIME * fps + phase * 7.0), float(frames)))];
	}
	v_y = (VERTEX.y + 0.5) * g.y;
	vec3 w = flora_place(VERTEX.xy, org, g, ex, flip, ks, phase, TIME, INV_VIEW_MATRIX);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(INV_VIEW_MATRIX[2].xyz, 0.0)).xyz);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec2 uv = UV;
	if (tile_h > 0.0) {
		// the drawn picture's bottom part stays at the bottom; above it the band [tile.x, tile.y] repeats
		float y = v_y;                               // world units from the base (scale 1)
		float vb = y / geo.y;                        // 0 at the bottom, in drawn heights
		float v = 1.0 - vb;
		if (v < tile.y) {
			float band = tile.y - tile.x;
			v = tile.y - mod(tile.y - v, band);
		}
		uv.y = v;
	}
	vec4 t = texture(tex, v_uv.xy + uv * v_uv.zw);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb * tint;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += lit_tint;
}
