class_name TangImpactV6
extends Node2D

## 唐僧专属世界空间 Impact。
## 只负责 Contact 之后的视觉反馈，不参与伤害判定；避免复用旧 ring/lotus/impact 模板。
var kind := "bolt"
var life := 0.18
var duration := 0.18
var radius := 18.0
var primary := Color("F6C85F")
var secondary := Color("FFF7DC")
var direction := Vector2.RIGHT

func configure(at: Vector2, p_kind: String, p_radius: float, p_primary: Color, p_secondary: Color, dir := Vector2.RIGHT) -> void:
	global_position = at
	kind = p_kind
	radius = maxf(8.0, p_radius)
	primary = p_primary
	secondary = p_secondary
	direction = dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	match kind:
		"seal": duration = .34
		"robe": duration = .28
		"ultimate": duration = .40
		"wall": duration = .14
		"bead": duration = .16
		_: duration = .16
	life = duration
	z_index = clampi(int(global_position.y / 10.0) + 3, 0, 225)
	queue_redraw()

func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	z_index = clampi(int(global_position.y / 10.0) + 3, 0, 225)
	queue_redraw()

func _progress() -> float:
	return 1.0 - clampf(life / maxf(duration, .001), 0.0, 1.0)

func _fade() -> float:
	var p := _progress()
	return sin(p * PI)

func _octagon(r: float, rotation := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(Vector2.from_angle(rotation + i * TAU / 8.0) * r)
	pts.append(pts[0])
	return pts

func _draw() -> void:
	var p := _progress()
	var f := _fade()
	var c := Color(primary.r, primary.g, primary.b, .72 * f)
	var c2 := Color(secondary.r, secondary.g, secondary.b, .86 * f)
	match kind:
		"seal":
			# Q：真正主体只有中心八角镇压印。
			# 实际 185+ 数值范围不再连成巨大几何圈，只在八方向留下低亮短刻度。
			var inner := lerpf(14.0, minf(58.0, radius * .34), p)
			draw_polyline(_octagon(inner, PI / 8.0), c2, 2.0)
			for i in 8:
				var a := i * TAU / 8.0
				var radial := Vector2.from_angle(a)
				var tangent := radial.rotated(PI * .5)
				var core0 := radial * (inner + 4.0)
				var core1 := radial * (inner + 11.0)
				draw_line(core0, core1, c, 2.0)
				# 真实作用范围位置只画 5–7px 的刻度，禁止连接成大圆/大八角。
				var edge := radial * radius
				draw_line(edge - tangent * 3.5, edge + tangent * 3.5, Color(primary.r, primary.g, primary.b, .18 * f), 1.0)
			for i in 4:
				var y := -9.0 + i * 6.0
				draw_line(Vector2(-8, y), Vector2(8, y), Color(secondary.r, secondary.g, secondary.b, .42 * f), 1.0)
		"robe":
			# 袈裟释放瞬间：左右布势向外展开，不画圆盾。
			var spread := lerpf(18.0, minf(radius * .42, 58.0), p)
			draw_arc(Vector2(-8, -22), spread, 1.70, 3.02, 18, c, 3.0)
			draw_arc(Vector2(8, -22), spread, .12, 1.44, 18, c, 3.0)
			draw_line(Vector2(-spread * .72, -8), Vector2(-spread * .45, 18), c2, 2.0)
			draw_line(Vector2(spread * .72, -8), Vector2(spread * .45, 18), c2, 2.0)
		"bead":
			var rr := lerpf(5.0, 16.0, p)
			for i in 6:
				var a := i * TAU / 6.0 + .25
				var q := Vector2.from_angle(a) * rr
				draw_circle(q, 1.8, c if i % 2 == 0 else c2)
			draw_line(-direction * 8.0, direction * 8.0, Color(secondary.r, secondary.g, secondary.b, .46 * f), 1.0)
		"ultimate":
			# 终结技单目标命中保持中等尺寸；强度来自多目标梵音矢与法相本体，而非整屏贴图。
			var r0 := lerpf(12.0, minf(48.0, radius), p)
			var r1 := r0 * 1.55
			draw_polyline(_octagon(r0, p * .28), c2, 3.0)
			draw_polyline(_octagon(r1, -p * .22), Color(primary.r, primary.g, primary.b, .32 * f), 2.0)
			for i in 8:
				var a := i * TAU / 8.0
				var q0 := Vector2.from_angle(a) * (r1 + 3.0)
				var q1 := Vector2.from_angle(a) * (r1 + 11.0)
				draw_line(q0, q1, c, 2.0)
		"wall":
			var tangent := direction.rotated(PI * .5)
			for i in 5:
				var off := tangent * float(i - 2) * 3.0
				draw_line(off, off - direction * lerpf(5.0, 13.0, p), Color(primary.r, primary.g, primary.b, .54 * f), 1.0)
		_:
			# 普通咒弹：小型经文碎片，不震屏、不画大圆。
			var rr := lerpf(4.0, 14.0, p)
			for i in 4:
				var a := PI * .25 + i * TAU / 4.0
				var q := Vector2.from_angle(a) * rr
				var d := Vector2.from_angle(a)
				draw_colored_polygon(PackedVector2Array([q + d * 3.0, q + d.rotated(PI*.5) * 1.5, q - d * 3.0, q - d.rotated(PI*.5) * 1.5]), c if i % 2 == 0 else c2)
