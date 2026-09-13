extends SceneTree
## M2-R4 · 实际游戏地图真实战斗录像（配合 --write-movie evidence/m2-r4-*.avi）
## 与展示舞台(kf_stage)不同：这里跑真实 main.tscn——真实地图/刷怪/伤害/击杀/收服链，
## 1x 时标，自动驾驶+脚本化技能，连续展示：
##   悟空：移动→flip→平A挥棒弧→Q毫毛分身围攻→E定海重棒砸地(地裂+碎石)→筋斗闪残影
##   唐僧：远程环弹平A→Q禅音梵环波→G诵经念珠弹幕→E锦襕袈裟护体光环
## 用法：Godot_console --path . -s tests/combat_movie.gd --write-movie evidence/m2-r4-wukong-tangmonk-combat.avi

var m: Node2D
var p: CharacterBody2D

func _initialize() -> void:
	_run()

func _wait(s: float) -> void:
	await create_timer(s, true).timeout

## 等待树非暂停（避开三选一弹层）
func _wait_active(s: float) -> void:
	await _wait(s)
	var guard := 0
	while paused and guard < 60:
		await _wait(0.2)
		guard += 1

func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	var main_node: Node2D = scene.instantiate()
	root.add_child(main_node)
	await process_frame
	await process_frame
	m = get_first_node_in_group("main_ctl")
	if m == null:
		print("COMBAT_MOVIE fail: no main_ctl")
		quit(1)
		return
	p = m.player
	p.auto_pilot = true
	m.toast("R4 实录：真实地图 · 真实战斗 · 动作锚点编排")
	await _wait(1.0)

	# ===== 悟空：近战武器动作系统 =====
	p.set_hero("wukong")
	await _wait_active(1.5)
	m.toast("孙悟空 · 金红 #FF8A00 · 近中距离武器战士")
	await _wait_active(2.0)
	# 平A+移动（自动攻击自动进行）：显式走位展示 flip
	Input.action_press("move_right")
	await _wait_active(1.2)
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _wait_active(0.8)
	Input.action_release("move_left")
	await _wait_active(1.0)
	# Q 毫毛分身阵
	p.q_cd_left = 0.0
	p._cast_q()
	await _wait_active(2.2)
	# E 定海重棒（真实砸地：地裂/碎石/尘土/震屏）
	p.e_cd_left = 0.0
	p._cast_e()
	await _wait_active(2.4)
	# 筋斗闪
	p.dash_cd_left = 0.0
	p._do_dash(Vector2.RIGHT)
	await _wait_active(1.0)
	# 再来一轮平A → Q → E（连招与收招）
	await _wait_active(2.0)
	p.q_cd_left = 0.0
	p._cast_q()
	await _wait_active(1.6)
	p.e_cd_left = 0.0
	p._cast_e()
	await _wait_active(2.6)

	# ===== 唐僧：远程咒语弹幕系统 =====
	p.set_hero("tang")
	await _wait_active(1.5)
	m.toast("唐三藏 · 佛光金白 #F6C85F · 远程施法/弹幕")
	await _wait_active(2.0)
	# 远程平A环弹（自动攻击自动进行，AI 保持距离）
	Input.action_press("move_right")
	await _wait_active(0.9)
	Input.action_release("move_right")
	await _wait_active(1.6)
	# Q 禅音驱邪（梵环波）
	p.q_cd_left = 0.0
	p._cast_q()
	await _wait_active(2.4)
	# G 诵经·定妖（念珠弹幕）
	p.g_cd_left = 0.0
	p._cast_g()
	await _wait_active(2.6)
	# E 锦襕袈裟（护体光环）
	p.e_cd_left = 0.0
	p._cast_e()
	await _wait_active(2.2)
	# 收尾：再放一轮远程平A+Q，展示 flip 后弹道镜像
	Input.action_press("move_left")
	await _wait_active(0.9)
	Input.action_release("move_left")
	await _wait_active(1.4)
	p.q_cd_left = 0.0
	p._cast_q()
	await _wait_active(2.4)
	print("COMBAT_MOVIE done")
	quit(0)
