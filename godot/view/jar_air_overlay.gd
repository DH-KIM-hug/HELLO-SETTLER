## 병의 공기를 화면에 — WORLD_EVENTS 6장 '조짐은 병 시점에서 먼저 보인다' (숫자 대신 뿌연 유리·누런 하늘) · 3장 뚜껑 열기.
## 화면 전체를 덮는 얇은 막 (UI 아래, 3D 위). 시뮬레이션은 읽기만:
##  · 김 (JarAir.glass_fog · 곰팡이 조짐 Mold.omen_fog) → 유리 안쪽에 서린 김: 가장자리부터 뿌연 얼룩 + 흘러내리는 물줄기 몇 가닥
##  · 탁한 공기 (JarAir.stale 0.35↑) → 하늘이 누렇게 바램
##  · [E3-7 이슬의 하루 박자] 낮에 오르는 김 (JarWater.dew_vapour × 김) → 유리 위쪽이 엷게 뿌예짐 (습할수록 짙게, 닦으면 걷힘)
##  · 뚜껑이 열림 → 위에서 쏟아지는 거인의 방 빛 + 떠다니는 먼지 알갱이, 김은 빠르게 걷힘. 닫힐 때 부드럽게 사라짐
##  · [거인의 손 B6] 유리의 먼지막 (GiantHand.dust_shown) · 커튼 (낮이 어둑) · 감싼 손 (가장자리 손가락 + 따뜻한 빛) · 닦는 반짝임 (play_wipe)
## 밤에는 막도 함께 어두워진다.
class_name JarAirOverlay
extends ColorRect

const SHADER := """
shader_type canvas_item;
uniform float fog = 0.0;
uniform float lid = 0.0;
uniform float stale = 0.0;
uniform float night = 0.0;
uniform float dust = 0.0;
uniform float dim = 0.0;
uniform float cup = 0.0;
uniform float wipe = 0.0;
uniform float vapour = 0.0;
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
	// [B6] 닦는 중: 비스듬한 띠가 지나간 자리는 김·먼지막이 걷힘
	float sw = (uv.x + uv.y * 0.6) / 1.6;
	float wpos = wipe * 1.25 - 0.12;
	float wiped = (wipe > 0.001 && wipe < 0.999) ? smoothstep(wpos + 0.02, wpos - 0.02, sw) : 0.0;
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
		a = clamp(a * fog * (1.0 - wiped), 0.0, 0.85);
		col = vec4(vec3(0.86, 0.92, 0.93), a);
		col.rgb = mix(col.rgb, vec3(1.0), drop * 0.6);
		col.a = max(col.a, drop * 0.5 * fog * (1.0 - wiped));
	}
	// [E3-7] 낮의 김: 유리 위쪽(뚜껑 쪽)에 엷은 서림 — 아래로 갈수록 옅어지고, 천천히 일렁인다
	if (vapour > 0.001) {
		vec2 q2 = floor(px / 4.0) * 4.0 / size.y;
		float n2 = noise(q2 * 5.0 + vec2(t * 0.02, -t * 0.03)) * 0.65 + noise(q2 * 13.0 - vec2(0.0, t * 0.05)) * 0.35;
		float top = smoothstep(0.5, 0.02, uv.y + (n2 - 0.5) * 0.14);
		float av = clamp(top * (0.6 + 0.7 * n2) * vapour * (1.0 - wiped), 0.0, 0.6);
		col.rgb = mix(col.rgb, vec3(0.9, 0.95, 0.97), av / max(col.a + av, 0.001));
		col.a = col.a + av * (1.0 - col.a);
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
	// [거인의 손 B6] 유리에 앉은 먼지막 (닦으면 걷힘)
	if (dust > 0.001) {
		float sp = step(0.82, hash(floor(px / 3.0))) * 0.6 + noise(px / 90.0) * 0.4;
		float da = dust * (0.10 + 0.18 * sp) * (1.0 - wiped);
		col.rgb = mix(col.rgb, vec3(0.62, 0.6, 0.55), da / max(col.a + da, 0.001));
		col.a = max(col.a, da);
	}
	// [B6] 커튼: 낮의 볕이 줄어 어둑
	if (dim > 0.001) {
		col.rgb = mix(col.rgb, vec3(0.16, 0.15, 0.22), dim / max(col.a + dim, 0.001));
		col.a = col.a + dim * (1.0 - col.a);
	}
	// [B6] 손으로 감싸기: 양쪽 가장자리에서 거인의 손가락이 유리를 감쌈 (둥근 손끝 + 그림자) + 따뜻한 빛
	if (cup > 0.001) {
		float ex = abs(uv.x - 0.5) * 2.0;
		float glow = smoothstep(0.35, 1.0, ex) * 0.32;
		float fing = 0.0;
		float rim = 0.0;
		float shade = 0.0;
		float rad = 0.042 * size.y;
		for (int i = 0; i < 4; i++) {
			float fy = (0.34 + float(i) * 0.115 + 0.012 * float(i % 2)) * size.y;
			float reach = (0.13 + 0.035 * float(i == 1 || i == 2) - 0.03 * float(i == 3)) * size.x;
			for (int sd = 0; sd < 2; sd++) {
				float x0 = sd == 0 ? -rad : size.x + rad;
				float x1 = sd == 0 ? reach : size.x - reach;
				vec2 a0 = vec2(x0, fy);
				vec2 b0 = vec2(x1, fy + (sd == 0 ? 1.0 : -1.0) * 0.01 * size.y);
				vec2 pa = px - a0;
				vec2 ba = b0 - a0;
				float hh = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
				float dd = length(pa - ba * hh) - rad;
				fing = max(fing, smoothstep(1.5, -1.5, dd));
				rim = max(rim, smoothstep(3.5, 0.0, abs(dd + 1.5)) * step(dd, 1.0));
				shade = max(shade, smoothstep(26.0, 0.0, dd) * 0.35);
			}
		}
		vec3 skin = vec3(0.93, 0.74, 0.62);
		vec3 c4 = mix(vec3(1.0, 0.72, 0.42), vec3(0.25, 0.16, 0.12), shade * (1.0 - fing));
		c4 = mix(c4, skin, fing);
		c4 = mix(c4, vec3(0.55, 0.36, 0.3), rim * fing);
		float a4 = max(glow, max(fing * 0.92, shade)) * cup;
		col.rgb = mix(col.rgb, c4, clamp(a4 / max(col.a + a4, 0.001), 0.0, 1.0));
		col.a = clamp(col.a + a4 * (1.0 - col.a), 0.0, 1.0);
	}
	// [B6] 유리 닦기: 비스듬히 지나가는 반짝임
	if (wipe > 0.001 && wipe < 0.999) {
		float a5 = smoothstep(0.09, 0.0, abs(sw - wpos)) * 0.55;
		col.rgb = mix(col.rgb, vec3(1.0), a5 / max(col.a + a5, 0.001));
		col.a = max(col.a, a5);
	}
	col.rgb *= mix(vec3(1.0), vec3(0.35, 0.42, 0.65), night * 0.85);
	COLOR = col;
}
"""

