extends SceneTree

# 唐僧 R5 完整游戏运行时 smoke。
# 目的：用 Godot 真正实例化 scenes/main.tscn，验证继承链、平A/Q/E/G/R 的释放链能跑通，
# 并在逐帧层面验证 Contact 前不能出现旧 V6.1 预埋 hitstop。
# 不替代视觉录像；也不修改正式平衡数值。

var failed := false

func _initialize() -> void:
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout

func _fail(msg: String) -> void:
	failed = true
	push_error("TANG_R5_SMOKE " + msg)

func _durable_foe(game, at: Vector2):
	var e = game.spawn_enemy(at, "wolf", true)
	if e != null:
		e.hp = 9999.0
		e.max_hp = 9999.0
		e.speed = 0.0
		e.attack_cd = 999.0
	return e

func _wait_for_damage_without_precontact_hitstop(game, target, hp_before: float, timeout: float, label: String) -> bool:
	var elapsed := 0.0
	var contacted := false
	while elapsed < timeout:
		await process_frame
		var dt := maxf(1.0 / 240.0, float(root.get_process_delta_time()))
		elapsed += dt
		if target == null or not is_instance_valid(target):
			return true
		if float(target.hp) < hp_before:
			contacted = true
			break
		# 目标 HP 尚未变化 = 还没有真实伤害 Contact；此时禁止人物动作元数据顿帧。
		if float(game.hitstop) > .001:
			_fail(label + " leaked hitstop before Contact")
			return false
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
	if not (game.player is TangFighterV6R5):
		_fail("TangFighterV6R5 not installed")
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

	# 平A：近处静止目标，必须通过 world-space projectile 才能扣血。
	var target = _durable_foe(game, p.position + Vector2(120, 0))
	if target == null:
		_fail("could not spawn target")
		quit(3)
		return
	var hp0 := float(target.hp)
	p.cool.auto = 999.0
	p._auto(target)
	await _wait_for_damage_without_precontact_hitstop(game, target, hp0, 1.35, "normal")
	# 真正 Contact 后平A本身也不应制造夸张停顿。
	if float(game.hitstop) > .001:
		_fail("normal Contact should not add hitstop")

	# Q：Contact 后才结算范围伤害/净化；Contact 前仍不能出现旧人物帧 hitstop。
	hp0 = float(target.hp)
	p.cool.q = 0.0
	p._tang_q(target)
	await _wait_for_damage_without_precontact_hitstop(game, target, hp0, 1.80, "Q")
	await _wait(.08)

	# E：释放后必须得到旧数值口径的 3 秒 shield，并挂 TangWardV6。
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

	# G：验证 player-tick cadence 不依赖 SceneTreeTimer，并给足完整 windup+分拍+飞行时间。
	hp0 = float(target.hp)
	p.cool.g = 0.0
	p._tang_g()
	await _wait_for_damage_without_precontact_hitstop(game, target, hp0, 2.20, "G")
	await _wait(.35)

	# R：法相状态满足后执行；最后应由 R5/R3 调度收束法相。
	p.form_left = 4.0
	p.form_age = 1.0
	p.ultimate = 100.0
	p.cool.r = 0.0
	hp0 = float(target.hp)
	var r_ok := p._ultimate()
	if not r_ok:
		_fail("R ultimate refused valid form state")
	else:
		await _wait_for_damage_without_precontact_hitstop(game, target, hp0, 2.40, "R")
	await _wait(.65)
	if p.form_left > 0.0:
		_fail("R did not close dharma form after release")

	print("TANG_R5_RUNTIME_SMOKE_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
