extends SceneTree

# 唐僧 R9 正式运行录像：直接加载完整游戏 scenes/main.tscn。
# 顺序：左右走位 → 三拍远程平A → Q → E → G多目标 → 左朝向纯人物法相形成 → R多目标 → 收束。
# 重点观察：人物尺寸可读、POSE24 只在真实 Release 附近出现、弹体从实际 palm 脱手、
# Contact 后才 Impact，法相朝向与当前人物一致。禁止用 PIL/手工拼图代替本入口产出的实机录像。

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
		push_error("TANG_R9_MOVIE missing main scene")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	current_scene = game
	for i in 5:
		await process_frame
	if not (game.player is TangFighterV6R9):
		push_error("TANG_R9_MOVIE TangFighterV6R9 was not installed")
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
	game.toast("唐三藏 R9 · 更清楚的人物读形 / 真掌心Release / Contact-only命中")
	await _wait(.55)

	# 走位：先右再左，专门给人工视觉检查 flip、跑步脚步与法杖方向。
	Input.action_press("move_right")
	await _wait(.54)
	Input.action_release("move_right")
	await _wait(.12)
	Input.action_press("move_left")
	await _wait(.40)
	Input.action_release("move_left")
	await _wait(.20)

	var anchor_target = _durable_foe(game, p.position + Vector2(205, -8), "wolf")
	game.toast("平A · 持杖→合掌→袖手前引→可读的右掌Release→收势；一拍一枚独立咒弹")
	await _wait(1.90)

	p.cool.q = 0.0
	game.toast("Q 掌印镇压 · 右掌推出八角法印；飞行→Contact→镇压Impact")
	await _tap("skill_q")
	await _wait(1.42)

	p.cool.e = 0.0
	game.toast("E 锦襕袈裟 · 双肩布势 + 贴身护持；每次真实触敌才有小型接触反馈")
	await _tap("skill_e")
	await _wait(1.20)

	var offsets := [Vector2(175,-95), Vector2(235,-35), Vector2(225,70), Vector2(145,120), Vector2(-80,130)]
	for off in offsets:
		_durable_foe(game, p.position + off, "soldier")
	game.save["abilities"][p.g_ability()] = true
	p.cool.g = 0.0
	game.toast("G 诵经·定妖 · 近→远有限节拍；只有实际释放期保持前推掌")
	await _tap("gong")
	await _wait(1.70)

	# 法相前明确面向左，人工暂停帧可直接看出法身是否错误镜像。
	p.facing = Vector2.LEFT
	p.form_left = 4.2
	p.form_age = 1.0
	p.ultimate = 100.0
	game.toast("法相 · 干净Pose13人物 + 同人物低透明法身从背后升起；方向跟当前人物")
	await _wait(1.08)

	for off in [Vector2(-250,-120), Vector2(-320,-10), Vector2(-260,115), Vector2(210,-80)]:
		_durable_foe(game, p.position + off, "monk")
	p.cool.r = 0.0
	game.toast("R 大乘梵音 · 合掌→前引→右掌Release；梵音矢Contact后才hitstop/shake")
	await _tap("ult")
	await _wait(2.18)

	if is_instance_valid(anchor_target):
		print("TANG_R9_MOVIE_TARGET_HP=", anchor_target.hp)
	print("TANG_R9_MOVIE_DONE")
	quit(0)
