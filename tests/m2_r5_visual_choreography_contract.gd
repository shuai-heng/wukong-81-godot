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
	_need(FileAccess.file_exists("res://data/m2_r5_action_scripts.json"), "missing action scripts")
	_need(load("res://scripts/visual_choreography.gd") != null, "bootstrap script failed to load")
	_need(load("res://scripts/visual_choreography_rig.gd") != null, "rig script failed to load")
	_need(String(ProjectSettings.get_setting("autoload/VisualChoreography", "")).contains("visual_choreography.gd"), "autoload not enabled")

	var rig := FileAccess.get_file_as_string("res://scripts/visual_choreography_rig.gd")
	_has(rig, "KeyframeLib.body_anchor_world(player, \"palm\")", "Tang cast/projectile must use real palm anchor")
	_has(rig, "KeyframeLib.release_time(slug, action)", "cast seal must use existing action release clock")
	_has(rig, "player.get(\"kf_t\")", "visual choreography must read existing kf_t")
	_has(rig, "shot[\"from\"] = palm_world", "Tang ring projectile origin must be rebound to palm")
	_has(rig, "shot[\"pos\"] = palm_world", "Tang ring projectile first world position must be palm")
	_has(rig, "KeyframeLib.body_anchor_world(player, \"body_center\")", "movement visual must use body anchor")
	_has(rig, "form_echo.texture = kfs.texture", "form must reuse actual V6.1 pose texture")
	_need(not rig.contains("player.position + Vector2("), "fixed-offset fake anchor detected")
	_need(not rig.contains("global_position + Vector2(30"), "fixed-offset fake anchor detected")

	var action_raw := FileAccess.get_file_as_string("res://data/m2_r5_action_scripts.json")
	var actions = JSON.parse_string(action_raw)
	_need(actions is Dictionary, "m2_r5_action_scripts.json parse failed")
	if actions is Dictionary:
		_need(String(actions.get("balance_policy", "")) == "visual_only_no_damage_cd_invulnerability_change", "visual-only balance policy drift")
		var chars: Dictionary = actions.get("characters", {})
		var tang: Dictionary = chars.get("tang", {})
		var wk: Dictionary = chars.get("wukong", {})
		_need(String(tang.get("normal_attack", {}).get("source_anchor", "")) == "palm", "Tang normal attack source_anchor must be palm")
		_need(String(tang.get("normal_attack", {}).get("motion_type", "")) == "projectile", "Tang normal attack must stay ranged projectile")
		_need(String(wk.get("normal_attack", {}).get("source_anchor", "")) == "staff_tip", "Wukong normal attack source_anchor must be staff_tip")
		_need(String(wk.get("heavy", {}).get("environment_response", "")).contains("地裂"), "Wukong heavy must retain map feedback")

	var anchors_raw := FileAccess.get_file_as_string("res://data/v6_body_anchors.json")
	var anchors = JSON.parse_string(anchors_raw)
	_need(anchors is Dictionary, "v6_body_anchors.json parse failed")
	if anchors is Dictionary:
		var tang_anchor: Dictionary = anchors.get("tang_sanzang", {})
		var atk: Dictionary = tang_anchor.get("atk_combo", {})
		_need(not atk.is_empty(), "Tang atk_combo body-anchor track missing")
		var palm_count := 0
		for k in atk.keys():
			var entry = atk[k]
			if entry is Dictionary and entry.has("palm"):
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
