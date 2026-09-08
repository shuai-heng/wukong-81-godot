class_name JourneySave
extends RefCounted

static var override_dir = ""
static func directory() -> String:
	if not override_dir.is_empty():return override_dir
	var env=OS.get_environment("W81_DATA_DIR")
	if not env.is_empty():return env
	if OS.has_feature("standalone"):
		return OS.get_executable_path().get_base_dir().path_join("userdata")
	return ProjectSettings.globalize_path("res://userdata")

static func fresh() -> Dictionary:
	return {"version":2,"chapter":0,"unlocked":["tang"],"abilities":{},"completed":[],"stories":[],"events":0,"best":{},"settings":{"sound":.8,"music":.55,"shake":.7,"difficulty":1.0,"fullscreen":false}}

static func valid(d: Variant) -> bool:
	return d is Dictionary and d.get("version",0)==2 and d.get("unlocked") is Array and d.get("abilities") is Dictionary and d.get("completed") is Array and d.get("stories") is Array and d.get("settings") is Dictionary

static func load_game() -> Dictionary:
	for suffix in ["journey.json","journey.backup.json"]:
		var path=directory().path_join(suffix)
		if not FileAccess.file_exists(path):continue
		var d=JSON.parse_string(FileAccess.get_file_as_string(path))
		if valid(d):
			d.chapter=clampi(int(d.get("chapter",0)),0,JourneyContent.ROUTE.size()-1)
			d.unlocked=d.unlocked.filter(func(h):return JourneyContent.HEROES.has(h))
			if not d.unlocked.has("tang"):d.unlocked.push_front("tang")
			return d
	return fresh()

static func write(data: Dictionary) -> bool:
	if not valid(data):return false
	var folder=directory()
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:return false
	var path=folder.path_join("journey.json")
	var tmp=folder.path_join("journey.tmp.json")
	var f=FileAccess.open(tmp,FileAccess.WRITE)
	if f==null:return false
	f.store_string(JSON.stringify(data,"  "))
	f.close()
	if FileAccess.file_exists(path):
		var old=JSON.parse_string(FileAccess.get_file_as_string(path))
		if valid(old):DirAccess.copy_absolute(path,folder.path_join("journey.backup.json"))
	return DirAccess.rename_absolute(tmp,path)==OK
