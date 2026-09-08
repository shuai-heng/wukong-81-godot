extends SceneTree
func _initialize() -> void:
	var folder=ProjectSettings.globalize_path("res://../release/licenses")
	var f=FileAccess.open(folder.path_join("GODOT-ENGINE-EXACT.txt"),FileAccess.WRITE)
	f.store_string("Godot "+Engine.get_version_info().string+"\n\n"+Engine.get_license_text()+"\n\n")
	var licenses=Engine.get_license_info()
	for name in licenses:f.store_string("\n==== "+name+" ====\n"+licenses[name]+"\n")
	f.store_string("\nCOMPONENT COPYRIGHT NOTICES\n"+JSON.stringify(Engine.get_copyright_info(),"  "))
	f.close();quit()
