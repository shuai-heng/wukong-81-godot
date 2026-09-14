class_name TangWardV6
extends Node2D

var game
var owner_fighter
var life := 3.0
var radius := 105.0
var tick_damage := 4.0
var tick_left := 0.0
var primary := Color("F6C85F")
var secondary := Color("FFF7DC")

func configure(g, owner, duration := 3.0, r := 105.0, dmg := 4.0) -> void:
	game = g
	owner_fighter = owner
	life = duration
	radius = r
	tick_damage = dmg
	z_index = 228
	queue_redraw()

func _process(delta: float) -> void:
	if owner_fighter == null or not is_instance_valid(owner_fighter):
		queue_free()
		return
	global_position = owner_fighter.global_position
	life -= delta
	tick_left -= delta
	if tick_left <= 0.0:
		tick_left = 0.5
		for e in game.foes.duplicate():
			if not is_instance_valid(e) or e.dead or e.tame_ready:
				continue
			if e.global_position.distance_to(global_position) <= radius:
				e.hit(tick_damage, Vector2.ZERO, false, true)
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	# 不是大圆盾：用袈裟两侧弧线 + 金线垂坠表现贴身护持。
	var fade := clampf(life / 0.35, 0.0, 1.0)
	var c := Color(primary.r, primary.g, primary.b, 0.50 * fade)
	var c2 := Color(secondary.r, secondary.g, secondary.b, 0.72 * fade)
	var shoulder_y := -34.0
	draw_arc(Vector2(-7, shoulder_y), 32.0, 1.7, 3.05, 16, c, 3.0)
	draw_arc(Vector2(7, shoulder_y), 32.0, 0.1, 1.44, 16, c, 3.0)
	draw_line(Vector2(-34, -22), Vector2(-22, 12), c2, 2.0)
	draw_line(Vector2(34, -22), Vector2(22, 12), c2, 2.0)
	draw_line(Vector2(-22, 12), Vector2(22, 12), Color(primary.r, primary.g, primary.b, 0.32 * fade), 2.0)
	var t := Time.get_ticks_msec() * 0.001
	for i in 4:
		var x := -18.0 + i * 12.0
		var y := -12.0 + sin(t * 3.0 + i) * 4.0
		draw_circle(Vector2(x, y), 1.6, c2)
