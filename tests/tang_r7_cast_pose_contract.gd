extends SceneTree

const CONTRACT := "res://data/tang_runtime_pose_r7.json"
const MASK := "res://data/tang_pose24_r7_mask_png.b64"

func _init() -> void:
	var errors: Array[String] = []
	if not FileAccess.file_exists(CONTRACT):
		errors.append("missing R7 pose contract")
	if not FileAccess.file_exists(MASK):
		errors.append("missing R7 cleanup mask")
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
	if String(release.get("cleanup_method", "")) != "runtime_alpha_mask_only":
		errors.append("R7 must clean POSE24 with alpha mask only")
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
	var r7 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r7.gd")
	if game_v6.find("TangFighterV6R7") < 0:
		errors.append("complete-game entry is not wired to TangFighterV6R7")
	for token in ["extends TangFighterV6R6", "R7_POSE24_FILE", "R7_MASK_PATH", "Marshalls.base64_to_raw", "load_png_from_buffer", "ImageTexture.create_from_image", "return 24", "R7_PALM_UV", "func _r4_palm_local"]:
		if r7.find(token) < 0:
			errors.append("R7 missing cast-pose token: " + token)
	if r7.find("queue_attack(") >= 0 or r7.find("fx.emit(\"lotus\"") >= 0 or r7.find("fx.emit(\"ring\"") >= 0 or r7.find("fx.emit(\"rune\"") >= 0:
		errors.append("R7 reintroduced legacy Tang skill template")
	if r7.find("player.position + Vector2") >= 0 or r7.find("position + Vector2(30") >= 0:
		errors.append("R7 introduced fake fixed anchor")

	# Base64 PNG 必须至少能解码为 PNG 签名，防止文本损坏。
	var raw := Marshalls.base64_to_raw(FileAccess.get_file_as_string(MASK).strip_edges())
	if raw.size() < 8 or raw[0] != 137 or raw[1] != 80 or raw[2] != 78 or raw[3] != 71:
		errors.append("R7 mask is not valid PNG bytes")

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
