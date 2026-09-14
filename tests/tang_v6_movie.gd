extends SceneTree

# 唐僧 R2 正式运行录像：直接加载完整游戏 scenes/main.tscn。
# 顺序：移动 → 三拍远程平A → Q → E → G多目标 → 法相形成 → R多目标 → 收束。

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
		push_error("TANG_R2_MOVIE missing main scene")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	if not (game.player is TangFighterV6R2):
		push_error("TANG_R2_MOVIE TangFighterV6R2 was not installed")
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
	game.toast("唐三藏 R2 · 旧 lotus/ring/rune 已退出唐僧技能链")
	await _wait(.55)

	# 1) 走位：V6.1 run / flip / anchor 同步。
	Input.action_press("move_right")
	await _wait(.62)
	Input.action_release("move_right")
	await _wait(.20)

	# 2) 三拍平A：一枚真实 world-space 弹体/拍，保留旧小范围命中口径。
	var anchor_target = _durable_foe(game, p.position + Vector2(205, -8), "wolf")
	game.toast("平A · palm 起手 → 单枚咒弹 → world-space → Contact 后碎经文")
	await _wait(1.70)

	# 3) Q：飞行到世界落点，再展开镇压。
	p.cool.q = 0.0
	game.toast("Q 掌印镇压 · 法印先飞，再在 Contact 点展开范围")
	await _tap("skill_q")
	await _wait(1.30)

	# 4) E：袈裟不是圆盾；保留旧初始脉冲+3秒护持。
	p.cool.e = 0.0
	game.toast("E 锦襕袈裟 · 双肩布势 + 贴身护持，不画旧 ward 圆环")
	await _tap("skill_e")
	await _wait(1.10)

	# 5) G：制造多目标，观察念珠按节奏逐一脱手。
	var offsets := [Vector2(175,-95), Vector2(235,-35), Vector2(225,70), Vector2(145,120), Vector2(-80,130)]
	for off in offsets:
		_durable_foe(game, p.position + off, "soldier")
	game.save["abilities"][p.g_ability()] = true
	p.cool.g = 0.0
	game.toast("G 诵经·定妖 · 六珠蓄势，42ms 节奏逐目标释放")
	await _tap("gong")
	await _wait(1.55)

	# 6) 法相：录像加速进入，仅为了观察形成阶段；正式游戏仍由充能触发。
	p.form_left = 4.0
	p.form_age = 1.0
	p.ultimate = 100.0
	game.toast("法相 · V6.1 人物法身约 1.72×，620ms 形成，碰撞不放大")
	await _wait(1.05)

	# R 前补目标，观察分批梵音矢和法相延迟收束。
	for off in [Vector2(250,-120), Vector2(320,-10), Vector2(260,115), Vector2(-210,-80)]:
		_durable_foe(game, p.position + off, "monk")
	p.cool.r = 0.0
	game.toast("R 大乘梵音 · 多目标分批梵音矢，Contact 后命中，最后再收法相")
	await _tap("ult")
	await _wait(2.00)

	if is_instance_valid(anchor_target):
		print("TANG_R2_MOVIE_TARGET_HP=", anchor_target.hp)
	print("TANG_R2_MOVIE_DONE")
	quit(0)
