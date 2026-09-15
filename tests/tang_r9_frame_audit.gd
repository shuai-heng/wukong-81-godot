extends SceneTree

# 唐僧 R9 实机暂停帧审查。
# 这不是 storyboard，也不重绘任何人物；每张 PNG 都来自真正运行中的 scenes/main.tscn viewport。
# 用途：专门抓“跑步 / Release / projectile / Contact / E / 法相 / R / Recovery”单帧，
# 防止靠连续播放掩盖半身残留、双人物、烘焙大图、锚点漂移或错误朝向。

const OUT_DIR := "user://tang-r9-frame-audit"
var failed := false
var frame_index := 0
var manifest: Array[String] = []

func _initialize() -> void:
	_run()

func _wait(sec: float) -> void:
	await create_timer(sec, true).timeout

func _fail(msg: String) -> void:
	failed = true
	push_error("TANG_R9_FRAME_AUDIT " + msg)

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		_fail("viewport capture failed: " + label)
		return
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	var safe := "%02d_%s.png" % [frame_index, label]
	var path := OUT_DIR + "/" + safe
	var err := img.save_png(path)
	if err != OK:
		_fail("save_png failed %s err=%s" % [path, err])
		return
	manifest.append(safe)
	print("TANG_R9_FRAME ", ProjectSettings.globalize_path(path))
	frame_index += 1

func _durable_foe(game, at: Vector2, kind := "wolf"):
	var e = game.spawn_enemy(at, kind, true)
	if e != null:
		e.hp = 9999.0
		e.max_hp = 9999.0
		e.speed = 0.0
		e.attack_cd = 999.0
	return e

func _wait_pose(player, pose_id: int, timeout := 1.0) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		await process_frame
		elapsed += maxf(1.0 / 240.0, float(root.get_process_delta_time()))
		if is_instance_valid(player) and int(player._r4_pose_id) == pose_id:
			return true
	return false

func _wait_projectile(game, timeout := .8):
	var elapsed := 0.0
	while elapsed < timeout:
		await process_frame
		elapsed += maxf(1.0 / 240.0, float(root.get_process_delta_time()))
		for n in game.get_children():
			if n is TangSpellProjectileV6 and is_instance_valid(n):
				return n
	return null

func _wait_damage(target, hp_before: float, timeout := 1.5) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		await process_frame
		elapsed += maxf(1.0 / 240.0, float(root.get_process_delta_time()))
		if target == null or not is_instance_valid(target):
			return true
		if float(target.hp) < hp_before:
			return true
	return false

func _run() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed == null:
		_fail("main scene missing")
		quit(1)
		return
	var game = packed.instantiate()
	root.add_child(game)
	current_scene = game
	for i in 6:
		await process_frame
	if not (game.player is TangFighterV6R9):
		_fail("TangFighterV6R9 not installed")
		quit(2)
		return

	game.new_journey()
	await _wait(.30)
	var p = game.player
	p.set_hero("tang")
	p.invulnerable = 99.0
	game.spawn_cd = 999.0
	game.env_cd = 999.0
	game.preview_cd = 999.0

	# 01：地面跑步。任何横飞 Pose06 / 残影双人都应在单帧直接暴露。
	Input.action_press("move_right")
	await _wait(.28)
	await _capture("run_right")
	Input.action_release("move_right")
	await _wait(.16)

	# 02–04：平A Release → 已脱手 projectile → Contact。
	var target = _durable_foe(game, p.position + Vector2(210, 0), "wolf")
	if target == null:
		_fail("could not spawn audit target")
		quit(3)
		return
	p.cool.auto = 999.0
	var hp0 := float(target.hp)
	p._auto(target)
	if await _wait_pose(p, 24, .9):
		await _capture("normal_release_pose24")
	else:
		_fail("normal never reached POSE24")
	var projectile = await _wait_projectile(game, .55)
	if projectile != null:
		await _wait(.045)
		await _capture("normal_projectile_world_space")
	else:
		_fail("normal projectile not found")
	if await _wait_damage(target, hp0, 1.2):
		await _capture("normal_contact_impact")
	else:
		_fail("normal did not contact target")
	await _wait(.28)
	await _capture("normal_recovery")

	# 05：E 只看贴身袈裟线与真实目标 Contact，禁止大圆盾。
	p.cool.e = 0.0
	p._tang_e()
	await _wait(.58)
	await _capture("e_kasaya_guard")

	# 06：左朝向法相。法身必须同向、在人物背后形成，不能出现第二张烘焙佛像。
	p.facing = Vector2.LEFT
	p.form_left = 4.2
	p.form_age = 1.0
	p.ultimate = 100.0
	await _wait(.62)
	await _capture("form_left_clean_echo")

	# 07–08：R Release 与收招。
	for off in [Vector2(-250,-95), Vector2(-300,25), Vector2(-220,110)]:
		_durable_foe(game, p.position + off, "monk")
	p.cool.r = 0.0
	if not p._ultimate():
		_fail("R ultimate refused valid audit state")
	else:
		if await _wait_pose(p, 24, 1.2):
			await _capture("r_release_pose24")
		else:
			_fail("R never reached POSE24")
		await _wait(1.05)
		await _capture("r_projectiles_and_contacts")
		await _wait(1.05)
		await _capture("r_recovery_form_closed")

	var manifest_path := OUT_DIR + "/manifest.txt"
	var f := FileAccess.open(manifest_path, FileAccess.WRITE)
	if f != null:
		f.store_string("Tang R9 real Godot frame audit\n" + "\n".join(manifest) + "\n")
		f.close()
	print("TANG_R9_FRAME_AUDIT_DIR=", ProjectSettings.globalize_path(OUT_DIR))
	print("TANG_R9_FRAME_AUDIT_", "FAIL" if failed else "PASS", " frames=", frame_index)
	quit(1 if failed else 0)
