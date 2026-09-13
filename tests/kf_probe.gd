extends SceneTree
## V6.1 关键帧接入逻辑探针（headless）：真实物理帧 + 模拟按键，验证 idle/run 实时切换、
## 姿势推进、一次性动作播完回落、换装（白龙/悟空）、M2 插值/交叉淡化/状态过渡/演出元数据。
var fails: Array = []

## 子步4 桩主循环：承接 hitstop/震屏/残影调用（探针环境无真实 main）
## R3：另录制 弹体/冲击/尘土/焦痕/预告 调用，tick_shots 手动推进弹体到命中
class StubMain extends Node2D:
	var hitstop := 0.0
	var rng := RandomNumberGenerator.new()
	var shakes: Array = []
	var phantom_count := 0
	var phantom_tex: Texture2D = null
	var impacts: Array = []
	var shots: Array = []
	var marks: Array = []
	var decal_count := 0
	var dust_count := 0
	func request_shake(s: float) -> void:
		shakes.append(s)
	func spawn_phantom(pos: Vector2, flip: bool, tex: Texture2D = null, scl := Vector2.ONE, life := -1.0) -> void:
		phantom_count += 1
		phantom_tex = tex
	func toast(msg: String) -> void:
		pass
	func on_hit_feedback(pos: Vector2, dmg: float, heavy: bool) -> void:
		hitstop = 0.052 if heavy else 0.028
	func spawn_fx(pos: Vector2, r: float, color: Color) -> void:
		pass
	func spawn_impact(pos: Vector2, r: float, color: Color) -> void:
		impacts.append([pos, r])
		dust_count += 6
	func spawn_skill_shot(from: Vector2, to: Vector2, dur: float, color: Color, r := 9.0, on_arrive: Callable = Callable()) -> void:
		shots.append({"pos": from, "from": from, "to": to, "t": 0.0, "dur": maxf(dur, 0.04), "r": r, "on_arrive": on_arrive})
	func tick_shots(delta: float) -> void:
		for s in shots.duplicate():
			s["t"] = float(s["t"]) + delta
			var sfrom: Vector2 = s["from"]
			var sto: Vector2 = s["to"]
			var k: float = clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
			s["pos"] = sfrom.lerp(sto, k)
			if k >= 1.0:
				var cb: Callable = s["on_arrive"]
				shots.erase(s)
				if cb.is_valid():
					cb.call()
	func spawn_dust(pos: Vector2, r: float, n := 4) -> void:
		dust_count += n
	func spawn_decal(pos: Vector2, r: float, color: Color) -> void:
		decal_count += 1
	func spawn_ground_mark(pos: Vector2, r: float, life: float, color: Color) -> void:
		marks.append([pos, r, life])

