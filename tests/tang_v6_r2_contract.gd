extends SceneTree

# 唐僧 R2 静态/结构合同：专门防止旧技能表现回流。
# 该脚本由 Godot 运行时执行；本文件本身不替代真实录像验收。

var failed := false

func _assert_true(ok: bool, msg: String) -> void:
	if ok:
		print("PASS ", msg)
	else:
		failed = true
		push_error("FAIL " + msg)

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _initialize() -> void:
	var game_scene := _read("res://scenes/main.tscn")
	var game_v6 := _read("res://scripts/game_v6.gd")
	var tang := _read("res://scripts/tang_fighter_v6_r2.gd")
	var proj := _read("res://scripts/tang_spell_projectile_v6.gd")
	var impact := _read("res://scripts/tang_impact_v6.gd")
	var ward := _read("res://scripts/tang_ward_v6.gd")
	var spec := _read("res://data/tang_v6_skill_scripts.json")

	_assert_true(game_scene.contains("res://scripts/game_v6.gd"), "正式 main 场景进入 V6 完整游戏")
	_assert_true(game_v6.contains("TangFighterV6R2.new()"), "正式 player 使用 TangFighterV6R2")
	_assert_true(tang.contains("extends TangFighterV6"), "R2 继承 V6.1 关键帧/锚点系统")
	_assert_true(tang.contains("KeyframeLib.body_anchor_world(self, \"palm\")"), "技能起点使用真实 palm 锚点")
	_assert_true(tang.contains("register_spell_hit"), "多弹技能按技能组只记一次 on_hit")
	_assert_true(tang.contains("_release_g_bead"), "G 使用分批念珠释放")
	_assert_true(tang.contains("_release_r_arrow"), "R 使用分批梵音矢释放")
	_assert_true(tang.contains("1.72"), "法相有明确形成比例而非旧程序佛圈")

	# R2 新运行时不允许直接调用旧通用攻击/VFX模板。
	_assert_true(not tang.contains("queue_attack("), "R2 不调用旧 queue_attack Tang 技能")
	_assert_true(not tang.contains("fx.emit(\"lotus\""), "R2 无旧 lotus VFX")
	_assert_true(not tang.contains("fx.emit(\"ring\""), "R2 无旧 ring VFX")
	_assert_true(not tang.contains("fx.emit(\"rune\""), "R2 无旧 rune VFX")

	_assert_true(proj.contains("_find_world_contact"), "projectile 参与地图碰撞")
	_assert_true(proj.contains("Geometry2D.get_closest_point_to_segment"), "projectile 使用连续线段 Contact")
	_assert_true(proj.contains("TangImpactV6.new()"), "Contact 后使用唐僧专属 Impact")
	_assert_true(proj.contains("game.mechanic_solved = true"), "Q/G 净化仍可推进旧关卡机制")
	_assert_true(not proj.contains("game.fx.emit(\"impact\""), "projectile 不回退旧 generic impact")
	_assert_true(not proj.contains("game.fx.emit(\"lotus\""), "projectile 不回退旧 lotus")
	_assert_true(not proj.contains("game.fx.emit(\"ring\""), "projectile 不回退旧 ring")
	_assert_true(not proj.contains("game.fx.emit(\"rune\""), "projectile 不回退旧 rune")

	_assert_true(impact.contains("Contact 之后"), "专属 Impact 明确在 Contact 后")
	_assert_true(impact.contains("\"seal\""), "Q 有独立地面法印反馈")
	_assert_true(impact.contains("\"robe\""), "E 有独立袈裟展开反馈")
	_assert_true(ward.contains("e.hit(tick_damage"), "E 持续护持保留旧 ward tick damage")
	_assert_true(not ward.contains("draw_arc(Vector2.ZERO"), "E 不使用人物中心大圆盾")

	_assert_true(spec.contains("\"world_collision\": true"), "动作剧本声明地图 Contact")
	_assert_true(spec.contains("\"contact_before_impact\": true"), "动作剧本声明 Contact→Impact 顺序")
	_assert_true(spec.contains("\"old_tang_runtime_skills_disabled\": true"), "动作剧本明确旧 Tang 技能退役")

	print("TANG_V6_R2_CONTRACT_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
