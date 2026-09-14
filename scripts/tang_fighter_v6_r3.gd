class_name TangFighterV6R3
extends TangFighterV6R2

## R3：把 R2 已完成的新技能执行器真正接到 cast() 动态分派。
## 旧 TangFighterV6 的 Q/E/G/R 只保留为继承历史，不再由 Tang R3 调用。

func _tang_q(target) -> void:
	# 旧 Q 数值不变：1.9×伤害、185+22*t_nova 范围、200击退、净化；
	# 变化只在动作/投射/Contact/Impact 链。
	var radius := 185.0 + 22.0 * upgrade("t_nova")
	var dmg := damage() * 1.9
	var target_pos := target.position if target != null else position + facing * 250.0
	var group := _next_spell_group()
	var cb := Callable(self, "_release_q_r3").bind(target_pos, dmg, radius, group)
	var windup := _kf_cast("core_1", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "q"

func _release_q_r3(target_pos: Vector2, dmg: float, radius: float, group: int) -> void:
	_spawn_spell(target_pos, dmg, "seal", {
		"speed": 560.0,
		"life": 1.15,
		"knock": 200.0,
		"impact_radius": radius,
		"grant_combo": true,
		"hit_group_id": group,
		"cleanse": true
	})
	var echo_lv := upgrade("t_ring")
	if echo_lv > 0:
		var echo_damage := dmg * .5 * echo_lv
		var cb := Callable(self, "_release_q_echo_r3").bind(target_pos, echo_damage, radius * 1.30, group)
		get_tree().create_timer(.24).timeout.connect(cb)

func _release_q_echo_r3(target_pos: Vector2, dmg: float, radius: float, group: int) -> void:
	if is_dead or game == null:
		return
	# 余印也必须重新从当前 palm 脱手、飞行、Contact；不能在落点凭空爆第二圈。
	_spawn_spell(target_pos, dmg, "seal", {
		"speed": 610.0,
		"life": 1.0,
		"knock": 90.0,
		"impact_radius": radius,
		"grant_combo": true,
		"hit_group_id": group,
		"cleanse": true,
		"style_index": 1
	})

func _tang_e() -> void:
	var cb := Callable(self, "_release_e")
	var windup := _kf_cast("core_2", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "e"

func _tang_g() -> void:
	var dmg := damage() * 2.2
	var cb := Callable(self, "_release_g").bind(dmg)
	var windup := _kf_cast("unlock_1", cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "g"

func _ultimate() -> bool:
	if hero != "tang":
		return super()
	if form_left <= 0 or form_age < .8 or ultimate < 100:
		game.toast("法相中积满终结灵力后，按 R 释放")
		return false
	var primary := HeroIdentity.primary("tang")
	game.cinematic("大乘梵音·万字诛邪", primary)
	game.sound.play("ultimate")
	cool.r = 18
	invulnerable = maxf(invulnerable, .8)
	animate("cast", .7)
	var action := "finisher" if KeyframeLib.has_action(kf_slug, "finisher") else "unlock_1"
	var cb := Callable(self, "_release_r").bind(damage() * 8.0)
	var windup := _kf_cast(action, cb)
	_chant_left = maxf(_chant_left, windup)
	_chant_mode = "r"
	# 不在这里 end_form()；R2._release_r 会在最后一批梵音矢释放后再收法相。
	return true
