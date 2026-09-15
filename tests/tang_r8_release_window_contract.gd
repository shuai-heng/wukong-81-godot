extends SceneTree

const CONTRACT := "res://data/tang_runtime_pose_r8.json"

func _init() -> void:
	var errors: Array[String] = []
	if not FileAccess.file_exists(CONTRACT):
		errors.append("missing R8 release contract")
		_finish(errors)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	if not (data is Dictionary):
		errors.append("invalid R8 release contract json")
		_finish(errors)
		return
	if bool(data.get("balance_changes", true)):
		errors.append("R8 must not change balance")
	var gates: Dictionary = data.get("hard_gates", {})
	if String(gates.get("same_clock", "")) != "KeyframeLib.kf_t/kf_release_t":
		errors.append("R8 must use shared KeyframeLib clock")
	for key in ["full_character_crossfade_forbidden", "baked_crescent_forbidden", "world_space_after_release", "contact_before_impact", "precontact_hitstop_forbidden", "balance_change_forbidden"]:
		if not bool(gates.get(key, false)):
			errors.append("R8 hard gate disabled: " + key)

	var game_v6 := FileAccess.get_file_as_string("res://scripts/game_v6.gd")
	var r9 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r9.gd")
	var r8 := FileAccess.get_file_as_string("res://scripts/tang_fighter_v6_r8.gd")
	if game_v6.find("TangFighterV6R9") < 0:
		errors.append("complete game is not wired through TangFighterV6R9")
	if r9.find("extends TangFighterV6R8") < 0:
		errors.append("R9 must extend R8 instead of bypassing the release-order layer")
	for token in ["extends TangFighterV6R7", "func _kf_release_tick", "func _r8_release_delta", "kf_release_t", "_r5_release_hold_left", "return 24", "func _apply_r4_visual"]:
		if r8.find(token) < 0:
			errors.append("R8 missing release-window token: " + token)

	# 真正 Release 的顺序必须是：先锁定 release → 切可见 POSE24 → 再执行 callback 发弹。
	var latch_i := r8.find("_r8_last_release_kf_t = release_at")
	var sync_i := r8.find("_apply_r4_visual(0.0)")
	var callback_i := r8.find("cb.call()")
	if latch_i < 0 or sync_i < 0 or callback_i < 0 or not (latch_i < sync_i and sync_i < callback_i):
		errors.append("release ordering must be latch -> visible POSE sync -> projectile callback")

	# R9 可以扩大读形窗口，但不能改写 R8 的真实 release 顺序或引入第二套 timer。
	for token in ["func _r4_pose_for", "_r8_release_delta", "R9_NORMAL_RELEASE_POST"]:
		if r9.find(token) < 0:
			errors.append("R9 readability layer missing shared-release token: " + token)
	for forbidden in ["create_timer(", "await ", "player.position + Vector2", "position + Vector2(30", "queue_attack(", "fx.emit(\"lotus\"", "fx.emit(\"ring\"", "fx.emit(\"rune\""]:
		if r8.find(forbidden) >= 0 or r9.find(forbidden) >= 0:
			errors.append("R8/R9 forbidden token: " + forbidden)

	_finish(errors)

func _finish(errors: Array[String]) -> void:
	if errors.is_empty():
		print("TANG_R8_RELEASE_WINDOW_CONTRACT_PASS")
		quit(0)
		return
	for e in errors:
		push_error("TANG_R8: " + e)
	print("TANG_R8_RELEASE_WINDOW_CONTRACT_FAIL count=", errors.size())
	quit(1)
