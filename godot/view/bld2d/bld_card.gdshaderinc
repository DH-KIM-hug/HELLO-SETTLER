// 2D building picture placement (RENDERING.md 확정 2026-11-08 — world 3D, buildings 2D). Shared by bld_card.gdshader (one building,
// its own near picture) and bld_card_multi.gdshader (every building at village zoom from one far atlas, MultiMesh = 1 draw call).
// Rule from the spike / paper-doll residents: right = camera right (horizontal), so the drawing always faces the orthographic camera.
//  mode 0 CARD   upright; up = world up stretched by 1/cam_up.y so the picture shows 1:1 on screen. Its bottom edge stands on the
//                ground at the footprint's camera-nearest point (org + toward-camera * front) — the drawn base never sinks into the
//                terrain, and residents in front of the building draw over it, those behind are hidden by it.
//  mode 1 GROUND lying flat on the ground, stretched toward the camera by 1/sin(pitch) so it too shows 1:1; centred on org.
//                For flat places residents walk over (plaza, salt pans, graveyard, pasture, ferry landing).
// geo = (w, h, front, dx) in world units; flip = -1 mirrors left-right.
vec3 bld_place(vec2 corner, vec3 org, vec4 geo, float mode, float flip, float k, mat4 inv_view) {
	vec3 right = inv_view[0].xyz;
	right = normalize(vec3(right.x, 0.0, right.z));
	vec3 back = inv_view[2].xyz;
	vec3 back_h = normalize(vec3(back.x, 0.0, back.z));
	float x = (corner.x * flip * geo.x + geo.w) * k;
	if (mode < 0.5) {
		float cu = max(inv_view[1].y, 0.3);
		vec3 base = org + back_h * (geo.z * k);
		return base + right * x + vec3(0.0, (corner.y + 0.5) * geo.y * k / cu, 0.0);
	}
	float sb = max(back.y, 0.3);
	return org + right * x - back_h * (corner.y * geo.y * k / sb);
}

// Wind (the wheat rows): the top edge leans along the camera right by amp world units, the foot stays put (same curve as the
// flower cards, flora_card.gdshaderinc). The phase runs along the strip and from row to row, so a wave crosses the field.
vec3 bld_sway(vec3 w, vec2 corner, vec3 org, vec4 geo, float amp, float k, float t, mat4 inv_view) {
	vec3 right = normalize(vec3(inv_view[0].x, 0.0, inv_view[0].z));
	float up01 = corner.y + 0.5;
	float phase = org.x * 0.7 + org.z * 0.9 + geo.z * 2.6 + corner.x * geo.x * 0.8;
	return w + right * (amp * k * up01 * up01 * sin(t * 1.3 + phase));
}

// Depth-only lean (the wheat rows): view-space z to add to a card vertex — the foot comes toward the camera along the view ray by
// lean world units, the top stays, the picture does not move on screen. Rows standing one behind another then form one sloping
// surface (the top of the wheat): the screen outline (outline_post, by depth jumps) draws no line between them, and a villager
// standing among them is covered up to the top of the wheat. tools/bld2d/wheat_field.py (LEAN_S) sets the amounts.
// The pull grows from the top down at BLD_LEAN_SLOPE per unit of screen height (= LEAN_S / (sin cos) of the camera pitch: 0.8 of
// what makes a row meet the next row's plane exactly where that row's top covers it) and stops at lean — a tall row (the wheat
// forest) bends near its top and then stands straight, never past the front row. Needs a card mesh with rows of vertices
// (Bld2D.strip()): on a plain quad only the two ends count and the bend is lost.
const float BLD_LEAN_SLOPE = 1.609;
float bld_lean(vec2 corner, float lean, float h, float k) {
	return min(BLD_LEAN_SLOPE * (0.5 - corner.y) * h, lean) * k;
}

// Cut window (a ripe wheat row standing in front of a grave — BldEcon.grave_cut): x = card-local position along the camera right
// from the picture's centre line (world units), cut = (x0, x1, cap), h = the card's height. Between x0 and x1 nothing of the
// picture stands above cap; outside, the limit climbs back to the full height over BLD_CUT_RAMP (= BldEcon.GRAVE_RAMP) — longer
// for a deep cut (depth / BLD_CUT_DEEP times, = BldEcon.GRAVE_DEEP), so a deep dip is still a slope and not a cliff.
// → how far the picture is SUNK into the ground at x (bld_cut_sink): the wheat is not sliced off, it stands lower there — the
// ears at the top come down with it, so the notch is a dip of shorter wheat (no ruler line, no dark inside of the row showing).
// cut.z < 0 = no window.
const float BLD_CUT_RAMP = 0.6;
const float BLD_CUT_DEEP = 1.6;
float bld_cut_sink(float x, vec3 cut, float h) {
	float d = max(max(cut.x - x, x - cut.y), 0.0);
	float depth = h - min(cut.z, h);
	return depth * (1.0 - smoothstep(0.0, BLD_CUT_RAMP * max(1.0, depth / BLD_CUT_DEEP), d));
}

// Pull (the ripe wheat forest — Bld2D.wheat_pull): view-space z to add to every vertex of a card. The whole row comes toward the
// camera along the view ray, the picture does not move on screen. The rows of the forest then stand almost in one plane — the
// field's front face: the screen outline (outline_post, by depth jumps) draws no line between them, the forest is one mass, and
// nobody is seen half inside it (the residents work at its front edge — BldEcon.wheat_stand).

vec3 bld_srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
