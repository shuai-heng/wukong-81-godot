extends SceneTree

# 旧完整游戏真实运行录像：唐僧移动 → 远程平A → Q → 法相。
# 不建展示舞台，直接加载 scenes/main.tscn。

func _initialize() -> void:
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		push_error("TANG_V6_MOVIE missing main scene")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	game.new_journey()
	await _wait(0.35)
	var p = game.player
	p.set_hero("tang")
	p.invulnerable = 99.0
	game.spawn_cd = 999.0
	game.env_cd = 999.0
	game.preview_cd = 999.0
	game.toast("唐三藏 V6.1：真实姿势 + 掌前法印 + world-space 远程平A")
	await _wait(0.65)

	# 先展示 V6.1 run 姿势。
	Input.action_press("move_right")
	await _wait(0.78)
	Input.action_release("move_right")
	await _wait(0.28)

	# 固定一个耐打目标，让唐僧连续远程平A；旧完整游戏的同一份伤害在接触时结算。
	var foe = game.spawn_enemy(p.position + Vector2(165, -10), "wolf", true)
	if foe != null:
		foe.hp = 9999.0
		foe.max_hp = 9999.0
	await _wait(2.45)

	# 展示 Q 的 V6.1 人物技能姿势；机制/伤害仍走旧完整游戏。
	Input.action_press("skill_q")
	await _wait(0.08)
	Input.action_release("skill_q")
	await _wait(1.45)

	# 直接进入法相观看段，只缩短录像，不改正式战斗数值配置。
	p.form_left = 2.25
	p.form_age = 0.0
	game.toast("唐三藏法相：V6.1 form 姿势，不再用草稿圆圈代替人物动作")
	await _wait(2.15)

	print("TANG_V6_MOVIE_DONE")
	quit(0)
