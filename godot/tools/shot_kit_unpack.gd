## 스타터킷 풀기 캡처 (OPENING 단계 8 v3.9) — 창이 필요: godot --path godot -s res://tools/shot_kit_unpack.gd
## 창조(연출 없이)로 세상을 만든 뒤 아무 데나 누름 → 특성 쪽지 → [여기에 내려놓기] → 손이 상자를 내려놓음 → 초확대 · 주민이 기어 나옴 →
## 건물 놓기 칸 (초록 · 빨강 그림자) → 하나 놓음 → [알아서 놓기] → 다 놓인 마을.
## 결과 godot_shots/: kit_pick_note · kit_pick_bad · kit_drop · kit_climb_a · kit_climb_b · kit_kid_sky · kit_tray_green · kit_tray_red · kit_placed_one · kit_placed
extends SceneTree

const SAVE_DIR := "user://shot_kit_save"
var c: Node
var s: Node
var out_dir := ""
var step := 0
var t := 0.0
var _phase_t := 0.0
var _last_phase := ""
var _shot := {}
var spot := Vector2.ZERO
var green := Vector2.ZERO


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../godot_shots").simplify_path()
	SafeArea.fake = Vector2(28, 16)
	StartFlow.navigate = false
	GameSettings.path = "user://shot_settings.cfg"
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	OS.set_environment("NAZAKJI_SAVE_DIR", SAVE_DIR)


func _save(name: String) -> void:
	name = OS.get_environment("SHOT_PREFIX") + name          # (A28) 예: SHOT_PREFIX=a28_ → godot_shots/a28_kit_climb_a.png
	root.get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " t=", snappedf(t, 0.01))


func _once(name: String) -> bool:
	if _shot.has(name):
		return false
	_shot[name] = true
	return true


func _process(dt: float) -> bool:
	t += dt
	if dt > 0.045 and step >= 1:                    # 멈칫 (A18) 기록 — 캡처를 저장한 화면은 빼고 볼 것
		print("slow frame %.0f ms (step %d, phase %s)" % [dt * 1000.0, step, (s.unpack.phase if s != null and s.get("unpack") != null else "-")])
	match step:
		0:
			root.size = Vector2i(390, 844)
			CreationPlan.clear(SAVE_DIR)
			StartFlow.plan = CreationPlan.make(20261107, 512)
			c = load(StartFlow.CREATION_SCENE).instantiate()
			c.set("instant", true)
			root.add_child(c)
			c.call("jump", "life")
			c.call("next")
			root.remove_child(c)
			c.free()
			StartFlow.take()
			StartFlow.mode = "new"
			s = load(StartFlow.GAME_SCENE).instantiate()
			root.add_child(s)
			t = 0.0
			step = 1
		1:
			if t > 2.0 and _once("bad"):
				var w: JarWorld = s.world
				var wp := Vector2.ZERO
				for k in range(0, w.water.n * w.water.n, 61):
					if w.water.depth(k) > 0.05 and w.water.inside(w.water.cx(k), w.water.cy(k), 40.0):
						wp = Vector2(w.water.cx(k), w.water.cy(k))
						break
				s.show_spot(wp)
			if t > 2.4 and _once("bad_shot"):
				_save("kit_pick_bad")
				var ch: Array = s.world.spot_choices(1)
				spot = ch[0]["p"] + Vector2(6.0, -4.0)
				if not bool(s.world.kit_spot_ok(spot.x, spot.y)["ok"]):
					spot = ch[0]["p"]
				s.show_spot(spot)
			if t > 2.9 and _once("note_shot"):
				_save("kit_pick_note")
				s.put_here()
				t = 0.0
				step = 2
		2:
			if s.arrival != null and s.unpack == null:
				t = 0.0
				step = 3
				return false
			if s.village != null and s.get("debug_mode"):
				s.set_debug_mode(false)
			var un: KitUnpack = s.unpack
			if un == null:
				var cs: Variant = s._pick.get("confirm") if not s._pick.is_empty() else null
				if cs != null and (cs as ConfirmSheet).visible:
					(cs as ConfirmSheet).answer(true)
				return false
			if un.phase != _last_phase:
				_last_phase = un.phase
				_phase_t = 0.0
				print("phase ", un.phase, " t=", snappedf(t, 0.01))
			_phase_t += dt
			match un.phase:
				"drop":
					if _phase_t > 0.45 and _once("drop"):
						_save("kit_drop")
				"climb":
					if _phase_t > 1.1 and _once("ca"):
						_save("kit_climb_a")
					if _phase_t > 2.6 and _once("cb"):
						_save("kit_climb_b")
					if _phase_t > un.climb.size() * KitUnpack.CLIMB_GAP + KitUnpack.CLIMB_T + 1.2 and _once("kid"):
						_save("kit_kid_sky")
				"tray":
					if _phase_t > 0.3 and _once("tray_sel"):
						var hut := ""
						for it: Dictionary in un.items:
							if String(it["type"]) == "오두막":
								hut = String(it["key"])
								break
						un.select(hut)
						green = spot
						for i in 32:
							var q := un.spot + Vector2(6.5, 0.0).rotated(i * TAU / 32.0 + 0.6)
							if bool(un.aim_ground(q)["ok"]):
								green = q
								break
						un.aim_ground(green)
					if _phase_t > 0.6 and _once("green"):
						_save("kit_tray_green")
						un.aim_ground(un.spot + Vector2(1.0, 0.5))
					if _phase_t > 0.8 and _once("red"):
						_save("kit_tray_red")
						un.place_at(green)
					if _phase_t > 2.2 and _once("one"):
						_save("kit_placed_one")
						un.auto_place()
				"end", "done":
					pass
		3:
			if t > 2.0 and _once("placed"):
				_save("kit_placed")
				quit(0)
	return false
