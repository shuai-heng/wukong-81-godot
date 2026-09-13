extends SceneTree
## V6.1 关键帧接入逻辑探针（headless）：真实物理帧 + 模拟按键，验证 idle/run 实时切换、
## 姿势推进、一次性动作播完回落、换装（白龙/悟空）、M2 插值/交叉淡化/状态过渡/演出元数据、
## R3 完整技能释放编排、R4 身体锚点/挥击弧/世界弹体/命中绑定到达。
var fails: Array = []

## 桩主循环：承接 hitstop/震屏/残影调用（探针环境无真实 main）
## R3：录制 弹体/冲击/尘土/焦痕/预告 调用；R4：同步 挥击弧/碎石/地裂/梵环波/念珠/环弹/护体/星点
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
	# ---- R4 ----
	var swings: Array = []       # {id,color,width,pts,times,feeding}
	var swing_seq := 0
	var debris_count := 0
	var cracks: Array = []       # [pos, r]
	var waves: Array = []        # 同 main.fx_waves
	var beads: Array = []        # 同 main.fx_shots(kind=bead)
	var rings: Array = []        # 同 main.fx_shots(kind=ring)
	var auras: Array = []
	var mote_count := 0
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
	func spawn_ring_shot(from: Vector2, to: Vector2, dur: float, color: Color, r := 10.0,
			on_arrive: Callable = Callable(), target: Node2D = null) -> void:
		rings.append({"pos": from, "from": from, "to": to, "t": 0.0, "dur": maxf(dur, 0.05),
			"color": color, "r": r, "kind": "ring", "target": target, "on_arrive": on_arrive})
	func spawn_bead(from: Vector2, target: Node2D, speed: float, color: Color, on_arrive: Callable) -> void:
		beads.append({"pos": from, "from": from, "to": target.global_position, "t": 0.0,
			"dur": maxf(0.08, from.distance_to(target.global_position) / maxf(speed, 1.0)),
			"color": color, "r": 4.0, "kind": "bead", "target": target, "on_arrive": on_arrive})
	func swing_begin(color: Color, width := 7.0) -> int:
		swing_seq += 1
		swings.append({"id": swing_seq, "color": color, "width": width, "pts": [], "times": [], "feeding": true})
		return swing_seq
	func swing_point(id: int, pos: Vector2) -> void:
		for sw in swings:
			if int(sw["id"]) == id:
				(sw["pts"] as Array).append(pos)
				return
	func swing_end(id: int) -> void:
		for sw in swings:
			if int(sw["id"]) == id:
				sw["feeding"] = false
	func spawn_debris(pos: Vector2, n := 7, color := Color("8a7a62")) -> void:
		debris_count += n
	func spawn_crack(pos: Vector2, r: float, color: Color) -> void:
		cracks.append([pos, r])
	func spawn_wave(pos: Vector2, r1: float, dur: float, color: Color, hits: Dictionary, white := false) -> void:
		waves.append({"pos": pos, "r": 26.0, "t": 0.0, "dur": maxf(dur, 0.08), "r1": r1,
			"color": color, "white": white, "hits": hits.duplicate()})
	func spawn_aura(follow: Node2D, life: float, color: Color) -> void:
		auras.append([follow, life])
	func spawn_motes(follow: Node2D, dur: float, color: Color, n := 7) -> void:
		mote_count += 1
	func tick_shots(delta: float) -> void:
		for arr in [shots, rings, beads]:
			for s in (arr as Array).duplicate():
				s["t"] = float(s["t"]) + delta
				var sfrom: Vector2 = s["from"]
				var sto: Vector2 = s["to"]
				var tgt = s.get("target")
				if tgt != null and is_instance_valid(tgt):
					s["to"] = tgt.global_position
					sto = tgt.global_position
				var k: float = clampf(float(s["t"]) / float(s["dur"]), 0.0, 1.0)
				s["pos"] = sfrom.lerp(sto, k)
				if k >= 1.0:
					var cb: Callable = s["on_arrive"]
					arr.erase(s)
					if cb.is_valid():
						cb.call()
	func tick_waves(delta: float) -> void:
		for w in waves.duplicate():
			w["t"] = float(w["t"]) + delta
			var wk: float = clampf(float(w["t"]) / float(w["dur"]), 0.0, 1.0)
			var rr := lerpf(26.0, float(w["r1"]), 1.0 - (1.0 - wk) * (1.0 - wk))
			w["r"] = rr
			var hits: Dictionary = w["hits"]
			for e in hits.keys().duplicate():
				var rec: Dictionary = hits[e]
				if rr >= float(rec["d"]):
					hits.erase(e)
					if is_instance_valid(e):
						var cb: Callable = rec["cb"]
						if cb.is_valid():
							cb.call(e)
			if wk >= 1.0:
				waves.erase(w)
	func spawn_dust(pos: Vector2, r: float, n := 4) -> void:
		dust_count += n
	func spawn_decal(pos: Vector2, r: float, color: Color) -> void:
		decal_count += 1
	func spawn_ground_mark(pos: Vector2, r: float, life: float, color: Color) -> void:
		marks.append([pos, r, life])

