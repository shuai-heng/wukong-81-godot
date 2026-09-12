extends Node2D
## Boss：五行山·石猿王（三阶段）+ 收服后转为队友
## 美术占位：Boss 帧待美术管线补充（A03），当前用狼帧放大+深紫着色，剪影可辨

signal tamed
signal defeated

const TAME_THRESHOLD := 0.12      # 残血 12% 以下可收服
const DEF := {"hp": 900.0, "contact": 16.0, "speed": 46.0, "scale": 2.1, "tint": Color(0.72, 0.38, 0.85), "kind": "wolf", "name": "石猿王"}

var boss_name := "石猿王"
var max_hp := 900.0
var hp := 900.0
var phase := 1
var cfg: Dictionary = {}
var unlocked_hero := "wukong"
var tame_ready := false
var is_ally := false
var hit_r := 34.0
var flash_left := 0.0
var knock := Vector2.ZERO
var anim_t := 0.0
var charge_cd := 3.5
var slam_cd := 5.0
var charge_left := 0.0
var charge_dir := Vector2.ZERO
var attack_cd := 0.0
var follow_t := 0.0
var sprite: Sprite2D
var main: Node2D
var base_tint: Color = Color(0.72, 0.38, 0.85)
var art_static := false             # G15：使用正式 Boss PNG 单帧静态图时停止图集走帧

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = SpriteLib.frame_tex(Vector2i(0, 2))
	sprite.scale = Vector2(2.1, 2.1)
	sprite.modulate = base_tint
	add_child(sprite)
	add_to_group("boss")
	add_to_group("enemies")
	_apply_trial_art()

## G15：章节 Boss 名对应正式 PNG（黄风大圣/黄风怪→yellow_wind_king，牛魔王→bull_demon_king），
## 命中即替换贴图并取消占位紫染色；未命中保持原渲染 fallback
func _apply_trial_art() -> void:
	if art_static:
		return
	var t := SpriteLib.trial_tex("boss:" + boss_name)
	if t == null:
		return
	sprite.texture = t
	var base: float = float(cfg.get("scale", DEF["scale"])) if not cfg.is_empty() else float(DEF["scale"])
	sprite.scale = Vector2.ONE * SpriteLib.fit_scale(t, base)
	sprite.modulate = Color.WHITE
	base_tint = Color.WHITE
	art_static = true

func setup(m: Node2D, chapter_cfg: Dictionary = {}) -> void:
	main = m
	cfg = chapter_cfg
	max_hp = float(cfg.get("hp", 900.0))
	hp = max_hp
	boss_name = str(cfg.get("name", DEF["name"]))
	unlocked_hero = str(cfg.get("unlock", "wukong"))
	sprite.scale = Vector2(float(cfg.get("scale", 2.1)), float(cfg.get("scale", 2.1)))
	sprite.modulate = cfg.get("tint", DEF["tint"])
	base_tint = sprite.modulate
	_apply_trial_art()

