extends Node2D
## Tiny world-space Tang normal-attack impact. Visual only.
## Spawned only after the tracked world-space projectile leaves main.fx_shots.

var life := 0.16
var max_life := 0.16
var primary := Color("f6c85f")
var secondary := Color("fff7dc")

func setup(world_pos: Vector2, p: Color, s: Color) -> void:
	global_position = world_pos
	primary = p
	secondary = s
	z_index = 8
	queue_redraw()

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := clampf(life / max_life, 0.0, 1.0)
	var appear := 1.0 - k
	var r := lerpf(3.0, 9.0, appear)
	var c1 := Color(primary.r, primary.g, primary.b, 0.70 * k)
	var c2 := Color(secondary.r, secondary.g, secondary.b, 0.82 * k)
	# 中心只是一粒小闪光；外围6枚短“经文/莲瓣”线，不做大爆炸。
	draw_circle(Vector2.ZERO, 1.6 + appear * 1.2, c2)
	for i in 6:
		var a := TAU * float(i) / 6.0
		var p0 := Vector2.from_angle(a) * r * 0.55
		var p1 := Vector2.from_angle(a) * r
		draw_line(p0, p1, c1, 1.2)
		var side := Vector2.from_angle(a + PI * 0.5) * 1.2
		draw_line(p1 - side, p1 + side, c2, 0.8)
