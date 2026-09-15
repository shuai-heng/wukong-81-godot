class_name TangFighterV6R9
extends "res://scripts/tang_fighter_v6_r8.gd"

## R9：战斗读形与法相对齐层（visual-only）。
## R8 保证 release → visible pose → palm → world-space projectile。
## R9 只增强人物读形、平A Release 可读时间和法相朝向，不改战斗数值。

const R9_CHARACTER_SCALE := 1.10
const R9_NORMAL_RELEASE_PRE := .035
const R9_NORMAL_RELEASE_POST := .180
const R9_FORM_ECHO_START_SCALE := .27
const R9_FORM_ECHO_END_SCALE := .72

func _r4_pose_for(mode: String, p: float) -> int:
	if mode == "normal":
		var d := _r8_release_delta(mode)
		if d < R8_NO_RELEASE * .5:
			if d < -.22:
				return 13
			if d < -.085:
				return 2
			if d < -R9_NORMAL_RELEASE_PRE:
				return 3
			if d <= R9_NORMAL_RELEASE_POST:
				return 24
			if d < .29:
				return 3
			if d < .41:
				return 2
			return 13
	return super(mode, p)

func _apply_r4_visual(dt: float) -> void:
	super(dt)
	if hero != "tang" or kf_sprite == null or not kf_sprite.visible:
		return
	kf_sprite.scale *= R9_CHARACTER_SCALE

func _sync_form_echo(dt: float) -> void:
	super(dt)
	if hero != "tang" or form_left <= 0.0 or _form_echo == null or not _form_echo.visible:
		return
	var eased := _form_birth * _form_birth * (3.0 - 2.0 * _form_birth)
	if kf_sprite != null and kf_sprite.visible:
		_form_echo.flip_h = kf_sprite.flip_h
		_form_echo.position.x = kf_sprite.position.x
	_form_echo.position.y = lerpf(-6.0, -22.0, eased)
	_form_echo.scale = Vector2.ONE * lerpf(R9_FORM_ECHO_START_SCALE, R9_FORM_ECHO_END_SCALE, eased)
	_form_echo.modulate = Color(1.0, .90, .56, lerpf(.02, .18, eased))
	_form_echo.z_index = 0