## 木桩敌人：真实 take_hit/hp，验证伤害结算时机
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
	# R4：Q 走梵环波——波前抵达登记距离才结算；释放帧瞬间不应有伤害
	_chk(stub.waves.size() > 0, "Q释放帧生成梵环波", str(stub.waves.size()))
	_chk(dummy.hp >= hp0, "波前未到不结算", str(dummy.hp))
	stub.tick_waves(0.02)
	_chk(dummy.hp >= hp0, "波前未到不结算(推进)", str(dummy.hp))
	stub.tick_waves(0.08)
	_chk(dummy.hp < hp0, "波前抵达结算伤害", str(dummy.hp))
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
	_chk(stub.auras.size() == 0, "E护体未释放不展开", str(stub.auras.size()))
	KeyframeLib.play_action(p, "idle", false)
	_chk(float(p.kf_release_t) < 0.0, "打断取消待释放", str(p.kf_release_t))
	# 弹体命中绑定到达
	var shot_flag := [false]
	stub.spawn_skill_shot(Vector2.ZERO, Vector2(100.0, 0.0), 0.10, Color.WHITE, 8.0, func(): shot_flag[0] = true)
	stub.tick_shots(0.05)
	_chk(not shot_flag[0], "弹体未到不结算", "")
	stub.tick_shots(0.06)
	_chk(shot_flag[0], "弹体到达结算", "")
	# ---- R4：唐僧远程平A——世界空间环弹（release 前不存在 / release 生成 / 脱手不跟人 / 到达才伤害） ----
	for arr in [stub.rings, stub.beads]:
		(arr as Array).clear()
	p.atk_cd_left = 0.0
	p.e_cd_left = 99.0
	p.q_cd_left = 99.0
	var rel_atk: float = KeyframeLib.release_time("tang_sanzang", "atk_combo")
	p._auto_attack()
	_chk(str(p.kf_action) == "atk_combo", "平A登记atk_combo", p.kf_action)
	_chk(stub.rings.is_empty(), "平A释放前无弹体", str(stub.rings.size()))
	p.kf_t = rel_atk - 0.02
	p._kf_release_tick()
	_chk(stub.rings.is_empty(), "释放帧前弹体未产生", str(stub.rings.size()))
	p.kf_t = rel_atk
	p._kf_release_tick()
	_chk(stub.rings.size() >= 1, "释放帧生成环弹", str(stub.rings.size()))
	var ring_from: Vector2 = stub.rings[0]["from"]
	_chk(ring_from.distance_to(p.global_position) > 4.0, "环弹从锡杖端生成(非身体中心)", str(ring_from))
	var dummy_hp_pre: float = dummy.hp
	stub.tick_shots(0.02)
	_chk(dummy.hp >= dummy_hp_pre, "环弹未到不结算", str([dummy_hp_pre, dummy.hp]))
	# 脱手：弹体生成后人物位移，弹体 from/弹道不跟随
	var p_pos0: Vector2 = p.global_position
	p.global_position += Vector2(160.0, -60.0)
	stub.tick_shots(2.0)
	_chk(dummy.hp < dummy_hp_pre, "环弹到达结算(人物已位移)", str([dummy_hp_pre, dummy.hp]))
	_chk(stub.rings.is_empty(), "环弹命中后消散", str(stub.rings.size()))
	p.global_position = p_pos0
	# ---- R4：唐僧 G 念珠弹幕（掌心锚点→逐敌追踪，到达结算） ----
	p.g_cd_left = 0.0
	var hp_g0: float = dummy.hp
	p._cast_g()
	_chk(stub.mote_count > 0, "G起手期梵文星点", str(stub.mote_count))
	p.kf_t = KeyframeLib.release_time("tang_sanzang", "unlock_1")
	p._kf_release_tick()
	_chk(stub.beads.size() >= 1, "G释放帧逐敌念珠", str(stub.beads.size()))
	_chk(dummy.hp >= hp_g0, "念珠未到不结算", str(dummy.hp))
	stub.tick_shots(2.0)
	_chk(dummy.hp < hp_g0, "念珠到达结算", str(dummy.hp))
	_chk(stub.beads.is_empty(), "念珠命中后消散", str(stub.beads.size()))
	# ---- R4：唐僧 E 护体光环（释放帧展开） ----
	p.e_cd_left = 0.0
	p._cast_e()
	p.kf_t = KeyframeLib.release_time("tang_sanzang", "core_2")
	p._kf_release_tick()
	_chk(stub.auras.size() >= 1, "E释放帧护体光环", str(stub.auras.size()))
	# ---- R4：whiff 后不冻结（无敌人 Q 打空回落） ----
	dummy.remove_from_group("enemies")
	p.q_cd_left = 0.0
	p._cast_q()
	for i in 150:
		await physics_frame
		if str(p.kf_action) == "":
			break
	_chk(str(p.kf_action) == "", "whiff后动作回落不冻结", p.kf_action)
	_chk(float(p.kf_release_t) < 0.0, "whiff后无悬挂待释放", str(p.kf_release_t))
	# ---- R4：状态切换不锁死（Q→E→dash 快速连打后仍可响应） ----
	dummy.add_to_group("enemies")
	p.q_cd_left = 0.0
	p.e_cd_left = 0.0
	p.dash_cd_left = 0.0
	p._cast_q()
	p._cast_e()
	p._do_dash(Vector2.RIGHT)
	_chk(str(p.kf_action) == "dodge", "连打后仍在响应(dodge)", p.kf_action)
	for i in 200:
		await physics_frame
		if str(p.kf_action) == "":
			break
	_chk(str(p.kf_action) == "", "连打后回idle不锁死", p.kf_action)
	# ---- 悟空 E：起手期落点预告圈（作用区域先示形） ----
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
	# ---- R4：悟空身体锚点轨道（staff_tip 随关键帧变化 / flip 镜像 / 挥击弧采样） ----
	p.main = stub
	var wk_kfs: Array = KeyframeLib._acts["sun_wukong"]["atk_combo"]
	KeyframeLib.play_action(p, "atk_combo", true)
	p.kf_t = 0.198
	KeyframeLib._apply_pose(p, wk_kfs)
	p.sprite.flip_h = false
	KeyframeLib._apply_pose(p, wk_kfs)
	var tip_a: Vector2 = KeyframeLib.body_anchor_world(p, "staff_tip")
	p.kf_t = 0.463
	KeyframeLib._apply_pose(p, wk_kfs)
	var tip_b: Vector2 = KeyframeLib.body_anchor_world(p, "staff_tip")
	_chk(tip_a.distance_to(tip_b) > 20.0, "staff_tip随关键帧变化", str([tip_a, tip_b]))
	p.kf_t = 0.397
	KeyframeLib._apply_pose(p, wk_kfs)
	var tip_r: Vector2 = KeyframeLib.body_anchor_world(p, "staff_tip")
	p.sprite.flip_h = true
	KeyframeLib._apply_pose(p, wk_kfs)
	var tip_l: Vector2 = KeyframeLib.body_anchor_world(p, "staff_tip")
	_chk(absf((tip_r.x - p.global_position.x) + (tip_l.x - p.global_position.x)) < 2.0, "身体锚点flip镜像", str([tip_r, tip_l]))
	p.sprite.flip_h = false
	# 悟空平A：挥击弧登记 + 窗口内采样到真实棍端轨迹
	for sw in stub.swings:
		(sw["pts"] as Array).clear()
	dummy.add_to_group("enemies")
	p.atk_cd_left = 0.0
	p.e_cd_left = 99.0
	p.q_cd_left = 99.0
	p._auto_attack()
	_chk(p.kf_swing_id > 0, "平A登记挥击弧", str(p.kf_swing_id))
	p.kf_t = 0.463
	p._kf_swing_tick()
	p.kf_t = 0.529
	p._kf_swing_tick()
	var sw_pts: Array = []
	for sw in stub.swings:
		if int(sw["id"]) == p.kf_swing_id:
			sw_pts = sw["pts"]
	_chk(sw_pts.size() >= 2, "挥击弧采样≥2点", str(sw_pts.size()))
	if sw_pts.size() >= 2:
		_chk(Vector2(sw_pts[0]).distance_to(Vector2(sw_pts[sw_pts.size() - 1])) > 8.0, "弧点随棍端移动", str(sw_pts))
	# ---- R4：悟空 E 真实砸地（落点=敌人世界坐标，非固定屏幕坐标） ----
	stub.cracks.clear()
	stub.marks.clear()
	dummy.position = p.position + Vector2(150.0, -30.0)
	p.e_cd_left = 0.0
	p._cast_e()
	p.kf_t = KeyframeLib.release_time("sun_wukong", "heavy")
	p._kf_release_tick()
	_chk(stub.cracks.size() >= 1, "E释放帧地裂", str(stub.cracks.size()))
	if stub.cracks.size() >= 1:
		_chk(Vector2(stub.cracks[0][0]).distance_to(dummy.position) < 12.0, "地裂用实际世界坐标", str([stub.cracks[0][0], dummy.position]))
	_chk(stub.debris_count > 0, "E砸地碎石", str(stub.debris_count))
	# 落点随目标移动而变化（非固定屏幕坐标）
	stub.cracks.clear()
	dummy.position = p.position + Vector2(-120.0, 60.0)
	p.e_cd_left = 0.0
	p._cast_e()
	p.kf_t = KeyframeLib.release_time("sun_wukong", "heavy")
	p._kf_release_tick()
	if stub.cracks.size() >= 1:
		_chk(Vector2(stub.cracks[0][0]).distance_to(dummy.position) < 12.0, "地裂跟随新落点", str([stub.cracks[0][0], dummy.position]))
	# ---- R4：悟空 Q 毫毛分身（释放帧分身残影围击） ----
	var ph0: int = stub.phantom_count
	p.q_cd_left = 0.0
	p._cast_q()
	p.kf_t = KeyframeLib.release_time("sun_wukong", "core_1")
	p._kf_release_tick()
	_chk(stub.phantom_count == ph0, "Q释放帧未直接出分身(延迟0.05s)", str([ph0, stub.phantom_count]))
	for i in 30:
		await physics_frame
	_chk(stub.phantom_count > ph0, "Q分身围攻(残影)", str([ph0, stub.phantom_count]))
	# 收尾：回 idle、无悬挂
	dummy.remove_from_group("enemies")
	p.atk_cd_left = 99.0
	p.main = null
	for i in 90:
		await physics_frame
		if str(p.kf_action) == "":
			break
	Input.action_press("move_right")
	for i in 20:
		await physics_frame
	_chk(str(p.kf_action) == "run", "悟空移动run", p.kf_action)
	Input.action_release("move_right")
	print("KF_PROBE fails=%d %s" % [fails.size(), str(fails)])
	quit(0 if fails.is_empty() else 1)
