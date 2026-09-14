extends Node2D
## M2-R5 · Tang/Wukong vertical-slice visual choreography rig.
## VISUAL ONLY: no damage/CD/invulnerability/balance changes.
## It reads the player's existing V6.1 kf_action/kf_t clock and body anchors.
## No second skill clock is created.

const SUPPORTED_HEROES := ["tang", "wukong"]
const TANG_SEAL_MAX_R := 10.0
const FORM_BUILD_TIME := 0.55
const FORM_FADE_TIME := 0.24

var player: CharacterBody2D
var main: Node2D
var form_echo: Sprite2D

var _hero := ""
var _form_was_on := false
var _form_age := 0.0
var _form_alpha := 0.0
var _form_center := Vector2.ZERO
var _seal_alpha := 0.0
var _seal_pos := Vector2.ZERO
var _seal_r := 0.0
var _move_alpha := 0.0
var _move_pos := Vector2.ZERO
var _move_dir := Vector2.RIGHT

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	if player == null:
		set_process(false)
		return
	main = player.get("main") as Node2D
	form_echo = Sprite2D.new()
	form_echo.name = "FormEcho"
	form_echo.visible = false
	form_echo.z_index = -3
	form_echo.centered = true
	add_child(form_echo)
	z_index = 3

func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	_hero = String(player.get("hero"))
	if not SUPPORTED_HEROES.has(_hero):
		_reset_visuals(delta)
		return
	main = player.get("main") as Node2D
	_tick_form(delta)
	_tick_cast_seal(delta)
	_tick_movement(delta)
	_rebind_tang_ring_shots_to_palm()
	queue_redraw()

func _reset_visuals(delta: float) -> void:
	_form_alpha = maxf(0.0, _form_alpha - delta / FORM_FADE_TIME)
	_seal_alpha = 0.0
	_move_alpha = 0.0
	if form_echo != null:
		form_echo.visible = false
	queue_redraw()

func _kf_sprite() -> Sprite2D:
	return player.get("kf_sprite") as Sprite2D

func _tick_form(delta: float) -> void:
	var form_on := float(player.get("form_left")) > 0.0
	_form_center = to_local(KeyframeLib.body_anchor_world(player, "body_center"))
	if form_on and not _form_was_on:
		_form_age = 0.0
		if main != null and main.has_method("request_shake"):
			main.call("request_shake", 1.6 if _hero == "tang" else 3.2)
		if _hero == "tang" and main != null and main.has_method("spawn_motes"):
			main.call("spawn_motes", player, 0.8, HeroIdentity.primary(_hero), 7)
	_form_was_on = form_on

	if form_on:
		_form_age += delta
		_form_alpha = minf(1.0, _form_alpha + delta / FORM_BUILD_TIME)
	else:
		_form_alpha = maxf(0.0, _form_alpha - delta / FORM_FADE_TIME)

	var kfs := _kf_sprite()
	if form_echo == null or kfs == null or kfs.texture == null or _form_alpha <= 0.001:
		if form_echo != null:
			form_echo.visible = false
		return

	# 法相投影使用当前 V6.1 姿势，不引入额外角色/佛像插画。
	form_echo.texture = kfs.texture
	form_echo.position = kfs.position
	form_echo.rotation = kfs.rotation
	form_echo.flip_h = kfs.flip_h
	var build := smoothstep(0.0, 1.0, minf(1.0, _form_age / FORM_BUILD_TIME))
	var target_scale := 1.72 if _hero == "tang" else 2.10
	form_echo.scale = kfs.scale * lerpf(1.08, target_scale, build)
	var col := HeroIdentity.primary(_hero)
	var pulse := 0.88 + 0.12 * sin(Time.get_ticks_msec() * 0.008)
	form_echo.modulate = Color(col.r, col.g, col.b, (0.18 if _hero == "tang" else 0.22) * _form_alpha * pulse)
	form_echo.visible = true

func _tick_cast_seal(delta: float) -> void:
	_seal_alpha = maxf(0.0, _seal_alpha - delta * 7.5)
	if _hero != "tang":
		return
	var action := String(player.get("kf_action"))
	var slug := String(player.get("kf_slug"))
	if action != "atk_combo" or slug == "" or not KeyframeLib.has_action(slug, action):
		return
	var release := KeyframeLib.release_time(slug, action)
	var t := float(player.get("kf_t"))
	var palm_world := KeyframeLib.body_anchor_world(player, "palm")
	_seal_pos = to_local(palm_world)
	# 同一 kf_t 时间轴：释放前形成，释放后快速衰减。
	var pre := clampf(1.0 - maxf(release - t, 0.0) / maxf(release * 0.72, 0.08), 0.0, 1.0)
	if t <= release + 0.12:
		_seal_alpha = maxf(_seal_alpha, (0.35 + 0.65 * pre) * clampf(1.0 - maxf(t - release, 0.0) / 0.12, 0.0, 1.0))
		_seal_r = lerpf(4.0, TANG_SEAL_MAX_R, pre)

