class_name TangFighterV6R2
extends TangFighterV6

## 唐僧第二轮正式技能编排。
## 目标：旧 Tang 技能模板在运行时完全旁路；保留旧伤害/CD/升级口径，重做动作语义、接触时序和视觉层级。
var _spell_group_serial := 0
var _seen_hit_groups := {}

func _next_spell_group() -> int:
	_spell_group_serial += 1
	return _spell_group_serial

func register_spell_hit(group_id: int) -> void:
	if group_id <= 0:
		on_hit()
		return
	if _seen_hit_groups.has(group_id):
		return
	_seen_hit_groups[group_id] = true
	# 只保留很小的集合，避免长局缓存增长。
	if _seen_hit_groups.size() > 32:
		var keys := _seen_hit_groups.keys()
		for i in mini(16, keys.size()):
			_seen_hit_groups.erase(keys[i])
	on_hit()

func tang_spell_hit(e, base_damage: float, force: Vector2, ultimate_hit := false) -> bool:
	if e == null or not is_instance_valid(e) or e.dead or e.tame_ready:
		return false
	# 复刻旧 resolve_attack 的 crit / frost / burn 口径，视觉返工不偷改通用构筑收益。
	var crit := game.rng.randf() < minf(.4, .08 * upgrade("crit"))
	var dmg := base_damage * (1.8 if crit else 1.0)
	if upgrade("frost") > 0:
		e.slow = 2.5 + upgrade("frost")
	if upgrade("burn") > 0:
		e.burn = 3.0 + upgrade("burn")
	var ok := e.hit(dmg, force, crit, true, ultimate_hit)
	if ok and is_instance_valid(e):
		var number_color := Color("ffd993") if crit or ultimate_hit else HeroIdentity.secondary("tang")
		game.fx.number(e.global_position, str(int(dmg)), number_color, crit or ultimate_hit)
	return ok

# ====================== 平A：三拍咒语弹幕 ======================
func _auto(target) -> void:
	if hero != "tang":
		super(target)
		return
	auto_step += 1
	cool.auto = maxf(.23, .50 * (1 - .09 * upgrade("atkSpeed")))
	animate("atk", .4)
	facing = (target.position - position).normalized()
	var splash := 40.0 * (1 + .12 * upgrade("range"))
	var cb := Callable(self, "_release_auto_r2").bind(target.get_instance_id(), damage(), auto_step % 3, splash)
	var windup := _kf_cast("atk_combo", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "normal"

func _release_auto_r2(vid: int, dmg: float, style: int, splash: float) -> void:
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
		"grant_combo": true,
		"hit_group_id": 0,
		"impact_radius": splash,
		"style_index": style
	})

# ====================== E：锦襕袈裟 ======================
func _release_e() -> void:
	# 旧 E：3s shield + 105/3s/4伤害 ward + 一次 170 半径、0.4× 伤害。
	# 新视觉不再画 ring；一次释放脉冲由袈裟展开承担，持续伤害由贴身护持承担。
	shield = 3.0
	var ward := TangWardV6.new()
	game.add_child(ward)
	ward.configure(game, self, 3.0, 105.0, 4.0)
	_spawn_tang_impact(global_position, "robe", 170.0)
	var hits := 0
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		var off := e.global_position - global_position
		if off.length() > 190.0:
			continue
		var force := off.normalized() * 200.0 if off.length_squared() > .01 else facing * 200.0
		if tang_spell_hit(e, damage() * .4, force, false):
			hits += 1
	if hits > 0:
		on_hit()

# ====================== G：诵经·定妖 ======================
func _release_g(dmg: float) -> void:
	hp = minf(max_hp, hp + max_hp * .18)
	game.clear_hazards(position, 420)
	reveal = 6
	if position.distance_to(game.objective_at) < 490.0 and game.chapter.mechanic in ["seal", "cleanse", "rain"]:
		game.mechanic_solved = true
	var ids: Array[int] = []
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		if position.distance_to(e.position) <= 390.0:
			ids.append(e.get_instance_id())
	var group := _next_spell_group()
	for i in ids.size():
		var delay := float(i % 7) * .042 + floori(float(i) / 7.0) * .018
		var cb := Callable(self, "_release_g_bead").bind(ids[i], dmg, group)
		if delay <= .001:
			cb.call()
		else:
			get_tree().create_timer(delay).timeout.connect(cb)

func _release_g_bead(target_id: int, dmg: float, group: int) -> void:
	if is_dead or game == null:
		return
	var victim = instance_from_id(target_id)
	if not (victim is Node2D) or not is_instance_valid(victim) or victim.dead or victim.tame_ready:
		return
	# 连续弹幕的每一枚都从当时动作姿势的 palm 起飞，而不是冻结成 player.position 偏移。
	_spawn_spell(victim.global_position, dmg, "bead", {
		"speed": 620.0,
		"life": 1.35,
		"knock": 80.0,
		"target_id": target_id,
		"homing": true,
		"grant_combo": true,
		"hit_group_id": group
	})

