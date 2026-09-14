extends SceneTree
## M2-R5 · 真实完整游戏 Vertical Slice 录像入口。
## 不是展示舞台：加载 scenes/main.tscn，复用真实地图/刷怪/玩家战斗/KeyframeLib/VisualChoreography。
## 用法：
## godot --path . -s tests/m2_r5_visual_movie.gd --write-movie evidence/m2-r5-visual-choreography.avi
## 交付时再由 ffmpeg 转 GIF，ZIP + GIF 同时给负责人。

var m: Node2D
var p: CharacterBody2D

func _initialize() -> void:
	_run()

func _wait(s: float) -> void:
	await create_timer(s, true).timeout

func _wait_active(s: float) -> void:
	await _wait(s)
	var guard := 0
	while paused and guard < 60:
		await _wait(0.2)
		guard += 1

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		print("M2_R5_MOVIE fail: main scene load")
		quit(1)
		return
	var main_node := scene.instantiate() as Node2D
	if main_node == null:
		print("M2_R5_MOVIE fail: main scene instantiate")
		quit(1)
		return
	root.add_child(main_node)
	await process_frame
	await process_frame
	m = get_first_node_in_group("main_ctl") as Node2D
	if m == null:
		print("M2_R5_MOVIE fail: no main_ctl")
		quit(1)
		return
	var player_v = m.get("player")
	if not (player_v is CharacterBody2D):
		print("M2_R5_MOVIE fail: no player")
		quit(1)
		return
	p = player_v as CharacterBody2D
	p.set("auto_pilot", true)
	m.call("toast", "M2-R5：真实游戏 · V6.1动作编排 · 唐僧远程 / 悟空近战")
	await _wait_active(0.8)

	# ===== 唐僧：真实palm锚点 → 同时钟掌前法印 → world-space projectile → contact后impact =====
	p.call("set_hero", "tang")
	m.call("toast", "唐三藏：远程平A · palm真实锚点 · 脱手后world-space")
	await _wait_active(1.2)
	Input.action_press("move_right")
	await _wait_active(1.0)
	Input.action_release("move_right")
	await _wait_active(2.2) # 自动平A期间观察掌前法印/唯一world projectile/impact
	Input.action_press("move_left")
	await _wait_active(0.8)
	Input.action_release("move_left")
	await _wait_active(1.6)
	# 唐僧法相：测试入口只缩短观看片段，不改正式配置/数值文件。
	p.call("_enter_form")
	p.set("form_left", minf(float(p.get("form_left")), 3.2))
	m.call("toast", "唐三藏法相：现有V6.1 form姿势投影 · 佛光金/象牙白")
	await _wait_active(3.6)

	# ===== 悟空：真实staff_tip棍势 → 重砸真实地面反馈 → 人物专属法相 =====
	p.call("set_hero", "wukong")
	m.call("toast", "孙悟空：staff_tip真实棍势 · 赤金武器战士")
	await _wait_active(1.2)
	Input.action_press("move_right")
	await _wait_active(1.0)
	Input.action_release("move_right")
	await _wait_active(1.8)
	p.set("e_cd_left", 0.0)
	p.call("_cast_e")
	m.call("toast", "悟空重砸：武器端点→真实落点→地裂/碎石/尘土")
	await _wait_active(2.6)
	p.call("_enter_form")
	p.set("form_left", minf(float(p.get("form_left")), 3.2))
	m.call("toast", "悟空法相：V6.1 form姿势投影 · 赤金断续棍势环")
	await _wait_active(3.6)

	print("M2_R5_VISUAL_MOVIE done")
	quit(0)
