extends SceneTree

func _init() -> void:
	var errors: Array[String] = []
	var game_v6 := FileAccess.get_file_as_string("res://scripts/game_v6.gd")
	var r6 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r6.gd")
	var r5 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r5.gd")
	var projectile := FileAccess.get_file_as_string("res://scripts/tang_spell_projectile_v6.gd")
	var r4 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r4.gd")

	if game_v6.find("TangFighterV6R6") < 0:
		errors.append("complete-game entry is not wired to TangFighterV6R6")
	if r6.find("extends TangFighterV6R5") < 0:
		errors.append("R6 must preserve R5 Contact-only layer")
	if r5.find("extends TangFighterV6R4") < 0:
		errors.append("R5 must extend R4 pose layer")
	for token in ["hitstop_before", "shake_before", "_r5_release_hold_left", "func _hold_release_pose", "game.hitstop = hitstop_before", "game.shake = shake_before"]:
		if r5.find(token) < 0:
			errors.append("R5 missing legacy-meta suppression token: " + token)

	# 真正命中反馈必须位于 projectile Contact/Impact 层，而不是人物动作帧。
	for token in ["func _impact", "_apply_feedback(hit_any, hit_count)", "if not hit_any", "game.hitstop", "game.shake"]:
		if projectile.find(token) < 0:
			errors.append("projectile contact feedback missing token: " + token)
	if projectile.find("_impact(e)") < 0 or projectile.find("_impact(null)") < 0:
		errors.append("projectile must reach impact from enemy/ground contact")

	# R4 仍承担普通人物 Pose / palm 锚点；R5/R6 不得退回 player.position + 固定偏移。
	for token in ["func _r4_palm_world", "func _spawn_spell", "PALM_UV", "POSE_06", "POSE_35"]:
		if r4.find(token) < 0:
			errors.append("R4 pose/anchor guard missing token: " + token)
	for layer in [r5, r6]:
		if layer.find("player.position + Vector2") >= 0 or layer.find("position + Vector2(30") >= 0:
			errors.append("R5/R6 introduced a fixed fake anchor")

	_finish(errors)

func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("TANG_R5_CONTACT_FEEDBACK_CONTRACT_PASS")
		quit(0)
		return
	for e in errors:
		push_error("TANG_R5: " + e)
	print("TANG_R5_CONTACT_FEEDBACK_CONTRACT_FAIL count=", errors.size())
	quit(1)
