extends SceneTree
## Headless unit-test runner (no addons needed).
##   godot --headless --path godot --script res://tests/run.gd [-- --filter=substring]
## Discovers tests/unit/test_*.gd, runs every `test_*` method, prints a summary, exit 1 on failure.

func _init() -> void:
	var filter := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			filter = a.trim_prefix("--filter=")
	var dir := DirAccess.open("res://tests/unit")
	if dir == null:
		printerr("tests/unit not found")
		quit(2)
		return
	var files: Array[String] = []
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	files.sort()
	var total := 0
	var failed := 0
	var asserts := 0
	for file in files:
		var script := load("res://tests/unit/" + file) as GDScript
		if script == null:
			printerr("cannot load " + file)
			failed += 1
			continue
		for m in script.get_script_method_list():
			var mname: String = m["name"]
			if not mname.begins_with("test_"):
				continue
			if filter != "" and not (filter in mname or filter in file):
				continue
			var inst = script.new()
			total += 1
			inst.call(mname)
			asserts += inst._asserts
			if inst._fails.size() > 0:
				failed += 1
				for msg in inst._fails:
					print("  FAIL %s::%s — %s" % [file, mname, msg])
			else:
				print("  ok   %s::%s" % [file, mname])
	print("TESTS %d run, %d failed, %d asserts" % [total, failed, asserts])
	quit(1 if failed > 0 else 0)
