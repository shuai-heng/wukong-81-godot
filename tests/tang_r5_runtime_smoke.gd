extends SceneTree

# 唐僧 R9 完整游戏运行时 smoke。
# 目的：真正实例化 scenes/main.tscn，验证 R9→R8→R7→R6→R5→R4→R3 链、
# 清理后的 POSE24 只在真实 Release 窗口出现、平A/Q/E/G/R 的 Contact 顺序、
# 以及 R9 的人物读形/法相朝向没有破坏战斗数值与控制。

var failed := false

func _initialize() -> void:
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout

func _fail(msg: String) -> void:
	failed = true
	push_error("TANG_R9_SMOKE " + msg)

func _durable_foe(game, at: Vector2):
	var e = game.spawn_enemy(at, "wolf", true)
	if e != null:
		e.hp = 9999.0
		e.max_hp = 9999.0
		e.speed = 0.0
		e.attack_cd = 999.0
	return e

func _wait_for_damage_without_precontact_hitstop(game, player, target, hp_before: float, timeout: float, label: String, expect_release_pose := true) -> bool:
	var elapsed := 0.0
	var contacted := false
	var release_seen := false
	while elapsed < timeout:
		await process_frame
		var dt := maxf(1.0 / 240.0, float(root.get_process_delta_time()))
		elapsed += dt
		if player != null and is_instance_valid(player) and int(player._r4_pose_id) == 24:
			release_seen = true
		if target == null or not is_instance_valid(target):
			return true
		if float(target.hp) < hp_before:
			contacted = true
			break
		# HP 尚未变化 = 还没真实 Contact；此时不允许人物动作 metadata 先顿帧。
		if float(game.hitstop) > .001:
			_fail(label + " leaked hitstop before Contact")
			return false
	if expect_release_pose and not release_seen:
		_fail(label + " never showed clean POSE24 during real release window")
	if not contacted:
		_fail(label + " did not reach damage Contact in timeout")
		return false
	return true

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("main scene missing")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	current_scene = game
	for i in 5:
		await process_frame
	if not (game.player is TangFighterV6R9):
		_fail("TangFighterV6R9 not installed")
		quit(2)
		return

	game.new_journey()
	await _wait(.20)
	var p = game.player
	p.set_hero("tang")
	p.invulnerable = 99.0
	game.spawn_cd = 999.0
	game.env_cd = 999.0
	game.preview_cd = 999.0

	# 正式清理 Release Texture 必须可加载；失败时绝不能偷用原始带月牙 POSE24。
	var cast_tex = p._r7_cast_texture()
	if cast_tex == null:
		_fail("clean POSE24 release texture failed to load")
	# R9 只改可视 scale，不允许碰撞/玩家 Node2D scale 跟着放大。
	if p.scale != Vector2.ONE:
		_fail("R9 changed player Node2D/collision scale")

	var target = _durable_foe(game, p.position + Vector2(120, 0))
	if target == null:
		_fail("could not spawn target")
		quit(3)
		return

	# 平A：必须经历可读的干净 POSE24 Release 窗口，然后 world-space projectile 才能扣血。
	var hp0 := float(target.hp)
	p.cool.auto = 999.0
	p._auto(target)
	await _wait_for_damage_without_precontact_hitstop(game, p, target, hp0, 1.35, "normal", true)
	if float(game.hitstop) > .001:
		_fail("normal Contact should not add hitstop")

	# Q：同样必须在真实 release 附近看到前推掌，Contact 后才伤害。
	hp0 = float(target.hp)
	p.cool.q = 0.0
	p._tang_q(target)
	await _wait_for_damage_without_precontact_hitstop(game, p, target, hp0, 1.80, "Q", true)
	await _wait(.08)

	# E 不使用 POSE24；仍验证旧数值口径 shield + TangWardV6。
	p.cool.e = 0.0
	p._tang_e()
	await _wait(1.15)
	if p.shield <= 0.0:
		_fail("E kasaya shield was not applied")
	var ward_found := false
	for n in game.get_children():
		if n is TangWardV6:
			ward_found = true
			break
	if not ward_found:
		_fail("E TangWardV6 node missing")

	# G：多弹 cadence 期间允许持 POSE24，但结束必须 Recovery，不能永久僵住。
	hp0 = float(target.hp)
	p.cool.g = 0.0
	p._tang_g()
	await _wait_for_damage_without_precontact_hitstop(game, p, target, hp0, 2.20, "G", true)
	await _wait(.35)
	if int(p._r4_pose_id) == 24 and p._r5_release_hold_left <= .001:
		_fail("G stayed frozen on POSE24 after cadence ended")

	# 法相：先向左，验证投影严格跟当前真正可见 KFSprite 朝向。
	p.facing = Vector2.LEFT
	p.form_left = 4.0
	p.form_age = 1.0
	p.ultimate = 100.0
	await _wait(.22)
	if p._form_echo == null or not p._form_echo.visible:
		_fail("R9 dharma form echo did not become visible")
	elif p.kf_sprite != null and p._form_echo.flip_h != p.kf_sprite.flip_h:
		_fail("R9 dharma form echo flip does not match visible Tang pose")

	# R：前推 Release + Contact-only feedback + 最终收法相。
	p.cool.r = 0.0
	hp0 = float(target.hp)
	var r_ok := p._ultimate()
	if not r_ok:
		_fail("R ultimate refused valid form state")
	else:
		await _wait_for_damage_without_precontact_hitstop(game, p, target, hp0, 2.40, "R", true)
	await _wait(.65)
	if p.form_left > 0.0:
		_fail("R did not close dharma form after release")
	if int(p._r4_pose_id) == 24 and p._r5_release_hold_left <= .001:
		_fail("R stayed frozen on POSE24 after finisher cadence ended")

	print("TANG_R9_RUNTIME_SMOKE_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
