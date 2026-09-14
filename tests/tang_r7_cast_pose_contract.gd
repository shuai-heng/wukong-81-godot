extends SceneTree

const CONTRACT := "res://data/tang_runtime_pose_r7.json"
const CLEAN_CAST := "res://art/v7_clean/tang_sanzang/tang_sanzang__POSE_24__CAST_CLEAN.png"

func _init() -> void:
	var errors: Array[String] = []
	if not FileAccess.file_exists(CONTRACT):
		errors.append("missing R7 pose contract")
	if not ResourceLoader.exists(CLEAN_CAST):
		errors.append("missing R7 clean cast PNG")
	if not errors.is_empty():
		_finish(errors)
		return

	var data = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	if not (data is Dictionary):
		errors.append("invalid R7 pose contract json")
		_finish(errors)
		return
	if bool(data.get("balance_changes", true)):
		errors.append("R7 visual pass must not change balance")

	var release: Dictionary = data.get("release_pose", {})
	if int(release.get("source_pose", -1)) != 24:
		errors.append("R7 release pose must derive from POSE24")
	if String(release.get("clean_asset", "")) != "art/v7_clean/tang_sanzang/tang_sanzang__POSE_24__CAST_CLEAN.png":
		errors.append("R7 clean asset path drifted")
	if String(release.get("cleanup_method", "")) != "alpha_cleanup_from_existing_pose":
		errors.append("R7 clean asset must be alpha-cleaned from existing pose")
	if bool(release.get("rgb_repainted", true)):
		errors.append("R7 must preserve original POSE24 RGB")
	var palm: Array = release.get("palm_uv", [])
	if palm.size() != 2:
		errors.append("R7 palm_uv missing")

	var timelines: Dictionary = data.get("timelines", {})
	for action in ["normal", "q", "g", "r"]:
		var poses: Array = timelines.get(action, {}).get("poses", [])
		if not 24 in poses:
			errors.append("clean release POSE24 missing from " + action)
	var gates: Dictionary = data.get("hard_gates", {})
	for key in ["single_damage_projectile_per_normal", "release_anchor_follows_visible_pose", "world_space_after_release", "contact_before_impact", "precontact_hitstop_forbidden", "full_character_crossfade_forbidden", "baked_large_skill_art_for_form_forbidden", "old_lotus_ring_rune_runtime_forbidden"]:
		if not bool(gates.get(key, false)):
			errors.append("R7 hard gate disabled: " + key)

	var game_v6 := FileAccess.get_file_as_string("res://scripts/game_v6.gd")
	var r8 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r8.gd")
	var r7 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r7.gd")
	if game_v6.find("TangFighterV6R8") < 0:
		errors.append("complete-game entry is not wired to TangFighterV6R8")
	if r8.find("extends TangFighterV6R7") < 0:
		errors.append("R8 must preserve R7 clean cast-pose layer")
	for token in ["extends TangFighterV6R6", "R7_CAST_PATH", "return 24", "R7_PALM_UV", "func _r4_palm_local"]:
		if r7.find(token) < 0:
			errors.append("R7 missing cast-pose token: " + token)
	if r7.find("tang_pose24_r7_mask_png.b64") >= 0 or r7.find("Marshalls.base64_to_raw") >= 0:
		errors.append("R7 still depends on temporary runtime base64 mask")
	if r7.find("queue_attack(") >= 0 or r7.find("fx.emit(\"lotus\"") >= 0 or r7.find("fx.emit(\"ring\"") >= 0 or r7.find("fx.emit(\"rune\"") >= 0:
		errors.append("R7 reintroduced legacy Tang skill template")
	if r7.find("player.position + Vector2") >= 0 or r7.find("position + Vector2(30") >= 0:
		errors.append("R7 introduced fake fixed anchor")

	var tex: Texture2D = load(CLEAN_CAST)
	if tex == null:
		errors.append("R7 clean cast PNG failed ResourceLoader load")
	else:
		var img := tex.get_image()
		if img == null or img.is_empty() or img.get_width() != 256 or img.get_height() != 256:
			errors.append("R7 clean cast PNG dimensions invalid")

	_finish(errors)

func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("TANG_R7_CAST_POSE_CONTRACT_PASS")
		quit(0)
		return
	for e in errors:
		push_error("TANG_R7: " + e)
	print("TANG_R7_CAST_POSE_CONTRACT_FAIL count=", errors.size())
	quit(1)
