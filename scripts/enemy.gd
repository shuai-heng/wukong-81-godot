extends Node2D
## 敌人：追击玩家 + 接触伤害，受击白闪/击退，燃烧/减速，死亡掉经验珠

const DEFS := {
	"wolf": {"hp": 60.0, "speed": 55.0, "touch": 9.0, "row": 2, "walk": [0, 1]},
	"bone": {"hp": 45.0, "speed": 42.0, "touch": 7.0, "row": 2, "walk": [3, 4]},
	"bat":  {"hp": 30.0, "speed": 72.0, "touch": 6.0, "row": 2, "walk": [6, 7]},
}

var kind := "wolf"
var hp := 60.0
var speed := 55.0
var touch_dmg := 9.0
var hit_r := 14.0
var flash_left := 0.0
var knock := Vector2.ZERO
var anim_t := 0.0
var burn_lvl := 0
var burn_left := 0.0
var burn_tick := 0.0
var slow_left := 0.0
var slow_amt := 0.0
var dragon_stack := 0
var revived_once := false
var dragon_until := 0.0
var sprite: Sprite2D
var main: Node2D

func setup(k: String, m: Node2D) -> void:
	kind = k
	main = m
	var d: Dictionary = DEFS[k]
	hp = d["hp"]
	speed = d["speed"]
	touch_dmg = d["touch"]
	hit_r = 18.0 if k == "wolf" else 15.0

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = SpriteLib.frame_tex(_cell(0))
	add_child(sprite)
	add_to_group("enemies")

func _cell(walk_idx: int) -> Vector2i:
	var d: Dictionary = DEFS[kind]
	return Vector2i(d["walk"][walk_idx], d["row"])

func _physics_process(delta: float) -> void:
	var player: Node2D = main.player
	var to_p: Vector2 = player.global_position - global_position
	var dir := to_p.normalized()
	var moving := to_p.length() > 12.0
	var spd := speed * (1.0 - slow_amt if slow_left > 0.0 else 1.0)
	if moving:
		global_position += dir * spd * delta
	global_position += knock * delta
	knock = knock.move_toward(Vector2.ZERO, 600.0 * delta)
	global_position = global_position.clamp(Vector2(24, 24), Vector2(1576, 1176))
	sprite.flip_h = dir.x < 0.0
	anim_t += delta
	if moving:
		var f := int(anim_t * 6.0) % 2
		sprite.texture = SpriteLib.frame_tex(_cell(f))
	if to_p.length() < 17.0:
		player.take_damage(touch_dmg, dir * 60.0, self)
		knock = -dir * 180.0
	if slow_left > 0.0:
		slow_left -= delta
		modulate = Color(0.7, 0.85, 1.0)
	elif flash_left <= 0.0:
		modulate = Color.WHITE
	if flash_left > 0.0:
		flash_left -= delta
		if flash_left <= 0.0:
			modulate = Color.WHITE
	if burn_left > 0.0:
		burn_left -= delta
		burn_tick -= delta
		if burn_tick <= 0.0:
			burn_tick = 0.5
			take_hit(6.0 * burn_lvl, Vector2.ZERO, true)

func apply_burn(lvl: int, dur: float) -> void:
	burn_lvl = maxi(burn_lvl, lvl)
	burn_left = dur

func apply_dragon(dur: float) -> void:
	if global_position.distance_to(main.player.global_position) > 99999.0:
		return
	var t := Time.get_ticks_msec() / 1000.0
	dragon_stack = dragon_stack + 1 if dragon_until > t else 1
	dragon_until = t + dur

func has_dragon() -> bool:
	return dragon_until > Time.get_ticks_msec() / 1000.0

func apply_frost(dur: float, amt: float) -> void:
	slow_left = dur
	slow_amt = maxf(slow_amt if slow_left > 0.0 else 0.0, amt)

func take_hit(dmg: float, k: Vector2, silent := false) -> void:
	hp -= dmg
	if not silent:
		flash_left = 0.1
		knock = k
		modulate = Color(3.0, 3.0, 3.0)
	if hp <= 0.0:
		# 外传·幽冥地府：亡者复苏一次（半血重立）
		if main.trial.has("revive_once") and not revived_once:
			revived_once = true
			hp = main.player.max_hp * 0.0 + 30.0
			modulate = Color(0.6, 0.4, 0.9)
			main.spawn_fx(global_position, 40.0, Color(0.6, 0.4, 0.9))
			return
		main.on_enemy_died(global_position)
		queue_free()
