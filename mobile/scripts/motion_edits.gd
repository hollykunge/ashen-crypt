extends RefCounted
## Sparse offsets on the existing run cycle and combat combo, in normalized frames.
const FILE := "res://art/reference-hero/puppet/motion_edits.json"
const DEFAULTS = preload("res://art/reference-hero/puppet/motion_edits.json")
const FRAMES := {"run": 37, "combo": 20}

static func sample(track: Dictionary, frame: float, count: int, loop: bool) -> Vector2:
	var lo := 0.0
	var hi := float(count)
	var left := Vector2.ZERO
	var right := Vector2.ZERO
	if loop and track.has("0"):
		right = Vector2(track["0"][0],track["0"][1])
	for key in track:
		var at := float(key)
		var value: Array = track[key]
		if at <= frame and at >= lo:
			lo = at
			left = Vector2(value[0], value[1])
		if at >= frame and at <= hi:
			hi = at
			right = Vector2(value[0], value[1])
	if is_equal_approx(lo,hi):
		return left
	return left.lerp(right,smoothstep(lo,hi,frame))

static func save(data: Dictionary, path := FILE) -> Error:
	var dest := ProjectSettings.globalize_path(path)
	var temp := dest + "." + str(OS.get_process_id()) + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var ok := file.store_string(JSON.stringify(data,"\t") + "\n")
	file.close()
	if not ok:
		DirAccess.remove_absolute(temp)
		return ERR_FILE_CANT_WRITE
	var error := DirAccess.rename_absolute(temp,dest)
	if error != OK:
		DirAccess.remove_absolute(temp)
	return error