## R3 木桩敌人：真实 take_hit/hp，验证伤害结算时机
class ProbeDummy extends Node2D:
	var hit_r := 22.0
	var hp := 1000.0
	func _ready() -> void:
		add_to_group("enemies")
	func take_hit(dmg: float, knock: Vector2) -> void:
		hp -= dmg

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
	# ---- M2 子步1：关键帧间插值（同步采样，core_1 段[280,373)ms）----
	KeyframeLib.play_action(p, "core_1", true)
	var kfs: Array = KeyframeLib._acts["tang_sanzang"]["core_1"]
	p.kf_t = 0.3265
	KeyframeLib._apply_pose(p, kfs)
	var mid_pos: Vector2 = p.kf_sprite.position
	var mid_rot: float = p.kf_sprite.rotation
	var mid_tex: Texture2D = p.kf_sprite.texture
	p.kf_t = 0.280
	KeyframeLib._apply_pose(p, kfs)
	var lo_pos: Vector2 = p.kf_sprite.position
	var lo_rot: float = p.kf_sprite.rotation
	p.kf_t = 0.373
	KeyframeLib._apply_pose(p, kfs)
	var hi_pos: Vector2 = p.kf_sprite.position
	var hi_rot: float = p.kf_sprite.rotation
	_chk(mid_pos != lo_pos and mid_pos != hi_pos, "插值中间位移异于两端", str([lo_pos, mid_pos, hi_pos]))
	_chk(mid_rot > minf(lo_rot, hi_rot) and mid_rot < maxf(lo_rot, hi_rot), "旋转插值介于两端", str([lo_rot, mid_rot, hi_rot]))
	p.kf_t = 0.3729
	KeyframeLib._apply_pose(p, kfs)
	_chk(p.kf_sprite.texture == mid_tex, "段内纹理不变", "")
	p.kf_t = 0.373
	KeyframeLib._apply_pose(p, kfs)
	_chk(p.kf_sprite.texture != mid_tex, "关键帧时刻纹理切换", "")
	p.kf_t = 0.3265
	p.sprite.flip_h = false
	KeyframeLib._apply_pose(p, kfs)
	var r_pos: Vector2 = p.kf_sprite.position
	var r_rot: float = p.kf_sprite.rotation
	p.sprite.flip_h = true
	KeyframeLib._apply_pose(p, kfs)
	_chk(absf(p.kf_sprite.position.x + r_pos.x) < 0.001 and absf(p.kf_sprite.rotation + r_rot) < 0.0001, "flip镜像取反",
		str([r_pos, p.kf_sprite.position, r_rot, p.kf_sprite.rotation]))
	p.sprite.flip_h = false
	# ---- M2 子步2：姿势交叉淡化 ----
	_chk(p.kf_fade_sprite != null, "淡化层已创建")
	if p.kf_fade_sprite != null:
		Input.action_press("move_right")
		var switched := false
		var fade_alpha := -1.0
		for i in 120:
			await physics_frame
			if not switched and p.kf_fade_sprite.visible:
				switched = true
				fade_alpha = p.kf_fade_sprite.modulate.a
		Input.action_release("move_right")
		_chk(switched, "姿势切换触发交叉淡化")
		if switched:
			_chk(fade_alpha > 0.0 and fade_alpha < 1.0, "淡化层中间透明度", str(fade_alpha))
		for i in 40:
			await physics_frame
		_chk(not p.kf_fade_sprite.visible, "淡化层淡出后隐藏")
		_chk(absf(p.kf_sprite.modulate.a - 1.0) < 0.01, "主精灵透明度回落", str(p.kf_sprite.modulate.a))
	# ---- M2 子步3：状态过渡混合（idle↔run 切换短过渡；收招不冻结） ----
	for i in 30:
		await physics_frame
	Input.action_press("move_right")
	var blended := false
	var blend_alpha := -1.0
	for i in 20:
		await physics_frame
		if i < 8 and p.kf_blend_left > 0.0:
			blended = true
			blend_alpha = p.kf_sprite.modulate.a
	Input.action_release("move_right")
	_chk(blended, "状态切换触发过渡混合")
	if blended:
		_chk(blend_alpha < 1.0, "过渡期主精灵半透明", str(blend_alpha))
	for i in 40:
		await physics_frame
	_chk(absf(p.kf_sprite.modulate.a - 1.0) < 0.01, "过渡后透明度回落", str(p.kf_sprite.modulate.a))
	_chk(str(p.kf_action) == "idle", "子步3后回idle", p.kf_action)
	# 确定性验证缩放缓冲：手动设 blend 中点，同帧施加后 scale 应小于纯姿势 scale
	var kfs_run: Array = KeyframeLib._acts["tang_sanzang"]["run"]
	p.kf_t = 0.045
	KeyframeLib._apply_pose(p, kfs_run)
	var sc_pure: float = p.kf_sprite.scale.x
	p.kf_blend_left = 0.05
	p.kf_blend_dur = 0.1
	KeyframeLib._advance_fades(p, 0.0)
	_chk(p.kf_sprite.scale.x < sc_pure, "过渡期缩放缓冲生效", str([sc_pure, p.kf_sprite.scale.x]))
	p.kf_blend_left = 0.0
	KeyframeLib._advance_fades(p, 0.0)
	_chk(absf(p.kf_sprite.modulate.a - 1.0) < 0.01, "缓冲结束后透明度复原", str(p.kf_sprite.modulate.a))
	# ---- M2 子步4：打击感元数据接入（core_1 段8=747-840ms：hitstop70/震屏4.0/vfx1.0） ----
	var stub := StubMain.new()
	p.main = stub
	KeyframeLib.play_action(p, "core_1", true)
	p.kf_t = 0.750
	KeyframeLib.tick(p, 0.0, false)
	_chk(stub.hitstop > 0.0, "元数据触发hitstop", str(stub.hitstop))
	_chk(stub.shakes.size() > 0, "元数据触发震屏", str(stub.shakes))
	_chk(p.kf_freeze_left > 0.0, "元数据顿帧定格", str(p.kf_freeze_left))
	_chk(p.kf_glow_sprite != null and p.kf_glow_sprite.visible, "高强度vfx发光层可见", "")
	p.kf_t = 0.0
	KeyframeLib.tick(p, 0.0, false)
	_chk(not p.kf_glow_sprite.visible, "低强度vfx关闭发光", "")
	for i in 120:
		await physics_frame
		if str(p.kf_action) == "":
			break
	Input.action_press("move_right")
	var trail_pts := 0
	for i in 20:
		await physics_frame
		if p.kf_trail != null:
			trail_pts = p.kf_trail.get_point_count()
	Input.action_release("move_right")
	_chk(trail_pts >= 2, "run拖尾采样", str(trail_pts))
	var pc0: int = stub.phantom_count
	KeyframeLib.play_action(p, "atk_combo", true)
	for i in 30:
		await physics_frame
	_chk(stub.phantom_count > pc0, "元数据残影", str([pc0, stub.phantom_count]))
	_chk(stub.phantom_tex != null, "残影用姿势纹理", "")
	# ---- R3：完整技能释放编排（起手→释放帧→命中→地图反馈） ----
	var dummy := ProbeDummy.new()
	dummy.position = p.position + Vector2(90.0, 0.0)
	root.add_child(dummy)
	for i in 3:
		await physics_frame
	var rel_q: float = KeyframeLib.release_time("tang_sanzang", "core_1")
	_chk(rel_q > 0.0, "释放帧解析(hitbox_active)", str(rel_q))
	p.atk_cd_left = 99.0   # 冻结自动攻击：时序断言只考察本次 Q
	p._cast_q()
	var hp0: float = dummy.hp
	_chk(str(p.kf_action) == "core_1" and float(p.kf_release_t) > 0.0, "Q登记待释放", str([p.kf_action, p.kf_release_t]))
	_chk(dummy.hp >= hp0, "起手期(帧0)无伤害", str(dummy.hp))
	p.kf_t = rel_q - 0.03
	p._kf_release_tick()
	_chk(dummy.hp >= hp0, "释放帧前伤害未到", str(dummy.hp))
	p.kf_t = rel_q
	p._kf_release_tick()
	_chk(dummy.hp < hp0, "释放帧结算伤害", str(dummy.hp))
	_chk(stub.impacts.size() > 0, "释放帧触发冲击+地图反馈", str(stub.impacts.size()))
	_chk(stub.dust_count > 0, "尘土生成", str(stub.dust_count))
	# 锚点：随姿势偏移、随 flip 镜像
	KeyframeLib.play_action(p, "core_1", true)
	p.kf_t = 0.40
	KeyframeLib._apply_pose(p, KeyframeLib._acts["tang_sanzang"]["core_1"])
	p.sprite.flip_h = false
	KeyframeLib._apply_pose(p, KeyframeLib._acts["tang_sanzang"]["core_1"])
	var aw_r: Vector2 = KeyframeLib.anchor_world(p, "f")
	_chk(aw_r.distance_to(p.global_position) > 1.0, "锚点偏离身体中心", str(aw_r))
	p.sprite.flip_h = true
	KeyframeLib._apply_pose(p, KeyframeLib._acts["tang_sanzang"]["core_1"])
	var aw_l: Vector2 = KeyframeLib.anchor_world(p, "f")
	_chk((aw_r.x - p.global_position.x) * (aw_l.x - p.global_position.x) < 0.0, "锚点随flip镜像", str([aw_r, aw_l]))
	p.sprite.flip_h = false
	# 打断取消：起手中切动作→待释放作废
	p._cast_e()
	_chk(float(p.kf_release_t) > 0.0, "E登记待释放", str(p.kf_release_t))
	KeyframeLib.play_action(p, "idle", false)
	_chk(float(p.kf_release_t) < 0.0, "打断取消待释放", str(p.kf_release_t))
	# 弹体命中绑定到达
	var shot_flag := [false]
	stub.spawn_skill_shot(Vector2.ZERO, Vector2(100.0, 0.0), 0.10, Color.WHITE, 8.0, func(): shot_flag[0] = true)
	stub.tick_shots(0.05)
	_chk(not shot_flag[0], "弹体未到不结算", "")
	stub.tick_shots(0.06)
	_chk(shot_flag[0], "弹体到达结算", "")
	# 悟空 E：起手期出现落点预告圈（作用区域先示形）
	p.main = stub
	p.hero = "wukong"
	p._kf_rebuild()
	p.e_cd_left = 0.0
	p._cast_e()
	_chk(stub.marks.size() > 0, "E起手期落点预告圈", str(stub.marks.size()))
	for i in 90:
		await physics_frame
	dummy.remove_from_group("enemies")   # 撤桩：后续 run 断言不受自动攻击干扰
	p.atk_cd_left = 99.0
	for i in 60:
		await physics_frame   # 排空残余一次性动作
	p.main = null
	_chk(str(p.kf_slug) == "sun_wukong", "切悟空slug", p.kf_slug)
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	_chk(str(p.kf_action) == "run", "悟空移动run", p.kf_action)
	Input.action_release("move_right")
	print("KF_PROBE fails=%d %s" % [fails.size(), str(fails)])
	quit(0 if fails.is_empty() else 1)
