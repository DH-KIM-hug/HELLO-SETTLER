## 개발: 넓은 세상 저장 파일 크기·시간 재기 (ROADMAP A16). 1024칸 세상 + 키트 하나를 n일 흘린 뒤 병 파일 한 칸을 쓰고 다시 읽는다.
## 실행: godot --headless --path godot -s tools/measure_save.gd -- [일 수 (기본 30)] [시드 (기본 4)]
## 흘린 세상은 user://measure_world_<시드>_<일>.bin 에 (옛 형식 그대로) 남겨 두고 다음엔 다시 흘리지 않는다.
extends SceneTree


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var days := float(args[0]) if args.size() > 0 else 30.0
	var seed_v := int(args[1]) if args.size() > 1 else 4
	var cache := "user://measure_world_snap_%d_%d.bin" % [seed_v, int(days)]
	var jw: JarWorld
	if FileAccess.file_exists(cache):
		var f := FileAccess.open_compressed(cache, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
		jw = JarWorld.from_dict(bytes_to_var(f.get_buffer(f.get_length())))
		f.close()
		print("흘려 둔 세상을 읽음 (%s)" % cache)
	else:
		var t0 := Time.get_ticks_msec()
		jw = JarWorld.create(seed_v, WorldCfg.SIZE)
		var sp := jw.recommended_kit_spots()
		jw.place_kit(sp[0].x, sp[0].y)
		jw.water.offline = true
		for d in int(days):
			jw.advance(Balance.DAY)
		jw.water.offline = false
		print("1024칸 세상 %d일 흘림: %.1f초" % [int(days), (Time.get_ticks_msec() - t0) / 1000.0])
		var f := FileAccess.open_compressed(cache, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		f.store_buffer(var_to_bytes(jw.to_dict(false)))
		f.close()
	var v := jw.primary()
	print("주민 %d명 · 건물 %d · 병 %.1f일" % [v.people.size(), v.buildings.size(), v.t / Balance.DAY])
	# 저장 (찍기 + 누르기 + 바이트 + ZSTD 쓰기) — 옛 v1 (누르지 않음)과 지금 (WorldPack)
	var d := jw.to_dict(false)
	for packed: bool in [false, true]:
		var path := "user://measure_jar_%s.dat.a" % ("v2" if packed else "v1")
		var t1 := Time.get_ticks_usec()
		var dd := jw.to_dict(false)
		var t2 := Time.get_ticks_usec()
		var body: Variant = WorldPack.pack_payload({"world": dd}) if packed else {"world": dd}
		var bytes := SaveFile.pack(body, 1, 0.0)
		SaveFile.write_raw(path, bytes)
		var t3 := Time.get_ticks_usec()
		var fl := FileAccess.open(path, FileAccess.READ)
		var size := fl.get_length()
		fl.close()
		var t4 := Time.get_ticks_usec()
		var r := SaveFile.read_slot(path)
		var jw2 := JarWorld.from_dict((r["payload"] as Dictionary)["world"])
		var t5 := Time.get_ticks_usec()
		var same := SaveCodec.digest(jw.to_dict(false)) == SaveCodec.digest(jw2.to_dict(false))
		print("%s: 병 파일 %.2f MB (누르기 전 %.2f MB) · 찍기 %.0f ms · 누르기+쓰기 %.0f ms · 읽기+되살리기 %.0f ms · 왕복 지문 같음 %s" % [
			"v2 WorldPack" if packed else "v1 그대로", size / 1048576.0, bytes.size() / 1048576.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, (t5 - t4) / 1000.0, same])
	# 물 사전 안의 큰 값들
	var wd: Dictionary = d["water"]
	var rows: Array = []
	for k: Variant in wd:
		var b := var_to_bytes(wd[k]).size()
		if b > 20000:
			rows.append([b, k])
	rows.sort_custom(func(a: Array, c: Array) -> bool: return a[0] > c[0])
	for row: Array in rows:
		print("  water.%s  %.0f KB (누르기 전)" % [row[1], row[0] / 1024.0])
	quit(0)
