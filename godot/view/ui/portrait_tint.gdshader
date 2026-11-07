// 그림 초상 층 (PortraitComposer) — tinted: 회색 바탕(0.6 = 물들일 색)에 색을 곱함 · use_cut: 모자 위로 삐져나온 머리를 자름
shader_type canvas_item;

uniform vec4 tint = vec4(1.0);
uniform bool tinted = false;
uniform bool use_cut = false;
uniform float alpha = 1.0;
uniform sampler2D cut : filter_linear_mipmap;
varying vec4 modulate_col;     // 정점 색 (= modulate) — fragment의 COLOR엔 그림 색이 이미 곱해져 있어 따로 받음

void vertex() {
	modulate_col = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 rgb = tinted ? clamp(vec3(c.r) * tint.rgb / 0.6, 0.0, 1.0) : c.rgb;
	float a = c.a * alpha;
	if (use_cut) {
		a *= 1.0 - texture(cut, UV).r;
	}
	COLOR = vec4(rgb, a) * modulate_col;
}
