extends SceneTree

const CONTRACT := "res://data/tang_runtime_pose_r6.json"

func _init() -> void:
	var errors: Array[String] = []
	if not FileAccess.file_exists(CONTRACT):
		errors.append("missing R6 pose contract")
		_finish(errors)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	if not (data is Dictionary):
		errors.append("invalid R6 pose contract json")
		_finish(errors)
		return

	if bool(data.get("balance_changes", true)):
		errors.append("R6 visual pass must not change balance")
	var principles: Dictionary = data.get("principles", {})
	if int(principles.get("form_subject_pose", -1)) != 13:
		errors.append("form body must use clean POSE13")
	if int(principles.get("form_echo_pose", -1)) != 13:
		errors.append("form echo must use clean POSE13")
	if bool(principles.get("form_baked_skill_art_allowed", true)):
		errors.append("baked form skill art must be disabled")
	if bool(principles.get("finisher_baked_skill_art_allowed", true)):
		errors.append("baked finisher skill art must be disabled")

	var timelines: Dictionary = data.get("timelines", {})
	var rposes: Array = timelines.get("r", {}).get("poses", [])
	for bad in range(19, 37):
		if bad in rposes:
			errors.append("baked/special pose leaked into R: %d" % bad)
	var deny: Array = data.get("form_and_finisher_denylist", [])
	for id in range(30, 37):
		if not id in deny:
			errors.append("R6 denylist must include POSE_%02d" % id)

	var game_v6 := FileAccess.get_file_as_string("res://scripts/game_v6.gd")
	var r8 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r8.gd")
	var r7 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r7.gd")
	var r6 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r6.gd")
	if game_v6.find("TangFighterV6R8") < 0:
		errors.append("complete-game entry is not wired to TangFighterV6R8")
	if r8.find("extends TangFighterV6R7") < 0:
		errors.append("R8 must preserve R7 clean-release layer")
	if r7.find("extends TangFighterV6R6") < 0:
		errors.append("R7 must preserve R6 clean-form layer")
	if r6.find("extends TangFighterV6R5") < 0:
		errors.append("R6 must preserve R5 Contact-only layer")
	for forbidden in ["POSE_30__", "POSE_31__", "POSE_32__", "POSE_33__", "POSE_34__", "POSE_35__", "POSE_36__"]:
		if r6.find(forbidden) >= 0:
			errors.append("R6 directly references baked special pose: " + forbidden)
	for token in ["return 13", "return 2", "return 3", "_r4_pose_tex(13)", "R6_FORM_ECHO_MAX_SCALE"]:
		if r6.find(token) < 0:
			errors.append("R6 missing clean form token: " + token)

	_finish(errors)

func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("TANG_R6_FORM_CONTRACT_PASS")
		quit(0)
		return
	for e in errors:
		push_error("TANG_R6: " + e)
	print("TANG_R6_FORM_CONTRACT_FAIL count=", errors.size())
	quit(1)
