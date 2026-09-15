class_name TangFighterV6R9
extends TangFighterV6R8

## R9：战斗读形与法相对齐层（visual-only）。
##
## R8 已保证真正 Release 的顺序是：锁定 release → 可见 POSE24 → palm → world-space projectile。
## R9 不改任何战斗数值，只收三个视觉问题：
## - 平A atk_combo 在 KeyframeLib 中是 2x 速度，R8 的 POSE24 窗口实际只有约 60–70ms，肉眼容易像闪帧；
##   R9 把 normal Release 可读窗口扩到约 100ms 量级，同时仍然只围绕真实 kf_release_t。
## - 唐僧 V6 人物在完整游戏 960×540/1440×810 画面里偏小；R9 统一放大 10%，碰撞体完全不变，
##   palm 会随当前可见 Sprite2D scale 同步变化，因此不会产生固定偏移假锚点。
## - 法相投影严格跟当前 KFSprite 的 flip，逐渐从人物背后升起并放大；不加载 POSE30–36，
##   不把整张旧佛像/莲花技能图叠回人物。

const R9_CHARACTER_SCALE := 1.10
const R9_NORMAL_RELEASE_PRE := .035
const R9_NORMAL_RELEASE_POST := .180
const R9_FORM_ECHO_START_SCALE := .27
const R9_FORM_ECHO_END_SCALE := .72

func _r4_pose_for(mode: String, p: float) -> int:
	if mode == "normal":
		var d := _r8_release_delta(mode)
		if d < R8_NO_RELEASE * .5:
			# atk_combo 2x：这里的 action-time 会折半为 wall-time。
			# 13 持杖 → 2 合掌 → 3 袖手前引 → 24 右掌前推 Release → 3 → 2 → 13。
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
	# 每次 super() 都会从 R4 基准 scale 重建，因此这里不会逐帧累计。
	# 只提升人物读形，不改 Node2D/player 的碰撞与世界位置。
	kf_sprite.scale *= R9_CHARACTER_SCALE

func _sync_form_echo(dt: float) -> void:
	super(dt)
	if hero != "tang" or form_left <= 0.0 or _form_echo == null or not _form_echo.visible:
		return
	var eased := _form_birth * _form_birth * (3.0 - 2.0 * _form_birth)
	# 方向必须和当前真正显示的 KFSprite 一致，而不是依赖隐藏的旧 sprite。
	if kf_sprite != null and kf_sprite.visible:
		_form_echo.flip_h = kf_sprite.flip_h
		_form_echo.position.x = kf_sprite.position.x
	_form_echo.position.y = lerpf(-6.0, -22.0, eased)
	_form_echo.scale = Vector2.ONE * lerpf(R9_FORM_ECHO_START_SCALE, R9_FORM_ECHO_END_SCALE, eased)
	_form_echo.modulate = Color(1.0, .90, .56, lerpf(.02, .18, eased))
	_form_echo.z_index = 0
