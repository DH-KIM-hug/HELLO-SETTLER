// 2D flora / prop picture placement (RENDERING.md 확정 2026-11-08 — world 3D, everything else 2D). Shared by flora_card.gdshader
// (one card: its own texture or a rect of an atlas) and flora_card_multi.gdshader (a whole atlas group in ONE MultiMesh draw).
// Same rule as the building cards (view/bld2d/bld_card.gdshaderinc): right = camera right, so the drawing always faces the
// orthographic camera; sizes come from where the 3D model stood on screen (tools/flora2d/measure.json), times the instance size k.
//  mode 0 CARD    upright; bottom edge on the ground at org + toward-camera * front (the model's nearest ground point) — residents
//                 in front draw over it, those behind are hidden. Up is stretched by 1/cam_up.y so it shows 1:1.
//  mode 1 GROUND  lying flat (lily pads, fallen leaves, litter), stretched toward the camera by 1/sin(pitch); centred on org + cy.
//  mode 2 CENTRE  upright, the picture centre at org + up * cy (things in the air: the giant sunflower head, seeds, flames, smoke).
// geo = (w, h, front, dx) world units at scale 1 · ex = (mode, cy, sway, depth front) · flip = -1 mirrors about the origin.
// Depth front (card mode): the card is pushed straight away from the camera (screen position unchanged — orthographic) so its
// depth is that of a plane `depth front` in front of the origin instead of `front` — a great tree whose roots / leaf carpet reach
// far toward the camera still hides only what stands behind its trunk, not the residents walking on its carpet.

vec3 flora_place(vec2 corner, vec3 org, vec4 geo, vec4 ex, float flip, float k, float phase, float t, mat4 inv_view) {
	vec3 right = inv_view[0].xyz;
	right = normalize(vec3(right.x, 0.0, right.z));
	vec3 back = inv_view[2].xyz;
	vec3 back_h = normalize(vec3(back.x, 0.0, back.z));
	float up01 = corner.y + 0.5;
	float sway = ex.z * up01 * up01 * sin(t * 1.3 + phase) * geo.y * 0.025;
	float x = flip * (corner.x * geo.x + geo.w) * k + sway * k;
	float cu = max(inv_view[1].y, 0.3);
	if (ex.x < 0.5) {
		vec3 base = org + back_h * (geo.z * k);
		float hy = up01 * geo.y * k / cu;
		// push away from the camera, but never under the ground: a point hy above the base can travel hy / sin(pitch) along the
		// view ray before it reaches the ground (bottom edge 0 → the drawn base stays on the ground, in front of the terrain)
		float push = min((geo.z - ex.w) * k * dot(back_h, back), hy / max(back.y, 0.3) * 0.9);
		return base + right * x + vec3(0.0, hy, 0.0) - back * max(push, 0.0);
	}
	if (ex.x < 1.5) {
		float sb = max(back.y, 0.3);
		return org + right * x - back_h * ((corner.y * geo.y + ex.y) * k / sb);
	}
	return org + right * x + vec3(0.0, (corner.y * geo.y + ex.y) * k / cu, 0.0);
}
