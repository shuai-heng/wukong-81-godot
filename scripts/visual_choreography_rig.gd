extends Node2D
## M2-R5 · Tang/Wukong vertical-slice visual choreography rig.
## VISUAL ONLY: no damage/CD/invulnerability/balance changes.
## Reads the existing V6.1 kf_action/kf_t clock and body anchors.

const IMPACT_SCRIPT := preload("res://scripts/visual_choreography_impact.gd")
const SUPPORTED_HEROES := ["tang", "wukong"]
const TANG_SEAL_MAX_R := 10.0
const FORM_BUILD_TIME := 0.55
const FORM_FADE_TIME := 0.24

var player: CharacterBody2D
var main: Node2D
var form_echo: Sprite2D

var _hero: String = ""
var _form_was_on: bool = false
var _form_age: float = 0.0
var _form_alpha: float = 0.0
var _form_center: Vector2 = Vector2.ZERO
var _seal_alpha: float = 0.0
var _seal_pos: Vector2 = Vector2.ZERO
var _seal_r: float = 0.0
var _move_alpha: float = 0.0
var _move_pos: Vector2 = Vector2.ZERO
var _move_dir: Vector2 = Vector2.RIGHT
var _next_shot_id: int = 1
var _shot_last_world: Dictionary = {}
var _projectile_visuals: Array[Dictionary] = []

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
	_tick_tang_projectiles()
	queue_redraw()

func _reset_visuals(delta: float) -> void:
	_form_alpha = maxf(0.0, _form_alpha - delta / FORM_FADE_TIME)
	_seal_alpha = 0.0
	_move_alpha = 0.0
	_projectile_visuals.clear()
	_shot_last_world.clear()
	if form_echo != null:
		form_echo.visible = false
	queue_redraw()

func _kf_sprite() -> Sprite2D:
	return player.get("kf_sprite") as Sprite2D

func _tick_form(delta: float) -> void:
	var form_on: bool = float(player.get("form_left")) > 0.0
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

	var kfs: Sprite2D = _kf_sprite()
	if form_echo == null or kfs == null or kfs.texture == null or _form_alpha <= 0.001:
		if form_echo != null:
			form_echo.visible = false
		return

	form_echo.texture = kfs.texture
	form_echo.position = kfs.position
	form_echo.rotation = kfs.rotation
	form_echo.flip_h = kfs.flip_h
	var build: float = smoothstep(0.0, 1.0, minf(1.0, _form_age / FORM_BUILD_TIME))
	var target_scale: float = 1.72 if _hero == "tang" else 2.10
	form_echo.scale = kfs.scale * lerpf(1.08, target_scale, build)
	var col: Color = HeroIdentity.primary(_hero)
	var pulse: float = 0.88 + 0.12 * sin(float(Time.get_ticks_msec()) * 0.008)
	var alpha: float = (0.18 if _hero == "tang" else 0.22) * _form_alpha * pulse
	form_echo.modulate = Color(col.r, col.g, col.b, alpha)
	form_echo.visible = true

func _tick_cast_seal(delta: float) -> void:
	_seal_alpha = maxf(0.0, _seal_alpha - delta * 7.5)
	if _hero != "tang":
		return
	var action: String = String(player.get("kf_action"))
	var slug: String = String(player.get("kf_slug"))
	if action != "atk_combo" or slug == "" or not KeyframeLib.has_action(slug, action):
		return
	var release: float = KeyframeLib.release_time(slug, action)
	var t: float = float(player.get("kf_t"))
	var palm_world: Vector2 = KeyframeLib.body_anchor_world(player, "palm")
	_seal_pos = to_local(palm_world)
	var pre: float = clampf(1.0 - maxf(release - t, 0.0) / maxf(release * 0.72, 0.08), 0.0, 1.0)
	if t <= release + 0.12:
		var release_fade: float = clampf(1.0 - maxf(t - release, 0.0) / 0.12, 0.0, 1.0)
		_seal_alpha = maxf(_seal_alpha, (0.35 + 0.65 * pre) * release_fade)
		_seal_r = lerpf(4.0, TANG_SEAL_MAX_R, pre)

func _tick_movement(delta: float) -> void:
	var vel: Vector2 = player.velocity
	if vel.length() < 24.0:
		_move_alpha = maxf(0.0, _move_alpha - delta * 7.0)
		return
	var slug: String = String(player.get("kf_slug"))
	var action: String = String(player.get("kf_action"))
	if slug == "" or action == "":
		return
	_move_alpha = minf(1.0, _move_alpha + delta * 5.0)
	_move_dir = vel.normalized()
	_move_pos = to_local(KeyframeLib.body_anchor_world(player, "body_center"))

func _rebind_tang_ring_shots_to_palm() -> void:
	if _hero != "tang" or main == null:
		return
	var shots_v: Variant = main.get("fx_shots")
	if not (shots_v is Array):
		return
	var shots: Array = shots_v
	var changed: bool = false
	for i: int in range(shots.size()):
		if not (shots[i] is Dictionary):
			continue
		var shot: Dictionary = shots[i]
		if String(shot.get("kind", "")) != "ring" or bool(shot.get("_m2r5_anchor_bound", false)):
			continue
		var palm_world: Vector2 = KeyframeLib.body_anchor_world(player, "palm")
		shot["from"] = palm_world
		shot["pos"] = palm_world
		shot["_m2r5_anchor_bound"] = true
		shot["_m2r5_id"] = _next_shot_id
		_next_shot_id += 1
		shots[i] = shot
		changed = true
	if changed:
		main.set("fx_shots", shots)