# ====================== R：大乘梵音 ======================
func _release_r(dmg: float) -> void:
	var ids: Array[int] = []
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		if position.distance_to(e.position) <= 630.0:
			ids.append(e.get_instance_id())
	var group := _next_spell_group()
	var palm := KeyframeLib.body_anchor_world(self, "palm")
	_spawn_tang_impact(palm, "ultimate", 54.0)
	var last_delay := 0.0
	for i in ids.size():
		var delay := float(i % 8) * .040 + floori(float(i) / 8.0) * .080
		last_delay = maxf(last_delay, delay)
		var cb := Callable(self, "_release_r_arrow").bind(ids[i], dmg, group)
		if delay <= .001:
			cb.call()
		else:
			get_tree().create_timer(delay).timeout.connect(cb)
	# 法相先完成梵音释放，再收束；禁止弹体刚生成就瞬间撤掉法身。
	get_tree().create_timer(last_delay + .20).timeout.connect(Callable(self, "_finish_r_form"))

func _release_r_arrow(target_id: int, dmg: float, group: int) -> void:
	if is_dead or game == null:
		return
	var victim = instance_from_id(target_id)
	if not (victim is Node2D) or not is_instance_valid(victim) or victim.dead or victim.tame_ready:
		return
	_spawn_spell(victim.global_position, dmg, "ultimate", {
		"speed": 760.0,
		"life": 1.4,
		"knock": 320.0,
		"target_id": target_id,
		"homing": true,
		"grant_combo": true,
		"hit_group_id": group,
		"is_ultimate": true
	})

func _finish_r_form() -> void:
	if is_instance_valid(self):
		end_form()

func _spawn_tang_impact(at: Vector2, p_kind: String, p_radius: float) -> void:
	var fx := TangImpactV6.new()
	game.add_child(fx)
	fx.configure(at, p_kind, p_radius, HeroIdentity.primary("tang"), HeroIdentity.secondary("tang"), facing)

# ====================== 法相：形成 → 持续 → 收束 ======================
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
	_form_birth = minf(1.0, _form_birth + dt / .62)
	var eased := _form_birth * _form_birth * (3.0 - 2.0 * _form_birth)
	_form_echo.texture = kf_sprite.texture
	_form_echo.flip_h = kf_sprite.flip_h
	_form_echo.position = kf_sprite.position + Vector2(0, -7)
	_form_echo.rotation = kf_sprite.rotation
	_form_echo.scale = kf_sprite.scale * lerpf(.84, 1.72, eased)
	_form_echo.modulate = Color(1.0, .88, .48, .05 + .24 * eased)
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
	var t := Time.get_ticks_msec() * .001

	if _chant_left > 0.0 and kf_sprite != null and kf_sprite.visible:
		var palm := KeyframeLib.body_anchor_world(self, "palm") - global_position
		match _chant_mode:
			"q":
				# Q：掌前八角小法印逐渐成形。
				var pts := PackedVector2Array()
				for i in 8:
					pts.append(palm + Vector2.from_angle(i * TAU / 8.0 + t * .35) * 11.0)
				pts.append(pts[0])
				draw_polyline(pts, Color(primary.r, primary.g, primary.b, .72), 2.0)
				draw_line(palm - Vector2(5,0), palm + Vector2(5,0), secondary, 1.0)
				draw_line(palm - Vector2(0,5), palm + Vector2(0,5), secondary, 1.0)
			"e":
				# E：金线从身体两肩向袈裟边缘收拢，不使用圆盾。
				var body := KeyframeLib.body_anchor_world(self, "body_center") - global_position
				draw_arc(body + Vector2(-6,-18), 22, 1.7, 3.0, 12, Color(primary.r, primary.g, primary.b, .46), 2.0)
				draw_arc(body + Vector2(6,-18), 22, .14, 1.44, 12, Color(secondary.r, secondary.g, secondary.b, .52), 2.0)
			"g":
				# G：六枚念珠围掌蓄势，随后按节奏逐枚脱手。
				for i in 6:
					var a := t * 1.7 + i * TAU / 6.0
					var q := palm + Vector2.from_angle(a) * 12.0
					draw_circle(q, 1.8, secondary if i % 2 else primary)
			"r":
				# R：形成扇形经文刻度；真正大强度留给法相与多目标 contact。
				for i in 7:
					var a := lerpf(-1.0, 1.0, float(i) / 6.0) + facing.angle()
					var q0 := palm + Vector2.from_angle(a) * 12.0
					var q1 := palm + Vector2.from_angle(a) * 19.0
					draw_line(q0, q1, Color(primary.r, primary.g, primary.b, .60), 2.0)
			_:
				# 平A：四点小型法印，不盖住人物。
				for i in 4:
					var a := t * 2.3 + i * TAU / 4.0
					var q := palm + Vector2.from_angle(a) * 8.0
					draw_colored_polygon(PackedVector2Array([q+Vector2(0,-2),q+Vector2(2,0),q+Vector2(0,2),q+Vector2(-2,0)]), secondary if i % 2 else primary)

	if form_left > 0.0:
		# 法相只补经文刻度，主体是 V6.1 当前 form 人物投影。
		var ramp := clampf(_form_birth, 0.0, 1.0)
		for i in 12:
			var a2 := i * TAU / 12.0 + t * .20
			var p2 := Vector2(cos(a2) * 58.0, -30 + sin(a2) * 34.0) * ramp
			var tangent := Vector2.from_angle(a2 + PI*.5)
			draw_line(p2 - tangent * 2.5, p2 + tangent * 2.5, Color(primary.r, primary.g, primary.b, .52), 2.0)
