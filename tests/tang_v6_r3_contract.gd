extends SceneTree

# 唐僧完整运行链结构门禁：R3 新 Q/E/G/R；R4 普通人物 Pose；R5 Contact-only；R6 纯人物法相；R7 清理后的前推掌 Release 帧。
# 防止旧 Bootstrap、旧 Tang 技能或旧 generic VFX 回流。
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
	var project := _read("res://project.godot")
	var game_scene := _read("res://scenes/main.tscn")
	var game_v6 := _read("res://scripts/game_v6.gd")
	var r2 := _read("res://scripts/tang_fighter_v6_r2.gd")
	var r3 := _read("res://scripts/tang_fighter_v6_r3.gd")
	var r4 := _read("res://scripts/tang_fighter_v6_r4.gd")
	var r5 := _read("res://scripts/tang_fighter_v6_r5.gd")
	var r6 := _read("res://scripts/tang_fighter_v6_r6.gd")
	var r7 := _read("res://scripts/tang_fighter_v6_r7.gd")
	var proj := _read("res://scripts/tang_spell_projectile_v6.gd")
	var impact := _read("res://scripts/tang_impact_v6.gd")
	var ward := _read("res://scripts/tang_ward_v6.gd")
	var spec := _read("res://data/tang_v6_skill_scripts.json")

	_assert_true(game_scene.contains("res://scripts/game_v6.gd"), "正式 main 场景进入 V6 完整游戏")
	_assert_true(game_v6.contains("TangFighterV6R7.new()"), "正式 player 使用 TangFighterV6R7")
	_assert_true(r7.contains("extends TangFighterV6R6"), "R7 继承 R6 干净法相层")
	_assert_true(r6.contains("extends TangFighterV6R5"), "R6 继承 R5 Contact-only 层")
	_assert_true(r5.contains("extends TangFighterV6R4"), "R5 继承 R4 人物视觉层")
	_assert_true(r4.contains("extends TangFighterV6R3"), "R4 继承 R3 新技能执行层")
	_assert_true(not project.contains("TangV6Bootstrap"), "旧 Bootstrap autoload 已从正式入口删除")
	_assert_true(not FileAccess.file_exists("res://scripts/tang_v6_actor.gd"), "旧 TangV6Actor 文件已删除")
	_assert_true(not FileAccess.file_exists("res://scripts/tang_v6_bootstrap.gd"), "旧 TangV6Bootstrap 文件已删除")

	_assert_true(r3.contains("func _tang_q"), "R3 覆盖旧 Q")
	_assert_true(r3.contains("func _tang_e"), "R3 覆盖旧 E")
	_assert_true(r3.contains("func _tang_g"), "R3 覆盖旧 G")
	_assert_true(r3.contains("func _ultimate"), "R3 覆盖旧 R")
	_assert_true(r3.contains("_release_q_r3"), "Q 接通新 world-space 法印弹")
	_assert_true(r3.contains("_release_e"), "E 接通新袈裟护持执行器")
	_assert_true(r3.contains("_release_g"), "G 接通分批念珠执行器")
	_assert_true(r3.contains("_release_r"), "R 接通分批梵音执行器")
	_assert_true(not r3.contains("queue_attack("), "R3 不调用旧 queue_attack Tang 技能")
	_assert_true(not r3.contains("fx.emit(\"lotus\""), "R3 无旧 lotus")
	_assert_true(not r3.contains("fx.emit(\"ring\""), "R3 无旧 ring")
	_assert_true(not r3.contains("fx.emit(\"rune\""), "R3 无旧 rune")

	_assert_true(r2.contains("register_spell_hit"), "G/R 整批命中按技能组计一次 on_hit")
	_assert_true(r4.contains("func _r4_palm_world"), "技能起点跟当前可见人物 Pose 的 palm")
	_assert_true(r4.contains("func _spawn_spell"), "R4 在实际 release 同帧覆盖 projectile 起点")
	_assert_true(r6.contains("_r4_pose_tex(13)"), "法相使用干净人物 Pose13 形成投影")
	_assert_true(not r6.contains("POSE_31__") and not r6.contains("POSE_36__"), "R6 不直接加载烘焙法相/终结 Pose")
	_assert_true(r7.contains("R7_POSE24_FILE") and r7.contains("R7_MASK_PATH"), "R7 用遮罩清理现有 POSE24 作为前推掌 Release 帧")
	_assert_true(r7.contains("R7_PALM_UV"), "R7 Release projectile 绑定 POSE24 真实前推掌")
	_assert_true(proj.contains("_find_world_contact"), "projectile 参与世界障碍 Contact")
	_assert_true(proj.contains("Geometry2D.get_closest_point_to_segment"), "高速 projectile 使用连续线段 Contact")
	_assert_true(proj.contains("TangImpactV6.new()"), "Contact 后使用 Tang 专属 Impact")
	_assert_true(proj.contains("game.mechanic_solved = true"), "Q/G 净化仍保留旧关卡机制")
	_assert_true(not proj.contains("game.fx.emit(\"impact\""), "弹体不回退 generic impact")
	_assert_true(not proj.contains("game.fx.emit(\"lotus\""), "弹体不回退 lotus")
	_assert_true(not proj.contains("game.fx.emit(\"ring\""), "弹体不回退 ring")
	_assert_true(not proj.contains("game.fx.emit(\"rune\""), "弹体不回退 rune")

	_assert_true(impact.contains("Contact 之后"), "专属 Impact 明确 Contact→Impact")
	_assert_true(impact.contains("\"seal\""), "Q 有独立地面法印")
	_assert_true(impact.contains("\"robe\""), "E 有独立袈裟展开反馈")
	_assert_true(ward.contains("e.hit(tick_damage"), "E 保留旧 ward tick damage")
	_assert_true(not ward.contains("draw_arc(Vector2.ZERO"), "E 不画人物中心大圆盾")

	_assert_true(spec.contains("\"world_collision\": true"), "动作剧本声明地图 Contact")
	_assert_true(spec.contains("\"contact_before_impact\": true"), "动作剧本声明 Contact→Impact")
	_assert_true(spec.contains("\"old_tang_runtime_skills_disabled\": true"), "动作剧本声明旧 Tang 技能退役")

	print("TANG_V6_RUNTIME_CONTRACT_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)