extends SceneTree

const CONTRACT := "res://data/tang_runtime_pose_r9.json"
const CLEAN_CAST := "res://art/v7_clean/tang_sanzang/tang_sanzang__POSE_24__CAST_CLEAN.png"

func _init() -> void:
	var errors: Array[String] = []
	if not FileAccess.file_exists(CONTRACT):
		errors.append("missing R9 readability contract")
		_finish(errors)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	if not (data is Dictionary):
		errors.append("invalid R9 contract json")
		_finish(errors)
		return
	if bool(data.get("balance_changes", true)):
		errors.append("R9 visual pass must not change balance")

	var game_v6 := FileAccess.get_file_as_string("res://scripts/game_v6.gd")
	var r9 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r9.gd")
	var r8 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r8.gd")
	if game_v6.find("TangFighterV6R9.new()") < 0:
		errors.append("complete game is not wired to TangFighterV6R9")
	if r9.find("extends TangFighterV6R8") < 0:
		errors.append("R9 must preserve R8 release ordering")
	for token in ["R9_CHARACTER_SCALE", "R9_NORMAL_RELEASE_PRE", "R9_NORMAL_RELEASE_POST", "func _r4_pose_for", "func _apply_r4_visual", "func _sync_form_echo", "kf_sprite.flip_h"]:
		if r9.find(token) < 0:
			errors.append("R9 missing readability token: " + token)
	for token in ["_r8_last_release_kf_t = release_at", "_apply_r4_visual(0.0)", "cb.call()"]:
		if r8.find(token) < 0:
			errors.append("R8 release ordering token missing under R9: " + token)
	for forbidden in ["queue_attack(", "fx.emit(\"lotus\"", "fx.emit(\"ring\"", "fx.emit(\"rune\"", "player.position + Vector2", "position + Vector2(30"]:
		if r9.find(forbidden) >= 0:
			errors.append("R9 reintroduced forbidden runtime template: " + forbidden)

	var readability: Dictionary = data.get("readability", {})
	var visual_scale := float(readability.get("character_visual_scale_multiplier", 0.0))
	if visual_scale < 1.05 or visual_scale > 1.20:
		errors.append("R9 character visual scale must be a bounded readability adjustment")
	if bool(readability.get("collision_scale_changed", true)):
		errors.append("R9 must not change collision scale")
	if float(readability.get("normal_release_post_action_seconds", 0.0)) < .15:
		errors.append("normal release pose is still too brief to read at atk_combo 2x")

	var form: Dictionary = data.get("form", {})
	if int(form.get("subject_pose", -1)) != 13 or int(form.get("echo_pose", -1)) != 13:
		errors.append("R9 form must remain clean POSE13 + POSE13 echo")
	if bool(form.get("baked_pose_30_36_allowed", true)):
		errors.append("R9 must keep baked POSE30-36 out of final form")
	if String(form.get("echo_flip_source", "")) != "current_visible_kf_sprite.flip_h":
		errors.append("form echo direction must follow the visible character")

	# Pause-frame asset gate: the cleaned Release pose must not still contain the old huge crescent on the right.
	var tex: Texture2D = load(CLEAN_CAST)
	if tex == null:
		errors.append("clean Release texture cannot load")
	else:
		var img := tex.get_image()
		if img == null or img.is_empty() or img.get_width() != 256 or img.get_height() != 256:
			errors.append("clean Release texture dimensions invalid")
		else:
			var opaque := 0
			var right_opaque := 0
			var max_x := -1
			for y in img.get_height():
				for x in img.get_width():
					if img.get_pixel(x, y).a > .08:
						opaque += 1
						max_x = maxi(max_x, x)
						if x >= 210:
							right_opaque += 1
			if opaque < 1500:
				errors.append("clean Release texture lost too much of the character")
			if max_x > 210 or right_opaque > 24:
				errors.append("old baked crescent/VFX still leaks on the right side of clean POSE24")

	_finish(errors)

func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("TANG_R9_VISUAL_READABILITY_CONTRACT_PASS")
		quit(0)
		return
	for e in errors:
		push_error("TANG_R9: " + e)
	print("TANG_R9_VISUAL_READABILITY_CONTRACT_FAIL count=", errors.size())
	quit(1)
