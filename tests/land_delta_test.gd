extends SceneTree

## The .landdelta format round trip (B5 step 6): MHLandDelta writes, reads
## back and agrees with itself; and when given a file written by
## tools/land_delta.py (first argument after --), reads the values Python
## wrote (that test writes them with: d[10:40, 100:180] a ramp -3..3 m along
## x, d[250:, 250:] = 3.25, size 300) and writes it back for Python to check.

func _init() -> void:
	var failures: Array[String] = []
	var d := MHLandDelta.new(300, 2.0)
	d.set_at(120, 20, 1.5)
	d.set_at(290, 290, -2.25)
	d.set_at(5, 5, 0.001)   # under EPSILON: no tile
	var back := MHLandDelta.from_bytes(d.to_bytes())
	if back == null: failures.append("own bytes didn't read back")
	else:
		if back.tiles.size() != 2: failures.append("expected 2 tiles, got %d" % back.tiles.size())
		if absf(back.at(120, 20) - 1.5) > .01: failures.append("value at 120,20: %f" % back.at(120, 20))
		if absf(back.at(290, 290) + 2.25) > .01: failures.append("value at 290,290: %f" % back.at(290, 290))
		if absf(back.at(0, 0)) > 0.0: failures.append("untouched point isn't 0")
	var args := OS.get_cmdline_user_args()
	if args.size() >= 1:
		var py := MHLandDelta.read(args[0])
		if py == null: failures.append("couldn't read Python's file " + args[0])
		else:
			if py.size != 300: failures.append("Python's size %d" % py.size)
			if absf(py.at(299, 299) - 3.25) > .01: failures.append("Python's corner %f" % py.at(299, 299))
			if absf(py.at(150, 20) - 0.797) > .02: failures.append("Python's ramp %f" % py.at(150, 20))
			if args.size() >= 2 and not py.write(args[1]): failures.append("couldn't write " + args[1])
	if failures.is_empty():
		print("land_delta_test: PASS")
		quit(0)
	else:
		for f in failures: print("land_delta_test: FAIL ", f)
		quit(1)
