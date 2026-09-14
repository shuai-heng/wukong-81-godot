class_name TangFighterV6
extends JourneyFighter

## 唐僧 V6 专属运行时。
## 旧完整游戏继续负责章节/敌人/数值；唐僧的平A、Q、E、G、法相、R 全部旁路旧 lotus/rune/ward/程序佛圈。
var main
var dragon_left := 0.0

# ---- KeyframeLib 统一动作时钟 ----
var kf_sprite: Sprite2D
var kf_slug := ""
var kf_action := ""
var kf_t := 0.0
var kf_one_shot := false
var kf_speed := 1.0
var kf_dragon := false
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

var _form_echo: Sprite2D
var _was_form := false
var _form_birth := 0.0
var _chant_left := 0.0
var _chant_mode := ""

func _ready() -> void:
	super()
	main = game
	KeyframeLib.attach(self)
	_form_echo = Sprite2D.new()
	_form_echo.name = "TangFormEcho"
	_form_echo.visible = false
	_form_echo.z_index = 0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_form_echo.material = mat
	add_child(_form_echo)
	_kf_rebuild()

func set_hero(h: String) -> void:
	super(h)
	if kf_sprite != null:
		_kf_rebuild()

func in_form() -> bool:
	return form_left > 0.0

func _kf_rebuild() -> void:
	if hero != "tang":
		kf_slug = ""
		kf_action = ""
		KeyframeLib.hide_visuals(self)
		sprite.visible = true
		if _form_echo != null:
			_form_echo.visible = false
		return
	kf_slug = KeyframeLib.slug_for("tang", false)
	kf_action = ""
	kf_t = 0.0
	KeyframeLib.hide_visuals(self)
	sprite.visible = kf_slug == ""

func tick(dt: float, input_enabled: bool=true) -> void:
	main = game
	super(dt, input_enabled)
	_chant_left = maxf(0.0, _chant_left - dt)
	if hero != "tang" or kf_slug == "":
		_sync_form_echo(dt)
		return
	KeyframeLib.tick(self, dt, move_vector.length_squared() > 0.01 or dash_left > 0.0)
	_kf_release_tick()
	# 唐僧禁用人物中心 generic trail；拖尾只属于已脱手 projectile。
	if kf_trail != null:
		kf_trail.visible = false
		kf_trail.clear_points()
	# 960×540 完整游戏中提高人物读形，仅改视觉 scale，不改碰撞。
	if kf_sprite != null and kf_sprite.visible:
		kf_sprite.scale *= 1.16
		if kf_glow_sprite != null and kf_glow_sprite.visible:
			kf_glow_sprite.scale = kf_sprite.scale
	_sync_form_echo(dt)
	queue_redraw()

func _kf_cast(action: String, cb: Callable) -> float:
	KeyframeLib.play_action(self, action, true)
	if kf_slug == "" or not KeyframeLib.has_action(kf_slug, action):
		if cb.is_valid():
			cb.call()
		return 0.0
	KeyframeLib.schedule_release(self, action, cb)
	return float(kf_release_t) / maxf(kf_speed, 0.01)

func kf_cancel_release() -> void:
	kf_release_t = -1.0
	kf_release_cb = Callable()
	kf_cast_action = ""
	if kf_orb != null:
		kf_orb.visible = false

func _kf_release_tick() -> void:
	if kf_release_t < 0.0:
		return
	if str(kf_action) != kf_cast_action:
		kf_cancel_release()
		return
	if kf_t >= kf_release_t:
		var cb := kf_release_cb
		kf_cancel_release()
		if cb.is_valid():
			cb.call()
	else:
		KeyframeLib.update_charge(self, kf_t / maxf(kf_release_t, 0.001))
		if kf_orb != null and kf_orb.visible:
			# 硬规则：蓄力点跟真实 palm 锚点，不用 player.position + 固定偏移。
			kf_orb.global_position = KeyframeLib.body_anchor_world(self, "palm")

