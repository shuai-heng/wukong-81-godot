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
## - projectile 仍由 R4/R3 从当前可见 Pose 的 palm 脱手并进入 world-space；
## - 不改伤害、CD、护盾、净化、法相、终结数值。

const R8_NO_RELEASE := 999.0

var _r8_last_release_action := ""
var _r8_last_release_mode := ""
var _r8_last_release_kf_t := -999.0

# TangFighterV6.tick() 会动态调用本方法；这里在真正 release 回调执行的同一 tick
# 记录 release 在统一 kf_t 上的位置，供人物 Pose 在释放后的 recovery 阶段继续对齐。
func _kf_release_tick() -> void:
	var armed := kf_release_t >= 0.0
	var release_at := kf_release_t
	var cast_action := String(kf_cast_action)
	var action_before := String(kf_action)
	var mode_before := _r4_mode
	var t_before := kf_t
	super()
	if armed and release_at >= 0.0 and action_before == cast_action and t_before + .0001 >= release_at:
		_r8_last_release_action = action_before
		_r8_last_release_mode = mode_before
		_r8_last_release_kf_t = release_at

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
