extends SceneTree

# 唐僧 R8 正式运行录像：直接加载完整游戏 scenes/main.tscn。
# 顺序：移动 → 三拍远程平A → Q → E → G多目标 → 纯人物法相形成 → R多目标 → 收束。
# 重点观察：POSE24 只在真实 Release 短窗口出现；这是实机录像入口，不允许用 PIL/手工拼图代替。

func _initialize() -> void:
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout

func _tap(action: String, hold := 0.07) -> void:
	Input.action_press(action)
	await _wait(hold)
	Input.action_release(action)

func _durable_foe(game, at: Vector2, kind := "wolf"):
	var e = game.spawn_enemy(at, kind, true)
	if e != null:
		e.hp = 9999.0
		e.max_hp = 9999.0
		e.speed = 0.0
		e.attack_cd = 999.0
	return e

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("TANG_R8_MOVIE missing main scene")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	current_scene = game
	for i in 5:
		await process_frame
	if not (game.player is TangFighterV6R8):
		push_error("TANG_R8_MOVIE TangFighterV6R8 was not installed")
		quit(2)
		return

	game.new_journey()
	await _wait(.32)
	var p = game.player
	p.set_hero("tang")
	p.invulnerable = 99.0
	game.spawn_cd = 999.0
	game.env_cd = 999.0
	game.preview_cd = 999.0
	game.toast("唐三藏 R8 · Release短窗口 + world-space技能 + Contact-only命中")
	await _wait(.55)

	# 走位：地面步态，不允许 POSE06 横飞。
	Input.action_press("move_right")
	await _wait(.62)
	Input.action_release("move_right")
	await _wait(.20)

	var anchor_target = _durable_foe(game, p.position + Vector2(205, -8), "wolf")
	game.toast("平A · 持杖→合掌→袖手前引→短暂右掌Release→收势；单枚咒弹独立飞行")
	await _wait(1.70)

	p.cool.q = 0.0
	game.toast("Q 掌印镇压 · Release瞬间右掌推出八角法印；Contact后才展开")
	await _tap("skill_q")
	await _wait(1.35)

	p.cool.e = 0.0
	game.toast("E 锦襕袈裟 · 双肩布势 + 贴身护持，无旧大圆盾")
	await _tap("skill_e")
	await _wait(1.15)

	var offsets := [Vector2(175,-95), Vector2(235,-35), Vector2(225,70), Vector2(145,120), Vector2(-80,130)]
	for off in offsets:
		_durable_foe(game, p.position + off, "soldier")
	game.save["abilities"][p.g_ability()] = true
	p.cool.g = 0.0
	game.toast("G 诵经·定妖 · 仅实际分拍释放期间保持前推掌；结束立即Recovery")
	await _tap("gong")
	await _wait(1.60)

	p.form_left = 4.2
	p.form_age = 1.0
	p.ultimate = 100.0
	game.toast("法相 · 干净Pose13本体 + 同人物低透明法身升起放大；无烘焙佛像/莲花")
	await _wait(1.05)

	for off in [Vector2(250,-120), Vector2(320,-10), Vector2(260,115), Vector2(-210,-80)]:
		_durable_foe(game, p.position + off, "monk")
	p.cool.r = 0.0
	game.toast("R 大乘梵音 · 实际梵音矢分拍期间持前推掌；Contact后才hitstop/shake")
	await _tap("ult")
	await _wait(2.10)

	if is_instance_valid(anchor_target):
		print("TANG_R8_MOVIE_TARGET_HP=", anchor_target.hp)
	print("TANG_R8_MOVIE_DONE")
	quit(0)
