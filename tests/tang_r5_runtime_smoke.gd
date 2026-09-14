extends SceneTree

# 唐僧 R5 完整游戏运行时 smoke。
# 目的：用 Godot 真正实例化 scenes/main.tscn，验证继承链、平A/Q/E/G/R 的释放链能跑通。
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
	var hp0 := target.hp
	p.cool.auto = 999.0
	p._auto(target)
	await _wait(.90)
	if is_instance_valid(target) and target.hp >= hp0:
		_fail("normal projectile did not damage target")
	# 平A不允许人物关键帧预置 hitstop。
	if game.hitstop > .001:
		_fail("normal attack leaked pre-baked hitstop")

	# Q：Contact 后才结算范围伤害/净化；这里至少验证完整释放不报错且目标掉血。
	hp0 = target.hp
	p.cool.q = 0.0
	p._tang_q(target)
	await _wait(1.20)
	if is_instance_valid(target) and target.hp >= hp0:
		_fail("Q seal did not resolve damage")

	# E：释放后必须得到旧数值口径的 3 秒 shield，并挂 TangWardV6。
	p.cool.e = 0.0
	p._tang_e()
	await _wait(.75)
	if p.shield <= 0.0:
		_fail("E kasaya shield was not applied")
	var ward_found := false
	for n in game.get_children():
		if n is TangWardV6:
			ward_found = true
			break
	if not ward_found:
		_fail("E TangWardV6 node missing")

	# G：直接走正式动作释放入口；验证 player-tick cadence 不依赖 SceneTreeTimer。
	hp0 = target.hp
	p.cool.g = 0.0
	p._tang_g()
	await _wait(1.55)
	if is_instance_valid(target) and target.hp >= hp0:
		_fail("G beads did not resolve damage")

	# R：法相状态满足后执行；最后应由 R5/R3 调度收束法相。
	p.form_left = 4.0
	p.form_age = 1.0
	p.ultimate = 100.0
	p.cool.r = 0.0
	var r_ok := p._ultimate()
	if not r_ok:
		_fail("R ultimate refused valid form state")
	await _wait(1.80)
	if p.form_left > 0.0:
		_fail("R did not close dharma form after release")

	print("TANG_R5_RUNTIME_SMOKE_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
