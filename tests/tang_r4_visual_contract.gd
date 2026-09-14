extends SceneTree

const CONTRACT := "res://data/tang_runtime_pose_r4.json"
const REQUIRED_POSES := [1, 2, 3, 4, 5, 13, 31, 36]
const FILES := {
	1: "tang_sanzang__POSE_01__R1C1.png",
	2: "tang_sanzang__POSE_02__R1C2.png",
	3: "tang_sanzang__POSE_03__R1C3.png",
	4: "tang_sanzang__POSE_04__R1C4.png",
	5: "tang_sanzang__POSE_05__R1C5.png",
	13: "tang_sanzang__POSE_13__R3C1.png",
	31: "tang_sanzang__POSE_31__R6C1.png",
	36: "tang_sanzang__POSE_36__R6C6.png",
}

func _init() -> void:
	var errors: Array[String] = []
	if not FileAccess.file_exists(CONTRACT):
		errors.append("missing pose contract")
	_finish(errors)
	return

	var data = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	if not (data is Dictionary):
		errors.append("pose contract json invalid")
		_finish(errors)
		return

	if String(data.get("character", "")) != "tang_sanzang":
		errors.append("wrong character")
	if bool(data.get("balance_changes", true)):
		errors.append("visual rebuild must not change balance")
	var principles: Dictionary = data.get("principles", {})
	if String(principles.get("normal_attack_role", "")) != "ranged_caster":
		errors.append("Tang normal attack must remain ranged")
	if String(principles.get("source_anchor", "")) != "current_visual_pose.palm":
		errors.append("projectile source must follow current visual palm")
	if not bool(principles.get("world_space_after_release", false)):
		errors.append("projectile must enter world space after release")
	if not bool(principles.get("contact_before_impact", false)):
		errors.append("contact must precede impact")

	for id in REQUIRED_POSES:
		var rel := "res://art/v6_pose/tang_sanzang/" + String(FILES[id])
		if not ResourceLoader.exists(rel):
			errors.append("missing pose %02d" % id)

	var timelines: Dictionary = data.get("timelines", {})
	var run_poses: Array = timelines.get("run", {}).get("poses", [])
	if 6 in run_poses:
		errors.append("POSE_06 horizontal flying pose leaked into run")
	var normal_poses: Array = timelines.get("normal", {}).get("poses", [])
	for bad in [14, 15, 16, 17, 18]:
		if bad in normal_poses:
			errors.append("melee staff pose leaked into ranged normal: %d" % bad)
	for action in ["normal", "q", "e", "g"]:
		var poses: Array = timelines.get(action, {}).get("poses", [])
		for bad in [19,20,21,22,23,24,25,26,27,28,29,35]:
			if bad in poses:
				errors.append("baked VFX pose %d leaked into %s" % [bad, action])
	var form_poses: Array = timelines.get("form", {}).get("poses", [])
	if 35 in form_poses or int(timelines.get("form", {}).get("echo_pose", -1)) == 35:
		errors.append("giant lotus POSE_35 leaked into form")

	var game_v6 := FileAccess.get_file_as_string("res://scripts/game_v6.gd")
	if game_v6.find("TangFighterV6R4") < 0:
		errors.append("complete-game entry is not wired to TangFighterV6R4")
	var r4 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r4.gd")
	for token in ["func _r4_palm_world", "func _spawn_spell", "func _sync_form_echo", "POSE_06", "POSE_35"]:
		if r4.find(token) < 0:
			errors.append("missing R4 guard/token: " + token)

	_finish(errors)

func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("TANG_R4_VISUAL_CONTRACT_PASS")
		quit(0)
		return
	for e in errors:
		push_error("TANG_R4: " + e)
	print("TANG_R4_VISUAL_CONTRACT_FAIL count=", errors.size())
	quit(1)
