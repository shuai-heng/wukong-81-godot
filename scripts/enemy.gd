extends Node2D
## 敌人：追击玩家 + 接触伤害，受击白闪/击退，死亡掉经验珠

const DEFS := {
	"wolf": {"hp": 60.0, "speed": 55.0, "touch": 9.0, "row": 2, "walk": [0, 1]},
	"bone": {"hp": 45.0, "speed": 42.0, "touch": 7.0, "row": 2, "walk": [3, 4]},
	"bat":  {"hp": 30.0, "speed": 72.0, "touch": 6.0, "row": 2, "walk": [6, 7]},
}

var kind := "wolf"
var hp := 60.0
var speed := 55.0
var touch_dmg := 9.0
var flash_left := 0.0
var knock := Vector2.ZERO
var anim_t := 0.0
var sprite: Sprite2D
var main: Node2D

func setup(k: String, m: Node2D) -> void:
	kind = k
	main = m
	var d: Dictionary = DEFS[k]
	hp = d["hp"]
	speed = d["speed"]
	touch_dmg = d["touch"]

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
	if moving:
		global_position += dir * speed * delta
	global_position += knock * delta
	knock = knock.move_toward(Vector2.ZERO, 600.0 * delta)
	global_position = global_position.clamp(Vector2(24, 24), Vector2(1576, 1176))
	sprite.flip_h = dir.x < 0.0
	# 两帧步进动画
	anim_t += delta
	if moving:
		var f := int(anim_t * 6.0) % 2
		sprite.texture = SpriteLib.frame_tex(_cell(f))
	# 接触伤害
	if to_p.length() < 17.0:
		player.take_damage(touch_dmg, dir * 60.0)
		knock = -dir * 180.0
	if flash_left > 0.0:
		flash_left -= delta
		if flash_left <= 0.0:
			modulate = Color.WHITE

func take_hit(dmg: float, k: Vector2) -> void:
	hp -= dmg
	flash_left = 0.1
	knock = k
	modulate = Color(3.0, 3.0, 3.0)
	if hp <= 0.0:
		main.on_enemy_died(global_position)
		queue_free()
