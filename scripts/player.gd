extends CharacterBody2D
## 玩家：WASD 移动 / 自动攻击 / Space 冲刺 / 卡牌成长（G01）

signal attacked
signal died
signal leveled

const SPEED_BASE := 130.0
const DASH_SPEED := 460.0
const DASH_TIME := 0.18
const DASH_CD_BASE := 1.2
const ATK_INTERVAL_BASE := 0.5
const ATK_RANGE_BASE := 95.0
const WORLD := Rect2(24, 24, 1552, 1152)

var hp := 100.0
var max_hp := 100.0
var level := 1
var exp_pts := 0
var exp_next := 5
var kills := 0
var atk_count := 0
var upgrades := {}                 # id -> level
var auto_pilot := false
var dash_cd_left := 0.0
var dash_left := 0.0
var dash_dir := Vector2.RIGHT
var dash_from := Vector2.ZERO
var atk_cd_left := 0.0
var atk_anim_left := 0.0
var hurt_cd := 0.0
var stance_step := 0               # 三棒重击计数
var sprite: AnimatedSprite2D
var main: Node2D

# ---- 卡牌数值（web BALANCE_CAPS 同源） ----
func lvl(id: String) -> int:
	return upgrades.get(id, 0)

func dmg_mul() -> float:
	return 1.0 + Cards.CAPS["dmgPerLevel"] * lvl("dmg")

func base_dmg() -> float:
	return 34.0 * dmg_mul()

func atk_interval() -> float:
	return ATK_INTERVAL_BASE * maxf(Cards.CAPS["atkCdMin"], 1.0 - 0.12 * lvl("atkSpeed"))

func atk_range() -> float:
	return ATK_RANGE_BASE * (1.0 + 0.16 * lvl("range")) * (1.0 + 0.08 * lvl("w_arc"))

func atk_arc() -> float:
	return deg_to_rad(65.0) + 0.3 * lvl("w_arc")

func crit_chance() -> float:
	return minf(Cards.CAPS["critMax"], 0.14 * lvl("crit"))

func dr() -> float:
	return minf(Cards.CAPS["drMax"], 0.10 * lvl("dr"))

func move_speed() -> float:
	return SPEED_BASE * (1.0 + 0.07 * lvl("moveSpeed"))

func dash_cd() -> float:
	return DASH_CD_BASE * maxf(Cards.CAPS["dashCdMin"], 1.0 - 0.22 * lvl("dashCd"))

func dash_dmg() -> float:
	return 20.0 + 14.0 * lvl("dashDmg")

func magnet_r() -> float:
	return 70.0 + 45.0 * lvl("magnet")

func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteLib.build_frames("wukong")
	sprite.animation = "idle"
	sprite.play()
	add_child(sprite)

func _physics_process(delta: float) -> void:
	dash_cd_left = maxf(0.0, dash_cd_left - delta)
	atk_cd_left = maxf(0.0, atk_cd_left - delta)
	atk_anim_left = maxf(0.0, atk_anim_left - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	if lvl("regen") > 0 and hp < max_hp:
		hp = minf(max_hp, hp + 0.6 * lvl("regen") * delta)

	var dir := Vector2.ZERO
	if auto_pilot:
		var target := _nearest_enemy()
		if target:
			dir = (target.global_position - global_position).normalized()
	else:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("dash") and dash_cd_left <= 0.0:
		dash_left = DASH_TIME
		dash_cd_left = dash_cd()
		dash_dir = dir if dir != Vector2.ZERO else Vector2.RIGHT
		dash_from = global_position
		main.spawn_phantom(global_position, sprite.flip_h)

	if dash_left > 0.0:
		dash_left -= delta
		velocity = dash_dir * DASH_SPEED
		modulate.a = 0.6
		if lvl("dashDmg") > 0:
			for e in get_tree().get_nodes_in_group("enemies"):
				if not e.has_method("take_hit"):
					continue
				if _seg_dist(e.global_position, dash_from, global_position) < 26.0 + e.hit_r:
					e.take_hit(dash_dmg(), dash_dir * 150.0)
	else:
		velocity = dir * move_speed()
		modulate.a = 1.0
	move_and_slide()
	global_position = global_position.clamp(WORLD.position, WORLD.end)
	_update_anim(dir)
	_auto_attack()

func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _update_anim(dir: Vector2) -> void:
	if dir.x != 0.0:
		sprite.flip_h = dir.x < 0.0
	if atk_anim_left > 0.0:
		sprite.play("atk")
	elif velocity.length() > 5.0:
		sprite.play("run")
	else:
		sprite.play("idle")

func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := atk_range()
	for e in get_tree().get_nodes_in_group("enemies"):
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _auto_attack() -> void:
	if atk_cd_left > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	atk_cd_left = atk_interval()
	atk_anim_left = 0.22
	atk_count += 1
	attacked.emit()
	var to_t: Vector2 = target.global_position - global_position
	sprite.flip_h = to_t.x < 0.0
	# 三棒重击（w_pose）：每第三棒伤害 ×1.9、范围 ×1.35
	stance_step = (stance_step + 1) % 3
	var heavy := lvl("w_pose") > 0 and stance_step == 0
	var dmg := base_dmg() * (1.9 if heavy else 1.0)
	var rng := atk_range() * (1.35 if heavy else 1.0)
	var arc := atk_arc() * (1.2 if heavy else 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		var off: Vector2 = e.global_position - global_position
		if off.length() <= rng + e.hit_r and absf(off.angle_to(to_t)) <= arc:
			var final_dmg := dmg
			if main.rng.randf() < crit_chance():
				final_dmg *= 2.0
			e.take_hit(final_dmg, off.normalized() * 120.0)
			if lvl("burn") > 0:
				e.apply_burn(lvl("burn"), 3.0)
			if lvl("frost") > 0:
				e.apply_frost(1.5, 0.3 * lvl("frost"))

func take_damage(amount: float, knock: Vector2 = Vector2.ZERO, source: Node2D = null) -> void:
	if hurt_cd > 0.0 or dash_left > 0.0:
		return
	hurt_cd = 0.55
	hp = maxf(0.0, hp - amount * (1.0 - dr()))
	modulate = Color(1.0, 0.5, 0.5)
	get_tree().create_timer(0.12).timeout.connect(func(): modulate = Color.WHITE)
	# 刺沙反甲：攻击者反受 9+5×层
	if source != null and source.has_method("take_hit") and lvl("thorns") > 0:
		source.take_hit(9.0 + 5.0 * lvl("thorns"), Vector2.ZERO)
	if knock != Vector2.ZERO:
		global_position += knock * 0.2
	if hp <= 0.0:
		died.emit()

func gain_exp(n: int) -> void:
	exp_pts += n
	while exp_pts >= exp_next:
		exp_pts -= exp_next
		level += 1
		exp_next = 5 + level * 3
		max_hp += 6.0
		hp = minf(max_hp, hp + 8.0)
		leveled.emit()

func apply_card(id: String) -> void:
	upgrades[id] = lvl(id) + 1
	if id == "hp":
		max_hp += 28.0
		hp = max_hp

func on_kill_heal() -> void:
	if lvl("lifesteal") > 0:
		hp = minf(max_hp, hp + 4.0 * lvl("lifesteal"))