func _tick_tang_projectiles() -> void:
	_projectile_visuals.clear()
	if _hero != "tang" or main == null:
		_shot_last_world.clear()
		return
	var shots_v: Variant = main.get("fx_shots")
	if not (shots_v is Array):
		return
	var shots: Array = shots_v
	var live: Dictionary = {}
	for shot_v: Variant in shots:
		if not (shot_v is Dictionary):
			continue
		var shot: Dictionary = shot_v
		if String(shot.get("kind", "")) != "ring" or not bool(shot.get("_m2r5_anchor_bound", false)):
			continue
		var sid: int = int(shot.get("_m2r5_id", 0))
		if sid <= 0:
			continue
		var pos: Vector2 = shot.get("pos", Vector2.ZERO)
		var to: Vector2 = shot.get("to", pos)
		var dir_world: Vector2 = Vector2.RIGHT
		if to.distance_to(pos) > 0.5:
			dir_world = (to - pos).normalized()
		var dir_local: Vector2 = (to_local(pos + dir_world * 8.0) - to_local(pos)).normalized()
		live[sid] = true
		_shot_last_world[sid] = pos
		_projectile_visuals.append({"pos": to_local(pos), "dir": dir_local})

	var ended: Array[int] = []
	for sid_v: Variant in _shot_last_world.keys():
		var sid: int = int(sid_v)
		if not live.has(sid):
			_spawn_tang_impact(_shot_last_world[sid])
			ended.append(sid)
	for sid: int in ended:
		_shot_last_world.erase(sid)

func _spawn_tang_impact(world_pos: Vector2) -> void:
	if main == null:
		return
	var impact: Node2D = IMPACT_SCRIPT.new() as Node2D
	if impact == null:
		return
	main.add_child(impact)
	impact.call("setup", world_pos, HeroIdentity.primary("tang"), HeroIdentity.secondary("tang"))

func _draw() -> void:
	if not SUPPORTED_HEROES.has(_hero):
		return
	var primary: Color = HeroIdentity.primary(_hero)
	var secondary: Color = HeroIdentity.secondary(_hero)

	if _hero == "tang" and _seal_alpha > 0.01:
		var c1: Color = Color(primary.r, primary.g, primary.b, 0.78 * _seal_alpha)
		var c2: Color = Color(secondary.r, secondary.g, secondary.b, 0.62 * _seal_alpha)
		draw_arc(_seal_pos, _seal_r, 0.0, TAU, 20, c1, 1.4)
		draw_arc(_seal_pos, _seal_r * 0.62, -0.35, TAU - 0.35, 16, c2, 1.0)
		for i: int in range(6):
			var a: float = TAU * float(i) / 6.0 + float(player.get("kf_t")) * 1.7
			var p0: Vector2 = _seal_pos + Vector2.from_angle(a) * (_seal_r * 0.72)
			var p1: Vector2 = _seal_pos + Vector2.from_angle(a) * (_seal_r * 1.05)
			draw_line(p0, p1, c2, 1.0)

	if _hero == "tang":
		var pc: Color = Color(primary.r, primary.g, primary.b, 0.72)
		var pw: Color = Color(secondary.r, secondary.g, secondary.b, 0.84)
		for pv: Dictionary in _projectile_visuals:
			var p: Vector2 = pv.get("pos", Vector2.ZERO)
			var dir: Vector2 = pv.get("dir", Vector2.RIGHT)
			var side: Vector2 = dir.orthogonal()
			var diamond := PackedVector2Array([p + dir * 4.0, p + side * 2.2, p - dir * 3.0, p - side * 2.2, p + dir * 4.0])
			draw_polyline(diamond, pw, 1.0)
			draw_circle(p - dir * 6.0, 1.1, pc)
			draw_circle(p - dir * 10.0, 0.75, Color(primary.r, primary.g, primary.b, 0.38))

	if _move_alpha > 0.01:
		var side_move: Vector2 = _move_dir.orthogonal()
		var move_len: float = 7.0 if _hero == "tang" else 12.0
		var spread: float = 5.0 if _hero == "tang" else 7.0
		var mc: Color = Color(secondary.r, secondary.g, secondary.b, (0.18 if _hero == "tang" else 0.28) * _move_alpha)
		for s_v: Variant in [-1.0, 1.0]:
			var s: float = float(s_v)
			var start: Vector2 = _move_pos + side_move * spread * s
			draw_line(start, start - _move_dir * move_len, mc, 1.2)

	if _form_alpha > 0.01:
		var fc: Color = Color(primary.r, primary.g, primary.b, 0.34 * _form_alpha)
		var sc: Color = Color(secondary.r, secondary.g, secondary.b, 0.26 * _form_alpha)
		var t_now: float = float(Time.get_ticks_msec()) * 0.001
		if _hero == "tang":
			draw_arc(_form_center, 31.0, 0.0, TAU, 36, fc, 1.8)
			draw_arc(_form_center, 24.0, 0.0, TAU, 28, sc, 1.0)
			for i: int in range(8):
				var a_ring: float = TAU * float(i) / 8.0 + t_now * 0.25
				var r0: Vector2 = _form_center + Vector2.from_angle(a_ring) * 28.0
				var r1: Vector2 = _form_center + Vector2.from_angle(a_ring) * 34.0
				draw_line(r0, r1, sc, 1.0)
		else:
			for i: int in range(4):
				var a0: float = t_now * 0.7 + float(i) * TAU / 4.0
				draw_arc(_form_center, 34.0, a0, a0 + 0.62, 8, fc, 2.2)
				var spark: Vector2 = _form_center + Vector2.from_angle(a0 + 0.31) * 39.0
				draw_line(spark, spark + Vector2.from_angle(a0 + 0.31) * 7.0, sc, 1.4)