var v: Village
var mat: ShaderMaterial
var lid := 0.0                        # 화면의 뚜껑 열림 정도 (부드럽게)
var fog := 0.0
var dust := 0.0                       # [거인의 손 B6] 유리의 먼지막 · 커튼 · 감싼 손 · 닦는 반짝임 (화면만 부드럽게)
var dim := 0.0
var warm := 0.0
var wipe := 0.0
var vapour := 0.0                     # [E3-7] 낮의 김 (화면만 부드럽게)
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
	var goal := GiantHand.fog_shown(v)        # 김 · 곰팡이 조짐 — 닦으면 걷히고 천천히 다시 서림 (B6)
	if wipe > 0.0 and wipe < 1.0:              # 닦는 동안은 띠가 지나간 자리만 걷힘 (셰이더) — 다 닦으면 그대로
		pass
	elif wipe >= 1.0:
		fog = goal
		dust = GiantHand.dust_shown(v)
	else:
		fog = lerpf(fog, goal, 1.0 - exp(-(4.0 if open else 1.5) * dt))
		dust = lerpf(dust, GiantHand.dust_shown(v), 1.0 - exp(-4.0 * dt))
	var day := 1.0 - night
	dim = lerpf(dim, (1.0 - GiantHand.curtain_light(v.water.curtain)) * 0.32 * day, 1.0 - exp(-3.0 * dt))
	warm = move_toward(warm, 1.0 if v.water.cup_left > 0.0 else 0.0, dt * 1.5)
	vapour = lerpf(vapour, vapour_goal(v), 1.0 - exp(-1.5 * dt))
	if wipe > 0.0:
		wipe = wipe + dt / 0.7 if wipe < 1.0 else 0.0
	mat.set_shader_parameter("fog", fog * (1.0 - 0.75 * lid))      # 열면 유리의 김이 금방 걷힌다
	mat.set_shader_parameter("lid", lid)
	mat.set_shader_parameter("stale", v.air.stale if v.air != null else 0.0)
	mat.set_shader_parameter("night", night)
	mat.set_shader_parameter("t", _t)
	mat.set_shader_parameter("dust", dust * (1.0 - 0.5 * lid))
	mat.set_shader_parameter("dim", dim)
	mat.set_shader_parameter("cup", warm)
	mat.set_shader_parameter("wipe", minf(wipe, 1.0))
	mat.set_shader_parameter("vapour", vapour * (1.0 - 0.8 * lid))
	mat.set_shader_parameter("size", get_viewport_rect().size)
	visible = fog > 0.01 or lid > 0.01 or (v.air != null and v.air.stale > 0.36) or dust > 0.01 or dim > 0.01 or warm > 0.01 or wipe > 0.0 or vapour > 0.01


## [E3-7] 낮의 김이 유리 위쪽에 서리는 정도 0~0.6 — 습할수록 짙고 (김 0.1 → 거의 없음 · 0.65↑ → 짙음), 닦으면 걷혔다가 다시 서림
static func vapour_goal(vg: Village) -> float:
	if vg.water == null:
		return 0.0
	var hum := vg.air.humid if vg.air != null else vg.water.humid
	return vg.water.dew_vapour() * clampf((hum - 0.05) / 0.6, 0.0, 1.0) * 0.6 * (1.0 - vg.water.glass_clear)


## [B6] 유리 닦기의 반짝임 한 번
func play_wipe() -> void:
	wipe = 0.001
