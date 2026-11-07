## (P1 성능) 모델마다 삼각형 수 — 몸 · 접힌 곳 선 · 멀리 LOD(있으면). 출력 줄 머리 "TRI".
## godot --headless --path . -s tools/ta_tri_count.gd [-- flora]
extends SceneTree


func _init() -> void:
	var names: Array = []
	for f in DirAccess.get_files_at("res://art/models/flora"):
		if f.ends_with(".glb"):
			names.append("flora/" + f.get_basename())
	for f in DirAccess.get_files_at("res://art/models"):
		if f.ends_with(".glb"):
			names.append(f.get_basename())
	for n: String in names:
		var m := Art.model(n)
		var b := 0
		var l := 0
		if m["mesh"] != null:
			b = (m["mesh"] as ArrayMesh).surface_get_array_index_len(0) / 3
		if m["lines"] != null:
			l = (m["lines"] as ArrayMesh).surface_get_array_index_len(0) / 3
		print("TRI %s body %d lines %d" % [n, b, l])
	quit()
