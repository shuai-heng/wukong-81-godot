class_name TangFighterV6R6
extends "res://scripts/tang_fighter_v6_r5.gd"

## R6：法相 / 终结技彻底去除烘焙大技能板，并消除整个人物 crossfade 重影。
##
## R4 已经把普通走位、平A、Q/E/G 限制到低污染人物 Pose；
## 视觉复核后确认 POSE_30 仍带少量莲瓣/底部佛光，因此也不作为最终法相人物。
## R6 进一步执行 owner 的硬规则：
## - 法相人物本体改用完全干净的 POSE_13 持杖人形；
## - 法相投影仍是同一个 POSE_13 人物，只做透明度 / 尺寸 / 高度形成；
## - R 人物动作只用 POSE_02 合掌、POSE_03 袖手前送、POSE_13 持杖收势；
## - POSE_30–36 全部退出 Tang 最终 form / R 人物层，不再把莲花、佛像、光柱、大法阵烘焙进人物；
## - 普通人物 Pose 切换不再叠一张旧人物做 crossfade，避免双人/半身重影；
## - 佛光刻度 / 梵音矢仍由程序视觉与 world-space projectile 单独构成；
## - 不改伤害、CD、碰撞体、护盾、净化、法相时长与终结规则。

const R6_FORM_ECHO_MAX_SCALE := .62

# R4 的可视 Pose 查询仍是唯一人物时间轴；R6 只替换 form / R 两种语义的图片选择。
func _r4_pose_for(mode: String, p: float) -> int:
	if mode == "form":
		return 13
	if mode == "r":
		# 合掌聚势 → 袖手前送梵音 → 持杖收势。
		if p < .18:
			return 2
		if p < .72:
			return 3
		if p < .90:
			return 2
		return 13
	return super(mode, p)

# 像素角色使用明确关键帧切换；不把上一张完整人物叠在新人物上做 55ms ghost fade。
# 身体 root 的 offset/rotation/scale 仍由 R4 连续计算，因此只是去掉整图重影，不是冻结动作。
func _snapshot_r4_fade() -> void:
	if _r4_fade != null:
		_r4_fade.visible = false
	_r4_fade_left = 0.0

# 法相主体 = 完全干净的 POSE_13 人物低透明放大投影。
# 变化感由形成过程和程序 VFX 提供，而不是换一张带巨大莲花/佛像的技能插画。
func _sync_form_echo(dt: float) -> void:
	var now := hero == "tang" and form_left > 0.0
	if now and not _was_form:
		_form_birth = 0.0
	if not now:
		if _form_echo != null:
			_form_echo.visible = false
		_was_form = false
		return
	_was_form = true
	_form_birth = minf(1.0, _form_birth + dt / .64)
	if _form_echo == null:
		return
	var tex := _r4_pose_tex(13)
	if tex == null:
		_form_echo.visible = false
		return
	var eased := _form_birth * _form_birth * (3.0 - 2.0 * _form_birth)
	_form_echo.texture = tex
	_form_echo.flip_h = sprite.flip_h
	_form_echo.position = Vector2(0, lerpf(-5.0, -19.0, eased))
	_form_echo.rotation = 0.0
	_form_echo.scale = Vector2.ONE * lerpf(.23, R6_FORM_ECHO_MAX_SCALE, eased)
	_form_echo.modulate = Color(1.0, .90, .56, lerpf(.025, .19, eased))
	_form_echo.visible = true
