extends SceneTree
## V6.1 关键帧接入逻辑探针（headless）：真实物理帧 + 模拟按键，验证 idle/run 实时切换、
## 姿势推进、一次性动作播完回落、换装（白龙/悟空）。
var fails: Array = []

func _initialize() -> void:
	_run()

func _chk(cond: bool, name: String, extra := "") -> void:
	if not cond:
		fails.append("%s%s" % [name, (" 实际=" + str(extra)) if extra != "" else ""])

func _run() -> void:
	var ps: Script = load("res://scripts/player.gd")
	var p: CharacterBody2D = ps.new()
	root.add_child(p)
	if p.sprite == null:
		p._ready()   # -s 模式 _initialize 阶段 add_child 不触发 ready
	for i in 3:
		await physics_frame
	_chk(str(p.kf_slug) == "tang_sanzang", "唐僧slug", p.kf_slug)
	_chk(str(p.kf_action) == "idle", "初始idle", p.kf_action)
	Input.action_press("move_right")
	for i in 25:
		await physics_frame
	_chk(str(p.kf_action) == "run", "移动切run", p.kf_action)
	var t0: Texture2D = p.kf_sprite.texture
	for i in 15:
		await physics_frame
	_chk(p.kf_sprite.texture != t0, "run姿势推进")
	Input.action_release("move_right")
	for i in 10:
		await physics_frame
	_chk(str(p.kf_action) == "idle", "停止回idle", p.kf_action)
	KeyframeLib.play_action(p, "core_1", true)
	_chk(str(p.kf_action) == "core_1", "Q=core_1", p.kf_action)
	for i in 150:
		await physics_frame
	_chk(str(p.kf_action) == "idle", "Q播完回idle", p.kf_action)
	p.hero = "wukong"
	p._kf_rebuild()
	_chk(str(p.kf_slug) == "sun_wukong", "切悟空slug", p.kf_slug)
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	_chk(str(p.kf_action) == "run", "悟空移动run", p.kf_action)
	Input.action_release("move_right")
	print("KF_PROBE fails=%d %s" % [fails.size(), str(fails)])
	quit(0 if fails.is_empty() else 1)
