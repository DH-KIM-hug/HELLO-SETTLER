// Campfire flame as a 2D storybook flipbook (view/campfire.gd, Flora2D) — six drawn frames (flame_0..5 in the common atlas)
// cycled at fps. Unshaded and drawn in the transparent pass (after the screen grading, like render/flame.gdshader) so the
// fire keeps its drawn colours at night; the alpha is the picture's own cut-out edge (no soft see-through).
// heat scales the flame (0 = out · 0.35 smudge · 1 normal · 1.4 big); smoky tints it toward a dull red.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled, skip_vertex_transform;

#include "res://view/flora2d/flora_card.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 geo = vec4(0.9, 1.0, 0.0, 0.0);
uniform vec4 frame_uv[6];
uniform float fps = 7.0;
uniform float heat = 1.0;
uniform float smoky = 0.0;
uniform float lift = 0.16;
uniform float pull = 1.4;          // moved toward the camera along the view ray (screen place unchanged): drawn over the log card

varying vec4 v_uv;

void vertex() {
	float k = clamp(heat, 0.0, 1.5) * 1.3 * length(MODEL_MATRIX[1].xyz);
	v_uv = frame_uv[int(mod(floor(TIME * fps), 6.0))];
	vec3 org = MODEL_MATRIX[3].xyz + vec3(0.0, lift, 0.0) + normalize(INV_VIEW_MATRIX[2].xyz) * pull;
	vec3 w = flora_place(VERTEX.xy, org, geo, vec4(0.0, 0.0, 0.0, 0.0), 1.0, k, 0.0, TIME, INV_VIEW_MATRIX);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec4 t = texture(tex, v_uv.xy + UV * v_uv.zw);
	if (t.a < 0.5) {
		discard;
	}
	ALBEDO = mix(t.rgb, t.rgb * vec3(0.8, 0.45, 0.35), smoky);
	ALPHA = 1.0;
}
