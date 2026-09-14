class_name TangV6Actor
extends Node2D

# 唐僧 V6.1 视觉代理：挂在旧完整游戏 JourneyFighter 下。
# 只替换唐僧的姿势/弹道演出；伤害、冷却、成长数值仍由旧完整游戏结算。

const PRIMARY := Color("f6c85f")
const SECONDARY := Color("fff7dc")
const PROJECTILE_TRAVEL := 0.24
const AUTO_CONTACT_DELAY := 0.50

var fighter
var sprite: AnimatedSprite2D
var main
var dragon_left := 0.0

# KeyframeLib 所需状态（与现 main/player.gd 同字段契约）。
var kf_sprite: Sprite2D
var kf_slug := ""
var kf_action := ""
var kf_t := 0.0
var kf_one_shot := false
var kf_speed := 1.0
var kf_fade_sprite: Sprite2D
var kf_xfade_left := 0.0
var kf_xfade_dur := 0.075
var kf_fade_base := Color.WHITE
var kf_blend_left := 0.0
var kf_blend_dur := 0.1
var kf_glow_sprite: Sprite2D
var kf_trail: Line2D
var kf_seg := -1
var kf_freeze_left := 0.0
var kf_after_t := -1.0
var kf_orb: Sprite2D
var kf_release_t := -1.0
var kf_release_cb: Callable = Callable()
var kf_cast_action := ""

var _enabled := false
var _last_auto_step := -1
var _prev_cool := {"q": 0.0, "e": 0.0, "g": 0.0, "r": 0.0}
var _pending_auto := false
var _pending_target := Vector2.ZERO
var _pending_release_at := 0.0
var _shots: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _seal_alpha := 0.0
var _seal_world := Vector2.ZERO

func setup(p) -> void:
	fighter = p
	main = fighter.game
	sprite = fighter.sprite
	position = Vector2.ZERO
	z_index = 90
	KeyframeLib.attach(self)
	kf_slug = KeyframeLib.slug_for("tang", false)
	_last_auto_step = int(fighter.auto_step)
	for key in _prev_cool.keys():
		_prev_cool[key] = float(fighter.cool.get(key, 0.0))
	_set_enabled(String(fighter.hero) == "tang")

func in_form() -> bool:
	return fighter != null and float(fighter.form_left) > 0.0

func kf_cancel_release() -> void:
	kf_release_t = -1.0
	kf_release_cb = Callable()
	kf_cast_action = ""
	if kf_orb != null:
		kf_orb.visible = false

func _set_enabled(v: bool) -> void:
	if _enabled == v:
		return
	_enabled = v
	if not _enabled:
		KeyframeLib.hide_visuals(self)
		if sprite != null:
			sprite.visible = true
		_pending_auto = false
		_shots.clear()
		_impacts.clear()
		queue_redraw()
		return
	if sprite != null:
		sprite.visible = false
	kf_action = ""
	kf_t = 0.0

func _process(delta: float) -> void:
	if fighter == null or not is_instance_valid(fighter):
		queue_free()
		return
	main = fighter.game
	sprite = fighter.sprite
	_set_enabled(String(fighter.hero) == "tang")
	if not _enabled:
		return
	if kf_slug == "":
		kf_slug = KeyframeLib.slug_for("tang", false)
	if kf_slug == "":
		# V6 数据缺失时绝不让人物消失。
		sprite.visible = true
		return

	# 旧完整游戏的 facing 是 Vector2；V6 姿势跟随相同朝向。
	sprite.flip_h = float(fighter.facing.x) < 0.0
	var dt := minf(delta, 0.05)
	if main != null and float(main.hitstop) > 0.0:
		queue_redraw()
		return

	_capture_tang_attacks()
	_capture_skill_actions()
	var moving := Vector2(fighter.move_vector).length_squared() > 0.01 or float(fighter.dash_left) > 0.0
	if float(fighter.dash_left) > 0.0 and kf_action != "dodge":
		KeyframeLib.play_action(self, "dodge", true)
	KeyframeLib.tick(self, dt, moving)
	_tick_pending_release()
	_tick_shots(dt)
	_tick_impacts(dt)
	_tick_seal(dt)
	queue_redraw()

func _capture_tang_attacks() -> void:
	if main == null:
		return
	# 旧完整游戏会先把唐僧平A作为“目标点圆形攻击”排队。
	# 这里把同一份攻击延后到真实弹体接触时刻，不复制伤害、不改数值。
	var arr: Array = main.attacks
	for i in range(arr.size()):
		if not (arr[i] is Dictionary):
			continue
		var a: Dictionary = arr[i]
		if String(a.get("hero", "")) != "tang" or not bool(a.get("auto", false)):
			continue
		if bool(a.get("_tang_v6_bound", false)):
			continue
		a["_tang_v6_bound"] = true
		a["delay"] = maxf(float(a.get("delay", 0.0)), AUTO_CONTACT_DELAY)
		# 旧 lotus 圆环只保留为接触反馈；缩小，避免覆盖人物。
		a["radius"] = minf(float(a.get("radius", 40.0)), 44.0)
		a["vfx"] = "impact"
		arr[i] = a
		_pending_target = Vector2(a.get("at", fighter.position + fighter.facing * 150.0))
		_start_auto_action()
	main.attacks = arr

func _start_auto_action() -> void:
	_pending_auto = true
	KeyframeLib.play_action(self, "atk_combo", true)
	_pending_release_at = KeyframeLib.release_time(kf_slug, "atk_combo")
	_seal_alpha = 0.0

