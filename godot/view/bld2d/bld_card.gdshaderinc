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

vec3 bld_srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