# ====================== 唐僧新平A ======================
func _auto(target) -> void:
	if hero != "tang":
		super(target)
		return
	auto_step += 1
	cool.auto = maxf(.23, .50 * (1 - .09 * upgrade("atkSpeed")))
	animate("atk", .4)
	facing = (target.position - position).normalized()
	var vid := target.get_instance_id()
	var cb := Callable(self, "_release_auto").bind(vid, damage())
	var windup := _kf_cast("atk_combo", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "normal"

func _release_auto(vid: int, dmg: float) -> void:
	var victim = instance_from_id(vid)
	var aim := position + facing * 190.0
	if victim is Node2D and is_instance_valid(victim):
		aim = victim.global_position
	_spawn_spell(aim, dmg, "bolt", {
		"speed": 760.0,
		"life": 1.0,
		"knock": 120.0,
		"target_id": vid,
		"homing": true,
		"grant_combo": true
	})

# ====================== 唐僧 Q/E/G ======================
func cast(key: String) -> bool:
	if hero != "tang":
		return super(key)
	if is_dead or float(cool[key]) > 0.0 or anim_left > .28:
		return false
	if key == "r":
		return _ultimate()
	if key == "g":
		var need := g_ability()
		if not game.has_ability(need):
			game.toast("尚未习得" + JourneyContent.ABILITIES[need].name + " · 前往" + JourneyContent.ABILITIES[need].source)
			game.sound.play("ui", .4)
			return false
	var target = game.nearest(position, 600)
	if target != null:
		facing = (target.position - position).normalized()
	var mouse := game.get_global_mouse_position() - position
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and mouse.length() > 8:
		facing = mouse.normalized()
	# 保留旧平衡数值：Q 3.5 / E 6.5 / G 14，再乘原 cdr。
	cool[key] = (3.5 if key == "q" else (6.5 if key == "e" else 14.0)) * maxf(.62, 1 - .1 * upgrade("cdr"))
	animate("cast" if key in ["g", "e"] else "atk", .4)
	game.sound.play(hero, .9)
	match key:
		"q": _tang_q(target)
		"e": _tang_e()
		"g": _tang_g()
	game.skill_used(hero, key)
	return true

func _tang_q(target) -> void:
	# 掌印镇压：从 palm 发射；抵达世界落点后才展开范围判定。
	var r := 185.0 + 22.0 * upgrade("t_nova")
	var target_pos := position + facing * 250.0
	if target != null:
		target_pos = target.position
	var cb := Callable(self, "_release_q").bind(target_pos, damage() * 1.9, r)
	var windup := _kf_cast("core_1", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "q"

func _release_q(target_pos: Vector2, dmg: float, r: float) -> void:
	_spawn_spell(target_pos, dmg, "seal", {
		"speed": 560.0,
		"life": 1.15,
		"knock": 200.0,
		"impact_radius": r,
		"grant_combo": true,
		"cleanse": true
	})
	var echo_lv := upgrade("t_ring")
	if echo_lv > 0:
		var cb := Callable(self, "_release_q_echo").bind(target_pos, dmg * .5 * echo_lv, r * 1.30)
		get_tree().create_timer(.24).timeout.connect(cb)

func _release_q_echo(target_pos: Vector2, dmg: float, r: float) -> void:
	if not is_instance_valid(self) or is_dead:
		return
	_spawn_spell(target_pos, dmg, "seal", {
		"speed": 610.0,
		"life": 1.0,
		"knock": 90.0,
		"impact_radius": r,
		"cleanse": true
	})

func _tang_e() -> void:
	# 锦襕袈裟：不再调用旧 ward/ring；释放帧生成贴身袈裟护持。
	var cb := Callable(self, "_release_e")
	var windup := _kf_cast("core_2", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "e"

func _release_e() -> void:
	shield = 3.0
	var ward := TangWardV6.new()
	game.add_child(ward)
	ward.configure(game, self, 3.0, 105.0, 4.0)
	var palm := KeyframeLib.body_anchor_world(self, "palm")
	game.fx.burst(palm, HeroIdentity.secondary("tang"), 4)

func _tang_g() -> void:
	# 诵经·定妖：保留旧 G 的 390 范围、2.2×伤害、18%治疗、净化、揭示；改成逐目标念珠接触结算。
	var cb := Callable(self, "_release_g").bind(damage() * 2.2)
	var windup := _kf_cast("unlock_1", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "g"

func _release_g(dmg: float) -> void:
	hp = minf(max_hp, hp + max_hp * .18)
	game.clear_hazards(position, 420)
	reveal = 6
	var from := KeyframeLib.body_anchor_world(self, "palm")
	var first := true
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		if position.distance_to(e.position) > 390.0:
			continue
		_spawn_spell(e.position, dmg, "bead", {
			"from": from,
			"speed": 620.0,
			"life": 1.35,
			"knock": 80.0,
			"target_id": e.get_instance_id(),
			"homing": true,
			"grant_combo": first
		})
		first = false

# ====================== 法相 / R ======================
func _ultimate() -> bool:
	if hero != "tang":
		return super()
	if form_left <= 0 or form_age < .8 or ultimate < 100:
		game.toast("法相中积满终结灵力后，按 R 释放")
		return false
	var primary := HeroIdentity.primary("tang")
	game.cinematic("大乘梵音·万字诛邪", primary, .8)
	game.sound.play("ultimate")
	cool.r = 18
	invulnerable = maxf(invulnerable, .8)
	animate("cast", .7)
	var action := "finisher" if KeyframeLib.has_action(kf_slug, "finisher") else "unlock_1"
	var cb := Callable(self, "_release_r").bind(damage() * 8.0)
	var windup := _kf_cast(action, cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "r"
	return true

func _release_r(dmg: float) -> void:
	var from := KeyframeLib.body_anchor_world(self, "palm")
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		if position.distance_to(e.position) > 630.0:
			continue
		_spawn_spell(e.position, dmg, "ultimate", {
			"from": from,
			"speed": 760.0,
			"life": 1.4,
			"knock": 320.0,
			"target_id": e.get_instance_id(),
			"homing": true,
			"is_ultimate": true
		})
	end_form()

func _spawn_spell(target_pos: Vector2, dmg: float, p_kind: String, opts := {}) -> void:
	var from: Vector2 = opts.get("from", KeyframeLib.body_anchor_world(self, "palm"))
	var p := TangSpellProjectileV6.new()
	game.add_child(p)
	var cfg := opts.duplicate()
	cfg.erase("from")
	cfg["primary"] = HeroIdentity.primary("tang")
	cfg["secondary"] = HeroIdentity.secondary("tang")
	p.configure(game, self, from, target_pos, dmg, p_kind, cfg)

# ====================== 法相充能 / 受击反射 ======================
func on_hit() -> void:
	if hero != "tang":
		super()
		return
	combo = combo + 1 if combo_left > 0 else 1
	combo_left = 2.8
	if form_left <= 0:
		form_charge = minf(100, form_charge + (5 + .5 * min(combo, 12)) * (1 + .2 * upgrade("comboForm")))
		if form_charge >= 100:
			form_charge = 0
			form_left = 10 + upgrade("formDuration")
			form_age = 0
			ultimate = 0
			_form_birth = 0.0
			game.cinematic("佛光金身法相", HeroIdentity.primary("tang"), .8)
			game.sound.play("form")
			game.fx.burst(position - Vector2(0, 18), HeroIdentity.secondary("tang"), 6)
	elif form_age >= .8:
		ultimate = minf(100, ultimate + 2 * (1 + .2 * upgrade("ultGain")))

func take_hit(amount: float, from: Vector2) -> bool:
	# 复制旧伤害口径，但删掉 Tang 旧 reflect ring；有反伤时改成一枚真实 world-space 经文反击。
	if hero != "tang":
		return super(amount, from)
	if invulnerable > 0 or dash_left > 0 or is_dead:
		return false
	amount *= float(game.save.settings.get("difficulty", 1.0))
	var reduction := minf(.65, .08 * upgrade("dr") + (.4 if shield > 0 else 0))
	var actual := amount * (1 - reduction)
	hp = maxf(0, hp - actual)
	invulnerable = .55
	combo = 0
	combo_left = 0
	if anim_left <= 0:
		animate("hurt", .2)
	game.sound.play("hurt")
	game.fx.number(position, "-" + str(int(actual)), Color("ff8d88"), true)
	game.shake = maxf(game.shake, 4)
	game.hurt_flash = .22
	position = game.world.resolve(position + (position - from).normalized() * 9, 10)
	var reflect_dmg := 5.0 * upgrade("thorns")
	if shield > 0 and upgrade("t_reflect") > 0:
		reflect_dmg += 8.0 + 8.0 * upgrade("t_reflect")
	if reflect_dmg > 0:
		var target = game.nearest(position, 180)
		if target != null:
			_spawn_spell(target.position, reflect_dmg, "bead", {
				"speed": 680.0,
				"life": .8,
				"knock": 60.0,
				"target_id": target.get_instance_id(),
				"homing": true
			})
	if hp <= 0:
		is_dead = true
		game.fail_run()
	return true

func end_form() -> void:
	super()
	_form_birth = 0.0
	_was_form = false
	if _form_echo != null:
		_form_echo.visible = false
	if kf_slug != "":
		kf_action = ""

func _sync_form_echo(dt: float) -> void:
	var now := hero == "tang" and form_left > 0.0 and kf_sprite != null and kf_sprite.visible
	if now and not _was_form:
		_form_birth = 0.0
	if not now:
		if _form_echo != null:
			_form_echo.visible = false
		_was_form = false
		return
	_was_form = true
	_form_birth = minf(1.0, _form_birth + dt / .55)
	var eased := _form_birth * _form_birth * (3.0 - 2.0 * _form_birth)
	_form_echo.texture = kf_sprite.texture
	_form_echo.flip_h = kf_sprite.flip_h
	_form_echo.position = kf_sprite.position + Vector2(0, -5)
	_form_echo.rotation = kf_sprite.rotation
	_form_echo.scale = kf_sprite.scale * lerpf(.78, 1.55, eased)
	_form_echo.modulate = Color(1.0, .88, .48, .08 + .20 * eased)
	_form_echo.visible = true

func _draw() -> void:
	if hero != "tang":
		super()
		return
	# 接地阴影。
	draw_set_transform(Vector2(0, 2), 0, Vector2(1, .4))
	draw_circle(Vector2.ZERO, 17, Color(0, 0, 0, .34))
	draw_set_transform(Vector2.ZERO)
	var primary := HeroIdentity.primary("tang")
	var secondary := HeroIdentity.secondary("tang")
	# 起手只有掌心少量金白经文碎点；VFX 不盖人物。
	if _chant_left > 0.0 and kf_sprite != null and kf_sprite.visible:
		var palm := KeyframeLib.body_anchor_world(self, "palm") - global_position
		var t := Time.get_ticks_msec() * .001
		var count := 4 if _chant_mode == "normal" else 7
		for i in count:
			var a := t * 2.3 + i * TAU / count
			var rr := 8.0 + 2.0 * sin(t * 4.0 + i)
			var pp := palm + Vector2(cos(a), sin(a)) * rr
			draw_colored_polygon(PackedVector2Array([
				pp + Vector2(0,-2), pp + Vector2(2,0), pp + Vector2(0,2), pp + Vector2(-2,0)
			]), secondary if i % 2 else primary)
	# 法相主体由 V6.1 当前人物姿势投影；这里只补九点经文刻度，不画旧 lotus/ring。
	if form_left > 0.0:
		var t2 := Time.get_ticks_msec() * .00055
		var ramp := clampf(_form_birth, 0.0, 1.0)
		for i in 9:
			var a2 := i * TAU / 9.0 + t2
			var p2 := Vector2(cos(a2) * 48.0, -28 + sin(a2) * 28.0) * ramp
			draw_line(p2 - Vector2(2,0), p2 + Vector2(2,0), Color(primary.r, primary.g, primary.b, .62), 2.0)
			draw_line(p2 - Vector2(0,2), p2 + Vector2(0,2), Color(secondary.r, secondary.g, secondary.b, .52), 1.0)
