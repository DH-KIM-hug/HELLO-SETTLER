## 주민 동작 분포 (헤드리스 가능): 넓은 세상 기본 확대에서 병 2시간 동안 화면이 실제로 트는 동작(클립) 세기
## 실행: godot --headless --path godot -s res://tools/anim_histogram.gd -- [배속=1] [병 시간=2] [시작 시각=9]
extends SceneTree

const SEED := 20261106
var scene: Node
var frame := 0
var speed := 1.0
var hours := 2.0
var start_h := 9.0
var days := 1.0
var clips := {}
var sims := {}
var phase := {}       # 같은 클립을 트는 사람들의 재생 위치 (동기화 확인)
var samples := 0
var jar_t := 0.0
var pair_n := 0
var pair_sync := 0


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	speed = float(a[0]) if a.size() > 0 else speed
	hours = float(a[1]) if a.size() > 1 else hours
	start_h = float(a[2]) if a.size() > 2 else start_h
	days = float(a[3]) if a.size() > 3 else days
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	scene = load("res://scenes/world.tscn").instantiate()
	scene.world_seed = SEED
	root.add_child(scene)


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 4:
		return false
	if frame == 4:
		scene.set_process(false)
		scene.set_debug_mode(false)
		scene.village.water.offline = true
		scene.world.advance(Balance.DAY * days)          # 하루 살게 둔 뒤 (일거리가 생김)
		var now: float = scene.village.hour_now() * Balance.HOUR
		scene.world.advance(fposmod(start_h * Balance.HOUR - now, Balance.DAY))
		scene.village.water.offline = false
		scene.cam.ppu = 16.0
		scene.cam.ppu_goal = 16.0
		scene.cam._apply()
		scene.look_at_ground(scene.village.center + Vector2(1, 1))
		scene.clock.set_speed(Balance.SPEEDS.find(speed))
		print("시작 %.2f시 · 주민 %d명 · 배속 ×%.0f" % [scene.village.hour_now(), scene.village.people.size(), speed])
		return false
	for _i in 200:
		if _one():
			_report()
			quit()
			return true
	return false


func _one() -> bool:
	var dt := 1.0 / 30.0
	var w_dt := dt
	# ×1은 화면 2시간을 다 돌리지 않고 화면 0.5초 걸음으로 (동작 시간은 같은 비율로 흐름)
	if speed <= 1.0:
		w_dt = 0.5
	scene.clock.tick(w_dt)
	for vv: Array in scene.village_views():
		(vv[1] as VillageView).sync(w_dt)
	jar_t += w_dt * speed
	frame += 1
	if frame % 6 == 0:
		var vw: VillageView = scene.view
		var pos := {}
		for r: Resident in scene.village.people:
			var m: ResidentModel = vw.residents.get(r.id)
			if m == null or not m.visible:
				continue
			var c: String = m._clip_now
			clips[c] = clips.get(c, 0) + 1
			sims[r.anim] = sims.get(r.anim, 0) + 1
			samples += 1
			if m._player != null and m._player.current_animation != "":
				if not pos.has(c):
					pos[c] = []
				pos[c].append(m._player.current_animation_position / maxf(0.01, m._player.current_animation_length))
		for c: String in pos:          # 같은 클립을 트는 둘이 거의 같은 자리(한 바퀴의 3% 안)에 있는 비율
			var a: Array = pos[c]
			for i in a.size():
				for j in range(i + 1, a.size()):
					var d := absf(float(a[i]) - float(a[j]))
					pair_n += 1
					if minf(d, 1.0 - d) < 0.03:
						pair_sync += 1
	return jar_t >= hours * Balance.HOUR


func _report() -> void:
	var lod: bool = (scene.view as VillageView)._resident_lod_close()
	print("확대 %.1f · 가까이 LOD=%s · 표본 %d" % [scene.cam.ppu, lod, samples])
	print("[desync] 같은 클립 짝 %d · 박자가 맞은 짝 %.0f%% (엇갈렸다면 약 6%%)" % [pair_n, 100.0 * pair_sync / maxf(1, pair_n)])
	for tag: String in ["clip", "sim"]:
		var d: Dictionary = clips if tag == "clip" else sims
		var ks := d.keys()
		ks.sort_custom(func(x, y) -> bool: return d[x] > d[y])
		var s := ""
		for k in ks:
			s += "%s %.0f%% · " % [k if k != "" else "(none)", 100.0 * d[k] / maxf(1, samples)]
		print("[%s] %s" % [tag, s])
