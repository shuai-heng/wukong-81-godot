class_name TangFighterV6R5
extends TangFighterV6R4

## R5：Contact-only feedback。
## R4 已经解决人物 Pose 污染与真实 palm 锚点；R5 只处理最后一层旧动作元数据泄漏：
## - V6.1 旧关键帧里的 hitstop/camera_shake 属于旧近战/旧演出语义，唐僧不再采用；
## - 平A/Q/G/R 的顿帧与震屏只能由 TangSpellProjectileV6 在真实 Contact -> Impact 后触发；
## - G/R 多弹幕仍可短暂“持施法姿势”，但只冻结人物 Pose 时钟，不冻结移动/碰撞/输入；
## - 不改伤害、CD、护盾、净化、Boss 终结伤害上限等任何平衡数值。

var _r5_release_hold_left := 0.0

func _hold_release_pose(seconds: float) -> void:
	# 覆盖 R3 的同名实现：不把“持势”混进 KeyframeLib 的旧 metadata freeze。
	# R5 自己持有这一段视觉时间；技能已经 release 的 projectile 仍是 world-space。
	var hold := maxf(0.0, seconds)
	_r5_release_hold_left = maxf(_r5_release_hold_left, hold)
	_chant_left = maxf(_chant_left, hold)

func tick(dt: float, input_enabled: bool=true) -> void:
	# 保存进入 player tick 前的真实世界反馈。若上一物理阶段 projectile 已 Contact，
	# 这些值就是合法反馈，必须保留；这里只撤销本次人物关键帧 metadata 新增的部分。
	var hitstop_before := 0.0
	var shake_before := 0.0
	if game != null:
		hitstop_before = float(game.hitstop)
		shake_before = float(game.shake)

	# 只有 R5 显式 release-hold 才允许冻结人物姿势。
	# 旧关键帧 metadata 上一帧遗留的 kf_freeze_left 不得继续带入。
	if _r5_release_hold_left > 0.0:
		kf_freeze_left = _r5_release_hold_left
	else:
		kf_freeze_left = 0.0

	super(dt, input_enabled)

	# KeyframeLib._fire_meta() 可能根据旧 V6.1 hitstop_ms/camera_shake 在人物动作帧上写反馈。
	# 唐僧 R5 的伤害已经是 projectile Contact 模型，因此人物帧新增的反馈全部撤销。
	# 真正 projectile Contact 若发生在本 tick 之前，其值已包含在 *_before 中，不会被抹掉；
	# 若发生在本 tick 之后，则由 TangSpellProjectileV6._apply_feedback() 正常写入。
	if game != null:
		if float(game.hitstop) > hitstop_before:
			game.hitstop = hitstop_before
		if float(game.shake) > shake_before:
			game.shake = shake_before

	# 同理，旧 metadata 写入的 kf_freeze_left 不保留；只保留本角色明确声明的 release hold。
	if _r5_release_hold_left > 0.0:
		_r5_release_hold_left = maxf(0.0, _r5_release_hold_left - dt)
	kf_freeze_left = _r5_release_hold_left
