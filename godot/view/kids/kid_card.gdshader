// 아이·아기 소품 그림 한 장 (view/kids_view.gd — 요람·돌·나비·먼지): 그림판(art/kids2d/kids_props.png)의 한 칸을
// 카메라를 보는 세로 판으로 그린다 (주민 인형·flora2d와 같은 규칙: 오른쪽 = 카메라 오른쪽(수평), 위 = 세계 위, 세로는 1/cu 늘림).
// 재질 하나 · 사각형 하나를 모든 소품이 나눠 쓰고, 소품마다 다른 것은 instance uniform 뿐. 노드의 회전·배율은 읽지 않는다.
// 빛 = 주민 인형과 같음 (해 그림자 안에서는 청록 그늘 한 단계, 조금 스스로 밝음).
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, ambient_light_disabled, specular_disabled, depth_draw_opaque, shadows_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.5;
uniform vec3 lit_tint : source_color = vec3(1.0);
uniform vec3 shade_tint : source_color = vec3(0.55, 0.76, 0.87);
uniform float self_lit = 0.5;

instance uniform vec4 rect = vec4(0.0, 0.0, 1.0, 1.0);     // 그림판의 칸 (u, v, 너비, 높이 — 0~1)
instance uniform vec4 geo = vec4(0.3, 0.3, 0.0, 0.0);      // 너비, 높이 (세계 단위), 기울임 (라디안 — 판 가운데 둘레), 카메라 쪽으로 당김
instance uniform vec4 fx = vec4(1.0, 1.0, 0.0, 0.0);       // 가로 배율, 세로 배율, 기준 (0 = 밑이 노드 자리 · 1 = 가운데가 노드 자리), 위로 올림 (화면 세로 — 세계 단위)

varying vec2 v_uv;

void vertex() {
	vec2 q = vec2(VERTEX.x * geo.x * fx.x, VERTEX.y * geo.y * fx.y);
	float c = cos(geo.z), s = sin(geo.z);
	q = vec2(c * q.x - s * q.y, s * q.x + c * q.y);
	q.y += geo.y * fx.y * 0.5 * (1.0 - fx.z) + fx.w;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	right = normalize(vec3(right.x, 0.0, right.z));
	vec3 back = INV_VIEW_MATRIX[2].xyz;
	float cu = max(INV_VIEW_MATRIX[1].y, 0.3);
	vec3 org = MODEL_MATRIX[3].xyz;
	vec3 w = org + right * q.x + vec3(0.0, q.y / cu, 0.0) + back * geo.w;
	v_uv = rect.xy + vec2(UV.x, UV.y) * rect.zw;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(back, 0.0)).xyz);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}

void fragment() {
	vec4 t = texture(tex, v_uv);
	if (t.a < alpha_cut) {
		discard;
	}
	ALBEDO = t.rgb;
	ROUGHNESS = 1.0;
}

void light() {
	float lit = step(0.5, ATTENUATION);
	DIFFUSE_LIGHT += mix(mix(shade_tint, lit_tint, lit), vec3(1.0), self_lit * (1.0 - lit));
}
