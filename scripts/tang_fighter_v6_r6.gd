class_name TangFighterV6R6
extends TangFighterV6R5

## R6：法相 / 终结技去除烘焙大技能板。
##
## R4 已经把普通走位、平A、Q/E/G 限制到低污染人物 Pose；
## 但 POSE_31 / POSE_36 本身仍带有大面积佛光、莲瓣、悬空底座，作为法相主体仍然太像“整张技能 PNG”。
## R6 进一步执行 owner 的硬规则：
## - 法相人物本体改用 POSE_30（相对干净的完整站姿）；
## - 法相投影同样使用人物 POSE_30，只做透明度 / 尺寸 / 高度形成，不复制大佛像或莲花板；
## - R 的人物动作只在合掌 POSE_02、POSE_30、持杖 POSE_13 之间收束；
## - 佛光刻度 / 梵音矢仍由 R4/R3 的程序视觉与 world-space projectile 单独构成；
## - 不改伤害、CD、碰撞体、护盾、净化、法相时长与终结规则。

const R6_POSE30_FILE := "tang_sanzang__POSE_30__R5C6.png"
const R6_POSE_ROOT := "res://art/v6_pose/tang_sanzang/"
const R6_POSE_CLEAN_ROOT := "res://art/v6_pose_clean/tang_sanzang/"
const R6_FORM_ECHO_MAX_SCALE := .61

var _r6_pose30_tex: Texture2D

func _r6_pose30() -> Texture2D:
	if _r6_pose30_tex != null:
		return _r6_pose30_tex
	var clean := R6_POSE_CLEAN_ROOT + R6_POSE30_FILE
	var base := R6_POSE_ROOT + R6_POSE30_FILE
	if ResourceLoader.exists(clean):
		_r6_pose30_tex = load(clean)
	elif ResourceLoader.exists(base):
		_r6_pose30_tex = load(base)
	return _r6_pose30_tex

# R4 的可视 Pose 查询仍是唯一人物时间轴；R6 只替换 form / R 两种语义的图片选择。
func _r4_pose_for(mode: String, p: float) -> int:
	if mode == "form":
		return 30
	if mode == "r":
		# 合掌收势 → 人形法身展开 → 合掌 → 持杖回位。
		if p < .16:
			return 2
		if p < .74:
			return 30
		if p < .90:
			return 2
		return 13
	return super(mode, p)

# 让 R4 的通用加载器认识 POSE_30；其他 Pose 仍走 R4 白名单。
func _r4_pose_tex(pose_id: int) -> Texture2D:
	if pose_id == 30:
		return _r6_pose30()
	return super(pose_id)

# POSE_30 的掌心点跟随实际可见 Sprite 的 scale/rotation/flip。
# 这里只声明该人物图片内部的手部坐标，不是 player.position 固定偏移。
func _r4_palm_local() -> Vector2:
	if _r4_pose_id != 30:
		return super()
	if kf_sprite == null:
		return Vector2.ZERO
	var uv := Vector2(.63, .57)
	var p := (uv - Vector2(.5, .5)) * 256.0
	if kf_sprite.flip_h:
		p.x = -p.x
	p = Vector2(p.x * kf_sprite.scale.x, p.y * kf_sprite.scale.y)
	p = p.rotated(kf_sprite.rotation)
	return kf_sprite.position + p

# 法相主体 = 同一个人物的低透明放大投影。
# 不再使用带完整佛光/莲花底座的 POSE_31 / 36。
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
	var tex := _r6_pose30()
	if tex == null:
		_form_echo.visible = false
		return
	var eased := _form_birth * _form_birth * (3.0 - 2.0 * _form_birth)
	_form_echo.texture = tex
	_form_echo.flip_h = sprite.flip_h
	_form_echo.position = Vector2(0, lerpf(-5.0, -18.0, eased))
	_form_echo.rotation = 0.0
	_form_echo.scale = Vector2.ONE * lerpf(.23, R6_FORM_ECHO_MAX_SCALE, eased)
	_form_echo.modulate = Color(1.0, .90, .56, lerpf(.025, .18, eased))
	_form_echo.visible = true
