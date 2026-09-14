class_name TangFighterV6R7
extends TangFighterV6R6

## R7：把现有 POSE_24 真正变成“干净释放关键帧”，不再用站姿硬切假装施法。
##
## 原 POSE_24 的人物动作本身非常合适：左手持杖、右掌明确前推；问题是 PNG 内烘焙了巨大月牙/烟云。
## R7 不重画角色，也不修改平衡，而是在运行时：
## - 读取仓库已有 POSE_24 原图；
## - 读取 data/tang_pose24_r7_mask_png.b64 的 256x256 清理遮罩；
## - 只保留人物/锡杖/前推手臂，去掉大月牙、烟云与大块底部光效；
## - 将清理后的 POSE_24 作为 normal/Q/G/R 的 Release 关键帧；
## - projectile source 绑定该画面真实前推右掌，而不是固定 player.position 偏移；
## - R6 法相仍使用干净 POSE_13 人物投影；R5 Contact-only feedback 与 R3 world-space projectile 保持不变。

const R7_POSE24_FILE := "tang_sanzang__POSE_24__R4C6.png"
const R7_MASK_PATH := "res://data/tang_pose24_r7_mask_png.b64"
const R7_PALM_UV := Vector2(.735, .535)

var _r7_cast_tex: Texture2D
var _r7_cast_load_failed := false

func _ready() -> void:
	super()
	# 预热一次，避免第一次平A/技能释放时解码 PNG 产生视觉卡顿。
	_r7_cast_texture()

func _r7_cast_texture() -> Texture2D:
	if _r7_cast_tex != null:
		return _r7_cast_tex
	if _r7_cast_load_failed:
		return null

	var source_path := POSE_ROOT + R7_POSE24_FILE
	if not ResourceLoader.exists(source_path) or not FileAccess.file_exists(R7_MASK_PATH):
		_r7_cast_load_failed = true
		push_error("Tang R7 missing POSE24 source or cleanup mask")
		return null
	var source_tex: Texture2D = load(source_path)
	if source_tex == null:
		_r7_cast_load_failed = true
		return null
	var base_img := source_tex.get_image()
	if base_img == null or base_img.is_empty():
		_r7_cast_load_failed = true
		return null
	base_img.convert(Image.FORMAT_RGBA8)

	var b64 := FileAccess.get_file_as_string(R7_MASK_PATH).strip_edges()
	var bytes := Marshalls.base64_to_raw(b64)
	var mask_img := Image.new()
	var err := mask_img.load_png_from_buffer(bytes)
	if err != OK:
		_r7_cast_load_failed = true
		push_error("Tang R7 cleanup mask decode failed: %s" % err)
		return null
	mask_img.convert(Image.FORMAT_L8)
	if mask_img.get_width() != base_img.get_width() or mask_img.get_height() != base_img.get_height():
		_r7_cast_load_failed = true
		push_error("Tang R7 cleanup mask size mismatch")
		return null

	# 只做 alpha 清理，RGB 仍完全来自仓库原 POSE_24；不二次生成角色颜色/轮廓。
	for y in base_img.get_height():
		for x in base_img.get_width():
			var c := base_img.get_pixel(x, y)
			c.a *= mask_img.get_pixel(x, y).r
			base_img.set_pixel(x, y, c)
	_r7_cast_tex = ImageTexture.create_from_image(base_img)
	return _r7_cast_tex

# ====================== 更像“真的在施法”的人物动作剧本 ======================
func _r4_pose_for(mode: String, p: float) -> int:
	match mode:
		"normal":
			# 持杖定身 → 合掌聚咒 → 右掌前推 Release → 合掌 → 回位。
			if p < .16: return 13
			if p < .34: return 2
			if p < .72: return 24
			if p < .88: return 2
			return 13
		"q":
			# 合掌聚印 → 右掌把八角镇压印推出 → 收掌。
			if p < .20: return 2
			if p < .72: return 24
			if p < .90: return 2
			return 13
		"g":
			# 念咒蓄势 → 前推掌保持 Release 姿势供念珠分拍脱手 → 回位。
			if p < .20: return 2
			if p < .76: return 24
			if p < .92: return 2
			return 13
		"r":
			# 法相中：合掌聚势 → 右掌前推铺开梵音矢 → 合掌收束 → 持杖回位。
			if p < .16: return 2
			if p < .74: return 24
			if p < .90: return 2
			return 13
		_:
			return super(mode, p)

func _r4_pose_tex(pose_id: int) -> Texture2D:
	if pose_id == 24:
		var cleaned := _r7_cast_texture()
		if cleaned != null:
			return cleaned
		# 若遮罩异常，绝不回退到带巨大月牙的原 POSE_24；退回干净合掌帧。
		return super(2)
	return super(pose_id)

func _r4_palm_local() -> Vector2:
	if _r4_pose_id != 24:
		return super()
	if kf_sprite == null:
		return Vector2.ZERO
	var p := (R7_PALM_UV - Vector2(.5, .5)) * 256.0
	if kf_sprite.flip_h:
		p.x = -p.x
	p = Vector2(p.x * kf_sprite.scale.x, p.y * kf_sprite.scale.y)
	p = p.rotated(kf_sprite.rotation)
	return kf_sprite.position + p