func _physics_process(delta: float) -> void:
	if is_ally:
		_ally_tick(delta)
		return
	var player: Node2D = main.player
	var to_p: Vector2 = player.global_position - global_position
	var dir := to_p.normalized()
	attack_cd = maxf(0.0, attack_cd - delta)
	charge_cd = maxf(0.0, charge_cd - delta)
	slam_cd = maxf(0.0, slam_cd - delta)
	anim_t += delta
	var speed := float(cfg.get("speed", 46.0))
	if phase == 3:
		speed *= 1.4
	if charge_left > 0.0:
		charge_left -= delta
		global_position += charge_dir * 330.0 * delta
		modulate = Color(0.9, 0.6, 1.0, 0.75)
	else:
		modulate = Color.WHITE
		if to_p.length() > hit_r + 14.0:
			global_position += dir * speed * delta
	global_position += knock * delta
	knock = knock.move_toward(Vector2.ZERO, 500.0 * delta)
	global_position = global_position.clamp(Vector2(40, 40), Vector2(1560, 1160))
	sprite.flip_h = dir.x < 0.0
	if not art_static:
		sprite.texture = SpriteLib.frame_tex(Vector2i(int(anim_t * 6.0) % 2, 2))
	# 阶段推进
	var frac := hp / max_hp
	phase = 1 if frac > 0.66 else (2 if frac > 0.33 else 3)
	var behavior := str(cfg.get("behavior", "charge"))
	# 行为分派：charge 冲锋 / slam 震地 / ranged 风弹 / pull 袖里乾坤 / summon 召唤 / mirror 高速压制
	match behavior:
		"ranged":
			charge_cd = maxf(0.0, charge_cd - delta)
			if charge_cd <= 0.0:
				charge_cd = float(cfg.get("ranged_every", 2.2))
				main.spawn_bullet(global_position, dir, 240.0, 10.0)
		"pull":
			slam_cd = maxf(0.0, slam_cd - delta)
			if slam_cd <= 0.0 and to_p.length() < 340.0:
				slam_cd = 4.5
				player.global_position = player.global_position.move_toward(global_position, 170.0)
				player.take_damage(12.0, Vector2.ZERO, self)
				main.spawn_fx(global_position, 200.0, Color(0.55, 0.75, 0.55))
		"summon":
			charge_cd = maxf(0.0, charge_cd - delta)
			if charge_cd <= 0.0:
				charge_cd = 5.0
				main.summon_minions(global_position, 2 + (3 if phase == 3 else 0))
		"mirror":
			attack_cd = maxf(0.0, attack_cd - delta)
			if attack_cd <= 0.0 and to_p.length() < hit_r + 30.0:
				attack_cd = 0.45
				player.take_damage(9.0, dir * 70.0, self)
			if phase >= 2 and charge_cd <= 0.0:
				charge_cd = 2.2
				charge_left = 0.4
				charge_dir = dir
	# 通用：charge 型（默认）与 phase>=2 冲锋
	if behavior == "charge" or (behavior in ["mirror", "summon"] and phase >= 2):
		if charge_cd <= 0.0 and charge_left <= 0.0:
			charge_cd = float(cfg.get("charge_every", 4.0))
			charge_left = 0.55
			charge_dir = dir
	if behavior == "slam" or behavior == "slam_only":
		slam_cd = maxf(0.0, slam_cd - delta)
		if slam_cd <= 0.0:
			slam_cd = float(cfg.get("slam_every", 5.0))
			main.spawn_fx(global_position, 150.0, Color("c46bff"))
			if to_p.length() < 170.0:
				player.take_damage(14.0, dir * 90.0, self)
	elif phase == 3 and behavior != "ranged" and behavior != "pull" and slam_cd <= 0.0:
		slam_cd = 5.0
		main.spawn_fx(global_position, 150.0, Color("c46bff"))
		if to_p.length() < 170.0:
			player.take_damage(14.0, dir * 90.0, self)
	if to_p.length() < hit_r + 12.0 and attack_cd <= 0.0:
		attack_cd = 0.8
		player.take_damage(float(cfg.get("contact", 16.0)), dir * 90.0, self)
	if flash_left > 0.0:
		flash_left -= delta
		if flash_left <= 0.0:
			modulate = Color.WHITE
	if frac <= TAME_THRESHOLD and not tame_ready:
		tame_ready = true
		main.on_boss_tame_ready()

func _ally_tick(delta: float) -> void:
	var player: Node2D = main.player
	var to_p: Vector2 = player.global_position - global_position
	if to_p.length() > 60.0:
		global_position += to_p.normalized() * 150.0 * delta
	anim_t += delta
	if not art_static:
		sprite.texture = SpriteLib.frame_tex(Vector2i(int(anim_t * 5.0) % 2, 2))
	follow_t -= delta
	if follow_t <= 0.0:
		follow_t = 0.8
		for e in get_tree().get_nodes_in_group("enemies"):
			if e.global_position.distance_to(global_position) < 110.0:
				e.take_hit(70.0, (e.global_position - global_position).normalized() * 120.0)
				break

func take_hit(dmg: float, k: Vector2) -> void:
	if is_ally:
		return
	hp -= dmg
	flash_left = 0.1
	knock = k * 0.35
	modulate = Color(2.6, 2.6, 2.6)
	if hp <= 0.0:
		hp = 0.0
		_tame(true)

func _tame(by_zero: bool) -> void:
	if is_ally:
		return
	is_ally = true
	tame_ready = false
	remove_from_group("boss")
	remove_from_group("enemies")
	add_to_group("allies")
	sprite.modulate = base_tint.lerp(Color.WHITE, 0.55)
	scale = Vector2(0.85, 0.85)
	if by_zero:
		hp = max_hp * 0.35
	main.on_boss_tamed(unlocked_hero)
	tamed.emit()