func _capture_skill_actions() -> void:
	# 先把唐僧 Q/E/G 的人物姿势换成 V6.1；旧技能伤害/机制保持原逻辑。
	var mapping := {"q": "core_1", "e": "core_2", "g": "unlock_1"}
	for key in ["q", "e", "g"]:
		var now := float(fighter.cool.get(key, 0.0))
		var prev := float(_prev_cool.get(key, 0.0))
		if now > prev + 0.20 and KeyframeLib.has_action(kf_slug, String(mapping[key])):
			KeyframeLib.play_action(self, String(mapping[key]), true)
		_prev_cool[key] = now

func _tick_pending_release() -> void:
	if not _pending_auto or kf_action != "atk_combo":
		return
	if kf_t < _pending_release_at:
		# 法印必须跟 palm 锚点移动；释放前逐渐形成。
		var k := clampf(kf_t / maxf(_pending_release_at, 0.001), 0.0, 1.0)
		_seal_alpha = maxf(_seal_alpha, smoothstep(0.28, 1.0, k))
		_seal_world = KeyframeLib.body_anchor_world(self, "palm")
		return
	var from := KeyframeLib.body_anchor_world(self, "palm")
	var to := _pending_target
	if from.distance_to(to) < 40.0:
		to = from + (fighter.facing.normalized() if Vector2(fighter.facing).length() > 0.1 else Vector2.RIGHT) * 150.0
	_shots.append({"from": from, "to": to, "pos": from, "age": 0.0, "dur": PROJECTILE_TRAVEL})
	_pending_auto = false
	_seal_alpha = 1.0
	_seal_world = from
	if main != null and main.sound != null:
		main.sound.play("cast", 0.48)

func _tick_shots(dt: float) -> void:
	var keep: Array[Dictionary] = []
	for shot in _shots:
		shot["age"] = float(shot["age"]) + dt
		var k := clampf(float(shot["age"]) / maxf(float(shot["dur"]), 0.001), 0.0, 1.0)
		var ease := k * k * (3.0 - 2.0 * k)
		shot["pos"] = Vector2(shot["from"]).lerp(Vector2(shot["to"]), ease)
		if k >= 1.0:
			_impacts.append({"pos": Vector2(shot["to"]), "life": 0.18, "max": 0.18})
			if main != null and main.fx != null:
				main.fx.burst(Vector2(shot["to"]), PRIMARY, 5)
		else:
			keep.append(shot)
	_shots = keep

func _tick_impacts(dt: float) -> void:
	for imp in _impacts:
		imp["life"] = float(imp["life"]) - dt
	_impacts = _impacts.filter(func(v): return float(v["life"]) > 0.0)

func _tick_seal(dt: float) -> void:
	if _pending_auto and kf_action == "atk_combo":
		_seal_world = KeyframeLib.body_anchor_world(self, "palm")
	else:
		_seal_alpha = maxf(0.0, _seal_alpha - dt * 7.0)

func _draw() -> void:
	if not _enabled:
		return
	# 掌前法印：小、紧贴真实手掌，不遮挡人物。
	if _seal_alpha > 0.01:
		var p := to_local(_seal_world)
		var r := 4.0 + 6.0 * _seal_alpha
		var c1 := Color(PRIMARY.r, PRIMARY.g, PRIMARY.b, 0.82 * _seal_alpha)
		var c2 := Color(SECONDARY.r, SECONDARY.g, SECONDARY.b, 0.72 * _seal_alpha)
		draw_arc(p, r, 0.0, TAU, 20, c1, 1.5)
		draw_arc(p, r * 0.58, 0.35, TAU + 0.35, 16, c2, 1.0)
		for i in 6:
			var a := TAU * float(i) / 6.0 + kf_t * 1.4
			draw_line(p + Vector2.from_angle(a) * r * 0.70, p + Vector2.from_angle(a) * r * 1.05, c2, 1.0)

	# 唯一一枚 world-space projectile：脱手后不再粘人物。
	for shot in _shots:
		var p := to_local(Vector2(shot["pos"]))
		var from := Vector2(shot["from"])
		var to := Vector2(shot["to"])
		var dir := (to - from).normalized()
		var dl := (to_local(Vector2(shot["pos"]) + dir * 8.0) - p).normalized()
		var side := dl.orthogonal()
		var body := PackedVector2Array([p + dl * 6.0, p + side * 3.0, p - dl * 4.0, p - side * 3.0, p + dl * 6.0])
		draw_colored_polygon(body, Color(PRIMARY.r, PRIMARY.g, PRIMARY.b, 0.38))
		draw_polyline(body, SECONDARY, 1.25)
		draw_circle(p - dl * 8.0, 1.6, Color(PRIMARY.r, PRIMARY.g, PRIMARY.b, 0.72))
		draw_circle(p - dl * 13.0, 1.0, Color(PRIMARY.r, PRIMARY.g, PRIMARY.b, 0.34))

	# 接触后才生成的小型命中反馈。
	for imp in _impacts:
		var p := to_local(Vector2(imp["pos"]))
		var k := clampf(float(imp["life"]) / maxf(float(imp["max"]), 0.001), 0.0, 1.0)
		var grow := 1.0 - k
		var r := lerpf(4.0, 13.0, grow)
		for i in 6:
			var a := TAU * float(i) / 6.0
			draw_line(p + Vector2.from_angle(a) * r * 0.35, p + Vector2.from_angle(a) * r, Color(PRIMARY.r, PRIMARY.g, PRIMARY.b, 0.78 * k), 1.5)
		draw_circle(p, 2.2, Color(SECONDARY.r, SECONDARY.g, SECONDARY.b, 0.90 * k))
