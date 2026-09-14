extends SceneTree
## M2-R5 static/runtime-load contract gate for the Tang/Wukong visual slice.
## Run: godot --headless --path . --script res://tests/m2_r5_visual_choreography_contract.gd

var failures: Array[String] = []

func _need(ok: bool, msg: String) -> void:
	if not ok:
		failures.append(msg)

func _has(src: String, token: String, msg: String) -> void:
	_need(src.contains(token), msg)

func _init() -> void:
	_need(FileAccess.file_exists("res://scripts/visual_choreography.gd"), "missing visual_choreography.gd")
	_need(FileAccess.file_exists("res://scripts/visual_choreography_rig.gd"), "missing visual_choreography_rig.gd")
	_need(FileAccess.file_exists("res://scripts/visual_choreography_impact.gd"), "missing visual_choreography_impact.gd")
	_need(FileAccess.file_exists("res://data/m2_r5_action_scripts.json"), "missing action scripts")
	_need(load("res://scripts/visual_choreography.gd") != null, "bootstrap script failed to load")
	_need(load("res://scripts/visual_choreography_rig.gd") != null, "rig script failed to load")
	_need(load("res://scripts/visual_choreography_impact.gd") != null, "impact script failed to load")
	_need(String(ProjectSettings.get_setting("autoload/VisualChoreography", "")).contains("visual_choreography.gd"), "autoload not enabled")

	var rig := FileAccess.get_file_as_string("res://scripts/visual_choreography_rig.gd")
	_has(rig, "KeyframeLib.body_anchor_world(player, \"palm\")", "Tang cast/projectile must use real palm anchor")
	_has(rig, "KeyframeLib.release_time(slug, action)", "cast seal must use existing action release clock")
	_has(rig, "player.get(\"kf_t\")", "visual choreography must read existing kf_t")
	_has(rig, "shot[\"from\"] = palm_world", "Tang ring projectile origin must be rebound to palm")
	_has(rig, "shot[\"pos\"] = palm_world", "Tang ring projectile first world position must be palm")
	_has(rig, "KeyframeLib.body_anchor_world(player, \"body_center\")", "movement/form visual must use body anchor")
	_has(rig, "form_echo.texture = kfs.texture", "form must reuse actual V6.1 pose texture")
	_has(rig, "if not live.has(sid):", "impact must wait until tracked projectile leaves world lifecycle")
	_has(rig, "_spawn_tang_impact(_shot_last_world[sid])", "Tang contact must lead to world-space impact")
	_need(not rig.contains("player.position + Vector2("), "fixed-offset fake anchor detected")
	_need(not rig.contains("global_position + Vector2(30"), "fixed-offset fake anchor detected")

	var impact_src := FileAccess.get_file_as_string("res://scripts/visual_choreography_impact.gd")
	_need(not impact_src.contains("damage"), "visual impact must not own damage")
	_need(not impact_src.contains("camera"), "Tang normal impact must not own camera shake")

	var action_raw := FileAccess.get_file_as_string("res://data/m2_r5_action_scripts.json")
	var actions_v = JSON.parse_string(action_raw)
	_need(actions_v is Dictionary, "m2_r5_action_scripts.json parse failed")
	if actions_v is Dictionary:
		var actions := actions_v as Dictionary
		_need(String(actions.get("balance_policy", "")) == "visual_only_no_damage_cd_invulnerability_change", "visual-only balance policy drift")
		var chars_v = actions.get("characters", {})
		_need(chars_v is Dictionary, "characters must be a Dictionary")
		if chars_v is Dictionary:
			var chars := chars_v as Dictionary
			var tang_v = chars.get("tang", {})
			var wk_v = chars.get("wukong", {})
			_need(tang_v is Dictionary, "Tang action script missing")
			_need(wk_v is Dictionary, "Wukong action script missing")
			if tang_v is Dictionary:
				var tang := tang_v as Dictionary
				var tang_na_v = tang.get("normal_attack", {})
				_need(tang_na_v is Dictionary, "Tang normal_attack missing")
				if tang_na_v is Dictionary:
					var tang_na := tang_na_v as Dictionary
					_need(String(tang_na.get("source_anchor", "")) == "palm", "Tang normal attack source_anchor must be palm")
					_need(String(tang_na.get("motion_type", "")) == "projectile", "Tang normal attack must stay ranged projectile")
					_need(String(tang_na.get("trajectory_type", "")).contains("world_space"), "Tang projectile must become world-space after release")
			if wk_v is Dictionary:
				var wk := wk_v as Dictionary
				var wk_na_v = wk.get("normal_attack", {})
				var wk_heavy_v = wk.get("heavy", {})
				_need(wk_na_v is Dictionary, "Wukong normal_attack missing")
				_need(wk_heavy_v is Dictionary, "Wukong heavy missing")
				if wk_na_v is Dictionary:
					var wk_na := wk_na_v as Dictionary
					_need(String(wk_na.get("source_anchor", "")) == "staff_tip", "Wukong normal attack source_anchor must be staff_tip")
				if wk_heavy_v is Dictionary:
					var wk_heavy := wk_heavy_v as Dictionary
					_need(String(wk_heavy.get("environment_response", "")).contains("地裂"), "Wukong heavy must retain map feedback")

	var anchors_raw := FileAccess.get_file_as_string("res://data/v6_body_anchors.json")
	var anchors_v = JSON.parse_string(anchors_raw)
	_need(anchors_v is Dictionary, "v6_body_anchors.json parse failed")
	if anchors_v is Dictionary:
		var anchors := anchors_v as Dictionary
		var tang_anchor_v = anchors.get("tang_sanzang", {})
		_need(tang_anchor_v is Dictionary, "Tang anchor block missing")
		if tang_anchor_v is Dictionary:
			var tang_anchor := tang_anchor_v as Dictionary
			var atk_v = tang_anchor.get("atk_combo", {})
			_need(atk_v is Dictionary, "Tang atk_combo body-anchor track missing")
			if atk_v is Dictionary:
				var atk := atk_v as Dictionary
				var palm_count := 0
				for k in atk.keys():
					var entry_v = atk[k]
					if entry_v is Dictionary and (entry_v as Dictionary).has("palm"):
						palm_count += 1
				_need(palm_count >= 4, "Tang atk_combo palm track is too sparse")

	if failures.is_empty():
		print("[M2-R5] VISUAL_CHOREOGRAPHY_CONTRACT PASS")
		quit(0)
	else:
		for f in failures:
			push_error("[M2-R5] " + f)
		print("[M2-R5] VISUAL_CHOREOGRAPHY_CONTRACT FAIL count=" + str(failures.size()))
		quit(1)
