extends CharacterBody2D
## 玩家：WASD 移动 / 自动攻击 / Space 冲刺（无敌帧）

signal attacked
signal died

const SPEED_BASE := 130.0
const DASH_SPEED := 460.0
const DASH_TIME := 0.18
const DASH_CD := 1.2
const ATK_INTERVAL := 0.5
const ATK_RANGE := 95.0
const ATK_ARC := deg_to_rad(65.0)
const WORLD := Rect2(24, 24, 1552, 1152)

var hp := 100.0
var max_hp := 100.0
var level := 1
var exp_pts := 0
var exp_next := 5
var speed := SPEED_BASE
var dmg := 34.0
var kills := 0
var atk_count := 0
var auto_pilot := false          # 冒烟模式自动索敌
var dash_cd_left := 0.0
var dash_left := 0.0
var dash_dir := Vector2.RIGHT
var atk_cd_left := 0.0
var atk_anim_left := 0.0
var hurt_cd := 0.0

var sprite: AnimatedSprite2D
var main: Node2D

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

	var dir := Vector2.ZERO
	if auto_pilot:
		var target := _nearest_enemy()
		if target:
			dir = (target.global_position - global_position).normalized()
	else:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("dash") and dash_cd_left <= 0.0:
		dash_left = DASH_TIME
		dash_cd_left = DASH_CD
		dash_dir = dir if dir != Vector2.ZERO else Vector2.RIGHT
		main.spawn_ghost(global_position, sprite.flip_h)

	if dash_left > 0.0:
		dash_left -= delta
		velocity = dash_dir * DASH_SPEED
		modulate.a = 0.6
	else:
		velocity = dir * speed
		modulate.a = 1.0
	move_and_slide()
	global_position = global_position.clamp(WORLD.position, WORLD.end)
	_update_anim(dir)
	_auto_attack()

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
	var best_d := ATK_RANGE
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
	atk_cd_left = ATK_INTERVAL
	atk_anim_left = 0.22
	atk_count += 1
	attacked.emit()
	var to_t := target.global_position - global_position
	sprite.flip_h = to_t.x < 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		var off: Vector2 = e.global_position - global_position
		if off.length() <= ATK_RANGE and absf(off.angle_to(to_t)) <= ATK_ARC:
			e.take_hit(dmg, off.normalized() * 120.0)

func take_damage(amount: float, knock: Vector2 = Vector2.ZERO) -> void:
	if hurt_cd > 0.0 or dash_left > 0.0:
		return
	hurt_cd = 0.55
	hp = maxf(0.0, hp - amount)
	modulate = Color(1.0, 0.5, 0.5)
	get_tree().create_timer(0.12).timeout.connect(func(): modulate = Color.WHITE)
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
		dmg *= 1.15
		speed *= 1.02
		max_hp += 10.0
		hp = minf(max_hp, hp + 20.0)
