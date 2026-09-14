class_name TangFighterV6R8
extends TangFighterV6R7

## R8：Release 短窗口。
##
## R7 已经把现有 POSE_24 清理成人物-only 的右掌前推关键帧；
## R8 解决最后一个“僵住像贴图”的问题：POSE_24 不再占据 normal/Q/G/R 的大半段时间，
## 而只在真正的 KeyframeLib release 附近出现。
##
## 硬规则：
## - 仍与技能共用 KeyframeLib.kf_t / kf_release_t；不建立独立动作时钟；
## - normal/Q：POSE_24 只覆盖 release 前后约百毫秒；
## - G/R：只有实际多弹 release cadence 持续期间才允许保持 POSE_24；
## - release 前后用 POSE_02 / POSE_03 / POSE_13 接动作，形成聚势→前推→回收；
## - 真正 release 的执行顺序固定为：锁定 release 时刻 → 切到可见 POSE24 → 取 palm → 生成 projectile；
## - projectile 仍由 R4/R3 从当前可见 Pose 的 palm 脱手并进入 world-space；
## - E 初次展开与持续 tick 的视觉反馈都只在真实受伤目标位置出现；
## - 不改伤害、CD、护盾、净化、法相、终结数值。

const R8_NO_RELEASE := 999.0

var _r8_last_release_action := ""
var _r8_last_release_mode := ""
var _r8_last_release_kf_t := -999.0

# 不调用父级实现：父级会先 kf_cancel_release() 再 cb.call()，那样回调中的 _r4_palm_world()
# 可能看到 release 信息已经被清空。R8 必须先锁定 release，再强制视觉同步到 POSE24，最后才发弹。
func _kf_release_tick() -> void:
	if kf_release_t < 0.0:
		return
	if String(kf_action) != String(kf_cast_action):
		kf_cancel_release()
		return
	if kf_t >= kf_release_t:
		var cb := kf_release_cb
		var release_at := kf_release_t
		var action_before := String(kf_action)
		var mode_before := _r4_mode
		# 先写入统一时钟上的 release 位置。
		_r8_last_release_action = action_before
		_r8_last_release_mode = mode_before
		_r8_last_release_kf_t = release_at
		# 再清理 armed callback，避免重复触发。
		kf_cancel_release()
		# 此刻 _r8_release_delta()==0，因此 normal/Q/G/R 都会得到清理后的 POSE24。
		# 先把人物同步到真实 Release Pose，随后 cb 里的 _spawn_spell() 再读取 palm。
		if hero == "tang" and kf_sprite != null:
			_apply_r4_visual(0.0)
		if cb.is_valid():
			cb.call()
	else:
		KeyframeLib.update_charge(self, kf_t / maxf(kf_release_t, .001))
		if kf_orb != null and kf_orb.visible:
			kf_orb.global_position = _r4_palm_world()

func kf_cancel_release() -> void:
	# 取消/切人时不能把上一次技能的 Release 窗口带进下一动作。
	if kf_release_t >= 0.0 and String(kf_action) != String(kf_cast_action):
		_r8_last_release_action = ""
		_r8_last_release_mode = ""
		_r8_last_release_kf_t = -999.0
	super()

func set_hero(h: String) -> void:
	super(h)
	if h != "tang":
		_r8_last_release_action = ""
		_r8_last_release_mode = ""
		_r8_last_release_kf_t = -999.0

func _r8_release_delta(mode: String) -> float:
	if mode not in ["normal", "q", "g", "r"]:
		return R8_NO_RELEASE
	# release 尚未发生：直接使用当前 action 的真实 kf_release_t。
	if kf_release_t >= 0.0 and String(kf_cast_action) == String(kf_action):
		return kf_t - kf_release_t
	# release 已发生：继续沿同一个 kf_t 计算 recovery。
	if _r8_last_release_mode == mode and _r8_last_release_action == String(kf_action):
		return kf_t - _r8_last_release_kf_t
	return R8_NO_RELEASE

func _r4_pose_for(mode: String, p: float) -> int:
	var d := _r8_release_delta(mode)
	match mode:
		"normal":
			if d < R8_NO_RELEASE * .5:
				if d < -.20: return 13
				if d < -.07: return 2
				if d < -.018: return 3
				if d <= .115: return 24
				if d < .22: return 3
				if d < .34: return 2
				return 13
			# 安全回退也不长时间停 POSE24。
			if p < .26: return 13
			if p < .43: return 2
			if p < .58: return 3
			if p < .70: return 24
			if p < .82: return 3
			if p < .91: return 2
			return 13
		"q":
			if d < R8_NO_RELEASE * .5:
				if d < -.26: return 2
				if d < -.07: return 3
				if d <= .16: return 24
				if d < .30: return 3
				if d < .44: return 2
				return 13
			if p < .28: return 2
			if p < .46: return 3
			if p < .63: return 24
			if p < .78: return 3
			if p < .91: return 2
			return 13
		"g", "r":
			# 多弹幕真正 release cadence 期间才保持前推掌。
			if _r5_release_hold_left > .001:
				return 24
			if d < R8_NO_RELEASE * .5:
				if d < -.30: return 2
				if d < -.08: return 3
				if d < 0.0: return 24
				# cadence 已结束则立刻开始 recovery，不能又停在 POSE24。
				if d < .15: return 3
				if d < .31: return 2
				return 13
			if p < .25: return 2
			if p < .44: return 3
			if p < .58: return 24
			if p < .76: return 3
			if p < .90: return 2
			return 13
		_:
			return super(mode, p)

func _apply_r4_visual(dt: float) -> void:
	super(dt)
	if hero != "tang" or kf_sprite == null or not kf_sprite.visible:
		return
	# Release 帧只有轻微身体前送，不做整图拉伸/夸张缩放；动作主体仍是 POSE24 的真实手臂。
	if _r4_pose_id == 24:
		var sign_x := -1.0 if kf_sprite.flip_h else 1.0
		kf_sprite.position.x += 2.4 * sign_x
		kf_sprite.position.y -= .8
		kf_sprite.rotation += deg_to_rad(-.8) * sign_x

func _r8_target_contact(at: Vector2, dir: Vector2) -> void:
	if game == null or not is_instance_valid(game):
		return
	var fx := TangImpactV6.new()
	game.add_child(fx)
	fx.configure(at, "ward_tick", 12.0, HeroIdentity.primary("tang"), HeroIdentity.secondary("tang"), dir)

# E 保留原数值，但初次展开的每个真实受伤目标也得到一个小型 Contact 反馈。
# 持续 0.5s tick 的后续 Contact 由 TangWardV6 自己在目标位置生成。
func _release_e() -> void:
	shield = 3.0
	var ward := TangWardV6.new()
	game.add_child(ward)
	ward.configure(game, self, 3.0, 105.0, 4.0)
	_spawn_tang_impact(global_position, "robe", 170.0)
	var hits := 0
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		var off := e.global_position - global_position
		if off.length() > 190.0:
			continue
		var dir := off.normalized() if off.length_squared() > .01 else facing
		var force := dir * 200.0
		if tang_spell_hit(e, damage() * .4, force, false):
			hits += 1
			_r8_target_contact(e.global_position, dir)
	if hits > 0:
		on_hit()
