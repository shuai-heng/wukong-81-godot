extends Node2D
## Boss：五行山·石猿王（三阶段）+ 收服后转为队友
## 美术占位：Boss 帧待美术管线补充（A03），当前用狼帧放大+深紫着色，剪影可辨

signal tamed
signal defeated

const MAX_HP := 900.0
const CONTACT := 16.0
const SPEED_BASE := 46.0
const TAME_THRESHOLD := 0.12      # 残血 12% 以下可收服

var hp := MAX_HP
var phase := 1
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

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = SpriteLib.frame_tex(Vector2i(0, 2))
	sprite.scale = Vector2(2.1, 2.1)
	sprite.modulate = Color(0.72, 0.38, 0.85)
	add_child(sprite)
	add_to_group("boss")
	add_to_group("enemies")

func setup(m: Node2D) -> void:
	main = m

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
	var speed := SPEED_BASE
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
	sprite.texture = SpriteLib.frame_tex(Vector2i(int(anim_t * 6.0) % 2, 2))
	# 阶段推进
	var frac := hp / MAX_HP
	phase = 1 if frac > 0.66 else (2 if frac > 0.33 else 3)
	if phase >= 2 and charge_cd <= 0.0 and charge_left <= 0.0:
		charge_cd = 4.0
		charge_left = 0.55
		charge_dir = dir
	if phase == 3 and slam_cd <= 0.0:
		slam_cd = 5.0
		main.spawn_fx(global_position, 150.0, Color("c46bff"))
		if to_p.length() < 170.0:
			player.take_damage(14.0, dir * 90.0, self)
	if to_p.length() < hit_r + 12.0 and attack_cd <= 0.0:
		attack_cd = 0.8
		player.take_damage(CONTACT, dir * 90.0, self)
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
	sprite.modulate = Color(0.72, 0.85, 1.0)
	scale = Vector2(0.85, 0.85)
	if by_zero:
		hp = MAX_HP * 0.35
	main.on_boss_tamed()
	tamed.emit()
