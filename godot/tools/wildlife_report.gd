## 물고기 무리 수 보고 (헤드리스 — E3-12·A28: 큰 짐승 없음, 물고기만): godot --headless --path godot -s res://tools/wildlife_report.gd [-- small|world] [일 수]
## 무리마다 상한·수를 날마다 찍는다 (B3 — 균형 맞추기용)
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if args.size() > 0 else "small"
	var days := int(args[1]) if args.size() > 1 else 40
	Village.default_created = {"year": 2026, "month": 4, "day": 15}
	var v: Village
	if mode == "world":
		var jw := JarWorld.create_with_kit(20261106, WorldCfg.SIZE)
		jw.water.offline = true
		v = jw.primary()
	else:
		v = Village.new_prototype(33)
		v.water.offline = true
	var w := v.wild
	w.settle(v)
	for h: Dictionary in w.herds:
		print("%d %s (%.0f, %.0f) n=%d cap=%d hab=%.0f %s" % [h["id"], h["kind"], h["x"], h["y"], h["n"], h["cap"], h["hab"], h["name"]])
	for d in days:
		w._day(v)
		var parts := PackedStringArray()
		for h: Dictionary in w.herds:
			parts.append("%s%d/%d" % [String(h["kind"]).substr(0, 2), h["n"], h["cap"]])
		print("day %2d  %s" % [d + 1, " ".join(parts)])
	quit(0)
