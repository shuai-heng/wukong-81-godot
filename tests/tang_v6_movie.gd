extends SceneTree

# 旧完整游戏真实运行录像：移动 → 新平A → Q → E → G → 法相 → R。
# 不建展示舞台，直接加载正式 scenes/main.tscn。

func _initialize() -> void:
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout

func _tap(action: String, hold := 0.07) -> void:
	Input.action_press(action)
	await _wait(hold)
	Input.action_release(action)

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
	await process_frame
	if not (game.player is TangFighterV6):
		push_error("TANG_V6_MOVIE V6 fighter was not installed")
		quit(2)
		return
	game.new_journey()
	await _wait(0.30)
	var p = game.player
	p.set_hero("tang")
	p.invulnerable = 99.0
	game.spawn_cd = 999.0
	game.env_cd = 999.0
	game.preview_cd = 999.0
	game.toast("唐三藏 V6：旧技能旁路 · 掌心锚点 · world-space 法术")
	await _wait(0.45)

	# V6.1 run。
	Input.action_press("move_right")
	await _wait(0.58)
	Input.action_release("move_right")
	await _wait(0.18)

	# 耐打目标：连续观察掌心起手与世界空间咒弹。
	var foe = game.spawn_enemy(p.position + Vector2(178, -6), "wolf", true)
	if foe != null:
		foe.hp = 9999.0
		foe.max_hp = 9999.0
	await _wait(1.55)

	game.toast("Q · 掌印镇压：法印先飞行，接触世界落点后才展开")
	await _tap("skill_q")
	await _wait(1.15)

	game.toast("E · 锦襕袈裟：贴身护持，不再是旧 ward 大圆环")
	await _tap("skill_e")
	await _wait(1.05)

	# 录像专用解锁 G，不修改正式默认存档。
	game.save["abilities"][p.g_ability()] = true
	p.cool.g = 0.0
	game.toast("G · 诵经定妖：念珠弹从 palm 脱手逐目标飞行")
	await _tap("gong")
	await _wait(1.35)

	# 直接进入法相观看段，仅缩短录像；正式数值仍由游戏充能进入。
	p.form_left = 3.0
	p.form_age = 1.0
	p.ultimate = 100.0
	game.toast("法相 · V6.1 人物法身投影，不再画旧程序佛圈")
	await _wait(0.95)

	game.toast("R · 大乘梵音：法相收势后发出 world-space 梵音矢")
	await _tap("ult")
	await _wait(1.65)

	print("TANG_V6_MOVIE_DONE")
	quit(0)
