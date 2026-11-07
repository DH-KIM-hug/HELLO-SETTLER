## 걸음 동작의 '발이 땅을 미는 빠르기' 재기 — 동작 1배속에서 디딘(낮은) 발이 몸 뒤로 미끄러지는 빠르기 (칸/초, 모델 크기 포함)
## godot --headless --path . -s tools/measure_stride.gd → ResidentModel.STRIDE 값
extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for cfg: Array in [["walk", 10.0, ""], ["carry", 10.0, "밀"], ["run", 2.5, ""], ["walk_elder", 30.0, ""]]:
		var r := Resident.new()
		r.id = 7
		r.age = cfg[1]
		var m := ResidentModel.new()
		root.add_child(m)
		m.setup_from(r)
		var clip: String = cfg[0]
		var p := m._player
		p.speed_scale = 1.0
		p.play(clip, 0.0)
		var ln := p.get_animation(clip).length
		var fl := m.skel.find_bone("foot.L")
		var fr := m.skel.find_bone("foot.R")
		var n := 240
		var vals := []
		var prev_low := Vector3.ZERO
		var prev_key := ""
		for i in n + 1:
			p.seek(ln * i / n, true)
			p.advance(0.0)
			var gl := m.skel.transform
			var nd: Node = m.skel.get_parent()
			while nd != null and nd is Node3D:
				gl = (nd as Node3D).transform * gl
				if nd == m:
					break
				nd = nd.get_parent()
			var a := gl * m.skel.get_bone_global_pose(fl).origin
			var b := gl * m.skel.get_bone_global_pose(fr).origin
			var key := "L" if a.y < b.y else "R"
			var low := a if key == "L" else b
			if key == prev_key:
				vals.append(Vector2(low.x - prev_low.x, low.z - prev_low.z).length() / (ln / n))
			prev_low = low
			prev_key = key
		vals.sort()
		var acc := 0.0
		for v: float in vals:
			acc += v
		var k := m.scale.x * m.pose.scale.y
		print("STRIDE %s len=%.3f median=%.3f mean=%.3f cells/s at speed_scale 1 (scale %.3f) per unit scale median=%.3f" % [clip, ln, vals[vals.size() / 2], acc / vals.size(), k, vals[vals.size() / 2] / k])
		m.free()
	quit()
