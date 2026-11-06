## 병의 공기를 화면에 — WORLD_EVENTS 6장 '조짐은 병 시점에서 먼저 보인다' (숫자 대신 뿌연 유리·누런 하늘) · 3장 뚜껑 열기.
## 화면 전체를 덮는 얇은 막 (UI 아래, 3D 위). 시뮬레이션은 읽기만:
##  · 김 (JarAir.glass_fog · 곰팡이 조짐 Mold.omen_fog) → 유리 안쪽에 서린 김: 가장자리부터 뿌연 얼룩 + 흘러내리는 물줄기 몇 가닥
##  · 탁한 공기 (JarAir.stale 0.35↑) → 하늘이 누렇게 바램
##  · 뚜껑이 열림 → 위에서 쏟아지는 거인의 방 빛 + 떠다니는 먼지 알갱이, 김은 빠르게 걷힘. 닫힐 때 부드럽게 사라짐
## 밤에는 막도 함께 어두워진다.
class_name JarAirOverlay
extends ColorRect

const SHADER := """
shader_type canvas_item;
uniform float fog = 0.0;
uniform float lid = 0.0;
uniform float stale = 0.0;
uniform float night = 0.0;
uniform float t = 0.0;
uniform vec2 size = vec2(360.0, 640.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = uv * size;
	vec4 col = vec4(0.0);
	// 서린 김: 가장자리일수록 짙고, 얼룩덜룩 (도트 크기 4px 칸으로 끊어 그림체에 맞춤)
	if (fog > 0.001) {
		vec2 q = floor(px / 4.0) * 4.0 / size.y;
		float edge = max(abs(uv.x - 0.5) * 2.0 * (size.x / size.y) * 1.25, abs(uv.y - 0.5) * 2.0);
		edge = max(edge, length((uv - 0.5) * vec2(size.x / size.y, 1.0)) * 1.55);
		float n = noise(q * 7.0 + vec2(0.0, t * 0.01)) * 0.6 + noise(q * 19.0) * 0.4;
		float a = smoothstep(0.3, 1.05, edge + (n - 0.5) * 0.5) * 0.72 + 0.1 + (n - 0.5) * 0.08;
		// 흘러내린 물줄기: 김이 걷힌 세로 줄 몇 가닥
		float col_id = floor(px.x / 6.0);
		float streak = step(0.93, hash(vec2(col_id, 3.0)));
		float drop_end = hash(vec2(col_id, 7.0)) * 0.7 + 0.1;
		a *= 1.0 - streak * step(uv.y, drop_end) * 0.75;
		float drop = streak * smoothstep(0.012, 0.0, abs(uv.y - drop_end)) ;
		a = clamp(a * fog, 0.0, 0.85);
		col = vec4(vec3(0.86, 0.92, 0.93), a);
		col.rgb = mix(col.rgb, vec3(1.0), drop * 0.6);
		col.a = max(col.a, drop * 0.5 * fog);
	}
	// 누런 하늘 (탁한 공기)
	float y = smoothstep(0.35, 0.9, stale) * 0.16;
	col.rgb = mix(col.rgb, vec3(0.86, 0.72, 0.36), y / max(col.a + y, 0.001));
	col.a = max(col.a, y);
	// 뚜껑이 열림: 위에서 쏟아지는 빛 + 먼지 알갱이
	if (lid > 0.001) {
		// 위(뚜껑)에서 퍼지는 부드러운 빛 + 느리게 흔들리는 빛줄기
		vec2 src = vec2(0.5, -0.25);
		vec2 d = (uv - src) * vec2(size.x / size.y, 1.0);
		float r = length(d);
		float glow = smoothstep(1.25, 0.2, r);
		float ang = atan(d.x, d.y);
		float rays = 0.45 + 0.55 * smoothstep(-0.2, 0.8, sin(ang * 11.0 + sin(t * 0.4) * 0.6) * sin(ang * 5.0 - t * 0.25) + 0.3);
		float mouth = smoothstep(0.09, 0.0, uv.y);           // 열린 병 입구 쪽 가장자리가 환함
		float a2 = (glow * rays * 0.75 + mouth * 0.55) * lid;
		// 떠다니는 먼지 알갱이 (2px, 천천히 내려앉음)
		vec2 mp = px + vec2(sin(t * 0.7 + floor(px.y / 40.0)) * 6.0, -t * 7.0);
		vec2 cell = floor(mp / 5.0);
		float mote = step(0.992, hash(cell)) * step(length(fract(mp / 5.0) - 0.5), 0.3);
		float m = mote * glow * lid;
		vec3 warm = vec3(1.0, 0.88, 0.6);
		float a_tot = a2 + m * 0.8;
		col.rgb = mix(col.rgb, warm, clamp(a_tot / max(col.a + a_tot, 0.001), 0.0, 1.0));
		col.a = clamp(col.a + a_tot * (1.0 - col.a), 0.0, 1.0);
	}
	col.rgb *= mix(vec3(1.0), vec3(0.35, 0.42, 0.65), night * 0.85);
	COLOR = col;
}
"""

var v: Village
var mat: ShaderMaterial
var lid := 0.0                        # 화면의 뚜껑 열림 정도 (부드럽게)
var fog := 0.0
var _t := 0.0


func setup(village: Village) -> void:
	v = village
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(1, 1, 1, 0)
	mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	mat.shader = sh
	material = mat


func update_from(dt: float, night: float) -> void:
	if v == null:
		return
	_t += dt
	var open := v.air != null and v.air.lid_open
	lid = move_toward(lid, 1.0 if open else 0.0, dt * (2.5 if open else 1.2))
	var goal := 0.0
	if v.air != null:
		goal = v.air.glass_fog()
	if v.mold != null:
		goal = maxf(goal, v.mold.omen_fog)
	fog = lerpf(fog, goal, 1.0 - exp(-(4.0 if open else 1.5) * dt))
	mat.set_shader_parameter("fog", fog * (1.0 - 0.75 * lid))      # 열면 유리의 김이 금방 걷힌다
	mat.set_shader_parameter("lid", lid)
	mat.set_shader_parameter("stale", v.air.stale if v.air != null else 0.0)
	mat.set_shader_parameter("night", night)
	mat.set_shader_parameter("t", _t)
	mat.set_shader_parameter("size", get_viewport_rect().size)
	visible = fog > 0.01 or lid > 0.01 or (v.air != null and v.air.stale > 0.36)