func _tick_movement(delta: float) -> void:
	var vel: Vector2 = player.velocity
	if vel.length() < 24.0:
		_move_alpha = maxf(0.0, _move_alpha - delta * 7.0)
		return
	var slug := String(player.get("kf_slug"))
	var action := String(player.get("kf_action"))
	if slug == "" or action == "":
		return
	_move_alpha = minf(1.0, _move_alpha + delta * 5.0)
	_move_dir = vel.normalized()
	# 移动表现绑定当前姿势真实 body_center，而非 player.position + 固定偏移。
	_move_pos = to_local(KeyframeLib.body_anchor_world(player, "body_center"))

func _rebind_tang_ring_shots_to_palm() -> void:
	if _hero != "tang" or main == null:
		return
	var shots_v = main.get("fx_shots")
	if not (shots_v is Array):
		return
	var shots: Array = shots_v
	var changed := false
	for i in range(shots.size()):
		if not (shots[i] is Dictionary):
			continue
		var shot: Dictionary = shots[i]
		if String(shot.get("kind", "")) != "ring" or bool(shot.get("_m2r5_anchor_bound", false)):
			continue
		# 唐僧普通弹幕真正从当前 V6.1 palm 世界坐标脱手；之后仍由 main 的 world-space shot 自己飞行。
		var palm_world := KeyframeLib.body_anchor_world(player, "palm")
		shot["from"] = palm_world
		shot["pos"] = palm_world
		shot["_m2r5_anchor_bound"] = true
		shots[i] = shot
		changed = true
	if changed:
		main.set("fx_shots", shots)

func _draw() -> void:
	if not SUPPORTED_HEROES.has(_hero):
		return
	var primary := HeroIdentity.primary(_hero)
	var secondary := HeroIdentity.secondary(_hero)

	# 唐僧平A：掌前小型法印。尺寸刻意克制，VFX 只强化动作，不取代动作。
	if _hero == "tang" and _seal_alpha > 0.01:
		var c1 := Color(primary.r, primary.g, primary.b, 0.78 * _seal_alpha)
		var c2 := Color(secondary.r, secondary.g, secondary.b, 0.62 * _seal_alpha)
		draw_arc(_seal_pos, _seal_r, 0.0, TAU, 20, c1, 1.4)
		draw_arc(_seal_pos, _seal_r * 0.62, -0.35, TAU - 0.35, 16, c2, 1.0)
		for i in 6:
			var a := TAU * float(i) / 6.0 + float(player.get("kf_t")) * 1.7
			var p0 := _seal_pos + Vector2.from_angle(a) * (_seal_r * 0.72)
			var p1 := _seal_pos + Vector2.from_angle(a) * (_seal_r * 1.05)
			draw_line(p0, p1, c2, 1.0)

	# 走位只给少量方向性动势线；一远一近长度/重量不同，不做模板换色。
	if _move_alpha > 0.01:
		var side := _move_dir.orthogonal()
		var len := 7.0 if _hero == "tang" else 12.0
		var spread := 5.0 if _hero == "tang" else 7.0
		var mc := Color(secondary.r, secondary.g, secondary.b, (0.18 if _hero == "tang" else 0.28) * _move_alpha)
		for s in [-1.0, 1.0]:
			var start := _move_pos + side * spread * s
			draw_line(start, start - _move_dir * len, mc, 1.2)

	# 法相几何层：跟真实 body_center 锚点；只是形成/强化视觉，不改碰撞。
	if _form_alpha > 0.01:
		var fc := Color(primary.r, primary.g, primary.b, 0.34 * _form_alpha)
		var sc := Color(secondary.r, secondary.g, secondary.b, 0.26 * _form_alpha)
		var t := Time.get_ticks_msec() * 0.001
		if _hero == "tang":
			# 佛光：双环 + 克制的经文刻度，不贴巨大佛像。
			draw_arc(_form_center, 31.0, 0, TAU, 36, fc, 1.8)
			draw_arc(_form_center, 24.0, 0, TAU, 28, sc, 1.0)
			for i in 8:
				var a := TAU * float(i) / 8.0 + t * 0.25
				var p0 := _form_center + Vector2.from_angle(a) * 28.0
				var p1 := _form_center + Vector2.from_angle(a) * 34.0
				draw_line(p0, p1, sc, 1.0)
		else:
			# 悟空：断续赤金棍势环 + 外冲火星，强调武器战士而非佛光模板。
			for i in 4:
				var a0 := t * 0.7 + i * TAU / 4.0
				draw_arc(_form_center, 34.0, a0, a0 + 0.62, 8, fc, 2.2)
				var sp := _form_center + Vector2.from_angle(a0 + 0.31) * 39.0
				draw_line(sp, sp + Vector2.from_angle(a0 + 0.31) * 7.0, sc, 1.4)
