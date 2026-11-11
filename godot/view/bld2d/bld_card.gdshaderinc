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

// (Q8 ⑥) How a WHEAT row is drawn in that window (BldEcon.notch_sink — the same sum). Inside the window: the full dip, as
// bld_cut_sink (what stands behind is seen exactly as before). Outside it the row does not come back up on one smooth slope
// shared by all six rows (their dips lined up on the screen → a clean V with sheared ears, a scissor cut). It climbs back in
// ear clumps over the same reach (ramp * BLD_NOTCH_REACH): every clump (BLD_NOTCH_CLUMP wide, a little wider or narrower per
// row and per side) stands at one height, so its ears are not sheared, and rises to it from the one before in a short
// rounded step at its inner edge (BLD_NOTCH_STEP = the share of the clump the step takes; the first one starts from the dip,
// so there is no wall at the edge of the window). The clump by the gap is the shortest, each one further out about an ear
// taller, along a gentle shoulder ((1 - s)^BLD_NOTCH_ROUND), and each reads the shoulder at its own spot (hash): rows do not
// line up, the side is ragged like the top of the field. seed = per row (bld_row_seed); < 0 = bld_cut_sink (fence).
// (Q14) Even clumps climbing by even steps showed on screen as the back row's staircase — a ruled diagonal with teeth. So the
// clump borders are shifted (BLD_NOTCH_WIDE, in clump widths: narrow and wide clumps mix), each clump reads the shoulder at its
// own middle (a wide clump steps up a lot, a narrow one a little) +- BLD_NOTCH_VARY / 2 (VARY < 1 - WIDE keeps it rising
// outward), and each row / side is back at full height a little sooner (up to BLD_NOTCH_SHORT of the reach).
const float BLD_NOTCH_CLUMP = 0.16;
const float BLD_NOTCH_REACH = 1.0;
const float BLD_NOTCH_STEP = 0.36;
const float BLD_NOTCH_ROUND = 1.3;
const float BLD_NOTCH_WIDE = 0.56;
const float BLD_NOTCH_VARY = 0.4;
const float BLD_NOTCH_SHORT = 0.15;
float bld_hash(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float bld_row_seed(vec3 org, float front) {
	return 1.0 + fract(front * 3.7 + 0.31) * 61.0 + fract(org.x * 0.37 + org.z * 0.71) * 7.0;
}

// how far clump i (its middle at mid, in clump widths) is sunk, 0..1
float bld_notch_level(float i, float mid, float s0, float cw, float reach) {
	if (i < 0.0) {
		return 1.0;
	}
	float s = clamp((mid + BLD_NOTCH_VARY * (bld_hash(s0 + i * 7.31) - 0.5)) * cw / reach, 0.0, 1.0);
	return pow(1.0 - s, BLD_NOTCH_ROUND);
}

// inner border of clump j, in clump widths (the first clump starts at the edge of the window)
float bld_notch_edge(float j, float s0) {
	if (j <= 0.0) {
		return 0.0;
	}
	return j + BLD_NOTCH_WIDE * (bld_hash(s0 + j * 3.17) - 0.5);
}

float bld_notch_sink(float x, vec3 cut, float h, float seed) {
	float d = max(max(cut.x - x, x - cut.y), 0.0);
	float depth = h - min(cut.z, h);
	if (seed < 0.0 || d <= 0.0 || depth <= 0.0) {
		return bld_cut_sink(x, cut, h);
	}
	float s0 = seed + step(cut.y, x) * 5.3;
	float cw = BLD_NOTCH_CLUMP * (0.75 + 0.5 * bld_hash(s0));
	float reach = BLD_CUT_RAMP * max(1.0, depth / BLD_CUT_DEEP) * BLD_NOTCH_REACH * (1.0 - BLD_NOTCH_SHORT * bld_hash(s0 + 2.9));
	float u = d / cw;
	float c = floor(u);                // the clump: its borders are shifted, so it may be the one before or after
	float e0 = bld_notch_edge(c, s0);
	float e1 = e0;
	if (u < e0) {
		c -= 1.0;
		e0 = bld_notch_edge(c, s0);
	} else {
		e1 = bld_notch_edge(c + 1.0, s0);
		if (u >= e1) {
			c += 1.0;
			e0 = e1;
			e1 = bld_notch_edge(c + 1.0, s0);
		}
	}
	return depth * mix(bld_notch_level(c - 1.0, (bld_notch_edge(c - 1.0, s0) + e0) * 0.5, s0, cw, reach), bld_notch_level(c, (e0 + e1) * 0.5, s0, cw, reach),
		smoothstep(0.0, BLD_NOTCH_STEP, (u - e0) / (e1 - e0)));
}

// (Q8 ⑦) Grow-back of a wheat row after its sheaves were carted away (BldEcon regrow — view only): grow 0 → 1. The picture rises
// out of the ground (x = how much of its height shows, eased) and is squashed a little while short (y = picture scale), ear
// clumps a touch apart in time so the top is not a ruler line. z = how ripe it looks (0 young green → 1 the picture's gold).
const float BLD_GROW_SQUASH = 0.6;
const float BLD_GROW_CLUMP = 0.31;
const float BLD_GROW_LATE = 0.3;
const vec3 BLD_GROW_YOUNG = vec3(0.55, 1.04, 0.95);
vec3 bld_grow(float grow, float x, float seed) {
	float u = x / BLD_GROW_CLUMP + seed;
	float i = floor(u);
	float late = mix(bld_hash(seed * 3.1 + i * 5.77), bld_hash(seed * 3.1 + (i + 1.0) * 5.77), smoothstep(0.5, 1.0, u - i));
	float g = clamp(grow * (1.0 + BLD_GROW_LATE) - BLD_GROW_LATE * late, 0.0, 1.0);
	float e = g * g * (3.0 - 2.0 * g);
	return vec3(e, mix(BLD_GROW_SQUASH, 1.0, e), smoothstep(0.35, 0.95, g));
}

// Picture v for a card fragment: sunk by sink (world units) and squashed to sc of its height, both from the foot. < 0 = nothing there.
float bld_sunk_v(float v, float sink, float sc, float h) {
	return 1.0 - ((1.0 - v) + sink / h) / sc;
}

// Pull (the ripe wheat forest — Bld2D.wheat_pull): view-space z to add to every vertex of a card. The whole row comes toward the
// camera along the view ray, the picture does not move on screen. The rows of the forest then stand almost in one plane — the
// field's front face: the screen outline (outline_post, by depth jumps) draws no line between them, the forest is one mass, and
// nobody is seen half inside it (the residents work at its front edge — BldEcon.wheat_stand).

vec3 bld_srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
