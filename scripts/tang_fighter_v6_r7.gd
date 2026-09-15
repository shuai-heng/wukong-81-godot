class_name TangFighterV6R7
extends "res://scripts/tang_fighter_v6_r6.gd"

## R7：干净释放关键帧。
##
## 原 POSE_24 含烘焙月牙/烟云，而且曾出现损坏 PNG，不能继续进入正式运行时。
## 当前 Release 只复用仓库内已经通过导入的 POSE_03（袖手前引）人物本体；
## 技能法印、projectile、impact 全部由独立 VFX/world-space 对象生成。
## 这保证人物 PNG 本身不再携带巨大技能插画，同时保持统一 kf_t / release 时钟。

const R7_CAST_PATH := "res://art/v6_pose/tang_sanzang/tang_sanzang__POSE_03__R1C3.png"
# 这是 POSE_03 的人物局部掌心锚点比例；flip/scale/rotation 会在 _r4_palm_local 中同步。
const R7_PALM_UV := Vector2(.655, .505)

var _r7_cast_tex: Texture2D
var _r7_cast_load_failed := false

func _ready() -> void:
	super()
	_r7_cast_texture()

func _r7_cast_texture() -> Texture2D:
	if _r7_cast_tex != null:
		return _r7_cast_tex
	if _r7_cast_load_failed:
		return null
	if not ResourceLoader.exists(R7_CAST_PATH):
		_r7_cast_load_failed = true
		push_error("Tang R7 cast pose missing: " + R7_CAST_PATH)
		return null
	_r7_cast_tex = load(R7_CAST_PATH)
	if _r7_cast_tex == null:
		_r7_cast_load_failed = true
		push_error("Tang R7 cast pose failed to load")
	return _r7_cast_tex

func _r4_pose_for(mode: String, p: float) -> int:
	match mode:
		"normal":
			if p < .16: return 13
			if p < .34: return 2
			if p < .72: return 24
			if p < .88: return 2
			return 13
		"q":
			if p < .20: return 2
			if p < .72: return 24
			if p < .90: return 2
			return 13
		"g":
			if p < .20: return 2
			if p < .76: return 24
			if p < .92: return 2
			return 13
		"r":
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
		return super(3)
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
