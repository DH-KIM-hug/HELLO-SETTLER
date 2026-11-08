## Reference renders for the 2D flora / prop pictures (tools/flora2d — RENDERING.md 확정 2026-11-08). Needs a window:
##   godot --path godot -s res://tools/flora2d/ref_render.gd -- <sheets.json> <out_dir> [sheet ...]
## For every sheet cell: the game's own 3D model (Art.instance / Art.parts) at the game camera (orthographic, pitch 48°, yaw 45°,
## model front toward the camera), fitted into the cell, transparent background -> <out_dir>/cells/<pic>.png
## + <out_dir>/cells/<pic>.json {ppx: cell pixels per world unit, ox, oy: model origin in cell pixels}. compose.py builds the
## magenta reference sheet for codex and measure.json (screen size / placement of each model at scale 1).
extends SceneTree

const PITCH := 48.0
const YAW := 45.0
const FILL := 0.74                 # the model fills this share of its cell

var jobs: Array = []               # [pic, spec, cell size]
var out_dir := ""
var vp: SubViewport
var cam: Camera3D
var holder: Node3D
var frame := 0
var _i := -1
var _wait := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var sheets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	out_dir = args[1]
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("cells"))
	var only := args.slice(2)
	for s: String in sheets:
		if not only.is_empty() and not s in only:
			continue
		var d: Dictionary = sheets[s]
		var cs := Vector2i(int(d["size"][0]) / int(d["grid"][0]), int(d["size"][1]) / int(d["grid"][1]))
		for c: Dictionary in d["cells"]:
			if c["spec"] != null:
				jobs.append([c["pic"], c["spec"], cs])
	vp = SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var w := Node3D.new()
	vp.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 75, 0)      # upper-left on screen (camera yaw 45°)
	w.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	w.add_child(cam)
	holder = Node3D.new()
	w.add_child(holder)


func _build(spec: Variant) -> Node3D:
	var n := Node3D.new()
	holder.add_child(n)
	var extra_yaw := 0.0
	if spec is String:
		Art.instance(n, spec)
	else:
		var d: Dictionary = spec
		extra_yaw = float(d.get("yaw", 0.0))
		var parts := Art.parts(d["model"])
		for pn: String in d["keep"]:
			if not parts.has(pn):
				push_warning("no part %s in %s" % [pn, d["model"]])
				continue
			var pd: Dictionary = parts[pn]
			var mi := MeshInstance3D.new()
			mi.mesh = pd["mesh"]
			mi.material_override = Art.body_mat()
			mi.position = pd["origin"]
			n.add_child(mi)
			if pd["lines"] != null:
				var li := MeshInstance3D.new()
				li.mesh = pd["lines"]
				li.position = pd["origin"]
				n.add_child(li)
		if d.has("yaw"):
			# turn the part about its own origin (sunflower head = top of the neck)
			for c in n.get_children():
				var p := (c as Node3D).position
				(c as Node3D).transform = Transform3D(Basis(Vector3.UP, deg_to_rad(extra_yaw)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, p)
	n.rotation.y = deg_to_rad(YAW)
	return n


func _aabb(n: Node3D) -> AABB:
	var bb := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.mesh.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	return bb


func _process(_dt: float) -> bool:
	frame += 1
	if frame < 4:
		return false
	if _wait > 0:
		_wait -= 1
		return false
	if _i >= 0:
		_save()
	_i += 1
	if _i >= jobs.size():
		quit()
		return true
	_setup(jobs[_i])
	_wait = 3
	return false


var _org := Vector3.ZERO


func _setup(job: Array) -> void:
	for c in holder.get_children():
		c.free()
	var cs: Vector2i = job[2]
	vp.size = cs
	var n := _build(job[1])
	var bb := _aabb(n)
	_org = n.global_position
	var yaw := deg_to_rad(YAW)
	var pitch := deg_to_rad(PITCH)
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var up := back.cross(right).normalized() * -1.0
	if up.y < 0.0:
		up = -up
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	# tight fit: project every vertex (not the AABB corners — those leave thin flowers at half the cell)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var xf := mi.global_transform
		for si in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
			for v in verts:
				var p := xf * v
				var s := Vector2(p.dot(right), p.dot(up))
				mn = mn.min(s)
				mx = mx.max(s)
	if mn.x > mx.x:
		for i in 8:
			var p := bb.get_endpoint(i)
			var s := Vector2(p.dot(right), p.dot(up))
			mn = mn.min(s)
			mx = mx.max(s)
	var ext := mx - mn
	var size := maxf(ext.y / FILL, ext.x / FILL * float(cs.y) / float(cs.x))
	var c2 := (mn + mx) * 0.5
	var center := right * c2.x + up * c2.y
	cam.size = size
	cam.global_transform = Transform3D(Basis(), center + back * 400.0).looking_at(center, Vector3.UP)
	cam.near = 1.0
	cam.far = 1000.0


func _save() -> void:
	var job: Array = jobs[_i]
	var img := vp.get_texture().get_image()
	var pic: String = job[0]
	img.save_png(out_dir.path_join("cells/%s.png" % pic))
	var o := cam.unproject_position(_org)
	var meta := {"ppx": float(vp.size.y) / cam.size, "ox": o.x, "oy": o.y, "w": vp.size.x, "h": vp.size.y}
	var f := FileAccess.open(out_dir.path_join("cells/%s.json" % pic), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	f.close()
	print("ref ", pic, " ", meta)
