class_name TangSpellProjectileV6
extends Node2D

var game
var caster
var velocity := Vector2.ZERO
var destination := Vector2.ZERO
var speed := 720.0
var life := 1.2
var damage := 0.0
var knock := 90.0
var hit_radius := 12.0
var impact_radius := 0.0
var primary := Color("F6C85F")
var secondary := Color("FFF7DC")
var kind := "bolt"
var target_id := 0
var homing := false
var grant_combo := false
var cleanse := false
var is_ultimate := false
var _done := false
var _trail: Array[Vector2] = []

func configure(g, owner, start: Vector2, target: Vector2, dmg: float, p_kind := "bolt", opts := {}) -> void:
	game = g
	caster = owner
	global_position = start
	destination = target
	damage = dmg
	kind = p_kind
	speed = float(opts.get("speed", speed))
	life = float(opts.get("life", life))
	knock = float(opts.get("knock", knock))
	hit_radius = float(opts.get("hit_radius", hit_radius))
	impact_radius = float(opts.get("impact_radius", 0.0))
	primary = opts.get("primary", primary)
	secondary = opts.get("secondary", secondary)
	target_id = int(opts.get("target_id", 0))
	homing = bool(opts.get("homing", false))
	grant_combo = bool(opts.get("grant_combo", false))
	cleanse = bool(opts.get("cleanse", false))
	is_ultimate = bool(opts.get("is_ultimate", false))
	var d := destination - start
	velocity = (d.normalized() if d.length_squared() > 0.01 else Vector2.RIGHT) * speed
	z_index = 235
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _done:
		return
	if game == null or not is_instance_valid(game):
		queue_free()
		return
	var target = instance_from_id(target_id) if target_id != 0 else null
	if homing and target is Node2D and is_instance_valid(target):
		destination = target.global_position
		var want := (destination - global_position).normalized() * speed
		velocity = velocity.lerp(want, minf(1.0, delta * 6.0))
	var prev := global_position
	global_position += velocity * delta
	life -= delta
	_trail.push_front(global_position)
	while _trail.size() > 7:
		_trail.pop_back()

	# 真正的世界空间接触：弹体先移动，再检测这一帧是否碰到敌人。
	for e in game.foes.duplicate():
		if not is_instance_valid(e) or e.dead or e.tame_ready:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(e.global_position, prev, global_position)
		if closest.distance_to(e.global_position) <= hit_radius + 16.0:
			_impact(e)
			return

	if kind == "seal" and global_position.distance_to(destination) <= maxf(12.0, speed * delta * 1.1):
		global_position = destination
		_impact(null)
		return
	if life <= 0.0:
		_impact(null)
		return
	queue_redraw()

func _impact(direct_target) -> void:
	if _done:
		return
	_done = true
	var hit_any := false
	var dir := velocity.normalized()
	if impact_radius > 0.0:
		for e in game.foes.duplicate():
			if not is_instance_valid(e) or e.dead or e.tame_ready:
				continue
			var off := e.global_position - global_position
			if off.length() <= impact_radius + 20.0:
				if e.hit(damage, off.normalized() * knock, false, false, is_ultimate):
					hit_any = true
	else:
		var victim = direct_target
		if victim == null and target_id != 0:
			victim = instance_from_id(target_id)
		if victim is Node2D and is_instance_valid(victim) and not victim.dead and not victim.tame_ready:
			hit_any = victim.hit(damage, dir * knock, false, false, is_ultimate)

	if cleanse:
		game.clear_hazards(global_position, impact_radius if impact_radius > 0.0 else 44.0)
	if hit_any and grant_combo and caster != null and is_instance_valid(caster):
		caster.on_hit()

	# Contact 之后才做 Impact。普通平A只给很小的碎片，技能按层级放大。
	var r := 15.0
	var sparks := 3
	if kind == "seal":
		r = minf(maxf(28.0, impact_radius * 0.28), 56.0)
		sparks = 7
		game.fx.emit("rune", global_position, primary, 22.0, dir, 0.16)
	elif kind == "bead":
		r = 20.0
		sparks = 4
	elif kind == "ultimate":
		r = 34.0
		sparks = 9
	game.fx.emit("impact", global_position, secondary, r, dir, 0.14 if kind != "ultimate" else 0.22)
	game.fx.burst(global_position, primary, sparks)
	queue_free()

func _draw() -> void:
	# 2–4px 拖尾，不做整屏光带。
	for i in range(_trail.size() - 1):
		var a: Vector2 = _trail[i] - global_position
		var b: Vector2 = _trail[i + 1] - global_position
		var alpha := 0.30 * (1.0 - float(i) / maxf(1.0, _trail.size()))
		draw_line(a, b, Color(primary.r, primary.g, primary.b, alpha), maxf(1.0, 3.0 - i * 0.3))

	var ang := velocity.angle()
	if kind == "bead":
		draw_circle(Vector2.ZERO, 5.0, primary)
		draw_circle(Vector2.ZERO, 2.0, secondary)
		draw_line(Vector2(-7, 0).rotated(ang), Vector2(7, 0).rotated(ang), Color(secondary.r, secondary.g, secondary.b, 0.7), 1.0)
	elif kind == "seal":
		var pts := PackedVector2Array()
		for i in 8:
			pts.append(Vector2.from_angle(i * TAU / 8.0 + ang) * (10.0 if i % 2 == 0 else 6.0))
		draw_colored_polygon(pts, Color(primary.r, primary.g, primary.b, 0.72))
		draw_polyline(PackedVector2Array([Vector2(-5, 0).rotated(ang), Vector2(5, 0).rotated(ang)]), secondary, 2.0)
		draw_polyline(PackedVector2Array([Vector2(0, -5).rotated(ang), Vector2(0, 5).rotated(ang)]), secondary, 2.0)
	elif kind == "ultimate":
		var p := PackedVector2Array([
			Vector2(13, 0).rotated(ang), Vector2(0, -7).rotated(ang),
			Vector2(-10, 0).rotated(ang), Vector2(0, 7).rotated(ang)])
		draw_colored_polygon(p, Color(primary.r, primary.g, primary.b, 0.84))
		draw_line(Vector2(-13, 0).rotated(ang), Vector2(16, 0).rotated(ang), secondary, 2.0)
	else:
		var p := PackedVector2Array([
			Vector2(10, 0).rotated(ang), Vector2(0, -5).rotated(ang),
			Vector2(-7, 0).rotated(ang), Vector2(0, 5).rotated(ang)])
		draw_colored_polygon(p, primary)
		draw_circle(Vector2.ZERO, 2.0, secondary)
